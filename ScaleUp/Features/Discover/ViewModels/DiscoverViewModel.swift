import SwiftUI

@Observable
@MainActor
final class DiscoverViewModel {

    // MARK: - State

    var searchText = ""
    var isLoading = false
    var selectedDomain: String?
    var selectedContentType: ContentType?

    // Browse sections
    var recommendations: [Content] = []
    var trending: [Content] = []
    var gapContent: [Content] = []
    var creators: [Creator] = []
    var learningPaths: [LearningPath] = []

    // Search results
    var searchResults: [Content] = []
    var searchCreatorResults: [Creator] = []
    var isSearching = false

    // Explore grid
    var exploreResults: [Content] = []
    var selectedDifficulty: Difficulty?
    var currentPage = 1
    var hasMore = true
    var isLoadingMore = false

    // Available domains from content
    var availableDomains: [String] = []

    private let contentService = ContentService()
    private var searchTask: Task<Void, Never>?

    // MARK: - Computed

    var featuredContent: Content? {
        filteredRecommendations.first
    }

    var pickedForYou: [Content] {
        Array(filteredRecommendations.dropFirst())
    }

    var filteredRecommendations: [Content] {
        guard let type = selectedContentType else { return recommendations }
        return recommendations.filter { $0.contentType == type }
    }

    var filteredTrending: [Content] {
        guard let type = selectedContentType else { return trending }
        return trending.filter { $0.contentType == type }
    }

    var filteredExploreResults: [Content] {
        guard let type = selectedContentType else { return exploreResults }
        return exploreResults.filter { $0.contentType == type }
    }

    var isShowingSearchResults: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasAnyFeedContent: Bool {
        !recommendations.isEmpty || !trending.isEmpty || !gapContent.isEmpty ||
        !creators.isEmpty || !learningPaths.isEmpty || !exploreResults.isEmpty
    }

    // All content for local search fallback
    var allLocalContent: [Content] {
        let combined = recommendations + trending + gapContent + exploreResults
        var seen = Set<String>()
        return combined.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Load Feed

    func loadFeed() async {
        isLoading = true

        async let recsTask: [Content] = {
            (try? await self.contentService.fetchRecommendations()) ?? []
        }()
        async let trendTask: [Content] = {
            (try? await self.contentService.fetchTrending()) ?? []
        }()
        async let gapTask: [Content] = {
            (try? await self.contentService.fetchGapContent()) ?? []
        }()
        async let creatorsTask: [Creator] = {
            (try? await self.contentService.searchCreators(limit: 10)) ?? []
        }()
        async let pathsTask: [LearningPath] = {
            (try? await self.contentService.exploreLearningPaths(limit: 6)) ?? []
        }()
        async let exploreTask: [Content] = {
            (try? await self.contentService.explore(page: 1, limit: 30)) ?? []
        }()

        let (recs, trend, gap, crs, paths, explore) = await (
            recsTask, trendTask, gapTask, creatorsTask, pathsTask, exploreTask
        )

        recommendations = recs
        trending = trend
        gapContent = gap
        creators = crs
        learningPaths = paths
        exploreResults = explore

        // Extract unique domains
        let allContent = recs + trend + gap + explore
        let domains = Set(allContent.compactMap { $0.domain })
        availableDomains = domains.sorted()

        // Ensure explore has data even if API explore fails
        if exploreResults.isEmpty && !recommendations.isEmpty {
            var seen = Set<String>()
            exploreResults = (recommendations + trending + gapContent).filter { seen.insert($0.id).inserted }
        }

        isLoading = false
    }

    // MARK: - Search

    func search() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            isSearching = false
            searchResults = []
            searchCreatorResults = []
            return
        }

        // Set searching immediately so UI shows loading state during debounce
        isSearching = true

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            let lowerQuery = query.lowercased()

            // Always search local data first (instant results)
            let localContent = allLocalContent.filter { item in
                item.title.lowercased().contains(lowerQuery) ||
                (item.domain?.lowercased().contains(lowerQuery) ?? false) ||
                (item.topics?.contains(where: { $0.lowercased().contains(lowerQuery) }) ?? false) ||
                (item.tags?.contains(where: { $0.lowercased().contains(lowerQuery) }) ?? false) ||
                (item.description?.lowercased().contains(lowerQuery) ?? false)
            }
            let localCreators = creators.filter { creator in
                creator.displayName.lowercased().contains(lowerQuery) ||
                (creator.bio?.lowercased().contains(lowerQuery) ?? false) ||
                (creator.username?.lowercased().contains(lowerQuery) ?? false)
            }

            // Show local results immediately
            searchResults = localContent
            searchCreatorResults = localCreators

            // Try API to supplement
            async let contentTask: [Content] = {
                (try? await self.contentService.explore(search: query, page: 1, limit: 20)) ?? []
            }()
            async let creatorTask: [Creator] = {
                (try? await self.contentService.searchCreators(search: query, limit: 10)) ?? []
            }()

            let (apiContent, apiCreators) = await (contentTask, creatorTask)
            guard !Task.isCancelled else { return }

            // Merge API results with local (deduplicated)
            if !apiContent.isEmpty {
                var seen = Set(localContent.map { $0.id })
                var merged = localContent
                for item in apiContent where seen.insert(item.id).inserted {
                    merged.append(item)
                }
                searchResults = merged
            }
            if !apiCreators.isEmpty {
                var seen = Set(localCreators.map { $0.id })
                var merged = localCreators
                for creator in apiCreators where seen.insert(creator.id).inserted {
                    merged.append(creator)
                }
                searchCreatorResults = merged
            }

            isSearching = false
        }
    }

    // MARK: - Domain Filter

    func filterByDomain(_ domain: String?) async {
        selectedDomain = domain
        currentPage = 1
        hasMore = true

        if let domain {
            if let results = try? await contentService.explore(domain: domain, page: 1, limit: 20), !results.isEmpty {
                exploreResults = results
                hasMore = results.count >= 20
            } else {
                // Fallback: filter all loaded data
                let lowerDomain = domain.lowercased()
                let all = recommendations + trending + gapContent
                var seen = Set<String>()
                exploreResults = all.filter { item in
                    seen.insert(item.id).inserted && (item.domain?.lowercased() == lowerDomain)
                }
                hasMore = false
            }
        } else {
            if let results = try? await contentService.explore(page: 1, limit: 30), !results.isEmpty {
                exploreResults = results
                hasMore = results.count >= 20
            } else {
                // Fallback: show all loaded content
                var seen = Set<String>()
                exploreResults = (recommendations + trending + gapContent).filter { seen.insert($0.id).inserted }
                hasMore = false
            }
        }
    }

    // MARK: - Load More

    func loadMoreExplore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        currentPage += 1

        if let results = try? await contentService.explore(
            domain: selectedDomain,
            difficulty: selectedDifficulty?.rawValue,
            page: currentPage
        ) {
            exploreResults.append(contentsOf: results)
            hasMore = results.count >= 20
        } else {
            hasMore = false
        }

        isLoadingMore = false
    }

    // MARK: - Mock Data

    private func loadMockData() {
        let mockCreators = [
            Creator(id: "c1", firstName: "Sarah", lastName: "Johnson", username: "sarahj", profilePicture: nil, bio: "Product leader & educator", tier: .anchor, followersCount: 12400, contentCount: 45, averageRating: 4.7),
            Creator(id: "c2", firstName: "Alex", lastName: "Chen", username: "alexc", profilePicture: nil, bio: "Data science mentor", tier: .core, followersCount: 8200, contentCount: 32, averageRating: 4.5),
            Creator(id: "c3", firstName: "Priya", lastName: "Sharma", username: "priyas", profilePicture: nil, bio: "SEO & digital marketing expert", tier: .rising, followersCount: 3100, contentCount: 18, averageRating: 4.3),
            Creator(id: "c4", firstName: "Marcus", lastName: "Wright", username: "marcusw", profilePicture: nil, bio: "System design expert", tier: .core, followersCount: 5600, contentCount: 24, averageRating: 4.6)
        ]

        creators = mockCreators

        let mockContent: [Content] = [
            Content(id: "d1", creatorId: mockCreators[0], title: "The Art of Product Roadmapping", description: "Master roadmapping from day one", contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1560, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["Roadmapping"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 18300, likeCount: 1200, commentCount: 67, saveCount: 890, averageRating: 4.8, ratingCount: 234, publishedAt: Date().addingTimeInterval(-86400 * 2), createdAt: nil),
            Content(id: "d2", creatorId: mockCreators[1], title: "Machine Learning Basics with Python", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 2400, sourceType: .youtube, sourceAttribution: nil, domain: "Data Science", topics: ["ML", "Python"], tags: nil, difficulty: .beginner, aiData: nil, status: .published, viewCount: 32100, likeCount: 2100, commentCount: 134, saveCount: 1500, averageRating: 4.7, ratingCount: 456, publishedAt: Date().addingTimeInterval(-86400 * 1), createdAt: nil),
            Content(id: "d3", creatorId: mockCreators[2], title: "SEO Fundamentals: Complete Guide", description: "Everything you need to know about search engine optimization and digital marketing", contentType: .article, contentURL: nil, thumbnailURL: nil, duration: 600, sourceType: .original, sourceAttribution: nil, domain: "Digital Marketing", topics: ["SEO", "Marketing", "Digital Marketing"], tags: ["seo", "search", "optimization", "marketing"], difficulty: .beginner, aiData: nil, status: .published, viewCount: 45200, likeCount: 3400, commentCount: 210, saveCount: 2800, averageRating: 4.5, ratingCount: 567, publishedAt: Date().addingTimeInterval(-86400 * 4), createdAt: nil),
            Content(id: "d4", creatorId: mockCreators[3], title: "System Design Interview: Complete Guide", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 3600, sourceType: .original, sourceAttribution: nil, domain: "Engineering", topics: ["System Design"], tags: nil, difficulty: .advanced, aiData: nil, status: .published, viewCount: 27800, likeCount: 1800, commentCount: 98, saveCount: 1200, averageRating: 4.9, ratingCount: 345, publishedAt: Date().addingTimeInterval(-86400 * 3), createdAt: nil),
            Content(id: "d5", creatorId: mockCreators[0], title: "Metrics That Matter for PMs", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1200, sourceType: .original, sourceAttribution: nil, domain: "Product Management", topics: ["Metrics", "Analytics"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 9800, likeCount: 670, commentCount: 34, saveCount: 450, averageRating: 4.6, ratingCount: 123, publishedAt: Date().addingTimeInterval(-86400 * 6), createdAt: nil),
            Content(id: "d6", creatorId: mockCreators[1], title: "Data Visualization with Tableau", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 1800, sourceType: .youtube, sourceAttribution: nil, domain: "Data Science", topics: ["Visualization", "Tableau"], tags: nil, difficulty: .beginner, aiData: nil, status: .published, viewCount: 15600, likeCount: 980, commentCount: 45, saveCount: 670, averageRating: 4.4, ratingCount: 189, publishedAt: Date().addingTimeInterval(-86400 * 5), createdAt: nil),
            Content(id: "d7", creatorId: mockCreators[2], title: "Advanced SEO Strategies for 2026", description: "Take your SEO and marketing to the next level with advanced techniques", contentType: .article, contentURL: nil, thumbnailURL: nil, duration: 420, sourceType: .original, sourceAttribution: nil, domain: "Digital Marketing", topics: ["SEO", "Content Marketing", "Digital Marketing"], tags: ["seo", "advanced", "marketing"], difficulty: .advanced, aiData: nil, status: .published, viewCount: 8900, likeCount: 560, commentCount: 28, saveCount: 340, averageRating: 4.3, ratingCount: 87, publishedAt: Date().addingTimeInterval(-86400 * 7), createdAt: nil),
            Content(id: "d8", creatorId: mockCreators[3], title: "API Design Best Practices", description: nil, contentType: .video, contentURL: nil, thumbnailURL: nil, duration: 2100, sourceType: .original, sourceAttribution: nil, domain: "Engineering", topics: ["API", "Backend"], tags: nil, difficulty: .intermediate, aiData: nil, status: .published, viewCount: 12400, likeCount: 890, commentCount: 56, saveCount: 620, averageRating: 4.7, ratingCount: 234, publishedAt: Date().addingTimeInterval(-86400 * 3), createdAt: nil)
        ]

        recommendations = mockContent
        trending = Array(mockContent.prefix(5).shuffled())
        gapContent = Array(mockContent.suffix(4))
        exploreResults = mockContent
        availableDomains = ["Data Science", "Digital Marketing", "Engineering", "Product Management"]

        learningPaths = [
            LearningPath(id: "lp1", title: "PM Career Fast-Track", description: "From IC to senior PM in 12 weeks", domain: "Product Management", difficulty: "intermediate", items: nil, creatorId: "c1", creatorName: "Sarah Johnson", followerCount: 340, averageRating: 4.7, ratingCount: 89, estimatedDuration: 720, isPublished: true),
            LearningPath(id: "lp2", title: "Data Science Foundations", description: "Everything you need to start your DS journey", domain: "Data Science", difficulty: "beginner", items: nil, creatorId: "c2", creatorName: "Alex Chen", followerCount: 520, averageRating: 4.8, ratingCount: 145, estimatedDuration: 1200, isPublished: true),
            LearningPath(id: "lp3", title: "SEO Mastery Path", description: "From zero to SEO expert", domain: "Digital Marketing", difficulty: "beginner", items: nil, creatorId: "c3", creatorName: "Priya Sharma", followerCount: 410, averageRating: 4.6, ratingCount: 98, estimatedDuration: 480, isPublished: true),
            LearningPath(id: "lp4", title: "System Design Mastery", description: "Ace any system design interview", domain: "Engineering", difficulty: "advanced", items: nil, creatorId: "c4", creatorName: "Marcus Wright", followerCount: 280, averageRating: 4.9, ratingCount: 67, estimatedDuration: 900, isPublished: true)
        ]
    }
}
