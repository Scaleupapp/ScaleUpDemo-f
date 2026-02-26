import Foundation

// MARK: - Creator Endpoints

enum CreatorEndpoints {

    // MARK: - Request Bodies

    struct ApplyBody: Encodable {
        let motivation: String?
        let expertise: [String]?
        let portfolio: String?
    }

    struct UpdateCreatorProfileBody: Encodable {
        let bio: String?
        let expertise: [String]?
        let socialLinks: [String: String]?
    }

    struct EndorseBody: Encodable {
        let note: String?
    }

    // MARK: - Endpoints

    static func apply(motivation: String? = nil, expertise: [String]? = nil, portfolio: String? = nil) -> Endpoint {
        .post("/creator/apply", body: ApplyBody(motivation: motivation, expertise: expertise, portfolio: portfolio))
    }

    static func applicationStatus() -> Endpoint {
        .get("/creator/application-status")
    }

    static func searchCreators() -> Endpoint {
        .get("/creator/search")
    }

    static func profile() -> Endpoint {
        .get("/creator/profile")
    }

    static func updateProfile(bio: String? = nil, expertise: [String]? = nil, socialLinks: [String: String]? = nil) -> Endpoint {
        .put("/creator/profile", body: UpdateCreatorProfileBody(bio: bio, expertise: expertise, socialLinks: socialLinks))
    }

    static func pendingApplications() -> Endpoint {
        .get("/creator/applications/pending")
    }

    static func endorse(applicationId: String, note: String? = nil) -> Endpoint {
        .post("/creator/applications/\(applicationId)/endorse", body: EndorseBody(note: note))
    }
}
