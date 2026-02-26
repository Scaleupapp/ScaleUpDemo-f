import XCTest
@testable import ScaleUp

// MARK: - Content Model Tests

/// Tests for `Content`, `ContentCreator`, `SourceAttribution`, `AIData`, `KeyConcept`,
/// and related enum decoding.
final class ContentModelTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Content Decoding

    func testContent_decodesFromFullJSON() throws {
        // Given
        let json = JSONFactory.contentJSON(
            id: "content-id-abc",
            title: "Learn Swift",
            description: "A comprehensive guide",
            contentType: "video",
            contentURL: "https://example.com/video.mp4",
            thumbnailURL: "https://example.com/thumb.jpg",
            duration: 3600,
            sourceType: "youtube",
            domain: "programming",
            topics: ["Swift", "iOS"],
            tags: ["beginner", "swift"],
            difficulty: "beginner",
            status: "published",
            publishedAt: "2025-01-10T00:00:00.000Z",
            viewCount: 5000,
            likeCount: 200,
            commentCount: 30,
            saveCount: 100,
            averageRating: 4.8,
            ratingCount: 50,
            recommendationScore: 0.92,
            createdAt: "2025-01-01T00:00:00.000Z",
            updatedAt: "2025-01-15T00:00:00.000Z"
        )
        let data = JSONFactory.data(from: json)

        // When
        let content = try decoder.decode(Content.self, from: data)

        // Then
        XCTAssertEqual(content.id, "content-id-abc")
        XCTAssertEqual(content.title, "Learn Swift")
        XCTAssertEqual(content.description, "A comprehensive guide")
        XCTAssertEqual(content.contentType, .video)
        XCTAssertEqual(content.contentURL, "https://example.com/video.mp4")
        XCTAssertEqual(content.thumbnailURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(content.duration, 3600)
        XCTAssertEqual(content.sourceType, .youtube)
        XCTAssertEqual(content.domain, "programming")
        XCTAssertEqual(content.topics, ["Swift", "iOS"])
        XCTAssertEqual(content.tags, ["beginner", "swift"])
        XCTAssertEqual(content.difficulty, .beginner)
        XCTAssertEqual(content.status, .published)
        XCTAssertEqual(content.publishedAt, "2025-01-10T00:00:00.000Z")
        XCTAssertEqual(content.viewCount, 5000)
        XCTAssertEqual(content.likeCount, 200)
        XCTAssertEqual(content.commentCount, 30)
        XCTAssertEqual(content.saveCount, 100)
        XCTAssertEqual(content.averageRating, 4.8, accuracy: 0.001)
        XCTAssertEqual(content.ratingCount, 50)
        XCTAssertEqual(content.recommendationScore, 0.92, accuracy: 0.001)
        XCTAssertEqual(content.createdAt, "2025-01-01T00:00:00.000Z")
        XCTAssertEqual(content.updatedAt, "2025-01-15T00:00:00.000Z")
    }

    func testContent_idMapsFromUnderscore() throws {
        let json = JSONFactory.contentJSON(id: "mongo_content_id")
        let data = JSONFactory.data(from: json)
        let content = try decoder.decode(Content.self, from: data)
        XCTAssertEqual(content.id, "mongo_content_id")
    }

    func testContent_recommendationScoreMapsFromUnderscore() throws {
        let json = JSONFactory.contentJSON(recommendationScore: 0.75)
        let data = JSONFactory.data(from: json)
        let content = try decoder.decode(Content.self, from: data)
        XCTAssertEqual(content.recommendationScore, 0.75, accuracy: 0.001)
    }

    func testContent_missingOptionalFields() throws {
        let json = JSONFactory.contentJSON(
            description: nil,
            thumbnailURL: nil,
            duration: nil,
            publishedAt: nil,
            recommendationScore: nil
        )
        let data = JSONFactory.data(from: json)
        let content = try decoder.decode(Content.self, from: data)

        XCTAssertNil(content.description)
        XCTAssertNil(content.thumbnailURL)
        XCTAssertNil(content.duration)
        XCTAssertNil(content.publishedAt)
        XCTAssertNil(content.recommendationScore)
    }

    // MARK: - ContentCreator Decoding

    func testContentCreator_decodesFromJSON() throws {
        let json = JSONFactory.contentCreatorJSON(
            id: "creator-123",
            firstName: "Alice",
            lastName: "Smith",
            username: "alice",
            profilePicture: "https://example.com/alice.jpg"
        )
        let data = JSONFactory.data(from: json)

        let creator = try decoder.decode(ContentCreator.self, from: data)

        XCTAssertEqual(creator.id, "creator-123")
        XCTAssertEqual(creator.firstName, "Alice")
        XCTAssertEqual(creator.lastName, "Smith")
        XCTAssertEqual(creator.username, "alice")
        XCTAssertEqual(creator.profilePicture, "https://example.com/alice.jpg")
    }

    func testContentCreator_idMapsFromUnderscore() throws {
        let json = JSONFactory.contentCreatorJSON(id: "underscore_creator_id")
        let data = JSONFactory.data(from: json)
        let creator = try decoder.decode(ContentCreator.self, from: data)
        XCTAssertEqual(creator.id, "underscore_creator_id")
    }

    func testContentCreator_optionalFieldsMissing() throws {
        let json = JSONFactory.contentCreatorJSON(username: nil, profilePicture: nil)
        let data = JSONFactory.data(from: json)
        let creator = try decoder.decode(ContentCreator.self, from: data)

        XCTAssertNil(creator.username)
        XCTAssertNil(creator.profilePicture)
    }

    // MARK: - SourceAttribution Decoding

    func testSourceAttribution_decodesFromFullJSON() throws {
        let json: [String: Any] = [
            "platform": "YouTube",
            "originalCreatorName": "TechLead",
            "originalCreatorUrl": "https://youtube.com/@techlead",
            "originalContentUrl": "https://youtube.com/watch?v=abc",
            "importDisclaimer": "Content imported from YouTube"
        ]
        let data = JSONFactory.data(from: json)

        let attribution = try decoder.decode(SourceAttribution.self, from: data)

        XCTAssertEqual(attribution.platform, "YouTube")
        XCTAssertEqual(attribution.originalCreatorName, "TechLead")
        XCTAssertEqual(attribution.originalCreatorUrl, "https://youtube.com/@techlead")
        XCTAssertEqual(attribution.originalContentUrl, "https://youtube.com/watch?v=abc")
        XCTAssertEqual(attribution.importDisclaimer, "Content imported from YouTube")
    }

    func testSourceAttribution_allFieldsOptional() throws {
        let json: [String: Any] = [:]
        let data = JSONFactory.data(from: json)

        let attribution = try decoder.decode(SourceAttribution.self, from: data)

        XCTAssertNil(attribution.platform)
        XCTAssertNil(attribution.originalCreatorName)
        XCTAssertNil(attribution.originalCreatorUrl)
        XCTAssertNil(attribution.originalContentUrl)
        XCTAssertNil(attribution.importDisclaimer)
    }

    // MARK: - AIData Decoding

    func testAIData_decodesFromFullJSON() throws {
        let json: [String: Any] = [
            "summary": "This video covers Swift basics.",
            "keyConcepts": [
                [
                    "concept": "Variables",
                    "description": "How to declare variables",
                    "timestamp": 120.5,
                    "importance": "high"
                ]
            ],
            "prerequisites": ["Programming basics"],
            "qualityScore": 0.9,
            "autoTags": ["swift", "variables"]
        ]
        let data = JSONFactory.data(from: json)

        let aiData = try decoder.decode(AIData.self, from: data)

        XCTAssertEqual(aiData.summary, "This video covers Swift basics.")
        XCTAssertEqual(aiData.keyConcepts?.count, 1)
        XCTAssertEqual(aiData.keyConcepts?.first?.concept, "Variables")
        XCTAssertEqual(aiData.prerequisites, ["Programming basics"])
        XCTAssertEqual(aiData.qualityScore, 0.9, accuracy: 0.001)
        XCTAssertEqual(aiData.autoTags, ["swift", "variables"])
    }

    func testAIData_allFieldsOptional() throws {
        let json: [String: Any] = [:]
        let data = JSONFactory.data(from: json)

        let aiData = try decoder.decode(AIData.self, from: data)

        XCTAssertNil(aiData.summary)
        XCTAssertNil(aiData.keyConcepts)
        XCTAssertNil(aiData.prerequisites)
        XCTAssertNil(aiData.qualityScore)
        XCTAssertNil(aiData.autoTags)
    }

    // MARK: - KeyConcept Decoding

    func testKeyConcept_decodesFromFullJSON() throws {
        let json: [String: Any] = [
            "concept": "Closures",
            "description": "Anonymous functions in Swift",
            "timestamp": 300.0,
            "importance": "high"
        ]
        let data = JSONFactory.data(from: json)

        let concept = try decoder.decode(KeyConcept.self, from: data)

        XCTAssertEqual(concept.concept, "Closures")
        XCTAssertEqual(concept.description, "Anonymous functions in Swift")
        XCTAssertEqual(concept.timestamp, 300.0, accuracy: 0.001)
        XCTAssertEqual(concept.importance, "high")
    }

    func testKeyConcept_missingOptionalFields() throws {
        let json: [String: Any] = [
            "concept": "Protocols"
        ]
        let data = JSONFactory.data(from: json)

        let concept = try decoder.decode(KeyConcept.self, from: data)

        XCTAssertEqual(concept.concept, "Protocols")
        XCTAssertNil(concept.description)
        XCTAssertNil(concept.timestamp)
        XCTAssertNil(concept.importance)
    }

    // MARK: - Content with Nested Models

    func testContent_withSourceAttribution() throws {
        var json = JSONFactory.contentJSON()
        json["sourceAttribution"] = [
            "platform": "YouTube",
            "originalCreatorName": "SwiftDev"
        ] as [String: Any]
        let data = JSONFactory.data(from: json)

        let content = try decoder.decode(Content.self, from: data)

        XCTAssertNotNil(content.sourceAttribution)
        XCTAssertEqual(content.sourceAttribution?.platform, "YouTube")
        XCTAssertEqual(content.sourceAttribution?.originalCreatorName, "SwiftDev")
    }

    func testContent_withAIData() throws {
        var json = JSONFactory.contentJSON()
        json["aiData"] = [
            "summary": "AI generated summary",
            "qualityScore": 0.85
        ] as [String: Any]
        let data = JSONFactory.data(from: json)

        let content = try decoder.decode(Content.self, from: data)

        XCTAssertNotNil(content.aiData)
        XCTAssertEqual(content.aiData?.summary, "AI generated summary")
        XCTAssertEqual(content.aiData?.qualityScore, 0.85, accuracy: 0.001)
    }

    func testContent_withoutOptionalNestedModels() throws {
        let json = JSONFactory.contentJSON()
        let data = JSONFactory.data(from: json)

        let content = try decoder.decode(Content.self, from: data)

        // sourceAttribution and aiData are not in the default factory JSON
        XCTAssertNil(content.sourceAttribution)
        XCTAssertNil(content.aiData)
    }

    // MARK: - Enum Decoding: ContentType

    func testContentType_video() throws {
        let data = "\"video\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(ContentType.self, from: data), .video)
    }

    func testContentType_article() throws {
        let data = "\"article\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(ContentType.self, from: data), .article)
    }

    func testContentType_infographic() throws {
        let data = "\"infographic\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(ContentType.self, from: data), .infographic)
    }

    func testContentType_invalidValue_throws() {
        let data = "\"podcast\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(ContentType.self, from: data))
    }

    // MARK: - Enum Decoding: ContentStatus

    func testContentStatus_allCases() throws {
        let cases: [(String, ContentStatus)] = [
            ("draft", .draft),
            ("processing", .processing),
            ("ready", .ready),
            ("published", .published),
            ("unpublished", .unpublished),
            ("rejected", .rejected)
        ]

        for (raw, expected) in cases {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(ContentStatus.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for raw value: \(raw)")
        }
    }

    // MARK: - Enum Decoding: Difficulty

    func testDifficulty_allCases() throws {
        let cases: [(String, Difficulty)] = [
            ("beginner", .beginner),
            ("intermediate", .intermediate),
            ("advanced", .advanced)
        ]

        for (raw, expected) in cases {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(Difficulty.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for raw value: \(raw)")
        }
    }

    func testDifficulty_invalidValue_throws() {
        let data = "\"expert\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(Difficulty.self, from: data))
    }

    // MARK: - Enum Decoding: SourceType

    func testSourceType_original() throws {
        let data = "\"original\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(SourceType.self, from: data), .original)
    }

    func testSourceType_youtube() throws {
        let data = "\"youtube\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(SourceType.self, from: data), .youtube)
    }

    func testSourceType_invalidValue_throws() {
        let data = "\"vimeo\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(SourceType.self, from: data))
    }

    // MARK: - Identifiable / Hashable

    func testContent_conformsToIdentifiable() throws {
        let json = JSONFactory.contentJSON(id: "id-123")
        let data = JSONFactory.data(from: json)
        let content = try decoder.decode(Content.self, from: data)
        XCTAssertEqual(content.id, "id-123")
    }

    func testContentCreator_conformsToIdentifiable() throws {
        let json = JSONFactory.contentCreatorJSON(id: "creator-456")
        let data = JSONFactory.data(from: json)
        let creator = try decoder.decode(ContentCreator.self, from: data)
        XCTAssertEqual(creator.id, "creator-456")
    }
}
