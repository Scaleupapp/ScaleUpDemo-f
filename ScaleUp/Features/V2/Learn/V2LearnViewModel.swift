import Foundation

@Observable
@MainActor
final class V2LearnViewModel {
    var continueWatching: [Content] = []
    var recommendations: [Content] = []
    var trending: [Content] = []
    /// Top gap from the user's diagnostic — used to derive "why this" reasons
    /// on recommendations ("Closes your gap on X").
    var topGap: V2HomeData.TopGap?
    /// The user's objective label, used for the trending section's "why this".
    var objectiveLabel: String?
    var isLoading = false
    var error: String?

    private let contentService = ContentService()
    private let userService = UserService()

    func load() async {
        isLoading = true
        error = nil

        async let recsTask = (try? await contentService.fetchRecommendations()) ?? []
        async let trendingTask = (try? await contentService.fetchTrending()) ?? []
        async let continueTask = (try? await userService.fetchSavedContent()) ?? []

        let (recs, trend, cont) = await (recsTask, trendingTask, continueTask)

        recommendations = Array(recs.prefix(8))
        trending = Array(trend.prefix(8))
        // Best-effort continue-watching surrogate from saved content until
        // ContentProgress filtering is available. Replace when v1 exposes a
        // dedicated "in progress" endpoint.
        continueWatching = Array(cont.prefix(4))

        // V2 home payload is @MainActor-isolated; await separately so the
        // strict concurrency checker is happy (it can't cross-actor an async
        // let return).
        if let home = try? await V2APIClient.shared.get("/plan/today") as V2APIResponse<V2HomeData> {
            topGap = home.data.topGap
            objectiveLabel = home.data.objectiveLabel
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
