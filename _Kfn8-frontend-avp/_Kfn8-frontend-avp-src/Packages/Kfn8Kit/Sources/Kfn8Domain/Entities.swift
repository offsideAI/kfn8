import Foundation

public enum RoomKind: String, Codable, Sendable, CaseIterable {
    case live
    /// Schema-only in MVP1 (D3). No offsite implementation exists.
    case offsite
}

public enum Affinity: String, Codable, Sendable, CaseIterable {
    case floor, wall, ceiling, tabletop
    /// Schema-only in MVP1 (D3): catalogued, never placeable.
    case freestandingOutdoor = "freestanding-outdoor"

    public var isPlaceableInMVP1: Bool { self != .freestandingOutdoor }
}

public struct Space: Codable, Sendable, Equatable, Identifiable {
    public var id: SpaceID
    public var name: String
    public init(id: SpaceID = SpaceID(), name: String) { self.id = id; self.name = name }
}

public struct ScanFileReference: Codable, Sendable, Equatable {
    /// Relative to the app's scan directory, never absolute.
    public var relativePath: String
    public var byteCount: Int
    public var sha256: String
    public var capturedAt: Date
    public var roomFrameVersion: Int
    public init(relativePath: String, byteCount: Int, sha256: String, capturedAt: Date, roomFrameVersion: Int) {
        self.relativePath = relativePath; self.byteCount = byteCount; self.sha256 = sha256
        self.capturedAt = capturedAt; self.roomFrameVersion = roomFrameVersion
    }
}

public struct Room: Codable, Sendable, Equatable, Identifiable {
    public var id: RoomID
    public var spaceID: SpaceID
    public var name: String
    public var kind: RoomKind
    public var scan: ScanFileReference?
    public var frame: RoomFrame?
    /// Session world-anchor identifier used for relocalization. Separate from the frame definition; replacing the
    /// anchor never rewrites room-local placements.
    public var sessionAnchorID: UUID?
    public init(id: RoomID = RoomID(), spaceID: SpaceID, name: String, kind: RoomKind = .live, scan: ScanFileReference? = nil,
                frame: RoomFrame? = nil, sessionAnchorID: UUID? = nil) {
        self.id = id; self.spaceID = spaceID; self.name = name; self.kind = kind; self.scan = scan; self.frame = frame
        self.sessionAnchorID = sessionAnchorID
    }
}

/// Immutable reference to exactly one published asset revision.
public struct AssetReference: Codable, Sendable, Hashable {
    public var assetID: AssetID
    public var revisionID: RevisionID
    public var variantID: String?
    public init(assetID: AssetID, revisionID: RevisionID, variantID: String? = nil) {
        self.assetID = assetID; self.revisionID = revisionID; self.variantID = variantID
    }
}

public struct Placement: Codable, Sendable, Equatable, Identifiable {
    public var id: PlacementID
    public var asset: AssetReference
    /// Room-local rigid transform; scale is always one.
    public var transform: RigidTransform
    public init(id: PlacementID = PlacementID(), asset: AssetReference, transform: RigidTransform) {
        self.id = id; self.asset = asset; self.transform = transform
    }
}

public struct Design: Codable, Sendable, Equatable, Identifiable {
    public var id: DesignID
    public var roomID: RoomID
    public var name: String
    /// Monotonic local committed-edit counter. Not a revision history.
    public var version: Int
    public var placements: [Placement]
    public init(id: DesignID = DesignID(), roomID: RoomID, name: String, version: Int = 0, placements: [Placement] = []) {
        self.id = id; self.roomID = roomID; self.name = name; self.version = version; self.placements = placements
    }

    public func placement(_ id: PlacementID) -> Placement? { placements.first { $0.id == id } }

    /// Cheap duplication: new Design and Placement IDs, the same immutable asset references, version reset.
    public func duplicated(name: String) -> Design {
        Design(roomID: roomID, name: name, version: 0,
               placements: placements.map { Placement(asset: $0.asset, transform: $0.transform) })
    }

    public var referencedRevisions: Set<AssetReference> { Set(placements.map(\.asset)) }
}
