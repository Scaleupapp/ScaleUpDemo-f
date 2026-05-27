import SwiftUI

struct DrillBriefView: View {
    let drill: DrillTodayResponse
    let onStart: () -> Void

    private var codeBlocks: [CodeBlock] {
        CodeBlock.parse(from: drill.brief)
    }

    private var proseBrief: String {
        CodeBlock.stripCodeBlocks(from: drill.brief)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                badgeRow

                // Prose portion of the brief
                if !proseBrief.isEmpty {
                    Text(proseBrief)
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Code blocks, if any
                if !codeBlocks.isEmpty {
                    CodeViewer(blocks: codeBlocks)
                } else if proseBrief.isEmpty {
                    // Fallback: no code fences and no stripped prose → show raw brief
                    Text(drill.brief)
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let criteria = drill.acceptanceCriteria, !criteria.isEmpty {
                    acceptanceList(criteria)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            startButton
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
    }

    private var badgeRow: some View {
        HStack(spacing: 8) {
            badge(text: drill.drillSubtype.displayName, icon: drill.drillSubtype.iconName)
            badge(text: "\(drill.timeBudgetMinutes) min", icon: "clock")
            badge(text: drill.difficulty.rawValue.capitalized, icon: "chart.bar.fill")
        }
    }

    private func badge(text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.gray.opacity(0.15)))
    }

    private func acceptanceList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What we're looking for")
                .font(.headline)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.tint)
                    Text(item)
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var startButton: some View {
        Button(action: onStart) {
            HStack(spacing: 8) {
                Text("Start")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
