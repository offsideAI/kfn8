import Foundation
import Kfn8Catalogue
import Kfn8Domain
import Observation

/// The online catalogue (M2 parity): browse, download into the pinned cache, revocation checks, and newer revisions.
/// Active only when a base URL is configured. Anonymous: no account, no device identifier, no analytics.
@MainActor
@Observable
final class RemoteCatalogue {
    enum Status: Equatable { case notConfigured, idle, loading, loaded, failed(String) }

    private(set) var status: Status = .notConfigured
    private(set) var listing: [AssetSummary] = []
    /// The latest published state of each downloaded item, independent of the current search (for update offers).
    private(set) var downloadedLatest: [UUID: AssetDetail] = [:]
    private(set) var index = DownloadedAssetIndex()
    /// Verified local files for downloaded revisions; a revision missing here can't be placed offline.
    private(set) var files: [AssetReference: URL] = [:]
    private(set) var revoked: Set<RevisionID> = []
    private(set) var downloading: Set<UUID> = []
    /// Browsing: free-text search, an affinity filter and the server's opaque cursor for the next page.
    var searchText = ""
    var affinityFilter: Affinity?
    private(set) var nextCursor: String?
    private(set) var loadingMore = false

    private let client: CatalogueClient?
    private let cache: AssetCache?
    private let sync: RevocationSync?
    private let indexURL: URL

    init(options: LaunchOptions, storageRoot: URL) {
        indexURL = storageRoot.appending(path: "downloaded-assets.json")
        var baseURL = options.apiBaseURL
        var transport: any HTTPTransport = URLSessionTransport()
        var source: any ByteSource = URLSessionByteSource()
        #if DEBUG
        if let fixtures = options.catalogueFixtures {
            baseURL = URL(string: "https://fixtures.kfn8.invalid/")
            transport = FixtureCatalogueTransport(root: fixtures)
            source = FixtureByteSource(root: fixtures)
        }
        #endif
        guard let baseURL else { client = nil; cache = nil; sync = nil; return }
        let client = CatalogueClient(baseURL: baseURL, transport: transport)
        let cache = try? AssetCache(root: storageRoot.appending(path: "asset-cache"), source: source)
        self.client = client
        self.cache = cache
        sync = cache.map { RevocationSync(client: client, cache: $0, stateURL: storageRoot.appending(path: "revocation-sync.json")) }
        status = cache == nil ? .failed("The download cache couldn't be created.") : .idle
        index = (try? DownloadedAssetIndex.load(from: indexURL)) ?? DownloadedAssetIndex()
    }

    var isConfigured: Bool { client != nil }

    // MARK: What can be placed

    /// The newest downloaded revision of each online item that is still available on this device.
    var placeableItems: [CatalogueItem] {
        index.latestPerAsset.compactMap { d in files[d.reference].flatMap { CatalogueItem(downloaded: d, file: $0) } }
            .filter { !revoked.contains($0.reference.revisionID) }
    }

    /// The exact revision a Design pinned, if it's still available here. Nil means a labelled absence, never a substitute.
    func placeableItem(for reference: AssetReference) -> CatalogueItem? {
        guard !revoked.contains(reference.revisionID), let d = index.item(for: reference), let file = files[d.reference] else { return nil }
        return CatalogueItem(downloaded: d, file: file)
    }

    /// Why a pinned online item can't be shown.
    func absenceReason(for reference: AssetReference) -> String? {
        if revoked.contains(reference.revisionID) { return "no longer available" }
        if index.item(for: reference) != nil, files[reference] == nil { return "not downloaded on this device" }
        return nil
    }

    func latestRevision(of asset: AssetID) -> (RevisionID, String)? {
        guard let d = downloadedLatest[asset.rawValue] else { return nil }
        return (RevisionID(rawValue: d.latestRevisionId), "A newer version of \(d.name) is available (revision \(d.latestRevision)).")
    }

    /// Online items not yet downloaded, for the "More from the catalogue" list.
    var notYetDownloaded: [AssetSummary] {
        listing.filter { s in !index.items.contains { $0.id.rawValue == s.id } && s.domainAffinity?.isPlaceableInMVP1 == true }
    }

    // MARK: Refresh and download

    /// Launch/foreground opportunity: revocations first (each applied durably before the cursor moves), then files and listing.
    func refresh(pinned: Set<AssetReference>, force: Bool = false) async {
        guard let client, let cache, let sync else { return }
        status = .loading
        await cache.setPinned(pinned)
        var offlineNote: String?
        do { _ = try await sync.sync(force: force) } catch {
            offlineNote = "Couldn't check for withdrawn items: \(Self.describe(error))" // best effort; checked again next time
        }
        await reloadLocalState(cache: cache)
        var latest: [UUID: AssetDetail] = [:]
        for id in Set(index.items.map(\.id.rawValue)) {
            if let detail = try? await client.asset(id) { latest[id] = detail } // offline: no offers this time
        }
        downloadedLatest = latest
        await search()
        if case .failed = status, let offlineNote { status = .failed(offlineNote) }
    }

    /// First page for the current search and filter. Pagination is the server's (stable, opaque cursors).
    func search() async {
        guard let client else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let page = try await client.assets(query: query.isEmpty ? nil : query, affinity: affinityFilter?.rawValue, limit: 30)
            listing = page.items
            nextCursor = page.nextCursor
            status = .loaded
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    func loadMore() async {
        guard let client, let cursor = nextCursor, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let page = try await client.assets(query: query.isEmpty ? nil : query, affinity: affinityFilter?.rawValue, cursor: cursor, limit: 30)
            listing += page.items.filter { item in !listing.contains { $0.id == item.id } }
            nextCursor = page.nextCursor
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    private func reloadLocalState(cache: AssetCache) async {
        var found: [AssetReference: URL] = [:]
        var gone: Set<RevisionID> = []
        for d in index.items {
            if await cache.isRevoked(d.reference.revisionID) { gone.insert(d.reference.revisionID); continue }
            if let url = try? await cache.file(for: d.rendition, online: false) { found[d.reference] = url }
        }
        files = found
        revoked = gone
    }

    func download(_ summary: AssetSummary) async throws {
        try await download(asset: AssetID(rawValue: summary.id), revisionID: RevisionID(rawValue: summary.latestRevisionId))
    }

    /// Downloads one revision's placement model into the pinned cache, verifying size and SHA-256, and remembers it.
    /// Works from the asset's own detail, so it doesn't depend on what the current search shows.
    func download(asset: AssetID, revisionID: RevisionID) async throws {
        guard let client, let cache else { throw CatalogueError.unavailable }
        downloading.insert(asset.rawValue)
        defer { downloading.remove(asset.rawValue) }
        let detail = try await client.asset(asset.rawValue)
        guard detail.latestRevisionId == revisionID.rawValue else { throw CatalogueError.notFound }
        let revision = try await client.revision(asset: detail.id, revision: detail.latestRevision)
        guard let rendition = revision.renditionsForPlacement().first(where: { $0.fileName.hasPrefix("lod0") }) else {
            throw CatalogueError.decoding("no placement model in revision \(revision.revision)")
        }
        let file = try await cache.file(for: rendition)
        // Rugs are exempt from virtual collision, so the floor-covering flag comes from the detail.
        let item = DownloadedAsset(reference: revision.reference, name: detail.name, category: detail.category, affinity: detail.affinity,
                                   sizeMetres: revision.sizeMetres, isFloorCovering: detail.isFloorCovering, rendition: rendition,
                                   offer: detail.offer?.pricedOffer, downloadedAt: .now)
        downloadedLatest[detail.id] = detail
        var next = index
        next.upsert(item)
        try next.save(to: indexURL)
        index = next
        files[item.reference] = file
    }

    static func describe(_ error: any Error) -> String {
        switch error {
        case CatalogueError.unavailable, CatalogueError.transport: "The online catalogue isn't reachable right now."
        case CatalogueError.revoked: "This item is no longer available."
        case CatalogueError.notFound: "This item couldn't be found in the online catalogue."
        case AssetCacheError.insufficientStorage: "There isn't enough storage on this device to download it."
        case AssetCacheError.checksumMismatch, AssetCacheError.sizeMismatch: "The download was damaged and wasn't installed. Try again."
        case AssetCacheError.missingOffline: "This item isn't downloaded on this device."
        case AssetCacheError.revoked: "This item is no longer available."
        default: "\(error)"
        }
    }
}

#if DEBUG
/// Debug-only: serves recorded catalogue responses from `<root>/<request path>.json` ({"status": …, "body": …}), so
/// UI tests exercise browse, download, revocation and pricing without a network or a server.
struct FixtureCatalogueTransport: HTTPTransport {
    let root: URL
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw CatalogueError.transport("no URL") }
        let file = root.appending(path: String(url.path.drop { $0 == "/" }) + ".json")
        let wrapper = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        guard let status = wrapper?["status"] as? Int, let body = wrapper?["body"] else { throw CatalogueError.decoding("bad fixture \(file.lastPathComponent)") }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (try JSONSerialization.data(withJSONObject: body), response)
    }
}

/// Debug-only: "downloads" model bytes from `<root>/bytes/<file name>`.
struct FixtureByteSource: ByteSource {
    let root: URL
    func download(_ url: URL, to destination: URL) async throws {
        try FileManager.default.copyItem(at: root.appending(path: "bytes").appending(path: url.lastPathComponent), to: destination)
    }
}
#endif
