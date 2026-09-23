import Foundation
import Kfn8M0ProbeCore
import simd

/// File-based remote control for unattended or agent-driven runs. The Mac writes `Documents/commands.json` with
/// `xcrun devicectl device copy to`; the app polls it twice a second, executes each command once (by `id`), writes
/// `Documents/status.json` after every poll, and renames the command file to `commands-done.json`.
/// Nothing here is a shipping feature; it exists so the M0 probe can be driven without hands in the headset.
@MainActor
final class RemoteCommandChannel {
    struct CommandFile: Decodable {
        var id: String
        var commands: [Command]
    }

    struct Command: Decodable {
        var op: String
        var on: Bool?
        var intensity: Float?
        var radius: Float?
        var type: String?
        var surroundings: Bool?
        var mode: String?
        var fixture: String?
        var to: [Float]?
        var by: [Float]?
        var probe: String?
        var outcome: String?
        var observed: String?
        var text: String?
    }

    struct Status: Encodable {
        var timestamp: Date
        var lastCommandID: String?
        var errors: [String]
        var immersiveOpen: Bool
        var lamp: String
        var occlusionMode: String
        var planes: Int
        var meshAnchors: Int
        var sceneUnderstanding: String
        var fixtures: [String: [Float]]
        var cube: [Float]
        var manipulation: [String: String]
        var frames: FrameTimeStatistics.Summary
        var records: Int
        var notes: Int
    }

    private weak var session: ProbeSession?
    private var lastID: String?
    private var task: Task<Void, Never>?

    init(session: ProbeSession) {
        self.session = session
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private var documents: URL? {
        try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    private func poll() {
        guard let session, let documents else { return }
        var errors: [String] = []
        let commandURL = documents.appendingPathComponent("commands.json")
        if let data = try? Data(contentsOf: commandURL) {
            do {
                let file = try JSONDecoder().decode(CommandFile.self, from: data)
                if file.id != lastID {
                    lastID = file.id
                    session.evidence.note("remote command file \(file.id): \(file.commands.map(\.op).joined(separator: ","))")
                    for command in file.commands {
                        if let error = execute(command, session: session) { errors.append(error) }
                    }
                    let done = documents.appendingPathComponent("commands-done.json")
                    try? FileManager.default.removeItem(at: done)
                    try? FileManager.default.moveItem(at: commandURL, to: done)
                    session.writeEvidence()
                }
            } catch {
                errors.append("commands.json decode failed: \(error.localizedDescription)")
            }
        }
        writeStatus(session: session, errors: errors, documents: documents)
    }

    private func execute(_ c: Command, session: ProbeSession) -> String? {
        switch c.op {
        case "openSpace":
            session.remoteSpaceRequest = true
        case "closeSpace":
            session.remoteSpaceRequest = false
        case "lamp":
            if let type = c.type, let lightType = LightingProbeState.LightType(rawValue: type) { session.lighting.lightType = lightType }
            if let intensity = c.intensity { session.lighting.intensity = intensity }
            if let radius = c.radius { session.lighting.attenuationRadius = radius }
            if let surroundings = c.surroundings { session.lighting.surroundingsLightingEnabled = surroundings }
            if let on = c.on, on != session.lighting.isLightOn { session.toggleLight() } else { session.applyLightingChanges() }
        case "occlusion":
            let wantOccluded = (c.mode ?? "occluded") == "occluded"
            if wantOccluded != (session.occlusion.mode == .occludedBySurroundings) { session.toggleOcclusionMode() }
        case "move":
            guard let name = c.fixture, let to = c.to, to.count == 3 else { return "move: fixture and to[3] required" }
            let target = SIMD3<Float>(to[0], to[1], to[2])
            if name == "cube" {
                session.scene.setCubePosition(target)
            } else if let affinity = AttachmentAffinity(rawValue: name) {
                session.nudge(affinity: affinity, by: target - (session.scene.position(of: affinity) ?? target))
            } else {
                return "move: unknown fixture \(name)"
            }
        case "nudge":
            guard let name = c.fixture, let affinity = AttachmentAffinity(rawValue: name), let by = c.by, by.count == 3 else {
                return "nudge: fixture and by[3] required"
            }
            session.nudge(affinity: affinity, by: SIMD3<Float>(by[0], by[1], by[2]))
        case "cancel":
            guard let name = c.fixture, let affinity = AttachmentAffinity(rawValue: name) else { return "cancel: fixture required" }
            session.cancelManipulation(affinity: affinity)
        case "record":
            guard let probeName = c.probe, let probe = ProbeKind(rawValue: probeName),
                  let outcomeName = c.outcome, let outcome = ProbeOutcome(rawValue: outcomeName) else {
                return "record: probe and outcome required"
            }
            session.record(probe, expected: "remote-driven check", observed: c.observed ?? "", outcome: outcome, recordedBy: "agent-mirrored-view")
        case "note":
            session.evidence.note(c.text ?? "", probe: nil)
        case "resetFrames":
            FrameTimeSink.shared.reset()
        case "status":
            break
        default:
            return "unknown op \(c.op)"
        }
        return nil
    }

    private func writeStatus(session: ProbeSession, errors: [String], documents: URL) {
        var fixtures: [String: [Float]] = [:]
        for affinity in AttachmentAffinity.allCases {
            if let p = session.scene.position(of: affinity) { fixtures[affinity.rawValue] = [p.x, p.y, p.z] }
        }
        let cube = session.scene.cubePosition
        let status = Status(
            timestamp: Date(), lastCommandID: lastID, errors: errors, immersiveOpen: session.isImmersiveOpen,
            lamp: "\(session.lighting.isLightOn ? "on" : "off") \(session.lighting.lightType.rawValue) \(Int(session.lighting.intensity)) r\(session.lighting.attenuationRadius) surroundings=\(session.lighting.surroundingsLightingEnabled); \(session.scene.lampComponentSummary)",
            occlusionMode: session.occlusion.mode.rawValue,
            planes: session.surfaces.detected.count, meshAnchors: session.surfaces.meshAnchorCount,
            sceneUnderstanding: session.sceneUnderstandingStatus,
            fixtures: fixtures, cube: [cube.x, cube.y, cube.z],
            manipulation: Dictionary(uniqueKeysWithValues: session.manipulation.map { ($0.key.rawValue, $0.value.transcriptSummary) }),
            frames: session.frameSummary,
            records: session.evidence.records.count, notes: session.evidence.notes.count)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(status) {
            try? data.write(to: documents.appendingPathComponent("status.json"), options: .atomic)
        }
    }
}
