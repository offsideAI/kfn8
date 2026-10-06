import Kfn8iOSProbeCore
import RealityKit
import SwiftUI

/// Nonshipping I0.S2 feasibility probe for iPhone/iPad: relocalization, real-world collision, occlusion, lighting and
/// the room photo. No App Store, no analytics, no accounts; evidence stays in the app's Documents folder.
@main
struct ProbeApp: App {
    @State private var model = ProbeModel()

    var body: some SwiftUI.Scene {
        WindowGroup {
            ProbeScreen(model: model)
        }
    }
}

struct ProbeScreen: View {
    @Bindable var model: ProbeModel
    @State private var session: ProbeSession?
    @State private var page: Page = .setup

    enum Page: String, CaseIterable, Identifiable {
        case setup = "Setup", relocalize = "Find", collide = "Collide", occlude = "Occlude", light = "Light", photo = "Photo", evidence = "Evidence"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                if let session { ARContainer(arView: session.arView).ignoresSafeArea(edges: .top) } else { Color.black }
                // Aim point for the centre raycasts.
                Circle().strokeBorder(Probe.brass, lineWidth: 2).frame(width: 22, height: 22).accessibilityHidden(true)
            }
            panel
        }
        .onAppear {
            guard session == nil else { return }
            let s = ProbeSession(model: model)
            session = s
            s.run()
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Seven pages don't fit a segmented control on an iPhone (labels truncate), so they scroll as full-label buttons.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Page.allCases) { p in
                        Button(p.rawValue) { page = p }
                            .font(.subheadline.weight(page == p ? .semibold : .regular))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(page == p ? Probe.brass : Probe.bone, in: .capsule)
                            .accessibilityAddTraits(page == p ? .isSelected : [])
                    }
                }
            }
            Group {
                switch page {
                case .setup: setup
                case .relocalize: relocalize
                case .collide: collide
                case .occlude: occlude
                case .light: light
                case .photo: photo
                case .evidence: evidence
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let message = model.message { Text(message).font(.footnote).foregroundStyle(Probe.quiet) }
            if let error = model.lastError { Text(error).font(.footnote.weight(.semibold)).foregroundStyle(Probe.ink) }
        }
        .padding(14)
        .background(Probe.paper)
        .foregroundStyle(Probe.ink)
        .tint(Probe.brass)
    }

    // MARK: Pages

    private var setup: some View {
        VStack(alignment: .leading, spacing: 4) {
            line("Device", "\(model.device.model) · iOS \(model.device.systemVersion) · build \(model.device.appBuild)\(model.device.isSimulator ? " · SIMULATOR" : "")")
            line("Depth sensor", model.device.hasDepthSensor ? "Yes (room mesh)" : "No (planes only)")
            line("Tracking", model.tracking)
            line("Mapping", model.mapping)
            line("Planes", model.planeSummary)
            line("Mesh pieces", "\(model.meshAnchorCount)")
            line("Frames", model.frameSummary)
            Button("Reset frame timing") { model.resetFrames() }
        }
    }

    private var relocalize: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. Aim at the floor, place the marker. 2. Walk around until Mapping says Mapped, then save. 3. Quit and reopen the probe, tap Find room. Then try Find room in a different room.")
                .font(.footnote)
            HStack {
                Button("Place marker") { session?.placeMarker() }
                Button("Save room map") { session?.saveMap() }.disabled(!model.markerPlaced)
                Button("Find room") { session?.relocalize() }
            }
            .buttonStyle(.bordered)
            line("Mapping", model.mapping)
            line("Saved map", model.savedMapBytes.map { "\($0 / 1024) KB" } ?? "none")
            line("Attempt", model.relocalization.summary)
            chipsAndRecord(.relocalization)
        }
    }

    private var collide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Place the box on open floor, then drag it or nudge it into a sofa or table.").font(.footnote)
            HStack {
                Button("Place box") { session?.placeBox() }
                Button("Left") { session?.nudgeBox(right: -0.1, forward: 0) }
                Button("Right") { session?.nudgeBox(right: 0.1, forward: 0) }
                Button("Away") { session?.nudgeBox(right: 0, forward: 0.1) }
                Button("Closer") { session?.nudgeBox(right: 0, forward: -0.1) }
            }
            .buttonStyle(.bordered).disabled(model.device.isSimulator)
            line("With tolerance", contactText(model.contactWithTolerance))
            line("Full size", contactText(model.contactFullSize))
            chipsAndRecord(.collision)
        }
    }

    private var occlude: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Put the box behind real furniture. Look while still, then while walking and turning.").font(.footnote)
            Toggle("Room mesh occlusion", isOn: $model.sceneOcclusion).onChange(of: model.sceneOcclusion) { session?.applyRenderOptions() }
            Toggle("People occlusion", isOn: $model.peopleOcclusion)
                .onChange(of: model.peopleOcclusion) { session?.run() }
                .disabled(!model.device.supportsPeopleOcclusion)
            chipsAndRecord(.occlusion)
        }
    }

    private var light: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aim at a wall and place the lamp. Turn it on and off; compare with the room mesh lighting switch.").font(.footnote)
            HStack {
                Button("Place lamp") { session?.placeLamp() }
                Button(model.lampOn ? "Lamp off" : "Lamp on") { session?.setLamp(on: !model.lampOn) }.disabled(!model.lampPlaced)
            }
            .buttonStyle(.bordered)
            Slider(value: $model.lampIntensity, in: 2_000...120_000) { Text("Intensity") }
                .onChange(of: model.lampIntensity) { if model.lampOn { session?.setLamp(on: true) } }
                .accessibilityValue("\(Int(model.lampIntensity)) lumens")
            Toggle("Room mesh receives virtual light", isOn: $model.meshReceivesLighting).onChange(of: model.meshReceivesLighting) { session?.applyRenderOptions() }
            Toggle("Environment texturing", isOn: $model.environmentTexturing).onChange(of: model.environmentTexturing) { session?.run() }
            chipsAndRecord(.lighting)
        }
    }

    private var photo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("I agree to capture a picture of this room", isOn: Binding(get: { model.photo.hasConsent }, set: { model.photo.setConsent($0) }))
            HStack {
                Button("Capture photo") { session?.capturePhoto() }.disabled(!model.photo.hasConsent)
                if let url = model.lastPhotoURL { ShareLink("Share", item: url) }
            }
            .buttonStyle(.bordered)
            Text(model.photo.summary).font(.footnote)
            chipsAndRecord(.photo)
        }
    }

    private var evidence: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ProbeID.allCases, id: \.self) { p in line(p.title, model.log.outcome(for: p)?.rawValue ?? "not recorded") }
            line("Records", "\(model.log.records.count)")
            line("File", "Documents/\(ProbeModel.evidenceFileName)")
        }
    }

    // MARK: Pieces

    private func chipsAndRecord(_ probe: ProbeID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowChips(probe: probe, selected: model.selectedChips[probe] ?? []) { model.toggle($0, for: probe) }
            HStack {
                ForEach(Outcome.allCases, id: \.self) { o in
                    Button("Record \(o.rawValue)") { model.record(probe, o) }.buttonStyle(.borderedProminent)
                }
            }
            .font(.footnote)
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Probe.quiet)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
    }

    private func contactText(_ v: Bool?) -> String { v.map { $0 ? "Touching real geometry" : "Clear" } ?? "Not tested" }
}

private struct FlowChips: View {
    let probe: ProbeID
    let selected: Set<String>
    let toggle: (Chip) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(probe.chips) { chip in
                    let on = selected.contains(chip.id)
                    Button(chip.text) { toggle(chip) }
                        .font(.footnote)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(on ? Probe.brass : Probe.bone, in: .capsule)
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

private struct ARContainer: UIViewRepresentable {
    let arView: ARView
    func makeUIView(context: Context) -> ARView { arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

/// Showroom palette for the probe (no purple, indigo or cyan).
enum Probe {
    static let bone = Color(red: 0.937, green: 0.914, blue: 0.867)
    static let paper = Color(red: 0.969, green: 0.953, blue: 0.922)
    static let brass = Color(red: 0.722, green: 0.573, blue: 0.290)
    static let ink = Color(red: 0.110, green: 0.102, blue: 0.094)
    static let quiet = ink.opacity(0.7)
}
