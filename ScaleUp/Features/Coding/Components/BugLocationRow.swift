import SwiftUI

struct BugLocationRow: View {
    @Binding var location: BugLocation
    let index: Int
    let onDelete: () -> Void

    @FocusState private var fileFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bug \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete bug \(index + 1)")
            }

            HStack(spacing: 8) {
                fileField
                lineField
            }

            explanationField
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Subviews

    private var fileField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("File")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("e.g. main.js", text: $location.file)
                .font(.system(.subheadline, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($fileFocused)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lineField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Line")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("42", value: $location.line, format: .number)
                .font(.system(.subheadline, design: .monospaced))
                .keyboardType(.numberPad)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(width: 80, alignment: .leading)
    }

    private var explanationField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Explanation")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(
                "What's wrong + why an LLM would do this",
                text: $location.explanation,
                axis: .vertical
            )
            .lineLimit(2...5)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
