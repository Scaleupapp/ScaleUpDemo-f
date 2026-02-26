import SwiftUI

// MARK: - Forgot Password View Model

@Observable
@MainActor
final class ForgotPasswordViewModel {

    // MARK: - Step

    enum Step {
        case email
        case reset
    }

    // MARK: - Form Fields

    var email = ""
    var otp = ""
    var newPassword = ""

    // MARK: - State

    var step: Step = .email
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: - Field Errors

    var emailError: String?
    var otpError: String?
    var passwordError: String?

    // MARK: - Dependencies

    private let authService: AuthService
    private let hapticManager: HapticManager

    // MARK: - Init

    init(authService: AuthService, hapticManager: HapticManager) {
        self.authService = authService
        self.hapticManager = hapticManager
    }

    // MARK: - Send Reset OTP

    /// Validates the email and sends a password-reset OTP.
    func sendResetOTP() async {
        clearErrors()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedEmail.isEmpty else {
            emailError = "Email is required"
            hapticManager.warning()
            return
        }

        guard trimmedEmail.isValidEmail else {
            emailError = "Enter a valid email address"
            hapticManager.warning()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.forgotPassword(email: trimmedEmail)
            hapticManager.success()
            step = .reset
        } catch let error as APIError {
            errorMessage = error.errorDescription
            hapticManager.error()
        } catch {
            errorMessage = "Failed to send reset code. Please try again."
            hapticManager.error()
        }
    }

    // MARK: - Reset Password

    /// Validates the OTP and new password, then resets the password.
    func resetPassword() async {
        clearErrors()

        var isValid = true

        if otp.count != 6 {
            otpError = "Enter the 6-digit code"
            isValid = false
        }

        if newPassword.isEmpty {
            passwordError = "New password is required"
            isValid = false
        } else if newPassword.count < 8 {
            passwordError = "Password must be at least 8 characters"
            isValid = false
        }

        guard isValid else {
            hapticManager.warning()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            try await authService.resetPassword(
                email: trimmedEmail,
                otp: otp,
                newPassword: newPassword
            )
            hapticManager.success()
            successMessage = "Password reset successfully! You can now sign in with your new password."
        } catch let error as APIError {
            errorMessage = error.errorDescription
            hapticManager.error()
        } catch {
            errorMessage = "Failed to reset password. Please try again."
            hapticManager.error()
        }
    }

    // MARK: - Helpers

    private func clearErrors() {
        errorMessage = nil
        successMessage = nil
        emailError = nil
        otpError = nil
        passwordError = nil
    }
}
