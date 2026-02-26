import SwiftUI

// MARK: - Creator Dashboard View

struct CreatorDashboardView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var viewModel: CreatorDashboardViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.profile == nil {
                        dashboardSkeletonView
                    } else if let error = viewModel.error, viewModel.profile == nil {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadProfile() }
                            }
                        )
                    } else if let profile = viewModel.profile {
                        dashboardContent(profile: profile, viewModel: viewModel)
                    } else {
                        noCreatorProfileView
                    }
                }
            }
            .navigationTitle("Creator Studio")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: Binding(
                get: { viewModel?.showEditProfile ?? false },
                set: { viewModel?.showEditProfile = $0 }
            )) {
                if let profile = viewModel?.profile {
                    EditCreatorProfileView(
                        profile: profile,
                        creatorService: dependencies.creatorService,
                        hapticManager: dependencies.hapticManager
                    ) { updatedProfile in
                        viewModel?.applyUpdatedProfile(updatedProfile)
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CreatorDashboardViewModel(
                    creatorService: dependencies.creatorService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.profile == nil {
                await viewModel.loadProfile()
            }
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(profile: CreatorProfile, viewModel: CreatorDashboardViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Profile Header
                profileHeaderSection(profile: profile, viewModel: viewModel)

                // Stats Grid
                statsGridSection(stats: profile.stats)

                // Quick Actions
                quickActionsSection

                // Specializations
                if !profile.specializations.isEmpty {
                    specializationsSection(specializations: profile.specializations)
                }

                // Social Links
                if let socialLinks = profile.socialLinks {
                    socialLinksSection(socialLinks: socialLinks)
                }

                // Edit Profile Button
                editProfileButton(viewModel: viewModel)

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Profile Header

    @ViewBuilder
    private func profileHeaderSection(profile: CreatorProfile, viewModel: CreatorDashboardViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            // Avatar with tier ring
            CreatorAvatar(
                imageURL: nil,
                name: appState.currentUser?.firstName ?? "Creator",
                tier: profile.tier.rawValue,
                size: 80
            )

            // Name
            Text(appState.currentUser?.firstName ?? "Creator")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            // Tier Badge
            HStack(spacing: Spacing.xs) {
                Image(systemName: viewModel.tierIcon)
                    .font(.system(size: 12))
                Text(viewModel.tierDisplayName)
                    .font(Typography.caption)
            }
            .foregroundStyle(viewModel.tierColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(viewModel.tierColor.opacity(0.15))
            .clipShape(Capsule())

            // Domain
            Text(profile.domain)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            // Bio
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, Spacing.xl)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Stats Grid

    @ViewBuilder
    private func statsGridSection(stats: CreatorStats) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Performance")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.sm),
                    GridItem(.flexible(), spacing: Spacing.sm)
                ],
                spacing: Spacing.sm
            ) {
                statCard(
                    icon: "doc.text.fill",
                    value: "\(stats.totalContent)",
                    label: "Total Content",
                    color: ColorTokens.primary
                )

                statCard(
                    icon: "eye.fill",
                    value: viewModel?.formattedViews ?? "0",
                    label: "Total Views",
                    color: ColorTokens.info
                )

                statCard(
                    icon: "person.2.fill",
                    value: viewModel?.formattedFollowers ?? "0",
                    label: "Followers",
                    color: ColorTokens.success
                )

                ratingCard(rating: stats.averageRating)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Stat Card

    @ViewBuilder
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Rating Card

    @ViewBuilder
    private func ratingCard(rating: Double) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "star.fill")
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.warning)

            HStack(spacing: Spacing.xs) {
                Text(String(format: "%.1f", rating))
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                StarRatingDisplay(rating: rating, size: 10)
            }

            Text("Avg. Rating")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Quick Actions")

            VStack(spacing: Spacing.sm) {
                quickActionRow(
                    icon: "arrow.up.doc.fill",
                    title: "Upload Content",
                    subtitle: "Share your knowledge",
                    color: ColorTokens.primary
                )

                quickActionRow(
                    icon: "map.fill",
                    title: "Create Learning Path",
                    subtitle: "Guide learners step by step",
                    color: ColorTokens.success
                )

                quickActionRow(
                    icon: "chart.bar.fill",
                    title: "View Analytics",
                    subtitle: "Track your performance",
                    color: ColorTokens.info
                )
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Quick Action Row

    @ViewBuilder
    private func quickActionRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        Button {
            // Placeholder action
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Specializations

    @ViewBuilder
    private func specializationsSection(specializations: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Specializations")

            FlowLayout(spacing: Spacing.sm) {
                ForEach(specializations, id: \.self) { spec in
                    TagChip(title: spec, isSelected: true)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Social Links

    @ViewBuilder
    private func socialLinksSection(socialLinks: CreatorSocialLinks) -> some View {
        let links = buildSocialLinkItems(socialLinks)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Social Links")

                HStack(spacing: Spacing.md) {
                    ForEach(links, id: \.name) { link in
                        Button {
                            if let url = URL(string: link.url) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            VStack(spacing: Spacing.xs) {
                                Image(systemName: link.icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(ColorTokens.primary)
                                    .frame(width: 44, height: 44)
                                    .background(ColorTokens.surfaceElevatedDark)
                                    .clipShape(Circle())

                                Text(link.name)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textSecondaryDark)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - Social Link Helpers

    private struct SocialLinkItem: Hashable {
        let name: String
        let url: String
        let icon: String
    }

    private func buildSocialLinkItems(_ socialLinks: CreatorSocialLinks) -> [SocialLinkItem] {
        var items: [SocialLinkItem] = []
        if let linkedin = socialLinks.linkedin, !linkedin.isEmpty {
            items.append(SocialLinkItem(name: "LinkedIn", url: linkedin, icon: "link.circle.fill"))
        }
        if let twitter = socialLinks.twitter, !twitter.isEmpty {
            items.append(SocialLinkItem(name: "Twitter", url: twitter, icon: "at.circle.fill"))
        }
        if let youtube = socialLinks.youtube, !youtube.isEmpty {
            items.append(SocialLinkItem(name: "YouTube", url: youtube, icon: "play.circle.fill"))
        }
        if let website = socialLinks.website, !website.isEmpty {
            items.append(SocialLinkItem(name: "Website", url: website, icon: "globe"))
        }
        return items
    }

    // MARK: - Edit Profile Button

    @ViewBuilder
    private func editProfileButton(viewModel: CreatorDashboardViewModel) -> some View {
        SecondaryButton(title: "Edit Profile") {
            viewModel.showEditProfile = true
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - No Creator Profile (Application CTA)

    private var noCreatorProfileView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            EmptyStateView(
                icon: "person.crop.rectangle.badge.plus",
                title: "Become a Creator",
                subtitle: "Share your expertise with learners around the world. Apply to join the creator program.",
                buttonTitle: "Apply Now"
            ) {
                // Navigation to application view handled by parent
            }

            Spacer()
        }
    }

    // MARK: - Skeleton Loading View

    private var dashboardSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Avatar skeleton
                VStack(spacing: Spacing.md) {
                    SkeletonLoader(width: 86, height: 86, cornerRadius: CornerRadius.full)
                    SkeletonLoader(width: 140, height: 22)
                    SkeletonLoader(width: 80, height: 24, cornerRadius: CornerRadius.full)
                    SkeletonLoader(width: 100, height: 16)
                }
                .padding(.top, Spacing.sm)

                // Stats grid skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 120, height: 20)
                        .padding(.horizontal, Spacing.md)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Spacing.sm),
                            GridItem(.flexible(), spacing: Spacing.sm)
                        ],
                        spacing: Spacing.sm
                    ) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonLoader(height: 100, cornerRadius: CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Quick actions skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 120, height: 20)
                        .padding(.horizontal, Spacing.md)

                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonLoader(height: 64, cornerRadius: CornerRadius.medium)
                            .padding(.horizontal, Spacing.md)
                    }
                }

                // Specializations skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 140, height: 20)
                        .padding(.horizontal, Spacing.md)

                    HStack(spacing: Spacing.sm) {
                        SkeletonLoader(width: 80, height: 32, cornerRadius: CornerRadius.full)
                        SkeletonLoader(width: 100, height: 32, cornerRadius: CornerRadius.full)
                        SkeletonLoader(width: 70, height: 32, cornerRadius: CornerRadius.full)
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }
}
