import SwiftUI
import SafariServices

/// Routes to the correct detail view based on content type.
/// Use this as the destination in `.navigationDestination(for: Content.self)`.
struct ContentDestinationView: View {
    let content: Content

    var body: some View {
        switch content.contentType {
        case .notes:
            NotesDetailView(contentId: content.id)
        case .video:
            PlayerView(contentId: content.id)
        case .infographic, .article:
            // TODO: open a proper in-app reader when one exists.
            if let urlString = content.contentURL, let url = URL(string: urlString) {
                CDVSafariView(url: url)
            } else {
                PlayerView(contentId: content.id)
            }
        }
    }
}

/// SFSafariViewController wrapper scoped to ContentDestinationView.
private struct CDVSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
