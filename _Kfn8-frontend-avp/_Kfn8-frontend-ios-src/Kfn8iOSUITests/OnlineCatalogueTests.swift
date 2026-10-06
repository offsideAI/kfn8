import CryptoKit
import XCTest

/// I2.S1 and the priced inventory path (I3.S2.T1) end to end on the simulators, against a recorded online catalogue
/// served from files (`--catalogue-fixtures`, Debug builds only). The model bytes are a real conformed fixture and the
/// SHA-256 is computed here, so the app's checksum verification is exercised for real. No network, no server; the
/// deployed end-to-end run (I2.S1.T5) still needs DigitalOcean.
final class OnlineCatalogueTests: Kfn8TestCase {
    static let assetID = "6f3c2a10-5b7e-4c1d-9a2e-0d4b8c7e1f01"
    static let revision1 = "8a1d2e30-7c4b-4f5a-9b6c-1e2f3a4b5c01"
    static let revision2 = "8a1d2e30-7c4b-4f5a-9b6c-1e2f3a4b5c02"
    static let name = "Leather pouf"

    var fixtures: URL!

    override func setUp() async throws {
        try await super.setUp()
        fixtures = URL(filePath: NSTemporaryDirectory()).appending(path: "kfn8-fixtures-\(UUID().uuidString)")
        try writeCatalogue(latestRevision: 1, revoked: [])
    }

    func testBrowseDownloadPlacePriceUpdateAndRevoke() throws {
        var app = launch(["--catalogue-fixtures", fixtures.path])
        scanNewRoom(app)

        // Browse and download: the item appears in the catalogue once its model is verified.
        tap(app, "Download \(Self.name)")
        tap(app, "Add \(Self.name)", timeout: 20)
        XCTAssertTrue(row(app, Self.name).waitForExistence(timeout: 15), "the downloaded item wasn't placed")
        tap(app, "Add Modern arm chair")
        XCTAssertTrue(row(app, "Modern arm chair").waitForExistence(timeout: 15))

        // Priced path: a dated price, the retailer link, and a subtotal that says it covers priced items only.
        waitForText(app, containing: "each · checked")
        waitForText(app, containing: "priced items only")
        XCTAssertTrue(app.links["View at the retailer"].exists || text(app, containing: "View at the retailer").exists)
        snapshot(app, "priced-inventory")
        leaveRoomView(app)

        // A newer revision is published: offered per Design, applied only when accepted.
        app.terminate()
        try writeCatalogue(latestRevision: 2, revoked: [])
        app = launch(["--catalogue-fixtures", fixtures.path])
        waitForText(app, containing: "A newer version of \(Self.name) is available (revision 2)")
        tap(app, "Update")
        XCTAssertTrue(text(app, containing: "A newer version of \(Self.name)").waitForNonExistence(timeout: 15), "the update wasn't applied")
        XCTAssertTrue(row(app, Self.name).exists)

        // Rights revocation of that revision: on the next launch the row stays, labelled, and nothing is substituted.
        app.terminate()
        try writeCatalogue(latestRevision: 2, revoked: [Self.revision2])
        app = launch(["--catalogue-fixtures", fixtures.path, "--force-revocation-sync"])
        waitForText(app, containing: "\(Self.name) (no longer available)")
        XCTAssertGreaterThanOrEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "\(Self.name) (no longer available)")).count, 2,
                                    "the Design row and the inventory line both name the withdrawn item")
        XCTAssertFalse(button(app, "Add \(Self.name)").exists, "a revoked item is still offered")
        snapshot(app, "revoked-labelled-absence")
    }

    // MARK: Fixtures

    private func writeCatalogue(latestRevision: Int, revoked: [String]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: fixtures.appending(path: "bytes"), withIntermediateDirectories: true)
        // A real conformed model from this repository: the ottoman's LOD0 USDZ.
        let source = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../Kfn8iOS/Resources/Catalogue/Ottoman_01/lod0.usdz").standardizedFileURL
        let bytes = try Data(contentsOf: source)
        let sha = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let revisions = [1: Self.revision1, 2: Self.revision2]
        for (n, _) in revisions { try bytes.write(to: fixtures.appending(path: "bytes/pouf-r\(n).usdz")) }

        let dims: [String: Any] = ["width": 0.8846, "depth": 0.6211, "height": 0.6243]
        let offer: [String: Any] = ["amount_minor": 34900, "available": true, "currency": "USD",
                                    "fetched_at": "2026-10-01T09:00:00Z", "retailer_url": "https://retailer.invalid/pouf"]
        let summary: [String: Any] = [
            "affinity": "floor", "category": "seating", "delivery_mode": "public", "dimensions_m": dims, "id": Self.assetID,
            "latest_revision": latestRevision, "latest_revision_id": revisions[latestRevision]!, "name": Self.name, "offer": offer,
            "tenant_id": "00000000-0000-4000-8000-00000000c0de", "thumbnail_url": NSNull(),
        ]
        var detail = summary
        detail["dominant_colour"] = "walnut"
        detail["is_floor_covering"] = false
        detail["style_tags"] = ["leather"]
        detail["variants"] = [["id": "default", "label": "Default"]]
        try write(["items": [summary], "next_cursor": NSNull()], to: "v1/assets")
        try write(detail, to: "v1/assets/\(Self.assetID)")
        for (n, id) in revisions {
            try write([
                "asset_id": Self.assetID, "attachment": NSNull(), "contract_version": "1.0.0", "dimensions_m": dims,
                "renditions": [["format": "usdz", "lod": 0, "sha256": sha, "size_bytes": bytes.count, "triangles": 1000,
                                "url": "https://cdn.kfn8.invalid/a/\(Self.assetID)/r\(n)/pouf-r\(n).usdz", "variant_key": "default"]],
                "revision": n, "revision_id": id, "variants": [["id": "default", "label": "Default"]],
            ], to: "v1/assets/\(Self.assetID)/revisions/\(n)")
        }
        let items = revoked.enumerated().map { ["reason": "rights", "revision_id": $1, "sequence": $0 + 1] as [String: Any] }
        try write(["has_more": false, "items": items, "next_cursor": revoked.isEmpty ? NSNull() : "c\(revoked.count)" as Any], to: "v1/revocations")
    }

    private func write(_ body: [String: Any], to path: String, status: Int = 200) throws {
        let url = fixtures.appending(path: path + ".json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: ["status": status, "body": body], options: [.sortedKeys]).write(to: url)
    }
}
