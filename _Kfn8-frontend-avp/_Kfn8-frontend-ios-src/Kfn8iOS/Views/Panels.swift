import Kfn8Catalogue
import Kfn8Domain
import SwiftUI

struct DesignPanel: View {
    /// Scaled button columns never get wider than a phone panel, so at the largest text sizes they become one column.
    static let maximumColumn: CGFloat = 240
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .body) private var actionWidth: CGFloat = 140
    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            AdaptiveStack {
                Text("Designs").font(Showroom.display(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let d = model.currentDesign { Text(d.name).foregroundStyle(Showroom.quiet).accessibilityLabel("Current design: \(d.name)") }
            }
            // Actions wrap as whole buttons rather than squeezing their labels, at every text size.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: min(actionWidth, Self.maximumColumn)), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                Button("Undo", systemImage: "arrow.uturn.backward") { Task { await model.undo() } }.disabled(!model.undoHistory.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { Task { await model.redo() } }.disabled(!model.undoHistory.canRedo)
                Button("Duplicate", systemImage: "plus.square.on.square") { Task { await model.duplicateCurrentDesign() } }
                Button("Rename", systemImage: "pencil") { newName = model.currentDesign?.name ?? ""; renaming = true }
                if let target = model.flipTarget {
                    Button("Flip to \(target.name)", systemImage: "arrow.left.arrow.right") { model.requestFlip() }
                        .accessibilityHint("Switches the room to the other design once it has loaded. Double-tap in the room view does the same.")
                }
            }
            .buttonStyle(.bordered)
            .lineLimit(2)
            if model.designs.count > 1 {
                Picker("Design", selection: Binding(get: { model.currentDesign?.id }, set: { id in
                    if let d = model.designs.first(where: { $0.id == id }) { model.selectDesign(d) }
                })) {
                    ForEach(model.designs) { Text($0.name).tag(Optional($0.id)) }
                }
                .pickerStyle(.menu)
            }
            if let status = model.statusMessage { Text(status).foregroundStyle(Showroom.quiet) }
            if model.isRoomViewOpen, model.currentDesign?.placements.contains(where: { model.item(for: $0.asset)?.isLighting == true }) == true {
                Toggle("Lamps on", isOn: $model.lampsOn)
                    .accessibilityHint("Up to two lamps light the furniture around them.")
            }
            ForEach(model.updateOffers) { offer in
                AdaptiveStack {
                    Text(offer.summary).foregroundStyle(Showroom.quiet).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Update") { Task { await model.acceptUpdate(offer) } }.buttonStyle(.bordered)
                }
            }
            if let design = model.currentDesign {
                if design.placements.isEmpty {
                    Text("Nothing placed yet. Add something from the catalogue.").foregroundStyle(Showroom.quiet)
                }
                ForEach(design.placements) { PlacementRow(placement: $0) }
            }
        }
        .alert("Rename design", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Rename") { Task { await model.renameCurrentDesign(to: newName) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct PlacementRow: View {
    @Environment(AppModel.self) private var model
    let placement: Placement

    var body: some View {
        let item = model.item(for: placement.asset)
        let selected = model.selection == placement.id
        VStack(alignment: .leading, spacing: 10) {
            Button {
                model.selection = selected ? nil : placement.id
            } label: {
                AdaptiveStack {
                    Text(title(item)).font(Showroom.ui(17, relativeTo: .headline))
                    if model.heldInvalid.contains(placement.id) { Text("not saved").foregroundStyle(Showroom.quiet) }
                    Text(item?.dimensionLabel ?? "").foregroundStyle(Showroom.quiet).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title(item)), \(item?.dimensionLabel ?? "")")
            .accessibilityValue(model.positionDescription(placement))
            .accessibilityAddTraits(selected ? .isSelected : [])
            if selected, let item {
                PlacementControls(id: placement.id, affinity: item.affinity)
                if let readings = model.clearanceReadings(for: placement.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clearances").font(Showroom.ui(15, relativeTo: .subheadline))
                        ForEach(readings, id: \.side) { Text($0.text).font(Showroom.ui(14, relativeTo: .footnote)).foregroundStyle(Showroom.quiet) }
                    }
                    .accessibilityElement(children: .combine)
                }
            } else if selected {
                Button("Remove", systemImage: "trash") { Task { await model.remove(placement.id) } }.buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(selected ? Showroom.brass.opacity(0.18) : Showroom.bone.opacity(0.4), in: .rect(cornerRadius: 14))
    }

    /// An item that can no longer be shown keeps its row and says why; it is never swapped for something else.
    private func title(_ item: CatalogueItem?) -> String {
        if let item { return item.name }
        let name = model.remote.index.item(for: placement.asset)?.name ?? "Unavailable item"
        return "\(name) (\(model.remote.absenceReason(for: placement.asset) ?? "unavailable"))"
    }
}

/// Non-gesture alternatives for every touch action: move, raise and lower, rotate, cancel, remove.
struct PlacementControls: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .callout) private var controlWidth: CGFloat = 150
    let id: PlacementID
    let affinity: Affinity
    private let step: Float = 0.1

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(controlWidth, DesignPanel.maximumColumn)), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            if model.isRoomViewOpen && model.alignment.showsSpatialContent {
                move("Left", "arrow.left", SIMD3(-step, 0, 0))
                move("Right", "arrow.right", SIMD3(step, 0, 0))
                move("Toward wall", "arrow.up", SIMD3(0, 0, -step))
                move("Away from wall", "arrow.down", SIMD3(0, 0, step))
                if affinity == .wall {
                    move("Raise", "arrow.up.to.line", SIMD3(0, step, 0))
                    move("Lower", "arrow.down.to.line", SIMD3(0, -step, 0))
                } else {
                    Button("Rotate left 15°", systemImage: "rotate.left") { Task { await model.rotate(id, byDegrees: 15) } }
                    Button("Rotate right 15°", systemImage: "rotate.right") { Task { await model.rotate(id, byDegrees: -15) } }
                }
                Button("Cancel move", systemImage: "xmark") { model.cancel(id) }.disabled(!model.heldInvalid.contains(id))
            }
            Button("Remove", systemImage: "trash") { Task { await model.remove(id) } }
        }
        .lineLimit(2)
        .buttonStyle(.bordered)
        .font(Showroom.ui(15, relativeTo: .callout))
    }

    private func move(_ title: String, _ icon: String, _ delta: SIMD3<Float>) -> some View {
        Button(title, systemImage: icon) { Task { await model.nudge(id, by: delta) } }
    }
}

/// Generic-first inventory: quantities and real dimensions. Prices, dates and subtotals only when real offers exist.
struct InventoryPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let lines = model.inventoryLines
        VStack(alignment: .leading, spacing: 10) {
            Text("Inventory").font(Showroom.display(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            if lines.isEmpty { Text("Nothing in this design yet.").foregroundStyle(Showroom.quiet) }
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(line.quantity) ×").monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.isMissing ? "\(line.name) (\(model.remote.absenceReason(for: line.reference) ?? "unavailable"))" : line.name)
                        Text(line.dimensionsLabel).font(Showroom.ui(14, relativeTo: .footnote)).foregroundStyle(Showroom.quiet)
                        if let price = line.priceText() {
                            Text(price).font(Showroom.ui(14, relativeTo: .footnote)).foregroundStyle(Showroom.quiet)
                        }
                        if let url = line.offer?.retailerURL, line.offer?.available == true {
                            Link("View at the retailer", destination: url).font(Showroom.ui(14, relativeTo: .footnote))
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ForEach(Inventory.subtotals(lines), id: \.currency) { Text($0.text()).font(Showroom.ui(16, relativeTo: .callout)) }
        }
    }
}

struct CataloguePanel: View {
    @Environment(AppModel.self) private var model
    let preview: (CatalogueItem) -> Void

    var body: some View {
        let canPlace = model.isRoomViewOpen && model.alignment.showsSpatialContent
        VStack(alignment: .leading, spacing: 12) {
            Text("Catalogue").font(Showroom.display(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            if !canPlace { Text("Open the room view to place items.").foregroundStyle(Showroom.quiet) }
            ForEach(model.catalogue) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name).font(Showroom.ui(18, relativeTo: .headline))
                    Text("\(item.category.capitalized) · \(item.affinity.rawValue) · \(item.dimensionLabel)").foregroundStyle(Showroom.quiet)
                    if item.source == .bundled {
                        Text("\(item.licence) · \(item.author)").font(Showroom.ui(13, relativeTo: .caption)).foregroundStyle(Showroom.quiet)
                    }
                    AdaptiveStack {
                        Button("Add \(item.name)") { Task { await model.add(item) } }
                            .buttonStyle(BrassButtonStyle())
                            .disabled(!canPlace)
                        Button("Preview \(item.name)") { preview(item) }.buttonStyle(.bordered)
                    }
                    if model.addFailedItem == item.id { Text(ReleaseOutcome.message).foregroundStyle(Showroom.quiet) }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Showroom.bone.opacity(0.4), in: .rect(cornerRadius: 14))
            }
            RemoteCatalogueSection()
        }
    }
}

struct RemoteCatalogueSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("More from the catalogue").font(Showroom.ui(17, relativeTo: .headline))
            switch model.remote.status {
            case .notConfigured:
                Text("The online catalogue isn't connected in this build.").foregroundStyle(Showroom.quiet)
            case .idle, .loading:
                ProgressView("Checking the online catalogue…")
            case .failed(let reason):
                Text("\(reason) Everything already downloaded still works offline.").foregroundStyle(Showroom.quiet)
            case .loaded:
                RemoteSearch()
                let items = model.remote.notYetDownloaded
                if items.isEmpty { Text("Nothing more to download for this search.").foregroundStyle(Showroom.quiet) }
                ForEach(items, id: \.id) { summary in
                    AdaptiveStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.name)
                            if let offer = summary.offer {
                                Text(offer.pricedOffer.amountText()).font(Showroom.ui(14, relativeTo: .footnote)).foregroundStyle(Showroom.quiet)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if model.remote.downloading.contains(summary.id) {
                            ProgressView().accessibilityLabel("Downloading \(summary.name)")
                        } else {
                            Button("Download \(summary.name)") {
                                Task {
                                    do { try await model.remote.download(summary) } catch { model.errorMessage = AppModel.describe(error) }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                if model.remote.nextCursor != nil {
                    Button(model.remote.loadingMore ? "Loading…" : "Show more") { Task { await model.remote.loadMore() } }
                        .buttonStyle(.bordered)
                        .disabled(model.remote.loadingMore)
                }
            }
        }
    }
}

/// Search and filter the online catalogue. Search text is sent to the catalogue service only to find furniture; it
/// isn't logged by the service and carries no account or device identifier.
private struct RemoteSearch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var remote = model.remote
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search the online catalogue", text: $remote.searchText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { Task { await model.remote.search() } }
            Picker("Goes on", selection: $remote.affinityFilter) {
                Text("Anywhere").tag(Affinity?.none)
                ForEach([Affinity.floor, .wall, .ceiling, .tabletop], id: \.self) { Text($0.rawValue.capitalized).tag(Affinity?.some($0)) }
            }
            .pickerStyle(.menu)
            .onChange(of: model.remote.affinityFilter) { Task { await model.remote.search() } }
        }
    }
}
