import SwiftUI

struct FilterBottomSheet: View {
    @Bindable var viewModel: ExploreViewModel
    var onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        // Domain multi-select
                        domainSection

                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)

                        // Difficulty picker
                        difficultySection

                        Divider()
                            .background(ColorTokens.surfaceElevatedDark)

                        // Sort picker
                        sortSection

                        Spacer()
                            .frame(height: Spacing.lg)

                        // Action buttons
                        VStack(spacing: Spacing.sm) {
                            PrimaryButton(title: "Apply Filters") {
                                onApply()
                            }

                            SecondaryButton(title: "Reset") {
                                viewModel.resetFilters()
                            }
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.backgroundDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.primary)
                }
            }
        }
    }

    // MARK: - Domain Section

    private var domainSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Domain")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(viewModel.availableDomains, id: \.self) { domain in
                    Button {
                        viewModel.selectDomain(domain)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: viewModel.selectedDomain == domain
                                  ? "checkmark.square.fill"
                                  : "square")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    viewModel.selectedDomain == domain
                                        ? ColorTokens.primary
                                        : ColorTokens.textTertiaryDark
                                )

                            Text(domain)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Spacer()
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Difficulty Section

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Difficulty")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            HStack(spacing: Spacing.sm) {
                difficultyOption(label: "All", difficulty: nil)
                difficultyOption(label: "Beginner", difficulty: .beginner)
                difficultyOption(label: "Intermediate", difficulty: .intermediate)
                difficultyOption(label: "Advanced", difficulty: .advanced)
            }
        }
    }

    private func difficultyOption(label: String, difficulty: Difficulty?) -> some View {
        Button {
            viewModel.selectDifficulty(difficulty)
        } label: {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(
                    viewModel.selectedDifficulty == difficulty
                        ? .white
                        : ColorTokens.textSecondaryDark
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    viewModel.selectedDifficulty == difficulty
                        ? ColorTokens.primary
                        : ColorTokens.surfaceElevatedDark
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Sort By")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(SortOption.allCases) { option in
                    Button {
                        viewModel.sortBy = option
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: viewModel.sortBy == option
                                  ? "largecircle.fill.circle"
                                  : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    viewModel.sortBy == option
                                        ? ColorTokens.primary
                                        : ColorTokens.textTertiaryDark
                                )

                            Text(option.rawValue)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Spacer()
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
