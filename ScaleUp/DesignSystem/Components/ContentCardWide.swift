import SwiftUI
import NukeUI

struct ContentCardWide: View {
    let title: String
    let creatorName: String
    let domain: String
    let thumbnailURL: String?
    let duration: Int?
    var difficulty: Difficulty?
    var rating: Double?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed 16:9 thumbnail
            thumbnailView
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipped()

            // Gradient overlay
            GradientOverlay(startOpacity: 0, endOpacity: 0.9, startPoint: 0.3)

            // Duration badge at top-right
            if let duration {
                VStack {
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(Typography.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                    Spacer()
                }
                .padding(Spacing.md)
            }

            // Title + creator overlay at bottom-left
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Difficulty badge
                if let difficulty {
                    Text(difficulty.rawValue.capitalized)
                        .font(Typography.micro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 3)
                        .background(difficultyColor(difficulty))
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(Typography.displayMedium)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: Spacing.sm) {
                    Text(creatorName)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.white.opacity(0.85))

                    Text("·")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.white.opacity(0.5))

                    Text(domain)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.white.opacity(0.7))

                    if let rating, rating > 0 {
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.warning)
                            Text(String(format: "%.1f", rating))
                                .font(Typography.bodySmall)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailURL, let url = URL(string: thumbnailURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(ColorTokens.surfaceElevatedDark)
            .overlay {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner:
            return ColorTokens.success
        case .intermediate:
            return ColorTokens.warning
        case .advanced:
            return ColorTokens.error
        }
    }
}

#Preview {
    ContentCardWide(
        title: "Building Scalable Products",
        creatorName: "Jane Doe",
        domain: "Product Management",
        thumbnailURL: nil,
        duration: 1245,
        difficulty: .intermediate,
        rating: 4.7
    )
    .padding()
    .background(ColorTokens.backgroundDark)
}
