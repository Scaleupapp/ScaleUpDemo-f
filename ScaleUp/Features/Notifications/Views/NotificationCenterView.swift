import SwiftUI

// MARK: - In-App Notification Model

/// Represents an in-app notification item displayed in the notification center.
/// This is separate from push notifications — it models an activity feed item.
struct InAppNotification: Identifiable, Equatable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let deepLink: DeepLink?

    enum NotificationType: String, CaseIterable {
        case quizAvailable = "quiz_available"
        case milestoneReached = "milestone_reached"
        case streakReminder = "streak_reminder"
        case journeyUpdate = "journey_update"
        case socialFollow = "social_follow"
        case socialComment = "social_comment"

        var icon: String {
            switch self {
            case .quizAvailable: return "questionmark.circle.fill"
            case .milestoneReached: return "trophy.fill"
            case .streakReminder: return "flame.fill"
            case .journeyUpdate: return "map.fill"
            case .socialFollow: return "person.badge.plus"
            case .socialComment: return "bubble.left.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .quizAvailable: return ColorTokens.info
            case .milestoneReached: return ColorTokens.anchorGold
            case .streakReminder: return ColorTokens.warning
            case .journeyUpdate: return ColorTokens.primary
            case .socialFollow: return ColorTokens.success
            case .socialComment: return ColorTokens.primaryLight
            }
        }
    }
}

// MARK: - Notification Center View Model

@Observable @MainActor
final class NotificationCenterViewModel {

    // MARK: - State

    var notifications: [InAppNotification] = []
    var isLoading: Bool = false

    // MARK: - Computed

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var hasNotifications: Bool {
        !notifications.isEmpty
    }

    // MARK: - Load

    /// Loads notifications. Currently uses mock data since there is
    /// no notifications API endpoint yet.
    func loadNotifications() async {
        isLoading = true

        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(400))

        notifications = Self.mockNotifications
        isLoading = false
    }

    // MARK: - Actions

    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
    }

    func markAsRead(_ notification: InAppNotification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
    }

    func dismiss(_ notification: InAppNotification) {
        notifications.removeAll { $0.id == notification.id }
    }

    // MARK: - Mock Data

    private static var mockNotifications: [InAppNotification] {
        let now = Date()
        let calendar = Calendar.current

        return [
            InAppNotification(
                id: "notif-1",
                type: .quizAvailable,
                title: "New Quiz Available",
                message: "Test your knowledge on \"Swift Concurrency Patterns\" — 10 questions ready.",
                timestamp: calendar.date(byAdding: .minute, value: -15, to: now) ?? now,
                isRead: false,
                deepLink: .quiz(id: "quiz-swift-concurrency")
            ),
            InAppNotification(
                id: "notif-2",
                type: .milestoneReached,
                title: "7-Day Streak!",
                message: "You've been learning for 7 days straight. Keep the momentum going!",
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                isRead: false,
                deepLink: .tab(.home)
            ),
            InAppNotification(
                id: "notif-3",
                type: .journeyUpdate,
                title: "Journey Updated",
                message: "Your learning journey has been adapted based on your recent quiz performance.",
                timestamp: calendar.date(byAdding: .hour, value: -5, to: now) ?? now,
                isRead: false,
                deepLink: .journey
            ),
            InAppNotification(
                id: "notif-4",
                type: .socialFollow,
                title: "New Follower",
                message: "Alex Chen started following you.",
                timestamp: calendar.date(byAdding: .hour, value: -8, to: now) ?? now,
                isRead: true,
                deepLink: .profile(userId: "user-alex")
            ),
            InAppNotification(
                id: "notif-5",
                type: .quizAvailable,
                title: "Quiz Reminder",
                message: "You have a pending quiz on \"Design Patterns in iOS\" from yesterday.",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                isRead: true,
                deepLink: .quiz(id: "quiz-design-patterns")
            ),
            InAppNotification(
                id: "notif-6",
                type: .socialComment,
                title: "Comment on Your Playlist",
                message: "Priya left a comment on your \"SwiftUI Essentials\" playlist.",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                isRead: true,
                deepLink: .playlist(id: "playlist-swiftui")
            ),
            InAppNotification(
                id: "notif-7",
                type: .streakReminder,
                title: "Don't Lose Your Streak",
                message: "You haven't completed any content today. A 5-minute session is all it takes.",
                timestamp: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                isRead: true,
                deepLink: .todayPlan
            ),
            InAppNotification(
                id: "notif-8",
                type: .milestoneReached,
                title: "First Quiz Aced!",
                message: "Congratulations! You scored 100% on your first quiz.",
                timestamp: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                isRead: true,
                deepLink: .quizList
            ),
        ]
    }
}

// MARK: - Notification Center View

/// An in-app notification center (activity feed) that displays recent notifications,
/// milestones, quiz alerts, and social activity.
struct NotificationCenterView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var viewModel = NotificationCenterViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(ColorTokens.primary)
                } else if viewModel.hasNotifications {
                    notificationList
                } else {
                    emptyState
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.unreadCount > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.markAllAsRead()
                            }
                        } label: {
                            Text("Mark All Read")
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.primary)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadNotifications()
        }
    }

    // MARK: - Notification List

    @ViewBuilder
    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.notifications) { notification in
                    NotificationRow(notification: notification)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.markAsRead(notification)
                            // Deep link navigation would be handled by the parent
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    viewModel.dismiss(notification)
                                }
                            } label: {
                                Label("Dismiss", systemImage: "trash")
                            }
                        }

                    if notification.id != viewModel.notifications.last?.id {
                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)
                            .padding(.leading, 68)
                    }
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            VStack(spacing: Spacing.sm) {
                Text("All Caught Up!")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("No new notifications. Keep learning and they'll show up here.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Notification Row

/// A single row in the notification center list.
private struct NotificationRow: View {
    let notification: InAppNotification

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type.iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: notification.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(notification.type.iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(notification.title)
                        .font(notification.isRead ? Typography.body : Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    Spacer()

                    Text(notification.timestamp.timeAgo())
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                Text(notification.message)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .lineLimit(2)
            }

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(ColorTokens.primary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            notification.isRead
                ? Color.clear
                : ColorTokens.primary.opacity(0.04)
        )
    }
}

// MARK: - Preview

#Preview {
    NotificationCenterView()
        .environment(DependencyContainer())
        .preferredColorScheme(.dark)
}
