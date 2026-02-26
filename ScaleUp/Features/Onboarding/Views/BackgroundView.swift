import SwiftUI

struct BackgroundView: View {

    @Bindable var viewModel: OnboardingViewModel

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // MARK: - Education Section
                educationSection

                Divider()
                    .background(ColorTokens.surfaceElevatedDark)
                    .padding(.horizontal, Spacing.lg)

                // MARK: - Work Experience Section
                workExperienceSection

                // Bottom padding for scroll
                Spacer()
                    .frame(height: Spacing.xl)
            }
            .padding(.top, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Education Section

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader(
                icon: "graduationcap.fill",
                title: "Education"
            )

            ForEach(Array(viewModel.educationEntries.enumerated()), id: \.element.id) { index, entry in
                educationCard(index: index, entry: entry)
            }

            addButton(title: "Add Another Education") {
                withAnimation(Animations.standard) {
                    viewModel.addEducationEntry()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Education Card

    private func educationCard(index: Int, entry: EducationEntry) -> some View {
        VStack(spacing: Spacing.md) {
            // Remove button for additional entries
            if viewModel.educationEntries.count > 1 {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(Animations.standard) {
                            viewModel.removeEducationEntry(entry)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }

            TextFieldStyled(
                label: "Degree / Program",
                placeholder: "e.g., B.Tech in Computer Science",
                text: educationBinding(index: index, keyPath: \.degree),
                icon: "book.fill"
            )

            TextFieldStyled(
                label: "Institution",
                placeholder: "e.g., IIT Delhi",
                text: educationBinding(index: index, keyPath: \.institution),
                icon: "building.columns.fill"
            )

            HStack(spacing: Spacing.md) {
                // Year Picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Year")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)

                    Picker("Year", selection: educationYearBinding(index: index)) {
                        ForEach((1990...(currentYear + 6)), id: \.self) { year in
                            Text(String(year))
                                .tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(ColorTokens.textPrimaryDark)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                    .background(ColorTokens.surfaceDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                    )
                }

                // Currently Pursuing Toggle
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Currently Pursuing")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)

                    Toggle("", isOn: educationPursuingBinding(index: index))
                        .toggleStyle(SwitchToggleStyle(tint: ColorTokens.primary))
                        .frame(height: 52)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
        )
    }

    // MARK: - Work Experience Section

    private var workExperienceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader(
                icon: "briefcase.fill",
                title: "Work Experience"
            )

            ForEach(Array(viewModel.workExperienceEntries.enumerated()), id: \.element.id) { index, entry in
                workExperienceCard(index: index, entry: entry)
            }

            addButton(title: "Add Another Experience") {
                withAnimation(Animations.standard) {
                    viewModel.addWorkExperienceEntry()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Work Experience Card

    private func workExperienceCard(index: Int, entry: WorkExperienceEntry) -> some View {
        VStack(spacing: Spacing.md) {
            // Remove button for additional entries
            if viewModel.workExperienceEntries.count > 1 {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(Animations.standard) {
                            viewModel.removeWorkExperienceEntry(entry)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }

            TextFieldStyled(
                label: "Role / Title",
                placeholder: "e.g., Software Engineer",
                text: experienceBinding(index: index, keyPath: \.role),
                icon: "person.text.rectangle.fill"
            )

            TextFieldStyled(
                label: "Company",
                placeholder: "e.g., Google",
                text: experienceBinding(index: index, keyPath: \.company),
                icon: "building.2.fill"
            )

            HStack(spacing: Spacing.md) {
                // Years Stepper
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Years")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)

                    HStack(spacing: Spacing.sm) {
                        Button {
                            if viewModel.workExperienceEntries[index].years > 0 {
                                viewModel.workExperienceEntries[index].years -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(ColorTokens.primary)
                        }

                        Text("\(viewModel.workExperienceEntries[index].years)")
                            .font(Typography.titleMedium)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .frame(minWidth: 30)

                        Button {
                            if viewModel.workExperienceEntries[index].years < 50 {
                                viewModel.workExperienceEntries[index].years += 1
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(ColorTokens.primary)
                        }
                    }
                    .frame(height: 52)
                }

                // Currently Working Toggle
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Currently Working")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)

                    Toggle("", isOn: experienceWorkingBinding(index: index))
                        .toggleStyle(SwitchToggleStyle(tint: ColorTokens.primary))
                        .frame(height: 52)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
        )
    }

    // MARK: - Shared Components

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.primary)

            Text(title)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
        }
    }

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                Text(title)
                    .font(Typography.bodySmall)
            }
            .foregroundStyle(ColorTokens.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ColorTokens.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
    }

    // MARK: - Bindings

    private func educationBinding(index: Int, keyPath: WritableKeyPath<EducationEntry, String>) -> Binding<String> {
        Binding(
            get: {
                guard index < viewModel.educationEntries.count else { return "" }
                return viewModel.educationEntries[index][keyPath: keyPath]
            },
            set: {
                guard index < viewModel.educationEntries.count else { return }
                viewModel.educationEntries[index][keyPath: keyPath] = $0
            }
        )
    }

    private func educationYearBinding(index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard index < viewModel.educationEntries.count else { return currentYear }
                return viewModel.educationEntries[index].yearOfCompletion
            },
            set: {
                guard index < viewModel.educationEntries.count else { return }
                viewModel.educationEntries[index].yearOfCompletion = $0
            }
        )
    }

    private func educationPursuingBinding(index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard index < viewModel.educationEntries.count else { return false }
                return viewModel.educationEntries[index].currentlyPursuing
            },
            set: {
                guard index < viewModel.educationEntries.count else { return }
                viewModel.educationEntries[index].currentlyPursuing = $0
            }
        )
    }

    private func experienceBinding(index: Int, keyPath: WritableKeyPath<WorkExperienceEntry, String>) -> Binding<String> {
        Binding(
            get: {
                guard index < viewModel.workExperienceEntries.count else { return "" }
                return viewModel.workExperienceEntries[index][keyPath: keyPath]
            },
            set: {
                guard index < viewModel.workExperienceEntries.count else { return }
                viewModel.workExperienceEntries[index][keyPath: keyPath] = $0
            }
        )
    }

    private func experienceWorkingBinding(index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard index < viewModel.workExperienceEntries.count else { return false }
                return viewModel.workExperienceEntries[index].currentlyWorking
            },
            set: {
                guard index < viewModel.workExperienceEntries.count else { return }
                viewModel.workExperienceEntries[index].currentlyWorking = $0
            }
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.backgroundDark.ignoresSafeArea()
        BackgroundView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
