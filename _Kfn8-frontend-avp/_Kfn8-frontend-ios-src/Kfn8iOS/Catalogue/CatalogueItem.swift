import Foundation
import Kfn8Catalogue
import Kfn8Domain

/// One placeable item, bundled or downloaded from the online catalogue. Its model has been checksum-verified before it
/// gets here (bundle reader or asset cache).
struct CatalogueItem: Identifiable, Sendable, Hashable {
    enum Source: Sendable, Hashable { case bundled, downloaded }

    var id: AssetID { reference.assetID }
    let reference: AssetReference
    let name: String
    let category: String
    let affinity: Affinity
    let geometry: ItemGeometry
    let modelURL: URL
    let licence: String
    let author: String
    let source: Source
    let offer: PricedOffer?

    var isLighting: Bool { category == "lighting" }
    var dimensionLabel: String { PreviewFit(itemSize: geometry.size, volumeSize: geometry.size).dimensionLabel }

    static func == (a: CatalogueItem, b: CatalogueItem) -> Bool { a.reference == b.reference }
    func hash(into h: inout Hasher) { h.combine(reference) }

    init(bundled a: BundledAsset) {
        reference = a.reference; name = a.name; category = a.category; affinity = a.affinity; geometry = a.geometry
        modelURL = a.modelURL; licence = a.licence; author = a.author; source = .bundled; offer = nil
    }

    init?(downloaded d: DownloadedAsset, file: URL) {
        guard let affinity = Affinity(rawValue: d.affinity) else { return nil }
        reference = d.reference; name = d.name; category = d.category; self.affinity = affinity
        geometry = ItemGeometry(size: d.sizeMetres, isFloorCovering: d.isFloorCovering)
        modelURL = file; licence = "Online catalogue"; author = ""; source = .downloaded; offer = d.offer
    }
}
