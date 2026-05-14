import SwiftUI

/// Post-diagnostic bridge — hosts the v2 post-diagnostic flow in the
/// mandated order:
///
///   Diagnostic → Reality Check → Calibration → Plan Creation → Home
///
///   1. Reality Check  — review/confirm the (diagnostic-informed) weekly hours.
///                       On continue: persists any change + triggers plan
///                       generation (POST /api/v2/plan/generate).
///   2. Calibration    — diagnostic result: calibration gap, patterns,
///                       trajectory, top-3 actions.
///   3. Plan Creation  — polls plan-generation status, then → Home.
///
/// v1's DiagnosticContainerView hands off here after a diagnostic completes,
/// passing the attemptId + an onComplete closure that advances the launch state.
struct V2DiagnosticResultsBridge: View {
    let attemptId: String
    let onComplete: () -> Void

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            V2PostDiagnosticRealityCheckView(attemptId: attemptId) {
                // Reality Check done (hours confirmed + plan generation kicked off)
                // → Calibration insights.
                path.append(PostDiagnosticStep.calibration)
            }
            .navigationDestination(for: PostDiagnosticStep.self) { step in
                switch step {
                case .calibration:
                    V2CalibrationInsightsView(
                        path: $path,
                        attemptId: attemptId,
                        onContinueToPlanCreation: {
                            path.append(PostDiagnosticStep.planCreation)
                        }
                    )
                case .planCreation:
                    V2PlanCreationView(attemptId: attemptId) {
                        onComplete()
                    }
                }
            }
        }
        // Safety net — if any screen posts the exit signal directly.
        .onReceive(NotificationCenter.default.publisher(for: .v2OnboardingExit)) { _ in
            onComplete()
        }
    }
}

private enum PostDiagnosticStep: Hashable {
    case calibration
    case planCreation
}

/// Notification fired as a fallback "I'm done — advance" signal.
extension Notification.Name {
    static let v2OnboardingExit = Notification.Name("scaleup.v2.onboarding.exit")
}
