import SwiftUI

// MARK: - App Launch State

enum AppLaunchState: Equatable {
    case splash
    case welcome
    case phoneVerification
    case onboarding(step: Int)
    /// Placement students skip the generic D2C onboarding (their objective is
    /// already seeded server-side) and see a short intro before the diagnostic.
    case placementOnboardingIntro
    case diagnostic
    case home
}

// MARK: - App State

@Observable
@MainActor
final class AppState {

    var launchState: AppLaunchState = .splash
    var currentUser: User?
    /// Persona/placement context from GET /api/v2/me/context. Nil or
    /// `persona == "general"` for D2C users; only placement (institution) users
    /// carry a non-nil `placement` block, which drives the PlacementsRoot shell.
    var userContext: UserContext?
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
            // Resolve persona BEFORE launchState so the first .home render picks
            // the right shell (no general→placement flash).
            await loadUserContext()

            // v2 per-user status — server decides v1 vs v2 and whether the
            // user still needs the v2 onboarding flow. Awaited before
            // launchState so the first render reflects it.
            await V2FeatureFlag.shared.syncUserStatus()
            launchState = resolveLaunchState(for: user)
        } catch {
            await KeychainManager.shared.clearTokens()
        }

        isCheckingAuth = false
    }

    /// Decides the launch state for a freshly-fetched user.
    ///
    /// A v2 user who still needs the v2 onboarding flow (new user, or an
    /// existing user who just accepted v2) is routed into onboarding
    /// regardless of their v1 onboarding flag — `ScaleUpApp` then renders
    /// `V2OnboardingFlowView` because the v2 flag is on. Everyone else
    /// follows the normal v1 progression.
    private func resolveLaunchState(for user: User) -> AppLaunchState {
        let flag = V2FeatureFlag.shared
        // Placement (institution) students get a locked objective seeded by the
        // backend (1B) at claim time — they skip the objective-selection
        // onboarding entirely and go straight to the diagnostic (scoped to that
        // objective), then the PlacementsRoot home. `userContext` is resolved
        // before this runs (in checkAuth / handleAuthSuccess).
        if userContext?.isPlacement == true {
            // A placement student who hasn't finished the diagnostic sees the
            // short PlacementOnboardingIntroView first (which hands off to the
            // diagnostic), NOT the generic D2C onboarding.
            return user.diagnosticComplete == true ? .home : .placementOnboardingIntro
        }
        // Finishing the diagnostic is the last step of onboarding — so a user who
        // has completed it must NEVER be routed back through onboarding. This is the
        // safety net for a placement student whose /me/context briefly resolved to
        // 'general' after a session refresh: they reached the diagnostic, so send
        // them Home (the shell self-corrects once the placement context reloads),
        // never back into the generic "set up your profile" flow.
        if user.diagnosticComplete == true {
            return .home
        }
        if flag.isEnabled && flag.needsV2Onboarding {
            return .onboarding(step: 1)
        }
        if user.onboardingComplete == true {
            return .diagnostic
        }
        return .onboarding(step: max(1, user.onboardingStep ?? 1))
    }

    // MARK: - Login Success

    func handleAuthSuccess(_ authData: AuthData) async {
        await KeychainManager.shared.saveTokens(
            access: authData.accessToken,
            refresh: authData.refreshToken
        )
        currentUser = authData.user
        AnalyticsService.shared.identify(userId: authData.user.id)
        await loadUserContext()

        // v2 per-user status — server decides v1 vs v2 and whether the user
        // (a fresh registration is forced onto v2) still needs onboarding.
        await V2FeatureFlag.shared.syncUserStatus()
        launchState = resolveLaunchState(for: authData.user)
    }

    // MARK: - Persona / Placement Context

    /// Resolves the user's persona (general vs placement) and, for placement
    /// users, their institution/cohort/objective context. Best-effort: on any
    /// failure `userContext` is left nil and the user gets the general (D2C)
    /// experience — so this never blocks login or breaks D2C.
    func loadUserContext() async {
        for attempt in 0..<3 {
            do {
                let resp: V2APIResponse<UserContext> = try await V2APIClient.shared.get("/me/context")
                userContext = resp.data
                return
            } catch {
                // Transient (e.g. an access-token refresh mid-flight after a session
                // expiry) — retry before giving up rather than instantly assuming D2C.
                if attempt < 2 { try? await Task.sleep(for: .milliseconds(600)) }
            }
        }
        // All retries failed: KEEP any context we already resolved rather than nuking
        // a placement student down to 'general'. Only a true first launch stays nil.
    }

    /// Redeems a 6-digit college invite code, enrolling the (already logged-in)
    /// student into their cohort. POSTs the code, adopts the returned
    /// `UserContext` (now carrying the placement persona), then re-routes
    /// like the launch flow so the shell re-renders into the placement
    /// experience. Returns `true` on success. On any failure (non-2xx / thrown)
    /// the state is left unchanged and `false` is returned.
    func redeemInviteCode(_ code: String) async -> Bool {
        struct ClaimBody: Codable { let code: String }
        do {
            let resp: V2APIResponse<UserContext> = try await V2APIClient.shared.post(
                "/me/claim-code", body: ClaimBody(code: code)
            )
            userContext = resp.data
            // Re-route like the launch flow does after loadUserContext(): the
            // new persona drives whether resolveLaunchState picks the placement
            // or personal shell.
            if let user = currentUser {
                launchState = resolveLaunchState(for: user)
            }
            return true
        } catch {
            // Leave userContext (and the current shell) unchanged on failure.
            return false
        }
    }

    // MARK: - Onboarding

    func advanceOnboarding(to step: Int) {
        launchState = .onboarding(step: step)
    }

    /// Routes a freshly-registered user into onboarding.
    ///
    /// Must sync v2 status FIRST: a brand-new account has no data, so
    /// `/api/v2/me/status` forces them onto v2 and `ScaleUpApp` then renders
    /// `V2OnboardingFlowView` instead of v1 onboarding. Skipping this sync
    /// (setting `.onboarding` directly) is what left new users on v1.
    func routeFreshRegistrationToOnboarding() async {
        // A roster email auto-enrols the student server-side at register time, so
        // resolve the placement context first: a placement student skips the generic
        // onboarding and goes straight to the short placement intro (NOT the D2C flow).
        await loadUserContext()
        await V2FeatureFlag.shared.syncUserStatus()
        if userContext?.isPlacement == true {
            launchState = .placementOnboardingIntro
            return
        }
        launchState = .onboarding(step: 1)
    }

    func completeOnboarding() {
        if currentUser?.diagnosticComplete == true {
            launchState = .home
        } else {
            launchState = .diagnostic
        }
    }

    // MARK: - Placement Onboarding

    /// Advances a placement student from the intro screen to the existing
    /// diagnostic. Their locked placement objective is already the active
    /// primary objective server-side, so the diagnostic is scoped correctly.
    func proceedFromPlacementIntro() {
        launchState = .diagnostic
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
        userContext = nil
        AnalyticsService.shared.reset()
        launchState = .welcome
    }
}

// MARK: - Me Endpoint

private struct MeEndpoint: Endpoint {
    let path = "/users/me"
    let method = HTTPMethod.get
}
