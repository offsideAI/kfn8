import Darwin
import Foundation
import Kfn8Domain

/// Frame times, memory, thermal state and model load times while the room view is open, written to the app's
/// Documents folder when it closes. Local only: never uploaded.
@MainActor
final class PerformanceMonitor {
    private var stats = FrameTimeStatistics(targetFrameRate: 60)
    private var worst: [Double] = []
    private var memory: [PerformanceTrace.MemorySample] = []
    private var loads: [PerformanceTrace.LoadSample] = []
    private var thermal: [String] = []
    private var started: Date?
    private var lastSample: TimeInterval = 0

    func begin() {
        stats.reset(); worst = []; memory = []; loads = []; thermal = []
        started = .now
        lastSample = 0
    }

    func frame(delta: Double) {
        guard let started else { return }
        stats.record(deltaTime: delta)
        worst.append(delta * 1000)
        if worst.count > 64 { worst = Array(worst.sorted(by: >).prefix(16)) }
        let t = Date().timeIntervalSince(started)
        if t - lastSample >= 1 {
            lastSample = t
            memory.append(.init(t: t, footprintBytes: Self.footprint()))
            let state = Self.describe(ProcessInfo.processInfo.thermalState)
            if thermal.last != state { thermal.append(state) }
        }
    }

    func recordLoad(asset: String, milliseconds: Double) { loads.append(.init(asset: asset, milliseconds: milliseconds)) }

    /// Writes `Documents/perf-<timestamp>.json` and returns its URL, or nil when nothing was measured.
    func end(placements: Int, activeLights: Int) throws -> URL? {
        guard let started, stats.count > 0 else { return nil }
        self.started = nil
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        let trace = PerformanceTrace(startedAt: started, durationSeconds: Date().timeIntervalSince(started), placements: placements,
                                     activeLights: activeLights, frames: stats.summary, worstFrameMilliseconds: Array(worst.sorted(by: >).prefix(10)),
                                     memory: memory, loads: loads, isSimulator: simulator)
        struct File: Encodable { var trace: PerformanceTrace; var thermalStates: [String] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let url = URL.documentsDirectory.appending(path: "perf-\(Int(started.timeIntervalSince1970)).json")
        try encoder.encode(File(trace: trace, thermalStates: thermal)).write(to: url, options: .atomic)
        return url
    }

    private static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    private static func describe(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
