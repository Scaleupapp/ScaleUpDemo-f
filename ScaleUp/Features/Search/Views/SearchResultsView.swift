import SwiftUI
import NukeUI

// MARK: - Search Results View

struct SearchResultsView: View {
    let viewModel: SearchViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                switch viewModel.selectedTab {
                case .content:
                    contentResultsList
                case .creators:
                    creatorResultsList
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Content Results

    @ViewBuilder
    private var contentResultsList: some View {
        ForEach(viewModel.results) { content in
            ContentResultRow(content: content)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)

            if content.id != viewModel.results.last?.id {
                Divider()
                    .background(ColorTokens.surfaceElevatedDark)
                    .padding(.horizontal, Spacing.md)
            }

            // Trigger load more when reaching the last few items
            if content.id == viewModel.results.last?.id && viewModel.hasMore {
                loadMoreIndicator
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
            }
        }

        // Loading more spinner
        if viewModel.isLoadingMore {
            loadMoreIndicator
        }
    }

    // MARK: - Creator Results

    @ViewBuilder
    private var creatorResultsList: some View {
        if viewModel.creatorResults.isEmpty {
            VStack {
                Spacer()
                    .frame(height: Spacing.xxxl)
                EmptyStateView(
                    icon: "person.2",
                    title: "No creators found",
                    subtitle: "Try searching with different keywords"
                )
            }
        } else {
            ForEach(viewModel.creatorResults) { creator in
                CreatorResultRow(creator: creator)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)

                if creator.id != viewModel.creatorResults.last?.id {
                    Divider()
                        .background(ColorTokens.surfaceElevatedDark)
                        .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    // MARK: - Load More Indicator

    private var loadMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(ColorTokens.primary)
                .padding(.vertical, Spacing.md)
            Spacer()
        }
    }
}

// MARK: - Content Result Row

struct ContentResultRow: View {
    let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Thumbnail (80x45, 16:9 aspect)
            thumbnailView
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)

                HStack(spacing: Spacing.xs) {
                    Text(content.creator.firstName + " " + content.creator.lastName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .lineLimit(1)

                    Text("\u{2022}")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    Text(content.domain)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .lineLimit(1)
                }

                HStack(spacing: Spacing.xs) {
                    // Rating
                    if content.averageRating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(ColorTokens.warning)

                            Text(String(format: "%.1f", content.averageRating))
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                        }
                    }

                    // View count
                    if content.viewCount > 0 {
                        if content.averageRating > 0 {
                            Text("\u{2022}")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }
                        Text(formatViewCount(content.viewCount))
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }

                    // Duration
                    if let duration = content.duration {
                        Text("\u{2022}")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                        Text(formatDuration(duration))
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailURL = content.resolvedThumbnailURL, let url = URL(string: thumbnailURL) {
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

    // MARK: - Formatters

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM views", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK views", Double(count) / 1_000)
        }
        return "\(count) views"
    }
}

// MARK: - Creator Result Row

struct CreatorResultRow: View {
    let creator: CreatorSearchResult

    var body: some View {
        let profile = creator.creatorProfile

        HStack(spacing: Spacing.sm) {
            // Creator Avatar
            CreatorAvatar(
                imageURL: nil,
                name: creator.displayName,
                tier: profile?.tier.rawValue ?? "rising",
                size: 40
            )

            // Creator info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(creator.displayName)
                        .font(Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    // Tier badge
                    if let tier = profile?.tier {
                        tierBadge(tier: tier)
                    }
                }

                if let domain = profile?.domain {
                    Text(domain)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .lineLimit(1)
                }

                if let stats = profile?.stats {
                    HStack(spacing: Spacing.sm) {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                            Text(formatFollowerCount(stats.totalFollowers))
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.warning)
                            Text(String(format: "%.1f", stats.averageRating))
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }

                        HStack(spacing: 2) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                            Text("\(stats.totalContent) items")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Tier Badge

    @ViewBuilder
    private func tierBadge(tier: CreatorTier) -> some View {
        let tierConfig = tierConfiguration(for: tier)
        Text(tierConfig.label)
            .font(Typography.micro)
            .foregroundStyle(tierConfig.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tierConfig.color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func tierConfiguration(for tier: CreatorTier) -> (label: String, color: Color) {
        switch tier {
        case .anchor:
            return ("Anchor", ColorTokens.anchorGold)
        case .core:
            return ("Core", ColorTokens.coreSilver)
        case .rising:
            return ("Rising", ColorTokens.risingBronze)
        }
    }

    // MARK: - Formatter

    private func formatFollowerCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count) followers"
    }
}
