import XCTest
@testable import ScaleUp

final class DrillServiceTests: XCTestCase {
    // Pure unit tests on the Codable shapes — no network required.

    // MARK: - DrillSubmission encoding

    func testDrillSubmissionEncodesPromptShape() throws {
        let body = DrillSubmitBody(
            drillSubtype: .prompt,
            submission: .prompt(text: "Write a function that...")
        )
        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["drill_subtype"] as? String, "prompt")
        let submission = json?["submission"] as? [String: Any]
        XCTAssertEqual(submission?["prompt_text"] as? String, "Write a function that...")
    }

    func testDrillSubmissionEncodesVerifyShape() throws {
        let body = DrillSubmitBody(
            drillSubtype: .verify,
            submission: .verify(bugLocations: [
                BugLocation(file: "main.js", line: 42, explanation: "off-by-one")
            ])
        )
        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let submission = json?["submission"] as? [String: Any]
        let locations = submission?["bug_locations"] as? [[String: Any]]
        XCTAssertEqual(locations?.first?["file"] as? String, "main.js")
        XCTAssertEqual(locations?.first?["line"] as? Int, 42)
        XCTAssertEqual(locations?.first?["explanation"] as? String, "off-by-one")
        // 'id' from Identifiable should NOT be in JSON (CodingKeys omits it)
        XCTAssertNil(locations?.first?["id"])
    }

    func testDrillSubmissionEncodesDecomposeShape() throws {
        let body = DrillSubmitBody(
            drillSubtype: .decompose,
            submission: .decompose(steps: [
                DecompositionStep(step: "Step 1", rationale: "Because")
            ])
        )
        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let submission = json?["submission"] as? [String: Any]
        let steps = submission?["decomposition_steps"] as? [[String: Any]]
        XCTAssertEqual(steps?.first?["step"] as? String, "Step 1")
        XCTAssertEqual(steps?.first?["rationale"] as? String, "Because")
        // 'id' should NOT be in JSON (CodingKeys omits it)
        XCTAssertNil(steps?.first?["id"])
    }

    // MARK: - Response decoding

    func testDrillTodayResponseDecodes() throws {
        let json = """
        {
          "bundle_id": "abc123",
          "brief": "Write a prompt...",
          "time_budget_minutes": 5,
          "drill_subtype": "prompt",
          "difficulty": "easy",
          "role_track": "swe",
          "language": "python",
          "acceptance_criteria": ["Criterion 1"]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DrillTodayResponse.self, from: json)
        XCTAssertEqual(decoded.bundleId, "abc123")
        XCTAssertEqual(decoded.drillSubtype, .prompt)
        XCTAssertEqual(decoded.difficulty, .easy)
        XCTAssertEqual(decoded.roleTrack, .swe)
        XCTAssertEqual(decoded.timeBudgetMinutes, 5)
        XCTAssertEqual(decoded.acceptanceCriteria?.first, "Criterion 1")
        XCTAssertNil(decoded.starterRepo)
    }

    func testDrillResultGradedResponseDecodes() throws {
        let json = """
        {
          "attempt_id": "att1",
          "status": "graded",
          "overall_score": 78,
          "rubric_breakdown": [
            {"dimension": "specificity", "score": 8.0, "feedback": "good"}
          ],
          "what_to_try_next": "Be more specific",
          "integrity_confidence": "high",
          "graded_at": "2026-05-26T17:00:00.000Z",
          "drill_subtype": "prompt",
          "difficulty": "easy",
          "role_track": "swe"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DrillResultGradedResponse.self, from: json)
        XCTAssertEqual(decoded.attemptId, "att1")
        XCTAssertEqual(decoded.overallScore, 78)
        XCTAssertEqual(decoded.rubricBreakdown.count, 1)
        XCTAssertEqual(decoded.rubricBreakdown.first?.dimension, "specificity")
        XCTAssertEqual(decoded.rubricBreakdown.first?.score, 8.0)
        XCTAssertEqual(decoded.whatToTryNext, "Be more specific")
    }
}
