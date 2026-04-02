import SwiftUI

struct NotesThumbnail: View {
    let title: String
    let domain: String?
    let pageCount: Int?

    private var gradientColors: [Color] {
        let palettes: [[Color]] = [
            [Color(hex: 0xE85D04), Color(hex: 0xBE3A00)], // warm orange
            [Color(hex: 0x2563EB), Color(hex: 0x1E40AF)], // blue
            [Color(hex: 0x7C3AED), Color(hex: 0x5B21B6)], // purple
            [Color(hex: 0x059669), Color(hex: 0x065F46)], // emerald
            [Color(hex: 0xDB2777), Color(hex: 0x9D174D)], // pink
            [Color(hex: 0xD97706), Color(hex: 0x92400E)], // amber
            [Color(hex: 0x0891B2), Color(hex: 0x155E75)], // teal
            [Color(hex: 0x4F46E5), Color(hex: 0x3730A3)], // indigo
        ]
        let hash = abs(title.hashValue)
        return palettes[hash % palettes.count]
    }

    var body: some View {
        ZStack {
            // Vibrant gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle texture overlay
            Canvas { context, size in
                // Diagonal lines for texture
                for i in stride(from: -size.height, through: size.width + size.height, by: 8) {
                    var path = Path()
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i - size.height, y: size.height))
                    context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Title as the main visual
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                if let domain = domain, !domain.isEmpty {
                    Text(domain.capitalized)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Page count pill top-right
            if let pages = pageCount {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(pages) pg")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.25))
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
    }
}
