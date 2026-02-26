import Foundation

// MARK: - Journey Service

/// Service layer wrapping journey-related API calls.
final class JourneyService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Get Journey

    /// Fetches the user's active learning journey.
    /// Returns `nil` when the backend has no journey for this user
    /// (backend responds with `{ success: true, data: null }`).
    func getJourney() async throws -> Journey? {
        let response: Journey? = try await apiClient.requestOptional(
            JourneyEndpoints.getJourney()
        )
        return response
    }

    // MARK: - Generate

    /// Generates a new learning journey from an objective.
    func generate(objectiveId: String) async throws -> Journey {
        let response: Journey = try await apiClient.request(
            JourneyEndpoints.generate(objectiveId: objectiveId)
        )
        return response
    }

    // MARK: - Today

    /// Fetches today's plan from the active journey.
    func today() async throws -> TodayPlan {
        let response: TodayPlan = try await apiClient.request(
            JourneyEndpoints.today()
        )
        return response
    }

    // MARK: - Week

    /// Fetches a specific week's plan.
    func week(number: Int) async throws -> WeeklyPlan {
        let response: WeeklyPlan = try await apiClient.request(
            JourneyEndpoints.week(number: number)
        )
        return response
    }

    // MARK: - Pause

    /// Pauses the active learning journey.
    func pause() async throws {
        try await apiClient.requestVoid(
            JourneyEndpoints.pause()
        )
    }

    // MARK: - Resume

    /// Resumes a paused learning journey.
    func resume() async throws {
        try await apiClient.requestVoid(
            JourneyEndpoints.resume()
        )
    }

    // MARK: - Milestones

    /// Fetches milestones for the active journey.
    func milestones() async throws -> [Milestone] {
        let response: [Milestone] = try await apiClient.request(
            JourneyEndpoints.milestones()
        )
        return response
    }
}
