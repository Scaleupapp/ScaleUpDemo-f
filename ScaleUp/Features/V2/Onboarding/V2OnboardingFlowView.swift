import SwiftUI

/// V2 Onboarding flow container.
///
/// Correct order (the rebuild):
///   1. Objective Setup    — free text + typeahead
///   2. Confirmation Gate  — NLU parse result, confirm or fix
///   3. Topic Selection    — suggested topics, add/remove
///   4. Topic Proficiency  — per-topic self-rating → save w/ computed hours
///                           → advance app to .diagnostic
///
/// The diagnostic, then Reality Check + Calibration, happen AFTER this flow
/// (handled by V2DiagnosticResultsBridge once the diagnostic completes).
///
/// v1 OnboardingContainerView is untouched — this is only shown when
/// the user is on v2 (V2FeatureFlag.shared.isEnabled).
struct V2OnboardingFlowView: View {
    @State private var path = NavigationPath()
    @State private var state = V2OnboardingState()

    var body: some View {
        NavigationStack(path: $path) {
            V2ObjectiveSetupView(path: $path)
                .environment(state)
                .navigationDestination(for: V2OnboardingRoute.self) { route in
                    switch route {
                    case .confirm:
                        V2ObjectiveConfirmView(path: $path)
                            .environment(state)
                    case .topicSelection:
                        V2TopicSelectionView(path: $path)
                            .environment(state)
                    case .topicProficiency:
                        V2TopicProficiencyView(path: $path)
                            .environment(state)
                    }
                }
        }
    }
}

#Preview { V2OnboardingFlowView().preferredColorScheme(.dark) }
