import SwiftUI

// MARK: - ScaleUp Logo
// "scaleUp" — uses real Text for all letters, overlays an arrow on the U's right stem.

struct ScaleUpLogo: View {
    let fontSize: CGFloat

    var body: some View {
        // Render "scaleUp" as a single text, then overlay the arrow
        ZStack(alignment: .topTrailing) {
            Text("scaleUp")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(ColorTokens.gold)

            // Arrow extending upward from the U
            // Position it over the U's right vertical stroke
            ArrowOverlay(fontSize: fontSize)
                .offset(
                    x: -fontSize * 0.28,   // align with U's right stroke
                    y: -fontSize * 0.32     // extend above the U
                )
        }
    }
}

// MARK: - Arrow Overlay
// Just the upward arrow stem + chevron head that sits on top of the U

private struct ArrowOverlay: View {
    let fontSize: CGFloat

    private var stemHeight: CGFloat { fontSize * 0.38 }
    private var strokeWidth: CGFloat { max(fontSize * 0.1, 2.5) }
    private var headSize: CGFloat { fontSize * 0.14 }

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let gold = Color(hex: 0xD4A843)

            // Stem
            var stem = Path()
            stem.move(to: CGPoint(x: midX, y: size.height))
            stem.addLine(to: CGPoint(x: midX, y: headSize * 1.1))
            context.stroke(stem, with: .color(gold),
                           style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Chevron arrowhead
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
