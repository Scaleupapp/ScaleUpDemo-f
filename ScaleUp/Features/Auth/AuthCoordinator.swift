import SwiftUI

// MARK: - Auth Route

/// Navigation destinations within the authentication flow.
enum AuthRoute: Hashable {
    case login
    case register
    case phoneOTP
    case forgotPassword
}

// MARK: - Auth Coordinator

/// Root coordinator for the authentication flow.
/// Manages a `NavigationStack` with `WelcomeView` as the root
/// and pushes login, register, phone OTP, and forgot-password screens.
struct AuthCoordinator: View {
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onLogin: { path.append(.login) },
                onRegister: { path.append(.register) },
                onPhoneOTP: { path.append(.phoneOTP) }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .login:
                    LoginView(
                        onForgotPassword: { path.append(.forgotPassword) }
                    )
                case .register:
                    RegisterView(
                        onSignIn: {
                            // Pop to root then push login
                            path = [.login]
                        }
                    )
                case .phoneOTP:
                    PhoneOTPView()
                case .forgotPassword:
                    ForgotPasswordView(
                        onBackToLogin: {
                            // Pop back to login
                            if let loginIndex = path.firstIndex(of: .login) {
                                path = Array(path.prefix(through: loginIndex))
                            } else {
                                path = [.login]
                            }
                        }
                    )
                }
            }
        }
        .tint(ColorTokens.primary)
    }
}
