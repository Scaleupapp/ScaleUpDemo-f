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
        let data = try await api.requestRaw(AuthEndpoints.login, body: body)
        return try parseAuthResponse(data)
    }

    // MARK: - Google Auth

    func googleAuth(idToken: String) async throws -> AuthData {
        let body = GoogleAuthRequest(idToken: idToken)
        let data = try await api.requestRaw(AuthEndpoints.google, body: body)
        return try parseAuthResponse(data)
    }

    // MARK: - Reactivation

    func reactivate(email: String, password: String) async throws -> AuthData {
        let body = ReactivateRequest(email: email, password: password)
        return try await api.request(AuthEndpoints.reactivate, body: body)
    }

    func reactivateWithGoogle(idToken: String) async throws -> AuthData {
        let body = ReactivateGoogleRequest(googleIdToken: idToken)
        return try await api.request(AuthEndpoints.reactivate, body: body)
    }

    // MARK: - Response Parsing

    private func parseAuthResponse(_ data: Data) throws -> AuthData {
        let decoder = JSONDecoder()
        // Try parsing as standard API wrapper: { success, data: { ... } }
        struct Wrapper<T: Decodable>: Decodable { let success: Bool; let data: T }

        // Check if this is a reactivation response
        if let wrapper = try? decoder.decode(Wrapper<ReactivationNeeded>.self, from: data),
           wrapper.data.needsReactivation {
            throw ReactivationRequiredError(info: wrapper.data)
        }

        // Normal auth response
        let wrapper = try decoder.decode(Wrapper<AuthData>.self, from: data)
        return wrapper.data
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

// MARK: - Reactivation Error

struct ReactivationRequiredError: Error, Sendable {
    let info: ReactivationNeeded
}

private enum AuthEndpoints: Endpoint {
    case register, login, google
    case sendOTP, verifyOTP
    case forgotPassword, resetPassword
    case reactivate
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
        case .reactivate: return "/auth/reactivate"
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

private struct ReactivateRequest: Encodable, Sendable {
    let email: String
    let password: String
}

private struct ReactivateGoogleRequest: Encodable, Sendable {
    let googleIdToken: String
}
