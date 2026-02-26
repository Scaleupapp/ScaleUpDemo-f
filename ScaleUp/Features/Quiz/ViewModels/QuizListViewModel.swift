import SwiftUI

// MARK: - Quiz Tab

enum QuizTab: String, CaseIterable {
    case active = "Active"
    case available = "Available"
    case completed = "Completed"
}

// MARK: - Quiz List View Model

@Observable
@MainActor
final class QuizListViewModel {

    // MARK: - State

    var availableQuizzes: [Quiz] = []
    var inProgressQuizzes: [Quiz] = []
    var completedQuizzes: [Quiz] = []
    var isLoading: Bool = false
    var error: APIError?
    var selectedTab: QuizTab = .active

    // MARK: - Dependencies

    private let quizService: QuizService

    // MARK: - Init

    init(quizService: QuizService) {
        self.quizService = quizService
    }

    // MARK: - Load Quizzes

    /// Fetches all quizzes and sorts them into available and in-progress buckets.
    func loadQuizzes() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let allQuizzes = try await quizService.list()
            categorize(allQuizzes)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes all quizzes without showing full loading state.
    func refresh() async {
        error = nil

        do {
            let allQuizzes = try await quizService.list()
            categorize(allQuizzes)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    var isEmpty: Bool {
        availableQuizzes.isEmpty && inProgressQuizzes.isEmpty && completedQuizzes.isEmpty
    }

    /// Quizzes for the currently selected tab.
    var currentTabQuizzes: [Quiz] {
        switch selectedTab {
        case .active: return inProgressQuizzes
        case .available: return availableQuizzes
        case .completed: return completedQuizzes
        }
    }

    /// The best default tab to select (first non-empty).
    var bestDefaultTab: QuizTab {
        if !inProgressQuizzes.isEmpty { return .active }
        if !availableQuizzes.isEmpty { return .available }
        if !completedQuizzes.isEmpty { return .completed }
        return .active
    }

    /// Count for a given tab.
    func count(for tab: QuizTab) -> Int {
        switch tab {
        case .active: return inProgressQuizzes.count
        case .available: return availableQuizzes.count
        case .completed: return completedQuizzes.count
        }
    }

    // MARK: - Private

    private func categorize(_ quizzes: [Quiz]) {
        availableQuizzes = quizzes.filter { $0.status == .ready || $0.status == .delivered }
        inProgressQuizzes = quizzes.filter { $0.status == .inProgress }
        completedQuizzes = quizzes.filter { $0.status == .completed }
    }
}
