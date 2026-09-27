import Foundation
import Kfn8Domain
import simd

/// One placeable catalogue item backed by a contract-validated manifest.
struct CatalogueItem: Identifiable, Sendable, Hashable {
    var id: AssetID { reference.assetID }
    let reference: AssetReference
    let name: String
    let category: String
    let affinity: Affinity
    let geometry: ItemGeometry
    let modelURL: URL
    let licence: String
    let author: String

    var dimensionLabel: String { PreviewFit(itemSize: geometry.size, volumeSize: geometry.size).dimensionLabel }

    static func == (a: CatalogueItem, b: CatalogueItem) -> Bool { a.reference == b.reference }
    func hash(into h: inout Hasher) { h.combine(reference) }
}

/// Minimal decoding of contract-v1 manifests (the backend owns the full schema).
private struct ManifestV1: Decodable {
    struct Asset: Decodable { let id: UUID; let name: String; let category: String; let affinity: String; let is_floor_covering: Bool? }
    struct Spec: Decodable { let width_m: Float; let depth_m: Float; let height_m: Float }
    struct Licence: Decodable { let licence_id: String; let author: String }
    struct Attachment: Decodable { let mount_point_m: [Float]? }
    struct Rendition: Decodable { let lod: Int; let format: String; let path: String; let sha256: String }
    let asset: Asset
    let revision: Int
    let dimension_spec: Spec
    let licence: Licence
    let attachment: Attachment?
    let renditions: [Rendition]
}

enum BundledCatalogueError: Error, Equatable {
    case missingDirectory
    case invalidManifest(String)
}

enum BundledCatalogue {
    /// Revision IDs are derived deterministically from asset ID + revision number so pins survive relaunch.
    static func revisionID(asset: UUID, revision: Int) -> RevisionID {
        var bytes = Array(withUnsafeBytes(of: asset.uuid) { Data($0) })
        bytes[15] ^= UInt8(truncatingIfNeeded: revision)
        bytes[14] ^= 0x5A
        return RevisionID(rawValue: UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                                                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])))
    }

    static func load(from bundle: Bundle = .main) throws -> [CatalogueItem] {
        guard let root = bundle.url(forResource: "Catalogue", withExtension: nil) else { throw BundledCatalogueError.missingDirectory }
        let dirs = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter(\.hasDirectoryPath)
        return try dirs.map { dir in
            let manifestURL = dir.appendingPathComponent("manifest.json")
            let m: ManifestV1
            do { m = try JSONDecoder().decode(ManifestV1.self, from: Data(contentsOf: manifestURL)) } catch {
                throw BundledCatalogueError.invalidManifest("\(dir.lastPathComponent): \(error)")
            }
            guard let affinity = Affinity(rawValue: m.asset.affinity),
                  let usdz = m.renditions.first(where: { $0.format == "usdz" && $0.lod == 0 }) else {
                throw BundledCatalogueError.invalidManifest(dir.lastPathComponent)
            }
            let size = SIMD3(m.dimension_spec.width_m, m.dimension_spec.height_m, m.dimension_spec.depth_m)
            let mount = m.attachment?.mount_point_m.flatMap { $0.count == 3 ? SIMD3($0[0], $0[1], $0[2]) : nil }
            return CatalogueItem(
                reference: AssetReference(assetID: AssetID(rawValue: m.asset.id), revisionID: revisionID(asset: m.asset.id, revision: m.revision)),
                name: m.asset.name, category: m.asset.category, affinity: affinity,
                geometry: ItemGeometry(size: size, mountPoint: mount, isFloorCovering: m.asset.is_floor_covering ?? false),
                modelURL: dir.appendingPathComponent(usdz.path), licence: m.licence.licence_id, author: m.licence.author)
        }.sorted { $0.name < $1.name }
    }
}
