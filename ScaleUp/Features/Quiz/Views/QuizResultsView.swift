import SwiftUI

// MARK: - Quiz Results View

struct QuizResultsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let quizId: String
    var preloadedAttempt: QuizAttempt?
    var preloadedQuiz: Quiz?

    @State private var viewModel: QuizResultsViewModel?
    @State private var showReview = false
    @State private var showCelebration = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.attempt == nil {
                        LoadingOverlay(message: "Loading results...")
                    } else if let error = viewModel.error, viewModel.attempt == nil {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadResults(quizId: quizId) }
                            }
                        )
                    } else if viewModel.attempt != nil {
                        resultsContent(viewModel: viewModel)
                    }
                }

                // Celebration overlay
                if showCelebration {
                    CelebrationOverlay()
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = QuizResultsViewModel(quizService: dependencies.quizService)
                if let preloadedAttempt {
                    vm.attempt = preloadedAttempt
                    vm.quiz = preloadedQuiz
                }
                viewModel = vm
            }
        }
        .task {
            guard let viewModel else { return }
            if viewModel.attempt == nil {
                await viewModel.loadResults(quizId: quizId)
            }
            // Trigger celebration after a short delay
            if !appeared {
                appeared = true
                try? await Task.sleep(for: .milliseconds(600))
                if viewModel.isHighScore {
                    withAnimation(Animations.spring) {
                        showCelebration = true
                    }
                    // Auto-dismiss celebration
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation(Animations.smooth) {
                        showCelebration = false
                    }
                }
            }
        }
        .sheet(isPresented: $showReview) {
            if let viewModel, let quiz = viewModel.quiz, let attempt = viewModel.attempt {
                NavigationStack {
                    QuizReviewView(quiz: quiz, attempt: attempt)
                }
            }
        }
    }

    // MARK: - Results Content

    @ViewBuilder
    private func resultsContent(viewModel: QuizResultsViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Score Gauge
                scoreSection(viewModel: viewModel)

                // Score summary
                scoreSummary(viewModel: viewModel)

                // Trend comparison
                if let trendText = viewModel.trendText {
                    trendSection(trendText: trendText, comparison: viewModel.comparison)
                }

                // Topic breakdown
                if let breakdown = viewModel.topicBreakdown, !breakdown.isEmpty {
                    topicBreakdownSection(breakdown: breakdown)
                }

                // Strengths
                if !viewModel.strengths.isEmpty {
                    strengthsSection(strengths: viewModel.strengths)
                }

                // Weaknesses
                if !viewModel.weaknesses.isEmpty {
                    weaknessesSection(weaknesses: viewModel.weaknesses)
                }

                // Missed concepts
                if !viewModel.missedConcepts.isEmpty {
                    missedConceptsSection(concepts: viewModel.missedConcepts)
                }

                // Action buttons
                actionButtons

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.lg)
        }
    }

    // MARK: - Score Section

    private func scoreSection(viewModel: QuizResultsViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            ScoreGauge(
                score: viewModel.scorePercentage,
                size: 180,
                label: viewModel.isHighScore ? "Excellent!" : "Keep Going"
            )

            if viewModel.isHighScore {
                Text("You passed!")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.success)
            } else {
                Text("Almost there!")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.warning)
            }
        }
    }

    // MARK: - Score Summary

    private func scoreSummary(viewModel: QuizResultsViewModel) -> some View {
        HStack(spacing: Spacing.md) {
            scoreStat(
                icon: "checkmark.circle.fill",
                color: ColorTokens.success,
                value: "\(viewModel.score?.correct ?? 0)",
                label: "Correct"
            )

            scoreStat(
                icon: "xmark.circle.fill",
                color: ColorTokens.error,
                value: "\(viewModel.score?.incorrect ?? 0)",
                label: "Incorrect"
            )

            scoreStat(
                icon: "minus.circle.fill",
                color: ColorTokens.textTertiaryDark,
                value: "\(viewModel.score?.skipped ?? 0)",
                label: "Skipped"
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    private func scoreStat(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Trend Section

    private func trendSection(trendText: String, comparison: ComparisonToPrevious?) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: trendIcon(comparison?.trend))
                .foregroundStyle(trendColor(comparison?.trend))

            Text(trendText)
                .font(Typography.bodyBold)
                .foregroundStyle(trendColor(comparison?.trend))

            Spacer()
        }
        .padding(Spacing.md)
        .background(trendColor(comparison?.trend).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
    }

    private func trendIcon(_ trend: Trend?) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .none: return "arrow.right"
        }
    }

    private func trendColor(_ trend: Trend?) -> Color {
        switch trend {
        case .improving: return ColorTokens.success
        case .declining: return ColorTokens.error
        case .stable: return ColorTokens.info
        case .none: return ColorTokens.textSecondaryDark
        }
    }

    // MARK: - Topic Breakdown Section

    private func topicBreakdownSection(breakdown: [TopicBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Topic Breakdown")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)

            ForEach(breakdown, id: \.topic) { topic in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(topic.topic)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textPrimaryDark)

                        Spacer()

                        Text("\(topic.correct)/\(topic.total)")
                            .font(Typography.mono)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorTokens.surfaceElevatedDark)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(percentage: topic.percentage))
                                .frame(width: geo.size.width * (topic.percentage / 100))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private func barColor(percentage: Double) -> Color {
        switch percentage {
        case 80...100: return ColorTokens.success
        case 60..<80: return ColorTokens.primary
        case 40..<60: return ColorTokens.warning
        default: return ColorTokens.error
        }
    }

    // MARK: - Strengths Section

    private func strengthsSection(strengths: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Strengths")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)

            FlowLayout(spacing: Spacing.sm) {
                ForEach(strengths, id: \.self) { strength in
                    Text(strength)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.success)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(ColorTokens.success.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(ColorTokens.success.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Weaknesses Section

    private func weaknessesSection(weaknesses: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Areas to Improve")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)

            FlowLayout(spacing: Spacing.sm) {
                ForEach(weaknesses, id: \.self) { weakness in
                    Text(weakness)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.error)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(ColorTokens.error.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(ColorTokens.error.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Missed Concepts Section

    private func missedConceptsSection(concepts: [MissedConcept]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Missed Concepts")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)

            ForEach(Array(concepts.enumerated()), id: \.offset) { _, concept in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.warning)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(concept.concept ?? "Unknown concept")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textPrimaryDark)

                        if let suggestion = concept.suggestion {
                            Text(suggestion)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                        }
                    }

                    Spacer()

                    if concept.contentId != nil {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.primary)
                    }
                }
                .padding(Spacing.md)
                .background(ColorTokens.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(title: "Review Answers") {
                showReview = true
            }
            .padding(.horizontal, Spacing.md)

            PrimaryButton(title: "Back to Learning") {
                dismiss()
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}

// MARK: - Celebration Overlay

private struct CelebrationOverlay: View {
    @State private var particles: [CelebrationParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                animateParticles()
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        let colors: [Color] = [
            ColorTokens.primary,
            ColorTokens.primaryLight,
            ColorTokens.success,
            ColorTokens.anchorGold,
            ColorTokens.warning,
            Color(hex: "#FD79A8"),
        ]

        particles = (0..<40).map { _ in
            CelebrationParticle(
                id: UUID(),
                color: colors.randomElement() ?? ColorTokens.primary,
                size: CGFloat.random(in: 6...14),
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: size.height + 20
                ),
                targetY: CGFloat.random(in: -50...size.height * 0.4),
                opacity: 1.0
            )
        }
    }

    private func animateParticles() {
        for index in particles.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 1.5...2.5)

            withAnimation(
                .spring(duration: duration, bounce: 0.2)
                .delay(delay)
            ) {
                particles[index].position.y = particles[index].targetY
                particles[index].position.x += CGFloat.random(in: -60...60)
            }

            withAnimation(
                .easeOut(duration: 0.8)
                .delay(delay + duration * 0.6)
            ) {
                particles[index].opacity = 0
            }
        }
    }
}

// MARK: - Celebration Particle

private struct CelebrationParticle: Identifiable {
    let id: UUID
    let color: Color
    let size: CGFloat
    var position: CGPoint
    let targetY: CGFloat
    var opacity: Double
}
