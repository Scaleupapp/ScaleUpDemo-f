import SwiftUI

struct InterviewResultsView: View {
    @Bindable var viewModel: InterviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scoreAnimated = false
    @State private var showNewInterview = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.state == .evaluating || viewModel.state == .saving {
                evaluatingState
            } else if let evaluation = viewModel.evaluation {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Close button
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }

                        scoreCircle(evaluation)
                        subScores(evaluation)
                        summarySection(evaluation)
                        strengthsAndImprovements(evaluation)
                        integrityBadge(evaluation)
                        perQuestionSection(evaluation)

                        // Back to profile button
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back to Profile")
                                    .font(Typography.bodyBold)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ColorTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        .buttonStyle(.plain)

                        newInterviewButton
                        Spacer().frame(height: Spacing.xxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                }
            } else if case .error(let msg) = viewModel.state {
                errorState(msg)
            }
        }
        .fullScreenCover(isPresented: $showNewInterview) {
            InterviewSessionView(viewModel: InterviewViewModel())
        }
    }

    // MARK: - Evaluating State

    private var evaluatingState: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ColorTokens.gold)
            }

            Text(viewModel.state == .saving ? "Saving interview..." : "AI is evaluating your performance...")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("This may take a minute. We're analyzing communication,\ncontent quality, structure, and confidence.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Score Circle

    private func scoreCircle(_ evaluation: InterviewEvaluation) -> some View {
        VStack(spacing: Spacing.md) {
            Text("Interview Complete")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            ZStack {
                // Background circle
                Circle()
                    .stroke(ColorTokens.surfaceElevated, lineWidth: 10)
                    .frame(width: 140, height: 140)

                // Score arc
                Circle()
                    .trim(from: 0, to: scoreAnimated ? scoreProgress(evaluation) : 0)
                    .stroke(
                        scoreColor(evaluation),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: scoreAnimated)

                // Score text
                VStack(spacing: 2) {
                    Text("\(evaluation.overallScore ?? 0)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(evaluation))
                    Text("/ 100")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scoreAnimated = true
                }
            }

            // Rating label
            Text(scoreLabel(evaluation))
                .font(Typography.bodyBold)
                .foregroundStyle(scoreColor(evaluation))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(scoreColor(evaluation).opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private func scoreProgress(_ evaluation: InterviewEvaluation) -> CGFloat {
        CGFloat(evaluation.overallScore ?? 0) / 100.0
    }

    private func scoreColor(_ evaluation: InterviewEvaluation) -> Color {
        let score = evaluation.overallScore ?? 0
        if score >= 70 { return ColorTokens.success }
        if score >= 40 { return ColorTokens.warning }
        return ColorTokens.error
    }

    private func scoreLabel(_ evaluation: InterviewEvaluation) -> String {
        let score = evaluation.overallScore ?? 0
        if score >= 85 { return "Excellent" }
        if score >= 70 { return "Good" }
        if score >= 55 { return "Average" }
        if score >= 40 { return "Below Average" }
        return "Needs Improvement"
    }

    // MARK: - Sub Scores

    private func subScores(_ evaluation: InterviewEvaluation) -> some View {
        VStack(spacing: Spacing.md) {
            Text("BREAKDOWN")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: Spacing.sm) {
                subScoreBar(label: "Communication", subScore: evaluation.communication, icon: "bubble.left.and.bubble.right.fill")
                subScoreBar(label: "Content", subScore: evaluation.content, icon: "doc.text.fill")
                subScoreBar(label: "Structure", subScore: evaluation.structure, icon: "list.bullet.rectangle.fill")
                subScoreBar(label: "Confidence", subScore: evaluation.confidence, icon: "person.fill.checkmark")
            }
            .padding(Spacing.md)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }

    private func subScoreBar(label: String, subScore: InterviewSubScore?, icon: String) -> some View {
        let score = subScore?.score ?? 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(barColor(score))
                Text(label)
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text("\(score)/100")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(barColor(score))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.surfaceElevated)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(score))
                        .frame(width: geo.size.width * (scoreAnimated ? CGFloat(score) / 100.0 : 0))
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: scoreAnimated)
                }
            }
            .frame(height: 6)
        }
    }

    private func barColor(_ score: Int) -> Color {
        if score >= 70 { return ColorTokens.success }
        if score >= 40 { return ColorTokens.warning }
        return ColorTokens.error
    }

    // MARK: - Summary

    private func summarySection(_ evaluation: InterviewEvaluation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SUMMARY")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .tracking(1)

            if let summary = evaluation.summary {
                Text(summary)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineSpacing(4)
                    .padding(Spacing.md)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
        }
    }

    // MARK: - Strengths & Improvements

    private func strengthsAndImprovements(_ evaluation: InterviewEvaluation) -> some View {
        VStack(spacing: Spacing.md) {
            // Strengths
            if let strengths = evaluation.overallStrengths, !strengths.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("STRENGTHS")
                        .font(Typography.captionBold)
                        .foregroundStyle(ColorTokens.success)
                        .tracking(1)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(strengths, id: \.self) { strength in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ColorTokens.success)
                                    .padding(.top, 2)
                                Text(strength)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.success.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(ColorTokens.success.opacity(0.2), lineWidth: 1)
                    )
                }
            }

            // Improvements
            if let improvements = evaluation.overallImprovements, !improvements.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("AREAS TO IMPROVE")
                        .font(Typography.captionBold)
                        .foregroundStyle(ColorTokens.warning)
                        .tracking(1)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(improvements, id: \.self) { item in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ColorTokens.warning)
                                    .padding(.top, 2)
                                Text(item)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(ColorTokens.warning.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Integrity Badge

    private func integrityBadge(_ evaluation: InterviewEvaluation) -> some View {
        Group {
            if let report = evaluation.integrityReport {
                let integrity = report.overallIntegrity ?? "clean"
                let isClean = integrity == "clean"
                let isSuspicious = integrity == "suspicious"
                let tintColor = isClean ? ColorTokens.success : isSuspicious ? ColorTokens.error : ColorTokens.warning

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: isClean ? "shield.checkmark.fill" : isSuspicious ? "exclamationmark.shield.fill" : "shield.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(tintColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Interview Integrity")
                                .font(Typography.bodySmallBold)
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text(isClean ? "Clean" : isSuspicious ? "Suspicious" : "Minor Flags")
                                .font(Typography.caption)
                                .foregroundStyle(tintColor)
                        }

                        Spacer()

                        Text(isClean ? "No issues" : "\(report.flags?.count ?? 0) flags")
                            .font(Typography.captionBold)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    // Show individual flag descriptions
                    if let flags = report.flags, !flags.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(flags, id: \.self) { flag in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(tintColor)
                                        .padding(.top, 2)
                                    Text(flag)
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Show recommendation
                    if let rec = report.recommendation, !rec.isEmpty {
                        Text(rec)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .italic()
                            .padding(.top, 2)
                    }
                }
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(tintColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Per-Question Section

    private func perQuestionSection(_ evaluation: InterviewEvaluation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let questions = evaluation.perQuestion, !questions.isEmpty {
                Text("QUESTION-BY-QUESTION")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .tracking(1)

                ForEach(questions) { q in
                    questionAccordion(q)
                }
            }
        }
    }

    private func questionAccordion(_ q: PerQuestionFeedback) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Answer summary
                if let answer = q.answer, !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Answer")
                            .font(Typography.captionBold)
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(answer)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineSpacing(3)
                    }
                }

                // Feedback
                if let feedback = q.feedback, !feedback.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Feedback")
                            .font(Typography.captionBold)
                            .foregroundStyle(ColorTokens.gold)
                        Text(feedback)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineSpacing(3)
                    }
                }

                // Strengths
                if let strengths = q.strengths, !strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(strengths, id: \.self) { s in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(ColorTokens.success)
                                Text(s)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                }

                // Model Answer
                if let modelAnswer = q.modelAnswer, !modelAnswer.isEmpty {
                    DisclosureGroup {
                        Text(modelAnswer)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineSpacing(3)
                            .padding(.top, 4)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.gold)
                            Text("View Model Answer")
                                .font(Typography.captionBold)
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }
                    .tint(ColorTokens.gold)
                }
            }
            .padding(.top, Spacing.sm)
        } label: {
            HStack(spacing: Spacing.sm) {
                Text("Q\(q.questionNumber)")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 28)

                Text(q.question ?? "Question \(q.questionNumber)")
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                if let score = q.score {
                    Text("\(score)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(barColor(score))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(barColor(score).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .tint(ColorTokens.textTertiary)
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - New Interview Button

    private var newInterviewButton: some View {
        Button {
            Haptics.medium()
            showNewInterview = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("Start New Interview")
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(ColorTokens.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ColorTokens.gold)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.warning)

            Text("Something went wrong")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            newInterviewButton
                .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }
}
