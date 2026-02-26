import Foundation
import GoogleSignIn

final class GoogleSignInManager {

    @MainActor
    func signIn() async throws -> String {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw GoogleSignInError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.noIDToken
        }

        return idToken
    }
}

enum GoogleSignInError: Error, LocalizedError {
    case noRootViewController
    case noIDToken

    var errorDescription: String? {
        switch self {
        case .noRootViewController: return "Could not find root view controller"
        case .noIDToken: return "Failed to get Google ID token"
        }
    }
}
