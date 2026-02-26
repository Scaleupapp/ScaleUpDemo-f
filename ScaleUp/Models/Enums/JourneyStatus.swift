import Foundation

enum JourneyStatus: String, Codable, Hashable {
    case generating
    case active
    case paused
    case completed
    case abandoned
}
