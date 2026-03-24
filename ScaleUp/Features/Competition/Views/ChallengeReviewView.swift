import SwiftUI

struct ChallengeReviewView: View {
    let challengeId: String
    let topic: String

    @State private var review: ChallengeReview?
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private let service = CompetitionService()
    private let gold = Color(hex: 0xFFD700)
    private let green = Color(hex: 0x22C55E)
    private let red = Color(hex: 0xEF4444)

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(gold)
            } else if let error = error {
                errorView(error)
            } else if let review = review {
                reviewContent(review)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadReview() }
    }

    // MARK: - Review Content

    private func reviewContent(_ review: ChallengeReview) -> some View {
        VStack(spacing: 0) {
            // Header
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

                Text("Review")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Invisible spacer for centering
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            // Summary bar
            HStack(spacing: 16) {
                summaryItem(
                    value: "\(review.correctCount)/\(review.totalQuestions)",
                    label: "Correct",
                    color: green
                )

                if let score = review.handicappedScore {
                    summaryItem(
                        value: "\(Int(score))",
                        label: "Score",
                        color: gold
                    )
                }

                if let time = review.totalTimeTaken {
                    summaryItem(
                        value: formatTime(time),
                        label: "Time",
                        color: .cyan
                    )
                }
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)

            // Questions list
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(review.questions) { question in
                        questionReviewCard(question)
                    }

                    Spacer().frame(height: Spacing.xxxl)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Question Card

    private func questionReviewCard(_ question: ReviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Question header
            HStack {
                Text("Q\(question.questionIndex + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(question.isCorrect ? green : red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((question.isCorrect ? green : red).opacity(0.12))
                    .clipShape(Capsule())

                if let concept = question.concept {
                    Text(concept)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text(formatTime(question.timeSpent))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Question text
            Text(question.questionText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Options
            VStack(spacing: 6) {
                ForEach(question.options, id: \.label) { option in
                    optionRow(option, question: question)
                }
            }

            // Explanation
            if let explanation = question.explanation, !explanation.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(gold)
                    Text(explanation)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(gold.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            (question.isCorrect ? green : red).opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Option Row

    private func optionRow(_ option: ChallengeOption, question: ReviewQuestion) -> some View {
        let isUserAnswer = option.label == question.selectedAnswer
        let isCorrectAnswer = option.label == question.correctAnswer
        let bgColor: Color = isCorrectAnswer ? green.opacity(0.1) : (isUserAnswer && !question.isCorrect ? red.opacity(0.1) : Color.clear)
        let borderColor: Color = isCorrectAnswer ? green.opacity(0.5) : (isUserAnswer && !question.isCorrect ? red.opacity(0.5) : ColorTokens.border)

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(isCorrectAnswer ? green : (isUserAnswer ? red : ColorTokens.border), lineWidth: 1.5)
                    .frame(width: 26, height: 26)

                if isCorrectAnswer {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(green)
                } else if isUserAnswer && !question.isCorrect {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(red)
                } else {
                    Text(option.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Text(option.text)
                .font(.system(size: 13, weight: isCorrectAnswer || isUserAnswer ? .semibold : .regular))
                .foregroundStyle(isCorrectAnswer ? green : (isUserAnswer && !question.isCorrect ? red : ColorTokens.textSecondary))
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    // MARK: - Summary Item

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
            HStack(spacing: 12) {
                Button { Task { await loadReview() } } label: {
                    Text("Retry")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button { dismiss() } label: {
                    Text("Go Back")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        if mins > 0 { return String(format: "%d:%02d", mins, secs) }
        return "\(secs)s"
    }

    private func loadReview() async {
        isLoading = true
        error = nil
        do {
            review = try await service.fetchChallengeReview(challengeId: challengeId)
        } catch {
            self.error = "Could not load review"
        }
        isLoading = false
    }
}
