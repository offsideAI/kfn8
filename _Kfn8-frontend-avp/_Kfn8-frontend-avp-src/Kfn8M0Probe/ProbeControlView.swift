import Kfn8M0ProbeCore
import SwiftUI

/// Window controls for every probe. Every spatial action has a button alternative here (non-gesture path).
struct ProbeControlView: View {
    @Environment(ProbeSession.self) private var session
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var wallObservation = ""
    @State private var floorObservation = ""
    @State private var edgeObservation = ""
    @State private var movingObservation = ""
    @State private var manipulationObservation = ""
    @State private var manipulationOutcome: ProbeOutcome = .inconclusive
    @State private var lightingOutcome: ProbeOutcome = .inconclusive
    @State private var occlusionOutcome: ProbeOutcome = .inconclusive

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            Form {
                environmentSection
                immersiveSection
                lightingSection
                occlusionSection
                manipulationSection
                exportSection
                evidenceSection
            }
            .navigationTitle("Kfn8 M0 Probe")
        }
        .task { await applyLaunchArguments() }
    }

    /// Simulator/automation hook, driven only by explicit launch arguments. `--open-immersive` opens the Mixed
    /// Immersive Space on launch; `--lamp-on` also turns the lamp on; `--occlusion-default` switches the occlusion
    /// cube to default blending for A/B screenshots. Never active without the arguments.
    private func applyLaunchArguments() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--open-immersive"), !session.isImmersiveOpen else { return }
        if case .opened = await openImmersiveSpace(id: ProbeSession.immersiveSpaceID) {
            session.isImmersiveOpen = true
            if arguments.contains("--lamp-on"), !session.lighting.isLightOn { session.toggleLight() }
            if arguments.contains("--occlusion-default"), session.occlusion.mode == .occludedBySurroundings { session.toggleOcclusionMode() }
        } else {
            session.lastError = "Immersive space failed to open from launch arguments"
        }
    }

    private var environmentSection: some View {
        Section("Environment") {
            LabeledContent("OS", value: session.evidence.environment.systemVersion)
            LabeledContent("Device", value: session.evidence.environment.deviceModel)
            LabeledContent("Simulator", value: session.evidence.environment.isSimulator ? "yes (not device evidence)" : "no")
            LabeledContent("Surfaces", value: "\(session.surfaces.detected.count) planes, \(session.surfaces.meshAnchorCount) mesh anchors")
            LabeledContent("ARKit", value: "\(session.surfaces.providerState); \(session.surfaces.authorization)")
            if let error = session.lastError {
                Text(error).foregroundStyle(.secondary)
            }
        }
    }

    private var immersiveSection: some View {
        Section("Mixed Immersive Space") {
            if session.isImmersiveOpen {
                Button("Close immersive space") {
                    Task {
                        await dismissImmersiveSpace()
                        session.isImmersiveOpen = false
                    }
                }
            } else {
                Button("Open immersive space") {
                    Task {
                        switch await openImmersiveSpace(id: ProbeSession.immersiveSpaceID) {
                        case .opened: session.isImmersiveOpen = true
                        case .error: session.lastError = "Immersive space failed to open"
                        case .userCancelled: session.lastError = "Immersive space cancelled by user"
                        @unknown default: session.lastError = "Immersive space: unknown result"
                        }
                    }
                }
            }
            frameTimeRow
        }
    }

    /// Refreshes once per second from the live statistics; per-frame observation would re-render the window at 90 Hz.
    private var frameTimeRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let summary = FrameTimeSink.shared.statistics.summary
            LabeledContent("Frame times") {
                if summary.sampleCount == 0 {
                    Text("no samples")
                } else {
                    Text(verbatim: String(format: "n=%d p50 %.2f ms p95 %.2f ms p99 %.2f ms max %.2f ms drops %d",
                                          summary.sampleCount, summary.p50Milliseconds ?? 0, summary.p95Milliseconds ?? 0,
                                          summary.p99Milliseconds ?? 0, summary.maxMilliseconds ?? 0, summary.droppedFrames))
                        .font(.caption)
                }
            }
        }
    }

    private var lightingSection: some View {
        @Bindable var session = session
        return Section("1. Physical space lighting (blocking)") {
            Text(session.lighting.expectedBehaviour).font(.caption).foregroundStyle(.secondary)
            Picker("Light type", selection: $session.lighting.lightType) {
                ForEach(LightingProbeState.LightType.allCases, id: \.self) { Text($0.rawValue) }
            }
            .onChange(of: session.lighting.lightType) { session.applyLightingChanges() }
            Toggle("SurroundingsLight component", isOn: $session.lighting.surroundingsLightingEnabled)
                .onChange(of: session.lighting.surroundingsLightingEnabled) { session.applyLightingChanges() }
            Slider(value: $session.lighting.intensity, in: 200...20000, step: 200) { Text("Intensity") }
                .onChange(of: session.lighting.intensity) { session.applyLightingChanges() }
            LabeledContent("Intensity", value: String(format: "%.0f", session.lighting.intensity))
            Button(session.lighting.isLightOn ? "Turn lamp off" : "Turn lamp on") { session.toggleLight() }
            TextField("Observed on real wall", text: $wallObservation)
            TextField("Observed on real floor", text: $floorObservation)
            outcomePicker($lightingOutcome)
            Button("Record lighting comparison") {
                let recorded = session.lighting.recordComparison(observedOnWall: wallObservation, observedOnFloor: floorObservation,
                                                                 frameTimes: session.frameSummary)
                if recorded {
                    session.record(.lighting, expected: session.lighting.expectedBehaviour,
                                   observed: "wall: \(wallObservation); floor: \(floorObservation); type \(session.lighting.lightType.rawValue) intensity \(Int(session.lighting.intensity))",
                                   outcome: lightingOutcome)
                } else {
                    session.lastError = "Turn the lamp on before recording a lighting comparison."
                }
            }
            .disabled(wallObservation.isEmpty || floorObservation.isEmpty)
        }
    }

    private var occlusionSection: some View {
        @Bindable var session = session
        return Section("2. Environment occlusion (blocking)") {
            Text(session.occlusion.expectedBehaviour).font(.caption).foregroundStyle(.secondary)
            LabeledContent("Mode", value: session.occlusion.mode.rawValue)
            Button("Toggle blending mode") { session.toggleOcclusionMode() }
            TextField("Edge quality while still", text: $edgeObservation)
            TextField("Artifacts while walking/turning", text: $movingObservation)
            outcomePicker($occlusionOutcome)
            Button("Record occlusion observation") {
                session.occlusion.record(edgeQuality: edgeObservation, artifactsWhileMoving: movingObservation, frameTimes: session.frameSummary)
                session.record(.occlusion, expected: session.occlusion.expectedBehaviour,
                               observed: "mode \(session.occlusion.mode.rawValue); edges: \(edgeObservation); moving: \(movingObservation)",
                               outcome: occlusionOutcome)
            }
            .disabled(edgeObservation.isEmpty || movingObservation.isEmpty)
        }
    }

    private var manipulationSection: some View {
        Section("3. ManipulationComponent (blocking)") {
            Text("Expected: drag with indirect and direct pinch; release keeps the item (.stay); a release inside real geometry or off its surface stays translucent and unsaved with no jump; cancel restores the last committed placement.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(AttachmentAffinity.allCases, id: \.self) { affinity in
                manipulationRow(affinity)
            }
            TextField("Observed manipulation behaviour", text: $manipulationObservation)
            outcomePicker($manipulationOutcome)
            Button("Record manipulation observation") {
                let transcript = AttachmentAffinity.allCases.map { affinity -> String in
                    guard let state = session.manipulation[affinity] else { return "" }
                    let t = state.transcript
                    return "\(affinity.rawValue): begins \(t.begins) updates \(t.updates) releases \(t.releases) cancelled \(t.cancelledReleases) ends \(t.ends) handoffs \(t.handOffs) updatesAfterRelease \(t.updatesAfterReleaseWithoutBegin) inputs \(t.inputKinds.map(\.rawValue).sorted().joined(separator: "/")) phase \(state.phase)"
                }.joined(separator: " | ")
                session.record(.manipulation, expected: "Release .stay honoured; invalid release held unsaved without re-grab requirement resolved by platform evidence",
                               observed: "\(manipulationObservation) || \(transcript)", outcome: manipulationOutcome)
            }
            .disabled(manipulationObservation.isEmpty)
        }
    }

    private func manipulationRow(_ affinity: AttachmentAffinity) -> some View {
        let state = session.manipulation[affinity]
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(affinity.rawValue.capitalized).bold()
                Spacer()
                Text(verbatim: state.map { "\($0.phase)" } ?? "-").font(.caption)
                if let copy = state?.statusCopy { Text(copy).font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Button("◀︎ 5 cm") { session.nudge(affinity: affinity, by: SIMD3(-0.05, 0, 0)) }
                Button("▶︎ 5 cm") { session.nudge(affinity: affinity, by: SIMD3(0.05, 0, 0)) }
                Button("▲ 5 cm") { session.nudge(affinity: affinity, by: SIMD3(0, 0.05, 0)) }
                Button("▼ 5 cm") { session.nudge(affinity: affinity, by: SIMD3(0, -0.05, 0)) }
                Button("Away 5 cm") { session.nudge(affinity: affinity, by: SIMD3(0, 0, -0.05)) }
                Button("Closer 5 cm") { session.nudge(affinity: affinity, by: SIMD3(0, 0, 0.05)) }
                Button("Cancel") { session.cancelManipulation(affinity: affinity) }
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(affinity.rawValue) fixture controls")
    }

    private var exportSection: some View {
        Section("4. Passthrough still export (nonblocking)") {
            Text("Route: ScreenCaptureKit picker + SCStream (visionOS 27). SCScreenshotManager is unavailable on visionOS; ARKit camera frames need an enterprise entitlement. Consent is required before any capture; nothing is uploaded.")
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent("State", value: exportPhaseText)
            switch session.export.phase {
            case .awaitingConsent:
                Button("I consent to a still image of my home being written to this device") { session.export.grantConsent() }
            case .consented:
                Button("Present picker and capture one frame") { session.exporter.begin() }
                Button("Withdraw consent") { session.export.revokeConsent() }
            case .capturing:
                ProgressView("Waiting for first frame…")
            case .captured(let url, _):
                ShareLink(item: url) { Label("Share exported PNG", systemImage: "square.and.arrow.up") }
                Button("Reset export probe") { session.export = ExportProbeState() }
            case .failed, .unavailable:
                Button("Reset export probe") { session.export = ExportProbeState() }
            }
        }
    }

    private var exportPhaseText: String {
        switch session.export.phase {
        case .awaitingConsent: "awaiting consent"
        case .consented: "consented, not captured"
        case .capturing: "capturing"
        case .captured(let url, let bytes): "captured \(bytes) bytes → \(url.lastPathComponent)"
        case .failed(let reason): "failed: \(reason)"
        case .unavailable(let reason): "unavailable: \(reason)"
        }
    }

    private var evidenceSection: some View {
        Section("Evidence") {
            ForEach(ProbeKind.allCases) { probe in
                LabeledContent(probe.title, value: session.evidence.latestOutcome(for: probe).rawValue)
            }
            LabeledContent("Blocking gates passed", value: session.evidence.blockingGatesPassed ? "yes" : "no")
            LabeledContent("Records", value: "\(session.evidence.records.count)")
            if let url = session.evidenceFileURL {
                ShareLink(item: url) { Label("Share M0-EVIDENCE.json", systemImage: "doc.text") }
            }
            Button("Write evidence file now") { session.writeEvidence() }
            Button("Reset frame-time samples") { FrameTimeSink.shared.reset() }
        }
    }

    private func outcomePicker(_ selection: Binding<ProbeOutcome>) -> some View {
        Picker("Outcome", selection: selection) {
            Text("passed").tag(ProbeOutcome.passed)
            Text("failed").tag(ProbeOutcome.failed)
            Text("inconclusive").tag(ProbeOutcome.inconclusive)
        }
        .pickerStyle(.segmented)
    }
}
