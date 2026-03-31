import SwiftUI

extension Notification.Name {
    static let dismissQuizSession = Notification.Name("dismissQuizSession")
    static let popToQuizList = Notification.Name("popToQuizList")
}

struct QuizSessionView: View {
    let quiz: Quiz
    @State private var viewModel = QuizSessionViewModel()
    @State private var showExitConfirm = false
    @State private var showQuestionPicker = false
    @State private var navigateToResults = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if viewModel.isStarting {
                    startingState
                } else if viewModel.hasCompleted {
                    completedTransition
                } else {
                    quizContent
                }
            }
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToResults) {
                QuizResultsView(
                    quizId: quiz.id,
                    attempt: viewModel.completedAttempt
                )
            }
        }
        .alert("Exit Quiz?", isPresented: $showExitConfirm) {
            Button("Continue Quiz", role: .cancel) {}
            Button("Exit", role: .destructive) {
                viewModel.cleanup()
                dismiss()
            }
        } message: {
            Text("Your progress will be saved. You can continue later.")
        }
        .sheet(isPresented: $showQuestionPicker) {
            questionNavigator
        }
        .task {
            await viewModel.startQuiz(quiz)
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissQuizSession)) { _ in
            dismiss()
        }
    }

    // MARK: - Main Quiz Content

    private var quizContent: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar

            // Progress bar
            progressBar

            // Timer
            timerDisplay

            // Question content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    questionCard

                    optionsList

                    // Optional text response
                    if viewModel.currentQuestionHasTextInput {
                        textResponseInput
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }

            // Bottom navigation
            bottomBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { showExitConfirm = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Circle())
            }

            Spacer()

            // Question counter
            Button { showQuestionPicker = true } label: {
                HStack(spacing: 4) {
                    Text("\(viewModel.currentIndex + 1)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.gold)
                    Text("/ \(viewModel.totalQuestions)")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ColorTokens.surfaceElevated)
                .clipShape(Capsule())
            }

            Spacer()

            // Answered count
            Text("\(viewModel.answeredCount) answered")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorTokens.surfaceElevated)

                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorTokens.gold)
                    .frame(width: geo.size.width * viewModel.progress)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Timer

    private var timerDisplay: some View {
        HStack(spacing: 8) {
            // Timer ring
            ZStack {
                Circle()
                    .stroke(ColorTokens.surfaceElevated, lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: viewModel.timeRemainingProgress)
                    .stroke(viewModel.timeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.timeRemaining)

                Text(viewModel.timeRemainingFormatted)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(viewModel.timeColor)
            }

            if viewModel.timeRemaining <= 10 {
                Text("Hurry up!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            Spacer()

            // Difficulty badge
            if let difficulty = viewModel.currentQuestion?.difficulty {
                HStack(spacing: 3) {
                    Circle()
                        .fill(difficulty.color)
                        .frame(width: 6, height: 6)
                    Text(difficulty.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(difficulty.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(difficulty.color.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Question Card

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Competency + concept badges
            HStack(spacing: 6) {
                if let competency = viewModel.currentQuestion?.competency {
                    Text(competency)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.purple.opacity(0.1))
                        .clipShape(Capsule())
                }
                if let concept = viewModel.currentQuestion?.concept {
                    Text(concept.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ColorTokens.gold)
                }
            }

            // Scenario context (for applied_scenario, situational_judgment, case_study)
            if let scenario = viewModel.currentQuestionScenario {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 10))
                        Text("SCENARIO")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundStyle(.cyan)

                    Text(scenario)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.cyan.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.cyan.opacity(0.15), lineWidth: 1)
                        )
                )
            }

            Text(viewModel.currentQuestion?.questionText ?? "")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorTokens.gold.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Options

    private var optionsList: some View {
        VStack(spacing: 10) {
            if let question = viewModel.currentQuestion {
                ForEach(question.options, id: \.stableId) { option in
                    optionButton(option)
                }
            }
        }
    }

    private func optionButton(_ option: QuizOption) -> some View {
        let isSelected = viewModel.selectedAnswer == option.label

        return Button {
            viewModel.selectAnswer(option.label)
        } label: {
            HStack(spacing: 12) {
                // Label circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? ColorTokens.gold : ColorTokens.border, lineWidth: 2)
                        .frame(width: 32, height: 32)

                    if isSelected {
                        Circle()
                            .fill(ColorTokens.gold)
                            .frame(width: 32, height: 32)

                        Text(option.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                    } else {
                        Text(option.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }

                Text(option.text)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : ColorTokens.textSecondary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ColorTokens.gold.opacity(0.1) : ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? ColorTokens.gold : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Text Response Input

    private var textResponseInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)

                Text(viewModel.currentQuestion?.textPrompt ?? "Explain your reasoning (optional)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            TextField("Type your answer...", text: Binding(
                get: { viewModel.currentTextResponse },
                set: { viewModel.currentTextResponse = $0 }
            ), axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ColorTokens.border, lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Previous
            Button {
                Haptics.selection()
                viewModel.previousQuestion()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.currentIndex > 0 ? .white : ColorTokens.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Circle())
            }
            .disabled(viewModel.currentIndex <= 0)

            // Skip / Submit
            if viewModel.selectedAnswer == nil {
                Button {
                    Haptics.selection()
                    viewModel.skipQuestion()
                } label: {
                    Text("Skip")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else if viewModel.isLastQuestion {
                Button {
                    Haptics.medium()
                    Task { await viewModel.completeQuiz() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isCompleting {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.8)
                            Text("Submitting...")
                                .font(.system(size: 14, weight: .bold))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Finish Quiz")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.isCompleting ? ColorTokens.gold.opacity(0.6) : ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(viewModel.isCompleting)
            } else {
                Button {
                    Haptics.selection()
                    viewModel.nextQuestion()
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Next
            Button {
                Haptics.selection()
                viewModel.nextQuestion()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(!viewModel.isLastQuestion ? .white : ColorTokens.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Circle())
            }
            .disabled(viewModel.isLastQuestion)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            ColorTokens.background
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }

    // MARK: - Question Navigator

    private var questionNavigator: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                        spacing: 10
                    ) {
                        ForEach(0..<viewModel.totalQuestions, id: \.self) { index in
                            Button {
                                viewModel.goToQuestion(index)
                                showQuestionPicker = false
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(questionColor(for: index))
                                        .frame(height: 48)

                                    Text("\(index + 1)")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(index == viewModel.currentIndex ? .black : .white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Questions")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showQuestionPicker = false }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func questionColor(for index: Int) -> Color {
        if index == viewModel.currentIndex {
            return ColorTokens.gold
        }
        if let answer = viewModel.answers[index] {
            return answer == "skipped" ? ColorTokens.surfaceElevated : ColorTokens.gold.opacity(0.3)
        }
        return ColorTokens.surface
    }

    // MARK: - States

    private var startingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ColorTokens.gold)
            Text("Preparing your quiz...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var completedTransition: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text("Quiz Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ProgressView()
                    .tint(ColorTokens.gold)

                Text(viewModel.isCompleting ? "Generating insights & analysis..." : "Preparing your results...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)

                Text(viewModel.isCompleting
                    ? "Our AI is analyzing your performance\nand updating your knowledge profile"
                    : "Almost there...")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .onChange(of: viewModel.isCompleting) { _, isCompleting in
            if !isCompleting && viewModel.hasCompleted {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    navigateToResults = true
                }
            }
        }
        .onAppear {
            // If already done completing when view appears, navigate immediately
            if !viewModel.isCompleting && viewModel.hasCompleted {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    navigateToResults = true
                }
            }
        }
    }
}
