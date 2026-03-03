import SwiftUI

struct ProfileHeaderView: View {
    let user: User
    var creatorProfile: CreatorProfileData?
    var onEditTapped: () -> Void
    var onFollowersTapped: () -> Void
    var onFollowingTapped: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Avatar + Name + Role Badge
            VStack(spacing: Spacing.sm) {
                avatarView

                Text(user.displayName)
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)

                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                roleBadge
            }

            // Bio
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Followers / Following stats
            HStack(spacing: Spacing.xl) {
                statButton(count: user.followersCount ?? 0, label: "Followers", action: onFollowersTapped)
                statButton(count: user.followingCount ?? 0, label: "Following", action: onFollowingTapped)
            }

            // Skills chips
            if let skills = user.skills, !skills.isEmpty {
                skillsRow(skills)
            }

            // Edit Profile button
            Button(action: {
                Haptics.selection()
                onEditTapped()
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                    Text("Edit Profile")
                        .font(Typography.bodySmall)
                }
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.full))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.full)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 80
        if let url = user.profilePicture, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    initialsCircle(size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(roleColor, lineWidth: 3))
        } else {
            initialsCircle(size: size)
                .overlay(Circle().stroke(roleColor, lineWidth: 3))
        }
    }

    private func initialsCircle(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(ColorTokens.surfaceElevated)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var initials: String {
        let first = user.firstName.prefix(1)
        let last = (user.lastName ?? "").prefix(1)
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Role Badge

    @ViewBuilder
    private var roleBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: roleIcon)
                .font(.system(size: 10))
            Text(roleLabel)
                .font(Typography.micro)
        }
        .foregroundStyle(roleColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(roleColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var roleLabel: String {
        switch user.role {
        case .admin: return "Admin"
        case .creator:
            return (creatorProfile?.tier?.displayName ?? "Creator") + " Creator"
        case .consumer: return "Learner"
        }
    }

    private var roleIcon: String {
        switch user.role {
        case .admin: return "shield.fill"
        case .creator: return creatorProfile?.tier?.icon ?? "star.fill"
        case .consumer: return "graduationcap.fill"
        }
    }

    private var roleColor: Color {
        switch user.role {
        case .admin: return ColorTokens.info
        case .creator: return creatorProfile?.tier?.color ?? ColorTokens.gold
        case .consumer: return ColorTokens.gold
        }
    }

    // MARK: - Stats

    private func statButton(count: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Skills

    private func skillsRow(_ skills: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(skills.prefix(8), id: \.self) { skill in
                    Text(skill)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}
