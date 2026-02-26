import SwiftUI

// MARK: - Search Tab

enum SearchTab: String, CaseIterable, Identifiable {
    case content = "Content"
    case creators = "Creators"

    var id: String { rawValue }
}

// MARK: - Search View Model

@Observable
@MainActor
final class SearchViewModel {

    // MARK: - Constants

    private static let recentSearchesKey = "com.scaleup.recentSearches"
    private static let maxRecentSearches = 10

    // MARK: - Published State

    var query: String = ""
    var results: [Content] = []
    var creatorResults: [CreatorSearchResult] = []
    var recentSearches: [String] = []
    var isSearching: Bool = false
    var isLoadingMore: Bool = false
    var currentPage: Int = 1
    var hasMore: Bool = false
    var selectedTab: SearchTab = .content
    var error: APIError?

    // MARK: - Computed Properties

    var isEmpty: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasResults: Bool {
        !results.isEmpty || !creatorResults.isEmpty
    }

    var hasResultsForCurrentTab: Bool {
        switch selectedTab {
        case .content:
            return !results.isEmpty
        case .creators:
            return !creatorResults.isEmpty
        }
    }

    var showEmptyResults: Bool {
        !isEmpty && !isSearching && !hasResultsForCurrentTab && query.count >= 2
    }

    // MARK: - Suggested Topics

    let suggestedTopics: [String] = [
        "Product Management",
        "React",
        "System Design",
        "SAT Math",
        "Leadership",
        "Marketing Strategy",
        "Machine Learning",
        "Public Speaking",
        "Finance",
        "UX Research"
    ]

    // MARK: - Dependencies

    private let searchService: SearchService
    private let creatorService: CreatorService
    private let debouncer = Debouncer(duration: .milliseconds(500))
    var searchDebounceTask: Task<Void, Never>?

    // MARK: - Init

    init(searchService: SearchService, creatorService: CreatorService) {
        self.searchService = searchService
        self.creatorService = creatorService
        loadRecentSearches()
    }

    // MARK: - Search

    /// Triggers a debounced search. Each keystroke resets the timer
    /// so only the final query fires the network request.
    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            clearSearch()
            return
        }

        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            await debouncer.debounce { [weak self] in
                await self?.performSearch()
            }
        }
    }

    /// Performs the actual search request against the API.
    /// Content and creator searches run independently so one failure doesn't block the other.
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        error = nil
        currentPage = 1

        // Run content and creator searches independently
        async let contentResult: Result<PaginatedData<Content>, Error> = {
            do {
                let response = try await searchService.searchContent(
                    query: trimmed,
                    page: 1,
                    limit: 20
                )
                return .success(response)
            } catch {
                return .failure(error)
            }
        }()

        async let creatorResult: Result<[CreatorSearchResult], Error> = {
            do {
                let creators = try await creatorService.search()
                return .success(creators)
            } catch {
                return .failure(error)
            }
        }()

        let (content, creators) = await (contentResult, creatorResult)

        guard !Task.isCancelled else { return }

        // Process content results
        switch content {
        case .success(let contentResponse):
            results = contentResponse.items
            hasMore = (contentResponse.pagination?.hasMore ?? false)
        case .failure(let err):
            results = []
            hasMore = false
            print("⚠️ Content search failed: \(err)")
        }

        // Process creator results
        switch creators {
        case .success(let allCreators):
            creatorResults = allCreators.filter { creator in
                creator.displayName.localizedCaseInsensitiveContains(trimmed) ||
                (creator.creatorProfile?.domain.localizedCaseInsensitiveContains(trimmed) ?? false) ||
                (creator.creatorProfile?.specializations.contains { $0.localizedCaseInsensitiveContains(trimmed) } ?? false)
            }
        case .failure(let err):
            creatorResults = []
            print("⚠️ Creator search failed: \(err)")
        }

        if hasResults {
            saveToRecentSearches(trimmed)
        }

        isSearching = false
    }

    // MARK: - Load More (Pagination)

    /// Loads the next page of content results for infinite scroll.
    func loadMore() async {
        guard !isLoadingMore, hasMore, selectedTab == .content else { return }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let response = try await searchService.searchContent(
                query: trimmed,
                page: nextPage,
                limit: 20
            )

            guard !Task.isCancelled else { return }

            results.append(contentsOf: response.items)
            currentPage = nextPage
            hasMore = (response.pagination?.hasMore ?? false)
        } catch {
            // Silently fail on pagination errors; the user can scroll again.
        }

        isLoadingMore = false
    }

    // MARK: - Clear Search

    /// Resets all search state back to the initial idle view.
    func clearSearch() {
        query = ""
        results = []
        creatorResults = []
        currentPage = 1
        hasMore = false
        isSearching = false
        isLoadingMore = false
        error = nil
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
    }

    // MARK: - Suggested Topic Selection

    /// Sets the query to a suggested topic and immediately searches.
    func selectSuggestedTopic(_ topic: String) {
        query = topic
        Task { await search() }
    }

    // MARK: - Recent Searches (UserDefaults persistence)

    /// Removes a single recent search at the given index.
    func removeRecentSearch(at index: Int) {
        guard recentSearches.indices.contains(index) else { return }
        recentSearches.remove(at: index)
        persistRecentSearches()
    }

    /// Clears all recent searches.
    func clearRecentSearches() {
        recentSearches = []
        persistRecentSearches()
    }

    /// Adds a query to the recent searches list (deduplicating, max 10).
    private func saveToRecentSearches(_ searchQuery: String) {
        recentSearches.removeAll { $0.lowercased() == searchQuery.lowercased() }
        recentSearches.insert(searchQuery, at: 0)
        if recentSearches.count > Self.maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(Self.maxRecentSearches))
        }
        persistRecentSearches()
    }

    /// Loads recent searches from UserDefaults.
    private func loadRecentSearches() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentSearchesKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        recentSearches = decoded
    }

    /// Persists the current recent searches list to UserDefaults.
    private func persistRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: Self.recentSearchesKey)
        }
    }
}
