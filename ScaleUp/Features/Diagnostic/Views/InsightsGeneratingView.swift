import SwiftUI

struct InsightsGeneratingView: View {
    /// Parent passes `true` when insights JSON is loaded; we crossfade out.
    var isReady: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stageIndex: Int = 0
    @State private var factIndex: Int = 0
    @State private var ringRotation: Double = 0
    @State private var iconScale: CGFloat = 1.0
    @State private var barHeights: [CGFloat] = [0.2, 0.35, 0.5]
    @State private var elapsedSec: Double = 0
    @State private var timer: Timer?

    private let stages: [String] = [
        "Analyzing your answers…",
        "Comparing your self-rating to actual performance…",
        "Generating personalized insights…",
    ]

    private let facts: [String] = [
        "Most learners discover one major blind spot in their first calibration.",
        "People who get calibrated learn 2-3x faster than those who don't.",
        "The biggest gains come from the topics you didn't expect to struggle with.",
    ]

    private let factIcons: [String] = [
        "lightbulb.fill",
        "chart.line.uptrend.xyaxis",
        "sparkles",
    ]

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            backgroundBarHint
                .opacity(0.18)

            VStack(spacing: 0) {
                Spacer()
                haloIcon
                    .padding(.bottom, Spacing.xl)

                Text(stages[stageIndex])
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .id(stageIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                Text("Usually ~10 seconds")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.bottom, Spacing.xxl)

                factCard
                    .padding(.horizontal, Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)

                factDots
                    .padding(.top, Spacing.md)

                Spacer()
            }
        }
        .opacity(isReady ? 0 : 1)
        .animation(.easeInOut(duration: 0.45), value: isReady)
        .onAppear { startAnimations() }
        .onDisappear { stopTimer() }
    }

    private var haloIcon: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [ColorTokens.gold, ColorTokens.gold.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(ringRotation))

            Circle()
                .fill(ColorTokens.gold.opacity(0.12))
                .frame(width: 110, height: 110)

            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .scaleEffect(iconScale)
        }
    }

    private var factCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: factIcons[factIndex])
                .foregroundStyle(ColorTokens.gold)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Did you know")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .tracking(0.6)
                Text(facts[factIndex])
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineSpacing(3)
            }
        }
        .id(factIndex)
        .transition(.opacity)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private var factDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<facts.count, id: \.self) { i in
                Circle()
                    .fill(i == factIndex ? ColorTokens.gold : ColorTokens.gold.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var backgroundBarHint: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<barHeights.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.gold)
                        .frame(width: 36, height: 80 * barHeights[i])
                }
            }
            .padding(.bottom, 80)
        }
    }

    private func startAnimations() {
        if !reduceMotion {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                iconScale = 1.1
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            elapsedSec += 0.5

            let newStage: Int = {
                if elapsedSec < 3 { return 0 }
                if elapsedSec < 7 { return 1 }
                return 2
            }()
            if newStage != stageIndex {
                withAnimation(.easeInOut(duration: 0.3)) { stageIndex = newStage }
            }

            if Int(elapsedSec * 2) % 10 == 0 && elapsedSec > 0 {
                withAnimation(.easeInOut(duration: 0.4)) {
                    factIndex = (factIndex + 1) % facts.count
                }
            }

            if !reduceMotion {
                let progress = min(1.0, elapsedSec / 12.0)
                withAnimation(.easeOut(duration: 0.5)) {
                    barHeights = [
                        0.3 + 0.6 * CGFloat(progress) * 0.5,
                        0.5 + 0.4 * CGFloat(progress),
                        0.4 + 0.5 * CGFloat(progress) * 0.8,
                    ]
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    InsightsGeneratingView(isReady: false)
        .background(ColorTokens.background)
}
