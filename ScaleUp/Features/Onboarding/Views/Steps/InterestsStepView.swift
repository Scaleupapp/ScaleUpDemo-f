import SwiftUI

struct InterestsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Heading
                VStack(spacing: Spacing.sm) {
                    Text("Pick your interests")
                        .font(Typography.displayMedium)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Select at least 3 topics")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.top, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Selected count
                if !viewModel.selectedTopics.isEmpty {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(viewModel.selectedTopics.count >= 3 ? ColorTokens.success : ColorTokens.gold)
                        Text("\(viewModel.selectedTopics.count) selected")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Topic Chips - Flow Layout
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(viewModel.suggestedTopics, id: \.self) { topic in
                        topicChip(topic)
                    }

                    // Show custom-added topics not in suggestions
                    ForEach(Array(viewModel.selectedTopics.filter { !viewModel.suggestedTopics.contains($0) }), id: \.self) { topic in
                        topicChip(topic)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Custom topic input
                HStack(spacing: Spacing.sm) {
                    ScaleUpTextField(
                        label: "Add your own topic",
                        icon: "plus",
                        text: $viewModel.customTopic,
                        autocapitalization: .words
                    )

                    Button {
                        viewModel.addCustomTopic()
                    } label: {
                        Text("Add")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.buttonPrimaryText)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 14)
                            .background(ColorTokens.gold)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                    .padding(.top, 20) // align with text field (below label)
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xxl)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Topic Chip

    private func topicChip(_ topic: String) -> some View {
        let isSelected = viewModel.selectedTopics.contains(topic)

        return Button {
            viewModel.toggleTopic(topic)
        } label: {
            Text(topic)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? ColorTokens.gold : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(Motion.springSnappy, value: isSelected)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
