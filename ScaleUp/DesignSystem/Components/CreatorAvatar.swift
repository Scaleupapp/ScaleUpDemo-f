import SwiftUI
import NukeUI

struct CreatorAvatar: View {
    let imageURL: String?
    let name: String
    var tier: String? // "anchor", "core", "rising"
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            // Tier ring
            Circle()
                .stroke(tierColor, lineWidth: tier != nil ? 2.5 : 0)
                .frame(width: size + 6, height: size + 6)

            // Avatar
            if let imageURL, let url = URL(string: imageURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        initialsView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(ColorTokens.surfaceElevatedDark)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundStyle(ColorTokens.primary)
            }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }

    private var tierColor: Color {
        switch tier?.lowercased() {
        case "anchor": return ColorTokens.anchorGold
        case "core": return ColorTokens.coreSilver
        case "rising": return ColorTokens.risingBronze
        default: return .clear
        }
    }
}
