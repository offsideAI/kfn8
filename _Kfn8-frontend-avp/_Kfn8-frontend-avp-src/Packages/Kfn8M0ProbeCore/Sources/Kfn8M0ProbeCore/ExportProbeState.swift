import Foundation

/// Consent-gated still export. No capture can start before explicit consent to an image of the home, and nothing is
/// uploaded. The capture route itself (ScreenCaptureKit stream on visionOS 27) is a device question.
public struct ExportProbeState: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case awaitingConsent
        case consented
        case capturing
        case captured(fileURL: URL, byteCount: Int)
        case failed(String)
        case unavailable(String)
    }

    public private(set) var phase: Phase = .awaitingConsent

    public init() {}

    public mutating func grantConsent() {
        if case .awaitingConsent = phase { phase = .consented }
    }

    public mutating func revokeConsent() { phase = .awaitingConsent }

    /// Returns false when capture is attempted without consent; the app must not proceed.
    public mutating func beginCapture() -> Bool {
        guard case .consented = phase else { return false }
        phase = .capturing
        return true
    }

    public mutating func finishCapture(fileURL: URL, byteCount: Int) {
        guard case .capturing = phase else { return }
        phase = byteCount > 0 ? .captured(fileURL: fileURL, byteCount: byteCount) : .failed("Empty file written")
    }

    public mutating func fail(_ reason: String) { phase = .failed(reason) }

    public mutating func markUnavailable(_ reason: String) { phase = .unavailable(reason) }

    public var canCapture: Bool {
        if case .consented = phase { return true }
        return false
    }
}
