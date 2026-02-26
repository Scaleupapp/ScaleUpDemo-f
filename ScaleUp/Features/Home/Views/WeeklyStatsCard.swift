import SwiftUI

// MARK: - Weekly Stats Card

struct WeeklyStatsCard: View {
    let stats: WeeklyStats

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.primary)

                Text("This Week")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()
            }

            // Stats row
            HStack(spacing: Spacing.lg) {
                WeeklyStatItem(
                    value: "\(stats.contentConsumed)",
                    label: "Lessons Completed"
                )

                Divider()
                    .frame(height: 40)
                    .background(ColorTokens.surfaceElevatedDark)

                WeeklyStatItem(
                    value: "\(stats.dominantTopics.count)",
                    label: "Topics Explored"
                )
            }

            // Topics explored
            if !stats.dominantTopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(stats.dominantTopics, id: \.self) { topic in
                            Text(topic)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.primary)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(ColorTokens.primary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .cardStyle()
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Weekly Stat Item

private struct WeeklyStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
    }
}
