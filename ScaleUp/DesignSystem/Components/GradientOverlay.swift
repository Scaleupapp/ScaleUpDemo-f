import SwiftUI

struct GradientOverlay: View {
    var startOpacity: Double = 0
    var endOpacity: Double = 0.85
    var startPoint: CGFloat = 0.4

    var body: some View {
        LinearGradient(
            colors: [
                .black.opacity(startOpacity),
                .black.opacity(endOpacity),
            ],
            startPoint: .init(x: 0.5, y: startPoint),
            endPoint: .bottom
        )
    }
}
