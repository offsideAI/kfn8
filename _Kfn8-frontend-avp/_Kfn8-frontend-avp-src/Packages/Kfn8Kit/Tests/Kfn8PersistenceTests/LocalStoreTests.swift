import Foundation
import Kfn8Domain
import SwiftData
import Testing
@testable import Kfn8Persistence

/// File store whose removals or writes can be made to fail, to exercise crash and IO-failure paths.
actor FlakyFileStore: FileStoring {
    let inner: FileStore
    var failRemovals = false
    var failWrites = false
    init(root: URL) throws { inner = try FileStore(root: root) }
    func setFailRemovals(_ v: Bool) { failRemovals = v }
    func setFailWrites(_ v: Bool) { failWrites = v }
    func write(_ data: Data, to relativePath: String) async throws -> (byteCount: Int, sha256: String) {
        if failWrites { throw FileStoreError.writeFailed(relativePath) }
        return try await inner.write(data, to: relativePath)
    }
    func remove(_ relativePath: String) async throws {
        if failRemovals { throw FileStoreError.removeFailed(relativePath) }
        try await inner.remove(relativePath)
    }
    func exists(_ relativePath: String) async -> Bool { await inner.exists(relativePath) }
    func read(_ relativePath: String) async throws -> Data { try await inner.read(relativePath) }
}

struct Fixture {
    let dir: URL
    var storeURL: URL { dir.appendingPathComponent("kfn8.store") }
    var filesURL: URL { dir.appendingPathComponent("files") }
    init() { dir = FileManager.default.temporaryDirectory.appendingPathComponent("kfn8-tests-\(UUID().uuidString)") }
    func open(files: (any FileStoring)? = nil) throws -> LocalStore {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return LocalStore(container: try Kfn8Container.make(url: storeURL), files: try files ?? FileStore(root: filesURL))
    }
}

private func ref() -> AssetReference { AssetReference(assetID: AssetID(), revisionID: RevisionID()) }
private func frame() throws -> RoomFrame { try RoomFrame.derive(floorHeight: -1.5, wallPoint: SIMD3(0, 0, -2), wallNormal: SIMD3(0, 0, 1)) }

@Suite(.serialized) struct LocalStoreTests {
    @Test func createOpenRestartKeepsCommittedState() async throws {
        let fx = Fixture()
        var designID: DesignID
        var placement: Placement
        do {
            let store = try fx.open()
            let space = try await store.createSpace(name: "Home")
            let room = try await store.createRoom(in: space.id, name: "Living room")
            let design = try await store.createDesign(in: room.id, name: "Option A")
            placement = Placement(asset: ref(), transform: RigidTransform(translation: SIMD3(1, 0, 1.5), yaw: 0.3))
            var d = try await store.commit(.add(placement), to: design.id, expectedVersion: 0)
            d = try await store.commit(.move(placement.id, from: placement.transform, to: RigidTransform(translation: SIMD3(1.2, 0, 1.5), yaw: 0.3)),
                                       to: design.id, expectedVersion: d.version)
            #expect(d.version == 2)
            designID = design.id
        }
        // "Terminate and relaunch": a brand-new container on the same file.
        let reopened = try fx.open()
        let d = try await reopened.design(designID)
        #expect(d.version == 2)
        #expect(d.placements.count == 1)
        #expect(d.placements[0].id == placement.id)
        #expect(abs(d.placements[0].transform.translation.x - 1.2) < 1e-6)
        #expect(d.placements[0].transform.rotation.angle > 0.29)
    }

    @Test func schemaBaselineIsVersionOne() {
        #expect(Kfn8SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(Kfn8MigrationPlan.schemas.count == 1)
    }

    @Test func staleVersionAndInvalidEditLeaveCommittedStateUntouched() async throws {
        let store = try Fixture().open()
        let space = try await store.createSpace(name: "Home")
        let room = try await store.createRoom(in: space.id, name: "Room")
        let design = try await store.createDesign(in: room.id, name: "A")
        let p = Placement(asset: ref(), transform: .identity)
        _ = try await store.commit(.add(p), to: design.id, expectedVersion: 0)
        await #expect(throws: PersistenceError.versionConflict(expected: 0, actual: 1)) {
            try await store.commit(.remove(p), to: design.id, expectedVersion: 0)
        }
        await #expect(throws: PersistenceError.edit(.duplicatePlacement(p.id))) {
            try await store.commit(.add(p), to: design.id, expectedVersion: 1)
        }
        let after = try await store.design(design.id)
        #expect(after.version == 1 && after.placements == [p])
    }

    @Test func failedScanWritePreservesPreviousScan() async throws {
        let fx = Fixture()
        let flaky = try FlakyFileStore(root: fx.filesURL)
        let store = try fx.open(files: flaky)
        let space = try await store.createSpace(name: "Home")
        let room = try await store.createRoom(in: space.id, name: "Room")
        let first = try await store.attachScan(Data("scan-1".utf8), frame: try frame(), to: room.id, capturedAt: .now)
        await flaky.setFailWrites(true)
        await #expect(throws: PersistenceError.self) {
            try await store.attachScan(Data("scan-2".utf8), frame: try frame(), to: room.id, capturedAt: .now)
        }
        let rooms = try await store.rooms(in: space.id)
        #expect(rooms[0].scan == first.scan)
        #expect(await flaky.exists(first.scan!.relativePath))
    }

    @Test func rescanReplacesFileAndRemovesOldOne() async throws {
        let fx = Fixture()
        let files = try FileStore(root: fx.filesURL)
        let store = try fx.open(files: files)
        let space = try await store.createSpace(name: "Home")
        let room = try await store.createRoom(in: space.id, name: "Room")
        let a = try await store.attachScan(Data("a".utf8), frame: try frame(), to: room.id, capturedAt: .now)
        let b = try await store.attachScan(Data("bb".utf8), frame: try frame(), to: room.id, capturedAt: .now)
        #expect(b.scan!.byteCount == 2 && b.scan!.sha256.count == 64)
        #expect(!(await files.exists(a.scan!.relativePath)))
        #expect(await files.exists(b.scan!.relativePath))
        #expect(b.frame != nil)
    }

    @Test func countedDeleteRemovesScanAndRecordsButKeepsSharedRevisionReferences() async throws {
        let fx = Fixture()
        let files = try FileStore(root: fx.filesURL)
        let store = try fx.open(files: files)
        let space = try await store.createSpace(name: "Home")
        let doomed = try await store.createRoom(in: space.id, name: "Doomed")
        let kept = try await store.createRoom(in: space.id, name: "Kept")
        let scanned = try await store.attachScan(Data("scan".utf8), frame: try frame(), to: doomed.id, capturedAt: .now)
        let shared = ref()
        for (room, name) in [(doomed.id, "D1"), (doomed.id, "D2"), (kept.id, "K1")] {
            let d = try await store.createDesign(in: room, name: name)
            _ = try await store.commit(.add(Placement(asset: shared, transform: .identity)), to: d.id, expectedVersion: 0)
        }
        let preview = try await store.deletionPreview(room: doomed.id)
        #expect(preview.designs == 2 && preview.scanFiles == 1)
        #expect(preview.confirmationText == "Delete 1 room and 2 designs? This can't be undone.")
        _ = try await store.deleteRoom(doomed.id)
        #expect(!(await files.exists(scanned.scan!.relativePath)))
        #expect(try await store.rooms(in: space.id).map(\.name) == ["Kept"])
        #expect(try await store.revisionReferenceCounts()[shared] == 1, "the surviving design still pins the shared revision")
    }

    @Test func crashBetweenRecordsAndFilesIsFinishedOnRelaunch() async throws {
        let fx = Fixture()
        let flaky = try FlakyFileStore(root: fx.filesURL)
        let store = try fx.open(files: flaky)
        let space = try await store.createSpace(name: "Home")
        let room = try await store.createRoom(in: space.id, name: "Room")
        let scanned = try await store.attachScan(Data("scan".utf8), frame: try frame(), to: room.id, capturedAt: .now)
        await flaky.setFailRemovals(true)
        await #expect(throws: PersistenceError.deletionIncomplete(remainingFiles: 1)) {
            try await store.deleteRoom(room.id)
        }
        #expect(await flaky.exists(scanned.scan!.relativePath), "deletion is not claimed complete while the file remains")
        // Relaunch with a working file store: the journal finishes the job.
        let relaunched = try fx.open()
        #expect(try await relaunched.finishPendingDeletions() == 0)
        #expect(!FileManager.default.fileExists(atPath: fx.filesURL.appendingPathComponent(scanned.scan!.relativePath).path))
    }

    @Test func duplicateIsIndependentAndSharesRevisions() async throws {
        let store = try Fixture().open()
        let space = try await store.createSpace(name: "Home")
        let room = try await store.createRoom(in: space.id, name: "Room")
        let a = try await store.createDesign(in: room.id, name: "A")
        let p = Placement(asset: ref(), transform: .identity)
        _ = try await store.commit(.add(p), to: a.id, expectedVersion: 0)
        let b = try await store.duplicate(a.id, name: "A copy")
        _ = try await store.commit(.remove(b.placements[0]), to: b.id, expectedVersion: 0)
        #expect(try await store.design(a.id).placements.count == 1)
        #expect(try await store.design(b.id).placements.isEmpty)
        let names = try await store.designs(in: room.id).map(\.name)
        #expect(names == ["A", "A copy"])
    }

    @Test func fileStoreRejectsPathEscape() async throws {
        let files = try FileStore(root: Fixture().filesURL)
        await #expect(throws: FileStoreError.invalidPath("../etc/passwd")) { try await files.write(Data(), to: "../etc/passwd") }
        await #expect(throws: FileStoreError.invalidPath("/abs")) { try await files.write(Data(), to: "/abs") }
    }
}
