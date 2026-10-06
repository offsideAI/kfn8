import Foundation
import Kfn8Domain

/// One catalogue item downloaded from the online catalogue, remembered across launches so Designs that use it keep
/// working offline. The model bytes live in the pinned `AssetCache`; this records what the app needs to place it.
public struct DownloadedAsset: Codable, Sendable, Equatable, Identifiable {
    public var id: AssetID { reference.assetID }
    public var reference: AssetReference
    public var name: String
    public var category: String
    public var affinity: String
    public var sizeMetres: SIMD3<Float>
    public var isFloorCovering: Bool
    public var rendition: CachedRendition
    public var offer: PricedOffer?
    public var downloadedAt: Date

    public init(reference: AssetReference, name: String, category: String, affinity: String, sizeMetres: SIMD3<Float>,
                isFloorCovering: Bool, rendition: CachedRendition, offer: PricedOffer?, downloadedAt: Date) {
        self.reference = reference; self.name = name; self.category = category; self.affinity = affinity
        self.sizeMetres = sizeMetres; self.isFloorCovering = isFloorCovering; self.rendition = rendition
        self.offer = offer; self.downloadedAt = downloadedAt
    }
}

/// The downloaded-items list, written atomically after every change. Several revisions of one asset can be kept
/// (an older Design may still pin the older one).
public struct DownloadedAssetIndex: Codable, Sendable, Equatable {
    public private(set) var items: [DownloadedAsset] = []

    public init(items: [DownloadedAsset] = []) { self.items = items }

    public static func load(from url: URL) throws -> DownloadedAssetIndex {
        guard FileManager.default.fileExists(atPath: url.path) else { return DownloadedAssetIndex() }
        return try JSONDecoder.kfn8.decode(DownloadedAssetIndex.self, from: Data(contentsOf: url))
    }

    public func save(to url: URL) throws {
        try JSONEncoder.kfn8.encode(self).write(to: url, options: .atomic)
    }

    public mutating func upsert(_ item: DownloadedAsset) {
        items.removeAll { $0.reference == item.reference }
        items.append(item)
    }

    /// The newest downloaded revision of each asset, for the catalogue list.
    public var latestPerAsset: [DownloadedAsset] {
        Dictionary(grouping: items, by: \.id).values.compactMap { $0.max { $0.downloadedAt < $1.downloadedAt } }.sorted { $0.name < $1.name }
    }

    public func item(for reference: AssetReference) -> DownloadedAsset? {
        items.first { $0.reference.assetID == reference.assetID && $0.reference.revisionID == reference.revisionID }
    }
}

public extension Offer {
    var pricedOffer: PricedOffer {
        PricedOffer(amountMinor: amountMinor, currency: currency, available: available,
                    retailerURL: retailerUrl.flatMap(URL.init(string:)), fetchedAt: fetchedAt)
    }
}

extension JSONEncoder {
    static var kfn8: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        e.outputFormatting = [.sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var kfn8: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }
}
