import Foundation

// MARK: - Accessibility Identifiers

/// Centralized accessibility identifiers for UI testing.
///
/// Use these constants in production views via `.accessibilityIdentifier(AccessibilityID.Auth.welcomeScreen)`
/// and in UI tests to locate elements by identifier. Keeping identifiers in one place prevents
/// mismatches between the app target and the test target.
enum AccessibilityID {

    // MARK: - Auth Flow

    enum Auth {
        static let welcomeScreen = "auth.welcome"
        static let loginButton = "auth.login"
        static let registerButton = "auth.register"
        static let emailField = "auth.email"
        static let passwordField = "auth.password"
        static let confirmPasswordField = "auth.confirmPassword"
        static let firstNameField = "auth.firstName"
        static let lastNameField = "auth.lastName"
        static let submitButton = "auth.submit"
        static let googleSignInButton = "auth.googleSignIn"
        static let phoneOTPButton = "auth.phoneOTP"
        static let forgotPasswordButton = "auth.forgotPassword"
        static let errorBanner = "auth.errorBanner"
        static let loadingIndicator = "auth.loading"
    }

    // MARK: - Tab Bar

    enum TabBar {
        static let home = "tab.home"
        static let discover = "tab.discover"
        static let journey = "tab.journey"
        static let progress = "tab.progress"
        static let profile = "tab.profile"
    }

    // MARK: - Home

    enum Home {
        static let scrollView = "home.scrollView"
        static let readinessScore = "home.readinessScore"
        static let streakBadge = "home.streakBadge"
        static let nextActionCard = "home.nextAction"
        static let objectiveCard = "home.objectiveCard"
        static let weeklyStatsSection = "home.weeklyStats"
        static let upcomingMilestones = "home.upcomingMilestones"
        static let continueContent = "home.continueContent"
    }

    // MARK: - Discover

    enum Discover {
        static let scrollView = "discover.scrollView"
        static let searchField = "discover.searchField"
        static let categoryFilter = "discover.categoryFilter"
        static let contentCard = "discover.contentCard"
        static let recommendedSection = "discover.recommended"
        static let trendingSection = "discover.trending"
        static let filterButton = "discover.filterButton"
    }

    // MARK: - Journey

    enum Journey {
        static let scrollView = "journey.scrollView"
        static let phaseIndicator = "journey.phaseIndicator"
        static let weeklyPlan = "journey.weeklyPlan"
        static let milestoneCard = "journey.milestoneCard"
        static let progressRing = "journey.progressRing"
        static let dailyAssignment = "journey.dailyAssignment"
        static let streakCounter = "journey.streakCounter"
    }

    // MARK: - Progress / Knowledge Profile

    enum Progress {
        static let scrollView = "progress.scrollView"
        static let overallScore = "progress.overallScore"
        static let topicMasteryList = "progress.topicMastery"
        static let topicMasteryItem = "progress.topicMasteryItem"
        static let strengthsList = "progress.strengths"
        static let weaknessesList = "progress.weaknesses"
        static let quizHistory = "progress.quizHistory"
    }

    // MARK: - Profile

    enum Profile {
        static let scrollView = "profile.scrollView"
        static let avatar = "profile.avatar"
        static let displayName = "profile.displayName"
        static let bio = "profile.bio"
        static let editButton = "profile.editButton"
        static let followersCount = "profile.followers"
        static let followingCount = "profile.following"
        static let settingsButton = "profile.settings"
        static let logoutButton = "profile.logout"
    }

    // MARK: - Content Detail

    enum ContentDetail {
        static let scrollView = "contentDetail.scrollView"
        static let title = "contentDetail.title"
        static let videoPlayer = "contentDetail.videoPlayer"
        static let likeButton = "contentDetail.likeButton"
        static let saveButton = "contentDetail.saveButton"
        static let shareButton = "contentDetail.shareButton"
        static let commentsList = "contentDetail.comments"
        static let ratingView = "contentDetail.rating"
        static let creatorInfo = "contentDetail.creatorInfo"
    }

    // MARK: - Quiz

    enum Quiz {
        static let container = "quiz.container"
        static let questionText = "quiz.questionText"
        static let optionButton = "quiz.optionButton"
        static let nextButton = "quiz.nextButton"
        static let submitButton = "quiz.submitButton"
        static let timerLabel = "quiz.timer"
        static let progressIndicator = "quiz.progress"
        static let resultScore = "quiz.resultScore"
        static let explanationText = "quiz.explanation"
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let container = "onboarding.container"
        static let progressBar = "onboarding.progressBar"
        static let nextButton = "onboarding.nextButton"
        static let skipButton = "onboarding.skipButton"
        static let objectiveSelection = "onboarding.objectiveSelection"
        static let domainSelection = "onboarding.domainSelection"
        static let timelineSelection = "onboarding.timelineSelection"
    }

    // MARK: - Common / Shared

    enum Common {
        static let loadingOverlay = "common.loadingOverlay"
        static let errorState = "common.errorState"
        static let emptyState = "common.emptyState"
        static let retryButton = "common.retryButton"
        static let backButton = "common.backButton"
        static let closeButton = "common.closeButton"
        static let pullToRefresh = "common.pullToRefresh"
    }
}
