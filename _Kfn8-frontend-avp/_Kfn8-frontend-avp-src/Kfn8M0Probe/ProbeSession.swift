import Foundation
import Kfn8M0ProbeCore
import Observation
import RealityKit
import simd

/// Main-actor owner of all probe control state, the RealityKit fixture scene and the evidence log.
@MainActor
@Observable
final class ProbeSession {
    static let controlWindowID = "kfn8-m0-control"
    static let immersiveSpaceID = "kfn8-m0-immersive"

    var lighting = LightingProbeState()
    var occlusion = OcclusionProbeState()
    var export = ExportProbeState()
    var manipulation: [AttachmentAffinity: ManipulationProbeState] = [:]
    var evidence: EvidenceLog
    var lastError: String?
    var evidenceFileURL: URL?
    var isImmersiveOpen = false
    /// Keeps RealityKit event subscriptions alive for the life of the immersive scene.
    @ObservationIgnored var subscriptions: [EventSubscription] = []

    let scene = ProbeScene()
    let surfaces = SurfaceTracker()
    let exporter = ExportProbeCoordinator()

    init() {
        evidence = EvidenceLog(environment: ProbeSession.captureEnvironment())
        for affinity in AttachmentAffinity.allCases {
            manipulation[affinity] = ManipulationProbeState(affinity: affinity,
                                                            initialPosition: ProbeScene.initialPosition(for: affinity),
                                                            isNewPlacement: false)
        }
        exporter.session = self
    }

    // MARK: Evidence

    func record(_ probe: ProbeKind, expected: String, observed: String, outcome: ProbeOutcome, includeFrameTimes: Bool = true) {
        let summary = includeFrameTimes && FrameTimeSink.shared.statistics.count > 0 ? FrameTimeSink.shared.statistics.summary : nil
        evidence.append(EvidenceRecord(probe: probe, expected: expected, observed: observed, outcome: outcome, frameTimes: summary))
        writeEvidence()
    }

    func writeEvidence() {
        do {
            let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let url = directory.appendingPathComponent("M0-EVIDENCE.json")
            try evidence.encodedJSON().write(to: url, options: .atomic)
            evidenceFileURL = url
        } catch {
            lastError = "Evidence write failed: \(error.localizedDescription)"
        }
    }

    var frameSummary: FrameTimeStatistics.Summary { FrameTimeSink.shared.statistics.summary }

    // MARK: Lighting

    func toggleLight() {
        lighting.toggleLight()
        scene.applyLighting(lighting)
    }

    func applyLightingChanges() { scene.applyLighting(lighting) }

    // MARK: Occlusion

    func toggleOcclusionMode() {
        occlusion.toggleMode()
        scene.applyOcclusion(occlusion)
    }

    // MARK: Manipulation lifecycle, driven by ManipulationEvents in the immersive view

    func manipulationWillBegin(affinity: AttachmentAffinity, inputKinds: Set<ManipulationProbeState.InputKind>) {
        manipulation[affinity]?.willBegin(inputKinds: inputKinds)
    }

    func manipulationDidUpdate(affinity: AttachmentAffinity, position: SIMD3<Float>) {
        manipulation[affinity]?.didUpdate(position: position)
        let intersecting = scene.intersectsRealWorld(affinity: affinity, at: position)
        scene.setIntersectionCue(affinity: affinity, active: intersecting)
    }

    func manipulationDidHandOff(affinity: AttachmentAffinity) {
        manipulation[affinity]?.didHandOff()
    }

    func manipulationWillRelease(affinity: AttachmentAffinity, wasCancelled: Bool, releasedPosition: SIMD3<Float>, releasedYaw: Float) {
        guard var state = manipulation[affinity] else { return }
        let resolution = resolveRelease(affinity: affinity, releasedPosition: releasedPosition, releasedYaw: releasedYaw)
        state.willRelease(wasCancelled: wasCancelled, resolution: resolution)
        manipulation[affinity] = state
        scene.setIntersectionCue(affinity: affinity, active: state.phase == .heldInvalid)
        switch state.phase {
        case .placed:
            if let attached = attachedPose(affinity: affinity, position: state.currentPosition, yaw: releasedYaw) {
                scene.apply(pose: attached, to: affinity)
            } else {
                scene.apply(position: state.currentPosition, to: affinity)
            }
        case .heldInvalid, .idle, .manipulating:
            break
        }
    }

    func manipulationWillEnd(affinity: AttachmentAffinity) {
        manipulation[affinity]?.willEnd()
    }

    /// Non-gesture cancel path (accessibility requirement): restores the committed placement.
    func cancelManipulation(affinity: AttachmentAffinity) {
        guard var state = manipulation[affinity] else { return }
        state.cancel()
        manipulation[affinity] = state
        scene.setIntersectionCue(affinity: affinity, active: false)
        scene.apply(position: state.currentPosition, to: affinity)
    }

    /// Non-gesture nudge (accessibility requirement): moves the fixture by a fixed step and runs the same release logic.
    func nudge(affinity: AttachmentAffinity, by offset: SIMD3<Float>) {
        guard let current = scene.position(of: affinity) else { return }
        let target = current + offset
        manipulation[affinity]?.willBegin(inputKinds: [.unknown])
        manipulation[affinity]?.didUpdate(position: target)
        scene.apply(position: target, to: affinity)
        manipulationWillRelease(affinity: affinity, wasCancelled: false, releasedPosition: target, releasedYaw: scene.yaw(of: affinity))
        manipulationWillEnd(affinity: affinity)
    }

    private func attachedPose(affinity: AttachmentAffinity, position: SIMD3<Float>, yaw: Float) -> AttachedPose? {
        AttachmentResolver.resolve(affinity: affinity, releasedPosition: position, releasedYaw: yaw, surfaces: surfaces.detected)
    }

    private func resolveRelease(affinity: AttachmentAffinity, releasedPosition: SIMD3<Float>, releasedYaw: Float) -> ReleaseResolution {
        let resolver = ReleaseResolver()
        return resolver.resolve(released: releasedPosition) { candidate in
            guard let attached = attachedPose(affinity: affinity, position: candidate, yaw: releasedYaw) else {
                // Without any detected compatible surface the probe cannot claim validity. Reported, not hidden.
                return surfaces.detected.isEmpty ? !scene.intersectsRealWorld(affinity: affinity, at: candidate) : false
            }
            return !scene.intersectsRealWorld(affinity: affinity, at: attached.position)
        }
    }

    // MARK: Environment

    private static func captureEnvironment() -> EvidenceEnvironment {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        return EvidenceEnvironment(systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                                   deviceModel: model, appBuild: build, isSimulator: simulator)
    }
}
