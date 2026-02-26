import SwiftUI

// MARK: - Topic Mastery Grid

/// Extracted 2-column grid component for displaying topic mastery cards.
/// Each cell shows a KnowledgeBar with the topic name, score, level badge, and trend.
struct TopicMasteryGrid: View {

    let topics: [TopicMastery]
    let knowledgeService: KnowledgeService
    let recommendationService: RecommendationService

    @State private var sortOption: SortOption = .byScore
    @State private var selectedTopic: TopicMastery?

    // MARK: - Sort Options

    enum SortOption: String, CaseIterable {
        case byScore = "Score"
        case alphabetical = "A-Z"
        case byTrend = "Trend"
    }

    // MARK: - Sorted Topics

    private var sortedTopics: [TopicMastery] {
        switch sortOption {
        case .byScore:
            return topics.sorted { $0.score > $1.score }
        case .alphabetical:
            return topics.sorted { $0.topic.lowercased() < $1.topic.lowercased() }
        case .byTrend:
            return topics.sorted { trendPriority($0.trend) < trendPriority($1.trend) }
        }
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {

            // Sort options
            sortPicker

            // 2-column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.sm),
                GridItem(.flexible(), spacing: Spacing.sm)
            ], spacing: Spacing.sm) {
                ForEach(sortedTopics, id: \.topic) { topic in
                    topicCell(topic)
                        .onTapGesture {
                            selectedTopic = topic
                        }
                }
            }
        }
        .navigationDestination(item: $selectedTopic) { topic in
            TopicDetailView(
                topicName: topic.topic,
                knowledgeService: knowledgeService,
                recommendationService: recommendationService
            )
        }
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    withAnimation(Animations.quick) {
                        sortOption = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(Typography.caption)
                        .foregroundStyle(
                            sortOption == option
                                ? ColorTokens.textPrimaryDark
                                : ColorTokens.textTertiaryDark
                        )
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            sortOption == option
                                ? ColorTokens.primary.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    sortOption == option
                                        ? ColorTokens.primary.opacity(0.5)
                                        : ColorTokens.textTertiaryDark.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Topic Cell

    @ViewBuilder
    private func topicCell(_ topic: TopicMastery) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Topic name and score
            HStack {
                Text(topic.topic)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(topic.score))")
                    .font(Typography.mono)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.surfaceElevatedDark)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelGradient(for: topic.level))
                        .frame(width: geo.size.width * (topic.score / 100))
                }
            }
            .frame(height: 6)

            // Level badge and trend
            HStack(spacing: Spacing.xs) {
                levelBadge(topic.level)

                Spacer()

                trendIndicator(topic.trend)
            }
        }
        .padding(Spacing.sm)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Level Badge

    @ViewBuilder
    private func levelBadge(_ level: MasteryLevel) -> some View {
        Text(levelDisplayName(level))
            .font(Typography.micro)
            .foregroundStyle(levelColor(level))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(levelColor(level).opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Trend Indicator

    @ViewBuilder
    private func trendIndicator(_ trend: Trend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trendIconName(trend))
                .font(.system(size: 9, weight: .bold))
            Text(trend.rawValue.capitalized)
                .font(Typography.micro)
        }
        .foregroundStyle(trendColor(trend))
    }

    // MARK: - Helpers

    private func levelColor(_ level: MasteryLevel) -> Color {
        switch level {
        case .expert: return ColorTokens.anchorGold
        case .advanced: return ColorTokens.primary
        case .intermediate: return ColorTokens.info
        case .beginner: return ColorTokens.textSecondaryDark
        case .notStarted: return ColorTokens.textTertiaryDark
        }
    }

    private func levelDisplayName(_ level: MasteryLevel) -> String {
        switch level {
        case .notStarted: return "Not Started"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }

    private func levelGradient(for level: MasteryLevel) -> LinearGradient {
        let color = levelColor(level)
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func trendIconName(_ trend: Trend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .improving: return ColorTokens.success
        case .stable: return ColorTokens.textSecondaryDark
        case .declining: return ColorTokens.error
        }
    }

    private func trendPriority(_ trend: Trend) -> Int {
        switch trend {
        case .improving: return 0
        case .stable: return 1
        case .declining: return 2
        }
    }
}
