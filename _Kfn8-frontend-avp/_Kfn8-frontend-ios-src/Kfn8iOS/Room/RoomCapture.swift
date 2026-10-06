import ARKit
import Kfn8Domain
import simd

/// How this device can capture a room. Decided from what ARKit reports at runtime, never from the device name.
enum RoomCaptureMode: Equatable {
    /// The iOS simulator has no ARKit camera: the labelled simulated room stands in, and nothing it shows is device evidence.
    case simulated
    /// World tracking with plane classification. `hasDepthSensor` adds the LiDAR scene mesh for collisions and occlusion.
    case arkit(hasDepthSensor: Bool)

    static var current: RoomCaptureMode {
        guard ARWorldTrackingConfiguration.isSupported else { return .simulated }
        return .arkit(hasDepthSensor: ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh))
    }

    var label: String {
        switch self {
        case .simulated: SimulatedRoom.label
        case .arkit(true): "Camera and depth sensor"
        case .arkit(false): "Camera only"
        }
    }

    /// The plain notice owed to people without a depth sensor (no silent fallback).
    var limitation: String? {
        switch self {
        case .arkit(false): "No depth sensor: only floors, walls, tables and seats are checked for collisions."
        case .simulated, .arkit(true): nil
        }
    }
}

/// What a scan stores on the device: the classified planes and, once ARKit has mapped enough, the world map used to
/// find the room again. Never uploaded; excluded from backup with the rest of the store.
struct ScanSnapshot: Codable, Sendable {
    struct Plane: Codable, Sendable, Equatable {
        var kind: SurfaceKind
        var classification: String
        /// Session coordinates. `axisU` is the plane's first in-plane axis; `halfExtent` is along (axisU, axisV).
        var centre: SIMD3<Float>
        var normal: SIMD3<Float>
        var axisU: SIMD3<Float>
        var halfExtent: SIMD2<Float>
    }
    var capturedAt: Date
    var planes: [Plane]
    var meshAnchorCount: Int
    var simulated: Bool
    var worldMap: Data?
}

/// Classified planes in session coordinates, and the room rules derived from them: the frame (floor + widest wall),
/// room-local support surfaces, and real obstacles (tables and seats down to the floor, walls).
struct CapturedPlanes {
    private(set) var byID: [UUID: ScanSnapshot.Plane] = [:]

    var all: [ScanSnapshot.Plane] { Array(byID.values) }
    mutating func set(_ plane: ScanSnapshot.Plane, id: UUID) { byID[id] = plane }
    mutating func remove(_ id: UUID) { byID[id] = nil }
    mutating func removeAll() { byID = [:] }

    var hasFloor: Bool { all.contains { $0.classification == "floor" } }
    var hasWall: Bool { all.contains { $0.kind == .vertical } }

    /// Floor sets the height; the widest wall over 1 m sets the origin and the yaw.
    func deriveFrame() -> RoomFrame? {
        guard let floor = all.filter({ $0.classification == "floor" }).max(by: { $0.halfExtent.x * $0.halfExtent.y < $1.halfExtent.x * $1.halfExtent.y }),
              let wall = all.filter({ $0.kind == .vertical }).max(by: { $0.halfExtent.x < $1.halfExtent.x }),
              wall.halfExtent.x > 0.5 else { return nil }
        return try? RoomFrame.derive(floorHeight: floor.centre.y, wallPoint: wall.centre, wallNormal: wall.normal)
    }

    func roomLocalSurfaces(frame: RoomFrame) -> [Surface] {
        let inv = frame.sessionFromRoom.inverse
        return byID.map { id, p in
            Surface(id: id, kind: p.kind, centre: inv.apply(p.centre), normal: inv.rotation.act(p.normal),
                    halfExtent: p.halfExtent, isFloor: p.classification == "floor")
        }
    }

    /// Real geometry for collisions on camera-only devices and for clearance readings everywhere.
    func obstacles(frame: RoomFrame) -> [OrientedBox] {
        let inv = frame.sessionFromRoom.inverse
        return all.compactMap { p in
            let c = inv.apply(p.centre), u = inv.rotation.act(p.axisU)
            let yaw = atan2(-u.z, u.x) // rotation about +Y that maps +X onto u
            switch (p.kind, p.classification) {
            case (.horizontalUp, "table"), (.horizontalUp, "seat"):
                guard c.y > 0.1 else { return nil }
                return OrientedBox(basePivot: RigidTransform(translation: SIMD3(c.x, 0, c.z), yaw: yaw),
                                   size: SIMD3(p.halfExtent.x * 2, c.y, p.halfExtent.y * 2))
            case (.vertical, _):
                let n = simd_normalize(inv.rotation.act(p.normal))
                let wallYaw = atan2(n.x, n.z) // the box's +Z faces into the room
                return OrientedBox(centrePose: RigidTransform(translation: c, yaw: wallYaw),
                                   halfSize: SIMD3(p.halfExtent.x, max(p.halfExtent.y, 1.2), 0.025))
            default:
                return nil
            }
        }
    }
}

/// Synthetic room for the iOS simulator only, labelled wherever it is shown. Room-local coordinates (metres, +Y up):
/// a 5 × 5 m floor in front of the wall, the wall through the origin facing +Z, a 2.6 m ceiling, and one table as a
/// real obstacle.
enum SimulatedRoom {
    static let label = "Simulated room (simulator only)"

    static let surfaces: [Surface] = [
        Surface(kind: .horizontalUp, centre: SIMD3(0, 0, 2), normal: SIMD3(0, 1, 0), halfExtent: SIMD2(2.5, 2.5), isFloor: true),
        Surface(kind: .vertical, centre: SIMD3(0, 1.3, 0), normal: SIMD3(0, 0, 1), halfExtent: SIMD2(2.5, 1.3)),
        Surface(kind: .horizontalDown, centre: SIMD3(0, 2.6, 2), normal: SIMD3(0, -1, 0), halfExtent: SIMD2(2.5, 2.5)),
        Surface(kind: .horizontalUp, centre: SIMD3(1.1, 0.74, 1.4), normal: SIMD3(0, 1, 0), halfExtent: SIMD2(0.5, 0.3)),
    ]

    /// The table under the tabletop surface above: real geometry that placements must not pass through.
    static let table = OrientedBox(basePivot: RigidTransform(translation: SIMD3(1.1, 0, 1.4)), size: SIMD3(1.0, 0.74, 0.6))
    static let wall = OrientedBox(centrePose: RigidTransform(translation: SIMD3(0, 1.3, -0.025)), halfSize: SIMD3(2.5, 1.3, 0.025))
    static let obstacles: [OrientedBox] = [table]
    /// Obstacles for clearance readings, including the wall.
    static let clearanceObstacles: [OrientedBox] = [table, wall]

    /// Where the simulator's virtual camera stands and looks: across the room toward the wall.
    static let cameraPosition = SIMD3<Float>(0, 1.5, 4.4)
    static let cameraTarget = SIMD3<Float>(0, 0.6, 1.2)
}
