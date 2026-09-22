import Foundation
import Testing
@testable import Kfn8M0ProbeCore

@Suite struct LightingProbeStateTests {
    @Test func comparisonRequiresLightOn() {
        var state = LightingProbeState()
        let recordedWhileOff = state.recordComparison(observedOnWall: "none", observedOnFloor: "none", frameTimes: nil)
        #expect(!recordedWhileOff)
        state.toggleLight()
        let recordedWhileOn = state.recordComparison(observedOnWall: "brighter", observedOnFloor: "pool of light", frameTimes: nil)
        #expect(recordedWhileOn)
        #expect(state.comparisons.count == 1)
        #expect(state.comparisons[0].surroundingsLightingEnabled)
    }

    @Test func expectedBehaviourTracksSurroundingsFlag() {
        var state = LightingProbeState()
        #expect(state.expectedBehaviour.contains("brightens the real wall"))
        state.surroundingsLightingEnabled = false
        #expect(state.expectedBehaviour.contains("do not change"))
    }
}

@Suite struct OcclusionProbeStateTests {
    @Test func toggleAlternatesModes() {
        var state = OcclusionProbeState()
        #expect(state.mode == .occludedBySurroundings)
        state.toggleMode()
        #expect(state.mode == .defaultBlending)
        state.toggleMode()
        #expect(state.mode == .occludedBySurroundings)
    }

    @Test func observationsCaptureModeAndDistance() {
        var state = OcclusionProbeState()
        state.objectDistanceMetres = 2
        state.record(edgeQuality: "clean", artifactsWhileMoving: "slight lag at edges", frameTimes: nil)
        #expect(state.observations.count == 1)
        #expect(state.observations[0].distanceMetres == 2)
        #expect(state.observations[0].mode == .occludedBySurroundings)
    }
}

@Suite struct ExportProbeStateTests {
    @Test func captureIsImpossibleWithoutConsent() {
        var state = ExportProbeState()
        #expect(!state.canCapture)
        let began = state.beginCapture()
        #expect(!began)
        #expect(state.phase == .awaitingConsent)
    }

    @Test func consentThenCaptureThenFile() {
        var state = ExportProbeState()
        state.grantConsent()
        #expect(state.canCapture)
        let began = state.beginCapture()
        #expect(began)
        let url = URL(fileURLWithPath: "/tmp/probe.png")
        state.finishCapture(fileURL: url, byteCount: 1234)
        #expect(state.phase == .captured(fileURL: url, byteCount: 1234))
    }

    @Test func emptyFileIsFailure() {
        var state = ExportProbeState()
        state.grantConsent()
        _ = state.beginCapture()
        state.finishCapture(fileURL: URL(fileURLWithPath: "/tmp/empty.png"), byteCount: 0)
        #expect(state.phase == .failed("Empty file written"))
    }

    @Test func revokingConsentReturnsToStart() {
        var state = ExportProbeState()
        state.grantConsent()
        state.revokeConsent()
        #expect(!state.canCapture)
    }

    @Test func unavailableIsRecordedNotSubstituted() {
        var state = ExportProbeState()
        state.markUnavailable("No passthrough pixels in captured frame")
        #expect(state.phase == .unavailable("No passthrough pixels in captured frame"))
        #expect(!state.canCapture)
    }
}
