import Testing
import simd
@testable import Kfn8M0ProbeCore

@Suite struct ManipulationProbeStateTests {
    @Test func validReleaseCommits() {
        var state = ManipulationProbeState(affinity: .floor, initialPosition: SIMD3(0, 0, -1), isNewPlacement: true)
        state.willBegin(inputKinds: [.indirectPinch])
        state.didUpdate(position: SIMD3(0.5, 0, -1))
        state.willRelease(wasCancelled: false, resolution: .validAsReleased)
        state.willEnd()
        #expect(state.phase == .placed)
        #expect(state.isSaved)
        #expect(state.committedPosition == SIMD3(0.5, 0, -1))
        #expect(state.transcript.inputKinds == [.indirectPinch])
        #expect(state.statusCopy == nil)
    }

    @Test func resolvedReleaseMovesToValidatedCandidate() {
        var state = ManipulationProbeState(affinity: .tabletop, initialPosition: SIMD3(0, 0.75, -1), isNewPlacement: false)
        state.willBegin(inputKinds: [.directPinch])
        state.didUpdate(position: SIMD3(0.2, 0.75, -1))
        state.willRelease(wasCancelled: false, resolution: .resolved(SIMD3(0.25, 0.75, -1)))
        #expect(state.currentPosition == SIMD3(0.25, 0.75, -1))
        #expect(state.isSaved)
    }

    @Test func unresolvedReleaseStaysHeldAndUnsavedWithQuietCopy() {
        var state = ManipulationProbeState(affinity: .wall, initialPosition: SIMD3(0, 1.2, -2), isNewPlacement: false)
        state.willBegin(inputKinds: [.indirectPinch])
        state.didUpdate(position: SIMD3(0, 1.2, -0.5))
        state.willRelease(wasCancelled: false, resolution: .unresolved)
        #expect(state.phase == .heldInvalid)
        #expect(!state.isSaved)
        #expect(state.committedPosition == SIMD3(0, 1.2, -2), "committed state is preserved")
        #expect(state.currentPosition == SIMD3(0, 1.2, -0.5), "preview stays where released, no distant jump")
        #expect(state.statusCopy == "There isn't enough space here")
    }

    @Test func updatesAfterReleaseAreCountedAsContinuationEvidence() {
        var state = ManipulationProbeState(affinity: .floor, initialPosition: .zero, isNewPlacement: false)
        state.willBegin(inputKinds: [.indirectPinch])
        state.willRelease(wasCancelled: false, resolution: .unresolved)
        state.didUpdate(position: SIMD3(0.1, 0, 0))
        #expect(state.transcript.updatesAfterReleaseWithoutBegin == 1)
        state.willBegin(inputKinds: [.indirectPinch])
        state.didUpdate(position: SIMD3(0.2, 0, 0))
        #expect(state.transcript.updatesAfterReleaseWithoutBegin == 1, "a new begin resets the re-grab detection")
        #expect(state.transcript.begins == 2)
    }

    @Test func cancelRestoresPreDragPlacement() {
        var state = ManipulationProbeState(affinity: .floor, initialPosition: SIMD3(1, 0, 1), isNewPlacement: false)
        state.willBegin(inputKinds: [.pointer])
        state.didUpdate(position: SIMD3(2, 0, 2))
        state.willRelease(wasCancelled: true, resolution: .unresolved)
        #expect(state.phase == .placed)
        #expect(state.currentPosition == SIMD3(1, 0, 1))
        #expect(state.transcript.cancelledReleases == 1)
    }

    @Test func cancelRemovesNewPlacement() {
        var state = ManipulationProbeState(affinity: .ceiling, initialPosition: SIMD3(0, 2, 0), isNewPlacement: true)
        state.willBegin(inputKinds: [.indirectPinch])
        state.cancel()
        #expect(state.phase == .idle)
        #expect(state.committedPosition == nil)
    }

    @Test func transcriptSummaryMentionsEveryCounter() {
        var state = ManipulationProbeState(affinity: .wall, initialPosition: .zero, isNewPlacement: false)
        state.willBegin(inputKinds: [.directPinch])
        state.willRelease(wasCancelled: false, resolution: .unresolved)
        let summary = state.transcriptSummary
        #expect(summary.hasPrefix("wall:"))
        #expect(summary.contains("begins 1") && summary.contains("releases 1") && summary.contains("phase heldInvalid"))
        #expect(summary.contains("directPinch"))
    }

    @Test func handOffIsRecorded() {
        var state = ManipulationProbeState(affinity: .floor, initialPosition: .zero, isNewPlacement: false)
        state.willBegin(inputKinds: [.indirectPinch])
        state.didHandOff()
        #expect(state.transcript.handOffs == 1)
    }
}
