import SwiftUI

extension Notification.Name {
    static let dismissLiveEventSession = Notification.Name("dismissLiveEventSession")
}

struct LiveEventResultsView: View {
    let results: LiveEventResults
    let topic: String

    @State private var showScoreAnimation = false
    @State private var showDetails = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    private let purpleAccent = Color(red: 139.0/255.0, green: 92.0/255.0, blue: 246.0/255.0) // #8B5CF6
    private let correctColor = Color(red: 34.0/255.0, green: 197.0/255.0, blue: 94.0/255.0) // #22C55E

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    scoreHero
                    statsRow
                    leaderboardSection
                    actionButtons

                    Spacer().frame(height: Spacing.xxxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                showScoreAnimation = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                showDetails = true
            }
        }
    }

    // MARK: - Score Hero

    private var scoreHero: some View {
        VStack(spacing: Spacing.md) {
            Text("LIVE EVENT COMPLETE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(purpleAccent)

            // Animated score circle
            ZStack {
                Circle()
                    .stroke(purpleAccent.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: showScoreAnimation ? scoreProgress : 0)
                    .stroke(
                        purpleAccent,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.4), value: showScoreAnimation)

                Circle()
                    .fill(ColorTokens.surface)
                    .frame(width: 130, height: 130)

                VStack(spacing: 2) {
                    Text("\(Int(results.attempt?.handicappedScore ?? 0))")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(purpleAccent)

                    Text("SCORE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .scaleEffect(showScoreAnimation ? 1.0 : 0.5)
                .opacity(showScoreAnimation ? 1.0 : 0)
            }

            Text(topic)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(Int(results.attempt?.handicappedScore ?? 0))",
                label: "Score",
                color: purpleAccent
            )
            statCard(
                value: "#\(results.attempt?.rank ?? 0)",
                label: "Rank",
                color: .cyan
            )
            statCard(
                value: formattedTime(results.attempt?.timeTaken ?? 0),
                label: "Time",
                color: correctColor
            )
        }
        .opacity(showDetails ? 1 : 0)
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("LEADERBOARD")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(purpleAccent)

            VStack(spacing: 0) {
                ForEach(results.event.leaderboard) { entry in
                    leaderboardRow(entry: entry)

                    if entry.id != results.event.leaderboard.last?.id {
                        Divider()
                            .background(ColorTokens.border)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTokens.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .opacity(showDetails ? 1 : 0)
    }

    private func leaderboardRow(entry: LiveLeaderboardEntry) -> some View {
        let isCurrentUser = entry.id == results.attempt.map({ _ in entry.id }) // Highlight by rank match
        let isTop3 = entry.rank <= 3

        return HStack(spacing: 12) {
            // Rank
            if entry.rank == 1 {
                Text("\u{1F947}")
                    .font(.system(size: 18))
                    .frame(width: 30)
            } else if entry.rank == 2 {
                Text("\u{1F948}")
                    .font(.system(size: 18))
                    .frame(width: 30)
            } else if entry.rank == 3 {
                Text("\u{1F949}")
                    .font(.system(size: 18))
                    .frame(width: 30)
            } else {
                Text("#\(entry.rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 30)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.userId.displayName)
                        .font(.system(size: 14, weight: isTop3 ? .bold : .medium))
                        .foregroundStyle(.white)

                    if entry.rank == results.attempt?.rank {
                        Text("You")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(purpleAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(purpleAccent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Score
            Text("\(Int(entry.handicappedScore))")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isTop3 ? purpleAccent : ColorTokens.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 12)
        .background(
            entry.rank == results.attempt?.rank
                ? purpleAccent.opacity(0.08)
                : Color.clear
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Share Live Results
            Button {
                Haptics.medium()
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share Live Results")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(purpleAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Done
            Button {
                NotificationCenter.default.post(name: .dismissLiveEventSession, object: nil)
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .opacity(showDetails ? 1 : 0)
    }

    // MARK: - Helpers

    private var scoreProgress: Double {
        min(1.0, max(0, (results.attempt?.handicappedScore ?? 0) / 100.0))
    }

    private func formattedTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
