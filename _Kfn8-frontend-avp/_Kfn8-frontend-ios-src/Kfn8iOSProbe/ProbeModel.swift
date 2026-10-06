import ARKit
import Foundation
import Kfn8Domain
import Kfn8iOSProbeCore
import Observation
import UIKit

/// Everything the probe panel shows and records. The evidence file is rewritten after every record, so the founder
/// never has to remember to save, and the agent pulls it with `devicectl device copy from`.
@MainActor @Observable
final class ProbeModel {
    static let evidenceFileName = "IOS-PROBE-EVIDENCE.json"

    // Session status (from ARSessionDelegate, only updated when a value changes)
    var tracking = "Starting…"
    var mapping = "Not available"
    var planeSummary = "No planes yet"
    var meshAnchorCount = 0
    var ambientIntensity: Double?
    var frameSummary = "–"
    var interruptions = 0

    // Toggles applied by ProbeSession
    var sceneOcclusion = true
    var peopleOcclusion = true
    var meshReceivesLighting = true
    var environmentTexturing = true

    // Relocalization
    var markerPlaced = false
    var savedMapBytes: Int?
    var relocalization = RelocalizationAttempt()

    // Collision box
    var boxPlaced = false
    var contactWithTolerance: Bool?
    var contactFullSize: Bool?

    // Lamp
    var lampPlaced = false
    var lampOn = false
    var lampIntensity: Float = 40_000

    // Photo
    var photo = PhotoFlow()
    var lastPhotoURL: URL?

    // Evidence
    private(set) var log: EvidenceLog
    var selectedChips: [ProbeID: Set<String>] = [:]
    var message: String?
    var lastError: String?

    private var stats = FrameTimeStatistics(targetFrameRate: 60)
    private var framesSinceSummary = 0

    let device: DeviceInfo

    init() {
        var sysinfo = utsname()
        uname(&sysinfo)
        let model = withUnsafeBytes(of: &sysinfo.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        device = DeviceInfo(model: model, systemVersion: UIDevice.current.systemVersion,
                            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
                            isSimulator: simulator,
                            hasDepthSensor: ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh),
                            supportsPeopleOcclusion: ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth))
        log = EvidenceLog(device: device)
        if let data = try? Data(contentsOf: Self.evidenceURL), let saved = try? EvidenceLog.decoded(from: data), saved.device == device {
            log = saved // keep earlier records from this device and build across relaunches (relocalization needs one)
        }
    }

    static var documents: URL { URL.documentsDirectory }
    static var evidenceURL: URL { documents.appending(path: evidenceFileName) }
    static var worldMapURL: URL { documents.appending(path: "probe-room.arworldmap") }

    // MARK: Frames

    func frame(delta: Double) {
        stats.record(deltaTime: delta)
        framesSinceSummary += 1
        if framesSinceSummary >= 60 {
            framesSinceSummary = 0
            let s = stats.summary
            frameSummary = String(format: "p50 %.1f ms · p99 %.1f ms · %d dropped of %d",
                                  s.p50Milliseconds ?? 0, s.p99Milliseconds ?? 0, s.droppedFrames, s.sampleCount)
        }
    }

    func resetFrames() { stats.reset(); frameSummary = "–" }

    // MARK: Evidence

    func toggle(_ chip: Chip, for probe: ProbeID) {
        var set = selectedChips[probe] ?? []
        if set.contains(chip.id) { set.remove(chip.id) } else { set.insert(chip.id) }
        selectedChips[probe] = set
    }

    func record(_ probe: ProbeID, _ outcome: Outcome) {
        log.record(probe, outcome, observations: selectedChips[probe] ?? [], context: context(for: probe))
        selectedChips[probe] = []
        persist()
        message = "Recorded \(probe.title): \(outcome.rawValue)"
    }

    func note(_ text: String) { log.note(text); persist() }

    func fail(_ text: String) { lastError = text; note("error: \(text)") }

    private func persist() {
        do { try log.encoded().write(to: Self.evidenceURL, options: .atomic) } catch {
            lastError = "Couldn't write the evidence file: \(error.localizedDescription)"
        }
    }

    private func context(for probe: ProbeID) -> [String: String] {
        var c: [String: String] = [
            "tracking": tracking, "mapping": mapping, "planes": planeSummary, "meshAnchors": "\(meshAnchorCount)",
            "frames": frameSummary, "interruptions": "\(interruptions)",
        ]
        switch probe {
        case .relocalization:
            c["savedMapBytes"] = savedMapBytes.map(String.init) ?? "none"
            c["attempt"] = relocalization.summary
        case .collision:
            c["contactWithTolerance"] = contactWithTolerance.map { $0 ? "touching" : "clear" } ?? "untested"
            c["contactFullSize"] = contactFullSize.map { $0 ? "touching" : "clear" } ?? "untested"
            c["tolerance"] = "inset \(OrientedBox.realWorldInset) m, base lift \(OrientedBox.realWorldBaseLift) m"
        case .occlusion:
            c["sceneOcclusion"] = sceneOcclusion ? "on" : "off"
            c["peopleOcclusion"] = peopleOcclusion && device.supportsPeopleOcclusion ? "on" : "off"
        case .lighting:
            c["lamp"] = lampPlaced ? (lampOn ? "on" : "off") : "not placed"
            c["lampIntensityLumens"] = String(format: "%.0f", lampIntensity)
            c["meshReceivesLighting"] = meshReceivesLighting ? "on" : "off"
            c["environmentTexturing"] = environmentTexturing ? "on" : "off"
            c["ambientIntensity"] = ambientIntensity.map { String(format: "%.0f", $0) } ?? "n/a"
        case .photo:
            c["photo"] = photo.summary
            c["file"] = lastPhotoURL?.lastPathComponent ?? "none"
        }
        return c
    }
}
