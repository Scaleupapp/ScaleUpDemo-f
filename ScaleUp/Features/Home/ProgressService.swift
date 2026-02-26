import Foundation

// MARK: - Progress Service

/// Service layer wrapping content progress tracking API calls.
final class ProgressService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Update Progress

    /// Updates playback progress for a content item.
    func updateProgress(contentId: String, position: Double, duration: Double) async throws -> ContentProgress {
        let response: ContentProgress = try await apiClient.request(
            ProgressEndpoints.update(contentId: contentId, position: position, duration: duration)
        )
        return response
    }

    // MARK: - Mark Complete

    /// Marks a content item as fully completed.
    func markComplete(contentId: String) async throws -> ContentProgress {
        let response: ContentProgress = try await apiClient.request(
            ProgressEndpoints.complete(contentId: contentId)
        )
        return response
    }

    // MARK: - History

    /// Fetches the user's content consumption history.
    func history(limit: Int? = nil) async throws -> [ContentProgress] {
        let response: [ContentProgress] = try await apiClient.request(
            ProgressEndpoints.history(limit: limit)
        )
        return response
    }

    // MARK: - Stats

    /// Fetches aggregated progress statistics.
    func stats() async throws -> ProgressStats {
        let response: ProgressStats = try await apiClient.request(
            ProgressEndpoints.stats()
        )
        return response
    }
}
