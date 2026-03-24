import SwiftUI

struct CompetitionStatsSection: View {
    let stats: CompetitionStats?
    let weeklyBoard: WeeklyLeaderboard?

    private let gold = Color(hex: 0xFFD700)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(gold)

                Text("Competition")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                NavigationLink(value: LeaderboardDestination()) {
                    HStack(spacing: 4) {
                        Text("Leaderboard")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(gold)
                }
            }

            // Stats row — clean grid
            if let stats = stats {
                HStack(spacing: 0) {
                    statItem(
                        icon: "flame.fill",
                        iconColor: .orange,
                        value: "\(stats.challengeStreak)",
                        label: "Streak"
                    )

                    divider

                    statItem(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        value: "\(stats.challengesThisWeek)",
                        label: "This Week"
                    )

                    divider

                    statItem(
                        icon: "target",
                        iconColor: gold,
                        value: "\(stats.todayCompleted)/\(stats.todayTotal)",
                        label: "Today"
                    )

                    if let percentile = stats.percentile {
                        divider

                        statItem(
                            icon: "chart.bar.fill",
                            iconColor: Color(hex: 0x8B5CF6),
                            value: "Top \(Int(percentile))%",
                            label: "Rank"
                        )
                    }
                }
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.surfaceElevated)
                )
            }

            // Mini leaderboard preview
            if let board = weeklyBoard, !board.entries.isEmpty {
                leaderboardPreview(board)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(gold.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Stat Item

    private func statItem(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(width: 1, height: 36)
    }

    // MARK: - Leaderboard Preview

    private func leaderboardPreview(_ board: WeeklyLeaderboard) -> some View {
        let topEntries = Array(
            board.entries
                .sorted { $0.totalHandicappedScore > $1.totalHandicappedScore }
                .prefix(3)
        )

        return VStack(spacing: 0) {
            ForEach(Array(topEntries.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: Spacing.sm) {
                    Text(rankEmoji(index + 1))
                        .font(.system(size: 14))
                        .frame(width: 22)

                    Circle()
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text(String(entry.userId.displayName.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ColorTokens.textSecondary)
                        )

                    Text(entry.userId.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(Int(entry.totalHandicappedScore))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(index == 0 ? gold : .white)
                }
                .padding(.vertical, 8)

                if index < topEntries.count - 1 {
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                }
            }

            // See Full Board
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)
                .padding(.top, 4)

            NavigationLink(value: LeaderboardDestination()) {
                HStack(spacing: 4) {
                    Text("See Full Board")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(gold)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
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
