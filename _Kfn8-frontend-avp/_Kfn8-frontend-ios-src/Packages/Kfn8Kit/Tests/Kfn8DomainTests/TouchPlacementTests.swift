import Foundation
import Testing
import simd
@testable import Kfn8Domain

@Suite struct DragPlaneTests {
    @Test func floorItemsDragAlongTheirSupportHeight() {
        let pose = RigidTransform(translation: SIMD3(0, 0.74, 1), yaw: 0.3)
        let plane = DragPlane.forItem(affinity: .tabletop, at: pose)
        // A camera 1.5 m up looking down and forward.
        let hit = try! #require(plane.intersect(origin: SIMD3(0, 1.5, 3), direction: SIMD3(0.2, -0.76, -1.5)))
        #expect(abs(hit.y - 0.74) < 1e-4)
        let moved = plane.dragged(pose, toward: hit)
        #expect(moved.rotation == pose.rotation)
    }

    @Test func wallItemsStayOnTheWallPlane() {
        // A sconce on the wall z = 0 facing +Z (its front −Z points out of the wall once turned 180°).
        let pose = RigidTransform(translation: SIMD3(0.5, 1.5, 0.12), yaw: .pi)
        let plane = DragPlane.forItem(affinity: .wall, at: pose)
        let hit = try! #require(plane.intersect(origin: SIMD3(0, 1.4, 3), direction: SIMD3(-0.3, 0.1, -1)))
        #expect(abs(hit.z - 0.12) < 1e-4)
    }

    @Test func raysParallelToOrPointingAwayFromThePlaneMiss() {
        let plane = DragPlane(point: .zero, normal: SIMD3(0, 1, 0))
        #expect(plane.intersect(origin: SIMD3(0, 1, 0), direction: SIMD3(1, 0, 0)) == nil)
        #expect(plane.intersect(origin: SIMD3(0, 1, 0), direction: SIMD3(0, 1, 0)) == nil)
    }
}

@Suite struct LightingPlanTests {
    @Test func atMostTwoLightingPlacementsAreLit() {
        let lamp = AssetReference(assetID: AssetID(), revisionID: RevisionID())
        let chair = AssetReference(assetID: AssetID(), revisionID: RevisionID())
        var design = Design(roomID: RoomID(), name: "A")
        design.placements = [Placement(asset: chair, transform: .identity)] + (0..<3).map { _ in Placement(asset: lamp, transform: .identity) }
        let lit = LightingPlan.activeLights(in: design) { $0 == lamp }
        #expect(lit == Array(design.placements[1...2].map(\.id)))
    }

    @Test func lightSitsUnderTheShadeOrOutFromTheWall() {
        #expect(LightingPlan.lightOffset(affinity: .ceiling, size: SIMD3(0.5, 1.3, 0.5)).y < 0.2)
        #expect(LightingPlan.lightOffset(affinity: .wall, size: SIMD3(0.15, 0.34, 0.25)).z < 0)
    }
}

@Suite struct ClearanceSummaryTests {
    @Test func reportsTheNearestGapPerSideAndWithholdsUnscannedSides() {
        let chair = OrientedBox(basePivot: .identity, size: SIMD3(0.8, 1, 0.9))
        let table = OrientedBox(basePivot: RigidTransform(translation: SIMD3(1.3, 0, 0)), size: SIMD3(0.6, 0.74, 1))
        let farTable = OrientedBox(basePivot: RigidTransform(translation: SIMD3(2.5, 0, 0)), size: SIMD3(0.6, 0.74, 1))
        let readings = ClearanceSummary.readings(item: chair, obstacles: [farTable, table])
        let right = try! #require(readings.first { $0.side == .right })
        #expect(!right.isWithheld)
        #expect(right.text.contains("60 cm"), "nearest table: 1.3 − 0.3 − 0.4 = 0.6 m, got \(right.text)")
        #expect(readings.first { $0.side == .left }?.isWithheld == true)
    }
}

@Suite struct PhotoExportFlowTests {
    @Test func nothingIsCapturedWithoutConsent() {
        var f = PhotoExportFlow()
        let early = f.giveConsent()
        #expect(!early)
        f.requestPhoto()
        f.declineConsent()
        #expect(f.step == .idle)
        let afterDecline = f.giveConsent()
        #expect(!afterDecline)
    }

    @Test func consentCaptureThenSaveOrDenial() {
        var f = PhotoExportFlow()
        f.requestPhoto()
        let agreed = f.giveConsent()
        #expect(agreed && f.step == .capturing)
        f.captured(bytes: 1200)
        f.savedToPhotos(true)
        #expect(f.step == .saved)
        f.finish()
        f.requestPhoto()
        _ = f.giveConsent()
        f.captured(bytes: 900)
        f.savedToPhotos(false)
        #expect(f.step == .photosDenied && f.message?.contains("share") == true)
    }

    @Test func captureFailureIsReported() {
        var f = PhotoExportFlow()
        f.requestPhoto()
        _ = f.giveConsent()
        f.captureFailed("no image")
        #expect(f.message == "The photo couldn't be taken: no image")
    }
}
