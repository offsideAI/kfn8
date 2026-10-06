import Foundation
import simd

/// The plane a touch drag moves an item along, in room-local space: the floor or tabletop height for supported items,
/// the ceiling height for hung items, and the wall plane for wall items. A drag never changes the item's support.
public struct DragPlane: Sendable, Equatable {
    public var point: SIMD3<Float>
    public var normal: SIMD3<Float>

    public init(point: SIMD3<Float>, normal: SIMD3<Float>) { self.point = point; self.normal = simd_normalize(normal) }

    /// Wall items face out of their wall, so the wall normal is the item's front (−Z).
    public static func forItem(affinity: Affinity, at pose: RigidTransform) -> DragPlane {
        switch affinity {
        case .wall: DragPlane(point: pose.translation, normal: pose.rotation.act(SIMD3(0, 0, -1)))
        case .floor, .tabletop, .ceiling, .freestandingOutdoor: DragPlane(point: pose.translation, normal: SIMD3(0, 1, 0))
        }
    }

    /// Where a ray (e.g. from the camera through a touch) meets the plane, if it does in front of the ray's origin.
    public func intersect(origin: SIMD3<Float>, direction: SIMD3<Float>) -> SIMD3<Float>? {
        let d = simd_normalize(direction)
        let denom = simd_dot(normal, d)
        guard abs(denom) > 1e-4 else { return nil }
        let t = simd_dot(point - origin, normal) / denom
        guard t > 0 else { return nil }
        return origin + d * t
    }

    /// The pose the drag should preview: the item keeps its rotation and moves to the touched point on its plane.
    public func dragged(_ pose: RigidTransform, toward hit: SIMD3<Float>) -> RigidTransform {
        RigidTransform(translation: hit, rotation: pose.rotation)
    }
}

/// Up to two lighting placements give off light at once (the M4 load is "two active virtual lights").
public enum LightingPlan {
    public static let maximumActiveLights = 2

    /// The lighting placements that emit light, in Design order, capped at the maximum.
    public static func activeLights(in design: Design, isLighting: (AssetReference) -> Bool) -> [PlacementID] {
        Array(design.placements.filter { isLighting($0.asset) }.prefix(maximumActiveLights).map(\.id))
    }

    /// Where the light sits in the item's own base-centre coordinates: just under a ceiling shade, and at the middle of
    /// a wall fitting, slightly out from the wall.
    public static func lightOffset(affinity: Affinity, size: SIMD3<Float>) -> SIMD3<Float> {
        switch affinity {
        case .ceiling: SIMD3(0, size.y * 0.1, 0)
        case .wall: SIMD3(0, size.y / 2, -size.z / 2)
        case .floor, .tabletop, .freestandingOutdoor: SIMD3(0, size.y * 0.9, 0)
        }
    }
}

/// Clearance readings for one placed item against the real obstacles that have been scanned. Gaps, never verdicts.
public enum ClearanceSummary {
    public static func readings(item: OrientedBox, obstacles: [OrientedBox]) -> [ClearanceReading] {
        ClearanceSide.allCases.map { side in
            let gaps = obstacles.compactMap { Clearance.gap(item: item, obstacle: $0, side: side) }
            // The nearest obstacle on that side is the gap people care about.
            return Clearance.reading(side: side, samples: gaps.min().map { [$0] } ?? [])
        }
    }
}

/// Room photo export: a picture of someone's home is only taken after they agree to it, and only kept on the device
/// or shared by them. No watermark, no upload.
public struct PhotoExportFlow: Sendable, Equatable {
    public enum Step: Sendable, Equatable {
        case idle
        case askingConsent
        case capturing
        case captured(bytes: Int)
        case saved
        case photosDenied
        case failed(String)
    }

    public private(set) var step: Step = .idle

    public init() {}

    public mutating func requestPhoto() { if step != .capturing { step = .askingConsent } }
    public mutating func declineConsent() { if step == .askingConsent { step = .idle } }

    /// Returns true only when the person has just agreed; the caller then captures.
    public mutating func giveConsent() -> Bool {
        guard step == .askingConsent else { return false }
        step = .capturing
        return true
    }

    public mutating func captured(bytes: Int) { if step == .capturing { step = .captured(bytes: bytes) } }
    public mutating func captureFailed(_ reason: String) { if step == .capturing { step = .failed(reason) } }

    public mutating func savedToPhotos(_ saved: Bool) {
        guard case .captured = step else { return }
        step = saved ? .saved : .photosDenied
    }

    public mutating func writeFailed(_ reason: String) {
        guard case .captured = step else { return }
        step = .failed(reason)
    }

    public mutating func finish() { step = .idle }

    public var message: String? {
        switch step {
        case .idle, .askingConsent, .capturing: nil
        case .captured: "Photo taken. Save it to Photos or share it."
        case .saved: "Saved to Photos."
        case .photosDenied: "Photos access wasn't allowed, so the photo wasn't saved. You can still share it."
        case .failed(let reason): "The photo couldn't be taken: \(reason)"
        }
    }
}
