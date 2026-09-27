import Kfn8Domain
import SwiftUI

@main
struct Kfn8iOSApp: App {
    @State private var model = AppModel.launch()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(model)
                .task { await model.bootstrap(); await model.refreshRemote() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refreshRemote() } } }
        }
    }
}

/// The shared main window with iPhone/iPad room actions: a full-screen AR room view and a preview sheet.
private struct PhoneRootView: View {
    @Environment(AppModel.self) private var model
    @State private var previewItem: CatalogueItem?

    var body: some View {
        @Bindable var model = model
        MainWindow(actions: RoomViewActions(
            openRoomView: { model.isImmersiveOpen = true },
            closeRoomView: { model.isImmersiveOpen = false },
            preview: { previewItem = $0 }
        ))
        .fullScreenCover(isPresented: $model.isImmersiveOpen) {
            ARRoomScreen().environment(model)
        }
        .sheet(item: $previewItem) { PreviewSheet(item: $0).environment(model) }
    }
}
