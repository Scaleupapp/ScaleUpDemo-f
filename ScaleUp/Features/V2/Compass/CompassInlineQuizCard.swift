import SwiftUI

struct CompassInlineQuizCard: View {
    @Bindable var model: CompassInlineQuizModel
    let onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.phase {
            case .generating:
                Label("Building your check\u{2026}", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.gold)
                ProgressView().tint(ColorTokens.gold)

            case .taking:
                if let q = model.currentQuestion {
                    Text("Check \u{00B7} \(model.currentIndex + 1)/\(model.totalQuestions)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTokens.gold)
                    Text(q.questionText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    ForEach(q.options, id: \.stableId) { opt in
                        Button {
                            Task { await model.choose(opt.label) }
                        } label: {
                            HStack {
                                Text("\(opt.label).").fontWeight(.bold)
                                Text(opt.text)
                                Spacer()
                            }
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

            case .completing:
                Label("Scoring\u{2026}", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.gold)
                ProgressView().tint(ColorTokens.gold)

            case .done:
                if let rq = model.reviewedQuiz {
                    Text("Check: \(Int((model.checkScore ?? 0).rounded()))%")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    ForEach(Array(rq.questions.enumerated()), id: \.offset) { idx, q in
                        let mine = model.answers[idx]
                        let correct = q.correctAnswer
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: mine == correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(mine == correct ? .green : .red)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.questionText)
                                    .font(.caption)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                if mine != correct, let ex = q.explanation {
                                    Text(ex)
                                        .font(.caption2)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }
                        }
                    }
                }

            case .failed:
                Text(model.errorMessage ?? "Couldn't run the check.")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(12)
        .background(ColorTokens.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ColorTokens.gold.opacity(0.2), lineWidth: 1)
        )
        .onChange(of: model.phase) { _, newPhase in
            if newPhase == .done || newPhase == .failed {
                onFinished()
            }
        }
    }
}
