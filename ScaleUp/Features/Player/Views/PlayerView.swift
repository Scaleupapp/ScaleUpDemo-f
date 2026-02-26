import SwiftUI
import NukeUI

// MARK: - Player View

/// Main player container pushed from ContentDetailView when "Play" is tapped.
/// Renders a YouTube or native player depending on the content's sourceType,
/// with controls overlay, metadata, actions, AI summary, similar content, and comments.
struct PlayerView: View {

    let contentId: String

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PlayerViewModel?

    // MARK: - YouTube Player Coordinator Reference

    @State private var youtubeCoordinator: YouTubePlayerView.Coordinator?
    @State private var youtubeError: Int?
    @State private var showPlaylistSheet = false

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark.ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.content == nil {
                    loadingView
                } else if let error = viewModel.error, viewModel.content == nil {
                    ErrorStateView(
                        message: error.errorDescription ?? "Failed to load content."
                    ) {
                        Task { await viewModel.loadContent(id: contentId) }
                    }
                } else if let content = viewModel.content {
                    playerContent(content: content, viewModel: viewModel)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(for: Content.self) { content in
            ContentDetailView(contentId: content.id)
        }
        .statusBarHidden(viewModel?.isFullscreen == true || viewModel?.isControlsVisible == false)
        .ignoresSafeArea(viewModel?.isFullscreen == true ? .all : [])
        .sheet(isPresented: $showPlaylistSheet) {
            AddToPlaylistSheet(contentId: contentId)
                .environment(dependencies)
        }
        .onAppear {
            initializeViewModel()
        }
        .task {
            if let viewModel, viewModel.content == nil {
                await viewModel.loadContent(id: contentId)
            }
        }
        .onDisappear {
            OrientationHelper.resetToDefault()
            Task {
                await viewModel?.cleanup()
            }
        }
    }

    // MARK: - Player Content Layout

    private func playerContent(content: Content, viewModel: PlayerViewModel) -> some View {
        // Always use native player — videos are stored in S3 regardless of sourceType
        nativeContent(content: content, viewModel: viewModel)
    }

    // MARK: - YouTube Content (full-page WKWebView)

    /// For YouTube, the mobile page already has title, comments, related videos.
    /// We show the WKWebView full-screen with just a close button.
    private func youtubeContent(content: Content, viewModel: PlayerViewModel) -> some View {
        ZStack(alignment: .topLeading) {
            if let videoId = viewModel.youtubeVideoId {
                YouTubePlayerView(
                    videoId: videoId,
                    isPlaying: Binding(
                        get: { viewModel.isPlaying },
                        set: { viewModel.isPlaying = $0 }
                    ),
                    currentTime: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.currentTime = $0 }
                    ),
                    duration: Binding(
                        get: { viewModel.duration },
                        set: { viewModel.duration = $0 }
                    ),
                    isReady: Binding(
                        get: { viewModel.isPlayerReady },
                        set: { viewModel.isPlayerReady = $0 }
                    ),
                    onTimeUpdate: { current, total in
                        viewModel.onTimeUpdate(current: current, total: total)
                    },
                    onVideoEnded: {
                        Task { await viewModel.onVideoEnded() }
                    }
                )
                .ignoresSafeArea()
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
            }
            .padding(.top, Spacing.sm)
            .padding(.leading, Spacing.md)
        }
    }

    // MARK: - Native Content (custom player + metadata)

    private func nativeContent(content: Content, viewModel: PlayerViewModel) -> some View {
        VStack(spacing: 0) {
            // Video player area — fills screen in fullscreen, 16:9 otherwise
            playerArea(content: content, viewModel: viewModel)

            // Hide metadata in fullscreen mode
            if !viewModel.isFullscreen {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    titleSection(content: content)
                    creatorRow(content: content)
                    actionBar(viewModel: viewModel)

                    Divider()
                        .background(ColorTokens.surfaceElevatedDark)

                    if let aiData = content.aiData, aiData.summary != nil {
                        aiSummarySection(aiData: aiData, viewModel: viewModel)
                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)
                    }

                    if !viewModel.similarContent.isEmpty {
                        similarContentSection(viewModel: viewModel)
                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)
                    }

                    CommentsSection(
                        comments: viewModel.comments,
                        commentCount: viewModel.commentCount,
                        isLoading: viewModel.isLoadingComments,
                        isSubmitting: viewModel.isSubmittingComment,
                        newCommentText: Binding(
                            get: { viewModel.newCommentText },
                            set: { viewModel.newCommentText = $0 }
                        ),
                        currentUserId: appState.currentUser?.id,
                        onSubmit: {
                            Task { await viewModel.addComment() }
                        }
                    )

                    Spacer()
                        .frame(height: Spacing.xxxl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }
            } // end if !isFullscreen
        }
    }

    // MARK: - Player Area

    private func playerArea(content: Content, viewModel: PlayerViewModel) -> some View {
        ZStack(alignment: .bottom) {
            // Use presigned stream URL (falls back to contentURL)
            NativePlayerView(
                videoURL: viewModel.streamURL ?? content.contentURL,
                isPlaying: Binding(
                    get: { viewModel.isPlaying },
                    set: { viewModel.isPlaying = $0 }
                ),
                currentTime: Binding(
                    get: { viewModel.currentTime },
                    set: { viewModel.currentTime = $0 }
                ),
                duration: Binding(
                    get: { viewModel.duration },
                    set: { viewModel.duration = $0 }
                ),
                playbackSpeed: viewModel.playbackSpeed,
                isMuted: viewModel.isMuted,
                onTimeUpdate: { current, total in
                    viewModel.onTimeUpdate(current: current, total: total)
                },
                onVideoEnded: {
                    Task { await viewModel.onVideoEnded() }
                }
            )
            .playerAspectRatio(isFullscreen: viewModel.isFullscreen)
            .background(Color.black)
            .clipped()

            // Controls overlay
            PlayerControlsOverlay(
                isPlaying: viewModel.isPlaying,
                currentTime: viewModel.currentTime,
                duration: viewModel.duration,
                isVisible: viewModel.isControlsVisible,
                isMuted: viewModel.isMuted,
                isFullscreen: viewModel.isFullscreen,
                playbackSpeedLabel: viewModel.playbackSpeedLabel,
                onPlayPause: {
                    viewModel.togglePlayPause()
                },
                onSeek: { seconds in
                    viewModel.seek(to: seconds)
                },
                onClose: {
                    if viewModel.isFullscreen {
                        viewModel.toggleFullscreen()
                    } else {
                        dismiss()
                    }
                },
                onTap: {
                    viewModel.toggleControls()
                },
                onSkipForward: {
                    viewModel.skipForward()
                },
                onSkipBackward: {
                    viewModel.skipBackward()
                },
                onToggleMute: {
                    viewModel.toggleMute()
                },
                onSelectSpeed: { speed in
                    viewModel.setPlaybackSpeed(speed)
                },
                onToggleFullscreen: {
                    viewModel.toggleFullscreen()
                }
            )
            .playerAspectRatio(isFullscreen: viewModel.isFullscreen)

            // Mini progress bar at the bottom of the video area
            miniProgressBar(viewModel: viewModel)
        }
    }

    // MARK: - Mini Progress Bar

    private func miniProgressBar(viewModel: PlayerViewModel) -> some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 3)

                    Rectangle()
                        .fill(ColorTokens.primary)
                        .frame(
                            width: geometry.size.width * viewModel.progress,
                            height: 3
                        )
                        .animation(Animations.quick, value: viewModel.progress)
                }
            }
        }
        .playerAspectRatio(isFullscreen: viewModel.isFullscreen)
        .allowsHitTesting(false)
    }

    // MARK: - Title Section

    private func titleSection(content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(content.title)
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            HStack(spacing: Spacing.sm) {
                if let duration = content.duration {
                    Label(formatDuration(duration), systemImage: "clock")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                Text("\(formatCount(content.viewCount)) views")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                Text(content.difficulty.rawValue.capitalized)
                    .font(Typography.micro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(difficultyColor(content.difficulty))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Creator Row

    private func creatorRow(content: Content) -> some View {
        NavigationLink {
            PublicProfileView(userId: content.creator.id)
        } label: {
            HStack(spacing: Spacing.sm) {
                CreatorAvatar(
                    imageURL: content.creator.profilePicture,
                    name: "\(content.creator.firstName) \(content.creator.lastName)",
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(content.creator.firstName) \(content.creator.lastName)")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text(content.domain)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Bar

    private func actionBar(viewModel: PlayerViewModel) -> some View {
        HStack(spacing: Spacing.xl) {
            // Like
            actionButton(
                icon: viewModel.isLiked ? "heart.fill" : "heart",
                label: "\(viewModel.likeCount)",
                color: viewModel.isLiked ? ColorTokens.error : ColorTokens.textSecondaryDark
            ) {
                Task { await viewModel.toggleLike() }
            }

            // Save
            actionButton(
                icon: viewModel.isSaved ? "bookmark.fill" : "bookmark",
                label: "Save",
                color: viewModel.isSaved ? ColorTokens.primary : ColorTokens.textSecondaryDark
            ) {
                Task { await viewModel.toggleSave() }
            }

            // Rate
            Menu {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Task { await viewModel.rateContent(value: star) }
                    } label: {
                        Label(
                            "\(star) Star\(star > 1 ? "s" : "")",
                            systemImage: star <= viewModel.userRating ? "star.fill" : "star"
                        )
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.userRating > 0 ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            viewModel.userRating > 0
                                ? ColorTokens.warning
                                : ColorTokens.textSecondaryDark
                        )
                    Text("Rate")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }

            // Add to Playlist
            actionButton(
                icon: "text.badge.plus",
                label: "Playlist",
                color: ColorTokens.textSecondaryDark
            ) {
                showPlaylistSheet = true
            }

            // Share
            ShareLink(
                item: content(viewModel)?.contentURL ?? "",
                subject: Text(content(viewModel)?.title ?? "")
            ) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                    Text("Share")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    private func content(_ viewModel: PlayerViewModel) -> Content? {
        viewModel.content
    }

    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                Text(label)
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Summary Section

    private func aiSummarySection(aiData: AIData, viewModel: PlayerViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(Animations.standard) {
                    viewModel.isAISummaryExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.primary)

                        Text("AI Summary")
                            .font(Typography.titleMedium)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                    }

                    Spacer()

                    Image(systemName: viewModel.isAISummaryExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
            .buttonStyle(.plain)

            if viewModel.isAISummaryExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Summary text
                    if let summary = aiData.summary {
                        Text(summary)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                            .lineSpacing(4)
                    }

                    // Key concepts as TagChips
                    if let concepts = aiData.keyConcepts, !concepts.isEmpty {
                        Text("Key Concepts")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .padding(.top, Spacing.xs)

                        FlowLayout(spacing: Spacing.sm) {
                            ForEach(concepts, id: \.concept) { concept in
                                TagChip(title: concept.concept)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
                .background(ColorTokens.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Source Attribution Section

    private func sourceAttributionSection(content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)

                Text("This content is sourced from YouTube")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            if let attribution = content.sourceAttribution {
                HStack(spacing: Spacing.sm) {
                    if let creatorName = attribution.originalCreatorName {
                        Text("Original creator:")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)

                        if let creatorUrl = attribution.originalCreatorUrl,
                           let url = URL(string: creatorUrl) {
                            Link(destination: url) {
                                Text(creatorName)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.primary)
                                    .underline()
                            }
                        } else {
                            Text(creatorName)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textPrimaryDark)
                        }
                    }
                }

                if let disclaimer = attribution.importDisclaimer {
                    Text(disclaimer)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .lineSpacing(2)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Similar Content Section

    private func similarContentSection(viewModel: PlayerViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Similar Content")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(viewModel.similarContent) { item in
                        NavigationLink(value: item) {
                            ContentCard(
                                title: item.title,
                                creatorName: "\(item.creator.firstName) \(item.creator.lastName)",
                                domain: item.domain,
                                thumbnailURL: item.resolvedThumbnailURL,
                                duration: item.duration,
                                rating: item.averageRating > 0 ? item.averageRating : nil,
                                viewCount: item.viewCount > 0 ? item.viewCount : nil,
                                isYouTube: item.sourceType == .youtube
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, -Spacing.md)
            .padding(.leading, Spacing.md)
        }
    }

    // MARK: - YouTube Error Fallback

    private func youtubeErrorFallback(content: Content) -> some View {
        ZStack {
            // Thumbnail background
            if let thumbnailURL = content.resolvedThumbnailURL, let url = URL(string: thumbnailURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(ColorTokens.surfaceElevatedDark)
                    }
                }
                .overlay(Color.black.opacity(0.6))
            } else {
                Rectangle().fill(ColorTokens.surfaceElevatedDark)
            }

            VStack(spacing: Spacing.md) {
                Image(systemName: "play.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                Text("This video can't be embedded")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Tap to open in YouTube")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                Button {
                    if let url = URL(string: content.contentURL) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundStyle(.red)
                        Text("Open in YouTube")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(ColorTokens.surfaceElevatedDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            // Player placeholder
            Rectangle()
                .fill(ColorTokens.surfaceElevatedDark)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    ProgressView()
                        .tint(ColorTokens.primary)
                        .scaleEffect(1.5)
                }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                SkeletonLoader(height: 24)
                SkeletonLoader(width: 200, height: 16)
                SkeletonLoader(width: 160, height: 14)
            }
            .padding(.horizontal, Spacing.md)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func initializeViewModel() {
        if viewModel == nil {
            viewModel = PlayerViewModel(
                contentService: dependencies.contentService,
                progressService: dependencies.progressService,
                recommendationService: dependencies.recommendationService
            )
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%dh %dm", hours, remainingMinutes)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: return ColorTokens.success
        case .intermediate: return ColorTokens.warning
        case .advanced: return ColorTokens.error
        }
    }
}

// MARK: - Player Aspect Ratio Extension

extension View {
    /// Applies 16:9 aspect ratio in portrait mode, fills available space in fullscreen.
    @ViewBuilder
    func playerAspectRatio(isFullscreen: Bool) -> some View {
        if isFullscreen {
            self
        } else {
            self.aspectRatio(16 / 9, contentMode: .fit)
        }
    }
}
