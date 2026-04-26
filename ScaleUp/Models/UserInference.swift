import Foundation

// MARK: - UserInference (BUG-8 Phase 9)
//
// One inferred fact about the user that the system has surfaced for
// transparency. The user can confirm it (we got it right) or dismiss
// it (we got it wrong — stop using this in personalisation).

struct UserInference: Decodable, Identifiable, Sendable {
    let _id: String
    let userId: String?
    let key: String
    let kind: InferenceKind
    let title: String
    let description: String
    let status: InferenceStatus
    let firstSurfacedAt: String?
    let resolvedAt: String?

    var id: String { key }

    enum InferenceKind: String, Decodable, Sendable {
        case cognitiveTrait = "cognitive_trait"
        case goalBlocker    = "goal_blocker"
        case misconception
    }

    enum InferenceStatus: String, Decodable, Sendable {
        case pending, confirmed, dismissed
    }
}
