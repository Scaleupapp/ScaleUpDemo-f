import SwiftUI

struct EditContentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditContentViewModel
    var onSaved: (() -> Void)?

    init(content: Content, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: EditContentViewModel(content: content))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        titleSection
                        descriptionSection
                        domainSection
                        topicsSection
                        tagsSection
                        difficultySection
                    }
                    .padding(Spacing.md)
                    .padding(.bottom, 80)
                }

                // Error banner
                if let error = viewModel.errorMessage {
                    VStack {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ColorTokens.error)
                            Text(error)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.error)
                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .background(ColorTokens.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .padding(.horizontal, Spacing.md)

                        Spacer()
                    }
                    .padding(.top, Spacing.sm)
                }
            }
            .navigationTitle("Edit Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.save()
                            if viewModel.didSave {
                                onSaved?()
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().tint(ColorTokens.gold)
                        } else {
                            Text("Save")
                                .font(Typography.bodySmallBold)
                                .foregroundStyle(viewModel.hasChanges ? ColorTokens.gold : ColorTokens.textTertiary)
                        }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isSaving)
                }
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Title")
            TextField("Content title", text: $viewModel.title)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .tint(ColorTokens.gold)
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            Text("\(viewModel.title.count)/200")
                .font(Typography.micro)
                .foregroundStyle(viewModel.title.count > 200 ? ColorTokens.error : ColorTokens.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Description")
            TextEditor(text: $viewModel.description)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimary)
                .tint(ColorTokens.gold)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
    }

    private var domainSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Domain")
            TextField("e.g. product management", text: $viewModel.domain)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimary)
                .tint(ColorTokens.gold)
                .textInputAutocapitalization(.never)
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
    }

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Topics")

            // Existing topics
            if !viewModel.topics.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(viewModel.topics, id: \.self) { topic in
                        chipWithRemove(topic) { viewModel.removeTopic(topic) }
                    }
                }
            }

            // Add topic
            HStack(spacing: Spacing.sm) {
                TextField("Add topic", text: $viewModel.topicInput)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .tint(ColorTokens.gold)
                    .textInputAutocapitalization(.never)
                    .onSubmit { viewModel.addTopic() }

                Button { viewModel.addTopic() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.gold)
                }
                .disabled(viewModel.topicInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(Spacing.sm)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Tags")

            if !viewModel.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(viewModel.tags, id: \.self) { tag in
                        chipWithRemove(tag) { viewModel.removeTag(tag) }
                    }
                }
            }

            HStack(spacing: Spacing.sm) {
                TextField("Add tag", text: $viewModel.tagInput)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .tint(ColorTokens.gold)
                    .textInputAutocapitalization(.never)
                    .onSubmit { viewModel.addTag() }

                Button { viewModel.addTag() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.gold)
                }
                .disabled(viewModel.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(Spacing.sm)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Difficulty")

            HStack(spacing: Spacing.sm) {
                ForEach(["beginner", "intermediate", "advanced"], id: \.self) { level in
                    Button {
                        Haptics.selection()
                        viewModel.difficulty = level
                    } label: {
                        Text(level.capitalized)
                            .font(Typography.bodySmall)
                            .foregroundStyle(viewModel.difficulty == level ? .black : ColorTokens.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(viewModel.difficulty == level ? difficultyColor(level) : ColorTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(ColorTokens.textTertiary)
    }

    private func chipWithRemove(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.gold)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ColorTokens.gold.opacity(0.1))
        .clipShape(Capsule())
    }

    private func difficultyColor(_ level: String) -> Color {
        switch level {
        case "beginner": return ColorTokens.success
        case "intermediate": return ColorTokens.gold
        case "advanced": return ColorTokens.error
        default: return ColorTokens.gold
        }
    }
}
