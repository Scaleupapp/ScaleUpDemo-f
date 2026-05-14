import SwiftUI

/// Post-diagnostic bridge — hosts the 2-step v2 post-diagnostic flow:
///   1. Reality Check  — review/adjust the (now diagnostic-informed) weekly hours
///   2. Calibration    — calibration gap + trajectory + top-3 actions
///
/// v1's DiagnosticContainerView hands off here after a diagnostic completes,
/// passing the attemptId + an onComplete closure that advances the launch state.
struct V2DiagnosticResultsBridge: View {
    let attemptId: String
    let onComplete: () -> Void

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            V2PostDiagnosticRealityCheckView {
                // Reality Check done → push Calibration insights.
                path.append(PostDiagnosticStep.calibration)
            }
            .navigationDestination(for: PostDiagnosticStep.self) { step in
                switch step {
                case .calibration:
                    V2CalibrationInsightsView(path: $path, attemptId: attemptId)
                }
            }
        }
        // V2CalibrationInsightsView's "Got it — let's start" posts this.
        .onReceive(NotificationCenter.default.publisher(for: .v2OnboardingExit)) { _ in
            onComplete()
        }
    }
}

private enum PostDiagnosticStep: Hashable {
    case calibration
}

/// Notification fired by V2CalibrationInsightsView to signal "I'm done — advance".
extension Notification.Name {
    static let v2OnboardingExit = Notification.Name("scaleup.v2.onboarding.exit")
}
