import Kfn8Domain
import RealityKit
import SwiftUI

/// Inspect an item before placing it: an orbitable model with its real dimensions. A phone screen can't show true
/// scale, so the model is fitted to the view and the real size is always stated; the room view places it 1:1.
struct PreviewSheet: View {
    let item: CatalogueItem
    @Environment(\.dismiss) private var dismiss
    @State private var yaw: Float = 0
    @State private var dragStart: Float?
    @State private var loadError: String?

    /// The size the model is fitted into on screen (a 0.5 m preview "volume").
    private static let stage = SIMD3<Float>(repeating: 0.5)

    var body: some View {
        let fit = PreviewFit(itemSize: item.geometry.size, volumeSize: Self.stage)
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                RealityView { content in
                    content.camera = .virtual
                    let pivot = Entity()
                    pivot.name = "preview-pivot"
                    do {
                        let model = try await Entity(contentsOf: item.modelURL)
                        model.scale = SIMD3(repeating: fit.scale)
                        model.position = SIMD3(0, -item.geometry.size.y * fit.scale / 2, 0)
                        pivot.addChild(model)
                    } catch {
                        loadError = "Couldn't load \(item.name) for preview: \(error.localizedDescription)"
                    }
                    pivot.position = SIMD3(0, 0, -0.9)
                    content.add(pivot)
                    let light = DirectionalLight()
                    light.light.intensity = 3000
                    light.look(at: pivot.position, from: SIMD3(0.6, 1.2, 0.4), relativeTo: nil)
                    content.add(light)
                } update: { content in
                    content.entities.first { $0.name == "preview-pivot" }?.orientation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
                }
                .frame(minHeight: 280)
                .background(Showroom.bone, in: .rect(cornerRadius: 16))
                .gesture(DragGesture().onChanged { g in
                    let start = dragStart ?? yaw
                    dragStart = start
                    yaw = start + Float(g.translation.width) * 0.01
                }.onEnded { _ in dragStart = nil })
                .accessibilityElement()
                .accessibilityLabel("3D preview of \(item.name). Drag to turn it.")
                .accessibilityAddTraits(.allowsDirectInteraction)

                AdaptiveStack {
                    Button("Turn left", systemImage: "rotate.left") { yaw += .pi / 4 }
                    Button("Turn right", systemImage: "rotate.right") { yaw -= .pi / 4 }
                }
                .buttonStyle(.bordered)

                Text(item.name).font(Showroom.display(26, relativeTo: .title2))
                Text("Real size: \(fit.dimensionLabel)").font(Showroom.ui(17, relativeTo: .headline))
                Text("Shown smaller than real size. Open the room view to see it at true scale in your room.")
                    .foregroundStyle(Showroom.quiet)
                if let loadError { Text(loadError).foregroundStyle(Showroom.ink) }
                Spacer(minLength: 0)
            }
            .padding(20)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
        .font(Showroom.ui())
        .tint(Showroom.brass)
        .foregroundStyle(Showroom.ink)
        .preferredColorScheme(.light)
    }
}
