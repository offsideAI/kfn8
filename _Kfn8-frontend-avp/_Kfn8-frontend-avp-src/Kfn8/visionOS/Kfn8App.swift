import Kfn8Domain
import RealityKit
import SwiftUI

@main
struct Kfn8App: App {
    @State private var model = AppModel.launch()
    @State private var immersion: any ImmersionStyle = .mixed
    @Environment(\.scenePhase) private var scenePhase

    var body: some SwiftUI.Scene {
        WindowGroup(id: "main") {
            VisionMainWindow()
                .environment(model)
                .task { await model.bootstrap(); await model.refreshRemote() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refreshRemote() } } }
        }
        .defaultSize(width: 1380, height: 900)

        WindowGroup(id: "preview", for: UUID.self) { $assetID in
            PreviewVolume(assetID: assetID).environment(model)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.7, height: 0.7, depth: 0.7, in: .meters)

        ImmersiveSpace(id: "room") {
            RoomImmersiveView().environment(model)
        }
        .immersionStyle(selection: $immersion, in: .mixed)
    }
}

/// The shared main window with visionOS room actions: the Mixed Immersive Space and the preview volume.
private struct VisionMainWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MainWindow(actions: RoomViewActions(
            openRoomView: {
                switch await openImmersiveSpace(id: "room") {
                case .opened: model.isImmersiveOpen = true
                case .error, .userCancelled: model.errorMessage = "The room view didn't open."
                @unknown default: model.errorMessage = "The room view didn't open."
                }
            },
            closeRoomView: {
                await dismissImmersiveSpace()
                model.isImmersiveOpen = false
            },
            preview: { openWindow(id: "preview", value: $0.id.rawValue) }
        ))
    }
}
