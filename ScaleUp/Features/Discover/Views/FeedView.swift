import SwiftUI

struct FeedView: View {
    @Bindable var viewModel: DiscoverViewModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark.ignoresSafeArea()

            if viewModel.isLoading && viewModel.pickedForYou.isEmpty {
                feedSkeletonView
            } else if let error = viewModel.error, viewModel.pickedForYou.isEmpty {
                ErrorStateView(
                    message: error.errorDescription ?? "Failed to load feed."
                ) {
                    Task { await viewModel.loadFeed() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                feedContent
            }
        }
        .task {
            if viewModel.pickedForYou.isEmpty {
                await viewModel.loadFeed()
            }
        }
        .onChange(of: viewModel.pickedForYou.count) {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Spacing.lg + 4) {
                // Hero Banner
                if let hero = viewModel.heroContent {
                    NavigationLink(value: hero) {
                        HeroBannerView(content: hero)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.md)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5), value: appeared)
                }

                // Picked For You
                if !viewModel.pickedForYouCarousel.isEmpty {
                    feedSection(
                        title: "Picked For You",
                        icon: "star.fill",
                        iconColor: ColorTokens.anchorGold,
                        items: viewModel.pickedForYouCarousel,
                        delay: 0.1
                    )
                }

                // Strengthen Your Weak Spots
                if !viewModel.gapContent.isEmpty {
                    feedSection(
                        title: "Strengthen Your Weak Spots",
                        icon: "target",
                        iconColor: ColorTokens.warning,
                        items: viewModel.gapContent,
                        delay: 0.2
                    )
                }

                // Trending This Week
                if !viewModel.trendingContent.isEmpty {
                    feedSection(
                        title: "Trending This Week",
                        icon: "flame.fill",
                        iconColor: ColorTokens.error,
                        items: viewModel.trendingContent,
                        delay: 0.3
                    )
                }

                // Creator Spotlight
                if !viewModel.creators.isEmpty {
                    CreatorSpotlightRow(creators: viewModel.creators)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
                }

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxxl)
            }
            .padding(.top, Spacing.sm)
        }
        .refreshable {
            appeared = false
            await viewModel.refresh()
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    // MARK: - Feed Section

    private func feedSection(title: String, icon: String, iconColor: Color, items: [Content], delay: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 4) {
            // Enhanced section header with icon
            HStack(spacing: Spacing.xs + 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                HStack(spacing: 2) {
                    Text("See All")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ColorTokens.primary)
                }
            }
            .padding(.horizontal, Spacing.md)

            HorizontalCarousel(items: items) { item in
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
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }

    // MARK: - Skeleton Loading

    private var feedSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Hero skeleton
                SkeletonLoader(height: 220, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)

                // Section skeletons
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SkeletonLoader(width: 160, height: 18)
                            .padding(.horizontal, Spacing.md)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(0..<4, id: \.self) { _ in
                                    SkeletonCard()
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        }
                    }
                }
            }
            .padding(.top, Spacing.sm)
        }
    }
}
