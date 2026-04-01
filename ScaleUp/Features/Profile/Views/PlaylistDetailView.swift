import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String

    @State private var playlist: Playlist?
    @State private var contentItems: [Content] = []
    @State private var isLoading = true
    @State private var editTitle = ""
    @State private var showRenameAlert = false
    @State private var showDeleteConfirm = false
    @State private var navigateToContentId: String?
    @State private var playlistQueue: [String] = []  // For auto-play
    @Environment(\.dismiss) private var dismiss

    private let playerService = PlayerService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if contentItems.isEmpty {
                emptyState
            } else {
                mainList
            }
        }
        .navigationTitle(playlist?.title ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Rename Playlist", isPresented: $showRenameAlert) {
            TextField("Playlist name", text: $editTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") { Task { await renamePlaylist() } }
        }
        .alert("Delete Playlist?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deletePlaylist() } }
        } message: {
            Text("This will permanently delete this playlist.")
        }
        .navigationDestination(item: $navigateToContentId) { id in
            PlayerView(contentId: id)
        }
        .task { await loadPlaylist() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    editTitle = playlist?.title ?? ""
                    showRenameAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    shuffleItems()
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Playlist", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(ColorTokens.gold)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("This playlist is empty")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Main List

    private var mainList: some View {
        List {
            // Header
            headerSection
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                .listRowSeparator(.hidden)

            // Content rows — long press to drag reorder
            ForEach(Array(contentItems.enumerated()), id: \.element.id) { index, content in
                Button {
                    navigateToContentId = content.id
                } label: {
                    contentRow(content, index: index)
                }
                .listRowBackground(ColorTokens.surface)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await removeItem(content) }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: moveItems)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(contentItems.count) items")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)

            if let playlist, !playlist.formattedDuration.isEmpty {
                Text("·").foregroundStyle(ColorTokens.textTertiary)
                Text(playlist.formattedDuration)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            // Play All button
            Button {
                guard let first = contentItems.first else { return }
                navigateToContentId = first.id
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text("Play All")
                }
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(ColorTokens.gold)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Content Row

    private func contentRow(_ content: Content, index: Int) -> some View {
        HStack(spacing: Spacing.md) {
            // Index number
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 20)

            // Thumbnail with watched indicator
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottomTrailing) {
                    thumbnailImage(content)
                        .frame(width: 80, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    if !content.overlayBadge.isEmpty {
                        Text(content.overlayBadge)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .padding(3)
                    }
                }

                // Watched checkmark
                if content._progress?.isCompleted == true {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .background(Circle().fill(.black.opacity(0.5)).frame(width: 12, height: 12))
                        .offset(x: 3, y: 3)
                }
            }

            // Title + creator
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(Typography.caption)
                    .foregroundStyle(content._progress?.isCompleted == true ? ColorTokens.textTertiary : ColorTokens.textPrimary)
                    .lineLimit(2)
                if let creator = content.creatorId {
                    Text(creator.displayName)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))
        }
    }

    @ViewBuilder
    private func thumbnailImage(_ content: Content) -> some View {
        if let thumb = content.thumbnailURL, let url = URL(string: thumb) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ColorTokens.surfaceElevated
                }
            }
        } else {
            ColorTokens.surfaceElevated
        }
    }

    // MARK: - Actions

    private func loadPlaylist() async {
        isLoading = true
        playlist = try? await playerService.fetchPlaylistDetail(playlistId: playlistId)
        contentItems = (playlist?.items ?? []).compactMap { $0.contentId?.contentValue }
        isLoading = false
    }

    private func renamePlaylist() async {
        let name = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let updated = try? await playerService.updatePlaylist(playlistId: playlistId, title: name, description: nil) {
            playlist = updated
            Haptics.success()
        }
    }

    private func deletePlaylist() async {
        try? await playerService.deletePlaylist(playlistId: playlistId)
        Haptics.success()
        dismiss()
    }

    private func removeItem(_ content: Content) async {
        contentItems.removeAll { $0.id == content.id }
        Haptics.success()
        try? await playerService.removeFromPlaylist(playlistId: playlistId, contentId: content.id)
        await loadPlaylist()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        contentItems.move(fromOffsets: source, toOffset: destination)
        Haptics.light()
    }

    private func shuffleItems() {
        withAnimation {
            contentItems.shuffle()
        }
        Haptics.light()
    }
}

// Make String usable with navigationDestination(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}
