import SwiftUI

struct CompletionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var checkmarkScale: CGFloat = 0
    @State private var glowOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            mainContent
            if viewModel.isLoading {
                progressOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .alert("Couldn't finish setup", isPresented: errorBinding, actions: {
            Button("Try again") {
                Task { await viewModel.completeOnboarding() }
            }
            Button("Cancel", role: .cancel) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.isLoading },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RadialGradient(
                    colors: [ColorTokens.gold.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 160
                )
                .frame(width: 320, height: 320)
                .opacity(glowOpacity)

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

            VStack(spacing: Spacing.sm) {
                Text("You're all set!")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Take a short diagnostic so we can\ntailor your plan, or jump in now.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(textOpacity)

            Spacer().frame(height: Spacing.lg)

            if let objective = viewModel.selectedObjective {
                VStack(spacing: Spacing.sm) {
                    summaryRow(icon: "target", label: "Goal", value: objective.displayName)
                    summaryRow(icon: "clock.fill", label: "Pace", value: "\(Int(viewModel.weeklyHours)) hrs/week")
                    summaryRow(icon: "tag.fill", label: "Topics", value: "\(viewModel.totalSelectedCount) selected")
                }
                .padding(Spacing.md)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .padding(.horizontal, Spacing.lg)
                .opacity(textOpacity)
            }

            Spacer()

            // Primary: take the diagnostic (recommended, gold).
            // Secondary: skip to home — still completes onboarding on the server
            // so the user doesn't get sent back into the flow next launch.
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Start assessment", icon: "arrow.right", isLoading: false) {
                    Task { await viewModel.completeOnboarding() }
                }

                Button {
                    Task { await viewModel.completeOnboardingAndSkipDiagnostic() }
                } label: {
                    Text("Skip assessment for now")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
            .opacity(buttonOpacity)
            .disabled(viewModel.isLoading)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.1)) {
                checkmarkScale = 1
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) { glowOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) { textOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) { buttonOpacity = 1 }
            Haptics.success()
        }
    }

    // MARK: - Progress overlay

    /// Full-screen overlay shown while the onboarding submit is in flight.
    /// Crucial UX: without it the user taps the button, sees nothing change,
    /// and assumes the app is broken (see Build 116 feedback).
    private var progressOverlay: some View {
        ZStack {
            ColorTokens.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 4)
                        .frame(width: 64, height: 64)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.gold))
                        .scaleEffect(1.4)
                }
                VStack(spacing: 6) {
                    Text(viewModel.submitProgressMessage.isEmpty ? "Setting up…" : viewModel.submitProgressMessage)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("This usually takes a few seconds.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
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
