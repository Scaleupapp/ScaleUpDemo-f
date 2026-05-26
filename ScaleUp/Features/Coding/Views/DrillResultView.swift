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

    // MARK: - What you missed (placeholder)

    private var whatYouMissedSection: some View {
        DisclosureGroup(isExpanded: $showWhatYouMissed) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This section will reveal seeded bugs you missed (for verify drills) or reference-answer elements you didn't include (for prompt/decompose).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Backend follow-up: graded response needs a `what_you_missed` array.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("What you missed", systemImage: "eye.fill")
                .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            integrityConfidence: "high",
            gradedAt: "2026-05-26T10:00:00Z",
            drillSubtype: .prompt,
            difficulty: .medium,
            roleTrack: .ai_eng
        ),
        onDone: {}
    )
}
