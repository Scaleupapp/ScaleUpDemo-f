import SwiftUI

// MARK: - Phone OTP View Model

@Observable
@MainActor
final class PhoneOTPViewModel {

    // MARK: - Step

    enum Step {
        case phone
        case otp
    }

    // MARK: - Form Fields

    var phone = ""
    var otp = ""
    var firstName = ""
    var lastName = ""

    // MARK: - State

    var step: Step = .phone
    var isLoading = false
    var errorMessage: String?
    var isNewUser = false
    var showNameInput = false
    var countdownSeconds = 0

    // MARK: - Field Errors

    var phoneError: String?
    var otpError: String?
    var firstNameError: String?

    // MARK: - Dependencies

    private let authService: AuthService
    private let authManager: AuthManager
    private let hapticManager: HapticManager

    // MARK: - Timer

    nonisolated(unsafe) private var countdownTask: Task<Void, Never>?

    // MARK: - Init

    init(authService: AuthService, authManager: AuthManager, hapticManager: HapticManager) {
        self.authService = authService
        self.authManager = authManager
        self.hapticManager = hapticManager
    }

    deinit {
        countdownTask?.cancel()
    }

    // MARK: - Send OTP

    /// Validates the phone number and sends an OTP.
    func sendOTP() async {
        clearErrors()

        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else {
            phoneError = "Phone number is required"
            hapticManager.warning()
            return
        }

        guard trimmedPhone.isValidPhone else {
            phoneError = "Enter a valid 10-digit phone number"
            hapticManager.warning()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.sendPhoneOTP(phone: trimmedPhone.formattedPhone)
            hapticManager.success()
            step = .otp
            startCountdown()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            hapticManager.error()
        } catch {
            errorMessage = "Failed to send OTP. Please try again."
            hapticManager.error()
        }
    }

    // MARK: - Verify OTP

    /// Verifies the OTP. If `isNewUser`, prompts for name before completing.
    func verifyOTP(appState: AppState) async {
        clearErrors()

        guard otp.count == 6 else {
            otpError = "Enter the 6-digit OTP"
            hapticManager.warning()
            return
        }

        // If we need the name and it's showing, validate it
        if showNameInput {
            guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                firstNameError = "First name is required"
                hapticManager.warning()
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let response = try await authService.verifyPhoneOTP(
                phone: trimmedPhone.formattedPhone,
                otp: otp,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            // If the user is new and we haven't collected the name yet, show name input
            if response.isNewUser && !showNameInput && firstName.isEmpty {
                isNewUser = true
                showNameInput = true
                isLoading = false
                hapticManager.selection()
                return
            }

            authManager.handleAuthSuccess(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user
            )

            appState.currentUser = response.user
            hapticManager.success()

            if response.isNewUser || !response.user.onboardingComplete {
                appState.authStatus = .onboarding
            } else {
                appState.authStatus = .authenticated
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
            hapticManager.error()
        } catch {
            errorMessage = "Verification failed. Please try again."
            hapticManager.error()
        }
    }

    // MARK: - Resend OTP

    /// Resends the OTP if the countdown has finished.
    func resendOTP() async {
        guard countdownSeconds == 0 else { return }

        clearErrors()
        isLoading = true
        defer { isLoading = false }

        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await authService.sendPhoneOTP(phone: trimmedPhone.formattedPhone)
            hapticManager.success()
            otp = ""
            startCountdown()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            hapticManager.error()
        } catch {
            errorMessage = "Failed to resend OTP. Please try again."
            hapticManager.error()
        }
    }

    // MARK: - Countdown Timer

    private func startCountdown() {
        countdownTask?.cancel()
        countdownSeconds = 60

        countdownTask = Task { [weak self] in
            while let self, self.countdownSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.countdownSeconds -= 1
            }
        }
    }

    // MARK: - Helpers

    private func clearErrors() {
        errorMessage = nil
        phoneError = nil
        otpError = nil
        firstNameError = nil
    }
}
