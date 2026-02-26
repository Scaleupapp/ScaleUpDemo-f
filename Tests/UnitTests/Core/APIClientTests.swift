import XCTest
@testable import ScaleUp

// MARK: - API Client Tests

/// Tests for `APIClient` covering request building, response decoding,
/// error mapping, void responses, and token injection.
///
/// Uses `MockURLProtocol` to intercept `URLSession` traffic.
/// Because `APIClient` creates its own session with `URLSessionConfiguration.default`,
/// we register `MockURLProtocol` globally via `URLProtocol.registerClass(_:)`.
final class APIClientTests: XCTestCase {

    // MARK: - Properties

    private var sut: APIClient!
    private var mockTokenProvider: MockTokenProvider!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        URLProtocol.registerClass(MockURLProtocol.self)

        mockTokenProvider = MockTokenProvider(accessToken: "test-token-123")
        sut = APIClient(tokenProvider: mockTokenProvider)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        sut = nil
        mockTokenProvider = nil
        super.tearDown()
    }

    // MARK: - Simple Decodable for Testing

    private struct TestItem: Codable, Equatable {
        let name: String
        let value: Int
    }

    // MARK: - Successful Typed Response

    func testRequest_successfulResponse_decodesTypedData() async throws {
        // Given
        let expectedItem = TestItem(name: "Widget", value: 42)
        let responseData = JSONFactory.apiResponse(data: expectedItem)

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let endpoint = Endpoint.get("/test/items", requiresAuth: false)
        let result: TestItem = try await sut.request(endpoint)

        // Then
        XCTAssertEqual(result.name, "Widget")
        XCTAssertEqual(result.value, 42)
    }

    func testRequest_successfulResponse_withNestedData() async throws {
        // Given
        let items = [TestItem(name: "A", value: 1), TestItem(name: "B", value: 2)]
        let responseData = JSONFactory.apiResponse(data: items)

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let endpoint = Endpoint.get("/test/items", requiresAuth: false)
        let result: [TestItem] = try await sut.request(endpoint)

        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "A")
        XCTAssertEqual(result[1].name, "B")
    }

    // MARK: - Void Response

    func testRequestVoid_successfulResponse_doesNotThrow() async throws {
        // Given
        let responseData = JSONFactory.apiVoidResponse(success: true, message: "Done")

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When / Then — should not throw
        let endpoint = Endpoint.post("/test/action", requiresAuth: false)
        try await sut.requestVoid(endpoint)
    }

    func testRequestVoid_failedResponse_throwsBadRequest() async throws {
        // Given
        let responseData = JSONFactory.apiVoidResponse(
            success: false,
            message: "Validation failed"
        )

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When / Then
        let endpoint = Endpoint.post("/test/action", requiresAuth: false)
        do {
            try await sut.requestVoid(endpoint)
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            if case .badRequest(let message) = error {
                XCTAssertEqual(message, "Validation failed")
            } else {
                XCTFail("Expected badRequest, got \(error)")
            }
        }
    }

    // MARK: - Error Mapping by Status Code

    func testRequest_400_throwsBadRequest() async throws {
        try await assertStatusCodeThrows(
            statusCode: 400,
            errorDetail: ["code": "VALIDATION_ERROR", "details": "Invalid input"],
            expectedError: { error in
                if case .badRequest(let msg) = error {
                    XCTAssertEqual(msg, "Invalid input")
                } else {
                    XCTFail("Expected badRequest, got \(error)")
                }
            }
        )
    }

    func testRequest_401_throwsUnauthorized() async throws {
        // Create a client without a token provider so 401 retry is skipped
        let noAuthClient = APIClient(tokenProvider: nil)

        let responseData = JSONFactory.apiErrorResponse(
            errorCode: "UNAUTHORIZED",
            errorDetails: "Token expired"
        )

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 401), responseData)
        }

        let endpoint = Endpoint.get("/test", requiresAuth: false)
        do {
            let _: TestItem = try await noAuthClient.request(endpoint)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            if case .unauthorized = error {
                // Success
            } else {
                XCTFail("Expected unauthorized, got \(error)")
            }
        }
    }

    func testRequest_403_throwsForbidden() async throws {
        try await assertStatusCodeThrows(
            statusCode: 403,
            expectedError: { error in
                if case .forbidden = error {
                    // Success
                } else {
                    XCTFail("Expected forbidden, got \(error)")
                }
            }
        )
    }

    func testRequest_404_throwsNotFound() async throws {
        try await assertStatusCodeThrows(
            statusCode: 404,
            expectedError: { error in
                if case .notFound = error {
                    // Success
                } else {
                    XCTFail("Expected notFound, got \(error)")
                }
            }
        )
    }

    func testRequest_409_throwsConflict() async throws {
        try await assertStatusCodeThrows(
            statusCode: 409,
            errorDetail: ["code": "CONFLICT", "details": "Already exists"],
            expectedError: { error in
                if case .conflict(let msg) = error {
                    XCTAssertEqual(msg, "Already exists")
                } else {
                    XCTFail("Expected conflict, got \(error)")
                }
            }
        )
    }

    func testRequest_429_throwsRateLimited() async throws {
        try await assertStatusCodeThrows(
            statusCode: 429,
            expectedError: { error in
                if case .rateLimited = error {
                    // Success
                } else {
                    XCTFail("Expected rateLimited, got \(error)")
                }
            }
        )
    }

    func testRequest_500_throwsServerError() async throws {
        try await assertStatusCodeThrows(
            statusCode: 500,
            expectedError: { error in
                if case .serverError = error {
                    // Success
                } else {
                    XCTFail("Expected serverError, got \(error)")
                }
            }
        )
    }

    func testRequest_502_throwsServerError() async throws {
        try await assertStatusCodeThrows(
            statusCode: 502,
            expectedError: { error in
                if case .serverError = error {
                    // Success
                } else {
                    XCTFail("Expected serverError, got \(error)")
                }
            }
        )
    }

    // MARK: - Network Error

    func testRequest_networkError_throwsNetworkError() async throws {
        // Given
        let networkError = NSError(domain: NSURLErrorDomain,
                                    code: NSURLErrorNotConnectedToInternet,
                                    userInfo: [NSLocalizedDescriptionKey: "No internet"])

        MockURLProtocol.requestHandler = { _ in
            throw networkError
        }

        // When / Then
        let endpoint = Endpoint.get("/test", requiresAuth: false)
        do {
            let _: TestItem = try await sut.request(endpoint)
            XCTFail("Expected network error")
        } catch let error as APIError {
            if case .networkError(let underlyingError) = error {
                XCTAssertEqual((underlyingError as NSError).code, NSURLErrorNotConnectedToInternet)
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        }
    }

    // MARK: - Decoding Error

    func testRequest_invalidJSON_throwsDecodingError() async throws {
        // Given - return valid API response but with wrong data shape
        let badData = """
        {"success": true, "data": {"unexpected": "shape"}}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), badData)
        }

        // When / Then
        let endpoint = Endpoint.get("/test", requiresAuth: false)
        do {
            let _: TestItem = try await sut.request(endpoint)
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            if case .decodingError = error {
                // Success
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    func testRequestVoid_invalidJSON_throwsDecodingError() async throws {
        // Given - return completely invalid JSON
        let badData = "not json at all".data(using: .utf8)!

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), badData)
        }

        // When / Then
        let endpoint = Endpoint.post("/test", requiresAuth: false)
        do {
            try await sut.requestVoid(endpoint)
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            if case .decodingError = error {
                // Success
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    // MARK: - Request Building

    func testRequest_buildsCorrectURL() async throws {
        // Given
        let responseData = JSONFactory.apiResponse(data: TestItem(name: "x", value: 1))

        MockURLProtocol.requestHandler = { request in
            // Verify URL
            let urlString = request.url?.absoluteString ?? ""
            XCTAssertTrue(urlString.contains("/api/v1/users/profile"),
                         "URL should contain the endpoint path, got: \(urlString)")
            return (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let endpoint = Endpoint.get("/users/profile", requiresAuth: false)
        let _: TestItem = try await sut.request(endpoint)
    }

    func testRequest_setsCorrectHTTPMethod() async throws {
        // Given
        let responseData = JSONFactory.apiVoidResponse(success: true)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let endpoint = Endpoint.post("/test", requiresAuth: false)
        try await sut.requestVoid(endpoint)
    }

    func testRequest_setsContentTypeHeaders() async throws {
        // Given
        let responseData = JSONFactory.apiResponse(data: TestItem(name: "x", value: 1))

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let endpoint = Endpoint.get("/test", requiresAuth: false)
        let _: TestItem = try await sut.request(endpoint)
    }

    func testRequest_setsQueryItems() async throws {
        // Given
        let responseData = JSONFactory.apiResponse(data: TestItem(name: "x", value: 1))

        MockURLProtocol.requestHandler = { request in
            let urlString = request.url?.absoluteString ?? ""
            XCTAssertTrue(urlString.contains("page=1"), "Should contain page query item")
            XCTAssertTrue(urlString.contains("limit=20"), "Should contain limit query item")
            return (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "20")
        ]
        let endpoint = Endpoint.get("/test", queryItems: queryItems, requiresAuth: false)
        let _: TestItem = try await sut.request(endpoint)
    }

    func testRequest_encodesBodyAsJSON() async throws {
        // Given
        struct RequestBody: Codable {
            let title: String
            let count: Int
        }

        let responseData = JSONFactory.apiVoidResponse(success: true)

        MockURLProtocol.requestHandler = { request in
            // Verify body is present
            XCTAssertNotNil(request.httpBody ?? request.bodyStreamData,
                           "POST with body should have httpBody")

            if let bodyData = request.httpBody {
                let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
                XCTAssertEqual(json?["title"] as? String, "Test Title")
                XCTAssertEqual(json?["count"] as? Int, 5)
            }

            return (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let body = RequestBody(title: "Test Title", count: 5)
        let endpoint = Endpoint.post("/test", body: body, requiresAuth: false)
        try await sut.requestVoid(endpoint)
    }

    // MARK: - Bearer Token Injection

    func testRequest_withAuth_injectsBearerToken() async throws {
        // Given
        let responseData = JSONFactory.apiResponse(data: TestItem(name: "x", value: 1))

        MockURLProtocol.requestHandler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertEqual(authHeader, "Bearer test-token-123",
                          "Should inject Bearer token from token provider")
            return (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let endpoint = Endpoint.get("/test", requiresAuth: true)
        let _: TestItem = try await sut.request(endpoint)
    }

    func testRequest_withoutAuth_doesNotInjectToken() async throws {
        // Given — client with no token provider
        let noAuthClient = APIClient(tokenProvider: nil)
        let responseData = JSONFactory.apiResponse(data: TestItem(name: "x", value: 1))

        MockURLProtocol.requestHandler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertNil(authHeader, "Should not have Authorization header without provider")
            return (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When
        let endpoint = Endpoint.get("/test", requiresAuth: true)
        let _: TestItem = try await noAuthClient.request(endpoint)
    }

    // MARK: - API Response Failure (success: false)

    func testRequest_successFalse_throwsBadRequestWithMessage() async throws {
        // Given - HTTP 200 but success: false in response body
        let responseData = JSONFactory.apiErrorResponse(
            success: false,
            message: "Email already in use",
            errorDetails: "Duplicate email detected"
        )

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When / Then
        let endpoint = Endpoint.post("/auth/register", requiresAuth: false)
        do {
            let _: TestItem = try await sut.request(endpoint)
            XCTFail("Expected badRequest error")
        } catch let error as APIError {
            if case .badRequest(let msg) = error {
                XCTAssertEqual(msg, "Duplicate email detected")
            } else {
                XCTFail("Expected badRequest, got \(error)")
            }
        }
    }

    func testRequest_successFalseWithoutDetail_fallsBackToMessage() async throws {
        // Given
        let responseData: Data = {
            let json: [String: Any] = ["success": false, "message": "Something went wrong"]
            return try! JSONSerialization.data(withJSONObject: json)
        }()

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 200), responseData)
        }

        // When / Then
        let endpoint = Endpoint.get("/test", requiresAuth: false)
        do {
            let _: TestItem = try await sut.request(endpoint)
            XCTFail("Expected badRequest error")
        } catch let error as APIError {
            if case .badRequest(let msg) = error {
                XCTAssertEqual(msg, "Something went wrong")
            } else {
                XCTFail("Expected badRequest, got \(error)")
            }
        }
    }

    // MARK: - 401 Retry with Token Refresh

    func testRequest_401_retriesAfterTokenRefresh() async throws {
        // Given
        var callCount = 0
        let responseData = JSONFactory.apiResponse(data: TestItem(name: "Refreshed", value: 99))

        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                // First call returns 401
                return (makeHTTPResponse(statusCode: 401),
                        JSONFactory.apiErrorResponse(errorCode: "UNAUTHORIZED"))
            } else {
                // Second call (after refresh) returns success
                return (makeHTTPResponse(statusCode: 200), responseData)
            }
        }

        // When
        let endpoint = Endpoint.get("/test", requiresAuth: true)
        let result: TestItem = try await sut.request(endpoint)

        // Then
        XCTAssertEqual(result.name, "Refreshed")
        XCTAssertEqual(result.value, 99)
        XCTAssertEqual(mockTokenProvider.refreshCallCount, 1, "Should have triggered one refresh")
    }

    func testRequest_401_refreshFails_throwsUnauthorized() async throws {
        // Given
        mockTokenProvider.setRefreshResult(.failure(TestError.refreshFailed))

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: 401),
             JSONFactory.apiErrorResponse(errorCode: "UNAUTHORIZED"))
        }

        // When / Then
        let endpoint = Endpoint.get("/test", requiresAuth: true)
        do {
            let _: TestItem = try await sut.request(endpoint)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            if case .unauthorized = error {
                // Success
            } else {
                XCTFail("Expected unauthorized, got \(error)")
            }
        }
    }

    // MARK: - Base URL

    func testBaseURL_isCorrect() {
        XCTAssertEqual(APIClient.baseURL.absoluteString, "http://localhost:5001/api/v1")
    }

    // MARK: - Helpers

    /// Helper to test that a given HTTP status code throws the expected `APIError`.
    private func assertStatusCodeThrows(
        statusCode: Int,
        errorDetail: [String: Any]? = nil,
        expectedError: (APIError) -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws {
        // Use a client without token provider to avoid 401 retry logic
        let client = APIClient(tokenProvider: nil)

        var responseJSON: [String: Any] = ["success": false]
        if let errorDetail {
            responseJSON["error"] = errorDetail
        }
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        MockURLProtocol.requestHandler = { _ in
            (makeHTTPResponse(statusCode: statusCode), responseData)
        }

        let endpoint = Endpoint.get("/test", requiresAuth: false)
        do {
            let _: TestItem = try await client.request(endpoint)
            XCTFail("Expected error for status code \(statusCode)", file: file, line: line)
        } catch let error as APIError {
            expectedError(error)
        }
    }
}

// MARK: - URLRequest Body Stream Helper

private extension URLRequest {
    /// Reads the body from `httpBodyStream` if `httpBody` is nil.
    var bodyStreamData: Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            guard bytesRead > 0 else { break }
            data.append(buffer, count: bytesRead)
        }
        return data.isEmpty ? nil : data
    }
}
