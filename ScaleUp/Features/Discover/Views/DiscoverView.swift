import SwiftUI

// MARK: - Discover Tab

enum DiscoverTab: String, CaseIterable {
    case forYou = "For You"
    case explore = "Explore"
}

struct DiscoverView: View {

    @Environment(DependencyContainer.self) private var dependencies
    @State private var selectedTab: DiscoverTab = .forYou
    @State private var showSearch = false

    // MARK: - View Models

    @State private var feedViewModel: DiscoverViewModel?
    @State private var exploreViewModel: ExploreViewModel?

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with search
                headerSection

                // Tab content
                TabView(selection: $selectedTab) {
                    if let feedViewModel {
                        FeedView(viewModel: feedViewModel)
                            .tag(DiscoverTab.forYou)
                    }

                    if let exploreViewModel {
                        ExploreView(viewModel: exploreViewModel)
                            .tag(DiscoverTab.explore)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Animations.standard, value: selectedTab)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(for: Content.self) { content in
            ContentDetailView(contentId: content.id)
        }
        .navigationDestination(isPresented: $showSearch) {
            SearchView()
                .environment(dependencies)
        }
        .onAppear {
            initializeViewModels()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 0) {
            // Title row
            HStack {
                Text("Discover")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                // Notification bell
                Button {
                    // Notifications
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .frame(width: 36, height: 36)
                        .background(ColorTokens.surfaceElevatedDark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.sm)

            // Search bar
            searchBar

            // Segmented control
            segmentedControl

            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTokens.surfaceElevatedDark.opacity(0),
                            ColorTokens.surfaceElevatedDark,
                            ColorTokens.surfaceElevatedDark.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        Button {
            showSearch = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ColorTokens.primary.opacity(0.7))

                Text("Search content, creators, topics...")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                Spacer()

                // Mic icon hint
                Image(systemName: "mic.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textTertiaryDark.opacity(0.5))
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 44)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        LinearGradient(
                            colors: [
                                ColorTokens.primary.opacity(0.15),
                                ColorTokens.surfaceElevatedDark,
                                ColorTokens.primary.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(DiscoverTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: Spacing.sm) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: tab == .forYou ? "sparkles" : "safari")
                                .font(.system(size: 12, weight: .medium))

                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .foregroundStyle(
                            selectedTab == tab
                                ? ColorTokens.textPrimaryDark
                                : ColorTokens.textTertiaryDark
                        )

                        // Animated indicator
                        Capsule()
                            .fill(selectedTab == tab ? ColorTokens.primary : .clear)
                            .frame(height: 3)
                            .frame(width: selectedTab == tab ? 40 : 0)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, 2)
    }

    // MARK: - Helpers

    private func initializeViewModels() {
        if feedViewModel == nil {
            feedViewModel = DiscoverViewModel(
                contentService: dependencies.contentService,
                recommendationService: dependencies.recommendationService,
                creatorService: dependencies.creatorService
            )
        }
        if exploreViewModel == nil {
            exploreViewModel = ExploreViewModel(
                contentService: dependencies.contentService
            )
        }
    }
}

#Preview {
    DiscoverView()
        .environment(DependencyContainer())
        .preferredColorScheme(.dark)
}
