import SwiftUI

/// V2 Learn Tab — App Store / Discover-style layout. Search → Type + Topic
/// filter chips → editorial hero → Top Creators strip → Picked For You rail
/// → Closes Your Gaps rail → Path spotlight → contextual rails → Browse-by.
///
/// All rails honour the Type + Topic chip filters at the top. "See all →" on
/// every rail opens DiscoverView pre-positioned at the matching section.
struct V2LearnView: View {
    @State private var vm = V2LearnViewModel()
    @State private var discoverDestination: DiscoverDestination?
    @Environment(V2TaskRouter.self) private var taskRouter

    /// Identifiable sheet target so the Discover destination can vary per
    /// Browse-by entry (topic / type / creator / section).
    struct DiscoverDestination: Identifiable {
        let filter: DiscoverView.InitialFilter
        var id: String {
            switch filter {
            case .none: return "none"
            case .topic: return "topic"
            case .type(let t): return "type-\(t.rawValue)"
            case .creator: return "creator"
            case .section(let s): return "section-\(s.rawValue)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // 1. Search — opens v1 Discover (full search + browse).
                    searchBar
                        .padding(.horizontal, V2Theme.pad)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    if vm.isLoading && vm.recommendations.isEmpty && vm.continueWatching.isEmpty {
                        loadingState
                            .padding(.horizontal, V2Theme.pad)
                    } else if everythingEmpty {
                        emptyState
                            .padding(.horizontal, V2Theme.pad)
                    } else {
                        // 2. Unified filter bar (Type + Topic chips) — Discover-styled.
                        unifiedFilterBar
                            .padding(.bottom, 18)

                        // 3+ : remaining sections.
                        loadedSections
                            .padding(.horizontal, V2Theme.pad)
                    }

                    Spacer().frame(height: 100)
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        .sheet(item: $discoverDestination) { dest in
            NavigationStack {
                DiscoverView(initialFilter: dest.filter)
                    .navigationTitle("Discover")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { discoverDestination = nil }
                        }
                    }
            }
        }
    }

    private var everythingEmpty: Bool {
        vm.continueWatching.isEmpty
        && vm.recommendations.isEmpty
        && vm.trending.isEmpty
        && vm.gapFilling.isEmpty
        && vm.trendingNotes.isEmpty
        && vm.newThisWeek.isEmpty
        && vm.hiddenGems.isEmpty
        && vm.learningPaths.isEmpty
        && vm.topCreators.isEmpty
    }

    // MARK: - Search bar (matches Discover)

    private var searchBar: some View {
        Button { discoverDestination = .init(filter: .none) } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("Search topics, creators, content...")
                    .font(.system(size: 15))
                    .foregroundStyle(ColorTokens.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Unified filter bar (mirror of DiscoverView.unifiedFilterBar)

    private var unifiedFilterBar: some View {
        VStack(spacing: 2) {
            filterRow(label: "Type") {
                typeChip(nil, label: "All")
                typeChip(.video, label: "Videos")
                typeChip(.notes, label: "Notes")
                typeChip(.article, label: "Articles")
                typeChip(.infographic, label: "Infographics")
            }

            if !vm.availableDomains.isEmpty {
                filterRow(label: "Topic") {
                    topicChip(nil, label: "All")
                    ForEach(vm.availableDomains, id: \.self) { domain in
                        topicChip(domain, label: domain)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface.opacity(0.4))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(ColorTokens.border.opacity(0.5)),
            alignment: .bottom
        )
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
        let isSelected = vm.selectedContentType == type
        return Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.selectedContentType = (vm.selectedContentType == type && type != nil) ? nil : type
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
        let isSelected = (domain == nil && vm.selectedDomain == nil) || vm.selectedDomain == domain
        return Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.selectedDomain = (vm.selectedDomain == domain && domain != nil) ? nil : domain
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

    // MARK: - Loaded layout

    @ViewBuilder
    private var loadedSections: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 3. TODAY'S PICK — scored editorial hero.
            if let hero = vm.hero {
                todaysPickHeader
                EditorialHeroCard(
                    item: hero,
                    reasonTag: heroEyebrow(for: hero),
                    creatorLabel: hero.creatorId?.displayName,
                    action: { openContent(hero) }
                )
                .padding(.bottom, 22)
            }

            // 4. TOP CREATORS.
            if !vm.topCreators.isEmpty {
                railHeader("Top Creators", icon: "person.2.fill") {
                    discoverDestination = .init(filter: .section(.creators))
                }
                topCreatorsStrip
                    .padding(.bottom, 22)
            }

            // 5. PICKED FOR YOU — horizontal rail of distinct-reason cards.
            let pickedCards = filteredMadeForYouCards()
            if !pickedCards.isEmpty {
                railHeader("Picked For You", icon: "sparkles") {
                    discoverDestination = .init(filter: .section(.picked))
                }
                pickedForYouRail(cards: pickedCards)
                    .padding(.bottom, 22)
            }

            // 6. CLOSES YOUR GAPS — yellow-bordered cards with Start Learning.
            let gaps = vm.filteredGapFilling
            if !gaps.isEmpty {
                railHeader("Closes Your Gaps", icon: "lightbulb.fill") {
                    discoverDestination = .init(filter: .section(.gaps))
                }
                gapRail(items: gaps)
                    .padding(.bottom, 22)
            }

            // 7. PATH SPOTLIGHT.
            if let path = vm.heroPath {
                PathSpotlightCard(
                    path: path,
                    topicLabel: pathTopicLabel(for: path),
                    action: { openPath(path) }
                )
                .padding(.bottom, 22)
            }

            // 8. CONTINUE WATCHING.
            let continueFiltered = vm.filteredContinueWatching
            if !continueFiltered.isEmpty {
                railHeader("Continue Watching", icon: "play.circle.fill") {
                    discoverDestination = .init(filter: .type(.video))
                }
                mediumRail(items: continueFiltered, showProgress: true)
                    .padding(.bottom, 22)
            }

            // 9. TRENDING IN {DOMAIN}.
            let trendingFiltered = vm.filteredTrending
            if !trendingFiltered.isEmpty {
                railHeader(trendingHeader, icon: "flame.fill") {
                    discoverDestination = .init(filter: .section(.trending))
                }
                mediumRail(items: trendingFiltered, large: true)
                    .padding(.bottom, 22)
            }

            // 10. NEW THIS WEEK.
            let newFiltered = vm.filteredNewThisWeek
            if !newFiltered.isEmpty {
                railHeader("New This Week", icon: "sparkle") {
                    discoverDestination = .init(filter: .none)
                }
                mediumRail(items: newFiltered)
                    .padding(.bottom, 22)
            }

            // 11. HIDDEN GEMS.
            let gemsFiltered = vm.filteredHiddenGems
            if !gemsFiltered.isEmpty {
                railHeader("Hidden Gems", icon: "diamond.fill") {
                    discoverDestination = .init(filter: .section(.browse))
                }
                mediumRail(items: gemsFiltered)
                    .padding(.bottom, 22)
            }

            // 12. TRENDING NOTES.
            let notesFiltered = vm.filteredTrendingNotes
            if !notesFiltered.isEmpty {
                railHeader("Trending Notes", icon: "doc.text.fill") {
                    discoverDestination = .init(filter: .type(.notes))
                }
                mediumRail(items: notesFiltered, isNotesRail: true)
                    .padding(.bottom, 22)
            }

            // 13. BROWSE BY … — each entry opens Discover pre-positioned.
            Text("Browse another way".uppercased())
                .v2Eyebrow()
                .padding(.top, 6)
                .padding(.bottom, 4)
            VStack(spacing: 0) {
                browseLink(icon: "square.grid.2x2", label: "Browse by topic") {
                    discoverDestination = .init(filter: .topic)
                }
                browseLink(icon: "play.rectangle", label: "Browse videos") {
                    discoverDestination = .init(filter: .type(.video))
                }
                browseLink(icon: "person.2", label: "Browse by creator") {
                    discoverDestination = .init(filter: .creator)
                }
            }
        }
    }

    // MARK: - Made For You filtering

    /// Apply chip filters to the per-card distinct-reason picks. We filter
    /// the underlying `content`, preserving each card's reasonTag + detail.
    private func filteredMadeForYouCards() -> [V2LearnViewModel.MadeForYouCard] {
        let cards = vm.madeForYouCards
        let type = vm.selectedContentType
        let domain = vm.selectedDomain?.lowercased()
        guard type != nil || domain != nil else { return cards }
        return cards.filter { card in
            let typeOK = type.map { card.content.contentType == $0 } ?? true
            let domainOK = domain.map { (card.content.domain?.lowercased() ?? "") == $0 } ?? true
            return typeOK && domainOK
        }
    }

    private var trendingHeader: String {
        if let label = vm.objectiveLabel, !label.isEmpty {
            return "Trending in \(label)"
        }
        return "Trending in your domain"
    }

    private var todaysPickHeader: some View {
        HStack {
            Text("TODAY'S PICK").v2Eyebrow()
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func heroEyebrow(for item: Content) -> String {
        if let gap = vm.topGap, vm.heroScore(item) >= 3 {
            return "EDITOR'S CHOICE · FOR YOUR \(vm.prettyTopic(gap.topic).uppercased())"
        }
        if let label = vm.objectiveLabel, !label.isEmpty {
            return "EDITOR'S CHOICE · FOR \(label.uppercased())"
        }
        return "EDITOR'S CHOICE"
    }

    private func pathTopicLabel(for path: LearningPath) -> String {
        if let gap = vm.topGap {
            return vm.prettyTopic(gap.topic)
        }
        return path.domain ?? path.title
    }

    // MARK: - Top Creators strip (mirror of DiscoverView.creatorsSection)

    private var topCreatorsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(vm.topCreators) { creator in
                    Button { openCreator(creator) } label: {
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
        }
    }

    // MARK: - Picked For You rail (horizontal cards with reason eyebrow)

    private func pickedForYouRail(cards: [V2LearnViewModel.MadeForYouCard]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(cards) { card in
                    Button { openContent(card.content) } label: {
                        PickedForYouCard(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Gap rail (Discover's gapSection treatment)

    private func gapRail(items: [Content]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items, id: \.id) { item in
                    Button { openContent(item) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.warning)
                                if let domain = item.domain {
                                    Text(domain)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(ColorTokens.warning)
                                }
                                Spacer()
                            }

                            Text(item.title)
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
        }
    }

    // MARK: - Rail header (with See all)

    private func railHeader(_ title: String, icon: String? = nil, seeAll: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
            }
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: seeAll) {
                HStack(spacing: 2) {
                    Text("See all")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(ColorTokens.gold)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 10)
    }

    // MARK: - Medium rail

    private func mediumRail(
        items: [Content],
        large: Bool = false,
        showProgress: Bool = false,
        isNotesRail: Bool = false,
        subtitleBuilder: ((Content) -> String?)? = nil
    ) -> some View {
        let cardWidth: CGFloat = large ? 200 : 170
        let thumbHeight: CGFloat = large ? 112 : 96
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items, id: \.id) { item in
                    Button { openContent(item) } label: {
                        MediumRailCard(
                            item: item,
                            width: cardWidth,
                            thumbHeight: thumbHeight,
                            showProgress: showProgress,
                            isNotes: isNotesRail || item.contentType == .notes,
                            subtitle: subtitleBuilder?(item)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Routing

    private func openContent(_ item: Content) {
        taskRouter.open(
            taskType: "watch",
            payload: V2HomeData.Payload(
                contentId: item.id,
                quizId: nil,
                interviewId: nil,
                url: nil,
                weekNumber: nil,
                challengeId: nil,
                topic: nil
            ),
            title: item.title
        )
    }

    /// Path tap routes to Discover (paths section).
    private func openPath(_ path: LearningPath) {
        discoverDestination = .init(filter: .section(.paths))
    }

    /// Creator tap opens Discover scrolled to the creators strip — there's no
    /// in-line CreatorProfileView push from this sheet-presented context.
    private func openCreator(_ creator: Creator) {
        discoverDestination = .init(filter: .creator)
    }

    // MARK: - Browse utility links

    private func browseLink(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 28, height: 28)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(label)
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading / Empty

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading recommendations…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📚").font(.system(size: 32))
            Text("Nothing here yet")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Once you set an objective, we'll surface content tailored for it.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

// MARK: - Editorial hero card

/// Full-width "Today's pick" treatment — large thumbnail with gradient
/// scrim, gold eyebrow naming the reason, title + meta + watch CTA.
private struct EditorialHeroCard: View {
    let item: Content
    let reasonTag: String
    let creatorLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    thumbnail
                        .frame(height: 220)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 160)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(reasonTag)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.gold)
                            .lineLimit(1)
                        Text(item.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            if let creator = creatorLabel, !creator.isEmpty {
                                Text(creator)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                Text("·").foregroundStyle(.white.opacity(0.6))
                            }
                            if let rating = item.averageRating, rating > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                    Text(String(format: "%.1f", rating))
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundStyle(ColorTokens.gold)
                                Text("·").foregroundStyle(.white.opacity(0.6))
                            }
                            Text(durationLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                            if let views = item.viewCount, views > 0 {
                                Text("·").foregroundStyle(.white.opacity(0.6))
                                Text("\(formatCount(views)) views")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(16)
                }

                HStack(spacing: 6) {
                    Text("Watch now")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ColorTokens.background)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.gold)
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: V2Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    heroPlaceholder
                }
            }
        } else {
            heroPlaceholder
        }
    }

    private var heroPlaceholder: some View {
        LinearGradient(
            colors: [ColorTokens.card, ColorTokens.surface],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: item.contentType == .notes ? "doc.text.image.fill" : "play.fill")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.gold.opacity(0.85))
        )
    }

    private var durationLabel: String {
        if item.contentType == .notes, let p = item.pageCount, p > 0 {
            return "\(p) pages"
        }
        if let mins = item.duration.map({ Int(ceil(Double($0) / 60)) }), mins > 0 {
            return "\(mins) min"
        }
        return "—"
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Picked For You card

/// Discover-style content card with the per-card reason as a gold eyebrow
/// above the title. Preserves the distinct-reason buckets from the VM.
private struct PickedForYouCard: View {
    let card: V2LearnViewModel.MadeForYouCard

    private var content: Content { card.content }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                thumbnail
                    .frame(width: 200, height: 112)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
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

            // Reason eyebrow (gold) — this is what differentiates the card.
            Text(card.reasonTag)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(ColorTokens.gold)
                .lineLimit(1)

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
                }
                Spacer()
                if let mins = content.duration.map({ Int(ceil(Double($0) / 60)) }), mins > 0 {
                    Text("\(mins) min")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .frame(width: 200)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlStr = content.thumbnailURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [ColorTokens.surfaceElevated, ColorTokens.surface],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: content.contentType == .notes ? "doc.text.image.fill" : "play.fill")
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.gold.opacity(0.5))
        )
    }

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
}

// MARK: - Path spotlight card

/// Full-width "Master {topic}" path card with item count, duration, and a
/// progress bar (zero until per-item progress is plumbed through).
private struct PathSpotlightCard: View {
    let path: LearningPath
    let topicLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Text("MASTER \(topicLabel.uppercased())")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(ColorTokens.background)
                    .lineLimit(1)

                Text(path.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let desc = path.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.background.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if path.itemCount > 0 {
                        Label("\(path.itemCount) lessons", systemImage: "list.bullet")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    if !path.formattedDuration.isEmpty {
                        Label("~\(path.formattedDuration)", systemImage: "clock")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    if let r = path.averageRating, r > 0 {
                        Label(String(format: "%.1f", r), systemImage: "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundStyle(ColorTokens.background.opacity(0.9))

                GeometryReader { _ in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ColorTokens.background.opacity(0.25))
                        Capsule()
                            .fill(ColorTokens.background)
                            .frame(width: 0)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 6) {
                    Text("Start")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(ColorTokens.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ColorTokens.background))
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [ColorTokens.goldLight, ColorTokens.gold],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: V2Theme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medium rail card

/// Reusable card for every horizontal rail — thumbnail on top, title +
/// metadata below. Picks up progress bar overlay or notes glyph as needed.
private struct MediumRailCard: View {
    let item: Content
    let width: CGFloat
    let thumbHeight: CGFloat
    let showProgress: Bool
    let isNotes: Bool
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                thumbnail
                    .frame(width: width, height: thumbHeight)
                    .clipped()

                if isNotes {
                    HStack(spacing: 3) {
                        Text("📝")
                        Text("NOTES")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.65)))
                    .padding(6)
                }

                if showProgress, let pct = progressPercent {
                    VStack(spacing: 0) {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(.black.opacity(0.4))
                                Rectangle()
                                    .fill(ColorTokens.gold)
                                    .frame(width: geo.size.width * CGFloat(pct) / 100)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
            .clipShape(
                .rect(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 12
                )
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.gold)
                        .lineLimit(1)
                } else {
                    Text(metaLine)
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: width, alignment: .leading)
        }
        .frame(width: width)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    railPlaceholder
                }
            }
        } else {
            railPlaceholder
        }
    }

    private var railPlaceholder: some View {
        LinearGradient(
            colors: [ColorTokens.surfaceElevated, ColorTokens.surface],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(
            Image(systemName: isNotes ? "doc.text.image.fill" : "play.fill")
                .foregroundStyle(ColorTokens.gold)
        )
    }

    private var metaLine: String {
        if isNotes, let p = item.pageCount, p > 0 {
            return "\(p) pages"
        }
        if let mins = item.duration.map({ Int(ceil(Double($0) / 60)) }), mins > 0 {
            return "\(mins) min"
        }
        return item.contentType.rawValue.capitalized
    }

    private var progressPercent: Int? {
        guard let pct = item._progress?.progressPercentage, pct > 0 else { return nil }
        return min(100, pct)
    }
}

#Preview { V2LearnView().preferredColorScheme(.dark) }
