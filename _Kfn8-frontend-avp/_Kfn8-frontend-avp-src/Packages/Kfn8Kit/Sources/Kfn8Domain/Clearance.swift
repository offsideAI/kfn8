import Foundation
import simd

/// Clearance is a gap to the nearest real obstacle on one side of an item. It is never a "fits" verdict.
/// Uncertainty is derived from repeated observations of that gap (ARKit exposes no calibrated confidence score);
/// with no observations the reading is withheld and the user is told which side to rescan.
public enum ClearanceSide: String, Sendable, CaseIterable { case left, right, front, back }

public struct ClearanceReading: Sendable, Equatable {
    public var side: ClearanceSide
    public var text: String
    public var isWithheld: Bool
}

public enum Clearance {
    /// Base measurement noise assumed for a single observation, until device validation replaces it.
    public static let baseUncertainty: Float = 0.02
    /// Beyond this spread the gap is shown as a range instead of a single value.
    public static let rangeThreshold: Float = 0.03

    public static func reading(side: ClearanceSide, samples: [Float]) -> ClearanceReading {
        let valid = samples.filter { $0.isFinite && $0 >= 0 }
        guard !valid.isEmpty else {
            return ClearanceReading(side: side, text: "Not enough of the \(side.rawValue) side is scanned. Look toward it to rescan.", isWithheld: true)
        }
        let lo = valid.min()!, hi = valid.max()!
        let spread = hi - lo + baseUncertainty
        if spread > rangeThreshold {
            let a = round(max(0, lo - baseUncertainty / 2), step: 0.05), b = round(hi + baseUncertainty / 2, step: 0.05)
            let range = (a < 1 && b < 1) ? "\(Int((a * 100).rounded()))–\(Int((b * 100).rounded())) cm" : "\(format(a))–\(format(b))"
            return ClearanceReading(side: side, text: "\(side.rawValue.capitalized): \(range) gap", isWithheld: false)
        }
        let mid = (lo + hi) / 2
        return ClearanceReading(side: side, text: "\(side.rawValue.capitalized): about \(format(round(mid, step: mid >= 1 ? 0.05 : 0.01))) gap", isWithheld: false)
    }

    static func round(_ v: Float, step: Float) -> Float { (v / step).rounded() * step }

    static func format(_ metres: Float) -> String {
        metres >= 1 ? String(format: "%.2f m", metres) : "\(Int((metres * 100).rounded())) cm"
    }

    /// Horizontal gap from an item's box face to an obstacle box face on a given side, in room-local space.
    /// Returns nil when the obstacle is not on that side (no overlap in the perpendicular extent).
    public static func gap(item: OrientedBox, obstacle: OrientedBox, side: ClearanceSide) -> Float? {
        let dir: SIMD3<Float> = switch side {
        case .left: item.pose.rotation.act(SIMD3(-1, 0, 0))
        case .right: item.pose.rotation.act(SIMD3(1, 0, 0))
        case .front: item.pose.rotation.act(SIMD3(0, 0, -1))
        case .back: item.pose.rotation.act(SIMD3(0, 0, 1))
        }
        let across = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), dir))
        func extent(_ b: OrientedBox, along axis: SIMD3<Float>) -> (Float, Float) {
            let c = simd_dot(b.pose.translation, axis)
            let axes = [b.pose.rotation.act(SIMD3(1, 0, 0)), b.pose.rotation.act(SIMD3(0, 1, 0)), b.pose.rotation.act(SIMD3(0, 0, 1))]
            let r = (0..<3).reduce(Float(0)) { $0 + b.halfSize[$1] * abs(simd_dot(axes[$1], axis)) }
            return (c - r, c + r)
        }
        let (iAcrossLo, iAcrossHi) = extent(item, along: across), (oAcrossLo, oAcrossHi) = extent(obstacle, along: across)
        guard oAcrossHi > iAcrossLo && oAcrossLo < iAcrossHi else { return nil }
        let (_, iFar) = extent(item, along: dir), (oNear, _) = extent(obstacle, along: dir)
        let g = oNear - iFar
        return g >= 0 ? g : nil
    }
}
