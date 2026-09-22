import Foundation

/// One observation recorded during a probe run. Written by the app to a JSON file the founder returns.
public struct EvidenceRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var probe: ProbeKind
    public var expected: String
    public var observed: String
    public var outcome: ProbeOutcome
    public var frameTimes: FrameTimeStatistics.Summary?

    public init(id: UUID = UUID(), timestamp: Date = Date(), probe: ProbeKind, expected: String, observed: String,
                outcome: ProbeOutcome, frameTimes: FrameTimeStatistics.Summary? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.probe = probe
        self.expected = expected
        self.observed = observed
        self.outcome = outcome
        self.frameTimes = frameTimes
    }
}

/// Environment facts captured on the device at launch. Blank strings are reported as blank, never guessed.
public struct EvidenceEnvironment: Codable, Sendable, Equatable {
    public var systemVersion: String
    public var deviceModel: String
    public var appBuild: String
    public var isSimulator: Bool

    public init(systemVersion: String, deviceModel: String, appBuild: String, isSimulator: Bool) {
        self.systemVersion = systemVersion
        self.deviceModel = deviceModel
        self.appBuild = appBuild
        self.isSimulator = isSimulator
    }
}

public struct EvidenceLog: Codable, Sendable, Equatable {
    public var environment: EvidenceEnvironment
    public private(set) var records: [EvidenceRecord] = []

    public init(environment: EvidenceEnvironment) {
        self.environment = environment
    }

    public mutating func append(_ record: EvidenceRecord) { records.append(record) }

    public func records(for probe: ProbeKind) -> [EvidenceRecord] { records.filter { $0.probe == probe } }

    /// Latest outcome per probe; `.notRun` when no record exists. Simulator records never count as device evidence.
    public func latestOutcome(for probe: ProbeKind) -> ProbeOutcome {
        guard !environment.isSimulator else { return .notRun }
        return records(for: probe).last?.outcome ?? .notRun
    }

    public var blockingGatesPassed: Bool {
        ProbeKind.allCases.filter(\.isBlocking).allSatisfy { latestOutcome(for: $0) == .passed }
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> EvidenceLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(EvidenceLog.self, from: data)
    }
}
