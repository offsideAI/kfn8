import Foundation
import Testing
import simd
@testable import Kfn8Domain

private let gb = Locale(identifier: "en_GB")
private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
private func day(_ d: Int, hour: Int = 12) -> Date { utc.date(from: DateComponents(year: 2026, month: 9, day: d, hour: hour))! }

@Suite struct InventoryTests {
    let chair = AssetReference(assetID: AssetID(), revisionID: RevisionID())
    let vase = AssetReference(assetID: AssetID(), revisionID: RevisionID())

    func design(_ refs: [AssetReference]) -> Design {
        Design(roomID: RoomID(), name: "A", placements: refs.map { Placement(asset: $0, transform: .identity) })
    }

    @Test func genericOnlyListHasQuantitiesDimensionsAndNoTotal() {
        let lines = Inventory.lines(for: design([chair, chair, vase])) { ref in
            InventorySource(name: ref == chair ? "Arm chair" : "Vase", sizeMetres: ref == chair ? SIMD3(0.82, 1.02, 0.99) : SIMD3(0.22, 0.31, 0.22))
        }
        #expect(lines.map(\.quantity) == [2, 1])
        #expect(lines[0].dimensionsLabel == "W 82 × D 99 × H 102 cm")
        #expect(lines.allSatisfy { $0.priceText() == nil })
        #expect(Inventory.subtotals(lines).isEmpty, "no fabricated subtotal for an all-generic list")
    }

    @Test func mixedListSaysPricedItemsOnlyAndCollapsesSameDayDates() {
        let lines = Inventory.lines(for: design([chair, chair, vase])) { ref in
            ref == chair ? InventorySource(name: "Chair", sizeMetres: .one, offer: PricedOffer(amountMinor: 24900, currency: "GBP", available: true, retailerURL: nil, fetchedAt: day(3, hour: 9)))
                         : InventorySource(name: "Vase", sizeMetres: .one)
        }
        let totals = Inventory.subtotals(lines)
        #expect(totals.count == 1 && totals[0].amountMinor == 49800 && totals[0].pricedItemsOnly)
        #expect(totals[0].text(locale: gb, calendar: utc) == "£498.00 · priced items only · prices from 3 Sep")
    }

    @Test func fullyPricedMultiDayRangeAndSeparateCurrencies() {
        let lines = Inventory.lines(for: design([chair, vase])) { ref in
            ref == chair ? InventorySource(name: "Chair", sizeMetres: .one, offer: PricedOffer(amountMinor: 10000, currency: "USD", available: true, retailerURL: nil, fetchedAt: day(1)))
                         : InventorySource(name: "Vase", sizeMetres: .one, offer: PricedOffer(amountMinor: 5000, currency: "EUR", available: true, retailerURL: nil, fetchedAt: day(5)))
        }
        let totals = Inventory.subtotals(lines)
        #expect(totals.map(\.currency) == ["EUR", "USD"], "no FX conversion into one fictitious total")
        #expect(totals.allSatisfy { !$0.pricedItemsOnly })
        let sameCurrency = Inventory.subtotals(Inventory.lines(for: design([chair, vase])) { ref in
            InventorySource(name: "x", sizeMetres: .one, offer: PricedOffer(amountMinor: 100, currency: "USD", available: true, retailerURL: nil, fetchedAt: ref == chair ? day(1) : day(5)))
        })
        #expect(sameCurrency[0].text(locale: gb, calendar: utc) == "US$2.00 · prices from 1 Sep – 5 Sep")
    }

    @Test func delistedKeepsDatedPriceButLeavesSubtotal() {
        let lines = Inventory.lines(for: design([chair])) { _ in
            InventorySource(name: "Chair", sizeMetres: .one, offer: PricedOffer(amountMinor: 24900, currency: "GBP", available: false, retailerURL: nil, fetchedAt: day(2)))
        }
        #expect(lines[0].priceText(locale: gb, calendar: utc) == "No longer sold · £249.00 on 2 Sep")
        #expect(Inventory.subtotals(lines).isEmpty)
    }

    @Test func missingAssetIsLabelledNotSubstituted() {
        let lines = Inventory.lines(for: design([chair])) { _ in nil }
        #expect(lines[0].isMissing && lines[0].name == "Unavailable item")
    }
}

@Suite struct DesignSwitcherTests {
    @Test func keepsCurrentUntilNextIsReady() {
        let a = DesignID(), b = DesignID()
        var s = DesignSwitcher(showing: a)
        s.request(b)
        #expect(s.shown == a, "no partial-room flash while loading")
        s.resourcesReady(DesignID()) // stale completion ignored
        #expect(s.shown == a)
        s.resourcesReady(b)
        #expect(s.shown == b)
    }

    @Test func failedLoadKeepsCurrentAndReports() {
        let a = DesignID(), b = DesignID()
        var s = DesignSwitcher(showing: a)
        s.request(b)
        s.resourcesFailed(b)
        #expect(s.shown == a && s.lastFailure == b)
    }
}

@Suite struct AssetUpdateOfferTests {
    @Test func offersOnlyNewerRevisionsAndAcceptsAsCommittedEdit() throws {
        let old = AssetReference(assetID: AssetID(), revisionID: RevisionID(), variantID: "oak")
        let current = AssetReference(assetID: AssetID(), revisionID: RevisionID())
        let p1 = Placement(asset: old, transform: .identity), p2 = Placement(asset: current, transform: .identity)
        let d = Design(roomID: RoomID(), name: "A", placements: [p1, p2])
        let newRevision = RevisionID()
        let offers = AssetUpdateOffer.offers(for: d) { id in
            id == old.assetID ? (newRevision, "Revision 2: corrected leg height") : (current.revisionID, "")
        }
        #expect(offers.count == 1 && offers[0].to.variantID == "oak")
        let accepted = try d.applying(offers[0].edit)
        #expect(accepted.placements[0].asset.revisionID == newRevision && accepted.version == 1)
    }
}
