import Kfn8Domain
import Kfn8Persistence
import RealityKit
import SwiftUI

@main
struct Kfn8App: App {
    @State private var model: AppModel
    @State private var immersion: any ImmersionStyle = .mixed
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PlacementTag.registerComponent()
        PerformanceSystem.registerSystem()
        let args = ProcessInfo.processInfo.arguments
        let simulated: Bool = {
            #if targetEnvironment(simulator)
            true
            #else
            args.contains("--simulated-room")
            #endif
        }()
        let base: URL
        if let i = args.firstIndex(of: "--store-path"), i + 1 < args.count {
            base = URL(fileURLWithPath: args[i + 1])
        } else if args.contains("--fresh-store") {
            base = FileManager.default.temporaryDirectory.appendingPathComponent("kfn8-\(UUID().uuidString)")
        } else {
            base = URL.applicationSupportDirectory.appendingPathComponent("Kfn8")
        }
        let repository: any DesignRepository
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            var noBackup = URLResourceValues()
            noBackup.isExcludedFromBackup = true // scans and designs never leave the device, including via backup
            var b = base
            try? b.setResourceValues(noBackup)
            repository = LocalStore(container: try Kfn8Container.make(url: base.appendingPathComponent("kfn8.store")),
                                    files: try FileStore(root: base.appendingPathComponent("files")))
        } catch {
            fatalError("Kfn8 could not open its local store: \(error)")
        }
        let catalogue = (try? BundledCatalogue.load()) ?? []
        let remote = RemoteCatalogue(baseURL: RemoteCatalogue.configuredBaseURL(), storageRoot: base)
        _model = State(initialValue: AppModel(repository: repository, catalogue: catalogue, isSimulatedRoom: simulated, remote: remote))
    }

    var body: some SwiftUI.Scene {
        WindowGroup(id: "main") {
            MainWindow()
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
