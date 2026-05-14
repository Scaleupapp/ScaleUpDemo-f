import SwiftUI

/// Loader for v2 quiz tasks that have no pre-baked quizId.
///
/// v2 plan quiz tasks don't always carry a quizId (v1 quizzes are generated
/// on demand). This sheet requests a quiz for the task's topic, polls the
/// trigger until it's ready, then drops the user straight into QuizSession.
struct V2QuizRequestLoaderSheet: View {
    let topic: String
    let onClose: () -> Void

    @State private var quiz: Quiz?
    @State private var loadError: String?

    private let quizService = QuizService()

    var body: some View {
        NavigationStack {
            Group {
                if let quiz {
                    QuizSessionView(quiz: quiz)
                } else if let loadError {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Couldn't start this quiz")
                            .font(Typography.titleLarge)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text(loadError)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                        PrimaryButton(title: "Close", action: onClose)
                            .padding(.horizontal, Spacing.xl)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(ColorTokens.gold)
                        Text("Building your quiz on \(topic)…")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let trigger = try await quizService.requestQuiz(topic: topic, questionCount: 10)
            var quizId = trigger.quizId

            // Poll the trigger until the quiz is generated (~up to 60s).
            if quizId == nil, let triggerId = trigger.triggerId {
                for _ in 0..<30 {
                    try? await Task.sleep(for: .seconds(2))
                    let status = try await quizService.checkTriggerStatus(triggerId: triggerId)
                    if let qid = status.quizId {
                        quizId = qid
                        break
                    }
                    if status.status == "failed" {
                        loadError = "We couldn't build a quiz for this topic. Try again in a bit."
                        return
                    }
                }
            }

            guard let qid = quizId else {
                loadError = "This is taking longer than expected. Try again in a moment."
                return
            }
            quiz = try await quizService.fetchQuiz(id: qid)
        } catch {
            loadError = "Couldn't reach the quiz service. Check your connection and try again."
        }
    }
}
