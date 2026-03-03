import SwiftUI

struct CompletionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var checkmarkScale: CGFloat = 0
    @State private var glowOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Gold glow
            ZStack {
                // Ambient glow
                RadialGradient(
                    colors: [ColorTokens.gold.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 160
                )
                .frame(width: 320, height: 320)
                .opacity(glowOpacity)

                // Checkmark circle
                ZStack {
                    Circle()
                        .fill(ColorTokens.gold.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(ColorTokens.gold, lineWidth: 3)
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .scaleEffect(checkmarkScale)
            }

            Spacer().frame(height: Spacing.xl)

            // Text
            VStack(spacing: Spacing.sm) {
                Text("You're all set!")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Your personalized learning\njourney begins now")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(textOpacity)

            Spacer().frame(height: Spacing.lg)

            // Summary
            if let objective = viewModel.selectedObjective {
                VStack(spacing: Spacing.sm) {
                    summaryRow(icon: "target", label: "Goal", value: objective.displayName)
                    summaryRow(icon: "clock.fill", label: "Pace", value: "\(Int(viewModel.weeklyHours)) hrs/week")
                    summaryRow(icon: "tag.fill", label: "Topics", value: "\(viewModel.selectedTopics.count) selected")
                }
                .padding(Spacing.md)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .padding(.horizontal, Spacing.lg)
                .opacity(textOpacity)
            }

            Spacer()

            // CTA
            PrimaryButton(title: "Start Learning", icon: "arrow.right", isLoading: viewModel.isLoading) {
                Task { await viewModel.completeOnboarding() }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
            .opacity(buttonOpacity)
        }
        .onAppear {
            // Checkmark bounce in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.1)) {
                checkmarkScale = 1
            }

            // Glow
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                glowOpacity = 1
            }

            // Text
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                textOpacity = 1
            }

            // Button
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                buttonOpacity = 1
            }

            Haptics.success()
        }
    }

    // MARK: - Summary Row

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 20)

            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()

            Text(value)
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }
}
