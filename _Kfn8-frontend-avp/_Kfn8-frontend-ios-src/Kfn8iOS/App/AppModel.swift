import Foundation
import Kfn8Catalogue
import Kfn8Domain
import Kfn8Persistence
import Observation
import os

/// Local diagnostics only (the device's unified log). No collection endpoint, no analytics SDK.
let appLog = Logger(subsystem: "com.appliaison.kfn8.ios", category: "app")

/// Main-actor owner of navigation, selection, undo and the placement pipeline. Persistence runs on its own actor and
/// only Sendable domain values cross; RealityKit entities are a projection of `currentDesign` plus unsaved previews.
@MainActor
@Observable
final class AppModel {
    let repository: any DesignRepository
    let bundled: [CatalogueItem]
    let remote: RemoteCatalogue
    let captureMode: RoomCaptureMode
    let options: LaunchOptions

    /// Bundled items plus downloaded online items that are still available (not revoked, file present).
    var catalogue: [CatalogueItem] { bundled + remote.placeableItems }

    // Navigation
    var spaces: [Space] = []
    var rooms: [Room] = []
    var designs: [Design] = []
    var currentSpaceID: SpaceID?
    var currentRoom: Room?
    var currentDesign: Design?

    // Room view
    var isRoomViewOpen = false
    var alignment: AlignmentState = .searching(attempt: 0)
    var surfaces: [Surface] = []
    /// Real obstacles scanned so far (tables, seats, walls), room-local, for clearance readings.
    var realObstacles: [OrientedBox] = []
    /// Bumped to restart room tracking, e.g. to rescan into the same Room.
    var sessionGeneration = 0
    var cameraDenied = false
    /// Room-local real-geometry test from the room session (scan mesh, scanned planes or the simulated room).
    @ObservationIgnored var realGeometryIntersects: ((OrientedBox) -> Bool)?
    /// Room-local pose in front of the camera, facing it, for new placements.
    @ObservationIgnored var poseInFront: (() -> RigidTransform)?

    // Editing
    var selection: PlacementID?
    var undoHistory = UndoHistory()
    /// Live, unsaved transforms: during a drag, and for releases that could not be resolved (held invalid).
    var previewTransforms: [PlacementID: RigidTransform] = [:]
    var heldInvalid: Set<PlacementID> = []
    var overlapCues: Set<PlacementID> = []
    var statusMessage: String?
    /// The catalogue item whose last Add found no valid spot, so the message shows beside the button that was pressed.
    var addFailedItem: AssetID?
    var errorMessage: String?

    // A/B flip: the shown composition changes only once the next Design is ready.
    var switcher: DesignSwitcher?
    var preparingDesign: Design?

    // Lighting and photo
    var lampsOn = true
    var photo = PhotoExportFlow()

    init(repository: any DesignRepository, bundled: [CatalogueItem], remote: RemoteCatalogue, captureMode: RoomCaptureMode, options: LaunchOptions) {
        self.repository = repository
        self.bundled = bundled
        self.remote = remote
        self.captureMode = captureMode
        self.options = options
    }

    var isSimulatedRoom: Bool { captureMode == .simulated }

    /// The bundled revision is matched by asset; a downloaded one by its exact revision (an older Design may pin it).
    func item(for reference: AssetReference) -> CatalogueItem? {
        bundled.first { $0.id == reference.assetID } ?? remote.placeableItem(for: reference)
    }

    // MARK: Lifecycle

    func bootstrap() async {
        await perform {
            let pending = try await repository.finishPendingDeletions()
            if pending > 0 { errorMessage = "\(pending) file(s) from an earlier deletion couldn't be removed yet." }
            spaces = try await repository.spaces()
            if let first = spaces.first { try await selectSpace(first.id) }
        }
        await refreshRemote(force: options.forceRevocationSync)
    }

    /// Launch and foreground opportunity for the online catalogue and revocation checks (no heartbeat).
    func refreshRemote(force: Bool = false) async {
        let pins = (try? await repository.revisionReferenceCounts()).map { Set($0.keys) } ?? []
        await remote.refresh(pinned: pins, force: force)
    }

    /// Runs persistence work and shows any failure; nothing is swallowed.
    func perform(_ work: () async throws -> Void) async {
        do { try await work() } catch { errorMessage = Self.describe(error) }
    }

    static func describe(_ error: any Error) -> String {
        switch error {
        case PersistenceError.versionConflict: "This design changed elsewhere. Your last edit wasn't saved."
        case PersistenceError.saveFailed(let why): "Couldn't save: \(why)"
        case PersistenceError.scanUnreadable: "This room's scan couldn't be read. Rescan the room to place things again."
        case PersistenceError.deletionIncomplete(let n): "Deleted, but \(n) file(s) are still being removed."
        case PersistenceError.scanWriteFailed: "Couldn't store the room scan. Your previous scan is unchanged."
        case let e as AssetCacheError: RemoteCatalogue.describe(e)
        case let e as CatalogueError: RemoteCatalogue.describe(e)
        default: "Something went wrong: \(error.localizedDescription)"
        }
    }

    // MARK: Spaces, rooms, designs

    func createSpace() async {
        await perform {
            let space = try await repository.createSpace(name: spaces.isEmpty ? "Home" : "Space \(spaces.count + 1)")
            spaces = try await repository.spaces()
            try await selectSpace(space.id)
        }
    }

    func selectSpace(_ id: SpaceID) async throws {
        currentSpaceID = id
        rooms = try await repository.rooms(in: id)
        if let room = rooms.first { try await selectRoom(room) } else { currentRoom = nil; designs = []; currentDesign = nil }
    }

    func createRoom() async {
        guard let space = currentSpaceID else { return }
        await perform {
            let room = try await repository.createRoom(in: space, name: "Room \(rooms.count + 1)")
            rooms = try await repository.rooms(in: space)
            try await selectRoom(room)
        }
    }

    func selectRoom(_ room: Room) async throws {
        currentRoom = room
        alignment = .searching(attempt: 0)
        surfaces = []
        realObstacles = []
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

    func duplicateCurrentDesign() async {
        guard let d = currentDesign, let room = currentRoom else { return }
        await perform {
            let copy = try await repository.duplicate(d.id, name: "\(d.name) copy")
            designs = try await repository.designs(in: room.id)
            selectDesign(copy)
        }
    }

    func renameCurrentDesign(to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let d = currentDesign, !trimmed.isEmpty, trimmed != d.name else { return }
        await commit(.rename(from: d.name, to: trimmed), to: d)
    }

    // MARK: A/B flip

    /// The Design an A/B flip goes to: the other Design in this room most recently listed.
    var flipTarget: Design? { designs.first { $0.id != currentDesign?.id } }

    /// Outside the room view there is nothing to preload, so the flip is immediate; inside, it waits for the models.
    func requestFlip() {
        guard let target = flipTarget else { return }
        guard isRoomViewOpen, alignment.showsSpatialContent else { selectDesignKeepingSwitcher(target); return }
        switcher?.request(target.id)
        preparingDesign = target
        statusMessage = "Loading \(target.name)…"
    }

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

    // MARK: Inventory and updates

    /// Generic-first inventory. Prices appear only for online items that carry a real offer.
    var inventoryLines: [InventoryLine] {
        guard let d = currentDesign else { return [] }
        return Inventory.lines(for: d) { ref in
            if let item = self.item(for: ref) { return InventorySource(name: item.name, sizeMetres: item.geometry.size, offer: item.offer) }
            // Withdrawn or not on this device: keep the name, drop the price, and mark the line unavailable.
            return remote.index.item(for: ref).map { InventorySource(name: $0.name, sizeMetres: $0.sizeMetres, offer: nil, isAvailable: false) }
        }
    }

    /// Newer revisions of online items used in this Design, offered per Design and never applied automatically.
    var updateOffers: [AssetUpdateOffer] {
        guard let d = currentDesign else { return [] }
        return AssetUpdateOffer.offers(for: d) { remote.latestRevision(of: $0) }
    }

    func acceptUpdate(_ offer: AssetUpdateOffer) async {
        guard let d = currentDesign else { return }
        do {
            try await remote.download(asset: offer.to.assetID, revisionID: offer.to.revisionID)
            await commit(offer.edit, to: d)
        } catch {
            errorMessage = Self.describe(error)
        }
    }

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
