import SwiftUI

struct SeeAllDestination: Hashable {
    let title: String
    let items: [Content]
}

struct QuizListDestination: Hashable {}

struct NotificationDestination: Hashable {}

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(ObjectiveContext.self) private var objectiveContext
    @State private var viewModel = HomeViewModel()
    @State private var quizViewModel = QuizListViewModel()
    @State private var notificationVM = NotificationViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.dashboard == nil && viewModel.recommendations.isEmpty {
                    loadingState
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Content.self) { content in
                PlayerView(contentId: content.id)
            }
            .navigationDestination(for: SeeAllDestination.self) { destination in
                SeeAllContentView(title: destination.title, items: destination.items)
                    .navigationDestination(for: Content.self) { content in
                        PlayerView(contentId: content.id)
                    }
            }
            .navigationDestination(for: QuizListDestination.self) { _ in
                QuizListView()
            }
            .navigationDestination(for: Quiz.self) { quiz in
                QuizDetailView(quiz: quiz)
            }
            .navigationDestination(for: NotificationDestination.self) { _ in
                NotificationListView()
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
        .task {
            await viewModel.loadDashboard(objectiveId: objectiveContext.activeObjectiveId)
            objectiveContext.updateFromDashboard(viewModel.dashboard?.objectives)
            await quizViewModel.loadQuizzes()
            await notificationVM.refreshUnreadCount()
        }
        .onChange(of: objectiveContext.activeObjective?.id) { oldId, newId in
            guard newId != oldId, newId != nil else { return }
            Task {
                await viewModel.loadDashboard(objectiveId: objectiveContext.activeObjectiveId)
                objectiveContext.updateFromDashboard(viewModel.dashboard?.objectives)
            }
        }
        .coachMark(
            .tabHome,
            icon: "house.fill",
            title: "Your Dashboard",
            message: "Your readiness score, recommendations, and next actions update as you learn."
        )
    }

    // MARK: - Main Content

    private var myObjectiveChallenges: [DailyChallenge] {
        let obj = objectiveContext.activeObjective
        let role = obj?.targetRole?.lowercased() ?? ""
        let skill = obj?.targetSkill?.lowercased() ?? ""
        let objType = obj?.objectiveType?.lowercased() ?? ""

        return viewModel.todayChallenges.filter { challenge in
            let topic = challenge.topic.lowercased()
            // Exact match or contains-based fuzzy match
            return (!role.isEmpty && (topic == role || topic.contains(role) || role.contains(topic)))
                || (!skill.isEmpty && (topic == skill || topic.contains(skill) || skill.contains(topic)))
                || (!objType.isEmpty && (topic == objType || topic.contains(objType) || objType.contains(topic)))
        }
    }

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Compact header: greeting + score
                compactHeader
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)

                // Welcome card for new users
                if viewModel.isNewUser {
                    welcomeCard
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                }

                // Daily Challenge — compact card(s) for objective-matching challenges
                if !myObjectiveChallenges.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(myObjectiveChallenges) { challenge in
                            homeChallengeCard(challenge)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
                }

                // Next action (slim)
                if let action = viewModel.firstNextAction {
                    if action.type == "quiz" {
                        NavigationLink(value: QuizListDestination()) {
                            nextActionBanner(action)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                    } else {
                        Button {
                            appState.selectedTab = .journey
                        } label: {
                            nextActionBanner(action)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                    }
                }

                // Quiz section
                if !quizViewModel.availableQuizzes.isEmpty {
                    quizSection
                        .padding(.bottom, Spacing.sm)
                }

                // Content sections
                if hasAnyContent {
                    contentFeed
                        .padding(.top, Spacing.xs)
                } else if !viewModel.isLoading {
                    homeEmptyState
                        .padding(.top, Spacing.xl)
                }

                Spacer().frame(height: Spacing.xxxl)
            }
        }
        .refreshable {
            await viewModel.loadDashboard(objectiveId: objectiveContext.activeObjectiveId)
            objectiveContext.updateFromDashboard(viewModel.dashboard?.objectives)
        }
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        HStack(spacing: Spacing.sm) {
            // Greeting
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.greeting)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
                if let name = appState.currentUser?.firstName {
                    Text(name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            // Score badge — only when user has a score
            if viewModel.readinessScore > 0 {
                scoreBadge
            }

            // Notification bell
            NavigationLink(value: NotificationDestination()) {
                notificationBell
            }
            .buttonStyle(.plain)
        }
    }

    private var notificationBell: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 36, height: 36)

            if notificationVM.unreadCount > 0 {
                Text(notificationVM.unreadCount > 99 ? "99+" : "\(notificationVM.unreadCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -2)
            }
        }
    }

    private var scoreBadge: some View {
        VStack(spacing: 1) {
            Text("\(viewModel.readinessScore)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.gold)
            Text("Score")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(ColorTokens.gold.opacity(0.7))
        }
        .frame(width: 44, height: 44)
        .background(ColorTokens.gold.opacity(0.12))
        .clipShape(Circle())
    }

    // MARK: - Home Challenge Card (Compact)

    private func homeChallengeCard(_ challenge: DailyChallenge) -> some View {
        let isCompleted = challenge.isCompletedByUser
        let gold = Color(hex: 0xFFD700)
        let green = Color(hex: 0x22C55E)
        let streak = viewModel.competitionStats?.challengeStreak ?? 0

        return Group {
            if isCompleted {
                // Completed — single-line compact card
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(green)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(challenge.topic.capitalized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if let score = challenge.userScore {
                                Text("\(Int(score)) pts")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(gold)
                            }
                            if streak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                    Text("\(streak)d")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer()

                    NavigationLink(value: LeaderboardDestination()) {
                        Text("Results")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(green)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(green.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                // Active — compact action card
                NavigationLink(value: challenge) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(gold)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(challenge.topic.capitalized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text("\(challenge.participantCount) playing")
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Play")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(gold)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(gold.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Welcome Card (New Users)

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Start Your Learning Journey")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                welcomeBullet(icon: "safari.fill", text: "Browse Discover to find content you like")
                welcomeBullet(icon: "play.circle.fill", text: "Watch a video and try the AI Tutor")
                welcomeBullet(icon: "brain.head.profile", text: "Take quizzes to build your knowledge profile")
            }

            Button {
                Haptics.selection()
                appState.selectedTab = .discover
            } label: {
                HStack(spacing: 6) {
                    Text("Explore Content")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ColorTokens.goldGradient)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func welcomeBullet(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - Next Action Banner

    private func nextActionBanner(_ action: NextAction) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: action.type == "quiz" ? "brain.head.profile" : "play.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.gold)

            Text(action.message ?? "Continue your learning journey")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ColorTokens.gold)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(ColorTokens.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Content Feed

    private var contentFeed: some View {
        VStack(spacing: Spacing.lg) {
            // Continue Watching
            if !viewModel.continueWatching.isEmpty {
                sectionRow(title: "Continue Watching", icon: "play.circle.fill") {
                    continueWatchingCards
                }
            }

            // Hero content card
            if let hero = viewModel.heroContent {
                heroCard(hero)
                    .padding(.horizontal, Spacing.lg)
            }

            // Recommended For You
            if viewModel.recommendations.count > 1 {
                let recItems = Array(viewModel.recommendations.dropFirst())
                sectionRow(title: "Recommended For You", icon: "sparkles", items: recItems) {
                    horizontalContentScroll(items: recItems, width: 180)
                }
            }

            // Trending
            if !viewModel.trending.isEmpty {
                sectionRow(title: "Trending", icon: "flame.fill", items: viewModel.trending) {
                    horizontalContentScroll(items: viewModel.trending, width: 180)
                }
            }

            // All Content
            if !viewModel.allContent.isEmpty {
                sectionRow(title: "Explore", icon: "safari.fill", items: viewModel.allContent) {
                    horizontalContentScroll(items: viewModel.allContent, width: 180)
                }
            }
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ content: Content) -> some View {
        NavigationLink(value: content) {
            HStack(spacing: Spacing.sm) {
                Group {
                    if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                heroPlaceholder
                            }
                        }
                    } else {
                        heroPlaceholder
                    }
                }
                .frame(width: 150, height: 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    homeContentTypeBadge(content.contentType)
                        .padding(4)
                }
                .overlay(alignment: .bottomTrailing) {
                    if !content.formattedDuration.isEmpty {
                        Text(content.formattedDuration)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(4)
                    }
                }
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(radius: 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let domain = content.domain {
                            Text(domain.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }

                    Text(content.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let creator = content.creatorId {
                        HStack(spacing: 4) {
                            Text(creator.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .lineLimit(1)
                            if let tier = creator.tier {
                                TierBadge(tier: tier, compact: true)
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        if let views = content.viewCount, views > 0 {
                            Label(formatCount(views), systemImage: "eye")
                        }
                        if let rating = content.averageRating, rating > 0 {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.sm)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.gold.opacity(0.2), ColorTokens.surfaceElevated, ColorTokens.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Section Row

    private func sectionRow<V: View>(title: String, icon: String, items: [Content] = [], @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if !items.isEmpty {
                    NavigationLink(value: SeeAllDestination(title: title, items: items)) {
                        Text("See All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ColorTokens.gold)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            content()
        }
    }

    // MARK: - Content Cards

    private func horizontalContentScroll(items: [Content], width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        contentCard(item, width: width)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func contentCard(_ content: Content, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            thumbnailPlaceholder(for: content)
                        }
                    }
                } else {
                    thumbnailPlaceholder(for: content)
                }
            }
            .frame(width: width, height: width * 9 / 16)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                homeContentTypeBadge(content.contentType)
                    .padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                if !content.formattedDuration.isEmpty {
                    Text(content.formattedDuration)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(6)
                }
            }

            Text(content.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let creator = content.creatorId {
                HStack(spacing: 3) {
                    Text(creator.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                    if let tier = creator.tier {
                        TierBadge(tier: tier, compact: true)
                    }
                }
            }
        }
        .frame(width: width)
    }

    private func homeContentTypeBadge(_ type: ContentType) -> some View {
        HStack(spacing: 3) {
            Image(systemName: type.badgeIcon)
                .font(.system(size: 9, weight: .bold))
            Text(type.badgeLabel)
                .font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(type.badgeColor)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }

    private func thumbnailPlaceholder(for content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.surfaceElevated, ColorTokens.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 4) {
                Image(systemName: content.contentType == .video ? "play.fill" : "doc.text")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.gold.opacity(0.5))
                if let domain = content.domain {
                    Text(domain)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
    }

    // MARK: - Continue Watching

    private var continueWatchingCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(viewModel.continueWatching) { item in
                    if let content = item.content {
                        NavigationLink(value: content) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottom) {
                                    Group {
                                        if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                                            AsyncImage(url: imageURL) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                default:
                                                    thumbnailPlaceholder(for: content)
                                                }
                                            }
                                        } else {
                                            thumbnailPlaceholder(for: content)
                                        }
                                    }
                                    .frame(width: 220, height: 220 * 9 / 16)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack {
                                        Spacer()
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Rectangle().fill(Color.white.opacity(0.3))
                                                Rectangle().fill(ColorTokens.gold)
                                                    .frame(width: geo.size.width * item.progress)
                                            }
                                            .frame(height: 3)
                                        }
                                        .frame(height: 3)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Text(content.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Text("\(item.percentageCompleted ?? 0)% watched")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            .frame(width: 220)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonLoader(height: 50)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 36)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 120)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 180)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .padding(.top, Spacing.xl)
    }

    // MARK: - Empty State

    private var hasAnyContent: Bool {
        !viewModel.continueWatching.isEmpty ||
        !viewModel.recommendations.isEmpty ||
        !viewModel.trending.isEmpty ||
        !viewModel.allContent.isEmpty ||
        !quizViewModel.availableQuizzes.isEmpty
    }

    private var homeEmptyState: some View {
        EmptyStateView(
            icon: "books.vertical",
            title: "Your feed is empty",
            message: "Start exploring content to get personalized recommendations and track your progress.",
            actionLabel: "Explore Content",
            actionIcon: "safari.fill",
            action: { appState.selectedTab = .discover }
        )
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    // MARK: - Quiz Section

    private var quizSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
                Text("Quizzes")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink(value: QuizListDestination()) {
                    Text("See All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .padding(.horizontal, Spacing.lg)

            // Quiz cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(quizViewModel.availableQuizzes.prefix(4)) { quiz in
                        NavigationLink(value: quiz) {
                            homeQuizCard(quiz)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    private func homeQuizCard(_ quiz: Quiz) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type icon + badge
            HStack(spacing: 6) {
                Image(systemName: quiz.type.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)

                Text(quiz.type.displayName.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(ColorTokens.gold)

                Spacer()

                if quiz.status == .inProgress {
                    Text("IN PROGRESS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Trigger context
            Text(quizTriggerContext(quiz))
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(1)

            // Title
            Text(quiz.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            // Stats row
            HStack(spacing: 10) {
                Label("\(quiz.totalQuestions)Q", systemImage: "list.bullet")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                Label("\(quiz.estimatedMinutes)m", systemImage: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                Spacer()
            }

            // CTA
            Text("Take Quiz")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(ColorTokens.gold)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .padding(12)
        .frame(width: 190, height: 185)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func quizTriggerContext(_ quiz: Quiz) -> String {
        switch quiz.type {
        case .topicConsolidation:
            return "3+ lessons on \(quiz.topic) completed"
        case .weeklyReview:
            return "Weekly check on your progress"
        case .retentionCheck:
            return "Test what you remember"
        case .milestoneAssessment:
            return "Milestone reached in \(quiz.topic)"
        case .competencyAssessment:
            return "Skill assessment for \(quiz.topic)"
        case .appliedScenario:
            return "Apply \(quiz.topic) concepts"
        case .examSimulation:
            return "Practice exam for \(quiz.topic)"
        default:
            return "Based on your \(quiz.topic) learning"
        }
    }
}
