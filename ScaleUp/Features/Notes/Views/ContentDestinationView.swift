import SwiftUI

/// Routes to the correct detail view based on content type.
/// Use this as the destination in `.navigationDestination(for: Content.self)`.
struct ContentDestinationView: View {
    let content: Content

    var body: some View {
        if content.contentType == .notes {
            NotesDetailView(contentId: content.id)
        } else {
            PlayerView(contentId: content.id)
        }
    }
}
