import SwiftUI

/// V2 Main Tab View — the new 4-tab IA.
///
/// Houses Home / Learn / Compass / You with a persistent Compass FAB
/// floating above the tab bar on every tab.
struct V2MainTabView: View {
    @State private var nav = V2NavState()
    @State private var taskRouter = V2TaskRouter()

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
        .sheet(isPresented: $nav.compassSheetOpen) {
            V2CompassSheetView(currentScreen: nav.selectedTab)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(get: { taskRouter.route }, set: { taskRouter.route = $0 })) { route in
            V2TaskSheet(route: route) { taskRouter.close() }
        }
    }
}

#Preview {
    V2MainTabView()
        .preferredColorScheme(.dark)
}
