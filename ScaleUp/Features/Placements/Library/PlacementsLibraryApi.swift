import Foundation

// MARK: - Codable Models

/// An item inside a curated shelf returned by GET /api/v2/me/placement/shelves.
/// For type=="link" the url is the stored URL;
/// for type=="file" the url is a short-lived presigned GET URL.
struct PlacementShelfItem: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let note: String?
    let fileName: String?
    let mime: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type, title, note, fileName, mime, url
    }
}

/// A curated shelf returned by GET /api/v2/me/placement/shelves.
struct PlacementShelf: Codable, Identifiable {
    let id: String
    let title: String
    let order: Int?
    let items: [PlacementShelfItem]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, order, items
    }
}

// MARK: - API Service

/// Thin @MainActor service for the Library placement shelves endpoint.
/// All networking goes through V2APIClient.shared (GET /api/v2).
@MainActor
final class PlacementsLibraryApi {
    static let shared = PlacementsLibraryApi()
    private init() {}

    // GET /api/v2/me/placement/shelves
    func fetchShelves() async throws -> [PlacementShelf] {
        let resp: V2APIResponse<[PlacementShelf]> = try await V2APIClient.shared.get("/me/placement/shelves")
        return resp.data
    }
}
