import SwiftUI

/// Placements shell — the 4-tab IA for institution (placement) users:
/// Home / Campus / Library / You, with a persistent Compass FAB.
///
/// Mirrors `V2MainTabView` but with the placement IA. It reuses the V2 Compass
/// sheet, the V2 task router/sheet, and `V2YouView` unchanged. The V2 Compass
/// reads `@Environment(V2NavState.self)`, so a `V2NavState` shim is injected
/// for it even though the placement tabs are driven by `PlacementNavState`.
struct PlacementsMainTabView: View {
    @State private var nav = PlacementNavState()
    /// Compatibility shim: `V2CompassView` requires a `V2NavState` in the
    /// environment. The placement tabs don't use it; it exists only so the
    /// reused Compass sheet renders without crashing.
    @State private var v2Nav = V2NavState()
    @State private var taskRouter = V2TaskRouter()
    /// Assessment id a push tap wants opened, threaded down to the Assessments
    /// section on the Home tab. Set by `routePlacementDeepLink`.
    @State private var focusAssessmentId: String?
    @Environment(ObjectiveContext.self) private var objectiveContext
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $nav.selectedTab) {
                PlacementsHomeView(focusAssessmentId: $focusAssessmentId)
                    .tabItem { Label(PlacementTab.home.label, systemImage: PlacementTab.home.icon) }
                    .tag(PlacementTab.home)

                PlacementsCampusView()
                    .tabItem { Label(PlacementTab.campus.label, systemImage: PlacementTab.campus.icon) }
                    .tag(PlacementTab.campus)

                PlacementsLibraryView()
                    .tabItem { Label(PlacementTab.library.label, systemImage: PlacementTab.library.icon) }
                    .tag(PlacementTab.library)

                V2YouView(isPlacement: true)
                    .tabItem { Label(PlacementTab.you.label, systemImage: PlacementTab.you.icon) }
                    .tag(PlacementTab.you)
            }
            .tint(ColorTokens.gold)

            // Persistent Compass FAB on every placement tab (no Compass tab here).
            CompassFAB { nav.compassSheetOpen = true }
                .padding(.trailing, 16)
                .padding(.bottom, 72)
                .transition(.scale.combined(with: .opacity))
        }
        .environment(v2Nav)
        .environment(taskRouter)
        // Sheets don't reliably inherit @Observable environment objects — re-inject
        // exactly what the reused V2 screens read (see V2MainTabView for the same pattern).
        .sheet(isPresented: $nav.compassSheetOpen) {
            V2CompassSheetView(currentScreen: .home, isPlacement: true)
                .environment(v2Nav)
                .environment(taskRouter)
                .environment(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(get: { taskRouter.route }, set: { taskRouter.route = $0 })) { route in
            V2TaskSheet(route: route) { taskRouter.close() }
                .environment(v2Nav)
                .environment(taskRouter)
                .environment(objectiveContext)
                .environment(appState)
        }
        // Sole consumer of the placement push-tap deep link. `.onChange` covers
        // a tap while the shell is live; `.task` covers a cold launch where the
        // link was set before this view mounted.
        .onChange(of: appState.placementDeepLink) { _, link in
            routePlacementDeepLink(link)
        }
        .task {
            routePlacementDeepLink(appState.placementDeepLink)
        }
    }

    /// Switches to the Home tab (where the Assessments list lives) and, for a
    /// results deep link, threads the assessment id down so its result opens.
    /// Consumes the signal so it fires exactly once.
    private func routePlacementDeepLink(_ link: PlacementDeepLink?) {
        guard let link else { return }
        nav.selectedTab = .home
        if case .assessmentResult(let id) = link {
            focusAssessmentId = id
        }
        appState.placementDeepLink = nil
    }
}
