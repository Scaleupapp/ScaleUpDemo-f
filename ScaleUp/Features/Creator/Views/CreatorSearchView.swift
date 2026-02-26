import SwiftUI

// MARK: - Creator Search View

struct CreatorSearchView: View {
    @Environment(DependencyContainer.self) private var dependencies

    // MARK: - State

    @State private var creators: [CreatorSearchResult] = []
    @State private var filteredCreators: [CreatorSearchResult] = []
    @State private var searchText: String = ""
    @State private var selectedDomain: String?
    @State private var isLoading = false
    @State private var error: APIError?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if isLoading && creators.isEmpty {
                    searchSkeletonView
                } else if let error, creators.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await loadCreators() }
                        }
                    )
                } else if filteredCreators.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Creators Found",
                        subtitle: "Try adjusting your search or filters."
                    )
                } else if creators.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No Creators Yet",
                        subtitle: "Check back soon for new creators."
                    )
                } else {
                    searchContent
                }
            }
            .navigationTitle("Discover Creators")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search by name or domain"
            )
            .onChange(of: searchText) {
                applyFilters()
            }
            .onChange(of: selectedDomain) {
                applyFilters()
            }
        }
        .task {
            if creators.isEmpty {
                await loadCreators()
            }
        }
    }

    // MARK: - Search Content

    private var searchContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {

                // Domain Filter Chips
                domainFilterChips

                // Creator Grid
                creatorGrid

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.sm)
        }
        .refreshable {
            await loadCreators()
        }
    }

    // MARK: - Domain Filter Chips

    private var domainFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // "All" chip
                filterChip(title: "All", isSelected: selectedDomain == nil) {
                    selectedDomain = nil
                }

                // Dynamic domain chips
                ForEach(availableDomains, id: \.self) { domain in
                    filterChip(title: domain, isSelected: selectedDomain == domain) {
                        selectedDomain = selectedDomain == domain ? nil : domain
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Filter Chip

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? .white : ColorTokens.textSecondaryDark)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? ColorTokens.primary : ColorTokens.surfaceElevatedDark)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? ColorTokens.primary : ColorTokens.textTertiaryDark.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Creator Grid

    private var creatorGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.sm),
                GridItem(.flexible(), spacing: Spacing.sm)
            ],
            spacing: Spacing.sm
        ) {
            ForEach(filteredCreators) { creator in
                creatorCard(creator: creator)
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Creator Card

    @ViewBuilder
    private func creatorCard(creator: CreatorSearchResult) -> some View {
        let profile = creator.creatorProfile

        VStack(spacing: Spacing.sm) {
            // Avatar
            CreatorAvatar(
                imageURL: nil,
                name: creator.displayName,
                tier: profile?.tier.rawValue ?? "rising",
                size: 56
            )

            // Creator Name
            Text(creator.displayName)
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .lineLimit(1)

            // Tier Badge
            if let tier = profile?.tier {
                tierBadge(tier: tier)
            }

            // Stats row
            if let stats = profile?.stats {
                HStack(spacing: Spacing.md) {
                    VStack(spacing: 2) {
                        Text("\(stats.totalFollowers)")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                        Text("Followers")
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }

                    VStack(spacing: 2) {
                        Text("\(stats.totalContent)")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                        Text("Content")
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }

                // Rating
                StarRatingDisplay(rating: stats.averageRating, size: 10)
            }

            // Specializations preview
            if let specializations = profile?.specializations, !specializations.isEmpty {
                Text(specializations.prefix(2).joined(separator: ", "))
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Tier Badge

    @ViewBuilder
    private func tierBadge(tier: CreatorTier) -> some View {
        let (color, icon, name) = tierProperties(tier)

        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(name)
                .font(Typography.micro)
        }
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Skeleton Loading View

    private var searchSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                // Filter chips skeleton
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonLoader(width: 80, height: 36, cornerRadius: CornerRadius.full)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Grid skeleton
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.sm),
                        GridItem(.flexible(), spacing: Spacing.sm)
                    ],
                    spacing: Spacing.sm
                ) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: Spacing.sm) {
                            SkeletonLoader(width: 62, height: 62, cornerRadius: CornerRadius.full)
                            SkeletonLoader(width: 100, height: 16)
                            SkeletonLoader(width: 60, height: 20, cornerRadius: CornerRadius.full)
                            SkeletonLoader(width: 120, height: 12)
                            SkeletonLoader(width: 80, height: 12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(ColorTokens.cardDark)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadCreators() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let results = try await dependencies.creatorService.search()
            self.creators = results
            applyFilters()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Filtering

    private func applyFilters() {
        var results = creators

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter { creator in
                creator.displayName.lowercased().contains(query)
                    || (creator.creatorProfile?.domain.lowercased().contains(query) ?? false)
                    || (creator.creatorProfile?.specializations.contains { $0.lowercased().contains(query) } ?? false)
            }
        }

        // Filter by selected domain
        if let selectedDomain {
            results = results.filter { $0.creatorProfile?.domain == selectedDomain }
        }

        filteredCreators = results
    }

    /// Extracts unique domains from all loaded creators.
    private var availableDomains: [String] {
        Array(Set(creators.compactMap { $0.creatorProfile?.domain })).sorted()
    }

    // MARK: - Helpers

    private func tierProperties(_ tier: CreatorTier) -> (Color, String, String) {
        switch tier {
        case .anchor:
            return (ColorTokens.anchorGold, "crown.fill", "Anchor")
        case .core:
            return (ColorTokens.coreSilver, "shield.fill", "Core")
        case .rising:
            return (ColorTokens.risingBronze, "arrow.up.circle.fill", "Rising")
        }
    }
}
