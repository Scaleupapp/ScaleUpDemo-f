import SwiftUI

/// Plan-tab "we're generating your plan" interstitial.
///
/// Visual: a pulsing gold sparkle ring + a slowly-rotating dotted halo,
/// paired with copy that cycles every few seconds so the screen never
/// feels static during the 30-60s plan-generation wait.
struct GeneratingPlanView: View {
    @State private var pulse = false
    @State private var rotate = false
    @State private var tipIndex = 0

    private let tips: [String] = [
        "Mapping your topics to a personalised cadence…",
        "Balancing depth against your weekly hours…",
        "Setting milestones around your goal…",
        "Writing the first week so you can start strong…",
    ]

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Animated halo
            ZStack {
                // Outer rotating dotted ring
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [ColorTokens.gold.opacity(0.05), ColorTokens.gold.opacity(0.55), ColorTokens.gold.opacity(0.05)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 6])
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotate)

                // Inner pulse glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ColorTokens.gold.opacity(0.30), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulse ? 1.06 : 0.96)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                // Gold disc with sparkle
                Circle()
                    .fill(ColorTokens.gold.opacity(0.18))
                    .frame(width: 110, height: 110)

                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .rotationEffect(.degrees(pulse ? 4 : -4))
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            }
            .onAppear {
                pulse = true
                rotate = true
            }

            VStack(spacing: Spacing.sm) {
                Text("Crafting your plan")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(tips[tipIndex])
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xl)
                    .id("tip-\(tipIndex)")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.4), value: tipIndex)
            }

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<tips.count, id: \.self) { i in
                    Capsule()
                        .fill(i == tipIndex ? ColorTokens.gold : ColorTokens.textTertiary.opacity(0.3))
                        .frame(width: i == tipIndex ? 16 : 5, height: 5)
                        .animation(.easeInOut(duration: 0.3), value: tipIndex)
                }
            }

            Text("This usually takes a minute or two")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                tipIndex = (tipIndex + 1) % tips.count
            }
        }
    }
}
