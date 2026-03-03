import SwiftUI

@Observable
@MainActor
final class AdminDashboardViewModel {
    var stats: AdminStats?
    var isLoading = false

    private let adminService = AdminService()

    func loadStats() async {
        isLoading = true
        stats = try? await adminService.fetchStats()
        isLoading = false
    }
}

struct AdminDashboardView: View {
    @State private var viewModel = AdminDashboardViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    statsStrip
                    navigationSection
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("Admin Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadStats()
        }
        .refreshable {
            await viewModel.loadStats()
        }
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                adminStat(value: viewModel.stats?.totalUsers ?? 0, label: "Users", icon: "person.3.fill", color: ColorTokens.info)
                statDivider
                adminStat(value: viewModel.stats?.totalCreators ?? 0, label: "Creators", icon: "star.fill", color: ColorTokens.gold)
                statDivider
                adminStat(value: viewModel.stats?.totalContent ?? 0, label: "Content", icon: "doc.text.fill", color: ColorTokens.success)
                statDivider
                adminStat(value: viewModel.stats?.publishedContent ?? 0, label: "Published", icon: "checkmark.circle.fill", color: ColorTokens.success)
                statDivider
                adminStat(value: viewModel.stats?.reportedContent ?? 0, label: "Reported", icon: "exclamationmark.triangle.fill", color: ColorTokens.error)
                statDivider
                adminStat(value: viewModel.stats?.bannedUsers ?? 0, label: "Banned", icon: "person.slash.fill", color: ColorTokens.error)
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
        }
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    private func adminStat(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(width: 80)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(ColorTokens.border.opacity(0.3))
            .frame(width: 1, height: 40)
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(spacing: Spacing.sm) {
            NavigationLink {
                UserManagementView()
            } label: {
                adminNavRow(
                    icon: "person.2.fill", title: "User Management",
                    subtitle: "Search, ban/unban users", color: ColorTokens.info,
                    badge: nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CreatorPromotionView()
            } label: {
                adminNavRow(
                    icon: "arrow.up.circle.fill", title: "Creator Promotions",
                    subtitle: "Manage creator tiers", color: ColorTokens.gold,
                    badge: nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ContentModerationView()
            } label: {
                adminNavRow(
                    icon: "shield.fill", title: "Content Moderation",
                    subtitle: "Review reported content", color: ColorTokens.warning,
                    badge: viewModel.stats?.reportedContent
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PendingApplicationsView()
            } label: {
                adminNavRow(
                    icon: "doc.text.magnifyingglass", title: "Creator Applications",
                    subtitle: "Review pending applications", color: ColorTokens.success,
                    badge: viewModel.stats?.pendingApplications
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
    }

    private func adminNavRow(icon: String, title: String, subtitle: String, color: Color, badge: Int?) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ColorTokens.error)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}
