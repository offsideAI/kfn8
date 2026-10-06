import Foundation

/// A/B flip between two named Designs. The shown composition only changes once the next Design's resources are ready,
/// so the room never flashes half-loaded. A failed load keeps the current Design and reports it.
public struct DesignSwitcher: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case showing(DesignID)
        case preparing(current: DesignID, next: DesignID)
    }

    public private(set) var phase: Phase
    public private(set) var lastFailure: DesignID?

    public init(showing id: DesignID) { phase = .showing(id) }

    public var shown: DesignID {
        switch phase { case .showing(let id), .preparing(let id, _): id }
    }

    public mutating func request(_ id: DesignID) {
        guard id != shown else { phase = .showing(id); return }
        phase = .preparing(current: shown, next: id)
    }

    /// Called when every asset of the pending Design is loaded. Stale completions are ignored.
    public mutating func resourcesReady(_ id: DesignID) {
        if case .preparing(_, let next) = phase, next == id { phase = .showing(id); lastFailure = nil }
    }

    public mutating func resourcesFailed(_ id: DesignID) {
        if case .preparing(let current, let next) = phase, next == id { phase = .showing(current); lastFailure = id }
    }
}

/// Per-Design offer to move a placement to a newer published revision. Never applied automatically.
public struct AssetUpdateOffer: Sendable, Equatable, Identifiable {
    public var id: PlacementID { placementID }
    public var placementID: PlacementID
    public var from: AssetReference
    public var to: AssetReference
    public var summary: String

    /// The committed edit that accepts this offer.
    public var edit: DesignEdit { .changeRevision(placementID, from: from, to: to) }

    public static func offers(for design: Design, latest: (AssetID) -> (RevisionID, String)?) -> [AssetUpdateOffer] {
        design.placements.compactMap { p in
            guard let (newest, summary) = latest(p.asset.assetID), newest != p.asset.revisionID else { return nil }
            return AssetUpdateOffer(placementID: p.id, from: p.asset,
                                    to: AssetReference(assetID: p.asset.assetID, revisionID: newest, variantID: p.asset.variantID), summary: summary)
        }
    }
}
