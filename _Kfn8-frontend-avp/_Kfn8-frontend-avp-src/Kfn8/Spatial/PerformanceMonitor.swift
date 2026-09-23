import Darwin
import Foundation
import Kfn8Domain
import RealityKit

/// Samples RealityKit update deltas and process memory while the room view is open, then writes a local trace.
@MainActor
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private(set) var stats = FrameTimeStatistics(targetFrameRate: 90)
    private var worst: [Double] = []
    private var memory: [PerformanceTrace.MemorySample] = []
    private var loads: [PerformanceTrace.LoadSample] = []
    private var started: Date?
    private var lastMemorySample: TimeInterval = 0

    func begin() {
        stats.reset(); worst = []; memory = []; loads = []
        started = .now
        lastMemorySample = 0
    }

    func frame(_ delta: Double) {
        guard let started else { return }
        stats.record(deltaTime: delta)
        worst.append(delta * 1000)
        if worst.count > 64 { worst.sort(by: >); worst.removeLast(worst.count - 32) }
        let t = Date.now.timeIntervalSince(started)
        if t - lastMemorySample >= 1 {
            lastMemorySample = t
            memory.append(.init(t: t, footprintBytes: Self.footprint()))
        }
    }

    func recordLoad(asset: String, milliseconds: Double) { loads.append(.init(asset: asset, milliseconds: milliseconds)) }

    /// Writes Documents/perf-<timestamp>.json and returns its URL.
    @discardableResult
    func end(placements: Int, activeLights: Int) -> URL? {
        guard let started else { return nil }
        self.started = nil
        #if targetEnvironment(simulator)
        let sim = true
        #else
        let sim = false
        #endif
        let trace = PerformanceTrace(startedAt: started, durationSeconds: Date.now.timeIntervalSince(started), placements: placements,
                                     activeLights: activeLights, frames: stats.summary, worstFrameMilliseconds: Array(worst.sorted(by: >).prefix(10)),
                                     memory: memory, loads: loads, isSimulator: sim)
        guard let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        let url = dir.appendingPathComponent("perf-\(Int(started.timeIntervalSince1970)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do { try encoder.encode(trace).write(to: url, options: .atomic) } catch { placementLog.error("trace write failed: \(error.localizedDescription, privacy: .public)"); return nil }
        return url
    }

    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}

/// Feeds RealityKit's update delta into the monitor.
struct PerformanceSystem: System {
    static let dependencies: [SystemDependency] = []
    init(scene: RealityKit.Scene) {}
    mutating func update(context: SceneUpdateContext) { PerformanceMonitor.shared.frame(context.deltaTime) }
}
