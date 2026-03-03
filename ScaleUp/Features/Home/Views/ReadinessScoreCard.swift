import SwiftUI

struct ReadinessScoreCard: View {
    let score: Int

    @State private var animatedScore: Double = 0

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Score ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(ColorTokens.surfaceElevated, lineWidth: 8)
                    .frame(width: 120, height: 120)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedScore / 100)
                    .stroke(
                        ColorTokens.goldGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Score number
                Text("\(score)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text("Learning Score")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Based on quizzes, content & consistency")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedScore = Double(score)
            }
        }
    }
}
