import SwiftUI
import NukeUI

struct ContentCard: View {
    let title: String
    let creatorName: String
    let domain: String
    let thumbnailURL: String?
    let duration: Int?
    var rating: Double?
    var viewCount: Int?
    var progress: Double?
    var isNew: Bool = false
    var isYouTube: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                thumbnailView
                    .frame(width: 180, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small + 4))

                // Subtle gradient overlay at bottom
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small + 4))

                // Duration badge — top right
                if let duration {
                    VStack {
                        HStack {
                            Spacer()
                            Text(formatDuration(duration))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Spacer()
                    }
                    .padding(Spacing.xs + 2)
                }

                // NEW badge — top left
                if isNew {
                    VStack {
                        HStack {
                            Text("NEW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(ColorTokens.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(Spacing.xs + 2)
                }

                // Progress bar at bottom
                if let progress, progress > 0 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(.white.opacity(0.2))
                                Rectangle()
                                    .fill(ColorTokens.primary)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(height: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }

            // Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(creatorName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(domain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.primary.opacity(0.8))

                    if let rating {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiaryDark)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(ColorTokens.warning)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                        }
                    }

                    if let viewCount {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                        Text(formatViewCount(viewCount))
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }
        }
        .frame(width: 180)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surfaceDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [
                            ColorTokens.surfaceElevatedDark,
                            ColorTokens.primary.opacity(0.12),
                            ColorTokens.surfaceElevatedDark,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailURL, let url = URL(string: thumbnailURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if state.error != nil {
                    // On error, show placeholder
                    placeholderView
                } else {
                    // Loading state
                    placeholderView
                }
            }
            .frame(width: 180, height: 110)
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(ColorTokens.surfaceElevatedDark)
            .overlay {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count) views"
    }
}
