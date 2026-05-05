import Foundation

// MARK: - Response Types

struct SyllabusUploadInitResponse: Codable, Sendable {
    let syllabusId: String
    let uploadUrl: String           // pre-signed S3 PUT URL
}

struct SyllabusStatusResponse: Codable, Sendable {
    let status: String              // "pending" | "extracting" | "ready" | "failed"
    let extractedTopics: [SuggestedTopic]?
    let errorReason: String?
}

// MARK: - Errors

enum SyllabusUploadError: Error, LocalizedError {
    case http(Int)
    case upload(URLError)
    case decoding(Error)
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .http(let c):                return "Server error (\(c))."
        case .upload(let e):              return "Upload failed: \(e.localizedDescription)"
        case .decoding:                   return "Bad server response."
        case .extractionFailed(let r):    return r.isEmpty ? "Extraction failed." : r
        }
    }
}

// MARK: - Service

/// Networking layer for the diagnostic syllabus upload flow.
/// Follows the same auth pattern as `OnboardingTopicService`: a synchronous
/// `() -> String?` token closure injected at construction time.
@MainActor
final class SyllabusUploadService {

    /// Default base URL — matches the hardcoded value in `APIClient`.
    static let defaultBaseURL = URL(string: "https://api.scaleupapp.club/api/v1")!

    private let session: URLSession
    private let baseURL: URL
    private let authToken: () -> String?

    init(
        session: URLSession = .shared,
        baseURL: URL = SyllabusUploadService.defaultBaseURL,
        authToken: @escaping () -> String? = { nil }
    ) {
        self.session = session
        self.baseURL = baseURL
        self.authToken = authToken
    }

    // MARK: Init upload

    func initUpload(filename: String, mimeType: String, byteCount: Int) async throws -> SyllabusUploadInitResponse {
        struct Body: Encodable {
            let filename: String
            let mimeType: String
            let byteCount: Int
        }
        return try await postJSON(
            path: "/diagnostic/syllabus/upload-init",
            body: Body(filename: filename, mimeType: mimeType, byteCount: byteCount)
        )
    }

    // MARK: Upload to S3

    func uploadFile(
        to url: URL,
        data: Data,
        mimeType: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        let delegate = UploadProgressDelegate(progress: progress)
        do {
            let (_, response) = try await session.upload(for: req, from: data, delegate: delegate)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw SyllabusUploadError.http(http.statusCode)
            }
        } catch let urlErr as URLError {
            throw SyllabusUploadError.upload(urlErr)
        }
    }

    // MARK: Complete upload

    func completeUpload(syllabusId: String) async throws {
        struct Empty: Encodable {}
        let _: SyllabusStatusResponse = try await postJSON(
            path: "/diagnostic/syllabus/\(syllabusId)/complete",
            body: Empty()
        )
    }

    // MARK: Poll status

    func pollStatus(syllabusId: String) async throws -> SyllabusStatusResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("/diagnostic/syllabus/\(syllabusId)/status"))
        req.httpMethod = "GET"
        if let token = authToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SyllabusUploadError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do {
            return try JSONDecoder().decode(SyllabusStatusResponse.self, from: data)
        } catch {
            throw SyllabusUploadError.decoding(error)
        }
    }

    // MARK: Helpers

    private func postJSON<T: Encodable, R: Decodable>(path: String, body: T) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SyllabusUploadError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw SyllabusUploadError.decoding(error)
        }
    }
}

// MARK: - Upload Progress Delegate

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let progress: (Double) -> Void

    init(progress: @escaping (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let p = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        Task { @MainActor in self.progress(p) }
    }
}
