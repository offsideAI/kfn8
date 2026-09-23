import Foundation
import Testing
import simd
@testable import Kfn8Domain

private func ref() -> AssetReference { AssetReference(assetID: AssetID(), revisionID: RevisionID()) }

@Suite struct RigidTransformTests {
    @Test func compositionAndInverse() {
        let a = RigidTransform(translation: SIMD3(1, 0, 2), yaw: .pi / 3)
        let b = RigidTransform(translation: SIMD3(0.5, 0.2, -1), yaw: -.pi / 5)
        #expect((a * a.inverse).isApproximately(.identity))
        let p = SIMD3<Float>(0.3, 0.4, 0.5)
        #expect(simd_length((a * b).apply(p) - a.apply(b.apply(p))) < 1e-5)
    }

    @Test func codableRoundTrip() throws {
        let t = RigidTransform(translation: SIMD3(1, 2, 3), yaw: 1.1)
        let data = try JSONEncoder().encode(t)
        #expect(try JSONDecoder().decode(RigidTransform.self, from: data).isApproximately(t))
    }
}

@Suite struct RoomFrameTests {
    @Test func deriveFromFloorAndWall() throws {
        // Wall at z = -3 facing +Z (into the room), floor at y = -1.6 (session origin at head height).
        let frame = try RoomFrame.derive(floorHeight: -1.6, wallPoint: SIMD3(0.4, 0.2, -3), wallNormal: SIMD3(0, 0, 1))
        #expect(simd_length(frame.sessionFromRoom.translation - SIMD3(0.4, -1.6, -3)) < 1e-5)
        // A placement 1 m out from the wall, on the floor.
        let local = RigidTransform(translation: SIMD3(0, 0, 1))
        #expect(simd_length(frame.sessionTransform(for: local).translation - SIMD3(0.4, -1.6, -2)) < 1e-5)
    }

    @Test func roomLocalSurvivesAnchorChange() throws {
        // The same room seen from two sessions with different world origins: room-local placements do not change.
        let local = RigidTransform(translation: SIMD3(0.7, 0, 1.2), yaw: 0.4)
        let s1 = try RoomFrame.derive(floorHeight: -1.5, wallPoint: SIMD3(0, 0, -2), wallNormal: SIMD3(0, 0, 1))
        let s2 = try RoomFrame.derive(floorHeight: -1.4, wallPoint: SIMD3(3, 0, 1), wallNormal: SIMD3(-1, 0, 0))
        let world1 = s1.sessionTransform(for: local), world2 = s2.sessionTransform(for: local)
        #expect(s1.roomLocal(from: world1).isApproximately(local))
        #expect(s2.roomLocal(from: world2).isApproximately(local))
        #expect(!world1.isApproximately(world2))
    }

    @Test func rejectsNonVerticalWall() {
        #expect(throws: RoomFrame.DerivationError.degenerateWallNormal) {
            try RoomFrame.derive(floorHeight: 0, wallPoint: .zero, wallNormal: SIMD3(0, 1, 0))
        }
        #expect(throws: RoomFrame.DerivationError.wallNotVertical) {
            try RoomFrame.derive(floorHeight: 0, wallPoint: .zero, wallNormal: SIMD3(0, 0.6, 0.8))
        }
    }

    @Test func alignmentIsBoundedAndWithholdsContent() {
        var state = AlignmentState.searching(attempt: 0)
        #expect(!state.showsSpatialContent)
        state = state.afterFailedAttempt()
        #expect(state == .searching(attempt: 1))
        state = state.afterFailedAttempt()
        #expect(state == .exhausted)
        #expect(state.userMessage == "I can't tell where this room is yet")
    }
}

@Suite struct DesignEditTests {
    @Test func everyCompletedEditIncrementsVersion() throws {
        var d = Design(roomID: RoomID(), name: "Living")
        let p = Placement(asset: ref(), transform: .identity)
        d = try d.applying(.add(p))
        d = try d.applying(.move(p.id, from: .identity, to: RigidTransform(translation: SIMD3(1, 0, 0))))
        d = try d.applying(.rename(from: "Living", to: "Living A"))
        #expect(d.version == 3)
        #expect(d.name == "Living A")
    }

    @Test func staleOrMissingEditsThrowWithoutMutation() throws {
        let p = Placement(asset: ref(), transform: .identity)
        let d = try Design(roomID: RoomID(), name: "x").applying(.add(p))
        #expect(throws: EditError.staleEdit(p.id)) {
            try d.applying(.move(p.id, from: RigidTransform(translation: SIMD3(9, 9, 9)), to: .identity))
        }
        #expect(throws: EditError.duplicatePlacement(p.id)) { try d.applying(.add(p)) }
        let ghost = PlacementID()
        #expect(throws: EditError.placementNotFound(ghost)) { try d.applying(.changeVariant(ghost, from: nil, to: "oak")) }
        #expect(d.version == 1)
    }

    @Test func inverseUndoesEveryEdit() throws {
        let p = Placement(asset: ref(), transform: .identity)
        let base = try Design(roomID: RoomID(), name: "x").applying(.add(p))
        let newRef = AssetReference(assetID: p.asset.assetID, revisionID: RevisionID())
        let edits: [DesignEdit] = [.move(p.id, from: .identity, to: RigidTransform(translation: SIMD3(1, 0, 1))),
                                   .changeVariant(p.id, from: nil, to: "oak"), .changeRevision(p.id, from: p.asset, to: newRef),
                                   .remove(p), .rename(from: "x", to: "y")]
        for edit in edits {
            let after = try base.applying(edit)
            let back = try after.applying(edit.inverse)
            #expect(back.placements == base.placements && back.name == base.name)
            #expect(back.version == base.version + 2, "undo is itself a committed edit")
        }
    }

    @Test func undoRedoHistory() throws {
        var h = UndoHistory()
        let p = Placement(asset: ref(), transform: .identity)
        h.recordCommitted(.add(p))
        #expect(h.nextUndo == .remove(p))
        h.didCommitUndo()
        #expect(h.nextRedo == .add(p) && !h.canUndo)
        h.didCommitRedo()
        #expect(h.canUndo && !h.canRedo)
        h.recordCommitted(.rename(from: "a", to: "b"))
        #expect(!h.canRedo)
    }

    @Test func duplicationGetsNewIDsAndSharesRevisions() throws {
        let p = Placement(asset: ref(), transform: RigidTransform(translation: SIMD3(1, 0, 0)))
        let d = try Design(roomID: RoomID(), name: "A").applying(.add(p))
        let copy = d.duplicated(name: "A copy")
        #expect(copy.id != d.id && copy.version == 0)
        #expect(copy.placements[0].id != p.id)
        #expect(copy.referencedRevisions == d.referencedRevisions)
        #expect(copy.placements[0].transform == p.transform)
    }
}

@Suite struct PreviewFitTests {
    @Test func fitsAtTrueScale() {
        let f = PreviewFit(itemSize: SIMD3(0.2, 0.3, 0.2), volumeSize: SIMD3(0.6, 0.6, 0.6))
        #expect(f.isTrueScale)
    }

    @Test func oversizedUsesOneUniformScaleAndShowsRealDimensions() {
        let f = PreviewFit(itemSize: SIMD3(2.0, 0.9, 0.95), volumeSize: SIMD3(0.64, 0.64, 0.64), padding: 0.02)
        #expect(abs(f.scale - 0.3) < 1e-5)
        #expect(f.dimensionLabel == "W 200 × D 95 × H 90 cm")
    }
}

@Suite struct AttachmentTests {
    let floor = Surface(kind: .horizontalUp, centre: SIMD3(0, 0, 2), normal: SIMD3(0, 1, 0), halfExtent: SIMD2(3, 3), isFloor: true)
    let table = Surface(kind: .horizontalUp, centre: SIMD3(1, 0.74, 1.5), normal: SIMD3(0, 1, 0), halfExtent: SIMD2(0.6, 0.4))
    let wall = Surface(kind: .vertical, centre: SIMD3(0, 1.2, 0), normal: SIMD3(0, 0, 1), halfExtent: SIMD2(3, 1.2))
    let ceiling = Surface(kind: .horizontalDown, centre: SIMD3(0, 2.5, 2), normal: SIMD3(0, -1, 0), halfExtent: SIMD2(3, 3))

    @Test func floorItemDropsToFloorKeepingYaw() throws {
        let pose = try #require(Attachment.attach(affinity: .floor, item: ItemGeometry(size: SIMD3(0.8, 1, 0.9)),
                                                  released: RigidTransform(translation: SIMD3(1, 0.3, 1.5), yaw: 0.5), surfaces: [floor, table]))
        #expect(pose.translation.y == 0)
        #expect(abs(Attachment.yawAngle(pose.rotation) - 0.5) < 1e-4)
    }

    @Test func floorItemReleasedHighDropsUnderGravity() throws {
        let pose = try #require(Attachment.attach(affinity: .floor, item: ItemGeometry(size: SIMD3(0.8, 1, 0.9)),
                                                  released: RigidTransform(translation: SIMD3(-1, 1.4, 1.6)), surfaces: [floor, table]))
        #expect(pose.translation == SIMD3(-1, 0, 1.6), "drops straight down, not to the floor centre")
    }

    @Test func tabletopItemDropsOntoTableBeneathButNotOffItsEdge() throws {
        let item = ItemGeometry(size: SIMD3(0.2, 0.3, 0.2))
        let onTable = try #require(Attachment.attach(affinity: .tabletop, item: item, released: RigidTransform(translation: SIMD3(1.2, 1.3, 1.5)), surfaces: [floor, table]))
        #expect(abs(onTable.translation.y - 0.74) < 1e-5)
        #expect(Attachment.attach(affinity: .tabletop, item: item, released: RigidTransform(translation: SIMD3(-1, 1.3, 1.5)), surfaces: [floor, table]) == nil)
    }

    @Test func tabletopItemIgnoresFloor() throws {
        let pose = try #require(Attachment.attach(affinity: .tabletop, item: ItemGeometry(size: SIMD3(0.2, 0.3, 0.2)),
                                                  released: RigidTransform(translation: SIMD3(1, 0.9, 1.5)), surfaces: [floor, table]))
        #expect(abs(pose.translation.y - 0.74) < 1e-5)
    }

    @Test func wallItemHangsByMountPointFacingRoom() throws {
        let item = ItemGeometry(size: SIMD3(0.21, 0.38, 0.21), mountPoint: SIMD3(0, 0.19, 0.105))
        let pose = try #require(Attachment.attach(affinity: .wall, item: item,
                                                  released: RigidTransform(translation: SIMD3(0.5, 1.5, 0.3)), surfaces: [wall]))
        let mountWorld = pose.apply(item.mountPoint!)
        #expect(abs(mountWorld.z) < 1e-5, "mount point on the wall plane")
        #expect(abs(mountWorld.y - (1.5 + 0.19)) < 1e-5, "mount stays at the height it had when released")
        let front = pose.rotation.act(SIMD3<Float>(0, 0, -1))
        #expect(simd_length(front - SIMD3(0, 0, 1)) < 1e-4, "front faces into the room")
    }

    @Test func ceilingItemHangsFromCeiling() throws {
        let item = ItemGeometry(size: SIMD3(0.55, 1.36, 0.55), mountPoint: SIMD3(0, 1.36, 0))
        let pose = try #require(Attachment.attach(affinity: .ceiling, item: item,
                                                  released: RigidTransform(translation: SIMD3(0, 1.0, 2)), surfaces: [ceiling]))
        #expect(abs(pose.apply(item.mountPoint!).y - 2.5) < 1e-5)
    }

    @Test func outdoorAffinityNotPlaceableAndFarReleaseInvalid() {
        #expect(Attachment.attach(affinity: .freestandingOutdoor, item: ItemGeometry(size: SIMD3(1, 1, 1)), released: .identity, surfaces: [floor]) == nil)
        #expect(Attachment.attach(affinity: .wall, item: ItemGeometry(size: SIMD3(0.2, 0.2, 0.2)),
                                  released: RigidTransform(translation: SIMD3(0, 1.2, 2)), surfaces: [wall]) == nil)
    }
}

@Suite struct CollisionTests {
    let chair = ItemGeometry(size: SIMD3(0.8, 1.0, 0.9))
    let sofa = OrientedBox(basePivot: RigidTransform(translation: SIMD3(0, 0, 2)), size: SIMD3(2, 0.8, 0.9))

    @Test func realGeometryIsHard() {
        let c = PlacementRules.check(item: chair, at: RigidTransform(translation: SIMD3(0.5, 0, 2)), real: [sofa], virtual: [])
        #expect(!c.isValid)
    }

    @Test func restingContactIsNotCollision() {
        let c = PlacementRules.check(item: chair, at: RigidTransform(translation: SIMD3(1.4, 0, 2)), real: [sofa], virtual: [])
        #expect(c.isValid)
    }

    @Test func virtualOverlapIsSoftAndRugsAreExempt() {
        let other = OrientedBox(basePivot: RigidTransform(translation: SIMD3(0, 0, 0)), size: SIMD3(0.8, 1, 0.9))
        let soft = PlacementRules.check(item: chair, at: RigidTransform(translation: SIMD3(0.3, 0, 0)), real: [], virtual: [(other, false)])
        #expect(soft.isValid && soft.showsOverlapCue)
        let onRug = PlacementRules.check(item: chair, at: RigidTransform(translation: SIMD3(0.3, 0, 0)), real: [],
                                         virtual: [(OrientedBox(basePivot: .identity, size: SIMD3(2, 0.01, 3)), true)])
        #expect(!onRug.showsOverlapCue)
        let rug = PlacementRules.check(item: ItemGeometry(size: SIMD3(2, 0.01, 3), isFloorCovering: true), at: .identity, real: [], virtual: [(other, false)])
        #expect(!rug.showsOverlapCue)
    }

    @Test func rotatedBoxesUseSeparatingAxes() {
        let a = OrientedBox(basePivot: RigidTransform(translation: .zero, yaw: .pi / 4), size: SIMD3(1, 1, 1))
        let near = OrientedBox(basePivot: RigidTransform(translation: SIMD3(0.8, 0, 0)), size: SIMD3(0.3, 1, 0.3))
        let far = OrientedBox(basePivot: RigidTransform(translation: SIMD3(0.95, 0, 0)), size: SIMD3(0.3, 1, 0.3))
        #expect(a.intersects(near))
        #expect(!a.intersects(far))
    }
}

@Suite struct ReleaseTests {
    @Test func validReleaseStays() {
        let r = ReleaseResolver().resolve(released: .identity) { _ in true }
        #expect(r == .valid(.identity))
    }

    @Test func pushOutWithinLimitAgainstMultipleObstacles() {
        // Blocked for x < 0.1 and for z < 0.05: nearest valid is along +X at 0.1.
        let r = ReleaseResolver().resolve(released: .identity) { $0.translation.x >= 0.1 }
        guard case .pushedOut(let t, let d) = r else { Issue.record("expected push-out"); return }
        #expect(abs(t.translation.x - 0.1) < 1e-4 && abs(d - 0.1) < 1e-4)
    }

    @Test func neverJumpsBeyondTwentyFiveCentimetres() {
        let r = ReleaseResolver().resolve(released: .identity) { simd_length($0.translation) > 0.3 }
        #expect(r == .heldInvalid)
        #expect(ReleaseOutcome.message == "There isn't enough space here")
    }

    @Test func ceilingConstraintRejectsUpwardEscape() {
        // Only upward moves are clear of the obstacle, but the ceiling forbids y > 0.05.
        let r = ReleaseResolver().resolve(released: .identity) { $0.translation.y > 0.06 && $0.translation.y < 0.05 }
        #expect(r == .heldInvalid)
    }
}
