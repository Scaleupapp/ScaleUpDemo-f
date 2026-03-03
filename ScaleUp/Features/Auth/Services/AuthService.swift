import Foundation

// MARK: - Auth Service

actor AuthService {

    private let api = APIClient.shared

    // MARK: - Registration

    func register(email: String, password: String, firstName: String, lastName: String?) async throws -> AuthData {
        let body = RegisterRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        return try await api.request(AuthEndpoints.register, body: body)
    }

    // MARK: - Login

    func login(email: String, password: String) async throws -> AuthData {
        let body = LoginRequest(email: email, password: password)
        return try await api.request(AuthEndpoints.login, body: body)
    }

    // MARK: - Google Auth

    func googleAuth(idToken: String) async throws -> AuthData {
        let body = GoogleAuthRequest(idToken: idToken)
        return try await api.request(AuthEndpoints.google, body: body)
    }

    // MARK: - Phone OTP

    func sendOTP(phone: String) async throws {
        let body = SendOTPRequest(phone: phone)
        _ = try await api.requestRaw(AuthEndpoints.sendOTP, body: body)
    }

    func verifyOTP(phone: String, otp: String, firstName: String?, lastName: String?) async throws -> AuthData {
        let body = VerifyOTPRequest(
            phone: phone, otp: otp,
            firstName: firstName, lastName: lastName
        )
        return try await api.request(AuthEndpoints.verifyOTP, body: body)
    }

    // MARK: - Password Reset

    func forgotPassword(email: String) async throws {
        let body = ForgotPasswordRequest(email: email)
        _ = try await api.requestRaw(AuthEndpoints.forgotPassword, body: body)
    }

    func resetPassword(email: String, otp: String, newPassword: String) async throws {
        let body = ResetPasswordRequest(email: email, otp: otp, newPassword: newPassword)
        _ = try await api.requestRaw(AuthEndpoints.resetPassword, body: body)
    }

    // MARK: - Logout

    func logout() async throws {
        _ = try await api.requestRaw(AuthEndpoints.logout)
        await KeychainManager.shared.clearTokens()
    }
}

// MARK: - Endpoints

private enum AuthEndpoints: Endpoint {
    case register, login, google
    case sendOTP, verifyOTP
    case forgotPassword, resetPassword
    case logout

    var path: String {
        switch self {
        case .register: return "/auth/register"
        case .login: return "/auth/login"
        case .google: return "/auth/google"
        case .sendOTP: return "/auth/phone/send-otp"
        case .verifyOTP: return "/auth/phone/verify-otp"
        case .forgotPassword: return "/auth/forgot-password"
        case .resetPassword: return "/auth/reset-password"
        case .logout: return "/auth/logout"
        }
    }

    var method: HTTPMethod {
        .post
    }

    var requiresAuth: Bool {
        self == .logout
    }
}

// MARK: - Request Bodies

private struct RegisterRequest: Encodable, Sendable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String?
}

private struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

private struct GoogleAuthRequest: Encodable, Sendable {
    let idToken: String
}

private struct SendOTPRequest: Encodable, Sendable {
    let phone: String
}

private struct VerifyOTPRequest: Encodable, Sendable {
    let phone: String
    let otp: String
    let firstName: String?
    let lastName: String?
}

private struct ForgotPasswordRequest: Encodable, Sendable {
    let email: String
}

private struct ResetPasswordRequest: Encodable, Sendable {
    let email: String
    let otp: String
    let newPassword: String
}
