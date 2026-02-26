import XCTest
@testable import ScaleUp

// MARK: - User Model Tests

/// Tests for `User`, `PublicUser`, `AuthResponse`, `Education`,
/// and `WorkExperience` model decoding.
final class UserModelTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - User Decoding

    func testUser_decodesFromFullJSON() throws {
        // Given
        let json = JSONFactory.userJSON(
            id: "abc123",
            email: "john@example.com",
            phone: "+1234567890",
            isPhoneVerified: true,
            isEmailVerified: true,
            firstName: "John",
            lastName: "Doe",
            username: "johndoe",
            profilePicture: "https://example.com/pic.jpg",
            bio: "Hello world",
            dateOfBirth: "1990-05-15",
            location: "New York",
            education: [
                ["degree": "BS", "institution": "MIT", "yearOfCompletion": 2012, "currentlyPursuing": false]
            ],
            workExperience: [
                ["role": "Engineer", "company": "Apple", "years": 5, "currentlyWorking": true]
            ],
            skills: ["Swift", "Python"],
            role: "creator",
            authProvider: "google",
            onboardingComplete: true,
            onboardingStep: 5,
            followersCount: 100,
            followingCount: 50,
            isActive: true,
            isBanned: false,
            lastLoginAt: "2025-01-20T08:00:00.000Z",
            createdAt: "2024-06-01T00:00:00.000Z"
        )
        let data = JSONFactory.data(from: json)

        // When
        let user = try decoder.decode(User.self, from: data)

        // Then
        XCTAssertEqual(user.id, "abc123")
        XCTAssertEqual(user.email, "john@example.com")
        XCTAssertEqual(user.phone, "+1234567890")
        XCTAssertTrue(user.isPhoneVerified)
        XCTAssertTrue(user.isEmailVerified)
        XCTAssertEqual(user.firstName, "John")
        XCTAssertEqual(user.lastName, "Doe")
        XCTAssertEqual(user.username, "johndoe")
        XCTAssertEqual(user.profilePicture, "https://example.com/pic.jpg")
        XCTAssertEqual(user.bio, "Hello world")
        XCTAssertEqual(user.dateOfBirth, "1990-05-15")
        XCTAssertEqual(user.location, "New York")
        XCTAssertEqual(user.skills, ["Swift", "Python"])
        XCTAssertEqual(user.role, .creator)
        XCTAssertEqual(user.authProvider, "google")
        XCTAssertTrue(user.onboardingComplete)
        XCTAssertEqual(user.onboardingStep, 5)
        XCTAssertEqual(user.followersCount, 100)
        XCTAssertEqual(user.followingCount, 50)
        XCTAssertTrue(user.isActive)
        XCTAssertFalse(user.isBanned)
        XCTAssertEqual(user.lastLoginAt, "2025-01-20T08:00:00.000Z")
        XCTAssertEqual(user.createdAt, "2024-06-01T00:00:00.000Z")
    }

    func testUser_idMapsFromUnderscore() throws {
        // Given - the backend sends "_id" not "id"
        let json: [String: Any] = JSONFactory.userJSON(id: "mongo_object_id_123")
        let data = JSONFactory.data(from: json)

        // When
        let user = try decoder.decode(User.self, from: data)

        // Then
        XCTAssertEqual(user.id, "mongo_object_id_123")
    }

    func testUser_missingOptionalFields() throws {
        // Given - minimal user JSON with optionals absent
        let json = JSONFactory.userJSON(
            phone: nil,
            username: nil,
            profilePicture: nil,
            bio: nil,
            dateOfBirth: nil,
            location: nil,
            lastLoginAt: nil
        )
        let data = JSONFactory.data(from: json)

        // When
        let user = try decoder.decode(User.self, from: data)

        // Then
        XCTAssertNil(user.phone)
        XCTAssertNil(user.username)
        XCTAssertNil(user.profilePicture)
        XCTAssertNil(user.bio)
        XCTAssertNil(user.dateOfBirth)
        XCTAssertNil(user.location)
        XCTAssertNil(user.lastLoginAt)
    }

    func testUser_conformsToIdentifiable() throws {
        let json = JSONFactory.userJSON(id: "identifiable-id")
        let data = JSONFactory.data(from: json)
        let user = try decoder.decode(User.self, from: data)

        // Identifiable requires `id` property
        XCTAssertEqual(user.id, "identifiable-id")
    }

    func testUser_conformsToHashable() throws {
        let json1 = JSONFactory.userJSON(id: "same-id", email: "a@a.com")
        let json2 = JSONFactory.userJSON(id: "same-id", email: "a@a.com")
        let user1 = try decoder.decode(User.self, from: JSONFactory.data(from: json1))
        let user2 = try decoder.decode(User.self, from: JSONFactory.data(from: json2))

        XCTAssertEqual(user1.hashValue, user2.hashValue)
    }

    // MARK: - Education Decoding

    func testEducation_decodesFromJSON() throws {
        let json: [String: Any] = [
            "degree": "Master of Science",
            "institution": "Stanford University",
            "yearOfCompletion": 2020,
            "currentlyPursuing": false
        ]
        let data = JSONFactory.data(from: json)

        let education = try decoder.decode(Education.self, from: data)

        XCTAssertEqual(education.degree, "Master of Science")
        XCTAssertEqual(education.institution, "Stanford University")
        XCTAssertEqual(education.yearOfCompletion, 2020)
        XCTAssertFalse(education.currentlyPursuing)
    }

    func testEducation_optionalYearOfCompletion() throws {
        let json: [String: Any] = [
            "degree": "PhD",
            "institution": "MIT",
            "currentlyPursuing": true
        ]
        let data = JSONFactory.data(from: json)

        let education = try decoder.decode(Education.self, from: data)

        XCTAssertNil(education.yearOfCompletion)
        XCTAssertTrue(education.currentlyPursuing)
    }

    // MARK: - WorkExperience Decoding

    func testWorkExperience_decodesFromJSON() throws {
        let json: [String: Any] = [
            "role": "Senior Developer",
            "company": "Google",
            "years": 3,
            "currentlyWorking": true
        ]
        let data = JSONFactory.data(from: json)

        let experience = try decoder.decode(WorkExperience.self, from: data)

        XCTAssertEqual(experience.role, "Senior Developer")
        XCTAssertEqual(experience.company, "Google")
        XCTAssertEqual(experience.years, 3)
        XCTAssertTrue(experience.currentlyWorking)
    }

    func testWorkExperience_optionalYears() throws {
        let json: [String: Any] = [
            "role": "Intern",
            "company": "Startup",
            "currentlyWorking": false
        ]
        let data = JSONFactory.data(from: json)

        let experience = try decoder.decode(WorkExperience.self, from: data)

        XCTAssertNil(experience.years)
    }

    // MARK: - User with Education and WorkExperience

    func testUser_withEducationAndWorkExperience() throws {
        let json = JSONFactory.userJSON(
            education: [
                ["degree": "BS", "institution": "MIT", "yearOfCompletion": 2015, "currentlyPursuing": false],
                ["degree": "MS", "institution": "Stanford", "currentlyPursuing": true]
            ],
            workExperience: [
                ["role": "Developer", "company": "Apple", "years": 3, "currentlyWorking": false],
                ["role": "Lead", "company": "Google", "years": 2, "currentlyWorking": true]
            ]
        )
        let data = JSONFactory.data(from: json)

        let user = try decoder.decode(User.self, from: data)

        XCTAssertEqual(user.education.count, 2)
        XCTAssertEqual(user.education[0].degree, "BS")
        XCTAssertEqual(user.education[1].institution, "Stanford")
        XCTAssertNil(user.education[1].yearOfCompletion)

        XCTAssertEqual(user.workExperience.count, 2)
        XCTAssertEqual(user.workExperience[0].company, "Apple")
        XCTAssertTrue(user.workExperience[1].currentlyWorking)
    }

    // MARK: - PublicUser Decoding

    func testPublicUser_decodesFromJSON() throws {
        let json = JSONFactory.publicUserJSON(
            id: "pub-user-id",
            firstName: "Jane",
            lastName: "Smith",
            username: "janesmith",
            profilePicture: "https://example.com/jane.jpg",
            bio: "Creator",
            role: "creator",
            followersCount: 500,
            followingCount: 200
        )
        let data = JSONFactory.data(from: json)

        let user = try decoder.decode(PublicUser.self, from: data)

        XCTAssertEqual(user.id, "pub-user-id")
        XCTAssertEqual(user.firstName, "Jane")
        XCTAssertEqual(user.lastName, "Smith")
        XCTAssertEqual(user.username, "janesmith")
        XCTAssertEqual(user.profilePicture, "https://example.com/jane.jpg")
        XCTAssertEqual(user.bio, "Creator")
        XCTAssertEqual(user.role, .creator)
        XCTAssertEqual(user.followersCount, 500)
        XCTAssertEqual(user.followingCount, 200)
    }

    func testPublicUser_idMapsFromUnderscore() throws {
        let json = JSONFactory.publicUserJSON(id: "underscore_mapped_id")
        let data = JSONFactory.data(from: json)

        let user = try decoder.decode(PublicUser.self, from: data)

        XCTAssertEqual(user.id, "underscore_mapped_id")
    }

    func testPublicUser_missingOptionalFields() throws {
        let json = JSONFactory.publicUserJSON(
            username: nil,
            profilePicture: nil,
            bio: nil
        )
        let data = JSONFactory.data(from: json)

        let user = try decoder.decode(PublicUser.self, from: data)

        XCTAssertNil(user.username)
        XCTAssertNil(user.profilePicture)
        XCTAssertNil(user.bio)
    }

    // MARK: - AuthResponse Decoding

    func testAuthResponse_decodesFromJSON() throws {
        let json = JSONFactory.authResponseJSON(
            accessToken: "access-xyz",
            refreshToken: "refresh-xyz"
        )
        let data = JSONFactory.data(from: json)

        let authResponse = try decoder.decode(AuthResponse.self, from: data)

        XCTAssertEqual(authResponse.accessToken, "access-xyz")
        XCTAssertEqual(authResponse.refreshToken, "refresh-xyz")
        XCTAssertEqual(authResponse.user.email, "test@example.com")
        XCTAssertEqual(authResponse.user.firstName, "John")
    }

    func testAuthResponse_containsFullUser() throws {
        let json = JSONFactory.authResponseJSON(
            userOverrides: [
                "firstName": "Alice",
                "lastName": "Wonder",
                "role": "admin"
            ]
        )
        let data = JSONFactory.data(from: json)

        let authResponse = try decoder.decode(AuthResponse.self, from: data)

        XCTAssertEqual(authResponse.user.firstName, "Alice")
        XCTAssertEqual(authResponse.user.lastName, "Wonder")
        XCTAssertEqual(authResponse.user.role, .admin)
    }

    // MARK: - UserRole Enum

    func testUserRole_consumer() throws {
        let data = "\"consumer\"".data(using: .utf8)!
        let role = try decoder.decode(UserRole.self, from: data)
        XCTAssertEqual(role, .consumer)
    }

    func testUserRole_creator() throws {
        let data = "\"creator\"".data(using: .utf8)!
        let role = try decoder.decode(UserRole.self, from: data)
        XCTAssertEqual(role, .creator)
    }

    func testUserRole_admin() throws {
        let data = "\"admin\"".data(using: .utf8)!
        let role = try decoder.decode(UserRole.self, from: data)
        XCTAssertEqual(role, .admin)
    }

    func testUserRole_invalidValue_throwsDecodingError() {
        let data = "\"superadmin\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(UserRole.self, from: data))
    }

    // MARK: - User Encoding Roundtrip

    func testUser_encodingRoundtrip() throws {
        let json = JSONFactory.userJSON()
        let data = JSONFactory.data(from: json)

        let user = try decoder.decode(User.self, from: data)
        let encodedData = try JSONEncoder().encode(user)
        let reDecoded = try decoder.decode(User.self, from: encodedData)

        XCTAssertEqual(user, reDecoded)
    }
}
