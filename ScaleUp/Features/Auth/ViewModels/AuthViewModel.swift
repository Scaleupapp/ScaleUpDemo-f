import SwiftUI

@Observable
@MainActor
final class AuthViewModel {

    // MARK: - Form Fields

    var email = ""
    var password = ""
    var firstName = ""
    var lastName = ""
    var phone = ""
    var otp = ""

    // MARK: - State

    var isLoading = false
    var errorMessage: String?
    var otpSent = false
    var otpCooldown = 0

    // Reactivation
    var needsReactivation = false
    var reactivationInfo: ReactivationNeeded?

    // Phone not registered (standalone phone login for unregistered user)
    var phoneNeedsRegistration = false

    // MARK: - Dependencies

    private let authService = AuthService()
    private var cooldownTask: Task<Void, Never>?

    // MARK: - Validation

    var isLoginValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    var isRegisterValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8
    }

    var isPhoneValid: Bool {
        phone.count >= 10
    }

    var isOTPValid: Bool {
        otp.count == 6
    }

    // MARK: - Actions

    func login() async -> AuthData? {
        guard isLoginValid else { return nil }
        isLoading = true
        errorMessage = nil
        needsReactivation = false

        do {
            let result = try await authService.login(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password
            )
            isLoading = false
            Haptics.success()
            return result
        } catch let error as ReactivationRequiredError {
            reactivationInfo = error.info
            needsReactivation = true
            isLoading = false
            return nil
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            Haptics.error()
            return nil
        } catch {
            errorMessage = "Connection error. Please try again."
            isLoading = false
            Haptics.error()
            return nil
        }
    }

    func reactivateAccount() async -> AuthData? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await authService.reactivate(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password
            )
            needsReactivation = false
            reactivationInfo = nil
            isLoading = false
            Haptics.success()
            return result
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            Haptics.error()
            return nil
        } catch {
            errorMessage = "Could not reactivate. Please try again."
            isLoading = false
            Haptics.error()
            return nil
        }
    }

    func cancelReactivation() {
        needsReactivation = false
        reactivationInfo = nil
    }

    func register() async -> AuthData? {
        guard isRegisterValid else { return nil }
        isLoading = true
        errorMessage = nil

        do {
            let result = try await authService.register(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password,
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lastName.trimmingCharacters(in: .whitespaces)
            )
            isLoading = false
            Haptics.success()
            AnalyticsService.shared.track(.registrationCompleted(method: .email))
            return result
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            Haptics.error()
            return nil
        } catch {
            errorMessage = "Connection error. Please try again."
            isLoading = false
            Haptics.error()
            return nil
        }
    }

    func sendOTP() async {
        guard isPhoneValid else { return }
        isLoading = true
        errorMessage = nil

        let formattedPhone = phone.hasPrefix("+") ? phone : "+91\(phone)"
        AnalyticsService.shared.track(.phoneEntered)

        do {
            try await authService.sendOTP(phone: formattedPhone)
            otpSent = true
            isLoading = false
            startCooldown()
            Haptics.success()
            AnalyticsService.shared.track(.otpRequested)
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            Haptics.error()
            AnalyticsService.shared.track(.otpFailed(reason: error.errorDescription ?? "api_error"))
        } catch {
            errorMessage = "Failed to send OTP. Try again."
            isLoading = false
            Haptics.error()
            AnalyticsService.shared.track(.otpFailed(reason: "unknown"))
        }
    }

    func verifyOTP() async -> AuthData? {
        guard isOTPValid else { return nil }
        isLoading = true
        errorMessage = nil
        phoneNeedsRegistration = false

        let formattedPhone = phone.hasPrefix("+") ? phone : "+91\(phone)"

        do {
            let result = try await authService.verifyOTP(
                phone: formattedPhone,
                otp: otp,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName
            )
            isLoading = false
            Haptics.success()
            AnalyticsService.shared.track(.otpVerified)
            if !firstName.isEmpty {
                // firstName is only sent on the phone-based registration branch
                AnalyticsService.shared.track(.registrationCompleted(method: .phone))
            }
            return result
        } catch is PhoneNotRegisteredError {
            phoneNeedsRegistration = true
            errorMessage = "No account found with this phone number. Please sign up first."
            isLoading = false
            Haptics.error()
            return nil
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            Haptics.error()
            return nil
        } catch {
            errorMessage = "Verification failed. Try again."
            isLoading = false
            Haptics.error()
            return nil
        }
    }

    /// Link phone to the already-authenticated user (used after email registration).
    func verifyPhoneForUser() async -> Bool {
        guard isOTPValid else { return false }
        isLoading = true
        errorMessage = nil

        let formattedPhone = phone.hasPrefix("+") ? phone : "+91\(phone)"

        do {
            try await authService.verifyPhoneForUser(phone: formattedPhone, otp: otp)
            isLoading = false
            Haptics.success()
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            Haptics.error()
            return false
        } catch {
            errorMessage = "Verification failed. Try again."
            isLoading = false
            Haptics.error()
            return false
        }
    }

    // MARK: - Cooldown

    func startResendCooldown() {
        startCooldown()
    }

    private func startCooldown() {
        otpCooldown = 60
        cooldownTask?.cancel()
        cooldownTask = Task { @MainActor [weak self] in
            while let self, self.otpCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.otpCooldown -= 1
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
