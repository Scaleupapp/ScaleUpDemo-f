import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String

    @State private var playlist: Playlist?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var showRenameAlert = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private let playerService = PlayerService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if let playlist {
                contentView(playlist)
            }
        }
        .navigationTitle(playlist?.title ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        editTitle = playlist?.title ?? ""
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

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
        .alert("Rename Playlist", isPresented: $showRenameAlert) {
            TextField("Playlist name", text: $editTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task { await renamePlaylist() }
            }
        }
        .alert("Delete Playlist?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deletePlaylist() }
            }
        } message: {
            Text("This will permanently delete this playlist.")
        }
        .task {
            await loadPlaylist()
        }
    }

    // MARK: - Content

    private var resolvedContentItems: [Content] {
        (playlist?.items ?? []).compactMap { $0.contentId?.contentValue }
    }

    @ViewBuilder
    private func contentView(_ playlist: Playlist) -> some View {
        if resolvedContentItems.isEmpty {
            emptyPlaylistView
        } else {
            playlistListView(playlist)
        }
    }

    private var emptyPlaylistView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("This playlist is empty")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    private func playlistListView(_ playlist: Playlist) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                headerRow(playlist)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)

                ForEach(resolvedContentItems) { content in
                    NavigationLink {
                        PlayerView(contentId: content.id)
                    } label: {
                        contentRow(content, index: resolvedContentItems.firstIndex(where: { $0.id == content.id }) ?? 0)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 6)
                }
            }
        }
    }


    private func headerRow(_ playlist: Playlist) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(resolvedContentItems.count) items")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            if !playlist.formattedDuration.isEmpty {
                Text("·").foregroundStyle(ColorTokens.textTertiary)
                Text(playlist.formattedDuration)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Spacer()
            if !isEditing, let first = resolvedContentItems.first {
                NavigationLink {
                    PlayerView(contentId: first.id)
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
                .buttonStyle(.plain)
            }
        }
    }

    private func contentRow(_ content: Content, index: Int) -> some View {
        HStack(spacing: Spacing.md) {
            // Index number
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 20)

            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                if let thumb = content.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            ColorTokens.surfaceElevated
                        }
                    }
                    .frame(width: 80, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ColorTokens.surfaceElevated
                        .frame(width: 80, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if !content.formattedDuration.isEmpty {
                    Text(content.formattedDuration)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(3)
                }
            }

            // Title + creator
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                if let creator = content.creatorId {
                    Text(creator.displayName)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func loadPlaylist() async {
        isLoading = true
        playlist = try? await playerService.fetchPlaylistDetail(playlistId: playlistId)
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

    private func removeItems(at offsets: IndexSet) {
        guard let items = playlist?.items else { return }
        for index in offsets {
            let contentId = items[index].contentId?.idValue ?? ""
            Task {
                try? await playerService.removeFromPlaylist(playlistId: playlistId, contentId: contentId)
                await loadPlaylist()
            }
        }
    }

}
