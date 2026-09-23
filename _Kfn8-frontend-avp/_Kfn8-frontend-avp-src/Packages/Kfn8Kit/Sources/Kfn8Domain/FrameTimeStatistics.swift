import Foundation

/// Accumulates per-frame intervals (seconds) and summarises them. Pure value type; the app feeds it from a
/// RealityKit `System` using `SceneUpdateContext.deltaTime`. Nothing here is a claim about 90 Hz until a device run
/// produces the samples.
public struct FrameTimeStatistics: Sendable, Equatable {
    public private(set) var samples: [Double] = []
    public let targetFrameRate: Double
    /// Frames longer than the target interval by more than this fraction count as drops.
    public let dropTolerance: Double

    public init(targetFrameRate: Double = 90, dropTolerance: Double = 0.5) {
        precondition(targetFrameRate > 0)
        self.targetFrameRate = targetFrameRate
        self.dropTolerance = dropTolerance
    }

    public mutating func record(deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else { return }
        samples.append(deltaTime)
    }

    public mutating func reset() { samples.removeAll(keepingCapacity: true) }

    public var count: Int { samples.count }

    public var targetInterval: Double { 1 / targetFrameRate }

    public var droppedFrameCount: Int {
        let limit = targetInterval * (1 + dropTolerance)
        return samples.filter { $0 > limit }.count
    }

    public func percentile(_ p: Double) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let clamped = min(max(p, 0), 100)
        let rank = clamped / 100 * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = rank - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }

    public var maximum: Double? { samples.max() }

    public struct Summary: Codable, Sendable, Equatable {
        public var sampleCount: Int
        public var p50Milliseconds: Double?
        public var p95Milliseconds: Double?
        public var p99Milliseconds: Double?
        public var maxMilliseconds: Double?
        public var droppedFrames: Int
        public var targetFrameRate: Double
    }

    public var summary: Summary {
        Summary(sampleCount: count,
                p50Milliseconds: percentile(50).map { $0 * 1000 },
                p95Milliseconds: percentile(95).map { $0 * 1000 },
                p99Milliseconds: percentile(99).map { $0 * 1000 },
                maxMilliseconds: maximum.map { $0 * 1000 },
                droppedFrames: droppedFrameCount,
                targetFrameRate: targetFrameRate)
    }
}
