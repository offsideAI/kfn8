import Foundation
import SwiftData

/// Versioned SwiftData schema. @Model types never leave the persistence actor; callers get Kfn8Domain values.
/// No CloudKit: the container is configured with `cloudKitDatabase: .none`.
public enum Kfn8SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [SpaceRecord.self, RoomRecord.self, DesignRecord.self, PlacementRecord.self, DeletionJournalRecord.self]
    }

    @Model public final class SpaceRecord {
        @Attribute(.unique) public var id: UUID
        public var name: String
        @Relationship(deleteRule: .cascade, inverse: \RoomRecord.space) public var rooms: [RoomRecord] = []
        public init(id: UUID, name: String) { self.id = id; self.name = name }
    }

    @Model public final class RoomRecord {
        @Attribute(.unique) public var id: UUID
        public var name: String
        public var kind: String
        public var space: SpaceRecord?
        public var scanRelativePath: String?
        public var scanByteCount: Int?
        public var scanSHA256: String?
        public var scanCapturedAt: Date?
        public var scanFrameVersion: Int?
        public var frameData: Data?
        public var sessionAnchorID: UUID?
        @Relationship(deleteRule: .cascade, inverse: \DesignRecord.room) public var designs: [DesignRecord] = []
        public init(id: UUID, name: String, kind: String) { self.id = id; self.name = name; self.kind = kind }
    }

    @Model public final class DesignRecord {
        @Attribute(.unique) public var id: UUID
        public var name: String
        public var version: Int
        public var updatedAt: Date
        public var room: RoomRecord?
        @Relationship(deleteRule: .cascade, inverse: \PlacementRecord.design) public var placements: [PlacementRecord] = []
        public init(id: UUID, name: String, version: Int) { self.id = id; self.name = name; self.version = version; self.updatedAt = .now }
    }

    @Model public final class PlacementRecord {
        @Attribute(.unique) public var id: UUID
        public var assetID: UUID
        public var revisionID: UUID
        public var variantID: String?
        public var tx: Float
        public var ty: Float
        public var tz: Float
        public var qx: Float
        public var qy: Float
        public var qz: Float
        public var qw: Float
        public var ordinal: Int
        public var design: DesignRecord?
        public init(id: UUID, assetID: UUID, revisionID: UUID, variantID: String?, ordinal: Int) {
            self.id = id; self.assetID = assetID; self.revisionID = revisionID; self.variantID = variantID; self.ordinal = ordinal
            tx = 0; ty = 0; tz = 0; qx = 0; qy = 0; qz = 0; qw = 1
        }
    }

    /// Idempotent deletion journal: written in the same save that removes records, cleared after files are gone.
    @Model public final class DeletionJournalRecord {
        @Attribute(.unique) public var id: UUID
        public var relativePaths: [String]
        public var createdAt: Date
        public init(id: UUID, relativePaths: [String]) { self.id = id; self.relativePaths = relativePaths; self.createdAt = .now }
    }
}

public enum Kfn8MigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [Kfn8SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public typealias SpaceRecord = Kfn8SchemaV1.SpaceRecord
public typealias RoomRecord = Kfn8SchemaV1.RoomRecord
public typealias DesignRecord = Kfn8SchemaV1.DesignRecord
public typealias PlacementRecord = Kfn8SchemaV1.PlacementRecord
public typealias DeletionJournalRecord = Kfn8SchemaV1.DeletionJournalRecord

public enum Kfn8Container {
    /// On-disk store at `url`, or in-memory when nil. Never CloudKit.
    public static func make(url: URL?) throws -> ModelContainer {
        let schema = Schema(versionedSchema: Kfn8SchemaV1.self)
        let config = url.map { ModelConfiguration(schema: schema, url: $0, cloudKitDatabase: .none) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: Kfn8MigrationPlan.self, configurations: [config])
    }
}
