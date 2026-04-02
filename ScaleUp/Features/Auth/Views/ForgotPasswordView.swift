import SwiftUI

/// Three-step forgot password flow: email → OTP → new password.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()
    @State private var step: Step = .email
    @State private var newPassword = ""
    @State private var successMessage: String?

    private enum Step { case email, otp, newPassword }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    contentSection

                    if let success = successMessage {
                        successBanner(success)
                    }
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    Spacer().frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    handleBack()
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
        .animation(.easeOut(duration: 0.3), value: step)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: stepIcon)
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.gold)
                .padding(.bottom, Spacing.xs)

            Text(stepTitle)
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(stepSubtitle)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.xl)
    }

    private var stepIcon: String {
        switch step {
        case .email: return "envelope.badge.shield.half.filled"
        case .otp: return "lock.shield"
        case .newPassword: return "key.fill"
        }
    }

    private var stepTitle: String {
        switch step {
        case .email: return "Forgot password?"
        case .otp: return "Check your email"
        case .newPassword: return "New password"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .email: return "Enter the email linked to your account and we'll send a reset code."
        case .otp: return "Enter the 6-digit code we sent to \(viewModel.email)"
        case .newPassword: return "Choose a strong password (at least 8 characters)."
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        switch step {
        case .email:
            emailStep
        case .otp:
            otpStep
        case .newPassword:
            newPasswordStep
        }
    }

    // MARK: - Step 1: Email

    private var emailStep: some View {
        VStack(spacing: Spacing.lg) {
            ScaleUpTextField(
                label: "Email",
                icon: "envelope",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            PrimaryButton(
                title: "Send Reset Code",
                icon: "arrow.right",
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.email.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                Task { await handleSendCode() }
            }
        }
    }

    // MARK: - Step 2: OTP

    private var otpStep: some View {
        VStack(spacing: Spacing.lg) {
            OTPInputView(code: $viewModel.otp)

            if viewModel.otpCooldown > 0 {
                Text("Resend in \(viewModel.otpCooldown)s")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            } else {
                Button("Resend Code") {
                    Task { await handleSendCode() }
                }
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.gold)
            }

            PrimaryButton(
                title: "Verify Code",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isOTPValid
            ) {
                viewModel.clearError()
                step = .newPassword
            }
        }
    }

    // MARK: - Step 3: New Password

    private var newPasswordStep: some View {
        VStack(spacing: Spacing.lg) {
            ScaleUpTextField(
                label: "New Password",
                icon: "lock",
                text: $newPassword,
                isSecure: true,
                autocapitalization: .never
            )

            Text("Must be at least 8 characters")
                .font(Typography.caption)
                .foregroundStyle(
                    newPassword.isEmpty
                        ? ColorTokens.textTertiary
                        : newPassword.count >= 8
                            ? ColorTokens.success
                            : ColorTokens.error
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryButton(
                title: "Reset Password",
                isLoading: viewModel.isLoading,
                isDisabled: newPassword.count < 8 || !viewModel.isOTPValid
            ) {
                Task { await handleResetPassword() }
            }
        }
    }

    // MARK: - Actions

    private func handleSendCode() async {
        viewModel.clearError()
        successMessage = nil
        viewModel.isLoading = true

        do {
            try await AuthService().forgotPassword(
                email: viewModel.email.trimmingCharacters(in: .whitespaces).lowercased()
            )
            viewModel.isLoading = false
            if step == .email {
                step = .otp
            }
            viewModel.startResendCooldown()
            Haptics.success()
        } catch let error as APIError {
            viewModel.errorMessage = error.errorDescription
            viewModel.isLoading = false
            Haptics.error()
        } catch {
            viewModel.errorMessage = "Failed to send reset code. Try again."
            viewModel.isLoading = false
            Haptics.error()
        }
    }

    private func handleResetPassword() async {
        viewModel.clearError()
        successMessage = nil
        viewModel.isLoading = true

        do {
            try await AuthService().resetPassword(
                email: viewModel.email.trimmingCharacters(in: .whitespaces).lowercased(),
                otp: viewModel.otp,
                newPassword: newPassword
            )
            viewModel.isLoading = false
            successMessage = "Password reset successfully. You can now sign in."
            Haptics.success()
            // Auto-dismiss after short delay
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch let error as APIError {
            viewModel.errorMessage = error.errorDescription
            viewModel.isLoading = false
            Haptics.error()
        } catch {
            viewModel.errorMessage = "Reset failed. Check your code and try again."
            viewModel.isLoading = false
            Haptics.error()
        }
    }

    private func handleBack() {
        switch step {
        case .email:
            dismiss()
        case .otp:
            step = .email
            viewModel.otp = ""
            viewModel.clearError()
        case .newPassword:
            step = .otp
            newPassword = ""
            viewModel.clearError()
        }
    }

    // MARK: - Banners

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.success)
            Text(message)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.success)
            Spacer()
        }
        .padding(Spacing.sm)
        .background(ColorTokens.success.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
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
