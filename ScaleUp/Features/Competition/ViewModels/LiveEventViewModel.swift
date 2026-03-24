import SwiftUI

@Observable
@MainActor
final class LiveEventViewModel {

    // MARK: - State

    let event: LiveEvent
    var lobbyState: LobbyState? = nil
    var currentQuestion: LiveQuestionResponse? = nil
    var isInLobby = false
    var isLive = false
    var isComplete = false
    var participantCount = 0
    var selectedAnswer: String? = nil
    var questionResults: LiveQuestionResults? = nil
    var eventResults: LiveEventResults? = nil
    var error: String? = nil

    private let service = CompetitionService()
    private var pollingTask: Task<Void, Never>? = nil

    // MARK: - Init

    init(event: LiveEvent) {
        self.event = event
    }

    // MARK: - Join Lobby

    func joinLobby() async {
        error = nil

        do {
            let response = try await service.joinLobby(eventId: event.id)
            participantCount = response.participantCount
            isInLobby = true
            startLobbyPolling()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Lobby Polling

    private func startLobbyPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await pollLobbyState()
                guard !Task.isCancelled, !isLive else { return }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func pollLobbyState() async {
        do {
            let state = try await service.fetchLobbyState(eventId: event.id)
            lobbyState = state
            participantCount = state.participantCount

            if state.status == "live" {
                isInLobby = false
                isLive = true
                startQuestionPolling()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Question Polling

    private func startQuestionPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await pollCurrentQuestion()
                guard !Task.isCancelled, !isComplete else { return }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func pollCurrentQuestion() async {
        do {
            let question = try await service.fetchCurrentQuestion(eventId: event.id)
            currentQuestion = question

            if question.eventComplete {
                isLive = false
                isComplete = true
                pollingTask?.cancel()
                await fetchResults()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Submit Answer

    func submitAnswer() async {
        guard let answer = selectedAnswer,
              let questionIndex = currentQuestion?.questionIndex else { return }

        do {
            _ = try await service.submitLiveAnswer(
                eventId: event.id,
                questionIndex: questionIndex,
                selectedAnswer: answer,
                timeSpent: 0
            )
            selectedAnswer = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Results

    func fetchResults() async {
        do {
            eventResults = try await service.fetchEventResults(eventId: event.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
