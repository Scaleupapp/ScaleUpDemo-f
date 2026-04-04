import Foundation
import SwiftUI

// MARK: - Interview Type

enum InterviewType: String, Codable, Sendable, CaseIterable, Identifiable {
    case mba_admissions
    case placement_hr
    case placement_technical
    case case_study
    case behavioral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mba_admissions: return "MBA Admissions"
        case .placement_hr: return "Placement - HR"
        case .placement_technical: return "Placement - Technical"
        case .case_study: return "Case Study"
        case .behavioral: return "Behavioral"
        }
    }

    var icon: String {
        switch self {
        case .mba_admissions: return "building.columns.fill"
        case .placement_hr: return "person.2.fill"
        case .placement_technical: return "gearshape.2.fill"
        case .case_study: return "chart.bar.doc.horizontal.fill"
        case .behavioral: return "brain.fill"
        }
    }

    var color: Color {
        switch self {
        case .mba_admissions: return .orange
        case .placement_hr: return .blue
        case .placement_technical: return .green
        case .case_study: return .purple
        case .behavioral: return .cyan
        }
    }

    var description: String {
        switch self {
        case .mba_admissions: return "IIM, ISB, XLRI style admissions"
        case .placement_hr: return "HR round, cultural fit, behavioral"
        case .placement_technical: return "Technical knowledge, problem solving"
        case .case_study: return "Consulting-style business cases"
        case .behavioral: return "STAR method, situational questions"
        }
    }
}

// MARK: - Difficulty

enum InterviewDifficulty: String, Codable, Sendable, CaseIterable {
    case easy, moderate, hard
    var displayName: String { rawValue.capitalized }
}

// MARK: - Status

enum InterviewStatus: String, Codable, Sendable {
    case setup, in_progress, completed, evaluating, evaluated, abandoned
}

// MARK: - Transcript Entry

struct TranscriptEntry: Codable, Sendable, Identifiable {
    let role: String // interviewer or candidate
    let content: String
    let questionNumber: Int?
    let isFollowUp: Bool?
    let timestamp: Double?
    let responseDuration: Double?
    let createdAt: Date?

    var id: String { "\(role)_\(timestamp ?? 0)_\(content.hashValue)" }
    var isInterviewer: Bool { role == "interviewer" }
}

// MARK: - Evaluation

struct InterviewSubScore: Codable, Sendable {
    let score: Int?
    let feedback: String?
}

struct PerQuestionFeedback: Codable, Sendable, Identifiable {
    let questionNumber: Int
    let question: String?
    let answer: String?
    let score: Int?
    let feedback: String?
    let modelAnswer: String?
    let strengths: [String]?
    let improvements: [String]?
    let responseTime: Double?
    let integrityFlag: String?

    var id: Int { questionNumber }
}

struct IntegrityReport: Codable, Sendable {
    let overallIntegrity: String? // clean, minor_flags, suspicious
    let flags: [String]?
    let recommendation: String?
}

struct InterviewEvaluation: Codable, Sendable {
    let overallScore: Int?
    let summary: String?
    let communication: InterviewSubScore?
    let content: InterviewSubScore?
    let structure: InterviewSubScore?
    let confidence: InterviewSubScore?
    let perQuestion: [PerQuestionFeedback]?
    let overallStrengths: [String]?
    let overallImprovements: [String]?
    let integrityReport: IntegrityReport?
}

// MARK: - Session (Full)

struct InterviewSession: Codable, Sendable, Identifiable {
    let id: String
    let userId: String?
    let interviewType: InterviewType
    let targetRole: String?
    let targetCompany: String?
    let difficulty: InterviewDifficulty
    let status: InterviewStatus
    let systemInstruction: String?
    let transcript: [TranscriptEntry]?
    let totalQuestions: Int?
    let startedAt: Date?
    let completedAt: Date?
    let duration: Int?
    let evaluation: InterviewEvaluation?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, interviewType, targetRole, targetCompany, difficulty
        case status, systemInstruction, transcript, totalQuestions
        case startedAt, completedAt, duration, evaluation, createdAt
    }
}

// MARK: - Session Summary (for list)

struct InterviewSessionSummary: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let interviewType: InterviewType
    let targetRole: String?
    let targetCompany: String?
    let difficulty: InterviewDifficulty
    let status: InterviewStatus
    let totalQuestions: Int?
    let duration: Int?
    let startedAt: Date?
    let createdAt: Date?

    // Nested evaluation.overallScore - decode manually
    let overallScore: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case interviewType, targetRole, targetCompany, difficulty
        case status, totalQuestions, duration, startedAt, createdAt
        case overallScore
    }

    // Try to decode overallScore from nested evaluation object
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        interviewType = try c.decode(InterviewType.self, forKey: .interviewType)
        targetRole = try c.decodeIfPresent(String.self, forKey: .targetRole)
        targetCompany = try c.decodeIfPresent(String.self, forKey: .targetCompany)
        difficulty = try c.decode(InterviewDifficulty.self, forKey: .difficulty)
        status = try c.decode(InterviewStatus.self, forKey: .status)
        totalQuestions = try c.decodeIfPresent(Int.self, forKey: .totalQuestions)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        // Backend select includes evaluation.overallScore flattened
        overallScore = try c.decodeIfPresent(Int.self, forKey: .overallScore)
    }

    var timeAgo: String {
        guard let date = createdAt ?? startedAt else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604800 { return "\(seconds / 86400)d ago" }
        return "\(seconds / 604800)w ago"
    }

    var durationString: String {
        guard let dur = duration else { return "" }
        let mins = dur / 60
        let secs = dur % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - API Response Types

struct StartInterviewResponse: Codable, Sendable {
    let _id: String
    let interviewType: InterviewType
    let targetRole: String?
    let targetCompany: String?
    let difficulty: InterviewDifficulty
    let status: InterviewStatus
    let systemInstruction: String
}

struct InterviewStatusResponse: Codable, Sendable {
    let status: InterviewStatus
}

// MARK: - Analytics

struct InterviewAnalytics: Codable, Sendable {
    let totalInterviews: Int
    let averageScore: Int
    let scoreTrend: [InterviewScorePoint]
    let dimensionAverages: DimensionAverages
    let weakestDimension: String?
    let interviewsThisWeek: Int
    let interviewsThisMonth: Int
    let typeBreakdown: [TypeCount]
}

struct InterviewScorePoint: Codable, Sendable, Identifiable {
    let date: Date?
    let score: Int
    let type: InterviewType?
    var id: String { "\(date?.timeIntervalSince1970 ?? 0)_\(score)" }
}

struct DimensionAverages: Codable, Sendable {
    let communication: Double
    let content: Double
    let structure: Double
    let confidence: Double
}

struct TypeCount: Codable, Sendable, Identifiable {
    let type: InterviewType
    let count: Int
    var id: String { type.rawValue }
}
