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

/// Attachment metadata on a TPO notice (attachment.url is presigned GET URL).
struct PlacementNoticeAttachment: Codable {
    let fileName: String?
    let mime: String?
    let url: String?
}

/// A TPO notice returned by GET /api/v2/me/placement/notices.
struct PlacementNotice: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let pinned: Bool
    let link: String?
    let attachment: PlacementNoticeAttachment?
    let read: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, body, pinned, link, attachment, read
    }
}

// MARK: - API Service

/// Thin @MainActor service for the Campus placement companies and notices endpoints.
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

    // GET /api/v2/me/placement/notices
    func fetchNotices() async throws -> [PlacementNotice] {
        let resp: V2APIResponse<[PlacementNotice]> = try await V2APIClient.shared.get("/me/placement/notices")
        return resp.data
    }

    // POST /api/v2/me/placement/notices/:id/read (ignore response body)
    // Backend returns { "success": true } with no "data" field, so we decode
    // data as an optional type so a missing key does not throw.
    func markNoticeRead(_ id: String) async throws {
        struct EmptyData: Codable {}
        struct NoBody: Codable {}
        let _: V2APIResponse<EmptyData?> = try await V2APIClient.shared.post(
            "/me/placement/notices/\(id)/read",
            body: NoBody()
        )
    }
}
