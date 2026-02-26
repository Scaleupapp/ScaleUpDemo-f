import Foundation

// MARK: - User Endpoints

enum UserEndpoints {

    // MARK: - Request Bodies

    struct UpdateMeBody: Encodable {
        let name: String?
        let bio: String?
        let phone: String?
        let avatarUrl: String?
    }

    // MARK: - Endpoints

    static func me() -> Endpoint {
        .get("/users/me")
    }

    static func updateMe(name: String? = nil, bio: String? = nil, phone: String? = nil, avatarUrl: String? = nil) -> Endpoint {
        .put("/users/me", body: UpdateMeBody(name: name, bio: bio, phone: phone, avatarUrl: avatarUrl))
    }

    static func deleteMe() -> Endpoint {
        .delete("/users/me")
    }

    static func getUser(id: String) -> Endpoint {
        .get("/users/\(id)")
    }
}
