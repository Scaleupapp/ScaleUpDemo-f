import SwiftUI

struct RegisterView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Text("Create account")
                            .font(Typography.displayMedium)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text("Start your learning journey today")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xl)

                    // Form
                    VStack(spacing: Spacing.md) {
                        HStack(spacing: Spacing.sm) {
                            ScaleUpTextField(
                                label: "First Name",
                                icon: "person",
                                text: $viewModel.firstName,
                                autocapitalization: .words
                            )

                            ScaleUpTextField(
                                label: "Last Name",
                                icon: "person",
                                text: $viewModel.lastName,
                                autocapitalization: .words
                            )
                        }

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

                        // Password hint
                        Text("Must be at least 8 characters")
                            .font(Typography.caption)
                            .foregroundStyle(
                                viewModel.password.isEmpty
                                    ? ColorTokens.textTertiary
                                    : viewModel.password.count >= 8
                                        ? ColorTokens.success
                                        : ColorTokens.error
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    // Create Account
                    PrimaryButton(
                        title: "Create Account",
                        isLoading: viewModel.isLoading,
                        isDisabled: !viewModel.isRegisterValid
                    ) {
                        Task {
                            if let authData = await viewModel.register() {
                                await appState.handleAuthSuccess(authData)
                            }
                        }
                    }

                    // Terms
                    Text("By creating an account, you agree to our\nTerms of Service and Privacy Policy")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
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
