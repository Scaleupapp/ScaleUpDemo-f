import SwiftUI

struct DrillSubmittingView: View {
    @State private var hintIndex = 0
    @State private var timerCancellable: Timer?

    private let hints = [
        "Compass is reading your answer…",
        "Checking against the rubric…",
        "Comparing to reference answers…",
        "Almost there…"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Pulsing icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 8) {
                Text("Grading…")
                    .font(.title3.weight(.semibold))

                Text(hints[hintIndex])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .id(hintIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .frame(height: 22)
            }

            Spacer()

            Text("Usually takes 8 seconds")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pulseScale = 1.15
            startHintRotation()
        }
        .onDisappear {
            timerCancellable?.invalidate()
        }
    }

    @State private var pulseScale: CGFloat = 1.0

    private func startHintRotation() {
        timerCancellable?.invalidate()
        timerCancellable = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.4)) {
                    hintIndex = (hintIndex + 1) % hints.count
                }
            }
        }
    }
}

#Preview {
    DrillSubmittingView()
}
