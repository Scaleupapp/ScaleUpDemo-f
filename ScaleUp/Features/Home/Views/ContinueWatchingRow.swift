import SwiftUI

// MARK: - Continue Watching Row

struct ContinueWatchingRow: View {
    let items: [ContentProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Continue Watching")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(items) { item in
                        NavigationLink(value: item.contentId.contentIdString) {
                            ContinueWatchingCard(progress: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }
}

// MARK: - Continue Watching Card

private struct ContinueWatchingCard: View {
    let progress: ContentProgress

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Thumbnail placeholder with progress overlay
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(ColorTokens.surfaceElevatedDark)
                    .frame(width: 200, height: 112)
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }

                // Gradient overlay
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(ColorTokens.cardOverlayGradient)
                    .frame(width: 200, height: 112)

                // Progress bar at bottom
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        Rectangle()
                            .fill(ColorTokens.primary)
                            .frame(
                                width: geo.size.width * progress.percentageCompleted / 100,
                                height: 3
                            )
                    }
                    .frame(width: 200, height: 3)
                }
                .frame(width: 200, height: 112)

                // Time remaining
                Text(formatRemaining())
                    .font(Typography.micro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(Spacing.sm)
            }

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text("Content")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)

                Text("\(Int(progress.percentageCompleted))% complete")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
        }
        .frame(width: 200)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surfaceDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private func formatRemaining() -> String {
        let remaining = Int(progress.totalDuration - progress.currentPosition)
        let minutes = remaining / 60
        if minutes > 0 {
            return "\(minutes) min left"
        }
        return "\(remaining)s left"
    }
}
