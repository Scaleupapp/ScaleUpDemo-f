import SwiftUI

// MARK: - App Launch State

enum AppLaunchState: Equatable {
    case splash
    case welcome
    case phoneVerification
    case onboarding(step: Int)
    case diagnostic
    case home
}

// MARK: - App State

@Observable
@MainActor
final class AppState {

    var launchState: AppLaunchState = .splash
    var currentUser: User?
    var isCheckingAuth = true
    var selectedTab: Tab = .home

    private let authService = AuthService()

    // MARK: - Auth Check on Launch

    func checkAuth() async {
        let token = await KeychainManager.shared.accessToken
        guard token != nil else {
            isCheckingAuth = false
            return
        }

        do {
            let user: User = try await APIClient.shared.request(MeEndpoint())
            currentUser = user
            AnalyticsService.shared.identify(userId: user.id)

            // v2 remote config — server kill switch + fresh-user routing.
            // Awaited before launchState so the first render reflects the flag.
            let isNewUser = user.onboardingComplete != true
            await V2FeatureFlag.shared.syncRemoteConfig(isNewUser: isNewUser)

            if user.onboardingComplete == true {
                if user.diagnosticComplete == true {
                    launchState = .home
                } else {
                    launchState = .diagnostic
                }
            } else {
                launchState = .onboarding(step: max(1, user.onboardingStep ?? 1))
            }
        } catch {
            await KeychainManager.shared.clearTokens()
        }

        isCheckingAuth = false
    }

    // MARK: - Login Success

    func handleAuthSuccess(_ authData: AuthData) async {
        await KeychainManager.shared.saveTokens(
            access: authData.accessToken,
            refresh: authData.refreshToken
        )
        currentUser = authData.user
        AnalyticsService.shared.identify(userId: authData.user.id)

        // v2 remote config — server kill switch + fresh-user routing.
        // A user who just registered has onboardingComplete=false → isNewUser.
        let isNewUser = authData.user.onboardingComplete != true
        await V2FeatureFlag.shared.syncRemoteConfig(isNewUser: isNewUser)

        if authData.user.onboardingComplete == true {
            if authData.user.diagnosticComplete == true {
                launchState = .home
            } else {
                launchState = .diagnostic
            }
        } else {
            launchState = .onboarding(step: max(1, authData.user.onboardingStep ?? 1))
        }
    }

    // MARK: - Onboarding

    func advanceOnboarding(to step: Int) {
        launchState = .onboarding(step: step)
    }

    func completeOnboarding() {
        if currentUser?.diagnosticComplete == true {
            launchState = .home
        } else {
            launchState = .diagnostic
        }
    }

    // MARK: - Diagnostic

    func completeDiagnostic() {
        launchState = .home
    }

    func markDiagnosticComplete() {
        currentUser?.diagnosticComplete = true
    }

    func skipDiagnostic() {
        launchState = .home
    }

    /// Sends the user back through onboarding. Used when the backend signals
    /// the user is missing prerequisites (e.g. empty objective specifics or
    /// no topic self-ratings). The server-side User model is not flipped
    /// here — once they re-complete onboarding, the next /me call returns
    /// the refreshed state.
    func sendToOnboarding(step: Int = 1) {
        launchState = .onboarding(step: max(1, step))
    }

    // MARK: - Logout

    func logout() async {
        try? await authService.logout()
        await KeychainManager.shared.clearTokens()
        URLCache.shared.removeAllCachedResponses()
        currentUser = nil
        AnalyticsService.shared.reset()
        launchState = .welcome
    }
}

// MARK: - Me Endpoint

private struct MeEndpoint: Endpoint {
    let path = "/users/me"
    let method = HTTPMethod.get
}
