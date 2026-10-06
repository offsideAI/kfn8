import Kfn8Domain
import Photos
import RealityKit
import SwiftUI
import UIKit

/// The full-screen room view: the camera (or the labelled simulated room) with the Design placed at true scale, the
/// panels in a resizable sheet (iPhone) or a side column (iPad), and on-screen buttons for everything touch can do.
struct RoomARScreen: View {
    @Environment(AppModel.self) private var model
    @State private var previewItem: CatalogueItem?
    @State private var panelHiddenAt = Date.distantPast
    @State private var session: RoomSession?
    @State private var showPanel = true
    @State private var photoFile: URL?
    @State private var panelHeight: PresentationDetent = .medium
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack(alignment: .top) {
            if let session {
                ARViewContainer(arView: session.arView).ignoresSafeArea()
                TurnHandles(overlay: session.overlay)
            } else {
                Showroom.ink.ignoresSafeArea()
            }
            VStack(spacing: 10) {
                topBar
                if model.photo.step == .askingConsent { consentBanner }
                RoomBanners()
            }
            .padding(.horizontal, 12)
        }
        .inspector(isPresented: Binding(get: { showPanel }, set: { showPanel = $0 })) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DesignPanel()
                    InventoryPanel()
                    CataloguePanel(preview: { previewItem = $0 })
                }
                .padding(16)
            }
            .accessibilityIdentifier("room-panel-scroll")
            // On iPhone the panel is itself a presented sheet, so its own presentations must come from inside it.
            .sheet(item: $previewItem) { PreviewSheet(item: $0) }
            .background(Showroom.paper)
            .presentationDetents([.fraction(0.32), .medium, .fraction(0.78)], selection: $panelHeight)
            .presentationBackgroundInteraction(.enabled)
            // Like a Maps panel: swiping down collapses it to its smallest height; "Hide panel" hides it.
            .interactiveDismissDisabled()
            .inspectorColumnWidth(min: 300, ideal: 360, max: 440)
        }
        .sheet(item: Binding(get: { photoFile.map(PhotoFile.init) }, set: { if $0 == nil { finishPhoto() } })) { file in
            PhotoResultSheet(file: file.url, finish: finishPhoto)
        }
        .task {
            guard session == nil else { return }
            let s = RoomSession(model: model)
            session = s
            await s.start()
            s.scene.sync()
        }
        .onChange(of: model.sessionGeneration) { Task { await session?.restart(); session?.scene.sync() } }
        .onChange(of: SceneKey(model)) { session?.scene.sync() }
        .onChange(of: model.preparingDesign) { session?.scene.preload(model.preparingDesign) }
        .font(Showroom.ui())
        .tint(Showroom.brass)
        .foregroundStyle(Showroom.ink)
        .preferredColorScheme(.light)
    }

    private var topBar: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Buttons first, so a long status at large text sizes never pushes them under the panel.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) { roomButtons }
                    status
                }
            } else {
                HStack(spacing: 10) {
                    status.frame(maxWidth: .infinity, alignment: .leading)
                    roomButtons
                }
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .padding(10)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.currentRoom.map(model.alignmentText) ?? "").font(Showroom.ui(15, relativeTo: .subheadline))
            if let limitation = model.captureMode.limitation { Text(limitation).font(Showroom.ui(13, relativeTo: .caption)) }
        }
        .foregroundStyle(Showroom.ink)
    }

    @ViewBuilder private var roomButtons: some View {
            Button("Photo", systemImage: "camera") {
                // The panel goes away for a photo of the room; consent is asked on screen, not behind the panel.
                if showPanel { showPanel = false; panelHiddenAt = .now }
                model.photo.requestPhoto()
            }
                .disabled(!model.alignment.showsSpatialContent || session == nil)
            Button(showPanel ? "Hide panel" : "Show panel", systemImage: "sidebar.right") {
                showPanel.toggle()
                if !showPanel { panelHiddenAt = .now }
            }
            Button("Leave room view", systemImage: "door.left.hand.open") {
                Task {
                    await session?.stop()
                    model.closeRoomView()
                }
            }
            // Text at regular sizes; at accessibility sizes all three are icons (their spoken labels stay full).
            .labelStyle(typeSize.isAccessibilitySize ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleOnly))
            .buttonStyle(BrassButtonStyle())
    }

    // MARK: Photo

    private var consentBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Take a photo of your room?").font(Showroom.ui(17, relativeTo: .headline))
            Text("The photo shows your home. It stays on this device unless you save or share it.").foregroundStyle(Showroom.quiet)
            AdaptiveStack {
                Button("Take photo") { takePhoto() }.buttonStyle(BrassButtonStyle())
                Button("Not now") { model.photo.declineConsent() }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private func takePhoto() {
        guard let session, model.photo.giveConsent() else { return }
        // @Sendable: the completion must not be main-actor isolated, whichever queue RealityKit calls it on.
        session.arView.snapshot(saveToHDR: false) { @Sendable image in
            let png = image?.pngData()
            Task { @MainActor in
                guard let png else { model.photo.captureFailed("the room view returned no image"); return }
                let url = URL.temporaryDirectory.appending(path: "Kfn8 room \(Int(Date().timeIntervalSince1970)).png")
                do {
                    try png.write(to: url, options: [.atomic, .completeFileProtection])
                    model.photo.captured(bytes: png.count)
                    // A sheet can't appear while the panel's own sheet is still animating away (iPhone).
                    let settle = 0.6 - Date().timeIntervalSince(panelHiddenAt)
                    if settle > 0 { try? await Task.sleep(for: .seconds(settle)) }
                    photoFile = url
                } catch {
                    model.photo.captureFailed("it couldn't be written: \(error.localizedDescription)")
                }
            }
        }
    }

    /// The temporary copy of someone's home is deleted as soon as they're done with it.
    private func finishPhoto() {
        if let url = photoFile { try? FileManager.default.removeItem(at: url) }
        photoFile = nil
        model.photo.finish()
    }
}

private struct PhotoFile: Identifiable { let url: URL; var id: URL { url } }

/// Photos runs its change block on its own queue, so the block must not be main-actor isolated (Swift 6 traps on
/// that at runtime). Keeping it in a nonisolated function stops it inheriting the view's isolation.
enum PhotoLibraryWriter {
    nonisolated static func add(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }
}

private struct PhotoResultSheet: View {
    @Environment(AppModel.self) private var model
    let file: URL
    let finish: () -> Void
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image = UIImage(contentsOfFile: file.path) {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(.rect(cornerRadius: 12))
                        .accessibilityLabel("Photo of your room with the placed furniture")
                }
                if let message = model.photo.message { Text(message).foregroundStyle(Showroom.quiet) }
                AdaptiveStack {
                    Button("Save to Photos", systemImage: "square.and.arrow.down") { Task { await save() } }
                        .buttonStyle(BrassButtonStyle())
                        .disabled(saving || model.photo.step == .saved)
                    ShareLink("Share", item: file).buttonStyle(.bordered)
                }
            }
            .padding(20)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: finish) } }
            .navigationTitle("Room photo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .font(Showroom.ui())
        .tint(Showroom.brass)
        .foregroundStyle(Showroom.ink)
        .preferredColorScheme(.light)
    }

    /// Add-only access: Kfn8 can add this photo but can't see anything else in the library.
    private func save() async {
        saving = true
        defer { saving = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { model.photo.savedToPhotos(false); return }
        do {
            try await PhotoLibraryWriter.add(Data(contentsOf: file))
            model.photo.savedToPhotos(true)
        } catch {
            model.photo.writeFailed("Photos didn't accept it: \(error.localizedDescription)")
        }
    }
}

/// What the RealityKit projection depends on; any change re-syncs the entities.
private struct SceneKey: Equatable {
    var design: Design?
    var previews: [PlacementID: RigidTransform]
    var held: Set<PlacementID>
    var cues: Set<PlacementID>
    var aligned: Bool
    var lit: [PlacementID]
    var placeable: Int

    @MainActor init(_ m: AppModel) {
        design = m.currentDesign; previews = m.previewTransforms; held = m.heldInvalid; cues = m.overlapCues
        aligned = m.alignment.showsSpatialContent; lit = m.litPlacements; placeable = m.remote.placeableItems.count
    }
}

/// Recovery, camera access and errors, over the camera view.
struct RoomBanners: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            if model.cameraDenied {
                banner {
                    Text("Kfn8 needs the camera to find your floor and walls. Nothing you scan leaves this device.")
                    Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                        .buttonStyle(BrassButtonStyle())
                }
            }
            if model.alignment == .exhausted {
                banner {
                    Text("I can't tell where this room is yet").font(Showroom.ui(17, relativeTo: .headline))
                    Text("You can rescan into this same room, or review its contents without placing them.").foregroundStyle(Showroom.quiet)
                    AdaptiveStack {
                        Button("Rescan this room") { model.rescanCurrentRoom() }.buttonStyle(BrassButtonStyle())
                        Button("Review contents") { model.reviewContents() }.buttonStyle(.bordered)
                    }
                }
            }
            if let message = model.photo.message, model.photo.step != .idle, case .failed = model.photo.step {
                banner { Text(message); Button("Dismiss") { model.photo.finish() } }
            }
            ErrorBanner()
        }
    }

    private func banner(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .accessibilityElement(children: .contain)
    }
}

/// One 45° turn button beside each placed floor, table or ceiling item, following it on screen.
private struct TurnHandles: View {
    @Environment(AppModel.self) private var model
    let overlay: RoomOverlay

    var body: some View {
        GeometryReader { _ in
            ForEach(Array(overlay.turnHandles.keys), id: \.self) { id in
                if let point = overlay.turnHandles[id], let p = model.currentDesign?.placement(id), let item = model.item(for: p.asset) {
                    Button { Task { await model.rotate(id, byDegrees: TurnHandle.degreesPerTap) } } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Showroom.ink)
                            .frame(width: 48, height: 48)
                            .background(Showroom.brass, in: .circle)
                    }
                    .accessibilityLabel("Turn \(item.name) 45 degrees")
                    .position(point)
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct ARViewContainer: UIViewRepresentable {
    let arView: ARView
    func makeUIView(context: Context) -> ARView { arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
