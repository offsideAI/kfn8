import Kfn8Domain
import RealityKit
import SwiftUI

/// visionOS room view: the shared `PlacementScene` in a Mixed Immersive Space, with ManipulationComponent input, an
/// in-room turn button per item, and occlusion by the real surroundings.
struct RoomImmersiveView: View {
    @Environment(AppModel.self) private var model
    @State private var scene: PlacementScene?
    @State private var session: RoomSession?
    @State private var subscriptions: [EventSubscription] = []

    var body: some View {
        RealityView { content in
            let scene = PlacementScene(model: model)
            scene.configureInput = { [model] e, p, item, shape in
                ManipulationComponent.configureEntity(e, hoverEffect: .spotlight(.default), allowedInputTypes: .all, collisionShapes: [shape])
                var m = e.components[ManipulationComponent.self] ?? ManipulationComponent()
                m.releaseBehavior = .stay
                m.dynamics.scalingBehavior = .none // placed scale is exactly one
                e.components.set(m)
                e.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))
                if let handle = Self.turnHandle(for: p.id, item: item, model: model) { e.addChild(handle) }
            }
            self.scene = scene
            PerformanceMonitor.shared.begin()
            content.add(scene.roomRoot)
            let s = RoomSession(model: model)
            content.add(s.meshRoot)
            session = s
            // Start here, where the session is guaranteed to exist; a separate .task could run first and find nil.
            let root = scene.roomRoot
            Task { await s.start(roomRoot: root) }
            model.poseInFront = { [weak s] in s?.poseInFront() ?? RigidTransform(translation: SIMD3(0, 0, 2)) }
            subscriptions = [
                content.subscribe(to: ManipulationEvents.DidUpdateTransform.self) { event in
                    guard let id = event.entity.components[PlacementTag.self]?.id else { return }
                    model.dragUpdated(id, roomLocal: scene.roomLocal(of: event.entity))
                },
                content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
                    guard let id = event.entity.components[PlacementTag.self]?.id else { return }
                    if event.wasCancelled {
                        model.cancel(id)
                        scene.sync()
                    } else {
                        let pose = scene.roomLocal(of: event.entity)
                        Task { await model.release(id, roomLocal: pose); scene.sync() }
                    }
                },
            ]
        } update: { _ in
            scene?.sync()
        }
        .onChange(of: model.sessionGeneration) {
            guard let s = session, let root = scene?.roomRoot else { return }
            s.stop()
            Task { await s.start(roomRoot: root) }
        }
        .onDisappear {
            session?.stop()
            if let url = PerformanceMonitor.shared.end(placements: model.currentDesign?.placements.count ?? 0, activeLights: 0) {
                placementLog.info("performance trace written: \(url.lastPathComponent, privacy: .public)")
            }
            model.isImmersiveOpen = false
        }
        .onChange(of: model.currentDesign) { scene?.sync() }
        .onChange(of: model.preparingDesign) { scene?.preload(model.preparingDesign) }
        .gesture(TapGesture(count: 2).targetedToAnyEntity().onEnded { _ in model.requestFlip() })
        .onChange(of: model.previewTransforms) { scene?.sync() }
        .onChange(of: model.alignment) { scene?.sync() }
    }

    /// In-room turn button: 45° clockwise per tap through the same release pipeline as the window's Rotate buttons
    /// (so Undo covers it). Billboarded so it always faces the viewer.
    private static func turnHandle(for id: PlacementID, item: CatalogueItem, model: AppModel) -> Entity? {
        guard let offset = TurnHandle.offset(for: item) else { return nil }
        let handle = Entity()
        handle.name = "turn-handle-\(id)"
        handle.position = offset
        handle.components.set(BillboardComponent())
        handle.components.set(ViewAttachmentComponent(rootView: TurnHandleView(name: item.name) {
            Task { await model.rotate(id, byDegrees: TurnHandle.degreesPerTap) }
        }))
        return handle
    }
}

/// The in-room turn button. Large enough to target by gaze at the default 2.4 m placement distance.
private struct TurnHandleView: View {
    let name: String
    let turn: () -> Void

    var body: some View {
        Button(action: turn) {
            Image(systemName: "rotate.right")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Showroom.brass)
                .frame(width: 96, height: 96)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .glassBackgroundEffect(in: .circle)
        .hoverEffect()
        .accessibilityLabel("Turn \(name) 45 degrees")
        .help("Turn 45°")
    }
}
