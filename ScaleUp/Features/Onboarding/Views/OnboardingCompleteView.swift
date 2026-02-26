import SwiftUI

struct OnboardingCompleteView: View {

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // MARK: - Success Animation
            successCheckmark

            // MARK: - Title & Subtitle
            VStack(spacing: Spacing.sm) {
                Text("You're All Set!")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .opacity(viewModel.showCompletionAnimation ? 1 : 0)
                    .offset(y: viewModel.showCompletionAnimation ? 0 : 20)
                    .animation(Animations.smooth.delay(0.2), value: viewModel.showCompletionAnimation)

                Text("Your personalized learning path is ready")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .opacity(viewModel.showCompletionAnimation ? 1 : 0)
                    .offset(y: viewModel.showCompletionAnimation ? 0 : 20)
                    .animation(Animations.smooth.delay(0.3), value: viewModel.showCompletionAnimation)
            }

            // MARK: - Objective Summary Card
            if !viewModel.objectiveSummary.isEmpty {
                objectiveSummaryCard
                    .opacity(viewModel.showCompletionAnimation ? 1 : 0)
                    .offset(y: viewModel.showCompletionAnimation ? 0 : 20)
                    .animation(Animations.smooth.delay(0.4), value: viewModel.showCompletionAnimation)
            }

            Spacer()

            // MARK: - Start Learning Button
            PrimaryButton(
                title: "Start Learning",
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.nextStep(
                        onboardingService: dependencies.onboardingService,
                        authManager: dependencies.authManager,
                        appState: appState
                    )
                }
            }
            .opacity(viewModel.showCompletionAnimation ? 1 : 0)
            .offset(y: viewModel.showCompletionAnimation ? 0 : 20)
            .animation(Animations.smooth.delay(0.5), value: viewModel.showCompletionAnimation)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: - Success Checkmark

    private var successCheckmark: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    ColorTokens.primary.opacity(0.15),
                    lineWidth: 4
                )
                .frame(width: 120, height: 120)
                .scaleEffect(viewModel.showCompletionAnimation ? 1 : 0.5)
                .opacity(viewModel.showCompletionAnimation ? 1 : 0)
                .animation(Animations.spring.delay(0.1), value: viewModel.showCompletionAnimation)

            // Inner filled circle
            Circle()
                .fill(ColorTokens.primary.opacity(0.1))
                .frame(width: 100, height: 100)
                .scaleEffect(viewModel.showCompletionAnimation ? 1 : 0.3)
                .opacity(viewModel.showCompletionAnimation ? 1 : 0)
                .animation(Animations.spring, value: viewModel.showCompletionAnimation)

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.success)
                .scaleEffect(viewModel.showCompletionAnimation ? 1 : 0)
                .animation(Animations.spring.delay(0.15), value: viewModel.showCompletionAnimation)
        }
    }

    // MARK: - Objective Summary Card

    private var objectiveSummaryCard: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "target")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.primary)

                Text("Your Objective")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()
            }

            Text(viewModel.objectiveSummary)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Details row
            HStack(spacing: Spacing.lg) {
                if let timeline = viewModel.selectedTimeline {
                    summaryDetail(
                        icon: "calendar",
                        text: timelineDisplayText(timeline)
                    )
                }

                summaryDetail(
                    icon: "chart.bar.fill",
                    text: viewModel.currentLevel.rawValue.capitalized
                )

                summaryDetail(
                    icon: "clock.fill",
                    text: "\(Int(viewModel.weeklyCommitHours))h/week"
                )
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.primary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.lg)
    }

    private func summaryDetail(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Text(text)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    private func timelineDisplayText(_ timeline: Timeline) -> String {
        switch timeline {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        case .noDeadline: return "Flexible"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.backgroundDark.ignoresSafeArea()
        OnboardingCompleteView(viewModel: {
            let vm = OnboardingViewModel()
            vm.selectedObjectiveType = .upskilling
            vm.targetSkill = "Product Management"
            vm.selectedTimeline = .threeMonths
            vm.currentLevel = .intermediate
            vm.weeklyCommitHours = 10
            vm.showCompletionAnimation = true
            return vm
        }())
    }
    .environment(DependencyContainer())
    .environment(AppState())
    .preferredColorScheme(.dark)
}
