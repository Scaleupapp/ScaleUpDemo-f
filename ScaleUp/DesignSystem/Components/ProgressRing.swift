import SwiftUI

struct ProgressRing: View {
    let score: Int
    let label: String
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10
    var showLabel: Bool = true
    var animated: Bool = true

    @State private var animatedScore: Double = 0

    private var scoreColor: Color {
        if score >= 70 { return ColorTokens.gold }
        if score >= 40 { return ColorTokens.info }
        return .orange
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.surfaceElevated, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: animatedScore / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: size * 0.28, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text("%")
                        .font(.system(size: size * 0.1, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .frame(width: size, height: size)

            if showLabel {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                    animatedScore = Double(score)
                }
            } else {
                animatedScore = Double(score)
            }
        }
    }
}
