import Foundation

@Observable
@MainActor
final class V2LearnViewModel {
    var continueWatching: [Content] = []
    var recommendations: [Content] = []
    var trending: [Content] = []
    /// /recommendations/gaps — content that addresses the user's weakest topics.
    var gapFilling: [Content] = []
    /// /recommendations/trending/notes — community notes trending right now.
    var trendingNotes: [Content] = []
    /// Learning paths from /learning-paths/explore — used for the path card.
    var learningPaths: [LearningPath] = []
    /// Similar-to-recently-watched (one fetch for the most recent saved item).
    /// Used to pick the "Because you watched" Made-For-You card.
    var similarToRecent: [Content] = []
    /// Top gap from the user's diagnostic — used to derive "why this" reasons
    /// on recommendations ("Closes your gap on X").
    var topGap: V2HomeData.TopGap?
    /// The user's objective label, used for the trending section's "why this".
    var objectiveLabel: String?
    var isLoading = false
    var error: String?

    private let contentService = ContentService()
    private let userService = UserService()

    /// Quick picks — anything in the personalized feed under 5 minutes.
    var quickPicks: [Content] {
        recommendations.filter { ($0.duration ?? 999) <= 300 }
    }

    /// Editorial hero — highest scoring recommendation by `heroScore`.
    /// Deterministic: ties break by id (string compare) so the same data → same hero.
    var hero: Content? {
        guard !recommendations.isEmpty else { return nil }
        return recommendations.max { a, b in
            let sa = heroScore(a)
            let sb = heroScore(b)
            if sa != sb { return sa < sb }
            return a.id < b.id  // deterministic tie-break
        }
    }

    /// Everything in `recommendations` except the hero — what the rails consume.
    var recommendationsAfterHero: [Content] {
        guard let h = hero else { return recommendations }
        return recommendations.filter { $0.id != h.id }
    }

    // MARK: - Hero scoring
    //
    // Signals used (matched to what's actually on `Content`):
    //  - gap_fit:       3.0 if title/topics/domain matches topGap.topic
    //  - novelty:       2.0 if createdAt/publishedAt ≤ 30 days
    //                   1.0 if ≤ 90 days; 0.5 if date is missing (neutral)
    //  - popularity:    min(1.0, log10(max(1, viewCount)) / 5)
    //                   fallback uses likeCount * 0.5 when viewCount is nil
    //  - duration_fit:  1.0 for 8-20 min, 0.5 for 5-30 min, 0 otherwise

    func heroScore(_ item: Content) -> Double {
        var score: Double = 0

        // 1. Gap fit
        if let gap = topGap, itemMatchesGap(item, gap: gap) {
            score += 3.0
        }

        // 2. Novelty
        let date = item.createdAt ?? item.publishedAt
        if let d = date {
            let age = Date().timeIntervalSince(d)
            let days = age / 86400
            if days <= 30 {
                score += 2.0
            } else if days <= 90 {
                score += 1.0
            }
        } else {
            // Neutral half-credit when date missing so undated items aren't fully
            // penalized vs older-but-dated ones.
            score += 0.5
        }

        // 3. Popularity (log-saturated, ~100K views → ~1.0)
        if let views = item.viewCount, views > 0 {
            score += min(1.0, log10(Double(max(1, views))) / 5.0)
        } else if let likes = item.likeCount, likes > 0 {
            // Fallback: rough proxy when viewCount missing.
            score += min(1.0, (log10(Double(max(1, likes))) / 5.0) * 0.5)
        }

        // 4. Duration fit
        if let d = item.duration {
            let mins = Double(d) / 60.0
            if mins >= 8 && mins <= 20 {
                score += 1.0
            } else if mins >= 5 && mins <= 30 {
                score += 0.5
            }
        }

        return score
    }

    private func itemMatchesGap(_ item: Content, gap: V2HomeData.TopGap) -> Bool {
        let g = gap.topic.lowercased()
        let topics = (item.topics ?? []).map { $0.lowercased() }
        let domain = item.domain?.lowercased() ?? ""
        let title = item.title.lowercased()
        if topics.contains(where: { matches($0, gap: g) }) { return true }
        if matches(domain, gap: g) { return true }
        if matches(title, gap: g) { return true }
        return false
    }

    // MARK: - Made For You

    /// Per-card distinct-reason picks for the MADE FOR YOU stack.
    struct MadeForYouCard: Identifiable {
        let content: Content
        let reasonTag: String     // short eyebrow
        let reasonDetail: String  // body line
        var id: String { content.id + "::" + reasonTag }
    }

    /// Up to 4 cards, one per reason bucket (gap fit → cohort proxy → similar
    /// to recently watched → objective fit). Skips buckets gracefully when no
    /// candidate exists, dedupes against the hero, and stops at 4 cards.
    var madeForYouCards: [MadeForYouCard] {
        var used = Set<String>()
        if let h = hero { used.insert(h.id) }
        var picks: [MadeForYouCard] = []

        // (1) Gap fit — top-gap-matching item not used as hero.
        if let gap = topGap {
            let pool = (recommendations + gapFilling)
                .filter { !used.contains($0.id) && itemMatchesGap($0, gap: gap) }
            // Prefer items with explicit gap-rail provenance, then by score.
            let pick = pool.max { heroScore($0) < heroScore($1) }
                ?? gapFilling.first(where: { !used.contains($0.id) })
            if let p = pick {
                used.insert(p.id)
                picks.append(.init(
                    content: p,
                    reasonTag: "CLOSES YOUR GAP",
                    reasonDetail: "Targets \(prettyTopic(gap.topic)) — currently \(gap.score)%."
                ))
            }
        }

        // (2) Cohort proxy — highest likeCount in user's domain (label match).
        let domainKey = (objectiveLabel ?? "").lowercased()
        let cohortPool: [Content] = {
            let base = recommendations + trending
            let filtered = base.filter { item in
                guard !used.contains(item.id) else { return false }
                guard !domainKey.isEmpty else { return true }
                let d = (item.domain ?? "").lowercased()
                return d.contains(domainKey) || domainKey.contains(d)
            }
            return filtered
        }()
        if let cohort = cohortPool.max(by: { ($0.likeCount ?? 0) < ($1.likeCount ?? 0) }),
           (cohort.likeCount ?? 0) > 0 {
            used.insert(cohort.id)
            let where_ = objectiveLabel?.isEmpty == false
                ? "POPULAR IN \(objectiveLabel!.uppercased())"
                : "POPULAR RIGHT NOW"
            picks.append(.init(
                content: cohort,
                reasonTag: where_,
                reasonDetail: "Liked by \(cohort.likeCount ?? 0) learners like you."
            ))
        }

        // (3) Similar to recently watched — uses /recommendations/similar/:id.
        // Pre-fetched into `similarToRecent` during load().
        if let sim = similarToRecent.first(where: { !used.contains($0.id) }) {
            used.insert(sim.id)
            picks.append(.init(
                content: sim,
                reasonTag: "BECAUSE YOU WATCHED",
                reasonDetail: "Builds on what you opened most recently."
            ))
        }

        // (4) Objective fit — highest-rated content where domain matches objective.
        let objPool = (recommendations + trending).filter { item in
            guard !used.contains(item.id) else { return false }
            guard !domainKey.isEmpty else { return false }
            let d = (item.domain ?? "").lowercased()
            return d.contains(domainKey) || domainKey.contains(d)
        }
        if let obj = objPool.max(by: { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }),
           (obj.averageRating ?? 0) > 0 {
            used.insert(obj.id)
            picks.append(.init(
                content: obj,
                reasonTag: "MATCHES YOUR GOAL",
                reasonDetail: "Aligned with your \(objectiveLabel ?? "current") goal."
            ))
        }

        // Backfill from highest-scored unused recs if we still have room.
        if picks.count < 4 {
            let extras = recommendationsAfterHero
                .filter { !used.contains($0.id) }
                .sorted { heroScore($0) > heroScore($1) }
            for ex in extras {
                if picks.count >= 4 { break }
                used.insert(ex.id)
                picks.append(.init(
                    content: ex,
                    reasonTag: "PICKED FOR YOU",
                    reasonDetail: reasonFor(ex)
                ))
            }
        }

        return Array(picks.prefix(4))
    }

    // MARK: - Path card

    /// Best matching path for the user — prefers gap-topic match, falls back to
    /// the highest-rated path in the user's objective domain. Returns nil if
    /// neither applies (caller hides the card).
    var heroPath: LearningPath? {
        guard !learningPaths.isEmpty else { return nil }

        if let gap = topGap {
            let g = gap.topic.lowercased()
            let matched = learningPaths.first { p in
                let d = (p.domain ?? "").lowercased()
                let t = p.title.lowercased()
                return matches(d, gap: g) || matches(t, gap: g)
            }
            if let m = matched { return m }
        }

        let domainKey = (objectiveLabel ?? "").lowercased()
        if !domainKey.isEmpty {
            let domainPaths = learningPaths.filter {
                let d = ($0.domain ?? "").lowercased()
                return d.contains(domainKey) || domainKey.contains(d)
            }
            if let best = domainPaths.max(by: { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }) {
                return best
            }
        }

        // Otherwise: just pick the highest-rated path overall so the card
        // remains useful even without an objective.
        return learningPaths.max { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }
    }

    // MARK: - New This Week / Hidden Gems
    //
    // Both rails derive client-side from the recommendations + trending pool
    // since the backend doesn't expose dedicated endpoints.

    var newThisWeek: [Content] {
        let pool = recommendations + trending
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        var seen = Set<String>()
        let recent = pool.filter { item in
            guard let d = item.createdAt ?? item.publishedAt else { return false }
            guard d >= cutoff else { return false }
            return seen.insert(item.id).inserted
        }
        return Array(
            recent.sorted { lhs, rhs in
                let l = lhs.createdAt ?? lhs.publishedAt ?? .distantPast
                let r = rhs.createdAt ?? rhs.publishedAt ?? .distantPast
                return l > r
            }.prefix(8)
        )
    }

    var hiddenGems: [Content] {
        let pool = recommendations + trending
        var seen = Set<String>()
        let gems = pool.filter { item in
            guard let rating = item.averageRating, rating >= 4.5 else { return false }
            // Low-view threshold — "undiscovered" by the cohort.
            let views = item.viewCount ?? 0
            guard views < 500 else { return false }
            return seen.insert(item.id).inserted
        }
        return Array(
            gems.sorted { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }.prefix(8)
        )
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil

        async let recsTask = (try? await contentService.fetchRecommendations()) ?? []
        async let trendingTask = (try? await contentService.fetchTrending()) ?? []
        async let continueTask = (try? await userService.fetchSavedContent()) ?? []
        async let gapsTask = (try? await contentService.fetchGapContent()) ?? []
        async let notesTask = (try? await contentService.fetchTrendingNotes()) ?? []
        async let pathsTask = (try? await contentService.exploreLearningPaths(limit: 8)) ?? []

        let (recs, trend, cont, gaps, notes, paths) = await (
            recsTask, trendingTask, continueTask, gapsTask, notesTask, pathsTask
        )

        recommendations = Array(recs.prefix(12))
        trending = Array(trend.prefix(10))
        // Best-effort continue-watching surrogate from saved content until
        // ContentProgress filtering is available. Replace when v1 exposes a
        // dedicated "in progress" endpoint.
        continueWatching = Array(cont.prefix(6))
        gapFilling = Array(gaps.prefix(10))
        trendingNotes = Array(notes.prefix(10))
        learningPaths = paths

        // V2 home payload is @MainActor-isolated; await separately so the
        // strict concurrency checker is happy (it can't cross-actor an async
        // let return).
        if let home = try? await V2APIClient.shared.get("/plan/today") as V2APIResponse<V2HomeData> {
            topGap = home.data.topGap
            objectiveLabel = home.data.objectiveLabel
        }

        // After everything else is set, fetch "similar to most recent" so the
        // BECAUSE YOU WATCHED card has candidates. Use continueWatching's first,
        // otherwise the highest-scored rec.
        let anchor = continueWatching.first ?? recommendations.first
        if let anchor {
            let similar = (try? await contentService.fetchSimilar(contentId: anchor.id, limit: 6)) ?? []
            // Dedupe against the anchor itself.
            similarToRecent = similar.filter { $0.id != anchor.id }
        } else {
            similarToRecent = []
        }

        isLoading = false
    }

    /// Pretty topic label — turns `critical-reasoning` into `Critical Reasoning`.
    func prettyTopic(_ canonical: String) -> String {
        canonical
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// "Why this" reason for a recommended content item, tied to user data.
    func reasonFor(_ item: Content) -> String {
        // 1. Gap match — content touches the user's weakest topic.
        if let gap = topGap {
            let gapSlug = gap.topic.lowercased()
            let topics = (item.topics ?? []).map { $0.lowercased() }
            let domain = item.domain?.lowercased() ?? ""
            let title = item.title.lowercased()
            if topics.contains(where: { matches($0, gap: gapSlug) })
                || matches(domain, gap: gapSlug)
                || matches(title, gap: gapSlug) {
                return "Closes your gap on \(prettyTopic(gap.topic)) — currently \(gap.score)%."
            }
        }
        // 2. Highly rated.
        if let rating = item.averageRating, rating >= 4.5 {
            return "Top-rated on \(prettyTopic(item.domain ?? "this topic"))."
        }
        if let likes = item.likeCount, likes >= 100 {
            return "Popular with \(prettyTopic(item.domain ?? "this domain")) learners."
        }
        // 3. Objective-relevant.
        if let label = objectiveLabel {
            return "For your \(label) goal."
        }
        return "Picked for you."
    }

    /// Gap-rail subtitle — names the topic and current score so the rail card
    /// can show "Critical Reasoning · 42%" without re-deriving it per cell.
    func gapSubtitle(for item: Content) -> String? {
        guard let gap = topGap else { return nil }
        return "\(prettyTopic(gap.topic)) · \(gap.score)%"
    }

    private func matches(_ s: String, gap: String) -> Bool {
        guard !s.isEmpty else { return false }
        if s == gap { return true }
        if s.contains(gap) || gap.contains(s) { return true }
        // Word-level overlap: "critical-reasoning" ↔ "critical reasoning"
        let gapWords = gap.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for w in gapWords where w.count > 3 && s.contains(w) { return true }
        return false
    }
}
