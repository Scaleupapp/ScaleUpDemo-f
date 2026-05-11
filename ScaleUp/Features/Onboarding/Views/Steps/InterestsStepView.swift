import SwiftUI

struct InterestsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var appeared = false
    @State private var infoTopic: SuggestedTopic?

    var body: some View {
        Group {
            if viewModel.showSyllabusUpload {
                SyllabusUploadView(viewModel: viewModel)
            } else if viewModel.isOnRatingSubStep {
                SelfRatingSubStepView(viewModel: viewModel)
            } else {
                topicSelectionScreen
            }
        }
        .task {
            viewModel.evaluateSyllabusGate()
            if !viewModel.showSyllabusUpload && viewModel.suggestedTopics.isEmpty {
                await viewModel.loadSuggestedTopics()
            }
        }
    }

    // MARK: - Topic selection

    private var topicSelectionScreen: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                heading
                if viewModel.isLoadingTopics {
                    ProgressView().padding(.top, Spacing.lg)
                } else {
                    selectionCounter
                    chipFlow
                    customAddRow
                    // No body CTA here — the bottom-bar Continue advances
                    // through the rating substep then to completion. Two
                    // buttons doing similar-looking things confused users.
                    Spacer().frame(height: Spacing.xxl)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
        .sheet(item: $infoTopic) { topic in
            TopicInfoSheet(topic: topic)
                .presentationDetents([.fraction(0.3)])
        }
    }

    private var headingSubtitle: String {
        let remaining = max(0, 8 - viewModel.totalSelectedCount)
        if remaining == 0 {
            return "All 8 slots used — tap a topic to swap it out."
        }
        return "We've suggested \(viewModel.suggestedTopics.count) — tap to remove or add up to \(remaining) more."
    }

    private var heading: some View {
        VStack(spacing: Spacing.sm) {
            Text("Pick your interests")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(headingSubtitle)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    private var selectionCounter: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(viewModel.totalSelectedCount >= 3 ? ColorTokens.success : ColorTokens.gold)
            Text("\(viewModel.totalSelectedCount) of 8 selected")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var chipFlow: some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(Array(viewModel.allDisplayableTopics.enumerated()), id: \.element.id) { index, topic in
                TopicChipView(
                    topic: topic,
                    isSelected: viewModel.selectedCanonicals.contains(topic.canonicalName),
                    onToggle: { viewModel.toggleTopic(topic) },
                    onInfo: { infoTopic = topic }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.03), value: appeared)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var customAddRow: some View {
        HStack(spacing: Spacing.sm) {
            ScaleUpTextField(
                label: "Add a topic",
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
                    .background(viewModel.totalSelectedCount < 8 ? ColorTokens.gold : ColorTokens.gold.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .disabled(viewModel.totalSelectedCount >= 8)
            .padding(.top, 20)
        }
        .padding(.horizontal, Spacing.lg)
    }

}

private struct TopicInfoSheet: View {
    let topic: SuggestedTopic
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(topic.name).font(Typography.titleMedium)
                if topic.isFutureProofing {
                    Text("✦ Future-proofing")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            Text(topic.description).font(Typography.body).foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
        .padding(Spacing.lg)
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
        let widthCap: CGFloat = (proposal.width ?? bounds.width)
        let childProposal = ProposedViewSize(width: widthCap, height: nil)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: childProposal
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        // Cap each chip's intrinsic width at the container width so a single
        // long topic ("emerging technologies in product management") doesn't
        // spill off the side of the screen. Subviews wrap their text within
        // the cap. Previously we passed `.unspecified` and any chip wider than
        // the screen drew over the edges.
        let widthCap = maxWidth.isFinite ? maxWidth : .infinity
        let childProposal = ProposedViewSize(width: widthCap, height: nil)

        for subview in subviews {
            var size = subview.sizeThatFits(childProposal)
            if size.width > widthCap { size.width = widthCap }

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

#Preview {
    let app = AppState()
    let vm = OnboardingViewModel(initialStep: 4, appState: app)
    vm.suggestedTopics = [
        SuggestedTopic(canonicalName: "product-strategy", name: "Product Strategy", description: "Vision, roadmap, prioritisation.", isFutureProofing: false, baseDifficulty: "intermediate"),
        SuggestedTopic(canonicalName: "ai-product-mgmt", name: "AI Product Management", description: "Scoping AI features and evals.", isFutureProofing: true, baseDifficulty: "intermediate")
    ]
    vm.selectedCanonicals = ["product-strategy", "ai-product-mgmt"]
    return InterestsStepView(viewModel: vm)
}
