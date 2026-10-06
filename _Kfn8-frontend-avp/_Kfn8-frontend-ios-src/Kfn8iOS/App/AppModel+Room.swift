import Foundation
import Kfn8Domain
import Kfn8Persistence

extension AppModel {
    /// One-line room status, shown in the room list and the room view.
    func alignmentText(_ room: Room) -> String {
        let simulated = isSimulatedRoom ? " · \(SimulatedRoom.label)" : ""
        if !isRoomViewOpen { return (room.frame == nil ? "Not scanned yet" : "Scanned") + simulated }
        switch alignment {
        case .verified: return "Aligned" + simulated
        case .searching: return (room.frame == nil ? "Scanning: move slowly and point at the floor and a wall" : "Looking for this room…") + simulated
        case .exhausted: return "I can't tell where this room is yet"
        }
    }

    func openRoomView() {
        guard currentRoom != nil else { return }
        alignment = .searching(attempt: 0)
        statusMessage = nil
        isRoomViewOpen = true
    }

    func closeRoomView() {
        isRoomViewOpen = false
        previewTransforms = [:]
        heldInvalid = []
        statusMessage = nil
    }

    /// First scan: the floor and a stable wall gave a room frame. Stores the scan (with the world map when ready).
    func captureCompleted(frame: RoomFrame, surfaces: [Surface], scanData: Data, anchorID: UUID?) async {
        guard let room = currentRoom else { return }
        await perform {
            currentRoom = try await repository.attachScan(scanData, frame: frame, to: room.id, capturedAt: .now, sessionAnchorID: anchorID)
            self.surfaces = surfaces
            alignment = .verified(frame)
            rooms = try await repository.rooms(in: room.spaceID)
            statusMessage = nil
        }
    }

    func alignmentVerified(_ frame: RoomFrame, surfaces: [Surface]) {
        alignment = .verified(frame)
        self.surfaces = surfaces
        statusMessage = nil
    }

    func alignmentAttemptFailed() { alignment = alignment.afterFailedAttempt() }

    /// The current room's scan file, whose world map lets the room be found again.
    func currentScanData() async -> Data? {
        guard let room = currentRoom else { return nil }
        do { return try await repository.scanData(for: room.id) } catch {
            errorMessage = Self.describe(error)
            return nil
        }
    }

    /// Replaces the room's scan file, keeping its frame and anchor (a richer world map when leaving the room).
    func updateScan(_ data: Data) async {
        guard let room = currentRoom, let frame = room.frame else { return }
        await perform {
            currentRoom = try await repository.attachScan(data, frame: frame, to: room.id, capturedAt: .now, sessionAnchorID: room.sessionAnchorID)
        }
    }

    /// Rescan into the same Room: only the frame/anchor mapping is cleared. Designs and room-local placements stay.
    func rescanCurrentRoom() {
        guard let room = currentRoom else { return }
        currentRoom = Room(id: room.id, spaceID: room.spaceID, name: room.name, kind: room.kind, scan: room.scan, frame: nil, sessionAnchorID: nil)
        alignment = .searching(attempt: 0)
        statusMessage = "Rescanning: point at the floor and a wall."
        sessionGeneration += 1
    }

    /// "Review contents": leave the room view, keep the Designs, show no positions or clearances.
    func reviewContents() { closeRoomView() }
}
