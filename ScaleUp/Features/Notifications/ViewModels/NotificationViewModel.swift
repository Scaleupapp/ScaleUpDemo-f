import SwiftUI

@Observable
@MainActor
final class NotificationViewModel {

    var notifications: [AppNotification] = []
    var unreadCount: Int = 0
    var isLoading = false
    var currentPage = 1
    var hasMore = true

    private let service = NotificationService()

    // MARK: - Load

    func loadNotifications() async {
        isLoading = true
        currentPage = 1

        do {
            notifications = try await service.fetchNotifications(page: 1)
            hasMore = notifications.count >= 30
        } catch {
            // Keep existing list on error
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }

        let nextPage = currentPage + 1
        do {
            let more = try await service.fetchNotifications(page: nextPage)
            notifications.append(contentsOf: more)
            currentPage = nextPage
            hasMore = more.count >= 30
        } catch {
            // Silently fail
        }
    }

    // MARK: - Unread Count

    func refreshUnreadCount() async {
        do {
            let response = try await service.fetchUnreadCount()
            unreadCount = response.unreadCount
        } catch {
            // Keep existing count
        }
    }

    // MARK: - Mark Read

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        // Optimistic update
        if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
            let updated = AppNotification(
                id: notification.id,
                userId: notification.userId,
                type: notification.type,
                title: notification.title,
                message: notification.message,
                isRead: true,
                deepLink: notification.deepLink,
                createdAt: notification.createdAt,
                updatedAt: notification.updatedAt
            )
            notifications[idx] = updated
            unreadCount = max(0, unreadCount - 1)
        }

        try? await service.markAsRead(id: notification.id)
    }

    func markAllAsRead() async {
        // Optimistic update
        notifications = notifications.map { n in
            AppNotification(
                id: n.id, userId: n.userId, type: n.type,
                title: n.title, message: n.message, isRead: true,
                deepLink: n.deepLink, createdAt: n.createdAt, updatedAt: n.updatedAt
            )
        }
        unreadCount = 0

        try? await service.markAllAsRead()
    }

    // MARK: - Dismiss

    func dismiss(_ notification: AppNotification) async {
        notifications.removeAll { $0.id == notification.id }
        if !notification.isRead {
            unreadCount = max(0, unreadCount - 1)
        }

        try? await service.dismiss(id: notification.id)
    }
}
