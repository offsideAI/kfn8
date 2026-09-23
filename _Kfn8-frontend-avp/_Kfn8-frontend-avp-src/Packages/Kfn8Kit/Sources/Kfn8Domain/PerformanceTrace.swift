import Foundation

/// Local performance trace for M4 evidence. Written to the app's Documents on the device; never uploaded.
public struct PerformanceTrace: Codable, Sendable, Equatable {
    public struct MemorySample: Codable, Sendable, Equatable {
        public var t: TimeInterval
        public var footprintBytes: UInt64
        public init(t: TimeInterval, footprintBytes: UInt64) { self.t = t; self.footprintBytes = footprintBytes }
    }
    public struct LoadSample: Codable, Sendable, Equatable {
        public var asset: String
        public var milliseconds: Double
        public init(asset: String, milliseconds: Double) { self.asset = asset; self.milliseconds = milliseconds }
    }

    public var startedAt: Date
    public var durationSeconds: TimeInterval
    public var placements: Int
    public var activeLights: Int
    public var frames: FrameTimeStatistics.Summary
    public var worstFrameMilliseconds: [Double]
    public var memory: [MemorySample]
    public var loads: [LoadSample]
    public var isSimulator: Bool

    public init(startedAt: Date, durationSeconds: TimeInterval, placements: Int, activeLights: Int, frames: FrameTimeStatistics.Summary,
                worstFrameMilliseconds: [Double], memory: [MemorySample], loads: [LoadSample], isSimulator: Bool) {
        self.startedAt = startedAt; self.durationSeconds = durationSeconds; self.placements = placements; self.activeLights = activeLights
        self.frames = frames; self.worstFrameMilliseconds = worstFrameMilliseconds; self.memory = memory; self.loads = loads; self.isSimulator = isSimulator
    }

    public var peakFootprintBytes: UInt64 { memory.map(\.footprintBytes).max() ?? 0 }

    /// The M4 acceptance target: 15 continuous minutes, 20 placements, two lights, 90 Hz, zero dropped frames, on a
    /// real M2. Simulator traces never meet it.
    public var meetsM4Target: Bool {
        !isSimulator && durationSeconds >= 15 * 60 && placements >= 20 && activeLights >= 2 && frames.droppedFrames == 0 && frames.targetFrameRate == 90
    }
}
