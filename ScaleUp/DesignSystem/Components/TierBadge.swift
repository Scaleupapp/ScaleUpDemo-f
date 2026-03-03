import SwiftUI

struct TierBadge: View {
    let tier: CreatorTier
    var compact: Bool = false

    var body: some View {
        if compact {
            Image(systemName: tier.icon)
                .font(.system(size: 8))
                .foregroundStyle(tier.color)
        } else {
            HStack(spacing: 3) {
                Image(systemName: tier.icon)
                    .font(.system(size: 8))
                Text(tier.displayName)
                    .font(Typography.micro)
            }
            .foregroundStyle(tier.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tier.color.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}
