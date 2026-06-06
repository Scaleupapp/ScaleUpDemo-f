import SwiftUI

/// V2 Main Tab View — the new 4-tab IA.
///
/// Houses Home / Learn / Compass / You with a persistent Compass FAB
/// floating above the tab bar on every tab.
struct V2MainTabView: View {
    @State private var nav = V2NavState()
    @State private var taskRouter = V2TaskRouter()
    @State private var nextStep = NextStepCoordinator.shared
    /// Forwarded into the task sheet so v1 screens that need it (e.g.
    /// CompetitionHubView) have it — sheets don't reliably inherit it.
    @Environment(ObjectiveContext.self) private var objectiveContext
    /// PlayerView and other v1 detail screens read AppState; without this,
    /// sheets crash on the same class of bug as the FAB-Compass issue.
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $nav.selectedTab) {
                V2HomeView()
                    .tabItem { Label(V2Tab.home.label, systemImage: V2Tab.home.icon) }
                    .tag(V2Tab.home)

                V2LearnView()
                    .tabItem { Label(V2Tab.learn.label, systemImage: V2Tab.learn.icon) }
                    .tag(V2Tab.learn)

                V2CompassView()
                    .tabItem { Label(V2Tab.compass.label, systemImage: V2Tab.compass.icon) }
                    .tag(V2Tab.compass)

                V2YouView()
                    .tabItem { Label(V2Tab.you.label, systemImage: V2Tab.you.icon) }
                    .tag(V2Tab.you)
            }
            .tint(ColorTokens.gold)

            // Persistent Compass FAB on all tabs except the Compass tab itself.
            if nav.selectedTab != .compass {
                CompassFAB { nav.compassSheetOpen = true }
                    .padding(.trailing, 16)
                    .padding(.bottom, 72)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .environment(nav)
        .environment(taskRouter)
        // Sheet content does NOT reliably inherit @Observable environment
        // objects — re-inject explicitly so V2CompassView / V2TaskSheet
        // (which depend on V2TaskRouter) don't crash when presented here.
        .sheet(isPresented: $nav.compassSheetOpen) {
            V2CompassSheetView(currentScreen: nav.selectedTab)
                .environment(nav)
                .environment(taskRouter)
                .environment(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(get: { taskRouter.route }, set: { taskRouter.route = $0 })) { route in
            V2TaskSheet(route: route) { taskRouter.close() }
                .environment(nav)
                .environment(taskRouter)
                .environment(objectiveContext)
                .environment(appState)
        }
        .onChange(of: nextStep.pending) { _, intent in
            guard let intent else { return }
            nextStep.pending = nil
            routeNextStep(intent)
        }
    }

    /// Translates a `NextStepCoordinator` intent into real navigation. Clears
    /// any open sheet first, then routes after it dismisses to avoid
    /// sheet-over-sheet races.
    private func routeNextStep(_ intent: NextStepCoordinator.Intent) {
        taskRouter.close()
        nav.compassSheetOpen = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            switch intent {
            case .launchQuiz(let topic):
                taskRouter.route = .quizByTopic(topic: topic, weekNumber: nil)
            case .startInterview:
                taskRouter.route = .interview(scenarioId: nil)
            case .reviewQuiz(let quizId):
                taskRouter.route = .quiz(quizId: quizId)
            case .launchDrill, .tutorOn, .openPlan:
                break // wired in Phase 2
            }
        }
    }
}

#Preview {
    V2MainTabView()
        .preferredColorScheme(.dark)
}
