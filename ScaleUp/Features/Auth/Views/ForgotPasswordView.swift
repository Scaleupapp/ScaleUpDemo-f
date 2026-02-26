import SwiftUI

// MARK: - Forgot Password View

/// Two-step flow: email input to receive reset code, then OTP + new password.
struct ForgotPasswordView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    // MARK: - Navigation

    let onBackToLogin: () -> Void

    // MARK: - State

    @State private var viewModel: ForgotPasswordViewModel?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView {
                if let vm = viewModel {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        // MARK: Header
                        headerSection(vm)

                        // MARK: Error Banner
                        if let errorMessage = vm.errorMessage {
                            errorBanner(errorMessage)
                        }

                        // MARK: Success Banner
                        if let successMessage = vm.successMessage {
                            successBanner(successMessage)
                        }

                        // MARK: Content
                        if vm.successMessage != nil {
                            // Show back-to-login after success
                            backToLoginButton
                        } else {
                            switch vm.step {
                            case .email:
                                emailStepSection(vm)
                            case .reset:
                                resetStepSection(vm)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ColorTokens.backgroundDark, for: .navigationBar)
        .loadingOverlay(isPresented: viewModel?.isLoading ?? false)
        .onAppear {
            if viewModel == nil {
                viewModel = ForgotPasswordViewModel(
                    authService: dependencies.authService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
    }

    // MARK: - Header

    private func headerSection(_ vm: ForgotPasswordViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(vm.step == .email ? "Forgot Password" : "Reset Password")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(vm.step == .email
                 ? "Enter your email and we'll send you a code to reset your password"
                 : "Enter the code from your email and choose a new password")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Email Step

    private func emailStepSection(_ vm: ForgotPasswordViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            TextFieldStyled(
                label: "Email",
                placeholder: "Enter your email",
                text: Binding(
                    get: { vm.email },
                    set: { vm.email = $0 }
                ),
                icon: "envelope.fill",
                errorMessage: vm.emailError,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never
            )

            PrimaryButton(
                title: "Send Reset Code",
                isLoading: vm.isLoading
            ) {
                Task { await vm.sendResetOTP() }
            }
        }
    }

    // MARK: - Reset Step

    private func resetStepSection(_ vm: ForgotPasswordViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Verification Code")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                OTPInputView(
                    otp: Binding(
                        get: { vm.otp },
                        set: { vm.otp = $0 }
                    ),
                    errorMessage: vm.otpError
                )
            }

            TextFieldStyled(
                label: "New Password",
                placeholder: "Create a new password (min 8 characters)",
                text: Binding(
                    get: { vm.newPassword },
                    set: { vm.newPassword = $0 }
                ),
                icon: "lock.fill",
                isSecure: true,
                errorMessage: vm.passwordError,
                textContentType: .newPassword
            )

            PrimaryButton(
                title: "Reset Password",
                isLoading: vm.isLoading,
                isDisabled: vm.otp.count != 6
            ) {
                Task { await vm.resetPassword() }
            }
        }
    }

    // MARK: - Back to Login

    private var backToLoginButton: some View {
        PrimaryButton(title: "Back to Sign In") {
            onBackToLogin()
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.error)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.error)
            Spacer()
        }
        .padding(Spacing.md)
        .background(ColorTokens.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Success Banner

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.success)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.success)
            Spacer()
        }
        .padding(Spacing.md)
        .background(ColorTokens.success.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}
