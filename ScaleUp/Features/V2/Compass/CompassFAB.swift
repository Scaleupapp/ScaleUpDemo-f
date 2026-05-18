import SwiftUI

/// Persistent Compass floating-action-button.
///
/// Lives above the tab bar on every tab. Tapping opens the Compass sheet.
/// Visual identity: gold gradient circle with the Compass glyph (🧭).
struct CompassFAB: View {
    let action: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [ColorTokens.goldLight, ColorTokens.gold, ColorTokens.goldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                    .shadow(color: ColorTokens.gold.opacity(0.4), radius: 12, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: "location.north.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.background)
                    .rotationEffect(.degrees(-45))
            }
            .scaleEffect(pulsing ? 1.04 : 1.0)
            .animation(
                .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: pulsing
            )
        }
        .buttonStyle(.plain)
        .onAppear { pulsing = true }
        .accessibilityLabel("Open Compass")
    }
}

#Preview {
    ZStack {
        ColorTokens.background.ignoresSafeArea()
        CompassFAB(action: {})
    }
}
