import ARKit
import Combine
import Kfn8Domain
import RealityKit
import SwiftUI
import UIKit

/// iPhone/iPad room view: the shared `PlacementScene` in an `ARView`, touch input feeding the shared release pipeline,
/// a turn button beside each item, and the shared Design/Catalogue/Inventory panels in an inspector (a trailing column
/// on iPad, a resizable bottom sheet on iPhone).
struct ARRoomScreen: View {
    @Environment(AppModel.self) private var model
    @State private var controller: ARRoomController?
    @State private var showPanel = true
    /// iPhone sheet height. After an item is added it drops to half height so the new item is visible in the room.
    @State private var panelDetent = PresentationDetent.height(160)

    var body: some View {
        ZStack {
            if let controller {
                ARViewContainer(arView: controller.arView).ignoresSafeArea()
                TurnButtons(layout: controller.layout, controller: controller).ignoresSafeArea()
            } else {
                Showroom.ink.ignoresSafeArea()
            }
        }
        .overlay(alignment: .top) { statusBar }
        .inspector(isPresented: $showPanel) {
            RoomPanel(actions: actions)
                .presentationDetents([.height(160), .medium, RoomPanelDetent.tallest], selection: $panelDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
                .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        }
        .task {
            let c = ARRoomController(model: model)
            controller = c
            await c.start()
        }
        .onDisappear {
            if let controller { Task { await controller.stop() } }
            if let url = PerformanceMonitor.shared.end(placements: model.currentDesign?.placements.count ?? 0, activeLights: 0) {
                placementLog.info("performance trace written: \(url.lastPathComponent, privacy: .public)")
            }
        }
        .onChange(of: model.currentDesign?.placements.count ?? 0) { old, new in
            if new > old, panelDetent == RoomPanelDetent.tallest { panelDetent = .medium }
        }
        .onChange(of: model.sessionGeneration) { Task { await controller?.restart() } }
        .onChange(of: model.preparingDesign) { controller?.scene.preload(model.preparingDesign) }
    }

    private var actions: RoomViewActions {
        RoomViewActions(openRoomView: {}, closeRoomView: { model.isImmersiveOpen = false }, preview: { _ in })
    }

    private var statusBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let room = model.currentRoom {
                    Text(room.name).font(Showroom.display(22, relativeTo: .title3)).accessibilityAddTraits(.isHeader)
                    Text(model.alignmentText(room)).font(Showroom.ui(14, relativeTo: .subheadline))
                }
                if let controller, !controller.session.hasSceneMesh, !model.isSimulatedRoom {
                    Text("No depth sensor: only floors, walls, tables and seats are checked for collisions.")
                        .font(Showroom.ui(13, relativeTo: .caption))
                }
            }
            .foregroundStyle(Showroom.ink)
            Spacer()
            Button(showPanel ? "Hide panel" : "Show panel", systemImage: "sidebar.right") { showPanel.toggle() }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            Button("Leave room view") { model.isImmersiveOpen = false }
                .buttonStyle(BrassButtonStyle())
        }
        .padding(12)
        .background(Showroom.bone.opacity(0.85), in: .rect(cornerRadius: 16))
        .padding(.horizontal, 12)
        .tint(Showroom.brass)
    }
}

/// The shared panels, scrollable, with their own preview sheet (the inspector is itself a sheet on iPhone).
private struct RoomPanel: View {
    @Environment(AppModel.self) private var model
    let actions: RoomViewActions
    @State private var previewItem: CatalogueItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoomBanners(actions: actions)
                DesignPanel()
                CataloguePanel(openPreview: { previewItem = $0 })
                InventoryPanel()
            }
            .padding(16)
        }
        .accessibilityIdentifier("room-panel-scroll")
        .font(Showroom.ui())
        .tint(Showroom.brass)
        .sheet(item: $previewItem) { PreviewSheet(item: $0).environment(model) }
    }
}

/// The iPhone panel never covers the top bar, so Leave and the room status stay reachable at every height.
private enum RoomPanelDetent {
    static let tallest = PresentationDetent.fraction(0.78)
}

private struct ARViewContainer: UIViewRepresentable {
    let arView: ARView
    func makeUIView(context: Context) -> ARView { arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

/// Screen positions of each placed item's turn button, refreshed as the camera moves.
@MainActor
@Observable
final class TurnButtonLayout {
    var points: [PlacementID: CGPoint] = [:]
}

private struct TurnButtons: View {
    let layout: TurnButtonLayout
    let controller: ARRoomController

    var body: some View {
        ZStack {
            ForEach(Array(layout.points.keys), id: \.self) { id in
                if let point = layout.points[id] {
                    let name = controller.itemName(id)
                    Button { controller.turn(id) } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Showroom.brass)
                            .frame(width: 48, height: 48)
                            .background(Showroom.bone.opacity(0.9), in: .circle)
                    }
                    .accessibilityLabel("Turn \(name) 45 degrees")
                    .position(point)
                }
            }
        }
    }
}

/// Owns the ARView, the shared placement scene and the room session, and turns touches into the shared edit pipeline.
@MainActor
final class ARRoomController: NSObject, UIGestureRecognizerDelegate {
    let arView: ARView
    let scene: PlacementScene
    let session: ARRoomSession
    let layout = TurnButtonLayout()
    private let model: AppModel
    private var updates: (any Cancellable)?
    private var coaching: ARCoachingOverlayView?

    private struct Drag {
        var id: PlacementID
        var entity: Entity
        var planePoint: SIMD3<Float>
        var planeNormal: SIMD3<Float>
        var grabOffset: SIMD3<Float>
    }
    private var drag: Drag?
    private var twist: (id: PlacementID, entity: Entity, start: simd_quatf)?

    init(model: AppModel) {
        self.model = model
        arView = ARView(frame: .zero, cameraMode: model.isSimulatedRoom ? .nonAR : .ar, automaticallyConfigureSession: false)
        scene = PlacementScene(model: model)
        session = ARRoomSession(model: model)
        super.init()
        let anchor = AnchorEntity(world: matrix_identity_float4x4)
        anchor.addChild(scene.roomRoot)
        arView.scene.addAnchor(anchor)
        if model.isSimulatedRoom {
            // Labelled simulated room: a fixed camera at standing eye height looking toward the simulated wall.
            arView.environment.background = .color(UIColor(Showroom.paper))
            let camera = PerspectiveCamera()
            camera.look(at: SIMD3(0, 0.6, -2), from: SIMD3(0, 1.4, 1.2), relativeTo: nil)
            let cameraAnchor = AnchorEntity(world: matrix_identity_float4x4)
            cameraAnchor.addChild(camera)
            arView.scene.addAnchor(cameraAnchor)
            // The visionOS simulator supplies a virtual room; here the simulated floor and wall are drawn faintly
            // (room-local, matching `SimulatedRoom`'s surfaces) so placements can be read on screen.
            let floor = ModelEntity(mesh: .generatePlane(width: 5, depth: 5), materials: [SimpleMaterial(color: UIColor(Showroom.bone), isMetallic: false)])
            floor.position = SIMD3(0, 0, 2)
            let wall = ModelEntity(mesh: .generatePlane(width: 5, height: 2.6), materials: [SimpleMaterial(color: UIColor(Showroom.clay).withAlphaComponent(0.25), isMetallic: false)])
            wall.position = SIMD3(0, 1.3, 0)
            floor.name = "simulated-floor"; wall.name = "simulated-wall"
            scene.roomRoot.addChild(floor)
            scene.roomRoot.addChild(wall)
        } else {
            let overlay = ARCoachingOverlayView()
            overlay.session = arView.session
            overlay.goal = .tracking
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            arView.addSubview(overlay)
            coaching = overlay
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotate(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        for g in [pan, rotate, tap, doubleTap] as [UIGestureRecognizer] { g.delegate = self; arView.addGestureRecognizer(g) }
        updates = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTurnButtons() }
        }
        observeAndSync()
    }

    func start() async {
        PerformanceMonitor.shared.begin()
        model.poseInFront = { [weak self] in self?.session.poseInFront() ?? RigidTransform(translation: SIMD3(0, 0, 2)) }
        await session.start(in: arView, roomRoot: scene.roomRoot)
    }

    func restart() async {
        await session.stop()
        await session.start(in: arView, roomRoot: scene.roomRoot)
    }

    func stop() async {
        updates?.cancel()
        model.poseInFront = nil
        await session.stop()
    }

    /// Re-projects the Design whenever anything `sync()` reads changes (the RealityView `update` equivalent).
    private func observeAndSync() {
        let scene = scene
        withObservationTracking { scene.sync() } onChange: { [weak self] in
            Task { @MainActor in self?.observeAndSync() }
        }
    }

    func itemName(_ id: PlacementID) -> String {
        model.currentDesign?.placement(id).flatMap { model.item(for: $0.asset) }?.name ?? "item"
    }

    func turn(_ id: PlacementID) {
        Task { await model.rotate(id, byDegrees: TurnHandle.degreesPerTap) }
    }

    // MARK: Turn buttons

    private func refreshTurnButtons() {
        var points: [PlacementID: CGPoint] = [:]
        if scene.roomRoot.isEnabled, let design = model.currentDesign {
            let camera = arView.cameraTransform
            let forward = camera.rotation.act(SIMD3<Float>(0, 0, -1))
            for p in design.placements {
                guard let e = scene.entities[p.id], e.parent != nil, let item = model.item(for: p.asset),
                      let offset = TurnHandle.offset(for: item) else { continue }
                let world = e.convert(position: offset, to: nil)
                guard simd_dot(world - camera.translation, forward) > 0.1, let point = arView.project(world) else { continue }
                points[p.id] = point
            }
        }
        let moved = points.count != layout.points.count || points.contains { id, pt in
            guard let old = layout.points[id] else { return true }
            return abs(old.x - pt.x) > 0.5 || abs(old.y - pt.y) > 0.5
        }
        if moved { layout.points = points }
    }

    // MARK: Touch

    nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        (g is UIPanGestureRecognizer && other is UIRotationGestureRecognizer) || (g is UIRotationGestureRecognizer && other is UIPanGestureRecognizer)
    }

    private func placement(at point: CGPoint) -> (PlacementID, Entity)? {
        var e = arView.entity(at: point)
        while let current = e {
            if let tag = current.components[PlacementTag.self] { return (tag.id, current) }
            e = current.parent
        }
        return nil
    }

    @objc private func tap(_ g: UITapGestureRecognizer) {
        guard let (id, _) = placement(at: g.location(in: arView)) else { return }
        model.selection = id
    }

    @objc private func doubleTap(_ g: UITapGestureRecognizer) {
        guard placement(at: g.location(in: arView)) != nil else { return }
        model.requestFlip()
    }

    /// One finger drags on the plane the item rests on (horizontal for floor/table/ceiling items, the wall plane for
    /// wall items). Release runs the shared pipeline: attach → real collision → ≤25 cm resolution → commit, or held.
    @objc private func pan(_ g: UIPanGestureRecognizer) {
        let point = g.location(in: arView)
        switch g.state {
        case .began:
            guard let (id, e) = placement(at: point), let item = model.currentDesign?.placement(id).flatMap({ model.item(for: $0.asset) }),
                  let ray = arView.ray(through: point) else { return }
            let origin = e.position(relativeTo: nil)
            let normal: SIMD3<Float> = item.affinity == .wall ? e.convert(direction: SIMD3(0, 0, 1), to: nil) : SIMD3(0, 1, 0)
            guard let hit = Self.intersect(ray: ray, planePoint: origin, normal: normal) else { return }
            drag = Drag(id: id, entity: e, planePoint: origin, planeNormal: normal, grabOffset: origin - hit)
            model.selection = id
        case .changed:
            guard let d = drag, let ray = arView.ray(through: point),
                  let hit = Self.intersect(ray: ray, planePoint: d.planePoint, normal: d.planeNormal) else { return }
            d.entity.setPosition(hit + d.grabOffset, relativeTo: nil)
            model.dragUpdated(d.id, roomLocal: scene.roomLocal(of: d.entity))
        case .ended:
            guard let d = drag else { return }
            drag = nil
            let pose = scene.roomLocal(of: d.entity)
            Task { await model.release(d.id, roomLocal: pose) }
        default:
            guard let d = drag else { return }
            drag = nil
            model.cancel(d.id)
        }
    }

    /// Two fingers twist about the vertical axis only; no scaling (placed scale is exactly one).
    @objc private func rotate(_ g: UIRotationGestureRecognizer) {
        switch g.state {
        case .began:
            guard let (id, e) = placement(at: g.location(in: arView)) else { return }
            twist = (id, e, e.orientation(relativeTo: nil))
            model.selection = id
        case .changed:
            guard let t = twist else { return }
            let turn = simd_quatf(angle: -Float(g.rotation), axis: SIMD3(0, 1, 0))
            t.entity.setOrientation(turn * t.start, relativeTo: nil)
            model.dragUpdated(t.id, roomLocal: scene.roomLocal(of: t.entity))
        case .ended:
            guard let t = twist else { return }
            twist = nil
            let pose = scene.roomLocal(of: t.entity)
            Task { await model.release(t.id, roomLocal: pose) }
        default:
            guard let t = twist else { return }
            twist = nil
            model.cancel(t.id)
        }
    }

    private static func intersect(ray: (origin: SIMD3<Float>, direction: SIMD3<Float>), planePoint: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float>? {
        let denom = simd_dot(ray.direction, normal)
        guard abs(denom) > 1e-4 else { return nil }
        let t = simd_dot(planePoint - ray.origin, normal) / denom
        guard t > 0 else { return nil }
        return ray.origin + ray.direction * t
    }
}
