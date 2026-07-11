import SwiftUI

/// Student result detail for a graded placement assessment.
/// Shown when tapping a row with session.status == "graded".
/// Displays score, integrity, and a breakdown from session.result.raw.
struct PlacementAssessmentResultView: View {
    let row: PlacementAssessmentRow
    @Environment(\.dismiss) private var dismiss
    @Environment(V2TaskRouter.self) private var taskRouter

    private var result: PlacementSessionResult? { row.session?.result }
    private var windowClosed: Bool { row.windowClosed == true }

    @State private var review: PlacementReviewResponse?
    @State private var isLoadingReview = false
    @State private var showCapstone = false

    /// Weakest competency derived from the MCQ competency breakdown (if present).
    private var weakestCompetency: (name: String, score: Double)? {
        guard let breakdown = result?.raw?.competencyBreakdown, !breakdown.isEmpty else { return nil }
        let sorted = breakdown.sorted { $0.value < $1.value }
        guard let first = sorted.first else { return nil }
        return (name: first.key, score: first.value)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    scoreSection

                    if windowClosed {
                        if let raw = result?.raw {
                            breakdownSection(raw: raw)
                        }
                        questionReviewSection
                    } else {
                        Text("Detailed review unlocks once the assessment closes.")
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    // Recommended practice — always visible (practice is private).
                    if let weakest = weakestCompetency {
                        recommendedPracticeBlock(competency: weakest.name, score: weakest.score)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Your Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadReview() }
        }
        .sheet(isPresented: $showCapstone) {
            NavigationStack {
                V2CodingHubView(onClose: { showCapstone = false }, initialSegment: .capstones)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Recommended practice block

    private func recommendedPracticeBlock(competency: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("Recommended practice")
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            Text("You scored \(Int(score.rounded()))% on \(competency.replacingOccurrences(of: "_", with: " ").capitalized). Practice privately to improve — this won't affect your official scores.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                taskRouter.route = .quizByTopic(topic: competency, weekNumber: nil)
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "bolt.fill")
                    Text("Practice \(competency.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(V2Theme.bodyMedium)
                    Spacer()
                }
                .foregroundStyle(ColorTokens.background)
                .padding(.vertical, 13)
                .background(ColorTokens.gold)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ColorTokens.gold.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Review loading

    private func loadReview() async {
        guard windowClosed, review == nil, !isLoadingReview else { return }
        guard let sessionId = row.session?.id else { return }
        isLoadingReview = true
        defer { isLoadingReview = false }
        review = try? await PlacementsAssessmentsApi.shared.fetchReview(sessionId: sessionId)
    }

    // MARK: - Score

    /// Wave 3: not enough interview evidence to produce a grade.
    private var isInsufficient: Bool { result?.gradeStatus == "insufficient" }
    /// Wave 3: score is being human-reviewed before it's final.
    private var needsReview: Bool { result?.needsReview == true }

    @ViewBuilder
    private var scoreSection: some View {
        if isInsufficient {
            insufficientSection
        } else {
            gradedScoreSection
        }
    }

    /// Shown instead of a score when there isn't enough interview evidence.
    private var insufficientSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 34))
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Not enough interview evidence to grade")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text("Contact your placement office.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 2) {
                Text(row.assessment.title)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                Text(row.assessment.type.uppercased())
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var gradedScoreSection: some View {
        VStack(spacing: 18) {
            if needsReview {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Score under review")
                        .font(V2Theme.small)
                }
                .foregroundStyle(ColorTokens.background)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(ColorTokens.gold))
            }

            // Score ring + integrity
            HStack(spacing: 28) {
                if let score = result?.score {
                    scoreRing(score)
                }

                if let integrity = result?.integrity {
                    VStack(spacing: 4) {
                        Image(systemName: integrityIcon(integrity))
                            .font(.system(size: 28))
                            .foregroundStyle(integrityColor(integrity))
                        Text(integrity.capitalized)
                            .font(.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text("Integrity")
                            .font(.caption2)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            // Assessment info
            VStack(spacing: 4) {
                Text(row.assessment.title)
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                Text(row.assessment.type.uppercased())
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scoreRing(_ score: Double) -> some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.surface, lineWidth: 9)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(score.rounded()))%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("SCORE")
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .frame(width: 108, height: 108)
    }

    // MARK: - Breakdown

    @ViewBuilder
    private func breakdownSection(raw: PlacementResultRaw) -> some View {
        // Drill: rubric breakdown + what you missed
        if let rubric = raw.rubricBreakdown, !rubric.isEmpty {
            drillBreakdown(rubric: rubric, whatYouMissed: raw.whatYouMissed)
        }

        // Interview: dimensions
        if let dims = raw.dimensions, !dims.isEmpty {
            dimensionBreakdown(title: "Interview Dimensions", dimensions: dims)
        }

        // Capstone: dimension scores
        if let dims = raw.dimensionScores, !dims.isEmpty {
            dimensionBreakdown(title: "Dimension Scores", dimensions: dims)
        }

        // MCQ: competency breakdown
        if let competency = raw.competencyBreakdown, !competency.isEmpty {
            mcqBreakdown(competency: competency)
        }
    }

    private func drillBreakdown(rubric: [RubricItem], whatYouMissed: [WhatYouMissedItem]?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rubric Breakdown")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)

            VStack(spacing: 10) {
                ForEach(rubric, id: \.dimension) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.dimension.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textPrimary)
                            if let feedback = item.feedback, !feedback.isEmpty {
                                Text(feedback)
                                    .font(V2Theme.tiny)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                        Spacer()
                        Text(String(format: "%.0f", item.score))
                            .font(V2Theme.h3)
                            .foregroundStyle(scoreColor(item.score))
                    }
                    .padding(12)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            if let missed = whatYouMissed, !missed.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What You Missed (\(missed.count))")
                        .font(V2Theme.h3)
                        .foregroundStyle(ColorTokens.textPrimary)
                    ForEach(missed) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(V2Theme.small)
                                .bold()
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text(item.detail)
                                .font(V2Theme.tiny)
                                .foregroundStyle(ColorTokens.textSecondary)
                            if let ref = item.reference, !ref.isEmpty {
                                Text(ref)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(ColorTokens.textPrimary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func dimensionBreakdown(title: String, dimensions: [PlacementResultDimension]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            VStack(spacing: 14) {
                ForEach(dimensions) { dim in
                    competencyBar(
                        name: dim.name,
                        value: dim.score,
                        feedback: dim.feedback,
                        suffix: ""
                    )
                }
            }
            .padding(14)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func mcqBreakdown(competency: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Competency Breakdown")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            VStack(spacing: 14) {
                ForEach(competency.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    competencyBar(name: key, value: value, feedback: nil, suffix: "%")
                }
            }
            .padding(14)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// A clean labelled progress bar used by the dimension and competency breakdowns.
    @ViewBuilder
    private func competencyBar(name: String, value: Double?, feedback: String?, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer(minLength: 8)
                if let value {
                    Text(suffix == "%" ? String(format: "%.0f%%", value) : String(format: "%.0f", value))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(scoreColor(value))
                }
            }
            if let value {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ColorTokens.surface)
                            .frame(height: 6)
                        Capsule()
                            .fill(scoreColor(value))
                            .frame(width: geo.size.width * CGFloat(max(0, min(100, value)) / 100), height: 6)
                    }
                }
                .frame(height: 6)
            }
            if let feedback, !feedback.isEmpty {
                Text(feedback)
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Question Review

    @ViewBuilder
    private var questionReviewSection: some View {
        if isLoadingReview && review == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else if let questions = review?.questions, !questions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Question Review")
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)

                ForEach(questions) { question in
                    questionCard(question)
                }
            }
        }
    }

    private func questionCard(_ question: PlacementReviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(question.index + 1). \(question.questionText)")
                .font(V2Theme.small)
                .bold()
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let scenario = question.scenario, !scenario.isEmpty {
                Text(scenario)
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if question.studentAnswer == nil {
                Text("Not answered")
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.error)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(question.options, id: \.label) { option in
                    optionRow(option, question: question)
                }
            }

            if let explanation = question.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func optionRow(_ option: PlacementReviewOption, question: PlacementReviewQuestion) -> some View {
        let isCorrect = option.label == question.correctAnswer
        let isStudentPick = option.label == question.studentAnswer
        let isWrongPick = isStudentPick && !isCorrect

        HStack(alignment: .top, spacing: 8) {
            if isCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.success)
            } else if isWrongPick {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ColorTokens.error)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Text("\(option.label). \(option.text)\(isWrongPick ? " (your answer)" : "")")
                .font(V2Theme.tiny)
                .foregroundStyle(optionColor(isCorrect: isCorrect, isWrongPick: isWrongPick))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(optionBackground(isCorrect: isCorrect, isWrongPick: isWrongPick))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func optionColor(isCorrect: Bool, isWrongPick: Bool) -> Color {
        if isCorrect { return ColorTokens.success }
        if isWrongPick { return ColorTokens.error }
        return ColorTokens.textPrimary
    }

    private func optionBackground(isCorrect: Bool, isWrongPick: Bool) -> Color {
        if isCorrect { return ColorTokens.success.opacity(0.12) }
        if isWrongPick { return ColorTokens.error.opacity(0.10) }
        return Color.clear
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 85...: return ColorTokens.success
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return ColorTokens.error
        }
    }

    private func integrityIcon(_ integrity: String) -> String {
        switch integrity.lowercased() {
        case "high": return "checkmark.shield.fill"
        case "medium": return "shield.fill"
        default: return "shield.slash.fill"
        }
    }

    private func integrityColor(_ integrity: String) -> Color {
        switch integrity.lowercased() {
        case "high": return ColorTokens.success
        case "medium": return .orange
        default: return ColorTokens.error
        }
    }
}
