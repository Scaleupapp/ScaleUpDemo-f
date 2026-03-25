import SwiftUI

struct LiveEventSessionView: View {
    @State var viewModel: LiveEventViewModel
    @State private var navigateToResults = false
    @State private var showResultsOverlay = false
    @State private var pulseAnimation = false
    @Environment(\.dismiss) private var dismiss

    private let purpleAccent = Color(red: 139.0/255.0, green: 92.0/255.0, blue: 246.0/255.0) // #8B5CF6

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if let question = viewModel.currentQuestion, !question.eventComplete {
                sessionContent(question: question)
            } else if viewModel.isComplete {
                completedTransition
            } else {
                loadingState
            }

            // Brief results overlay
            if showResultsOverlay, let results = viewModel.questionResults {
                resultsOverlay(results: results)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToResults) {
            if let results = viewModel.eventResults {
                LiveEventResultsView(
                    results: results,
                    topic: viewModel.event.topic
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    navigateToResults = true
                }
            }
        }
    }

    // MARK: - Session Content

    private func sessionContent(question: LiveQuestionResponse) -> some View {
        VStack(spacing: 0) {
            topBar(question: question)
            timerBar(question: question)
            questionCounter(question: question)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    questionCard(question: question)
                    optionsList(question: question)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }

            bottomBar
        }
    }

    // MARK: - Top Bar

    private func topBar(question: LiveQuestionResponse) -> some View {
        HStack {
            // LIVE indicator with pulse
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.3 : 0.8)
                    .opacity(pulseAnimation ? 1.0 : 0.5)

                Text("LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.red.opacity(0.12))
            .clipShape(Capsule())

            Spacer()

            // Participant count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(purpleAccent)

                Text("\(viewModel.participantCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: viewModel.participantCount)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(purpleAccent.opacity(0.12))
            .clipShape(Capsule())

            Spacer()

            // Topic badge
            Text(viewModel.event.formattedTitle.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(purpleAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(purpleAccent.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Timer Bar

    private func timerBar(question: LiveQuestionResponse) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.surfaceElevated)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(timerColor(question: question))
                        .frame(width: geo.size.width * timerProgress(question: question))
                        .animation(.linear(duration: 1), value: question.timeRemaining)
                }
            }
            .frame(height: 5)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(timerColor(question: question))

                    Text(formatTimeRemaining(question.timeRemaining ?? 0))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(timerColor(question: question))
                }

                Spacer()

                if let remaining = question.timeRemaining, remaining <= 5 && remaining > 0 {
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

    private func questionCounter(question: LiveQuestionResponse) -> some View {
        HStack {
            Text("Q \((question.questionIndex ?? 0) + 1)/\(question.totalQuestions ?? 10)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            if let difficulty = question.difficulty {
                difficultyBadge(difficulty)
            }
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

    private func questionCard(question: LiveQuestionResponse) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(question.questionText ?? "")
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
                        .stroke(purpleAccent.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Options

    private func optionsList(question: LiveQuestionResponse) -> some View {
        VStack(spacing: 10) {
            if let options = question.options {
                ForEach(options, id: \.label) { option in
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
                        .stroke(isSelected ? purpleAccent : ColorTokens.border, lineWidth: 2)
                        .frame(width: 32, height: 32)

                    if isSelected {
                        Circle()
                            .fill(purpleAccent)
                            .frame(width: 32, height: 32)

                        Text(option.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
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
                    .fill(isSelected ? purpleAccent.opacity(0.1) : ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? purpleAccent : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if viewModel.selectedAnswer != nil {
                Button {
                    Haptics.medium()
                    Task { await viewModel.submitAnswer() }
                } label: {
                    HStack(spacing: 6) {
                        Text("Submit")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(purpleAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
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

    // MARK: - Results Overlay

    private func resultsOverlay(results: LiveQuestionResults) -> some View {
        VStack(spacing: Spacing.md) {
            Text("\(results.correctPercentage)% got it right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("\(results.totalAnswered) answered")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(purpleAccent.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(purpleAccent)
            Text("Waiting for next question...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - Completed Transition

    private var completedTransition: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(purpleAccent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(purpleAccent)
            }

            Text("Live Event Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ProgressView()
                    .tint(purpleAccent)

                Text("Calculating results...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func timerProgress(question: LiveQuestionResponse) -> Double {
        let limit = Double(question.timeLimit ?? 30)
        let remaining = question.timeRemaining ?? 0
        guard limit > 0 else { return 0 }
        return max(0, min(1, remaining / limit))
    }

    private func timerColor(question: LiveQuestionResponse) -> Color {
        let remaining = question.timeRemaining ?? 0
        if remaining <= 5 { return .red }
        if remaining <= 10 { return .orange }
        return purpleAccent
    }

    private func formatTimeRemaining(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
