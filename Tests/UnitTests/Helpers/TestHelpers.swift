import Foundation
import XCTest
@testable import ScaleUp

// MARK: - MockURLProtocol

/// A configurable `URLProtocol` subclass that intercepts `URLSession` requests
/// and returns pre-configured responses. Thread-safe via `NSLock`.
final class MockURLProtocol: URLProtocol {

    /// Handler invoked for every intercepted request. Set before making requests.
    /// Return `(HTTPURLResponse, Data)` or throw an error.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Collects all intercepted requests for later assertions.
    nonisolated(unsafe) private static var _capturedRequests: [URLRequest] = []
    nonisolated(unsafe) private static let lock = NSLock()

    static var capturedRequests: [URLRequest] {
        lock.withLock { _capturedRequests }
    }

    static var lastCapturedRequest: URLRequest? {
        capturedRequests.last
    }

    static func reset() {
        lock.withLock {
            _capturedRequests.removeAll()
        }
        requestHandler = nil
    }

    // MARK: - URLProtocol Overrides

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.withLock {
            Self._capturedRequests.append(request)
        }

        guard let handler = Self.requestHandler else {
            let error = NSError(domain: "MockURLProtocol", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "No request handler set"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - MockTokenProvider

/// A mock `TokenProviding` implementation for testing.
final class MockTokenProvider: TokenProviding, @unchecked Sendable {

    private let lock = NSLock()

    private var _accessToken: String?
    var accessToken: String? {
        get async { lock.withLock { _accessToken } }
    }

    private var _refreshResult: Result<String, Error> = .success("refreshed-token")
    private var _refreshDelay: UInt64 = 0
    private var _refreshCallCount: Int = 0

    var refreshCallCount: Int {
        lock.withLock { _refreshCallCount }
    }

    init(accessToken: String? = "test-access-token") {
        self._accessToken = accessToken
    }

    func setAccessToken(_ token: String?) {
        lock.withLock { _accessToken = token }
    }

    func setRefreshResult(_ result: Result<String, Error>) {
        lock.withLock { _refreshResult = result }
    }

    func setRefreshDelay(nanoseconds: UInt64) {
        lock.withLock { _refreshDelay = nanoseconds }
    }

    func refreshAccessToken() async throws -> String {
        let (result, delay) = lock.withLock {
            _refreshCallCount += 1
            return (_refreshResult, _refreshDelay)
        }

        if delay > 0 {
            try await Task.sleep(nanoseconds: delay)
        }

        switch result {
        case .success(let token):
            lock.withLock { _accessToken = token }
            return token
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock Session Configuration

/// Creates a `URLSessionConfiguration` that routes all requests through `MockURLProtocol`.
func makeMockSessionConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    config.timeoutIntervalForRequest = 5
    config.timeoutIntervalForResource = 5
    return config
}

// MARK: - HTTP Response Helpers

/// Creates a successful `HTTPURLResponse` with the given status code.
func makeHTTPResponse(url: URL = APIClient.baseURL,
                      statusCode: Int = 200,
                      headers: [String: String]? = ["Content-Type": "application/json"]) -> HTTPURLResponse {
    HTTPURLResponse(url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers)!
}

// MARK: - JSONFactory

/// Helper to create JSON `Data` payloads for testing API responses and model decoding.
enum JSONFactory {

    // MARK: - API Response Wrappers

    /// Wraps `data` in the standard `{ success, message, data }` envelope.
    static func apiResponse<T: Encodable>(success: Bool = true,
                                           message: String? = nil,
                                           data: T) -> Data {
        let wrapper: [String: Any] = [
            "success": success,
            "message": message as Any,
            "data": try! JSONSerialization.jsonObject(with: JSONEncoder().encode(data))
        ]
        return try! JSONSerialization.data(withJSONObject: wrapper)
    }

    /// Creates a successful API response wrapping raw JSON data.
    static func apiResponseRaw(success: Bool = true,
                                message: String? = nil,
                                dataJSON: [String: Any]) -> Data {
        var wrapper: [String: Any] = [
            "success": success,
            "data": dataJSON
        ]
        if let message { wrapper["message"] = message }
        return try! JSONSerialization.data(withJSONObject: wrapper)
    }

    /// Creates a void API response (no data field).
    static func apiVoidResponse(success: Bool = true,
                                 message: String? = nil,
                                 error: [String: Any]? = nil) -> Data {
        var wrapper: [String: Any] = ["success": success]
        if let message { wrapper["message"] = message }
        if let error { wrapper["error"] = error }
        return try! JSONSerialization.data(withJSONObject: wrapper)
    }

    /// Creates an error API response.
    static func apiErrorResponse(success: Bool = false,
                                  message: String? = nil,
                                  errorCode: String? = nil,
                                  errorDetails: String? = nil) -> Data {
        var wrapper: [String: Any] = ["success": success]
        if let message { wrapper["message"] = message }
        var errorObj: [String: Any] = [:]
        if let errorCode { errorObj["code"] = errorCode }
        if let errorDetails { errorObj["details"] = errorDetails }
        if !errorObj.isEmpty { wrapper["error"] = errorObj }
        return try! JSONSerialization.data(withJSONObject: wrapper)
    }

    // MARK: - User JSON

    static func userJSON(
        id: String = "507f1f77bcf86cd799439011",
        email: String = "test@example.com",
        phone: String? = nil,
        isPhoneVerified: Bool = false,
        isEmailVerified: Bool = true,
        firstName: String = "John",
        lastName: String = "Doe",
        username: String? = "johndoe",
        profilePicture: String? = nil,
        bio: String? = "A test user",
        dateOfBirth: String? = nil,
        location: String? = "San Francisco",
        education: [[String: Any]] = [],
        workExperience: [[String: Any]] = [],
        skills: [String] = ["Swift", "iOS"],
        role: String = "consumer",
        authProvider: String = "email",
        onboardingComplete: Bool = true,
        onboardingStep: Int = 5,
        followersCount: Int = 10,
        followingCount: Int = 20,
        isActive: Bool = true,
        isBanned: Bool = false,
        lastLoginAt: String? = "2025-01-15T10:30:00.000Z",
        createdAt: String = "2025-01-01T00:00:00.000Z"
    ) -> [String: Any] {
        var json: [String: Any] = [
            "_id": id,
            "email": email,
            "isPhoneVerified": isPhoneVerified,
            "isEmailVerified": isEmailVerified,
            "firstName": firstName,
            "lastName": lastName,
            "education": education,
            "workExperience": workExperience,
            "skills": skills,
            "role": role,
            "authProvider": authProvider,
            "onboardingComplete": onboardingComplete,
            "onboardingStep": onboardingStep,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "isActive": isActive,
            "isBanned": isBanned,
            "createdAt": createdAt
        ]
        if let phone { json["phone"] = phone }
        if let username { json["username"] = username }
        if let profilePicture { json["profilePicture"] = profilePicture }
        if let bio { json["bio"] = bio }
        if let dateOfBirth { json["dateOfBirth"] = dateOfBirth }
        if let location { json["location"] = location }
        if let lastLoginAt { json["lastLoginAt"] = lastLoginAt }
        return json
    }

    static func userAPIResponse(overrides: [String: Any] = [:]) -> Data {
        var json = userJSON()
        for (key, value) in overrides { json[key] = value }
        return apiResponseRaw(dataJSON: json)
    }

    // MARK: - PublicUser JSON

    static func publicUserJSON(
        id: String = "507f1f77bcf86cd799439011",
        firstName: String = "Jane",
        lastName: String = "Smith",
        username: String? = "janesmith",
        profilePicture: String? = nil,
        bio: String? = "Public bio",
        role: String = "creator",
        followersCount: Int = 100,
        followingCount: Int = 50
    ) -> [String: Any] {
        var json: [String: Any] = [
            "_id": id,
            "firstName": firstName,
            "lastName": lastName,
            "role": role,
            "followersCount": followersCount,
            "followingCount": followingCount
        ]
        if let username { json["username"] = username }
        if let profilePicture { json["profilePicture"] = profilePicture }
        if let bio { json["bio"] = bio }
        return json
    }

    // MARK: - AuthResponse JSON

    static func authResponseJSON(
        userOverrides: [String: Any] = [:],
        accessToken: String = "access-token-123",
        refreshToken: String = "refresh-token-456"
    ) -> [String: Any] {
        var user = userJSON()
        for (key, value) in userOverrides { user[key] = value }
        return [
            "user": user,
            "accessToken": accessToken,
            "refreshToken": refreshToken
        ]
    }

    // MARK: - Content JSON

    static func contentCreatorJSON(
        id: String = "507f1f77bcf86cd799439012",
        firstName: String = "Creator",
        lastName: String = "One",
        username: String? = "creator1",
        profilePicture: String? = nil
    ) -> [String: Any] {
        var json: [String: Any] = [
            "_id": id,
            "firstName": firstName,
            "lastName": lastName
        ]
        if let username { json["username"] = username }
        if let profilePicture { json["profilePicture"] = profilePicture }
        return json
    }

    static func contentJSON(
        id: String = "507f1f77bcf86cd799439099",
        title: String = "Test Content",
        description: String? = "A test piece of content",
        contentType: String = "video",
        contentURL: String = "https://example.com/video.mp4",
        thumbnailURL: String? = "https://example.com/thumb.jpg",
        duration: Int? = 600,
        sourceType: String = "original",
        domain: String = "programming",
        topics: [String] = ["Swift"],
        tags: [String] = ["ios", "swift"],
        difficulty: String = "intermediate",
        status: String = "published",
        publishedAt: String? = "2025-01-10T12:00:00.000Z",
        viewCount: Int = 1000,
        likeCount: Int = 50,
        commentCount: Int = 10,
        saveCount: Int = 25,
        averageRating: Double = 4.5,
        ratingCount: Int = 20,
        recommendationScore: Double? = 0.85,
        createdAt: String = "2025-01-01T00:00:00.000Z",
        updatedAt: String = "2025-01-15T00:00:00.000Z"
    ) -> [String: Any] {
        var json: [String: Any] = [
            "_id": id,
            "creatorId": contentCreatorJSON(),
            "title": title,
            "contentType": contentType,
            "contentURL": contentURL,
            "sourceType": sourceType,
            "domain": domain,
            "topics": topics,
            "tags": tags,
            "difficulty": difficulty,
            "status": status,
            "viewCount": viewCount,
            "likeCount": likeCount,
            "commentCount": commentCount,
            "saveCount": saveCount,
            "averageRating": averageRating,
            "ratingCount": ratingCount,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        if let description { json["description"] = description }
        if let thumbnailURL { json["thumbnailURL"] = thumbnailURL }
        if let duration { json["duration"] = duration }
        if let publishedAt { json["publishedAt"] = publishedAt }
        if let recommendationScore { json["_recommendationScore"] = recommendationScore }
        return json
    }

    // MARK: - Quiz JSON

    static func quizQuestionJSON(
        question: String = "What is Swift?",
        options: [String] = ["A language", "A bird", "A car", "A framework"],
        correctAnswer: Int = 0,
        explanation: String? = "Swift is a programming language by Apple.",
        difficulty: String? = "beginner",
        type: String? = "multiple_choice",
        relatedContent: String? = nil,
        relatedTimestamp: Double? = nil
    ) -> [String: Any] {
        var json: [String: Any] = [
            "question": question,
            "options": options,
            "correctAnswer": correctAnswer
        ]
        if let explanation { json["explanation"] = explanation }
        if let difficulty { json["difficulty"] = difficulty }
        if let type { json["type"] = type }
        if let relatedContent { json["relatedContent"] = relatedContent }
        if let relatedTimestamp { json["relatedTimestamp"] = relatedTimestamp }
        return json
    }

    static func quizJSON(
        id: String = "507f1f77bcf86cd799439033",
        userId: String = "507f1f77bcf86cd799439011",
        type: String = "topic_consolidation",
        topic: String = "Swift Basics",
        sourceContent: [String] = ["content1", "content2"],
        questions: [[String: Any]]? = nil,
        passingScore: Int = 70,
        timeLimit: Int? = 30,
        status: String = "ready",
        expiresAt: String? = "2025-02-01T00:00:00.000Z",
        createdAt: String = "2025-01-15T00:00:00.000Z"
    ) -> [String: Any] {
        var json: [String: Any] = [
            "_id": id,
            "userId": userId,
            "type": type,
            "topic": topic,
            "sourceContent": sourceContent,
            "questions": questions ?? [quizQuestionJSON()],
            "passingScore": passingScore,
            "status": status,
            "createdAt": createdAt
        ]
        if let timeLimit { json["timeLimit"] = timeLimit }
        if let expiresAt { json["expiresAt"] = expiresAt }
        return json
    }

    static func quizAttemptJSON(
        id: String = "507f1f77bcf86cd799439044",
        quizId: String = "507f1f77bcf86cd799439033",
        userId: String = "507f1f77bcf86cd799439011",
        answers: [[String: Any]] = [
            ["questionIndex": 0, "selectedAnswer": 0, "timeTaken": 15]
        ],
        score: [String: Any] = [
            "total": 1, "correct": 1, "incorrect": 0, "skipped": 0, "percentage": 100.0
        ],
        status: String = "completed",
        startedAt: String = "2025-01-15T10:00:00.000Z",
        completedAt: String? = "2025-01-15T10:05:00.000Z"
    ) -> [String: Any] {
        var json: [String: Any] = [
            "_id": id,
            "quizId": quizId,
            "userId": userId,
            "answers": answers,
            "score": score,
            "status": status,
            "startedAt": startedAt
        ]
        if let completedAt { json["completedAt"] = completedAt }
        return json
    }

    // MARK: - Journey JSON

    static func journeyPhaseDetailJSON(
        name: String = "foundation",
        description: String = "Build foundational knowledge",
        topics: [String] = ["Basics", "Syntax"],
        weekNumbers: [Int] = [1, 2],
        estimatedDuration: String? = "2 weeks"
    ) -> [String: Any] {
        var json: [String: Any] = [
            "name": name,
            "description": description,
            "topics": topics,
            "weekNumbers": weekNumbers
        ]
        if let estimatedDuration { json["estimatedDuration"] = estimatedDuration }
        return json
    }

    static func dailyAssignmentJSON(
        day: Int = 1,
        topics: [String] = ["Variables"],
        contentIds: [String] = ["c1", "c2"],
        estimatedMinutes: Int = 45,
        isRestDay: Bool = false
    ) -> [String: Any] {
        [
            "day": day,
            "topics": topics,
            "contentIds": contentIds,
            "estimatedMinutes": estimatedMinutes,
            "isRestDay": isRestDay
        ]
    }

    static func weeklyPlanJSON(
        weekNumber: Int = 1,
        theme: String = "Getting Started",
        dailyAssignments: [[String: Any]]? = nil
    ) -> [String: Any] {
        [
            "weekNumber": weekNumber,
            "theme": theme,
            "dailyAssignments": dailyAssignments ?? [dailyAssignmentJSON()]
        ]
    }

    static func milestoneJSON(
        id: String = "507f1f77bcf86cd799439055",
        type: String = "content_completion",
        title: String = "Complete Week 1",
        description: String? = "Finish all week 1 assignments",
        targetValue: Int = 5,
        currentValue: Int = 3,
        status: String = "in_progress",
        completedAt: String? = nil
    ) -> [String: Any] {
        var json: [String: Any] = [
            "_id": id,
            "type": type,
            "title": title,
            "targetValue": targetValue,
            "currentValue": currentValue,
            "status": status
        ]
        if let description { json["description"] = description }
        if let completedAt { json["completedAt"] = completedAt }
        return json
    }

    static func journeyProgressJSON(
        overallPercentage: Double = 45.0,
        contentConsumed: Int = 9,
        contentAssigned: Int = 20,
        quizzesCompleted: Int = 2,
        quizzesAssigned: Int = 5,
        currentStreak: Int = 3,
        milestonesCompleted: Int = 1,
        milestonesTotal: Int = 4
    ) -> [String: Any] {
        [
            "overallPercentage": overallPercentage,
            "contentConsumed": contentConsumed,
            "contentAssigned": contentAssigned,
            "quizzesCompleted": quizzesCompleted,
            "quizzesAssigned": quizzesAssigned,
            "currentStreak": currentStreak,
            "milestonesCompleted": milestonesCompleted,
            "milestonesTotal": milestonesTotal
        ]
    }

    static func journeyJSON(
        id: String = "507f1f77bcf86cd799439066",
        userId: String = "507f1f77bcf86cd799439011",
        objectiveId: String = "507f1f77bcf86cd799439077",
        title: String = "Learn Swift Programming",
        phases: [[String: Any]]? = nil,
        weeklyPlans: [[String: Any]]? = nil,
        milestones: [[String: Any]]? = nil,
        progress: [String: Any]? = nil,
        currentPhase: String = "foundation",
        currentWeek: Int = 1,
        status: String = "active",
        createdAt: String = "2025-01-01T00:00:00.000Z"
    ) -> [String: Any] {
        [
            "_id": id,
            "userId": userId,
            "objectiveId": objectiveId,
            "title": title,
            "phases": phases ?? [journeyPhaseDetailJSON()],
            "weeklyPlans": weeklyPlans ?? [weeklyPlanJSON()],
            "milestones": milestones ?? [milestoneJSON()],
            "progress": progress ?? journeyProgressJSON(),
            "currentPhase": currentPhase,
            "currentWeek": currentWeek,
            "status": status,
            "createdAt": createdAt
        ]
    }

    static func todayPlanJSON(
        weekNumber: Int = 1,
        day: Int = 3,
        plan: [String: Any]? = nil,
        weekGoals: [String]? = ["Complete 3 lessons", "Pass quiz"]
    ) -> [String: Any] {
        var json: [String: Any] = [
            "weekNumber": weekNumber,
            "day": day,
            "plan": plan ?? dailyAssignmentJSON(day: day)
        ]
        if let weekGoals { json["weekGoals"] = weekGoals }
        return json
    }

    // MARK: - Data Conversion

    /// Converts a dictionary to JSON `Data`.
    static func data(from dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict)
    }
}

// MARK: - Test Error

/// Simple error type for testing.
enum TestError: Error, LocalizedError {
    case mockFailure
    case refreshFailed

    var errorDescription: String? {
        switch self {
        case .mockFailure: return "Mock failure"
        case .refreshFailed: return "Refresh failed"
        }
    }
}
