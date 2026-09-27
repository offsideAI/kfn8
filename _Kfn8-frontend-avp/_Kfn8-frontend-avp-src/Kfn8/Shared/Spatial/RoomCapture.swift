import Foundation
import Kfn8Domain
import RealityKit
import simd

/// Structured elements from one capture, stored locally as the scan file. Never uploaded.
struct ScanSnapshot: Codable, Sendable {
    struct Plane: Codable, Sendable { var kind: String; var classification: String; var centre: [Float]; var normal: [Float]; var halfExtent: [Float] }
    var capturedAt: Date
    var planes: [Plane]
    var meshAnchorCount: Int
    var simulated: Bool
    /// iPhone/iPad only: the archived ARKit world map used to find this room again. Local only, never uploaded.
    var worldMap: Data?
}

/// Classified planes in session coordinates, as reported by either platform's ARKit. Platform sessions translate their
/// anchors into `ScanSnapshot.Plane` (kind + a lowercase classification such as "floor", "wall", "table"); the frame
/// and surface rules here are the same on visionOS and iPhone/iPad.
struct CapturedPlanes {
    private(set) var byID: [UUID: ScanSnapshot.Plane] = [:]

    var all: [ScanSnapshot.Plane] { Array(byID.values) }

    mutating func set(_ plane: ScanSnapshot.Plane, id: UUID) { byID[id] = plane }
    mutating func remove(_ id: UUID) { byID[id] = nil }
    mutating func removeAll() { byID = [:] }

    /// Floor sets height; the widest wall (over 1 m) sets origin and yaw.
    func deriveFrame() -> RoomFrame? {
        guard let floor = all.filter({ $0.classification.contains("floor") }).max(by: { $0.halfExtent[0] * $0.halfExtent[1] < $1.halfExtent[0] * $1.halfExtent[1] }),
              let wall = all.filter({ $0.kind == SurfaceKind.vertical.rawValue }).max(by: { $0.halfExtent[0] < $1.halfExtent[0] }),
              wall.halfExtent[0] > 0.5 else { return nil }
        return try? RoomFrame.derive(floorHeight: floor.centre[1], wallPoint: SIMD3(wall.centre[0], wall.centre[1], wall.centre[2]),
                                     wallNormal: SIMD3(wall.normal[0], wall.normal[1], wall.normal[2]))
    }

    func roomLocalSurfaces(frame: RoomFrame) -> [Surface] {
        let inv = frame.sessionFromRoom.inverse
        return byID.map { id, p in
            let c = inv.apply(SIMD3(p.centre[0], p.centre[1], p.centre[2]))
            let n = inv.rotation.act(SIMD3(p.normal[0], p.normal[1], p.normal[2]))
            return Surface(id: id, kind: SurfaceKind(rawValue: p.kind) ?? .horizontalUp, centre: c, normal: n,
                           halfExtent: SIMD2(p.halfExtent[0], p.halfExtent[1]), isFloor: p.classification.contains("floor"))
        }
    }
}

/// Synthetic room for simulators only (ARKit reports unsupported there). Clearly labelled in the UI; never compiled
/// into a claim of device behaviour. Wall 3.2 m ahead, 2.6 m ceiling, one table as a real obstacle.
@MainActor
enum SimulatedRoom {
    /// The simulated loss applies once per launch so "Rescan this room" can then succeed.
    static var lossConsumed = false

    static func start(model: AppModel, roomRoot: Entity) async {
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
        if room.frame != nil, ProcessInfo.processInfo.arguments.contains("--simulate-lost-alignment"), !lossConsumed {
            // Simulator-only test switch: the returning room is not found, so the bounded guided attempts run out.
            lossConsumed = true
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
