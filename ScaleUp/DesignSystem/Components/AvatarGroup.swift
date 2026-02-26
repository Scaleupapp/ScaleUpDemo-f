import SwiftUI
import NukeUI

// MARK: - AvatarGroup

struct AvatarGroup: View {
    let imageURLs: [String?]
    var maxDisplay: Int = 3
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: -8) {
            ForEach(displayURLs.indices, id: \.self) { index in
                avatarView(for: displayURLs[index])
                    .zIndex(Double(displayURLs.count - index))
            }

            if overflowCount > 0 {
                overflowBadge
                    .zIndex(0)
            }
        }
    }

    // MARK: - Private

    private var displayURLs: [String?] {
        Array(imageURLs.prefix(maxDisplay))
    }

    private var overflowCount: Int {
        max(0, imageURLs.count - maxDisplay)
    }

    private func avatarView(for urlString: String?) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        placeholderCircle
                    }
                }
            } else {
                placeholderCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(ColorTokens.backgroundDark, lineWidth: 2)
        )
    }

    private var placeholderCircle: some View {
        Circle()
            .fill(ColorTokens.surfaceElevatedDark)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
    }

    private var overflowBadge: some View {
        Circle()
            .fill(ColorTokens.surfaceDark)
            .frame(width: size, height: size)
            .overlay {
                Text("+\(overflowCount)")
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
            }
            .overlay(
                Circle()
                    .stroke(ColorTokens.backgroundDark, lineWidth: 2)
            )
    }
}
