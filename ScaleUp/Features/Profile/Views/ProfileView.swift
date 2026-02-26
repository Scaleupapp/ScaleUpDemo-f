import SwiftUI

// MARK: - Profile View

struct ProfileView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var viewModel: ProfileViewModel?

    private let contentColumns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.user == nil {
                        profileSkeletonView
                    } else if let error = viewModel.error, viewModel.user == nil {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadProfile() }
                            }
                        )
                    } else if viewModel.user != nil {
                        profileContent(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle(viewModel?.displayName ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel?.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showEditSheet ?? false },
                set: { viewModel?.showEditSheet = $0 }
            )) {
                if let user = viewModel?.user {
                    EditProfileView(user: user) { updatedUser in
                        viewModel?.applyUpdatedUser(updatedUser)
                        appState.currentUser = updatedUser
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel?.showSettings ?? false },
                set: { viewModel?.showSettings = $0 }
            )) {
                SettingsView()
            }
            .navigationDestination(for: Content.self) { content in
                ContentDetailView(contentId: content.id)
            }
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlistId: playlist.id)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ProfileViewModel(
                    userService: dependencies.userService,
                    contentService: dependencies.contentService,
                    progressService: dependencies.progressService,
                    socialService: dependencies.socialService,
                    objectiveService: dependencies.objectiveService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.user == nil {
                // Use appState.currentUser as an immediate cache, then fetch fresh data
                if let cachedUser = appState.currentUser {
                    viewModel.applyUpdatedUser(cachedUser)
                }
                await viewModel.loadProfile()
                await viewModel.loadActivityData()
            }
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(viewModel: ProfileViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Profile Header
                profileHeader(viewModel: viewModel)

                // Quick Actions
                quickActionsRow(viewModel: viewModel)

                // Activity Tabs
                activityTabBar(viewModel: viewModel)

                // Activity Content
                activityContent(viewModel: viewModel)

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
    private func profileHeader(viewModel: ProfileViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            // Avatar
            CreatorAvatar(
                imageURL: viewModel.user?.profilePicture,
                name: viewModel.displayName,
                size: 100
            )

            // Name & Username
            VStack(spacing: Spacing.xs) {
                Text(viewModel.displayName)
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                if let username = viewModel.usernameDisplay {
                    Text(username)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }

            // Role Badge
            roleBadge(text: viewModel.roleBadgeText, role: viewModel.user?.role ?? .consumer)

            // Bio
            if let bio = viewModel.user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Stats Row
            if let user = viewModel.user {
                statsRow(user: user)
            }

            // Location & Member Since
            HStack(spacing: Spacing.md) {
                if let location = viewModel.user?.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                if let memberSince = viewModel.memberSinceFormatted {
                    Label(memberSince, systemImage: "calendar")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Role Badge

    @ViewBuilder
    private func roleBadge(text: String, role: UserRole) -> some View {
        let badgeColor: Color = switch role {
        case .creator: ColorTokens.primary
        case .admin: ColorTokens.warning
        case .consumer: ColorTokens.info
        }

        Text(text)
            .font(Typography.micro)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(badgeColor)
            .clipShape(Capsule())
    }

    // MARK: - Stats Row

    @ViewBuilder
    private func statsRow(user: User) -> some View {
        HStack(spacing: Spacing.xl) {
            NavigationLink {
                FollowListView(
                    userId: user.id,
                    initialMode: .followers
                )
            } label: {
                statItem(count: user.followersCount, label: "Followers")
            }

            divider

            NavigationLink {
                FollowListView(
                    userId: user.id,
                    initialMode: .following
                )
            } label: {
                statItem(count: user.followingCount, label: "Following")
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(ColorTokens.textTertiaryDark.opacity(0.3))
            .frame(width: 1, height: 32)
    }

    // MARK: - Quick Actions Row

    @ViewBuilder
    private func quickActionsRow(viewModel: ProfileViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            SecondaryButton(title: "Edit Profile") {
                viewModel.showEditSheet = true
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Activity Tab Bar

    @ViewBuilder
    private func activityTabBar(viewModel: ProfileViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ProfileViewModel.ActivityTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedTab = tab
                        }
                        Task { await viewModel.loadActivityData() }
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: tabIcon(tab))
                                    .font(.system(size: 13))
                                Text(tab.rawValue)
                                    .font(Typography.bodySmall)
                            }
                            .foregroundStyle(
                                viewModel.selectedTab == tab
                                    ? ColorTokens.primary
                                    : ColorTokens.textSecondaryDark
                            )
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)

                            Rectangle()
                                .fill(viewModel.selectedTab == tab ? ColorTokens.primary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(
            VStack {
                Spacer()
                Rectangle()
                    .fill(ColorTokens.surfaceElevatedDark)
                    .frame(height: 1)
            }
        )
        .padding(.horizontal, Spacing.md)
    }

    private func tabIcon(_ tab: ProfileViewModel.ActivityTab) -> String {
        switch tab {
        case .objectives: return "target"
        case .liked: return "heart.fill"
        case .saved: return "bookmark.fill"
        case .history: return "clock.fill"
        case .playlists: return "music.note.list"
        }
    }

    // MARK: - Activity Content

    @ViewBuilder
    private func activityContent(viewModel: ProfileViewModel) -> some View {
        if viewModel.isLoadingActivity && viewModel.currentTabItemCount == 0 {
            activityLoadingSkeleton
        } else {
            switch viewModel.selectedTab {
            case .objectives:
                objectivesList(viewModel: viewModel)
            case .liked:
                contentGrid(items: viewModel.likedContent, emptyIcon: "heart", emptyText: "No liked content yet", emptySubtext: "Videos you like will appear here")
            case .saved:
                contentGrid(items: viewModel.savedContent, emptyIcon: "bookmark", emptyText: "No saved content yet", emptySubtext: "Videos you bookmark will appear here")
            case .history:
                historyList(items: viewModel.historyContent)
            case .playlists:
                playlistsList(items: viewModel.playlists)
            }
        }
    }

    // MARK: - Objectives List

    @ViewBuilder
    private func objectivesList(viewModel: ProfileViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            // Add Objective button
            Button {
                viewModel.showAddObjective = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Objective")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(ColorTokens.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(ColorTokens.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .buttonStyle(.plain)

            if viewModel.objectives.isEmpty {
                activityEmptyState(
                    icon: "target",
                    title: "No objectives set",
                    subtitle: "Define your learning goals to get personalized journeys"
                )
            } else {
                ForEach(viewModel.objectives) { objective in
                    objectiveCard(objective, viewModel: viewModel)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .sheet(isPresented: Binding(
            get: { viewModel.showAddObjective },
            set: { viewModel.showAddObjective = $0 }
        )) {
            AddObjectiveSheet(viewModel: viewModel)
        }
    }

    private func objectiveCard(_ objective: Objective, viewModel: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header: type + status
            HStack {
                // Type icon + label
                HStack(spacing: Spacing.xs) {
                    Image(systemName: objectiveTypeIcon(objective.objectiveType))
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.primary)

                    Text(objectiveTypeLabel(objective.objectiveType))
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                }

                Spacer()

                // Status badge
                objectiveStatusBadge(objective)
            }

            // Specifics
            if let specifics = objective.specifics {
                Text(objectiveSpecificsSummary(objective.objectiveType, specifics: specifics))
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .lineLimit(2)
            }

            // Meta row: level, timeline, hours
            HStack(spacing: Spacing.md) {
                if let level = objective.currentLevel {
                    HStack(spacing: 3) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                        Text(level.rawValue.capitalized)
                            .font(Typography.caption)
                    }
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                if let timeline = objective.timeline {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(timelineLabel(timeline))
                            .font(Typography.caption)
                    }
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                }

                if let hours = objective.weeklyCommitHours {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(Int(hours))h/week")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }

            // Weight bar
            if let weight = objective.weight, weight > 0 {
                HStack(spacing: Spacing.xs) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorTokens.surfaceElevatedDark)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorTokens.primary)
                                .frame(width: geo.size.width * Double(weight) / 100.0, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(weight)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .frame(width: 30, alignment: .trailing)
                }
            }

            // Action buttons
            HStack(spacing: Spacing.sm) {
                if objective.status == .active {
                    Button {
                        Task { await viewModel.pauseObjective(objective) }
                    } label: {
                        Label("Pause", systemImage: "pause.circle")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.warning)
                    }
                    .buttonStyle(.plain)

                    if objective.isPrimary != true {
                        Button {
                            Task { await viewModel.setPrimaryObjective(objective) }
                        } label: {
                            Label("Set Primary", systemImage: "star")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.primary)
                        }
                        .buttonStyle(.plain)
                    }
                } else if objective.status == .paused {
                    Button {
                        Task { await viewModel.resumeObjective(objective) }
                    } label: {
                        Label("Resume", systemImage: "play.circle")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.success)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    objective.isPrimary == true ? ColorTokens.primary.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private func objectiveStatusBadge(_ objective: Objective) -> some View {
        let (text, color): (String, Color) = {
            if objective.isPrimary == true && objective.status == .active {
                return ("Primary", ColorTokens.primary)
            }
            switch objective.status {
            case .active: return ("Active", ColorTokens.success)
            case .paused: return ("Paused", ColorTokens.warning)
            case .completed: return ("Done", ColorTokens.info)
            case .none: return ("Active", ColorTokens.success)
            }
        }()

        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func objectiveTypeIcon(_ type: ObjectiveType) -> String {
        switch type {
        case .examPreparation: return "doc.text.fill"
        case .upskilling: return "arrow.up.circle.fill"
        case .interviewPreparation: return "person.crop.rectangle.fill"
        case .networking: return "person.3.fill"
        case .careerSwitch: return "arrow.triangle.swap"
        case .academicExcellence: return "graduationcap.fill"
        case .casualLearning: return "book.fill"
        }
    }

    private func objectiveTypeLabel(_ type: ObjectiveType) -> String {
        switch type {
        case .examPreparation: return "Exam Preparation"
        case .upskilling: return "Upskilling"
        case .interviewPreparation: return "Interview Prep"
        case .networking: return "Networking"
        case .careerSwitch: return "Career Switch"
        case .academicExcellence: return "Academic Excellence"
        case .casualLearning: return "Casual Learning"
        }
    }

    private func objectiveSpecificsSummary(_ type: ObjectiveType, specifics: ObjectiveSpecifics) -> String {
        switch type {
        case .examPreparation:
            return specifics.examName ?? "Exam preparation"
        case .upskilling, .casualLearning, .networking:
            return specifics.targetSkill ?? type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        case .interviewPreparation:
            var parts: [String] = []
            if let role = specifics.targetRole { parts.append(role) }
            if let company = specifics.targetCompany { parts.append("at \(company)") }
            return parts.isEmpty ? "Interview preparation" : parts.joined(separator: " ")
        case .careerSwitch:
            if let from = specifics.fromDomain, let to = specifics.toDomain {
                return "\(from) → \(to)"
            }
            return "Career transition"
        case .academicExcellence:
            return specifics.targetSkill ?? "Academic focus"
        }
    }

    private func timelineLabel(_ timeline: Timeline) -> String {
        switch timeline {
        case .oneMonth: return "1 month"
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .oneYear: return "1 year"
        case .noDeadline: return "No deadline"
        }
    }

    // MARK: - Content Grid (Liked / Saved)

    @ViewBuilder
    private func contentGrid(items: [Content], emptyIcon: String, emptyText: String, emptySubtext: String) -> some View {
        if items.isEmpty {
            activityEmptyState(icon: emptyIcon, title: emptyText, subtitle: emptySubtext)
        } else {
            LazyVGrid(columns: contentColumns, spacing: Spacing.md) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        profileContentCard(item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Profile Content Card

    private func profileContentCard(_ item: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
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

                // Duration badge
                if let duration = item.duration, duration > 0 {
                    Text(formatDuration(duration))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
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

                Text(item.creator.firstName + " " + item.creator.lastName)
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                    .lineLimit(1)

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
                }
            }
        }
    }

    // MARK: - History List

    @ViewBuilder
    private func historyList(items: [ContentProgress]) -> some View {
        if items.isEmpty {
            activityEmptyState(icon: "clock", title: "No watch history", subtitle: "Videos you watch will appear here")
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(items) { progress in
                    historyRow(progress)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func historyRow(_ progress: ContentProgress) -> some View {
        HStack(spacing: Spacing.sm) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                if case .populated(let content) = progress.contentId,
                   let thumbURL = content.resolvedThumbnailURL,
                   let url = URL(string: thumbURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(ColorTokens.surfaceElevatedDark)
                            .overlay {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ColorTokens.textTertiaryDark)
                            }
                    }
                } else {
                    Rectangle()
                        .fill(ColorTokens.surfaceElevatedDark)
                        .overlay {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }
                }

                // Progress bar overlay at bottom
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(progress.isCompleted ? ColorTokens.success : ColorTokens.primary)
                            .frame(
                                width: geo.size.width * min(progress.percentageCompleted / 100, 1.0),
                                height: 3
                            )
                    }
                }
            }
            .frame(width: 80, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                if case .populated(let content) = progress.contentId {
                    Text(content.title)
                        .font(Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(2)

                    Text(content.creator.firstName + " " + content.creator.lastName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .lineLimit(1)
                } else {
                    Text("Content")
                        .font(Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                }

                HStack(spacing: Spacing.xs) {
                    if progress.isCompleted {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Completed")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(ColorTokens.success)
                    } else {
                        Text("\(Int(progress.percentageCompleted))%")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.primary)
                    }

                    if progress.totalDuration > 0 {
                        Circle()
                            .fill(ColorTokens.textTertiaryDark)
                            .frame(width: 3, height: 3)

                        Text(formatDuration(Int(progress.totalDuration)))
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Playlists List

    @ViewBuilder
    private func playlistsList(items: [Playlist]) -> some View {
        if items.isEmpty {
            activityEmptyState(icon: "music.note.list", title: "No playlists yet", subtitle: "Create a playlist to organize your content")
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(items) { playlist in
                    NavigationLink(value: playlist) {
                        playlistRow(playlist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func playlistRow(_ playlist: Playlist) -> some View {
        HStack(spacing: Spacing.sm) {
            // Playlist thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(ColorTokens.surfaceElevatedDark)

                if let firstItem = playlist.items.first,
                   case .populated(let content) = firstItem.contentId,
                   let thumbURL = content.thumbnailURL,
                   let url = URL(string: thumbURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
            .frame(width: 56, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text("\(playlist.items.count) \(playlist.items.count == 1 ? "video" : "videos")")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)

                    if !playlist.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Empty State

    private func activityEmptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Text(title)
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Activity Loading Skeleton

    private var activityLoadingSkeleton: some View {
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
    }

    // MARK: - Helpers

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: return ColorTokens.success
        case .intermediate: return ColorTokens.warning
        case .advanced: return ColorTokens.error
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins >= 60 {
            let hours = mins / 60
            let remainingMins = mins % 60
            return String(format: "%d:%02d:%02d", hours, remainingMins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Skeleton Loading View

    private var profileSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Avatar skeleton
                SkeletonLoader(width: 100, height: 100, cornerRadius: CornerRadius.full)

                // Name skeleton
                VStack(spacing: Spacing.sm) {
                    SkeletonLoader(width: 180, height: 22)
                    SkeletonLoader(width: 120, height: 14)
                }

                // Role badge skeleton
                SkeletonLoader(width: 60, height: 24, cornerRadius: CornerRadius.full)

                // Bio skeleton
                VStack(spacing: Spacing.xs) {
                    SkeletonLoader(width: 280, height: 14)
                    SkeletonLoader(width: 220, height: 14)
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

                // Edit button skeleton
                SkeletonLoader(height: 52, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)

                // Tab bar skeleton
                HStack(spacing: Spacing.lg) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonLoader(width: 70, height: 28, cornerRadius: CornerRadius.small)
                    }
                }

                // Content grid skeleton
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
            }
            .padding(.vertical, Spacing.md)
        }
    }
}
