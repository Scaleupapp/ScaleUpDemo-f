import SwiftUI
import PhotosUI

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EditProfileViewModel()
    @State private var cropImage: IdentifiableImage?
    let user: User
    var onSave: (User) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        avatarSection
                        nameSection
                        usernameSection
                        bioSection
                        locationSection
                        skillsSection
                        educationSection
                        workSection
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let updated = await viewModel.save() {
                                onSave(updated)
                                dismiss()
                            }
                        }
                    }
                    .foregroundStyle(viewModel.hasChanges ? ColorTokens.gold : ColorTokens.textTertiary)
                    .disabled(!viewModel.hasChanges || viewModel.isSaving)
                }
            }
            .onAppear {
                viewModel.configure(with: user)
            }
            .overlay {
                if viewModel.isSaving {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .tint(ColorTokens.gold)
                        .scaleEffect(1.2)
                }
            }
            .fullScreenCover(item: $cropImage) { item in
                ImageCropView(image: item.image) { cropped in
                    viewModel.avatarImage = cropped
                    cropImage = nil
                } onCancel: {
                    cropImage = nil
                }
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: Spacing.sm) {
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = viewModel.avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else if let url = viewModel.avatarURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                initialsView
                            }
                        }
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                    } else {
                        initialsView
                    }

                    ZStack {
                        Circle()
                            .fill(ColorTokens.gold)
                            .frame(width: 28, height: 28)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .onChange(of: viewModel.selectedPhotoItem) {
                Task {
                    guard let item = viewModel.selectedPhotoItem,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    cropImage = IdentifiableImage(image: image)
                }
            }

            Text("Tap to change photo")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.surfaceElevated)
                .frame(width: 90, height: 90)
            Text("\(user.firstName.prefix(1))\((user.lastName ?? "").prefix(1))".uppercased())
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Name")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            HStack(spacing: Spacing.sm) {
                fieldInput("First name", text: $viewModel.firstName)
                fieldInput("Last name", text: $viewModel.lastName)
            }
        }
    }

    // MARK: - Username

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Username")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
            fieldInput("username", text: $viewModel.username)
        }
    }

    // MARK: - Bio

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Bio")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            TextEditor(text: $viewModel.bio)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Location")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
            fieldInput("City, Country", text: $viewModel.location)
        }
    }

    // MARK: - Skills

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Skills")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            // Existing skills as chips
            if !viewModel.skills.isEmpty {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(viewModel.skills, id: \.self) { skill in
                        HStack(spacing: 4) {
                            Text(skill)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.gold)

                            Button {
                                viewModel.removeSkill(skill)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            // Add skill input
            HStack(spacing: Spacing.sm) {
                fieldInput("Add a skill", text: $viewModel.newSkill)
                    .onSubmit { viewModel.addSkill() }

                Button {
                    viewModel.addSkill()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorTokens.gold)
                }
                .disabled(viewModel.newSkill.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Education

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Education")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            ForEach(Array(viewModel.education.enumerated()), id: \.offset) { index, edu in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(edu.degree)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text(edu.institution)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        if let year = edu.yearOfCompletion {
                            Text(edu.currentlyPursuing == true ? "Currently pursuing" : "Completed \(year)")
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    Spacer()
                    Button {
                        viewModel.education.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(ColorTokens.error)
                    }
                }
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }

            // Add education form
            if viewModel.showAddEducation {
                VStack(spacing: Spacing.sm) {
                    fieldInput("Degree (e.g. B.Tech Computer Science)", text: $viewModel.newEduDegree)
                    fieldInput("Institution", text: $viewModel.newEduInstitution)
                    HStack(spacing: Spacing.sm) {
                        fieldInput("Year", text: $viewModel.newEduYear)
                            .keyboardType(.numberPad)
                        Toggle("Currently pursuing", isOn: $viewModel.newEduCurrently)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .tint(ColorTokens.gold)
                    }
                    HStack(spacing: Spacing.sm) {
                        Button {
                            viewModel.showAddEducation = false
                            viewModel.clearEducationForm()
                        } label: {
                            Text("Cancel")
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(ColorTokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                .overlay(RoundedRectangle(cornerRadius: CornerRadius.small).stroke(ColorTokens.border, lineWidth: 1))
                        }
                        Button {
                            viewModel.addEducation()
                        } label: {
                            Text("Add")
                                .font(Typography.bodySmallBold)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(ColorTokens.gold)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        }
                        .disabled(viewModel.newEduDegree.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.newEduInstitution.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(Spacing.sm)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            } else {
                Button {
                    viewModel.showAddEducation = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Education")
                            .font(Typography.bodySmall)
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(ColorTokens.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Work Experience

    private var workSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Work Experience")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            ForEach(Array(viewModel.workExperience.enumerated()), id: \.offset) { index, work in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(work.role)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text(work.company)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                        if let years = work.years {
                            Text(work.currentlyWorking == true ? "Current (\(years) yrs)" : "\(years) years")
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    Spacer()
                    Button {
                        viewModel.workExperience.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(ColorTokens.error)
                    }
                }
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }

            // Add work form
            if viewModel.showAddWork {
                VStack(spacing: Spacing.sm) {
                    fieldInput("Role (e.g. Senior Engineer)", text: $viewModel.newWorkRole)
                    fieldInput("Company", text: $viewModel.newWorkCompany)
                    HStack(spacing: Spacing.sm) {
                        fieldInput("Years", text: $viewModel.newWorkYears)
                            .keyboardType(.numberPad)
                        Toggle("Currently working", isOn: $viewModel.newWorkCurrently)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .tint(ColorTokens.gold)
                    }
                    HStack(spacing: Spacing.sm) {
                        Button {
                            viewModel.showAddWork = false
                            viewModel.clearWorkForm()
                        } label: {
                            Text("Cancel")
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(ColorTokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                .overlay(RoundedRectangle(cornerRadius: CornerRadius.small).stroke(ColorTokens.border, lineWidth: 1))
                        }
                        Button {
                            viewModel.addWorkExperience()
                        } label: {
                            Text("Add")
                                .font(Typography.bodySmallBold)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(ColorTokens.gold)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        }
                        .disabled(viewModel.newWorkRole.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.newWorkCompany.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(Spacing.sm)
                .background(ColorTokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            } else {
                Button {
                    viewModel.showAddWork = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Work Experience")
                            .font(Typography.bodySmall)
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(ColorTokens.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Field Helper

    private func fieldInput(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(Spacing.sm)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
    }
}
