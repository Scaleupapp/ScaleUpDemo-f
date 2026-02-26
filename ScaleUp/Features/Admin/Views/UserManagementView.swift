import SwiftUI

// MARK: - User Management View

struct UserManagementView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var viewModel: UserManagementViewModel?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    userListSkeletonView
                } else if let error = viewModel.error, viewModel.users.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadUsers() }
                        }
                    )
                } else if viewModel.users.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "person.slash",
                        title: "No Users Found",
                        subtitle: "No users match your current filters.",
                        buttonTitle: "Clear Filters",
                        action: {
                            viewModel.searchText = ""
                            viewModel.selectedRoleFilter = nil
                            Task { await viewModel.loadUsers() }
                        }
                    )
                } else {
                    userListContent(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = UserManagementViewModel(
                    adminService: dependencies.adminService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.users.isEmpty {
                await viewModel.loadUsers()
            }
        }
    }

    // MARK: - User List Content

    @ViewBuilder
    private func userListContent(viewModel: UserManagementViewModel) -> some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar(viewModel: viewModel)

            // Role Filter
            roleFilterBar(viewModel: viewModel)

            // User List
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.users) { user in
                        NavigationLink {
                            AdminUserDetailView(user: user)
                        } label: {
                            UserRow(
                                user: user,
                                isActionInProgress: viewModel.actionInProgressUserId == user.id
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if user.isBanned {
                                Button {
                                    viewModel.userToUnban = user
                                    viewModel.showUnbanConfirmation = true
                                } label: {
                                    Label("Unban", systemImage: "checkmark.circle")
                                }
                                .tint(ColorTokens.success)
                            } else {
                                Button {
                                    viewModel.userToBan = user
                                    viewModel.showBanConfirmation = true
                                } label: {
                                    Label("Ban", systemImage: "nosign")
                                }
                                .tint(ColorTokens.error)
                            }
                        }
                        .onAppear {
                            // Pagination trigger: load more when reaching the last item
                            if user.id == viewModel.users.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }

                    // Loading more indicator
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(ColorTokens.primary)
                                .padding(Spacing.md)
                            Spacer()
                        }
                    }

                    // Bottom spacing
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }
            .refreshable {
                await viewModel.loadUsers()
            }
        }
        // Ban Confirmation Alert
        .alert("Ban User", isPresented: Binding(
            get: { viewModel.showBanConfirmation },
            set: { viewModel.showBanConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {
                viewModel.userToBan = nil
            }
            Button("Ban", role: .destructive) {
                if let user = viewModel.userToBan {
                    Task { await viewModel.banUser(id: user.id) }
                }
            }
        } message: {
            if let user = viewModel.userToBan {
                Text("Are you sure you want to ban \(user.firstName) \(user.lastName)? They will lose access to the platform.")
            }
        }
        // Unban Confirmation Alert
        .alert("Unban User", isPresented: Binding(
            get: { viewModel.showUnbanConfirmation },
            set: { viewModel.showUnbanConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {
                viewModel.userToUnban = nil
            }
            Button("Unban") {
                if let user = viewModel.userToUnban {
                    Task { await viewModel.unbanUser(id: user.id) }
                }
            }
        } message: {
            if let user = viewModel.userToUnban {
                Text("Are you sure you want to unban \(user.firstName) \(user.lastName)? They will regain access to the platform.")
            }
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private func searchBar(viewModel: UserManagementViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            TextField("Search users...", text: Binding(
                get: { viewModel.searchText },
                set: { newValue in
                    viewModel.searchText = newValue
                    viewModel.searchUsers()
                }
            ))
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    Task { await viewModel.loadUsers() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Role Filter Bar

    @ViewBuilder
    private func roleFilterBar(viewModel: UserManagementViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                RoleFilterChip(
                    title: "All",
                    isSelected: viewModel.selectedRoleFilter == nil
                ) {
                    Task { await viewModel.filterByRole(nil) }
                }

                ForEach(UserRole.allCases, id: \.self) { role in
                    RoleFilterChip(
                        title: role.rawValue.capitalized,
                        isSelected: viewModel.selectedRoleFilter == role
                    ) {
                        Task { await viewModel.filterByRole(role) }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Skeleton Loading View

    private var userListSkeletonView: some View {
        VStack(spacing: 0) {
            // Search bar skeleton
            SkeletonLoader(height: 44, cornerRadius: CornerRadius.small)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

            // Filter skeleton
            HStack(spacing: Spacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonLoader(width: 80, height: 32, cornerRadius: CornerRadius.full)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            // User rows skeleton
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.sm) {
                    ForEach(0..<8, id: \.self) { _ in
                        SkeletonLoader(height: 76, cornerRadius: CornerRadius.medium)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }
        }
    }
}

// MARK: - User Row

private struct UserRow: View {
    let user: User
    let isActionInProgress: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            CreatorAvatar(
                imageURL: user.profilePicture,
                name: "\(user.firstName) \(user.lastName)",
                size: 44
            )

            // User Info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    // Ban status indicator
                    if user.isBanned {
                        Circle()
                            .fill(ColorTokens.error)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(user.email)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    RoleBadge(role: user.role)

                    Text(formattedDate(user.createdAt))
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }

            Spacer()

            if isActionInProgress {
                ProgressView()
                    .tint(ColorTokens.primary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Helpers

    private func formattedDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: dateString) else {
            // Fallback: try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            guard let fallbackDate = isoFormatter.date(from: dateString) else {
                return dateString
            }
            return formatForDisplay(fallbackDate)
        }
        return formatForDisplay(date)
    }

    private func formatForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Role Badge

private struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.rawValue.capitalized)
            .font(Typography.micro)
            .foregroundStyle(roleColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(roleColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var roleColor: Color {
        switch role {
        case .admin:
            return ColorTokens.error
        case .creator:
            return ColorTokens.warning
        case .consumer:
            return ColorTokens.info
        }
    }
}

// MARK: - Role Filter Chip

private struct RoleFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? .white : ColorTokens.textSecondaryDark)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? ColorTokens.primary : ColorTokens.surfaceElevatedDark)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? ColorTokens.primary : ColorTokens.textTertiaryDark.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
