import SwiftUI

struct ScoreGauge: View {
    let score: Int // 0 to 100
    var size: CGFloat = 160
    var label: String?

    @State private var animatedScore: Double = 0

    private var scoreColor: Color {
        switch score {
        case 90...100: return ColorTokens.anchorGold
        case 70..<90: return ColorTokens.primary
        case 50..<70: return ColorTokens.info
        case 20..<50: return ColorTokens.warning
        default: return ColorTokens.error
        }
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        ColorTokens.surfaceElevatedDark,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))

                // Score arc
                Circle()
                    .trim(from: 0, to: animatedScore * 0.75)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))

                // Center content
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: size * 0.25, weight: .bold, design: .monospaced))
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    if let label {
                        Text(label)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.spring(duration: 1.2, bounce: 0.15)) {
                animatedScore = Double(score) / 100.0
            }
        }
    }
}
