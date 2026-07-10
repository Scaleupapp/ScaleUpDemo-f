import SwiftUI

/// First-login hook for placement (institution) students — a 3-step welcome
/// that replaces the old intro→diagnostic path:
///
///   1. Objective confirmation (`PlacementOnboardingIntroView`)
///   2. Placement season + upcoming drives (`PlacementSeasonView`)
///   3. A 2-minute practice win with AI feedback (`PlacementFirstWinView`)
///
/// The current step lives in `AppState.placementOnboardingStep`, so the whole
/// hook renders under the single `.placementOnboardingIntro` launch state and
/// `resolveLaunchState` stays unchanged. The final CTA (and every "Skip for
/// now") calls `AppState.finishPlacementOnboarding()`, which marks the student
/// onboarded and routes to `.home`. Returning students never see this flow.
struct PlacementOnboardingFlowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.placementOnboardingStep {
        case .objective:
            PlacementOnboardingIntroView()
                .transition(.opacity)
                .trackScreen("placement_onboarding_objective")
        case .season:
            PlacementSeasonView()
                .transition(.opacity)
                .trackScreen("placement_onboarding_season")
        case .win:
            PlacementFirstWinView()
                .transition(.opacity)
                .trackScreen("placement_onboarding_win")
        }
    }
}
