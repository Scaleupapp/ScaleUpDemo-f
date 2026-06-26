import Foundation

// MARK: - Codable Models

/// The top-level response from GET /api/v2/me/placement/practice.
struct PlacementPractice: Codable {
    let hasAssessment: Bool
    let recommendations: [PracticeRec]
    let types: [PracticeType]
}

/// A competency-targeted practice recommendation.
struct PracticeRec: Codable, Identifiable {
    let competency: String
    let score: Int
    let suggestedType: String
    let topic: String
    let reason: String

    var id: String { competency }
}

/// One of the four engine types the student can practice with.
struct PracticeType: Codable, Identifiable {
    let key: String   // "quiz" | "drill" | "capstone" | "interview"
    let label: String

    var id: String { key }
}

// MARK: - API Service

/// Thin @MainActor service for the placement practice endpoint.
/// All networking goes through V2APIClient.shared (GET /api/v2).
@MainActor
final class PlacementsPracticeApi {
    static let shared = PlacementsPracticeApi()
    private init() {}

    // GET /api/v2/me/placement/practice
    func fetchPractice() async throws -> PlacementPractice {
        let resp: V2APIResponse<PlacementPractice> = try await V2APIClient.shared.get("/me/placement/practice")
        return resp.data
    }
}
