import Foundation

/// Client wrapper around `/api/coding/capstones/*` — mirrors DrillService.
/// Translates the backend's tagged-union error bodies into typed
/// CapstoneServiceError so views can branch without re-parsing JSON.
@MainActor
final class CapstoneService {
    static let shared = CapstoneService()
    private let client = V2APIClient.shared

    // MARK: - Library + start

    func listLibrary(difficulty: DrillDifficulty? = nil, roleTrack: RoleTrack? = nil)
        async throws -> [CapstoneLibraryEntry]
    {
        var path = "/capstones/library"
        var q: [String] = []
        if let d = difficulty { q.append("difficulty=\(d.rawValue)") }
        if let r = roleTrack  { q.append("role_track=\(r.rawValue)") }
        if !q.isEmpty { path += "?\(q.joined(separator: "&"))" }
        struct Wrapper: Codable { let capstones: [CapstoneLibraryEntry] }
        let w: Wrapper = try await client.getCoding(path)
        return w.capstones
    }

    func start(bundleId: String) async throws -> CapstoneStartResponse {
        struct Body: Codable { let bundle_id: String }
        // Decoded manually with capstoneDecoder because the default decoder
        // cannot parse `expires_at` (ISO8601 string) into Date and we end up
        // showing a useless "Couldn't start" alert to the user instead of
        // moving them onto the pairing screen.
        let (data, status) = try await client.rawCodingData(method: "POST", path: "/capstones/start", body: Body(bundle_id: bundleId))
        if status == 201 || status == 200 {
            return try JSONDecoder.capstoneDecoder.decode(CapstoneStartResponse.self, from: data)
        }
        if status == 404 {
            throw mapStartError(data)
        }
        throw V2APIError.httpError(status, data)
    }

    /// POST /capstones/retry — start a new session against a previously graded bundle.
    /// Mirrors `start()` shape; the response carries `is_retry: true`.
    func retry(bundleId: String) async throws -> CapstoneStartResponse {
        struct Body: Codable { let bundle_id: String }
        let (data, status) = try await client.rawCodingData(method: "POST", path: "/capstones/retry", body: Body(bundle_id: bundleId))
        if status == 201 || status == 200 {
            return try JSONDecoder.capstoneDecoder.decode(CapstoneStartResponse.self, from: data)
        }
        if status == 409 {
            throw CapstoneServiceError.invalidTransition(currentStatus: "in_progress")
        }
        if status == 400 || status == 404 {
            throw mapStartError(data)
        }
        throw V2APIError.httpError(status, data)
    }

    /// GET /capstones/summary — Compass-tab snapshot.
    func summary() async throws -> APICapstoneSummary {
        try await client.getCoding("/capstones/summary")
    }

    /// GET /capstones/history — paginated full history + headline stats.
    func history(limit: Int = 30, offset: Int = 0) async throws -> CapstoneHistoryResponse {
        try await client.getCoding("/capstones/history?limit=\(limit)&offset=\(offset)")
    }

    /// POST /capstones/request — "Surprise me" picker. Returns the next-best bundle
    /// preview as a CapstoneLibraryEntry-shaped struct so it slots straight into
    /// the existing PreflightView pipeline.
    func requestNext() async throws -> CapstoneLibraryEntry {
        struct Wrapper: Codable {
            let bundle: APICapstoneBundleView
            let cadence: String
            let reason: String
        }
        let w: Wrapper = try await client.postCoding("/capstones/request", body: EmptyBody())
        return CapstoneLibraryEntry(
            bundleId: w.bundle.bundleId,
            brief: w.bundle.brief,
            difficulty: DrillDifficulty(rawValue: w.bundle.difficulty.rawValue) ?? .medium,
            roleTrack: RoleTrack(rawValue: w.bundle.roleTrack.rawValue) ?? .swe,
            timeBudgetMinutes: w.bundle.timeBudgetMinutes.rawValue,
            language: w.bundle.language,
            stackVariant: w.bundle.stackVariant,
            interviewParallel: w.bundle.interviewParallel,
            alreadyCompleted: false
        )
    }

    // MARK: - Generator (Phase 3)

    /// POST /capstones/generate — kick off custom generation. Returns request_id
    /// to poll. 202 on success.
    func generateCapstone(jobDescription: String, topicHint: String?, difficulty: DrillDifficulty?) async throws -> CapstoneGenerationStatus {
        struct Body: Codable {
            let job_description: String
            let topic_hint: String?
            let difficulty: String?
        }
        let body = Body(
            job_description: jobDescription,
            topic_hint: (topicHint?.isEmpty == false) ? topicHint : nil,
            difficulty: difficulty?.rawValue
        )
        // The endpoint returns 202 with the request envelope; decode it as a status.
        let (data, _) = try await client.rawCodingData(method: "POST", path: "/capstones/generate", body: body)
        return try JSONDecoder.capstoneDecoder.decode(CapstoneGenerationStatus.self, from: data)
    }

    /// GET /capstones/generations/:id — poll. When status=="ready", `bundle` is set.
    func generationStatus(requestId: String) async throws -> CapstoneGenerationStatus {
        try await client.getCoding("/capstones/generations/\(requestId)")
    }

    private struct EmptyBody: Codable {}

    // MARK: - Status / control

    func getStatus(sessionId: String) async throws -> CapstoneSessionView {
        try await client.getCoding("/capstones/\(sessionId)/status")
    }

    func control(sessionId: String, action: CapstoneControlAction)
        async throws -> CapstoneSessionView
    {
        do {
            return try await client.postCoding(
                "/capstones/\(sessionId)/control",
                body: CapstoneControlRequest(action: action)
            )
        } catch V2APIError.httpError(let status, let data) where status == 409 {
            struct Err: Codable { let error: String?; let current_status: String? }
            let err = try? JSONDecoder().decode(Err.self, from: data)
            throw CapstoneServiceError.invalidTransition(currentStatus: err?.current_status)
        }
    }

    // MARK: - Result polling

    /// Polls `/result`. Returns `.graded` when status is 200, `.pending`
    /// when 202. Mirrors DrillService.pollResult.
    enum ResultPoll: Sendable {
        case graded(CapstoneResult)
        case pending(currentStatus: CapstoneSessionStatus)
    }

    func pollResult(sessionId: String) async throws -> ResultPoll {
        let (data, status) = try await client.rawCodingData(
            method: "GET", path: "/capstones/\(sessionId)/result"
        )
        if status == 200 {
            let graded = try JSONDecoder.capstoneDecoder.decode(CapstoneResult.self, from: data)
            return .graded(graded)
        }
        struct Pending: Codable { let status: CapstoneSessionStatus }
        let p = try JSONDecoder.capstoneDecoder.decode(Pending.self, from: data)
        return .pending(currentStatus: p.status)
    }

    // MARK: - Replay

    func getReplay(sessionId: String) async throws -> CapstoneReplay {
        try await client.getCoding("/capstones/\(sessionId)/replay")
    }

    // MARK: - Voice reflection

    /// Uploads audio + enqueues transcription + re-eval. Returns 202 on
    /// success; throws `.reflectionAlreadyRecorded` if `replace=false`
    /// and the session already has a transcript.
    func uploadVoiceReflection(
        sessionId: String,
        audio: Data,
        mimeType: String,
        replace: Bool = false
    ) async throws {
        let query = replace ? "?replace=true" : ""
        // V2APIClient doesn't ship a multipart helper; build the request
        // by hand. Multipart is just two boundary-delimited form parts:
        // the file content and that's it.
        let boundary = "scaleup-\(UUID().uuidString)"
        var body = Data()
        let crlf = "\r\n".data(using: .utf8)!
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"audio\"; filename=\"reflection.\(mimeExt(mimeType))\"\r\n".data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audio)
        body.append(crlf)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let urlString = await client.codingBaseURL() + "/capstones/\(sessionId)/voice-reflection\(query)"
        guard let url = URL(string: urlString) else {
            throw V2APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = await KeychainManager.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw V2APIError.serverError(0)
        }
        if http.statusCode == 409 {
            struct Err: Codable { let error: String?; let current_status: String? }
            let err = try? JSONDecoder().decode(Err.self, from: data)
            if err?.error == "reflection_already_recorded" {
                throw CapstoneServiceError.reflectionAlreadyRecorded
            }
            throw CapstoneServiceError.sessionNotGraded(currentStatus: err?.current_status)
        }
        if http.statusCode >= 400 {
            throw V2APIError.httpError(http.statusCode, data)
        }
    }

    // MARK: - Internals

    private func mapStartError(_ data: Data) -> Error {
        struct Err: Codable { let error: String? }
        let err = try? JSONDecoder().decode(Err.self, from: data)
        switch err?.error {
        case "bundle_not_found":              return CapstoneServiceError.sessionNotFound
        case "not_a_capstone":                return CapstoneServiceError.notACapstone
        case "no_coding_track_for_objective": return CapstoneServiceError.noCodingTrackForObjective
        default: return V2APIError.httpError(404, data)
        }
    }

    private func mimeExt(_ mime: String) -> String {
        switch mime {
        case "audio/m4a", "audio/x-m4a", "audio/mp4": return "m4a"
        case "audio/mpeg", "audio/mp3":               return "mp3"
        case "audio/wav", "audio/x-wav":              return "wav"
        case "audio/webm":                            return "webm"
        case "audio/ogg":                             return "ogg"
        default:                                      return "m4a"
        }
    }
}

// MARK: - JSON helpers

extension JSONDecoder {
    /// Decoder for capstone payloads — handles the backend's ISO8601 date
    /// strings consistently (some endpoints serialize without fractional
    /// seconds, some with).
    static var capstoneDecoder: JSONDecoder {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            if let dt = formatter.date(from: s) { return dt }
            if let dt = fallback.date(from: s) { return dt }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(s)")
        }
        return d
    }
}

extension V2APIClient {
    /// Expose the coding base URL so multipart-by-hand uploads can
    /// resolve the right host. V2APIClient.baseURL is private; this
    /// helper reflects the same selection logic.
    func codingBaseURL() async -> String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let v1 = (configured?.isEmpty == false ? configured! : "https://api.scaleupapp.club/api/v1")
        return v1.replacingOccurrences(of: "/api/v1", with: "/api/coding")
    }
}
