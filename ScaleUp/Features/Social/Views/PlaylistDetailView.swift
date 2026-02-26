import SwiftUI
import NukeUI

// MARK: - Playlist Detail View

struct PlaylistDetailView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let playlistId: String

    @State private var viewModel: PlaylistDetailViewModel?
    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.playlist == nil {
                    detailSkeleton
                } else if let error = viewModel.error, viewModel.playlist == nil {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadPlaylist(id: playlistId) }
                        }
                    )
                } else if let playlist = viewModel.playlist {
                    detailContent(playlist: playlist, viewModel: viewModel)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Playlist", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(ColorTokens.primary)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let playlist = viewModel?.playlist {
                EditPlaylistSheet(
                    playlist: playlist,
                    onSave: { name, description, isPublic in
                        Task {
                            await viewModel?.updatePlaylist(
                                name: name,
                                description: description,
                                isPublic: isPublic
                            )
                        }
                    }
                )
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = PlaylistDetailViewModel(socialService: dependencies.socialService)
            }
        }
        .task {
            if viewModel?.playlist == nil {
                await viewModel?.loadPlaylist(id: playlistId)
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(playlist: Playlist, viewModel: PlaylistDetailViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                playlistHeader(playlist: playlist, viewModel: viewModel)

                // Content Items
                if playlist.items.isEmpty {
                    emptyItemsState
                } else {
                    itemsList(playlist: playlist, viewModel: viewModel)
                }

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func playlistHeader(playlist: Playlist, viewModel: PlaylistDetailViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            // Hero thumbnail
            playlistHeroImage(playlist: playlist)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .padding(.horizontal, Spacing.md)

            // Title and metadata
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(playlist.title)
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .lineLimit(3)
                }

                // Stats row
                HStack(spacing: Spacing.md) {
                    Label(
                        "\(viewModel.itemCount) \(viewModel.itemCount == 1 ? "item" : "items")",
                        systemImage: "music.note"
                    )
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                    if viewModel.totalDuration > 0 {
                        Label(
                            formatDuration(viewModel.totalDuration),
                            systemImage: "clock"
                        )
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                    }

                    // Public/Private badge
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: playlist.isPublic ? "globe" : "lock.fill")
                            .font(.system(size: 10))
                        Text(playlist.isPublic ? "Public" : "Private")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(
                        playlist.isPublic ? ColorTokens.success : ColorTokens.textTertiaryDark
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)

            Divider()
                .background(ColorTokens.surfaceElevatedDark)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Hero Image

    @ViewBuilder
    private func playlistHeroImage(playlist: Playlist) -> some View {
        if let firstItem = playlist.items.first,
           case .populated(let content) = firstItem.contentId,
           let thumbnailURL = content.thumbnailURL,
           let url = URL(string: thumbnailURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay {
                            LinearGradient(
                                colors: [.clear, ColorTokens.backgroundDark.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                } else {
                    heroPlaceholder
                }
            }
        } else {
            heroPlaceholder
        }
    }

    private var heroPlaceholder: some View {
        LinearGradient(
            colors: [
                ColorTokens.primary.opacity(0.4),
                ColorTokens.primaryDark.opacity(0.7),
                ColorTokens.surfaceDark
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Items List

    @ViewBuilder
    private func itemsList(playlist: Playlist, viewModel: PlaylistDetailViewModel) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(playlist.items.enumerated()), id: \.element.id) { index, item in
                PlaylistItemRow(item: item, index: index + 1)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.removeItem(contentId: item.id) }
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await viewModel.removeItem(contentId: item.id) }
                        } label: {
                            Label("Remove from Playlist", systemImage: "minus.circle")
                        }
                    }

                if index < playlist.items.count - 1 {
                    Divider()
                        .background(ColorTokens.surfaceElevatedDark)
                        .padding(.leading, 60)
                        .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    // MARK: - Empty Items State

    private var emptyItemsState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: Spacing.xl)

            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            VStack(spacing: Spacing.sm) {
                Text("No Items Yet")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Start adding content to build your learning playlist")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
    }

    // MARK: - Skeleton

    private var detailSkeleton: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                SkeletonLoader(height: 200, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 220, height: 24)
                    SkeletonLoader(width: 160, height: 14)
                    SkeletonLoader(width: 200, height: 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)

                Divider()
                    .background(ColorTokens.surfaceElevatedDark)
                    .padding(.horizontal, Spacing.md)

                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: Spacing.md) {
                        SkeletonLoader(width: 48, height: 48, cornerRadius: CornerRadius.small)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonLoader(width: 200, height: 16)
                            SkeletonLoader(width: 140, height: 12)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Playlist Item Row

private struct PlaylistItemRow: View {
    let item: PlaylistItem
    let index: Int

    /// Extracts the populated content if available.
    private var content: PlaylistContent? {
        if case .populated(let c) = item.contentId { return c }
        return nil
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Index number
            Text("\(index)")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
                .frame(width: 20)

            // Thumbnail
            itemThumbnail
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(content?.title ?? "Untitled")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)

                HStack(spacing: Spacing.xs) {
                    if let domain = content?.domain {
                        Text(domain)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }

                    if let duration = content?.duration {
                        Text("·")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                        Text(formatItemDuration(duration))
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }

            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var itemThumbnail: some View {
        if let thumbnailURL = content?.thumbnailURL,
           let url = URL(string: thumbnailURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    thumbnailPlaceholder
                }
            }
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(ColorTokens.surfaceElevatedDark)
            .overlay {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
    }

    // MARK: - Helpers

    private func formatItemDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Edit Playlist Sheet

private struct EditPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss

    let playlist: Playlist
    let onSave: (String?, String?, Bool?) -> Void

    @State private var name: String
    @State private var description: String
    @State private var isPublic: Bool

    init(playlist: Playlist, onSave: @escaping (String?, String?, Bool?) -> Void) {
        self.playlist = playlist
        self.onSave = onSave
        _name = State(initialValue: playlist.title)
        _description = State(initialValue: playlist.description ?? "")
        _isPublic = State(initialValue: playlist.isPublic)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    // Name field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Name")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimaryDark)

                        TextField("Playlist name", text: $name)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .padding(Spacing.md)
                            .background(ColorTokens.surfaceDark)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                            )
                    }

                    // Description field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Description")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimaryDark)

                        TextEditor(text: $description)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(Spacing.md)
                            .background(ColorTokens.surfaceDark)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                            )
                    }

                    // Visibility toggle
                    Toggle(isOn: $isPublic) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: isPublic ? "globe" : "lock.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(isPublic ? ColorTokens.success : ColorTokens.textTertiaryDark)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isPublic ? "Public" : "Private")
                                    .font(Typography.bodyBold)
                                    .foregroundStyle(ColorTokens.textPrimaryDark)

                                Text(isPublic ? "Anyone can see this playlist" : "Only you can see this playlist")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textSecondaryDark)
                            }
                        }
                    }
                    .tint(ColorTokens.primary)

                    Spacer()

                    PrimaryButton(
                        title: "Save Changes",
                        isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmedName, trimmedDescription.isEmpty ? nil : trimmedDescription, isPublic)
                        dismiss()
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
