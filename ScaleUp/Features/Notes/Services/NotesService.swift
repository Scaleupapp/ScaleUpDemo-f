import Foundation

// MARK: - Notes Service

actor NotesService {
    private let api = APIClient.shared

    // MARK: - Upload

    func requestUpload(fileName: String, fileType: String, fileSize: Int) async throws -> NotesUploadURLResponse {
        let body = NotesUploadRequest(fileName: fileName, fileType: fileType, fileSize: fileSize)
        return try await api.request(NotesEndpoints.requestUpload, body: body)
    }

    func completeUpload(
        key: String, title: String, description: String?,
        domain: String, topics: [String], tags: [String],
        difficulty: String, thumbnailKey: String?,
        collegeName: String?, collegeId: String?, fileFormat: String
    ) async throws -> Content {
        let body = NotesCompleteRequest(
            key: key, title: title, description: description,
            domain: domain, topics: topics, tags: tags,
            difficulty: difficulty, thumbnailKey: thumbnailKey,
            collegeName: collegeName, collegeId: collegeId, fileFormat: fileFormat
        )
        return try await api.request(NotesEndpoints.completeUpload, body: body)
    }

    func requestThumbnailUpload() async throws -> NotesUploadURLResponse {
        try await api.request(NotesEndpoints.requestThumbnailUpload)
    }

    // MARK: - CRUD

    func fetchMyNotes(page: Int = 1) async throws -> [Content] {
        try await api.request(NotesEndpoints.myNotes(page: page))
    }

    func publishNote(id: String) async throws {
        _ = try await api.requestRaw(NotesEndpoints.publish(id: id))
    }

    func unpublishNote(id: String) async throws {
        _ = try await api.requestRaw(NotesEndpoints.unpublish(id: id))
    }

    func deleteNote(id: String) async throws {
        _ = try await api.requestRaw(NotesEndpoints.delete(id: id))
    }

    // MARK: - Flashcards

    func generateFlashcards(contentId: String) async throws -> FlashcardSet {
        let body = FlashcardGenerateRequest(contentId: contentId)
        return try await api.request(FlashcardEndpoints.generate, body: body)
    }

    func fetchMyFlashcards(page: Int = 1) async throws -> FlashcardListResponse {
        try await api.request(FlashcardEndpoints.list(page: page))
    }

    func fetchFlashcardSet(id: String) async throws -> FlashcardSet {
        try await api.request(FlashcardEndpoints.get(id: id))
    }

    func recordStudy(id: String, masteredCount: Int) async throws {
        let body = StudyRecordRequest(masteredCount: masteredCount)
        _ = try await api.requestRaw(FlashcardEndpoints.study(id: id), body: body)
    }

    func deleteFlashcardSet(id: String) async throws {
        _ = try await api.requestRaw(FlashcardEndpoints.delete(id: id))
    }
}

// MARK: - Request Bodies

struct NotesUploadURLResponse: Codable, Sendable {
    let uploadURL: String
    let key: String
    let expiresIn: Int?
}

private struct NotesUploadRequest: Encodable, Sendable {
    let fileName: String
    let fileType: String
    let fileSize: Int
}

private struct NotesCompleteRequest: Encodable, Sendable {
    let key: String
    let title: String
    let description: String?
    let domain: String
    let topics: [String]
    let tags: [String]
    let difficulty: String
    let thumbnailKey: String?
    let collegeName: String?
    let collegeId: String?
    let fileFormat: String
}

private struct FlashcardGenerateRequest: Encodable, Sendable {
    let contentId: String
}

private struct StudyRecordRequest: Encodable, Sendable {
    let masteredCount: Int
}

// MARK: - Endpoints

private enum NotesEndpoints: Endpoint {
    case requestUpload
    case completeUpload
    case requestThumbnailUpload
    case myNotes(page: Int)
    case publish(id: String)
    case unpublish(id: String)
    case delete(id: String)

    var path: String {
        switch self {
        case .requestUpload: return "/notes/request-upload"
        case .completeUpload: return "/notes/complete-upload"
        case .requestThumbnailUpload: return "/notes/request-thumbnail-upload"
        case .myNotes: return "/notes/my-notes"
        case .publish(let id): return "/notes/\(id)/publish"
        case .unpublish(let id): return "/notes/\(id)/unpublish"
        case .delete(let id): return "/notes/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .requestUpload, .completeUpload, .requestThumbnailUpload, .publish, .unpublish: return .post
        case .myNotes: return .get
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .myNotes(let page):
            return [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
        default: return nil
        }
    }
}

private enum FlashcardEndpoints: Endpoint {
    case generate
    case list(page: Int)
    case get(id: String)
    case study(id: String)
    case delete(id: String)

    var path: String {
        switch self {
        case .generate: return "/flashcards/generate"
        case .list: return "/flashcards"
        case .get(let id): return "/flashcards/\(id)"
        case .study(let id): return "/flashcards/\(id)/study"
        case .delete(let id): return "/flashcards/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .generate, .study: return .post
        case .list, .get: return .get
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let page):
            return [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
        default: return nil
        }
    }
}
