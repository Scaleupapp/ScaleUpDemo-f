import SwiftUI

// MARK: - Quiz List View

struct QuizListView: View {
    @Environment(DependencyContainer.self) private var dependencies

    /// When true, skips the internal NavigationStack (use when pushed from another NavigationStack).
    var embedded: Bool = false

    @State private var viewModel: QuizListViewModel?
    @State private var showRequestSheet = false

    var body: some View {
        Group {
            if embedded {
                innerContent
            } else {
                NavigationStack {
                    innerContent
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = QuizListViewModel(quizService: dependencies.quizService)
            }
        }
        .task {
            if let viewModel, viewModel.isEmpty {
                await viewModel.loadQuizzes()
            }
        }
    }

    // MARK: - Inner Content

    private var innerContent: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.isEmpty {
                    quizListSkeleton
                } else if let error = viewModel.error, viewModel.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadQuizzes() }
                        }
                    )
                } else if viewModel.isEmpty {
                    EmptyStateView(
                        icon: "brain.head.profile",
                        title: "No Quizzes Yet",
                        subtitle: "Keep learning! Quizzes appear after consuming content.",
                        buttonTitle: "Request a Quiz",
                        action: { showRequestSheet = true }
                    )
                } else {
                    quizListContent(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Quizzes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRequestSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ColorTokens.primary)
                }
            }
        }
        .sheet(isPresented: $showRequestSheet, onDismiss: {
            // Auto-refresh when the request sheet is dismissed
            if let viewModel {
                Task { await viewModel.refresh() }
            }
        }) {
            RequestQuizView()
                .environment(dependencies)
        }
    }

    // MARK: - Quiz List Content

    @ViewBuilder
    private func quizListContent(viewModel: QuizListViewModel) -> some View {
        VStack(spacing: 0) {
            // Tab bar
            quizTabBar(viewModel: viewModel)
                .padding(.top, Spacing.sm)

            // Tab content
            TabView(selection: Bindable(viewModel).selectedTab) {
                quizTabContent(
                    quizzes: viewModel.inProgressQuizzes,
                    style: .inProgress,
                    emptyIcon: "flame",
                    emptyTitle: "No Active Quizzes",
                    emptySubtitle: "Start a quiz from the Available tab to see it here."
                )
                .tag(QuizTab.active)

                quizTabContent(
                    quizzes: viewModel.availableQuizzes,
                    style: .available,
                    emptyIcon: "sparkles",
                    emptyTitle: "No Quizzes Available",
                    emptySubtitle: "Request a new quiz or check back later."
                )
                .tag(QuizTab.available)

                quizTabContent(
                    quizzes: viewModel.completedQuizzes,
                    style: .completed,
                    emptyIcon: "trophy",
                    emptyTitle: "No Completed Quizzes",
                    emptySubtitle: "Complete a quiz to see your results here."
                )
                .tag(QuizTab.completed)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(Animations.standard, value: viewModel.selectedTab)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Tab Bar

    private func quizTabBar(viewModel: QuizListViewModel) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(QuizTab.allCases, id: \.self) { tab in
                let isSelected = viewModel.selectedTab == tab
                let count = viewModel.count(for: tab)

                Button {
                    withAnimation(Animations.quick) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: tabIcon(for: tab))
                            .font(.system(size: 12, weight: .semibold))

                        Text(tab.rawValue)
                            .font(Typography.bodySmall)

                        if count > 0 {
                            Text("\(count)")
                                .font(Typography.micro)
                                .foregroundStyle(isSelected ? ColorTokens.backgroundDark : tabColor(for: tab))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    isSelected
                                        ? AnyShapeStyle(Color.white.opacity(0.9))
                                        : AnyShapeStyle(tabColor(for: tab).opacity(0.15))
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(isSelected ? .white : ColorTokens.textSecondaryDark)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm + 2)
                    .background(
                        isSelected
                            ? tabColor(for: tab)
                            : Color.clear
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.clear : ColorTokens.surfaceElevatedDark,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private func tabIcon(for tab: QuizTab) -> String {
        switch tab {
        case .active: return "flame.fill"
        case .available: return "sparkles"
        case .completed: return "trophy.fill"
        }
    }

    private func tabColor(for tab: QuizTab) -> Color {
        switch tab {
        case .active: return ColorTokens.warning
        case .available: return ColorTokens.primary
        case .completed: return ColorTokens.success
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func quizTabContent(
        quizzes: [Quiz],
        style: QuizCardView.CardStyle,
        emptyIcon: String,
        emptyTitle: String,
        emptySubtitle: String
    ) -> some View {
        if quizzes.isEmpty {
            VStack(spacing: Spacing.lg) {
                Spacer()

                Image(systemName: emptyIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                VStack(spacing: Spacing.xs) {
                    Text(emptyTitle)
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textSecondaryDark)

                    Text(emptySubtitle)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()
            }
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(quizzes) { quiz in
                        NavigationLink {
                            if style == .completed {
                                QuizResultsView(quizId: quiz.id)
                                    .environment(dependencies)
                            } else {
                                QuizDetailView(quiz: quiz)
                                    .environment(dependencies)
                            }
                        } label: {
                            QuizCardView(quiz: quiz, style: style)
                        }
                        .buttonStyle(.plain)
                    }

                    // Bottom spacing for tab bar
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    // MARK: - Skeleton

    private var quizListSkeleton: some View {
        VStack(spacing: 0) {
            // Skeleton tab bar
            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonLoader(width: 100, height: 36, cornerRadius: CornerRadius.full)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonLoader(height: 140, cornerRadius: CornerRadius.medium)
                            .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
        }
    }
}

// MARK: - Quiz Card View

struct QuizCardView: View {
    let quiz: Quiz
    let style: CardStyle

    enum CardStyle {
        case inProgress
        case available
        case completed
    }

    private var isInProgress: Bool { style == .inProgress }
    private var isCompleted: Bool { style == .completed }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top color accent bar
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [quizTypeColor, quizTypeColor.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)

            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header row
                HStack(spacing: Spacing.sm) {
                    // Quiz type icon
                    Image(systemName: quizTypeIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(quizTypeColor)
                        .frame(width: 40, height: 40)
                        .background(quizTypeColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(quiz.topic)
                            .font(Typography.titleMedium)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .lineLimit(1)

                        Text(quizTypeLabel)
                            .font(Typography.caption)
                            .foregroundStyle(quizTypeColor)
                    }

                    Spacer()

                    // Status badge
                    if isInProgress {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ColorTokens.warning)
                                .frame(width: 6, height: 6)
                            Text("Resume")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.warning)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(ColorTokens.warning.opacity(0.12))
                        .clipShape(Capsule())
                    } else if isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Done")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(ColorTokens.success)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(ColorTokens.success.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                // Details row with chips
                HStack(spacing: Spacing.sm) {
                    detailChip(
                        icon: "list.bullet",
                        text: "\(quiz.totalQuestions) Qs"
                    )

                    if let timeLimit = quiz.timeLimit {
                        detailChip(
                            icon: "clock",
                            text: "\(timeLimit / 60) min"
                        )
                    }

                    if let tpq = quiz.timePerQuestion {
                        detailChip(
                            icon: "timer",
                            text: "\(tpq)s/Q"
                        )
                    }

                    Spacer()
                }

                // Expiry info
                if let expiresAt = quiz.expiresAt {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.warning)

                        Text("Expires \(formatExpiryDate(expiresAt))")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.warning)
                    }
                }

                // CTA row
                HStack {
                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        Text(isCompleted ? "View Results" : isInProgress ? "Continue" : "Start Quiz")
                            .font(Typography.bodyBold)
                            .foregroundStyle(isCompleted ? ColorTokens.success : isInProgress ? ColorTokens.warning : ColorTokens.primary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isCompleted ? ColorTokens.success : isInProgress ? ColorTokens.warning : ColorTokens.primary)
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isInProgress ? ColorTokens.warning.opacity(0.25)
                        : isCompleted ? ColorTokens.success.opacity(0.2)
                        : ColorTokens.surfaceElevatedDark,
                    lineWidth: 1
                )
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Detail Chip

    private func detailChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(Typography.caption)
        }
        .foregroundStyle(ColorTokens.textSecondaryDark)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(ColorTokens.surfaceElevatedDark)
        .clipShape(Capsule())
    }

    // MARK: - Quiz Type Helpers

    private var quizTypeIcon: String {
        switch quiz.type {
        case .topicConsolidation: return "books.vertical"
        case .weeklyReview: return "calendar.badge.clock"
        case .milestoneAssessment: return "flag.checkered"
        case .retentionCheck: return "brain"
        case .onDemand: return "sparkles"
        case .playlistMastery: return "music.note.list"
        }
    }

    private var quizTypeColor: Color {
        switch quiz.type {
        case .topicConsolidation: return ColorTokens.primary
        case .weeklyReview: return ColorTokens.info
        case .milestoneAssessment: return ColorTokens.anchorGold
        case .retentionCheck: return ColorTokens.warning
        case .onDemand: return ColorTokens.success
        case .playlistMastery: return ColorTokens.primaryLight
        }
    }

    private var quizTypeLabel: String {
        switch quiz.type {
        case .topicConsolidation: return "Topic Consolidation"
        case .weeklyReview: return "Weekly Review"
        case .milestoneAssessment: return "Milestone Assessment"
        case .retentionCheck: return "Retention Check"
        case .onDemand: return "On Demand"
        case .playlistMastery: return "Playlist Mastery"
        }
    }

    private func formatExpiryDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now)
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now)
    }
}
