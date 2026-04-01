import SwiftUI

struct ProfileTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(ObjectiveContext.self) private var objectiveContext
    @State private var viewModel = ProfileViewModel()
    @State private var showFollowList = false
    @State private var showCreatorApplication = false
    @State private var showAddObjective = false
    @State private var showCreateContent = false
    @State private var followListMode: FollowListMode = .followers

    enum FollowListMode {
        case followers, following
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.user == nil {
                    loadingView
                } else if let user = viewModel.user {
                    profileContent(user: user)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .refreshable {
                await viewModel.loadProfile()
            }
            .task {
                if viewModel.user == nil {
                    await viewModel.loadProfile()
                }
            }
            .sheet(isPresented: $viewModel.showEditSheet) {
                if let user = viewModel.user {
                    EditProfileSheet(user: user) { updated in
                        viewModel.applyUpdatedUser(updated)
                        appState.currentUser = updated
                    }
                }
            }
            .sheet(isPresented: $showFollowList) {
                if let user = viewModel.user {
                    FollowListSheet(userId: user.id, mode: followListMode)
                }
            }
            .sheet(isPresented: $showCreatorApplication) {
                CreatorApplicationView { app in
                    viewModel.applicationStatus = app
                }
            }
            .sheet(isPresented: $showAddObjective) {
                AddObjectiveSheet { newObj in
                    viewModel.objectives.insert(newObj, at: 0)
                }
            }
            .sheet(isPresented: $showCreateContent) {
                CreateContentView()
            }
            .navigationDestination(for: Content.self) { content in
                ContentDestinationView(content: content)
            }
            .navigationDestination(for: DailyChallenge.self) { challenge in
                ChallengeSessionView(challengeId: challenge.id, topic: challenge.topic)
            }
            .navigationDestination(for: LiveEvent.self) { event in
                LiveEventLobbyView(event: event)
            }
            .navigationDestination(for: LeaderboardDestination.self) { _ in
                LeaderboardView()
            }
        }
        .coachMark(
            .tabProfile,
            icon: "person.fill",
            title: "Your Account",
            message: "Manage objectives, view saved content, AI tutor history, and apply to become a creator."
        )
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ProfileHeaderView(
                    user: user,
                    creatorProfile: viewModel.creatorProfile,
                    onEditTapped: { viewModel.showEditSheet = true },
                    onFollowersTapped: {
                        followListMode = .followers
                        showFollowList = true
                    },
                    onFollowingTapped: {
                        followListMode = .following
                        showFollowList = true
                    }
                )

                Divider()
                    .overlay(ColorTokens.divider)
                    .padding(.horizontal, Spacing.md)

                // Role-specific sections
                roleSpecificSection(user: user)

                // Learning Tools group
                VStack(spacing: Spacing.sm) {
                    sectionLabel("Learning Tools")
                    myNotesLink
                    myFlashcardsLink
                    aiTutorHistoryLink
                }

                // Competition group
                VStack(spacing: Spacing.sm) {
                    sectionLabel("Competition")
                    competitionLink
                }

                // Admin group
                if viewModel.user?.role == .admin {
                    VStack(spacing: Spacing.sm) {
                        sectionLabel("Admin")
                        pendingNotesLink
                    }
                }

                // Objectives section (all users)
                objectivesSection

                // Content tabs
                contentTabsSection

                // Member since
                Text(viewModel.memberSince)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.bottom, Spacing.xl)
            }
        }
    }

    // MARK: - Role Specific Section

    @ViewBuilder
    private func roleSpecificSection(user: User) -> some View {
        if user.role == .consumer {
            if let app = viewModel.applicationStatus {
                // Has an existing application — show status card
                applicationStatusCard(app)
            } else {
                // No application — show "Become a Creator" banner
                becomeCreatorBanner
            }
        }

        if user.role == .creator {
            creatorDashboardPreview
        }

        if user.role == .admin {
            NavigationLink {
                AdminDashboardView()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(ColorTokens.info)
                    Text("Admin Dashboard")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(Spacing.md)
                .background(ColorTokens.info.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.info.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Become Creator Banner

    private var becomeCreatorBanner: some View {
        Button {
            showCreatorApplication = true
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Become a Creator")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Share your knowledge with the community")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(Spacing.md)
            .background(ColorTokens.goldGradient.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Application Status Card

    private func applicationStatusCard(_ app: CreatorApplication) -> some View {
        NavigationLink {
            ApplicationStatusView(application: app)
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: app.status.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(app.status.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Creator Application")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Status: \(app.status.displayName)")
                        .font(Typography.caption)
                        .foregroundStyle(app.status.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .background(app.status.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(app.status.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Creator Dashboard Preview

    private var creatorDashboardPreview: some View {
        VStack(spacing: 0) {
            if let profile = viewModel.creatorProfile {
                // Tier header with gradient
                creatorTierHeader(profile)

                // Stats strip
                if let stats = profile.stats {
                    creatorStatsStrip(stats)
                }

                // Quick actions
                creatorQuickActions(profile)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            (viewModel.creatorProfile?.tier?.color ?? ColorTokens.gold).opacity(0.4),
                            ColorTokens.border.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, Spacing.md)
    }

    private func creatorTierHeader(_ profile: CreatorProfileData) -> some View {
        let tierColor = profile.tier?.color ?? ColorTokens.gold
        return HStack(spacing: 12) {
            // Tier icon with glow
            ZStack {
                Circle()
                    .fill(tierColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(tierColor.opacity(0.08))
                    .frame(width: 56, height: 56)
                Image(systemName: profile.tier?.icon ?? "star.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tierColor)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(profile.tier?.displayName ?? "Creator") Creator")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                if let domain = profile.domain {
                    Text(domain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tierColor)
                }
            }

            Spacer()

            // Verified badge
            if profile.isVerified == true {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(tierColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [tierColor.opacity(0.12), ColorTokens.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func creatorStatsStrip(_ stats: CreatorStats) -> some View {
        HStack(spacing: 0) {
            creatorStat(value: formatStatNumber(stats.totalContent ?? 0), label: "Content", icon: "doc.text.fill")
            statDivider
            creatorStat(value: formatStatNumber(stats.totalViews ?? 0), label: "Views", icon: "eye.fill")
            statDivider
            creatorStat(value: formatStatNumber(stats.totalFollowers ?? 0), label: "Followers", icon: "person.2.fill")
            statDivider
            creatorStat(value: String(format: "%.1f", stats.averageRating ?? 0), label: "Rating", icon: "star.fill")
        }
        .padding(.vertical, 14)
        .background(ColorTokens.surface)
    }

    private func creatorStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(ColorTokens.border.opacity(0.3))
            .frame(width: 1, height: 32)
    }

    private func creatorQuickActions(_ profile: CreatorProfileData) -> some View {
        VStack(spacing: 0) {
            // Create Content — hero action
            Button {
                showCreateContent = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.gold)
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    Text("Create Content")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Divider().overlay(ColorTokens.border.opacity(0.2))

            // My Content
            NavigationLink {
                MyContentView()
            } label: {
                creatorActionRow(icon: "rectangle.stack.fill", title: "My Content")
            }
            .buttonStyle(.plain)

            // Review Applications (core/anchor only)
            if profile.tier == .core || profile.tier == .anchor {
                Divider().overlay(ColorTokens.border.opacity(0.2))

                NavigationLink {
                    PendingApplicationsView()
                } label: {
                    creatorActionRow(icon: "person.badge.clock", title: "Review Applications")
                }
                .buttonStyle(.plain)
            }
        }
        .background(ColorTokens.surface)
    }

    private func creatorActionRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 32, height: 32)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func formatStatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    // MARK: - AI Tutor History Link

    private var aiTutorHistoryLink: some View {
        NavigationLink {
            AITutorHistoryView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Tutor History")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Review past AI tutor conversations")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(ColorTokens.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
    }

    // MARK: - My Notes Link

    private var myNotesLink: some View {
        NavigationLink {
            MyNotesView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "doc.text.image.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("My Notes")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Upload and manage your notes")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.lg)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - My Flashcards Link

    private var myFlashcardsLink: some View {
        NavigationLink {
            MyFlashcardsView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 24))
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("My Flashcards")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Study your generated flashcard sets")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.lg)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Pending Notes Link (Admin)

    private var pendingNotesLink: some View {
        NavigationLink {
            PendingNotesReviewView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "doc.badge.clock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Review Notes")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Approve or reject pending submissions")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.lg)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Competition Link

    private var competitionLink: some View {
        NavigationLink {
            CompetitionHubView()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: 0xFFD700))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Challenges")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Compete, climb the leaderboard")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color(hex: 0xFFD700).opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Objectives Section

    private var objectivesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.gold)
                    Text("My Objectives")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    Haptics.light()
                    showAddObjective = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)

            if viewModel.objectives.count > 1 {
                Text("Tap an objective to switch. Your plan and progress update accordingly.")
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.horizontal, Spacing.md)
            }

            if viewModel.objectives.isEmpty {
                Button {
                    Haptics.light()
                    showAddObjective = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "scope")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.gold.opacity(0.6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set your first objective")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("Track your learning goals and progress")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .padding(14)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTokens.border.opacity(0.3), lineWidth: 1)
                            .stroke(ColorTokens.gold.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.md)
            } else {
                ForEach(viewModel.objectives.prefix(3)) { objective in
                    objectiveRow(objective)
                }
            }
        }
    }

    private func objectiveRow(_ obj: UserObjective) -> some View {
        objectiveRowContent(obj, isActive: obj.isPrimary == true)
    }

    private func objectiveRowContent(_ obj: UserObjective, isActive: Bool) -> some View {
        Button {
            if !isActive {
                Haptics.light()
                Task { await viewModel.activateObjective(obj.id, context: objectiveContext) }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                // Icon with active indicator
                ZStack {
                    Image(systemName: obj.typeIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(isActive ? ColorTokens.gold : ColorTokens.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(isActive ? ColorTokens.gold.opacity(0.15) : ColorTokens.gold.opacity(0.05))
                        .clipShape(Circle())

                    if isActive {
                        Circle()
                            .stroke(ColorTokens.gold, lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(obj.specificTitle)
                            .font(Typography.bodySmall)
                            .foregroundStyle(isActive ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                            .lineLimit(1)
                        if isActive {
                            Text("ACTIVE")
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorTokens.gold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: Spacing.xs) {
                        Text(obj.typeDisplay)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("\u{2022}")
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(obj.levelDisplay)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("\u{2022}")
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(obj.timelineDisplay)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    if let topics = obj.topicsOfInterest, !topics.isEmpty {
                        Text(topics.prefix(3).joined(separator: ", "))
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.gold.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.gold)
                } else {
                    Text("Switch")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(Spacing.sm)
            .padding(.horizontal, Spacing.xs)
            .background(isActive ? ColorTokens.gold.opacity(0.06) : ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(isActive ? ColorTokens.gold.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
        .contextMenu {
            if obj.status == .active && isActive {
                Button {
                    Task { await viewModel.pauseObjective(obj.id) }
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
            }
            if obj.status == .paused {
                Button {
                    Task { await viewModel.resumeObjective(obj.id) }
                } label: {
                    Label("Resume", systemImage: "play.circle")
                }
            }
        }
    }

    private func statusColor(_ status: ObjectiveStatus) -> Color {
        switch status {
        case .active: return ColorTokens.success
        case .paused: return ColorTokens.warning
        case .completed: return ColorTokens.gold
        case .abandoned: return ColorTokens.textTertiary
        }
    }

    // MARK: - Content Tabs

    @State private var selectedContentTab = 0

    private var contentTabsSection: some View {
        VStack(spacing: Spacing.md) {
            // Tab selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    contentTabChip("Liked", tab: 0, icon: "heart.fill")
                    contentTabChip("Saved", tab: 1, icon: "bookmark.fill")
                    contentTabChip("Playlists", tab: 2, icon: "list.star")
                    contentTabChip("History", tab: 3, icon: "clock.fill")
                }
                .padding(.horizontal, Spacing.md)
            }

            // Tab content
            switch selectedContentTab {
            case 0:
                contentList(items: viewModel.likedContent, emptyMessage: "No liked content yet")
                    .task { await viewModel.loadLikedContent() }
            case 1:
                contentList(items: viewModel.savedContent, emptyMessage: "No saved content yet")
                    .task { await viewModel.loadSavedContent() }
            case 2:
                playlistsList
                    .task { await viewModel.loadPlaylists() }
            case 3:
                historyList
                    .task { await viewModel.loadViewHistory() }
            default:
                EmptyView()
            }
        }
    }

    private func contentTabChip(_ title: String, tab: Int, icon: String) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedContentTab = tab
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(Typography.bodySmall)
            }
            .foregroundStyle(selectedContentTab == tab ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(selectedContentTab == tab ? ColorTokens.gold : ColorTokens.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Grid

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    @ViewBuilder
    private func contentList(items: [Content], emptyMessage: String) -> some View {
        if items.isEmpty {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text(emptyMessage)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
        } else {
            LazyVGrid(columns: gridColumns, spacing: Spacing.sm) {
                ForEach(items) { content in
                    NavigationLink(value: content) {
                        contentGridCell(content)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func contentGridCell(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with duration overlay
            ZStack(alignment: .bottomTrailing) {
                if let thumb = content.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            ColorTokens.surfaceElevated
                        }
                    }
                    .frame(height: 100)
                    .clipped()
                } else {
                    ColorTokens.surfaceElevated
                        .frame(height: 100)
                }

                if !content.overlayBadge.isEmpty {
                    Text(content.overlayBadge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(6)
                }
            }

            // Title + creator
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                if let creator = content.creatorId {
                    Text(creator.displayName)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - History Grid

    @ViewBuilder
    private var historyList: some View {
        if viewModel.viewHistory.isEmpty {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("No watch history yet")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
        } else {
            LazyVGrid(columns: gridColumns, spacing: Spacing.sm) {
                ForEach(viewModel.viewHistory) { progress in
                    if let content = progress.content {
                        NavigationLink(value: content) {
                            historyGridCell(progress)
                        }
                        .buttonStyle(.plain)
                    } else {
                        historyGridCell(progress)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func historyGridCell(_ progress: ContentProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with percentage overlay
            ZStack(alignment: .bottomTrailing) {
                if let content = progress.content, let thumb = content.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            ColorTokens.surfaceElevated
                        }
                    }
                    .frame(height: 100)
                    .clipped()
                } else {
                    ColorTokens.surfaceElevated
                        .frame(height: 100)
                }

                // Percentage badge
                Text("\(progress.percentageCompleted ?? 0)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(progress.isCompleted == true ? .black : .white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(progress.isCompleted == true ? ColorTokens.success : .black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(6)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(ColorTokens.surfaceElevated)
                    Rectangle()
                        .fill(progress.isCompleted == true ? ColorTokens.success : ColorTokens.gold)
                        .frame(width: geo.size.width * progress.progress)
                }
            }
            .frame(height: 3)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.content?.title ?? "Content")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Playlists List

    @ViewBuilder
    private var playlistsList: some View {
        if viewModel.isLoadingPlaylists && viewModel.playlists.isEmpty {
            ProgressView().tint(ColorTokens.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        } else if viewModel.playlists.isEmpty {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "list.star")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("No playlists yet")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("Create one from any video's action bar")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlistId: playlist.id)
                    } label: {
                        playlistRow(playlist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func playlistRow(_ playlist: Playlist) -> some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 50, height: 50)
                Image(systemName: "music.note.list")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text("\(playlist.itemCount ?? 0) items")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if !playlist.formattedDuration.isEmpty {
                        Text("·")
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(playlist.formattedDuration)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.deletePlaylist(playlist) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Loading / Empty States

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            SkeletonLoader(width: 80, height: 80, cornerRadius: 40)
            SkeletonLoader(width: 150, height: 20)
            SkeletonLoader(width: 100, height: 14)
            HStack(spacing: Spacing.xl) {
                SkeletonLoader(width: 60, height: 30)
                SkeletonLoader(width: 60, height: 30)
            }
        }
        .padding(.top, Spacing.xxl)
    }

    private var emptyStateView: some View {
        ErrorStateView(
            message: "We couldn't load your profile.\nCheck your connection and try again.",
            retryLabel: "Reload Profile",
            onRetry: {
                Task { await viewModel.loadProfile() }
            }
        )
    }
}

// MARK: - Follow List Sheet

struct FollowListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    let mode: ProfileTabView.FollowListMode

    @State private var followers: [FollowUser] = []
    @State private var following: [FollowUser] = []
    @State private var selectedSegment = 0
    @State private var isLoading = false

    private let userService = UserService()

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented picker
                    Picker("", selection: $selectedSegment) {
                        Text("Followers").tag(0)
                        Text("Following").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(Spacing.md)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(ColorTokens.gold)
                        Spacer()
                    } else {
                        let items = selectedSegment == 0 ? followers : following
                        if items.isEmpty {
                            Spacer()
                            Text(selectedSegment == 0 ? "No followers yet" : "Not following anyone")
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Spacer()
                        } else {
                            List(items) { user in
                                followUserRow(user)
                                    .listRowBackground(ColorTokens.surface)
                            }
                            .scrollContentBackground(.hidden)
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(selectedSegment == 0 ? "Followers" : "Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .onAppear {
                selectedSegment = mode == .followers ? 0 : 1
            }
            .task {
                await loadData()
            }
            .onChange(of: selectedSegment) {
                Task { await loadData() }
            }
        }
    }

    private func followUserRow(_ user: FollowUser) -> some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 40, height: 40)
                Text(user.initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let role = user.role {
                    Text(role.rawValue.capitalized)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            Spacer()
        }
    }

    private func loadData() async {
        isLoading = true
        if selectedSegment == 0 && followers.isEmpty {
            followers = (try? await userService.fetchFollowers(userId: userId)) ?? []
        } else if selectedSegment == 1 && following.isEmpty {
            following = (try? await userService.fetchFollowing(userId: userId)) ?? []
        }
        isLoading = false
    }
}
