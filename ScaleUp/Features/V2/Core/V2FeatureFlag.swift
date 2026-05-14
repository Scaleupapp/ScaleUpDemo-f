import SwiftUI

/// V2 Feature Flag — controls whether the user sees the v2 UX or the existing v1 app.
///
/// Backed by UserDefaults so testers can toggle without a rebuild.
/// Roll back at any time by flipping the flag OFF — v1 surfaces are fully intact.
///
/// Default: OFF (existing app). Testers enable via Settings → "Try v2 redesign".
///
/// Side effect: when the flag flips, we POST to /api/v2/opt-in/v2 so the server
/// can suppress v1 anti-thesis notifications (streak-panic, generic-trending)
/// for this user.
@Observable
@MainActor
final class V2FeatureFlag {
    static let shared = V2FeatureFlag()

    private static let key = "scaleup.v2.enabled"
    private static let onboardingKey = "scaleup.v2.onboarding.enabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.key)
            Task { await syncOptIn(isEnabled) }
        }
    }

    /// Sub-flag — show v2 onboarding/diagnostic screens too (not just home tabs).
    /// Default OFF even when isEnabled is ON, so testers can flip just the tab UX first.
    var v2OnboardingEnabled: Bool {
        didSet { UserDefaults.standard.set(v2OnboardingEnabled, forKey: Self.onboardingKey) }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.key)
        self.v2OnboardingEnabled = UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    /// Reset to v1 — single-tap rollback for testers.
    func disableAndRestart() {
        isEnabled = false
        v2OnboardingEnabled = false
    }

    // MARK: - Remote config (fresh-user routing + server kill switch)

    private struct V2RemoteConfig: Codable {
        let v2ApiEnabled: Bool
        let v2ForNewUsers: Bool
    }

    /// Fetched at launch (after auth). Two jobs:
    ///   1. Server kill switch — if the backend reports v2ApiEnabled=false,
    ///      force both local flags OFF so every client cleanly reverts to v1.
    ///   2. Fresh-user routing — a brand-new user (onboarding not complete)
    ///      is auto-opted into v2 when the server has v2ForNewUsers=true.
    /// Best-effort: on network failure the local flag stands.
    func syncRemoteConfig(isNewUser: Bool) async {
        do {
            let resp: V2APIResponse<V2RemoteConfig> = try await V2APIClient.shared.get("/config")
            let cfg = resp.data

            // Server kill switch wins over everything.
            if !cfg.v2ApiEnabled {
                if isEnabled { isEnabled = false }
                if v2OnboardingEnabled { v2OnboardingEnabled = false }
                return
            }

            // Brand-new user + server says fresh users get v2 → opt them in.
            if isNewUser && cfg.v2ForNewUsers && !isEnabled {
                isEnabled = true
                v2OnboardingEnabled = true
            }
        } catch {
            // best-effort — keep the local flag as-is
        }
    }

    /// Tell the backend the user has opted in/out so server-side workers can
    /// suppress v1 anti-thesis prompts. Best-effort; failures don't break the
    /// local flag.
    private func syncOptIn(_ enabled: Bool) async {
        struct OptInBody: Codable { let enabled: Bool }
        do {
            let _: V2APIResponse<OptInResponse> = try await V2APIClient.shared.post(
                "/opt-in/v2",
                body: OptInBody(enabled: enabled)
            )
        } catch {
            // Silent — flag stays local-only. Next sync attempt on next flip.
        }
    }

    private struct OptInResponse: Codable {
        let v2OptedIn: Bool?
    }
}
