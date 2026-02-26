import Foundation

// MARK: - Auth Service

/// Service layer wrapping authentication-related API calls.
final class AuthService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Register

    /// Creates a new user account with email and password.
    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.request(
            AuthEndpoints.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName.isEmpty ? nil : lastName
            )
        )
        return response
    }

    // MARK: - Login

    /// Authenticates an existing user with email and password.
    func login(email: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.request(
            AuthEndpoints.login(email: email, password: password)
        )
        return response
    }

    // MARK: - Google Auth

    /// Authenticates or registers a user via Google ID token.
    func googleAuth(idToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.request(
            AuthEndpoints.google(idToken: idToken)
        )
        return response
    }

    // MARK: - Phone OTP

    /// Sends an OTP to the given phone number.
    func sendPhoneOTP(phone: String) async throws {
        try await apiClient.requestVoid(
            AuthEndpoints.sendPhoneOTP(phone: phone)
        )
    }

    /// Verifies a phone OTP. Returns a `PhoneAuthResponse` which includes `isNewUser`.
    func verifyPhoneOTP(
        phone: String,
        otp: String,
        firstName: String,
        lastName: String
    ) async throws -> PhoneAuthResponse {
        let response: PhoneAuthResponse = try await apiClient.request(
            AuthEndpoints.verifyPhoneOTP(phone: phone, otp: otp)
        )
        return response
    }

    // MARK: - Forgot Password

    /// Sends a password-reset OTP to the given email address.
    func forgotPassword(email: String) async throws {
        try await apiClient.requestVoid(
            AuthEndpoints.forgotPassword(email: email)
        )
    }

    /// Resets the user's password using the OTP received via email.
    func resetPassword(email: String, otp: String, newPassword: String) async throws {
        try await apiClient.requestVoid(
            AuthEndpoints.resetPassword(token: otp, newPassword: newPassword)
        )
    }

    // MARK: - Logout

    /// Logs the current user out server-side.
    func logout() async throws {
        try await apiClient.requestVoid(
            AuthEndpoints.logout()
        )
    }
}

// MARK: - Phone Auth Response

/// Extended auth response for phone OTP verification that includes `isNewUser`.
struct PhoneAuthResponse: Decodable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let isNewUser: Bool
}
