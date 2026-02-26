import XCTest
@testable import ScaleUp

// MARK: - Token Interceptor Tests

/// Tests for `TokenInterceptor` covering single refresh, concurrent serialization,
/// and failure propagation.
final class TokenInterceptorTests: XCTestCase {

    // MARK: - Properties

    private var mockProvider: MockTokenProvider!
    private var sut: TokenInterceptor!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockProvider = MockTokenProvider(accessToken: "initial-token")
        sut = TokenInterceptor(tokenProvider: mockProvider)
    }

    override func tearDown() {
        sut = nil
        mockProvider = nil
        super.tearDown()
    }

    // MARK: - Single Token Refresh

    func testValidAccessToken_callsRefreshAndReturnsNewToken() async throws {
        // Given
        mockProvider.setRefreshResult(.success("new-token-abc"))

        // When
        let token = try await sut.validAccessToken()

        // Then
        XCTAssertEqual(token, "new-token-abc")
        XCTAssertEqual(mockProvider.refreshCallCount, 1)
    }

    func testValidAccessToken_updatesProviderAccessToken() async throws {
        // Given
        mockProvider.setRefreshResult(.success("updated-token"))

        // When
        _ = try await sut.validAccessToken()

        // Then
        let currentToken = await mockProvider.accessToken
        XCTAssertEqual(currentToken, "updated-token")
    }

    // MARK: - Refresh Failure

    func testValidAccessToken_refreshFailure_throwsError() async {
        // Given
        mockProvider.setRefreshResult(.failure(TestError.refreshFailed))

        // When / Then
        do {
            _ = try await sut.validAccessToken()
            XCTFail("Expected refresh to throw")
        } catch {
            XCTAssertTrue(error is TestError, "Expected TestError, got \(type(of: error))")
        }
    }

    func testValidAccessToken_refreshFailure_onlyCallsRefreshOnce() async {
        // Given
        mockProvider.setRefreshResult(.failure(TestError.refreshFailed))

        // When
        _ = try? await sut.validAccessToken()

        // Then
        XCTAssertEqual(mockProvider.refreshCallCount, 1)
    }

    // MARK: - Concurrent Refresh Serialization

    func testValidAccessToken_concurrentCalls_onlyRefreshOnce() async throws {
        // Given - add a delay to the refresh so concurrent calls overlap
        mockProvider.setRefreshResult(.success("shared-token"))
        mockProvider.setRefreshDelay(nanoseconds: 100_000_000) // 100ms

        // When - launch multiple concurrent requests
        async let token1 = sut.validAccessToken()
        async let token2 = sut.validAccessToken()
        async let token3 = sut.validAccessToken()

        let results = try await [token1, token2, token3]

        // Then - all callers get the same token, refresh called only once
        for token in results {
            XCTAssertEqual(token, "shared-token")
        }
        XCTAssertEqual(mockProvider.refreshCallCount, 1,
                       "Only one refresh call should be made for concurrent requests")
    }

    func testValidAccessToken_concurrentCalls_allGetSameToken() async throws {
        // Given
        mockProvider.setRefreshResult(.success("concurrent-token"))
        mockProvider.setRefreshDelay(nanoseconds: 50_000_000) // 50ms

        // When
        let results = try await withThrowingTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await self.sut.validAccessToken()
                }
            }

            var tokens: [String] = []
            for try await token in group {
                tokens.append(token)
            }
            return tokens
        }

        // Then
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0 == "concurrent-token" })
    }

    // MARK: - Concurrent Refresh Failure Propagates

    func testValidAccessToken_concurrentCalls_failurePropagates() async {
        // Given
        mockProvider.setRefreshResult(.failure(TestError.refreshFailed))
        mockProvider.setRefreshDelay(nanoseconds: 50_000_000) // 50ms

        // When
        let results = await withTaskGroup(of: Result<String, Error>.self, returning: [Result<String, Error>].self) { group in
            for _ in 0..<3 {
                group.addTask {
                    do {
                        let token = try await self.sut.validAccessToken()
                        return .success(token)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var outcomes: [Result<String, Error>] = []
            for await result in group {
                outcomes.append(result)
            }
            return outcomes
        }

        // Then - all callers receive the error
        XCTAssertEqual(results.count, 3)
        for result in results {
            switch result {
            case .success:
                XCTFail("Expected all callers to receive failure")
            case .failure(let error):
                XCTAssertTrue(error is TestError)
            }
        }
    }

    // MARK: - Sequential Calls

    func testValidAccessToken_sequentialCalls_refreshEachTime() async throws {
        // Given
        mockProvider.setRefreshResult(.success("token-1"))

        // When - first call
        let token1 = try await sut.validAccessToken()
        XCTAssertEqual(token1, "token-1")
        XCTAssertEqual(mockProvider.refreshCallCount, 1)

        // Given - change result for second call
        mockProvider.setRefreshResult(.success("token-2"))

        // When - second call (not concurrent, so triggers a new refresh)
        let token2 = try await sut.validAccessToken()

        // Then
        XCTAssertEqual(token2, "token-2")
        XCTAssertEqual(mockProvider.refreshCallCount, 2,
                       "Sequential calls should each trigger a refresh")
    }

    // MARK: - Recovery After Failure

    func testValidAccessToken_recoversAfterPreviousFailure() async throws {
        // Given - first call fails
        mockProvider.setRefreshResult(.failure(TestError.refreshFailed))
        _ = try? await sut.validAccessToken()
        XCTAssertEqual(mockProvider.refreshCallCount, 1)

        // Given - second call succeeds
        mockProvider.setRefreshResult(.success("recovered-token"))

        // When
        let token = try await sut.validAccessToken()

        // Then
        XCTAssertEqual(token, "recovered-token")
        XCTAssertEqual(mockProvider.refreshCallCount, 2)
    }
}
