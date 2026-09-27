import CryptoKit
import Foundation
import Kfn8Domain
import SwiftData
import simd

/// Repository surface used by the app. Only Sendable domain values cross this boundary.
public protocol DesignRepository: Sendable {
    func createSpace(name: String) async throws -> Space
    func spaces() async throws -> [Space]
    func createRoom(in space: SpaceID, name: String) async throws -> Room
    func rooms(in space: SpaceID) async throws -> [Room]
    func attachScan(_ data: Data, frame: RoomFrame, to room: RoomID, capturedAt: Date, sessionAnchorID: UUID?) async throws -> Room
    /// The room's current scan file, checked against its recorded SHA-256; nil when the room has never been scanned.
    func scanData(for room: RoomID) async throws -> Data?
    func updateFrame(_ frame: RoomFrame, for room: RoomID) async throws -> Room
    func createDesign(in room: RoomID, name: String) async throws -> Design
    func designs(in room: RoomID) async throws -> [Design]
    func design(_ id: DesignID) async throws -> Design
    func commit(_ edit: DesignEdit, to design: DesignID, expectedVersion: Int) async throws -> Design
    func duplicate(_ design: DesignID, name: String) async throws -> Design
    func deletionPreview(room: RoomID) async throws -> DeletionPreview
    func deleteRoom(_ room: RoomID) async throws -> DeletionPreview
    func deleteDesign(_ design: DesignID) async throws
    func finishPendingDeletions() async throws -> Int
    func revisionReferenceCounts() async throws -> [AssetReference: Int]
}

public struct DeletionPreview: Sendable, Equatable {
    public var rooms: Int
    public var designs: Int
    public var placements: Int
    public var scanFiles: Int
    /// Counted, irreversible confirmation copy. No trash, no archive.
    public var confirmationText: String {
        let r = rooms == 1 ? "1 room" : "\(rooms) rooms"
        let d = designs == 1 ? "1 design" : "\(designs) designs"
        return "Delete \(r) and \(d)? This can't be undone."
    }
}

public enum PersistenceError: Error, Equatable, Sendable {
    case notFound(String)
    case versionConflict(expected: Int, actual: Int)
    case edit(EditError)
    case saveFailed(String)
    case scanWriteFailed(String)
    case scanUnreadable(String)
    case deletionIncomplete(remainingFiles: Int)
}

public actor LocalStore: ModelActor, DesignRepository {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer
    private let files: any FileStoring

    public init(container: ModelContainer, files: any FileStoring) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        modelContainer = container
        self.files = files
    }

    // MARK: Spaces and rooms

    public func createSpace(name: String) throws -> Space {
        let space = Space(name: name)
        modelContext.insert(SpaceRecord(id: space.id.rawValue, name: name))
        try save()
        return space
    }

    public func spaces() throws -> [Space] {
        try modelContext.fetch(FetchDescriptor<SpaceRecord>(sortBy: [SortDescriptor(\.name)]))
            .map { Space(id: SpaceID(rawValue: $0.id), name: $0.name) }
    }

    public func createRoom(in space: SpaceID, name: String) throws -> Room {
        let spaceRecord = try fetchSpace(space)
        let room = Room(spaceID: space, name: name)
        let record = RoomRecord(id: room.id.rawValue, name: name, kind: room.kind.rawValue)
        modelContext.insert(record)
        record.space = spaceRecord
        try save()
        return room
    }

    public func rooms(in space: SpaceID) throws -> [Room] {
        try fetchSpace(space).rooms.sorted { $0.name < $1.name }.map(Self.room)
    }

    /// File first (atomic), then records. If the record save fails the new file is removed, so no orphan remains
    /// and the previously committed scan is untouched.
    public func attachScan(_ data: Data, frame: RoomFrame, to room: RoomID, capturedAt: Date, sessionAnchorID: UUID? = nil) async throws -> Room {
        let record = try fetchRoom(room)
        let path = "scans/\(room.rawValue.uuidString)/\(UUID().uuidString).scan"
        let written: (byteCount: Int, sha256: String)
        do { written = try await files.write(data, to: path) } catch { throw PersistenceError.scanWriteFailed("\(error)") }
        let previous = record.scanRelativePath
        record.scanRelativePath = path
        record.scanByteCount = written.byteCount
        record.scanSHA256 = written.sha256
        record.scanCapturedAt = capturedAt
        record.scanFrameVersion = frame.version
        record.frameData = try JSONEncoder().encode(frame)
        record.sessionAnchorID = sessionAnchorID
        if let previous { modelContext.insert(DeletionJournalRecord(id: UUID(), relativePaths: [previous])) }
        do { try save() } catch {
            try? await files.remove(path)
            throw error
        }
        _ = try? await finishPendingDeletions()
        return Self.room(record)
    }

    public func scanData(for room: RoomID) async throws -> Data? {
        let record = try fetchRoom(room)
        guard let path = record.scanRelativePath else { return nil }
        let data: Data
        do { data = try await files.read(path) } catch { throw PersistenceError.scanUnreadable("\(path): \(error.localizedDescription)") }
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard sha == record.scanSHA256 else { throw PersistenceError.scanUnreadable("\(path): checksum mismatch") }
        return data
    }

    public func updateFrame(_ frame: RoomFrame, for room: RoomID) throws -> Room {
        let record = try fetchRoom(room)
        record.frameData = try JSONEncoder().encode(frame)
        record.scanFrameVersion = frame.version
        try save()
        return Self.room(record)
    }

    // MARK: Designs

    public func createDesign(in room: RoomID, name: String) throws -> Design {
        let roomRecord = try fetchRoom(room)
        let design = Design(roomID: room, name: name)
        let record = DesignRecord(id: design.id.rawValue, name: name, version: 0)
        modelContext.insert(record)
        record.room = roomRecord
        try save()
        return design
    }

    public func designs(in room: RoomID) throws -> [Design] {
        try fetchRoom(room).designs.sorted { $0.name < $1.name }.map { Self.design($0, roomID: room) }
    }

    public func design(_ id: DesignID) throws -> Design {
        let r = try fetchDesign(id)
        return Self.design(r, roomID: RoomID(rawValue: r.room?.id ?? UUID()))
    }

    /// Atomic completed-edit commit. Validates against the committed snapshot and the expected version, writes the
    /// whole new state, and saves once. Any failure rolls back and leaves the committed state exactly as it was.
    public func commit(_ edit: DesignEdit, to id: DesignID, expectedVersion: Int) throws -> Design {
        let record = try fetchDesign(id)
        guard record.version == expectedVersion else {
            throw PersistenceError.versionConflict(expected: expectedVersion, actual: record.version)
        }
        let current = Self.design(record, roomID: RoomID(rawValue: record.room?.id ?? UUID()))
        let next: Design
        do { next = try current.applying(edit) } catch { throw PersistenceError.edit(error) }
        write(next, into: record)
        try save()
        return next
    }

    public func duplicate(_ id: DesignID, name: String) throws -> Design {
        let source = try design(id)
        let copy = source.duplicated(name: name)
        let record = DesignRecord(id: copy.id.rawValue, name: copy.name, version: 0)
        modelContext.insert(record)
        record.room = try fetchRoom(source.roomID)
        write(copy, into: record)
        try save()
        return copy
    }

    // MARK: Deletion

    public func deletionPreview(room: RoomID) throws -> DeletionPreview {
        let r = try fetchRoom(room)
        return DeletionPreview(rooms: 1, designs: r.designs.count, placements: r.designs.reduce(0) { $0 + $1.placements.count },
                               scanFiles: r.scanRelativePath == nil ? 0 : 1)
    }

    /// Records and journal entry in one save; then files; then the journal is cleared. A crash anywhere after the
    /// save is finished by `finishPendingDeletions()` on next launch. Never claims completion while files remain.
    public func deleteRoom(_ room: RoomID) async throws -> DeletionPreview {
        let preview = try deletionPreview(room: room)
        let record = try fetchRoom(room)
        let paths = [record.scanRelativePath].compactMap { $0 }
        if !paths.isEmpty { modelContext.insert(DeletionJournalRecord(id: UUID(), relativePaths: paths)) }
        modelContext.delete(record)
        try save()
        let remaining = try await finishPendingDeletions()
        if remaining > 0 { throw PersistenceError.deletionIncomplete(remainingFiles: remaining) }
        return preview
    }

    public func deleteDesign(_ id: DesignID) throws {
        modelContext.delete(try fetchDesign(id))
        try save()
    }

    /// Returns the number of files still pending (0 when every journal entry was completed).
    public func finishPendingDeletions() async throws -> Int {
        var remaining = 0
        for entry in try modelContext.fetch(FetchDescriptor<DeletionJournalRecord>()) {
            var left: [String] = []
            for path in entry.relativePaths {
                do { try await files.remove(path) } catch { left.append(path) }
            }
            if left.isEmpty { modelContext.delete(entry) } else { entry.relativePaths = left; remaining += left.count }
        }
        try save()
        return remaining
    }

    public func revisionReferenceCounts() throws -> [AssetReference: Int] {
        var counts: [AssetReference: Int] = [:]
        for p in try modelContext.fetch(FetchDescriptor<PlacementRecord>()) {
            counts[AssetReference(assetID: AssetID(rawValue: p.assetID), revisionID: RevisionID(rawValue: p.revisionID), variantID: p.variantID), default: 0] += 1
        }
        return counts
    }

    // MARK: Mapping

    private func write(_ design: Design, into record: DesignRecord) {
        record.name = design.name
        record.version = design.version
        record.updatedAt = .now
        let wanted = Set(design.placements.map(\.id.rawValue))
        for p in record.placements where !wanted.contains(p.id) { modelContext.delete(p) }
        let existing = Dictionary(uniqueKeysWithValues: record.placements.filter { wanted.contains($0.id) }.map { ($0.id, $0) })
        for (i, p) in design.placements.enumerated() {
            let r = existing[p.id.rawValue] ?? {
                let n = PlacementRecord(id: p.id.rawValue, assetID: p.asset.assetID.rawValue, revisionID: p.asset.revisionID.rawValue,
                                        variantID: p.asset.variantID, ordinal: i)
                modelContext.insert(n)
                n.design = record
                return n
            }()
            r.assetID = p.asset.assetID.rawValue
            r.revisionID = p.asset.revisionID.rawValue
            r.variantID = p.asset.variantID
            r.ordinal = i
            r.tx = p.transform.translation.x; r.ty = p.transform.translation.y; r.tz = p.transform.translation.z
            let q = p.transform.rotation.vector
            r.qx = q.x; r.qy = q.y; r.qz = q.z; r.qw = q.w
        }
    }

    private static func design(_ r: DesignRecord, roomID: RoomID) -> Design {
        let placements = r.placements.sorted { $0.ordinal < $1.ordinal }.map { p in
            Placement(id: PlacementID(rawValue: p.id),
                      asset: AssetReference(assetID: AssetID(rawValue: p.assetID), revisionID: RevisionID(rawValue: p.revisionID), variantID: p.variantID),
                      transform: RigidTransform(translation: SIMD3(p.tx, p.ty, p.tz), rotation: simd_quatf(vector: SIMD4(p.qx, p.qy, p.qz, p.qw))))
        }
        return Design(id: DesignID(rawValue: r.id), roomID: roomID, name: r.name, version: r.version, placements: placements)
    }

    private static func room(_ r: RoomRecord) -> Room {
        var scan: ScanFileReference?
        if let path = r.scanRelativePath, let bytes = r.scanByteCount, let sha = r.scanSHA256, let at = r.scanCapturedAt {
            scan = ScanFileReference(relativePath: path, byteCount: bytes, sha256: sha, capturedAt: at, roomFrameVersion: r.scanFrameVersion ?? 0)
        }
        let frame = r.frameData.flatMap { try? JSONDecoder().decode(RoomFrame.self, from: $0) }
        return Room(id: RoomID(rawValue: r.id), spaceID: SpaceID(rawValue: r.space?.id ?? UUID()), name: r.name,
                    kind: RoomKind(rawValue: r.kind) ?? .live, scan: scan, frame: frame, sessionAnchorID: r.sessionAnchorID)
    }

    private func save() throws {
        do { try modelContext.save() } catch {
            modelContext.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }

    private func fetchSpace(_ id: SpaceID) throws -> SpaceRecord {
        let raw = id.rawValue
        guard let r = try modelContext.fetch(FetchDescriptor<SpaceRecord>(predicate: #Predicate { $0.id == raw })).first else { throw PersistenceError.notFound("space \(id)") }
        return r
    }

    private func fetchRoom(_ id: RoomID) throws -> RoomRecord {
        let raw = id.rawValue
        guard let r = try modelContext.fetch(FetchDescriptor<RoomRecord>(predicate: #Predicate { $0.id == raw })).first else { throw PersistenceError.notFound("room \(id)") }
        return r
    }

    private func fetchDesign(_ id: DesignID) throws -> DesignRecord {
        let raw = id.rawValue
        guard let r = try modelContext.fetch(FetchDescriptor<DesignRecord>(predicate: #Predicate { $0.id == raw })).first else { throw PersistenceError.notFound("design \(id)") }
        return r
    }
}
