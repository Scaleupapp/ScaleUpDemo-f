import SwiftUI

// MARK: - Login View Model

@Observable
@MainActor
final class LoginViewModel {

    // MARK: - Form Fields

    var email = ""
    var password = ""

    // MARK: - State

    var isLoading = false
    var errorMessage: String?

    // MARK: - Field-Level Validation Errors

    var emailError: String?
    var passwordError: String?

    // MARK: - Dependencies

    private let authService: AuthService
    private let authManager: AuthManager
    private let hapticManager: HapticManager

    // MARK: - Init

    init(authService: AuthService, authManager: AuthManager, hapticManager: HapticManager) {
        self.authService = authService
        self.authManager = authManager
        self.hapticManager = hapticManager
    }

    // MARK: - Validation

    /// Validates all form fields and sets per-field error messages.
    /// - Returns: `true` if the form is valid.
    func validate() -> Bool {
        var isValid = true

        // Email
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if !email.isValidEmail {
            emailError = "Enter a valid email address"
            isValid = false
        } else {
            emailError = nil
        }

        // Password
        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        } else if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
            isValid = false
        } else {
            passwordError = nil
        }

        return isValid
    }

    // MARK: - Login

    /// Validates, calls the auth service, and transitions app state on success.
    func login(appState: AppState) async {
        clearErrors()

        guard validate() else {
            hapticManager.warning()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await authService.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password
            )

            authManager.handleAuthSuccess(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user
            )

            appState.currentUser = response.user
            hapticManager.success()

            if response.user.onboardingComplete {
                appState.authStatus = .authenticated
            } else {
                appState.authStatus = .onboarding
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
            hapticManager.error()
        } catch {
            errorMessage = "Something went wrong. Please try again."
            hapticManager.error()
        }
    }

    // MARK: - Helpers

    private func clearErrors() {
        errorMessage = nil
        emailError = nil
        passwordError = nil
    }
}
