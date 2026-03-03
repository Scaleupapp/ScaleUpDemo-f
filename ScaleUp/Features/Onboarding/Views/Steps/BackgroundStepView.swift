import SwiftUI

struct BackgroundStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Heading
                VStack(spacing: Spacing.sm) {
                    Text("Tell us about yourself")
                        .font(Typography.displayMedium)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("This helps us personalize your experience")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.top, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Education Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    sectionHeader(title: "Education", icon: "graduationcap.fill")

                    ForEach(Array(viewModel.educationEntries.enumerated()), id: \.element.id) { index, entry in
                        educationCard(index: index, entry: entry)
                    }

                    addButton(title: "Add Education") {
                        viewModel.addEducation()
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Work Experience Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    sectionHeader(title: "Work Experience", icon: "briefcase.fill")

                    ForEach(Array(viewModel.workEntries.enumerated()), id: \.element.id) { index, entry in
                        workCard(index: index, entry: entry)
                    }

                    addButton(title: "Add Experience") {
                        viewModel.addWork()
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

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

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.gold)
            Text(title)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }

    // MARK: - Education Card

    private func educationCard(index: Int, entry: EducationEntry) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("Education \(index + 1)")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                Spacer()
                Button {
                    withAnimation(Motion.springSnappy) {
                        viewModel.removeEducation(entry)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            ScaleUpTextField(
                label: "Degree",
                icon: "scroll.fill",
                text: Binding(
                    get: { viewModel.educationEntries.first(where: { $0.id == entry.id })?.degree ?? "" },
                    set: { newValue in
                        if let idx = viewModel.educationEntries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.educationEntries[idx].degree = newValue
                        }
                    }
                ),
                autocapitalization: .words
            )

            ScaleUpTextField(
                label: "Institution",
                icon: "building.columns.fill",
                text: Binding(
                    get: { viewModel.educationEntries.first(where: { $0.id == entry.id })?.institution ?? "" },
                    set: { newValue in
                        if let idx = viewModel.educationEntries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.educationEntries[idx].institution = newValue
                        }
                    }
                ),
                autocapitalization: .words
            )

            HStack(spacing: Spacing.sm) {
                Toggle("Currently Pursuing", isOn: Binding(
                    get: { viewModel.educationEntries.first(where: { $0.id == entry.id })?.currentlyPursuing ?? false },
                    set: { newValue in
                        if let idx = viewModel.educationEntries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.educationEntries[idx].currentlyPursuing = newValue
                        }
                    }
                ))
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .tint(ColorTokens.gold)
            }

            if !(viewModel.educationEntries.first(where: { $0.id == entry.id })?.currentlyPursuing ?? false) {
                yearPicker(
                    label: "Year of Completion",
                    value: Binding(
                        get: { viewModel.educationEntries.first(where: { $0.id == entry.id })?.yearOfCompletion },
                        set: { newValue in
                            if let idx = viewModel.educationEntries.firstIndex(where: { $0.id == entry.id }) {
                                viewModel.educationEntries[idx].yearOfCompletion = newValue
                            }
                        }
                    )
                )
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    // MARK: - Work Card

    private func workCard(index: Int, entry: WorkEntry) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("Experience \(index + 1)")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                Spacer()
                Button {
                    withAnimation(Motion.springSnappy) {
                        viewModel.removeWork(entry)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            ScaleUpTextField(
                label: "Role",
                icon: "person.text.rectangle",
                text: Binding(
                    get: { viewModel.workEntries.first(where: { $0.id == entry.id })?.role ?? "" },
                    set: { newValue in
                        if let idx = viewModel.workEntries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.workEntries[idx].role = newValue
                        }
                    }
                ),
                autocapitalization: .words
            )

            ScaleUpTextField(
                label: "Company",
                icon: "building.2.fill",
                text: Binding(
                    get: { viewModel.workEntries.first(where: { $0.id == entry.id })?.company ?? "" },
                    set: { newValue in
                        if let idx = viewModel.workEntries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.workEntries[idx].company = newValue
                        }
                    }
                ),
                autocapitalization: .words
            )

            HStack(spacing: Spacing.sm) {
                Toggle("Currently Working", isOn: Binding(
                    get: { viewModel.workEntries.first(where: { $0.id == entry.id })?.currentlyWorking ?? false },
                    set: { newValue in
                        if let idx = viewModel.workEntries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.workEntries[idx].currentlyWorking = newValue
                        }
                    }
                ))
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .tint(ColorTokens.gold)
            }

            yearsPicker(
                label: "Years of Experience",
                value: Binding(
                    get: { viewModel.workEntries.first(where: { $0.id == entry.id })?.years },
                    set: { newValue in
                        if let idx = viewModel.workEntries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.workEntries[idx].years = newValue
                        }
                    }
                )
            )
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    // MARK: - Year Picker (Education)

    private func yearPicker(label: String, value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach((2010...2030).reversed(), id: \.self) { year in
                        Button {
                            value.wrappedValue = (value.wrappedValue == year) ? nil : year
                        } label: {
                            Text("\(year)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(value.wrappedValue == year ? .white : ColorTokens.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(value.wrappedValue == year ? ColorTokens.gold : ColorTokens.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Years Picker (Work Experience)

    private func yearsPicker(label: String, value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20], id: \.self) { years in
                        Button {
                            value.wrappedValue = (value.wrappedValue == years) ? nil : years
                        } label: {
                            Text(years == 1 ? "1 yr" : "\(years) yrs")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(value.wrappedValue == years ? .white : ColorTokens.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(value.wrappedValue == years ? ColorTokens.gold : ColorTokens.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Add Button

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            withAnimation(Motion.springSmooth) {
                action()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text(title)
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(ColorTokens.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ColorTokens.gold.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.gold.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
    }
}
