import Foundation

enum UserRole: String, Codable, Hashable, CaseIterable {
    case consumer
    case creator
    case admin
}
