import SwiftUI

@main
struct Kfn8iOSApp: App {
    @State private var launch = AppModel.launch()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .success(let model):
                MainView()
                    .environment(model)
                    .task { await model.bootstrap() }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active { Task { await model.refreshRemote() } }
                    }
            case .failure(let failure):
                ContentUnavailableView("Kfn8 couldn't start", systemImage: "exclamationmark.triangle", description: Text(failure.message))
                    .font(Showroom.ui())
            }
        }
    }
}
