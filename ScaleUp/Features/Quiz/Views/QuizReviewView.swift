import SwiftUI

// MARK: - Quiz Review View

struct QuizReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let quiz: Quiz
    let attempt: QuizAttempt

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {

                    // Header
                    VStack(spacing: Spacing.xs) {
                        Text("Answer Review")
                            .font(Typography.titleLarge)
                            .foregroundStyle(ColorTokens.textPrimaryDark)

                        Text("\(quiz.questions.count) questions")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                    .padding(.top, Spacing.md)

                    // Questions
                    ForEach(Array(quiz.questions.enumerated()), id: \.offset) { index, question in
                        questionReviewCard(
                            index: index,
                            question: question,
                            userAnswer: userAnswer(for: index)
                        )
                    }

                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(ColorTokens.primary)
            }
        }
    }

    // MARK: - Question Review Card

    @ViewBuilder
    private func questionReviewCard(index: Int, question: QuizQuestion, userAnswer: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {

            // Question header
            HStack(spacing: Spacing.sm) {
                Text("Q\(index + 1)")
                    .font(Typography.bodyBold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(statusColor(question: question, userAnswer: userAnswer))
                    .clipShape(Circle())

                Text(statusLabel(question: question, userAnswer: userAnswer))
                    .font(Typography.caption)
                    .foregroundStyle(statusColor(question: question, userAnswer: userAnswer))

                Spacer()

                if let difficulty = question.difficulty {
                    Text(difficulty.capitalized)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTokens.surfaceElevatedDark)
                        .clipShape(Capsule())
                }
            }

            // Question text
            Text(question.questionText)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            // Options with states
            VStack(spacing: Spacing.sm) {
                ForEach(question.options) { option in
                    let optionIndex = question.options.firstIndex(where: { $0.id == option.id }) ?? 0
                    let state = reviewOptionState(
                        optionLabel: option.label,
                        correctAnswer: question.correctAnswer,
                        userAnswer: userAnswer,
                        question: question
                    )

                    QuizOptionPill(
                        label: option.label,
                        text: option.text,
                        state: state
                    )
                }
            }

            // Explanation
            if let explanation = question.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.info)

                        Text("Explanation")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.info)
                    }

                    Text(explanation)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.md)
                .background(ColorTokens.info.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }

            // Source content link
            if let sourceContentId = question.sourceContentId {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.primary)

                    if let concept = question.concept {
                        Text("Concept: \(concept)")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.primary)
                            .lineLimit(1)
                    } else {
                        Text("Source: \(sourceContentId.prefix(12))...")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.primary)
                            .lineLimit(1)
                    }

                    if let timestamp = question.sourceTimestamp {
                        Text("@ \(timestamp)")
                            .font(Typography.mono)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.primary)
                }
                .padding(Spacing.sm)
                .background(ColorTokens.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Helpers

    private func userAnswer(for questionIndex: Int) -> String? {
        let answer = attempt.answers.first { $0.questionIndex == questionIndex }
        guard let answer else { return nil }
        return answer.selectedAnswer != "skipped" ? answer.selectedAnswer : nil
    }

    private func reviewOptionState(optionLabel: String, correctAnswer: String?, userAnswer: String?, question: QuizQuestion) -> QuizOptionPill.OptionState {
        let isCorrectOption = optionLabel == correctAnswer

        guard let userAnswer else {
            // Skipped: show correct answer in green, rest dimmed
            return isCorrectOption ? .correct : .default
        }

        let isUserSelection = optionLabel == userAnswer

        if isCorrectOption {
            return .correct
        } else if isUserSelection {
            return .wrong
        } else {
            return .default
        }
    }

    private func statusColor(question: QuizQuestion, userAnswer: String?) -> Color {
        guard let userAnswer else { return ColorTokens.textTertiaryDark }
        return userAnswer == question.correctAnswer ? ColorTokens.success : ColorTokens.error
    }

    private func statusLabel(question: QuizQuestion, userAnswer: String?) -> String {
        guard let userAnswer else { return "Skipped" }
        return userAnswer == question.correctAnswer ? "Correct" : "Incorrect"
    }
}
