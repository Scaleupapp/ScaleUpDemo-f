import SwiftUI
import UIKit

enum ShareableSummaryCardGenerator {
    @MainActor
    static func render(_ card: ShareableSummaryCard) -> UIImage? {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .dark))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: ((String?) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { activityType, completed, _, _ in
            guard completed else { return }
            onComplete?(activityType?.rawValue)
        }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
