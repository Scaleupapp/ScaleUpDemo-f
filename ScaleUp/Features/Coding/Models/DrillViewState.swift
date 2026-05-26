import Foundation

enum DrillViewState: Equatable {
    case loading
    case brief
    case input
    case submitting
    case result(grade: DrillResultGradedResponse)
    case error(String)
    case calibrationRequired   // backend says user has no MetaSkillMastery
    case noDrillAvailable      // backend says no bundle matches

    // For Equatable on the .result case (DrillResultGradedResponse isn't Equatable yet)
    static func == (lhs: DrillViewState, rhs: DrillViewState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.brief, .brief), (.input, .input),
             (.submitting, .submitting), (.calibrationRequired, .calibrationRequired),
             (.noDrillAvailable, .noDrillAvailable):
            return true
        case (.result(let a), .result(let b)):
            return a.attemptId == b.attemptId
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}
