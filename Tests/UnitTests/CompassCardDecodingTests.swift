import XCTest
@testable import ScaleUp

final class CompassCardDecodingTests: XCTestCase {
    func testDecodesActivityResultCard() throws {
        let json = """
        [{"type":"activity_result","payload":{"activityType":"interview","title":"placement technical","date":"2026-05-01","overallScore":72,"scoreLabel":"72/100","dimensions":[{"name":"communication","score":7,"feedback":"clear"}],"highlights":{"strengths":["structure"],"improvements":["depth"]}}}]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([CompassCard].self, from: json)
        XCTAssertEqual(cards.count, 1)
        guard case let .activityResult(p) = cards[0].payload else { return XCTFail("wrong payload") }
        XCTAssertEqual(p.overallScore, 72)
        XCTAssertEqual(p.dimensions.first?.name, "communication")
    }

    func testDecodesWeakTopicsCard() throws {
        let json = """
        [{"type":"weak_topics","payload":{"topics":[{"topic":"recursion","score":35,"trend":"declining","assessedBy":["quiz"]}]}}]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([CompassCard].self, from: json)
        guard case let .weakTopics(topics) = cards[0].payload else { return XCTFail() }
        XCTAssertEqual(topics.first?.topic, "recursion")
    }

    func testUnknownCardTypeDecodesToUnknownAndIsIgnorable() throws {
        let json = """
        [{"type":"future_card","payload":{"whatever":true}}]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([CompassCard].self, from: json)
        guard case .unknown = cards[0].payload else { return XCTFail("should be unknown") }
        XCTAssertEqual(cards[0].type, "future_card")
    }

    func testDecodesTutoringResultCard() throws {
        let json = """
        [{"type":"tutoring_result","payload":{"topic":"recursion","checkScore":75,"beforeScore":35,"afterScore":52,"delta":17}}]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([CompassCard].self, from: json)
        guard case let .tutoringResult(p) = cards[0].payload else { return XCTFail("wrong payload") }
        XCTAssertEqual(p.delta, 17)
        XCTAssertEqual(p.topic, "recursion")
    }
}
