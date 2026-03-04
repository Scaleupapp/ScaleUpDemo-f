import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(CoachMarkManager.self) private var coachMarkManager

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            ForEach(Tab.allCases) { tab in
                tab.view
                    .tabItem {
                        Image(systemName: tab.icon)
                        Text(tab.label)
                    }
                    .tag(tab)
            }
        }
        .tint(ColorTokens.gold)
        .onAppear {
            configureTabBarAppearance()
        }
        .overlay {
            if coachMarkManager.showWelcomeCarousel {
                WelcomeCarouselView {
                    // After carousel dismisses, show the Home tab coach mark
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        coachMarkManager.show(.tabHome)
                    }
                }
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ColorTokens.background)

        // Unselected
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(ColorTokens.textTertiary)
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(ColorTokens.textTertiary)

        // Selected
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(ColorTokens.gold)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(ColorTokens.gold)

        // Top border
        appearance.shadowColor = UIColor(white: 1, alpha: 0.05)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Tab Definition

enum Tab: String, CaseIterable, Identifiable {
    case home
    case discover
    case journey
    case progress
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Home"
        case .discover: return "Discover"
        case .journey: return "My Plan"
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .discover: return "safari.fill"
        case .journey: return "map.fill"
        case .progress: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }

    @MainActor @ViewBuilder
    var view: some View {
        switch self {
        case .home: HomeView()
        case .discover: DiscoverView()
        case .journey: MyPlanView()
        case .progress: ProgressTabView()
        case .profile: ProfileTabView()
        }
    }
}

// MARK: - Placeholder Tab (Phase 1 only)

struct PlaceholderTab: View {
    let tab: Tab

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.gold)

                    Text(tab.label)
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Coming in Phase \(phaseNumber)")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .navigationTitle(tab.label)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var phaseNumber: String {
        switch tab {
        case .home, .discover: return "3"
        case .journey: return "5"
        case .progress: return "4"
        case .profile: return "6"
        }
    }
}
