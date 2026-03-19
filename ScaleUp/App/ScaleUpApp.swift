import SwiftUI

@main
struct ScaleUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var coachMarkManager = CoachMarkManager()
    @State private var pushManager = PushNotificationManager()
    @State private var uploadManager = UploadManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootView
                UploadProgressOverlay()
            }
                .environment(appState)
                .environment(coachMarkManager)
                .environment(pushManager)
                .environment(uploadManager)
                .preferredColorScheme(.dark)
                .task {
                    // Wire up push manager to app delegate
                    appDelegate.pushManager = pushManager
                    appDelegate.onDeepLink = { deepLink in
                        handleDeepLink(deepLink)
                    }

                    // Request push permission after auth
                    await pushManager.checkPermissionStatus()
                    if appState.launchState == .home && !pushManager.isPermissionGranted {
                        await pushManager.requestPermission()
                    }
                }
                .onChange(of: appState.launchState) { _, newState in
                    if case .home = newState {
                        Task {
                            if !pushManager.isPermissionGranted {
                                await pushManager.requestPermission()
                            }
                            pushManager.clearBadge()
                        }
                    }
                }
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

    // MARK: - Deep Link Routing

    private func handleDeepLink(_ deepLink: String) {
        if deepLink.contains("quizzes") || deepLink.contains("quiz") {
            appState.selectedTab = .home
        } else if deepLink.contains("journey") || deepLink.contains("milestones") {
            appState.selectedTab = .journey
        } else if deepLink.contains("content") {
            appState.selectedTab = .discover
        } else if deepLink.contains("users") {
            appState.selectedTab = .profile
        } else {
            appState.selectedTab = .home
        }
    }
}
