import Foundation
import simd

/// Invalid-release handling from the technical plan: try shortest-axis push-out first, then validated nearby
/// candidates within a hard search limit (default 25 cm). No distant jumps. If nothing validates, the item stays
/// unsaved and held; that outcome is reported, never hidden.
public enum ReleaseResolution: Sendable, Equatable {
    case validAsReleased
    case resolved(SIMD3<Float>)
    case unresolved
}

public struct ReleaseResolver: Sendable {
    public var searchLimit: Float
    public var step: Float

    public init(searchLimit: Float = 0.25, step: Float = 0.05) {
        precondition(searchLimit > 0 && step > 0 && step <= searchLimit)
        self.searchLimit = searchLimit
        self.step = step
    }

    /// Candidate offsets ordered by distance, then by axis preference. Deterministic so tests can assert order.
    public func candidateOffsets(preferredAxes: [SIMD3<Float>] = ReleaseResolver.defaultAxes) -> [SIMD3<Float>] {
        var result: [SIMD3<Float>] = []
        var magnitude = step
        while magnitude <= searchLimit + 1e-6 {
            for axis in preferredAxes {
                result.append(axis * magnitude)
            }
            magnitude += step
        }
        return result
    }

    public static let defaultAxes: [SIMD3<Float>] = [
        SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1), SIMD3(0, 1, 0),
    ]

    /// `isValid` is the caller's full validation: real-geometry intersection, attachment constraints, ceiling clearance.
    public func resolve(released: SIMD3<Float>,
                        penetrationPushOut: SIMD3<Float>? = nil,
                        isValid: (SIMD3<Float>) -> Bool) -> ReleaseResolution {
        if isValid(released) { return .validAsReleased }
        if let push = penetrationPushOut, simd_length(push) <= searchLimit, isValid(released + push) {
            return .resolved(released + push)
        }
        for offset in candidateOffsets() where isValid(released + offset) {
            return .resolved(released + offset)
        }
        return .unresolved
    }
}
