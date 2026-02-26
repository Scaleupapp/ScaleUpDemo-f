import Foundation

enum QuizStatus: String, Codable, Hashable {
    case generating
    case ready
    case delivered
    case inProgress = "in_progress"
    case completed
    case expired
}
