import CryptoKit
import Foundation

/// Filesystem side of persistence: scans and downloaded assets live as files, referenced relatively from records.
public protocol FileStoring: Sendable {
    func write(_ data: Data, to relativePath: String) async throws -> (byteCount: Int, sha256: String)
    func remove(_ relativePath: String) async throws
    func exists(_ relativePath: String) async -> Bool
    func read(_ relativePath: String) async throws -> Data
}

public enum FileStoreError: Error, Equatable, Sendable {
    case invalidPath(String)
    case writeFailed(String)
    case removeFailed(String)
}

public actor FileStore: FileStoring {
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func url(_ relativePath: String) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.split(separator: "/").contains("..") else {
            throw FileStoreError.invalidPath(relativePath)
        }
        return root.appendingPathComponent(relativePath)
    }

    /// Staging file + atomic rename, so a crash never leaves a half-written file at the final path.
    public func write(_ data: Data, to relativePath: String) throws -> (byteCount: Int, sha256: String) {
        let final = try url(relativePath)
        try FileManager.default.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = final.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).staging")
        do {
            try data.write(to: staging, options: [.atomic, .completeFileProtection])
            if FileManager.default.fileExists(atPath: final.path) { try FileManager.default.removeItem(at: final) }
            try FileManager.default.moveItem(at: staging, to: final)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw FileStoreError.writeFailed("\(relativePath): \(error.localizedDescription)")
        }
        return (data.count, SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }

    public func remove(_ relativePath: String) throws {
        let u = try url(relativePath)
        guard FileManager.default.fileExists(atPath: u.path) else { return } // idempotent
        do { try FileManager.default.removeItem(at: u) } catch { throw FileStoreError.removeFailed(relativePath) }
    }

    public func exists(_ relativePath: String) -> Bool {
        (try? url(relativePath)).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    public func read(_ relativePath: String) throws -> Data { try Data(contentsOf: try url(relativePath)) }
}
