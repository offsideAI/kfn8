import Foundation
import Kfn8Domain
import Kfn8Persistence

extension AppModel {
    /// Builds the model both apps start from: the device-local store (excluded from backup), the bundled catalogue and
    /// the optional remote catalogue. Launch arguments used by UI tests: `--store-path <dir>`, `--fresh-store`,
    /// `--simulated-room` (device builds only; simulators always use the labelled simulated room), `--api <url>`.
    static func launch() -> AppModel {
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
        return AppModel(repository: repository, catalogue: catalogue, isSimulatedRoom: simulated, remote: remote)
    }
}
