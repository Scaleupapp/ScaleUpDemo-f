import SwiftUI

@Observable
@MainActor
final class CreatorApplicationViewModel {

    // MARK: - Form Steps

    enum Step: Int, CaseIterable {
        case domain = 0
        case experience
        case links
        case review
    }

    var currentStep: Step = .domain

    // MARK: - Step 1: Domain & Specializations

    var domain = ""
    var specializations: [String] = []
    var newSpecialization = ""

    // MARK: - Step 2: Experience & Motivation

    var experience = ""
    var motivation = ""

    // MARK: - Step 3: Links

    var sampleContentLinks: [String] = [""]
    var portfolioUrl = ""
    var linkedin = ""
    var twitter = ""
    var youtube = ""
    var website = ""

    // MARK: - State

    var isSubmitting = false
    var errorMessage: String?
    var submittedApplication: CreatorApplication?

    private let creatorService = CreatorService()

    // MARK: - Navigation

    var canProceed: Bool {
        switch currentStep {
        case .domain:
            return !domain.trimmingCharacters(in: .whitespaces).isEmpty
        case .experience:
            return !experience.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !motivation.trimmingCharacters(in: .whitespaces).isEmpty
        case .links:
            return sampleContentLinks.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .review:
            return true
        }
    }

    func next() {
        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else { return }
        Haptics.light()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nextStep
        }
    }

    func back() {
        guard let prevStep = Step(rawValue: currentStep.rawValue - 1) else { return }
        Haptics.light()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = prevStep
        }
    }

    // MARK: - Specializations

    func addSpecialization() {
        let trimmed = newSpecialization.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !specializations.contains(trimmed) else { return }
        specializations.append(trimmed)
        newSpecialization = ""
        Haptics.light()
    }

    func removeSpecialization(_ spec: String) {
        specializations.removeAll { $0 == spec }
    }

    // MARK: - Links

    func addLinkField() {
        guard sampleContentLinks.count < 5 else { return }
        sampleContentLinks.append("")
    }

    func removeLinkField(at index: Int) {
        guard sampleContentLinks.count > 1 else { return }
        sampleContentLinks.remove(at: index)
    }

    // MARK: - Submit

    func submit() async {
        isSubmitting = true
        errorMessage = nil

        let socialLinks: SocialLinksInput? = {
            let hasAny = !linkedin.isEmpty || !twitter.isEmpty || !youtube.isEmpty || !website.isEmpty
            guard hasAny else { return nil }
            return SocialLinksInput(
                linkedin: linkedin.isEmpty ? nil : linkedin,
                twitter: twitter.isEmpty ? nil : twitter,
                youtube: youtube.isEmpty ? nil : youtube,
                website: website.isEmpty ? nil : website
            )
        }()

        let body = CreatorApplyRequest(
            domain: domain.lowercased().trimmingCharacters(in: .whitespaces),
            specializations: specializations,
            experience: experience,
            motivation: motivation,
            sampleContentLinks: sampleContentLinks.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            portfolioUrl: portfolioUrl.isEmpty ? nil : portfolioUrl,
            socialLinks: socialLinks
        )

        do {
            submittedApplication = try await creatorService.apply(body: body)
            Haptics.success()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to submit application"
            Haptics.error()
        }

        isSubmitting = false
    }
}
