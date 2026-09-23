import Foundation
import simd

// MARK: Attachment

public enum SurfaceKind: String, Sendable, Codable { case horizontalUp, horizontalDown, vertical }

public struct AttachmentPolicy: Sendable, Equatable {
    public var surface: SurfaceKind
    public var dropsToSupport: Bool
    public var suppressesGravity: Bool

    public static func forAffinity(_ affinity: Affinity) -> AttachmentPolicy? {
        switch affinity {
        case .floor, .tabletop: AttachmentPolicy(surface: .horizontalUp, dropsToSupport: true, suppressesGravity: false)
        case .wall: AttachmentPolicy(surface: .vertical, dropsToSupport: false, suppressesGravity: true)
        case .ceiling: AttachmentPolicy(surface: .horizontalDown, dropsToSupport: false, suppressesGravity: true)
        case .freestandingOutdoor: nil
        }
    }
}

/// A classified real surface in room-local coordinates (floor, wall, ceiling, table/seat top).
public struct Surface: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: SurfaceKind
    public var centre: SIMD3<Float>
    public var normal: SIMD3<Float>
    /// Half extents along the surface's two in-plane axes.
    public var halfExtent: SIMD2<Float>
    /// For floor vs table disambiguation of horizontalUp surfaces.
    public var isFloor: Bool

    public init(id: UUID = UUID(), kind: SurfaceKind, centre: SIMD3<Float>, normal: SIMD3<Float>, halfExtent: SIMD2<Float>, isFloor: Bool = false) {
        self.id = id; self.kind = kind; self.centre = centre; self.normal = simd_normalize(normal)
        self.halfExtent = halfExtent; self.isFloor = isFloor
    }

    func distance(from p: SIMD3<Float>) -> Float {
        let o = p - centre
        let along = abs(simd_dot(o, normal))
        let lateral = simd_length(o - normal * simd_dot(o, normal))
        return along + max(0, lateral - max(halfExtent.x, halfExtent.y))
    }
}

/// Item footprint metadata. The base-centre pivot is invariant; the mount point is separate metadata.
public struct ItemGeometry: Sendable, Equatable {
    public var size: SIMD3<Float>
    public var mountPoint: SIMD3<Float>?
    public var isFloorCovering: Bool
    public init(size: SIMD3<Float>, mountPoint: SIMD3<Float>? = nil, isFloorCovering: Bool = false) {
        self.size = size; self.mountPoint = mountPoint; self.isFloorCovering = isFloorCovering
    }
}

public enum Attachment {
    /// Attach a released pivot to the nearest compatible surface. Floor items only use floors; tabletop items prefer
    /// non-floor supports. Returns nil when nothing compatible is within `maxDistance`.
    public static func attach(affinity: Affinity, item: ItemGeometry, released: RigidTransform, surfaces: [Surface],
                              maxDistance: Float = 0.5) -> RigidTransform? {
        guard let policy = AttachmentPolicy.forAffinity(affinity) else { return nil }
        var candidates = surfaces.filter { $0.kind == policy.surface }
        if affinity == .floor { candidates = candidates.filter(\.isFloor) }
        if affinity == .tabletop { candidates = candidates.filter { !$0.isFloor } }
        // Supported items are judged from their base; hung items from their mount point, which is what touches the surface.
        let mount = item.mountPoint ?? (policy.surface == .vertical ? SIMD3(0, item.size.y / 2, item.size.z / 2) : SIMD3(0, item.size.y, 0))
        let p = policy.dropsToSupport ? released.translation : released.apply(mount)
        let chosen: Surface?
        if policy.dropsToSupport {
            // Gravity: fall onto the highest compatible support directly beneath (footprint contains the pivot),
            // from any height; never snap sideways onto a distant support.
            chosen = candidates.filter { s in
                s.centre.y <= p.y + 0.05 && abs(p.x - s.centre.x) <= s.halfExtent.x + 0.05 && abs(p.z - s.centre.z) <= s.halfExtent.y + 0.05
            }.max { $0.centre.y < $1.centre.y }
        } else {
            chosen = candidates.min(by: { $0.distance(from: p) < $1.distance(from: p) }).flatMap { $0.distance(from: p) <= maxDistance ? $0 : nil }
        }
        guard let s = chosen else { return nil }
        switch policy.surface {
        case .horizontalUp:
            // Drop to support, keep the user's yaw; gravity-bound items stay upright.
            let yaw = yawAngle(released.rotation)
            return RigidTransform(translation: SIMD3(p.x, s.centre.y, p.z), yaw: yaw)
        case .horizontalDown:
            // Hang from the ceiling by the mount point; the base-centre pivot sits `mount.y` below the ceiling.
            let rot = simd_quatf(angle: yawAngle(released.rotation), axis: SIMD3(0, 1, 0))
            let mountOnCeiling = SIMD3(p.x, s.centre.y, p.z)
            return RigidTransform(translation: mountOnCeiling - rot.act(mount), rotation: rot)
        case .vertical:
            // Face out of the wall: item front (−Z) along the wall normal means item +Z points into the wall.
            let into = -s.normal
            let yaw = atan2(into.x, into.z)
            let rot = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
            // The mount point lands on the wall plane at the release height; the base-centre pivot follows from it.
            let onWall = p - s.normal * simd_dot(p - s.centre, s.normal)
            return RigidTransform(translation: onWall - rot.act(mount), rotation: rot)
        }
    }

    static func yawAngle(_ q: simd_quatf) -> Float {
        let f = q.act(SIMD3<Float>(0, 0, -1))
        return atan2(-f.x, -f.z)
    }
}

// MARK: Collision classes

/// Oriented box in room-local space, used for real obstacles and virtual placements alike.
public struct OrientedBox: Sendable, Equatable {
    public var pose: RigidTransform
    public var halfSize: SIMD3<Float>
    /// Base-centre pivot box: pivot at the bottom centre.
    public init(basePivot pose: RigidTransform, size: SIMD3<Float>) {
        self.pose = pose * RigidTransform(translation: SIMD3(0, size.y / 2, 0))
        self.halfSize = size / 2
    }
    public init(centrePose: RigidTransform, halfSize: SIMD3<Float>) { self.pose = centrePose; self.halfSize = halfSize }

    private var axes: [SIMD3<Float>] { [pose.rotation.act(SIMD3(1, 0, 0)), pose.rotation.act(SIMD3(0, 1, 0)), pose.rotation.act(SIMD3(0, 0, 1))] }

    /// Separating-axis test. `tolerance` shrinks both boxes so resting contact is not an intersection.
    public func intersects(_ other: OrientedBox, tolerance: Float = 0.005) -> Bool {
        let a = axes, b = other.axes
        let ha = simd_max(halfSize - tolerance, .zero), hb = simd_max(other.halfSize - tolerance, .zero)
        let t = other.pose.translation - pose.translation
        var tests = a + b
        for i in 0..<3 { for j in 0..<3 {
            let c = simd_cross(a[i], b[j]); if simd_length(c) > 1e-5 { tests.append(simd_normalize(c)) }
        } }
        for axis in tests {
            let ra = (0..<3).reduce(Float(0)) { $0 + ha[$1] * abs(simd_dot(a[$1], axis)) }
            let rb = (0..<3).reduce(Float(0)) { $0 + hb[$1] * abs(simd_dot(b[$1], axis)) }
            if abs(simd_dot(t, axis)) > ra + rb { return false }
        }
        return true
    }
}

public struct PlacementCheck: Sendable, Equatable {
    /// Real geometry intersection: the placement cannot be committed here.
    public var blockedByReal: Bool
    /// Virtual overlap: allowed, with a subtle cue (never red, never modal).
    public var overlapsVirtual: Bool
    public var isValid: Bool { !blockedByReal }
    public var showsOverlapCue: Bool { overlapsVirtual }
}

public enum PlacementRules {
    /// Hard real-world collision, soft virtual overlap, rugs/mats exempt from the virtual cue.
    public static func check(item: ItemGeometry, at pose: RigidTransform, real: [OrientedBox], virtual: [(box: OrientedBox, isFloorCovering: Bool)]) -> PlacementCheck {
        let box = OrientedBox(basePivot: pose, size: item.size)
        let blocked = real.contains { box.intersects($0) }
        let overlap = !item.isFloorCovering && virtual.contains { !$0.isFloorCovering && box.intersects($0.box) }
        return PlacementCheck(blockedByReal: blocked, overlapsVirtual: overlap)
    }
}

// MARK: Invalid release

public enum ReleaseOutcome: Sendable, Equatable {
    case valid(RigidTransform)
    case pushedOut(RigidTransform, distance: Float)
    /// Nothing valid within the search limit: keep the unsaved preview where it is, quiet copy only.
    case heldInvalid

    public static let message = "There isn't enough space here"
}

public struct ReleaseResolver: Sendable {
    public var searchLimit: Float = 0.25
    public var step: Float = 0.025
    public init(searchLimit: Float = 0.25, step: Float = 0.025) { self.searchLimit = searchLimit; self.step = step }

    /// Candidates ordered by distance; horizontal first for gravity-bound items. Never beyond `searchLimit`.
    public func resolve(released: RigidTransform, isValid: (RigidTransform) -> Bool) -> ReleaseOutcome {
        if isValid(released) { return .valid(released) }
        let dirs: [SIMD3<Float>] = [SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1),
                                    simd_normalize(SIMD3(1, 0, 1)), simd_normalize(SIMD3(-1, 0, 1)),
                                    simd_normalize(SIMD3(1, 0, -1)), simd_normalize(SIMD3(-1, 0, -1)), SIMD3(0, 1, 0)]
        var d = step
        while d <= searchLimit + 1e-5 {
            for dir in dirs {
                let candidate = RigidTransform(translation: released.translation + dir * d, rotation: released.rotation)
                if isValid(candidate) { return .pushedOut(candidate, distance: d) }
            }
            d += step
        }
        return .heldInvalid
    }
}
