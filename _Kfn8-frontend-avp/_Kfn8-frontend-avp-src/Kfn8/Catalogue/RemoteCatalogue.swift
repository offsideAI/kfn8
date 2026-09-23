import Foundation
import Kfn8Catalogue
import Kfn8Domain
import Observation

/// Remote catalogue integration (M2). Active only when a base URL is configured via the `Kfn8APIBaseURL` Info.plist
/// key or `--api <url>`. Anonymous: no account, no device identifier, no analytics.
@MainActor
@Observable
final class RemoteCatalogue {
    enum Status: Equatable { case notConfigured, idle, loading, loaded(Int), failed(String) }

    private(set) var status: Status = .notConfigured
    private(set) var items: [AssetSummary] = []
    private(set) var downloaded: [CatalogueItem] = []
    private(set) var revoked: Set<RevisionID> = []

    let client: CatalogueClient?
    let cache: AssetCache?
    let sync: RevocationSync?

    init(baseURL: URL?, storageRoot: URL) {
        guard let baseURL else { client = nil; cache = nil; sync = nil; return }
        let client = CatalogueClient(baseURL: baseURL)
        let cache = try? AssetCache(root: storageRoot.appendingPathComponent("asset-cache"))
        self.client = client
        self.cache = cache
        self.sync = cache.map { RevocationSync(client: client, cache: $0, stateURL: storageRoot.appendingPathComponent("revocation-sync.json")) }
        status = .idle
    }

    static func configuredBaseURL() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--api"), i + 1 < args.count { return URL(string: args[i + 1]) }
        return (Bundle.main.object(forInfoDictionaryKey: "Kfn8APIBaseURL") as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    /// Launch / foreground opportunity. Revocation deltas first (durable before the cursor moves), then the listing.
    func refresh(pinned: Set<AssetReference>, force: Bool = false) async {
        guard let client, let cache, let sync else { return }
        status = .loading
        await cache.setPinned(pinned)
        do {
            let newlyRevoked = try await sync.sync(force: force)
            revoked.formUnion(newlyRevoked)
        } catch {
            // Offline: revocation is best-effort; cached assets keep working until the next successful check.
        }
        do {
            items = try await client.assets(limit: 100).items
            status = .loaded(items.count)
        } catch {
            status = .failed("\(error)")
        }
    }

    /// Downloads the placement rendition of the latest revision into the pinned cache and returns a placeable item.
    func download(_ summary: AssetSummary) async throws -> CatalogueItem {
        guard let client, let cache, let affinity = summary.domainAffinity else { throw CatalogueError.unavailable }
        let revision = try await client.revision(asset: summary.id, revision: summary.latestRevision)
        guard let rendition = revision.renditionsForPlacement().first(where: { $0.fileName.hasPrefix("lod0") }) else { throw CatalogueError.unavailable }
        let file = try await cache.file(for: rendition)
        let item = CatalogueItem(reference: revision.reference, name: summary.name, category: summary.category, affinity: affinity,
                                 geometry: ItemGeometry(size: revision.sizeMetres), modelURL: file, licence: "", author: "")
        downloaded.removeAll { $0.id == item.id }
        downloaded.append(item)
        return item
    }

    func isRevoked(_ ref: AssetReference) -> Bool { revoked.contains(ref.revisionID) }
}
