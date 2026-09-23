import Kfn8Domain
import RealityKit
import SwiftUI

/// Inspection preview in a volume: 1:1 when it fits, otherwise one uniform downscale with real dimensions shown.
struct PreviewVolume: View {
    @Environment(AppModel.self) private var model
    let assetID: UUID?
    static let volumeSize = SIMD3<Float>(0.7, 0.7, 0.7)

    var body: some View {
        if let item = model.catalogue.first(where: { $0.id.rawValue == assetID }) {
            let fit = PreviewFit(itemSize: item.geometry.size, volumeSize: PreviewVolume.volumeSize)
            RealityView { content in
                do {
                    let e = try await Entity(contentsOf: item.modelURL)
                    e.scale = SIMD3(repeating: fit.scale)
                    e.position = SIMD3(0, -PreviewVolume.volumeSize.y / 2 + 0.02, 0)
                    content.add(e)
                } catch {
                    model.errorMessage = "Couldn't load \(item.name) for preview: \(error.localizedDescription)"
                }
            }
            .ornament(attachmentAnchor: .scene(.bottom)) {
                VStack {
                    Text(item.name).font(Showroom.ui(17, relativeTo: .headline))
                    Text(fit.isTrueScale ? "Actual size · \(fit.dimensionLabel)" : "Shown at \(Int((fit.scale * 100).rounded())) % · \(fit.dimensionLabel)")
                        .font(Showroom.ui(15, relativeTo: .callout))
                }
                .padding(14)
                .glassBackgroundEffect()
            }
        } else {
            Text("This item isn't available.").font(Showroom.ui())
        }
    }
}
