import Foundation
import simd

/// Mirrors the platform's manipulation lifecycle so the probe can compare expected versus observed behaviour.
/// The state machine is driven by `ManipulationEvents` in the app and by tests here.
public struct ManipulationProbeState: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case idle
        case manipulating
        /// Released somewhere valid and committed.
        case placed
        /// Released somewhere invalid and no candidate within the search limit validated. Unsaved, still shown.
        case heldInvalid
    }

    public enum InputKind: String, Sendable, Codable, Equatable { case indirectPinch, directPinch, pointer, unknown }

    public struct Transcript: Sendable, Equatable {
        public var begins = 0
        public var updates = 0
        public var releases = 0
        public var cancelledReleases = 0
        public var ends = 0
        public var handOffs = 0
        /// Transform updates that arrived after a release without a new begin. Nonzero means the platform kept the
        /// manipulation alive after release, which is the invalid-release continuation question from the plan.
        public var updatesAfterReleaseWithoutBegin = 0
        public var inputKinds: Set<InputKind> = []
        public init() {}
    }

    public private(set) var phase: Phase = .idle
    public private(set) var transcript = Transcript()
    public private(set) var committedPosition: SIMD3<Float>?
    public private(set) var currentPosition: SIMD3<Float>
    public private(set) var isNewPlacement: Bool
    public private(set) var lastResolution: ReleaseResolution?
    public let affinity: AttachmentAffinity
    private var awaitingBeginAfterRelease = false

    public init(affinity: AttachmentAffinity, initialPosition: SIMD3<Float>, isNewPlacement: Bool) {
        self.affinity = affinity
        self.currentPosition = initialPosition
        self.committedPosition = isNewPlacement ? nil : initialPosition
        self.isNewPlacement = isNewPlacement
    }

    public mutating func willBegin(inputKinds: Set<InputKind>) {
        transcript.begins += 1
        transcript.inputKinds.formUnion(inputKinds)
        awaitingBeginAfterRelease = false
        phase = .manipulating
    }

    public mutating func didUpdate(position: SIMD3<Float>) {
        transcript.updates += 1
        if awaitingBeginAfterRelease { transcript.updatesAfterReleaseWithoutBegin += 1 }
        currentPosition = position
    }

    public mutating func didHandOff() { transcript.handOffs += 1 }

    /// `resolution` is computed by the caller using `ReleaseResolver` and real-geometry checks.
    public mutating func willRelease(wasCancelled: Bool, resolution: ReleaseResolution) {
        transcript.releases += 1
        awaitingBeginAfterRelease = true
        if wasCancelled {
            transcript.cancelledReleases += 1
            cancel()
            return
        }
        lastResolution = resolution
        switch resolution {
        case .validAsReleased:
            committedPosition = currentPosition
            isNewPlacement = false
            phase = .placed
        case .resolved(let position):
            currentPosition = position
            committedPosition = position
            isNewPlacement = false
            phase = .placed
        case .unresolved:
            phase = .heldInvalid
        }
    }

    public mutating func willEnd() { transcript.ends += 1 }

    /// Cancel restores the pre-drag placement, or removes a newly introduced item (position becomes nil-equivalent
    /// by reverting to `.idle` with no committed position).
    public mutating func cancel() {
        if let committed = committedPosition {
            currentPosition = committed
            phase = .placed
        } else {
            phase = .idle
        }
    }

    /// Quiet, non-modal copy from the plan. No red styling, no error modal.
    public var statusCopy: String? {
        phase == .heldInvalid ? "There isn't enough space here" : nil
    }

    public var isSaved: Bool { phase == .placed && committedPosition == currentPosition }

    /// One-line summary of the platform transcript for automatic evidence notes.
    public var transcriptSummary: String {
        let t = transcript
        let inputs = t.inputKinds.map(\.rawValue).sorted().joined(separator: "/")
        return "\(affinity.rawValue): begins \(t.begins) updates \(t.updates) releases \(t.releases) cancelled \(t.cancelledReleases) "
            + "ends \(t.ends) handoffs \(t.handOffs) updatesAfterRelease \(t.updatesAfterReleaseWithoutBegin) "
            + "inputs [\(inputs)] phase \(phase) resolution \(lastResolution.map { "\($0)" } ?? "none")"
    }
}
