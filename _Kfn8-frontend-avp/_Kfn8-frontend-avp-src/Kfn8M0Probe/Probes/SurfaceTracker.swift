import ARKit
import Foundation
import Kfn8M0ProbeCore
import Observation
import RealityKit
import simd

/// ARKit plane detection and scene reconstruction for the probe. Planes become `DetectedSurface`s for the
/// attachment policy; mesh anchors become collision-only entities (no model, so they never occlude on their own and
/// cannot confound the EnvironmentBlendingComponent probe).
@MainActor
@Observable
final class SurfaceTracker {
    private(set) var detected: [DetectedSurface] = []
    private(set) var meshAnchorCount = 0
    private(set) var authorization: String = "not requested"
    private(set) var providerState: String = "stopped"
    private(set) var isSupported = PlaneDetectionProvider.isSupported && SceneReconstructionProvider.isSupported

    let realWorldRoot = Entity()
    static let realWorldGroup = CollisionGroup(rawValue: 1 << 1)

    private let arSession = ARKitSession()
    private var planeProvider: PlaneDetectionProvider?
    private var meshProvider: SceneReconstructionProvider?
    private var meshEntities: [UUID: Entity] = [:]
    private var planeIDs: [UUID: UUID] = [:]

    func start() async {
        guard isSupported else {
            providerState = "unsupported on this device/simulator"
            return
        }
        let statuses = await arSession.requestAuthorization(for: [.worldSensing])
        authorization = statuses.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        guard statuses[.worldSensing] == .allowed else {
            providerState = "world sensing not allowed"
            return
        }
        let planes = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
        let meshes = SceneReconstructionProvider()
        planeProvider = planes
        meshProvider = meshes
        do {
            try await arSession.run([planes, meshes])
            providerState = "running"
        } catch {
            providerState = "run failed: \(error.localizedDescription)"
            return
        }
        Task { await self.consumePlanes(planes) }
        Task { await self.consumeMeshes(meshes) }
    }

    func stop() {
        arSession.stop()
        providerState = "stopped"
    }

    private func consumePlanes(_ provider: PlaneDetectionProvider) async {
        for await update in provider.anchorUpdates {
            apply(planeUpdate: update)
        }
    }

    private func apply(planeUpdate update: AnchorUpdate<PlaneAnchor>) {
        let anchor = update.anchor
        switch update.event {
        case .added, .updated:
            guard let surface = SurfaceTracker.surface(from: anchor, existingID: planeIDs[anchor.id]) else {
                detected.removeAll { $0.id == planeIDs[anchor.id] }
                return
            }
            planeIDs[anchor.id] = surface.id
            if let index = detected.firstIndex(where: { $0.id == surface.id }) {
                detected[index] = surface
            } else {
                detected.append(surface)
            }
        case .removed:
            if let id = planeIDs.removeValue(forKey: anchor.id) {
                detected.removeAll { $0.id == id }
            }
        }
    }

    /// Anchor +Y is the plane normal; extent centre is offset from the anchor origin.
    nonisolated static func surface(from anchor: PlaneAnchor, existingID: UUID?) -> DetectedSurface? {
        let kind: AttachmentPolicy.SurfaceKind
        switch anchor.surfaceClassification {
        case .floor, .table: kind = .horizontalUp
        case .ceiling: kind = .horizontalDown
        case .wall: kind = .vertical
        default: return nil
        }
        let originFromExtent = anchor.originFromAnchorTransform * anchor.geometry.extent.anchorFromExtentTransform
        let center = SIMD3<Float>(originFromExtent.columns.3.x, originFromExtent.columns.3.y, originFromExtent.columns.3.z)
        let normalColumn = anchor.originFromAnchorTransform.columns.1
        let normal = SIMD3<Float>(normalColumn.x, normalColumn.y, normalColumn.z)
        return DetectedSurface(id: existingID ?? UUID(), kind: kind, center: center, normal: normal,
                               extent: SIMD2(anchor.geometry.extent.width, anchor.geometry.extent.height))
    }

    private func consumeMeshes(_ provider: SceneReconstructionProvider) async {
        for await update in provider.anchorUpdates {
            let anchor = update.anchor
            switch update.event {
            case .added, .updated:
                guard let shape = try? await ShapeResource.generateStaticMesh(from: anchor) else { continue }
                let entity = meshEntities[anchor.id] ?? {
                    let created = Entity()
                    created.name = "realWorldMesh"
                    realWorldRoot.addChild(created)
                    meshEntities[anchor.id] = created
                    return created
                }()
                entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)
                entity.components.set(CollisionComponent(shapes: [shape], isStatic: true,
                                                         filter: CollisionFilter(group: SurfaceTracker.realWorldGroup, mask: .all)))
            case .removed:
                meshEntities.removeValue(forKey: anchor.id)?.removeFromParent()
            }
            meshAnchorCount = meshEntities.count
        }
    }
}
