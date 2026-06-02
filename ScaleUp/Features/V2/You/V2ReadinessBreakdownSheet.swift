import SwiftUI

/// "What's in your number" — the readiness breakdown sheet.
///
/// Surfaces the redesign's two new explainers:
///  • P1b: the per-competency rollup behind the composite readiness score
///    (`readiness.breakdown`) — what's measured, how you scored, what's a gap.
///  • P2: the personalized target and its Competitive / Strong / Exceptional
///    bands (`readiness.target` + `readiness.targetBands`) — "why this target".
///
/// Degrades gracefully: when there's no composite yet (`breakdown == nil`, i.e.
/// the user hasn't been assessed), we explain how to start building a real number
/// instead of showing an empty list.
struct V2ReadinessBreakdownSheet: View {
    let readiness: V2YouOverview.ReadinessBlock
    @Environment(\.dismiss) private var dismiss

    private var items: [V2YouOverview.ReadinessBlock.BreakdownItem] { readiness.breakdown ?? [] }
    private var assessed: [V2YouOverview.ReadinessBlock.BreakdownItem] { items.filter { $0.assessed } }
    private var gaps: [V2YouOverview.ReadinessBlock.BreakdownItem] { items.filter { !$0.assessed } }
    private var hasComposite: Bool { !items.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    scoreHeader
                    if let bands = readiness.targetBands {
                        targetBandsCard(bands: bands)
                    }
                    if hasComposite {
                        if !assessed.isEmpty {
                            competencySection(title: "What's shaping your number", items: assessed)
                        }
                        if !gaps.isEmpty {
                            competencySection(title: "Not measured yet", items: gaps)
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(20)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Your readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
    }

    // MARK: - Score + coverage header

    private var scoreHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(readiness.score)%")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                if let target = readiness.target {
                    Text("/ \(target)% target")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            Text(readiness.onTrackText)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
            if !items.isEmpty {
                Text(items.count == assessed.count
                     ? "Based on all \(items.count) skills this goal needs."
                     : "Based on \(assessed.count) of \(items.count) skills measured so far.")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Target bands ("why this target")

    private func targetBandsCard(bands: V2YouOverview.ReadinessBlock.TargetBands) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHY THIS TARGET")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(ColorTokens.gold)
            Text("Most people need to clear the Strong band to hit this goal. Here's where you stand:")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
            bandRow(label: "Competitive", value: bands.competitive)
            bandRow(label: "Strong", value: bands.strong, highlight: true)
            bandRow(label: "Exceptional", value: bands.exceptional)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ColorTokens.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(ColorTokens.surfaceElevated.opacity(0.7), lineWidth: 1))
    }

    private func bandRow(label: String, value: Int, highlight: Bool = false) -> some View {
        let reached = readiness.score >= value
        return HStack(spacing: 10) {
            Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(reached ? ColorTokens.gold : ColorTokens.textTertiary)
            Text(label)
                .font(.system(size: 14, weight: highlight ? .semibold : .regular))
                .foregroundStyle(highlight ? ColorTokens.textPrimary : ColorTokens.textSecondary)
            Spacer()
            Text("\(value)%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(reached ? ColorTokens.gold : ColorTokens.textSecondary)
        }
    }

    // MARK: - Competency breakdown

    private func competencySection(title: String, items: [V2YouOverview.ReadinessBlock.BreakdownItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(ColorTokens.gold)
            ForEach(items) { competencyRow($0) }
        }
    }

    private func competencyRow(_ item: V2YouOverview.ReadinessBlock.BreakdownItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if item.assessed {
                    Text("\(item.score)%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(scoreColor(item.score))
                } else {
                    Text("Not measured")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.surfaceElevated).frame(height: 6)
                    if item.assessed {
                        Capsule().fill(scoreColor(item.score))
                            .frame(width: max(6, geo.size.width * CGFloat(min(100, max(0, item.score))) / 100.0), height: 6)
                    }
                }
            }
            .frame(height: 6)
            Text("\(primitiveLabel(item.primitive)) · weight \(item.weight)")
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Empty state (no assessments yet)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BUILD YOUR NUMBER")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(ColorTokens.gold)
            Text("Your readiness gets sharper as you're assessed. Take a quiz or finish your diagnostic, and you'll see exactly which skills are shaping your number — and which to work on next.")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ColorTokens.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(ColorTokens.surfaceElevated.opacity(0.7), lineWidth: 1))
    }

    // MARK: - Helpers

    private func scoreColor(_ s: Int) -> Color {
        if s >= 70 { return ColorTokens.success }
        if s >= 40 { return ColorTokens.warning }
        return ColorTokens.error
    }

    private func primitiveLabel(_ p: String) -> String {
        switch p {
        case "coding": return "Coding"
        case "interview": return "Interview"
        default: return "Quiz"
        }
    }
}
