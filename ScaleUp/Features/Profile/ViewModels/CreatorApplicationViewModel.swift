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

    // MARK: - URL Validation

    private func isValidURL(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host, !host.isEmpty, host.contains(".")
        else { return false }
        return true
    }

    private func hostContains(_ s: String, _ needle: String) -> Bool {
        URL(string: s.trimmingCharacters(in: .whitespaces))?.host?.lowercased().contains(needle) ?? false
    }

    /// Validates all link fields. Returns a user-facing error string if anything is wrong, nil if all valid.
    private func validateLinks() -> String? {
        // Sample content links — must be valid URLs when non-empty
        for link in sampleContentLinks where !link.trimmingCharacters(in: .whitespaces).isEmpty {
            if !isValidURL(link) {
                return "One of your Sample Content Links isn't a valid URL. Please start with https:// and use a complete web address."
            }
        }

        // Portfolio — optional but if present must be valid
        if !portfolioUrl.isEmpty, !isValidURL(portfolioUrl) {
            return "Portfolio URL isn't valid. Please start with https:// and use a complete web address."
        }

        // LinkedIn — must point to linkedin.com
        if !linkedin.isEmpty {
            guard isValidURL(linkedin), hostContains(linkedin, "linkedin.com") else {
                return "LinkedIn URL must be a linkedin.com link (e.g. https://www.linkedin.com/in/yourname)."
            }
        }

        // Twitter/X — allow @handle OR a twitter.com / x.com URL
        if !twitter.isEmpty {
            let t = twitter.trimmingCharacters(in: .whitespaces)
            let isHandle = t.hasPrefix("@") && t.count > 1 && !t.contains(" ")
            let isValidTwitterURL = isValidURL(t) && (hostContains(t, "twitter.com") || hostContains(t, "x.com"))
            if !isHandle && !isValidTwitterURL {
                return "Twitter/X must be a handle (e.g. @yourname) or a twitter.com / x.com URL."
            }
        }

        // YouTube — must point to youtube.com or youtu.be
        if !youtube.isEmpty {
            guard isValidURL(youtube), (hostContains(youtube, "youtube.com") || hostContains(youtube, "youtu.be")) else {
                return "YouTube URL must be a youtube.com or youtu.be link."
            }
        }

        // Website — any valid URL
        if !website.isEmpty, !isValidURL(website) {
            return "Website URL isn't valid. Please start with https:// and use a complete web address."
        }

        return nil
    }

    // MARK: - Submit

    func submit() async {
        isSubmitting = true
        errorMessage = nil

        if let validationError = validateLinks() {
            errorMessage = validationError
            Haptics.error()
            isSubmitting = false
            return
        }

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
