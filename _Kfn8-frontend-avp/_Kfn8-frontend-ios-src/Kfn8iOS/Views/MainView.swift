import Kfn8Domain
import Kfn8Persistence
import SwiftUI

/// Spaces and Rooms on the left, the room's Designs, Inventory and Catalogue on the right. On iPhone the split view
/// collapses to one column, and choosing or creating a room shows its detail.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var compactColumn = NavigationSplitViewColumn.sidebar
    @State private var pendingDeletion: (room: Room, preview: DeletionPreview)?
    @State private var previewItem: CatalogueItem?

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            sidebar
        } detail: {
            RoomDetail(preview: { previewItem = $0 })
        }
        .onChange(of: model.currentRoom?.id) { _, id in compactColumn = id == nil ? .sidebar : .detail }
        .font(Showroom.ui())
        .tint(Showroom.brass)
        .foregroundStyle(Showroom.ink)
        .preferredColorScheme(.light)
        .confirmationDialog(pendingDeletion?.preview.confirmationText ?? "",
                            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                if let room = pendingDeletion?.room { Task { await model.delete(room) } }
                pendingDeletion = nil
            }
            Button("Keep", role: .cancel) { pendingDeletion = nil }
        }
        .fullScreenCover(isPresented: $model.isRoomViewOpen) {
            RoomARScreen().environment(model)
        }
        .sheet(item: $previewItem) { PreviewSheet(item: $0) }
    }

    private var sidebar: some View {
        List {
            Section("Spaces") {
                ForEach(model.spaces) { space in
                    Button(space.name) { Task { await model.perform { try await model.selectSpace(space.id) } } }
                        .fontWeight(space.id == model.currentSpaceID ? .semibold : .regular)
                        .accessibilityAddTraits(space.id == model.currentSpaceID ? .isSelected : [])
                }
                Button("New space", systemImage: "plus") { Task { await model.createSpace() } }
            }
            if model.currentSpaceID != nil {
                Section("Rooms") {
                    ForEach(model.rooms) { room in
                        HStack {
                            Button(room.name) {
                                Task { await model.perform { try await model.selectRoom(room) }; compactColumn = .detail }
                            }
                            .fontWeight(room.id == model.currentRoom?.id ? .semibold : .regular)
                            .accessibilityAddTraits(room.id == model.currentRoom?.id ? .isSelected : [])
                            Spacer()
                            Button("Delete \(room.name)", systemImage: "trash") {
                                Task { if let p = await model.deletionPreview(for: room) { pendingDeletion = (room, p) } }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                    Button("New room", systemImage: "plus") { Task { await model.createRoom() } }
                }
            }
        }
        .navigationTitle("Kfn8")
    }
}

/// The selected room outside the room view: status, banners and the three panels.
struct RoomDetail: View {
    @Environment(AppModel.self) private var model
    let preview: (CatalogueItem) -> Void

    var body: some View {
        if let room = model.currentRoom {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AdaptiveStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(room.name).font(Showroom.display(32)).accessibilityAddTraits(.isHeader)
                            Text(model.alignmentText(room)).font(Showroom.ui(15, relativeTo: .subheadline)).foregroundStyle(Showroom.quiet)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button(room.frame == nil ? "Scan this room" : "Open room view") { model.openRoomView() }
                            .buttonStyle(BrassButtonStyle())
                    }
                    if let limitation = model.captureMode.limitation {
                        Text(limitation).font(Showroom.ui(15, relativeTo: .callout)).foregroundStyle(Showroom.quiet)
                    }
                    ErrorBanner()
                    DesignPanel()
                    InventoryPanel()
                    CataloguePanel(preview: preview)
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Showroom.paper)
            .accessibilityIdentifier("room-detail-scroll")
        } else {
            ContentUnavailableView("No room yet", systemImage: "square.dashed", description: Text("Create a space and a room to start furnishing."))
                .font(Showroom.ui())
        }
    }
}

struct ErrorBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let message = model.errorMessage {
            AdaptiveStack {
                Text(message).foregroundStyle(Showroom.ink).frame(maxWidth: .infinity, alignment: .leading)
                Button("Dismiss") { model.errorMessage = nil }
            }
            .padding(14)
            .background(Showroom.clay.opacity(0.3), in: .rect(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
    }
}
