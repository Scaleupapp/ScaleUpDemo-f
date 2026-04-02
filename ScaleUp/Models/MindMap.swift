import Foundation

struct MindMapNode: Codable, Sendable, Identifiable {
    let id: String
    let label: String
    let description: String?
    let level: Int
    let parentId: String?
    let importance: Int?
    let color: String?
}

struct MindMapEdge: Codable, Sendable {
    let from: String
    let to: String
    let label: String?
    let type: String?
}

struct MindMap: Codable, Sendable, Identifiable {
    let id: String
    let userId: String?
    let contentId: MindMapContentRef?
    let title: String
    let nodes: [MindMapNode]
    let edges: [MindMapEdge]
    let totalNodes: Int?
    let status: String?
    let generatedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, contentId, title, nodes, edges, totalNodes, status, generatedAt, createdAt
    }
}

// For populated contentId
enum MindMapContentRef: Codable, Sendable {
    case id(String)
    case populated(MindMapContentDetail)

    struct MindMapContentDetail: Codable, Sendable {
        let _id: String
        let title: String
        let domain: String?
        let contentType: String?
    }

    init(from decoder: Decoder) throws {
        if let str = try? decoder.singleValueContainer().decode(String.self) {
            self = .id(str)
        } else {
            self = .populated(try MindMapContentDetail(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .id(let str):
            var c = encoder.singleValueContainer()
            try c.encode(str)
        case .populated(let detail):
            try detail.encode(to: encoder)
        }
    }
}
