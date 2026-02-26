import SwiftUI

// MARK: - Preview Data

/// Centralized mock data for SwiftUI previews.
/// Provides realistic sample instances of every major model type.
enum PreviewData {

    // MARK: - User

    static let user = User(
        id: "preview-user-001",
        email: "alex@scaleup.dev",
        phone: "+1234567890",
        isPhoneVerified: true,
        isEmailVerified: true,
        firstName: "Alex",
        lastName: "Morgan",
        username: "alexmorgan",
        profilePicture: nil,
        bio: "Lifelong learner passionate about software engineering and machine learning.",
        dateOfBirth: "1995-06-15",
        location: "San Francisco, CA",
        education: [
            Education(
                degree: "B.S. Computer Science",
                institution: "Stanford University",
                yearOfCompletion: 2017,
                currentlyPursuing: false
            )
        ],
        workExperience: [
            WorkExperience(
                role: "Senior Software Engineer",
                company: "TechCorp",
                years: 5,
                currentlyWorking: true
            )
        ],
        skills: ["Swift", "Python", "Machine Learning", "iOS Development"],
        role: .consumer,
        authProvider: "email",
        onboardingComplete: true,
        onboardingStep: 5,
        followersCount: 128,
        followingCount: 64,
        isActive: true,
        isBanned: false,
        lastLoginAt: "2026-02-24T10:00:00Z",
        createdAt: "2025-01-15T08:30:00Z"
    )

    // MARK: - Content

    static let content = Content(
        id: "preview-content-001",
        creatorId: .object(ContentCreator(
            id: "preview-creator-001",
            firstName: "Sarah",
            lastName: "Chen",
            username: "sarahchen",
            profilePicture: nil
        )),
        title: "Introduction to SwiftUI: Building Modern iOS Apps",
        description: "A comprehensive guide to building beautiful, responsive iOS applications using SwiftUI and the latest Apple frameworks.",
        contentType: .video,
        contentURL: "https://example.com/videos/swiftui-intro",
        thumbnailURL: "https://example.com/thumbnails/swiftui-intro.jpg",
        duration: 1800,
        sourceType: .original,
        sourceAttribution: nil,
        backendYoutubeVideoId: nil,
        domain: "iOS Development",
        topics: ["SwiftUI", "iOS", "Apple Frameworks"],
        tags: ["swift", "ios", "beginner", "tutorial"],
        difficulty: .beginner,
        aiData: AIData(
            summary: "This video covers the fundamentals of SwiftUI, including declarative syntax, state management, and building responsive layouts.",
            keyConcepts: [
                KeyConcept(
                    concept: "Declarative UI",
                    description: "Building interfaces by describing what they should look like",
                    timestamp: "2:00",
                    importance: 5
                )
            ],
            prerequisites: ["Basic Swift knowledge"],
            qualityScore: 0.92,
            autoTags: ["swiftui", "ios-development"]
        ),
        status: .published,
        publishedAt: "2026-02-20T14:00:00Z",
        viewCount: 15420,
        likeCount: 892,
        commentCount: 67,
        saveCount: 345,
        averageRating: 4.7,
        ratingCount: 203,
        recommendationScore: 0.95,
        createdAt: "2026-02-18T09:00:00Z",
        updatedAt: "2026-02-20T14:00:00Z"
    )

    // MARK: - Quiz

    static let quiz = Quiz(
        id: "preview-quiz-001",
        userId: "preview-user-001",
        title: "SwiftUI Fundamentals — Knowledge Check",
        type: .topicConsolidation,
        topic: "SwiftUI Fundamentals",
        sourceContentIds: ["preview-content-001"],
        objectiveId: nil,
        questions: [
            QuizQuestion(
                id: "q1",
                questionText: "What is the primary advantage of SwiftUI's declarative syntax?",
                questionType: "conceptual",
                options: [
                    QuizOption(id: "o1a", label: "A", text: "Faster compilation"),
                    QuizOption(id: "o1b", label: "B", text: "Describes UI state rather than step-by-step instructions"),
                    QuizOption(id: "o1c", label: "C", text: "Better memory management"),
                    QuizOption(id: "o1d", label: "D", text: "Automatic dark mode support"),
                ],
                correctAnswer: "B",
                explanation: "Declarative syntax lets you describe what the UI should look like for a given state.",
                difficulty: "easy",
                sourceContentId: "preview-content-001",
                sourceTimestamp: "02:00",
                concept: "Declarative Syntax"
            ),
            QuizQuestion(
                id: "q2",
                questionText: "Which property wrapper is used for local view state in SwiftUI?",
                questionType: "recall",
                options: [
                    QuizOption(id: "o2a", label: "A", text: "@Binding"),
                    QuizOption(id: "o2b", label: "B", text: "@State"),
                    QuizOption(id: "o2c", label: "C", text: "@Environment"),
                    QuizOption(id: "o2d", label: "D", text: "@Observable"),
                ],
                correctAnswer: "B",
                explanation: "@State is used for simple value types owned by the view.",
                difficulty: "easy",
                sourceContentId: nil,
                sourceTimestamp: nil,
                concept: nil
            ),
        ],
        totalQuestions: 2,
        timePerQuestion: 60,
        status: .ready,
        expiresAt: "2026-03-01T00:00:00Z",
        aiModel: "gpt-4o",
        generatedAt: "2026-02-24T08:00:00Z",
        createdAt: "2026-02-24T08:00:00Z",
        updatedAt: "2026-02-24T08:00:00Z"
    )

    // MARK: - Journey

    static let journey = Journey(
        id: "preview-journey-001",
        userId: "preview-user-001",
        objectiveId: "preview-objective-001",
        title: "iOS Development Mastery",
        phases: [
            JourneyPhaseDetail(
                id: "phase-001",
                name: "Foundation",
                type: "foundation",
                order: 1,
                durationDays: 28,
                startDate: nil,
                endDate: nil,
                status: "completed",
                objectives: ["Build a solid foundation in Swift and basic iOS concepts."],
                focusTopics: ["Swift Basics", "UIKit Fundamentals", "Auto Layout"]
            ),
            JourneyPhaseDetail(
                id: "phase-002",
                name: "Building",
                type: "building",
                order: 2,
                durationDays: 28,
                startDate: nil,
                endDate: nil,
                status: "active",
                objectives: ["Apply your knowledge by building real-world features."],
                focusTopics: ["SwiftUI", "Combine", "Networking"]
            ),
            JourneyPhaseDetail(
                id: "phase-003",
                name: "Mastery",
                type: "mastery",
                order: 3,
                durationDays: 28,
                startDate: nil,
                endDate: nil,
                status: "pending",
                objectives: ["Deepen understanding with advanced patterns and performance."],
                focusTopics: ["Architecture Patterns", "Testing", "Performance"]
            )
        ],
        weeklyPlans: [
            WeeklyPlan(
                id: "week-001",
                weekNumber: 1,
                phaseIndex: 0,
                status: "completed",
                dailyAssignments: [
                    DailyAssignment(
                        day: 1,
                        topics: ["Variables & Constants"],
                        contentIds: ["preview-content-001"],
                        estimatedTime: 45,
                        completed: false
                    ),
                    DailyAssignment(
                        day: 7,
                        topics: [],
                        contentIds: [],
                        estimatedTime: 0,
                        completed: false
                    )
                ],
                goals: ["Swift Language Essentials"],
                outcomes: nil
            )
        ],
        milestones: [milestone],
        progress: JourneyProgress(
            overallPercentage: 42.5,
            contentConsumed: 17,
            contentAssigned: 40,
            quizzesCompleted: 4,
            quizzesAssigned: 10,
            currentStreak: 7,
            milestonesCompleted: 2,
            milestonesTotal: 6
        ),
        currentPhaseIndex: 1,
        currentWeek: 6,
        status: .active,
        createdAt: "2026-01-10T08:00:00Z"
    )

    // MARK: - Milestone

    static let milestone = Milestone(
        id: "preview-milestone-001",
        type: "quiz_score",
        title: "Foundation Checkpoint",
        targetCriteria: MilestoneTargetCriteria(
            targetScore: 80,
            targetTopic: "Score 80% or higher on the Swift Basics assessment",
            streakDays: nil
        ),
        scheduledDate: nil,
        status: "completed",
        completedAt: "2026-02-10T16:30:00Z"
    )

    // MARK: - Knowledge Profile

    static let knowledgeProfile = KnowledgeProfile(
        overallScore: 72.5,
        totalTopicsCovered: 12,
        totalQuizzesTaken: 8,
        strengths: ["Swift Syntax", "SwiftUI Layouts", "State Management"],
        weaknesses: ["Concurrency", "Core Data"],
        topicMastery: [
            TopicMastery(
                topic: "Swift Fundamentals",
                score: 88.0,
                level: .advanced,
                trend: .improving,
                quizzesTaken: 3,
                lastAssessedAt: "2026-02-22T10:00:00Z"
            ),
            TopicMastery(
                topic: "SwiftUI",
                score: 75.0,
                level: .intermediate,
                trend: .improving,
                quizzesTaken: 2,
                lastAssessedAt: "2026-02-20T14:00:00Z"
            ),
            TopicMastery(
                topic: "Concurrency",
                score: 45.0,
                level: .beginner,
                trend: .stable,
                quizzesTaken: 1,
                lastAssessedAt: "2026-02-15T09:00:00Z"
            )
        ]
    )

    // MARK: - Playlist

    static let playlist = Playlist(
        id: "preview-playlist-001",
        userId: "preview-user-001",
        title: "SwiftUI Deep Dive",
        description: "My curated collection of the best SwiftUI resources.",
        isPublic: true,
        items: [
            PlaylistItem(
                contentId: .id("preview-content-001"),
                order: 0,
                addedAt: "2026-02-01T12:00:00Z"
            )
        ],
        itemCount: 1,
        createdAt: "2026-02-01T12:00:00Z"
    )

    // MARK: - Creator Profile

    static let creatorProfile = CreatorProfile(
        id: "preview-creator-profile-001",
        userId: "preview-creator-001",
        domain: "iOS Development",
        specializations: ["SwiftUI", "UIKit", "Combine"],
        bio: "Senior iOS Engineer with 8 years of experience. Passionate about teaching modern Apple development.",
        tier: .core,
        stats: CreatorStats(
            totalContent: 47,
            totalViews: 125000,
            totalFollowers: 3200,
            averageRating: 4.8
        ),
        socialLinks: CreatorSocialLinks(
            linkedin: "https://linkedin.com/in/sarahchen",
            twitter: "https://twitter.com/sarahchen_dev",
            youtube: "https://youtube.com/@sarahchen",
            website: "https://sarahchen.dev"
        ),
        createdAt: "2025-06-01T08:00:00Z"
    )

    // MARK: - Comment

    static let comment = Comment(
        id: "preview-comment-001",
        userId: CommentUser(
            id: "preview-user-002",
            firstName: "Jordan",
            lastName: "Lee",
            profilePicture: nil
        ),
        contentId: "preview-content-001",
        text: "Great explanation of declarative UI! The comparison with imperative approaches really helped me understand the difference.",
        parentId: nil,
        createdAt: "2026-02-23T18:45:00Z"
    )

    // MARK: - Objective

    static let objective = Objective(
        id: "preview-objective-001",
        userId: "preview-user-001",
        objectiveType: .upskilling,
        specifics: ObjectiveSpecifics(
            examName: nil,
            targetSkill: "iOS Development",
            targetRole: "Senior iOS Engineer",
            targetCompany: nil,
            fromDomain: nil,
            toDomain: nil
        ),
        timeline: .sixMonths,
        currentLevel: .intermediate,
        weeklyCommitHours: 10,
        status: .active,
        isPrimary: true,
        weight: 100,
        targetDate: nil,
        createdAt: "2026-01-10T08:00:00Z",
        updatedAt: "2026-02-24T10:00:00Z"
    )

    // MARK: - Dashboard Response

    static let dashboardResponse = DashboardResponse(
        objectives: [objective],
        readinessScore: 72,
        knowledgeProfile: knowledgeProfile,
        journey: JourneySummary(
            title: "iOS Development Mastery",
            currentPhase: "building",
            currentWeek: 6,
            progress: JourneyProgress(
                overallPercentage: 42.5,
                contentConsumed: 17,
                contentAssigned: 40,
                quizzesCompleted: 4,
                quizzesAssigned: 10,
                currentStreak: 7,
                milestonesCompleted: 2,
                milestonesTotal: 6
            ),
            streak: 7
        ),
        weeklyStats: WeeklyStats(
            contentConsumed: 5,
            totalContentConsumed: 17,
            dominantTopics: ["SwiftUI", "Swift"]
        ),
        nextActions: [
            NextAction(
                type: "content",
                message: "Continue your SwiftUI lesson on state management",
                data: nil
            ),
            NextAction(
                type: "quiz",
                message: "Take the SwiftUI Fundamentals quiz",
                data: nil
            )
        ],
        upcomingMilestones: [
            Milestone(
                id: "preview-milestone-002",
                type: "content_count",
                title: "Content Explorer",
                targetCriteria: MilestoneTargetCriteria(
                    targetScore: 20,
                    targetTopic: "Complete 20 pieces of content",
                    streakDays: nil
                ),
                scheduledDate: nil,
                status: "in_progress",
                completedAt: nil
            )
        ],
        pendingQuizzes: 2
    )
}

// MARK: - Preview DependencyContainer

extension DependencyContainer {

    /// A preview-compatible `DependencyContainer` for SwiftUI previews.
    ///
    /// Creates a fresh container. Services are lazy, so no real network
    /// calls are made unless explicitly triggered.
    static var preview: DependencyContainer {
        DependencyContainer()
    }
}

// MARK: - Preview AppState

extension AppState {

    /// An authenticated `AppState` pre-populated with a sample user.
    static var preview: AppState {
        let state = AppState()
        state.authStatus = .authenticated
        state.currentUser = PreviewData.user
        return state
    }

    /// An unauthenticated `AppState` for previewing auth flows.
    static var previewUnauthenticated: AppState {
        let state = AppState()
        state.authStatus = .unauthenticated
        state.currentUser = nil
        return state
    }

    /// An onboarding `AppState` for previewing onboarding screens.
    static var previewOnboarding: AppState {
        let state = AppState()
        state.authStatus = .onboarding
        state.currentUser = PreviewData.user
        return state
    }
}
