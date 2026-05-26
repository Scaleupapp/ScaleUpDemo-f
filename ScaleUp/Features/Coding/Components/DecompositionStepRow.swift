import SwiftUI

struct DecompositionStepRow: View {
    @Binding var step: DecompositionStep
    let index: Int
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                stepBadge
                Text("Step \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete step \(index + 1)")
                }
            }

            stepField
            rationaleField
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var stepBadge: some View {
        Text("\(index + 1)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Color.accentColor)
            .clipShape(Circle())
    }

    private var stepField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What to do")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(
                "e.g. Define the API contract — defaults, max page size, response shape",
                text: $step.step,
                axis: .vertical
            )
            .lineLimit(1...4)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var rationaleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Why this step exists / why here")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(
                "e.g. Other steps depend on these numbers; agreeing early prevents conflicts later",
                text: $step.rationale,
                axis: .vertical
            )
            .lineLimit(1...3)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
