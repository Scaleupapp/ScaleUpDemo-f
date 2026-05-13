import SwiftUI

/// Adapter that wraps V2CalibrationInsightsView so v1's DiagnosticContainerView
/// can hand off to it after a diagnostic completes.
///
/// v1's DiagnosticResultsView takes an attemptId + onComplete closure. v2's
/// V2CalibrationInsightsView takes an attemptId via NavigationPath. This shim
/// owns the path and triggers `onComplete` when the user taps "Got it — let's start".
struct V2DiagnosticResultsBridge: View {
    let attemptId: String
    let onComplete: () -> Void

    @State private var path = NavigationPath()
    @State private var done = false

    var body: some View {
        NavigationStack(path: $path) {
            V2CalibrationInsightsView(
                path: $path,
                attemptId: attemptId
            )
        }
        .onChange(of: done) { _, isDone in
            if isDone { onComplete() }
        }
        // V2CalibrationInsightsView's primary CTA sets v2OnboardingEnabled = false
        // as its exit-signal today. We observe that flag flip and forward the
        // existing v1 onComplete so the launch state advances correctly.
        .task(id: V2FeatureFlag.shared.v2OnboardingEnabled) {
            // No-op task — used only to react to flag changes. When the user
            // taps "Got it" in V2CalibrationInsightsView the flag flips OFF
            // and v1's onComplete fires below.
        }
        .onReceive(NotificationCenter.default.publisher(for: .v2OnboardingExit)) { _ in
            onComplete()
        }
    }
}

/// Notification fired by V2CalibrationInsightsView to signal "I'm done — advance".
extension Notification.Name {
    static let v2OnboardingExit = Notification.Name("scaleup.v2.onboarding.exit")
}
