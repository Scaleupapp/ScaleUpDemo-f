import XCTest
@testable import ScaleUp

// MARK: - Endpoint Tests

/// Tests for `Endpoint` factory methods, default values, query items,
/// body encoding, and `HTTPMethod` raw values.
final class EndpointTests: XCTestCase {

    // MARK: - Factory Method: .get

    func testGet_setsPathAndMethod() {
        let endpoint = Endpoint.get("/users/profile")

        XCTAssertEqual(endpoint.path, "/users/profile")
        XCTAssertEqual(endpoint.method, .get)
    }

    func testGet_defaultsRequiresAuthToTrue() {
        let endpoint = Endpoint.get("/test")

        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testGet_requiresAuthCanBeSetToFalse() {
        let endpoint = Endpoint.get("/auth/login", requiresAuth: false)

        XCTAssertFalse(endpoint.requiresAuth)
    }

    func testGet_bodyIsNil() {
        let endpoint = Endpoint.get("/test")

        XCTAssertNil(endpoint.body)
    }

    func testGet_queryItemsNilByDefault() {
        let endpoint = Endpoint.get("/test")

        XCTAssertNil(endpoint.queryItems)
    }

    func testGet_withQueryItems() {
        let queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "sort", value: "createdAt")
        ]
        let endpoint = Endpoint.get("/content", queryItems: queryItems)

        XCTAssertEqual(endpoint.queryItems?.count, 3)
        XCTAssertEqual(endpoint.queryItems?[0].name, "page")
        XCTAssertEqual(endpoint.queryItems?[0].value, "1")
        XCTAssertEqual(endpoint.queryItems?[1].name, "limit")
        XCTAssertEqual(endpoint.queryItems?[1].value, "20")
        XCTAssertEqual(endpoint.queryItems?[2].name, "sort")
        XCTAssertEqual(endpoint.queryItems?[2].value, "createdAt")
    }

    // MARK: - Factory Method: .post

    func testPost_setsPathAndMethod() {
        let endpoint = Endpoint.post("/auth/register")

        XCTAssertEqual(endpoint.path, "/auth/register")
        XCTAssertEqual(endpoint.method, .post)
    }

    func testPost_defaultsRequiresAuthToTrue() {
        let endpoint = Endpoint.post("/test")

        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testPost_bodyIsNilByDefault() {
        let endpoint = Endpoint.post("/test")

        XCTAssertNil(endpoint.body)
    }

    func testPost_withBody() {
        struct LoginBody: Codable {
            let email: String
            let password: String
        }

        let body = LoginBody(email: "test@example.com", password: "secret")
        let endpoint = Endpoint.post("/auth/login", body: body, requiresAuth: false)

        XCTAssertNotNil(endpoint.body)
        XCTAssertFalse(endpoint.requiresAuth)
    }

    func testPost_bodyIsEncodable() throws {
        struct TestBody: Codable, Equatable {
            let title: String
            let count: Int
        }

        let body = TestBody(title: "Hello", count: 5)
        let endpoint = Endpoint.post("/test", body: body)

        // Verify we can encode the body
        let encoder = JSONEncoder()
        let data = try encoder.encode(body)
        let decoded = try JSONDecoder().decode(TestBody.self, from: data)

        XCTAssertEqual(decoded.title, "Hello")
        XCTAssertEqual(decoded.count, 5)
        XCTAssertNotNil(endpoint.body)
    }

    // MARK: - Factory Method: .put

    func testPut_setsPathAndMethod() {
        let endpoint = Endpoint.put("/users/profile")

        XCTAssertEqual(endpoint.path, "/users/profile")
        XCTAssertEqual(endpoint.method, .put)
    }

    func testPut_defaultsRequiresAuthToTrue() {
        let endpoint = Endpoint.put("/test")

        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testPut_withBody() {
        struct UpdateBody: Codable {
            let firstName: String
        }

        let body = UpdateBody(firstName: "Jane")
        let endpoint = Endpoint.put("/users/profile", body: body)

        XCTAssertNotNil(endpoint.body)
    }

    func testPut_bodyIsNilByDefault() {
        let endpoint = Endpoint.put("/test")

        XCTAssertNil(endpoint.body)
    }

    // MARK: - Factory Method: .delete

    func testDelete_setsPathAndMethod() {
        let endpoint = Endpoint.delete("/content/123")

        XCTAssertEqual(endpoint.path, "/content/123")
        XCTAssertEqual(endpoint.method, .delete)
    }

    func testDelete_defaultsRequiresAuthToTrue() {
        let endpoint = Endpoint.delete("/test")

        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testDelete_withBody() {
        struct DeleteBody: Codable {
            let reason: String
        }

        let body = DeleteBody(reason: "No longer needed")
        let endpoint = Endpoint.delete("/content/123", body: body)

        XCTAssertNotNil(endpoint.body)
    }

    func testDelete_bodyIsNilByDefault() {
        let endpoint = Endpoint.delete("/test")

        XCTAssertNil(endpoint.body)
    }

    // MARK: - HTTPMethod Raw Values

    func testHTTPMethod_getRawValue() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
    }

    func testHTTPMethod_postRawValue() {
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
    }

    func testHTTPMethod_putRawValue() {
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
    }

    func testHTTPMethod_deleteRawValue() {
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
    }

    // MARK: - Direct Initializer

    func testEndpoint_directInit() {
        let endpoint = Endpoint(
            path: "/custom",
            method: .put,
            body: nil,
            queryItems: [URLQueryItem(name: "key", value: "value")],
            requiresAuth: false
        )

        XCTAssertEqual(endpoint.path, "/custom")
        XCTAssertEqual(endpoint.method, .put)
        XCTAssertNil(endpoint.body)
        XCTAssertEqual(endpoint.queryItems?.count, 1)
        XCTAssertFalse(endpoint.requiresAuth)
    }

    // MARK: - Edge Cases

    func testEndpoint_emptyPath() {
        let endpoint = Endpoint.get("")

        XCTAssertEqual(endpoint.path, "")
    }

    func testEndpoint_pathWithSpecialCharacters() {
        let endpoint = Endpoint.get("/users/search?q=test&page=1")

        XCTAssertEqual(endpoint.path, "/users/search?q=test&page=1")
    }

    func testEndpoint_emptyQueryItems() {
        let endpoint = Endpoint.get("/test", queryItems: [])

        XCTAssertNotNil(endpoint.queryItems)
        XCTAssertTrue(endpoint.queryItems?.isEmpty ?? false)
    }

    func testEndpoint_multipleQueryItemsSameName() {
        let queryItems = [
            URLQueryItem(name: "tag", value: "swift"),
            URLQueryItem(name: "tag", value: "ios"),
            URLQueryItem(name: "tag", value: "mobile")
        ]
        let endpoint = Endpoint.get("/content", queryItems: queryItems)

        XCTAssertEqual(endpoint.queryItems?.count, 3)
        XCTAssertEqual(endpoint.queryItems?.filter { $0.name == "tag" }.count, 3)
    }
}
