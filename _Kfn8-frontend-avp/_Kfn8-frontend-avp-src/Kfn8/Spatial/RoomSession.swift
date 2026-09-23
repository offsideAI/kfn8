import ARKit
import Foundation
import Kfn8Domain
import QuartzCore
import RealityKit
import simd

/// Structured elements from one capture, stored locally as the scan file. Never uploaded.
struct ScanSnapshot: Codable, Sendable {
    struct Plane: Codable, Sendable { var kind: String; var classification: String; var centre: [Float]; var normal: [Float]; var halfExtent: [Float] }
    var capturedAt: Date
    var planes: [Plane]
    var meshAnchorCount: Int
    var simulated: Bool
}

/// Owns ARKit providers on device, or the labelled synthetic room on the simulator. Produces room-local surfaces,
/// derives the room frame on first capture, and verifies alignment on return visits (bounded guided attempts).
@MainActor
final class RoomSession {
    private let model: AppModel
    // Providers cannot be re-run after a stop, so each start gets fresh instances.
    private var session = ARKitSession()
    private var planes = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
    private var world = WorldTrackingProvider()
    private var meshes = SceneReconstructionProvider()
    private var sessionPlanes: [UUID: ScanSnapshot.Plane] = [:]
    private(set) var meshEntities: [UUID: Entity] = [:]
    let meshRoot = Entity()
    private var tasks: [Task<Void, Never>] = []
    static let realWorldGroup = CollisionGroup(rawValue: 1 << 1)
    /// The simulated loss applies once per launch so "Rescan this room" can then succeed.
    nonisolated(unsafe) static var simulatedLossConsumed = false

    init(model: AppModel) { self.model = model }

    static var isARKitAvailable: Bool {
        PlaneDetectionProvider.isSupported && WorldTrackingProvider.isSupported && SceneReconstructionProvider.isSupported
    }

    func start(roomRoot: Entity) async {
        if model.isSimulatedRoom {
            await startSimulated(roomRoot: roomRoot)
            return
        }
        session = ARKitSession()
        planes = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
        world = WorldTrackingProvider()
        meshes = SceneReconstructionProvider()
        sessionPlanes = [:]
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
            let shape = ShapeResource.generateBox(size: box.halfSize * 2)
            let hits = scene.convexCast(convexShape: shape, fromPosition: box.pose.translation, fromOrientation: box.pose.rotation,
                                        toPosition: box.pose.translation + SIMD3(0, 0.001, 0), toOrientation: box.pose.rotation,
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
        if update.event == .removed { sessionPlanes[a.id] = nil; refreshSurfaces(); return }
        let kind: SurfaceKind
        switch a.surfaceClassification {
        case .floor, .table, .seat, .bed: kind = .horizontalUp
        case .ceiling: kind = .horizontalDown
        case .wall: kind = .vertical
        default: return
        }
        let m = a.originFromAnchorTransform * a.geometry.extent.anchorFromExtentTransform
        let n = a.originFromAnchorTransform.columns.1
        sessionPlanes[a.id] = .init(kind: kind.rawValue, classification: String(describing: a.surfaceClassification),
                                    centre: [m.columns.3.x, m.columns.3.y, m.columns.3.z], normal: [n.x, n.y, n.z],
                                    halfExtent: [a.geometry.extent.width / 2, a.geometry.extent.height / 2])
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
                        model.alignmentVerified(verified, surfaces: roomLocalSurfaces(frame: verified))
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
            if let (frame, _) = deriveFrame() {
                let anchor = WorldAnchor(originFromAnchorTransform: frame.sessionFromRoom.matrix)
                do { try await world.addAnchor(anchor) } catch {
                    model.errorMessage = "Couldn't anchor the room: \(error.localizedDescription)"
                    return
                }
                roomRoot.setTransformMatrix(frame.sessionFromRoom.matrix, relativeTo: nil)
                let snapshot = ScanSnapshot(capturedAt: .now, planes: Array(sessionPlanes.values), meshAnchorCount: meshEntities.count, simulated: false)
                await model.captureCompleted(frame: frame, surfaces: roomLocalSurfaces(frame: frame),
                                             scanData: (try? JSONEncoder().encode(snapshot)) ?? Data(), anchorID: anchor.id)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func deriveFrame() -> (RoomFrame, ScanSnapshot.Plane)? {
        let all = Array(sessionPlanes.values)
        guard let floor = all.filter({ $0.classification.contains("floor") }).max(by: { $0.halfExtent[0] * $0.halfExtent[1] < $1.halfExtent[0] * $1.halfExtent[1] }),
              let wall = all.filter({ $0.kind == SurfaceKind.vertical.rawValue }).max(by: { $0.halfExtent[0] < $1.halfExtent[0] }),
              wall.halfExtent[0] > 0.5,
              let frame = try? RoomFrame.derive(floorHeight: floor.centre[1], wallPoint: SIMD3(wall.centre[0], wall.centre[1], wall.centre[2]),
                                                wallNormal: SIMD3(wall.normal[0], wall.normal[1], wall.normal[2])) else { return nil }
        return (frame, wall)
    }

    private func refreshSurfaces() {
        if case .verified(let frame) = model.alignment { model.surfaces = roomLocalSurfaces(frame: frame) }
    }

    private func roomLocalSurfaces(frame: RoomFrame) -> [Surface] {
        let inv = frame.sessionFromRoom.inverse
        return sessionPlanes.map { id, p in
            let c = inv.apply(SIMD3(p.centre[0], p.centre[1], p.centre[2]))
            let n = inv.rotation.act(SIMD3(p.normal[0], p.normal[1], p.normal[2]))
            return Surface(id: id, kind: SurfaceKind(rawValue: p.kind) ?? .horizontalUp, centre: c, normal: n,
                           halfExtent: SIMD2(p.halfExtent[0], p.halfExtent[1]), isFloor: p.classification.contains("floor"))
        }
    }

    /// Room-local point `distance` metres in front of the user, for new placements. The default is beyond the main
    /// window (≈1–1.5 m) so new items never sit between the user and the window's controls and steal its taps.
    func pointInFront(distance: Float = 2.4) -> SIMD3<Float> {
        guard case .verified(let frame) = model.alignment else { return SIMD3(0, 0, 2) }
        var head = RigidTransform(translation: SIMD3(0, 1.4, 0))
        if !model.isSimulatedRoom, let device = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            let t = Transform(matrix: device.originFromAnchorTransform)
            head = RigidTransform(translation: t.translation, rotation: t.rotation)
        }
        var forward = head.rotation.act(SIMD3<Float>(0, 0, -1))
        forward.y = 0
        forward = simd_length(forward) > 0.01 ? simd_normalize(forward) : SIMD3(0, 0, -1)
        return frame.roomLocal(from: RigidTransform(translation: head.translation + forward * distance)).translation
    }

    // MARK: Simulator

    /// Synthetic room for the visionOS simulator only (ARKit reports unsupported there). Clearly labelled in the UI;
    /// never compiled into a claim of device behaviour. Wall 3.2 m ahead, 2.6 m ceiling, one table as a real obstacle.
    private func startSimulated(roomRoot: Entity) async {
        let frame = RoomFrame(sessionFromRoom: RigidTransform(translation: SIMD3(0, 0, -3.2)))
        roomRoot.setTransformMatrix(frame.sessionFromRoom.matrix, relativeTo: nil)
        let table = OrientedBox(basePivot: RigidTransform(translation: SIMD3(1.1, 0, 1.4)), size: SIMD3(1.0, 0.74, 0.6))
        let surfaces = [
            Surface(kind: .horizontalUp, centre: SIMD3(0, 0, 2), normal: SIMD3(0, 1, 0), halfExtent: SIMD2(2.5, 2.5), isFloor: true),
            Surface(kind: .vertical, centre: SIMD3(0, 1.3, 0), normal: SIMD3(0, 0, 1), halfExtent: SIMD2(2.5, 1.3)),
            Surface(kind: .horizontalDown, centre: SIMD3(0, 2.6, 2), normal: SIMD3(0, -1, 0), halfExtent: SIMD2(2.5, 2.5)),
            Surface(kind: .horizontalUp, centre: SIMD3(1.1, 0.74, 1.4), normal: SIMD3(0, 1, 0), halfExtent: SIMD2(0.5, 0.3)),
        ]
        model.realGeometryIntersects = { box in box.intersects(table) }
        let tableEntity = ModelEntity(mesh: .generateBox(size: SIMD3(1.0, 0.74, 0.6)), materials: [SimpleMaterial(color: .init(white: 0.55, alpha: 0.35), isMetallic: false)])
        tableEntity.position = SIMD3(1.1, 0.37, 1.4)
        tableEntity.name = "simulated-table"
        roomRoot.addChild(tableEntity)
        guard let room = model.currentRoom else { return }
        if room.frame != nil, ProcessInfo.processInfo.arguments.contains("--simulate-lost-alignment"), !RoomSession.simulatedLossConsumed {
            // Simulator-only test switch: the returning room is not found, so the bounded guided attempts run out.
            RoomSession.simulatedLossConsumed = true
            for _ in 0..<AlignmentState.maximumGuidedAttempts {
                try? await Task.sleep(for: .milliseconds(600))
                model.alignmentAttemptFailed()
            }
            return
        }
        if room.frame == nil {
            let snapshot = ScanSnapshot(capturedAt: .now, planes: surfaces.map {
                .init(kind: $0.kind.rawValue, classification: $0.isFloor ? "floor" : $0.kind.rawValue, centre: [$0.centre.x, $0.centre.y, $0.centre.z],
                      normal: [$0.normal.x, $0.normal.y, $0.normal.z], halfExtent: [$0.halfExtent.x, $0.halfExtent.y])
            }, meshAnchorCount: 0, simulated: true)
            await model.captureCompleted(frame: frame, surfaces: surfaces, scanData: (try? JSONEncoder().encode(snapshot)) ?? Data(), anchorID: nil)
        } else {
            model.alignmentVerified(frame, surfaces: surfaces)
        }
    }
}
