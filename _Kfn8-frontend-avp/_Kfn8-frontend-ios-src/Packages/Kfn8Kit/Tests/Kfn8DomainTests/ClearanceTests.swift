import Testing
import simd
@testable import Kfn8Domain

@Suite struct ClearanceTests {
    @Test func consistentSamplesGiveARoundedGapNotAVerdict() {
        let r = Clearance.reading(side: .left, samples: [0.452, 0.458, 0.455])
        #expect(r.text == "Left: about 46 cm gap" && !r.isWithheld)
        #expect(!r.text.lowercased().contains("fit"))
    }

    @Test func largeGapsRoundToFiveCentimetres() {
        #expect(Clearance.reading(side: .front, samples: [1.234]).text == "Front: about 1.25 m gap")
    }

    @Test func disagreeingSamplesBecomeARange() {
        #expect(Clearance.reading(side: .right, samples: [0.40, 0.47]).text == "Right: 40–50 cm gap")
    }

    @Test func noCoverageIsWithheldWithRescanHint() {
        let r = Clearance.reading(side: .back, samples: [])
        #expect(r.isWithheld && r.text.contains("rescan"))
    }

    @Test func gapBetweenBoxesOnEachSide() throws {
        let chair = OrientedBox(basePivot: .identity, size: SIMD3(0.8, 1, 0.9))
        let sofaRight = OrientedBox(basePivot: RigidTransform(translation: SIMD3(1.4, 0, 0)), size: SIMD3(0.6, 0.8, 2))
        let g = try #require(Clearance.gap(item: chair, obstacle: sofaRight, side: .right))
        #expect(abs(g - 0.7) < 1e-4)
        #expect(Clearance.gap(item: chair, obstacle: sofaRight, side: .left) == nil)
        let farAhead = OrientedBox(basePivot: RigidTransform(translation: SIMD3(3, 0, -3)), size: SIMD3(0.5, 1, 0.5))
        #expect(Clearance.gap(item: chair, obstacle: farAhead, side: .front) == nil, "not in the item's front corridor")
    }
}

@Suite struct PerformanceTraceTests {
    func trace(_ drops: Int, sim: Bool = false, minutes: Double = 15) -> PerformanceTrace {
        var s = FrameTimeStatistics(targetFrameRate: 90)
        for _ in 0..<100 { s.record(deltaTime: 1.0 / 90.0) }
        for _ in 0..<drops { s.record(deltaTime: 3.0 / 90.0) }
        return PerformanceTrace(startedAt: .now, durationSeconds: minutes * 60, placements: 20, activeLights: 2, frames: s.summary,
                                worstFrameMilliseconds: [], memory: [.init(t: 0, footprintBytes: 1_000), .init(t: 1, footprintBytes: 5_000)], loads: [], isSimulator: sim)
    }

    @Test func targetRequiresDeviceDurationAndZeroDrops() {
        #expect(trace(0).meetsM4Target)
        #expect(!trace(1).meetsM4Target, "one dropped frame fails; no average-only pass")
        #expect(!trace(0, sim: true).meetsM4Target, "simulator traces never count")
        #expect(!trace(0, minutes: 14).meetsM4Target)
        #expect(trace(0).peakFootprintBytes == 5_000)
    }
}
