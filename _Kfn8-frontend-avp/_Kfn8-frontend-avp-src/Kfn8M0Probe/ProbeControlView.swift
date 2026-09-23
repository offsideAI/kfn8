import Kfn8M0ProbeCore
import SwiftUI

/// Window controls for every probe. Every spatial action has a button alternative here (non-gesture path).
struct ProbeControlView: View {
    @Environment(ProbeSession.self) private var session
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var lightingChips: Set<String> = []
    @State private var occlusionChips: Set<String> = []
    @State private var manipulationChips: Set<String> = []

    private static let lightingOptions = ["Real wall brightened", "Real floor brightened", "Virtual panel brightened",
                                          "Uneven or jagged on real surfaces", "Turning off removed it", "No change at all"]
    private static let occlusionOptions = ["Furniture hid the cube", "Cube drew through furniture", "Edges clean while still",
                                           "Edges lag or flicker while moving", "Default mode drew on top as expected"]
    private static let manipulationOptions = ["Indirect pinch worked", "Direct grab worked", "Stayed where released",
                                              "Snapped to its surface", "Invalid release turned translucent",
                                              "Jumped more than 25 cm", "Moved after release without re-pinch",
                                              "Cancel restored position", "5 cm buttons moved it", "Scale gesture was rejected"]

    private enum Page: String, CaseIterable, Identifiable {
        case setup = "Setup", lighting = "1 Light", occlusion = "2 Occlude", manipulation = "3 Move", export = "4 Export", evidence = "Evidence"
        var id: String { rawValue }
    }
    @State private var page: Page = .setup

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            VStack(spacing: 0) {
                // One page at a time so every control fits without scrolling; scrolling was unreliable on device while
                // the immersive space was open.
                Picker("Page", selection: $page) {
                    ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                Form {
                    switch page {
                    case .setup:
                        environmentSection
                        immersiveSection
                    case .lighting: lightingSection
                    case .occlusion: occlusionSection
                    case .manipulation: manipulationSection
                    case .export: exportSection
                    case .evidence: evidenceSection
                    }
                }
            }
            .navigationTitle("Kfn8 M0 Probe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if session.isImmersiveOpen {
                        Button("Close space") { Task { await dismissImmersiveSpace(); session.immersiveSpaceDidChange(isOpen: false) } }
                    } else {
                        Button("Open space") { Task { await openSpace() } }
                    }
                }
            }
        }
        .task { await applyLaunchArguments() }
        .onChange(of: session.remoteSpaceRequest) { _, request in
            guard let request else { return }
            session.remoteSpaceRequest = nil
            Task {
                if request, !session.isImmersiveOpen {
                    await openSpace()
                } else if !request, session.isImmersiveOpen {
                    await dismissImmersiveSpace()
                    session.immersiveSpaceDidChange(isOpen: false)
                }
            }
        }
    }

    private func openSpace() async {
        switch await openImmersiveSpace(id: ProbeSession.immersiveSpaceID) {
        case .opened: session.immersiveSpaceDidChange(isOpen: true)
        case .error: session.lastError = "Immersive space failed to open"
        case .userCancelled: session.lastError = "Immersive space cancelled by user"
        @unknown default: session.lastError = "Immersive space: unknown result"
        }
    }

    /// Simulator/automation hook, driven only by explicit launch arguments. `--open-immersive` opens the Mixed
    /// Immersive Space on launch; `--lamp-on` also turns the lamp on; `--occlusion-default` switches the occlusion
    /// cube to default blending for A/B screenshots. Never active without the arguments.
    private func applyLaunchArguments() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--open-immersive"), !session.isImmersiveOpen else { return }
        if case .opened = await openImmersiveSpace(id: ProbeSession.immersiveSpaceID) {
            session.immersiveSpaceDidChange(isOpen: true)
            if arguments.contains("--lamp-on"), !session.lighting.isLightOn { session.toggleLight() }
            if arguments.contains("--occlusion-default"), session.occlusion.mode == .occludedBySurroundings { session.toggleOcclusionMode() }
        } else {
            session.lastError = "Immersive space failed to open from launch arguments"
        }
    }

    private var environmentSection: some View {
        Section("Environment") {
            LabeledContent("Probe build", value: "3 · white cube ahead")
            LabeledContent("OS", value: session.evidence.environment.systemVersion)
            LabeledContent("Device", value: session.evidence.environment.deviceModel)
            LabeledContent("Simulator", value: session.evidence.environment.isSimulator ? "yes (not device evidence)" : "no")
            LabeledContent("Surfaces", value: "\(session.surfaces.detected.count) planes, \(session.surfaces.meshAnchorCount) mesh anchors")
            LabeledContent("ARKit", value: "\(session.surfaces.providerState); \(session.surfaces.authorization)")
            LabeledContent("Scene understanding", value: session.sceneUnderstandingStatus)
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
                        session.immersiveSpaceDidChange(isOpen: false)
                    }
                }
            } else {
                Button("Open immersive space") {
                    Task {
                        switch await openImmersiveSpace(id: ProbeSession.immersiveSpaceID) {
                        case .opened: session.immersiveSpaceDidChange(isOpen: true)
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
            Slider(value: $session.lighting.intensity, in: 1000...100000, step: 1000) { Text("Intensity") }
                .onChange(of: session.lighting.intensity) { session.applyLightingChanges() }
            LabeledContent("Intensity", value: String(format: "%.0f (SDK default 26964)", session.lighting.intensity))
            Slider(value: $session.lighting.attenuationRadius, in: 1...12, step: 0.5) { Text("Attenuation radius") }
                .onChange(of: session.lighting.attenuationRadius) { session.applyLightingChanges() }
            LabeledContent("Attenuation radius", value: String(format: "%.1f m", session.lighting.attenuationRadius))
            Toggle("Virtual test panel behind lamp", isOn: $session.lighting.showVirtualTestPanel)
                .onChange(of: session.lighting.showVirtualTestPanel) { session.applyLightingChanges() }
            Button(session.lighting.isLightOn ? "Turn lamp off" : "Turn lamp on") { session.toggleLight() }
            LabeledContent("Lamp components", value: session.lampDiagnostic).font(.caption)
            chipGrid(ProbeControlView.lightingOptions, selection: $lightingChips)
            outcomeButtons { outcome in
                session.record(.lighting, expected: session.lighting.expectedBehaviour,
                               observed: observed(lightingChips) + "; type \(session.lighting.lightType.rawValue) intensity \(Int(session.lighting.intensity)) radius \(session.lighting.attenuationRadius) surroundings \(session.lighting.surroundingsLightingEnabled)",
                               outcome: outcome)
            }
            recordedLine(.lighting)
        }
    }

    private var occlusionSection: some View {
        @Bindable var session = session
        return Section("2. Environment occlusion (blocking)") {
            Text(session.occlusion.expectedBehaviour).font(.caption).foregroundStyle(.secondary)
            LabeledContent("Mode now", value: session.occlusion.mode == .occludedBySurroundings ? "OCCLUDED by surroundings (the mode under test)" : "default (comparison only)")
                .bold()
            Button(session.occlusion.mode == .occludedBySurroundings ? "Switch to default (comparison)" : "Switch back to OCCLUDED (mode under test)") { session.toggleOcclusionMode() }
            Text("Use the large WHITE cube (or any block). Record while the mode reads OCCLUDED. Passed means real furniture hid it in that mode.").font(.caption).foregroundStyle(.secondary)
            chipGrid(ProbeControlView.occlusionOptions, selection: $occlusionChips)
            outcomeButtons { outcome in
                session.occlusion.record(edgeQuality: observed(occlusionChips), artifactsWhileMoving: "", frameTimes: session.frameSummary)
                session.record(.occlusion, expected: session.occlusion.expectedBehaviour,
                               observed: "mode \(session.occlusion.mode.rawValue); " + observed(occlusionChips), outcome: outcome)
            }
            recordedLine(.occlusion)
        }
    }

    private var manipulationSection: some View {
        Section("3. ManipulationComponent (blocking)") {
            Text("Expected: drag with indirect and direct pinch; release keeps the item (.stay); a release inside real geometry or off its surface stays translucent and unsaved with no jump; cancel restores the last committed placement.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(AttachmentAffinity.allCases, id: \.self) { affinity in
                manipulationRow(affinity)
            }
            chipGrid(ProbeControlView.manipulationOptions, selection: $manipulationChips)
            outcomeButtons { outcome in
                let transcript = AttachmentAffinity.allCases.compactMap { session.manipulation[$0]?.transcriptSummary }.joined(separator: " | ")
                session.record(.manipulation, expected: "Release .stay honoured; invalid release held unsaved; continuation without re-grab measured from platform events",
                               observed: observed(manipulationChips) + " || " + transcript, outcome: outcome)
            }
            recordedLine(.manipulation)
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
            LabeledContent("Records", value: "\(session.evidence.records.count) recorded, \(session.evidence.notes.count) automatic notes")
            if let url = session.evidenceFileURL {
                ShareLink(item: url) { Label("Share M0-EVIDENCE.json", systemImage: "doc.text") }
            }
            Button("Write evidence file now") { session.writeEvidence() }
            Button("Reset frame-time samples") { FrameTimeSink.shared.reset() }
        }
    }

    private func chipGrid(_ options: [String], selection: Binding<Set<String>>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isOn = selection.wrappedValue.contains(option)
                Button {
                    if isOn { selection.wrappedValue.remove(option) } else { selection.wrappedValue.insert(option) }
                } label: {
                    Label(option, systemImage: isOn ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(isOn ? .accentColor : .secondary)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    /// One tap records the outcome together with the selected chips. No typing required.
    private func outcomeButtons(_ record: @escaping (ProbeOutcome) -> Void) -> some View {
        HStack {
            Button("Record: passed") { record(.passed) }.tint(.green)
            Button("Record: failed") { record(.failed) }.tint(.red)
            Button("Record: inconclusive") { record(.inconclusive) }
        }
        .buttonStyle(.borderedProminent)
    }

    private func recordedLine(_ probe: ProbeKind) -> some View {
        let count = session.evidence.records(for: probe).count
        return LabeledContent("Recorded", value: count == 0 ? "not yet" : "\(count)× — latest \(session.evidence.latestOutcome(for: probe).rawValue)")
            .font(.caption)
    }

    private func observed(_ chips: Set<String>) -> String {
        chips.isEmpty ? "no chips selected" : chips.sorted().joined(separator: "; ")
    }
}
