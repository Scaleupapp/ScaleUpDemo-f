import SwiftUI

// MARK: - Learning Stats View

/// Detailed learning statistics view showing total hours, lessons, topics,
/// topic distribution visualization, and breakdown with affinity scores.
struct LearningStatsView: View {

    let stats: ProgressStats

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {

                    // Hero stat numbers
                    heroStats

                    // Topic distribution bar chart
                    if !stats.topicBreakdown.isEmpty {
                        topicDistributionSection
                    }

                    // Topic breakdown list
                    if !stats.topicBreakdown.isEmpty {
                        topicBreakdownList
                    }

                    // Dominant topics
                    if !stats.dominantTopics.isEmpty {
                        dominantTopicsSection
                    }

                    // Bottom spacing
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("Learning Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Hero Stats

    private var heroStats: some View {
        VStack(spacing: Spacing.md) {
            // Large time stat
            VStack(spacing: Spacing.xs) {
                Text(formattedTotalTime)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Total Learning Time")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(ColorTokens.surfaceDark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.primary.opacity(0.2), lineWidth: 1)
            )

            // Secondary stats row
            HStack(spacing: Spacing.sm) {
                heroStatCard(
                    icon: "book.closed.fill",
                    value: "\(stats.totalContentConsumed)",
                    label: "Lessons Completed",
                    color: ColorTokens.primary
                )

                heroStatCard(
                    icon: "sparkles",
                    value: "\(stats.topicCount)",
                    label: "Topics Explored",
                    color: ColorTokens.info
                )
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private func heroStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .cardStyle()
    }

    // MARK: - Topic Distribution Section

    private var topicDistributionSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Topic Distribution")

            // Segmented horizontal bar chart
            VStack(spacing: Spacing.sm) {
                segmentedBar

                // Legend
                legendView
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    private var segmentedBar: some View {
        GeometryReader { geo in
            let total = stats.topicBreakdown.reduce(0) { $0 + $1.contentConsumed }
            let barWidth = geo.size.width

            HStack(spacing: 2) {
                ForEach(Array(sortedBreakdown.enumerated()), id: \.element.topic) { index, breakdown in
                    let fraction = total > 0 ? Double(breakdown.contentConsumed) / Double(total) : 0
                    let segmentWidth = max(barWidth * fraction, 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(segmentColor(for: index))
                        .frame(width: segmentWidth, height: 28)
                }
            }
        }
        .frame(height: 28)
    }

    private var legendView: some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(Array(sortedBreakdown.prefix(8).enumerated()), id: \.element.topic) { index, breakdown in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(segmentColor(for: index))
                        .frame(width: 8, height: 8)

                    Text(breakdown.topic)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .lineLimit(1)

                    Text("\(breakdown.contentConsumed)")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
        }
    }

    // MARK: - Topic Breakdown List

    private var topicBreakdownList: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Topic Breakdown")

            VStack(spacing: Spacing.sm) {
                ForEach(Array(sortedBreakdown.enumerated()), id: \.element.topic) { index, breakdown in
                    topicBreakdownRow(breakdown: breakdown, index: index)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func topicBreakdownRow(breakdown: ProgressTopicBreakdown, index: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            // Color indicator
            Circle()
                .fill(segmentColor(for: index))
                .frame(width: 10, height: 10)

            // Topic name
            Text(breakdown.topic)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .lineLimit(1)

            Spacer()

            // Content consumed
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(breakdown.contentConsumed) lessons")
                    .font(Typography.mono)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                // Affinity score bar
                HStack(spacing: Spacing.xs) {
                    Text("Affinity")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    affinityBar(score: breakdown.affinityScore)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    @ViewBuilder
    private func affinityBar(score: Double) -> some View {
        let clampedScore = min(max(score, 0), 1)

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ColorTokens.surfaceElevatedDark)
                .frame(width: 60, height: 4)

            RoundedRectangle(cornerRadius: 2)
                .fill(affinityColor(score))
                .frame(width: 60 * clampedScore, height: 4)
        }
    }

    // MARK: - Dominant Topics Section

    private var dominantTopicsSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Your Dominant Topics")

            FlowLayout(spacing: Spacing.sm) {
                ForEach(stats.dominantTopics, id: \.self) { topic in
                    MilestoneChip(
                        icon: "star.fill",
                        title: topic,
                        isCompleted: true
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Helpers

    private var formattedTotalTime: String {
        let totalSecs = Int(stats.totalTimeSpent)
        let hours = totalSecs / 3600
        let minutes = (totalSecs % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var sortedBreakdown: [ProgressTopicBreakdown] {
        stats.topicBreakdown.sorted { $0.contentConsumed > $1.contentConsumed }
    }

    private func segmentColor(for index: Int) -> Color {
        let colors: [Color] = [
            ColorTokens.primary,
            ColorTokens.success,
            ColorTokens.info,
            ColorTokens.warning,
            ColorTokens.error,
            ColorTokens.anchorGold,
            ColorTokens.primaryLight,
            ColorTokens.coreSilver,
            ColorTokens.risingBronze,
            Color(hex: "#FD79A8")
        ]
        return colors[index % colors.count]
    }

    private func affinityColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return ColorTokens.success
        case 0.5..<0.8: return ColorTokens.info
        case 0.3..<0.5: return ColorTokens.warning
        default: return ColorTokens.error
        }
    }
}
