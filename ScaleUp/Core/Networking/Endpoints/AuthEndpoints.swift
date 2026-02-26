import Foundation

// MARK: - Auth Endpoints

enum AuthEndpoints {

    // MARK: - Request Bodies

    struct RegisterBody: Encodable {
        let email: String
        let password: String
        let firstName: String
        let lastName: String?
    }

    struct LoginBody: Encodable {
        let email: String
        let password: String
    }

    struct GoogleAuthBody: Encodable {
        let idToken: String
    }

    struct RefreshTokenBody: Encodable {
        let refreshToken: String
    }

    struct SendPhoneOTPBody: Encodable {
        let phone: String
    }

    struct VerifyPhoneOTPBody: Encodable {
        let phone: String
        let otp: String
    }

    struct ForgotPasswordBody: Encodable {
        let email: String
    }

    struct ResetPasswordBody: Encodable {
        let token: String
        let newPassword: String
    }

    struct VerifyPhoneBody: Encodable {
        let phone: String
        let otp: String
    }

    // MARK: - Endpoints

    static func register(email: String, password: String, firstName: String, lastName: String?) -> Endpoint {
        .post(
            "/auth/register",
            body: RegisterBody(email: email, password: password, firstName: firstName, lastName: lastName),
            requiresAuth: false
        )
    }

    static func login(email: String, password: String) -> Endpoint {
        .post(
            "/auth/login",
            body: LoginBody(email: email, password: password),
            requiresAuth: false
        )
    }

    static func google(idToken: String) -> Endpoint {
        .post(
            "/auth/google",
            body: GoogleAuthBody(idToken: idToken),
            requiresAuth: false
        )
    }

    static func refreshToken(_ refreshToken: String) -> Endpoint {
        .post(
            "/auth/refresh-token",
            body: RefreshTokenBody(refreshToken: refreshToken),
            requiresAuth: false
        )
    }

    static func sendPhoneOTP(phone: String) -> Endpoint {
        .post(
            "/auth/send-phone-otp",
            body: SendPhoneOTPBody(phone: phone),
            requiresAuth: false
        )
    }

    static func verifyPhoneOTP(phone: String, otp: String) -> Endpoint {
        .post(
            "/auth/verify-phone-otp",
            body: VerifyPhoneOTPBody(phone: phone, otp: otp),
            requiresAuth: false
        )
    }

    static func forgotPassword(email: String) -> Endpoint {
        .post(
            "/auth/forgot-password",
            body: ForgotPasswordBody(email: email),
            requiresAuth: false
        )
    }

    static func resetPassword(token: String, newPassword: String) -> Endpoint {
        .post(
            "/auth/reset-password",
            body: ResetPasswordBody(token: token, newPassword: newPassword),
            requiresAuth: false
        )
    }

    static func verifyPhone(phone: String, otp: String) -> Endpoint {
        .post(
            "/auth/verify-phone",
            body: VerifyPhoneBody(phone: phone, otp: otp)
        )
    }

    static func logout() -> Endpoint {
        .post("/auth/logout")
    }
}
