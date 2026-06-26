import SwiftUI

/// V2 "You" Tab — full profile + library + role-aware affordances.
///
/// Top: header (avatar + name + username + bio + follower counts) + readiness ring + week/streak/gap stats.
/// Middle: My Library chip strip + My Learning NavigationLink rows.
/// Below: optional UserInference panel, role-gated Creator Hub / Admin Tools, Become-a-Creator card,
/// Settings row, footer.
struct V2YouView: View {
    let isPlacement: Bool

    init(isPlacement: Bool = false) {
        self.isPlacement = isPlacement
    }

    @State private var vm = V2YouViewModel()
    @Environment(AppState.self) private var appState
    @Environment(ObjectiveContext.self) private var objectiveContext

    // Sheet/state
    @State private var showEditProfile = false
    @State private var followListMode: ProfileTabView.FollowListMode = .followers
    @State private var showFollowList = false
    @State private var librarySheet: V2YouLibraryTab?
    @State private var showCreatorApp = false
    @State private var showCreateContent = false
    @State private var showAppStatus = false
    @State private var showReadinessBreakdown = false

    // Inference panel
    @State private var inferences: [UserInference] = []
    @State private var inferencesExpanded = false
    private let inferenceService = UserInferenceService()

    // Hire from ScaleUp — candidate side. Self-gated: the "Open to opportunities"
    // entry only renders when `available == true` (GET /you/talent didn't 404),
    // so the whole feature stays invisible until FEATURE_EMPLOYER_MARKETPLACE flips.
    @State private var hiringVM = V2HiringViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if vm.isLoading && vm.data == nil {
                    loadingState
                } else if let data = vm.data {
                    loadedContent(data: data)
                } else {
                    errorState
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
        }
        .task {
            await vm.load()
            await loadInferences()
            await loadHiring()
        }
        .refreshable {
            await vm.load()
            await loadInferences()
            await loadHiring()
        }
        // Re-inject env on every sheet — v1 views read AppState / ObjectiveContext
        // directly and SwiftUI doesn't reliably propagate @Observable across sheets.
        .sheet(isPresented: $showEditProfile) {
            if let user = appState.currentUser {
                EditProfileSheet(user: user) { updated in
                    appState.currentUser = updated
                }
                .environment(appState)
            }
        }
        .sheet(isPresented: $showFollowList) {
            if let user = appState.currentUser {
                FollowListSheet(userId: user.id, mode: followListMode)
                    .environment(appState)
            }
        }
        .sheet(item: $librarySheet) { tab in
            V2YouLibrarySheet(tab: tab)
                .environment(appState)
                .environment(objectiveContext)
        }
        .sheet(isPresented: $showCreatorApp) {
            CreatorApplicationView { _ in
                Task { await vm.load() }
            }
            .environment(appState)
        }
        .sheet(isPresented: $showCreateContent) {
            CreateContentView()
                .environment(appState)
                .environment(objectiveContext)
        }
        .sheet(isPresented: $showReadinessBreakdown) {
            if let data = vm.data {
                V2ReadinessBreakdownSheet(readiness: data.readiness)
            }
        }
    }

    // MARK: - Loaded content

    @ViewBuilder
    private func loadedContent(data: V2YouOverview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerProfile(data: data)

            readinessRing(readiness: data.readiness)
                .padding(.vertical, 20)

            statsBlock(data: data)

            sectionDivider.padding(.vertical, 18)

            // MY LIBRARY (B2C only)
            if !isPlacement {
                sectionLabel("My library")
                libraryStrip
                    .padding(.bottom, 16)
            }

            // MY LEARNING
            sectionLabel("My learning")
            learningRows(weekProgress: data.weekProgress)

            // OPEN TO OPPORTUNITIES (self-gated — only when the hiring feature is live; B2C only)
            if !isPlacement && hiringVM.available == true {
                sectionDivider.padding(.vertical, 18)
                sectionLabel("Career")
                openToOpportunitiesRow
            }

            // Inference panel (collapsible)
            if !inferences.isEmpty {
                sectionDivider.padding(.vertical, 18)
                inferencePanel
            }

            // Role-gated sections (B2C only)
            if !isPlacement && vm.isCreatorRole {
                sectionDivider.padding(.vertical, 18)
                creatorHubSection
            }

            if !isPlacement && vm.isAdminRole {
                sectionDivider.padding(.vertical, 18)
                adminToolsSection
            }

            // Become creator / application status (B2C only)
            if !isPlacement && vm.isConsumerOrContributor {
                if vm.applicationStatus == nil {
                    becomeCreatorCard
                        .padding(.top, 18)
                } else if let status = vm.applicationStatus, status != "approved" {
                    applicationStatusCard(status: status)
                        .padding(.top, 18)
                }
            }

            // Settings row + footer
            sectionDivider.padding(.vertical, 18)
            settingsRow
            footerView
                .padding(.top, 14)

            Spacer().frame(height: 100)
        }
        .padding(.horizontal, V2Theme.pad)
        .padding(.top, 16)
    }

    // MARK: - Header

    @ViewBuilder
    private func headerProfile(data: V2YouOverview) -> some View {
        let user = data.user
        let bio = appState.currentUser?.bio
        let username = appState.currentUser?.username

        VStack(alignment: .leading, spacing: 10) {
            // Avatar + name + settings gear
            Button {
                Haptics.selection()
                showEditProfile = true
            } label: {
                HStack(spacing: 14) {
                    avatar(user: user)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        if let username, !username.isEmpty {
                            Text("@\(username)")
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textTertiary)
                        } else {
                            Text("Edit profile")
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    Spacer()
                    NavigationLink {
                        SettingsView()
                            .environment(appState)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)

            if let bio, !bio.isEmpty {
                Text(bio)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }

            // Followers / following row (B2C only)
            if !isPlacement {
                HStack(spacing: 0) {
                    Button {
                        Haptics.selection()
                        followListMode = .followers
                        showFollowList = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(appState.currentUser?.followersCount ?? 0)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("followers")
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(" · ")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Button {
                        Haptics.selection()
                        followListMode = .following
                        showFollowList = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(appState.currentUser?.followingCount ?? 0)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("following")
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func avatar(user: V2YouOverview.UserBlock) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [ColorTokens.surfaceElevated, ColorTokens.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
            if let urlStr = user.avatarURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(user.initial)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Text(user.initial)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ColorTokens.gold)
            }
        }
    }

    // MARK: - Readiness ring & stats

    private func readinessRing(readiness: V2YouOverview.ReadinessBlock) -> some View {
        // The whole ring is the tap target for the breakdown sheet ("what's in
        // your number" + "why this target"). The inline Target line surfaces the
        // personalized P2 target without opening the sheet.
        Button {
            showReadinessBreakdown = true
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(ColorTokens.surfaceElevated, lineWidth: 9)
                        .frame(width: 130, height: 130)
                    Circle()
                        .trim(from: 0, to: CGFloat(readiness.score) / 100.0)
                        .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 130, height: 130)
                    VStack(spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(readiness.score)").font(.system(size: 32, weight: .bold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("%").font(.system(size: 18, weight: .bold)).foregroundStyle(ColorTokens.textSecondary)
                        }
                        Text("READINESS")
                            .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                Text(readiness.onTrackText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(readiness.weeksOverdue != nil ? ColorTokens.warning : ColorTokens.gold)

                if let weeks = readiness.weeksRemaining, weeks > 0 {
                    Text("\(weeks) week\(weeks == 1 ? "" : "s") remaining")
                        .font(.system(size: 11)).foregroundStyle(ColorTokens.textTertiary)
                } else if let overdue = readiness.weeksOverdue, overdue > 0 {
                    Text("\(overdue) week\(overdue == 1 ? "" : "s") past deadline")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.warning)
                }

                HStack(spacing: 6) {
                    if let target = readiness.target {
                        Text("Target \(target)%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text("·").font(.system(size: 11)).foregroundStyle(ColorTokens.textTertiary)
                    }
                    Text("What's in your number")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statsBlock(data: V2YouOverview) -> some View {
        VStack(spacing: 0) {
            if let wp = data.weekProgress {
                statRow(label: "This week", value: "\(wp.done) of \(wp.total) done", accent: true)
                rowDivider
            }
            statRow(label: "Streak", value: streakLabel(data.streak.current))
            if let gap = data.topGap {
                rowDivider
                statRow(label: "Top gap", value: gap.topic, trailing: "→ \(gap.ctaLabel)")
            }
            rowDivider
            statRow(label: "Time invested", value: "\(data.timeInvested.hours) hour\(data.timeInvested.hours == 1 ? "" : "s")")
        }
    }

    private func streakLabel(_ n: Int) -> String {
        switch n {
        case 0: return "Start one today"
        case 1: return "1 day"
        default: return "\(n) days"
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
    }

    private var sectionDivider: some View {
        Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 10, weight: .semibold)).tracking(0.8)
            .foregroundStyle(ColorTokens.textTertiary)
            .padding(.bottom, 8)
    }

    private func statRow(label: String, value: String, accent: Bool = false, trailing: String? = nil) -> some View {
        HStack {
            Text(label).font(V2Theme.body).foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent ? ColorTokens.gold : ColorTokens.textPrimary)
                if let t = trailing {
                    Text(t).font(.system(size: 12)).foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - My Library chip strip

    private var libraryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                libraryChip(.saved)
                libraryChip(.liked)
                libraryChip(.playlists)
                libraryChip(.history)
            }
        }
    }

    private func libraryChip(_ tab: V2YouLibraryTab) -> some View {
        Button {
            Haptics.selection()
            librarySheet = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon).font(.system(size: 12))
                Text(tab.title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(ColorTokens.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(V2Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - My Learning rows

    @ViewBuilder
    private func learningRows(weekProgress: V2YouOverview.WeekProgressBlock?) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                V2YouObjectivesView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                row(icon: "target", label: "My objectives")
            }
            .buttonStyle(.plain)

            NavigationLink {
                V2PlanDetailView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                if let wp = weekProgress {
                    row(icon: "calendar", label: "My plan", meta: "Week \(wp.week)")
                } else {
                    row(icon: "calendar", label: "My plan")
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                V2YouAnalyticsView()
                    .environment(appState)
            } label: {
                row(icon: "chart.line.uptrend.xyaxis", label: "Progress & analytics")
            }
            .buttonStyle(.plain)

            NavigationLink {
                MyNotesView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                row(icon: "note.text", label: "My notes & flashcards")
            }
            .buttonStyle(.plain)

            NavigationLink {
                InterviewHistoryView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                row(icon: "waveform.badge.mic", label: "Mock interviews & analytics")
            }
            .buttonStyle(.plain)

            // One unified coding entry — drills, capstones, and progress live
            // together in the hub (replaces the old split "drills & practice"
            // and "capstones & history" rows that confused learners).
            NavigationLink {
                V2CodingHubView(onClose: {}, showsCloseButton: false)
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                row(icon: "chevron.left.forwardslash.chevron.right", label: "Coding")
            }
            .buttonStyle(.plain)

            NavigationLink {
                CompetitionHubView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                row(icon: "trophy.fill", label: "Daily challenges & competition")
            }
            .buttonStyle(.plain)

            NavigationLink {
                V2CompassHistoryView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                row(icon: "safari", label: "My Compass activity")
            }
            .buttonStyle(.plain)

            NavigationLink {
                V2ActivitiesDetailView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                row(icon: "square.grid.2x2.fill", label: "All my activities")
            }
            .buttonStyle(.plain)
        }
    }

    private func row(icon: String, label: String, meta: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 32, height: 32)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(label).font(V2Theme.bodyMedium).foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            if let meta {
                Text(meta).font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Inference panel

    private var inferencePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.selection()
                withAnimation(.easeInOut(duration: 0.2)) { inferencesExpanded.toggle() }
            } label: {
                HStack {
                    sectionLabel("How we're personalising for you")
                    Spacer()
                    Image(systemName: inferencesExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if inferencesExpanded {
                VStack(spacing: 10) {
                    ForEach(inferences) { inf in
                        inferenceRow(inf)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inferenceRow(_ inference: UserInference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.gold)
                Text(inference.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer(minLength: 0)
            }
            Text(inference.description)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    resolveInference(inference, status: .confirmed)
                } label: {
                    Label("Sounds right", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(ColorTokens.success.opacity(0.18))
                        .foregroundStyle(ColorTokens.success)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    resolveInference(inference, status: .dismissed)
                } label: {
                    Label("Not really", systemImage: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(ColorTokens.surfaceElevated)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func loadInferences() async {
        if let list = try? await inferenceService.list() {
            self.inferences = list
        }
    }

    private func resolveInference(_ inference: UserInference, status: UserInference.InferenceStatus) {
        Haptics.selection()
        inferences.removeAll { $0.key == inference.key }
        Task { _ = try? await inferenceService.resolve(key: inference.key, status: status) }
    }

    // MARK: - Creator Hub

    private var creatorHubSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Creator hub")
            VStack(spacing: 0) {
                creatorTierHeader
                if let stats = vm.creatorStats?.stats {
                    creatorStatsStrip(stats)
                }
                creatorActions
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(V2Theme.cardBorder, lineWidth: 1)
            )
        }
    }

    private var creatorTierHeader: some View {
        let tier = vm.creatorStats?.tier
        let tierColor = tier?.color ?? ColorTokens.gold
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(tierColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: tier?.icon ?? "star.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tierColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(tier?.displayName ?? "Creator") Creator")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                if let domain = vm.creatorStats?.domain {
                    Text(domain).font(.system(size: 12, weight: .medium)).foregroundStyle(tierColor)
                }
            }
            Spacer()
            if vm.creatorStats?.isVerified == true {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(tierColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [tierColor.opacity(0.12), ColorTokens.surface],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private func creatorStatsStrip(_ stats: CreatorStats) -> some View {
        HStack(spacing: 0) {
            creatorStat(value: formatStat(stats.totalContent ?? 0), label: "Content")
            sDivider
            creatorStat(value: formatStat(stats.totalViews ?? 0), label: "Views")
            sDivider
            creatorStat(value: formatStat(stats.totalFollowers ?? 0), label: "Followers")
            sDivider
            creatorStat(value: String(format: "%.1f", stats.averageRating ?? 0), label: "Rating")
        }
        .padding(.vertical, 12)
        .background(ColorTokens.surface)
        .overlay(alignment: .top) { rowDivider }
        .overlay(alignment: .bottom) { rowDivider }
    }

    private var sDivider: some View {
        Rectangle().fill(V2Theme.cardBorder).frame(width: 1, height: 28)
    }

    private func creatorStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label).font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .textCase(.uppercase).tracking(0.4)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatStat(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private var creatorActions: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.light()
                showCreateContent = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(ColorTokens.gold).frame(width: 30, height: 30)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    Text("Create Content")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            rowDivider

            NavigationLink {
                MyContentView()
                    .environment(appState)
                    .environment(objectiveContext)
            } label: {
                creatorActionRow(icon: "rectangle.stack.fill", title: "My Content")
            }
            .buttonStyle(.plain)

            if let tier = vm.creatorStats?.tier, (tier == .core || tier == .anchor) {
                rowDivider
                NavigationLink {
                    PendingApplicationsView()
                        .environment(appState)
                } label: {
                    creatorActionRow(icon: "person.badge.clock", title: "Review Applications")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func creatorActionRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 30, height: 30)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Admin Tools

    private var adminToolsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Admin tools")
            VStack(spacing: 0) {
                NavigationLink {
                    AdminDashboardView().environment(appState)
                } label: {
                    creatorActionRow(icon: "shield.fill", title: "Dashboard")
                }
                .buttonStyle(.plain)
                rowDivider
                NavigationLink {
                    UserManagementView().environment(appState)
                } label: {
                    creatorActionRow(icon: "person.2.fill", title: "User Management")
                }
                .buttonStyle(.plain)
                rowDivider
                NavigationLink {
                    CreatorPromotionView().environment(appState)
                } label: {
                    creatorActionRow(icon: "arrow.up.circle.fill", title: "Creator Promotions")
                }
                .buttonStyle(.plain)
                rowDivider
                NavigationLink {
                    ContentModerationView().environment(appState)
                } label: {
                    creatorActionRow(icon: "doc.badge.gearshape.fill", title: "Content Moderation")
                }
                .buttonStyle(.plain)
                rowDivider
                NavigationLink {
                    PendingApplicationsView(isAdmin: true).environment(appState)
                } label: {
                    creatorActionRow(icon: "person.badge.clock", title: "Creator Applications")
                }
                .buttonStyle(.plain)
                rowDivider
                NavigationLink {
                    PendingNotesReviewView().environment(appState)
                } label: {
                    creatorActionRow(icon: "doc.badge.clock.fill", title: "Review Notes")
                }
                .buttonStyle(.plain)
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(V2Theme.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Become creator / application status

    private var becomeCreatorCard: some View {
        Button {
            Haptics.selection()
            showCreatorApp = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Become a Creator")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                    Text("Apply to share content with other learners.")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(ColorTokens.gold.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1, antialiased: true)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func applicationStatusCard(status: String) -> some View {
        let (label, color, icon): (String, Color, String) = {
            switch status {
            case "pending":  return ("Application under review", ColorTokens.warning, "hourglass")
            case "rejected": return ("Application not accepted", ColorTokens.error, "xmark.circle.fill")
            default:         return ("Application status", ColorTokens.gold, "info.circle.fill")
            }
        }()
        return Button {
            Haptics.selection()
            showCreatorApp = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Creator Application")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(label)
                        .font(V2Theme.small)
                        .foregroundStyle(color)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1, antialiased: true)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Open to opportunities (Hire from ScaleUp)

    /// Self-gated You-tab entry into the candidate hiring flow. Shows opted-in
    /// state and a pending-employer-interest badge; taps open the Open-to-work
    /// screen (which itself links into the connection inbox). Passes the shared
    /// `hiringVM` so opt-in state + the badge stay in sync after edits.
    /// Names the readiness band from the score + band thresholds, so the
    /// Open-to-work value banner can show it before the user has opted in.
    private func hiringBandName(_ r: V2YouOverview.ReadinessBlock?) -> String? {
        guard let r, let b = r.targetBands else { return nil }
        if r.score >= b.exceptional { return "Exceptional" }
        if r.score >= b.strong { return "Strong" }
        if r.score >= b.competitive { return "Competitive" }
        return nil
    }

    private var openToOpportunitiesRow: some View {
        NavigationLink {
            V2OpenToWorkView(
                viewModel: hiringVM,
                seedScore: vm.data?.readiness.score,
                seedBand: hiringBandName(vm.data?.readiness)
            )
                .environment(appState)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "briefcase")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 32, height: 32)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open to opportunities")
                        .font(V2Theme.bodyMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(hiringVM.optedIn ? "Discoverable to vetted employers" : "Let employers discover your readiness")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                if hiringVM.pendingCount > 0 {
                    Text("\(hiringVM.pendingCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.buttonPrimaryText)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(ColorTokens.gold)
                        .clipShape(Capsule())
                } else if hiringVM.optedIn {
                    Text("ON")
                        .font(.system(size: 10, weight: .bold)).tracking(0.5)
                        .foregroundStyle(ColorTokens.success)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(ColorTokens.success.opacity(0.15))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadHiring() async {
        await hiringVM.load()
        // If the feature is live, also pull connections so the pending badge is
        // accurate on first paint (a 404 already short-circuited `available`).
        if hiringVM.available == true {
            await hiringVM.loadConnections()
        }
    }

    // MARK: - Settings + footer

    private var settingsRow: some View {
        NavigationLink {
            SettingsView()
                .environment(appState)
        } label: {
            row(icon: "gearshape", label: "Settings")
        }
        .buttonStyle(.plain)
    }

    private var footerView: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let memberSince: String = {
            guard let date = appState.currentUser?.createdAt else { return "" }
            let f = DateFormatter()
            f.dateFormat = "MMM yyyy"
            return f.string(from: date)
        }()
        let suffix = memberSince.isEmpty ? "" : " · Member since \(memberSince)"
        return Text("ScaleUp · v\(version)\(suffix)")
            .font(.system(size: 11))
            .foregroundStyle(ColorTokens.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Loading / Error states

    private var loadingState: some View {
        VStack(spacing: 18) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading your overview…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.warning)
            Text(vm.error ?? "Couldn't load your overview.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await vm.load() } }
                .buttonStyle(.bordered)
                .tint(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 24)
    }
}

#Preview { V2YouView().preferredColorScheme(.dark) }
