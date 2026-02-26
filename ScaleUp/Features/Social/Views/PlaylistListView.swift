import SwiftUI
import NukeUI

// MARK: - Playlist List View

struct PlaylistListView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var viewModel: PlaylistListViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.isEmpty {
                        playlistListSkeleton
                    } else if let error = viewModel.error, viewModel.isEmpty {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadPlaylists() }
                            }
                        )
                    } else if viewModel.isEmpty {
                        EmptyStateView(
                            icon: "music.note.list",
                            title: "No Playlists Yet",
                            subtitle: "Create your first playlist to organize your learning",
                            buttonTitle: "Create Playlist",
                            action: { viewModel.showCreateSheet = true }
                        )
                    } else {
                        playlistListContent(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel?.showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ColorTokens.primary)
                            .font(.system(size: 22))
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showCreateSheet ?? false },
                set: { viewModel?.showCreateSheet = $0 }
            )) {
                CreatePlaylistView { newPlaylist in
                    viewModel?.addPlaylist(newPlaylist)
                }
                .environment(dependencies)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = PlaylistListViewModel(socialService: dependencies.socialService)
            }
        }
        .task {
            if let viewModel, viewModel.isEmpty {
                await viewModel.loadPlaylists()
            }
        }
    }

    // MARK: - Playlist List Content

    @ViewBuilder
    private func playlistListContent(viewModel: PlaylistListViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.playlists) { playlist in
                    NavigationLink(value: playlist) {
                        PlaylistCardView(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await viewModel.deletePlaylist(id: playlist.id) }
                        } label: {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.deletePlaylist(id: playlist.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(playlistId: playlist.id)
                .environment(dependencies)
        }
    }

    // MARK: - Skeleton

    private var playlistListSkeleton: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: Spacing.md) {
                        SkeletonLoader(width: 72, height: 72, cornerRadius: CornerRadius.small)

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            SkeletonLoader(width: 180, height: 18)
                            SkeletonLoader(width: 120, height: 14)
                            SkeletonLoader(width: 80, height: 12)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }
}

// MARK: - Playlist Card View

private struct PlaylistCardView: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail
            playlistThumbnail
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Metadata
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(playlist.title)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    Label(
                        "\(playlist.items.count) \(playlist.items.count == 1 ? "item" : "items")",
                        systemImage: "music.note"
                    )
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                    if let totalDuration = formattedTotalDuration {
                        Text("*")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)

                        Text(totalDuration)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                }

                // Public / Private badge
                HStack(spacing: Spacing.xs) {
                    Image(systemName: playlist.isPublic ? "globe" : "lock.fill")
                        .font(.system(size: 10))
                    Text(playlist.isPublic ? "Public" : "Private")
                        .font(Typography.micro)
                }
                .foregroundStyle(playlist.isPublic ? ColorTokens.success : ColorTokens.textTertiaryDark)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var playlistThumbnail: some View {
        if let firstItem = playlist.items.first,
           case .populated(let content) = firstItem.contentId,
           let thumbnailURL = content.thumbnailURL,
           let url = URL(string: thumbnailURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    placeholderGradient
                }
            }
        } else {
            placeholderGradient
        }
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [ColorTokens.primary.opacity(0.6), ColorTokens.primaryDark.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note.list")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Helpers

    private var formattedTotalDuration: String? {
        let total = playlist.items.compactMap { item -> Int? in
            if case .populated(let content) = item.contentId { return content.duration }
            return nil
        }.reduce(0, +)
        guard total > 0 else { return nil }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
