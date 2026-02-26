import Foundation

// MARK: - Knowledge Service

/// Service layer wrapping knowledge profile API calls.
final class KnowledgeService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Profile

    /// Fetches the user's full knowledge profile.
    func profile() async throws -> KnowledgeProfile {
        let response: KnowledgeProfile = try await apiClient.request(
            KnowledgeEndpoints.profile()
        )
        return response
    }

    // MARK: - Topic

    /// Fetches detailed knowledge data for a specific topic.
    func topic(name: String) async throws -> TopicMastery {
        let response: TopicMastery = try await apiClient.request(
            KnowledgeEndpoints.topic(name: name)
        )
        return response
    }

    // MARK: - Gaps

    /// Fetches the user's identified knowledge gaps.
    func gaps() async throws -> [String] {
        let response: [String] = try await apiClient.request(
            KnowledgeEndpoints.gaps()
        )
        return response
    }

    // MARK: - Strengths

    /// Fetches the user's identified strengths.
    func strengths() async throws -> [String] {
        let response: [String] = try await apiClient.request(
            KnowledgeEndpoints.strengths()
        )
        return response
    }
}
