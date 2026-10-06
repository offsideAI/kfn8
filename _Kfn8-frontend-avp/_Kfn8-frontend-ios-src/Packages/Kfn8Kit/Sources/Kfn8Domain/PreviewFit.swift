import simd

/// Volume preview: 1:1 if the item fits the usable bounds, otherwise one uniform downscale. Room placement is always 1:1.
public struct PreviewFit: Sendable, Equatable {
    public var scale: Float
    public var isTrueScale: Bool { scale == 1 }
    /// Real dimensions, always shown when downscaled so the preview never implies a misleading size.
    public var realDimensionsMetres: SIMD3<Float>

    public init(itemSize: SIMD3<Float>, volumeSize: SIMD3<Float>, padding: Float = 0.02) {
        let usable = simd_max(volumeSize - SIMD3(repeating: 2 * padding), SIMD3(repeating: 0.001))
        let ratios = usable / simd_max(itemSize, SIMD3(repeating: 0.0001))
        scale = min(1, ratios.min())
        realDimensionsMetres = itemSize
    }

    public var dimensionLabel: String {
        let cm = realDimensionsMetres * 100
        return "W \(Int(cm.x.rounded())) × D \(Int(cm.z.rounded())) × H \(Int(cm.y.rounded())) cm"
    }
}
