import SwiftUI

struct DiagnosticContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DiagnosticViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            switch viewModel.phase {
            case .welcome:
                DiagnosticWelcomeView(viewModel: viewModel) {
                    Task { await viewModel.abandonCurrent(at: "welcome") }
                    appState.skipDiagnostic()
                }
            case .selfRating:
                DiagnosticSelfRatingView(viewModel: viewModel)
            case .preparing:
                DiagnosticPreparingView()
            case .quiz:
                quizContent
            case .results:
                DiagnosticResultsView(attemptId: viewModel.attemptId ?? "") {
                    appState.markDiagnosticComplete()
                    appState.completeDiagnostic()
                }
                .overlay(CompletionConfettiView())
            case .error:
                errorView
            }
            if viewModel.isLoading && viewModel.phase != .preparing {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ColorTokens.gold)
            }
        }
    }

    // Plan 3a Task 9: quiz content with per-topic progress chip + transition card.
    // The chip is always visible at the top (when topic state is populated),
    // and the transition card briefly replaces the question when the engine
    // moves to a new topic.
    @ViewBuilder
    private var quizContent: some View {
        VStack(spacing: 0) {
            if viewModel.totalTopicCount > 0 {
                TopicProgressChip(
                    currentIndex: viewModel.currentTopicIndex,
                    totalCount: viewModel.totalTopicCount,
                    currentTopicName: viewModel.currentTopicName
                )
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)
            }

            if viewModel.showingTransition {
                Spacer()
                TopicTransitionCard(nextTopicName: viewModel.nextTopicName) {
                    viewModel.showingTransition = false
                }
                Spacer()
            } else if viewModel.isVoiceQuestion, let q = viewModel.currentQuestion {
                // Plan 3a Task 11: route voice-eligible questions to the
                // voice answer view. `onFallbackToTyped` reverts to MCQ
                // rendering for the same question.
                DiagnosticVoiceAnswerView(
                    questionId: q.id,
                    questionText: q.prompt,
                    canonicalCompetency: q.canonicalCompetency ?? q.competency,
                    onComplete: { result in
                        viewModel.handleVoiceAnswerComplete(result)
                    },
                    onFallbackToTyped: {
                        viewModel.isVoiceQuestion = false
                    }
                )
            } else {
                DiagnosticQuestionView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Soft, contextual icon — no harsh warning triangles. The
            // onboarding-redirect path uses a "set up" feel; the generic
            // error path uses a soft sparkle.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ColorTokens.gold.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .strokeBorder(ColorTokens.gold.opacity(0.20), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(ColorTokens.gold.opacity(0.14))
                    .frame(width: 96, height: 96)

                Image(systemName: viewModel.requiresOnboarding ? "person.crop.circle.badge.checkmark" : "sparkle")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.bottom, Spacing.xl)

            // Title
            Text(viewModel.requiresOnboarding ? "Let's finish setting up" : "Just a moment")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.sm)
                .padding(.horizontal, Spacing.xl)

            // Body — fixedSize so it always wraps.
            Text(
                (viewModel.errorMessage?.isEmpty == false)
                    ? viewModel.errorMessage!
                    : "We couldn't load your questions. This usually clears up in a moment."
            )
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Buttons
            VStack(spacing: Spacing.md) {
                if viewModel.requiresOnboarding {
                    PrimaryButton(title: "Complete onboarding") {
                        appState.sendToOnboarding(step: viewModel.onboardingResumeStep ?? 3)
                    }
                } else {
                    PrimaryButton(title: "Try again") {
                        Task { await viewModel.retry() }
                    }
                }

                Button("Skip for now") { appState.skipDiagnostic() }
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }
}
