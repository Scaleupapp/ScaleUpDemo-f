import SwiftUI

struct WelcomeCarouselView: View {
    @Environment(CoachMarkManager.self) private var coachMarkManager
    @State private var currentPage = 0
    @State private var isVisible = false

    let onComplete: () -> Void

    private struct Slide {
        let icon: String
        let title: String
        let subtitle: String
        let bullets: [(icon: String, text: String)]
    }

    private let slides: [Slide] = [
        Slide(
            icon: "arrow.triangle.2.circlepath",
            title: "The Learning Loop",
            subtitle: "Everything you do on ScaleUp feeds into a cycle that accelerates your growth.",
            bullets: [
                ("play.circle.fill", "Watch curated content on topics you care about"),
                ("brain.head.profile", "Take AI-generated quizzes to test retention"),
                ("chart.bar.fill", "Build a knowledge profile of your real skills"),
                ("sparkles", "Get smarter recommendations as ScaleUp learns you")
            ]
        ),
        Slide(
            icon: "square.grid.2x2.fill",
            title: "Your Command Centers",
            subtitle: "Five tabs, each serving a specific purpose in your journey.",
            bullets: [
                ("house.fill", "Home — Dashboard with score & recommendations"),
                ("safari.fill", "Discover — Browse content, creators & paths"),
                ("map.fill", "My Plan — AI-generated learning roadmap"),
                ("chart.bar.fill", "Progress — Knowledge profile & growth stats"),
                ("person.fill", "Profile — Account, objectives & saved content")
            ]
        ),
        Slide(
            icon: "rocket.fill",
            title: "Let's Get Started",
            subtitle: "Here's how to make the most of ScaleUp from day one.",
            bullets: [
                ("1.circle.fill", "Browse Discover to find content you like"),
                ("2.circle.fill", "Watch a video and try the AI Tutor"),
                ("3.circle.fill", "After 3+ lessons, a quiz unlocks automatically"),
                ("4.circle.fill", "Check Progress to see your knowledge grow")
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture {} // block taps through

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        Haptics.selection()
                        dismiss()
                    } label: {
                        Text("Skip Tour")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(ColorTokens.surfaceElevated.opacity(0.6))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

                Spacer()

                // Slides
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        slideView(slide)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots + CTA
                VStack(spacing: Spacing.lg) {
                    // Custom page dots
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? ColorTokens.gold : ColorTokens.textTertiary.opacity(0.4))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(Motion.springSnappy, value: currentPage)
                        }
                    }

                    // CTA
                    Button {
                        Haptics.medium()
                        if currentPage < slides.count - 1 {
                            withAnimation(Motion.springSmooth) {
                                currentPage += 1
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage < slides.count - 1 ? "Next" : "Start Exploring")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(ColorTokens.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.goldGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = true
            }
            Haptics.success()
        }
    }

    // MARK: - Slide

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: Spacing.lg) {
            // Icon with glow
            ZStack {
                RadialGradient(
                    colors: [ColorTokens.gold.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 80
                )
                .frame(width: 160, height: 160)

                Image(systemName: slide.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text(slide.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(slide.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, Spacing.md)

            // Bullets
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(slide.bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: bullet.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.gold)
                            .frame(width: 22)

                        Text(bullet.text)
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTokens.surface.opacity(0.5))
            )
            .padding(.horizontal, Spacing.md)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Dismiss

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            coachMarkManager.complete(.welcomeCarousel)
            onComplete()
        }
    }
}
