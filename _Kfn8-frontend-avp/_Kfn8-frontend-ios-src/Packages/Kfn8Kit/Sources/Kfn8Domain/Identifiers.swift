import Foundation

/// Client-generated stable identifiers. Distinct types so a DesignID can never be passed where a RoomID is expected.
public protocol Kfn8Identifier: Hashable, Codable, Sendable, CustomStringConvertible {
    var rawValue: UUID { get }
    init(rawValue: UUID)
}

public extension Kfn8Identifier {
    init() { self.init(rawValue: UUID()) }
    var description: String { rawValue.uuidString }
}

public struct SpaceID: Kfn8Identifier { public let rawValue: UUID; public init(rawValue: UUID) { self.rawValue = rawValue } }
public struct RoomID: Kfn8Identifier { public let rawValue: UUID; public init(rawValue: UUID) { self.rawValue = rawValue } }
public struct DesignID: Kfn8Identifier { public let rawValue: UUID; public init(rawValue: UUID) { self.rawValue = rawValue } }
public struct PlacementID: Kfn8Identifier { public let rawValue: UUID; public init(rawValue: UUID) { self.rawValue = rawValue } }
public struct AssetID: Kfn8Identifier { public let rawValue: UUID; public init(rawValue: UUID) { self.rawValue = rawValue } }
public struct RevisionID: Kfn8Identifier { public let rawValue: UUID; public init(rawValue: UUID) { self.rawValue = rawValue } }
