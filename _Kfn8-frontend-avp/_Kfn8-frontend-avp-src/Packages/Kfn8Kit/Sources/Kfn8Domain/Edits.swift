import Foundation

/// Every completed operation is one edit. Only completed edits are persisted; per-frame drag updates never are.
public enum DesignEdit: Codable, Sendable, Equatable {
    case add(Placement)
    case move(PlacementID, from: RigidTransform, to: RigidTransform)
    case remove(Placement)
    case changeVariant(PlacementID, from: String?, to: String?)
    case changeRevision(PlacementID, from: AssetReference, to: AssetReference)
    case rename(from: String, to: String)

    public var inverse: DesignEdit {
        switch self {
        case .add(let p): .remove(p)
        case .remove(let p): .add(p)
        case .move(let id, let from, let to): .move(id, from: to, to: from)
        case .changeVariant(let id, let from, let to): .changeVariant(id, from: to, to: from)
        case .changeRevision(let id, let from, let to): .changeRevision(id, from: to, to: from)
        case .rename(let from, let to): .rename(from: to, to: from)
        }
    }
}

public enum EditError: Error, Equatable, Sendable {
    case placementNotFound(PlacementID)
    case duplicatePlacement(PlacementID)
    case staleEdit(PlacementID)
    case notPlaceable(Affinity)
}

public extension Design {
    /// Applies an edit and increments the committed-edit counter. Throws without mutating on any inconsistency.
    func applying(_ edit: DesignEdit) throws(EditError) -> Design {
        var next = self
        switch edit {
        case .add(let p):
            guard placement(p.id) == nil else { throw .duplicatePlacement(p.id) }
            next.placements.append(p)
        case .remove(let p):
            guard let i = placements.firstIndex(where: { $0.id == p.id }) else { throw .placementNotFound(p.id) }
            next.placements.remove(at: i)
        case .move(let id, let from, let to):
            guard let i = placements.firstIndex(where: { $0.id == id }) else { throw .placementNotFound(id) }
            guard placements[i].transform.isApproximately(from) else { throw .staleEdit(id) }
            next.placements[i].transform = to
        case .changeVariant(let id, let from, let to):
            guard let i = placements.firstIndex(where: { $0.id == id }) else { throw .placementNotFound(id) }
            guard placements[i].asset.variantID == from else { throw .staleEdit(id) }
            next.placements[i].asset.variantID = to
        case .changeRevision(let id, let from, let to):
            guard let i = placements.firstIndex(where: { $0.id == id }) else { throw .placementNotFound(id) }
            guard placements[i].asset == from else { throw .staleEdit(id) }
            next.placements[i].asset = to
        case .rename(_, let to):
            next.name = to
        }
        next.version += 1
        return next
    }
}

/// Session-local undo/redo. Each undo or redo is itself a committed edit (the counter keeps rising).
public struct UndoHistory: Sendable, Equatable {
    public private(set) var undoStack: [DesignEdit] = []
    public private(set) var redoStack: [DesignEdit] = []
    public init() {}

    public mutating func recordCommitted(_ edit: DesignEdit) {
        undoStack.append(edit)
        redoStack.removeAll()
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// The edit to commit for an undo; call `didCommitUndo()` only after persistence succeeds.
    public var nextUndo: DesignEdit? { undoStack.last?.inverse }
    public var nextRedo: DesignEdit? { redoStack.last }

    public mutating func didCommitUndo() {
        guard let e = undoStack.popLast() else { return }
        redoStack.append(e)
    }

    public mutating func didCommitRedo() {
        guard let e = redoStack.popLast() else { return }
        undoStack.append(e)
    }
}
