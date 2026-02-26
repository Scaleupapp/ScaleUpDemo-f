import SwiftUI

// MARK: - ScrollFadeModifier

struct ScrollFadeModifier: ViewModifier {
    var edges: Edge.Set = .vertical
    var fadeLength: CGFloat = 20

    func body(content: Self.Content) -> some View {
        content
            .mask(
                VStack(spacing: 0) {
                    if edges.contains(.top) {
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: fadeLength)
                    }

                    Rectangle().fill(.black)

                    if edges.contains(.bottom) {
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: fadeLength)
                    }
                }
            )
    }
}

// MARK: - View Extension

extension View {
    func scrollFade(edges: Edge.Set = .vertical, fadeLength: CGFloat = 20) -> some View {
        modifier(ScrollFadeModifier(edges: edges, fadeLength: fadeLength))
    }
}
