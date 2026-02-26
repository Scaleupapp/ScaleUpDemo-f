import SwiftUI

struct CreatorSpotlightRow: View {
    let creators: [CreatorSearchResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 4) {
            // Enhanced section header
            HStack(spacing: Spacing.xs + 2) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.primary)

                Text("Top Creators")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                HStack(spacing: 2) {
                    Text("See All")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ColorTokens.primary)
                }
            }
            .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.md) {
                    ForEach(creators) { creator in
                        creatorCard(creator)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - Creator Card

    private func creatorCard(_ creator: CreatorSearchResult) -> some View {
        Button {
            // Creator profile navigation
        } label: {
            VStack(spacing: Spacing.sm) {
                // Avatar with double-ring tier indicator
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            tierGradient(creator.creatorProfile?.tier.rawValue ?? "rising"),
                            lineWidth: 2.5
                        )
                        .frame(width: 72, height: 72)

                    // Inner subtle ring
                    Circle()
                        .stroke(
                            tierGradient(creator.creatorProfile?.tier.rawValue ?? "rising"),
                            lineWidth: 1
                        )
                        .frame(width: 78, height: 78)
                        .opacity(0.3)

                    CreatorAvatar(
                        imageURL: nil,
                        name: creator.displayName,
                        tier: creator.creatorProfile?.tier.rawValue ?? "rising",
                        size: 64
                    )
                }

                VStack(spacing: 2) {
                    Text(creator.firstName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    Text(creator.creatorProfile?.domain ?? "Creator")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                        .lineLimit(1)

                    // Follower count or tier badge
                    Text(tierLabel(creator.creatorProfile?.tier.rawValue ?? "rising"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tierTextColor(creator.creatorProfile?.tier.rawValue ?? "rising"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierTextColor(creator.creatorProfile?.tier.rawValue ?? "rising").opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 88)
        }
        .buttonStyle(.plain)
    }

    private func tierGradient(_ tier: String) -> LinearGradient {
        switch tier.lowercased() {
        case "anchor":
            return LinearGradient(
                colors: [ColorTokens.anchorGold, ColorTokens.anchorGold.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case "core":
            return LinearGradient(
                colors: [ColorTokens.coreSilver, ColorTokens.coreSilver.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [ColorTokens.risingBronze, ColorTokens.risingBronze.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private func tierLabel(_ tier: String) -> String {
        switch tier.lowercased() {
        case "anchor": return "ANCHOR"
        case "core": return "CORE"
        default: return "RISING"
        }
    }

    private func tierTextColor(_ tier: String) -> Color {
        switch tier.lowercased() {
        case "anchor": return ColorTokens.anchorGold
        case "core": return ColorTokens.coreSilver
        default: return ColorTokens.risingBronze
        }
    }
}
