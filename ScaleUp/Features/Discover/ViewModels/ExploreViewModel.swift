import SwiftUI

// MARK: - Sort Option

enum SortOption: String, CaseIterable, Identifiable {
    case relevance = "Relevance"
    case newest = "Newest"
    case mostPopular = "Most Popular"

    var id: String { rawValue }
}

// MARK: - Explore View Model

@Observable
@MainActor
final class ExploreViewModel {

    // MARK: - Content

    var content: [Content] = []

    // MARK: - Filters

    var selectedDomain: String?
    var selectedDifficulty: Difficulty?
    var sortBy: SortOption = .relevance
    var searchQuery: String = ""

    // MARK: - Pagination

    var currentPage: Int = 1
    var hasMore: Bool = true
    var isLoadingMore: Bool = false

    // MARK: - State

    var isLoading = false
    var error: APIError?

    // MARK: - Available Domains

    let availableDomains: [String] = [
        "Product Management",
        "Entrepreneurship",
        "SAT Preparation",
        "Business Soft Skills",
        "Marketing",
        "MBA Preparation"
    ]

    // MARK: - Dependencies

    private let contentService: ContentService
    private let pageSize = 20

    // MARK: - Init

    init(contentService: ContentService) {
        self.contentService = contentService
    }

    // MARK: - Load Content (Initial)

    /// Loads the first page of explore content.
    func loadContent() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 1
        content = []

        do {
            let items = try await contentService.explore(
                domain: selectedDomain,
                difficulty: selectedDifficulty?.rawValue,
                search: searchQuery.isEmpty ? nil : searchQuery,
                page: 1,
                limit: pageSize
            )

            content = items
            hasMore = items.count >= pageSize
            currentPage = 1
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    // MARK: - Load More

    /// Loads the next page and appends results to the content array.
    func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMore else { return }

        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let items = try await contentService.explore(
                domain: selectedDomain,
                difficulty: selectedDifficulty?.rawValue,
                search: searchQuery.isEmpty ? nil : searchQuery,
                page: nextPage,
                limit: pageSize
            )

            content.append(contentsOf: items)
            hasMore = items.count >= pageSize
            currentPage = nextPage
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }

        isLoadingMore = false
    }

    // MARK: - Apply Filters

    /// Resets pagination and reloads content with current filters.
    func applyFilters() async {
        currentPage = 1
        hasMore = true
        content = []
        await loadContent()
    }

    // MARK: - Reset Filters

    /// Clears all filters and reloads content.
    func resetFilters() {
        selectedDomain = nil
        selectedDifficulty = nil
        sortBy = .relevance
        searchQuery = ""
    }

    // MARK: - Select Domain

    /// Toggles a domain filter on or off.
    func selectDomain(_ domain: String) {
        if selectedDomain == domain {
            selectedDomain = nil
        } else {
            selectedDomain = domain
        }
    }

    // MARK: - Select Difficulty

    /// Toggles a difficulty filter on or off.
    func selectDifficulty(_ difficulty: Difficulty?) {
        if selectedDifficulty == difficulty {
            selectedDifficulty = nil
        } else {
            selectedDifficulty = difficulty
        }
    }
}
