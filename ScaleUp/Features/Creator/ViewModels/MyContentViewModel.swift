import SwiftUI

@Observable
@MainActor
final class MyContentViewModel {

    var content: [Content] = []
    var isLoading = false
    var errorMessage: String?
    var selectedFilter: ContentStatus? = nil

    private let service = ContentCreationService()

    var filteredContent: [Content] {
        guard let filter = selectedFilter else { return content }
        return content.filter { $0.status == filter }
    }

    var statusCounts: [ContentStatus: Int] {
        var counts: [ContentStatus: Int] = [:]
        for item in content {
            if let status = item.status {
                counts[status, default: 0] += 1
            }
        }
        return counts
    }

    func loadContent() async {
        isLoading = true
        errorMessage = nil

        do {
            content = try await service.fetchMyContent()
        } catch {
            errorMessage = "Failed to load content"
        }

        isLoading = false
    }

    func publish(id: String) async {
        do {
            let updated = try await service.publishContent(id: id)
            if let index = content.firstIndex(where: { $0.id == id }) {
                content[index] = updated
            }
            Haptics.success()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to publish"
            Haptics.error()
        }
    }

    func unpublish(id: String) async {
        do {
            let updated = try await service.unpublishContent(id: id)
            if let index = content.firstIndex(where: { $0.id == id }) {
                content[index] = updated
            }
            Haptics.success()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to unpublish"
            Haptics.error()
        }
    }

    func delete(id: String) async {
        do {
            try await service.deleteContent(id: id)
            content.removeAll { $0.id == id }
            Haptics.success()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to delete"
            Haptics.error()
        }
    }
}
