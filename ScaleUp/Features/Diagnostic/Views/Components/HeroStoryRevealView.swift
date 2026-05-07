import SwiftUI

struct HeroStoryRevealView: View {
    let heroSentence: String
    let surpriseSentence: String
    let planSentence: String
    let overallScore: Int
    var onDone: () -> Void

    @State private var page: Int = 0
    @State private var animatedMeter: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ColorTokens.background.ignoresSafeArea()

            TabView(selection: $page) {
                screen1.tag(0)
                screen2.tag(1)
                screen3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: page)

            HStack {
                dots
                Spacer()
                skipButton
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .onAppear {
            startAutoAdvance()
            if !reduceMotion {
                withAnimation(.easeOut(duration: 1.2)) {
                    animatedMeter = CGFloat(overallScore) / 100.0
                }
            } else {
                animatedMeter = CGFloat(overallScore) / 100.0
            }
        }
    }

    private var screen1: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text("Here's where you stand.")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.surfaceElevated).frame(height: 14)
                GeometryReader { geo in
                    Capsule().fill(ColorTokens.gold)
                        .frame(width: geo.size.width * animatedMeter, height: 14)
                }.frame(height: 14)
            }
            .frame(maxWidth: 280)
            Text(heroSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    private var screen2: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text("Here's what surprised us.")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text(surpriseSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    private var screen3: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text("Here's what we recommend.")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text(planSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Button(action: onDone) {
                Text("See my results")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(ColorTokens.gold))
            }
            .padding(.top, Spacing.md)
            Spacer()
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i == page ? ColorTokens.gold : ColorTokens.gold.opacity(0.25))
                    .frame(width: i == page ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: page)
            }
        }
    }

    private var skipButton: some View {
        Button(action: onDone) {
            Text("Skip")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(ColorTokens.surface.opacity(0.7)))
        }
    }

    private func startAutoAdvance() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { t in
            if page < 2 {
                withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
            } else {
                t.invalidate()
            }
        }
    }
}
