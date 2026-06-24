import SwiftUI

/// Student result detail for a graded placement assessment.
/// Shown when tapping a row with session.status == "graded".
/// Displays score, integrity, and a breakdown from session.result.raw.
struct PlacementAssessmentResultView: View {
    let row: PlacementAssessmentRow
    @Environment(\.dismiss) private var dismiss

    private var result: PlacementSessionResult? { row.session?.result }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    scoreSection
                    if let raw = result?.raw {
                        breakdownSection(raw: raw)
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
        }
    }

    // MARK: - Score

    private var scoreSection: some View {
        VStack(spacing: 16) {
            // Score + integrity
            HStack(spacing: 24) {
                if let score = result?.score {
                    VStack(spacing: 4) {
                        Text("\(Int(score.rounded()))%")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(score))
                        Text("Score")
                            .font(.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
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
            .padding(.vertical, 8)

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
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            ForEach(dimensions) { dim in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dim.name.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textPrimary)
                        if let feedback = dim.feedback, !feedback.isEmpty {
                            Text(feedback)
                                .font(V2Theme.tiny)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                    Spacer()
                    if let score = dim.score {
                        Text(String(format: "%.0f", score))
                            .font(V2Theme.h3)
                            .foregroundStyle(scoreColor(score))
                    }
                }
                .padding(12)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func mcqBreakdown(competency: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Competency Breakdown")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            ForEach(competency.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", value))
                        .font(V2Theme.h3)
                        .foregroundStyle(scoreColor(value))
                }
                .padding(12)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
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
