import CryptoKit
import Foundation
import Kfn8Domain
import Testing
@testable import Kfn8Catalogue

/// Serves recorded backend responses (status + body) keyed by path prefix. No network, no server.
struct FixtureTransport: HTTPTransport {
    let routes: [(String, String)]
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url!.path
        guard let (_, file) = routes.first(where: { path.hasPrefix($0.0) }) else { throw CatalogueError.transport("no route \(path)") }
        let url = Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Fixtures")!
        let wrapper = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let body = try JSONSerialization.data(withJSONObject: wrapper["body"]!)
        return (body, HTTPURLResponse(url: request.url!, statusCode: wrapper["status"] as! Int, httpVersion: nil, headerFields: nil)!)
    }
}

@Suite struct ContractRoundTripTests {
    let client = CatalogueClient(baseURL: URL(string: "https://api.example.test")!, transport: FixtureTransport(routes: [
        ("/v1/assets/00000000-0000-4000-8000-000000000000", "error_not_found"),
        ("/v1/revocations", "revocations"),
    ]))

    @Test func contractIsPinned() {
        #expect(CatalogueAPIContract.apiVersion == "1.0.0")
        #expect(CatalogueAPIContract.contractSHA256.count == 64)
    }

    @Test func decodesRecordedPageDetailAndRevision() async throws {
        let decode = { (name: String) throws -> Data in
            let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
            let wrapper = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
            return try JSONSerialization.data(withJSONObject: wrapper["body"]!)
        }
        let page = try CatalogueClient.decoder.decode(AssetPage.self, from: try decode("assets_page"))
        #expect(page.items.count == 1 && page.nextCursor != nil)
        let detail = try CatalogueClient.decoder.decode(AssetDetail.self, from: try decode("asset_detail"))
        #expect(detail.offer?.amountMinor == 49900 && detail.offer?.currency == "USD")
        let revision = try CatalogueClient.decoder.decode(RevisionDetail.self, from: try decode("revision_detail"))
        #expect(revision.renditions.count == 2)
        #expect(revision.renditionsForPlacement().count == 1)
        #expect(revision.reference.assetID.rawValue == detail.id)
    }

    @Test func errorsMapToTypedCases() async {
        await #expect(throws: CatalogueError.notFound) { try await client.asset(UUID(uuidString: "00000000-0000-4000-8000-000000000000")!) }
        let revokedClient = CatalogueClient(baseURL: URL(string: "https://api.example.test")!, transport: FixtureTransport(routes: [("/v1/assets", "error_revoked")]))
        await #expect(throws: CatalogueError.revoked) { try await revokedClient.revision(asset: UUID(), revision: 1) }
    }

    @Test func revocationDeltaDecodes() async throws {
        let page = try await client.revocations(after: nil)
        #expect(page.items.count == 1 && page.items[0].reason == "rights" && !page.hasMore)
    }
}

/// Serves bytes from memory; can corrupt or count downloads.
actor MemorySource: ByteSource {
    var files: [URL: Data]
    var downloads = 0
    init(_ files: [URL: Data]) { self.files = files }
    func set(_ url: URL, _ data: Data) { files[url] = data }
    func download(_ url: URL, to destination: URL) async throws {
        downloads += 1
        guard let data = files[url] else { throw AssetCacheError.downloadFailed(url.absoluteString) }
        try data.write(to: destination)
    }
}

private func sha(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
private func tmp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("kfn8-cache-\(UUID())") }
private func rendition(_ url: URL, _ data: Data, ref: AssetReference = AssetReference(assetID: AssetID(), revisionID: RevisionID())) -> CachedRendition {
    CachedRendition(reference: ref, fileName: "lod0.usdz", url: url, sha256: sha(data), sizeBytes: data.count)
}

@Suite struct AssetCacheTests {
    @Test func downloadVerifyAndServeFromCache() async throws {
        let url = URL(string: "https://cdn.test/a.usdz")!, data = Data(repeating: 7, count: 4096)
        let source = MemorySource([url: data])
        let cache = try AssetCache(root: tmp(), source: source)
        let r = rendition(url, data)
        let file = try await cache.file(for: r)
        #expect(try Data(contentsOf: file) == data)
        _ = try await cache.file(for: r)
        #expect(await source.downloads == 1)
    }

    @Test func corruptDownloadRejectedAndNothingInstalled() async throws {
        let url = URL(string: "https://cdn.test/a.usdz")!, good = Data(repeating: 1, count: 100)
        let source = MemorySource([url: Data(repeating: 2, count: 100)])
        let cache = try AssetCache(root: tmp(), source: source)
        let r = rendition(url, good)
        await #expect(throws: AssetCacheError.self) { try await cache.file(for: r) }
        #expect(await cache.missingOffline([r]) == [r])
    }

    @Test func corruptedCachedFileIsRedownloaded() async throws {
        let url = URL(string: "https://cdn.test/a.usdz")!, data = Data(repeating: 3, count: 256)
        let source = MemorySource([url: data])
        let cache = try AssetCache(root: tmp(), source: source)
        let r = rendition(url, data)
        let file = try await cache.file(for: r)
        try Data(repeating: 9, count: 256).write(to: file)
        #expect(await cache.missingOffline([r]) == [r], "corruption detected before load")
        _ = try await cache.file(for: r)
        #expect(await source.downloads == 2)
    }

    @Test func offlineMissingIsExplicit() async throws {
        let cache = try AssetCache(root: tmp(), source: MemorySource([:]))
        let r = rendition(URL(string: "https://cdn.test/x.usdz")!, Data([1]))
        await #expect(throws: AssetCacheError.missingOffline("lod0.usdz")) { try await cache.file(for: r, online: false) }
    }

    @Test func insufficientStorageIsReportedNotEvictingPins() async throws {
        let url = URL(string: "https://cdn.test/big.usdz")!, data = Data(repeating: 1, count: 1000)
        let cache = try AssetCache(root: tmp(), source: MemorySource([url: data]), freeSpace: { 10 })
        await #expect(throws: AssetCacheError.insufficientStorage(needed: 1000, available: 10)) { try await cache.file(for: rendition(url, data)) }
    }

    @Test func lruEvictsOnlyUnreferencedDownloads() async throws {
        var files: [URL: Data] = [:]
        var rs: [CachedRendition] = []
        for i in 0..<4 {
            let u = URL(string: "https://cdn.test/\(i).usdz")!, d = Data(repeating: UInt8(i), count: 400)
            files[u] = d
            rs.append(rendition(u, d))
        }
        let cache = try AssetCache(root: tmp(), unreferencedBudget: 900, source: MemorySource(files))
        await cache.setPinned([rs[0].reference])
        for r in rs { _ = try await cache.file(for: r) }
        let missing = await cache.missingOffline(rs)
        #expect(!missing.contains(rs[0]), "pinned revision is never evicted even though it is the oldest")
        #expect(missing.contains(rs[1]), "oldest unreferenced download evicted")
        #expect(await cache.unreferencedBytes <= 900)
    }

    @Test func revocationRemovesBytesAndNextLoadReportsRevoked() async throws {
        let url = URL(string: "https://cdn.test/r.usdz")!, data = Data(repeating: 5, count: 64)
        let root = tmp()
        let cache = try AssetCache(root: root, source: MemorySource([url: data]))
        let r = rendition(url, data)
        let file = try await cache.file(for: r)
        try await cache.applyRevocation(r.reference.revisionID)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        await #expect(throws: AssetCacheError.revoked) { try await cache.file(for: r) }
        // Survives relaunch.
        let reopened = try AssetCache(root: root, source: MemorySource([url: data]))
        #expect(await reopened.isRevoked(r.reference.revisionID))
    }
}

@Suite struct RevocationSyncTests {
    @Test func appliesDeltasDurablyAndRespectsInterval() async throws {
        let client = CatalogueClient(baseURL: URL(string: "https://api.test")!, transport: FixtureTransport(routes: [("/v1/revocations", "revocations")]))
        let dir = tmp()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let cache = try AssetCache(root: dir.appendingPathComponent("cache"), source: MemorySource([:]))
        let sync = RevocationSync(client: client, cache: cache, stateURL: dir.appendingPathComponent("sync.json"))
        let now = Date()
        let revoked = try await sync.sync(now: now)
        #expect(revoked.count == 1)
        #expect(await cache.isRevoked(revoked[0]))
        #expect(await sync.cursor != nil)
        #expect(await !sync.isEligible(now: now.addingTimeInterval(60)), "no heartbeat polling")
        #expect(await sync.isEligible(now: now.addingTimeInterval(RevocationSync.minimumInterval)))
        let resumed = RevocationSync(client: client, cache: cache, stateURL: dir.appendingPathComponent("sync.json"))
        #expect(await resumed.cursor == (await sync.cursor), "cursor persisted across relaunch")
    }
}
