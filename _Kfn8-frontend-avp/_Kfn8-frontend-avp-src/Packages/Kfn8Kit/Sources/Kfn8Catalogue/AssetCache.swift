import CryptoKit
import Foundation
import Kfn8Domain

/// Downloads that can be streamed to disk. Abstracted so tests can serve bytes without a network.
public protocol ByteSource: Sendable {
    func download(_ url: URL, to destination: URL) async throws
}

public struct URLSessionByteSource: ByteSource {
    public init() {}
    public func download(_ url: URL, to destination: URL) async throws {
        let (tmp, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AssetCacheError.downloadFailed(url.absoluteString)
        }
        try FileManager.default.moveItem(at: tmp, to: destination)
    }
}

public enum AssetCacheError: Error, Equatable, Sendable {
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case sizeMismatch(expected: Int, actual: Int)
    case insufficientStorage(needed: Int, available: Int)
    case missingOffline(String)
    case revoked
}

/// One file of one immutable revision.
public struct CachedRendition: Codable, Sendable, Hashable {
    public var reference: AssetReference
    public var fileName: String
    public var url: URL
    public var sha256: String
    public var sizeBytes: Int
    public init(reference: AssetReference, fileName: String, url: URL, sha256: String, sizeBytes: Int) {
        self.reference = reference; self.fileName = fileName; self.url = url; self.sha256 = sha256; self.sizeBytes = sizeBytes
    }
}

/// Content cache for downloaded assets. Pinned revisions (referenced by any saved Design) are never evicted; only
/// unreferenced downloads are evicted, least-recently-used first, down to `unreferencedBudget`. Bundled assets live
/// in the app bundle and never enter this cache. Checksums are verified on install and before every load.
public actor AssetCache {
    struct Entry: Codable { var rendition: CachedRendition; var lastUsed: Date; var revoked: Bool }

    public let root: URL
    public let unreferencedBudget: Int
    let source: any ByteSource
    let freeSpace: @Sendable () -> Int
    private var index: [String: Entry] = [:]
    private var pinned: Set<AssetReference> = []
    private var revokedRevisions: Set<RevisionID> = []

    public init(root: URL, unreferencedBudget: Int = 2 << 30, source: any ByteSource = URLSessionByteSource(),
                freeSpace: @escaping @Sendable () -> Int = AssetCache.systemFreeSpace) throws {
        self.root = root
        self.unreferencedBudget = unreferencedBudget
        self.source = source
        self.freeSpace = freeSpace
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: root.appendingPathComponent("index.json")),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            index = saved
            revokedRevisions = Set(saved.values.filter(\.revoked).map(\.rendition.reference.revisionID))
        }
    }

    public static let systemFreeSpace: @Sendable () -> Int = {
        let values = try? URL.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Int(values?.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    static func key(_ r: CachedRendition) -> String { "\(r.reference.revisionID)/\(r.fileName)" }
    func path(_ r: CachedRendition) -> URL { root.appendingPathComponent(r.reference.revisionID.description).appendingPathComponent(r.fileName) }

    /// Replace the pin set from the persistence layer's revision reference counts.
    public func setPinned(_ references: Set<AssetReference>) {
        pinned = Set(references.map { AssetReference(assetID: $0.assetID, revisionID: $0.revisionID) })
    }

    public func isPinned(_ r: AssetReference) -> Bool { pinned.contains(AssetReference(assetID: r.assetID, revisionID: r.revisionID)) }

    /// Returns a verified local file, downloading (with space reservation and atomic install) if needed.
    public func file(for r: CachedRendition, online: Bool = true) async throws -> URL {
        if revokedRevisions.contains(r.reference.revisionID) { throw AssetCacheError.revoked }
        let dest = path(r)
        if FileManager.default.fileExists(atPath: dest.path) {
            if try Self.sha256(of: dest) == r.sha256 {
                index[Self.key(r)]?.lastUsed = .now
                try persist()
                return dest
            }
            try? FileManager.default.removeItem(at: dest) // corrupted: drop and re-download
            index[Self.key(r)] = nil
        }
        guard online else { throw AssetCacheError.missingOffline(r.fileName) }
        let available = freeSpace()
        guard available > r.sizeBytes else { throw AssetCacheError.insufficientStorage(needed: r.sizeBytes, available: available) }
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = dest.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).download")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await source.download(r.url, to: staging)
        let size = (try FileManager.default.attributesOfItem(atPath: staging.path)[.size] as? Int) ?? -1
        guard size == r.sizeBytes else { throw AssetCacheError.sizeMismatch(expected: r.sizeBytes, actual: size) }
        let actual = try Self.sha256(of: staging)
        guard actual == r.sha256 else { throw AssetCacheError.checksumMismatch(expected: r.sha256, actual: actual) }
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.moveItem(at: staging, to: dest)
        index[Self.key(r)] = Entry(rendition: r, lastUsed: .now, revoked: false)
        try evictUnreferenced()
        try persist()
        return dest
    }

    /// Which of these renditions cannot be loaded offline (missing or corrupted). Used to label incomplete Designs.
    public func missingOffline(_ renditions: [CachedRendition]) -> [CachedRendition] {
        renditions.filter { r in
            let p = path(r)
            return revokedRevisions.contains(r.reference.revisionID) || !FileManager.default.fileExists(atPath: p.path)
                || (try? Self.sha256(of: p)) != r.sha256
        }
    }

    /// Rights revocation: remove cached bytes and remember the revision as unavailable. Already-loaded entities stay
    /// on screen (the caller does not yank them); the next load reports `.revoked`.
    public func applyRevocation(_ revision: RevisionID) throws {
        revokedRevisions.insert(revision)
        for (k, e) in index where e.rendition.reference.revisionID == revision {
            try? FileManager.default.removeItem(at: path(e.rendition))
            index[k]?.revoked = true
        }
        if !index.values.contains(where: { $0.rendition.reference.revisionID == revision }) {
            // Record the tombstone even if nothing was cached.
            index["revoked/\(revision)"] = Entry(rendition: CachedRendition(reference: AssetReference(assetID: AssetID(rawValue: revision.rawValue), revisionID: revision),
                                                                             fileName: "", url: root, sha256: "", sizeBytes: 0), lastUsed: .now, revoked: true)
        }
        try persist()
    }

    public func isRevoked(_ revision: RevisionID) -> Bool { revokedRevisions.contains(revision) }

    public var unreferencedBytes: Int {
        index.values.filter { !$0.revoked && !isPinned($0.rendition.reference) }.reduce(0) { $0 + $1.rendition.sizeBytes }
    }

    private func evictUnreferenced() throws {
        var total = unreferencedBytes
        guard total > unreferencedBudget else { return }
        let candidates = index.filter { !$0.value.revoked && !isPinned($0.value.rendition.reference) }.sorted { $0.value.lastUsed < $1.value.lastUsed }
        for (k, e) in candidates where total > unreferencedBudget {
            try? FileManager.default.removeItem(at: path(e.rendition))
            index[k] = nil
            total -= e.rendition.sizeBytes
        }
    }

    private func persist() throws {
        try JSONEncoder().encode(index).write(to: root.appendingPathComponent("index.json"), options: .atomic)
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
