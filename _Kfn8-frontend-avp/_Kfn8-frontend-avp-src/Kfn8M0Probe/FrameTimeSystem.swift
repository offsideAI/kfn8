import Kfn8M0ProbeCore
import RealityKit
import os

private let log = Logger(subsystem: "com.appliaison.kfn8.m0probe", category: "frametime")

/// Samples RealityKit's per-update delta time. Registered once per scene; feeds the shared sink on the main actor.
struct FrameTimeSystem: System {
    static let dependencies: [SystemDependency] = []

    init(scene: Scene) { log.info("FrameTimeSystem created") }

    mutating func update(context: SceneUpdateContext) {
        FrameTimeSink.shared.record(deltaTime: context.deltaTime)
    }
}

@MainActor
final class FrameTimeSink {
    static let shared = FrameTimeSink()
    private(set) var statistics = FrameTimeStatistics(targetFrameRate: 90)
    var isRecording = false

    func record(deltaTime: Double) {
        guard isRecording else { return }
        if statistics.count == 0 { log.info("first frame sample \(deltaTime, privacy: .public)") }
        statistics.record(deltaTime: deltaTime)
    }

    func reset() { statistics.reset() }
}
