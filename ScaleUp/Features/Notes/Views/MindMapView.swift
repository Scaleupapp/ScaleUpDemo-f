import SwiftUI

struct MindMapView: View {
    let mindMap: MindMap
    @State private var scale: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss

    private let nodeWidth: CGFloat = 120
    private let nodeHeight: CGFloat = 50
    private let levelSpacing: CGFloat = 120
    private let siblingSpacing: CGFloat = 20

    var body: some View {
        NavigationStack {
            mapContent
                .background(ColorTokens.background)
                .navigationTitle(mindMap.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(ColorTokens.gold)
                    }
                }
        }
    }

    private var mapContent: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            ZStack {
                edgesLayer
                nodesLayer
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .padding(40)
        }
        .scaleEffect(scale)
        .gesture(MagnificationGesture().onChanged { scale = $0 }.onEnded { scale = max(0.5, min(2.0, $0)) })
    }

    private var edgesLayer: some View {
        ForEach(Array(mindMap.edges.enumerated()), id: \.offset) { _, edge in
            edgePath(edge)
        }
    }

    @ViewBuilder
    private func edgePath(_ edge: MindMapEdge) -> some View {
        if let fromPos = nodePosition(edge.from),
           let toPos = nodePosition(edge.to) {
            let isRelated = edge.type == "related"
            Path { path in
                path.move(to: fromPos)
                let controlPt = CGPoint(x: (fromPos.x + toPos.x) / 2, y: fromPos.y + (toPos.y - fromPos.y) * 0.3)
                path.addQuadCurve(to: toPos, control: controlPt)
            }
            .stroke(
                isRelated ? Color.orange.opacity(0.3) : Color.white.opacity(0.15),
                style: StrokeStyle(lineWidth: isRelated ? 1 : 1.5, dash: isRelated ? [4, 4] : [])
            )
        }
    }

    private var nodesLayer: some View {
        ForEach(mindMap.nodes) { node in
            if let pos = nodePosition(node.id) {
                nodeView(node)
                    .position(pos)
            }
        }
    }

    // MARK: - Node View

    @ViewBuilder
    private func nodeView(_ node: MindMapNode) -> some View {
        VStack(spacing: 4) {
            Text(node.label)
                .font(.system(size: node.level == 0 ? 13 : 11, weight: node.level == 0 ? .bold : .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let desc = node.description, !desc.isEmpty, node.level < 2 {
                Text(desc)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: node.level == 0 ? 140 : nodeWidth)
        .background(nodeColor(node))
        .clipShape(RoundedRectangle(cornerRadius: node.level == 0 ? 16 : 10))
        .shadow(color: nodeColor(node).opacity(0.3), radius: 4, y: 2)
    }

    private func nodeColor(_ node: MindMapNode) -> Color {
        switch node.color {
        case "primary": return ColorTokens.gold
        case "blue": return Color(hex: 0x2563EB)
        case "green": return Color(hex: 0x059669)
        case "purple": return Color(hex: 0x7C3AED)
        case "orange": return Color(hex: 0xE85D04)
        case "teal": return Color(hex: 0x0891B2)
        default: return node.level == 0 ? ColorTokens.gold : Color(hex: 0x334155)
        }
    }

    // MARK: - Layout

    private var canvasSize: CGSize {
        let positions = computePositions()
        let maxX = positions.values.map(\.x).max() ?? 400
        let maxY = positions.values.map(\.y).max() ?? 400
        return CGSize(width: maxX + nodeWidth + 80, height: maxY + nodeHeight + 80)
    }

    private func nodePosition(_ nodeId: String) -> CGPoint? {
        computePositions()[nodeId]
    }

    private func computePositions() -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        let root = mindMap.nodes.first { $0.level == 0 }
        guard let root else { return positions }

        let level1 = mindMap.nodes.filter { $0.level == 1 }
        let centerX: CGFloat = 400
        let startY: CGFloat = 40

        positions[root.id] = CGPoint(x: centerX, y: startY)

        let l1StartX: CGFloat = centerX - CGFloat(level1.count - 1) * (nodeWidth + siblingSpacing) / 2
        for (i, node) in level1.enumerated() {
            let x = l1StartX + CGFloat(i) * (nodeWidth + siblingSpacing)
            positions[node.id] = CGPoint(x: x, y: startY + levelSpacing)

            // Level 2 children
            let children = mindMap.nodes.filter { $0.parentId == node.id && $0.level == 2 }
            let childStartX = x - CGFloat(children.count - 1) * (nodeWidth + 10) / 2
            for (j, child) in children.enumerated() {
                let cx = childStartX + CGFloat(j) * (nodeWidth + 10)
                positions[child.id] = CGPoint(x: cx, y: startY + levelSpacing * 2)
            }
        }

        return positions
    }
}
