import Foundation

// MARK: - Objective Service

/// Service layer wrapping learning objective API calls.
final class ObjectiveService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List

    /// Fetches all objectives for the current user.
    func list() async throws -> [Objective] {
        let response: [Objective] = try await apiClient.request(
            ObjectiveEndpoints.list()
        )
        return response
    }

    // MARK: - Create

    /// Creates a new learning objective.
    func create(
        objectiveType: ObjectiveType,
        timeline: Timeline,
        currentLevel: Difficulty,
        weeklyCommitHours: Int,
        specifics: [String: String]? = nil
    ) async throws -> Objective {
        let response: Objective = try await apiClient.request(
            ObjectiveEndpoints.create(
                objectiveType: objectiveType.rawValue,
                timeline: timeline.rawValue,
                currentLevel: currentLevel.rawValue,
                weeklyCommitHours: weeklyCommitHours,
                specifics: specifics
            )
        )
        return response
    }

    // MARK: - Update

    /// Updates an existing objective.
    func update(
        id: String,
        specifics: [String: String]? = nil,
        timeline: String? = nil,
        currentLevel: String? = nil,
        weeklyCommitHours: Int? = nil
    ) async throws -> Objective {
        let response: Objective = try await apiClient.request(
            ObjectiveEndpoints.update(
                id: id,
                specifics: specifics,
                timeline: timeline,
                currentLevel: currentLevel,
                weeklyCommitHours: weeklyCommitHours
            )
        )
        return response
    }

    // MARK: - Pause

    /// Pauses an active objective.
    func pause(id: String) async throws {
        try await apiClient.requestVoid(
            ObjectiveEndpoints.pause(id: id)
        )
    }

    // MARK: - Resume

    /// Resumes a paused objective.
    func resume(id: String) async throws {
        try await apiClient.requestVoid(
            ObjectiveEndpoints.resume(id: id)
        )
    }

    // MARK: - Set Primary

    /// Sets an objective as the user's primary objective.
    func setPrimary(id: String) async throws {
        try await apiClient.requestVoid(
            ObjectiveEndpoints.setPrimary(id: id)
        )
    }
}
