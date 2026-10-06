import Foundation
import Kfn8Domain
import Testing
@testable import Kfn8Catalogue

@Suite struct DownloadedAssetsTests {
    func item(_ asset: AssetID, revision: RevisionID = RevisionID(), at date: Date, offer: PricedOffer? = nil) -> DownloadedAsset {
        let ref = AssetReference(assetID: asset, revisionID: revision)
        return DownloadedAsset(reference: ref, name: "Chair", category: "seating", affinity: "floor", sizeMetres: SIMD3(0.8, 1, 0.9),
                               isFloorCovering: false,
                               rendition: CachedRendition(reference: ref, fileName: "lod0-default.usdz", url: URL(string: "https://cdn.test/a.usdz")!,
                                                          sha256: "ab", sizeBytes: 10),
                               offer: offer, downloadedAt: date)
    }

    @Test func roundTripsThroughDiskAndKeepsOlderRevisions() throws {
        let asset = AssetID()
        var index = DownloadedAssetIndex()
        let offer = PricedOffer(amountMinor: 49900, currency: "USD", available: true, retailerURL: URL(string: "https://shop.test/p"),
                                fetchedAt: Date(timeIntervalSince1970: 1_791_000_000.123))
        let old = item(asset, at: Date(timeIntervalSince1970: 1_791_000_000))
        let new = item(asset, at: Date(timeIntervalSince1970: 1_791_000_100), offer: offer)
        index.upsert(old)
        index.upsert(new)
        index.upsert(new) // idempotent
        let url = FileManager.default.temporaryDirectory.appending(path: "downloaded-\(UUID()).json")
        try index.save(to: url)
        let loaded = try DownloadedAssetIndex.load(from: url)
        #expect(loaded == index)
        #expect(loaded.items.count == 2)
        #expect(loaded.latestPerAsset == [new])
        #expect(loaded.item(for: old.reference) == old)
    }

    @Test func missingFileIsAnEmptyIndex() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "none-\(UUID()).json")
        #expect(try DownloadedAssetIndex.load(from: url).items.isEmpty)
    }

    @Test func apiOfferMapsToADatedPricedOffer() {
        let dto = Offer(amountMinor: 1999, available: true, currency: "EUR", fetchedAt: Date(timeIntervalSince1970: 5), retailerUrl: "https://shop.test/x")
        let priced = dto.pricedOffer
        #expect(priced.amountMinor == 1999 && priced.currency == "EUR" && priced.retailerURL?.host == "shop.test")
    }
}
