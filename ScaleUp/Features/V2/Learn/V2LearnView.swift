import SwiftUI

/// V2 Learn Tab — App Store Today-style content discovery.
/// Editorial hero → category chips → themed rails (gaps / continue /
/// trending / quick picks / notes) with one mid-list themed editorial card.
struct V2LearnView: View {
    @State private var vm = V2LearnViewModel()
    @State private var showDiscover = false
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Search — opens v1 Discover (full search + browse).
                    Button { showDiscover = true } label: {
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
        .sheet(isPresented: $showDiscover) {
            NavigationStack {
                DiscoverView()
                    .navigationTitle("Discover")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showDiscover = false }
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
    }

    // MARK: - Loaded layout

    @ViewBuilder
    private var loadedSections: some View {
        // 1. Editorial hero — the highest-scored recommendation, large.
        if let hero = vm.hero {
            EditorialHeroCard(
                item: hero,
                reason: vm.reasonFor(hero)
            ) {
                openContent(hero)
            }
            .padding(.bottom, 4)
        }

        // 2. Category chips row — client-side filter for the rails below.
        chipsRow

        // 3. Closes your gaps — gold-tinted eyebrow.
        let gapsFiltered = vm.gapFilling.filter(activeFilter.matches)
        if !gapsFiltered.isEmpty {
            railHeader("CLOSES YOUR GAPS", eyebrow: true)
            mediumRail(items: gapsFiltered, subtitleBuilder: vm.gapSubtitle)
                .padding(.bottom, 14)
        }

        // 4. Continue watching — slightly prettier card style.
        let continueFiltered = vm.continueWatching.filter(activeFilter.matches)
        if !continueFiltered.isEmpty {
            railHeader("Continue watching")
            mediumRail(items: continueFiltered, showProgress: true)
                .padding(.bottom, 14)
        }

        // 5. Trending in {domain}.
        let trendingFiltered = vm.trending.filter(activeFilter.matches)
        if !trendingFiltered.isEmpty {
            railHeader(trendingHeader)
            mediumRail(items: trendingFiltered, large: true)
                .padding(.bottom, 14)
        }

        // 6. Mid-list themed editorial card — only when we know the gap.
        if let gap = vm.topGap {
            ThemedTopicCard(
                title: "Master \(vm.prettyTopic(gap.topic)) in a week",
                subtitle: "A guided path — videos, notes, and quizzes — to push you past \(gap.score)%.",
                action: { showDiscover = true }
            )
            .padding(.bottom, 14)
        }

        // 7. Quick picks — ≤5 min from the personalized feed.
        let quickFiltered = vm.quickPicks.filter(activeFilter.matches)
        if !quickFiltered.isEmpty {
            railHeader("5-MINUTE READS", eyebrow: true)
            mediumRail(items: quickFiltered)
                .padding(.bottom, 14)
        }

        // 8. Trending notes — community notes with a 📝 glyph.
        let notesFiltered = vm.trendingNotes.filter(activeFilter.matches)
        if !notesFiltered.isEmpty {
            railHeader("TRENDING NOTES", eyebrow: true)
            mediumRail(items: notesFiltered, isNotesRail: true)
                .padding(.bottom, 18)
        }

        // Browse another way — quiet utility section at the bottom.
        Text("Browse another way".uppercased())
            .v2Eyebrow()
            .padding(.top, 4)
            .padding(.bottom, 4)
        VStack(spacing: 0) {
            browseLink(icon: "square.grid.2x2", label: "Browse by topic")
            browseLink(icon: "play.rectangle", label: "Browse by content type")
            browseLink(icon: "person.2", label: "Browse by creator")
        }
    }

    private var trendingHeader: String {
        if let label = vm.objectiveLabel, !label.isEmpty {
            return "Trending in \(label)"
        }
        return "Trending in your domain"
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
            Button { showDiscover = true } label: {
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

    // MARK: - Browse utility links

    private func browseLink(icon: String, label: String) -> some View {
        Button { showDiscover = true } label: {
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
/// scrim, gold "WHY THIS" eyebrow, prominent title. Used once at the top.
private struct EditorialHeroCard: View {
    let item: Content
    let reason: String
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
                    .frame(height: 140)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHY THIS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.gold)
                        Text(item.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            Text(item.contentType.rawValue.capitalized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("·")
                                .foregroundStyle(.white.opacity(0.6))
                            Text(durationLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(16)
                }

                Text(reason)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.surface)
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

// MARK: - Themed editorial card (mid-list)

/// Full-width topical CTA — e.g. "Master Critical Reasoning in a week".
/// Routes into Discover for now; can be wired to a filtered view later.
private struct ThemedTopicCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text("FEATURED PATH")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(ColorTokens.background)
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.background.opacity(0.8))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text("Start path")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ColorTokens.background)
                .padding(.top, 4)
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

#Preview { V2LearnView().preferredColorScheme(.dark) }
