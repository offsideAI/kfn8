import Foundation
import Kfn8Domain
import simd

extension AppModel {
    /// Adds an item in front of the camera, facing it. Wall, ceiling and tabletop items go to the nearest suitable
    /// surface; if nothing fits, the message appears beside the button that was pressed.
    func add(_ item: CatalogueItem) async {
        guard let design = currentDesign, item.affinity.isPlaceableInMVP1, alignment.showsSpatialContent else { return }
        addFailedItem = nil
        let seed = poseInFront?() ?? RigidTransform(translation: SIMD3(0, 0, 1.5))
        let roomLocal = seed.translation
        var seeds = [seed]
        if let policy = AttachmentPolicy.forAffinity(item.affinity) {
            let compatible = surfaces.filter { $0.kind == policy.surface && (item.affinity != .tabletop || !$0.isFloor) }
                .sorted { simd_distance($0.centre, roomLocal) < simd_distance($1.centre, roomLocal) }
            let mount = item.geometry.mountPoint ?? SIMD3(0, item.geometry.size.y, 0)
            for s in compatible {
                switch s.kind {
                case .horizontalUp: seeds.append(RigidTransform(translation: s.centre, rotation: seed.rotation))
                case .horizontalDown: seeds.append(RigidTransform(translation: SIMD3(roomLocal.x, s.centre.y - mount.y, roomLocal.z), rotation: seed.rotation))
                case .vertical:
                    let onWall = roomLocal - s.normal * simd_dot(roomLocal - s.centre, s.normal)
                    seeds.append(RigidTransform(translation: SIMD3(onWall.x, 1.5 - mount.y, onWall.z) + s.normal * 0.2))
                }
            }
        }
        for candidate in seeds {
            switch resolve(item: item, placementID: nil, released: candidate) {
            case .valid(let pose), .pushedOut(let pose, _):
                let placement = Placement(asset: item.reference, transform: pose)
                statusMessage = nil
                if await commit(.add(placement), to: design) { selection = placement.id }
                return
            case .heldInvalid:
                continue
            }
        }
        statusMessage = ReleaseOutcome.message
        addFailedItem = item.id
    }

    /// Drag updates are previews only; nothing is saved per frame.
    func dragUpdated(_ id: PlacementID, roomLocal: RigidTransform) {
        previewTransforms[id] = roomLocal
        if let item = currentDesign?.placement(id).flatMap({ self.item(for: $0.asset) }) {
            if realGeometryIntersects?(OrientedBox(basePivot: roomLocal, size: item.geometry.size)) == true { heldInvalid.insert(id) } else { heldInvalid.remove(id) }
        }
    }

    /// Release: attach → hard real collision → push-out of up to 25 cm → save, or keep the unsaved preview held.
    func release(_ id: PlacementID, roomLocal: RigidTransform) async {
        guard let design = currentDesign, let placement = design.placement(id), let item = item(for: placement.asset) else { return }
        switch resolve(item: item, placementID: id, released: roomLocal) {
        case .valid(let pose), .pushedOut(let pose, _):
            previewTransforms[id] = nil
            heldInvalid.remove(id)
            statusMessage = nil
            guard !pose.isApproximately(placement.transform) else { return }
            await commit(.move(id, from: placement.transform, to: pose), to: design)
        case .heldInvalid:
            previewTransforms[id] = roomLocal
            heldInvalid.insert(id)
            statusMessage = ReleaseOutcome.message
        }
    }

    /// Cancel puts the item back where it was last saved.
    func cancel(_ id: PlacementID) {
        previewTransforms[id] = nil
        heldInvalid.remove(id)
        statusMessage = nil
    }

    /// Non-gesture move, in the room frame (x across the room, z away from the main wall), through the same release.
    func nudge(_ id: PlacementID, by delta: SIMD3<Float>) async {
        guard let placement = currentDesign?.placement(id) else { return }
        let from = previewTransforms[id] ?? placement.transform
        await release(id, roomLocal: RigidTransform(translation: from.translation + delta, rotation: from.rotation))
    }

    /// Non-gesture rotation about the vertical axis (positive = counter-clockwise seen from above).
    func rotate(_ id: PlacementID, byDegrees degrees: Float) async {
        guard let placement = currentDesign?.placement(id) else { return }
        let from = previewTransforms[id] ?? placement.transform
        let turn = simd_quatf(angle: degrees * .pi / 180, axis: SIMD3(0, 1, 0))
        await release(id, roomLocal: RigidTransform(translation: from.translation, rotation: turn * from.rotation))
    }

    func remove(_ id: PlacementID) async {
        guard let design = currentDesign, let placement = design.placement(id) else { return }
        previewTransforms[id] = nil
        heldInvalid.remove(id)
        await commit(.remove(placement), to: design)
        if selection == id { selection = nil }
    }

    func undo() async {
        guard let edit = undoHistory.nextUndo, let design = currentDesign else { return }
        if await commit(edit, to: design, recordUndo: false) { undoHistory.didCommitUndo() }
    }

    func redo() async {
        guard let edit = undoHistory.nextRedo, let design = currentDesign else { return }
        if await commit(edit, to: design, recordUndo: false) { undoHistory.didCommitRedo() }
    }

    /// Saves one completed edit atomically (optimistic version check). Failures are shown and leave the saved state.
    @discardableResult
    func commit(_ edit: DesignEdit, to design: Design, recordUndo: Bool = true) async -> Bool {
        do {
            let next = try await repository.commit(edit, to: design.id, expectedVersion: design.version)
            currentDesign = next
            if let i = designs.firstIndex(where: { $0.id == next.id }) { designs[i] = next }
            if recordUndo { undoHistory.recordCommitted(edit) }
            recomputeOverlapCues()
            return true
        } catch {
            appLog.error("commit failed: \(String(describing: error), privacy: .public)")
            errorMessage = Self.describe(error)
            return false
        }
    }

    func resolve(item: CatalogueItem, placementID: PlacementID?, released: RigidTransform) -> ReleaseOutcome {
        func attached(_ candidate: RigidTransform) -> RigidTransform? {
            guard let pose = Attachment.attach(affinity: item.affinity, item: item.geometry, released: candidate, surfaces: surfaces) else { return nil }
            if realGeometryIntersects?(OrientedBox(basePivot: pose, size: item.geometry.size)) == true { return nil }
            return pose // overlapping another virtual item never blocks; it only gets a cue
        }
        switch ReleaseResolver().resolve(released: released, isValid: { attached($0) != nil }) {
        case .valid(let c): return attached(c).map { .valid($0) } ?? .heldInvalid
        case .pushedOut(let c, let d): return attached(c).map { .pushedOut($0, distance: d) } ?? .heldInvalid
        case .heldInvalid: return .heldInvalid
        }
    }

    func recomputeOverlapCues() {
        guard let design = currentDesign else { overlapCues = []; return }
        var cues: Set<PlacementID> = []
        for p in design.placements {
            guard let item = item(for: p.asset) else { continue }
            let others = design.placements.filter { $0.id != p.id }.compactMap { o -> (box: OrientedBox, isFloorCovering: Bool)? in
                guard let g = self.item(for: o.asset)?.geometry else { return nil }
                return (OrientedBox(basePivot: o.transform, size: g.size), g.isFloorCovering)
            }
            if PlacementRules.check(item: item.geometry, at: p.transform, real: [], virtual: others).showsOverlapCue { cues.insert(p.id) }
        }
        overlapCues = cues
    }

    func displayedTransform(_ p: Placement) -> RigidTransform { previewTransforms[p.id] ?? p.transform }

    /// Gaps to scanned real obstacles around a placed item. Only while the room is aligned; never in "Review contents".
    func clearanceReadings(for id: PlacementID) -> [ClearanceReading]? {
        guard isRoomViewOpen, alignment.showsSpatialContent, let p = currentDesign?.placement(id), let item = item(for: p.asset) else { return nil }
        return ClearanceSummary.readings(item: OrientedBox(basePivot: displayedTransform(p), size: item.geometry.size), obstacles: realObstacles)
    }

    /// The lighting placements that currently give off light (at most two).
    var litPlacements: [PlacementID] {
        guard lampsOn, let d = currentDesign else { return [] }
        return LightingPlan.activeLights(in: d) { self.item(for: $0)?.isLighting == true }
    }
}

extension AppModel {
    /// Where a placed item is, for VoiceOver: across the room from the main wall's centre, out from the wall, height
    /// for wall and ceiling items, and which way it faces. Room-local: x across, +z out of the main wall, +y up.
    func positionDescription(_ p: Placement) -> String {
        let t = displayedTransform(p)
        let x = t.translation.x, z = t.translation.z
        let side = abs(x) < 0.005 ? "centred" : String(format: "%.2f m %@ of centre", abs(x), x > 0 ? "right" : "left")
        var parts = [side, String(format: "%.2f m out from the wall", z)]
        if let affinity = item(for: p.asset)?.affinity, affinity == .wall || affinity == .ceiling || affinity == .tabletop {
            parts.append(String(format: "%.2f m up", t.translation.y))
        }
        let front = t.rotation.act(SIMD3<Float>(0, 0, -1))
        var degrees = Int((atan2(-front.x, -front.z) * 180 / .pi).rounded())
        degrees = ((degrees % 360) + 360) % 360
        parts.append("turned \(degrees)°")
        return parts.joined(separator: ", ")
    }
}
