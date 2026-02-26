import SwiftUI

// MARK: - Register View Model

@Observable
@MainActor
final class RegisterViewModel {

    // MARK: - Form Fields

    var firstName = ""
    var lastName = ""
    var email = ""
    var password = ""

    // MARK: - State

    var isLoading = false
    var errorMessage: String?

    // MARK: - Field-Level Validation Errors

    var firstNameError: String?
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

        // First Name
        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            firstNameError = "First name is required"
            isValid = false
        } else {
            firstNameError = nil
        }

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

    // MARK: - Register

    /// Validates, creates the account, and transitions to onboarding on success.
    func register(appState: AppState) async {
        clearErrors()

        guard validate() else {
            hapticManager.warning()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await authService.register(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            authManager.handleAuthSuccess(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user
            )

            appState.currentUser = response.user
            hapticManager.success()

            // New registrations always go to onboarding
            appState.authStatus = .onboarding
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
        firstNameError = nil
        emailError = nil
        passwordError = nil
    }
}
