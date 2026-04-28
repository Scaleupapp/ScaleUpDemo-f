import SwiftUI

@main
struct ScaleUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var coachMarkManager = CoachMarkManager()
    @State private var pushManager = PushNotificationManager()
    @State private var uploadManager = UploadManager()
    @State private var objectiveContext = ObjectiveContext()

    init() {
        AnalyticsService.shared.configure(mixpanelToken: "e914bd9713918ab6ddc0c574a1d77255")
        AnalyticsService.shared.track(.appOpened)
        AnalyticsService.shared.handleAppForeground()
    }

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
                .environment(objectiveContext)
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
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        AnalyticsService.shared.handleAppForeground()
                    case .background:
                        AnalyticsService.shared.handleAppBackground()
                    default:
                        break
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
                .trackScreen("splash")

        case .welcome:
            WelcomeView()
                .transition(.opacity)
                .trackScreen("welcome")

        case .phoneVerification:
            PhoneVerificationView()
                .transition(.opacity)
                .trackScreen("phone_verification")

        case .onboarding(let step):
            OnboardingContainerView(initialStep: step, appState: appState)
                .transition(.opacity)
                .trackScreen("onboarding_step_\(step)")

        case .diagnostic:
            DiagnosticContainerView()
                .transition(.opacity)
                .trackScreen("diagnostic")

        case .home:
            MainTabView()
                .transition(.opacity)
        }
    }

    // MARK: - Deep Link Routing

    private func handleDeepLink(_ deepLink: String) {
        // Competition deep links
        if deepLink.hasPrefix("challenge://") {
            appState.selectedTab = .home
            return
        }
        if deepLink.hasPrefix("leaderboard://") {
            appState.selectedTab = .home
            return
        }
        if deepLink.hasPrefix("live_event://") || deepLink.hasPrefix("live_event_results://") {
            appState.selectedTab = .home
            return
        }
        if deepLink == "home://competition" {
            appState.selectedTab = .home
            return
        }

        // Existing deep links
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
