import Kfn8Domain
import RealityKit
import SwiftUI

/// Identifies a placement's root entity.
struct PlacementTag: Component { var id: PlacementID }

/// Caches one loaded template per asset; placements clone it. Loading failures are surfaced, never hidden.
@MainActor
final class ModelCache {
    private var templates: [AssetID: Entity] = [:]
    func entity(for item: CatalogueItem) async throws -> Entity {
        if let t = templates[item.id] { return t.clone(recursive: true) }
        let start = CFAbsoluteTimeGetCurrent()
        let loaded = try await Entity(contentsOf: item.modelURL)
        PerformanceMonitor.shared.recordLoad(asset: item.name, milliseconds: (CFAbsoluteTimeGetCurrent() - start) * 1000)
        templates[item.id] = loaded
        return loaded.clone(recursive: true)
    }
}

struct RoomImmersiveView: View {
    @Environment(AppModel.self) private var model
    @State private var roomRoot = Entity()
    @State private var session: RoomSession?
    @State private var cache = ModelCache()
    @State private var entities: [PlacementID: Entity] = [:]
    @State private var subscriptions: [EventSubscription] = []

    var body: some View {
        RealityView { content in
            roomRoot.name = "room-root"
            PerformanceMonitor.shared.begin()
            content.add(roomRoot)
            let s = RoomSession(model: model)
            content.add(s.meshRoot)
            session = s
            // Start here, where the session is guaranteed to exist; a separate .task could run first and find nil.
            let root = roomRoot
            Task { await s.start(roomRoot: root) }
            model.pointInFront = { [weak s] in s?.pointInFront() ?? SIMD3(0, 0, 2) }
            subscriptions = [
                content.subscribe(to: ManipulationEvents.DidUpdateTransform.self) { event in
                    guard let id = event.entity.components[PlacementTag.self]?.id else { return }
                    model.dragUpdated(id, roomLocal: roomLocal(of: event.entity))
                },
                content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
                    guard let id = event.entity.components[PlacementTag.self]?.id else { return }
                    if event.wasCancelled {
                        model.cancel(id)
                        sync()
                    } else {
                        let pose = roomLocal(of: event.entity)
                        Task { await model.release(id, roomLocal: pose); sync() }
                    }
                },
            ]
        } update: { _ in
            sync()
        }
        .onChange(of: model.sessionGeneration) {
            guard let s = session else { return }
            s.stop()
            let root = roomRoot
            Task { await s.start(roomRoot: root) }
        }
        .onDisappear {
            session?.stop()
            if let url = PerformanceMonitor.shared.end(placements: model.currentDesign?.placements.count ?? 0, activeLights: 0) {
                placementLog.info("performance trace written: \(url.lastPathComponent, privacy: .public)")
            }
            model.isImmersiveOpen = false
        }
        .onChange(of: model.currentDesign) { sync() }
        .onChange(of: model.preparingDesign) { preload(model.preparingDesign) }
        .gesture(TapGesture(count: 2).targetedToAnyEntity().onEnded { _ in model.requestFlip() })
        .onChange(of: model.previewTransforms) { sync() }
        .onChange(of: model.alignment) { sync() }
    }

    /// Loads every model of the pending Design before the flip is allowed to show it.
    private func preload(_ design: Design?) {
        guard let design else { return }
        Task {
            do {
                for p in design.placements {
                    guard let item = model.item(for: p.asset) else { continue }
                    _ = try await cache.entity(for: item)
                }
                model.flipResourcesReady(design.id)
            } catch {
                model.flipResourcesFailed(design.id, reason: error.localizedDescription)
            }
        }
    }

    private func roomLocal(of entity: Entity) -> RigidTransform {
        let t = entity.transformMatrix(relativeTo: roomRoot)
        let tr = Transform(matrix: t)
        return RigidTransform(translation: tr.translation, rotation: tr.rotation)
    }

    /// Project the committed design (+ previews) onto entities. Spatial content is withheld until alignment is verified.
    private func sync() {
        roomRoot.isEnabled = model.alignment.showsSpatialContent
        let placements = model.currentDesign?.placements ?? []
        let wanted = Set(placements.map(\.id))
        for (id, e) in entities where !wanted.contains(id) {
            e.removeFromParent()
            entities[id] = nil
        }
        for p in placements {
            if let e = entities[p.id] {
                apply(p, to: e)
            } else if let item = model.item(for: p.asset) {
                let placeholder = Entity()
                entities[p.id] = placeholder
                Task {
                    do {
                        let e = try await cache.entity(for: item)
                        configure(e, placement: p, item: item)
                        placeholder.removeFromParent()
                        roomRoot.addChild(e)
                        entities[p.id] = e
                        apply(p, to: e)
                    } catch {
                        entities[p.id] = nil
                        model.errorMessage = "Couldn't load \(item.name): \(error.localizedDescription)"
                    }
                }
            } else {
                // Asset no longer available (e.g. rights revoked): no substitute geometry, the panel shows the absence.
                continue
            }
        }
    }

    private func configure(_ e: Entity, placement p: Placement, item: CatalogueItem) {
        e.name = "placement-\(p.id)"
        e.components.set(PlacementTag(id: p.id))
        let size = item.geometry.size
        let shape = ShapeResource.generateBox(size: size).offsetBy(translation: SIMD3(0, size.y / 2, 0))
        ManipulationComponent.configureEntity(e, hoverEffect: .spotlight(.default), allowedInputTypes: .all, collisionShapes: [shape])
        var m = e.components[ManipulationComponent.self] ?? ManipulationComponent()
        m.releaseBehavior = .stay
        m.dynamics.scalingBehavior = .none // placed scale is exactly one
        e.components.set(m)
        e.components.set(GroundingShadowComponent(castsShadow: true))
        e.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))
        var accessibility = AccessibilityComponent()
        accessibility.label = LocalizedStringResource(stringLiteral: item.name)
        accessibility.isAccessibilityElement = true
        e.components.set(accessibility)
    }

    private func apply(_ p: Placement, to e: Entity) {
        let t = model.displayedTransform(p)
        e.setTransformMatrix(t.matrix, relativeTo: roomRoot)
        // Held-invalid previews are translucent; virtual overlap gets a subtler cue. Never red.
        if model.heldInvalid.contains(p.id) {
            e.components.set(OpacityComponent(opacity: 0.55))
        } else if model.overlapCues.contains(p.id) {
            e.components.set(OpacityComponent(opacity: 0.85))
        } else {
            e.components.remove(OpacityComponent.self)
        }
    }
}
