import SwiftUI

// MARK: - Recalibration Orchestration View
//
// Wraps the existing diagnostic question flow with recalibration semantics:
// POST /diagnostic/recalibration/start, then renders the quiz phase with
// the returned attemptId. Skips welcome + self-rating (context inherited
// from prior attempt). On quiz completion, shows RecalibrationResultsView.

struct RecalibrationOrchestrationView: View {
    @Bindable var viewModel: RecalibrationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var quizViewModel: DiagnosticViewModel?
    @State private var phase: OrchestratorPhase = .starting
    @State private var recalAttemptId: String?

    enum OrchestratorPhase {
        case starting
        case quiz
        case results(attemptId: String)
        case error(String)
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            switch phase {
            case .starting:
                startingView

            case .quiz:
                if let qvm = quizViewModel {
                    recalQuizContent(qvm)
                }

            case .results(let attemptId):
                RecalibrationResultsView(attemptId: attemptId) {
                    dismiss()
                }

            case .error(let message):
                errorView(message)
            }
        }
        .task {
            await startRecalibration()
        }
    }

    // MARK: - Starting spinner

    private var startingView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(ColorTokens.gold)
            Text("Starting recalibration…")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
    }

    // MARK: - Quiz content (reuses existing DiagnosticContainerView quiz phase)
    // We construct a DiagnosticViewModel, seed it with the recalibration attemptId
    // and pre-advance it to .quiz phase — skipping welcome and self-rating entirely
    // since those were captured in the original diagnostic attempt.

    @ViewBuilder
    private func recalQuizContent(_ qvm: DiagnosticViewModel) -> some View {
        VStack(spacing: 0) {
            if qvm.totalTopicCount > 0 {
                TopicProgressChip(
                    currentIndex: qvm.currentTopicIndex,
                    totalCount: qvm.totalTopicCount,
                    currentTopicName: qvm.currentTopicName
                )
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)
            }

            if qvm.showingTransition {
                Spacer()
                TopicTransitionCard(nextTopicName: qvm.nextTopicName) {
                    qvm.showingTransition = false
                }
                Spacer()
            } else if qvm.isVoiceQuestion, let q = qvm.currentQuestion {
                DiagnosticVoiceAnswerView(
                    questionId: q.id,
                    questionText: q.prompt,
                    canonicalCompetency: q.canonicalCompetency ?? q.competency,
                    onComplete: { result in qvm.handleVoiceAnswerComplete(result) },
                    onFallbackToTyped: { qvm.isVoiceQuestion = false }
                )
            } else {
                DiagnosticQuestionView(viewModel: qvm)
            }
        }
        .onChange(of: qvm.phase) { _, newPhase in
            if newPhase == .results, let id = qvm.attemptId {
                phase = .results(attemptId: id)
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.warning)
            Text("Couldn't start recalibration")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Dismiss") { dismiss() }
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.gold)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Start

    private func startRecalibration() async {
        do {
            let response = try await viewModel.start()
            recalAttemptId = response.attemptId

            let qvm = DiagnosticViewModel()
            // Seed the VM with the server-created attempt so that
            // nextQuestion calls hit the correct attempt endpoint.
            await qvm.prepareForRecalibration(
                attemptId: response.attemptId,
                totalQuestions: response.totalEstimatedQuestions
            )
            quizViewModel = qvm
            phase = .quiz
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
