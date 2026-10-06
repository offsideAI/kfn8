import CryptoKit
import Foundation
import Kfn8Domain

/// One bundled, placeable catalogue item read from a contract-v1 manifest. Its placement model (LOD0 USDZ) has been
/// checked against the manifest's size and SHA-256 before it is offered, so a corrupted bundle never loads.
public struct BundledAsset: Sendable, Hashable, Identifiable {
    public var id: AssetID { reference.assetID }
    public let reference: AssetReference
    public let name: String
    public let category: String
    public let affinity: Affinity
    public let geometry: ItemGeometry
    public let modelURL: URL
    public let licence: String
    public let author: String

    public static func == (a: BundledAsset, b: BundledAsset) -> Bool { a.reference == b.reference }
    public func hash(into h: inout Hasher) { h.combine(reference) }
}

public enum BundledCatalogueError: Error, Equatable {
    case missingDirectory
    case invalidManifest(item: String, reason: String)
    case modelMismatch(item: String, file: String)
}

/// Reads `Catalogue/<item>/manifest.json` folders. Only the fields the app needs are decoded; the backend owns the full
/// contract-v1 schema and `kfn8-validate --bundle` proves the bundled bytes match the backend's manifests.
public enum BundledCatalogue {
    public static func load(from root: URL) throws -> [BundledAsset] {
        guard (try? root.checkResourceIsReachable()) == true else { throw BundledCatalogueError.missingDirectory }
        let dirs = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter(\.hasDirectoryPath)
        return try dirs.map(loadItem).sorted { $0.name < $1.name }
    }

    /// Stable across launches, so Designs keep pinning the same bundled revision.
    public static func revisionID(asset: UUID, revision: Int) -> RevisionID {
        var bytes = Array(SHA256.hash(data: Data("kfn8-bundled/\(asset.uuidString.lowercased())/\(revision)".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // name-based UUID layout
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return RevisionID(rawValue: UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                                                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])))
    }

    private static func loadItem(_ dir: URL) throws -> BundledAsset {
        let item = dir.lastPathComponent
        let m: ManifestV1
        do { m = try JSONDecoder().decode(ManifestV1.self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json"))) } catch {
            throw BundledCatalogueError.invalidManifest(item: item, reason: "\(error)")
        }
        guard let affinity = Affinity(rawValue: m.asset.affinity) else {
            throw BundledCatalogueError.invalidManifest(item: item, reason: "unknown affinity \(m.asset.affinity)")
        }
        guard let usdz = m.renditions.first(where: { $0.format == "usdz" && $0.lod == 0 }) else {
            throw BundledCatalogueError.invalidManifest(item: item, reason: "no LOD0 USDZ rendition")
        }
        let model = dir.appendingPathComponent(usdz.path)
        let size = (try? model.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }
        guard size == usdz.size_bytes, (try? AssetCache.sha256(of: model)) == usdz.sha256 else {
            throw BundledCatalogueError.modelMismatch(item: item, file: usdz.path)
        }
        let spec = m.dimension_spec
        let mount = m.attachment?.mount_point_m.flatMap { $0.count == 3 ? SIMD3($0[0], $0[1], $0[2]) : nil }
        return BundledAsset(
            reference: AssetReference(assetID: AssetID(rawValue: m.asset.id), revisionID: revisionID(asset: m.asset.id, revision: m.revision)),
            name: m.asset.name, category: m.asset.category, affinity: affinity,
            geometry: ItemGeometry(size: SIMD3(spec.width_m, spec.height_m, spec.depth_m), mountPoint: mount,
                                   isFloorCovering: m.asset.is_floor_covering ?? false),
            modelURL: model, licence: m.licence.licence_id, author: m.licence.author)
    }
}

private struct ManifestV1: Decodable {
    struct Asset: Decodable { let id: UUID; let name: String; let category: String; let affinity: String; let is_floor_covering: Bool? }
    struct Spec: Decodable { let width_m: Float; let depth_m: Float; let height_m: Float }
    struct Licence: Decodable { let licence_id: String; let author: String }
    struct Attachment: Decodable { let mount_point_m: [Float]? }
    struct Rendition: Decodable { let lod: Int; let format: String; let path: String; let sha256: String; let size_bytes: Int }
    let asset: Asset
    let revision: Int
    let dimension_spec: Spec
    let licence: Licence
    let attachment: Attachment?
    let renditions: [Rendition]
}
