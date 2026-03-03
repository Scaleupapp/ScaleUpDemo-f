import SwiftUI

struct AddMilestoneSheet: View {
    @Bindable var viewModel: MyPlanViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var milestoneType = "custom"
    @State private var selectedTopic = ""
    @State private var targetScore = 70
    @State private var isSaving = false

    private let milestoneTypes = [
        ("custom", "Custom Goal"),
        ("topic_completion", "Topic Mastery"),
        ("score_target", "Score Target"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Milestone Title")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textSecondary)

                            TextField("e.g. Master User Research", text: $title)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(ColorTokens.surface)
                                )
                        }

                        // Type picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Type")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textSecondary)

                            HStack(spacing: 8) {
                                ForEach(milestoneTypes, id: \.0) { (type, label) in
                                    Button {
                                        milestoneType = type
                                    } label: {
                                        Text(label)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(milestoneType == type ? .white : ColorTokens.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(milestoneType == type ? ColorTokens.gold : ColorTokens.surface)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Topic picker (for topic_completion or score_target)
                        if milestoneType != "custom" && !viewModel.journeyTopics.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Topic")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ColorTokens.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.journeyTopics, id: \.self) { topic in
                                            Button {
                                                selectedTopic = topic
                                            } label: {
                                                Text(topic.capitalized)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(selectedTopic == topic ? .white : ColorTokens.textSecondary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(selectedTopic == topic ? ColorTokens.gold : ColorTokens.surface)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        // Score slider (for score_target)
                        if milestoneType == "score_target" {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Target Score")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(ColorTokens.textSecondary)
                                    Spacer()
                                    Text("\(targetScore)%")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(ColorTokens.gold)
                                }

                                Slider(value: Binding(
                                    get: { Double(targetScore) },
                                    set: { targetScore = Int($0) }
                                ), in: 30...100, step: 5)
                                .tint(ColorTokens.gold)
                            }
                        }

                        // Add button
                        Button {
                            isSaving = true
                            Task {
                                await viewModel.addMilestone(
                                    title: title,
                                    type: milestoneType,
                                    targetScore: milestoneType == "score_target" ? targetScore : nil,
                                    targetTopic: milestoneType != "custom" ? selectedTopic : nil
                                )
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Milestone")
                                }
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(title.isEmpty ? ColorTokens.textTertiary : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(title.isEmpty ? ColorTokens.surface : ColorTokens.gold)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || isSaving)
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle("New Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }
}
