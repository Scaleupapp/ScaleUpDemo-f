import SwiftUI

// MARK: - ScaleUpRefreshStyle

struct ScaleUpRefreshStyle: View {
    var isRefreshing: Bool
    var pullProgress: CGFloat

    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "bolt.circle.fill")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(ColorTokens.primary)
            .scaleEffect(isRefreshing ? 1.0 : min(pullProgress, 1.0))
            .rotationEffect(.degrees(rotation))
            .onChange(of: isRefreshing) { _, refreshing in
                if refreshing {
                    startSpinning()
                } else {
                    rotation = 0
                }
            }
    }

    // MARK: - Private

    private func startSpinning() {
        withAnimation(
            .linear(duration: 1.0)
            .repeatForever(autoreverses: false)
        ) {
            rotation = 360
        }
    }
}

// MARK: - RefreshableModifier

struct ScaleUpRefreshModifier: ViewModifier {
    let action: @Sendable () async -> Void

    func body(content: Self.Content) -> some View {
        content
            .refreshable {
                await action()
            }
            .tint(ColorTokens.primary)
    }
}

// MARK: - View Extension

extension View {
    func scaleUpRefreshable(action: @escaping @Sendable () async -> Void) -> some View {
        modifier(ScaleUpRefreshModifier(action: action))
    }
}
