import SwiftUI

// MARK: - Admin Dashboard View

struct AdminDashboardView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var viewModel: AdminDashboardViewModel?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let user = appState.currentUser, user.role != .admin {
                    accessDeniedView
                } else if let viewModel {
                    if viewModel.isLoading && viewModel.stats == nil {
                        dashboardSkeletonView
                    } else if let error = viewModel.error, viewModel.stats == nil {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadStats() }
                            }
                        )
                    } else {
                        dashboardContent(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AdminDashboardViewModel(
                    adminService: dependencies.adminService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.stats == nil {
                await viewModel.loadStats()
            }
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(viewModel: AdminDashboardViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Stats Overview Grid
                statsGrid(viewModel: viewModel)

                // Quick Links Section
                quickLinksSection

                // Bottom spacing
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Stats Grid

    @ViewBuilder
    private func statsGrid(viewModel: AdminDashboardViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Platform Overview")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md)
                ],
                spacing: Spacing.md
            ) {
                StatCard(
                    icon: "person.2.fill",
                    title: "Total Users",
                    value: "\(viewModel.totalUsers)",
                    color: ColorTokens.info
                )

                StatCard(
                    icon: "doc.text.fill",
                    title: "Total Content",
                    value: "\(viewModel.totalContent)",
                    color: ColorTokens.success
                )

                StatCard(
                    icon: "star.fill",
                    title: "Creators",
                    value: "\(viewModel.totalCreators)",
                    color: ColorTokens.warning
                )

                StatCard(
                    icon: "flame.fill",
                    title: "Active Journeys",
                    value: "\(viewModel.activeJourneys)",
                    color: ColorTokens.primary
                )
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Quick Links Section

    private var quickLinksSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Management")

            VStack(spacing: Spacing.sm) {
                NavigationLink {
                    UserManagementView()
                } label: {
                    QuickLinkRow(
                        icon: "person.crop.circle",
                        title: "User Management",
                        subtitle: "View, search, and manage users",
                        color: ColorTokens.info
                    )
                }

                NavigationLink {
                    ApplicationReviewView()
                } label: {
                    QuickLinkRow(
                        icon: "envelope.badge",
                        title: "Application Review",
                        subtitle: "Review creator applications",
                        color: ColorTokens.warning
                    )
                }

                NavigationLink {
                    ContentModerationView()
                } label: {
                    QuickLinkRow(
                        icon: "shield.checkered",
                        title: "Content Moderation",
                        subtitle: "Review and moderate content",
                        color: ColorTokens.error
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Access Denied View

    private var accessDeniedView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.error)

            Text("Access Denied")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("You do not have admin privileges to access this panel.")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }

    // MARK: - Skeleton Loading View

    private var dashboardSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Section header skeleton
                HStack {
                    SkeletonLoader(width: 160, height: 20)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)

                // Stats grid skeleton
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.md),
                        GridItem(.flexible(), spacing: Spacing.md)
                    ],
                    spacing: Spacing.md
                ) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonLoader(height: 120, cornerRadius: CornerRadius.medium)
                    }
                }
                .padding(.horizontal, Spacing.md)

                // Section header skeleton
                HStack {
                    SkeletonLoader(width: 140, height: 20)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)

                // Quick links skeleton
                VStack(spacing: Spacing.sm) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonLoader(height: 72, cornerRadius: CornerRadius.medium)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Quick Link Row

private struct QuickLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}
