import Foundation
import Kfn8Catalogue
import Kfn8Domain
import Kfn8Persistence

/// Launch arguments, used by the UI tests:
/// - `--store-path <dir>`: an isolated store for one test
/// - `--simulate-lost-alignment`: the next return visit can't find the room (simulator only)
/// - `--api <url>`: the online catalogue's base URL (otherwise the `Kfn8APIBaseURL` Info.plist key)
/// - `--catalogue-fixtures <dir>` (Debug builds only): serve the online catalogue from recorded files, no network
/// - `--force-revocation-sync`: check revocations now instead of waiting for the six-hour interval
struct LaunchOptions {
    var storeURL: URL
    var simulateLostAlignment: Bool
    var apiBaseURL: URL?
    var catalogueFixtures: URL?
    var forceRevocationSync: Bool

    static func parse(_ args: [String] = ProcessInfo.processInfo.arguments) -> LaunchOptions {
        func value(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let store = value("--store-path").map { URL(filePath: $0) } ?? URL.applicationSupportDirectory.appending(path: "Kfn8")
        let configured = (Bundle.main.object(forInfoDictionaryKey: "Kfn8APIBaseURL") as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
        var fixtures: URL?
        #if DEBUG
        fixtures = value("--catalogue-fixtures").map { URL(filePath: $0) }
        #endif
        return LaunchOptions(storeURL: store, simulateLostAlignment: args.contains("--simulate-lost-alignment"),
                             apiBaseURL: value("--api").flatMap(URL.init(string:)) ?? configured,
                             catalogueFixtures: fixtures, forceRevocationSync: args.contains("--force-revocation-sync"))
    }
}

/// Why the app can't start. Shown in full; the app never runs without its store.
struct LaunchFailure: Error { var message: String }

extension AppModel {
    /// The device-local store (excluded from backup), the verified bundled catalogue and the optional online catalogue.
    static func launch(options: LaunchOptions = .parse()) -> Result<AppModel, LaunchFailure> {
        PlacementTag.registerComponent()
        ModelRevision.registerComponent()
        let base = options.storeURL
        let repository: any DesignRepository
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            var noBackup = URLResourceValues()
            noBackup.isExcludedFromBackup = true // scans, world maps and designs never leave the device, including via backup
            var b = base
            try b.setResourceValues(noBackup)
            repository = LocalStore(container: try Kfn8Container.make(url: base.appending(path: "kfn8.store")),
                                    files: try FileStore(root: base.appending(path: "files")))
        } catch {
            return .failure(LaunchFailure(message: "Kfn8 couldn't open its storage on this device: \(error.localizedDescription)"))
        }
        let bundled: [CatalogueItem]
        do {
            guard let root = Bundle.main.url(forResource: "Catalogue", withExtension: nil) else {
                return .failure(LaunchFailure(message: "The built-in catalogue is missing from this build."))
            }
            bundled = try BundledCatalogue.load(from: root).map(CatalogueItem.init(bundled:))
        } catch {
            return .failure(LaunchFailure(message: "The built-in catalogue couldn't be read: \(error)"))
        }
        let remote = RemoteCatalogue(options: options, storageRoot: base)
        return .success(AppModel(repository: repository, bundled: bundled, remote: remote, captureMode: .current, options: options))
    }
}
