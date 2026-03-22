import SwiftUI

// MARK: - ScaleUp Logo
// "sUp" — the U has an upward arrow integrated into it.
// Matches the brand icon: lowercase s, uppercase U with arrow stem, lowercase p.

struct ScaleUpLogo: View {
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: fontSize * -0.02) {
            // "s" — lowercase
            Text("s")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(ColorTokens.gold)

            // "U" with integrated arrow
            UpArrowLetter(fontSize: fontSize)

            // "p" — lowercase
            Text("p")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(ColorTokens.gold)
        }
    }
}

// MARK: - U with Arrow
// The U letter has its right stem extended upward into an arrow

private struct UpArrowLetter: View {
    let fontSize: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            // Base U letter
            Text("U")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(ColorTokens.gold)

            // Arrow extending from the U
            ArrowStem(fontSize: fontSize)
                .offset(y: -fontSize * 0.28)
        }
    }
}

// MARK: - Arrow Stem
// Upward arrow that extends from the top of the U

private struct ArrowStem: View {
    let fontSize: CGFloat

    private var stemHeight: CGFloat { fontSize * 0.35 }
    private var strokeWidth: CGFloat { max(fontSize * 0.12, 3) }
    private var headSize: CGFloat { fontSize * 0.18 }

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let gold = Color(hex: 0xE8B84B)

            // Stem
            var stem = Path()
            stem.move(to: CGPoint(x: midX, y: size.height))
            stem.addLine(to: CGPoint(x: midX, y: headSize * 1.1))
            context.stroke(stem, with: .color(gold),
                           style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Arrowhead
            var head = Path()
            head.move(to: CGPoint(x: midX - headSize, y: headSize * 1.3))
            head.addLine(to: CGPoint(x: midX, y: 0))
            head.addLine(to: CGPoint(x: midX + headSize, y: headSize * 1.3))
            context.stroke(head, with: .color(gold),
                           style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: headSize * 3, height: stemHeight)
    }
}
