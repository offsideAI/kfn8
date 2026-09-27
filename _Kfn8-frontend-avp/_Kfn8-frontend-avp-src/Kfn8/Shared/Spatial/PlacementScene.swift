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

/// Where an item's turn button sits, in its own base-centre coordinates: on the vertical axis (so turning never swings
/// it behind the item), above supported items and below hung ones. Wall items always face out of the wall, so none.
enum TurnHandle {
    static let degreesPerTap: Float = -45 // clockwise seen from above, like "Rotate right"

    static func offset(for item: CatalogueItem) -> SIMD3<Float>? {
        let clearance: Float = 0.15
        switch item.affinity {
        case .floor, .tabletop: return SIMD3(0, item.geometry.size.y + clearance, 0)
        case .ceiling: return SIMD3(0, -clearance, 0)
        case .wall, .freestandingOutdoor: return nil
        }
    }
}

/// Projects the committed Design (+ unsaved previews) onto RealityKit entities under a room-local root. Shared by the
/// visionOS immersive space and the iPhone/iPad AR view; each platform adds its own input through `configureInput`.
@MainActor
final class PlacementScene {
    let roomRoot = Entity()
    private let model: AppModel
    private let cache = ModelCache()
    private(set) var entities: [PlacementID: Entity] = [:]
    /// Platform input for a newly loaded placement entity, given its box collision shape (base-centre pivot).
    var configureInput: (Entity, Placement, CatalogueItem, ShapeResource) -> Void = { _, _, _, _ in }

    init(model: AppModel) {
        self.model = model
        roomRoot.name = "room-root"
    }

    func roomLocal(of entity: Entity) -> RigidTransform {
        let t = Transform(matrix: entity.transformMatrix(relativeTo: roomRoot))
        return RigidTransform(translation: t.translation, rotation: t.rotation)
    }

    /// Spatial content is withheld until alignment is verified.
    func sync() {
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
            }
            // An asset that is no longer available (e.g. rights revoked) gets no substitute geometry; the panel shows the absence.
        }
    }

    /// Loads every model of the pending Design before the flip is allowed to show it.
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
        let size = item.geometry.size
        let shape = ShapeResource.generateBox(size: size).offsetBy(translation: SIMD3(0, size.y / 2, 0))
        e.components.set(CollisionComponent(shapes: [shape]))
        e.components.set(GroundingShadowComponent(castsShadow: true))
        var accessibility = AccessibilityComponent()
        accessibility.label = LocalizedStringResource(stringLiteral: item.name)
        accessibility.isAccessibilityElement = true
        e.components.set(accessibility)
        configureInput(e, p, item, shape)
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
