import SwiftUI

struct RubricBar: View {
    let dimension: String
    let score: Double   // 0..10
    let feedback: String?

    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayName)
                    .font(.subheadline.weight(.medium))
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

            if let feedback = feedback, !feedback.isEmpty {
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
