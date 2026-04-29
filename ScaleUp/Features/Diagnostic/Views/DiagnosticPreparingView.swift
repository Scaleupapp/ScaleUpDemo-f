import SwiftUI

struct DiagnosticPreparingView: View {
    @State private var ringRotation: Double = 0
    @State private var iconScale: CGFloat = 1.0
    @State private var factIndex: Int = 0

    private let facts: [String] = [
        "Most learners overrate themselves on familiar topics — and underrate themselves on the ones that matter.",
        "Research shows 5 minutes of self-assessment improves study efficiency by ~40%.",
        "We're picking the right difficulty per topic so you don't waste time on what you already know.",
        "Calibration — knowing what you don't know — is the #1 predictor of learning speed.",
        "Top performers retake this kind of check-in every 3-4 weeks to stay on target.",
        "Your answers stay private. We use them to shape your plan, not to grade you.",
        "Spaced practice + adaptive difficulty = the fastest known way to learn.",
    ]

    private let factIcons: [String] = [
        "lightbulb.fill",
        "sparkles",
        "chart.line.uptrend.xyaxis",
        "target",
        "clock.arrow.circlepath",
        "lock.shield.fill",
        "brain.head.profile",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            haloIcon
                .padding(.bottom, Spacing.xl)

            Text("Tailoring your assessment")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.sm)

            Text("Picking the right questions just for you…")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.xxl)

            factCard
                .padding(.horizontal, Spacing.lg)
                .fixedSize(horizontal: false, vertical: true)

            factDots
                .padding(.top, Spacing.md)

            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                iconScale = 1.1
            }
            startFactRotation()
        }
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

            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .scaleEffect(iconScale)
        }
    }

    private var factCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: factIcons[factIndex])
                    .foregroundStyle(ColorTokens.gold)
                    .font(.system(size: 13, weight: .semibold))
                Text("Did you know")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .tracking(0.6)
            }
            Text(facts[factIndex])
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(factIndex)
        .transition(.opacity)
        .padding(Spacing.md)
        .padding(.leading, 4) // room for the accent bar
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.gold)
                .frame(width: 3)
                .frame(maxHeight: .infinity, alignment: .leading),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .animation(.easeInOut(duration: 0.5), value: factIndex)
    }

    private var factDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<facts.count, id: \.self) { i in
                Circle()
                    .fill(i == factIndex ? ColorTokens.gold : ColorTokens.gold.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: factIndex)
            }
        }
    }

    private func startFactRotation() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                await MainActor.run { factIndex = (factIndex + 1) % facts.count }
            }
        }
    }
}
