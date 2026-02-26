import Foundation

// MARK: - Deep Link

/// Represents all navigable destinations in the ScaleUp app.
/// Used by both URL scheme handling (`scaleup://`) and notification payloads
/// to route users to the correct screen.
enum DeepLink: Equatable, Hashable {

    // MARK: - Tab Navigation

    case tab(MainTabView.Tab)

    // MARK: - Content

    case content(id: String)
    case player(contentId: String)

    // MARK: - Quiz

    case quiz(id: String)
    case quizList

    // MARK: - Journey

    case journey
    case todayPlan

    // MARK: - Social

    case profile(userId: String)
    case playlist(id: String)

    // MARK: - Admin

    case admin
    case adminUsers
    case adminApplications

    // MARK: - Parse from URL

    /// Parses a deep link from a URL with the `scaleup://` scheme.
    ///
    /// Supported URL paths:
    /// - `scaleup://tab/{tabName}`
    /// - `scaleup://content/{id}`
    /// - `scaleup://player/{contentId}`
    /// - `scaleup://quiz/{id}`
    /// - `scaleup://quizzes`
    /// - `scaleup://journey`
    /// - `scaleup://today`
    /// - `scaleup://profile/{userId}`
    /// - `scaleup://playlist/{id}`
    /// - `scaleup://admin`
    /// - `scaleup://admin/users`
    /// - `scaleup://admin/applications`
    static func from(url: URL) -> DeepLink? {
        guard url.scheme == "scaleup" else { return nil }

        let host = url.host()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "tab":
            guard let tabName = pathComponents.first,
                  let tab = MainTabView.Tab(rawValue: tabName) else { return nil }
            return .tab(tab)

        case "content":
            guard let id = pathComponents.first else { return nil }
            return .content(id: id)

        case "player":
            guard let contentId = pathComponents.first else { return nil }
            return .player(contentId: contentId)

        case "quiz":
            guard let id = pathComponents.first else { return nil }
            return .quiz(id: id)

        case "quizzes":
            return .quizList

        case "journey":
            return .journey

        case "today":
            return .todayPlan

        case "profile":
            guard let userId = pathComponents.first else { return nil }
            return .profile(userId: userId)

        case "playlist":
            guard let id = pathComponents.first else { return nil }
            return .playlist(id: id)

        case "admin":
            if let subPath = pathComponents.first {
                switch subPath {
                case "users":
                    return .adminUsers
                case "applications":
                    return .adminApplications
                default:
                    return .admin
                }
            }
            return .admin

        default:
            return nil
        }
    }

    // MARK: - Parse from Notification userInfo

    /// Parses a deep link from a notification's `userInfo` dictionary.
    ///
    /// Expected keys:
    /// - `type`: The notification type (e.g., "quiz", "content", "milestone", "journey")
    /// - `id`: An optional resource identifier
    static func from(userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard let type = userInfo["type"] as? String else { return nil }
        let id = userInfo["id"] as? String

        switch type {
        case "quiz":
            if let id { return .quiz(id: id) }
            return .quizList

        case "content":
            guard let id else { return nil }
            return .content(id: id)

        case "player":
            guard let id else { return nil }
            return .player(contentId: id)

        case "journey":
            return .journey

        case "today_plan":
            return .todayPlan

        case "milestone":
            return .journey

        case "streak":
            return .tab(.home)

        case "profile":
            guard let id else { return nil }
            return .profile(userId: id)

        case "playlist":
            guard let id else { return nil }
            return .playlist(id: id)

        case "admin":
            return .admin

        default:
            return nil
        }
    }
}
