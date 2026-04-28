# Day-1 Diagnostic — iOS Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Steps use checkbox syntax for tracking.

**Goal:** Add the Day-1 Diagnostic flow to the iOS app — new users land in the diagnostic immediately after onboarding; existing users can launch it from a banner.

**Architecture:** New feature module under `ScaleUp/Features/Diagnostic/`. `actor DiagnosticService` mirroring `QuizService`. `@Observable @MainActor final class DiagnosticViewModel` orchestrates screen state. Routing extended via new `AppLaunchState.diagnostic` case. Backend gate via `user.diagnosticComplete: Bool?` field.

**Tech Stack:** SwiftUI, async/await, `@Observable`, `APIClient.shared`.

---

## File structure

- `ScaleUp/Features/Diagnostic/Services/DiagnosticService.swift` — actor + endpoints
- `ScaleUp/Models/Diagnostic.swift` — all DTOs
- `ScaleUp/Features/Diagnostic/ViewModels/DiagnosticViewModel.swift` — orchestrator
- `ScaleUp/Features/Diagnostic/Views/DiagnosticContainerView.swift` — root, switches between screens
- `ScaleUp/Features/Diagnostic/Views/DiagnosticWelcomeView.swift` — Screen 1
- `ScaleUp/Features/Diagnostic/Views/DiagnosticSelfRatingView.swift` — Screen 2
- `ScaleUp/Features/Diagnostic/Views/DiagnosticQuestionView.swift` — Screen 3
- `ScaleUp/Features/Diagnostic/Views/DiagnosticResultsView.swift` — Screen 4
- Modify: `ScaleUp/App/AppState.swift` — add `.diagnostic` case + gate logic
- Modify: `ScaleUp/App/ScaleUpApp.swift` — route `.diagnostic` → `DiagnosticContainerView`
- Modify: `ScaleUp/Core/Analytics/AnalyticsEvent.swift` — add 4 new events
- Modify: `ScaleUp/Models/User.swift` — add `diagnosticComplete: Bool?`

---

## Phase A — Foundations (single bundled task)

### Task A: Models, Service, Analytics, Routing

**Goal:** Set up everything that doesn't render UI yet. Builds clean.

- Create `Models/Diagnostic.swift` with these Decodable / Encodable structs (matching backend response shapes from `docs/diagnostic-api.md`):

```swift
struct DiagnosticAttemptStart: Decodable {
    let attemptId: String
    let flowType: String          // "new_user" | "existing_user_tune"
    let competenciesToAssess: [DiagnosticCompetency]
}

struct DiagnosticCompetency: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let questionCap: Int
}

struct DiagnosticQuestion: Decodable, Identifiable {
    let id: String                 // questionId from backend
    let competency: String
    let difficulty: String         // "easy" | "medium" | "hard"
    let prompt: String
    let options: [DiagnosticOption]

    enum CodingKeys: String, CodingKey {
        case id = "_id", competency, difficulty, prompt, options
    }
}

struct DiagnosticOption: Decodable, Identifiable, Hashable {
    let id: String                 // "A" | "B" | "C" | "D"
    let text: String

    enum CodingKeys: String, CodingKey {
        case id = "key", text
    }
}

struct DiagnosticNextQuestion: Decodable {
    let question: DiagnosticQuestion?
    let done: Bool?
}

struct DiagnosticResults: Decodable {
    let attemptId: String
    let perCompetency: [DiagnosticCompetencyResult]

    enum CodingKeys: String, CodingKey {
        case attemptId, perCompetency = "results"
    }
}

struct DiagnosticCompetencyResult: Decodable, Identifiable {
    var id: String { competency }
    let competency: String
    let score: Int                 // 0-100
    let band: String               // "novice"|"familiar"|"proficient"|"expert"
    let calibrationDelta: Int?     // selfRating - assessed
}

enum DiagnosticSelfRating: String, CaseIterable, Codable, Identifiable {
    case novice, familiar, proficient, expert, unsure
    var id: String { rawValue }
    var displayLabel: String {
        switch self {
        case .novice: return "I haven't worked with this"
        case .familiar: return "I'm familiar"
        case .proficient: return "I'm proficient"
        case .expert: return "I know this well"
        case .unsure: return "Not sure"
        }
    }
}
```

- Create `Features/Diagnostic/Services/DiagnosticService.swift`:

```swift
import Foundation

actor DiagnosticService {
    private let api = APIClient.shared

    func start() async throws -> DiagnosticAttemptStart {
        try await api.request(DiagnosticEndpoints.start)
    }

    func submitSelfRating(attemptId: String, ratings: [String: String]) async throws {
        struct Body: Encodable { let ratings: [String: String] }
        let _: EmptyResponse = try await api.request(DiagnosticEndpoints.selfRating(id: attemptId), body: Body(ratings: ratings))
    }

    func nextQuestion(attemptId: String) async throws -> DiagnosticNextQuestion {
        try await api.request(DiagnosticEndpoints.nextQuestion(id: attemptId))
    }

    func submitAnswer(attemptId: String, questionId: String, selectedAnswer: String, timeTaken: Double) async throws {
        struct Body: Encodable {
            let questionId: String
            let selectedAnswer: String
            let timeTaken: Double
        }
        let _: EmptyResponse = try await api.request(
            DiagnosticEndpoints.answer(id: attemptId),
            body: Body(questionId: questionId, selectedAnswer: selectedAnswer, timeTaken: timeTaken)
        )
    }

    func finish(attemptId: String) async throws -> DiagnosticResults {
        try await api.request(DiagnosticEndpoints.finish(id: attemptId))
    }

    func abandon(attemptId: String) async throws {
        let _: EmptyResponse = try await api.request(DiagnosticEndpoints.abandon(id: attemptId), body: EmptyBody())
    }
}

private struct EmptyResponse: Decodable {}
private struct EmptyBody: Encodable {}

private enum DiagnosticEndpoints: Endpoint {
    case start
    case selfRating(id: String)
    case nextQuestion(id: String)
    case answer(id: String)
    case finish(id: String)
    case abandon(id: String)

    var path: String {
        switch self {
        case .start: return "/diagnostic/start"
        case .selfRating(let id): return "/diagnostic/\(id)/self-rating"
        case .nextQuestion(let id): return "/diagnostic/\(id)/next-question"
        case .answer(let id): return "/diagnostic/\(id)/answer"
        case .finish(let id): return "/diagnostic/\(id)/finish"
        case .abandon(let id): return "/diagnostic/\(id)/abandon"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .nextQuestion: return .get
        default: return .post
        }
    }
}
```

- Add to `AnalyticsEvent.swift` (existing patterns — match the existing case style and parameter shape):
  - `case diagnosticStarted(flowType: String)`
  - `case diagnosticSelfRatingSubmitted(attemptId: String)`
  - `case diagnosticFinished(attemptId: String, durationSeconds: Int, score: Int)`
  - `case diagnosticAbandoned(attemptId: String, atStep: String)`

- Modify `Models/User.swift`: add `let diagnosticComplete: Bool?` (optional, decodes safely on legacy responses).

- Modify `App/AppState.swift`:
  - Extend `AppLaunchState` with `case diagnostic`.
  - In `checkAuth()` and `handleAuthSuccess()`: after the `onboardingComplete` check, if onboarding is done but `diagnosticComplete != true`, set `launchState = .diagnostic` (instead of `.home`).
  - Add `func completeDiagnostic() { launchState = .home }`.
  - Add `func skipDiagnostic() { launchState = .home }` (same behavior — keeps the surface symmetric for telemetry-friendly call sites).
  - Modify `completeOnboarding()` so that if user is new (`currentUser?.diagnosticComplete != true`), set `.diagnostic` instead of `.home`.

- Modify `App/ScaleUpApp.swift`:
  - Add `case .diagnostic: DiagnosticContainerView()` to the launch-state switch.

- Create `Features/Diagnostic/Views/DiagnosticContainerView.swift` as a stub:
```swift
import SwiftUI
struct DiagnosticContainerView: View {
    var body: some View { Text("Diagnostic — placeholder") }
}
```
(Real implementation in Phase B.)

**Verification:** Project compiles via `xcodebuild -workspace ... -scheme ScaleUp -configuration Debug build` (or whatever the local build command is).

**Commit:** `feat(diagnostic-ios): models, service, analytics, routing scaffold`

---

## Phase B — UI screens

### Task B: ViewModel + 4 screens

**Goal:** Functional flow from welcome → self-rating → questions → results → home.

- `DiagnosticViewModel.swift` (`@Observable @MainActor final class`):
  - State: `phase: Phase` (`.welcome | .selfRating | .quiz | .results | .error`)
  - Holds: `attemptId: String?`, `competencies: [DiagnosticCompetency]`, `selfRatings: [String: DiagnosticSelfRating]`, `currentQuestion: DiagnosticQuestion?`, `currentSelection: String?`, `currentQuestionStartedAt: Date?`, `questionsAnswered: Int`, `totalQuestionsTarget: Int`, `results: DiagnosticResults?`, `errorMessage: String?`, `isLoading: Bool`
  - Methods: `start() async`, `submitSelfRatings() async`, `selectOption(_:)`, `submitCurrentAnswer() async`, `loadNextQuestion() async`, `finish() async`, `abandon() async`
  - Fire analytics at: start, selfRatingSubmitted, finished, abandoned
- `DiagnosticContainerView` switches on `viewModel.phase`.

- `DiagnosticWelcomeView`:
  - Headline: "Let's tune your plan to you"
  - Body: "A 5-minute check-in to gauge where you are. We use this to skip what you already know and double down on gaps."
  - Primary CTA: "Start" → `await viewModel.start()`
  - Secondary CTA: "Skip for now" → calls `appState.skipDiagnostic()` and fires `diagnosticAbandoned(atStep: "welcome")`

- `DiagnosticSelfRatingView`:
  - Header: "How would you rate yourself on each topic?"
  - For each competency, a row with the topic name + 5 selectable chips for `DiagnosticSelfRating.allCases`
  - "Continue" button enabled when all topics rated → `await viewModel.submitSelfRatings()`

- `DiagnosticQuestionView`:
  - Mirrors `QuizSessionView` styling (option button gold ring on select, bottom Submit bar)
  - Shows progress: "Question \(questionsAnswered + 1) of \(totalTarget)"
  - Question prompt + 4 options as tap rows
  - Submit button: `await viewModel.submitCurrentAnswer()` then `await viewModel.loadNextQuestion()`
  - When `done`, transitions phase to `.results` (via `await viewModel.finish()`)
  - Track time-on-question via `currentQuestionStartedAt`

- `DiagnosticResultsView`:
  - Headline: "Here's where you stand"
  - For each `DiagnosticCompetencyResult`: topic, band, score bar
  - Calibration callout if `|calibrationDelta|` >= 2: "You rated yourself X but assessed at Y — we'll keep an eye on this."
  - CTA: "Continue to my plan" → `appState.completeDiagnostic()`

- `ScaleUpApp.swift`: replace the placeholder with `DiagnosticContainerView()` injection of `appState` via environment.

**Verification:** Build succeeds. Manual smoke when app available.

**Commit:** `feat(diagnostic-ios): full UI flow with view-model orchestration`

---

## Phase C — Existing-user banner (optional v1.1)

Out of scope for the overnight session. Tracked here for future:
- Banner on Home tab when `user.diagnosticComplete == false` AND user has prior quiz activity.
- Tap → presents `DiagnosticContainerView` modally.

---

## Self-review

1. Spec coverage: A (models/service/routing), B (UI). Existing-user banner deferred.
2. No placeholders (Phase A's stub is named and replaced in Phase B).
3. Type consistency: backend response keys match Decodable mappings (`_id` → `id`, `key` → `id` for options).
4. Backward compat: `User.diagnosticComplete` is optional; legacy responses decode fine.
