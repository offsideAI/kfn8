import Foundation
import simd

/// The four MVP1 indoor affinities exercised by the manipulation probe. `freestandingOutdoor` is schema-only
/// in MVP1 and deliberately absent here.
public enum AttachmentAffinity: String, CaseIterable, Codable, Sendable {
    case floor
    case wall
    case ceiling
    case tabletop

    /// Floor and tabletop items rest on a support and keep gravity; wall and ceiling items orient to the surface
    /// normal and suppress gravity. One policy, parameterised by affinity.
    public var policy: AttachmentPolicy {
        switch self {
        case .floor: AttachmentPolicy(surface: .horizontalUp, snapsToSupport: true, suppressesGravity: false, expectedSurfaceNormalY: 1)
        case .tabletop: AttachmentPolicy(surface: .horizontalUp, snapsToSupport: true, suppressesGravity: false, expectedSurfaceNormalY: 1)
        case .wall: AttachmentPolicy(surface: .vertical, snapsToSupport: false, suppressesGravity: true, expectedSurfaceNormalY: 0)
        case .ceiling: AttachmentPolicy(surface: .horizontalDown, snapsToSupport: false, suppressesGravity: true, expectedSurfaceNormalY: -1)
        }
    }
}

public struct AttachmentPolicy: Sendable, Equatable {
    public enum SurfaceKind: Sendable, Equatable { case horizontalUp, horizontalDown, vertical }
    public var surface: SurfaceKind
    public var snapsToSupport: Bool
    public var suppressesGravity: Bool
    public var expectedSurfaceNormalY: Float
}

/// A detected real surface, in room/session coordinates. Populated by ARKit plane anchors in the app.
public struct DetectedSurface: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: AttachmentPolicy.SurfaceKind
    public var center: SIMD3<Float>
    public var normal: SIMD3<Float>
    public var extent: SIMD2<Float>

    public init(id: UUID = UUID(), kind: AttachmentPolicy.SurfaceKind, center: SIMD3<Float>, normal: SIMD3<Float>, extent: SIMD2<Float>) {
        self.id = id
        self.kind = kind
        self.center = center
        self.normal = simd_normalize(normal)
        self.extent = extent
    }
}

/// The result of applying an affinity to a released position: where the base-centre pivot goes and which way
/// the item faces. The mount point stays a separate concept; base-centre pivot is invariant.
public struct AttachedPose: Sendable, Equatable {
    public var position: SIMD3<Float>
    public var orientation: simd_quatf
    public var surfaceID: UUID?
}

public enum AttachmentResolver {
    /// Chooses the nearest compatible surface and computes the attached pose.
    /// Returns nil when no compatible surface is within `maxDistance` metres, which the caller treats as an invalid release.
    public static func resolve(affinity: AttachmentAffinity,
                               releasedPosition: SIMD3<Float>,
                               releasedYaw: Float,
                               surfaces: [DetectedSurface],
                               maxDistance: Float = 0.5) -> AttachedPose? {
        let policy = affinity.policy
        let candidates = surfaces.filter { $0.kind == policy.surface }
        guard let nearest = candidates.min(by: { distance(to: $0, from: releasedPosition) < distance(to: $1, from: releasedPosition) }),
              distance(to: nearest, from: releasedPosition) <= maxDistance else { return nil }

        switch policy.surface {
        case .horizontalUp, .horizontalDown:
            // Keep XZ, land the base-centre pivot on the plane height, keep the user's yaw.
            let position = SIMD3<Float>(releasedPosition.x, nearest.center.y, releasedPosition.z)
            let orientation = simd_quatf(angle: releasedYaw, axis: SIMD3<Float>(0, 1, 0))
            return AttachedPose(position: position, orientation: orientation, surfaceID: nearest.id)
        case .vertical:
            // Project onto the wall plane and face the item's front (-Z) along the wall normal (out into the room).
            let offset = releasedPosition - nearest.center
            let depth = simd_dot(offset, nearest.normal)
            let position = releasedPosition - nearest.normal * depth
            let orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: nearest.normal)
            return AttachedPose(position: position, orientation: orientation, surfaceID: nearest.id)
        }
    }

    /// Signed-plane distance for vertical surfaces, vertical gap for horizontal ones, both clamped to the surface extent.
    public static func distance(to surface: DetectedSurface, from point: SIMD3<Float>) -> Float {
        let offset = point - surface.center
        let alongNormal = abs(simd_dot(offset, surface.normal))
        // Lateral overshoot beyond the extent adds to the distance so far-away planes are not chosen.
        let lateral = offset - surface.normal * simd_dot(offset, surface.normal)
        let halfExtent = max(surface.extent.x, surface.extent.y) / 2
        let overshoot = max(0, simd_length(lateral) - halfExtent)
        return alongNormal + overshoot
    }
}
