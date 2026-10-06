import Foundation

/// One bounded attempt to find a saved room again. The marker anchor saved inside the world map only comes back once
/// ARKit has relocalized, so its return is the success signal.
public struct RelocalizationAttempt: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case idle
        case searching(startedAt: TimeInterval)
        case found(seconds: Double)
        case notFound(afterSeconds: Double)
    }

    public let budgetSeconds: Double
    public private(set) var state: State = .idle

    public init(budgetSeconds: Double = 30) { self.budgetSeconds = budgetSeconds }

    public mutating func start(at time: TimeInterval) { state = .searching(startedAt: time) }

    /// The saved marker reappeared. Ignored unless an attempt is running, so a marker placed by hand never counts.
    public mutating func markerRestored(at time: TimeInterval) {
        guard case .searching(let started) = state else { return }
        let elapsed = time - started
        state = elapsed <= budgetSeconds ? .found(seconds: elapsed) : .notFound(afterSeconds: elapsed)
    }

    /// Called every frame; ends the attempt once the budget is spent.
    public mutating func tick(at time: TimeInterval) {
        guard case .searching(let started) = state, time - started > budgetSeconds else { return }
        state = .notFound(afterSeconds: time - started)
    }

    public var summary: String {
        switch state {
        case .idle: "Not started"
        case .searching: "Looking for the saved room…"
        case .found(let s): String(format: "Found the room in %.1f s", s)
        case .notFound(let s): String(format: "Room not found after %.0f s", s)
        }
    }
}

/// Room photo: nothing is captured until the person agrees to a picture of their home, and nothing is uploaded.
public struct PhotoFlow: Sendable, Equatable {
    public enum Step: Sendable, Equatable {
        case needsConsent
        case ready
        case capturing
        case captured(bytes: Int)
        case savedToPhotos(bytes: Int)
        case photosDenied(bytes: Int)
        case failed(String)
    }

    public private(set) var step: Step = .needsConsent

    public init() {}

    public var hasConsent: Bool { step != .needsConsent }

    public mutating func setConsent(_ given: Bool) {
        if given { if step == .needsConsent { step = .ready } } else { step = .needsConsent }
    }

    /// Returns false (and changes nothing) without consent or while a capture is already running.
    public mutating func beginCapture() -> Bool {
        switch step {
        case .needsConsent, .capturing: return false
        default: step = .capturing; return true
        }
    }

    public mutating func captured(bytes: Int) { if step == .capturing { step = .captured(bytes: bytes) } }
    public mutating func captureFailed(_ reason: String) { if step == .capturing { step = .failed(reason) } }

    public mutating func photosResult(saved: Bool) {
        guard case .captured(let bytes) = step else { return }
        step = saved ? .savedToPhotos(bytes: bytes) : .photosDenied(bytes: bytes)
    }

    public var summary: String {
        switch step {
        case .needsConsent: "Agree to capture a picture of this room first."
        case .ready: "Ready to capture."
        case .capturing: "Capturing…"
        case .captured(let b): "Captured \(b / 1024) KB; saving to Photos…"
        case .savedToPhotos(let b): "Saved to Photos (\(b / 1024) KB). Open Photos to check it."
        case .photosDenied(let b): "Captured \(b / 1024) KB, but Photos access was declined. Use Share instead."
        case .failed(let reason): "Capture failed: \(reason)"
        }
    }
}
