import SwiftUI

// MARK: - Admin User Detail View

struct AdminUserDetailView: View {
    @Environment(DependencyContainer.self) private var dependencies

    let user: User

    @State private var showBanConfirmation: Bool = false
    @State private var showUnbanConfirmation: Bool = false
    @State private var isActionInProgress: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {

                    // Profile Header
                    profileHeader

                    // User Info Section
                    userInfoSection

                    // Account Status Section
                    accountStatusSection

                    // Education Section
                    if !user.education.isEmpty {
                        educationSection
                    }

                    // Work Experience Section
                    if !user.workExperience.isEmpty {
                        workExperienceSection
                    }

                    // Skills Section
                    if !user.skills.isEmpty {
                        skillsSection
                    }

                    // Social Stats Section
                    socialStatsSection

                    // Activity Summary Section (Placeholder)
                    activitySummarySection

                    // Admin Actions Section
                    adminActionsSection

                    // Bottom spacing
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("User Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // Ban Confirmation
        .alert("Ban User", isPresented: $showBanConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Ban", role: .destructive) {
                Task { await banUser() }
            }
        } message: {
            Text("Are you sure you want to ban \(user.firstName) \(user.lastName)? They will immediately lose access to the platform.")
        }
        // Unban Confirmation
        .alert("Unban User", isPresented: $showUnbanConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unban") {
                Task { await unbanUser() }
            }
        } message: {
            Text("Are you sure you want to unban \(user.firstName) \(user.lastName)? They will regain full access to the platform.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.md) {
            CreatorAvatar(
                imageURL: user.profilePicture,
                name: "\(user.firstName) \(user.lastName)",
                size: 80
            )

            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    if user.isBanned {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.error)
                    }
                }

                if let username = user.username {
                    Text("@\(username)")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                AdminRoleBadge(role: user.role)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - User Info Section

    private var userInfoSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Contact Information")

            VStack(spacing: 0) {
                InfoRow(icon: "envelope.fill", label: "Email", value: user.email)

                Divider()
                    .overlay(ColorTokens.surfaceElevatedDark)

                InfoRow(
                    icon: "phone.fill",
                    label: "Phone",
                    value: user.phone ?? "Not provided"
                )

                Divider()
                    .overlay(ColorTokens.surfaceElevatedDark)

                InfoRow(
                    icon: "mappin.circle.fill",
                    label: "Location",
                    value: user.location ?? "Not provided"
                )

                Divider()
                    .overlay(ColorTokens.surfaceElevatedDark)

                InfoRow(
                    icon: "calendar",
                    label: "Joined",
                    value: formattedDate(user.createdAt)
                )

                if let lastLogin = user.lastLoginAt {
                    Divider()
                        .overlay(ColorTokens.surfaceElevatedDark)

                    InfoRow(
                        icon: "clock.arrow.circlepath",
                        label: "Last Login",
                        value: formattedDate(lastLogin)
                    )
                }
            }
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Account Status Section

    private var accountStatusSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Account Status")

            VStack(spacing: 0) {
                StatusRow(
                    label: "Email Verified",
                    isVerified: user.isEmailVerified
                )

                Divider()
                    .overlay(ColorTokens.surfaceElevatedDark)

                StatusRow(
                    label: "Phone Verified",
                    isVerified: user.isPhoneVerified
                )

                Divider()
                    .overlay(ColorTokens.surfaceElevatedDark)

                StatusRow(
                    label: "Account Active",
                    isVerified: user.isActive
                )

                Divider()
                    .overlay(ColorTokens.surfaceElevatedDark)

                StatusRow(
                    label: "Onboarding Complete",
                    isVerified: user.onboardingComplete
                )

                Divider()
                    .overlay(ColorTokens.surfaceElevatedDark)

                HStack {
                    Text("Ban Status")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Spacer()

                    Text(user.isBanned ? "Banned" : "Active")
                        .font(Typography.bodyBold)
                        .foregroundStyle(user.isBanned ? ColorTokens.error : ColorTokens.success)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
            }
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Education Section

    private var educationSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Education")

            VStack(spacing: Spacing.sm) {
                ForEach(user.education.indices, id: \.self) { index in
                    let edu = user.education[index]
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.info)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(edu.degree)
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Text(edu.institution)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondaryDark)

                            if edu.currentlyPursuing {
                                Text("Currently Pursuing")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.warning)
                            } else if let year = edu.yearOfCompletion {
                                Text("Completed \(year)")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiaryDark)
                            }
                        }

                        Spacer()
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Work Experience Section

    private var workExperienceSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Work Experience")

            VStack(spacing: Spacing.sm) {
                ForEach(user.workExperience.indices, id: \.self) { index in
                    let work = user.workExperience[index]
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.warning)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(work.role)
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Text(work.company)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondaryDark)

                            if work.currentlyWorking {
                                Text("Currently Working")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.success)
                            } else if let years = work.years {
                                Text("\(years) year\(years == 1 ? "" : "s")")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiaryDark)
                            }
                        }

                        Spacer()
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Skills")

            FlowLayout(spacing: Spacing.sm) {
                ForEach(user.skills, id: \.self) { skill in
                    Text(skill)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.primary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(ColorTokens.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Social Stats Section

    private var socialStatsSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Social")

            HStack(spacing: Spacing.md) {
                SocialStatCard(
                    icon: "person.2.fill",
                    label: "Followers",
                    value: "\(user.followersCount)"
                )

                SocialStatCard(
                    icon: "person.badge.plus",
                    label: "Following",
                    value: "\(user.followingCount)"
                )
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Activity Summary Section (Placeholder)

    private var activitySummarySection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Activity Summary")

            VStack(spacing: Spacing.md) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    Text("Activity analytics coming soon")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    Spacer()
                }
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Admin Actions Section

    private var adminActionsSection: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "Admin Actions")

            VStack(spacing: Spacing.sm) {
                // Ban / Unban Button
                if user.isBanned {
                    Button {
                        showUnbanConfirmation = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            if isActionInProgress {
                                ProgressView()
                                    .tint(ColorTokens.success)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                            }
                            Text("Unban User")
                                .font(Typography.bodyBold)
                        }
                        .foregroundStyle(ColorTokens.success)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(ColorTokens.success.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(ColorTokens.success.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isActionInProgress)
                } else {
                    Button {
                        showBanConfirmation = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            if isActionInProgress {
                                ProgressView()
                                    .tint(ColorTokens.error)
                            } else {
                                Image(systemName: "nosign")
                                    .font(.system(size: 18))
                            }
                            Text("Ban User")
                                .font(Typography.bodyBold)
                        }
                        .foregroundStyle(ColorTokens.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(ColorTokens.error.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(ColorTokens.error.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isActionInProgress)
                }

                // Change Role Button (Placeholder)
                Button {
                    // Placeholder: role change not yet implemented
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 18))
                        Text("Change Role")
                            .font(Typography.bodyBold)
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(ColorTokens.surfaceElevatedDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(ColorTokens.textTertiaryDark.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Actions

    private func banUser() async {
        isActionInProgress = true
        do {
            try await dependencies.adminService.ban(userId: user.id)
            dependencies.hapticManager.success()
        } catch {
            dependencies.hapticManager.error()
        }
        isActionInProgress = false
    }

    private func unbanUser() async {
        isActionInProgress = true
        do {
            try await dependencies.adminService.unban(userId: user.id)
            dependencies.hapticManager.success()
        } catch {
            dependencies.hapticManager.error()
        }
        isActionInProgress = false
    }

    // MARK: - Helpers

    private func formattedDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: dateString) else {
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
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiaryDark)
                .frame(width: 20)

            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            Spacer()

            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
    }
}

// MARK: - Status Row

private struct StatusRow: View {
    let label: String
    let isVerified: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Spacer()

            Image(systemName: isVerified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(isVerified ? ColorTokens.success : ColorTokens.textTertiaryDark)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
    }
}

// MARK: - Social Stat Card

private struct SocialStatCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(ColorTokens.primary)

            Text(value)
                .font(Typography.monoLarge)
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
}

// MARK: - Admin Role Badge

private struct AdminRoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.rawValue.capitalized)
            .font(Typography.bodySmall)
            .foregroundStyle(roleColor)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
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
