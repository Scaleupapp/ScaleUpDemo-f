import Foundation

// MARK: - Content Repository

/// Actor-isolated cache-then-network repository for content.
///
/// Provides in-memory caching with time-based invalidation:
/// - Individual content items are cached for 30 minutes.
/// - Feed results are cached for 5 minutes.
/// - Explore (filtered) results are never cached — always fetched from the network.
///
/// Thread safety is guaranteed by Swift's actor isolation.
actor ContentRepository {

    // MARK: - Cache Configuration

    private static let contentCacheDuration: TimeInterval = 30 * 60  // 30 minutes
    private static let feedCacheDuration: TimeInterval = 5 * 60      // 5 minutes

    // MARK: - Cache Entries

    private struct CachedItem<T> {
        let value: T
        let timestamp: Date

        func isFresh(within duration: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < duration
        }
    }

    // MARK: - Cache Storage

    private var contentCache: [String: CachedItem<Content>] = [:]
    private var feedCache: CachedItem<[Content]>?

    // MARK: - Dependencies

    private let contentService: ContentService

    // MARK: - Init

    init(contentService: ContentService) {
        self.contentService = contentService
    }

    // MARK: - Get Content (by ID)

    /// Returns a single content item. Uses the in-memory cache if the entry
    /// is less than 30 minutes old; otherwise fetches from the network and
    /// updates the cache.
    func getContent(id: String) async throws -> Content {
        // Check cache first
        if let cached = contentCache[id],
           cached.isFresh(within: Self.contentCacheDuration) {
            return cached.value
        }

        // Fetch from network
        let content = try await contentService.getContent(id: id)

        // Update cache
        contentCache[id] = CachedItem(value: content, timestamp: Date())

        return content
    }

    // MARK: - Get Feed

    /// Returns the user's personalized feed. Uses cached results if less
    /// than 5 minutes old; otherwise fetches fresh data from the network.
    func getFeed() async throws -> [Content] {
        // Check cache first
        if let cached = feedCache,
           cached.isFresh(within: Self.feedCacheDuration) {
            return cached.value
        }

        // Fetch from network
        let feed = try await contentService.getFeed()

        // Update caches
        feedCache = CachedItem(value: feed, timestamp: Date())

        // Also cache individual items
        for item in feed {
            contentCache[item.id] = CachedItem(value: item, timestamp: Date())
        }

        return feed
    }

    // MARK: - Get Explore (Filtered — No Cache)

    /// Fetches explore/browse results with optional filters. These are
    /// always fetched from the network since filter combinations make
    /// caching impractical.
    func getExplore(
        domain: String? = nil,
        difficulty: String? = nil,
        search: String? = nil,
        page: Int? = nil,
        limit: Int? = nil
    ) async throws -> [Content] {
        let items = try await contentService.explore(
            domain: domain,
            difficulty: difficulty,
            search: search,
            page: page,
            limit: limit
        )

        // Opportunistically cache individual items from the response
        for item in items {
            contentCache[item.id] = CachedItem(value: item, timestamp: Date())
        }

        return items
    }

    // MARK: - Cache Invalidation

    /// Removes a single content item from the cache. Call this after
    /// actions that modify server-side state (like, save, rate) so the
    /// next fetch returns fresh data.
    func invalidateContent(id: String) {
        contentCache.removeValue(forKey: id)
    }

    /// Clears the feed cache, forcing the next `getFeed()` call to
    /// hit the network.
    func invalidateFeed() {
        feedCache = nil
    }

    /// Removes all cached data. Useful when the user logs out.
    func invalidateAll() {
        contentCache.removeAll()
        feedCache = nil
    }

    // MARK: - Cache Stats (Debug)

    /// Returns the number of individually cached content items.
    var cachedContentCount: Int {
        contentCache.count
    }

    /// Returns whether the feed cache is currently populated and fresh.
    var isFeedCached: Bool {
        feedCache?.isFresh(within: Self.feedCacheDuration) ?? false
    }
}
