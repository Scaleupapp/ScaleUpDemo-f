import SwiftUI

extension Notification.Name {
    static let dismissChallengeSession = Notification.Name("dismissChallengeSession")
}

struct ChallengeSessionView: View {
    let challengeId: String
    let topic: String

    @State private var viewModel: ChallengeViewModel
    @State private var navigateToResults = false
    @Environment(\.dismiss) private var dismiss

    init(challengeId: String, topic: String) {
        self.challengeId = challengeId
        self.topic = topic
        self._viewModel = State(initialValue: ChallengeViewModel(challengeId: challengeId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if viewModel.isLoading {
                    startingState
                } else if viewModel.isComplete {
                    completedTransition
                } else if viewModel.error != nil {
                    errorState
                } else if !viewModel.questions.isEmpty {
                    challengeContent
                }
            }
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToResults) {
                if let result = viewModel.result {
                    ChallengeResultsView(
                        result: result,
                        topic: topic,
                        challengeId: challengeId
                    )
                }
            }
        }
        .task {
            await viewModel.startChallenge()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissChallengeSession)) { _ in
            dismiss()
        }
    }

    // MARK: - Main Challenge Content

    private var challengeContent: some View {
        VStack(spacing: 0) {
            topBar
            timerBar
            questionCounter

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    questionCard
                    optionsList

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }

            bottomBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // No back button — challenge cannot be exited once started

            Spacer()

            // Topic badge
            Text(topic.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(goldColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(goldColor.opacity(0.12))
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Timer Bar

    private var timerBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.surfaceElevated)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(timerColor)
                        .frame(width: geo.size.width * timerProgress)
                        .animation(.linear(duration: 1), value: viewModel.timeRemaining)
                }
            }
            .frame(height: 5)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(timerColor)

                    Text(viewModel.timeRemainingFormatted)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(timerColor)
                }

                Spacer()

                if viewModel.timeRemaining <= 5 && viewModel.timeRemaining > 0 {
                    Text("Hurry!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Question Counter

    private var questionCounter: some View {
        HStack {
            Text("Q \(viewModel.currentQuestionIndex + 1)/\(viewModel.totalQuestions)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private func difficultyBadge(_ difficulty: String) -> some View {
        let color = difficultyColor(difficulty)
        return HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(difficulty.capitalized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return ColorTokens.textTertiary
        }
    }

    // MARK: - Question Card

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let concept = viewModel.currentQuestion?.concept {
                Text(concept.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(goldColor)
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
                        .stroke(goldColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Options

    private var optionsList: some View {
        VStack(spacing: 10) {
            if let question = viewModel.currentQuestion {
                ForEach(question.options, id: \.label) { option in
                    optionButton(option)
                }
            }
        }
    }

    private func optionButton(_ option: ChallengeOption) -> some View {
        let isSelected = viewModel.selectedAnswer == option.label

        return Button {
            Haptics.selection()
            viewModel.selectedAnswer = option.label
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? goldColor : ColorTokens.border, lineWidth: 2)
                        .frame(width: 32, height: 32)

                    if isSelected {
                        Circle()
                            .fill(goldColor)
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
                    .fill(isSelected ? goldColor.opacity(0.1) : ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? goldColor : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // No back/previous button in challenge mode

            if viewModel.selectedAnswer != nil {
                // Submit / Next button
                Button {
                    Haptics.medium()
                    Task { await viewModel.submitAnswer() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isLastQuestion {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Finish Challenge")
                                .font(.system(size: 14, weight: .bold))
                        } else {
                            Text("Submit")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(goldColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                // Placeholder — must select an answer (no skip)
                Text("Select an answer to continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            ColorTokens.background
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }

    // MARK: - Timer Helpers

    private var timerProgress: Double {
        let limit = 720.0 // Total challenge time limit in seconds
        guard limit > 0 else { return 0 }
        return max(0, min(1, viewModel.timeRemaining / limit))
    }

    private var timerColor: Color {
        if viewModel.timeRemaining <= 5 { return .red }
        if viewModel.timeRemaining <= 10 { return .orange }
        return goldColor
    }

    // MARK: - States

    private var startingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(goldColor)
            Text("Preparing your challenge...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var errorState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(viewModel.error ?? "Something went wrong")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.startChallenge() }
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(goldColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    private var completedTransition: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(goldColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(goldColor)
            }

            Text("Challenge Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ProgressView()
                    .tint(goldColor)

                Text("Calculating your score...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete && viewModel.result != nil {
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    navigateToResults = true
                }
            }
        }
        .onAppear {
            if viewModel.isComplete && viewModel.result != nil {
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    navigateToResults = true
                }
            }
        }
    }

    // MARK: - Constants

    private var goldColor: Color { Color(red: 1, green: 215.0/255.0, blue: 0) } // #FFD700
}
