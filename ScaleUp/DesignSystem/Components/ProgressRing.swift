import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var showPercentage: Bool = true

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    ColorTokens.surfaceElevatedDark,
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ColorTokens.progressGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center text
            if showPercentage {
                Text("\(Int(progress * 100))")
                    .font(Typography.monoLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                animatedProgress = newValue
            }
        }
    }
}
