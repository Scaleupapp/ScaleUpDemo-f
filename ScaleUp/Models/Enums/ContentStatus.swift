import Foundation

enum ContentStatus: String, Codable, Hashable {
    case draft
    case processing
    case ready
    case published
    case unpublished
    case rejected
}
