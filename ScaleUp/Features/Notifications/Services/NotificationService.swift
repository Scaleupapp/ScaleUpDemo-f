import Foundation

// MARK: - Notification Service

// MARK: - Response Wrappers

private struct NotificationListWrapper: Codable, Sendable {
    let notifications: [AppNotification]
    let unreadCount: Int?
}

actor NotificationService {
    private let api = APIClient.shared

    func fetchNotifications(page: Int = 1) async throws -> [AppNotification] {
        let wrapper: NotificationListWrapper = try await api.request(NotificationEndpoints.list(page: page))
        return wrapper.notifications
    }

    func fetchUnreadCount() async throws -> UnreadCountResponse {
        try await api.request(NotificationEndpoints.unreadCount)
    }

    func markAsRead(id: String) async throws {
        _ = try await api.requestRaw(NotificationEndpoints.markRead(id: id))
    }

    func markAllAsRead() async throws {
        _ = try await api.requestRaw(NotificationEndpoints.markAllRead)
    }

    func dismiss(id: String) async throws {
        _ = try await api.requestRaw(NotificationEndpoints.dismiss(id: id))
    }

    func registerDeviceToken(_ token: String) async throws {
        let body = DeviceTokenBody(fcmToken: token)
        _ = try await api.requestRaw(NotificationEndpoints.updateFcmToken, body: body)
    }
}

// MARK: - Request Bodies

private struct DeviceTokenBody: Encodable, Sendable {
    let fcmToken: String
}

// MARK: - Endpoints

private enum NotificationEndpoints: Endpoint {
    case list(page: Int)
    case unreadCount
    case markRead(id: String)
    case markAllRead
    case dismiss(id: String)
    case updateFcmToken

    var path: String {
        switch self {
        case .list: return "/notifications"
        case .unreadCount: return "/notifications/unread-count"
        case .markRead(let id): return "/notifications/\(id)/read"
        case .markAllRead: return "/notifications/read-all"
        case .dismiss(let id): return "/notifications/\(id)"
        case .updateFcmToken: return "/users/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .unreadCount:
            return .get
        case .markRead, .updateFcmToken:
            return .put
        case .markAllRead:
            return .post
        case .dismiss:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let page):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "30")
            ]
        default:
            return nil
        }
    }
}
