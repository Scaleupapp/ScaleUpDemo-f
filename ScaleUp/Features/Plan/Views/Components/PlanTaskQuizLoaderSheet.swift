import SwiftUI

/// A small sheet that fetches a Quiz by id and then shows QuizDetailView.
/// Used by PlanTabView when the user taps a quiz task — the plan stores
/// only the quizId in the task payload, but QuizDetailView needs the full
/// Quiz object.
struct PlanTaskQuizLoaderSheet: View {
    let quizId: String
    let onDismiss: () -> Void

    @State private var quiz: Quiz?
    @State private var loadError: String?

    private let quizService = QuizService()

    var body: some View {
        NavigationStack {
            Group {
                if let quiz {
                    QuizDetailView(quiz: quiz)
                } else if let loadError {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Couldn't load this quiz")
                            .font(Typography.titleLarge)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text(loadError)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                        PrimaryButton(title: "Close", action: onDismiss)
                            .padding(.horizontal, Spacing.xl)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(ColorTokens.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .task {
            do {
                quiz = try await quizService.fetchQuiz(id: quizId)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}
