import CryptoKit
import Foundation
import Kfn8Domain
import Testing
@testable import Kfn8Catalogue

@Suite struct BundledCatalogueTests {
    /// The app's real bundled catalogue, relative to this file.
    static let appCatalogue = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "../../../../Kfn8iOS/Resources/Catalogue").standardizedFileURL

    @Test func appBundleLoadsAllNineFixturesWithVerifiedModels() throws {
        let items = try BundledCatalogue.load(from: Self.appCatalogue)
        #expect(items.count == 9)
        #expect(Set(items.map(\.affinity)) == [.floor, .wall, .ceiling, .tabletop])
        let table = try #require(items.first { $0.name == "Oak side table" })
        #expect(table.affinity == .floor)
        #expect(abs(table.geometry.size.x - 0.55) < 0.0001 && abs(table.geometry.size.z - 0.45) < 0.0001)
    }

    @Test func revisionIDsAreStableAndDistinctPerRevision() {
        let asset = UUID()
        #expect(BundledCatalogue.revisionID(asset: asset, revision: 1) == BundledCatalogue.revisionID(asset: asset, revision: 1))
        #expect(BundledCatalogue.revisionID(asset: asset, revision: 1) != BundledCatalogue.revisionID(asset: asset, revision: 2))
    }

    @Test func corruptedModelIsRejected() throws {
        let dir = try Self.item(model: Data("model".utf8), declaredSHA: Self.sha("model"))
        try Data("tampered".utf8).write(to: dir.appending(path: "chair/lod0.usdz"))
        #expect(throws: BundledCatalogueError.modelMismatch(item: "chair", file: "lod0.usdz")) { try BundledCatalogue.load(from: dir) }
    }

    @Test func manifestWithoutUSDZOrWithUnknownAffinityIsRejected() throws {
        let noUSDZ = try Self.item(model: Data("m".utf8), declaredSHA: Self.sha("m"), format: "glb")
        #expect(throws: BundledCatalogueError.invalidManifest(item: "chair", reason: "no LOD0 USDZ rendition")) { try BundledCatalogue.load(from: noUSDZ) }
        let badAffinity = try Self.item(model: Data("m".utf8), declaredSHA: Self.sha("m"), affinity: "outdoorish")
        #expect(throws: BundledCatalogueError.invalidManifest(item: "chair", reason: "unknown affinity outdoorish")) { try BundledCatalogue.load(from: badAffinity) }
    }

    @Test func missingCatalogueDirectoryIsExplicit() {
        #expect(throws: BundledCatalogueError.missingDirectory) {
            try BundledCatalogue.load(from: FileManager.default.temporaryDirectory.appending(path: "no-such-\(UUID())"))
        }
    }

    static func sha(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }

    static func item(model: Data, declaredSHA: String, format: String = "usdz", affinity: String = "floor") throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "kfn8-bundle-\(UUID())")
        let dir = root.appending(path: "chair")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try model.write(to: dir.appending(path: "lod0.\(format)"))
        let manifest: [String: Any] = [
            "asset": ["id": UUID().uuidString, "name": "Chair", "category": "chair", "affinity": affinity],
            "revision": 1,
            "dimension_spec": ["width_m": 0.8, "depth_m": 0.9, "height_m": 1.0],
            "licence": ["licence_id": "CC0-1.0", "author": "Test"],
            "renditions": [["lod": 0, "format": format, "path": "lod0.\(format)", "sha256": declaredSHA, "size_bytes": model.count]],
        ]
        try JSONSerialization.data(withJSONObject: manifest).write(to: dir.appending(path: "manifest.json"))
        return root
    }
}
