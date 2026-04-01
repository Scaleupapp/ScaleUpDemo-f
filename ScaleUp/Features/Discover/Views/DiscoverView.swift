import SwiftUI

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var selectedCategory: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.sm)

                    if viewModel.isShowingSearchResults {
                        searchResultsView
                    } else if viewModel.isLoading && viewModel.recommendations.isEmpty {
                        loadingState
                    } else if !viewModel.isLoading && !viewModel.hasAnyFeedContent {
                        discoverEmptyState
                    } else {
                        mainFeed
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Content.self) { content in
                ContentDestinationView(content: content)
            }
            .navigationDestination(for: Creator.self) { creator in
                CreatorProfileView(creatorId: creator.id)
            }
        }
        .task {
            await viewModel.loadFeed()
        }
        .coachMark(
            .tabDiscover,
            icon: "safari.fill",
            title: "Content Library",
            message: "Search and browse all content. Filter by type, topic, or difficulty. Find creators to follow."
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            TextField("Search topics, creators, content...", text: $viewModel.searchText)
                .font(.system(size: 15))
                .foregroundStyle(ColorTokens.textPrimary)
                .tint(ColorTokens.gold)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: viewModel.searchText) {
                    viewModel.search()
                }

            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(ColorTokens.gold)
            } else if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    viewModel.searchResults = []
                    viewModel.searchCreatorResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Main Feed (single scroll, no tabs)

    private var mainFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 28) {
                // Unified filter bar
                unifiedFilterBar

                // Featured hero (full width)
                if let featured = viewModel.featuredContent {
                    NavigationLink(value: featured) {
                        featuredHero(featured)
                    }
                    .buttonStyle(.plain)
                }

                // Top Creators
                if !viewModel.creators.isEmpty {
                    creatorsSection
                }

                // Picked For You
                if !viewModel.pickedForYou.isEmpty {
                    contentSection(
                        title: "Picked For You",
                        icon: "sparkles",
                        items: Array(viewModel.pickedForYou.prefix(8))
                    )
                }

                // Knowledge Gaps
                if !viewModel.gapContent.isEmpty {
                    gapSection
                }

                // Trending
                if !viewModel.filteredTrending.isEmpty {
                    contentSection(
                        title: "Trending",
                        icon: "flame.fill",
                        items: viewModel.filteredTrending
                    )
                }

                // Learning Paths
                if !viewModel.learningPaths.isEmpty {
                    pathsSection
                }

                // All Content grid
                if !viewModel.filteredExploreResults.isEmpty {
                    browseSection
                }

                Spacer().frame(height: 80)
            }
            .padding(.top, Spacing.xs)
        }
        .refreshable {
            await viewModel.loadFeed()
        }
    }

    // MARK: - Filter Section

    private var unifiedFilterBar: some View {
        VStack(spacing: 0) {
            // Type filter row
            filterRow(label: "Type") {
                typeChip(nil, label: "All")
                typeChip(.video, label: "Videos")
                typeChip(.article, label: "Articles")
                typeChip(.infographic, label: "Infographics")
            }

            // Topic filter row
            if !viewModel.availableDomains.isEmpty {
                filterRow(label: "Topic") {
                    topicChip(nil, label: "All")
                    ForEach(viewModel.availableDomains, id: \.self) { domain in
                        topicChip(domain, label: domain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(ColorTokens.background)
    }

    private func filterRow<Content: View>(label: String, @ViewBuilder chips: () -> Content) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 40, alignment: .leading)
                .padding(.leading, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chips()
                }
                .padding(.trailing, Spacing.lg)
                .padding(.vertical, 6)
            }
        }
    }

    private func typeChip(_ type: ContentType?, label: String) -> some View {
        let isSelected = viewModel.selectedContentType == type
        return Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedContentType = (viewModel.selectedContentType == type && type != nil) ? nil : type
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .black : ColorTokens.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? ColorTokens.gold : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func topicChip(_ domain: String?, label: String) -> some View {
        let isSelected = (domain == nil && selectedCategory == nil) || selectedCategory == domain
        return Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = domain
            }
            Task { await viewModel.filterByDomain(domain) }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .black : ColorTokens.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? ColorTokens.gold : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Featured Hero

    private func featuredHero(_ content: Content) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Full-width thumbnail
            Group {
                if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            heroPlaceholder(content)
                        }
                    }
                } else {
                    heroPlaceholder(content)
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Gradient
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Info overlay
            VStack(alignment: .leading, spacing: 8) {
                if let domain = content.domain {
                    Text(domain.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(ColorTokens.gold)
                }

                Text(content.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    if let creator = content.creatorId {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(creator.tier?.color ?? ColorTokens.gold)
                                .frame(width: 6, height: 6)
                            Text(creator.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    if !content.overlayBadge.isEmpty {
                        Label(content.overlayBadge, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    if let rating = content.averageRating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(ColorTokens.gold)
                    }
                }
            }
            .padding(16)

            // Play button
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.4), radius: 8)
                        .padding(16)
                }
                Spacer()
            }
        }
        .overlay(alignment: .topLeading) {
            contentTypeBadge(content.contentType)
                .padding(12)
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func heroPlaceholder(_ content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.gold.opacity(0.3), ColorTokens.surfaceElevated, ColorTokens.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.gold.opacity(0.4))
                if let domain = content.domain {
                    Text(domain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
    }

    // MARK: - Creators Section

    private var creatorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "Top Creators", icon: "person.2.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.creators) { creator in
                        NavigationLink(value: creator) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(ColorTokens.surfaceElevated)
                                        .frame(width: 56, height: 56)

                                    if let pic = creator.profilePicture, let url = URL(string: pic) {
                                        AsyncImage(url: url) { phase in
                                            if case .success(let image) = phase {
                                                image.resizable().aspectRatio(contentMode: .fill)
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                            } else {
                                                Text(creator.initials)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(creator.tier?.color ?? ColorTokens.gold)
                                            }
                                        }
                                    } else {
                                        Text(creator.initials)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(creator.tier?.color ?? ColorTokens.gold)
                                    }

                                    Circle()
                                        .stroke(creator.tier?.color ?? ColorTokens.textTertiary, lineWidth: 2)
                                        .frame(width: 56, height: 56)
                                }

                                Text(creator.firstName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                if let tier = creator.tier {
                                    Text(tier.displayName)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(tier.color)
                                }
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Content Section (horizontal scroll)

    private func contentSection(title: String, icon: String, items: [Content]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: title, icon: icon)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { content in
                        NavigationLink(value: content) {
                            contentCard(content)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    private func contentCard(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            Group {
                if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            thumbnailPlaceholder(for: content)
                        }
                    }
                } else {
                    thumbnailPlaceholder(for: content)
                }
            }
            .frame(width: 200, height: 112)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topLeading) {
                contentTypeBadge(content.contentType)
                    .padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                if !content.overlayBadge.isEmpty {
                    Text(content.overlayBadge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }

            // Title
            Text(content.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 200, alignment: .leading)

            // Creator + tier + views
            HStack(spacing: 4) {
                if let creator = content.creatorId {
                    Text(creator.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                    if let tier = creator.tier {
                        TierBadge(tier: tier, compact: true)
                    }
                }
                Spacer()
                if let views = content.viewCount, views > 0 {
                    Text(formatCount(views) + " views")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .frame(width: 200)
        }
    }

    // MARK: - Gap Section

    private var gapSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "Fill Knowledge Gaps", icon: "lightbulb.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.gapContent) { content in
                        NavigationLink(value: content) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ColorTokens.warning)
                                    if let domain = content.domain {
                                        Text(domain)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(ColorTokens.warning)
                                    }
                                    Spacer()
                                }

                                Text(content.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Text("Start Learning")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(ColorTokens.gold)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .padding(12)
                            .frame(width: 200, height: 140)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ColorTokens.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(ColorTokens.warning.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Learning Paths Section

    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "Learning Paths", icon: "road.lanes")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.learningPaths) { path in
                        VStack(alignment: .leading, spacing: 8) {
                            if let domain = path.domain {
                                Text(domain.uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(ColorTokens.gold)
                            }

                            Text(path.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            if let desc = path.description {
                                Text(desc)
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            HStack {
                                if let rating = path.averageRating {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(ColorTokens.gold)
                                        Text(String(format: "%.1f", rating))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                Spacer()
                                if !path.formattedDuration.isEmpty {
                                    Label(path.formattedDuration, systemImage: "clock")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                            }
                        }
                        .padding(12)
                        .frame(width: 200, height: 155)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ColorTokens.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ColorTokens.border, lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Browse Section (grid)

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "Browse All", icon: "square.grid.2x2.fill")

            // Difficulty chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    difficultyChip(label: "All", difficulty: nil)
                    ForEach(Difficulty.allCases) { diff in
                        difficultyChip(label: diff.displayName, difficulty: diff)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }

            // Grid
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 16
            ) {
                ForEach(viewModel.filteredExploreResults) { content in
                    NavigationLink(value: content) {
                        gridCard(content)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if content.id == viewModel.filteredExploreResults.last?.id {
                            Task { await viewModel.loadMoreExplore() }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(ColorTokens.gold)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private func gridCard(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            thumbnailPlaceholder(for: content)
                        }
                    }
                } else {
                    thumbnailPlaceholder(for: content)
                }
            }
            .frame(height: 95)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                contentTypeBadge(content.contentType)
                    .padding(4)
            }
            .overlay(alignment: .bottomTrailing) {
                if !content.overlayBadge.isEmpty {
                    Text(content.overlayBadge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }

            Text(content.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let creator = content.creatorId {
                HStack(spacing: 3) {
                    Text(creator.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                    if let tier = creator.tier {
                        TierBadge(tier: tier, compact: true)
                    }
                }
            }
        }
    }

    private func difficultyChip(label: String, difficulty: Difficulty?) -> some View {
        let isSelected = viewModel.selectedDifficulty == difficulty
        return Button {
            Haptics.selection()
            viewModel.selectedDifficulty = difficulty
            Task { await viewModel.filterByDomain(viewModel.selectedDomain) }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .black : ColorTokens.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? ColorTokens.gold.opacity(0.8) : ColorTokens.surfaceElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                if viewModel.isSearching && viewModel.searchResults.isEmpty && viewModel.searchCreatorResults.isEmpty {
                    // Loading state
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(ColorTokens.gold)
                        Text("Searching...")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if viewModel.searchResults.isEmpty && viewModel.searchCreatorResults.isEmpty && !viewModel.isSearching {
                    // Empty state
                    emptySearchState
                } else {
                    // Creator results
                    if !viewModel.searchCreatorResults.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("CREATORS")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(ColorTokens.textTertiary)
                                Spacer()
                                Text("\(viewModel.searchCreatorResults.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(ColorTokens.gold)
                            }
                            .padding(.horizontal, Spacing.lg)

                            ForEach(viewModel.searchCreatorResults) { creator in
                                NavigationLink(value: creator) {
                                    searchCreatorRow(creator)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Content results
                    if !viewModel.searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("CONTENT")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(ColorTokens.textTertiary)
                                Spacer()
                                Text("\(viewModel.searchResults.count) results")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            .padding(.horizontal, Spacing.lg)

                            ForEach(viewModel.searchResults) { content in
                                NavigationLink(value: content) {
                                    searchContentRow(content)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.top, Spacing.md)
        }
    }

    private func searchCreatorRow(_ creator: Creator) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 44, height: 44)

                Text(creator.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(creator.tier?.color ?? ColorTokens.gold)

                Circle()
                    .stroke(creator.tier?.color ?? ColorTokens.textTertiary, lineWidth: 2)
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(creator.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    if let tier = creator.tier {
                        Text(tier.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(tier.color)
                    }
                    if let count = creator.contentCount, count > 0 {
                        Text("\(count) lessons")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 6)
    }

    private func searchContentRow(_ content: Content) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                thumbnailPlaceholder(for: content)
                            }
                        }
                    } else {
                        thumbnailPlaceholder(for: content)
                    }
                }
                .frame(width: 130, height: 73)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if !content.overlayBadge.isEmpty {
                    Text(content.overlayBadge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let creator = content.creatorId {
                    HStack(spacing: 4) {
                        Text(creator.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                        if let tier = creator.tier {
                            TierBadge(tier: tier, compact: true)
                        }
                    }
                }

                HStack(spacing: 8) {
                    contentTypeBadge(content.contentType)
                    if let domain = content.domain {
                        Text(domain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    if let views = content.viewCount, views > 0 {
                        Text(formatCount(views) + " views")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 2)
    }

    private var emptySearchState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No results for \"\(viewModel.searchText)\"")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Try different keywords or browse categories")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Empty State

    private var discoverEmptyState: some View {
        EmptyStateView(
            icon: "safari",
            title: "No content available yet",
            message: "Content will appear here as creators publish new lessons and resources.",
            actionLabel: "Refresh",
            actionIcon: "arrow.clockwise",
            action: { Task { await viewModel.loadFeed() } }
        )
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.gold)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Helpers

    private func contentTypeBadge(_ type: ContentType) -> some View {
        HStack(spacing: 3) {
            Image(systemName: type.badgeIcon)
                .font(.system(size: 9, weight: .bold))
            Text(type.badgeLabel)
                .font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(type.badgeColor)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }

    private func thumbnailPlaceholder(for content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.surfaceElevated, ColorTokens.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: content.contentType == .video ? "play.fill" : "doc.text")
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.gold.opacity(0.5))
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonLoader(height: 220)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 60)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 120)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 120)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .padding(.top, Spacing.md)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
