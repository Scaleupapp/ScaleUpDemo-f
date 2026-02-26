import SwiftUI
import NukeUI

struct HeroBannerView: View {
    let content: Content

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Taller hero — more cinematic feel
            thumbnailView
                .aspectRatio(4 / 3, contentMode: .fill)
                .frame(height: 240)
                .clipped()

            // Multi-stop gradient for better readability
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.05), location: 0.2),
                    .init(color: .black.opacity(0.3), location: 0.45),
                    .init(color: .black.opacity(0.7), location: 0.7),
                    .init(color: .black.opacity(0.95), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Side gradient for extra depth
            LinearGradient(
                colors: [ColorTokens.primary.opacity(0.15), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .opacity(0.6)

            // Content overlay
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Spacer()

                // Domain tag
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(ColorTokens.primary)
                        .frame(width: 6, height: 6)

                    Text(content.domain.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Spacing.sm + 2)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial.opacity(0.5))
                .clipShape(Capsule())

                // Title
                Text(content.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 3)

                // Creator + metadata
                HStack(spacing: Spacing.sm) {
                    Text(creatorFullName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    if let duration = content.duration {
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 3, height: 3)

                        Text(formatDuration(duration))
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if content.averageRating > 0 {
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 3, height: 3)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(ColorTokens.anchorGold)
                            Text(String(format: "%.1f", content.averageRating))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }

                // Action buttons
                HStack(spacing: Spacing.sm) {
                    // Play button — white with gradient edge
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                        Text("Watch Now")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, Spacing.md + 4)
                    .padding(.vertical, Spacing.sm + 3)
                    .background(.white)
                    .clipShape(Capsule())

                    // Bookmark button
                    Button {
                        // Save action handled by parent
                    } label: {
                        Image(systemName: "bookmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // Share button
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [
                            ColorTokens.primary.opacity(0.2),
                            .clear,
                            ColorTokens.primary.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailURL = content.resolvedThumbnailURL, let url = URL(string: thumbnailURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if state.error != nil {
                    placeholderView
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
            .fill(
                LinearGradient(
                    colors: [ColorTokens.primaryDark, ColorTokens.surfaceElevatedDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Featured Content")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.15))
                }
            }
    }

    // MARK: - Helpers

    private var creatorFullName: String {
        "\(content.creator.firstName) \(content.creator.lastName)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%dh %dm", hours, remainingMinutes)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
