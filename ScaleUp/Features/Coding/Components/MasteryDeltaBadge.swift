import SwiftUI

/// Floating "+N axis" badge that animates in after a drill grade lands.
/// In Phase A the backend doesn't return the delta in the graded response —
/// the badge is intentionally a placeholder for that follow-up. Currently it
/// renders nothing unless an explicit `delta` is provided by the caller.
struct MasteryDeltaBadge: View {
    let axis: String?   // e.g. "prompting" — nil = no delta to show
    let delta: Double?  // points added to the axis after EMA blend

    var body: some View {
        if let axis = axis, let delta = delta, delta > 0 {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.green)
                Text(String(format: "+%.1f %@", delta, axis.replacingOccurrences(of: "_", with: " ")))
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview("With delta") {
    MasteryDeltaBadge(axis: "prompting", delta: 2.5)
        .padding()
}

#Preview("Placeholder (no delta)") {
    MasteryDeltaBadge(axis: nil, delta: nil)
        .padding()
}
