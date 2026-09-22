import Kfn8M0ProbeCore
import RealityKit
import SwiftUI
import simd

/// RealityKit projection of the probe fixtures. Placement state lives in `ProbeSession`; entities are transient.
@MainActor
final class ProbeScene {
    let root = Entity()
    private(set) var fixtures: [AttachmentAffinity: Entity] = [:]
    private var models: [AttachmentAffinity: ModelEntity] = [:]
    private var shapes: [AttachmentAffinity: ShapeResource] = [:]
    private let lampLightEntity = Entity()
    private(set) var occlusionEntity = ModelEntity()
    static let fixtureGroup = CollisionGroup(rawValue: 1 << 2)

    private static let bone = UIColor(red: 0.93, green: 0.91, blue: 0.86, alpha: 1)
    private static let walnut = UIColor(red: 0.36, green: 0.25, blue: 0.18, alpha: 1)
    private static let brass = UIColor(red: 0.72, green: 0.58, blue: 0.30, alpha: 1)
    private static let clay = UIColor(red: 0.66, green: 0.45, blue: 0.36, alpha: 1)

    static func initialPosition(for affinity: AttachmentAffinity) -> SIMD3<Float> {
        switch affinity {
        case .floor: SIMD3(0.0, 0.0, -1.2)
        case .wall: SIMD3(0.5, 1.4, -1.2)
        case .ceiling: SIMD3(-0.5, 2.0, -1.2)
        case .tabletop: SIMD3(0.5, 0.75, -0.8)
        }
    }

    /// Fixture dimensions in metres (W, H, D). Base-centre pivot for every fixture; the ceiling pendant's mount point
    /// is metadata (top of the cord), not the pivot.
    static func size(for affinity: AttachmentAffinity) -> SIMD3<Float> {
        switch affinity {
        case .floor: SIMD3(0.55, 0.80, 0.55)
        case .wall: SIMD3(0.20, 0.30, 0.12)
        case .ceiling: SIMD3(0.28, 0.45, 0.28)
        case .tabletop: SIMD3(0.12, 0.30, 0.12)
        }
    }

    func build() {
        guard fixtures.isEmpty else { return }
        for affinity in AttachmentAffinity.allCases {
            let fixture = makeFixture(affinity: affinity)
            root.addChild(fixture)
            fixtures[affinity] = fixture
        }
        buildLamp()
        buildOcclusionObject()
    }

    private func makeFixture(affinity: AttachmentAffinity) -> Entity {
        let size = ProbeScene.size(for: affinity)
        let colour: UIColor = switch affinity {
        case .floor: ProbeScene.walnut
        case .wall: ProbeScene.brass
        case .ceiling: ProbeScene.brass
        case .tabletop: ProbeScene.clay
        }
        let model = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.01),
                                materials: [SimpleMaterial(color: colour, roughness: 0.6, isMetallic: affinity == .wall || affinity == .ceiling)])
        model.position = SIMD3(0, size.y / 2, 0) // base-centre pivot on the parent
        let pivot = Entity()
        pivot.name = "fixture.\(affinity.rawValue)"
        pivot.position = ProbeScene.initialPosition(for: affinity)
        pivot.addChild(model)
        let shape = ShapeResource.generateBox(size: size).offsetBy(translation: SIMD3(0, size.y / 2, 0))
        shapes[affinity] = shape
        ManipulationComponent.configureEntity(pivot, hoverEffect: .spotlight(.default), allowedInputTypes: .all, collisionShapes: [shape])
        var manipulation = pivot.components[ManipulationComponent.self] ?? ManipulationComponent()
        manipulation.releaseBehavior = .stay
        manipulation.dynamics.scalingBehavior = .none // placement scale is exactly one; reject scale gestures
        pivot.components.set(manipulation)
        pivot.components.set(CollisionComponent(shapes: [shape], mode: .trigger,
                                                filter: CollisionFilter(group: ProbeScene.fixtureGroup, mask: SurfaceTracker.realWorldGroup)))
        pivot.components.set(GroundingShadowComponent(castsShadow: true))
        pivot.components.set(FixtureComponent(affinity: affinity))
        models[affinity] = model
        return pivot
    }

    private func buildLamp() {
        // The floor fixture doubles as the lamp base so the founder can drag the lamp toward a real wall.
        guard let floorFixture = fixtures[.floor] else { return }
        let post = ModelEntity(mesh: .generateBox(size: SIMD3(0.03, 0.5, 0.03)),
                               materials: [SimpleMaterial(color: ProbeScene.brass, roughness: 0.4, isMetallic: true)])
        post.position = SIMD3(0, 0.80 + 0.25, 0)
        let bulb = ModelEntity(mesh: .generateSphere(radius: 0.05),
                               materials: [UnlitMaterial(color: ProbeScene.bone)])
        bulb.position = SIMD3(0, 0.80 + 0.55, 0)
        lampLightEntity.position = bulb.position
        floorFixture.addChild(post)
        floorFixture.addChild(bulb)
        floorFixture.addChild(lampLightEntity)
    }

    private func buildOcclusionObject() {
        occlusionEntity = ModelEntity(mesh: .generateBox(size: SIMD3(0.45, 0.45, 0.45), cornerRadius: 0.02),
                                      materials: [SimpleMaterial(color: ProbeScene.clay, roughness: 0.7, isMetallic: false)])
        occlusionEntity.name = "occlusionProbe"
        occlusionEntity.position = SIMD3(-0.9, 0.225, -1.5)
        occlusionEntity.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))
        ManipulationComponent.configureEntity(occlusionEntity, hoverEffect: .spotlight(.default), allowedInputTypes: .all,
                                              collisionShapes: [.generateBox(size: SIMD3(0.45, 0.45, 0.45))])
        var manipulation = occlusionEntity.components[ManipulationComponent.self] ?? ManipulationComponent()
        manipulation.releaseBehavior = .stay
        manipulation.dynamics.scalingBehavior = .none
        occlusionEntity.components.set(manipulation)
        root.addChild(occlusionEntity)
    }

    // MARK: Lighting

    func applyLighting(_ state: LightingProbeState) {
        lampLightEntity.components.remove(PointLightComponent.self)
        lampLightEntity.components.remove(PointLightComponent.SurroundingsLight.self)
        lampLightEntity.components.remove(SpotLightComponent.self)
        lampLightEntity.components.remove(SpotLightComponent.SurroundingsLight.self)
        lampLightEntity.components.remove(SpotLightComponent.Shadow.self)
        guard state.isLightOn else { return }
        let warm = UIColor(red: 1.0, green: 0.86, blue: 0.68, alpha: 1)
        switch state.lightType {
        case .point:
            lampLightEntity.components.set(PointLightComponent(color: warm, intensity: state.intensity, attenuationRadius: state.attenuationRadius))
            if state.surroundingsLightingEnabled {
                lampLightEntity.components.set(PointLightComponent.SurroundingsLight())
            }
        case .spot:
            let spot = SpotLightComponent(color: warm, intensity: state.intensity, innerAngleInDegrees: 35, outerAngleInDegrees: 70,
                                          attenuationRadius: state.attenuationRadius)
            var shadow = SpotLightComponent.Shadow() // separate component in the SDK, with visionOS 27 quality/lightSize
            shadow.quality = .high
            lampLightEntity.components.set(spot)
            lampLightEntity.components.set(shadow)
            lampLightEntity.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0)) // aim down at the floor
            if state.surroundingsLightingEnabled {
                lampLightEntity.components.set(SpotLightComponent.SurroundingsLight())
            }
        }
    }

    // MARK: Occlusion

    func applyOcclusion(_ state: OcclusionProbeState) {
        switch state.mode {
        case .occludedBySurroundings:
            occlusionEntity.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))
        case .defaultBlending:
            occlusionEntity.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .default))
        }
    }

    // MARK: Placement projection

    func position(of affinity: AttachmentAffinity) -> SIMD3<Float>? {
        fixtures[affinity]?.position(relativeTo: nil)
    }

    func yaw(of affinity: AttachmentAffinity) -> Float {
        guard let fixture = fixtures[affinity] else { return 0 }
        let forward = fixture.orientation(relativeTo: nil).act(SIMD3<Float>(0, 0, -1))
        return atan2(-forward.x, -forward.z)
    }

    func apply(position: SIMD3<Float>, to affinity: AttachmentAffinity) {
        fixtures[affinity]?.setPosition(position, relativeTo: nil)
    }

    func apply(pose: AttachedPose, to affinity: AttachmentAffinity) {
        guard let fixture = fixtures[affinity] else { return }
        fixture.setPosition(pose.position, relativeTo: nil)
        fixture.setOrientation(pose.orientation, relativeTo: nil)
    }

    /// Continuous soft cue: translucent while intersecting real geometry or held after an unresolved release.
    func setIntersectionCue(affinity: AttachmentAffinity, active: Bool) {
        guard let fixture = fixtures[affinity] else { return }
        if active {
            fixture.components.set(OpacityComponent(opacity: 0.55))
        } else {
            fixture.components.remove(OpacityComponent.self)
        }
    }

    /// Sweeps the fixture's collision box by 1 mm at the candidate position against real-world mesh collision only.
    func intersectsRealWorld(affinity: AttachmentAffinity, at position: SIMD3<Float>) -> Bool {
        guard let fixture = fixtures[affinity], let shape = shapes[affinity], let scene = fixture.scene else { return false }
        let orientation = fixture.orientation(relativeTo: nil)
        let hits = scene.convexCast(convexShape: shape, fromPosition: position, fromOrientation: orientation,
                                    toPosition: position + SIMD3(0, 0.001, 0), toOrientation: orientation,
                                    query: .any, mask: SurfaceTracker.realWorldGroup)
        return !hits.isEmpty
    }
}

/// Tags a fixture pivot with its affinity so event handlers can map entities back to state.
struct FixtureComponent: Component {
    var affinity: AttachmentAffinity
}
