import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var viewModel: HomeViewModel?
    @State private var seeAllTitle: String = ""
    @State private var seeAllItems: [Content] = []
    @State private var showSeeAll = false
    @State private var showQuizList = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.dashboardData == nil {
                        homeSkeletonView
                    } else if let error = viewModel.error, viewModel.dashboardData == nil {
                        ErrorStateView(
                            message: error.errorDescription ?? "Failed to load dashboard."
                        ) {
                            Task { await viewModel.loadDashboard() }
                        }
                    } else {
                        homeContent(viewModel: viewModel)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: Content.self) { content in
                ContentDetailView(contentId: content.id)
            }
            .navigationDestination(for: String.self) { contentId in
                ContentDetailView(contentId: contentId)
            }
            .navigationDestination(isPresented: $showSeeAll) {
                ContentListView(title: seeAllTitle, items: seeAllItems)
            }
            .navigationDestination(isPresented: $showQuizList) {
                QuizListView(embedded: true)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HomeViewModel(
                    dashboardService: dependencies.dashboardService,
                    progressService: dependencies.progressService,
                    recommendationService: dependencies.recommendationService
                )
            }
        }
        .task {
            if let viewModel, viewModel.dashboardData == nil {
                await viewModel.loadDashboard()
            }
        }
    }

    // MARK: - Home Content

    @ViewBuilder
    private func homeContent(viewModel: HomeViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {

                // Greeting Header
                greetingHeader(viewModel: viewModel)

                // Quick Stats Bar
                quickStatsBar(viewModel: viewModel)

                // Hero Journey Card (Netflix-style, top priority)
                if viewModel.hasActiveJourney, let journey = viewModel.dashboardData?.journey {
                    HeroPlanCard(journey: journey) {
                        // Navigate to Journey tab in future
                    }
                }

                // Quiz Alert Banner (prominent, tappable)
                if viewModel.pendingQuizzes > 0 {
                    QuizAlertBanner(count: viewModel.pendingQuizzes) {
                        showQuizList = true
                    }
                }

                // Continue Watching
                if !viewModel.continueWatching.isEmpty {
                    ContinueWatchingRow(items: viewModel.continueWatching)
                }

                // Trending Now
                if !viewModel.trendingContent.isEmpty {
                    contentSection(
                        title: "Trending Now",
                        icon: "flame.fill",
                        iconColor: .orange,
                        items: viewModel.trendingContent
                    )
                }

                // Recommended For You
                if !viewModel.recommendations.isEmpty {
                    contentSection(
                        title: viewModel.objectiveLabel.map { "Recommended for \($0)" } ?? "Recommended For You",
                        icon: "sparkles",
                        iconColor: ColorTokens.primary,
                        items: viewModel.recommendations
                    )
                }

                // Knowledge Snapshot
                if !viewModel.topicMasteries.isEmpty {
                    KnowledgeSnapshotRow(topics: viewModel.topicMasteries)
                }

                // Weekly Stats
                if let stats = viewModel.weeklyStats {
                    WeeklyStatsCard(stats: stats)
                }

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.sm)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Greeting Header

    @ViewBuilder
    private func greetingHeader(viewModel: HomeViewModel) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.greeting), \(appState.currentUser?.firstName ?? "Learner")")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text(viewModel.formattedDate)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            Spacer()

            if viewModel.streak > 0 {
                StreakBadge(count: viewModel.streak)
            }

            Image(systemName: "bell")
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .padding(.leading, Spacing.sm)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Quick Stats Bar

    @ViewBuilder
    private func quickStatsBar(viewModel: HomeViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                StatPill(
                    icon: "chart.bar.fill",
                    label: "Readiness",
                    value: "\(viewModel.readinessScore)%",
                    color: readinessColor(viewModel.readinessScore)
                )

                if viewModel.streak > 0 {
                    StatPill(
                        icon: "flame.fill",
                        label: "Streak",
                        value: "\(viewModel.streak) days",
                        color: .orange
                    )
                }

                if viewModel.pendingQuizzes > 0 {
                    StatPill(
                        icon: "questionmark.circle.fill",
                        label: "Quizzes",
                        value: "\(viewModel.pendingQuizzes) pending",
                        color: ColorTokens.primary
                    )
                }

                if let stats = viewModel.weeklyStats {
                    StatPill(
                        icon: "book.fill",
                        label: "This Week",
                        value: "\(stats.contentConsumed) lessons",
                        color: .cyan
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Reusable Content Section

    @ViewBuilder
    private func contentSection(title: String, icon: String, iconColor: Color, items: [Content]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Subtle top separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            ColorTokens.surfaceElevatedDark,
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, Spacing.lg)

            // Section header with icon and See All
            HStack {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                }

                Spacer()

                Button {
                    seeAllTitle = title
                    seeAllItems = items
                    showSeeAll = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(Typography.bodySmall)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.primary)
                }
            }
            .padding(.horizontal, Spacing.md)

            // Horizontal carousel
            HorizontalCarousel(items: items) { content in
                NavigationLink(value: content) {
                    ContentCard(
                        title: content.title,
                        creatorName: content.creator.firstName + " " + content.creator.lastName,
                        domain: content.domain,
                        thumbnailURL: content.resolvedThumbnailURL,
                        duration: content.duration,
                        rating: content.averageRating > 0 ? content.averageRating : nil,
                        viewCount: content.viewCount > 0 ? content.viewCount : nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func readinessColor(_ score: Int) -> Color {
        switch score {
        case 70...100: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }

    // MARK: - Skeleton Loading View

    private var homeSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                // Greeting skeleton
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonLoader(width: 200, height: 20)
                        SkeletonLoader(width: 120, height: 14)
                    }
                    Spacer()
                    SkeletonLoader(width: 50, height: 28, cornerRadius: CornerRadius.full)
                }
                .padding(.horizontal, Spacing.md)

                // Hero card skeleton
                SkeletonLoader(height: 200, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)

                // Stats bar skeleton
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonLoader(width: 120, height: 48, cornerRadius: CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Content sections skeleton
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SkeletonLoader(width: 160, height: 18)
                            .padding(.horizontal, Spacing.md)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(0..<3, id: \.self) { _ in
                                    SkeletonCard()
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                Text(value)
                    .font(Typography.caption.bold())
                    .foregroundStyle(ColorTokens.textPrimaryDark)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorTokens.surfaceElevatedDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}
