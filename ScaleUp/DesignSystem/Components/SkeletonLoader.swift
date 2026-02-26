import SwiftUI

struct SkeletonLoader: View {
    var width: CGFloat? = nil
    var height: CGFloat = 20
    var cornerRadius: CGFloat = CornerRadius.small

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(ColorTokens.surfaceElevatedDark)
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shimmerGradient)
                    .offset(x: isAnimating ? 300 : -300)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                .clear,
                ColorTokens.surfaceDark.opacity(0.4),
                .clear,
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Skeleton Card (for content card placeholders)

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SkeletonLoader(height: 110, cornerRadius: CornerRadius.small + 4)
            SkeletonLoader(width: 140, height: 14)
            SkeletonLoader(width: 100, height: 10)
        }
        .frame(width: 180)
    }
}
