import Foundation
import Testing
@testable import Kfn8iOSProbeCore

let phone = DeviceInfo(model: "iPhone14,3", systemVersion: "27.0", appBuild: "1", isSimulator: false, hasDepthSensor: true, supportsPeopleOcclusion: true)

@Suite struct EvidenceTests {
    @Test func everyProbeHasUniqueChips() {
        for probe in ProbeID.allCases {
            let ids = probe.chips.map(\.id)
            #expect(!ids.isEmpty)
            #expect(Set(ids).count == ids.count, "duplicate chip in \(probe)")
        }
    }

    @Test func recordKeepsOnlyTheProbesChipsInListedOrder() {
        var log = EvidenceLog(device: phone)
        log.record(.occlusion, .passed, observations: ["edges-clean-still", "furniture-hid", "photo-room"], context: ["sceneOcclusion": "on"])
        #expect(log.records.first?.observations == ["furniture-hid", "edges-clean-still"])
        #expect(log.outcome(for: .occlusion) == .passed)
        #expect(log.outcome(for: .lighting) == nil)
    }

    @Test func latestDeviceRecordWinsAndSimulatorRecordsNeverCount() {
        var log = EvidenceLog(device: phone)
        log.record(.collision, .failed, observations: [], context: [:])
        log.record(.collision, .passed, observations: [], context: [:])
        #expect(log.outcome(for: .collision) == .passed)

        var sim = EvidenceLog(device: DeviceInfo(model: "arm64", systemVersion: "27.0", appBuild: "1", isSimulator: true, hasDepthSensor: false, supportsPeopleOcclusion: false))
        sim.record(.photo, .passed, observations: ["photo-room"], context: [:])
        #expect(sim.records.count == 1)
        #expect(sim.outcome(for: .photo) == nil)
    }

    @Test func jsonRoundTripIsExact() throws {
        var log = EvidenceLog(device: phone)
        log.record(.relocalization, .inconclusive, observations: ["marker-shifted"], context: ["seconds": "4.2"],
                   at: Date(timeIntervalSince1970: 1_791_000_000.123_456))
        log.note("founder: tried in the kitchen too")
        #expect(try EvidenceLog.decoded(from: log.encoded()) == log)
    }
}

@Suite struct RelocalizationTests {
    @Test func foundWithinBudgetReportsSeconds() {
        var a = RelocalizationAttempt(budgetSeconds: 30)
        a.start(at: 100)
        a.tick(at: 110)
        a.markerRestored(at: 104.5 + 6)
        #expect(a.state == .found(seconds: 10.5))
    }

    @Test func budgetEndsTheAttemptAndLateMarkersDoNotRevive() {
        var a = RelocalizationAttempt(budgetSeconds: 30)
        a.start(at: 0)
        a.tick(at: 29.9)
        #expect(a.state == .searching(startedAt: 0))
        a.tick(at: 31)
        #expect(a.state == .notFound(afterSeconds: 31))
        a.markerRestored(at: 32)
        #expect(a.state == .notFound(afterSeconds: 31))
    }

    @Test func markerWithoutAnAttemptIsIgnored() {
        var a = RelocalizationAttempt()
        a.markerRestored(at: 5)
        #expect(a.state == .idle)
    }
}

@Suite struct PhotoFlowTests {
    @Test func noCaptureWithoutConsent() {
        var f = PhotoFlow()
        let began1 = f.beginCapture()
        #expect(!began1)
        #expect(f.step == .needsConsent)
    }

    @Test func consentedCaptureSavesOrReportsDenial() {
        var f = PhotoFlow()
        f.setConsent(true)
        let began2 = f.beginCapture()
        #expect(began2)
        let began3 = f.beginCapture()
        #expect(!began3, "no second capture while one is running")
        f.captured(bytes: 2048)
        f.photosResult(saved: true)
        #expect(f.step == .savedToPhotos(bytes: 2048))

        let began4 = f.beginCapture()
        #expect(began4)
        f.captured(bytes: 4096)
        f.photosResult(saved: false)
        #expect(f.step == .photosDenied(bytes: 4096))
    }

    @Test func withdrawingConsentBlocksTheNextCaptureAndFailuresAreKept() {
        var f = PhotoFlow()
        f.setConsent(true)
        f.setConsent(false)
        let began5 = f.beginCapture()
        #expect(!began5)
        f.setConsent(true)
        let began6 = f.beginCapture()
        #expect(began6)
        f.captureFailed("snapshot returned no image")
        #expect(f.step == .failed("snapshot returned no image"))
    }
}
