import SwiftUI

// MARK: - Edit Profile View Model

@Observable
@MainActor
final class EditProfileViewModel {

    // MARK: - Editable Fields

    var firstName: String = ""
    var lastName: String = ""
    var bio: String = ""
    var phone: String = ""

    // MARK: - State

    var isSaving = false
    var error: APIError?

    // MARK: - Original Values (for change detection)

    private var originalFirstName: String = ""
    private var originalLastName: String = ""
    private var originalBio: String = ""
    private var originalPhone: String = ""

    // MARK: - Dependencies

    private let userService: UserService
    private let hapticManager: HapticManager

    // MARK: - Constants

    static let bioMaxLength = 300

    // MARK: - Init

    init(userService: UserService, hapticManager: HapticManager) {
        self.userService = userService
        self.hapticManager = hapticManager
    }

    // MARK: - Populate

    /// Fills editable fields from the current user data.
    func populate(from user: User) {
        firstName = user.firstName
        lastName = user.lastName
        bio = user.bio ?? ""
        phone = user.phone ?? ""

        originalFirstName = user.firstName
        originalLastName = user.lastName
        originalBio = user.bio ?? ""
        originalPhone = user.phone ?? ""
    }

    // MARK: - Has Changes

    /// Returns `true` if any field differs from the original value.
    var hasChanges: Bool {
        firstName != originalFirstName ||
        lastName != originalLastName ||
        bio != originalBio ||
        phone != originalPhone
    }

    // MARK: - Validation

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var bioCharacterCount: Int {
        bio.count
    }

    var bioCharacterCountText: String {
        "\(bio.count)/\(Self.bioMaxLength)"
    }

    var isBioOverLimit: Bool {
        bio.count > Self.bioMaxLength
    }

    // MARK: - Save

    /// Calls the API to update the user profile. Returns the updated `User` on success.
    func save() async -> User? {
        guard hasChanges, isValid, !isBioOverLimit else { return nil }

        isSaving = true
        error = nil

        do {
            let fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)

            let updatedUser = try await userService.updateMe(
                name: fullName,
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                phone: trimmedPhone.isEmpty ? nil : trimmedPhone
            )

            hapticManager.success()
            isSaving = false
            return updatedUser
        } catch let apiError as APIError {
            self.error = apiError
            hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            hapticManager.error()
        }

        isSaving = false
        return nil
    }
}
