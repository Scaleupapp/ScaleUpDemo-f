import SwiftUI

struct CreatorAvatar: View {
    let creator: Creator
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let url = creator.profilePicture, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        initialsView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .overlay(
            Circle()
                .stroke(tierColor, lineWidth: size > 30 ? 2 : 1.5)
        )
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.surfaceElevated)
                .frame(width: size, height: size)

            Text(creator.initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var tierColor: Color {
        creator.tier?.color ?? ColorTokens.border
    }
}
