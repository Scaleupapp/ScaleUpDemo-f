import SwiftUI

struct StarRating: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var isInteractive: Bool = true
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? ColorTokens.warning : ColorTokens.textTertiaryDark)
                    .onTapGesture {
                        guard isInteractive else { return }
                        withAnimation(Animations.quick) {
                            rating = star
                        }
                    }
            }
        }
    }
}

struct StarRatingDisplay: View {
    let rating: Double
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(ColorTokens.warning)

            Text(String(format: "%.1f", rating))
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }
}
