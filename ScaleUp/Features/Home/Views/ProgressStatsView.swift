import SwiftUI

// MARK: - Progress Stats View

/// A reusable stats summary component displaying the user's aggregate
/// learning progress. Designed for use in the Home tab hero area and
/// a dedicated Progress tab.
///
/// Layout:
/// 1. Three large stat cards ("X hours learned", "Y lessons", "Z topics")
/// 2. A horizontal bar chart breaking down the top topics by affinity.
struct ProgressStatsView: View {
    let stats: ProgressStats

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // MARK: - Stat Cards
            statCardsRow

            // MARK: - Topic Breakdown
            if !stats.topicBreakdown.isEmpty {
                topicBreakdownSection
            }
        }
        .cardStyle()
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Stat Cards Row

    private var statCardsRow: some View {
        HStack(spacing: Spacing.sm) {
            StatCard(
                value: formattedHours,
                label: "Hours Learned",
                icon: "clock.fill",
                accentColor: ColorTokens.primary
            )

            StatCard(
                value: "\(stats.totalContentConsumed)",
                label: "Lessons Completed",
                icon: "checkmark.circle.fill",
                accentColor: ColorTokens.success
            )

            StatCard(
                value: "\(stats.topicCount)",
                label: "Topics Explored",
                icon: "sparkles",
                accentColor: ColorTokens.warning
            )
        }
    }

    // MARK: - Topic Breakdown Section

    private var topicBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Topic Breakdown")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            // Show the top topics sorted by affinity score
            let sortedTopics = stats.topicBreakdown
                .sorted { $0.affinityScore > $1.affinityScore }
                .prefix(5)

            ForEach(Array(sortedTopics.enumerated()), id: \.offset) { index, topic in
                TopicBarRow(
                    topic: topic,
                    maxAffinity: sortedTopics.first?.affinityScore ?? 1.0,
                    barColor: barColor(for: index)
                )
            }
        }
    }

    // MARK: - Helpers

    /// Converts total time spent (seconds) into a readable hours string.
    private var formattedHours: String {
        let totalSecs = Int(stats.totalTimeSpent)
        let hours = totalSecs / 3600
        let minutes = (totalSecs % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours).\(minutes / 6)" // single decimal
        } else if hours > 0 {
            return "\(hours)"
        } else {
            return "\(minutes)m"
        }
    }

    /// Returns a distinct color for each topic bar based on index.
    private func barColor(for index: Int) -> Color {
        let colors: [Color] = [
            ColorTokens.primary,
            ColorTokens.success,
            ColorTokens.info,
            ColorTokens.warning,
            ColorTokens.primaryLight,
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Stat Card

/// A single stat tile displaying a large number, a label, and a small icon.
private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(accentColor)

            // Value
            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            // Label
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceElevatedDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}

// MARK: - Topic Bar Row

/// A single row in the topic breakdown, consisting of a topic name,
/// a horizontal bar proportional to its affinity score, and the
/// content consumed count.
private struct TopicBarRow: View {
    let topic: ProgressTopicBreakdown
    let maxAffinity: Double
    let barColor: Color

    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Label row
            HStack {
                Text(topic.topic)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(1)

                Spacer()

                Text("\(topic.contentConsumed) lessons")
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.surfaceElevatedDark)
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: animatedWidth, height: 6)
                }
                .onAppear {
                    let fraction = maxAffinity > 0
                        ? topic.affinityScore / maxAffinity
                        : 0
                    withAnimation(.spring(duration: 0.8, bounce: 0.15).delay(Double.random(in: 0...0.2))) {
                        animatedWidth = geo.size.width * CGFloat(fraction)
                    }
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Compact Progress Stats

/// A smaller variant of `ProgressStatsView` intended for inline usage
/// (e.g. within a dashboard card that needs fewer details).
struct CompactProgressStats: View {
    let stats: ProgressStats

    var body: some View {
        HStack(spacing: Spacing.lg) {
            CompactStatItem(
                value: "\(Int(stats.totalTimeSpent) / 3600)",
                unit: "hrs",
                label: "Learned"
            )

            Divider()
                .frame(height: 36)
                .background(ColorTokens.surfaceElevatedDark)

            CompactStatItem(
                value: "\(stats.totalContentConsumed)",
                unit: "",
                label: "Lessons"
            )

            Divider()
                .frame(height: 36)
                .background(ColorTokens.surfaceElevatedDark)

            CompactStatItem(
                value: "\(stats.topicCount)",
                unit: "",
                label: "Topics"
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Stat Item

private struct CompactStatItem: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Typography.monoLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                if !unit.isEmpty {
                    Text(unit)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }

            Text(label)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("Full Stats") {
    ScrollView {
        ProgressStatsView(
            stats: ProgressStats(
                totalContentConsumed: 42,
                totalTimeSpent: 18720.0,
                dominantTopics: ["Swift", "SwiftUI", "Combine"],
                topicCount: 7,
                topicBreakdown: [
                    ProgressTopicBreakdown(topic: "Swift", contentConsumed: 15, affinityScore: 0.92),
                    ProgressTopicBreakdown(topic: "SwiftUI", contentConsumed: 12, affinityScore: 0.85),
                    ProgressTopicBreakdown(topic: "Combine", contentConsumed: 8, affinityScore: 0.65),
                    ProgressTopicBreakdown(topic: "Core Data", contentConsumed: 4, affinityScore: 0.40),
                    ProgressTopicBreakdown(topic: "Networking", contentConsumed: 3, affinityScore: 0.30),
                ]
            )
        )
    }
    .background(ColorTokens.backgroundDark)
    .preferredColorScheme(.dark)
}

#Preview("Compact Stats") {
    CompactProgressStats(
        stats: ProgressStats(
            totalContentConsumed: 42,
            totalTimeSpent: 18720.0,
            dominantTopics: ["Swift", "SwiftUI"],
            topicCount: 5,
            topicBreakdown: []
        )
    )
    .cardStyle()
    .padding()
    .background(ColorTokens.backgroundDark)
    .preferredColorScheme(.dark)
}
