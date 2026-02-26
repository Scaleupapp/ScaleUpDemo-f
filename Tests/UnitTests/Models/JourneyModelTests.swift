import XCTest
@testable import ScaleUp

// MARK: - Journey Model Tests

/// Tests for `Journey`, `JourneyPhaseDetail`, `WeeklyPlan`, `DailyAssignment`,
/// `Milestone`, `JourneyProgress`, `TodayPlan`, and related enum decoding.
final class JourneyModelTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Journey Decoding

    func testJourney_decodesFromFullJSON() throws {
        // Given
        let json = JSONFactory.journeyJSON(
            id: "journey-abc",
            userId: "user-123",
            objectiveId: "obj-456",
            title: "Master iOS Development",
            currentPhase: "building",
            currentWeek: 3,
            status: "active",
            createdAt: "2025-01-01T00:00:00.000Z"
        )
        let data = JSONFactory.data(from: json)

        // When
        let journey = try decoder.decode(Journey.self, from: data)

        // Then
        XCTAssertEqual(journey.id, "journey-abc")
        XCTAssertEqual(journey.userId, "user-123")
        XCTAssertEqual(journey.objectiveId, "obj-456")
        XCTAssertEqual(journey.title, "Master iOS Development")
        XCTAssertEqual(journey.currentPhase, .building)
        XCTAssertEqual(journey.currentWeek, 3)
        XCTAssertEqual(journey.status, .active)
        XCTAssertEqual(journey.createdAt, "2025-01-01T00:00:00.000Z")
    }

    func testJourney_idMapsFromUnderscore() throws {
        let json = JSONFactory.journeyJSON(id: "mongo_journey_id")
        let data = JSONFactory.data(from: json)
        let journey = try decoder.decode(Journey.self, from: data)
        XCTAssertEqual(journey.id, "mongo_journey_id")
    }

    func testJourney_containsNestedCollections() throws {
        let phases = [
            JSONFactory.journeyPhaseDetailJSON(name: "foundation"),
            JSONFactory.journeyPhaseDetailJSON(name: "building")
        ]
        let weeklyPlans = [
            JSONFactory.weeklyPlanJSON(weekNumber: 1),
            JSONFactory.weeklyPlanJSON(weekNumber: 2)
        ]
        let milestones = [
            JSONFactory.milestoneJSON(id: "m1"),
            JSONFactory.milestoneJSON(id: "m2")
        ]

        let json = JSONFactory.journeyJSON(
            phases: phases,
            weeklyPlans: weeklyPlans,
            milestones: milestones
        )
        let data = JSONFactory.data(from: json)

        let journey = try decoder.decode(Journey.self, from: data)

        XCTAssertEqual(journey.phases.count, 2)
        XCTAssertEqual(journey.weeklyPlans.count, 2)
        XCTAssertEqual(journey.milestones.count, 2)
    }

    // MARK: - JourneyPhaseDetail Decoding

    func testJourneyPhaseDetail_decodesFromFullJSON() throws {
        let json = JSONFactory.journeyPhaseDetailJSON(
            name: "mastery",
            description: "Achieve mastery level",
            topics: ["Advanced Patterns", "Architecture"],
            weekNumbers: [7, 8, 9],
            estimatedDuration: "3 weeks"
        )
        let data = JSONFactory.data(from: json)

        let phase = try decoder.decode(JourneyPhaseDetail.self, from: data)

        XCTAssertEqual(phase.name, .mastery)
        XCTAssertEqual(phase.description, "Achieve mastery level")
        XCTAssertEqual(phase.topics, ["Advanced Patterns", "Architecture"])
        XCTAssertEqual(phase.weekNumbers, [7, 8, 9])
        XCTAssertEqual(phase.estimatedDuration, "3 weeks")
    }

    func testJourneyPhaseDetail_missingOptionalDuration() throws {
        let json = JSONFactory.journeyPhaseDetailJSON(estimatedDuration: nil)
        let data = JSONFactory.data(from: json)

        let phase = try decoder.decode(JourneyPhaseDetail.self, from: data)

        XCTAssertNil(phase.estimatedDuration)
    }

    // MARK: - WeeklyPlan Decoding

    func testWeeklyPlan_decodesFromJSON() throws {
        let assignments = [
            JSONFactory.dailyAssignmentJSON(day: 1, estimatedMinutes: 30),
            JSONFactory.dailyAssignmentJSON(day: 2, estimatedMinutes: 45),
            JSONFactory.dailyAssignmentJSON(day: 3, estimatedMinutes: 60)
        ]
        let json = JSONFactory.weeklyPlanJSON(
            weekNumber: 2,
            theme: "Intermediate Concepts",
            dailyAssignments: assignments
        )
        let data = JSONFactory.data(from: json)

        let plan = try decoder.decode(WeeklyPlan.self, from: data)

        XCTAssertEqual(plan.weekNumber, 2)
        XCTAssertEqual(plan.theme, "Intermediate Concepts")
        XCTAssertEqual(plan.dailyAssignments.count, 3)
        XCTAssertEqual(plan.dailyAssignments[0].day, 1)
        XCTAssertEqual(plan.dailyAssignments[1].estimatedMinutes, 45)
    }

    // MARK: - DailyAssignment Decoding

    func testDailyAssignment_decodesFromJSON() throws {
        let json = JSONFactory.dailyAssignmentJSON(
            day: 5,
            topics: ["Error Handling", "Optionals"],
            contentIds: ["c1", "c2", "c3"],
            estimatedMinutes: 90,
            isRestDay: false
        )
        let data = JSONFactory.data(from: json)

        let assignment = try decoder.decode(DailyAssignment.self, from: data)

        XCTAssertEqual(assignment.day, 5)
        XCTAssertEqual(assignment.topics, ["Error Handling", "Optionals"])
        XCTAssertEqual(assignment.contentIds, ["c1", "c2", "c3"])
        XCTAssertEqual(assignment.estimatedMinutes, 90)
        XCTAssertFalse(assignment.isRestDay)
    }

    func testDailyAssignment_restDay() throws {
        let json = JSONFactory.dailyAssignmentJSON(
            day: 7,
            topics: [],
            contentIds: [],
            estimatedMinutes: 0,
            isRestDay: true
        )
        let data = JSONFactory.data(from: json)

        let assignment = try decoder.decode(DailyAssignment.self, from: data)

        XCTAssertEqual(assignment.day, 7)
        XCTAssertTrue(assignment.topics.isEmpty)
        XCTAssertTrue(assignment.contentIds.isEmpty)
        XCTAssertEqual(assignment.estimatedMinutes, 0)
        XCTAssertTrue(assignment.isRestDay)
    }

    // MARK: - Milestone Decoding

    func testMilestone_decodesFromFullJSON() throws {
        let json = JSONFactory.milestoneJSON(
            id: "milestone-abc",
            type: "quiz_completion",
            title: "Pass First Quiz",
            description: "Score at least 70% on the first quiz",
            targetValue: 70,
            currentValue: 85,
            status: "completed",
            completedAt: "2025-01-20T10:00:00.000Z"
        )
        let data = JSONFactory.data(from: json)

        let milestone = try decoder.decode(Milestone.self, from: data)

        XCTAssertEqual(milestone.id, "milestone-abc")
        XCTAssertEqual(milestone.type, "quiz_completion")
        XCTAssertEqual(milestone.title, "Pass First Quiz")
        XCTAssertEqual(milestone.description, "Score at least 70% on the first quiz")
        XCTAssertEqual(milestone.targetValue, 70)
        XCTAssertEqual(milestone.currentValue, 85)
        XCTAssertEqual(milestone.status, "completed")
        XCTAssertEqual(milestone.completedAt, "2025-01-20T10:00:00.000Z")
    }

    func testMilestone_idMapsFromUnderscore() throws {
        let json = JSONFactory.milestoneJSON(id: "underscore_milestone_id")
        let data = JSONFactory.data(from: json)
        let milestone = try decoder.decode(Milestone.self, from: data)
        XCTAssertEqual(milestone.id, "underscore_milestone_id")
    }

    func testMilestone_missingOptionalFields() throws {
        let json = JSONFactory.milestoneJSON(description: nil, completedAt: nil)
        let data = JSONFactory.data(from: json)
        let milestone = try decoder.decode(Milestone.self, from: data)

        XCTAssertNil(milestone.description)
        XCTAssertNil(milestone.completedAt)
    }

    // MARK: - JourneyProgress Decoding

    func testJourneyProgress_decodesFromJSON() throws {
        let json = JSONFactory.journeyProgressJSON(
            overallPercentage: 72.5,
            contentConsumed: 15,
            contentAssigned: 20,
            quizzesCompleted: 4,
            quizzesAssigned: 6,
            currentStreak: 7,
            milestonesCompleted: 3,
            milestonesTotal: 5
        )
        let data = JSONFactory.data(from: json)

        let progress = try decoder.decode(JourneyProgress.self, from: data)

        XCTAssertEqual(progress.overallPercentage, 72.5, accuracy: 0.001)
        XCTAssertEqual(progress.contentConsumed, 15)
        XCTAssertEqual(progress.contentAssigned, 20)
        XCTAssertEqual(progress.quizzesCompleted, 4)
        XCTAssertEqual(progress.quizzesAssigned, 6)
        XCTAssertEqual(progress.currentStreak, 7)
        XCTAssertEqual(progress.milestonesCompleted, 3)
        XCTAssertEqual(progress.milestonesTotal, 5)
    }

    func testJourneyProgress_zeroValues() throws {
        let json = JSONFactory.journeyProgressJSON(
            overallPercentage: 0.0,
            contentConsumed: 0,
            contentAssigned: 0,
            quizzesCompleted: 0,
            quizzesAssigned: 0,
            currentStreak: 0,
            milestonesCompleted: 0,
            milestonesTotal: 0
        )
        let data = JSONFactory.data(from: json)

        let progress = try decoder.decode(JourneyProgress.self, from: data)

        XCTAssertEqual(progress.overallPercentage, 0.0, accuracy: 0.001)
        XCTAssertEqual(progress.contentConsumed, 0)
        XCTAssertEqual(progress.currentStreak, 0)
    }

    // MARK: - TodayPlan Decoding

    func testTodayPlan_decodesFromJSON() throws {
        let json = JSONFactory.todayPlanJSON(
            weekNumber: 2,
            day: 4,
            weekGoals: ["Complete advanced topics", "Take quiz 3"]
        )
        let data = JSONFactory.data(from: json)

        let todayPlan = try decoder.decode(TodayPlan.self, from: data)

        XCTAssertEqual(todayPlan.weekNumber, 2)
        XCTAssertEqual(todayPlan.day, 4)
        XCTAssertNotNil(todayPlan.plan)
        XCTAssertEqual(todayPlan.weekGoals, ["Complete advanced topics", "Take quiz 3"])
    }

    func testTodayPlan_missingOptionalWeekGoals() throws {
        let json = JSONFactory.todayPlanJSON(weekGoals: nil)
        let data = JSONFactory.data(from: json)

        let todayPlan = try decoder.decode(TodayPlan.self, from: data)

        XCTAssertNil(todayPlan.weekGoals)
    }

    func testTodayPlan_planContainsDailyAssignment() throws {
        let assignment = JSONFactory.dailyAssignmentJSON(
            day: 3,
            topics: ["Protocols"],
            contentIds: ["c-proto-1"],
            estimatedMinutes: 60,
            isRestDay: false
        )
        let json = JSONFactory.todayPlanJSON(day: 3, plan: assignment)
        let data = JSONFactory.data(from: json)

        let todayPlan = try decoder.decode(TodayPlan.self, from: data)

        XCTAssertEqual(todayPlan.plan.day, 3)
        XCTAssertEqual(todayPlan.plan.topics, ["Protocols"])
        XCTAssertEqual(todayPlan.plan.estimatedMinutes, 60)
    }

    // MARK: - Enum Decoding: JourneyPhase

    func testJourneyPhase_allCases() throws {
        let cases: [(String, JourneyPhase)] = [
            ("foundation", .foundation),
            ("building", .building),
            ("strengthening", .strengthening),
            ("mastery", .mastery),
            ("revision", .revision),
            ("exam_prep", .examPrep)
        ]

        for (raw, expected) in cases {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(JourneyPhase.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for raw value: \(raw)")
        }
    }

    func testJourneyPhase_invalidValue_throws() {
        let data = "\"unknown_phase\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(JourneyPhase.self, from: data))
    }

    // MARK: - Enum Decoding: JourneyStatus

    func testJourneyStatus_allCases() throws {
        let cases: [(String, JourneyStatus)] = [
            ("generating", .generating),
            ("active", .active),
            ("paused", .paused),
            ("completed", .completed),
            ("abandoned", .abandoned)
        ]

        for (raw, expected) in cases {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(JourneyStatus.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for raw value: \(raw)")
        }
    }

    func testJourneyStatus_invalidValue_throws() {
        let data = "\"deleted\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(JourneyStatus.self, from: data))
    }

    // MARK: - Journey with Full Progress

    func testJourney_progressIsDecoded() throws {
        let progress = JSONFactory.journeyProgressJSON(
            overallPercentage: 60.0,
            contentConsumed: 12,
            contentAssigned: 20,
            quizzesCompleted: 3,
            quizzesAssigned: 5,
            currentStreak: 5,
            milestonesCompleted: 2,
            milestonesTotal: 4
        )
        let json = JSONFactory.journeyJSON(progress: progress)
        let data = JSONFactory.data(from: json)

        let journey = try decoder.decode(Journey.self, from: data)

        XCTAssertEqual(journey.progress.overallPercentage, 60.0, accuracy: 0.001)
        XCTAssertEqual(journey.progress.contentConsumed, 12)
        XCTAssertEqual(journey.progress.currentStreak, 5)
    }

    // MARK: - Identifiable Conformance

    func testJourney_conformsToIdentifiable() throws {
        let json = JSONFactory.journeyJSON(id: "j-identifiable")
        let data = JSONFactory.data(from: json)
        let journey = try decoder.decode(Journey.self, from: data)
        XCTAssertEqual(journey.id, "j-identifiable")
    }

    func testMilestone_conformsToIdentifiable() throws {
        let json = JSONFactory.milestoneJSON(id: "m-identifiable")
        let data = JSONFactory.data(from: json)
        let milestone = try decoder.decode(Milestone.self, from: data)
        XCTAssertEqual(milestone.id, "m-identifiable")
    }

    // MARK: - Journey with examPrep Phase

    func testJourney_examPrepPhase() throws {
        let json = JSONFactory.journeyJSON(currentPhase: "exam_prep")
        let data = JSONFactory.data(from: json)

        let journey = try decoder.decode(Journey.self, from: data)

        XCTAssertEqual(journey.currentPhase, .examPrep)
    }
}
