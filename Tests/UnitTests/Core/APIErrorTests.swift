import XCTest
@testable import ScaleUp

// MARK: - API Error Tests

/// Tests for `APIError` covering the `from(statusCode:detail:)` factory,
/// `errorDescription` conformance, and edge cases.
final class APIErrorTests: XCTestCase {

    // MARK: - from(statusCode:detail:) Mapping

    func testFrom_400_returnsBadRequest() {
        let error = APIError.from(statusCode: 400, detail: nil)
        if case .badRequest(let msg) = error {
            XCTAssertNil(msg, "Without detail, message should be nil")
        } else {
            XCTFail("Expected badRequest, got \(error)")
        }
    }

    func testFrom_400_withDetail_returnsBadRequestWithMessage() {
        let detail = APIErrorDetail(code: "VALIDATION_ERROR", details: "Invalid email format")
        let error = APIError.from(statusCode: 400, detail: detail)
        if case .badRequest(let msg) = error {
            XCTAssertEqual(msg, "Invalid email format")
        } else {
            XCTFail("Expected badRequest, got \(error)")
        }
    }

    func testFrom_400_withCodeOnly_fallsBackToCode() {
        let detail = APIErrorDetail(code: "VALIDATION_ERROR", details: nil)
        let error = APIError.from(statusCode: 400, detail: detail)
        if case .badRequest(let msg) = error {
            XCTAssertEqual(msg, "VALIDATION_ERROR")
        } else {
            XCTFail("Expected badRequest, got \(error)")
        }
    }

    func testFrom_401_returnsUnauthorized() {
        let error = APIError.from(statusCode: 401, detail: nil)
        if case .unauthorized = error {
            // Success
        } else {
            XCTFail("Expected unauthorized, got \(error)")
        }
    }

    func testFrom_403_returnsForbidden() {
        let error = APIError.from(statusCode: 403, detail: nil)
        if case .forbidden = error {
            // Success
        } else {
            XCTFail("Expected forbidden, got \(error)")
        }
    }

    func testFrom_404_returnsNotFound() {
        let error = APIError.from(statusCode: 404, detail: nil)
        if case .notFound = error {
            // Success
        } else {
            XCTFail("Expected notFound, got \(error)")
        }
    }

    func testFrom_409_returnsConflict() {
        let error = APIError.from(statusCode: 409, detail: nil)
        if case .conflict(let msg) = error {
            XCTAssertNil(msg)
        } else {
            XCTFail("Expected conflict, got \(error)")
        }
    }

    func testFrom_409_withDetail_returnsConflictWithMessage() {
        let detail = APIErrorDetail(code: "CONFLICT", details: "Username taken")
        let error = APIError.from(statusCode: 409, detail: detail)
        if case .conflict(let msg) = error {
            XCTAssertEqual(msg, "Username taken")
        } else {
            XCTFail("Expected conflict, got \(error)")
        }
    }

    func testFrom_429_returnsRateLimited() {
        let error = APIError.from(statusCode: 429, detail: nil)
        if case .rateLimited = error {
            // Success
        } else {
            XCTFail("Expected rateLimited, got \(error)")
        }
    }

    func testFrom_500_returnsServerError() {
        let error = APIError.from(statusCode: 500, detail: nil)
        if case .serverError = error {
            // Success
        } else {
            XCTFail("Expected serverError, got \(error)")
        }
    }

    func testFrom_502_returnsServerError() {
        let error = APIError.from(statusCode: 502, detail: nil)
        if case .serverError = error {
            // Success
        } else {
            XCTFail("Expected serverError for 502, got \(error)")
        }
    }

    func testFrom_503_returnsServerError() {
        let error = APIError.from(statusCode: 503, detail: nil)
        if case .serverError = error {
            // Success
        } else {
            XCTFail("Expected serverError for 503, got \(error)")
        }
    }

    func testFrom_599_returnsServerError() {
        let error = APIError.from(statusCode: 599, detail: nil)
        if case .serverError = error {
            // Success
        } else {
            XCTFail("Expected serverError for 599, got \(error)")
        }
    }

    func testFrom_418_returnsUnknown() {
        let error = APIError.from(statusCode: 418, detail: nil)
        if case .unknown(let code, let msg) = error {
            XCTAssertEqual(code, 418)
            XCTAssertNil(msg)
        } else {
            XCTFail("Expected unknown, got \(error)")
        }
    }

    func testFrom_418_withDetail_returnsUnknownWithMessage() {
        let detail = APIErrorDetail(code: nil, details: "I'm a teapot")
        let error = APIError.from(statusCode: 418, detail: detail)
        if case .unknown(let code, let msg) = error {
            XCTAssertEqual(code, 418)
            XCTAssertEqual(msg, "I'm a teapot")
        } else {
            XCTFail("Expected unknown, got \(error)")
        }
    }

    func testFrom_300_returnsUnknown() {
        let error = APIError.from(statusCode: 300, detail: nil)
        if case .unknown(let code, _) = error {
            XCTAssertEqual(code, 300)
        } else {
            XCTFail("Expected unknown for 300, got \(error)")
        }
    }

    // MARK: - errorDescription

    func testErrorDescription_unauthorized() {
        let error = APIError.unauthorized
        XCTAssertEqual(error.errorDescription, "Your session has expired. Please sign in again.")
    }

    func testErrorDescription_badRequest_withMessage() {
        let error = APIError.badRequest("Invalid email")
        XCTAssertEqual(error.errorDescription, "Invalid email")
    }

    func testErrorDescription_badRequest_withoutMessage() {
        let error = APIError.badRequest(nil)
        XCTAssertEqual(error.errorDescription, "The request was invalid. Please try again.")
    }

    func testErrorDescription_forbidden() {
        let error = APIError.forbidden
        XCTAssertEqual(error.errorDescription, "You don't have permission to perform this action.")
    }

    func testErrorDescription_notFound() {
        let error = APIError.notFound
        XCTAssertEqual(error.errorDescription, "The requested resource was not found.")
    }

    func testErrorDescription_conflict_withMessage() {
        let error = APIError.conflict("Already exists")
        XCTAssertEqual(error.errorDescription, "Already exists")
    }

    func testErrorDescription_conflict_withoutMessage() {
        let error = APIError.conflict(nil)
        XCTAssertEqual(error.errorDescription, "A conflict occurred. The resource may already exist.")
    }

    func testErrorDescription_rateLimited() {
        let error = APIError.rateLimited
        XCTAssertEqual(error.errorDescription, "Too many requests. Please wait a moment and try again.")
    }

    func testErrorDescription_serverError() {
        let error = APIError.serverError
        XCTAssertEqual(error.errorDescription, "An internal server error occurred. Please try again later.")
    }

    func testErrorDescription_networkError() {
        let underlyingError = NSError(domain: NSURLErrorDomain,
                                       code: NSURLErrorTimedOut,
                                       userInfo: [NSLocalizedDescriptionKey: "The request timed out."])
        let error = APIError.networkError(underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("timed out") ?? false)
    }

    func testErrorDescription_decodingError() {
        let underlyingError = NSError(domain: "Decoding",
                                       code: 0,
                                       userInfo: [NSLocalizedDescriptionKey: "Key not found"])
        let error = APIError.decodingError(underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Failed to process") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Key not found") ?? false)
    }

    func testErrorDescription_unknown_withMessage() {
        let error = APIError.unknown(418, "I'm a teapot")
        XCTAssertEqual(error.errorDescription, "I'm a teapot")
    }

    func testErrorDescription_unknown_withoutMessage() {
        let error = APIError.unknown(418, nil)
        XCTAssertEqual(error.errorDescription, "An unexpected error occurred (HTTP 418).")
    }

    // MARK: - Error Conformance

    func testAPIError_conformsToError() {
        let error: Error = APIError.notFound
        XCTAssertNotNil(error)
    }

    func testAPIError_conformsToLocalizedError() {
        let error: LocalizedError = APIError.serverError
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - APIErrorDetail Decoding

    func testAPIErrorDetail_decodesFromJSON() throws {
        let json = """
        {"code": "VALIDATION_ERROR", "details": "Email is required"}
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(APIErrorDetail.self, from: json)
        XCTAssertEqual(detail.code, "VALIDATION_ERROR")
        XCTAssertEqual(detail.details, "Email is required")
    }

    func testAPIErrorDetail_decodesWithNilFields() throws {
        let json = """
        {}
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(APIErrorDetail.self, from: json)
        XCTAssertNil(detail.code)
        XCTAssertNil(detail.details)
    }
}

// MARK: - Decodable APIErrorDetail extension for testing

/// Allow manual creation of `APIErrorDetail` for tests.
extension APIErrorDetail {
    init(code: String?, details: String?) {
        let json: [String: Any?] = ["code": code, "details": details]
        let data = try! JSONSerialization.data(
            withJSONObject: json.compactMapValues { $0 }
        )
        self = try! JSONDecoder().decode(APIErrorDetail.self, from: data)
    }
}
