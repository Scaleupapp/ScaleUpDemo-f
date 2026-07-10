import SwiftUI

/// V2 Learn — "what should I study for my goal?"
///
/// Top-down: search → editorial hero → goal-bound themed rails → master-#1-gap
/// path card → 5-min wins → continue watching → "explore more" sheet to
/// Discover. All exploration/discovery surfaces live in Discover (separate
/// sheet) — Learn stays purely objective-bound.
struct V2LearnView: View {
    @State private var vm = V2LearnViewModel()
    @State private var showDiscover: Bool = false
    @State private var discoverInitialQuery: String = ""
    @FocusState private var searchFocused: Bool
    @Environment(V2TaskRouter.self) private var taskRouter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    searchBar
                        .padding(.horizontal, V2Theme.pad)
                        .padding(.top, 12)
                        .padding(.bottom, 14)

                    if vm.isShowingSearchResults {
                        searchResultsView
                            .padding(.horizontal, V2Theme.pad)
                    } else if vm.isLoading && vm.recommendations.isEmpty && vm.continueWatching.isEmpty {
                        loadingState
                            .padding(.horizontal, V2Theme.pad)
                    } else if everythingEmpty {
                        emptyState
                            .padding(.horizontal, V2Theme.pad)
                    } else {
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
        .sheet(isPresented: $showDiscover) {
            NavigationStack {
                DiscoverView(
                    initialSearchQuery: discoverInitialQuery.isEmpty ? nil : discoverInitialQuery
                )
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
        vm.hero == nil
            && vm.themedRails.isEmpty
            && vm.gapPath == nil
            && vm.fiveMinWins.isEmpty
            && vm.continueWatching.isEmpty
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            TextField("Search your learning library…", text: $vm.searchText)
                .font(.system(size: 15))
                .foregroundStyle(ColorTokens.textPrimary)
                .tint(ColorTokens.gold)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .onChange(of: vm.searchText) { vm.search() }

            if vm.isSearching {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(ColorTokens.gold)
            } else if !vm.searchText.isEmpty {
                Button {
                    vm.clearSearch()
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResultsView: some View {
        if vm.isSearching && vm.searchResults.isEmpty {
            VStack(spacing: 10) {
                ProgressView().tint(ColorTokens.gold)
                Text("Searching your library…")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else if vm.searchResults.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("No matches in your library.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                Button {
                    discoverInitialQuery = vm.searchText
                    showDiscover = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Search the full library")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.gold)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(vm.searchResults.count) RESULT\(vm.searchResults.count == 1 ? "" : "S")")
                    .v2Eyebrow()
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                LazyVStack(spacing: 12) {
                    ForEach(vm.searchResults, id: \.id) { item in
                        Button { openContent(item) } label: {
                            SearchResultRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("open-\(item.id)")
                    }
                }

                Button {
                    discoverInitialQuery = vm.searchText
                    showDiscover = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Search the full library")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTokens.gold.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
        }
    }

    // MARK: - Loaded layout

    @ViewBuilder
    private var loadedSections: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 1. Editorial hero
            if let hero = vm.hero {
                todayEyebrow
                EditorialHeroCard(item: hero, action: { openContent(hero) })
                    .accessibilityIdentifier("open-\(hero.id)")
                    .padding(.bottom, 26)
            }

            // 2. Themed rails — "FOR YOUR {OBJECTIVE} — {Subtopic}"
            ForEach(vm.themedRails) { rail in
                railHeader(rail.title)
                horizontalRail(items: rail.items)
                    .padding(.bottom, 26)
            }

            // 3. MASTER YOUR #1 GAP — full-width path card
            if let path = vm.gapPath {
                masterGapHeader
                GapPathCard(
                    path: path,
                    topicLabel: vm.topGap.map { vm.prettyTopic($0.topic) } ?? (path.domain ?? path.title),
                    readinessLift: vm.gapPathReadinessLift,
                    action: { openPath(path) }
                )
                .padding(.bottom, 26)
            }

            // 4. 5-MIN WINS
            if !vm.fiveMinWins.isEmpty {
                railHeader("5-MIN WINS")
                horizontalRail(items: vm.fiveMinWins)
                    .padding(.bottom, 26)
            }

            // 5. CONTINUE WHERE YOU LEFT OFF
            if !vm.continueWatching.isEmpty {
                railHeader("CONTINUE WHERE YOU LEFT OFF")
                horizontalRail(items: vm.continueWatching, showProgress: true)
                    .padding(.bottom, 26)
            }

            // 6. Bottom escape card → Discover
            exploreMoreCard
                .padding(.bottom, 12)
        }
    }

    // MARK: - Eyebrows / headers

    private var todayEyebrow: some View {
        HStack {
            Text("TODAY · \(todayLabel)")
                .v2Eyebrow()
            Spacer()
        }
        .padding(.bottom, 10)
    }

    private var masterGapHeader: some View {
        let topic = vm.topGap.map { vm.prettyTopic($0.topic).uppercased() } ?? "YOUR TOP GAP"
        return HStack {
            Text("MASTER YOUR #1 GAP — \(topic)")
                .v2Eyebrow()
            Spacer()
        }
        .padding(.bottom, 10)
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: Date()).uppercased()
    }

    private func railHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(ColorTokens.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
        }
        .padding(.bottom, 10)
    }

    // MARK: - Horizontal rail of cards

    private func horizontalRail(items: [Content], showProgress: Bool = false) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items, id: \.id) { item in
                    Button { openContent(item) } label: {
                        RailCard(item: item, showProgress: showProgress)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("open-\(item.id)")
                }
            }
        }
    }

    // MARK: - Explore More card

    private var exploreMoreCard: some View {
        Button {
            discoverInitialQuery = ""
            showDiscover = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.gold.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Want to explore more?")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Browse the full library")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .fill(ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V2Theme.cardRadius)
                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    /// Path tap — no dedicated path detail in v2 yet, so open Discover where
    /// the user can find and pursue paths.
    private func openPath(_ path: LearningPath) {
        discoverInitialQuery = ""
        showDiscover = true
    }

    // MARK: - Loading / empty

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading your library…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.gold.opacity(0.85))
            Text("Set your objective to get personalized recommendations")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                discoverInitialQuery = ""
                showDiscover = true
            } label: {
                HStack(spacing: 6) {
                    Text("Browse the library")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTokens.background)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ColorTokens.gold)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 28)
    }
}

// MARK: - Editorial hero card

/// App-Store-Today style hero — full-bleed 220pt thumbnail, strong bottom
/// gradient, "EDITOR'S PICK" gold eyebrow + title + meta in the bottom third.
/// No yellow CTA bar; whole card is tappable; play glyph in the top-right.
private struct EditorialHeroCard: View {
    let item: Content
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                thumbnail
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Strong bottom-only gradient — covers ~50% of the card.
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Text only lives in the bottom third.
                VStack(alignment: .leading, spacing: 8) {
                    Text("EDITOR'S PICK")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ColorTokens.gold)
                        .lineLimit(1)

                    Text(item.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    metaRow
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                    .padding(12)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// Bottom meta — creator/duration/rating/topic. Creator row is hidden
    /// entirely when missing or placeholder text, so the card never shows
    /// "Creator · …" filler.
    @ViewBuilder
    private var metaRow: some View {
        let creator = realCreatorName
        let duration = durationLabel
        let topic = topicLabel
        let rating = item.averageRating

        HStack(spacing: 6) {
            if let creator {
                Text(creator)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                dot
            }
            if !duration.isEmpty {
                Text(duration)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            if let r = rating, r > 0 {
                dot
                HStack(spacing: 2) {
                    Image(systemName: "star.fill").font(.system(size: 9))
                    Text(String(format: "%.1f", r))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ColorTokens.gold)
            }
            if let topic {
                dot
                Text(topic)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var dot: some View {
        Text("·").foregroundStyle(.white.opacity(0.55))
    }

    /// Filters out placeholder/blank creator names ("Creator", "", " ").
    private var realCreatorName: String? {
        guard let name = item.creatorId?.displayName else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.caseInsensitiveCompare("Creator") == .orderedSame { return nil }
        if trimmed.caseInsensitiveCompare("Unknown") == .orderedSame { return nil }
        return trimmed
    }

    private var durationLabel: String {
        if item.contentType == .notes, let p = item.pageCount, p > 0 {
            return "\(p) pages"
        }
        if let mins = item.duration.map({ Int(ceil(Double($0) / 60)) }), mins > 0 {
            return "\(mins) min"
        }
        return ""
    }

    private var topicLabel: String? {
        if let d = item.domain, !d.isEmpty { return d }
        return item.topics?.first
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
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
            colors: [ColorTokens.card, ColorTokens.surface],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: item.contentType == .notes ? "doc.text.image.fill" : "play.fill")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.gold.opacity(0.85))
        )
    }
}

// MARK: - Rail card

/// Reusable card for every horizontal rail — thumbnail on top, title + meta
/// below. Optional progress bar overlay for Continue Watching.
private struct RailCard: View {
    let item: Content
    var showProgress: Bool = false

    private let width: CGFloat = 170
    private let thumbHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                thumbnail
                    .frame(width: width, height: thumbHeight)
                    .clipped()

                if showProgress, let pct = progressPercent {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.black.opacity(0.4))
                            Rectangle()
                                .fill(ColorTokens.gold)
                                .frame(width: geo.size.width * CGFloat(pct) / 100)
                        }
                    }
                    .frame(height: 3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }

                if item.contentType == .notes {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("NOTES")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.65)))
                    .padding(6)
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

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(metaLine)
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(1)
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
            Image(systemName: item.contentType == .notes ? "doc.text.image.fill" : "play.fill")
                .foregroundStyle(ColorTokens.gold)
        )
    }

    private var metaLine: String {
        if item.contentType == .notes, let p = item.pageCount, p > 0 {
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

// MARK: - Search result row

/// Vertical-list row used in the search results pane. Matches Discover's row
/// language so the user feels at home.
private struct SearchResultRow: View {
    let item: Content

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                thumbnail
                    .frame(width: 110, height: 62)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if let domain = item.domain {
                        Text(domain)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    if let mins = item.duration.map({ Int(ceil(Double($0) / 60)) }), mins > 0 {
                        Text("\(mins) min")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    if let r = item.averageRating, r > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 8))
                            Text(String(format: "%.1f", r)).font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(ColorTokens.gold)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
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
            Image(systemName: item.contentType == .notes ? "doc.text.image.fill" : "play.fill")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.gold.opacity(0.6))
        )
    }
}

// MARK: - Master-your-#1-gap path card

/// Full-width gold card naming the gap topic, lesson count, ~duration, and
/// the heuristic readiness lift. Tap → opens path detail (via Discover).
private struct GapPathCard: View {
    let path: LearningPath
    let topicLabel: String
    let readinessLift: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Text(topicLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(path.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.background.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitleLine)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.background.opacity(0.9))

                HStack(spacing: 6) {
                    Text("Start path")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(ColorTokens.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(ColorTokens.background))
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

    private var subtitleLine: String {
        var parts: [String] = []
        let lessons = path.itemCount
        if lessons > 0 {
            parts.append("\(lessons) lesson\(lessons == 1 ? "" : "s")")
        }
        let dur = path.formattedDuration
        if !dur.isEmpty { parts.append("~\(dur)") }
        if readinessLift > 0 { parts.append("Lift readiness +\(readinessLift)%") }
        return parts.joined(separator: " · ")
    }
}

#Preview { V2LearnView().preferredColorScheme(.dark) }
