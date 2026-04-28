import SwiftUI

struct DiagnosticWelcomeView: View {
    let viewModel: DiagnosticViewModel
    let onSkip: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero icon with animated pulse ring
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(ColorTokens.gold.opacity(isPulsing ? 0.0 : 0.18), lineWidth: 2)
                    .frame(width: isPulsing ? 180 : 155, height: isPulsing ? 180 : 155)
                    .animation(
                        .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                        value: isPulsing
                    )

                // Inner glow circle
                Circle()
                    .fill(ColorTokens.gold.opacity(0.14))
                    .frame(width: 140, height: 140)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.bottom, Spacing.xl)
            .onAppear { isPulsing = true }

            // Headline
            Text("Let's tune your plan to you")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.sm)

            // Subhead
            Text("A quick check-in to gauge where you are. We use this to skip what you know and double down on your real gaps.")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)

            // Value-prop cards
            VStack(spacing: Spacing.sm) {
                valuePropCard(
                    icon: "bolt.fill",
                    title: "Personalised to your goal",
                    body: "Questions adapt to what you're here to learn"
                )
                valuePropCard(
                    icon: "arrow.up.forward.circle.fill",
                    title: "Skip what you already know",
                    body: "We calibrate so you never waste time on basics"
                )
                valuePropCard(
                    icon: "target",
                    title: "Focus on your real gaps",
                    body: "Your learning plan gets built around your results"
                )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)

            Spacer()

            // Buttons
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Start Diagnostic", isLoading: viewModel.isLoading) {
                    Task { await viewModel.start() }
                }

                SecondaryButton(title: "Skip for now") {
                    onSkip()
                }
            }
            .padding(.horizontal, Spacing.lg)

            // Trust line
            Text("Takes 5 min  ·  Personalises your plan  ·  Retake anytime")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Value Prop Card

    private func valuePropCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(ColorTokens.gold.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(body)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
        )
    }
}
