import SwiftUI

// MARK: - Follow List View

struct FollowListView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    let userId: String
    var initialMode: FollowListViewModel.Mode = .followers

    @State private var viewModel: FollowListViewModel?
    @State private var selectedMode: FollowListViewModel.Mode = .followers

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Segmented Picker
                segmentedPicker

                // Content
                if let viewModel {
                    if viewModel.isLoading {
                        followListSkeletonView
                    } else if let error = viewModel.error, viewModel.users.isEmpty {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadUsers(userId: userId, mode: selectedMode) }
                            }
                        )
                        .frame(maxHeight: .infinity)
                    } else if viewModel.users.isEmpty {
                        emptyState
                            .frame(maxHeight: .infinity)
                    } else {
                        userList(viewModel: viewModel)
                    }
                }
            }
        }
        .navigationTitle(selectedMode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            selectedMode = initialMode
            if viewModel == nil {
                viewModel = FollowListViewModel(
                    socialService: dependencies.socialService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.users.isEmpty {
                await viewModel.loadUsers(userId: userId, mode: selectedMode)
            }
        }
        .onChange(of: selectedMode) { _, newMode in
            Task {
                await viewModel?.loadUsers(userId: userId, mode: newMode)
            }
        }
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(FollowListViewModel.Mode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - User List

    @ViewBuilder
    private func userList(viewModel: FollowListViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.users) { user in
                    NavigationLink {
                        PublicProfileView(userId: user.id)
                    } label: {
                        userRow(user: user, viewModel: viewModel)
                    }

                    if user.id != viewModel.users.last?.id {
                        Divider()
                            .background(ColorTokens.textTertiaryDark.opacity(0.2))
                            .padding(.leading, Spacing.md + 40 + Spacing.sm)
                    }
                }

                // Pagination trigger
                if viewModel.hasMore {
                    ProgressView()
                        .tint(ColorTokens.primary)
                        .padding(Spacing.md)
                        .onAppear {
                            Task {
                                await viewModel.loadMore(userId: userId, mode: selectedMode)
                            }
                        }
                }
            }
        }
    }

    // MARK: - User Row

    @ViewBuilder
    private func userRow(user: PublicUser, viewModel: FollowListViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            CreatorAvatar(
                imageURL: user.profilePicture,
                name: "\(user.firstName) \(user.lastName)",
                size: 40
            )

            // Name & Username
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    userRoleBadge(role: user.role)
                }

                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Follow/Unfollow Button (only for other users)
            if user.id != appState.currentUser?.id {
                followButton(userId: user.id, viewModel: viewModel)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Follow Button

    @ViewBuilder
    private func followButton(userId: String, viewModel: FollowListViewModel) -> some View {
        let isFollowing = viewModel.followingUserIds.contains(userId)
        let isToggling = viewModel.togglingUserIds.contains(userId)

        Button {
            Task { await viewModel.toggleFollow(userId: userId) }
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(Typography.bodySmall)
                .foregroundStyle(isFollowing ? ColorTokens.textSecondaryDark : .white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs + 2)
                .background(isFollowing ? ColorTokens.surfaceElevatedDark : ColorTokens.primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isFollowing ? ColorTokens.textTertiaryDark.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .disabled(isToggling)
        .opacity(isToggling ? 0.6 : 1.0)
    }

    // MARK: - Role Badge

    @ViewBuilder
    private func userRoleBadge(role: UserRole) -> some View {
        if role == .creator {
            Text("Creator")
                .font(Typography.micro)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ColorTokens.primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: selectedMode == .followers ? "person.2" : "person.badge.plus",
            title: selectedMode == .followers ? "No Followers Yet" : "Not Following Anyone",
            subtitle: selectedMode == .followers
                ? "When people follow this account, they'll appear here."
                : "Accounts that are followed will appear here."
        )
    }

    // MARK: - Skeleton Loading

    private var followListSkeletonView: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: Spacing.sm) {
                    SkeletonLoader(width: 40, height: 40, cornerRadius: CornerRadius.full)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SkeletonLoader(width: 140, height: 16)
                        SkeletonLoader(width: 90, height: 12)
                    }

                    Spacer()

                    SkeletonLoader(width: 80, height: 30, cornerRadius: CornerRadius.full)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            Spacer()
        }
    }
}
