import SwiftUI

struct CompetitionStatsSection: View {
    let stats: CompetitionStats?
    let weeklyBoard: WeeklyLeaderboard?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.gold)

                Text("Competition")
                    .font(Typography.titleMedium)
                    .foregroundStyle(.white)

                Spacer()
            }

            // Stats chips — horizontal scroll
            if let stats = stats {
                statsChips(stats)
            }

            // Weekly leaderboard preview card
            if let board = weeklyBoard, !board.entries.isEmpty {
                leaderboardPreviewCard(board)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Stats Chips

    private func statsChips(_ stats: CompetitionStats) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                statChip(
                    icon: "\u{1F525}",
                    label: "Streak",
                    value: "\(stats.challengeStreak)",
                    highlight: stats.challengeStreak >= 3
                )

                if let percentile = stats.percentile {
                    statChip(
                        icon: "\u{1F4CA}",
                        label: "Percentile",
                        value: "Top \(Int(percentile))%",
                        highlight: percentile <= 25
                    )
                }

                statChip(
                    icon: "\u{2705}",
                    label: "This Week",
                    value: "\(stats.challengesThisWeek)",
                    highlight: false
                )

                statChip(
                    icon: "\u{1F3AF}",
                    label: "Today",
                    value: "\(stats.todayCompleted)/\(stats.todayTotal) done",
                    highlight: stats.todayCompleted >= stats.todayTotal && stats.todayTotal > 0
                )
            }
        }
    }

    private func statChip(icon: String, label: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 18))

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? ColorTokens.gold : .white)

            Text(label)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(width: 80)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(highlight ? ColorTokens.gold.opacity(0.08) : ColorTokens.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(highlight ? ColorTokens.gold.opacity(0.25) : Color.clear, lineWidth: 1)
                )
        )
    }

    // MARK: - Leaderboard Preview Card

    private func leaderboardPreviewCard(_ board: WeeklyLeaderboard) -> some View {
        VStack(spacing: Spacing.sm) {
            // Top 3 mini rows
            let topEntries = Array(
                board.entries
                    .sorted { $0.totalHandicappedScore > $1.totalHandicappedScore }
                    .prefix(3)
            )

            ForEach(Array(topEntries.enumerated()), id: \.element.id) { index, entry in
                miniLeaderboardRow(entry: entry, rank: index + 1)
            }

            // Divider
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 1)

            // See Full Board link
            NavigationLink(value: LeaderboardDestination()) {
                HStack(spacing: 4) {
                    Text("See Full Board")
                        .font(Typography.bodySmallBold)
                        .foregroundStyle(ColorTokens.gold)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surfaceElevated)
        )
    }

    // MARK: - Mini Leaderboard Row

    private func miniLeaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(rankEmoji(rank))
                .font(.system(size: 16))
                .frame(width: 24)

            Circle()
                .fill(ColorTokens.card)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(entry.userId.displayName.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                )

            Text(entry.userId.displayName)
                .font(Typography.bodySmall)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text("\(Int(entry.totalHandicappedScore))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(rank == 1 ? ColorTokens.gold : .white)
        }
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "\u{1F947}"
        case 2: return "\u{1F948}"
        case 3: return "\u{1F949}"
        default: return "\(rank)"
        }
    }
}

// MARK: - Navigation Destination

struct LeaderboardDestination: Hashable {}
