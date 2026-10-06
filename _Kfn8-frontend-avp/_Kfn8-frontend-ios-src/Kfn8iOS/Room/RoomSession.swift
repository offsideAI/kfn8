import ARKit
import AVFoundation
import Combine
import Kfn8Domain
import Observation
import RealityKit
import UIKit

/// Screen positions for the on-screen turn buttons, refreshed a few times a second while the room view is open.
@MainActor
@Observable
final class RoomOverlay {
    var turnHandles: [PlacementID: CGPoint] = [:]
}

/// Owns the ARView for one visit to the room view. On a device it runs ARKit world tracking with plane classification,
/// the LiDAR mesh where present, world-map capture and relocalization. On the simulator it shows the labelled simulated
/// room through a virtual camera. Touch input feeds the shared release pipeline.
@MainActor
final class RoomSession: NSObject, ARSessionDelegate {
    static let roomAnchorName = "kfn8-room"
    /// The simulated loss applies once per launch, so "Rescan this room" can then succeed.
    static var simulatedLossConsumed = false

    let arView: ARView
    let scene: PlacementScene
    let overlay = RoomOverlay()
    let performance = PerformanceMonitor()
    private let model: AppModel
    private let worldRoot = AnchorEntity(world: .zero)
    private var planes = CapturedPlanes()
    private var meshAnchorCount = 0
    private var alignmentTask: Task<Void, Never>?
    private var updates: (any Cancellable)?
    private var frameCounter = 0
    private var mapSavedAfterCapture = true
    private var simulatedCamera: PerspectiveCamera?
    private var drag: (id: PlacementID, plane: DragPlane, start: RigidTransform, offset: SIMD3<Float>)?
    private var twist: (id: PlacementID, start: RigidTransform)?

    init(model: AppModel) {
        self.model = model
        scene = PlacementScene(model: model)
        arView = ARView(frame: .zero, cameraMode: model.isSimulatedRoom ? .nonAR : .ar, automaticallyConfigureSession: false)
        super.init()
        arView.session.delegate = self
        worldRoot.addChild(scene.roomRoot)
        arView.scene.addAnchor(worldRoot)
        scene.cache.onLoad = { [performance] name, ms in performance.recordLoad(asset: name, milliseconds: ms) }
        updates = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.frameUpdate(delta: event.deltaTime) }
        }
        installGestures()
    }

    // MARK: Start and stop

    func start() async {
        performance.begin()
        if model.isSimulatedRoom { await startSimulated() } else { await startDevice() }
    }

    func restart() async {
        alignmentTask?.cancel()
        if !model.isSimulatedRoom { arView.session.pause() }
        planes.removeAll()
        await start()
    }

    func stop() async {
        alignmentTask?.cancel()
        if !model.isSimulatedRoom {
            // Leaving an aligned room: store a fresh world map, since more of the room has usually been seen by now.
            if model.alignment.showsSpatialContent, model.currentRoom?.frame != nil, let map = await currentWorldMap() {
                await model.updateScan(snapshot(worldMap: map))
            }
            arView.session.pause()
        }
        do {
            if let url = try performance.end(placements: model.currentDesign?.placements.count ?? 0, activeLights: model.litPlacements.count) {
                appLog.info("performance trace written: \(url.lastPathComponent, privacy: .public)")
            }
        } catch {
            model.errorMessage = "Couldn't write the performance trace: \(error.localizedDescription)"
        }
        model.realGeometryIntersects = nil
        model.poseInFront = nil
    }

    // MARK: Device

    private func startDevice() async {
        guard await cameraAllowed() else {
            model.cameraDenied = true
            return
        }
        model.cameraDenied = false
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        let hasDepth = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        if hasDepth { config.sceneReconstruction = .mesh }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) { config.frameSemantics.insert(.personSegmentationWithDepth) }
        var returningAnchor: UUID?
        if let room = model.currentRoom, room.frame != nil, let anchorID = room.sessionAnchorID {
            returningAnchor = anchorID
            if let data = await model.currentScanData(), let saved = try? JSONDecoder().decode(ScanSnapshot.self, from: data),
               let mapData = saved.worldMap,
               let map = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData) {
                config.initialWorldMap = map
            } else {
                appLog.info("no world map stored for this room; relocalization will run out of attempts")
            }
        }
        // Collision and occlusion against the LiDAR mesh. Virtual light on real surfaces waits for decision ID-3.
        arView.environment.sceneUnderstanding.options = hasDepth ? [.collision, .occlusion] : []
        arView.renderOptions.remove(.disablePersonOcclusion)
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        addCoachingOverlay()
        model.realGeometryIntersects = hasDepth ? { [weak self] box in self?.meshIntersects(box) ?? false } : { [weak model] box in
            model?.realObstacles.contains { box.realWorldContactTest.intersects($0, tolerance: 0) } ?? false
        }
        model.poseInFront = { [weak self] in self?.devicePoseInFront() ?? RigidTransform(translation: SIMD3(0, 0, 1.5)) }
        alignmentTask = Task { [weak self] in
            if let anchor = returningAnchor { await self?.relocalize(anchorID: anchor) } else { await self?.capture() }
        }
    }

    private func cameraAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    private func addCoachingOverlay() {
        guard !arView.subviews.contains(where: { $0 is ARCoachingOverlayView }) else { return }
        let coaching = ARCoachingOverlayView(frame: arView.bounds)
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.session = arView.session
        coaching.goal = .anyPlane
        coaching.activatesAutomatically = true
        arView.addSubview(coaching)
    }

    /// First visit: wait for a floor and a wall, derive the room frame, anchor it, and store the scan.
    private func capture() async {
        while !Task.isCancelled {
            if let frame = planes.deriveFrame() {
                let anchor = ARAnchor(name: Self.roomAnchorName, transform: frame.sessionFromRoom.matrix)
                arView.session.add(anchor: anchor)
                scene.roomRoot.transform = Transform(matrix: frame.sessionFromRoom.matrix)
                try? await Task.sleep(for: .milliseconds(300)) // let the anchor join the session before mapping
                let map = await currentWorldMap()
                mapSavedAfterCapture = map != nil
                await model.captureCompleted(frame: frame, surfaces: planes.roomLocalSurfaces(frame: frame),
                                             scanData: snapshot(worldMap: map), anchorID: anchor.identifier)
                model.realObstacles = planes.obstacles(frame: frame)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    /// Return visit (or after an interruption): bounded guided attempts to find the saved room anchor. Content stays
    /// hidden until it is found; after the last attempt the person chooses to rescan or review contents.
    private func relocalize(anchorID: UUID) async {
        guard let version = model.currentRoom?.frame?.version else { return }
        while !Task.isCancelled, !model.alignment.showsSpatialContent, model.alignment != .exhausted {
            let deadline = CACurrentMediaTime() + 8
            var found = false
            while CACurrentMediaTime() < deadline, !Task.isCancelled {
                if let f = arView.session.currentFrame, case .normal = f.camera.trackingState,
                   let anchor = f.anchors.first(where: { $0.identifier == anchorID }) {
                    let t = Transform(matrix: anchor.transform)
                    let frame = RoomFrame(version: version, sessionFromRoom: RigidTransform(translation: t.translation, rotation: t.rotation))
                    scene.roomRoot.transform = Transform(matrix: frame.sessionFromRoom.matrix)
                    model.alignmentVerified(frame, surfaces: planes.roomLocalSurfaces(frame: frame))
                    model.realObstacles = planes.obstacles(frame: frame)
                    found = true
                    break
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
            if !found { model.alignmentAttemptFailed() }
        }
    }

    private func currentWorldMap() async -> Data? {
        guard let status = arView.session.currentFrame?.worldMappingStatus, status == .mapped || status == .extending else { return nil }
        return await Self.archivedWorldMap(from: arView.session)
    }

    /// ARKit may call the completion on any queue, so the block must not inherit main-actor isolation (Swift 6 traps).
    nonisolated private static func archivedWorldMap(from session: ARSession) async -> Data? {
        await withCheckedContinuation { continuation in
            session.getCurrentWorldMap { map, _ in
                continuation.resume(returning: map.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) })
            }
        }
    }

    private func snapshot(worldMap: Data?) -> Data {
        let s = ScanSnapshot(capturedAt: .now, planes: planes.all, meshAnchorCount: meshAnchorCount, simulated: model.isSimulatedRoom, worldMap: worldMap)
        return (try? JSONEncoder().encode(s)) ?? Data()
    }

    private func meshIntersects(_ box: OrientedBox) -> Bool {
        guard case .verified(let frame) = model.alignment else { return false }
        let test = box.realWorldContactTest
        let pose = frame.sessionTransform(for: test.pose)
        return !arView.scene.convexCast(convexShape: .generateBox(size: test.halfSize * 2), fromPosition: pose.translation, fromOrientation: pose.rotation,
                                        toPosition: pose.translation + SIMD3(0, 0.001, 0), toOrientation: pose.rotation,
                                        query: .any, mask: .sceneUnderstanding, relativeTo: nil).isEmpty
    }

    private func devicePoseInFront() -> RigidTransform {
        guard case .verified(let frame) = model.alignment, let camera = arView.session.currentFrame?.camera.transform else {
            return RigidTransform(translation: SIMD3(0, 0, 1.5))
        }
        let t = Transform(matrix: camera)
        return frame.poseInFront(of: RigidTransform(translation: t.translation, rotation: t.rotation), distance: 1.5)
    }

    // MARK: ARSessionDelegate

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planes = anchors.compactMap(Self.plane), meshes = anchors.count { $0 is ARMeshAnchor }
        MainActor.assumeIsolated { apply(planes: planes, removed: [], meshDelta: meshes) }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let planes = anchors.compactMap(Self.plane)
        guard !planes.isEmpty else { return }
        MainActor.assumeIsolated { apply(planes: planes, removed: [], meshDelta: 0) }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = anchors.filter { $0 is ARPlaneAnchor }.map(\.identifier), meshes = anchors.count { $0 is ARMeshAnchor }
        MainActor.assumeIsolated { apply(planes: [], removed: removed, meshDelta: -meshes) }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let mapped = frame.worldMappingStatus == .mapped
        MainActor.assumeIsolated {
            // A world map that wasn't ready at capture is stored as soon as ARKit has mapped the room.
            if mapped, !mapSavedAfterCapture, model.alignment.showsSpatialContent {
                mapSavedAfterCapture = true
                Task { if let map = await currentWorldMap() { await model.updateScan(snapshot(worldMap: map)) } }
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        let text = error.localizedDescription
        MainActor.assumeIsolated { model.errorMessage = "Room tracking stopped: \(text)" }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        MainActor.assumeIsolated {
            model.statusMessage = "The camera paused. Positions will be checked again when it resumes."
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        MainActor.assumeIsolated {
            // Alignment is re-verified, never assumed, after an interruption.
            guard let anchor = model.currentRoom?.sessionAnchorID, model.currentRoom?.frame != nil else { return }
            model.statusMessage = nil
            model.alignment = .searching(attempt: 0)
            alignmentTask?.cancel()
            alignmentTask = Task { [weak self] in await self?.relocalize(anchorID: anchor) }
        }
    }

    nonisolated func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool { true }

    private func apply(planes updated: [(UUID, ScanSnapshot.Plane)], removed: [UUID], meshDelta: Int) {
        for (id, p) in updated { planes.set(p, id: id) }
        for id in removed { planes.remove(id) }
        meshAnchorCount = max(0, meshAnchorCount + meshDelta)
        if case .verified(let frame) = model.alignment, !updated.isEmpty || !removed.isEmpty {
            model.surfaces = planes.roomLocalSurfaces(frame: frame)
            model.realObstacles = planes.obstacles(frame: frame)
        }
    }

    nonisolated private static func plane(_ anchor: ARAnchor) -> (UUID, ScanSnapshot.Plane)? {
        guard let a = anchor as? ARPlaneAnchor else { return nil }
        let kind: SurfaceKind, name: String
        switch a.classification {
        case .floor: (kind, name) = (.horizontalUp, "floor")
        case .table: (kind, name) = (.horizontalUp, "table")
        case .seat: (kind, name) = (.horizontalUp, "seat")
        case .ceiling: (kind, name) = (.horizontalDown, "ceiling")
        case .wall: (kind, name) = (.vertical, "wall")
        default: return nil
        }
        let m = a.transform
        let centre = m * SIMD4(a.center, 1)
        let r = a.planeExtent.rotationOnYAxis
        let u = m * SIMD4(cos(r), 0, -sin(r), 0)
        let n = m.columns.1
        return (a.identifier, ScanSnapshot.Plane(kind: kind, classification: name, centre: SIMD3(centre.x, centre.y, centre.z),
                                                 normal: simd_normalize(SIMD3(n.x, n.y, n.z)), axisU: simd_normalize(SIMD3(u.x, u.y, u.z)),
                                                 halfExtent: SIMD2(a.planeExtent.width / 2, a.planeExtent.height / 2)))
    }

    // MARK: Simulator

    private func startSimulated() async {
        let frame = RoomFrame(sessionFromRoom: .identity)
        scene.roomRoot.transform = Transform(matrix: frame.sessionFromRoom.matrix)
        if simulatedCamera == nil { buildSimulatedRoom() }
        model.realGeometryIntersects = { box in SimulatedRoom.obstacles.contains { box.realWorldContactTest.intersects($0, tolerance: 0) } }
        model.realObstacles = SimulatedRoom.clearanceObstacles
        model.poseInFront = {
            let look = Transform(matrix: float4x4(lookingFrom: SimulatedRoom.cameraPosition, at: SimulatedRoom.cameraTarget))
            return frame.poseInFront(of: RigidTransform(translation: look.translation, rotation: look.rotation), distance: 1.5)
        }
        guard let room = model.currentRoom else { return }
        if room.frame != nil, model.options.simulateLostAlignment, !Self.simulatedLossConsumed {
            Self.simulatedLossConsumed = true
            for _ in 0..<AlignmentState.maximumGuidedAttempts {
                try? await Task.sleep(for: .milliseconds(600))
                model.alignmentAttemptFailed()
            }
            return
        }
        if room.frame == nil {
            let s = ScanSnapshot(capturedAt: .now, planes: SimulatedRoom.surfaces.map {
                .init(kind: $0.kind, classification: $0.isFloor ? "floor" : ($0.kind == .vertical ? "wall" : ($0.kind == .horizontalDown ? "ceiling" : "table")),
                      centre: $0.centre, normal: $0.normal, axisU: SIMD3(1, 0, 0), halfExtent: $0.halfExtent)
            }, meshAnchorCount: 0, simulated: true, worldMap: nil)
            await model.captureCompleted(frame: frame, surfaces: SimulatedRoom.surfaces, scanData: (try? JSONEncoder().encode(s)) ?? Data(), anchorID: nil)
        } else {
            model.alignmentVerified(frame, surfaces: SimulatedRoom.surfaces)
        }
    }

    private func buildSimulatedRoom() {
        arView.environment.background = .color(UIColor(red: 0.937, green: 0.914, blue: 0.867, alpha: 1))
        let camera = PerspectiveCamera()
        camera.look(at: SimulatedRoom.cameraTarget, from: SimulatedRoom.cameraPosition, relativeTo: nil)
        worldRoot.addChild(camera)
        simulatedCamera = camera
        let sun = DirectionalLight()
        sun.light.intensity = 2500
        sun.look(at: .zero, from: SimulatedRoom.cameraPosition + SIMD3(1, 3, 0), relativeTo: nil)
        worldRoot.addChild(sun)
        let faint = SimpleMaterial(color: UIColor(white: 0.62, alpha: 0.35), roughness: 1, isMetallic: false)
        let floor = ModelEntity(mesh: .generatePlane(width: 5, depth: 5), materials: [faint])
        floor.position = SIMD3(0, 0, 2)
        let wall = ModelEntity(mesh: .generatePlane(width: 5, height: 2.6), materials: [faint])
        wall.position = SIMD3(0, 1.3, 0)
        let table = ModelEntity(mesh: .generateBox(size: SimulatedRoom.table.halfSize * 2), materials: [faint])
        table.position = SimulatedRoom.table.pose.translation
        for e in [floor, wall, table] { e.name = "simulated-room"; worldRoot.addChild(e) }
    }

    // MARK: Frames and turn buttons

    private func frameUpdate(delta: Double) {
        performance.frame(delta: delta)
        frameCounter += 1
        guard frameCounter % 6 == 0 else { return }
        var handles: [PlacementID: CGPoint] = [:]
        if model.alignment.showsSpatialContent, let design = model.currentDesign {
            let bounds = arView.bounds
            for p in design.placements {
                guard scene.entities[p.id]?.components[PlacementTag.self] != nil, let item = model.item(for: p.asset),
                      let offset = TurnHandle.offset(for: item) else { continue }
                let local = model.displayedTransform(p).apply(offset)
                let world = scene.roomRoot.convert(position: local, to: nil)
                if let point = arView.project(world), bounds.insetBy(dx: 24, dy: 24).contains(point) { handles[p.id] = point }
            }
        }
        if handles != overlay.turnHandles { overlay.turnHandles = handles }
    }

    // MARK: Touch

    private func installGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleTwist(_:)))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.require(toFail: doubleTap)
        for g in [pan, rotate, doubleTap, tap] as [UIGestureRecognizer] { arView.addGestureRecognizer(g) }
    }

    private func placementID(at point: CGPoint) -> PlacementID? {
        var e = arView.entity(at: point)
        while let current = e {
            if let tag = current.components[PlacementTag.self] { return tag.id }
            e = current.parent
        }
        return nil
    }

    /// The touch ray in room-local coordinates.
    private func roomRay(_ point: CGPoint) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? {
        guard let ray = arView.ray(through: point) else { return nil }
        let toRoom = scene.roomRoot.transformMatrix(relativeTo: nil).inverse
        let o = toRoom * SIMD4(ray.origin, 1), d = toRoom * SIMD4(ray.direction, 0)
        return (SIMD3(o.x, o.y, o.z), SIMD3(d.x, d.y, d.z))
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let point = g.location(in: arView)
        switch g.state {
        case .began:
            guard model.alignment.showsSpatialContent, let id = placementID(at: point), let p = model.currentDesign?.placement(id),
                  let item = model.item(for: p.asset), let ray = roomRay(point) else { drag = nil; return }
            let start = model.displayedTransform(p)
            let plane = DragPlane.forItem(affinity: item.affinity, at: start)
            let grab = plane.intersect(origin: ray.origin, direction: ray.direction) ?? start.translation
            model.selection = id
            drag = (id, plane, start, grab - start.translation)
        case .changed:
            guard let d = drag, let ray = roomRay(point), let hit = d.plane.intersect(origin: ray.origin, direction: ray.direction) else { return }
            model.dragUpdated(d.id, roomLocal: d.plane.dragged(d.start, toward: hit - d.offset))
            scene.sync()
        case .ended:
            guard let d = drag else { return }
            drag = nil
            let released = model.previewTransforms[d.id] ?? d.start
            Task { await model.release(d.id, roomLocal: released); scene.sync() }
        case .cancelled, .failed:
            if let d = drag { model.cancel(d.id); scene.sync() }
            drag = nil
        default: break
        }
    }

    /// Two-finger twist turns the item about its vertical axis. Wall items always face out of the wall.
    @objc private func handleTwist(_ g: UIRotationGestureRecognizer) {
        switch g.state {
        case .began:
            let id = placementID(at: g.location(in: arView)) ?? model.selection
            guard model.alignment.showsSpatialContent, let id, let p = model.currentDesign?.placement(id),
                  model.item(for: p.asset)?.affinity != .wall else { twist = nil; return }
            model.selection = id
            twist = (id, model.displayedTransform(p))
        case .changed:
            guard let t = twist else { return }
            let turn = simd_quatf(angle: -Float(g.rotation), axis: SIMD3(0, 1, 0)) // screen clockwise = clockwise from above
            model.dragUpdated(t.id, roomLocal: RigidTransform(translation: t.start.translation, rotation: turn * t.start.rotation))
            scene.sync()
        case .ended:
            guard let t = twist else { return }
            twist = nil
            let released = model.previewTransforms[t.id] ?? t.start
            Task { await model.release(t.id, roomLocal: released); scene.sync() }
        case .cancelled, .failed:
            if let t = twist { model.cancel(t.id); scene.sync() }
            twist = nil
        default: break
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let id = placementID(at: g.location(in: arView))
        model.selection = (id == model.selection) ? nil : id
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) { model.requestFlip() }
}

private extension float4x4 {
    /// A camera pose at `eye` whose −Z looks at `target`, with +Y up.
    init(lookingFrom eye: SIMD3<Float>, at target: SIMD3<Float>) {
        let back = simd_normalize(eye - target)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), back))
        let up = simd_cross(back, right)
        self.init(SIMD4(right, 0), SIMD4(up, 0), SIMD4(back, 0), SIMD4(eye, 1))
    }
}
