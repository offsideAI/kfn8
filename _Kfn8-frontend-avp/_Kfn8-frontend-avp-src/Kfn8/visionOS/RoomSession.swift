import ARKit
import Foundation
import Kfn8Domain
import QuartzCore
import RealityKit
import simd

/// visionOS: owns ARKit providers on device, or the labelled synthetic room on the simulator. Produces room-local
/// surfaces, derives the room frame on first capture (shared `CapturedPlanes` rules), and verifies alignment on return
/// visits (bounded guided attempts).
@MainActor
final class RoomSession {
    private let model: AppModel
    // Providers cannot be re-run after a stop, so each start gets fresh instances.
    private var session = ARKitSession()
    private var planes = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
    private var world = WorldTrackingProvider()
    private var meshes = SceneReconstructionProvider()
    private var sessionPlanes = CapturedPlanes()
    private(set) var meshEntities: [UUID: Entity] = [:]
    let meshRoot = Entity()
    private var tasks: [Task<Void, Never>] = []
    static let realWorldGroup = CollisionGroup(rawValue: 1 << 1)

    init(model: AppModel) { self.model = model }

    static var isARKitAvailable: Bool {
        PlaneDetectionProvider.isSupported && WorldTrackingProvider.isSupported && SceneReconstructionProvider.isSupported
    }

    func start(roomRoot: Entity) async {
        if model.isSimulatedRoom {
            await SimulatedRoom.start(model: model, roomRoot: roomRoot)
            return
        }
        session = ARKitSession()
        planes = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
        world = WorldTrackingProvider()
        meshes = SceneReconstructionProvider()
        sessionPlanes.removeAll()
        let auth = await session.requestAuthorization(for: [.worldSensing])
        guard auth[.worldSensing] == .allowed else {
            model.errorMessage = "Kfn8 needs world sensing to find your floor and walls. Nothing leaves this device."
            return
        }
        do { try await session.run([planes, world, meshes]) } catch {
            model.errorMessage = "Couldn't start room tracking: \(error.localizedDescription)"
            return
        }
        let planes = planes, meshes = meshes
        tasks.append(Task { for await u in planes.anchorUpdates { self.apply(u) } })
        tasks.append(Task { for await u in meshes.anchorUpdates { await self.apply(u) } })
        tasks.append(Task { await self.runAlignment(roomRoot: roomRoot) })
        model.realGeometryIntersects = { [weak roomRoot] box in
            guard let root = roomRoot, let scene = root.scene else { return false }
            // Shrunk for scan-mesh noise, so resting on the supporting floor/wall/table/ceiling is not a collision.
            let test = box.realWorldContactTest
            let shape = ShapeResource.generateBox(size: test.halfSize * 2)
            let hits = scene.convexCast(convexShape: shape, fromPosition: test.pose.translation, fromOrientation: test.pose.rotation,
                                        toPosition: test.pose.translation + SIMD3(0, 0.001, 0), toOrientation: test.pose.rotation,
                                        query: .any, mask: RoomSession.realWorldGroup, relativeTo: root)
            return !hits.isEmpty
        }
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        session.stop()
        model.realGeometryIntersects = nil
    }

    // MARK: Device

    private func apply(_ update: AnchorUpdate<PlaneAnchor>) {
        let a = update.anchor
        if update.event == .removed { sessionPlanes.remove(a.id); refreshSurfaces(); return }
        let kind: SurfaceKind
        switch a.surfaceClassification {
        case .floor, .table, .seat, .bed: kind = .horizontalUp
        case .ceiling: kind = .horizontalDown
        case .wall: kind = .vertical
        default: return
        }
        let m = a.originFromAnchorTransform * a.geometry.extent.anchorFromExtentTransform
        let n = a.originFromAnchorTransform.columns.1
        sessionPlanes.set(.init(kind: kind.rawValue, classification: String(describing: a.surfaceClassification),
                                centre: [m.columns.3.x, m.columns.3.y, m.columns.3.z], normal: [n.x, n.y, n.z],
                                halfExtent: [a.geometry.extent.width / 2, a.geometry.extent.height / 2]), id: a.id)
        refreshSurfaces()
    }

    private func apply(_ update: AnchorUpdate<MeshAnchor>) async {
        let a = update.anchor
        switch update.event {
        case .added, .updated:
            guard let shape = try? await ShapeResource.generateStaticMesh(from: a) else { return }
            let e = meshEntities[a.id] ?? { let n = Entity(); meshRoot.addChild(n); meshEntities[a.id] = n; return n }()
            e.setTransformMatrix(a.originFromAnchorTransform, relativeTo: nil)
            e.components.set(CollisionComponent(shapes: [shape], isStatic: true, filter: CollisionFilter(group: RoomSession.realWorldGroup, mask: .all)))
        case .removed:
            meshEntities.removeValue(forKey: a.id)?.removeFromParent()
        }
    }

    /// First visit: derive the frame from floor + largest wall and plant a world anchor at the room origin.
    /// Return visit: wait for the stored world anchor, with bounded guided attempts; content stays hidden until then.
    private func runAlignment(roomRoot: Entity) async {
        guard let room = model.currentRoom else { return }
        if let anchorID = room.sessionAnchorID, let frame = room.frame {
            while !Task.isCancelled, !model.alignment.showsSpatialContent, model.alignment != .exhausted {
                let deadline = CACurrentMediaTime() + 8
                var found = false
                while CACurrentMediaTime() < deadline, !Task.isCancelled {
                    if let anchor = await world.allAnchors?.first(where: { $0.id == anchorID }), anchor.isTracked {
                        let t = Transform(matrix: anchor.originFromAnchorTransform)
                        let verified = RoomFrame(version: frame.version, sessionFromRoom: RigidTransform(translation: t.translation, rotation: t.rotation))
                        roomRoot.setTransformMatrix(verified.sessionFromRoom.matrix, relativeTo: nil)
                        model.alignmentVerified(verified, surfaces: sessionPlanes.roomLocalSurfaces(frame: verified))
                        found = true
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
                if !found { model.alignmentAttemptFailed() }
            }
            return
        }
        // Capture: wait for a floor and a wall, derive, anchor, persist.
        while !Task.isCancelled {
            if let frame = sessionPlanes.deriveFrame() {
                let anchor = WorldAnchor(originFromAnchorTransform: frame.sessionFromRoom.matrix)
                do { try await world.addAnchor(anchor) } catch {
                    model.errorMessage = "Couldn't anchor the room: \(error.localizedDescription)"
                    return
                }
                roomRoot.setTransformMatrix(frame.sessionFromRoom.matrix, relativeTo: nil)
                let snapshot = ScanSnapshot(capturedAt: .now, planes: sessionPlanes.all, meshAnchorCount: meshEntities.count, simulated: false)
                await model.captureCompleted(frame: frame, surfaces: sessionPlanes.roomLocalSurfaces(frame: frame),
                                             scanData: (try? JSONEncoder().encode(snapshot)) ?? Data(), anchorID: anchor.id)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func refreshSurfaces() {
        if case .verified(let frame) = model.alignment { model.surfaces = sessionPlanes.roomLocalSurfaces(frame: frame) }
    }

    /// Room-local pose `distance` metres in front of the user for new placements, turned so the item's front (−Z)
    /// faces the user. The default distance is beyond the main window (≈1–1.5 m) so new items never sit between the
    /// user and the window's controls and steal its taps.
    func poseInFront(distance: Float = 2.4) -> RigidTransform {
        guard case .verified(let frame) = model.alignment else { return RigidTransform(translation: SIMD3(0, 0, 2)) }
        var head = RigidTransform(translation: SIMD3(0, 1.4, 0))
        if !model.isSimulatedRoom, let device = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            let t = Transform(matrix: device.originFromAnchorTransform)
            head = RigidTransform(translation: t.translation, rotation: t.rotation)
        }
        return frame.poseInFront(of: head, distance: distance)
    }
}
