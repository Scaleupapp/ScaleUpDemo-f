import SwiftUI

@main
struct ScaleUpApp: App {
    @State private var appState = AppState()
    @State private var coachMarkManager = CoachMarkManager()

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(appState)
                .environment(coachMarkManager)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch appState.launchState {
        case .splash:
            SplashView()
                .transition(.opacity)

        case .welcome:
            WelcomeView()
                .transition(.opacity)

        case .onboarding(let step):
            OnboardingContainerView(initialStep: step, appState: appState)
                .transition(.opacity)

        case .home:
            MainTabView()
                .transition(.opacity)
        }
    }
}
