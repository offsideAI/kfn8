import Foundation
import Kfn8Domain
import simd

/// DTO → domain mapping. Transport types are never persisted; the domain only sees immutable references.
public extension RevisionDetail {
    var reference: AssetReference { AssetReference(assetID: AssetID(rawValue: assetId), revisionID: RevisionID(rawValue: revisionId)) }

    func renditionsForPlacement() -> [CachedRendition] {
        renditions.filter { $0.format == "usdz" }.map {
            CachedRendition(reference: reference, fileName: "lod\($0.lod)-\($0.variantKey).usdz", url: URL(string: $0.url)!,
                            sha256: $0.sha256, sizeBytes: $0.sizeBytes)
        }
    }

    var sizeMetres: SIMD3<Float> { SIMD3(Float(dimensionsM.width), Float(dimensionsM.height), Float(dimensionsM.depth)) }
}

public extension AssetSummary {
    var domainAffinity: Affinity? { Affinity(rawValue: affinity) }
}
