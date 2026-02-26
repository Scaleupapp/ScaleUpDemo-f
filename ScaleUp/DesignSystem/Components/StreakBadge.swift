import SwiftUI

struct StreakBadge: View {
    let count: Int
    var isActive: Bool = true

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(
                    isActive
                        ? LinearGradient(
                            colors: [ColorTokens.warning, ColorTokens.error],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        : LinearGradient(
                            colors: [ColorTokens.textTertiaryDark],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                )
                .scaleEffect(isPulsing ? 1.15 : 1.0)

            Text("\(count)")
                .font(Typography.mono)
                .foregroundStyle(ColorTokens.textPrimaryDark)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorTokens.surfaceElevatedDark)
        .clipShape(Capsule())
        .onAppear {
            guard isActive else { return }
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}
