import Foundation
import Kfn8Catalogue
import Kfn8Domain
import Kfn8Persistence
import Observation
import os
import simd

/// Local diagnostics only (unified log on the device). No collection endpoint, no analytics SDK.
let placementLog = Logger(subsystem: "com.appliaison.kfn8", category: "placement")

/// Main-actor owner of navigation, selection, undo and the placement pipeline. Persistence runs on its own actor and
/// only Sendable domain values cross; RealityKit entities are a projection of `currentDesign` + transient previews.
@MainActor
@Observable
final class AppModel {
    // Persistence and catalogue
    let repository: any DesignRepository
    let bundledCatalogue: [CatalogueItem]
    let isSimulatedRoom: Bool
    let remote: RemoteCatalogue
    /// Bundled items plus remote items already downloaded into the pinned cache.
    var catalogue: [CatalogueItem] { bundledCatalogue + remote.downloaded.filter { !remote.isRevoked($0.reference) } }

    // Navigation
    var spaces: [Space] = []
    var rooms: [Room] = []
    var designs: [Design] = []
    var currentSpaceID: SpaceID?
    var currentRoom: Room?
    var currentDesign: Design?

    // Spatial state
    var alignment: AlignmentState = .searching(attempt: 0)
    var surfaces: [Surface] = []
    /// Room-local real-geometry test supplied by the immersive scene (mesh collision). Nil means no mesh yet.
    @ObservationIgnored var realGeometryIntersects: ((OrientedBox) -> Bool)?
    var isImmersiveOpen = false
    /// Bumped to restart room tracking (e.g. rescan into the same Room).
    var sessionGeneration = 0
    /// Supplied by the immersive scene: room-local pose in front of the user, facing them, for new placements.
    @ObservationIgnored var poseInFront: (() -> RigidTransform)?

    // Editing
    var selection: PlacementID?
    var undoHistory = UndoHistory()
    /// Live, unsaved transforms: during a drag and for releases that could not be resolved (held invalid).
    var previewTransforms: [PlacementID: RigidTransform] = [:]
    var heldInvalid: Set<PlacementID> = []
    var overlapCues: Set<PlacementID> = []
    var statusMessage: String?
    var errorMessage: String?

    // A/B flip: the shown composition only changes once the next Design is ready.
    var switcher: DesignSwitcher?
    /// Designs the immersive view is preloading for a flip.
    var preparingDesign: Design?

    init(repository: any DesignRepository, catalogue: [CatalogueItem], isSimulatedRoom: Bool, remote: RemoteCatalogue) {
        self.repository = repository
        self.bundledCatalogue = catalogue
        self.isSimulatedRoom = isSimulatedRoom
        self.remote = remote
    }

    /// Launch/foreground opportunity for remote catalogue and revocation checks (no heartbeat).
    func refreshRemote(force: Bool = false) async {
        let pins = (try? await repository.revisionReferenceCounts()).map { Set($0.keys) } ?? []
        await remote.refresh(pinned: pins, force: force)
    }

    func downloadRemote(_ summary: AssetSummary) async {
        do { _ = try await remote.download(summary) } catch { errorMessage = "Couldn't download \(summary.name): \(error)" }
    }

    func item(for reference: AssetReference) -> CatalogueItem? { catalogue.first { $0.reference.assetID == reference.assetID } }

    // MARK: Lifecycle

    func bootstrap() async {
        await perform {
            let pending = try await repository.finishPendingDeletions()
            if pending > 0 { errorMessage = "\(pending) file(s) from an earlier deletion could not be removed yet." }
            spaces = try await repository.spaces()
            if let first = spaces.first { try await selectSpace(first.id) }
        }
    }

    /// Runs an async persistence operation and surfaces any failure; nothing is swallowed.
    func perform(_ work: () async throws -> Void) async {
        do { try await work() } catch {
            errorMessage = Self.describe(error)
        }
    }

    static func describe(_ error: any Error) -> String {
        switch error {
        case PersistenceError.versionConflict: "This design changed elsewhere. Your last edit was not saved."
        case PersistenceError.saveFailed(let why): "Couldn't save: \(why)"
        case PersistenceError.scanUnreadable: "This room's scan couldn't be read. Rescan the room to place things again."
        case PersistenceError.deletionIncomplete(let n): "Deleted, but \(n) file(s) are still being removed."
        case PersistenceError.scanWriteFailed: "Couldn't store the room scan. Your previous scan is unchanged."
        default: "Something went wrong: \(error)"
        }
    }

    // MARK: Spaces, rooms, designs

    func createSpace(named name: String) async {
        await perform {
            let space = try await repository.createSpace(name: name)
            spaces = try await repository.spaces()
            try await selectSpace(space.id)
        }
    }

    func selectSpace(_ id: SpaceID) async throws {
        currentSpaceID = id
        rooms = try await repository.rooms(in: id)
        if let room = rooms.first { try await selectRoom(room) } else { currentRoom = nil; designs = []; currentDesign = nil }
    }

    func createRoom(named name: String) async {
        guard let space = currentSpaceID else { return }
        await perform {
            let room = try await repository.createRoom(in: space, name: name)
            rooms = try await repository.rooms(in: space)
            try await selectRoom(room)
        }
    }

    func selectRoom(_ room: Room) async throws {
        currentRoom = room
        alignment = .searching(attempt: 0)
        surfaces = []
        designs = try await repository.designs(in: room.id)
        if designs.isEmpty { designs = [try await repository.createDesign(in: room.id, name: "Design A")] }
        selectDesign(designs[0])
    }

    func selectDesign(_ design: Design) {
        switcher = DesignSwitcher(showing: design.id)
        preparingDesign = nil
        currentDesign = design
        undoHistory = UndoHistory()
        selection = nil
        previewTransforms = [:]
        heldInvalid = []
        recomputeOverlapCues()
    }

    /// The Design an A/B flip goes to: the most recently used other Design in this room.
    var flipTarget: Design? { designs.first { $0.id != currentDesign?.id } }

    /// Request an A/B flip. Outside the room view there is nothing to preload, so it switches immediately.
    func requestFlip() {
        guard let target = flipTarget else { return }
        guard isImmersiveOpen, alignment.showsSpatialContent else { selectDesignKeepingSwitcher(target); return }
        switcher?.request(target.id)
        preparingDesign = target
        statusMessage = "Loading \(target.name)…"
    }

    /// Called by the room view once every model of the pending Design is loaded.
    func flipResourcesReady(_ id: DesignID) {
        guard let target = designs.first(where: { $0.id == id }) else { return }
        switcher?.resourcesReady(id)
        if switcher?.shown == id { selectDesignKeepingSwitcher(target) }
    }

    func flipResourcesFailed(_ id: DesignID, reason: String) {
        switcher?.resourcesFailed(id)
        preparingDesign = nil
        statusMessage = nil
        errorMessage = "Couldn't switch designs: \(reason). Still showing \(currentDesign?.name ?? "the current design")."
    }

    private func selectDesignKeepingSwitcher(_ design: Design) {
        let s = switcher
        selectDesign(design)
        if var s { s.request(design.id); s.resourcesReady(design.id); switcher = s }
        statusMessage = nil
    }

    /// Generic-first inventory for the current Design. Bundled generics carry no offers, so no subtotal appears.
    var inventoryLines: [InventoryLine] {
        guard let d = currentDesign else { return [] }
        return Inventory.lines(for: d) { ref in
            self.catalogue.first { $0.reference.assetID == ref.assetID }.map { InventorySource(name: $0.name, sizeMetres: $0.geometry.size) }
        }
    }

    func duplicateCurrentDesign() async {
        guard let d = currentDesign, let room = currentRoom else { return }
        await perform {
            let copy = try await repository.duplicate(d.id, name: "\(d.name) copy")
            designs = try await repository.designs(in: room.id)
            selectDesign(copy)
        }
    }

    // MARK: Capture and alignment

    /// Called once the scan has a floor and a stable wall. Stores the scan and the derived frame, then verifies.
    func captureCompleted(frame: RoomFrame, surfaces: [Surface], scanData: Data, anchorID: UUID?) async {
        guard let room = currentRoom else { return }
        await perform {
            currentRoom = try await repository.attachScan(scanData, frame: frame, to: room.id, capturedAt: .now, sessionAnchorID: anchorID)
            self.surfaces = surfaces
            alignment = .verified(frame)
            rooms = try await repository.rooms(in: room.spaceID)
        }
    }

    func alignmentAttemptFailed() { alignment = alignment.afterFailedAttempt() }

    /// The current room's scan file (iPhone/iPad keeps its ARKit world map inside it for relocalization).
    func currentScanData() async -> Data? {
        guard let room = currentRoom else { return nil }
        do { return try await repository.scanData(for: room.id) } catch {
            errorMessage = Self.describe(error)
            return nil
        }
    }

    /// Replaces the current room's scan file, keeping its frame and anchor (e.g. a richer world map when leaving).
    func updateScan(_ data: Data) async {
        guard let room = currentRoom, let frame = room.frame else { return }
        await perform {
            currentRoom = try await repository.attachScan(data, frame: frame, to: room.id, capturedAt: .now, sessionAnchorID: room.sessionAnchorID)
        }
    }

    /// Rescan into the same Room: clears only the frame/anchor mapping. Designs and room-local placements are kept.
    func rescanCurrentRoom() async {
        guard let room = currentRoom else { return }
        currentRoom = Room(id: room.id, spaceID: room.spaceID, name: room.name, kind: room.kind, scan: room.scan, frame: nil, sessionAnchorID: nil)
        alignment = .searching(attempt: 0)
        statusMessage = "Rescanning: look at the floor and a wall."
        sessionGeneration += 1
    }

    func alignmentVerified(_ frame: RoomFrame, surfaces: [Surface]) {
        alignment = .verified(frame)
        self.surfaces = surfaces
    }

    // MARK: Placement pipeline

    /// Adds an item in front of the user, facing them; wall, ceiling and tabletop items go to the nearest suitable
    /// surface. Wall items then face out of the wall regardless of the seed's yaw.
    func add(_ item: CatalogueItem, near seed: RigidTransform) async {
        guard let design = currentDesign, item.affinity.isPlaceableInMVP1 else { return }
        let roomLocal = seed.translation
        var seeds = [seed]
        if let policy = AttachmentPolicy.forAffinity(item.affinity) {
            let compatible = surfaces.filter { $0.kind == policy.surface && (item.affinity != .tabletop || !$0.isFloor) }
                .sorted { simd_distance($0.centre, roomLocal) < simd_distance($1.centre, roomLocal) }
            for s in compatible {
                let mount = item.geometry.mountPoint ?? SIMD3(0, item.geometry.size.y, 0)
                switch s.kind {
                case .horizontalUp: seeds.append(RigidTransform(translation: s.centre, rotation: seed.rotation))
                case .horizontalDown: seeds.append(RigidTransform(translation: SIMD3(roomLocal.x, s.centre.y - mount.y, roomLocal.z), rotation: seed.rotation))
                case .vertical:
                    let onWall = roomLocal - s.normal * simd_dot(roomLocal - s.centre, s.normal)
                    seeds.append(RigidTransform(translation: SIMD3(onWall.x, 1.5 - mount.y, onWall.z) + s.normal * 0.2))
                }
            }
        }
        placementLog.info("add \(item.name, privacy: .public): \(seeds.count) seeds, surfaces \(self.surfaces.count)")
        for seed in seeds {
            let outcome = resolve(item: item, placementID: nil, released: seed)
            placementLog.info("seed \(seed.translation.debugDescription, privacy: .public) -> \(String(describing: outcome), privacy: .public)")
            switch outcome {
            case .valid(let pose), .pushedOut(let pose, _):
                let placement = Placement(asset: item.reference, transform: pose)
                statusMessage = nil
                await commit(.add(placement), to: design)
                selection = placement.id
                return
            case .heldInvalid:
                continue
            }
        }
        statusMessage = ReleaseOutcome.message
    }

    /// Transform updates during a drag are previews only; nothing is persisted per frame.
    func dragUpdated(_ id: PlacementID, roomLocal: RigidTransform) {
        previewTransforms[id] = roomLocal
        if let item = currentDesign?.placement(id).flatMap({ self.item(for: $0.asset) }) {
            let box = OrientedBox(basePivot: roomLocal, size: item.geometry.size)
            if realGeometryIntersects?(box) == true { heldInvalid.insert(id) } else { heldInvalid.remove(id) }
        }
    }

    /// Release: attach → hard real collision → ≤25 cm resolution → commit, or keep the unsaved preview held.
    func release(_ id: PlacementID, roomLocal: RigidTransform) async {
        guard let design = currentDesign, let placement = design.placement(id), let item = item(for: placement.asset) else { return }
        let outcome = resolve(item: item, placementID: id, released: roomLocal)
        placementLog.info("release \(item.name, privacy: .public) -> \(String(describing: outcome).prefix(80), privacy: .public)")
        switch outcome {
        case .valid(let pose), .pushedOut(let pose, _):
            previewTransforms[id] = nil
            heldInvalid.remove(id)
            statusMessage = nil
            guard !pose.isApproximately(placement.transform) else { return }
            await commit(.move(id, from: placement.transform, to: pose), to: design)
        case .heldInvalid:
            previewTransforms[id] = roomLocal
            heldInvalid.insert(id)
            statusMessage = ReleaseOutcome.message
        }
    }

    /// Cancel restores the last committed placement (a new, never-committed item has nothing to restore).
    func cancel(_ id: PlacementID) {
        previewTransforms[id] = nil
        heldInvalid.remove(id)
        statusMessage = nil
    }

    /// Non-gesture move: the same release pipeline as a drag, from the committed or held position.
    func nudge(_ id: PlacementID, by delta: SIMD3<Float>) async {
        guard let placement = currentDesign?.placement(id) else { return }
        let from = previewTransforms[id] ?? placement.transform
        await release(id, roomLocal: RigidTransform(translation: from.translation + delta, rotation: from.rotation))
    }

    /// Non-gesture rotation about the vertical axis.
    func rotate(_ id: PlacementID, byDegrees degrees: Float) async {
        guard let placement = currentDesign?.placement(id) else { return }
        let from = previewTransforms[id] ?? placement.transform
        let turn = simd_quatf(angle: degrees * .pi / 180, axis: SIMD3(0, 1, 0))
        await release(id, roomLocal: RigidTransform(translation: from.translation, rotation: turn * from.rotation))
    }

    func remove(_ id: PlacementID) async {
        guard let design = currentDesign, let placement = design.placement(id) else { return }
        previewTransforms[id] = nil
        heldInvalid.remove(id)
        await commit(.remove(placement), to: design)
        if selection == id { selection = nil }
    }

    func undo() async {
        placementLog.info("undo requested canUndo=\(self.undoHistory.canUndo) stack=\(self.undoHistory.undoStack.count)")
        guard let edit = undoHistory.nextUndo, let design = currentDesign else { return }
        if await commit(edit, to: design, recordUndo: false) { undoHistory.didCommitUndo() }
    }

    func redo() async {
        guard let edit = undoHistory.nextRedo, let design = currentDesign else { return }
        if await commit(edit, to: design, recordUndo: false) { undoHistory.didCommitRedo() }
    }

    @discardableResult
    private func commit(_ edit: DesignEdit, to design: Design, recordUndo: Bool = true) async -> Bool {
        do {
            let next = try await repository.commit(edit, to: design.id, expectedVersion: design.version)
            placementLog.info("commit ok v\(next.version) undoRecorded=\(recordUndo) \(String(describing: edit).prefix(120), privacy: .public)")
            currentDesign = next
            if let i = designs.firstIndex(where: { $0.id == next.id }) { designs[i] = next }
            if recordUndo { undoHistory.recordCommitted(edit) }
            recomputeOverlapCues()
            return true
        } catch {
            placementLog.error("commit failed: \(String(describing: error), privacy: .public)")
            errorMessage = Self.describe(error)
            return false
        }
    }

    func resolve(item: CatalogueItem, placementID: PlacementID?, released: RigidTransform) -> ReleaseOutcome {
        let others = (currentDesign?.placements ?? []).filter { $0.id != placementID }.compactMap { p -> (box: OrientedBox, isFloorCovering: Bool)? in
            guard let g = self.item(for: p.asset)?.geometry else { return nil }
            return (OrientedBox(basePivot: p.transform, size: g.size), g.isFloorCovering)
        }
        func attached(_ candidate: RigidTransform) -> RigidTransform? {
            guard let pose = Attachment.attach(affinity: item.affinity, item: item.geometry, released: candidate, surfaces: surfaces) else { return nil }
            let box = OrientedBox(basePivot: pose, size: item.geometry.size)
            if realGeometryIntersects?(box) == true { return nil }
            _ = PlacementRules.check(item: item.geometry, at: pose, real: [], virtual: others) // virtual overlap never blocks
            return pose
        }
        switch ReleaseResolver().resolve(released: released, isValid: { attached($0) != nil }) {
        case .valid(let c): return attached(c).map { .valid($0) } ?? .heldInvalid
        case .pushedOut(let c, let d): return attached(c).map { .pushedOut($0, distance: d) } ?? .heldInvalid
        case .heldInvalid: return .heldInvalid
        }
    }

    func recomputeOverlapCues() {
        guard let design = currentDesign else { overlapCues = []; return }
        var cues: Set<PlacementID> = []
        for p in design.placements {
            guard let item = item(for: p.asset) else { continue }
            let others = design.placements.filter { $0.id != p.id }.compactMap { o -> (box: OrientedBox, isFloorCovering: Bool)? in
                guard let g = self.item(for: o.asset)?.geometry else { return nil }
                return (OrientedBox(basePivot: o.transform, size: g.size), g.isFloorCovering)
            }
            if PlacementRules.check(item: item.geometry, at: p.transform, real: [], virtual: others).showsOverlapCue { cues.insert(p.id) }
        }
        overlapCues = cues
    }

    func displayedTransform(_ p: Placement) -> RigidTransform { previewTransforms[p.id] ?? p.transform }

    // MARK: Deletion

    func deletionPreview(for room: Room) async -> DeletionPreview? {
        do { return try await repository.deletionPreview(room: room.id) } catch {
            errorMessage = Self.describe(error)
            return nil
        }
    }

    func delete(_ room: Room) async {
        await perform {
            _ = try await repository.deleteRoom(room.id)
            if let space = currentSpaceID { try await selectSpace(space) }
        }
    }
}
