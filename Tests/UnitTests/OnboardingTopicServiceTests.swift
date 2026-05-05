import XCTest
@testable import ScaleUp

@MainActor
final class OnboardingTopicServiceTests: XCTestCase {

    override func setUp() async throws {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
    }

    func test_fetchSuggestedTopics_decodesResponse() async throws {
        let json = """
        {"topics":[{"canonicalName":"product-strategy","name":"Product Strategy","description":"Vision and roadmap","isFutureProofing":false,"baseDifficulty":"intermediate"}],"cacheHit":true,"source":"curated"}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.absoluteString.hasSuffix("/onboarding/topics/suggest") ?? false)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let session = makeSession()
        let service = OnboardingTopicService(session: session, baseURL: URL(string: "https://example.test")!, authToken: { "token" })
        let result = try await service.fetchSuggestedTopics(
            objectiveType: .upskilling,
            specifics: ["targetSkill": "Product Management"],
            company: nil
        )

        XCTAssertEqual(result.topics.count, 1)
        XCTAssertEqual(result.topics[0].canonicalName, "product-strategy")
        XCTAssertTrue(result.cacheHit)
    }

    func test_fetchSuggestedTopics_throwsOn500() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = OnboardingTopicService(
            session: makeSession(),
            baseURL: URL(string: "https://example.test")!,
            authToken: { "token" }
        )
        do {
            _ = try await service.fetchSuggestedTopics(objectiveType: .upskilling, specifics: [:], company: nil)
            XCTFail("expected throw")
        } catch {
            // ok
        }
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
