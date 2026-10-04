import ARKit
import AVFoundation
import Foundation
import Kfn8Domain
import RealityKit
import simd

/// iPhone/iPad: runs ARKit world tracking in an `ARView`, or the labelled simulated room on the simulator. Classified
/// planes feed the shared `CapturedPlanes` rules; on LiDAR devices RealityKit's scene mesh provides real-geometry
/// collisions and occlusion. On other devices only classified planes are known, and the UI says so. The ARKit world
/// map is kept inside the room's local scan file (never uploaded, removed with the room) to find the room again.
@MainActor
final class ARRoomSession: NSObject, ARSessionDelegate {
    private let model: AppModel
    private weak var arView: ARView?
    private var planes = CapturedPlanes()
    private var alignmentTask: Task<Void, Never>?
    private var running = false
    /// True when the device has a LiDAR scene mesh (collisions + occlusion).
    private(set) var hasSceneMesh = false
    /// Name of the ARKit anchor planted at the room origin on capture.
    static let roomAnchorName = "kfn8-room"

    init(model: AppModel) { self.model = model }

    static var isARKitAvailable: Bool { ARWorldTrackingConfiguration.isSupported }

    func start(in arView: ARView, roomRoot: Entity) async {
        self.arView = arView
        planes.removeAll()
        if model.isSimulatedRoom {
            await SimulatedRoom.start(model: model, roomRoot: roomRoot)
            return
        }
        guard Self.isARKitAvailable else {
            model.errorMessage = "This device can't track rooms in AR."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            model.errorMessage = "Kfn8 needs the camera to find your floor and walls. Turn it on in Settings › Kfn8. Nothing you scan leaves this device."
            return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                model.errorMessage = "Kfn8 needs the camera to find your floor and walls. Turn it on in Settings › Kfn8. Nothing you scan leaves this device."
                return
            }
        default:
            break
        }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        hasSceneMesh = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        if hasSceneMesh {
            config.sceneReconstruction = .mesh
            arView.environment.sceneUnderstanding.options.formUnion([.occlusion, .collision, .receivesLighting])
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        let returning = model.currentRoom?.frame != nil
        if returning { config.initialWorldMap = await savedWorldMap() }
        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        running = true
        model.realGeometryIntersects = hasSceneMesh ? { [weak roomRoot] box in
            guard let root = roomRoot, let scene = root.scene else { return false }
            // Shrunk for scan-mesh noise, so resting on the supporting floor/wall/table/ceiling is not a collision.
            let test = box.realWorldContactTest
            let shape = ShapeResource.generateBox(size: test.halfSize * 2)
            let hits = scene.convexCast(convexShape: shape, fromPosition: test.pose.translation, fromOrientation: test.pose.rotation,
                                        toPosition: test.pose.translation + SIMD3(0, 0.001, 0), toOrientation: test.pose.rotation,
                                        query: .any, mask: .sceneUnderstanding, relativeTo: root)
            return !hits.isEmpty
        } : nil
        let canRelocalize = config.initialWorldMap != nil
        alignmentTask = Task { await self.runAlignment(roomRoot: roomRoot, canRelocalize: canRelocalize) }
    }

    /// Stops tracking. When the room is aligned, first stores a fresh world map (more of the room has usually been seen
    /// by now than at capture), so the next visit relocalizes more reliably.
    func stop() async {
        alignmentTask?.cancel()
        alignmentTask = nil
        model.realGeometryIntersects = nil
        guard running, let arView else { return }
        running = false
        if !model.isSimulatedRoom, case .verified = model.alignment, model.currentRoom?.frame != nil {
            switch await archivedWorldMap() {
            case .success(let map):
                let snapshot = ScanSnapshot(capturedAt: .now, planes: planes.all, meshAnchorCount: 0, simulated: false, worldMap: map)
                do { await model.updateScan(try JSONEncoder().encode(snapshot)) } catch {
                    model.errorMessage = "Couldn't update this room's scan: \(error.localizedDescription)"
                }
            case .failure(let reason):
                placementLog.info("world map not refreshed on leave: \(reason.message, privacy: .public)")
            }
        }
        arView.session.pause()
    }

    /// Room-local pose for a new item: 1.5 m ahead of the camera on the horizontal, facing the viewer.
    func poseInFront(distance: Float = 1.5) -> RigidTransform {
        guard case .verified(let frame) = model.alignment else { return RigidTransform(translation: SIMD3(0, 0, 2)) }
        var camera = RigidTransform(translation: SIMD3(0, 1.4, 0))
        if !model.isSimulatedRoom, let t = arView?.cameraTransform {
            camera = RigidTransform(translation: t.translation, rotation: t.rotation)
        }
        return frame.poseInFront(of: camera, distance: distance)
    }

    // MARK: ARSessionDelegate (delivered on the main queue: the session's delegateQueue is nil)

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let updates = anchors.compactMap(Self.plane(from:))
        MainActor.assumeIsolated { apply(updates, removed: []) }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let updates = anchors.compactMap(Self.plane(from:))
        MainActor.assumeIsolated { apply(updates, removed: []) }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = anchors.compactMap { $0 as? ARPlaneAnchor }.map(\.identifier)
        MainActor.assumeIsolated { apply([], removed: removed) }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        let message = error.localizedDescription
        MainActor.assumeIsolated { model.errorMessage = "Room tracking stopped: \(message)" }
    }

    /// Translates an ARKit plane into the shared plane record (session coordinates). Unclassified planes are ignored.
    nonisolated private static func plane(from anchor: ARAnchor) -> (UUID, ScanSnapshot.Plane)? {
        guard let a = anchor as? ARPlaneAnchor else { return nil }
        let kind: SurfaceKind
        let classification: String
        switch a.classification {
        case .floor: kind = .horizontalUp; classification = "floor"
        case .table: kind = .horizontalUp; classification = "table"
        case .seat: kind = .horizontalUp; classification = "seat"
        case .ceiling: kind = .horizontalDown; classification = "ceiling"
        case .wall: kind = .vertical; classification = "wall"
        default: return nil
        }
        let centre = a.transform * SIMD4(a.center, 1)
        let n = a.transform.columns.1 // a plane anchor's local +Y is its normal
        return (a.identifier, .init(kind: kind.rawValue, classification: classification, centre: [centre.x, centre.y, centre.z],
                                    normal: [n.x, n.y, n.z], halfExtent: [a.planeExtent.width / 2, a.planeExtent.height / 2]))
    }

    private func apply(_ updates: [(UUID, ScanSnapshot.Plane)], removed: [UUID]) {
        for (id, plane) in updates { planes.set(plane, id: id) }
        for id in removed { planes.remove(id) }
        if case .verified(let frame) = model.alignment { model.surfaces = planes.roomLocalSurfaces(frame: frame) }
    }

    // MARK: Alignment

    /// First visit: derive the frame from floor + widest wall, plant an ARKit anchor at the room origin and store the
    /// scan with the world map. Return visit: relocalize against the saved map in bounded 8 s attempts, content hidden
    /// until the room anchor is tracked again; without a usable map the attempts run out and the user can rescan into
    /// the same Room or review its contents.
    private func runAlignment(roomRoot: Entity, canRelocalize: Bool) async {
        guard let room = model.currentRoom else { return }
        if let storedFrame = room.frame {
            while !Task.isCancelled, !model.alignment.showsSpatialContent, model.alignment != .exhausted {
                let deadline = Date.now.addingTimeInterval(8)
                var found = false
                while canRelocalize, Date.now < deadline, !Task.isCancelled {
                    if let anchor = relocalizedRoomAnchor(id: room.sessionAnchorID) {
                        let t = Transform(matrix: anchor)
                        let verified = RoomFrame(version: storedFrame.version, sessionFromRoom: RigidTransform(translation: t.translation, rotation: t.rotation))
                        roomRoot.setTransformMatrix(verified.sessionFromRoom.matrix, relativeTo: nil)
                        model.alignmentVerified(verified, surfaces: planes.roomLocalSurfaces(frame: verified))
                        found = true
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
                if !canRelocalize { try? await Task.sleep(for: .seconds(8)) }
                if !found, !Task.isCancelled { model.alignmentAttemptFailed() }
            }
            return
        }
        while !Task.isCancelled {
            if let frame = planes.deriveFrame() {
                let anchor = ARAnchor(name: Self.roomAnchorName, transform: frame.sessionFromRoom.matrix)
                arView?.session.add(anchor: anchor)
                roomRoot.setTransformMatrix(frame.sessionFromRoom.matrix, relativeTo: nil)
                var snapshot = ScanSnapshot(capturedAt: .now, planes: planes.all, meshAnchorCount: 0, simulated: false)
                switch await archivedWorldMap() {
                case .success(let map): snapshot.worldMap = map
                case .failure(let reason):
                    model.statusMessage = "Room found. Look around a little more before leaving so Kfn8 can find it again later."
                    placementLog.info("world map unavailable at capture: \(reason.message, privacy: .public)")
                }
                await model.captureCompleted(frame: frame, surfaces: planes.roomLocalSurfaces(frame: frame),
                                             scanData: (try? JSONEncoder().encode(snapshot)) ?? Data(), anchorID: anchor.identifier)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    /// The room anchor's session transform once ARKit has relocalized against the saved map and is tracking normally.
    private func relocalizedRoomAnchor(id: UUID?) -> simd_float4x4? {
        guard let frame = arView?.session.currentFrame, case .normal = frame.camera.trackingState else { return nil }
        return frame.anchors.first { $0.identifier == id || $0.name == Self.roomAnchorName }?.transform
    }

    // MARK: World map

    struct WorldMapUnavailable: Error { var message: String }

    /// The current ARKit world map, archived (the archive is Sendable; ARWorldMap is not).
    private func archivedWorldMap() async -> Result<Data, WorldMapUnavailable> {
        guard let session = arView?.session else { return .failure(.init(message: "no session")) }
        return await withCheckedContinuation { continuation in
            session.getCurrentWorldMap { map, error in
                guard let map else {
                    continuation.resume(returning: .failure(.init(message: error?.localizedDescription ?? "no map")))
                    return
                }
                do { continuation.resume(returning: .success(try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true))) } catch {
                    continuation.resume(returning: .failure(.init(message: error.localizedDescription)))
                }
            }
        }
    }

    /// The world map stored in the current room's scan, if any. A scan without one (e.g. captured before tracking
    /// had seen enough) simply cannot relocalize; an unreadable map is reported.
    private func savedWorldMap() async -> ARWorldMap? {
        guard let data = await model.currentScanData() else { return nil }
        let snapshot: ScanSnapshot
        do { snapshot = try JSONDecoder().decode(ScanSnapshot.self, from: data) } catch {
            model.errorMessage = "This room's scan couldn't be read. Rescan the room to place things again."
            return nil
        }
        guard let archived = snapshot.worldMap else { return nil }
        do { return try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: archived) } catch {
            model.errorMessage = "This room's saved map couldn't be read. Rescan the room to place things again."
            return nil
        }
    }
}
