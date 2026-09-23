import Foundation
import simd

/// Room-local frame derived from real geometry: the floor sets up (+Y) and height; a stable wall sets yaw and origin.
/// Placements are stored room-local and never rewritten when the session anchor changes.
public struct RoomFrame: Codable, Sendable, Equatable {
    /// Bumped whenever the derivation rule changes, so persisted frames can be re-derived.
    public static let currentVersion = 1

    public var version: Int
    /// World (session) pose of the room origin at capture time: origin on the floor at the wall's foot, −Z into the wall.
    public var sessionFromRoom: RigidTransform

    public init(version: Int = RoomFrame.currentVersion, sessionFromRoom: RigidTransform) {
        self.version = version
        self.sessionFromRoom = sessionFromRoom
    }

    public enum DerivationError: Error, Equatable {
        case wallNotVertical
        case degenerateWallNormal
    }

    /// Derive from a floor height and a wall point/normal in session coordinates. The wall normal points into the room.
    public static func derive(floorHeight: Float, wallPoint: SIMD3<Float>, wallNormal: SIMD3<Float>) throws -> RoomFrame {
        let horizontal = SIMD3<Float>(wallNormal.x, 0, wallNormal.z)
        guard simd_length(horizontal) > 1e-3 else { throw DerivationError.degenerateWallNormal }
        guard abs(simd_normalize(wallNormal).y) < 0.2 else { throw DerivationError.wallNotVertical }
        let into = simd_normalize(horizontal) // room +Z points out of the wall into the room
        let yaw = atan2(into.x, into.z)
        let origin = SIMD3<Float>(wallPoint.x, floorHeight, wallPoint.z)
        return RoomFrame(sessionFromRoom: RigidTransform(translation: origin, yaw: yaw))
    }

    /// Entity world transform = sessionFromRoom × placementRoomTransform (technical plan §4).
    public func sessionTransform(for roomLocal: RigidTransform) -> RigidTransform { sessionFromRoom * roomLocal }

    /// Inverse: convert an edit made in session space back into room-local space for persistence.
    public func roomLocal(from session: RigidTransform) -> RigidTransform { sessionFromRoom.inverse * session }
}

/// Alignment state after relocalization. Spatial content is withheld until verified.
public enum AlignmentState: Sendable, Equatable {
    case verified(RoomFrame)
    case searching(attempt: Int)
    case exhausted

    public static let maximumGuidedAttempts = 2

    public func afterFailedAttempt() -> AlignmentState {
        switch self {
        case .searching(let attempt) where attempt + 1 < AlignmentState.maximumGuidedAttempts: .searching(attempt: attempt + 1)
        case .searching, .exhausted: .exhausted
        case .verified: .searching(attempt: 0)
        }
    }

    public var showsSpatialContent: Bool { if case .verified = self { true } else { false } }

    /// Plain copy from the plan when alignment cannot be established.
    public var userMessage: String? {
        switch self {
        case .verified: nil
        case .searching: "Looking for this room…"
        case .exhausted: "I can't tell where this room is yet"
        }
    }
}
