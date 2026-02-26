import SwiftUI

// MARK: - Creator Application View Model

@Observable
@MainActor
final class CreatorApplicationViewModel {

    // MARK: - Form Fields

    var domain: String = ""
    var specializations: [String] = []
    var newSpecialization: String = ""
    var motivation: String = ""
    var experience: String = ""
    var portfolioUrl: String = ""
    var sampleLinks: [String] = []
    var newSampleLink: String = ""

    // MARK: - State

    var existingApplication: CreatorApplication?
    var isSubmitting = false
    var isCheckingStatus = false
    var error: APIError?
    var submitSuccess = false

    // MARK: - Dependencies

    private let creatorService: CreatorService
    private let hapticManager: HapticManager

    // MARK: - Init

    init(creatorService: CreatorService, hapticManager: HapticManager) {
        self.creatorService = creatorService
        self.hapticManager = hapticManager
    }

    // MARK: - Check Existing Application

    /// Checks whether the user has already submitted a creator application.
    func checkExistingApplication() async {
        guard !isCheckingStatus else { return }
        isCheckingStatus = true
        error = nil

        do {
            let application = try await creatorService.applicationStatus()
            self.existingApplication = application
        } catch let apiError as APIError {
            // A 404 means no existing application, which is expected
            if case .notFound = apiError {
                self.existingApplication = nil
            } else {
                self.error = apiError
            }
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isCheckingStatus = false
    }

    // MARK: - Submit Application

    /// Submits a new creator application to the API.
    func submitApplication() async {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        error = nil

        do {
            try await creatorService.apply(
                motivation: motivation.isEmpty ? nil : motivation,
                expertise: specializations.isEmpty ? nil : specializations,
                portfolio: portfolioUrl.isEmpty ? nil : portfolioUrl
            )
            self.submitSuccess = true
            hapticManager.success()
        } catch let apiError as APIError {
            self.error = apiError
            hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            hapticManager.error()
        }

        isSubmitting = false
    }

    // MARK: - Specialization Management

    /// Adds the current `newSpecialization` text as a specialization tag.
    func addSpecialization() {
        let trimmed = newSpecialization.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !specializations.contains(trimmed) else { return }
        specializations.append(trimmed)
        newSpecialization = ""
        hapticManager.selection()
    }

    /// Removes a specialization at the given index set offsets.
    func removeSpecialization(at offsets: IndexSet) {
        specializations.remove(atOffsets: offsets)
    }

    /// Removes a specialization by value.
    func removeSpecialization(_ value: String) {
        specializations.removeAll { $0 == value }
    }

    // MARK: - Sample Link Management

    /// Adds the current `newSampleLink` text as a sample content link.
    func addSampleLink() {
        let trimmed = newSampleLink.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !sampleLinks.contains(trimmed) else { return }
        sampleLinks.append(trimmed)
        newSampleLink = ""
        hapticManager.selection()
    }

    /// Removes a sample link at the given index set offsets.
    func removeSampleLink(at offsets: IndexSet) {
        sampleLinks.remove(atOffsets: offsets)
    }

    // MARK: - Validation

    /// Returns `true` when the form has all required fields filled in.
    var isValid: Bool {
        !domain.trimmingCharacters(in: .whitespaces).isEmpty
            && !specializations.isEmpty
            && motivation.trimmingCharacters(in: .whitespaces).count >= 50
    }

    /// Character count for the motivation field.
    var motivationCharCount: Int {
        motivation.count
    }

    /// Whether the motivation meets the minimum character requirement.
    var motivationMeetsMinimum: Bool {
        motivation.trimmingCharacters(in: .whitespaces).count >= 50
    }
}
