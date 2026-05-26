import SwiftUI

struct CalibrationProgressBar: View {
    let current: Int  // 1-indexed
    let total: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Step \(current) of \(total)")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("~\(estimatedMinRemaining) min left")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: proxy.size.width * progress)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }

    private var estimatedMinRemaining: Int {
        // 2 min per step
        max(0, (total - current + 1) * 2)
    }
}

#Preview {
    VStack(spacing: 0) {
        CalibrationProgressBar(current: 1, total: 3)
        CalibrationProgressBar(current: 2, total: 3)
        CalibrationProgressBar(current: 3, total: 3)
    }
}
