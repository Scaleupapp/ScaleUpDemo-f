import SwiftUI

struct QuizListView: View {
    @State private var viewModel = QuizListViewModel()
    @State private var showGenerateSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Tab switcher
                tabSwitcher
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                if viewModel.isLoading {
                    loadingState
                } else {
                    switch viewModel.selectedTab {
                    case .available:
                        availableTab
                    case .completed:
                        completedTab
                    }
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Quiz.self) { quiz in
            QuizDetailView(quiz: quiz)
        }
        .navigationDestination(for: QuizAttempt.self) { attempt in
            if let quizInfo = attempt.quizId {
                QuizResultsView(quizId: quizInfo.id, attempt: attempt)
            }
        }
        .sheet(isPresented: $showGenerateSheet) {
            generateQuizSheet
        }
        .onChange(of: viewModel.generatedQuizId) { _, newId in
            guard newId != nil else { return }
            showGenerateSheet = false
        }
        .task {
            await viewModel.loadQuizzes()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Quizzes")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(viewModel.availableQuizzes.count) available")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            Button { showGenerateSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                    Text("Generate")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(ColorTokens.gold)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(QuizListTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .semibold))

                        if tab == .available && !viewModel.availableQuizzes.isEmpty {
                            Text("\(viewModel.availableQuizzes.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(viewModel.selectedTab == tab ? .black : ColorTokens.gold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(viewModel.selectedTab == tab ? .black.opacity(0.2) : ColorTokens.gold.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(viewModel.selectedTab == tab ? .black : ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(viewModel.selectedTab == tab ? ColorTokens.gold : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Available Tab

    private var availableTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Spacing.md) {
                // Skill Assessments
                if !viewModel.pendingAssessments.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.purple)
                            Text("SKILL ASSESSMENTS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(.purple)
                        }
                        Text("Based on your objective analysis")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)

                        ForEach(viewModel.pendingAssessments) { quiz in
                            NavigationLink(value: quiz) {
                                quizCard(quiz, accentColor: .purple)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // In Progress
                if !viewModel.liveQuizzes.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        sectionLabel("IN PROGRESS", color: .blue)
                        ForEach(viewModel.liveQuizzes) { quiz in
                            NavigationLink(value: quiz) {
                                quizCard(quiz, accentColor: .blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Pending
                if !viewModel.pendingQuizzes.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        sectionLabel("READY TO TAKE", color: ColorTokens.gold)
                        ForEach(viewModel.pendingQuizzes) { quiz in
                            NavigationLink(value: quiz) {
                                quizCard(quiz, accentColor: ColorTokens.gold)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Empty state
                if viewModel.availableQuizzes.isEmpty && viewModel.pendingAssessments.isEmpty {
                    emptyState(
                        icon: "brain.head.profile",
                        title: "No quizzes available",
                        subtitle: "Keep learning and quizzes will appear automatically, or generate one now!"
                    )
                }

                Spacer().frame(height: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .refreshable {
            await viewModel.loadQuizzes()
        }
    }

    // MARK: - Completed Tab

    private var completedTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Spacing.md) {
                if viewModel.completedAttempts.isEmpty {
                    emptyState(
                        icon: "checkmark.circle",
                        title: "No completed quizzes",
                        subtitle: "Take a quiz and your results will appear here"
                    )
                } else {
                    ForEach(viewModel.completedAttempts) { attempt in
                        NavigationLink(value: attempt) {
                            completedCard(attempt)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .refreshable {
            await viewModel.loadQuizzes()
        }
    }

    // MARK: - Quiz Card

    private func quizCard(_ quiz: Quiz, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                // Type badge
                HStack(spacing: 4) {
                    Image(systemName: quiz.type.icon)
                        .font(.system(size: 9))
                    Text(quiz.type.displayName)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.15))
                .clipShape(Capsule())

                Spacer()

                // Expiry
                if let expiryText = quiz.expiresInText {
                    Text(expiryText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Text(quiz.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(quiz.topic.capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

            // Stats row
            HStack(spacing: Spacing.md) {
                Label("\(quiz.totalQuestions) questions", systemImage: "list.bullet")
                Label("~\(quiz.estimatedMinutes) min", systemImage: "clock")

                let dist = quiz.difficultyDistribution
                if dist.hard > 0 {
                    Label("\(dist.hard) hard", systemImage: "flame")
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(ColorTokens.textTertiary)

            // CTA
            HStack {
                Spacer()
                Text(quiz.status == .inProgress ? "Continue" : "Start Quiz")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Completed Card

    private func completedCard(_ attempt: QuizAttempt) -> some View {
        HStack(spacing: Spacing.md) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(ColorTokens.border, lineWidth: 3)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: (attempt.score?.percentage ?? 0) / 100)
                    .stroke(scoreColor(for: attempt.score?.percentage ?? 0), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(attempt.score?.percentage ?? 0))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(for: attempt.score?.percentage ?? 0))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(attempt.quizId?.title ?? "Quiz")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(attempt.quizId?.topic?.capitalized ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)

                HStack(spacing: 8) {
                    if let score = attempt.score {
                        Text("\(score.correct)/\(score.total) correct")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }

                    if let trend = attempt.analysis?.comparisonToPrevious?.trend {
                        HStack(spacing: 2) {
                            Image(systemName: trend == "improving" ? "arrow.up.right" : trend == "declining" ? "arrow.down.right" : "minus")
                                .font(.system(size: 9))
                            Text(trend.capitalized)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(
                            trend == "improving" ? .green :
                            trend == "declining" ? .red : .orange
                        )
                    }
                }

                if let date = attempt.completedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Generate Quiz Sheet

    private var generateQuizSheet: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Header
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 36))
                                .foregroundStyle(ColorTokens.gold)

                            Text("Generate a Quiz")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)

                            Text("AI will create a personalized quiz based on your learning")
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.lg)

                        // Topic
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TOPIC")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(ColorTokens.textTertiary)

                            TextField("e.g., product management, SEO, data science", text: $viewModel.generationTopic)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .tint(ColorTokens.gold)
                                .padding(12)
                                .background(ColorTokens.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            // Topic suggestions from objective
                            if let obj = viewModel.userObjective {
                                let suggestions = [obj.targetRole, obj.targetSkill].compactMap { $0 }
                                if !suggestions.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(suggestions, id: \.self) { suggestion in
                                                Button {
                                                    viewModel.generationTopic = suggestion
                                                } label: {
                                                    Text(suggestion)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(ColorTokens.gold)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(ColorTokens.gold.opacity(0.12))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Question Count
                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUESTIONS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(ColorTokens.textTertiary)

                            HStack(spacing: 8) {
                                ForEach([5, 10, 15, 20], id: \.self) { count in
                                    Button {
                                        viewModel.selectedQuestionCount = count
                                    } label: {
                                        Text("\(count)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(viewModel.selectedQuestionCount == count ? .black : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(viewModel.selectedQuestionCount == count ? ColorTokens.gold : ColorTokens.surfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Assessment Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ASSESSMENT TYPE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(ColorTokens.textTertiary)

                            VStack(spacing: 6) {
                                ForEach(AssessmentType.allCases, id: \.self) { type in
                                    assessmentTypeRow(type)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Objective Link
                        if let obj = viewModel.userObjective {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LINKED OBJECTIVE")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(ColorTokens.textTertiary)

                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(obj.targetRole ?? obj.targetSkill ?? "Your Objective")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text("Competency-aware quiz generation")
                                            .font(.system(size: 11))
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $viewModel.linkToObjective)
                                        .labelsHidden()
                                        .tint(ColorTokens.gold)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(ColorTokens.surfaceElevated)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.linkToObjective ? ColorTokens.gold.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                            .padding(.horizontal, Spacing.lg)
                        }

                        // Generate Button / Loading / Result
                        if viewModel.isGenerating {
                            VStack(spacing: Spacing.sm) {
                                ProgressView()
                                    .tint(ColorTokens.gold)
                                Text(viewModel.generationStatus ?? "Generating...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            .padding(.top, Spacing.sm)
                        } else if viewModel.generatedQuizId != nil {
                            // Success — sheet will dismiss via onChange
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.green)
                                Text("Quiz Ready!")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, Spacing.sm)
                        } else {
                            VStack(spacing: Spacing.sm) {
                                if viewModel.generationFailed {
                                    Text(viewModel.generationStatus ?? "Generation failed")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.red)
                                }

                                Button {
                                    viewModel.generationFailed = false
                                    let topic = viewModel.generationTopic.trimmingCharacters(in: .whitespaces)
                                    guard !topic.isEmpty else { return }
                                    Task { await viewModel.requestQuiz(topic: topic) }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 14))
                                        Text(viewModel.generationFailed ? "Retry" : "Generate Quiz")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        viewModel.generationTopic.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? ColorTokens.gold.opacity(0.3)
                                        : ColorTokens.gold
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(viewModel.generationTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                                .padding(.horizontal, Spacing.lg)
                            }
                        }

                        Spacer().frame(height: Spacing.xl)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showGenerateSheet = false }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.loadUserObjective()
        }
        .onDisappear {
            viewModel.resetGenerationState()
        }
    }

    // MARK: - Assessment Type Row

    private func assessmentTypeRow(_ type: AssessmentType) -> some View {
        let isSelected = viewModel.selectedAssessmentType == type
        return Button {
            viewModel.selectedAssessmentType = type
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? ColorTokens.gold : ColorTokens.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(type.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(type.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? ColorTokens.gold.opacity(0.08) : ColorTokens.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? ColorTokens.gold.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(color)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ColorTokens.textSecondary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func scoreColor(for percentage: Double) -> Color {
        if percentage >= 80 { return ColorTokens.gold }
        if percentage >= 60 { return .orange }
        return .red
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonLoader(height: 120)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 120)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 120)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .padding(.top, Spacing.md)
    }
}
