import SwiftUI

// MARK: - Add To Playlist Sheet

struct AddToPlaylistSheet: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    /// The content ID to add to or remove from playlists.
    let contentId: String

    // MARK: - State

    @State private var playlists: [Playlist] = []
    @State private var isLoading: Bool = false
    @State private var error: APIError?
    @State private var loadingPlaylistIds: Set<String> = []
    @State private var showCreateSheet: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if isLoading && playlists.isEmpty {
                    loadingSkeleton
                } else if let error, playlists.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: { Task { await loadPlaylists() } }
                    )
                } else {
                    playlistSelectionList
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.primary)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreatePlaylistView { newPlaylist in
                    playlists.insert(newPlaylist, at: 0)
                    // Automatically add the content to the newly created playlist
                    Task { await toggleContent(for: newPlaylist) }
                }
                .environment(dependencies)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await loadPlaylists()
        }
    }

    // MARK: - Playlist Selection List

    private var playlistSelectionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Create New Playlist row
                createNewPlaylistRow

                Divider()
                    .background(ColorTokens.surfaceElevatedDark)
                    .padding(.horizontal, Spacing.md)

                // Existing playlists
                if playlists.isEmpty {
                    emptyState
                } else {
                    ForEach(playlists) { playlist in
                        playlistRow(playlist: playlist)

                        if playlist.id != playlists.last?.id {
                            Divider()
                                .background(ColorTokens.surfaceElevatedDark)
                                .padding(.leading, 60)
                                .padding(.trailing, Spacing.md)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Create New Playlist Row

    private var createNewPlaylistRow: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(ColorTokens.primary.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ColorTokens.primary)
                }

                Text("Create New Playlist")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.primary)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playlist Row

    @ViewBuilder
    private func playlistRow(playlist: Playlist) -> some View {
        let containsContent = playlist.items.contains { $0.id == contentId }
        let isLoadingThis = loadingPlaylistIds.contains(playlist.id)

        Button {
            Task { await toggleContent(for: playlist) }
        } label: {
            HStack(spacing: Spacing.md) {
                // Playlist icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(ColorTokens.surfaceElevatedDark)
                        .frame(width: 48, height: 48)

                    Image(systemName: "music.note.list")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                // Playlist info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    HStack(spacing: Spacing.xs) {
                        Text("\(playlist.items.count) \(playlist.items.count == 1 ? "item" : "items")")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondaryDark)

                        Image(systemName: playlist.isPublic ? "globe" : "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }

                Spacer()

                // Checkmark / Loading
                if isLoadingThis {
                    ProgressView()
                        .tint(ColorTokens.primary)
                        .scaleEffect(0.8)
                } else if containsContent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.success)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoadingThis)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
                .frame(height: Spacing.xl)

            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Text("No playlists yet")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            Text("Create a playlist to start organizing content")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: Spacing.md) {
                    SkeletonLoader(width: 48, height: 48, cornerRadius: CornerRadius.small)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SkeletonLoader(width: 160, height: 16)
                        SkeletonLoader(width: 80, height: 12)
                    }

                    Spacer()

                    SkeletonLoader(width: 22, height: 22, cornerRadius: CornerRadius.full)
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Actions

    @MainActor
    private func loadPlaylists() async {
        isLoading = true
        error = nil

        do {
            playlists = try await dependencies.socialService.playlists()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    @MainActor
    private func toggleContent(for playlist: Playlist) async {
        let containsContent = playlist.items.contains { $0.id == contentId }
        loadingPlaylistIds.insert(playlist.id)

        do {
            let updatedPlaylist: Playlist
            if containsContent {
                updatedPlaylist = try await dependencies.socialService.removeFromPlaylist(
                    playlistId: playlist.id,
                    contentId: contentId
                )
            } else {
                updatedPlaylist = try await dependencies.socialService.addToPlaylist(
                    playlistId: playlist.id,
                    contentId: contentId
                )
            }

            // Update the local list with the returned playlist
            if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[index] = updatedPlaylist
            }

            dependencies.hapticManager.selection()
        } catch {
            dependencies.hapticManager.error()
        }

        loadingPlaylistIds.remove(playlist.id)
    }
}
