import SwiftUI

struct VerifiedBadge: View {
    var compact: Bool = false

    var body: some View {
        if compact {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.gold)
        } else {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 8))
                Text("Verified")
                    .font(Typography.micro)
            }
            .foregroundStyle(ColorTokens.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ColorTokens.gold.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}
