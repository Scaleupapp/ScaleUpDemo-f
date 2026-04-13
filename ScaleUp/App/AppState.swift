import SwiftUI

// MARK: - App Launch State

enum AppLaunchState: Equatable {
    case splash
    case welcome
    case phoneVerification
    case onboarding(step: Int)
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

            if user.onboardingComplete == true {
                launchState = .home
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

        if authData.user.onboardingComplete == true {
            launchState = .home
        } else {
            launchState = .onboarding(step: max(1, authData.user.onboardingStep ?? 1))
        }
    }

    // MARK: - Onboarding

    func advanceOnboarding(to step: Int) {
        launchState = .onboarding(step: step)
    }

    func completeOnboarding() {
        launchState = .home
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
