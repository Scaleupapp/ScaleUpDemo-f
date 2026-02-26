import SwiftUI

struct TagCloud: View {
    let availableTags: [String]
    @Binding var selectedTags: [String]
    var allowCustom: Bool = false

    @State private var customTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            FlowLayout(spacing: Spacing.sm) {
                ForEach(availableTags, id: \.self) { tag in
                    TagChip(
                        title: tag,
                        isSelected: selectedTags.contains(tag)
                    ) {
                        toggleTag(tag)
                    }
                }
            }

            if allowCustom {
                HStack(spacing: Spacing.sm) {
                    TextField("Add custom topic...", text: $customTag)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .padding(.horizontal, Spacing.sm)
                        .frame(height: 36)
                        .background(ColorTokens.surfaceDark)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                    if !customTag.isEmpty {
                        Button {
                            addCustomTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ColorTokens.primary)
                        }
                    }
                }
            }
        }
    }

    private func toggleTag(_ tag: String) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }

    private func addCustomTag() {
        let trimmed = customTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedTags.contains(trimmed) else { return }
        selectedTags.append(trimmed)
        customTag = ""
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? .white : ColorTokens.textSecondaryDark)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs + 2)
                .background(isSelected ? ColorTokens.primary : ColorTokens.surfaceElevatedDark)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? ColorTokens.primary : ColorTokens.textTertiaryDark.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, width: proposal.width ?? 0)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: width, height: y + rowHeight), positions)
    }
}
