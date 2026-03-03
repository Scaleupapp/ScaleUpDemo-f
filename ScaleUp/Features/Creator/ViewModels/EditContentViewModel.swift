import SwiftUI

@Observable
@MainActor
final class EditContentViewModel {

    let content: Content

    var title: String
    var description: String
    var domain: String
    var topics: [String]
    var tags: [String]
    var difficulty: String
    var topicInput = ""
    var tagInput = ""

    var isSaving = false
    var errorMessage: String?
    var didSave = false

    private let service = ContentCreationService()

    init(content: Content) {
        self.content = content
        self.title = content.title
        self.description = content.description ?? ""
        self.domain = content.domain ?? ""
        self.topics = content.topics ?? []
        self.tags = content.tags ?? []
        self.difficulty = content.difficulty?.rawValue ?? "intermediate"
    }

    var hasChanges: Bool {
        title != content.title ||
        description != (content.description ?? "") ||
        domain != (content.domain ?? "") ||
        topics != (content.topics ?? []) ||
        tags != (content.tags ?? []) ||
        difficulty != (content.difficulty?.rawValue ?? "intermediate")
    }

    func addTopic() {
        let trimmed = topicInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !topics.contains(trimmed) else { return }
        topics.append(trimmed)
        topicInput = ""
        Haptics.light()
    }

    func removeTopic(_ topic: String) {
        topics.removeAll { $0 == topic }
    }

    func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
        Haptics.light()
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func save() async {
        guard hasChanges else { return }
        isSaving = true
        errorMessage = nil

        let body = UpdateContentRequest(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
            domain: domain.trimmingCharacters(in: .whitespaces).lowercased(),
            topics: topics,
            tags: tags,
            difficulty: difficulty
        )

        do {
            _ = try await service.updateContent(id: content.id, body: body)
            didSave = true
            Haptics.success()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to save changes"
            Haptics.error()
        }

        isSaving = false
    }
}
