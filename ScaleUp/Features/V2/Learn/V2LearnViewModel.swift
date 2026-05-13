import Foundation

@Observable
@MainActor
final class V2LearnViewModel {
    var continueWatching: [Content] = []
    var recommendations: [Content] = []
    var trending: [Content] = []
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

        isLoading = false
    }
}
