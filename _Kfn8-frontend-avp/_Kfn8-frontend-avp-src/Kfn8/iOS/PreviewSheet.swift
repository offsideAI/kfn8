import Kfn8Domain
import RealityKit
import SwiftUI

/// Inspection preview on iPhone/iPad: the same fit rule as the visionOS volume (1:1 when it fits a 0.7 m box, otherwise
/// one uniform downscale), orbitable with touch, real dimensions always shown.
struct PreviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: CatalogueItem
    static let boxSize = SIMD3<Float>(0.7, 0.7, 0.7)

    var body: some View {
        let fit = PreviewFit(itemSize: item.geometry.size, volumeSize: PreviewSheet.boxSize)
        NavigationStack {
            VStack(spacing: 12) {
                RealityView { content in
                    content.camera = .virtual
                    do {
                        let e = try await Entity(contentsOf: item.modelURL)
                        e.scale = SIMD3(repeating: fit.scale)
                        e.position = SIMD3(0, -item.geometry.size.y * fit.scale / 2, 0) // centre the base-centre pivot
                        content.add(e)
                    } catch {
                        model.errorMessage = "Couldn't load \(item.name) for preview: \(error.localizedDescription)"
                    }
                }
                .realityViewCameraControls(.orbit)
                .background(Showroom.paper)
                .accessibilityLabel("3D preview of \(item.name). Drag to turn it.")
                VStack(spacing: 4) {
                    Text(item.name).font(Showroom.ui(17, relativeTo: .headline))
                    Text(fit.isTrueScale ? "Actual size · \(fit.dimensionLabel)" : "Shown at \(Int((fit.scale * 100).rounded())) % · \(fit.dimensionLabel)")
                        .font(Showroom.ui(15, relativeTo: .callout))
                        .foregroundStyle(Showroom.quiet)
                }
                .padding(.bottom, 12)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Showroom.brass)
    }
}
