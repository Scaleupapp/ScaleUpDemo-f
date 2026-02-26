import SwiftUI

// MARK: - Topic Detail View

/// Detail screen for a specific topic, pushed from the topic mastery grid.
/// Displays the ProgressRing score, level badge, trend, quiz stats, and gap-filling content.
struct TopicDetailView: View {

    let topicName: String
    let knowledgeService: KnowledgeService
    let recommendationService: RecommendationService

    @State private var viewModel: TopicDetailViewModel?

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.mastery == nil {
                    topicSkeletonView
                } else if let error = viewModel.error, viewModel.mastery == nil {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadTopic() }
                        }
                    )
                } else if viewModel.mastery != nil {
                    topicContent(viewModel: viewModel)
                }
            }
        }
        .navigationTitle(topicName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = TopicDetailViewModel(
                    topicName: topicName,
                    knowledgeService: knowledgeService,
                    recommendationService: recommendationService
                )
            }
        }
        .task {
            if let viewModel, viewModel.mastery == nil {
                await viewModel.loadTopic()
            }
        }
    }

    // MARK: - Topic Content

    @ViewBuilder
    private func topicContent(viewModel: TopicDetailViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Topic name hero
                Text(viewModel.topicName)
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Spacing.md)

                // Large ProgressRing
                ProgressRing(
                    progress: viewModel.scoreProgress,
                    size: 140,
                    lineWidth: 14,
                    showPercentage: true
                )
                .padding(.vertical, Spacing.sm)

                // Level Badge
                levelBadge(viewModel: viewModel)

                // Trend Indicator
                trendRow(viewModel: viewModel)

                // Stats Cards
                statsRow(viewModel: viewModel)

                // Take Quiz Button
                takeQuizButton

                // Related Gap Content
                if !viewModel.gapContent.isEmpty {
                    gapContentSection(viewModel: viewModel)
                }

                // Bottom spacing
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Level Badge

    @ViewBuilder
    private func levelBadge(viewModel: TopicDetailViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(viewModel.levelColor)
                .frame(width: 10, height: 10)

            Text(viewModel.levelDisplayName)
                .font(Typography.titleMedium)
                .foregroundStyle(viewModel.levelColor)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(viewModel.levelColor.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Trend Row

    @ViewBuilder
    private func trendRow(viewModel: TopicDetailViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: viewModel.trendIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(viewModel.trendColor)

            Text(viewModel.trendLabel)
                .font(Typography.body)
                .foregroundStyle(viewModel.trendColor)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(viewModel.trendColor.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Stats Row

    @ViewBuilder
    private func statsRow(viewModel: TopicDetailViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            // Quiz count
            VStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.primary)

                Text("\(viewModel.quizCount)")
                    .font(Typography.monoLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Assessments")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .cardStyle()

            // Last assessed
            VStack(spacing: Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.info)

                if let lastDate = viewModel.lastAssessedFormatted {
                    Text(lastDate)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)
                } else {
                    Text("Never")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                Text("Last Assessed")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .cardStyle()

            // Score
            VStack(spacing: Spacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.success)

                Text("\(viewModel.scoreInt)")
                    .font(Typography.monoLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Score")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .cardStyle()
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Take Quiz Button

    private var takeQuizButton: some View {
        PrimaryButton(title: "Take Quiz on This Topic") {
            // Quiz navigation handled by parent coordinator
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Gap Content Section

    @ViewBuilder
    private func gapContentSection(viewModel: TopicDetailViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Strengthen This Topic")

            HorizontalCarousel(items: viewModel.gapContent) { content in
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

    // MARK: - Skeleton

    private var topicSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                SkeletonLoader(width: 180, height: 28)
                    .padding(.top, Spacing.md)

                SkeletonLoader(width: 140, height: 140, cornerRadius: 70)

                SkeletonLoader(width: 120, height: 32, cornerRadius: CornerRadius.full)

                SkeletonLoader(width: 100, height: 28, cornerRadius: CornerRadius.full)

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

                SkeletonLoader(height: 52, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
    }
}
