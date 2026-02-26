import Foundation

enum JourneyPhase: String, Codable, Hashable {
    case foundation
    case building
    case strengthening
    case mastery
    case revision
    case examPrep = "exam_prep"
}
