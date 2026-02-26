import SwiftUI

// MARK: - History Filter

/// Filter options for the learning history list.
enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case inProgress = "In Progress"
    case completed = "Completed"

    var id: String { rawValue }
}

// MARK: - Learning History View Model

/// Drives the Learning History screen by fetching the user's content
/// consumption history from `ProgressService` and exposing filtered,
/// paginated results to the view layer.
@Observable
@MainActor
final class LearningHistoryViewModel {

    // MARK: - State

    /// The full list of history items fetched from the server.
    var history: [ContentProgress] = []

    /// Whether the initial load is in progress.
    var isLoading: Bool = false

    /// Whether additional items are being loaded (pagination).
    var isLoadingMore: Bool = false

    /// The most recent error encountered, if any.
    var error: APIError?

    /// The currently selected filter.
    var filter: HistoryFilter = .all

    // MARK: - Pagination

    /// Number of items to request per page.
    private let pageSize: Int = 20

    /// Whether there may be more items to load from the server.
    var hasMoreItems: Bool = true

    // MARK: - Dependencies

    private let progressService: ProgressService

    // MARK: - Init

    init(progressService: ProgressService) {
        self.progressService = progressService
    }

    // MARK: - Computed Properties

    /// The history list filtered by the current `filter` selection.
    var filteredHistory: [ContentProgress] {
        switch filter {
        case .all:
            return history
        case .inProgress:
            return history.filter { !$0.isCompleted }
        case .completed:
            return history.filter { $0.isCompleted }
        }
    }

    /// `true` when there is no data and no loading / error state.
    var isEmpty: Bool {
        !isLoading && error == nil && filteredHistory.isEmpty
    }

    // MARK: - Load History

    /// Fetches the first page of history from the server.
    func loadHistory() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let items = try await progressService.history(limit: pageSize)
            self.history = items
            self.hasMoreItems = items.count >= pageSize
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Load More

    /// Loads the next page of history (appended to the existing list).
    func loadMore() async {
        guard !isLoadingMore, hasMoreItems else { return }
        isLoadingMore = true

        do {
            // Request a larger window and deduplicate against current items
            let nextLimit = history.count + pageSize
            let items = try await progressService.history(limit: nextLimit)

            let existingIds = Set(history.map(\.id))
            let newItems = items.filter { !existingIds.contains($0.id) }

            self.history.append(contentsOf: newItems)
            self.hasMoreItems = newItems.count >= pageSize
        } catch {
            // Silently fail pagination — the user can retry by scrolling again
        }

        isLoadingMore = false
    }

    // MARK: - Refresh

    /// Performs a full refresh of the history list (pull-to-refresh).
    func refresh() async {
        error = nil

        do {
            let items = try await progressService.history(limit: pageSize)
            self.history = items
            self.hasMoreItems = items.count >= pageSize
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }
}
