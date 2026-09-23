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
    /// RealityKit's own scene understanding (what Apple says SurroundingsLight projects onto). Distinct from the
    /// ARKit providers in SurfaceTracker, which feed placement validation.
    private let spatialTracking = SpatialTrackingSession()
    var sceneUnderstandingStatus = "not started"
    /// Set by the remote channel; the control view observes it and calls the SwiftUI open/dismiss actions.
    var remoteSpaceRequest: Bool?
    @ObservationIgnored private var remote: RemoteCommandChannel?

    init() {
        evidence = EvidenceLog(environment: ProbeSession.captureEnvironment())
        for affinity in AttachmentAffinity.allCases {
            manipulation[affinity] = ManipulationProbeState(affinity: affinity,
                                                            initialPosition: ProbeScene.initialPosition(for: affinity),
                                                            isNewPlacement: false)
        }
        exporter.session = self
        evidence.note("app launched; evidence file is written automatically on launch, after each manipulation and on immersive close")
        writeEvidence()
        remote = RemoteCommandChannel(session: self)
        remote?.start()
    }

    func startSpatialTracking() async {
        let configuration = SpatialTrackingSession.Configuration(tracking: [.world, .plane], sceneUnderstanding: [.collision, .physics])
        let unavailable = await spatialTracking.run(configuration)
        if let unavailable {
            sceneUnderstandingStatus = "running; unavailable anchor \(unavailable.anchor) sceneUnderstanding \(unavailable.sceneUnderstanding)"
        } else {
            sceneUnderstandingStatus = "running; all requested capabilities available"
        }
        evidence.note("SpatialTrackingSession: \(sceneUnderstandingStatus)")
        writeEvidence()
    }

    var lampDiagnostic: String { scene.lampComponentSummary }

    /// Called by the app when the immersive space opens or closes; snapshots frame statistics and transcripts.
    func immersiveSpaceDidChange(isOpen: Bool) {
        isImmersiveOpen = isOpen
        if isOpen {
            evidence.note("immersive space opened; surfaces: \(surfaces.detected.count) planes, \(surfaces.meshAnchorCount) mesh anchors; ARKit \(surfaces.providerState); scene understanding \(sceneUnderstandingStatus)")
        } else {
            let s = frameSummary
            evidence.note("immersive space closed; frames n=\(s.sampleCount) p50=\(s.p50Milliseconds ?? 0) p95=\(s.p95Milliseconds ?? 0) p99=\(s.p99Milliseconds ?? 0) max=\(s.maxMilliseconds ?? 0) drops=\(s.droppedFrames); surfaces \(surfaces.detected.count) planes, \(surfaces.meshAnchorCount) mesh anchors")
            for affinity in AttachmentAffinity.allCases {
                if let state = manipulation[affinity], state.transcript.begins > 0 {
                    evidence.note(state.transcriptSummary, probe: .manipulation)
                }
            }
        }
        writeEvidence()
    }

    // MARK: Evidence

    func record(_ probe: ProbeKind, expected: String, observed: String, outcome: ProbeOutcome, includeFrameTimes: Bool = true,
                recordedBy: String = "founder") {
        let summary = includeFrameTimes && FrameTimeSink.shared.statistics.count > 0 ? FrameTimeSink.shared.statistics.summary : nil
        evidence.append(EvidenceRecord(probe: probe, expected: expected, observed: observed, outcome: outcome, frameTimes: summary,
                                       recordedBy: recordedBy))
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
        evidence.note("lamp \(lighting.isLightOn ? "on" : "off"): \(lighting.lightType.rawValue) intensity \(Int(lighting.intensity)) radius \(lighting.attenuationRadius) surroundings \(lighting.surroundingsLightingEnabled); components \(scene.lampComponentSummary); surfaces \(surfaces.detected.count) planes \(surfaces.meshAnchorCount) mesh; \(sceneUnderstandingStatus)", probe: .lighting)
        writeEvidence()
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
        if let state = manipulation[affinity] {
            evidence.note(state.transcriptSummary, probe: .manipulation)
        }
        writeEvidence()
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
            return !scene.intersectsRealWorld(affinity: affinity, at: ProbeScene.mountedPosition(for: affinity, pose: attached))
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
