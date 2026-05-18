import Foundation

/// V2 Learn — "what should I study for my goal?" Pure objective-bound
/// curation. Discover (separate sheet) covers the broader library exploration.
///
/// Holds: hero pick, 2-3 goal-bound themed rails, master-your-#1-gap path
/// card, 5-min wins, continue-watching, and inline search (scoped to the
/// user's objective domain).
@Observable
@MainActor
final class V2LearnViewModel {
    var continueWatching: [Content] = []
    var recommendations: [Content] = []
    var trending: [Content] = []
    /// /recommendations/gaps — content that addresses the user's weakest topics.
    var gapFilling: [Content] = []
    /// Learning paths from /learning-paths/explore — used for the path card.
    var learningPaths: [LearningPath] = []
    /// Top gap from the user's diagnostic — drives "Master your #1 gap" card
    /// and is the primary source for themed-rail subtopics when the knowledge
    /// profile call fails.
    var topGap: V2HomeData.TopGap?
    /// The user's objective label, used to head every themed rail.
    var objectiveLabel: String?
    /// Per-topic mastery scores from /knowledge/profile. We pick the lowest-
    /// scoring 2-3 as the themed-rail seeds. Empty when the call fails.
    var topicMastery: [TopicMasteryEntry] = []

    var isLoading = false
    var error: String?

    // MARK: - Search state

    var searchText: String = ""
    var searchResults: [Content] = []
    var isSearching: Bool = false
    private var searchTask: Task<Void, Never>?

    var isShowingSearchResults: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let contentService = ContentService()
    private let userService = UserService()
    private let knowledgeService = KnowledgeService()

    // MARK: - Derived: hero

    /// Editorial hero — highest scoring recommendation by `heroScore`.
    /// Deterministic: ties break by id so the same data → same hero.
    var hero: Content? {
        guard !recommendations.isEmpty else { return nil }
        return recommendations.max { a, b in
            let sa = heroScore(a)
            let sb = heroScore(b)
            if sa != sb { return sa < sb }
            return a.id < b.id
        }
    }

    var recommendationsAfterHero: [Content] {
        guard let h = hero else { return recommendations }
        return recommendations.filter { $0.id != h.id }
    }

    // MARK: - Hero scoring (unchanged signal mix from v1 Learn)

    func heroScore(_ item: Content) -> Double {
        var score: Double = 0

        // 1. Gap fit.
        if let gap = topGap, itemMatchesTopic(item, topic: gap.topic) {
            score += 3.0
        }

        // 2. Novelty.
        let date = item.createdAt ?? item.publishedAt
        if let d = date {
            let days = Date().timeIntervalSince(d) / 86400
            if days <= 30 { score += 2.0 }
            else if days <= 90 { score += 1.0 }
        } else {
            score += 0.5
        }

        // 3. Popularity (log-saturated).
        if let views = item.viewCount, views > 0 {
            score += min(1.0, log10(Double(max(1, views))) / 5.0)
        } else if let likes = item.likeCount, likes > 0 {
            score += min(1.0, (log10(Double(max(1, likes))) / 5.0) * 0.5)
        }

        // 4. Duration fit.
        if let d = item.duration {
            let mins = Double(d) / 60.0
            if mins >= 8 && mins <= 20 { score += 1.0 }
            else if mins >= 5 && mins <= 30 { score += 0.5 }
        }

        return score
    }

    // MARK: - Themed rails (goal-bound)

    /// One themed rail — "FOR YOUR {OBJECTIVE} — {Subtopic}".
    struct ThemedRail: Identifiable {
        let id = UUID()
        let title: String
        let items: [Content]
    }

    /// At most 3 themed rails. Seeded from the lowest-mastery subtopics when
    /// the knowledge profile is available; falls back to a single
    /// topGap-themed rail; and finally to a single objective-only rail when
    /// neither subtopic source is reachable.
    var themedRails: [ThemedRail] {
        let objective = objectiveLabel?.uppercased() ?? "YOUR GOAL"
        let pool = uniqueByID(recommendations + trending)
        let used = Set([hero?.id].compactMap { $0 })

        // Source 1: knowledge profile subtopics (preferred).
        if !topicMastery.isEmpty {
            // Lowest scores first — these are the user's weakest subtopics.
            let weakest = topicMastery
                .sorted { ($0.score ?? 100) < ($1.score ?? 100) }
                .prefix(5)
            var rails: [ThemedRail] = []
            var taken = used
            for entry in weakest {
                if rails.count >= 3 { break }
                let matches = pool.filter { item in
                    !taken.contains(item.id) && itemMatchesTopic(item, topic: entry.topic)
                }
                guard matches.count >= 3 else { continue }
                let capped = Array(matches.prefix(8))
                capped.forEach { taken.insert($0.id) }
                let subtitle = prettyTopic(entry.topic).uppercased()
                rails.append(.init(
                    title: "FOR YOUR \(objective) — \(subtitle)",
                    items: capped
                ))
            }
            if !rails.isEmpty { return rails }
        }

        // Source 2: topGap-only rail.
        if let gap = topGap {
            let matches = pool.filter { !used.contains($0.id) && itemMatchesTopic($0, topic: gap.topic) }
            if matches.count >= 3 {
                return [.init(
                    title: "FOR YOUR \(objective) — \(prettyTopic(gap.topic).uppercased())",
                    items: Array(matches.prefix(8))
                )]
            }
        }

        // Source 3: pure objective fallback — top scored recs sans hero.
        let fallback = recommendationsAfterHero
            .sorted { heroScore($0) > heroScore($1) }
            .prefix(8)
        guard fallback.count >= 3 else { return [] }
        return [.init(title: "FOR YOUR \(objective)", items: Array(fallback))]
    }

    // MARK: - Path card

    /// Best matching path for the user's #1 gap. nil → caller hides the card.
    /// Only returns when there's a real topic match — we don't pick a random
    /// "best path" when no gap-aligned path exists.
    var gapPath: LearningPath? {
        guard !learningPaths.isEmpty, let gap = topGap else { return nil }
        let g = gap.topic.lowercased()
        let matched = learningPaths.filter { p in
            let d = (p.domain ?? "").lowercased()
            let t = p.title.lowercased()
            return matches(d, target: g) || matches(t, target: g)
        }
        // Highest rated among matches.
        return matched.max { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }
    }

    /// Heuristic readiness lift for the path card subtitle.
    var gapPathReadinessLift: Int {
        guard let p = gapPath else { return 0 }
        return min(15, max(3, p.itemCount * 2))
    }

    // MARK: - 5-min wins

    /// Anything in the personalized feed under 5 minutes that's tagged for the
    /// user's domain (or any item ≤5min when no objective is set).
    var fiveMinWins: [Content] {
        let pool = uniqueByID(recommendations + trending).filter { item in
            guard let d = item.duration, d > 0, d <= 300 else { return false }
            return matchesObjectiveDomain(item)
        }
        let hid = hero?.id
        return Array(pool.filter { $0.id != hid }.prefix(6))
    }

    // MARK: - Topic / objective matching helpers

    /// True when an item's topics/domain/title matches the supplied topic slug.
    private func itemMatchesTopic(_ item: Content, topic: String) -> Bool {
        let g = topic.lowercased()
        let topics = (item.topics ?? []).map { $0.lowercased() }
        let domain = item.domain?.lowercased() ?? ""
        let title = item.title.lowercased()
        if topics.contains(where: { matches($0, target: g) }) { return true }
        if matches(domain, target: g) { return true }
        if matches(title, target: g) { return true }
        return false
    }

    /// True when an item's domain matches the objective label. When no
    /// objective is set, always true so the rail isn't accidentally empty.
    private func matchesObjectiveDomain(_ item: Content) -> Bool {
        let key = (objectiveLabel ?? "").lowercased()
        guard !key.isEmpty else { return true }
        let d = (item.domain ?? "").lowercased()
        guard !d.isEmpty else { return false }
        return d.contains(key) || key.contains(d)
    }

    private func matches(_ s: String, target: String) -> Bool {
        guard !s.isEmpty else { return false }
        if s == target { return true }
        if s.contains(target) || target.contains(s) { return true }
        let words = target.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for w in words where w.count > 3 && s.contains(w) { return true }
        return false
    }

    private func uniqueByID(_ items: [Content]) -> [Content] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Pretty labels

    /// "critical-reasoning" → "Critical Reasoning"
    func prettyTopic(_ canonical: String) -> String {
        canonical
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil

        async let recsTask = (try? await contentService.fetchRecommendations()) ?? []
        async let trendingTask = (try? await contentService.fetchTrending()) ?? []
        async let continueTask = (try? await userService.fetchSavedContent()) ?? []
        async let gapsTask = (try? await contentService.fetchGapContent()) ?? []
        async let pathsTask = (try? await contentService.exploreLearningPaths(limit: 8)) ?? []

        let (recs, trend, cont, gaps, paths) = await (
            recsTask, trendingTask, continueTask, gapsTask, pathsTask
        )

        recommendations = Array(recs.prefix(20))
        trending = Array(trend.prefix(20))
        // Prefer items with non-zero progress when the field is populated;
        // otherwise just use the saved list as-is.
        let withProgress = cont.filter { ($0._progress?.progressPercentage ?? 0) > 0 }
        continueWatching = Array((withProgress.isEmpty ? cont : withProgress).prefix(6))
        gapFilling = Array(gaps.prefix(10))
        learningPaths = paths

        // V2 home payload — gives us topGap + objectiveLabel.
        if let home = try? await V2APIClient.shared.get("/plan/today") as V2APIResponse<V2HomeData> {
            topGap = home.data.topGap
            objectiveLabel = home.data.objectiveLabel
        }

        // Knowledge profile — drives subtopic-keyed themed rails. Failing this
        // is non-fatal; the VM falls back to topGap or a single objective rail.
        if let profile = try? await knowledgeService.getProfile() {
            topicMastery = profile.topicMastery ?? []
        }

        isLoading = false
    }

    // MARK: - Search (scoped to user's objective)

    /// Debounced search across the user's library — local-first, then a
    /// domain-filtered API call when an objective is set. Empty query clears.
    func search() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            try? await _Concurrency.Task.sleep(for: .milliseconds(350))
            guard let self, !_Concurrency.Task.isCancelled else { return }
            await self.performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        let lower = query.lowercased()

        // 1. Local pool — everything we already have, client-side filtered.
        let pool = uniqueByID(recommendations + trending + gapFilling + continueWatching)
        let scoped = pool.filter { matchesObjectiveDomain($0) }
        let localHits = scoped.filter { item in
            item.title.lowercased().contains(lower)
                || (item.domain?.lowercased().contains(lower) ?? false)
                || (item.topics?.contains(where: { $0.lowercased().contains(lower) }) ?? false)
                || (item.description?.lowercased().contains(lower) ?? false)
        }
        searchResults = localHits

        // 2. API call — domain-filtered when we have an objective so the
        // server narrows for us; otherwise unfiltered + client-side scope.
        let domain = objectiveLabel?.isEmpty == false ? objectiveLabel : nil
        let api = (try? await contentService.explore(
            search: query, domain: domain, page: 1, limit: 20
        )) ?? []

        // Defensive: if backend ignored the domain filter (or we passed none),
        // post-filter client-side to keep Learn's search promise honest.
        let apiScoped = api.filter { matchesObjectiveDomain($0) }

        var seen = Set(localHits.map { $0.id })
        var merged = localHits
        for item in apiScoped where seen.insert(item.id).inserted {
            merged.append(item)
        }
        searchResults = merged
        isSearching = false
    }

    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
    }
}
