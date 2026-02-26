import SwiftUI

@Observable
@MainActor
final class DependencyContainer {

    // MARK: - Core Infrastructure

    let keychainManager: KeychainManager
    let tokenManager: TokenManager
    let apiClient: APIClient

    // MARK: - Auth

    let authManager: AuthManager

    // MARK: - Services

    let authService: AuthService
    let onboardingService: OnboardingService
    let dashboardService: DashboardService
    let contentService: ContentService
    let quizService: QuizService
    let journeyService: JourneyService
    let knowledgeService: KnowledgeService
    let socialService: SocialService
    let progressService: ProgressService
    let recommendationService: RecommendationService
    let userService: UserService
    let objectiveService: ObjectiveService
    let creatorService: CreatorService
    let searchService: SearchService
    let adminService: AdminService

    // MARK: - Repositories

    let contentRepository: ContentRepository

    // MARK: - Utilities

    let hapticManager: HapticManager

    // MARK: - Init

    init() {
        let keychain = KeychainManager()
        let token = TokenManager(keychainManager: keychain)
        let client = APIClient(tokenProvider: token)
        token.setAPIClient(client)

        self.keychainManager = keychain
        self.tokenManager = token
        self.apiClient = client

        self.authManager = AuthManager(apiClient: client, tokenManager: token)

        self.authService = AuthService(apiClient: client)
        self.onboardingService = OnboardingService(apiClient: client)
        self.dashboardService = DashboardService(apiClient: client)
        self.contentService = ContentService(apiClient: client)
        self.quizService = QuizService(apiClient: client)
        self.journeyService = JourneyService(apiClient: client)
        self.knowledgeService = KnowledgeService(apiClient: client)
        self.socialService = SocialService(apiClient: client)
        self.progressService = ProgressService(apiClient: client)
        self.recommendationService = RecommendationService(apiClient: client)
        self.userService = UserService(apiClient: client)
        self.objectiveService = ObjectiveService(apiClient: client)
        self.creatorService = CreatorService(apiClient: client)
        self.searchService = SearchService(apiClient: client)
        self.adminService = AdminService(apiClient: client)

        self.contentRepository = ContentRepository(contentService: ContentService(apiClient: client))

        self.hapticManager = HapticManager()
    }
}
