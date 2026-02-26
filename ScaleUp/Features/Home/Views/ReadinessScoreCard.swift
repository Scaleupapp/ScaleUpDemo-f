import SwiftUI

// MARK: - Readiness Score Card

struct ReadinessScoreCard: View {
    let score: Int

    var body: some View {
        VStack(spacing: Spacing.md) {
            ScoreGauge(
                score: score,
                size: 160,
                label: score >= 70 ? "Exam Readiness" : "Learning Score"
            )

            Text(scoreMessage)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.horizontal, Spacing.md)
    }

    private var scoreMessage: String {
        switch score {
        case 90...100:
            return "Outstanding! You are well-prepared."
        case 70..<90:
            return "Great progress! Keep pushing forward."
        case 50..<70:
            return "You are on the right track. Stay consistent."
        case 20..<50:
            return "Keep learning! Every session counts."
        default:
            return "Start your learning journey today."
        }
    }
}
