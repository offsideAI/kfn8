import Foundation

/// Structured API failure mapped from `{code, message, request_id}`.
public enum CatalogueError: Error, Equatable, Sendable {
    case notFound
    case revoked
    case invalidRequest(String)
    case rateLimited
    case unavailable
    case transport(String)
    case decoding(String)
    case http(Int, String)
}

/// Performs a request. Abstracted so tests can supply canned responses without a server.
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CatalogueError.transport("non-HTTP response") }
        return (data, http)
    }
}

/// Anonymous read-only client for API v1. No account, no device identifier, no analytics headers.
public struct CatalogueClient: Sendable {
    public let baseURL: URL
    let transport: any HTTPTransport

    public init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: s) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad date \(s)"))
        }
        return d
    }()

    func get<T: Decodable>(_ path: String, query: [String: String?] = [:]) async throws(CatalogueError) -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        let items = query.compactMap { k, v in v.map { URLQueryItem(name: k, value: $0) } }.sorted { $0.name < $1.name }
        components.queryItems = items.isEmpty ? nil : items
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport.data(for: request) } catch let e as CatalogueError { throw e } catch {
            throw .transport(error.localizedDescription)
        }
        guard (200..<300).contains(response.statusCode) else {
            let body = try? Self.decoder.decode(ErrorBody.self, from: data)
            switch response.statusCode {
            case 404: throw .notFound
            case 410: throw .revoked
            case 400: throw .invalidRequest(body?.message ?? "")
            case 429: throw .rateLimited
            case 503: throw .unavailable
            default: throw .http(response.statusCode, body?.message ?? "")
            }
        }
        do { return try Self.decoder.decode(T.self, from: data) } catch { throw .decoding("\(error)") }
    }

    public func assets(query: String? = nil, category: String? = nil, affinity: String? = nil, cursor: String? = nil, limit: Int = 30) async throws(CatalogueError) -> AssetPage {
        try await get("v1/assets", query: ["q": query, "category": category, "affinity": affinity, "cursor": cursor, "limit": String(limit)])
    }

    public func asset(_ id: UUID) async throws(CatalogueError) -> AssetDetail { try await get("v1/assets/\(id.uuidString.lowercased())") }

    public func revision(asset: UUID, revision: Int) async throws(CatalogueError) -> RevisionDetail {
        try await get("v1/assets/\(asset.uuidString.lowercased())/revisions/\(revision)")
    }

    public func revocations(after cursor: String?) async throws(CatalogueError) -> RevocationPage {
        try await get("v1/revocations", query: ["cursor": cursor])
    }
}
