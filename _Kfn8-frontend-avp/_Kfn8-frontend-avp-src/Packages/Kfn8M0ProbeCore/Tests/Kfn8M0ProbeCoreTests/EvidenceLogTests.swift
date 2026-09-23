import Foundation
import Testing
@testable import Kfn8M0ProbeCore

@Suite struct EvidenceLogTests {
    private func environment(simulator: Bool) -> EvidenceEnvironment {
        EvidenceEnvironment(systemVersion: "27.0", deviceModel: "RealityDevice14,1", appBuild: "1", isSimulator: simulator)
    }

    @Test func defaultOutcomeIsNotRun() {
        let log = EvidenceLog(environment: environment(simulator: false))
        for probe in ProbeKind.allCases { #expect(log.latestOutcome(for: probe) == .notRun) }
        #expect(!log.blockingGatesPassed)
    }

    @Test func simulatorRecordsNeverCountAsDeviceEvidence() {
        var log = EvidenceLog(environment: environment(simulator: true))
        for probe in ProbeKind.allCases {
            log.append(EvidenceRecord(probe: probe, expected: "x", observed: "y", outcome: .passed))
        }
        #expect(log.latestOutcome(for: .lighting) == .notRun)
        #expect(!log.blockingGatesPassed)
    }

    @Test func blockingGatesRequireAllThreeDevicePasses() {
        var log = EvidenceLog(environment: environment(simulator: false))
        log.append(EvidenceRecord(probe: .lighting, expected: "lit", observed: "lit", outcome: .passed))
        log.append(EvidenceRecord(probe: .occlusion, expected: "hidden", observed: "hidden", outcome: .passed))
        #expect(!log.blockingGatesPassed)
        log.append(EvidenceRecord(probe: .manipulation, expected: "stay", observed: "stay", outcome: .passed))
        #expect(log.blockingGatesPassed)
        log.append(EvidenceRecord(probe: .manipulation, expected: "stay", observed: "reset", outcome: .failed))
        #expect(!log.blockingGatesPassed, "latest record wins; an earlier pass does not survive a later failure")
    }

    @Test func nonblockingFailuresDoNotAffectGate() {
        var log = EvidenceLog(environment: environment(simulator: false))
        for probe in ProbeKind.allCases.filter(\.isBlocking) {
            log.append(EvidenceRecord(probe: probe, expected: "", observed: "", outcome: .passed))
        }
        log.append(EvidenceRecord(probe: .export, expected: "", observed: "", outcome: .unavailable))
        log.append(EvidenceRecord(probe: .splat, expected: "", observed: "", outcome: .unavailable))
        #expect(log.blockingGatesPassed)
    }

    @Test func notesNeverChangeOutcomes() {
        var log = EvidenceLog(environment: environment(simulator: false))
        for probe in ProbeKind.allCases.filter(\.isBlocking) {
            log.append(EvidenceRecord(probe: probe, expected: "", observed: "", outcome: .passed))
        }
        log.note("auto transcript after close", probe: .manipulation)
        log.note("frame summary")
        #expect(log.notes.count == 2)
        #expect(log.blockingGatesPassed)
        #expect(log.latestOutcome(for: .manipulation) == .passed)
    }

    @Test func jsonRoundTrip() throws {
        var log = EvidenceLog(environment: environment(simulator: false))
        var stats = FrameTimeStatistics()
        stats.record(deltaTime: 1.0 / 90.0)
        // ISO 8601 encoding carries whole seconds only, so the fixture uses a whole-second timestamp on purpose.
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        log.append(EvidenceRecord(timestamp: timestamp, probe: .occlusion, expected: "e", observed: "o", outcome: .inconclusive, frameTimes: stats.summary))
        log.note("auto", probe: .manipulation, timestamp: timestamp)
        let data = try log.encodedJSON()
        let decoded = try EvidenceLog.decode(data)
        #expect(decoded == log)
        #expect(String(decoding: data, as: UTF8.self).contains("\"isSimulator\" : false"))
    }
}
