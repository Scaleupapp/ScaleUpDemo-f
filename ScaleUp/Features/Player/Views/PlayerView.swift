import SwiftUI

struct PlayerView: View {
    let contentId: String

    @State private var viewModel = PlayerViewModel()
    @State private var selectedTab: PlayerTab = .about
    @State private var showReportSheet = false
    @State private var reportReason = ""
    @State private var reportDescription = ""
    @State private var isReporting = false
    @State private var reportSuccess = false
    @State private var isFullscreen = false
    @State private var showShareSheet = false

    // AI Tutor
    @State private var aiTutorVM = AITutorViewModel()
    @State private var showAITutorSheet = false
    @State private var showAITooltip = false

    enum PlayerTab: String, CaseIterable {
        case about = "About"
        case comments = "Comments"
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.content == nil {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .tint(ColorTokens.gold)
                    Text("Loading content...")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            } else if !viewModel.isLoading && viewModel.content == nil {
                ErrorStateView(
                    message: "This content couldn't be loaded.\nIt may have been removed or your connection dropped.",
                    retryLabel: "Try Again",
                    onRetry: {
                        Task { await viewModel.loadContent(id: contentId) }
                    }
                )
            } else if let content = viewModel.content {
                VStack(spacing: 0) {
                    // Video player
                    VideoPlayerView(
                        player: isFullscreen ? nil : viewModel.player,
                        isPlaying: Binding(
                            get: { viewModel.isPlaying },
                            set: { _ in viewModel.togglePlayPause() }
                        ),
                        isVideoReady: viewModel.isVideoReady,
                        isBuffering: viewModel.isBuffering,
                        currentTime: viewModel.currentTime,
                        duration: viewModel.duration,
                        playbackSpeed: viewModel.playbackSpeed,
                        onSeek: { viewModel.seek(to: $0) },
                        onSeekRelative: { viewModel.seekRelative(seconds: $0) },
                        onSpeedTap: { viewModel.showSpeedPicker = true },
                        onFullscreen: { isFullscreen = true }
                    )

                    // Content details
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            // Title
                            Text(content.title)
                                .font(Typography.titleLarge)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.top, Spacing.md)

                            // Stats row
                            statsRow(content)
                                .padding(.horizontal, Spacing.lg)

                            // Creator row
                            if let creator = content.creatorId {
                                creatorRow(creator)
                                    .padding(.horizontal, Spacing.lg)
                            }

                            // Action bar
                            ActionBar(
                                isLiked: viewModel.isLiked,
                                isSaved: viewModel.isSaved,
                                likeCount: viewModel.likeCount,
                                saveCount: viewModel.saveCount,
                                userRating: viewModel.userRating,
                                onLike: { Task { await viewModel.toggleLike() } },
                                onSave: { Task { await viewModel.toggleSave() } },
                                onRate: { val in Task { await viewModel.rate(val) } },
                                onShare: { showShareSheet = true },
                                onPlaylist: {
                                    viewModel.showPlaylistSheet = true
                                    Task { await viewModel.loadPlaylists() }
                                }
                            )
                            .padding(.horizontal, Spacing.lg)

                            // Tab selector
                            tabSelector
                                .padding(.horizontal, Spacing.lg)

                            // Tab content
                            switch selectedTab {
                            case .about:
                                aboutContent(content)
                            case .comments:
                                commentsSection
                            }

                            // Related content
                            if !viewModel.relatedContent.isEmpty {
                                ContentRow(
                                    title: "Up Next",
                                    items: viewModel.relatedContent,
                                    cardWidth: 200
                                )
                            }

                            Spacer().frame(height: Spacing.xxxl)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .overlay(alignment: .bottomTrailing) {
                        // Floating "Ask AI" button
                        if !isFullscreen {
                            askAIButton
                                .padding(.trailing, Spacing.lg)
                                .padding(.bottom, 80) // clear tab bar + safe area
                        }
                    }
                }
            }

            // Playlist added toast
            if let message = viewModel.playlistAddedMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorTokens.success.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.bottom, Spacing.xxl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeOut, value: viewModel.playlistAddedMessage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        reportReason = ""
                        reportDescription = ""
                        showReportSheet = true
                    } label: {
                        Label("Report Content", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
        .navigationDestination(for: Content.self) { content in
            PlayerView(contentId: content.id)
        }
        .navigationDestination(for: Creator.self) { creator in
            CreatorProfileView(creatorId: creator.id)
        }
        .task {
            await viewModel.loadContent(id: contentId)
            // Load AI Tutor status after content loads
            await aiTutorVM.loadStatus(
                contentId: contentId,
                contentTitle: viewModel.content?.title ?? "Content"
            )
            // Show tooltip for first-time users
            if !aiTutorVM.hasShownTooltip && aiTutorVM.buttonVisible {
                showAITooltip = true
                aiTutorVM.markTooltipShown()
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { showAITooltip = false }
                }
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .sheet(isPresented: $viewModel.showSpeedPicker) {
            speedPickerSheet
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showPlaylistSheet) {
            playlistSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReportSheet) {
            reportSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            ZStack {
                Color.black.ignoresSafeArea()

                VideoPlayerView(
                    player: viewModel.player,
                    isPlaying: Binding(
                        get: { viewModel.isPlaying },
                        set: { _ in viewModel.togglePlayPause() }
                    ),
                    isVideoReady: viewModel.isVideoReady,
                    isBuffering: viewModel.isBuffering,
                    currentTime: viewModel.currentTime,
                    duration: viewModel.duration,
                    playbackSpeed: viewModel.playbackSpeed,
                    onSeek: { viewModel.seek(to: $0) },
                    onSeekRelative: { viewModel.seekRelative(seconds: $0) },
                    onSpeedTap: { viewModel.showSpeedPicker = true },
                    isFullscreen: true,
                    onFullscreen: { isFullscreen = false }
                )
            }
            .ignoresSafeArea()
            .persistentSystemOverlays(.hidden)
            .sheet(isPresented: $viewModel.showSpeedPicker) {
                speedPickerSheet
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let content = viewModel.content {
                ShareActivityView(items: [
                    "Check out \"\(content.title)\" on ScaleUp!\n\nhttps://scaleupapp.club/content/\(content.id)"
                ])
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showAITutorSheet) {
            AITutorSheetView(
                contentId: contentId,
                contentTitle: viewModel.content?.title ?? "Content",
                viewModel: aiTutorVM
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(PlayerTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: Spacing.xs) {
                            Text(tab.rawValue)
                                .font(Typography.bodyBold)
                                .foregroundStyle(selectedTab == tab ? ColorTokens.textPrimary : ColorTokens.textTertiary)

                            if tab == .comments {
                                Text("\(viewModel.commentCount)")
                                    .font(Typography.micro)
                                    .foregroundStyle(selectedTab == tab ? ColorTokens.gold : ColorTokens.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(selectedTab == tab ? ColorTokens.gold.opacity(0.15) : ColorTokens.surfaceElevated)
                                    .clipShape(Capsule())
                            }
                        }

                        Rectangle()
                            .fill(selectedTab == tab ? ColorTokens.gold : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - About Tab Content

    private func aboutContent(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // AI Summary
            if let aiData = content.aiData, aiData.summary != nil {
                aiSummarySection(aiData)
                    .padding(.horizontal, Spacing.lg)
            }

            // Description
            if let desc = content.description, !desc.isEmpty {
                descriptionSection(desc)
                    .padding(.horizontal, Spacing.lg)
            }

            // Content info
            contentInfoSection(content)
                .padding(.horizontal, Spacing.lg)

            // Tags
            if let tags = content.tags, !tags.isEmpty {
                tagsSection(tags)
                    .padding(.horizontal, Spacing.lg)
            }

            // Source attribution
            if content.sourceType == .youtube, let attr = content.sourceAttribution {
                sourceAttribution(attr)
                    .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Content Info

    private func contentInfoSection(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(ColorTokens.gold)
                Text("Details")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            VStack(spacing: Spacing.xs) {
                if let domain = content.domain, !domain.isEmpty {
                    infoRow(label: "Domain", value: domain)
                }
                if let difficulty = content.difficulty {
                    infoRow(label: "Difficulty", value: difficulty.rawValue.capitalized)
                }
                if let topics = content.topics, !topics.isEmpty {
                    infoRow(label: "Topics", value: topics.joined(separator: ", "))
                }
                if let ratingCount = content.ratingCount, ratingCount > 0 {
                    infoRow(label: "Ratings", value: "\(ratingCount) ratings")
                }
                if let commentCount = content.commentCount, commentCount > 0 {
                    infoRow(label: "Comments", value: "\(commentCount)")
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Comment input
            commentInputBar
                .padding(.horizontal, Spacing.lg)

            // Comment error
            if let error = viewModel.commentError {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(ColorTokens.error)
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.error)
                    Spacer()
                }
                .padding(Spacing.sm)
                .background(ColorTokens.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .padding(.horizontal, Spacing.lg)
            }

            // Comments list
            if viewModel.isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(ColorTokens.gold)
                    Spacer()
                }
                .padding(.vertical, Spacing.xl)
            } else if viewModel.comments.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("No comments yet")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("Be the first to share your thoughts")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.comments) { comment in
                        commentRow(comment)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    private var commentInputBar: some View {
        HStack(spacing: Spacing.sm) {
            // User avatar placeholder
            Circle()
                .fill(ColorTokens.surfaceElevated)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

            TextField("Add a comment...", text: $viewModel.newCommentText, axis: .vertical)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimary)
                .tint(ColorTokens.gold)
                .lineLimit(1...4)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 8)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            if !viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    Task { await viewModel.postComment() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorTokens.gold)
                }
                .disabled(viewModel.isPostingComment)
            }
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Avatar
            Circle()
                .fill(ColorTokens.surfaceElevated)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(comment.userId?.initials ?? "?")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    Text(comment.userId?.displayName ?? "User")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .fontWeight(.semibold)

                    Text(comment.timeAgo)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Text(comment.text)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)

                if let likes = comment.likeCount, likes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                        Text("\(likes)")
                            .font(Typography.micro)
                    }
                    .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Speed Picker Sheet

    private var speedPickerSheet: some View {
        VStack(spacing: Spacing.lg) {
            Text("Playback Speed")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.top, Spacing.md)

            VStack(spacing: 0) {
                ForEach(viewModel.speedOptions, id: \.self) { speed in
                    Button {
                        viewModel.setSpeed(speed)
                        viewModel.showSpeedPicker = false
                    } label: {
                        HStack {
                            Text(speedDisplayName(speed))
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)

                            Spacer()

                            if viewModel.playbackSpeed == speed {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(ColorTokens.gold)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                    }

                    if speed != viewModel.speedOptions.last {
                        Divider()
                            .background(ColorTokens.divider)
                    }
                }
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background)
    }

    private func speedDisplayName(_ speed: Float) -> String {
        switch speed {
        case 0.5: return "0.5x — Slow"
        case 0.75: return "0.75x"
        case 1.0: return "1x — Normal"
        case 1.25: return "1.25x"
        case 1.5: return "1.5x"
        case 2.0: return "2x — Fast"
        default: return "\(speed)x"
        }
    }

    // MARK: - Playlist Sheet

    private var playlistSheet: some View {
        VStack(spacing: Spacing.md) {
            Text("Save to Playlist")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.top, Spacing.md)

            // Create new playlist
            HStack(spacing: Spacing.sm) {
                TextField("New playlist name", text: $viewModel.newPlaylistName)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 10)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                Button {
                    Task { await viewModel.createAndAddToPlaylist() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            viewModel.newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ColorTokens.textTertiary : ColorTokens.gold
                        )
                }
            }
            .padding(.horizontal, Spacing.lg)

            Divider()
                .background(ColorTokens.divider)
                .padding(.horizontal, Spacing.lg)

            // Error message
            if let error = viewModel.playlistError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, Spacing.lg)
            }

            // Existing playlists
            if viewModel.isLoadingPlaylists {
                ProgressView()
                    .tint(ColorTokens.gold)
                    .padding(.vertical, Spacing.lg)
            } else if viewModel.playlists.isEmpty {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("No playlists yet")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.vertical, Spacing.lg)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.playlists) { playlist in
                            Button {
                                Task { await viewModel.addToPlaylist(playlist) }
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 18))
                                        .foregroundStyle(ColorTokens.gold)
                                        .frame(width: 36, height: 36)
                                        .background(ColorTokens.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.title)
                                            .font(Typography.bodySmall)
                                            .foregroundStyle(ColorTokens.textPrimary)

                                        Text("\(playlist.itemCount ?? 0) items")
                                            .font(Typography.micro)
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus")
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.sm)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Report Sheet

    private var reportReasons: [(value: String, label: String, icon: String)] {
        [
            ("inappropriate", "Inappropriate Content", "eye.slash"),
            ("spam", "Spam", "xmark.bin"),
            ("misleading", "Misleading", "exclamationmark.triangle"),
            ("copyright", "Copyright Violation", "doc.badge.ellipsis"),
            ("harassment", "Harassment", "hand.raised"),
            ("other", "Other", "ellipsis.circle"),
        ]
    }

    private var reportSheet: some View {
        VStack(spacing: Spacing.lg) {
            if reportSuccess {
                // Success state
                VStack(spacing: Spacing.md) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(ColorTokens.success)
                    Text("Report Submitted")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Thank you for helping keep our community safe.")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(Spacing.lg)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showReportSheet = false
                        reportSuccess = false
                    }
                }
            } else {
                Text("Report Content")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.top, Spacing.md)

                // Reason picker
                VStack(spacing: 0) {
                    ForEach(reportReasons, id: \.value) { reason in
                        Button {
                            reportReason = reason.value
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: reason.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(reportReason == reason.value ? ColorTokens.gold : ColorTokens.textTertiary)
                                    .frame(width: 24)

                                Text(reason.label)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.textPrimary)

                                Spacer()

                                if reportReason == reason.value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ColorTokens.gold)
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                        }

                        if reason.value != reportReasons.last?.value {
                            Divider().background(ColorTokens.divider)
                        }
                    }
                }
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .padding(.horizontal, Spacing.lg)

                // Optional description
                TextField("Additional details (optional)", text: $reportDescription, axis: .vertical)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2...4)
                    .padding(Spacing.sm)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .padding(.horizontal, Spacing.lg)

                // Submit button
                Button {
                    Task {
                        guard !reportReason.isEmpty else { return }
                        isReporting = true
                        do {
                            try await ContentService().reportContent(
                                contentId: contentId,
                                reason: reportReason,
                                description: reportDescription.isEmpty ? nil : reportDescription
                            )
                            Haptics.success()
                            reportSuccess = true
                        } catch {
                            Haptics.error()
                            showReportSheet = false
                        }
                        isReporting = false
                    }
                } label: {
                    HStack {
                        if isReporting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "flag.fill")
                            Text("Submit Report")
                        }
                    }
                    .font(Typography.bodyBold)
                    .foregroundStyle(reportReason.isEmpty ? ColorTokens.textTertiary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(reportReason.isEmpty ? ColorTokens.surfaceElevated : ColorTokens.error)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                .disabled(reportReason.isEmpty || isReporting)
                .padding(.horizontal, Spacing.lg)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Creator Row

    private func creatorRow(_ creator: Creator) -> some View {
        HStack(spacing: Spacing.sm) {
            NavigationLink(value: creator) {
                HStack(spacing: Spacing.sm) {
                    CreatorAvatar(creator: creator, size: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: Spacing.xs) {
                            Text(creator.displayName)
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimary)

                            if let tier = creator.tier {
                                TierBadge(tier: tier)
                            }
                        }

                        if let followers = creator.followersCount, followers > 0 {
                            Text("\(formatCount(followers)) followers")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Task { await viewModel.toggleFollowCreator() }
            } label: {
                HStack(spacing: 4) {
                    if viewModel.isFollowingCreator {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(viewModel.isFollowingCreator ? "Following" : "Follow")
                        .font(Typography.caption)
                }
                .foregroundStyle(viewModel.isFollowingCreator ? ColorTokens.gold : ColorTokens.buttonPrimaryText)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .background(viewModel.isFollowingCreator ? ColorTokens.surface : ColorTokens.gold)
                .overlay(
                    viewModel.isFollowingCreator
                        ? Capsule().stroke(ColorTokens.gold, lineWidth: 1)
                        : nil
                )
                .clipShape(Capsule())
            }
            .disabled(viewModel.isFollowLoading)
        }
    }

    // MARK: - Stats Row

    private func statsRow(_ content: Content) -> some View {
        HStack(spacing: Spacing.md) {
            if let views = content.viewCount {
                Label(formatCount(views) + " views", systemImage: "eye")
            }
            if let rating = content.averageRating, rating > 0 {
                Label(String(format: "%.1f", rating), systemImage: "star.fill")
                    .foregroundStyle(ColorTokens.gold)
            }
            if !content.formattedDuration.isEmpty {
                Label(content.formattedDuration, systemImage: "clock")
            }
            if let comments = content.commentCount, comments > 0 {
                Label("\(comments)", systemImage: "bubble.left")
            }
        }
        .font(Typography.caption)
        .foregroundStyle(ColorTokens.textTertiary)
    }

    // MARK: - AI Summary

    private func aiSummarySection(_ aiData: AIData) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(Motion.springSnappy) {
                    viewModel.isAISummaryExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(ColorTokens.gold)
                    Text("AI Summary")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Image(systemName: viewModel.isAISummaryExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            if viewModel.isAISummaryExpanded {
                if let summary = aiData.summary {
                    Text(summary)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                if let concepts = aiData.keyConcepts, !concepts.isEmpty {
                    FlowLayout(spacing: Spacing.xs) {
                        ForEach(concepts) { concept in
                            HStack(spacing: 4) {
                                if let ts = concept.timestamp {
                                    Text(ts)
                                        .font(Typography.micro)
                                        .foregroundStyle(ColorTokens.gold)
                                }
                                Text(concept.concept)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTokens.surfaceElevated)
                            .clipShape(Capsule())
                        }
                    }
                }

                if let prereqs = aiData.prerequisites, !prereqs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prerequisites")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        ForEach(prereqs, id: \.self) { prereq in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ColorTokens.success)
                                Text(prereq)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Description

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(description)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(viewModel.isDescriptionExpanded ? nil : 3)

            Button {
                withAnimation {
                    viewModel.isDescriptionExpanded.toggle()
                }
            } label: {
                Text(viewModel.isDescriptionExpanded ? "Show less" : "Show more")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.gold)
            }
        }
    }

    // MARK: - Tags

    private func tagsSection(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Source Attribution

    private func sourceAttribution(_ attr: SourceAttribution) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sourced from YouTube")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let creator = attr.originalCreatorName {
                    Text("by \(creator)")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Ask AI Button

    private var askAIButton: some View {
        Button {
            if aiTutorVM.isLoadingStatus {
                // Still loading, do nothing
            } else if aiTutorVM.isDisabled {
                Haptics.warning()
                withAnimation { showAITooltip = true }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { showAITooltip = false }
                }
            } else {
                Haptics.light()
                showAITutorSheet = true
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                if aiTutorVM.isLoadingStatus {
                    ProgressView()
                        .tint(ColorTokens.buttonPrimaryText)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text("Ask AI")
                    .font(Typography.captionBold)
            }
            .foregroundStyle(ColorTokens.buttonPrimaryText)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(aiTutorVM.isDisabled ? ColorTokens.textTertiary : ColorTokens.gold)
            .clipShape(Capsule())
            .shadow(color: ColorTokens.gold.opacity(0.3), radius: 8, y: 4)
        }
        .overlay(alignment: .top) {
            if showAITooltip {
                tooltipBubble(aiTutorVM.isDisabled
                    ? "AI Tutor not available for this video"
                    : "Ask AI about this video")
                    .offset(y: -44)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
        }
    }

    private func tooltipBubble(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Share Sheet

private struct ShareActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
