import SwiftUI

/// DiscoverView — YouTube Home-style continuous content feed.
///
/// Layout (top → bottom):
///   1. Search bar
///   2. Sticky Type chip row (All / Videos / Notes / Articles / Infographics / Quick / Long)
///   3. Top Creators horizontal strip
///   4. Trending This Week horizontal rail (8 items)
///   5. "For You" vertical infinite feed of full-width 16:9 cards
///
/// The goal-bound rails (Knowledge Gaps, Paths, Picked-For-You) live in v2 Learn now.
/// Discover is the open library — no editorial hero, no topic filter, no grid.
struct DiscoverView: View {

    /// Optional pre-positioning hint from callers (e.g. v2 Learn's Browse-by
    /// buttons). Most legacy `.section(...)` values collapse to `.none` in the
    /// new structure — only `.type(...)` and `.creator` still mean something.
    enum InitialFilter: Equatable {
        case none
        case topic                          // no topic filter anymore — scrolls to chips
        case type(ContentType)              // preselect a content type
        case creator                        // anchor to the Top Creators row
        case section(DiscoverSection)       // legacy — most cases collapse to .none
    }

    /// Legacy enum kept for source compatibility with prior callers.
    /// Only `.creators` and `.trending` map to real anchors in the new layout.
    enum DiscoverSection: String, Equatable {
        case featured
        case creators
        case picked
        case gaps
        case trending
        case paths
        case browse
    }

    /// Pseudo content-type buckets exposed in the chip row. `Quick` / `Long`
    /// are duration-based filters applied client-side on top of the real
    /// `ContentType` filter.
    enum FeedTypeFilter: Equatable, Hashable {
        case all
        case type(ContentType)
        case quick   // duration <= 300s
        case long    // duration >= 900s
    }

    private let initialFilter: InitialFilter
    private let initialSearchQuery: String?

    init(initialFilter: InitialFilter = .none, initialSearchQuery: String? = nil) {
        self.initialFilter = initialFilter
        self.initialSearchQuery = initialSearchQuery
    }

    @State private var viewModel = DiscoverViewModel()
    @State private var selectedFeedType: FeedTypeFilter = .all
    @State private var didApplyInitialFilter = false
    @State private var didApplyInitialQuery = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 0) {
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
            applyInitialQueryIfNeeded()
        }
        .coachMark(
            .tabDiscover,
            icon: "safari.fill",
            title: "Content Library",
            message: "Search and browse all content. Filter by type. Find creators to follow."
        )
    }

    // MARK: - Initial query / filter

    private func applyInitialQueryIfNeeded() {
        guard !didApplyInitialQuery,
              let q = initialSearchQuery?.trimmingCharacters(in: .whitespaces),
              !q.isEmpty else { return }
        didApplyInitialQuery = true
        viewModel.searchText = q
        viewModel.search()
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

    // MARK: - Main Feed

    private var mainFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    Section {
                        feedSections
                    } header: {
                        stickyTypeChips
                            .id("filter-bar")
                    }
                }
                .padding(.top, 0)
            }
            .refreshable {
                await viewModel.loadFeed()
            }
            .onAppear { applyInitialFilter(using: proxy) }
            .onChange(of: viewModel.isLoading) { _, newValue in
                if !newValue { applyInitialFilter(using: proxy) }
            }
        }
    }

    @ViewBuilder
    private var feedSections: some View {
        VStack(spacing: Spacing.xl) {
            // Top Creators (kept)
            if !viewModel.creators.isEmpty {
                creatorsSection
                    .id("top-creators")
                    .id("section-creators")
            }

            // Trending This Week — one rail, 8 items
            if !viewModel.filteredTrending.isEmpty {
                contentSection(
                    title: "Trending This Week",
                    icon: "flame.fill",
                    items: Array(viewModel.filteredTrending.prefix(8))
                )
                .id("section-trending")
            }

            // FOR YOU — vertical infinite feed
            forYouFeed

            Spacer().frame(height: 80)
        }
        .padding(.top, Spacing.sm)
    }

    /// Runs once after the feed first loads — sets the type chip or scrolls to
    /// the requested anchor based on the caller-provided `initialFilter`.
    private func applyInitialFilter(using proxy: ScrollViewProxy) {
        guard !didApplyInitialFilter else { return }
        switch initialFilter {
        case .none:
            return
        case .topic:
            // No topic filter anymore — just snap to the chip row.
            didApplyInitialFilter = true
            withAnimation { proxy.scrollTo("filter-bar", anchor: .top) }
        case .type(let t):
            guard !viewModel.isLoading else { return }
            didApplyInitialFilter = true
            selectedFeedType = .type(t)
            viewModel.selectedContentType = t
            withAnimation { proxy.scrollTo("filter-bar", anchor: .top) }
        case .creator:
            guard !viewModel.creators.isEmpty else { return }
            didApplyInitialFilter = true
            withAnimation { proxy.scrollTo("top-creators", anchor: .top) }
        case .section(let section):
            guard !viewModel.isLoading else { return }
            didApplyInitialFilter = true
            // Only .creators and .trending survived — everything else falls back
            // to the chip row at the top.
            let anchor: String
            switch section {
            case .creators: anchor = "section-creators"
            case .trending: anchor = "section-trending"
            default: anchor = "filter-bar"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { proxy.scrollTo(anchor, anchor: .top) }
            }
        }
    }

    // MARK: - Sticky Type Chips

    private var stickyTypeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                feedTypeChip(.all, label: "All")
                feedTypeChip(.type(.video), label: "Videos")
                feedTypeChip(.type(.notes), label: "Notes")
                feedTypeChip(.type(.article), label: "Articles")
                feedTypeChip(.type(.infographic), label: "Infographics")
                feedTypeChip(.quick, label: "Quick")
                feedTypeChip(.long, label: "Long")
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 10)
        }
        .background(ColorTokens.background)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(ColorTokens.border.opacity(0.6)),
            alignment: .bottom
        )
    }

    private func feedTypeChip(_ filter: FeedTypeFilter, label: String) -> some View {
        let isSelected = selectedFeedType == filter
        return Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFeedType = filter
                // Push the real ContentType filter through to the VM so its
                // existing `filteredExploreResults` / `filteredTrending` work.
                switch filter {
                case .all, .quick, .long:
                    viewModel.selectedContentType = nil
                case .type(let t):
                    viewModel.selectedContentType = t
                }
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .black : ColorTokens.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? ColorTokens.gold : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - For You feed

    /// Applies the Quick/Long pseudo-types on top of `filteredExploreResults`.
    private var forYouFeedItems: [Content] {
        switch selectedFeedType {
        case .quick:
            return viewModel.filteredExploreResults.filter { ($0.duration ?? 0) > 0 && ($0.duration ?? 0) <= 300 }
        case .long:
            return viewModel.filteredExploreResults.filter { ($0.duration ?? 0) >= 900 }
        case .all, .type:
            return viewModel.filteredExploreResults
        }
    }

    @ViewBuilder
    private var forYouFeed: some View {
        let items = forYouFeedItems
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader(title: "For You", icon: "sparkles")

            if items.isEmpty {
                emptyForYou
            } else {
                LazyVStack(spacing: 20) {
                    ForEach(items) { content in
                        NavigationLink(value: content) {
                            FeedCard(content: content)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Trigger pagination when the last visible card
                            // appears. The VM no-ops if `hasMore == false`.
                            if content.id == items.last?.id {
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
                        .padding(.top, 8)
                } else if !viewModel.hasMore && !items.isEmpty {
                    Text("You're all caught up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    private var emptyForYou: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 26))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("Nothing matches this filter yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Try another type")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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

    // MARK: - Content Section (horizontal rail — used by Trending)

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
            Group {
                if content.contentType == .notes {
                    NotesThumbnail(title: content.title, domain: content.domain, pageCount: content.pageCount)
                } else if let url = content.thumbnailURL, let imageURL = URL(string: url) {
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

            Text(content.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 200, alignment: .leading)

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

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                if viewModel.isSearching && viewModel.searchResults.isEmpty && viewModel.searchCreatorResults.isEmpty {
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
                    emptySearchState
                } else {
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
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if content.contentType == .notes {
                        NotesThumbnail(title: content.title, domain: content.domain, pageCount: content.pageCount)
                    } else if let url = content.thumbnailURL, let imageURL = URL(string: url) {
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

    // MARK: - Empty / Loading

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

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonLoader(height: 50)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 80)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 200)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 200)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .padding(.top, Spacing.md)
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

    fileprivate func contentTypeBadge(_ type: ContentType) -> some View {
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

    fileprivate func thumbnailPlaceholder(for content: Content) -> some View {
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

    fileprivate func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - YouTube-style Feed Card

/// Full-width 16:9 feed card. Title and metadata sit BELOW the thumbnail —
/// not as an overlay — matching the YouTube mobile feed pattern.
private struct FeedCard: View {
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail: full width, 16:9, rounded.
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Group {
                        if content.contentType == .notes {
                            NotesThumbnail(
                                title: content.title,
                                domain: content.domain,
                                pageCount: content.pageCount
                            )
                        } else if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    feedPlaceholder
                                }
                            }
                        } else {
                            feedPlaceholder
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
                .overlay(alignment: .topLeading) {
                    typeBadge
                        .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    if !content.overlayBadge.isEmpty {
                        Text(content.overlayBadge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .padding(8)
                    }
                }
                .overlay(alignment: .center) {
                    if content.contentType == .video {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .aspectRatio(16.0/9.0, contentMode: .fit)

            // Title
            Text(content.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Metadata row
            metaRow
        }
    }

    private var typeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: content.contentType.badgeIcon)
                .font(.system(size: 9, weight: .bold))
            Text(content.contentType.badgeLabel)
                .font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(content.contentType.badgeColor)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }

    private var feedPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.surfaceElevated, ColorTokens.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: content.contentType == .video ? "play.fill" : "doc.text")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.gold.opacity(0.5))
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        let parts = buildMetaParts()
        HStack(spacing: 0) {
            if let creator = content.creatorId {
                HStack(spacing: 5) {
                    Circle()
                        .fill(creator.tier?.color ?? ColorTokens.gold)
                        .frame(width: 6, height: 6)
                    Text(creator.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
                if !parts.isEmpty {
                    Text(" · ")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            Text(parts.joined(separator: " · "))
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    /// Each non-empty piece: views, age, duration. Order matches YouTube.
    private func buildMetaParts() -> [String] {
        var parts: [String] = []
        if let views = content.viewCount, views > 0 {
            parts.append("\(formatCount(views)) views")
        }
        if let age = relativeAge(from: content.publishedAt) {
            parts.append(age)
        }
        let badge = content.overlayBadge
        if !badge.isEmpty {
            parts.append(badge)
        }
        return parts
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func relativeAge(from date: Date?) -> String? {
        guard let date else { return nil }
        let secs = Date().timeIntervalSince(date)
        guard secs >= 0 else { return nil }
        let mins = Int(secs / 60)
        if mins < 60 { return "\(max(mins, 1))m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        let weeks = days / 7
        if weeks < 5 { return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago" }
        let months = days / 30
        if months < 12 { return months <= 1 ? "1 month ago" : "\(months) months ago" }
        let years = days / 365
        return years <= 1 ? "1 year ago" : "\(years) years ago"
    }
}
