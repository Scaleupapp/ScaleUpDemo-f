import SwiftUI
import PhotosUI

@Observable
@MainActor
final class EditProfileViewModel {

    // MARK: - Form Fields

    var firstName = ""
    var lastName = ""
    var username = ""
    var bio = ""
    var location = ""
    var skills: [String] = []
    var newSkill = ""
    var education: [EducationInput] = []
    var workExperience: [WorkExperienceInput] = []

    // MARK: - Avatar

    var selectedPhotoItem: PhotosPickerItem?
    var avatarImage: UIImage?
    var avatarURL: String?
    var isUploadingAvatar = false

    // MARK: - Add Education Form

    var showAddEducation = false
    var newEduDegree = ""
    var newEduInstitution = ""
    var newEduYear = ""
    var newEduCurrently = false

    // MARK: - Add Work Form

    var showAddWork = false
    var newWorkRole = ""
    var newWorkCompany = ""
    var newWorkYears = ""
    var newWorkCurrently = false

    // MARK: - State

    var isSaving = false
    var errorMessage: String?
    var hasChanges: Bool {
        firstName != originalFirstName || lastName != originalLastName ||
        username != originalUsername || bio != originalBio ||
        location != originalLocation || skills != originalSkills ||
        education.count != originalEducationCount ||
        workExperience.count != originalWorkCount ||
        avatarImage != nil
    }

    // MARK: - Private

    private let userService = UserService()
    private var originalFirstName = ""
    private var originalLastName = ""
    private var originalUsername = ""
    private var originalBio = ""
    private var originalLocation = ""
    private var originalSkills: [String] = []
    private var originalEducationCount = 0
    private var originalWorkCount = 0

    // MARK: - Setup

    func configure(with user: User) {
        firstName = user.firstName
        lastName = user.lastName ?? ""
        username = user.username ?? ""
        bio = user.bio ?? ""
        location = user.location ?? ""
        skills = user.skills ?? []
        avatarURL = user.profilePicture
        education = (user.education ?? []).map {
            EducationInput(degree: $0.degree, institution: $0.institution,
                          yearOfCompletion: $0.yearOfCompletion, currentlyPursuing: $0.currentlyPursuing)
        }
        workExperience = (user.workExperience ?? []).map {
            WorkExperienceInput(role: $0.role, company: $0.company,
                               years: $0.years, currentlyWorking: $0.currentlyWorking)
        }

        originalFirstName = firstName
        originalLastName = lastName
        originalUsername = username
        originalBio = bio
        originalLocation = location
        originalSkills = skills
        originalEducationCount = education.count
        originalWorkCount = workExperience.count
    }

    // MARK: - Photo Selection

    func handlePhotoSelection() async {
        guard let item = selectedPhotoItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let image = UIImage(data: data) else { return }
        avatarImage = image
    }

    func uploadAvatarIfNeeded() async -> User? {
        guard let image = avatarImage else { return nil }
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return nil }

        isUploadingAvatar = true
        do {
            let updated = try await userService.uploadAvatar(imageData: jpegData)
            isUploadingAvatar = false
            return updated
        } catch {
            isUploadingAvatar = false
            return nil
        }
    }

    // MARK: - Skills

    func addSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !skills.contains(trimmed) else { return }
        skills.append(trimmed)
        newSkill = ""
        Haptics.light()
    }

    func removeSkill(_ skill: String) {
        skills.removeAll { $0 == skill }
        Haptics.light()
    }

    // MARK: - Education

    func addEducation() {
        let degree = newEduDegree.trimmingCharacters(in: .whitespacesAndNewlines)
        let institution = newEduInstitution.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !degree.isEmpty, !institution.isEmpty else { return }

        let entry = EducationInput(
            degree: degree,
            institution: institution,
            yearOfCompletion: Int(newEduYear),
            currentlyPursuing: newEduCurrently ? true : nil
        )
        education.append(entry)
        clearEducationForm()
        showAddEducation = false
        Haptics.light()
    }

    func clearEducationForm() {
        newEduDegree = ""
        newEduInstitution = ""
        newEduYear = ""
        newEduCurrently = false
    }

    // MARK: - Work Experience

    func addWorkExperience() {
        let role = newWorkRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = newWorkCompany.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !role.isEmpty, !company.isEmpty else { return }

        let entry = WorkExperienceInput(
            role: role,
            company: company,
            years: Int(newWorkYears),
            currentlyWorking: newWorkCurrently ? true : nil
        )
        workExperience.append(entry)
        clearWorkForm()
        showAddWork = false
        Haptics.light()
    }

    func clearWorkForm() {
        newWorkRole = ""
        newWorkCompany = ""
        newWorkYears = ""
        newWorkCurrently = false
    }

    // MARK: - Save

    func save() async -> User? {
        isSaving = true
        errorMessage = nil

        // Upload avatar first if changed
        var latestUser: User?
        if avatarImage != nil {
            latestUser = await uploadAvatarIfNeeded()
        }

        let body = UpdateProfileRequest(
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName,
            username: username.isEmpty ? nil : username,
            bio: bio.isEmpty ? nil : bio,
            location: location.isEmpty ? nil : location,
            skills: skills.isEmpty ? nil : skills,
            education: education.isEmpty ? nil : education,
            workExperience: workExperience.isEmpty ? nil : workExperience
        )

        do {
            let updated = try await userService.updateProfile(body: body)
            Haptics.success()
            isSaving = false
            return updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
            isSaving = false
            return latestUser // Return avatar-updated user if profile update fails
        } catch {
            errorMessage = "Failed to save changes"
            Haptics.error()
            isSaving = false
            return latestUser
        }
    }
}
