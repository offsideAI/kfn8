import Foundation
import Testing
import simd
@testable import Kfn8M0ProbeCore

@Suite struct AttachmentTests {
    let floor = DetectedSurface(kind: .horizontalUp, center: SIMD3(0, 0, 0), normal: SIMD3(0, 1, 0), extent: SIMD2(4, 4))
    let table = DetectedSurface(kind: .horizontalUp, center: SIMD3(1, 0.75, -1), normal: SIMD3(0, 1, 0), extent: SIMD2(1, 0.6))
    let ceiling = DetectedSurface(kind: .horizontalDown, center: SIMD3(0, 2.4, 0), normal: SIMD3(0, -1, 0), extent: SIMD2(4, 4))
    let wall = DetectedSurface(kind: .vertical, center: SIMD3(0, 1.2, -2), normal: SIMD3(0, 0, 1), extent: SIMD2(4, 2.4))

    @Test func policiesMatchPlan() {
        #expect(AttachmentAffinity.floor.policy.snapsToSupport)
        #expect(!AttachmentAffinity.floor.policy.suppressesGravity)
        #expect(AttachmentAffinity.tabletop.policy.snapsToSupport)
        #expect(AttachmentAffinity.wall.policy.suppressesGravity)
        #expect(AttachmentAffinity.ceiling.policy.suppressesGravity)
        #expect(AttachmentAffinity.wall.policy.surface == .vertical)
        #expect(AttachmentAffinity.ceiling.policy.surface == .horizontalDown)
    }

    @Test func floorItemDropsToFloorKeepingYaw() throws {
        let pose = try #require(AttachmentResolver.resolve(affinity: .floor, releasedPosition: SIMD3(0.5, 0.2, -1), releasedYaw: .pi / 2,
                                                            surfaces: [floor, table, ceiling, wall]))
        #expect(pose.position == SIMD3(0.5, 0, -1))
        #expect(pose.surfaceID == floor.id)
        let forward = pose.orientation.act(SIMD3<Float>(0, 0, -1))
        #expect(abs(forward.x - (-1)) < 1e-5)
    }

    @Test func tabletopItemPrefersNearestSupport() throws {
        let pose = try #require(AttachmentResolver.resolve(affinity: .tabletop, releasedPosition: SIMD3(1, 0.85, -1), releasedYaw: 0,
                                                            surfaces: [floor, table]))
        #expect(pose.surfaceID == table.id)
        #expect(pose.position.y == 0.75)
    }

    @Test func ceilingItemAttachesToCeilingOnly() throws {
        let pose = try #require(AttachmentResolver.resolve(affinity: .ceiling, releasedPosition: SIMD3(0, 2.2, 0), releasedYaw: 0,
                                                            surfaces: [floor, ceiling]))
        #expect(pose.surfaceID == ceiling.id)
        #expect(pose.position.y == 2.4)
    }

    @Test func wallItemProjectsOntoWallAndFacesRoom() throws {
        let pose = try #require(AttachmentResolver.resolve(affinity: .wall, releasedPosition: SIMD3(0.3, 1.5, -1.8), releasedYaw: 0,
                                                            surfaces: [floor, wall]))
        #expect(abs(pose.position.z - (-2)) < 1e-5)
        #expect(pose.position.x == 0.3 && pose.position.y == 1.5)
        // Item's +Z (back) points into the wall, so its front (-Z) faces the room along the wall normal.
        let back = pose.orientation.act(SIMD3<Float>(0, 0, 1))
        #expect(simd_length(back - wall.normal) < 1e-4)
    }

    @Test func noCompatibleSurfaceWithinRangeIsInvalid() {
        #expect(AttachmentResolver.resolve(affinity: .wall, releasedPosition: SIMD3(0, 1, 0), releasedYaw: 0, surfaces: [floor, wall]) == nil)
        #expect(AttachmentResolver.resolve(affinity: .floor, releasedPosition: SIMD3(0, 1.2, 0), releasedYaw: 0, surfaces: [floor]) == nil)
        #expect(AttachmentResolver.resolve(affinity: .ceiling, releasedPosition: SIMD3(0, 1, 0), releasedYaw: 0, surfaces: [floor, wall]) == nil)
    }

    @Test func distanceIncludesLateralOvershoot() {
        #expect(AttachmentResolver.distance(to: table, from: SIMD3(1, 0.75, -1)) == 0)
        #expect(AttachmentResolver.distance(to: table, from: SIMD3(3, 0.75, -1)) > 1)
    }
}
