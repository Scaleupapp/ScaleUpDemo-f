import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AuthViewModel()
    @State private var showForgotPassword = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Text("Welcome back")
                            .font(Typography.displayMedium)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text("Sign in to continue your journey")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xl)

                    // Form
                    VStack(spacing: Spacing.md) {
                        ScaleUpTextField(
                            label: "Email",
                            icon: "envelope",
                            text: $viewModel.email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )

                        ScaleUpTextField(
                            label: "Password",
                            icon: "lock",
                            text: $viewModel.password,
                            isSecure: true,
                            autocapitalization: .never
                        )
                    }

                    // Forgot password
                    HStack {
                        Spacer()
                        Button("Forgot password?") {
                            showForgotPassword = true
                        }
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    // Sign In
                    PrimaryButton(
                        title: "Sign In",
                        isLoading: viewModel.isLoading,
                        isDisabled: !viewModel.isLoginValid
                    ) {
                        Task {
                            if let authData = await viewModel.login() {
                                await appState.handleAuthSuccess(authData)
                            }
                        }
                    }

                    Spacer().frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
    }

    // MARK: - Components

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
                .frame(width: 40, height: 40)
                .background(ColorTokens.surfaceElevated)
                .clipShape(Circle())
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(ColorTokens.error)
            Text(message)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.error)
            Spacer()
        }
        .padding(Spacing.sm)
        .background(ColorTokens.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}
