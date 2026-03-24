import SwiftUI

struct CompetitionStatsSection: View {
    let stats: CompetitionStats?
    let weeklyBoard: WeeklyLeaderboard?

    private let gold = Color(hex: 0xFFD700)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(gold)

                Text("Competition")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                NavigationLink(value: LeaderboardDestination()) {
                    HStack(spacing: 3) {
                        Text("Leaderboard")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(gold)
                }
            }

            // Compact stats strip
            if let stats = stats {
                HStack(spacing: 0) {
                    compactStat(
                        icon: "flame.fill",
                        iconColor: .orange,
                        value: "\(stats.challengeStreak)",
                        label: "Streak"
                    )

                    miniDivider

                    compactStat(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        value: "\(stats.challengesThisWeek)",
                        label: "This Week"
                    )

                    miniDivider

                    compactStat(
                        icon: "target",
                        iconColor: gold,
                        value: "\(stats.todayCompleted)/\(stats.todayTotal)",
                        label: "Today"
                    )

                    if let percentile = stats.percentile {
                        miniDivider

                        compactStat(
                            icon: "chart.bar.fill",
                            iconColor: Color(hex: 0x8B5CF6),
                            value: "Top \(Int(percentile))%",
                            label: "Rank"
                        )
                    }
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ColorTokens.surfaceElevated)
                )
            }

            // Mini leaderboard — top 3 inline
            if let board = weeklyBoard, !board.entries.isEmpty {
                miniLeaderboard(board)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gold.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Compact Stat

    private func compactStat(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(width: 1, height: 28)
    }

    // MARK: - Mini Leaderboard

    private func miniLeaderboard(_ board: WeeklyLeaderboard) -> some View {
        let topEntries = Array(
            board.entries
                .sorted { $0.totalHandicappedScore > $1.totalHandicappedScore }
                .prefix(3)
        )

        return VStack(spacing: 0) {
            ForEach(Array(topEntries.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 8) {
                    Text(rankEmoji(index + 1))
                        .font(.system(size: 13))
                        .frame(width: 20)

                    Circle()
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Text(String(entry.userId.displayName.prefix(1)).uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ColorTokens.textSecondary)
                        )

                    Text(entry.userId.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(Int(entry.totalHandicappedScore))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(index == 0 ? gold : .white)
                }
                .padding(.vertical, 6)

                if index < topEntries.count - 1 {
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTokens.surfaceElevated)
        )
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
