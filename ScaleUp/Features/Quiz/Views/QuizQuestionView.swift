import SwiftUI

// MARK: - Quiz Question View

struct QuizQuestionView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let quizId: String

    @State private var viewModel: QuizSessionViewModel?
    @State private var showResults = false
    @State private var questionTransitionId = UUID()
    @State private var showConfetti = false

    // Timer state
    @State private var remainingSeconds: Int = 0
    @State private var timerActive = false

    // Animation states
    @State private var questionAppeared = false
    @State private var optionsAppeared = false
    @State private var pulseTimer = false

    var body: some View {
        ZStack {
            // Animated gradient background
            backgroundView

            if let viewModel {
                if viewModel.isSubmitting && viewModel.quiz == nil {
                    loadingView
                } else if let error = viewModel.error, viewModel.quiz == nil {
                    errorView(error: error, viewModel: viewModel)
                } else if viewModel.quiz != nil {
                    questionContent(viewModel: viewModel)
                }
            }

            // Confetti overlay
            if showConfetti {
                ConfettiOverlay()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = QuizSessionViewModel(quizService: dependencies.quizService)
            }
        }
        .task {
            if let viewModel, viewModel.quiz == nil {
                await viewModel.startQuiz(id: quizId)
                startTimerIfNeeded()
                triggerQuestionEntrance()
            }
        }
        .fullScreenCover(isPresented: $showResults) {
            if let viewModel, let attempt = viewModel.attempt {
                QuizResultsView(
                    quizId: viewModel.quiz?.id ?? quizId,
                    preloadedAttempt: attempt,
                    preloadedQuiz: viewModel.quiz
                )
                .environment(dependencies)
            }
        }
        .onChange(of: viewModel?.isCompleted ?? false) { _, isCompleted in
            if isCompleted && !showResults {
                withAnimation(Animations.spring) {
                    showConfetti = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showResults = true
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [ColorTokens.primary.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -200)
                .blur(radius: 40)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [ColorTokens.info.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: 120, y: 300)
                .blur(radius: 40)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 4)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(ColorTokens.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(pulseTimer ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: pulseTimer)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.primary)
            }

            Text("Preparing your quiz...")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Getting everything ready")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .onAppear { pulseTimer = true }
    }

    // MARK: - Error View

    private func errorView(error: APIError, viewModel: QuizSessionViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            ErrorStateView(
                message: error.localizedDescription,
                retryAction: {
                    Task { await viewModel.startQuiz(id: quizId) }
                }
            )

            Button("Close") { dismiss() }
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(viewModel: QuizSessionViewModel) -> some View {
        VStack(spacing: 0) {

            // Top bar
            topBar(viewModel: viewModel)

            // Segmented progress bar
            segmentedProgressBar(viewModel: viewModel)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

            // Question area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {

                    // Question number badge
                    HStack {
                        questionBadge(viewModel: viewModel)
                        Spacer()
                        if let question = viewModel.currentQuestion, let difficulty = question.difficulty {
                            difficultyBadge(difficulty)
                        }
                    }
                    .padding(.horizontal, Spacing.md)

                    // Question text with card
                    if let question = viewModel.currentQuestion {
                        questionCard(question: question)
                            .opacity(questionAppeared ? 1 : 0)
                            .offset(y: questionAppeared ? 0 : 20)

                        // Options with staggered animation
                        VStack(spacing: Spacing.sm) {
                            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                                let state = optionState(
                                    optionLabel: option.label,
                                    selectedAnswer: viewModel.selectedAnswer
                                )

                                Button {
                                    withAnimation(Animations.quick) {
                                        viewModel.selectAnswer(option.label)
                                    }
                                } label: {
                                    QuizOptionPill(
                                        label: option.label,
                                        text: option.text,
                                        state: state
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isSubmitting)
                                .opacity(optionsAppeared ? 1 : 0)
                                .offset(y: optionsAppeared ? 0 : 30)
                                .animation(
                                    Animations.spring.delay(Double(index) * 0.08),
                                    value: optionsAppeared
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.vertical, Spacing.lg)
            }
            .id(questionTransitionId)

            // Bottom bar
            bottomBar(viewModel: viewModel)
        }
        .loadingOverlay(isPresented: viewModel.isSubmitting && viewModel.quiz != nil, message: "Submitting...")
    }

    // MARK: - Top Bar

    private func topBar(viewModel: QuizSessionViewModel) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.surfaceElevatedDark.opacity(0.8))
                    .clipShape(Circle())
            }

            Spacer()

            // Timer
            if let timeLimit = viewModel.quiz?.timeLimit, timeLimit > 0 {
                timerDisplay
            }

            Spacer()

            // Question count pill
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(viewModel.currentQuestionIndex + 1)/\(viewModel.totalQuestions)")
                    .font(Typography.mono)
            }
            .foregroundStyle(ColorTokens.textSecondaryDark)
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs)
            .background(ColorTokens.surfaceElevatedDark.opacity(0.8))
            .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        let isUrgent = remainingSeconds <= 60
        let isWarning = remainingSeconds <= 30

        return HStack(spacing: Spacing.xs) {
            Image(systemName: isWarning ? "exclamationmark.circle.fill" : "clock")
                .font(.system(size: 14, weight: .semibold))
            Text(formatTime(remainingSeconds))
                .font(Typography.mono)
                .contentTransition(.numericText())
        }
        .foregroundStyle(isWarning ? ColorTokens.error : isUrgent ? ColorTokens.warning : ColorTokens.textSecondaryDark)
        .padding(.horizontal, Spacing.sm + 2)
        .padding(.vertical, Spacing.xs + 2)
        .background(
            Group {
                if isWarning {
                    ColorTokens.error.opacity(0.15)
                } else if isUrgent {
                    ColorTokens.warning.opacity(0.1)
                } else {
                    ColorTokens.surfaceElevatedDark.opacity(0.8)
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isWarning ? ColorTokens.error.opacity(0.3) : .clear, lineWidth: 1)
        )
        .animation(Animations.quick, value: remainingSeconds)
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { _ in
            guard timerActive, remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                timerActive = false
                Task {
                    if let viewModel {
                        await viewModel.completeQuiz()
                    }
                }
            }
        }
    }

    // MARK: - Segmented Progress Bar

    private func segmentedProgressBar(viewModel: QuizSessionViewModel) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<viewModel.totalQuestions, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(segmentColor(index: index, viewModel: viewModel))
                    .frame(height: 4)
                    .animation(Animations.standard, value: viewModel.currentQuestionIndex)
            }
        }
    }

    private func segmentColor(index: Int, viewModel: QuizSessionViewModel) -> Color {
        if index < viewModel.currentQuestionIndex {
            if viewModel.answers[index] == "__skipped__" {
                return ColorTokens.warning.opacity(0.6)
            }
            return ColorTokens.success
        } else if index == viewModel.currentQuestionIndex {
            return ColorTokens.primary
        } else {
            return ColorTokens.surfaceElevatedDark
        }
    }

    // MARK: - Question Badge

    private func questionBadge(viewModel: QuizSessionViewModel) -> some View {
        HStack(spacing: 6) {
            Text("Q\(viewModel.currentQuestionIndex + 1)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 32, height: 24)
                .background(ColorTokens.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("of \(viewModel.totalQuestions)")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
    }

    // MARK: - Difficulty Badge

    private func difficultyBadge(_ difficulty: String) -> some View {
        let color: Color = switch difficulty.lowercased() {
        case "easy": ColorTokens.success
        case "hard": ColorTokens.error
        default: ColorTokens.warning
        }

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(difficulty.capitalized)
                .font(Typography.micro)
                .foregroundStyle(color)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Question Card

    private func questionCard(question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(question.questionText)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .fixedSize(horizontal: false, vertical: true)

            if let concept = question.concept {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                    Text(concept)
                        .font(Typography.caption)
                }
                .foregroundStyle(ColorTokens.primary.opacity(0.8))
                .padding(.top, 2)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.surfaceDark)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(
                            LinearGradient(
                                colors: [ColorTokens.primary.opacity(0.2), ColorTokens.primary.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Bottom Bar

    private func bottomBar(viewModel: QuizSessionViewModel) -> some View {
        HStack(spacing: Spacing.md) {
            // Skip button
            Button {
                Task {
                    await viewModel.skipQuestion()
                    advanceQuestionTransition()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                    Text("Skip")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(ColorTokens.surfaceElevatedDark)
                .clipShape(Capsule())
            }
            .disabled(viewModel.isSubmitting)

            Spacer()

            // Next / Finish button
            if viewModel.hasSelectedAnswer {
                Button {
                    Task {
                        await viewModel.submitAnswer()
                        if !viewModel.isCompleted {
                            advanceQuestionTransition()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }

                        Text(viewModel.isLastQuestion ? "Finish" : "Next")
                            .font(Typography.bodyBold)

                        if !viewModel.isLastQuestion && !viewModel.isSubmitting {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        } else if viewModel.isLastQuestion && !viewModel.isSubmitting {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm + 2)
                    .background(
                        LinearGradient(
                            colors: viewModel.isLastQuestion
                                ? [ColorTokens.success, ColorTokens.success.opacity(0.8)]
                                : [ColorTokens.primary, ColorTokens.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: (viewModel.isLastQuestion ? ColorTokens.success : ColorTokens.primary).opacity(0.3), radius: 8, y: 4)
                }
                .disabled(viewModel.isSubmitting)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            ColorTokens.surfaceDark
                .shadow(.drop(color: .black.opacity(0.3), radius: 12, y: -4))
        )
        .animation(Animations.spring, value: viewModel.hasSelectedAnswer)
    }

    // MARK: - Helpers

    private func optionState(optionLabel: String, selectedAnswer: String?) -> QuizOptionPill.OptionState {
        guard let selectedAnswer else { return .default }
        return optionLabel == selectedAnswer ? .selected : .default
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimerIfNeeded() {
        guard let timeLimit = viewModel?.quiz?.timeLimit, timeLimit > 0 else { return }
        remainingSeconds = timeLimit
        timerActive = true
    }

    private func advanceQuestionTransition() {
        questionAppeared = false
        optionsAppeared = false
        withAnimation(Animations.standard) {
            questionTransitionId = UUID()
        }
        triggerQuestionEntrance()
    }

    private func triggerQuestionEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animations.spring) {
                questionAppeared = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(Animations.spring) {
                optionsAppeared = true
            }
        }
    }
}

// MARK: - Confetti Overlay

private struct ConfettiOverlay: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, rotation: Double, scale: CGFloat)] = []
    @State private var animate = false

    private let colors: [Color] = [
        ColorTokens.primary,
        ColorTokens.success,
        ColorTokens.warning,
        ColorTokens.info,
        ColorTokens.anchorGold,
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(particle.color)
                        .frame(width: 8, height: 12)
                        .scaleEffect(animate ? particle.scale : 0)
                        .rotationEffect(.degrees(animate ? particle.rotation : 0))
                        .position(
                            x: animate ? particle.x : geo.size.width / 2,
                            y: animate ? particle.y : -20
                        )
                        .opacity(animate ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0..<30).map { i in
                    (
                        id: i,
                        x: CGFloat.random(in: 20...geo.size.width - 20),
                        y: CGFloat.random(in: geo.size.height * 0.3...geo.size.height * 0.8),
                        color: colors[i % colors.count],
                        rotation: Double.random(in: 180...720),
                        scale: CGFloat.random(in: 0.6...1.2)
                    )
                }
                withAnimation(.easeOut(duration: 1.5)) {
                    animate = true
                }
            }
        }
        .ignoresSafeArea()
    }
}
