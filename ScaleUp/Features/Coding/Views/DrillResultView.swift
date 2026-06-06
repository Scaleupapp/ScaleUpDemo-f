import SwiftUI

struct DrillResultView: View {
    let grade: DrillResultGradedResponse
    let onDone: () -> Void

    @State private var animatedScore: Int = 0
    @State private var showMasteryBadge = false
    @State private var showWhatYouMissed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                scoreCard
                rubricSection
                whatToTryNextCard
                whatYouMissedSection

                nextStepCard

                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            doneButton
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
        .overlay(alignment: .bottom) {
            if showMasteryBadge {
                MasteryDeltaBadge(axis: nil, delta: nil)  // placeholder — see comment
                    .padding(.bottom, 80)
            }
        }
        .onAppear {
            // Animate the score counting up
            animateScore()
            // Show the mastery badge after a brief delay (placeholder for now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.5)) {
                    showMasteryBadge = true
                }
            }
        }
    }

    // MARK: - Score card

    private var scoreCard: some View {
        VStack(spacing: 4) {
            Text("Score")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(animatedScore)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(animatedScore)))
                Text("/ 100")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            scoreVerdict
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var scoreVerdict: some View {
        let s = grade.overallScore
        let (text, color) = scoreVerdictDetails(s)
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
    }

    private func scoreVerdictDetails(_ s: Int) -> (String, Color) {
        switch s {
        case 85...: return ("Excellent work", .green)
        case 70..<85: return ("Solid attempt", .blue)
        case 50..<70: return ("Getting there", .orange)
        default: return ("Room to grow", .red)
        }
    }

    // MARK: - Rubric section

    private var rubricSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How you did")
                .font(.headline)

            VStack(spacing: 14) {
                ForEach(grade.rubricBreakdown, id: \.dimension) { item in
                    RubricBar(
                        dimension: item.dimension,
                        score: item.score,
                        feedback: item.feedback
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - What to try next

    @ViewBuilder
    private var whatToTryNextCard: some View {
        if let next = grade.whatToTryNext, !next.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("What to try next time", systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(next)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - What you missed

    private var weakestDimension: String? {
        grade.rubricBreakdown.min(by: { $0.score < $1.score })?.dimension
    }

    @ViewBuilder private var nextStepCard: some View {
        if let pretty = weakestDimension?.replacingOccurrences(of: "_", with: " ").capitalized {
            NextStepCard(
                lead: "Your weakest area was",
                highlight: pretty,
                actionTitle: "Practice another drill"
            ) {
                NextStepCoordinator.shared.fire(.launchDrill(subtype: nil))
                onDone()
            }
        }
    }

    @ViewBuilder
    private var whatYouMissedSection: some View {
        let items = grade.whatYouMissed ?? []
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                DisclosureGroup(isExpanded: $showWhatYouMissed) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(items) { item in
                            whatYouMissedCard(item)
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    HStack {
                        Label("What you missed (\(items.count))", systemImage: "eye.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        // Empty array → render nothing; the result was complete enough that there's nothing to flag.
    }

    private func whatYouMissedCard(_ item: WhatYouMissedItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let ref = item.reference, !ref.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                                .foregroundStyle(.tint)
                            Text(ref)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Done button

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func animateScore() {
        let target = grade.overallScore
        let duration: Double = 0.9
        let steps = 30
        let stepDuration = duration / Double(steps)
        let increment = max(1, target / steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                if i == steps {
                    animatedScore = target
                } else {
                    animatedScore = min(target, increment * i)
                }
            }
        }
    }
}

#Preview {
    DrillResultView(
        grade: DrillResultGradedResponse(
            attemptId: "preview-123",
            status: "graded",
            overallScore: 78,
            rubricBreakdown: [
                RubricItem(dimension: "prompt_clarity", score: 8.0, feedback: "Clear and well-scoped prompt."),
                RubricItem(dimension: "ai_pair_effectiveness", score: 7.5, feedback: "Good back-and-forth."),
                RubricItem(dimension: "output_quality", score: 6.0, feedback: "Could validate edge cases.")
            ],
            whatToTryNext: "Try constraining the prompt further — specify the output format explicitly to reduce AI hallucinations.",
            whatYouMissed: [
                WhatYouMissedItem(title: "Missing null-check on userInput", detail: "The prompt didn't guard against null — the grader expected you to explicitly handle that case.", reference: "if (userInput == null) return DEFAULT_RESPONSE;"),
                WhatYouMissedItem(title: "No token-budget constraint", detail: "Reference answer included a max_tokens cap. Omitting it can cause runaway completions in production.", reference: nil)
            ],
            integrityConfidence: "high",
            gradedAt: "2026-05-27T10:00:00Z",
            drillSubtype: .prompt,
            difficulty: .medium,
            roleTrack: .ai_eng
        ),
        onDone: {}
    )
}
