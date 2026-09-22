import Testing
import simd
@testable import Kfn8M0ProbeCore

@Suite struct ReleaseResolverTests {
    @Test func validReleaseIsUntouched() {
        let resolver = ReleaseResolver()
        #expect(resolver.resolve(released: SIMD3(1, 0, 1)) { _ in true } == .validAsReleased)
    }

    @Test func candidatesNeverExceedSearchLimit() {
        let resolver = ReleaseResolver(searchLimit: 0.25, step: 0.05)
        let offsets = resolver.candidateOffsets()
        #expect(offsets.count == 25)
        #expect(offsets.allSatisfy { simd_length($0) <= 0.25 + 1e-5 })
        #expect(simd_length(offsets.first!) == 0.05)
    }

    @Test func shortestAxisPushOutWinsWhenValid() {
        let resolver = ReleaseResolver()
        let result = resolver.resolve(released: SIMD3(0, 0, 0), penetrationPushOut: SIMD3(0, 0, 0.03)) { $0.z >= 0.03 }
        #expect(result == .resolved(SIMD3(0, 0, 0.03)))
    }

    @Test func pushOutBeyondLimitIsIgnored() {
        let resolver = ReleaseResolver()
        let result = resolver.resolve(released: SIMD3(0, 0, 0), penetrationPushOut: SIMD3(0, 0, 0.6)) { $0.z >= 0.6 }
        #expect(result == .unresolved, "a 60 cm jump is a distant jump and must not happen")
    }

    @Test func nearestValidCandidateIsChosen() {
        let resolver = ReleaseResolver()
        let result = resolver.resolve(released: SIMD3(0, 0, 0)) { $0.x <= -0.1 }
        #expect(result == .resolved(SIMD3(-0.1, 0, 0)))
    }

    @Test func unresolvedWhenNothingWithinLimitValidates() {
        let resolver = ReleaseResolver()
        #expect(resolver.resolve(released: SIMD3(0, 0, 0)) { _ in false } == .unresolved)
    }
}
