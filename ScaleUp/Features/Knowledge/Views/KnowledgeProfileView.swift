import SwiftUI

// MARK: - Knowledge Profile View

/// Main view for the "Progress" tab. Displays the user's knowledge profile
/// with an Apple Fitness + Spotify Wrapped aesthetic on a dark background.
struct KnowledgeProfileView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var viewModel: KnowledgeProfileViewModel?
    @State private var showLearningStats = false
    @State private var showStrengthsWeaknesses = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.profile == nil {
                        profileSkeletonView
                    } else if let error = viewModel.error, viewModel.profile == nil {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadProfile() }
                            }
                        )
                    } else if !viewModel.hasData {
                        emptyProfileView
                    } else {
                        profileContent(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Knowledge Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = KnowledgeProfileViewModel(
                    knowledgeService: dependencies.knowledgeService,
                    progressService: dependencies.progressService,
                    recommendationService: dependencies.recommendationService
                )
            }
        }
        .task {
            if let viewModel, viewModel.profile == nil {
                await viewModel.loadProfile()
            }
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(viewModel: KnowledgeProfileViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Overall Score Hero
                overallScoreHero(viewModel: viewModel)

                // Learning Stats Row
                learningStatsRow(viewModel: viewModel)

                // Topic Mastery Grid
                if !viewModel.sortedTopics.isEmpty {
                    topicMasterySection(viewModel: viewModel)
                }

                // Strengths Section
                if !viewModel.topStrengths.isEmpty {
                    strengthsSection(viewModel: viewModel)
                }

                // Weaknesses Section
                if !viewModel.topWeaknesses.isEmpty {
                    weaknessesSection(viewModel: viewModel)
                }

                // Gap Recommendations
                if !viewModel.gapRecommendations.isEmpty {
                    gapRecommendationsSection(viewModel: viewModel)
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
    }

    // MARK: - Overall Score Hero

    @ViewBuilder
    private func overallScoreHero(viewModel: KnowledgeProfileViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            ScoreGauge(
                score: viewModel.overallScoreInt,
                size: 160,
                label: "Overall Score"
            )

            Text("\(viewModel.totalTopicsCovered) topics covered \u{2022} \(viewModel.totalQuizzesTaken) quizzes taken")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surfaceDark)
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Learning Stats Row

    @ViewBuilder
    private func learningStatsRow(viewModel: KnowledgeProfileViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Learning Stats") {
                showLearningStats = true
            }

            HStack(spacing: Spacing.sm) {
                statCard(
                    icon: "clock.fill",
                    value: viewModel.hoursLearned,
                    label: "Hours Learned"
                )

                statCard(
                    icon: "book.closed.fill",
                    value: "\(viewModel.lessonsCompleted)",
                    label: "Lessons Done"
                )

                statCard(
                    icon: "sparkles",
                    value: "\(viewModel.topicsExplored)",
                    label: "Topics"
                )
            }
            .padding(.horizontal, Spacing.md)
        }
        .navigationDestination(isPresented: $showLearningStats) {
            if let stats = viewModel.stats {
                LearningStatsView(stats: stats)
            }
        }
    }

    @ViewBuilder
    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.primary)

            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .cardStyle()
    }

    // MARK: - Topic Mastery Section

    @ViewBuilder
    private func topicMasterySection(viewModel: KnowledgeProfileViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Topic Mastery")

            TopicMasteryGrid(
                topics: viewModel.sortedTopics,
                knowledgeService: dependencies.knowledgeService,
                recommendationService: dependencies.recommendationService
            )
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Strengths Section

    @ViewBuilder
    private func strengthsSection(viewModel: KnowledgeProfileViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Your Strengths") {
                showStrengthsWeaknesses = true
            }

            FlowLayout(spacing: Spacing.sm) {
                ForEach(viewModel.topStrengths.prefix(6), id: \.self) { strength in
                    strengthChip(
                        title: strength,
                        score: viewModel.scoreForTopic(strength)
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .navigationDestination(isPresented: $showStrengthsWeaknesses) {
            StrengthsWeaknessesView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func strengthChip(title: String, score: Int) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.success)

            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            if score > 0 {
                Text("\(score)")
                    .font(Typography.mono)
                    .foregroundStyle(ColorTokens.success)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background(ColorTokens.success.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTokens.success.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Weaknesses Section

    @ViewBuilder
    private func weaknessesSection(viewModel: KnowledgeProfileViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Areas to Improve") {
                showStrengthsWeaknesses = true
            }

            FlowLayout(spacing: Spacing.sm) {
                ForEach(viewModel.topWeaknesses.prefix(6), id: \.self) { weakness in
                    weaknessChip(title: weakness)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func weaknessChip(title: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.error)

            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Strengthen")
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.error)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ColorTokens.error.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background(ColorTokens.error.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTokens.error.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Gap Recommendations

    @ViewBuilder
    private func gapRecommendationsSection(viewModel: KnowledgeProfileViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Fill Your Gaps")

            HorizontalCarousel(items: viewModel.gapRecommendations) { content in
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
        }
    }

    // MARK: - Empty State

    private var emptyProfileView: some View {
        EmptyStateView(
            icon: "brain.head.profile",
            title: "Build Your Knowledge Profile",
            subtitle: "Complete quizzes to build your knowledge profile. We'll track your mastery across topics and help you grow.",
            buttonTitle: "Start Learning",
            action: {}
        )
    }

    // MARK: - Skeleton Loading

    private var profileSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Score hero skeleton
                VStack(spacing: Spacing.md) {
                    SkeletonLoader(width: 160, height: 160, cornerRadius: 80)
                    SkeletonLoader(width: 200, height: 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(ColorTokens.surfaceDark)
                )
                .padding(.horizontal, Spacing.md)

                // Stats row skeleton
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: Spacing.sm) {
                            SkeletonLoader(width: 24, height: 24, cornerRadius: 12)
                            SkeletonLoader(width: 50, height: 22)
                            SkeletonLoader(width: 70, height: 12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .cardStyle()
                    }
                }
                .padding(.horizontal, Spacing.md)

                // Topic grid skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 140, height: 20)
                        .padding(.horizontal, Spacing.md)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: Spacing.sm),
                        GridItem(.flexible(), spacing: Spacing.sm)
                    ], spacing: Spacing.sm) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonLoader(height: 100, cornerRadius: CornerRadius.small)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Strengths skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 130, height: 20)
                        .padding(.horizontal, Spacing.md)

                    HStack(spacing: Spacing.sm) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonLoader(width: 90, height: 32, cornerRadius: CornerRadius.full)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Carousel skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 120, height: 20)
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
            .padding(.vertical, Spacing.md)
        }
    }
}
