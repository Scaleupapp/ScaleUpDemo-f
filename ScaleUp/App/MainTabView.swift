import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var selectedTab: Tab = .home

    // MARK: - Tab Definition

    enum Tab: String, CaseIterable {
        case home
        case discover
        case journey
        case progress
        case profile

        var title: String {
            switch self {
            case .home: return "Home"
            case .discover: return "Discover"
            case .journey: return "Journey"
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
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            NavigationStack {
                    DiscoverView()
                }
                .tabItem {
                    Label(Tab.discover.title, systemImage: Tab.discover.icon)
                }
                .tag(Tab.discover)

            JourneyView()
                .tabItem {
                    Label(Tab.journey.title, systemImage: Tab.journey.icon)
                }
                .tag(Tab.journey)

            KnowledgeProfileView()
                .tabItem {
                    Label(Tab.progress.title, systemImage: Tab.progress.icon)
                }
                .tag(Tab.progress)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.title, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(ColorTokens.primary)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

// MARK: - Placeholder Tab View

struct PlaceholderTabView: View {
    let tab: MainTabView.Tab

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                EmptyStateView(
                    icon: tab.icon,
                    title: tab.title,
                    subtitle: "Coming Soon"
                )
            }
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
