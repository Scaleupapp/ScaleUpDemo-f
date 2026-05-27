import SwiftUI

/// A live-ticking countdown badge that updates every second.
/// Color shifts from neutral → orange → red as time runs out.
struct DrillTimerBadge: View {
    /// When the drill (or calibration step) started.
    let startedAt: Date
    /// Total budget in seconds (e.g. `drill.timeBudgetMinutes * 60`).
    let totalSeconds: Int

    @State private var now = Date()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2.weight(.semibold))
            Text(formatted)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(backgroundColor))
        .foregroundStyle(foregroundColor)
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { date in
            now = date
        }
    }

    // MARK: - Computed

    private var elapsed: Int {
        max(0, Int(now.timeIntervalSince(startedAt)))
    }

    private var remaining: Int {
        max(0, totalSeconds - elapsed)
    }

    private var formatted: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private var backgroundColor: Color {
        if remaining <= 30 { return Color.red.opacity(0.18) }
        if remaining <= 60 { return Color.orange.opacity(0.18) }
        return Color.gray.opacity(0.15)
    }

    private var foregroundColor: Color {
        if remaining <= 30 { return .red }
        if remaining <= 60 { return .orange }
        return .secondary
    }
}

// MARK: - Preview

#Preview("Plenty of time") {
    DrillTimerBadge(
        startedAt: Date().addingTimeInterval(-30),
        totalSeconds: 5 * 60
    )
}

#Preview("Warning (< 60s)") {
    DrillTimerBadge(
        startedAt: Date().addingTimeInterval(-(4 * 60 + 15)),
        totalSeconds: 5 * 60
    )
}

#Preview("Critical (< 30s)") {
    DrillTimerBadge(
        startedAt: Date().addingTimeInterval(-(4 * 60 + 45)),
        totalSeconds: 5 * 60
    )
}
