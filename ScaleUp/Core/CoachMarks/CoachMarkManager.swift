import SwiftUI

// MARK: - Coach Mark Identifiers

enum CoachMarkID: String, CaseIterable {
    // Phase 1: Welcome carousel
    case welcomeCarousel = "coachMark_welcomeCarousel"

    // Phase 2: Tab-level marks
    case tabHome = "coachMark_tabHome"
    case tabDiscover = "coachMark_tabDiscover"
    case tabJourney = "coachMark_tabJourney"
    case tabProgress = "coachMark_tabProgress"
    case tabProfile = "coachMark_tabProfile"

    // Phase 3: Feature-specific
    case quizCard = "coachMark_quizCard"
    case readinessScore = "coachMark_readinessScore"
}

// MARK: - Coach Mark Manager

@Observable
@MainActor
final class CoachMarkManager {

    var activeCoachMark: CoachMarkID?

    var showWelcomeCarousel: Bool {
        !hasCompleted(.welcomeCarousel)
    }

    // MARK: - Init (handles existing user migration)

    init() {
        // Migration: if user already completed onboarding before this feature existed,
        // they'll have data. We mark the welcome carousel as seen so they don't get it.
        // This is triggered from MainTabView when we detect an existing user.
    }

    // MARK: - Query

    func hasCompleted(_ mark: CoachMarkID) -> Bool {
        UserDefaults.standard.bool(forKey: mark.rawValue)
    }

    func shouldShow(_ mark: CoachMarkID) -> Bool {
        !hasCompleted(mark) && activeCoachMark == nil
    }

    // MARK: - Actions

    func show(_ mark: CoachMarkID) {
        guard !hasCompleted(mark) else { return }
        withAnimation(Motion.springSmooth) {
            activeCoachMark = mark
        }
    }

    func complete(_ mark: CoachMarkID) {
        UserDefaults.standard.set(true, forKey: mark.rawValue)
        if activeCoachMark == mark {
            withAnimation(Motion.easeOut) {
                activeCoachMark = nil
            }
        }
    }

    func skipAllCoachMarks() {
        for mark in CoachMarkID.allCases {
            UserDefaults.standard.set(true, forKey: mark.rawValue)
        }
        withAnimation(Motion.easeOut) {
            activeCoachMark = nil
        }
    }

    /// Mark existing user — skip welcome carousel but still show tab tips
    func markExistingUser() {
        if !UserDefaults.standard.bool(forKey: "coachMark_existingUserMigrated") {
            UserDefaults.standard.set(true, forKey: CoachMarkID.welcomeCarousel.rawValue)
            UserDefaults.standard.set(true, forKey: "coachMark_existingUserMigrated")
        }
    }

    // MARK: - Debug

    func resetAll() {
        for mark in CoachMarkID.allCases {
            UserDefaults.standard.removeObject(forKey: mark.rawValue)
        }
        UserDefaults.standard.removeObject(forKey: "coachMark_existingUserMigrated")
        activeCoachMark = nil
    }
}
