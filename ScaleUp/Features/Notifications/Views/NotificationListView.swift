import SwiftUI

struct NotificationListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NotificationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.notifications.isEmpty {
                loadingState
            } else if viewModel.notifications.isEmpty {
                emptyState
            } else {
                notificationList
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.notifications.isEmpty && viewModel.unreadCount > 0 {
                    Button {
                        Task { await viewModel.markAllAsRead() }
                    } label: {
                        Text("Read All")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ColorTokens.gold)
                    }
                }
            }
        }
        .task {
            await viewModel.loadNotifications()
            await viewModel.refreshUnreadCount()
        }
    }

    // MARK: - Notification List

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.notifications) { notification in
                    notificationRow(notification)
                        .onAppear {
                            if notification.id == viewModel.notifications.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }
            }
            .padding(.top, Spacing.xs)
        }
        .refreshable {
            await viewModel.loadNotifications()
            await viewModel.refreshUnreadCount()
        }
    }

    // MARK: - Notification Row

    private func notificationRow(_ notification: AppNotification) -> some View {
        VStack(spacing: 0) {
            Button {
                Task { await viewModel.markAsRead(notification) }
                handleDeepLink(notification)
            } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    // Type icon
                    notificationIcon(notification.type)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.system(size: 14, weight: notification.isRead ? .medium : .bold))
                            .foregroundStyle(notification.isRead ? ColorTokens.textSecondary : .white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(notification.message)
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        if let date = notification.createdAt {
                            Text(date.timeAgoDisplay())
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.textTertiary.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Unread dot
                    if !notification.isRead {
                        Circle()
                            .fill(ColorTokens.gold)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(notification.isRead ? Color.clear : ColorTokens.gold.opacity(0.04))
            }
            .buttonStyle(.plain)

            Divider()
                .foregroundStyle(ColorTokens.surface)
                .padding(.leading, 60)
        }
    }

    // MARK: - Icon

    private func notificationIcon(_ type: NotificationType) -> some View {
        ZStack {
            Circle()
                .fill(iconBackground(type))
                .frame(width: 40, height: 40)

            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundStyle(iconForeground(type))
        }
    }

    private func iconBackground(_ type: NotificationType) -> Color {
        switch type {
        case .quizAvailable, .milestoneReached:
            return ColorTokens.gold.opacity(0.15)
        case .streakReminder:
            return Color.orange.opacity(0.15)
        case .journeyUpdate:
            return Color.blue.opacity(0.15)
        case .socialFollow:
            return Color.purple.opacity(0.15)
        case .socialComment:
            return Color.green.opacity(0.15)
        }
    }

    private func iconForeground(_ type: NotificationType) -> Color {
        switch type {
        case .quizAvailable, .milestoneReached:
            return ColorTokens.gold
        case .streakReminder:
            return .orange
        case .journeyUpdate:
            return .blue
        case .socialFollow:
            return .purple
        case .socialComment:
            return .green
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ notification: AppNotification) {
        guard let deepLink = notification.deepLink else { return }

        // Parse deep link and navigate
        let components = deepLink.split(separator: "/").map(String.init)

        if deepLink.contains("quizzes") || deepLink.contains("quiz") {
            appState.selectedTab = .home
        } else if deepLink.contains("journey") || deepLink.contains("milestones") {
            appState.selectedTab = .journey
        } else if deepLink.contains("content") {
            appState.selectedTab = .discover
        } else if deepLink.contains("users") {
            appState.selectedTab = .profile
        } else if deepLink.contains("home") {
            appState.selectedTab = .home
        }

        dismiss()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))

            Text("No Notifications")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ColorTokens.textSecondary)

            Text("You're all caught up! New notifications will appear here.")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(ColorTokens.surface)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.surface)
                            .frame(height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.surface)
                            .frame(width: 200, height: 12)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .padding(.top, Spacing.xl)
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}
