import SwiftUI

struct ChallengeResultsView: View {
    let result: ChallengeResult
    let topic: String
    let challengeId: String

    @State private var showScoreAnimation = false
    @State private var showDetails = false
    @State private var showShareSheet = false
    @State private var navigateToLeaderboard = false
    @Environment(\.dismiss) private var dismiss

    private let goldColor = Color(red: 1, green: 215.0/255.0, blue: 0) // #FFD700
    private let correctColor = Color(red: 34.0/255.0, green: 197.0/255.0, blue: 94.0/255.0) // #22C55E

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    scoreHero
                    personalBestBadge
                    statsRow
                    previousBestComparison
                    actionButtons

                    Spacer().frame(height: Spacing.xxxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToLeaderboard) {
            // LeaderboardView will be created separately
            EmptyView()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareScoreCardView(
                result: result,
                topic: topic
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
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
            Text("CHALLENGE COMPLETE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(goldColor)

            // Animated score circle
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(goldColor.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: showScoreAnimation ? scoreProgress : 0)
                    .stroke(
                        goldColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.4), value: showScoreAnimation)

                // Inner dark circle
                Circle()
                    .fill(ColorTokens.surface)
                    .frame(width: 130, height: 130)

                VStack(spacing: 2) {
                    Text("\(Int(result.handicappedScore))")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(goldColor)

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

    // MARK: - Personal Best Badge

    @ViewBuilder
    private var personalBestBadge: some View {
        if result.isPersonalBest {
            HStack(spacing: 6) {
                Text("\u{1F3C6}")
                    .font(.system(size: 16))
                Text("New Best!")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(goldColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(goldColor.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(goldColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(showScoreAnimation ? 1.0 : 0.8)
            .opacity(showScoreAnimation ? 1.0 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(1.0), value: showScoreAnimation)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(Int(result.handicappedScore))",
                label: "Score",
                color: goldColor
            )
            statCard(
                value: "\(result.correct)/\(result.total)",
                label: "Accuracy",
                color: correctColor
            )
            statCard(
                value: formattedTime(result.timeTaken),
                label: "Time",
                color: .cyan
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

    // MARK: - Previous Best Comparison

    @ViewBuilder
    private var previousBestComparison: some View {
        if result.previousBest > 0 {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Previous Best")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(Int(result.previousBest))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                // Difference indicator
                let diff = result.handicappedScore - result.previousBest
                HStack(spacing: 4) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(diff >= 0 ? "+\(Int(diff))" : "\(Int(diff))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(diff >= 0 ? correctColor : .red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background((diff >= 0 ? correctColor : .red).opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTokens.surface)
            )
            .opacity(showDetails ? 1 : 0)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Share Score
            Button {
                Haptics.medium()
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share Score")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(goldColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // View Leaderboard
            Button {
                Haptics.selection()
                navigateToLeaderboard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.number")
                        .font(.system(size: 14, weight: .semibold))
                    Text("View Leaderboard")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(goldColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(goldColor, lineWidth: 1.5)
                )
            }

            // Done
            Button {
                NotificationCenter.default.post(name: .dismissChallengeSession, object: nil)
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
        // Normalize score to 0-1 range (assume max score ~100)
        min(1.0, max(0, result.handicappedScore / 100.0))
    }

    private func formattedTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
