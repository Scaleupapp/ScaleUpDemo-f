import SwiftUI

struct CreatorProfileView: View {
    let creatorId: String

    @State private var viewModel = CreatorViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.creator == nil {
                ProgressView().tint(ColorTokens.gold)
            } else if let error = viewModel.errorMessage, viewModel.creator == nil {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(error)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            } else if let creator = viewModel.creator {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Profile header
                        profileHeader(creator)

                        // Stats
                        statsRow(creator)

                        // Mutual followers
                        mutualFollowersSection(creator)

                        // Bio
                        if let bio = creator.bio, !bio.isEmpty {
                            Text(bio)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .padding(.horizontal, Spacing.lg)
                        }

                        // Domain & Specializations
                        domainSection(creator)

                        // Background (Education, Work, Skills)
                        backgroundSection(creator)

                        // Content grid
                        if !viewModel.content.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Content (\(viewModel.content.count))")
                                    .font(Typography.titleMedium)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .padding(.horizontal, Spacing.lg)

                                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                                    ForEach(viewModel.content) { item in
                                        NavigationLink(value: item) {
                                            ContentCard(content: item, width: .infinity)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, Spacing.lg)
                            }
                        }

                        Spacer().frame(height: Spacing.xxl)
                    }
                    .padding(.top, Spacing.md)
                }
            }
        }
        .navigationTitle("Creator")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Content.self) { content in
            ContentDestinationView(content: content)
        }
        .task {
            await viewModel.loadCreator(id: creatorId)
        }
    }

    // MARK: - Profile Header

    private func profileHeader(_ creator: Creator) -> some View {
        VStack(spacing: Spacing.md) {
            CreatorAvatar(creator: creator, size: 80)

            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(creator.displayName)
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if creator.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: 0x60A5FA))
                    }

                    if let tier = creator.tier {
                        TierBadge(tier: tier)
                    }
                }

                if let username = creator.username {
                    Text("@\(username)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                if let createdAt = creator.createdAt {
                    Text("Joined \(createdAt.formatted(.dateTime.month(.wide).year()))")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            // Follow button
            Button {
                Task { await viewModel.toggleFollow() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isFollowing {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text(viewModel.isFollowing ? "Following" : "Follow")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(viewModel.isFollowing ? ColorTokens.gold : ColorTokens.buttonPrimaryText)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, 10)
                .background(
                    viewModel.isFollowing
                        ? ColorTokens.surface
                        : ColorTokens.gold
                )
                .overlay(
                    viewModel.isFollowing
                        ? Capsule().stroke(ColorTokens.gold, lineWidth: 1.5)
                        : nil
                )
                .clipShape(Capsule())
            }
            .disabled(viewModel.isFollowLoading)
            .opacity(viewModel.isFollowLoading ? 0.6 : 1)

        }
    }

    // MARK: - Stats Row

    private func statsRow(_ creator: Creator) -> some View {
        HStack(spacing: 0) {
            statColumn(value: formatCount(viewModel.localFollowersCount), label: "Followers")
            if let views = creator.totalViews, views > 0 {
                statColumn(value: formatCount(views), label: "Views")
            }
            statColumn(value: "\(creator.contentCount ?? 0)", label: "Content")
            if let rating = creator.averageRating, rating > 0 {
                statColumn(value: String(format: "%.1f", rating), label: "Rating")
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Mutual Followers

    @ViewBuilder
    private func mutualFollowersSection(_ creator: Creator) -> some View {
        if let mutual = creator.mutualFollowers, mutual.count > 0 {
            HStack(spacing: Spacing.sm) {
                // Overlapping avatars
                HStack(spacing: -8) {
                    ForEach(Array(mutual.users.prefix(3).enumerated()), id: \.element.id) { index, user in
                        mutualAvatar(user)
                            .zIndex(Double(3 - index))
                    }
                }

                Text(mutualFollowersText(mutual))
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(2)

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func mutualAvatar(_ user: FollowUser) -> some View {
        Group {
            if let pic = user.profilePicture, let url = URL(string: pic) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(ColorTokens.surface)
                }
            } else {
                Circle().fill(ColorTokens.surface)
                    .overlay(
                        Text(String(user.firstName.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.textSecondary)
                    )
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
        .overlay(Circle().stroke(ColorTokens.background, lineWidth: 2))
    }

    private func mutualFollowersText(_ mutual: MutualFollowersInfo) -> String {
        let names = mutual.users.prefix(2).map { $0.firstName }
        let remaining = mutual.count - names.count

        if mutual.count == 1 {
            return "Followed by \(names[0])"
        } else if remaining == 0 {
            return "Followed by \(names.joined(separator: " and "))"
        } else {
            return "Followed by \(names[0]) and \(remaining) other\(remaining == 1 ? "" : "s") you follow"
        }
    }

    // MARK: - Domain & Specializations

    @ViewBuilder
    private func domainSection(_ creator: Creator) -> some View {
        let hasDomain = creator.domain != nil && !(creator.domain?.isEmpty ?? true)
        let hasSpecs = creator.specializations != nil && !(creator.specializations?.isEmpty ?? true)

        if hasDomain || hasSpecs {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let domain = creator.domain, !domain.isEmpty {
                    Text(domain.capitalized)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                if let specs = creator.specializations, !specs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(specs, id: \.self) { spec in
                                Text(spec.capitalized)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.gold)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, 4)
                                    .background(ColorTokens.gold.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Background (Education, Work, Skills)

    @ViewBuilder
    private func backgroundSection(_ creator: Creator) -> some View {
        let hasEdu = creator.education != nil && !(creator.education?.isEmpty ?? true)
        let hasWork = creator.workExperience != nil && !(creator.workExperience?.isEmpty ?? true)
        let hasSkills = creator.skills != nil && !(creator.skills?.isEmpty ?? true)

        if hasEdu || hasWork || hasSkills {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let education = creator.education, !education.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Education", systemImage: "graduationcap")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        ForEach(education) { edu in
                            HStack(spacing: 6) {
                                Circle().fill(ColorTokens.info).frame(width: 6, height: 6)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(edu.degree)
                                        .font(Typography.bodySmall)
                                        .foregroundStyle(ColorTokens.textPrimary)
                                    HStack(spacing: 4) {
                                        Text(edu.institution)
                                            .font(Typography.micro)
                                            .foregroundStyle(ColorTokens.textTertiary)
                                        if let year = edu.yearOfCompletion {
                                            Text("· \(String(year))")
                                                .font(Typography.micro)
                                                .foregroundStyle(ColorTokens.textTertiary)
                                        }
                                        if edu.currentlyPursuing == true {
                                            Text("(Current)")
                                                .font(Typography.micro)
                                                .foregroundStyle(ColorTokens.gold)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }

                if let work = creator.workExperience, !work.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Work Experience", systemImage: "briefcase")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        ForEach(work) { exp in
                            HStack(spacing: 6) {
                                Circle().fill(ColorTokens.gold).frame(width: 6, height: 6)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(exp.role)
                                        .font(Typography.bodySmall)
                                        .foregroundStyle(ColorTokens.textPrimary)
                                    HStack(spacing: 4) {
                                        Text(exp.company)
                                            .font(Typography.micro)
                                            .foregroundStyle(ColorTokens.textTertiary)
                                        if let years = exp.years {
                                            Text("· \(years) yr\(years == 1 ? "" : "s")")
                                                .font(Typography.micro)
                                                .foregroundStyle(ColorTokens.textTertiary)
                                        }
                                        if exp.currentlyWorking == true {
                                            Text("(Current)")
                                                .font(Typography.micro)
                                                .foregroundStyle(ColorTokens.gold)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }

                if let skills = creator.skills, !skills.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Skills", systemImage: "lightbulb")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        FlowLayout(spacing: 6) {
                            ForEach(skills, id: \.self) { skill in
                                Text(skill.capitalized)
                                    .font(Typography.micro)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ColorTokens.surfaceElevated)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Helpers

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.gold)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
