import Kfn8Domain
import RealityKit
import UIKit

/// Identifies a placement's root entity.
struct PlacementTag: Component { var id: PlacementID }

/// Caches one loaded template per asset revision; placements clone it. Loading failures are shown, never hidden.
@MainActor
final class ModelCache {
    private var templates: [AssetReference: Entity] = [:]
    var onLoad: (String, Double) -> Void = { _, _ in }

    func entity(for item: CatalogueItem) async throws -> Entity {
        if let t = templates[item.reference] { return t.clone(recursive: true) }
        let start = CFAbsoluteTimeGetCurrent()
        let loaded = try await Entity(contentsOf: item.modelURL)
        onLoad(item.name, (CFAbsoluteTimeGetCurrent() - start) * 1000)
        templates[item.reference] = loaded
        return loaded.clone(recursive: true)
    }
}

/// Where an item's on-screen turn button sits, in its own base-centre coordinates: above supported items, below hung
/// ones. Wall items always face out of the wall, so they have none.
enum TurnHandle {
    static let degreesPerTap: Float = -45 // clockwise seen from above, like "Rotate right"

    static func offset(for item: CatalogueItem) -> SIMD3<Float>? {
        switch item.affinity {
        case .floor, .tabletop: SIMD3(0, item.geometry.size.y + 0.1, 0)
        case .ceiling: SIMD3(0, -0.1, 0)
        case .wall, .freestandingOutdoor: nil
        }
    }
}

/// Projects the saved Design (plus unsaved previews) onto entities under a room-local root. Held-invalid previews are
/// translucent and virtual overlaps get a subtler cue; nothing is ever red.
@MainActor
final class PlacementScene {
    let roomRoot = Entity()
    private let model: AppModel
    let cache = ModelCache()
    private(set) var entities: [PlacementID: Entity] = [:]
    private var loading: Set<PlacementID> = []

    init(model: AppModel) {
        self.model = model
        roomRoot.name = "room-root"
    }

    func roomLocal(of entity: Entity) -> RigidTransform {
        let t = Transform(matrix: entity.transformMatrix(relativeTo: roomRoot))
        return RigidTransform(translation: t.translation, rotation: t.rotation)
    }

    /// Spatial content is withheld until the room's alignment is verified.
    func sync() {
        roomRoot.isEnabled = model.alignment.showsSpatialContent
        let placements = model.currentDesign?.placements ?? []
        let wanted = Set(placements.map(\.id))
        for (id, e) in entities where !wanted.contains(id) {
            e.removeFromParent()
            entities[id] = nil
        }
        let lit = Set(model.litPlacements)
        for p in placements {
            guard let item = model.item(for: p.asset) else { continue } // unavailable: labelled in the panel, never substituted
            if let e = entities[p.id] {
                if e.components[PlacementTag.self] == nil { continue } // still loading
                if e.components[ModelRevision.self]?.reference != p.asset {
                    e.removeFromParent()
                    entities[p.id] = nil
                    load(p, item: item)
                } else {
                    apply(p, item: item, to: e, lit: lit.contains(p.id))
                }
            } else {
                load(p, item: item)
            }
        }
    }

    private func load(_ p: Placement, item: CatalogueItem) {
        guard !loading.contains(p.id) else { return }
        loading.insert(p.id)
        entities[p.id] = Entity() // placeholder until the model arrives
        Task {
            defer { loading.remove(p.id) }
            do {
                let e = try await cache.entity(for: item)
                guard entities[p.id] != nil else { return } // removed while loading
                configure(e, placement: p, item: item)
                roomRoot.addChild(e)
                entities[p.id] = e
                sync()
            } catch {
                entities[p.id] = nil
                model.errorMessage = "Couldn't load \(item.name): \(error.localizedDescription)"
            }
        }
    }

    /// Loads every model of the next Design before the flip is allowed to show it.
    func preload(_ design: Design?) {
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

    private func configure(_ e: Entity, placement p: Placement, item: CatalogueItem) {
        e.name = "placement-\(p.id)"
        e.components.set(PlacementTag(id: p.id))
        e.components.set(ModelRevision(reference: p.asset))
        let size = item.geometry.size
        // Placement entities stay out of the real-world collision group, so they never block their own sweep.
        e.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: size).offsetBy(translation: SIMD3(0, size.y / 2, 0))]))
        e.components.set(GroundingShadowComponent(castsShadow: true))
        var accessibility = AccessibilityComponent()
        accessibility.label = LocalizedStringResource(stringLiteral: item.name)
        accessibility.isAccessibilityElement = true
        e.components.set(accessibility)
    }

    private func apply(_ p: Placement, item: CatalogueItem, to e: Entity, lit: Bool) {
        e.setTransformMatrix(model.displayedTransform(p).matrix, relativeTo: roomRoot)
        if model.heldInvalid.contains(p.id) {
            e.components.set(OpacityComponent(opacity: 0.55))
        } else if model.overlapCues.contains(p.id) {
            e.components.set(OpacityComponent(opacity: 0.85))
        } else {
            e.components.remove(OpacityComponent.self)
        }
        let light = e.children.first { $0.name == "lamp-light" }
        if lit {
            let l = light ?? { let n = Entity(); n.name = "lamp-light"; e.addChild(n); return n }()
            l.position = LightingPlan.lightOffset(affinity: item.affinity, size: item.geometry.size)
            l.components.set(PointLightComponent(cgColor: UIColor(red: 1, green: 0.86, blue: 0.68, alpha: 1).cgColor,
                                                 intensity: 12_000, attenuationRadius: 4))
        } else {
            light?.removeFromParent()
        }
    }
}

/// The exact revision an entity was loaded from, so accepting an update swaps the model.
struct ModelRevision: Component { var reference: AssetReference }
