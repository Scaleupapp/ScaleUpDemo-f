import Foundation

// MARK: - Codable Models

/// A company recruiting drive returned by GET /api/v2/me/placement/companies.
struct PlacementDrive: Codable, Identifiable {
    let id: String
    let name: String
    let role: String?
    let package: String?
    let driveDate: String?
    let eligibility: String?
    let status: String
    let applyLink: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, role, package, driveDate, eligibility, status, applyLink, notes
    }
}

// MARK: - API Service

/// Thin @MainActor service for the Campus placement companies endpoint.
/// All networking goes through V2APIClient.shared (GET /api/v2).
@MainActor
final class PlacementsCampusApi {
    static let shared = PlacementsCampusApi()
    private init() {}

    // GET /api/v2/me/placement/companies
    func fetchCompanies() async throws -> [PlacementDrive] {
        let resp: V2APIResponse<[PlacementDrive]> = try await V2APIClient.shared.get("/me/placement/companies")
        return resp.data
    }
}
