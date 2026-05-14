import Foundation

/// Shared state across the v2 onboarding flow:
///   ObjectiveSetup → Confirm → TopicSelection → TopicProficiency
///   → [save w/ computed hours] → Diagnostic → RealityCheck → Calibration → Home
@Observable
@MainActor
final class V2OnboardingState {

    // MARK: - Step 1-2: objective entry + NLU parse

    var rawGoalText: String = ""
    var parseResult: V2ObjectiveParseResult?

    // Resolved structured objective (from the parse, possibly user-corrected)
    var objectiveType: V2ObjectiveType = .interviewPreparation
    var targetRole: String = ""
    var targetCompany: String = ""
    var examName: String = ""
    var targetSkill: String = ""
    var fromDomain: String = ""
    var toDomain: String = ""

    var timeline: V2Timeline = .sixMonths
    var currentLevel: V2CurrentLevel = .intermediate

    // MARK: - Step 3-4: topics + proficiency

    var suggestedTopics: [V2SuggestedTopic] = []
    var selectedTopics: [V2SuggestedTopic] = []        // after user add/remove
    // canonicalName → proficiency
    var topicProficiency: [String: V2Proficiency] = [:]

    // MARK: - Computed + saved

    var computedWeeklyHours: Int?       // from requiredTimeService, set before save
    var savedObjectiveId: String?       // after /onboarding/complete
    var diagnosticAttemptId: String?    // after diagnostic finishes

    // MARK: - Derived: specifics dict for API payloads

    var specifics: [String: String] {
        var s: [String: String] = [:]
        if !targetRole.isEmpty   { s["targetRole"] = targetRole }
        if !targetCompany.isEmpty { s["targetCompany"] = targetCompany }
        if !examName.isEmpty     { s["examName"] = examName }
        if !targetSkill.isEmpty  { s["targetSkill"] = targetSkill }
        if !fromDomain.isEmpty   { s["fromDomain"] = fromDomain }
        if !toDomain.isEmpty     { s["toDomain"] = toDomain }
        return s
    }

    /// Apply a parse result into the structured fields.
    func applyParse(_ result: V2ObjectiveParseResult) {
        parseResult = result
        if let t = V2ObjectiveType(rawValue: result.objectiveType) {
            objectiveType = t
        }
        targetRole    = result.specifics.targetRole ?? ""
        targetCompany = result.specifics.targetCompany ?? ""
        examName      = result.specifics.examName ?? ""
        targetSkill   = result.specifics.targetSkill ?? ""
        fromDomain    = result.specifics.fromDomain ?? ""
        toDomain      = result.specifics.toDomain ?? ""
    }

    // MARK: - Payload builders

    func requiredTimeBody() -> V2RequiredTimeRequest {
        V2RequiredTimeRequest(
            objectiveType: objectiveType.rawValue,
            specifics: specifics,
            timeline: timeline.rawValue,
            currentLevel: currentLevel.rawValue
        )
    }

    /// Body for v1 POST /onboarding/topics/suggest
    func topicsSuggestBody() -> V2TopicsSuggestRequest {
        V2TopicsSuggestRequest(
            objectiveType: objectiveType.rawValue,
            specifics: specifics,
            targetCompany: targetCompany.isEmpty ? nil : targetCompany
        )
    }

    /// Body for v1 POST /onboarding/complete — saves the objective with the
    /// COMPUTED weekly hours (not asked). topicSelfRatings is the per-topic map.
    func onboardingCompleteBody(weeklyCommitHours: Int) -> V2OnboardingCompleteRequest {
        var ratings: [String: String] = [:]
        for topic in selectedTopics {
            if let prof = topicProficiency[topic.canonicalName] {
                ratings[topic.canonicalName] = prof.rawValue
            }
        }
        return V2OnboardingCompleteRequest(
            objectiveType: objectiveType.rawValue,
            specifics: specifics,
            timeline: timeline.rawValue,
            currentLevel: currentLevel.rawValue,
            weeklyCommitHours: weeklyCommitHours,
            topicsOfInterest: selectedTopics.map { $0.canonicalName },
            topicSelfRatings: ratings
        )
    }
}

// MARK: - Enums

enum V2ObjectiveType: String, Codable, CaseIterable {
    case careerSwitch         = "career_switch"
    case interviewPreparation = "interview_preparation"
    case competitiveExam      = "exam_preparation"
    case upskilling           = "upskilling"
    case academicExcellence   = "academic_excellence"

    var displayName: String {
        switch self {
        case .careerSwitch:         return "Career Switch"
        case .interviewPreparation: return "Interview / Placement Prep"
        case .competitiveExam:      return "Competitive Exam"
        case .upskilling:           return "Upskilling"
        case .academicExcellence:   return "College / University Exam"
        }
    }
}

enum V2Timeline: String, Codable, CaseIterable {
    case oneMonth    = "1_month"
    case threeMonths = "3_months"
    case sixMonths   = "6_months"
    case oneYear     = "1_year"
    case noDeadline  = "no_deadline"

    var label: String {
        switch self {
        case .oneMonth:    return "1 month"
        case .threeMonths: return "3 months"
        case .sixMonths:   return "6 months"
        case .oneYear:     return "12 months"
        case .noDeadline:  return "No fixed deadline"
        }
    }
}

enum V2CurrentLevel: String, Codable, CaseIterable {
    case beginner     = "beginner"
    case intermediate = "intermediate"
    case advanced     = "advanced"

    var label: String {
        switch self {
        case .beginner:     return "Just starting"
        case .intermediate: return "Some experience"
        case .advanced:     return "Quite experienced"
        }
    }
}

/// Per-topic self-rating — matches v1 UserObjective.topicSelfRatings enum.
enum V2Proficiency: String, Codable, CaseIterable {
    case novice
    case familiar
    case proficient
    case expert

    var label: String {
        switch self {
        case .novice:     return "Novice"
        case .familiar:   return "Familiar"
        case .proficient: return "Proficient"
        case .expert:     return "Expert"
        }
    }
    var order: Int {
        switch self {
        case .novice: return 0
        case .familiar: return 1
        case .proficient: return 2
        case .expert: return 3
        }
    }
}

// MARK: - API request/response models

struct V2RequiredTimeRequest: Codable {
    let objectiveType: String
    let specifics: [String: String]
    let timeline: String
    let currentLevel: String
}

/// Response from POST /api/v2/objective/required-time
struct V2RequiredTimeResponse: Codable {
    let requiredHoursPerWeek: Int
    let requiredHoursPerDay: Double
    let totalHoursRemaining: Int
    let timelineWeeks: Int
    let baselineLabel: String
    let paths: Paths
    let warnings: [String]

    struct Paths: Codable {
        let commit: PathOption
        let lessTime: PathOptionAlt
        let moreTime: PathOptionAlt
    }
    struct PathOption: Codable {
        let hoursPerWeek: Int
        let label: String
    }
    struct PathOptionAlt: Codable {
        let hoursPerWeek: Int
        let timelineLabel: String
    }
}

struct V2TopicsSuggestRequest: Codable {
    let objectiveType: String
    let specifics: [String: String]
    let targetCompany: String?
}

/// v1 /onboarding/topics/suggest response (raw, not enveloped)
struct V2TopicsSuggestResponse: Codable {
    let targetKey: String
    let source: String
    let cacheHit: Bool
    let topics: [V2SuggestedTopic]
}

struct V2SuggestedTopic: Codable, Identifiable, Hashable {
    let name: String
    let canonicalName: String
    let description: String
    let baseDifficulty: String?
    let isFutureProofing: Bool?
    let sortOrder: Int?
    var isGenAITopic: Bool?
    /// Marks a topic the user added themselves (not from the suggestion).
    var userAdded: Bool?

    var id: String { canonicalName }
}

struct V2OnboardingCompleteRequest: Codable {
    let objectiveType: String
    let specifics: [String: String]
    let timeline: String
    let currentLevel: String
    let weeklyCommitHours: Int
    let topicsOfInterest: [String]
    let topicSelfRatings: [String: String]
}

/// v1 /onboarding/complete response (raw)
struct V2OnboardingCompleteResponse: Codable {
    let userObjectiveId: String
    let needsCalibration: Bool
}

// MARK: - NLU parse result (from /api/v2/objective/parse)

struct V2ObjectiveParseResult: Codable {
    let status: String                 // green | long_tail | rejected
    let rejectionKind: String?         // off_mission | gibberish | ambiguous
    let objectiveType: String
    let specifics: ParsedSpecifics
    let interpretation: String
    let confidence: String
    let flags: [String]
    let catalogMatches: CatalogMatches
    let message: ParseMessage
    let needsConfirmation: Bool

    struct ParsedSpecifics: Codable {
        let examName: String?
        let targetSkill: String?
        let targetRole: String?
        let targetCompany: String?
        let fromDomain: String?
        let toDomain: String?
    }
    struct CatalogMatches: Codable {
        let role: CatalogMatch?
        let company: CatalogMatch?
        let exam: CatalogMatch?
        let skill: CatalogMatch?
    }
    struct CatalogMatch: Codable {
        let slug: String
        let name: String
        let type: String
        let category: String?
    }
    struct ParseMessage: Codable {
        let title: String
        let body: String
        let showCatalogBrowse: Bool?
    }

    var isGreen: Bool { status == "green" }
    var isLongTail: Bool { status == "long_tail" }
    var isRejected: Bool { status == "rejected" }
}

// MARK: - Catalog typeahead (from /api/v2/objective/suggest + /popular)

struct V2CatalogEntry: Codable, Identifiable, Hashable {
    let type: String
    let name: String
    let canonicalSlug: String
    let mapsToObjectiveType: String
    let category: String?

    var id: String { "\(type)-\(canonicalSlug)" }
}
