import Foundation

/// The four device questions of I0.S2 (T3–T6), with occlusion split from collision so each has its own outcome.
public enum ProbeID: String, Codable, CaseIterable, Sendable {
    case relocalization, collision, occlusion, lighting, photo

    public var title: String {
        switch self {
        case .relocalization: "Find the room again"
        case .collision: "Real-world collision"
        case .occlusion: "Occlusion"
        case .lighting: "Lighting"
        case .photo: "Room photo"
        }
    }

    /// Observation chips: tap the ones that are true, then record. No typing on the device.
    public var chips: [Chip] {
        switch self {
        case .relocalization: [
            Chip("marker-same-spot", "Marker came back in the same spot"),
            Chip("marker-shifted", "Marker came back, but shifted"),
            Chip("never-found", "Room was never found"),
            Chip("other-room-nothing", "In a different room, nothing appeared"),
            Chip("other-room-false", "In a different room, the marker appeared anyway"),
        ]
        case .collision: [
            Chip("clear-resting", "Clear while resting on the floor"),
            Chip("blocked-in-furniture", "Blocked when pushed into furniture"),
            Chip("false-block", "Blocked while only resting on the floor"),
            Chip("missed-furniture", "Not blocked inside furniture"),
        ]
        case .occlusion: [
            Chip("furniture-hid", "Furniture hid the box"),
            Chip("edges-clean-still", "Edges clean while still"),
            Chip("flicker-moving", "Lag or flicker while moving"),
            Chip("person-hid", "A person hid the box"),
            Chip("no-occlusion", "No occlusion seen"),
        ]
        case .lighting: [
            Chip("wall-brightened", "The real wall brightened"),
            Chip("blocky-light", "Light on the wall looked blocky or patchy"),
            Chip("only-virtual-lit", "Only the virtual box was lit"),
            Chip("no-change", "No visible change"),
        ]
        case .photo: [
            Chip("photo-room", "Photo shows the real room"),
            Chip("photo-furniture", "Photo shows the furniture"),
            Chip("photo-blank", "Photo is black or empty"),
            Chip("photo-opened", "Opened the photo in Photos"),
        ]
        }
    }
}

public struct Chip: Hashable, Sendable, Identifiable {
    public let id: String
    public let text: String
    public init(_ id: String, _ text: String) { self.id = id; self.text = text }
}

public enum Outcome: String, Codable, Sendable, CaseIterable {
    case passed, failed, inconclusive
}

/// Where the evidence came from. Simulator records are kept but never count toward an outcome.
public struct DeviceInfo: Codable, Sendable, Equatable {
    public var model: String
    public var systemVersion: String
    public var appBuild: String
    public var isSimulator: Bool
    public var hasDepthSensor: Bool
    public var supportsPeopleOcclusion: Bool
    public init(model: String, systemVersion: String, appBuild: String, isSimulator: Bool, hasDepthSensor: Bool, supportsPeopleOcclusion: Bool) {
        self.model = model; self.systemVersion = systemVersion; self.appBuild = appBuild
        self.isSimulator = isSimulator; self.hasDepthSensor = hasDepthSensor; self.supportsPeopleOcclusion = supportsPeopleOcclusion
    }
}

public struct EvidenceRecord: Codable, Sendable, Equatable {
    public var probe: ProbeID
    public var outcome: Outcome
    /// Chip IDs that were selected, in the order the probe lists them.
    public var observations: [String]
    /// Automatic context captured by the app at the moment of recording.
    public var context: [String: String]
    public var recordedAt: Date
    public var isSimulator: Bool
}

public struct EvidenceLog: Codable, Sendable, Equatable {
    public var device: DeviceInfo
    public private(set) var records: [EvidenceRecord] = []
    public private(set) var notes: [String] = []

    public init(device: DeviceInfo) { self.device = device }

    /// Records one outcome. Observations are reduced to the probe's own chips, in its listed order.
    public mutating func record(_ probe: ProbeID, _ outcome: Outcome, observations: Set<String>, context: [String: String], at date: Date = .now) {
        let ordered = probe.chips.map(\.id).filter(observations.contains)
        // Millisecond precision, so the JSON file round-trips exactly.
        let stamp = Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
        records.append(EvidenceRecord(probe: probe, outcome: outcome, observations: ordered, context: context,
                                      recordedAt: stamp, isSimulator: device.isSimulator))
    }

    public mutating func note(_ text: String) { notes.append(text) }

    /// The latest device (non-simulator) outcome for a probe, if any.
    public func outcome(for probe: ProbeID) -> Outcome? {
        records.last { $0.probe == probe && !$0.isSimulator }?.outcome
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .millisecondsSince1970
        return try e.encode(self)
    }

    public static func decoded(from data: Data) throws -> EvidenceLog {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return try d.decode(EvidenceLog.self, from: data)
    }
}
