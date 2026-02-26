import SwiftUI

// MARK: - Public Profile View

struct PublicProfileView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    let userId: String

    @State private var publicUser: PublicUser?
    @State private var isLoading = false
    @State private var error: APIError?

    // MARK: - Follow State

    @State private var isFollowing = false
    @State private var isTogglingFollow = false
    @State private var localFollowersCount: Int = 0

    // MARK: - Creator Content

    @State private var creatorContent: [Content] = []
    @State private var isLoadingContent = false

    private let contentColumns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if isLoading && publicUser == nil {
                publicProfileSkeletonView
            } else if let error, publicUser == nil {
                ErrorStateView(
                    message: error.localizedDescription,
                    retryAction: {
                        Task { await loadUser() }
                    }
                )
            } else if let user = publicUser {
                publicProfileContent(user: user)
            }
        }
        .navigationTitle(publicUser.map { "\($0.firstName) \($0.lastName)" } ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: Content.self) { content in
            ContentDetailView(contentId: content.id)
        }
        .task {
            if publicUser == nil {
                await loadUser()
                await loadCreatorContent()
            }
        }
    }

    // MARK: - Load User

    @MainActor
    private func loadUser() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let user = try await dependencies.userService.getUser(id: userId)
            self.publicUser = user
            self.localFollowersCount = user.followersCount
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Load Creator Content

    @MainActor
    private func loadCreatorContent() async {
        isLoadingContent = true
        do {
            creatorContent = try await dependencies.contentService.explore(creatorId: userId, limit: 50)
        } catch {
            // Non-critical — profile still shows
        }
        isLoadingContent = false
    }

    // MARK: - Toggle Follow

    @MainActor
    private func toggleFollow() async {
        guard !isTogglingFollow else { return }
        isTogglingFollow = true

        let wasFollowing = isFollowing
        // Optimistic update
        isFollowing.toggle()
        localFollowersCount += isFollowing ? 1 : -1
        dependencies.hapticManager.selection()

        do {
            if wasFollowing {
                try await dependencies.socialService.unfollow(userId: userId)
            } else {
                try await dependencies.socialService.follow(userId: userId)
            }
        } catch {
            // Revert on failure
            isFollowing = wasFollowing
            localFollowersCount += wasFollowing ? 1 : -1
            dependencies.hapticManager.error()
        }

        isTogglingFollow = false
    }

    // MARK: - Content

    @ViewBuilder
    private func publicProfileContent(user: PublicUser) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Avatar
                CreatorAvatar(
                    imageURL: user.profilePicture,
                    name: "\(user.firstName) \(user.lastName)",
                    size: 100
                )

                // Name & Username
                VStack(spacing: Spacing.xs) {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    if let username = user.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                }

                // Role Badge
                publicRoleBadge(role: user.role)

                // Bio
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }

                // Stats Row
                publicStatsRow(user: user)

                // Follow/Unfollow Button
                if userId != appState.currentUser?.id {
                    followActionButton
                        .padding(.horizontal, Spacing.md)
                }

                // Creator Content Section
                creatorContentSection
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Creator Content Section

    @ViewBuilder
    private var creatorContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack {
                Text("Content")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                if !creatorContent.isEmpty {
                    Text("(\(creatorContent.count))")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)

            Divider()
                .background(ColorTokens.surfaceElevatedDark)
                .padding(.horizontal, Spacing.md)

            if isLoadingContent {
                // Loading skeleton grid
                LazyVGrid(columns: contentColumns, spacing: Spacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonLoader(height: 90, cornerRadius: CornerRadius.small + 4)
                            SkeletonLoader(height: 12)
                            SkeletonLoader(width: 80, height: 10)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            } else if creatorContent.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    Text("No content yet")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            } else {
                LazyVGrid(columns: contentColumns, spacing: Spacing.md) {
                    ForEach(creatorContent) { item in
                        NavigationLink(value: item) {
                            creatorContentCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            Spacer()
                .frame(height: Spacing.xxl)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Creator Content Card

    private func creatorContentCard(_ item: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            // Thumbnail
            ZStack {
                if let thumbnailURL = item.resolvedThumbnailURL, let url = URL(string: thumbnailURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(ColorTokens.surfaceElevatedDark)
                            .overlay {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(ColorTokens.textTertiaryDark)
                            }
                    }
                } else {
                    Rectangle()
                        .fill(ColorTokens.surfaceElevatedDark)
                        .overlay {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small + 4))

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(item.difficulty.rawValue.capitalized)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(difficultyColor(item.difficulty))

                    if item.viewCount > 0 {
                        Circle()
                            .fill(ColorTokens.textTertiaryDark)
                            .frame(width: 2.5, height: 2.5)

                        Text("\(item.viewCount) views")
                            .font(.system(size: 9))
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }

                    if item.averageRating > 0 {
                        Circle()
                            .fill(ColorTokens.textTertiaryDark)
                            .frame(width: 2.5, height: 2.5)

                        HStack(spacing: 1) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(ColorTokens.warning)
                            Text(String(format: "%.1f", item.averageRating))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                        }
                    }
                }
            }
        }
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: return ColorTokens.success
        case .intermediate: return ColorTokens.warning
        case .advanced: return ColorTokens.error
        }
    }

    // MARK: - Role Badge

    @ViewBuilder
    private func publicRoleBadge(role: UserRole) -> some View {
        let badgeColor: Color = switch role {
        case .creator: ColorTokens.primary
        case .admin: ColorTokens.warning
        case .consumer: ColorTokens.info
        }

        let badgeText = switch role {
        case .creator: "Creator"
        case .admin: "Admin"
        case .consumer: "Learner"
        }

        Text(badgeText)
            .font(Typography.micro)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(badgeColor)
            .clipShape(Capsule())
    }

    // MARK: - Stats Row

    @ViewBuilder
    private func publicStatsRow(user: PublicUser) -> some View {
        HStack(spacing: Spacing.xl) {
            NavigationLink {
                FollowListView(userId: user.id, initialMode: .followers)
            } label: {
                VStack(spacing: 2) {
                    Text("\(localFollowersCount)")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                    Text("Followers")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }

            Rectangle()
                .fill(ColorTokens.textTertiaryDark.opacity(0.3))
                .frame(width: 1, height: 32)

            NavigationLink {
                FollowListView(userId: user.id, initialMode: .following)
            } label: {
                VStack(spacing: 2) {
                    Text("\(user.followingCount)")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                    Text("Following")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Follow Action Button

    @ViewBuilder
    private var followActionButton: some View {
        Button {
            Task { await toggleFollow() }
        } label: {
            HStack(spacing: Spacing.sm) {
                if isTogglingFollow {
                    ProgressView()
                        .tint(isFollowing ? ColorTokens.primary : .white)
                }

                Text(isFollowing ? "Following" : "Follow")
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(isFollowing ? ColorTokens.primary : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isFollowing ? Color.clear : ColorTokens.primary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isFollowing ? ColorTokens.primary : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .disabled(isTogglingFollow)
    }

    // MARK: - Skeleton Loading

    private var publicProfileSkeletonView: some View {
        VStack(spacing: Spacing.lg) {
            // Avatar skeleton
            SkeletonLoader(width: 100, height: 100, cornerRadius: CornerRadius.full)

            // Name skeleton
            VStack(spacing: Spacing.sm) {
                SkeletonLoader(width: 180, height: 22)
                SkeletonLoader(width: 120, height: 14)
            }

            // Badge skeleton
            SkeletonLoader(width: 60, height: 24, cornerRadius: CornerRadius.full)

            // Bio skeleton
            VStack(spacing: Spacing.xs) {
                SkeletonLoader(width: 260, height: 14)
                SkeletonLoader(width: 200, height: 14)
            }

            // Stats skeleton
            HStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.xs) {
                    SkeletonLoader(width: 40, height: 20)
                    SkeletonLoader(width: 60, height: 12)
                }
                VStack(spacing: Spacing.xs) {
                    SkeletonLoader(width: 40, height: 20)
                    SkeletonLoader(width: 60, height: 12)
                }
            }

            // Button skeleton
            SkeletonLoader(height: 44, cornerRadius: CornerRadius.medium)
                .padding(.horizontal, Spacing.md)

            Spacer()
        }
        .padding(.vertical, Spacing.md)
    }
}
