import SwiftUI

extension Notification.Name {
    static let dismissChallengeSession = Notification.Name("dismissChallengeSession")
}

struct ChallengeSessionView: View {
    let challengeId: String
    let topic: String

    @State private var viewModel: ChallengeViewModel
    @State private var navigateToResults = false
    @State private var showWelcome = true
    @State private var countdown = 3
    @Environment(\.dismiss) private var dismiss

    init(challengeId: String, topic: String) {
        self.challengeId = challengeId
        self.topic = topic
        self._viewModel = State(initialValue: ChallengeViewModel(challengeId: challengeId))
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if showWelcome {
                welcomeScreen
            } else if viewModel.isLoading {
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
        .onDisappear {
            viewModel.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissChallengeSession)) { _ in
            dismiss()
        }
    }

    // MARK: - Welcome Screen

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            Spacer()

            VStack(spacing: Spacing.xl) {
                // Trophy icon
                ZStack {
                    Circle()
                        .fill(goldColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(goldColor)
                }

                // Topic
                Text(topic)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Challenge info
                VStack(spacing: 8) {
                    infoRow(icon: "questionmark.circle", text: "15 Questions")
                    infoRow(icon: "infinity", text: "No time limit")
                    infoRow(icon: "checkmark.shield", text: "No going back once answered")
                    infoRow(icon: "trophy", text: "Score against other players")
                }

                // Countdown or Start button
                if countdown > 0 && !showWelcome {
                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(goldColor)
                } else {
                    Button {
                        startCountdown()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("Start Challenge")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(goldColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, Spacing.xl)
                }
            }

            Spacer()

            // Tip at bottom
            Text("Tip: Read each question carefully before answering")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.bottom, Spacing.xl)
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(goldColor)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func startCountdown() {
        Haptics.medium()
        showWelcome = false
        Task {
            await viewModel.startChallenge()
        }
    }

    // MARK: - Main Challenge Content

    private var challengeContent: some View {
        VStack(spacing: 0) {
            topBar
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

            if viewModel.error != nil {
                VStack(spacing: Spacing.md) {
                    Text("Could not load results")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)

                    Button {
                        Task { await viewModel.completeChallenge() }
                    } label: {
                        Text("Retry")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(goldColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button { dismiss() } label: {
                        Text("Go Back")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            } else if viewModel.result == nil {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(goldColor)
                    Text("Calculating your score...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }

            Spacer()
        }
        .onChange(of: viewModel.result) { _, result in
            if result != nil {
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    navigateToResults = true
                }
            }
        }
        .onAppear {
            if viewModel.result != nil {
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
