import SwiftUI

struct RubricBar: View {
    let dimension: String
    let score: Double   // 0..10
    /// Weight this dimension contributes to the overall score, as a percentage
    /// (e.g. 25). Shown next to the name so the learner sees how it's weighted.
    var weightPct: Int? = nil
    /// Why this dimension earned its score (grading-transparency).
    var why: String? = nil
    /// One concrete thing to do better next time.
    var toImprove: String? = nil
    /// Legacy single-line caption (used by drill results). Rendered only when
    /// the richer why/toImprove pair isn't supplied.
    var feedback: String? = nil

    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayName)
                    .font(.subheadline.weight(.medium))
                if let weightPct {
                    Text("· \(weightPct)%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(score.rounded()))/10")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                    Capsule()
                        .fill(barColor)
                        .frame(width: proxy.size.width * animatedWidth)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                        animatedWidth = CGFloat(max(0, min(10, score)) / 10.0)
                    }
                }
            }
            .frame(height: 8)

            if let why = why, !why.isEmpty {
                Text(why)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            if let toImprove = toImprove, !toImprove.isEmpty {
                Label(toImprove, systemImage: "arrow.up.forward.circle")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if why == nil, toImprove == nil, let feedback = feedback, !feedback.isEmpty {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var displayName: String {
        // Backend dimensions are snake_case (e.g. "ai_pair_effectiveness");
        // turn into Title Case With Spaces for display
        dimension
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var barColor: Color {
        if score >= 8 { return .green }
        if score >= 6 { return .yellow }
        if score >= 4 { return .orange }
        return .red
    }
}

#Preview {
    VStack(spacing: 16) {
        RubricBar(dimension: "ai_pair_effectiveness", score: 8.5, feedback: "Good use of the AI pair in your approach.")
        RubricBar(dimension: "prompt_clarity", score: 6.0, feedback: "Could be more specific about constraints.")
        RubricBar(dimension: "decomposition_depth", score: 3.5, feedback: "Missing sub-task breakdown.")
    }
    .padding()
}
