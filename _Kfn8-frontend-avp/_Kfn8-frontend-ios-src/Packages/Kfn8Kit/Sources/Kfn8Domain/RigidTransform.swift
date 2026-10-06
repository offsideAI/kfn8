import Foundation
import simd

/// Rotation + translation only. Placed scale is exactly one by construction, so no scale can be persisted.
public struct RigidTransform: Codable, Sendable, Equatable {
    public var translation: SIMD3<Float>
    public var rotation: simd_quatf

    public static let identity = RigidTransform(translation: .zero, rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))

    public init(translation: SIMD3<Float> = .zero, rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)) {
        self.translation = translation
        self.rotation = simd_normalize(rotation)
    }

    public init(translation: SIMD3<Float>, yaw: Float) {
        self.init(translation: translation, rotation: simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)))
    }

    /// self ∘ other: apply `other` first, then `self`.
    public static func * (lhs: RigidTransform, rhs: RigidTransform) -> RigidTransform {
        RigidTransform(translation: lhs.translation + lhs.rotation.act(rhs.translation), rotation: lhs.rotation * rhs.rotation)
    }

    public var inverse: RigidTransform {
        let inv = rotation.inverse
        return RigidTransform(translation: inv.act(-translation), rotation: inv)
    }

    public func apply(_ point: SIMD3<Float>) -> SIMD3<Float> { rotation.act(point) + translation }

    public var matrix: simd_float4x4 {
        var m = simd_float4x4(rotation)
        m.columns.3 = SIMD4(translation, 1)
        return m
    }

    public func isApproximately(_ other: RigidTransform, tolerance: Float = 1e-4) -> Bool {
        simd_length(translation - other.translation) <= tolerance
            && (simd_length(rotation.vector - other.rotation.vector) <= tolerance
                || simd_length(rotation.vector + other.rotation.vector) <= tolerance)
    }

    // simd_quatf is not Codable; encode its vector.
    private enum CodingKeys: String, CodingKey { case translation, rotation }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let r = try c.decode(SIMD4<Float>.self, forKey: .rotation)
        self.init(translation: try c.decode(SIMD3<Float>.self, forKey: .translation), rotation: simd_quatf(vector: r))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(translation, forKey: .translation)
        try c.encode(rotation.vector, forKey: .rotation)
    }
}
