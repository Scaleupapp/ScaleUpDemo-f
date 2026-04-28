import SwiftUI

struct DiagnosticWelcomeView: View {
    let viewModel: DiagnosticViewModel
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.bottom, Spacing.xl)

            // Headline
            Text("Let's tune your plan to you")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.md)

            // Subhead
            Text("A 5-minute check-in to gauge where you are. We use this to skip what you already know and double down on gaps.")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)

            // Feature hints
            VStack(alignment: .leading, spacing: Spacing.md) {
                featureRow(
                    icon: "bolt.fill",
                    text: "Personalised questions based on your goal"
                )
                featureRow(
                    icon: "arrow.up.forward.circle.fill",
                    text: "Skip topics you already know"
                )
                featureRow(
                    icon: "target",
                    text: "We'll focus your plan on your real gaps"
                )
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)

            Spacer()

            // Buttons
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Start", isLoading: viewModel.isLoading) {
                    Task { await viewModel.start() }
                }

                SecondaryButton(title: "Skip for now") {
                    onSkip()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 24)

            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()
        }
    }
}
