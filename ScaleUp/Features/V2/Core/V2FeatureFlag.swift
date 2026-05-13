import SwiftUI

/// V2 Feature Flag — controls whether the user sees the v2 UX or the existing v1 app.
///
/// Backed by UserDefaults so testers can toggle without a rebuild.
/// Roll back at any time by flipping the flag OFF — v1 surfaces are fully intact.
///
/// Default: OFF (existing app). Testers enable via Settings → Developer → "Try v2".
@Observable
@MainActor
final class V2FeatureFlag {
    static let shared = V2FeatureFlag()

    private static let key = "scaleup.v2.enabled"
    private static let onboardingKey = "scaleup.v2.onboarding.enabled"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.key) }
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
}
