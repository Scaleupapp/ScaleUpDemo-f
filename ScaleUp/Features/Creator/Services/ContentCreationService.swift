import Foundation

actor ContentCreationService {
    private let api = APIClient.shared

    // MARK: - Upload Flow

    /// Step 1: Get a pre-signed S3 URL for direct upload
    func requestUploadURL(fileName: String, fileType: String, fileSize: Int) async throws -> UploadURLResponse {
        let body = RequestUploadBody(fileName: fileName, fileType: fileType, fileSize: fileSize)
        return try await api.request(ContentCreationEndpoints.requestUpload, body: body)
    }

    /// Step 2: Upload file data directly to S3 using the pre-signed URL
    func uploadToS3(url: String, data: Data, contentType: String) async throws {
        guard let uploadURL = URL(string: url) else { throw APIError.invalidURL }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badRequest("Upload to storage failed")
        }
    }

    /// Step 3: Register the uploaded content with the backend
    func completeUpload(body: CompleteUploadRequest) async throws -> Content {
        try await api.request(ContentCreationEndpoints.completeUpload, body: body)
    }

    // MARK: - Multipart Upload

    func initiateMultipart(fileName: String, fileType: String, fileSize: Int, partSize: Int) async throws -> MultipartInitResponse {
        let body = InitiateMultipartBody(fileName: fileName, fileType: fileType, fileSize: fileSize, partSize: partSize)
        return try await api.request(ContentCreationEndpoints.initiateMultipart, body: body)
    }

    func completeMultipart(key: String, uploadId: String, parts: [MultipartPart]) async throws {
        let body = CompleteMultipartBody(key: key, uploadId: uploadId, parts: parts)
        _ = try await api.requestRaw(ContentCreationEndpoints.completeMultipart, body: body)
    }

    func abortMultipart(key: String, uploadId: String) async throws {
        let body = AbortMultipartBody(key: key, uploadId: uploadId)
        _ = try await api.requestRaw(ContentCreationEndpoints.abortMultipart, body: body)
    }

    // MARK: - Content Management

    func fetchMyContent(page: Int = 1, status: String? = nil) async throws -> [Content] {
        try await api.request(ContentCreationEndpoints.myContent(page: page, status: status))
    }

    func updateContent(id: String, body: UpdateContentRequest) async throws -> Content {
        try await api.request(ContentCreationEndpoints.update(id: id), body: body)
    }

    func publishContent(id: String) async throws -> Content {
        try await api.request(ContentCreationEndpoints.publish(id: id))
    }

    func unpublishContent(id: String) async throws -> Content {
        try await api.request(ContentCreationEndpoints.unpublish(id: id))
    }

    func deleteContent(id: String) async throws {
        _ = try await api.requestRaw(ContentCreationEndpoints.delete(id: id))
    }
}

// MARK: - Request / Response Models

struct UploadURLResponse: Codable, Sendable {
    let uploadURL: String
    let key: String
    let expiresIn: Int?
}

struct RequestUploadBody: Encodable, Sendable {
    let fileName: String
    let fileType: String
    let fileSize: Int
}

struct CompleteUploadRequest: Encodable, Sendable {
    let key: String
    let title: String
    let description: String?
    let contentType: String
    let domain: String
    let topics: [String]
    let tags: [String]
    let difficulty: String
}

// MARK: - Multipart Models

struct InitiateMultipartBody: Encodable, Sendable {
    let fileName: String
    let fileType: String
    let fileSize: Int
    let partSize: Int
}

struct MultipartInitResponse: Codable, Sendable {
    let key: String
    let uploadId: String
    let totalParts: Int
    let partURLs: [PartURL]

    struct PartURL: Codable, Sendable {
        let partNumber: Int
        let url: String
    }
}

struct MultipartPart: Encodable, Sendable {
    let partNumber: Int
    let etag: String
}

struct CompleteMultipartBody: Encodable, Sendable {
    let key: String
    let uploadId: String
    let parts: [MultipartPart]
}

struct AbortMultipartBody: Encodable, Sendable {
    let key: String
    let uploadId: String
}

struct UpdateContentRequest: Encodable, Sendable {
    var title: String?
    var description: String?
    var domain: String?
    var topics: [String]?
    var tags: [String]?
    var difficulty: String?
    var thumbnailURL: String?
}

// MARK: - Endpoints

private enum ContentCreationEndpoints: Endpoint {
    case requestUpload
    case completeUpload
    case initiateMultipart
    case completeMultipart
    case abortMultipart
    case myContent(page: Int, status: String?)
    case update(id: String)
    case publish(id: String)
    case unpublish(id: String)
    case delete(id: String)

    var path: String {
        switch self {
        case .requestUpload: return "/content/request-upload"
        case .completeUpload: return "/content/complete-upload"
        case .initiateMultipart: return "/content/multipart/initiate"
        case .completeMultipart: return "/content/multipart/complete"
        case .abortMultipart: return "/content/multipart/abort"
        case .myContent: return "/content/my-content"
        case .update(let id), .delete(let id): return "/content/\(id)"
        case .publish(let id): return "/content/\(id)/publish"
        case .unpublish(let id): return "/content/\(id)/unpublish"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .requestUpload, .completeUpload, .publish, .unpublish,
             .initiateMultipart, .completeMultipart, .abortMultipart: return .post
        case .myContent: return .get
        case .update: return .put
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .myContent(let page, let status):
            var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
            if let status { items.append(URLQueryItem(name: "status", value: status)) }
            return items
        default: return nil
        }
    }
}
