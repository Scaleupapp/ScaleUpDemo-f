import SwiftUI

// MARK: - Discover View Model

@Observable
@MainActor
final class DiscoverViewModel {

    // MARK: - Content Sections

    var pickedForYou: [Content] = []
    var gapContent: [Content] = []
    var trendingContent: [Content] = []
    var creators: [CreatorSearchResult] = []

    /// First item from pickedForYou, used for the hero banner.
    var heroContent: Content? {
        pickedForYou.first
    }

    /// Picked-for-you items excluding the hero (to avoid duplication in carousel).
    var pickedForYouCarousel: [Content] {
        Array(pickedForYou.dropFirst())
    }

    // MARK: - State

    var isLoading = false
    var isRefreshing = false
    var error: APIError?

    // MARK: - Dependencies

    private let contentService: ContentService
    private let recommendationService: RecommendationService
    private let creatorService: CreatorService

    // MARK: - Init

    init(
        contentService: ContentService,
        recommendationService: RecommendationService,
        creatorService: CreatorService
    ) {
        self.contentService = contentService
        self.recommendationService = recommendationService
        self.creatorService = creatorService
    }

    // MARK: - Load Feed

    /// Fetches all feed sections concurrently. Each section loads independently
    /// so one failure doesn't block the rest.
    func loadFeed() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        await loadAllSections()
        isLoading = false
    }

    // MARK: - Refresh

    /// Re-fetches all sections without showing the full skeleton loader.
    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        error = nil

        await loadAllSections()
        isRefreshing = false
    }

    // MARK: - Load All Sections (resilient)

    /// Loads each data source independently so one failure doesn't block the rest.
    private func loadAllSections() async {
        let rs = recommendationService
        let cs = creatorService

        await withTaskGroup(of: DiscoverDataResult.self) { group in
            group.addTask { @Sendable in
                do {
                    let feed = try await rs.feed()
                    return .feed(feed)
                } catch {
                    print("‼️ DISCOVER FEED ERROR: \(error)")
                    return .failed("feed", error)
                }
            }
            group.addTask { @Sendable in
                do {
                    let gaps = try await rs.gaps()
                    return .gaps(gaps)
                } catch {
                    print("‼️ DISCOVER GAPS ERROR: \(error)")
                    return .failed("gaps", error)
                }
            }
            group.addTask { @Sendable in
                do {
                    let trending = try await rs.trending()
                    return .trending(trending)
                } catch {
                    print("‼️ DISCOVER TRENDING ERROR: \(error)")
                    return .failed("trending", error)
                }
            }
            group.addTask { @Sendable in
                do {
                    let creators = try await cs.search()
                    return .creators(creators)
                } catch {
                    print("‼️ DISCOVER CREATORS ERROR: \(error)")
                    return .failed("creators", error)
                }
            }

            var failCount = 0
            var lastError: APIError?

            for await result in group {
                switch result {
                case .feed(let feed):
                    self.pickedForYou = feed
                case .gaps(let gaps):
                    self.gapContent = gaps
                case .trending(let trending):
                    self.trendingContent = trending
                case .creators(let creators):
                    self.creators = creators
                case .failed(_, let err):
                    failCount += 1
                    lastError = err as? APIError ?? .unknown(0, err.localizedDescription)
                }
            }

            // Only show error if ALL sections failed
            if failCount == 4 {
                self.error = lastError
            }
        }
    }
}

// MARK: - Discover Data Result

private enum DiscoverDataResult: Sendable {
    case feed([Content])
    case gaps([Content])
    case trending([Content])
    case creators([CreatorSearchResult])
    case failed(String, Error)
}
