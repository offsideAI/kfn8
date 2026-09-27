import Kfn8Domain
import Kfn8Persistence
import SwiftUI

/// How a platform shows the room: a Mixed Immersive Space and a preview volume on visionOS; a full-screen AR view and
/// a preview sheet on iPhone/iPad. Each action reports its own failures through `AppModel.errorMessage`.
struct RoomViewActions {
    var openRoomView: @MainActor () async -> Void
    var closeRoomView: @MainActor () async -> Void
    var preview: @MainActor (CatalogueItem) -> Void
}

/// Spaces/Rooms sidebar and the room detail (Designs, Inventory, Catalogue). Shared by visionOS and iPhone/iPad.
struct MainWindow: View {
    @Environment(AppModel.self) private var model
    let actions: RoomViewActions
    @State private var pendingDeletion: (room: Room, preview: DeletionPreview)?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// On iPhone the split view collapses to one column; choosing or creating a room shows its detail.
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            sidebar
        } detail: {
            detail
        }
        .onChange(of: model.currentRoom?.id) { _, id in compactColumn = id == nil ? .sidebar : .detail }
        .font(Showroom.ui())
        .tint(Showroom.brass)
        .confirmationDialog(pendingDeletion?.preview.confirmationText ?? "", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                if let room = pendingDeletion?.room { Task { await model.delete(room) } }
                pendingDeletion = nil
            }
            Button("Keep", role: .cancel) { pendingDeletion = nil }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List {
            Section("Spaces") {
                ForEach(model.spaces) { space in
                    Button(space.name) { Task { await model.perform { try await model.selectSpace(space.id) } } }
                        .fontWeight(space.id == model.currentSpaceID ? .semibold : .regular)
                        .accessibilityAddTraits(space.id == model.currentSpaceID ? .isSelected : [])
                }
                Button("New space", systemImage: "plus") { Task { await model.createSpace(named: model.spaces.isEmpty ? "Home" : "Space \(model.spaces.count + 1)") } }
            }
            if model.currentSpaceID != nil {
                Section("Rooms") {
                    ForEach(model.rooms) { room in
                        HStack {
                            Button(room.name) { Task { await model.perform { try await model.selectRoom(room) } } }
                                .fontWeight(room.id == model.currentRoom?.id ? .semibold : .regular)
                            Spacer()
                            Button("Delete \(room.name)", systemImage: "trash") {
                                Task { if let p = await model.deletionPreview(for: room) { pendingDeletion = (room, p) } }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                    Button("New room", systemImage: "plus") { Task { await model.createRoom(named: "Room \(model.rooms.count + 1)") } }
                }
            }
        }
        .navigationTitle("Kfn8")
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let room = model.currentRoom {
            VStack(alignment: .leading, spacing: 18) {
                roomHeader(room)
                RoomBanners(actions: actions)
                if typeSize.isAccessibilitySize || sizeClass == .compact {
                    // Accessibility text sizes and iPhone widths: one column, so nothing is pushed past the edge.
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            DesignPanel(); InventoryPanel()
                            CataloguePanel(openPreview: actions.preview)
                        }
                        .padding(.bottom, 24)
                    }
                    .accessibilityIdentifier("catalogue-scroll")
                } else {
                    // Two columns so the catalogue never scrolls out of reach as the design grows.
                    HStack(alignment: .top, spacing: 24) {
                        ScrollView { VStack(alignment: .leading, spacing: 24) { DesignPanel(); InventoryPanel() }.padding(.bottom, 24) }
                            .frame(minWidth: 420, maxWidth: .infinity)
                        ScrollView { CataloguePanel(openPreview: actions.preview).padding(.bottom, 24) }
                            .frame(width: 320)
                            .accessibilityIdentifier("catalogue-scroll")
                    }
                }
            }
            .padding(sizeClass == .compact ? 16 : 28)
        } else {
            ContentUnavailableView("No room yet", systemImage: "square.dashed", description: Text("Create a space and a room to start furnishing."))
                .font(Showroom.ui())
        }
    }

    private func roomHeader(_ room: Room) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(room.name).font(Showroom.display(34)).accessibilityAddTraits(.isHeader)
                Text(model.alignmentText(room)).font(Showroom.ui(15, relativeTo: .subheadline)).foregroundStyle(Showroom.quiet)
            }
            Spacer()
            if model.isImmersiveOpen {
                Button("Leave room view") { Task { await actions.closeRoomView() } }
            } else {
                Button(room.frame == nil ? "Scan this room" : "Open room view") { Task { await actions.openRoomView() } }
                    .buttonStyle(BrassButtonStyle())
            }
        }
    }
}

extension AppModel {
    /// One-line room status shown under the room name and in the AR room view.
    func alignmentText(_ room: Room) -> String {
        let simulated = isSimulatedRoom ? " · simulated room (simulator only)" : ""
        if !isImmersiveOpen { return (room.frame == nil ? "Not scanned yet" : "Scanned") + simulated }
        switch alignment {
        case .verified: return "Aligned" + simulated
        case .searching: return (room.frame == nil ? "Scanning: look at the floor and a wall" : "Looking for this room…") + simulated
        case .exhausted: return "I can't tell where this room is yet"
        }
    }
}

/// Lost-alignment recovery choices and the current error, shared by the main window and the AR room view.
struct RoomBanners: View {
    @Environment(AppModel.self) private var model
    let actions: RoomViewActions

    var body: some View {
        if model.alignment == .exhausted && model.isImmersiveOpen {
            VStack(alignment: .leading, spacing: 10) {
                Text("I can't tell where this room is yet").font(Showroom.ui(17, relativeTo: .headline))
                Text("You can rescan into this same room, or review its contents without placing them.").foregroundStyle(Showroom.quiet)
                HStack {
                    Button("Rescan this room") { Task { await model.rescanCurrentRoom() } }.buttonStyle(BrassButtonStyle())
                    Button("Review contents") { Task { await actions.closeRoomView() } }
                }
            }
            .padding(16)
            .background(Showroom.bone.opacity(0.5), in: .rect(cornerRadius: 16))
        }
        if let message = model.errorMessage {
            HStack {
                Text(message).foregroundStyle(Showroom.ink)
                Spacer()
                Button("Dismiss") { model.errorMessage = nil }
            }
            .padding(14)
            .background(Showroom.clay.opacity(0.35), in: .rect(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
    }
}

struct DesignPanel: View {
    @Environment(AppModel.self) private var model
    /// Grows with Dynamic Type so whole words fit on a button line.
    @ScaledMetric(relativeTo: .body) private var actionWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Designs").font(Showroom.display(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            // Actions wrap as whole buttons instead of squeezing their labels (no clipping at any text size).
            LazyVGrid(columns: [GridItem(.adaptive(minimum: actionWidth), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
                Button("Undo", systemImage: "arrow.uturn.backward") { Task { await model.undo() } }.disabled(!model.undoHistory.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { Task { await model.redo() } }.disabled(!model.undoHistory.canRedo)
                Button("Duplicate", systemImage: "plus.square.on.square") { Task { await model.duplicateCurrentDesign() } }
                if let target = model.flipTarget {
                    Button("Flip to \(target.name)", systemImage: "arrow.left.arrow.right") { model.requestFlip() }
                        .accessibilityHint("Switches the room to the other design once it has loaded. Double-tap a placed item to do the same.")
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
                .pickerStyle(.segmented)
            }
            if let status = model.statusMessage {
                Text(status).foregroundStyle(Showroom.quiet).accessibilityLabel(status)
            }
            if let design = model.currentDesign {
                if design.placements.isEmpty {
                    Text("Nothing placed yet. Add something from the catalogue below.").foregroundStyle(Showroom.quiet)
                }
                ForEach(design.placements) { p in placementRow(p) }
            }
        }
    }

    private func placementRow(_ p: Placement) -> some View {
        let item = model.item(for: p.asset)
        let selected = model.selection == p.id
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                model.selection = selected ? nil : p.id
            } label: {
                HStack {
                    Text(item?.name ?? "Unavailable item").font(Showroom.ui(17, relativeTo: .headline))
                    if model.heldInvalid.contains(p.id) { Text("not saved").foregroundStyle(Showroom.quiet) }
                    Spacer()
                    Text(item?.dimensionLabel ?? "").foregroundStyle(Showroom.quiet)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            if selected { PlacementControls(id: p.id, affinity: item?.affinity ?? .floor) }
        }
        .padding(14)
        .background(selected ? Showroom.brass.opacity(0.18) : Showroom.bone.opacity(0.25), in: .rect(cornerRadius: 14))
    }
}

/// Non-gesture alternatives for every spatial action: move, raise/lower, rotate, cancel, remove.
struct PlacementControls: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .callout) private var controlWidth: CGFloat = 170
    let id: PlacementID
    let affinity: Affinity
    private let step: Float = 0.1

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: controlWidth), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            move("Left", "arrow.left", SIMD3(-step, 0, 0))
            move("Right", "arrow.right", SIMD3(step, 0, 0))
            move("Toward wall", "arrow.up", SIMD3(0, 0, -step))
            move("Away from wall", "arrow.down", SIMD3(0, 0, step))
            if affinity == .wall {
                move("Raise", "arrow.up.to.line", SIMD3(0, step, 0))
                move("Lower", "arrow.down.to.line", SIMD3(0, -step, 0))
            }
            Button("Rotate left 15°", systemImage: "rotate.left") { Task { await model.rotate(id, byDegrees: 15) } }
            Button("Rotate right 15°", systemImage: "rotate.right") { Task { await model.rotate(id, byDegrees: -15) } }
            Button("Cancel move", systemImage: "xmark") { model.cancel(id) }.disabled(!model.heldInvalid.contains(id))
            Button("Remove", systemImage: "trash") { Task { await model.remove(id) } }
        }
        .lineLimit(2)
        .buttonStyle(.bordered)
        .labelStyle(.titleAndIcon)
        .font(Showroom.ui(15, relativeTo: .callout))
    }

    private func move(_ title: String, _ icon: String, _ delta: SIMD3<Float>) -> some View {
        Button(title, systemImage: icon) { Task { await model.nudge(id, by: delta) } }
    }
}

/// Generic-first inventory: quantities and real dimensions; prices, dates and subtotals only when real offers exist.
struct InventoryPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let lines = model.inventoryLines
        VStack(alignment: .leading, spacing: 10) {
            Text("Inventory").font(Showroom.display(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            if lines.isEmpty {
                Text("Nothing in this design yet.").foregroundStyle(Showroom.quiet)
            }
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(line.quantity) ×").monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.isMissing ? "\(line.name) (unavailable)" : line.name)
                        Text(line.dimensionsLabel).font(Showroom.ui(14, relativeTo: .footnote)).foregroundStyle(Showroom.quiet)
                        if let price = line.priceText() {
                            Text(price).font(Showroom.ui(14, relativeTo: .footnote)).foregroundStyle(Showroom.quiet)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ForEach(Inventory.subtotals(lines), id: \.currency) { total in
                Text(total.text()).font(Showroom.ui(16, relativeTo: .callout))
            }
        }
        .padding(16)
        .background(Showroom.paper.opacity(0.3), in: .rect(cornerRadius: 16))
    }
}

struct CataloguePanel: View {
    @Environment(AppModel.self) private var model
    let openPreview: (CatalogueItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Catalogue").font(Showroom.display(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            VStack(spacing: 14) {
                ForEach(model.catalogue) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name).font(Showroom.ui(18, relativeTo: .headline))
                        Text("\(item.category.capitalized) · \(item.affinity.rawValue)").foregroundStyle(Showroom.quiet)
                        Text(item.dimensionLabel).foregroundStyle(Showroom.quiet)
                        Text("\(item.licence) · \(item.author)").font(Showroom.ui(13, relativeTo: .caption)).foregroundStyle(Showroom.quiet)
                        HStack {
                            Button("Add \(item.name)") {
                                Task { await model.add(item, near: model.poseInFront?() ?? RigidTransform(translation: SIMD3(0, 0, 2))) }
                            }
                            .buttonStyle(BrassButtonStyle())
                            .disabled(!model.alignment.showsSpatialContent)
                            Button("Preview") { openPreview(item) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Showroom.paper.opacity(0.35), in: .rect(cornerRadius: 18))
                    .accessibilityElement(children: .contain)
                }
            }
            if !model.alignment.showsSpatialContent {
                Text("Open the room view to place items.").foregroundStyle(Showroom.quiet)
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
                ProgressView()
            case .failed:
                Text("The online catalogue isn't reachable right now. Everything already downloaded still works offline.").foregroundStyle(Showroom.quiet)
            case .loaded:
                ForEach(model.remote.items.filter { item in !model.catalogue.contains { $0.id.rawValue == item.id } }, id: \.id) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Button("Download \(item.name)") { Task { await model.downloadRemote(item) } }
                    }
                }
            }
        }
    }
}
