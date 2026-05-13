import SwiftUI

/// V2 Onboarding flow container — drives the v2 objective → reality check →
/// (existing diagnostic flow) → calibration insights → home progression.
///
/// Existing v1 OnboardingContainerView is untouched. This is only shown when
/// V2FeatureFlag.shared.v2OnboardingEnabled is ON.
struct V2OnboardingFlowView: View {
    @State private var path = NavigationPath()
    @State private var state = V2OnboardingState()

    var body: some View {
        NavigationStack(path: $path) {
            V2ObjectiveSetupView(path: $path)
                .environment(state)
                .navigationDestination(for: V2OnboardingRoute.self) { route in
                    switch route {
                    case .realityCheck:
                        V2RealityCheckView(path: $path)
                            .environment(state)
                    case .calibrationInsights:
                        V2CalibrationInsightsView(
                            path: $path,
                            attemptId: state.diagnosticAttemptId
                        )
                        .environment(state)
                    }
                }
        }
    }
}

#Preview { V2OnboardingFlowView().preferredColorScheme(.dark) }
