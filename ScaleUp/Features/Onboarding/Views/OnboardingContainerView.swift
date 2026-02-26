import SwiftUI

struct OnboardingContainerView: View {

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Progress Bar
                progressBar

                // MARK: - Header
                header
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)

                // MARK: - Step Content
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: - Bottom Actions
                if viewModel.currentStep < 6 {
                    bottomActions
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                }
            }
        }
        .preferredColorScheme(.dark)
        .loadingOverlay(isPresented: viewModel.isLoading, message: "Saving...")
        .alert("Something went wrong", isPresented: showErrorBinding) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
        .onAppear {
            viewModel.prepopulate(from: appState.currentUser)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(ColorTokens.surfaceElevatedDark)
                    .frame(height: 4)

                Rectangle()
                    .fill(ColorTokens.heroGradient)
                    .frame(width: geometry.size.width * viewModel.progress, height: 4)
                    .animation(Animations.smooth, value: viewModel.progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Back button for objective sub-pages
            if viewModel.currentStep == 3 && viewModel.objectiveSubPage > 1 {
                Button {
                    viewModel.goBackInObjective()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(Typography.bodySmall)
                    }
                    .foregroundStyle(ColorTokens.primary)
                }
                .padding(.bottom, Spacing.xs)
            }

            Text(viewModel.stepTitle)
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(viewModel.stepSubtitle)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Animations.standard, value: viewModel.currentStep)
        .animation(Animations.standard, value: viewModel.objectiveSubPage)
    }

    // MARK: - Step Content

    private var stepContent: some View {
        Group {
            switch viewModel.currentStep {
            case 1:
                ProfileSetupView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 2:
                BackgroundView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 3:
                ObjectiveSetupView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 4:
                PreferencesView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 5:
                InterestsView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 6:
                OnboardingCompleteView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            default:
                EmptyView()
            }
        }
        .animation(Animations.standard, value: viewModel.currentStep)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: Spacing.sm) {
            // Error inline
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Spacing.xs)
            }

            PrimaryButton(
                title: viewModel.continueButtonTitle,
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.canAdvance
            ) {
                Task {
                    await viewModel.nextStep(
                        onboardingService: dependencies.onboardingService,
                        authManager: dependencies.authManager,
                        appState: appState
                    )
                }
            }

            if viewModel.canSkip {
                Button {
                    Task {
                        await viewModel.skipStep(
                            onboardingService: dependencies.onboardingService,
                            authManager: dependencies.authManager,
                            appState: appState
                        )
                    }
                } label: {
                    Text("Skip for now")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
        }
    }

    // MARK: - Error Binding

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView()
        .environment(DependencyContainer())
        .environment(AppState())
}
