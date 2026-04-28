import SwiftUI

struct DiagnosticQuestionView: View {
    let viewModel: DiagnosticViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar

            // Progress bar
            progressBar
                .padding(.top, Spacing.sm)

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    if let question = viewModel.currentQuestion {
                        questionCard(question)
                        optionsList(question)
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
            }

            // Bottom submit
            bottomBar
        }
        .task {
            if viewModel.currentQuestion == nil {
                await viewModel.loadNextQuestion()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Question counter badge
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("Question \(viewModel.questionsAnswered + 1) of \(viewModel.totalQuestionsTarget)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(ColorTokens.gold.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(ColorTokens.gold.opacity(0.25), lineWidth: 1)
            )

            Spacer()

            // Competency badge
            if let competency = viewModel.currentQuestion?.competency {
                Text(competency)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
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
    }

    // MARK: - Question Card

    private func questionCard(_ question: DiagnosticQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Difficulty badge
            HStack(spacing: 6) {
                Circle()
                    .fill(difficultyColor(question.difficulty))
                    .frame(width: 6, height: 6)
                Text(question.difficulty.capitalized)
                    .font(Typography.caption)
                    .foregroundStyle(difficultyColor(question.difficulty))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(difficultyColor(question.difficulty).opacity(0.1))
            .clipShape(Capsule())

            Text(question.prompt)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.gold.opacity(0.35), lineWidth: 1.5)
        )
        // Left accent bar
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ColorTokens.gold)
                .frame(width: 3)
                .padding(.vertical, Spacing.md)
                .padding(.leading, 0)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }

    // MARK: - Options

    private func optionsList(_ question: DiagnosticQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(question.options) { option in
                optionButton(option)
            }
        }
    }

    private func optionButton(_ option: DiagnosticOption) -> some View {
        let isSelected = viewModel.currentSelection == option.id

        return Button {
            viewModel.selectOption(option.id)
        } label: {
            HStack(spacing: Spacing.md) {
                // Leading circle indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? ColorTokens.gold : ColorTokens.border,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(ColorTokens.gold)
                            .frame(width: 12, height: 12)
                    }
                }

                // Option letter label
                Text(option.id)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? ColorTokens.gold : ColorTokens.textTertiary)
                    .frame(width: 16)

                Text(option.text)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isSelected ? ColorTokens.gold.opacity(0.10) : ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(
                                isSelected ? ColorTokens.gold : ColorTokens.border,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(ColorTokens.divider)

            PrimaryButton(
                title: "Submit",
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.currentSelection == nil
            ) {
                Task { await viewModel.submitCurrentAnswer() }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .background(
            ColorTokens.background
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }

    // MARK: - Helpers

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy":   return ColorTokens.success
        case "medium": return ColorTokens.warning
        case "hard":   return ColorTokens.error
        default:       return ColorTokens.textSecondary
        }
    }
}
