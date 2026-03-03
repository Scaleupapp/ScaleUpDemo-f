import SwiftUI

// MARK: - App Launch State

enum AppLaunchState: Equatable {
    case splash
    case welcome
    case onboarding(step: Int)
    case home
}

// MARK: - App Appearance

enum AppAppearance: String, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - App State

@Observable
@MainActor
final class AppState {

    var launchState: AppLaunchState = .splash
    var currentUser: User?
    var isCheckingAuth = true
    var selectedTab: Tab = .home

    // Theme — stored property so @Observable can track changes
    var appearance: AppAppearance = AppAppearance(
        rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "System"
    ) ?? .system {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
        }
    }

    var colorScheme: ColorScheme? {
        appearance.colorScheme
    }

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
        currentUser = nil
        launchState = .welcome
    }
}

// MARK: - Me Endpoint

private struct MeEndpoint: Endpoint {
    let path = "/users/me"
    let method = HTTPMethod.get
}
