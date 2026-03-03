import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: OnboardingViewModel

    init(initialStep: Int, appState: AppState) {
        _viewModel = State(initialValue: OnboardingViewModel(initialStep: initialStep, appState: appState))
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.currentStep < 6 {
                    headerSection
                }

                // Step Content
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.currentStep < 6 {
                    bottomBar
                }
            }
        }
        .animation(Motion.springSmooth, value: viewModel.currentStep)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            // Progress segments
            HStack(spacing: 4) {
                ForEach(1...6, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(step <= viewModel.currentStep ? AnyShapeStyle(ColorTokens.goldGradient) : AnyShapeStyle(ColorTokens.surfaceElevated))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            Text("Step \(viewModel.currentStep) of 6")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch viewModel.currentStep {
            case 1: ProfileStepView(viewModel: viewModel)
            case 2: BackgroundStepView(viewModel: viewModel)
            case 3: ObjectiveStepView(viewModel: viewModel)
            case 4: PreferencesStepView(viewModel: viewModel)
            case 5: InterestsStepView(viewModel: viewModel)
            case 6: CompletionStepView(viewModel: viewModel)
            default: EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: viewModel.isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: viewModel.isMovingForward ? .leading : .trailing).combined(with: .opacity)
        ))
        .id(viewModel.currentStep)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Back button
            if viewModel.currentStep > 1 {
                Button {
                    viewModel.back()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                }
            }

            Spacer()

            // Skip (for optional steps)
            if viewModel.isOptionalStep {
                Button {
                    Task { await viewModel.skip() }
                } label: {
                    Text("Skip")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.trailing, Spacing.md)
            }

            // Continue button
            Button {
                Task { await viewModel.next() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(ColorTokens.buttonPrimaryText)
                            .scaleEffect(0.8)
                    } else {
                        Text("Continue")
                            .font(Typography.bodyBold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(viewModel.canProceed ? ColorTokens.buttonPrimaryText : ColorTokens.buttonDisabledText)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 14)
                .background(
                    viewModel.canProceed
                        ? AnyShapeStyle(ColorTokens.goldGradient)
                        : AnyShapeStyle(ColorTokens.buttonDisabledBg)
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .disabled(!viewModel.canProceed || viewModel.isLoading)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(ColorTokens.surface)
    }
}
