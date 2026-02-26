import SwiftUI
import NukeUI

struct ContentDetailView: View {
    let contentId: String

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ContentDetailViewModel?
    @State private var showPlayer = false
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
                    detailContent(content: content, viewModel: viewModel)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ColorTokens.backgroundDark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel?.content?.title ?? "")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(1)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Share action
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            NavigationStack {
                PlayerView(contentId: contentId)
            }
            .environment(dependencies)
            .environment(appState)
        }
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
    }

    // MARK: - Detail Content

    private func detailContent(content: Content, viewModel: ContentDetailViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                // Thumbnail / Preview Area
                thumbnailSection(content: content)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Title
                    Text(content.title)
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    // Creator Row
                    creatorRow(content: content)

                    // Stats Row
                    statsRow(viewModel: viewModel)

                    // Action Bar
                    actionBar(viewModel: viewModel)

                    Divider()
                        .background(ColorTokens.surfaceElevatedDark)

                    // AI Summary Section
                    if let aiData = content.aiData, aiData.summary != nil {
                        aiSummarySection(aiData: aiData, viewModel: viewModel)

                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)
                    }

                    // Description
                    if let description = content.description, !description.isEmpty {
                        descriptionSection(description: description, viewModel: viewModel)

                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)
                    }

                    // Similar Content
                    if !viewModel.similarContent.isEmpty {
                        similarContentSection(viewModel: viewModel)

                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)
                    }

                    // Comments Section
                    commentsSection(viewModel: viewModel)
                }
                .padding(.horizontal, Spacing.md)

                Spacer()
                    .frame(height: Spacing.xxxl)
            }
        }
    }

    // MARK: - Thumbnail Section

    /// Higher quality thumbnail URL for the detail view.
    private func detailThumbnailURL(for content: Content) -> String? {
        if content.sourceType == .youtube, let videoId = content.youtubeVideoId {
            return "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
        }
        return content.thumbnailURL
    }

    private func thumbnailSection(content: Content) -> some View {
        ZStack(alignment: .center) {
            if let thumbnailURL = detailThumbnailURL(for: content), let url = URL(string: thumbnailURL) {
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

            // Play overlay
            Image(systemName: "play.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 8)

            // Duration badge
            if let duration = content.duration {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(Typography.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            .padding(Spacing.md)
                    }
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fill)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            showPlayer = true
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [ColorTokens.primaryDark, ColorTokens.surfaceElevatedDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Creator Row

    private func creatorRow(content: Content) -> some View {
        HStack(spacing: Spacing.sm) {
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
                        HStack(spacing: Spacing.xs) {
                            Text("\(content.creator.firstName) \(content.creator.lastName)")
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            // Difficulty badge
                            Text(content.difficulty.rawValue.capitalized)
                                .font(Typography.micro)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(difficultyColor(content.difficulty))
                                .clipShape(Capsule())
                        }

                        Text(content.domain)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if let viewModel {
                SecondaryButton(
                    title: viewModel.isFollowingCreator ? "Following" : "Follow"
                ) {
                    Task { await viewModel.toggleFollow() }
                }
                .frame(width: 100, height: 36)
            }
        }
    }

    // MARK: - Stats Row

    private func statsRow(viewModel: ContentDetailViewModel) -> some View {
        HStack(spacing: Spacing.md) {
            statItem(icon: "eye", value: formatCount(viewModel.content?.viewCount ?? 0), label: "views")
            statItem(icon: "heart.fill", value: formatCount(viewModel.likeCount), label: "likes")

            if let rating = viewModel.content?.averageRating, rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.warning)
                    Text(String(format: "%.1f", rating))
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                    Text("(\(viewModel.content?.ratingCount ?? 0))")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }

            statItem(icon: "bubble.left", value: formatCount(viewModel.commentCount), label: "comments")

            Spacer()
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiaryDark)
            Text(value)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Action Bar

    private func actionBar(viewModel: ContentDetailViewModel) -> some View {
        HStack(spacing: Spacing.xl) {
            // Like
            actionButton(
                icon: viewModel.isLiked ? "heart.fill" : "heart",
                label: "Like",
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
            actionButton(
                icon: "square.and.arrow.up",
                label: "Share",
                color: ColorTokens.textSecondaryDark
            ) {
                // Share action — future implementation
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
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

    private func aiSummarySection(aiData: AIData, viewModel: ContentDetailViewModel) -> some View {
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

                    // Key concepts
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

                    // Prerequisites
                    if let prerequisites = aiData.prerequisites, !prerequisites.isEmpty {
                        Text("Prerequisites")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .padding(.top, Spacing.xs)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(prerequisites, id: \.self) { prereq in
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(ColorTokens.success)
                                    Text(prereq)
                                        .font(Typography.bodySmall)
                                        .foregroundStyle(ColorTokens.textSecondaryDark)
                                }
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

    // MARK: - Description Section

    private func descriptionSection(description: String, viewModel: ContentDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("About")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(description)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .lineSpacing(4)
                .lineLimit(viewModel.isDescriptionExpanded ? nil : 4)

            if description.count > 200 {
                Button {
                    withAnimation(Animations.standard) {
                        viewModel.isDescriptionExpanded.toggle()
                    }
                } label: {
                    Text(viewModel.isDescriptionExpanded ? "Show Less" : "Read More")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Similar Content Section

    private func similarContentSection(viewModel: ContentDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Similar Content")
                .padding(.horizontal, -Spacing.md)

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
                                viewCount: item.viewCount > 0 ? item.viewCount : nil
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

    // MARK: - Comments Section

    private func commentsSection(viewModel: ContentDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Comments")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("(\(viewModel.commentCount))")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                Spacer()
            }

            // Add comment field
            HStack(spacing: Spacing.sm) {
                TextField("Add a comment...", text: Binding(
                    get: { viewModel.newCommentText },
                    set: { viewModel.newCommentText = $0 }
                ))
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)
                .frame(height: 40)
                .background(ColorTokens.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.full))

                if !viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        Task { await viewModel.addComment() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorTokens.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSubmittingComment)
                }
            }

            // Comments list
            if viewModel.isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(ColorTokens.primary)
                    Spacer()
                }
                .padding(Spacing.md)
            } else if viewModel.comments.isEmpty {
                Text("No comments yet. Be the first to share your thoughts!")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                    .padding(.vertical, Spacing.md)
            } else {
                ForEach(viewModel.comments) { comment in
                    commentRow(comment)
                }
            }
        }
    }

    // MARK: - Comment Row

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            CreatorAvatar(
                imageURL: comment.userId.profilePicture,
                name: "\(comment.userId.firstName) \(comment.userId.lastName)",
                size: 32
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("\(comment.userId.firstName) \(comment.userId.lastName)")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text(timeAgo(from: comment.createdAt))
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                Text(comment.text)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonLoader(height: 220)
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
            viewModel = ContentDetailViewModel(
                contentService: dependencies.contentService,
                recommendationService: dependencies.recommendationService,
                socialService: dependencies.socialService
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

    private func timeAgo(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return ""
            }
            return relativeTime(from: date)
        }
        return relativeTime(from: date)
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        }
    }
}
