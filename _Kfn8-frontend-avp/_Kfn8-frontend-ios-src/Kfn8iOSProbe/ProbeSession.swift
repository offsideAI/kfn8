import ARKit
import Combine
import Kfn8Domain
import Kfn8iOSProbeCore
import Photos
import RealityKit
import SwiftUI
import UIKit

/// Owns the ARView and its ARSession for the probe: world tracking with plane classification, the LiDAR mesh where
/// present, and the probe objects (relocalization marker, collision/occlusion box, lamp). Every failure is reported to
/// the model; nothing is swallowed.
@MainActor
final class ProbeSession: NSObject, ARSessionDelegate {
    nonisolated static let markerName = "kfn8-probe-marker"
    /// A chair-sized box: big enough to hide behind real furniture and to test resting contact.
    static let boxSize = SIMD3<Float>(0.6, 0.8, 0.6)

    let arView: ARView
    private let model: ProbeModel
    private var updates: (any Cancellable)?
    private var markerEntity: AnchorEntity?
    private var boxRoot: AnchorEntity?
    private var boxModel: ModelEntity?
    private var lampRoot: AnchorEntity?
    private var lampLight: PointLightComponent?
    private var lastPlaneSummary = ""

    init(model: ProbeModel) {
        self.model = model
        arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        super.init()
        arView.session.delegate = self
        updates = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.frameTick(delta: event.deltaTime) }
        }
        arView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragBox(_:))))
    }

    // MARK: Session

    func run(initialMap: ARWorldMap? = nil) {
        guard ARWorldTrackingConfiguration.isSupported else {
            model.fail("World tracking isn't supported here (simulator). The probe needs a physical iPhone or iPad.")
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = model.environmentTexturing ? .automatic : .none
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) { config.sceneReconstruction = .mesh }
        if model.peopleOcclusion, ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        config.initialWorldMap = initialMap
        arView.session.run(config, options: initialMap == nil ? [] : [.resetTracking, .removeExistingAnchors])
        applyRenderOptions()
    }

    func applyRenderOptions() {
        var options: ARView.Environment.SceneUnderstanding.Options = [.collision]
        if model.sceneOcclusion { options.insert(.occlusion) }
        if model.meshReceivesLighting { options.insert(.receivesLighting) }
        arView.environment.sceneUnderstanding.options = options
        if model.peopleOcclusion { arView.renderOptions.remove(.disablePersonOcclusion) } else { arView.renderOptions.insert(.disablePersonOcclusion) }
    }

    private func frameTick(delta: Double) {
        model.frame(delta: delta)
        model.relocalization.tick(at: CACurrentMediaTime())
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let tracking = Self.describe(frame.camera.trackingState)
        let mapping = Self.describe(frame.worldMappingStatus)
        let ambient = frame.lightEstimate.map { Double($0.ambientIntensity) }
        MainActor.assumeIsolated {
            if model.tracking != tracking { model.tracking = tracking }
            if model.mapping != mapping { model.mapping = mapping }
            if let ambient, abs((model.ambientIntensity ?? 0) - ambient) > 50 { model.ambientIntensity = ambient }
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let markerReturned = anchors.contains { $0.name == Self.markerName }
        MainActor.assumeIsolated {
            if markerReturned, let marker = anchors.first(where: { $0.name == Self.markerName }) {
                attachMarkerEntity(to: marker)
                model.relocalization.markerRestored(at: CACurrentMediaTime())
            }
            recountAnchors()
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        MainActor.assumeIsolated { recountAnchors() }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        MainActor.assumeIsolated { recountAnchors() }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        let text = error.localizedDescription
        MainActor.assumeIsolated { model.fail("AR session failed: \(text)") }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        MainActor.assumeIsolated { model.interruptions += 1; model.note("session interrupted") }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        MainActor.assumeIsolated { model.note("session interruption ended") }
    }

    private func recountAnchors() {
        let anchors = arView.session.currentFrame?.anchors ?? []
        var counts: [String: Int] = [:]
        var meshes = 0
        for a in anchors {
            if let plane = a as? ARPlaneAnchor { counts[Self.describe(plane.classification), default: 0] += 1 }
            if a is ARMeshAnchor { meshes += 1 }
        }
        let summary = counts.isEmpty ? "No planes yet" : counts.sorted { $0.key < $1.key }.map { "\($0.value) \($0.key)" }.joined(separator: ", ")
        if summary != lastPlaneSummary { lastPlaneSummary = summary; model.planeSummary = summary }
        if model.meshAnchorCount != meshes { model.meshAnchorCount = meshes }
    }

    // MARK: T3 Relocalization

    func placeMarker() {
        guard let hit = raycastFromCentre(alignment: .horizontal) else {
            model.message = "Point at the floor or a table until planes appear, then try again."
            return
        }
        for old in arView.session.currentFrame?.anchors.filter({ $0.name == Self.markerName }) ?? [] { arView.session.remove(anchor: old) }
        markerEntity?.removeFromParent()
        markerEntity = nil
        arView.session.add(anchor: ARAnchor(name: Self.markerName, transform: hit.worldTransform))
        model.markerPlaced = true
    }

    private func attachMarkerEntity(to anchor: ARAnchor) {
        markerEntity?.removeFromParent()
        let entity = AnchorEntity(anchor: anchor)
        let cone = ModelEntity(mesh: .generateCone(height: 0.25, radius: 0.08), materials: [UnlitMaterial(color: UIColor(Self.brass))])
        cone.position.y = 0.125
        entity.addChild(cone)
        arView.scene.addAnchor(entity)
        markerEntity = entity
    }

    func saveMap() {
        guard let status = arView.session.currentFrame?.worldMappingStatus, status == .mapped || status == .extending else {
            model.message = "Keep moving slowly around the room until mapping says Extending or Mapped."
            return
        }
        let model = self.model
        Task { @MainActor in
            switch await Self.archivedWorldMap(from: arView.session) {
            case .success(let data):
                do {
                    try data.write(to: ProbeModel.worldMapURL, options: .atomic)
                    model.savedMapBytes = data.count
                    model.message = "Saved the room map (\(data.count / 1024) KB). Quit and reopen the probe, then tap Find room."
                } catch { model.fail("Couldn't write the room map: \(error.localizedDescription)") }
            case .failure(let error):
                model.fail("Couldn't get the room map: \(error.localizedDescription)")
            }
        }
    }

    /// ARKit may call the completion on any queue, so the block must not inherit main-actor isolation (Swift 6 traps).
    nonisolated private static func archivedWorldMap(from session: ARSession) async -> Result<Data, any Error> {
        await withCheckedContinuation { continuation in
            session.getCurrentWorldMap { map, error in
                if let map {
                    continuation.resume(returning: Result { try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) })
                } else {
                    continuation.resume(returning: .failure(error ?? CocoaError(.fileWriteUnknown)))
                }
            }
        }
    }

    func relocalize() {
        let map: ARWorldMap
        do {
            let data = try Data(contentsOf: ProbeModel.worldMapURL)
            guard let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                model.fail("The saved room map is empty.")
                return
            }
            map = decoded
            model.savedMapBytes = data.count
        } catch {
            model.fail("No saved room map to load: \(error.localizedDescription)")
            return
        }
        markerEntity?.removeFromParent()
        markerEntity = nil
        model.markerPlaced = false
        model.relocalization.start(at: CACurrentMediaTime())
        run(initialMap: map)
    }

    // MARK: T4 Collision and occlusion box

    func placeBox() {
        guard let hit = raycastFromCentre(alignment: .horizontal) else {
            model.message = "Point at the floor until planes appear, then try again."
            return
        }
        boxRoot?.removeFromParent()
        let root = AnchorEntity(world: .zero)
        let pivot = Entity()
        let box = ModelEntity(mesh: .generateBox(size: Self.boxSize, cornerRadius: 0.02),
                              materials: [SimpleMaterial(color: UIColor(Self.clay), roughness: 0.6, isMetallic: false)])
        box.position.y = Self.boxSize.y / 2 // base-centre pivot, like every catalogue asset
        pivot.addChild(box)
        root.addChild(pivot)
        arView.scene.addAnchor(root)
        boxRoot = root
        boxModel = box
        moveBox(to: SIMD3(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z))
        model.boxPlaced = true
    }

    /// Nudges the box in the camera's floor-plane frame (forward = away from the person).
    func nudgeBox(right: Float, forward: Float) {
        guard let root = boxRoot, let cam = arView.session.currentFrame?.camera.transform else { return }
        var f = -SIMD3(cam.columns.2.x, 0, cam.columns.2.z)
        var r = SIMD3(cam.columns.0.x, 0, cam.columns.0.z)
        if simd_length(f) > 1e-4 { f = simd_normalize(f) }
        if simd_length(r) > 1e-4 { r = simd_normalize(r) }
        moveBox(to: root.position(relativeTo: nil) + r * right + f * forward)
    }

    @objc private func dragBox(_ g: UIPanGestureRecognizer) {
        guard boxRoot != nil else { return }
        let point = g.location(in: arView)
        guard let hit = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first else { return }
        moveBox(to: SIMD3(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z))
    }

    private func moveBox(to position: SIMD3<Float>) {
        guard let root = boxRoot else { return }
        root.setPosition(position, relativeTo: nil)
        if let cam = arView.session.currentFrame?.camera.transform {
            let yaw = atan2(cam.columns.3.x - position.x, cam.columns.3.z - position.z)
            root.setOrientation(simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)), relativeTo: nil)
        }
        testContact()
    }

    /// Sweeps the box against the reconstructed room mesh twice: with the shared support-contact tolerance (what the app
    /// will use) and at full size (what failed on the Vision Pro), so the evidence shows why the tolerance exists.
    func testContact() {
        guard let root = boxRoot else { return }
        let pose = RigidTransform(translation: root.position(relativeTo: nil), rotation: root.orientation(relativeTo: nil))
        let full = OrientedBox(basePivot: pose, size: Self.boxSize)
        let tolerant = hitsRealGeometry(full.realWorldContactTest)
        model.contactWithTolerance = tolerant
        model.contactFullSize = hitsRealGeometry(full)
        // Never red: blocked shows as translucent, like a held invalid placement in the app.
        boxModel?.components.set(OpacityComponent(opacity: tolerant ? 0.45 : 1))
    }

    private func hitsRealGeometry(_ box: OrientedBox) -> Bool {
        let shape = ShapeResource.generateBox(size: box.halfSize * 2)
        return !arView.scene.convexCast(convexShape: shape, fromPosition: box.pose.translation, fromOrientation: box.pose.rotation,
                                        toPosition: box.pose.translation + SIMD3(0, 0.001, 0), toOrientation: box.pose.rotation,
                                        query: .any, mask: .sceneUnderstanding, relativeTo: nil).isEmpty
    }

    // MARK: T5 Lamp

    func placeLamp() {
        guard let hit = raycastFromCentre(alignment: .vertical) else {
            model.message = "Point at a wall until it is detected, then try again."
            return
        }
        lampRoot?.removeFromParent()
        let normal = simd_normalize(SIMD3(hit.worldTransform.columns.1.x, hit.worldTransform.columns.1.y, hit.worldTransform.columns.1.z))
        let onWall = SIMD3(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z)
        let root = AnchorEntity(world: onWall + normal * 0.35)
        let bulb = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [UnlitMaterial(color: UIColor(Self.brass))])
        root.addChild(bulb)
        arView.scene.addAnchor(root)
        lampRoot = root
        model.lampPlaced = true
        setLamp(on: true)
    }

    func setLamp(on: Bool) {
        guard let root = lampRoot else { return }
        model.lampOn = on
        root.components.set(PointLightComponent(cgColor: UIColor(red: 1, green: 0.85, blue: 0.65, alpha: 1).cgColor,
                                                intensity: on ? model.lampIntensity : 0, attenuationRadius: 4))
    }

    // MARK: T6 Photo

    func capturePhoto() {
        guard model.photo.beginCapture() else { return }
        let model = self.model
        // @Sendable: the completion must not be main-actor isolated, whichever queue RealityKit calls it on.
        arView.snapshot(saveToHDR: false) { @Sendable image in
            let png = image?.pngData()
            Task { @MainActor in
                guard let png else { model.photo.captureFailed("the AR view returned no image"); return }
                let url = ProbeModel.documents.appending(path: "probe-photo-\(Int(Date().timeIntervalSince1970)).png")
                do { try png.write(to: url, options: .atomic) } catch {
                    model.photo.captureFailed("couldn't write the photo: \(error.localizedDescription)")
                    return
                }
                model.lastPhotoURL = url
                model.photo.captured(bytes: png.count)
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else { model.photo.photosResult(saved: false); return }
                do {
                    try await Self.addToPhotos(png)
                    model.photo.photosResult(saved: true)
                } catch {
                    model.photo.photosResult(saved: false)
                    model.fail("Photos refused the image: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Photos runs the change block on its own queue; a main-actor-isolated block traps at runtime under Swift 6.
    nonisolated private static func addToPhotos(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }

    // MARK: Helpers

    private func raycastFromCentre(alignment: ARRaycastQuery.TargetAlignment) -> ARRaycastResult? {
        let centre = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        return arView.raycast(from: centre, allowing: .existingPlaneGeometry, alignment: alignment).first
    }

    static let brass = Color(red: 0.722, green: 0.573, blue: 0.290)
    static let clay = Color(red: 0.690, green: 0.502, blue: 0.408)

    nonisolated static func describe(_ s: ARCamera.TrackingState) -> String {
        switch s {
        case .normal: "Normal"
        case .notAvailable: "Not available"
        case .limited(.initializing): "Limited: initializing"
        case .limited(.relocalizing): "Limited: relocalizing"
        case .limited(.excessiveMotion): "Limited: moving too fast"
        case .limited(.insufficientFeatures): "Limited: not enough detail"
        case .limited: "Limited"
        }
    }

    nonisolated static func describe(_ s: ARFrame.WorldMappingStatus) -> String {
        switch s {
        case .notAvailable: "Not available"
        case .limited: "Limited"
        case .extending: "Extending"
        case .mapped: "Mapped"
        @unknown default: "Unknown"
        }
    }

    nonisolated static func describe(_ c: ARPlaneAnchor.Classification) -> String {
        switch c {
        case .floor: "floor"
        case .wall: "wall"
        case .ceiling: "ceiling"
        case .table: "table"
        case .seat: "seat"
        case .window: "window"
        case .door: "door"
        case .none: "unclassified"
        @unknown default: "other"
        }
    }
}
