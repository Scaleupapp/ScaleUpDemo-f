import SwiftUI

/// V2 routing state — decides whether this user sees the v2 UX or the v1 app.
///
/// Server-driven. There is no manual toggle: a user's v2 status is determined
/// by `GET /api/v2/me/status` and cannot be changed from the app.
///
///   - New users (no prior data) are forced onto v2 — `isEnabled = true`,
///     `needsV2Onboarding = true`. There is no path back to v1.
///   - Existing users (have data) stay on v1; the server sets
///     `shouldShowV2Prompt` so the app can offer a one-time "try v2" prompt.
///     Accepting (`acceptV2()`) opts them in and routes them through v2
///     onboarding — their learning history is kept.
///
/// Rollback: the whole `/api/v2` namespace is behind the `V2_API_ENABLED`
/// kill switch. When it's off, `/api/v2/me/status` 404s, `syncUserStatus()`
/// forces `isEnabled = false`, and every client cleanly falls back to v1 —
/// no app update needed.
@Observable
@MainActor
final class V2FeatureFlag {
    static let shared = V2FeatureFlag()

    private static let enabledKey = "scaleup.v2.enabled"
    private static let needsOnboardingKey = "scaleup.v2.needsOnboarding"

    /// This user is on v2. Persisted for a fast cold launch, refreshed from
    /// the server by `syncUserStatus()`.
    private(set) var isEnabled: Bool

    /// The v2 user still has to go through the v2 onboarding flow (new user,
    /// or existing user who just accepted v2). Cleared once their v2 plan is
    /// generated.
    private(set) var needsV2Onboarding: Bool

    /// Existing v1 user who should be shown the one-time "try v2" prompt.
    /// Session-only — never persisted; the server's cooldown is the source
    /// of truth for "ask again later".
    var shouldShowV2Prompt: Bool = false

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.needsV2Onboarding = UserDefaults.standard.bool(forKey: Self.needsOnboardingKey)
    }

    // MARK: - Server status

    private struct StatusResponse: Codable {
        let v2Enabled: Bool
        let needsOnboarding: Bool
        let shouldShowPrompt: Bool
    }

    /// Fetch `GET /api/v2/me/status` and apply it. Call at launch (after auth).
    ///
    /// Failure handling distinguishes the kill switch from a network blip:
    ///   - 404 → the `/api/v2` namespace isn't mounted (kill switch off) →
    ///     force v1 so the client cleanly reverts.
    ///   - any other error → keep the persisted state so a transient network
    ///     failure doesn't bounce a v2 user back to v1 mid-session.
    func syncUserStatus() async {
        do {
            let resp: V2APIResponse<StatusResponse> = try await V2APIClient.shared.get("/me/status")
            apply(enabled: resp.data.v2Enabled,
                  needsOnboarding: resp.data.needsOnboarding,
                  showPrompt: resp.data.shouldShowPrompt)
        } catch V2APIError.serverError(let code) where code == 404 {
            // Kill switch is off — fully revert to v1.
            apply(enabled: false, needsOnboarding: false, showPrompt: false)
        } catch {
            // Transient — keep whatever was persisted.
        }
    }

    private func apply(enabled: Bool, needsOnboarding: Bool, showPrompt: Bool) {
        isEnabled = enabled
        needsV2Onboarding = needsOnboarding
        shouldShowV2Prompt = showPrompt
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        UserDefaults.standard.set(needsOnboarding, forKey: Self.needsOnboardingKey)
    }

    // MARK: - Existing-user actions

    /// The existing user accepted the "try v2" prompt. Opts them in on the
    /// server (which also flags them for re-onboarding) and flips local state
    /// so the app can route into the v2 onboarding flow immediately.
    /// Returns true on success.
    @discardableResult
    func acceptV2() async -> Bool {
        struct OptInBody: Codable { let enabled: Bool }
        struct OptInResponse: Codable { let v2OptedIn: Bool?; let needsOnboarding: Bool? }
        do {
            let _: V2APIResponse<OptInResponse> = try await V2APIClient.shared.post(
                "/opt-in/v2", body: OptInBody(enabled: true)
            )
            apply(enabled: true, needsOnboarding: true, showPrompt: false)
            return true
        } catch {
            return false
        }
    }

    /// The existing user dismissed the prompt — record it so the server's
    /// "ask again later" cooldown starts. Best-effort.
    func recordPromptDismissed() async {
        shouldShowV2Prompt = false
        struct Empty: Codable {}
        struct DismissResponse: Codable { let recorded: Bool? }
        let _: V2APIResponse<DismissResponse>? = try? await V2APIClient.shared.post(
            "/me/prompt-dismissed", body: Empty()
        )
    }

    /// Called by the v2 onboarding flow once the user has finished it, so a
    /// re-launch during the same session doesn't route them back in. The
    /// server clears its own flag when the v2 plan is generated.
    func markV2OnboardingDone() {
        apply(enabled: isEnabled, needsOnboarding: false, showPrompt: false)
    }
}
