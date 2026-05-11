import Foundation

// MARK: - Response types

struct SuggestedTopicsResponse: Codable, Sendable {
    let topics: [SuggestedTopic]
    let cacheHit: Bool
    let source: String      // "curated" | "llm-generated"
}

struct OnboardingCompletePayload: Codable, Sendable {
    let firstName: String
    let lastName: String
    let educationEntries: [EducationPayload]
    let workEntries: [WorkPayload]
    let objectiveType: String
    let specifics: [String: String]
    let timeline: String
    let currentLevel: String
    let weeklyHours: Double
    let learningStyle: String
    let topicsOfInterest: [TopicSelectionPayload]
    let topicSelfRatings: [String: String]   // canonicalName → proficiency raw
    let syllabusId: String?

    // Wire format must match backend's REQUIRED_FIELDS in
    // onboardingController.completeOnboarding (weeklyCommitHours +
    // preferredLearningStyle). We keep the friendlier Swift names but
    // serialize to the backend's expected keys.
    enum CodingKeys: String, CodingKey {
        case firstName, lastName, educationEntries, workEntries
        case objectiveType, specifics, timeline, currentLevel
        case weeklyHours = "weeklyCommitHours"
        case learningStyle = "preferredLearningStyle"
        case topicsOfInterest, topicSelfRatings, syllabusId
    }

    struct EducationPayload: Codable, Sendable {
        let degree: String
        let institution: String
        let yearOfCompletion: Int?
        let currentlyPursuing: Bool
    }
    struct WorkPayload: Codable, Sendable {
        let role: String
        let company: String
        let years: Int?
        let currentlyWorking: Bool
    }
    struct TopicSelectionPayload: Codable, Sendable {
        let canonicalName: String
        let name: String
        let source: String        // TopicSource.rawValue
        let isFutureProofing: Bool
    }
}

struct OnboardingCompleteResponse: Codable, Sendable {
    let userObjectiveId: String
    let needsCalibration: Bool
}

// MARK: - Errors

enum OnboardingTopicError: Error, LocalizedError {
    case network(URLError)
    case decoding(Error)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .decoding:       return "Could not read server response."
        case .http(let code): return "Server error (\(code)). Please try again."
        }
    }
}

// MARK: - Service

/// Networking layer for the Plan 2a diagnostic-onboarding endpoints.
/// Note: This project's existing `APIClient` actor uses a hardcoded base URL and
/// `KeychainManager` (an actor) for tokens. Since the test plan requires a
/// synchronous token closure (`() -> String?`), callers (e.g. the ViewModel)
/// pre-fetch the access token and inject it at construction time.
@MainActor
final class OnboardingTopicService {

    /// Default base URL — matches the hardcoded value in `APIClient`.
    static let defaultBaseURL = URL(string: "https://api.scaleupapp.club/api/v1")!

    private let session: URLSession
    private let baseURL: URL
    private let authToken: () -> String?

    init(
        session: URLSession = .shared,
        baseURL: URL = OnboardingTopicService.defaultBaseURL,
        authToken: @escaping () -> String? = { nil }
    ) {
        self.session = session
        self.baseURL = baseURL
        self.authToken = authToken
    }

    // MARK: Suggest topics

    func fetchSuggestedTopics(
        objectiveType: ObjectiveType,
        specifics: [String: String],
        company: String?
    ) async throws -> SuggestedTopicsResponse {
        struct Body: Encodable {
            let objectiveType: String
            let specifics: [String: String]
            let company: String?
        }
        let body = Body(objectiveType: objectiveType.rawValue, specifics: specifics, company: company)
        return try await post(path: "/onboarding/topics/suggest", body: body)
    }

    // MARK: Submit onboarding

    func submitOnboarding(_ payload: OnboardingCompletePayload) async throws -> OnboardingCompleteResponse {
        try await post(path: "/onboarding/complete", body: payload)
    }

    // MARK: helpers

    private func post<T: Encodable, R: Decodable>(path: String, body: T) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        req.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw OnboardingTopicError.http(-1)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw OnboardingTopicError.http(http.statusCode)
            }
            do {
                return try JSONDecoder().decode(R.self, from: data)
            } catch {
                throw OnboardingTopicError.decoding(error)
            }
        } catch let urlErr as URLError {
            throw OnboardingTopicError.network(urlErr)
        }
    }
}
