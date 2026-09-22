import Testing
@testable import Kfn8M0ProbeCore

@Suite struct FrameTimeStatisticsTests {
    @Test func emptyStatisticsReportNil() {
        let stats = FrameTimeStatistics()
        #expect(stats.percentile(50) == nil)
        #expect(stats.maximum == nil)
        #expect(stats.summary.sampleCount == 0)
        #expect(stats.summary.droppedFrames == 0)
    }

    @Test func ignoresInvalidSamples() {
        var stats = FrameTimeStatistics()
        stats.record(deltaTime: 0)
        stats.record(deltaTime: -1)
        stats.record(deltaTime: .nan)
        stats.record(deltaTime: .infinity)
        #expect(stats.count == 0)
    }

    @Test func percentilesAndDropsAt90Hz() {
        var stats = FrameTimeStatistics(targetFrameRate: 90, dropTolerance: 0.5)
        let steady = 1.0 / 90.0
        for _ in 0..<99 { stats.record(deltaTime: steady) }
        stats.record(deltaTime: steady * 3) // one clear drop
        #expect(stats.count == 100)
        #expect(stats.droppedFrameCount == 1)
        #expect(abs((stats.percentile(50) ?? 0) - steady) < 1e-9)
        #expect(stats.maximum == steady * 3)
        let summary = stats.summary
        #expect(summary.droppedFrames == 1)
        #expect(abs((summary.p50Milliseconds ?? 0) - steady * 1000) < 1e-6)
        #expect(summary.maxMilliseconds == steady * 3000)
    }

    @Test func percentileInterpolates() {
        var stats = FrameTimeStatistics()
        for value in [1.0, 2.0, 3.0, 4.0] { stats.record(deltaTime: value) }
        #expect(stats.percentile(50) == 2.5)
        #expect(stats.percentile(0) == 1)
        #expect(stats.percentile(100) == 4)
        #expect(stats.percentile(150) == 4)
    }
}
