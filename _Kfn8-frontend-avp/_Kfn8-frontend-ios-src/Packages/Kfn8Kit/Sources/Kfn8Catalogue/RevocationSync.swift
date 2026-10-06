import Foundation
import Kfn8Domain

/// Pulls monotonic rights-revocation deltas on launch/foreground/infrequent online opportunities (no heartbeat).
/// Each deletion is applied durably before the cursor advances, so a crash mid-sync simply repeats work.
public actor RevocationSync {
    public static let minimumInterval: TimeInterval = 6 * 60 * 60

    let client: CatalogueClient
    let cache: AssetCache
    let stateURL: URL
    struct State: Codable { var cursor: String?; var lastSync: Date? }
    private var state: State

    public init(client: CatalogueClient, cache: AssetCache, stateURL: URL) {
        self.client = client
        self.cache = cache
        self.stateURL = stateURL
        state = (try? JSONDecoder().decode(State.self, from: Data(contentsOf: stateURL))) ?? State()
    }

    public var cursor: String? { state.cursor }

    public func isEligible(now: Date = .now, force: Bool = false) -> Bool {
        force || state.lastSync.map { now.timeIntervalSince($0) >= Self.minimumInterval } ?? true
    }

    /// Returns revisions revoked in this pass. Throws on transport failure without advancing the cursor.
    @discardableResult
    public func sync(now: Date = .now, force: Bool = false) async throws -> [RevisionID] {
        guard isEligible(now: now, force: force) else { return [] }
        var revoked: [RevisionID] = []
        while true {
            let page = try await client.revocations(after: state.cursor)
            for item in page.items {
                let revision = RevisionID(rawValue: item.revisionId)
                try await cache.applyRevocation(revision) // durable before the cursor moves
                revoked.append(revision)
            }
            state.cursor = page.nextCursor
            try save()
            if !page.hasMore { break }
        }
        state.lastSync = now
        try save()
        return revoked
    }

    private func save() throws {
        try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
    }
}
