import SwiftUI

struct ShareScoreCardView: View {
    let result: ChallengeResult
    let topic: String

    @State private var showAnimation = false
    @Environment(\.dismiss) private var dismiss

    private let goldColor = Color(red: 1, green: 215.0/255.0, blue: 0) // #FFD700
    private let darkGold = Color(red: 0.15, green: 0.12, blue: 0.02)

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Preview of the card
                shareCardContent
                    .padding(Spacing.lg)

                // Share button
                Button {
                    Haptics.medium()
                    shareScore()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(goldColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, Spacing.lg)

                Button("Cancel") { dismiss() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showAnimation = true
            }
        }
    }

    // MARK: - Share Card Content (renderable to image)

    @ViewBuilder
    private var shareCardContent: some View {
        VStack(spacing: 20) {
            // Wordmark
            Text("SCALEUP")
                .font(.system(size: 16, weight: .black))
                .tracking(6)
                .foregroundStyle(goldColor)

            // Date and topic
            VStack(spacing: 4) {
                Text(formattedDate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text(topic)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Score circle
            ZStack {
                Circle()
                    .stroke(goldColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: showAnimation ? min(1.0, result.handicappedScore / 100.0) : 0)
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 104, height: 104)

                Text("\(Int(result.handicappedScore))")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(goldColor)
            }

            // Stats line
            Text("Top \(percentileText) \u{00B7} \(result.correct)/\(result.total) correct")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            // Personal best
            if result.isPersonalBest {
                Text("\u{1F3C6} New Personal Best!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(goldColor)
            }

            Divider()
                .overlay(goldColor.opacity(0.2))

            // CTA
            VStack(spacing: 6) {
                Text("Can you beat my score? \u{2192}")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text("scaleup.app/challenge")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(goldColor.opacity(0.6))
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.black, darkGold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(goldColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Share

    @MainActor
    private func shareScore() {
        let renderer = ImageRenderer(content: shareCardForExport)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 360, height: 480)

        guard let image = renderer.uiImage else { return }

        let text = "I scored \(Int(result.handicappedScore)) on today's \(topic) challenge on ScaleUp! \(result.isPersonalBest ? "New personal best! " : "")Can you beat my score?"

        let activityVC = UIActivityViewController(
            activityItems: [text, image],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Find the topmost presented VC
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        activityVC.popoverPresentationController?.sourceView = topVC.view
        topVC.present(activityVC, animated: true)
    }

    /// A static version of the card (no animations) for export rendering.
    private var shareCardForExport: some View {
        VStack(spacing: 20) {
            Text("SCALEUP")
                .font(.system(size: 16, weight: .black))
                .tracking(6)
                .foregroundStyle(goldColor)

            VStack(spacing: 4) {
                Text(formattedDate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text(topic)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            ZStack {
                Circle()
                    .stroke(goldColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(1.0, result.handicappedScore / 100.0))
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 104, height: 104)

                Text("\(Int(result.handicappedScore))")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(goldColor)
            }

            Text("Top \(percentileText) \u{00B7} \(result.correct)/\(result.total) correct")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            if result.isPersonalBest {
                Text("\u{1F3C6} New Personal Best!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(goldColor)
            }

            Rectangle()
                .fill(goldColor.opacity(0.2))
                .frame(height: 1)

            VStack(spacing: 6) {
                Text("Can you beat my score? \u{2192}")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text("scaleup.app/challenge")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(goldColor.opacity(0.6))
            }
        }
        .padding(28)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.black, darkGold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(goldColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }

    private var percentileText: String {
        let accuracy = Double(result.correct) / Double(max(1, result.total)) * 100
        return "\(Int(accuracy))%"
    }
}
