import SwiftUI

/// V2 Learn Tab — App Store Today-style content discovery with a stronger
/// curation layer: scored editorial hero, vertical "Made For You" stack with
/// distinct per-card reasoning, optional path card, then themed rails.
struct V2LearnView: View {
    @State private var vm = V2LearnViewModel()
    @State private var discoverDestination: DiscoverDestination?
    @State private var activeFilter: LearnFilter = .all
    @Environment(V2TaskRouter.self) private var taskRouter

    // MARK: - Filter chips

    enum LearnFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case watch = "Watch"
        case read = "Read"
        case notes = "Notes"
        case quick = "Quick (≤5 min)"
        case long = "Long form (≥15 min)"

        var id: String { rawValue }

        func matches(_ c: Content) -> Bool {
            switch self {
            case .all:
                return true
            case .watch:
                return c.contentType == .video
            case .read:
                return c.contentType == .article || c.contentType == .infographic
            case .notes:
                return c.contentType == .notes
            case .quick:
                return (c.duration ?? 999) <= 300
            case .long:
                return (c.duration ?? 0) >= 900
            }
        }
    }

    /// Identifiable sheet target so the Discover destination can vary per
    /// Browse-by entry (topic / type / creator).
    struct DiscoverDestination: Identifiable {
        let filter: DiscoverView.InitialFilter
        var id: String {
            switch filter {
            case .none: return "none"
            case .topic: return "topic"
            case .type(let t): return "type-\(t.rawValue)"
            case .creator: return "creator"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Search — opens v1 Discover (full search + browse).
                    Button { discoverDestination = .init(filter: .none) } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text("Search topics, creators, videos…")
                                .font(V2Theme.body)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ColorTokens.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if vm.isLoading && vm.recommendations.isEmpty && vm.continueWatching.isEmpty {
                        loadingState
                    } else if everythingEmpty {
                        emptyState
                    } else {
                        loadedSections
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
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
    }

    // MARK: - Loaded layout

    @ViewBuilder
    private var loadedSections: some View {
        // 1. TODAY'S PICK — scored editorial hero.
        if let hero = vm.hero {
            todaysPickHeader
            EditorialHeroCard(
                item: hero,
                reasonTag: heroEyebrow(for: hero),
                creatorLabel: hero.creatorId?.displayName,
                action: { openContent(hero) }
            )
            .padding(.bottom, 6)
        }

        // 2. MADE FOR YOU — 4 cards, each with a DIFFERENT reason bucket.
        let cards = vm.madeForYouCards
        if !cards.isEmpty {
            railHeader("MADE FOR YOU · \(cards.count) picks", eyebrow: true)
            VStack(spacing: 10) {
                ForEach(cards) { card in
                    Button { openContent(card.content) } label: {
                        MadeForYouRowCard(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 14)
        }

        // 3. PATH CARD — only when a real path was matched.
        if let path = vm.heroPath {
            PathSpotlightCard(
                path: path,
                topicLabel: pathTopicLabel(for: path),
                action: { openPath(path) }
            )
            .padding(.bottom, 14)
        }

        // 4. CATEGORIES — chip strip moved up to just under the path card.
        chipsRow

        // 5. CONTINUE WATCHING.
        let continueFiltered = vm.continueWatching.filter(activeFilter.matches)
        if !continueFiltered.isEmpty {
            railHeader("Continue watching")
            mediumRail(items: continueFiltered, showProgress: true)
                .padding(.bottom, 14)
        }

        // 6. TRENDING IN {DOMAIN}.
        let trendingFiltered = vm.trending.filter(activeFilter.matches)
        if !trendingFiltered.isEmpty {
            railHeader(trendingHeader)
            mediumRail(items: trendingFiltered, large: true)
                .padding(.bottom, 14)
        }

        // 7. NEW THIS WEEK — derived client-side from createdAt/publishedAt.
        let newFiltered = vm.newThisWeek.filter(activeFilter.matches)
        if !newFiltered.isEmpty {
            railHeader("NEW THIS WEEK", eyebrow: true)
            mediumRail(items: newFiltered)
                .padding(.bottom, 14)
        }

        // 8. HIDDEN GEMS — high rating, low views.
        let gemsFiltered = vm.hiddenGems.filter(activeFilter.matches)
        if !gemsFiltered.isEmpty {
            railHeader("HIDDEN GEMS", eyebrow: true)
            mediumRail(items: gemsFiltered)
                .padding(.bottom, 14)
        }

        // 9. TRENDING NOTES.
        let notesFiltered = vm.trendingNotes.filter(activeFilter.matches)
        if !notesFiltered.isEmpty {
            railHeader("TRENDING NOTES", eyebrow: true)
            mediumRail(items: notesFiltered, isNotesRail: true)
                .padding(.bottom, 18)
        }

        // 10. BROWSE BY … — each entry opens Discover pre-positioned.
        Text("Browse another way".uppercased())
            .v2Eyebrow()
            .padding(.top, 4)
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
        .padding(.bottom, 2)
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

    // MARK: - Chips

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LearnFilter.allCases) { filter in
                    let isActive = activeFilter == filter
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isActive ? ColorTokens.background : ColorTokens.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    isActive ? ColorTokens.gold : ColorTokens.surface
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    isActive ? .clear : V2Theme.cardBorder,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Rail header

    private func railHeader(_ title: String, eyebrow: Bool = false) -> some View {
        HStack {
            if eyebrow {
                Text(title).v2Eyebrow()
            } else {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            Spacer()
            Button { discoverDestination = .init(filter: .none) } label: {
                Text("See all")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Medium rail

    private func mediumRail(
        items: [Content],
        large: Bool = false,
        showProgress: Bool = false,
        isNotesRail: Bool = false,
        subtitleBuilder: ((Content) -> String?)? = nil
    ) -> some View {
        let cardWidth: CGFloat = large ? 180 : 150
        let thumbHeight: CGFloat = large ? 108 : 90
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

    /// Path tap routes to Discover. There's no path-detail view yet, and
    /// DiscoverView is where learning paths live today. Matches existing pattern.
    private func openPath(_ path: LearningPath) {
        discoverDestination = .init(filter: .topic)
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

// MARK: - Made For You row card

/// Horizontal row used in the vertical Made-For-You stack. Left: 90×60 thumb.
/// Right: title, creator, reason eyebrow + body line, duration.
private struct MadeForYouRowCard: View {
    let card: V2LearnViewModel.MadeForYouCard

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
                .frame(width: 90, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(card.reasonTag)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(ColorTokens.gold)
                    .lineLimit(1)

                Text(card.content.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let creator = card.content.creatorId?.displayName, !creator.isEmpty {
                        Text(creator)
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .lineLimit(1)
                        Text("·")
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Text(metaLine)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }

                Text(card.reasonDetail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    private var metaLine: String {
        if card.content.contentType == .notes, let p = card.content.pageCount, p > 0 {
            return "\(p) pages"
        }
        if let mins = card.content.duration.map({ Int(ceil(Double($0) / 60)) }), mins > 0 {
            return "\(mins) min"
        }
        return card.content.contentType.rawValue.capitalized
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlStr = card.content.thumbnailURL, let url = URL(string: urlStr) {
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
            startPoint: .top, endPoint: .bottom
        )
        .overlay(
            Image(systemName: card.content.contentType == .notes
                  ? "doc.text.image.fill"
                  : "play.fill")
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.gold)
        )
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

                // Progress bar — 0% until per-path progress is plumbed.
                GeometryReader { geo in
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
