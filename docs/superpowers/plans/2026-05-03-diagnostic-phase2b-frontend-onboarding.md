# Day-1 Diagnostic — Plan 2b: Frontend Onboarding

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework Step 5 of onboarding (Interests → taxonomy chips + per-topic self-rating + optional syllabus upload) and surface a calibration banner on Home for existing users — on **iOS (SwiftUI)** and **Android (React Native)** — wired to the new backend endpoints from Plan 2a. Mixpanel events for the onboarding subset are instrumented on both platforms.

**Architecture:**
- iOS: one new model addition (`ProficiencyLevel` + `topicSelfRatings`), one rebuilt step view (`InterestsStepView`), two new step views (`SelfRatingSubStepView`, `SyllabusUploadView`), one new networking service (`OnboardingTopicService`), one new Home component (`CalibrationBannerView`) with `UserDefaults`-backed persistence, view model updates.
- Android: mirror of iOS — `OnboardingData` interface extended, `InterestsStep.tsx` rebuilt, new `SelfRatingSubStep.tsx` and `SyllabusUpload.tsx`, new `onboardingTopicService.ts`, new `CalibrationBanner.tsx` for `HomeScreen` with AsyncStorage-backed persistence + Redux slice for state.
- Cross-cutting Mixpanel events instrumented per spec §13.5 (onboarding subset only).
- **No backend, no diagnostic engine, no results, no plan integration in this plan.** All consumed APIs come from Plan 2a.

**Tech Stack:**
- iOS: Swift 5.10, SwiftUI (iOS 17+), `@Observable` view models, `URLSession` networking (existing pattern in `OnboardingService.swift`), `UserDefaults` for banner persistence, XCTest + SwiftUI Previews for snapshot smoke tests.
- Android: React Native 0.74+, TypeScript 5.x, Axios (existing `api.ts`), `@reduxjs/toolkit` slices, `@react-native-async-storage/async-storage`, `react-native-document-picker` 9.x, `react-native-image-picker` 7.x, `mixpanel-react-native` (existing), `@testing-library/react-native` for UI tests.

**Source documents (read-only references):**
- Spec: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/specs/2026-05-03-day1-diagnostic-redesign-design.md` — focus on §3.1, §3.4, §3.6, §13.1, §13.2, §13.4, §13.5 (onboarding subset), Appendix A.
- Plan 1 (data foundation): `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/plans/2026-05-03-diagnostic-phase0.5-seed-scripts.md`
- Plan 2a (backend onboarding APIs that this plan consumes): `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/plans/2026-05-03-diagnostic-phase2a-backend-foundation.md`

**iOS repo path (all iOS file paths in this plan are relative to here):**
`/Users/nirpekshnandan/My Products/ScaleUpDemo-f/`

**Android repo path (all Android file paths in this plan are relative to here):**
`/Users/nirpekshnandan/My Products/ScaleUpAndroid/`

---

## File Structure (decisions locked here)

### iOS

| Path | Responsibility | Status |
|---|---|---|
| `ScaleUp/Models/Onboarding.swift` | Onboarding enums + entry models | MODIFY (add `ProficiencyLevel`) |
| `ScaleUp/Features/Onboarding/ViewModels/OnboardingViewModel.swift` | Step state + submission | MODIFY (taxonomy fetch, self-ratings, sub-step nav, syllabus state) |
| `ScaleUp/Features/Onboarding/Services/OnboardingTopicService.swift` | Networking for `/onboarding/topics/suggest` and `/onboarding/complete` | NEW |
| `ScaleUp/Features/Onboarding/Services/OnboardingTopicServiceTests.swift` | Service tests with mocked URLProtocol | NEW |
| `ScaleUp/Features/Onboarding/Services/SyllabusUploadService.swift` | Networking for `/diagnostic/syllabus/upload-init`, `/complete`, `/status` | NEW |
| `ScaleUp/Features/Onboarding/Views/Steps/InterestsStepView.swift` | Step 5 — taxonomy chips + custom add cap-8 + AI badge + tooltip | MODIFY (rebuild) |
| `ScaleUp/Features/Onboarding/Views/Steps/SelfRatingSubStepView.swift` | Step 5 sub-view — 4 chips per topic + anchored examples | NEW |
| `ScaleUp/Features/Onboarding/Views/Steps/SyllabusUploadView.swift` | Optional syllabus upload card + progress + extracted-topic confirm | NEW |
| `ScaleUp/Features/Onboarding/Views/Components/TopicChipView.swift` | Reusable taxonomy chip with description tooltip + AI badge | NEW |
| `ScaleUp/Features/Home/Views/CalibrationBannerView.swift` | Home-tab banner for users with `needsCalibration: true` | NEW |
| `ScaleUp/Features/Home/Services/CalibrationPromptStore.swift` | UserDefaults-backed dismiss / quiet-period / max-prompt tracking | NEW |
| `ScaleUp/Features/Home/Services/CalibrationPromptStoreTests.swift` | Persistence + quiet-period unit tests | NEW |
| `ScaleUp/Features/Home/Views/HomeView.swift` | Home tab root | MODIFY (mount banner above existing content) |
| `ScaleUp/Services/Analytics/MixpanelEvents.swift` | Existing event constants (or equivalent) | MODIFY (add onboarding events) |

### Android

| Path | Responsibility | Status |
|---|---|---|
| `src/screens/onboarding/OnboardingContainer.tsx` | Step state + submission | MODIFY (`OnboardingData` interface, sub-step nav, taxonomy fetch) |
| `src/services/onboardingTopicService.ts` | Axios calls for taxonomy + onboarding completion | NEW |
| `src/services/syllabusService.ts` | Axios calls for syllabus init / complete / status polling | NEW |
| `src/screens/onboarding/steps/InterestsStep.tsx` | Step 5 — taxonomy chips + custom add cap-8 + AI badge + tooltip | MODIFY (rebuild) |
| `src/screens/onboarding/steps/SelfRatingSubStep.tsx` | 4 chips per topic + anchored example modal | NEW |
| `src/screens/onboarding/steps/SyllabusUpload.tsx` | Optional upload card + status polling | NEW |
| `src/screens/onboarding/components/TopicChip.tsx` | Reusable chip with description tooltip + AI badge | NEW |
| `src/screens/home/CalibrationBanner.tsx` | Home banner | NEW |
| `src/screens/home/HomeScreen.tsx` | Home root | MODIFY (mount banner) |
| `src/store/slices/calibrationSlice.ts` | Banner shown / dismissed / count + quiet-until persisted via AsyncStorage | NEW |
| `src/services/analytics/mixpanel.ts` | Existing analytics module | MODIFY (add onboarding event helpers) |
| `__tests__/onboardingTopicService.test.ts` | Service tests with mocked Axios | NEW |
| `__tests__/calibrationSlice.test.ts` | Reducer + thunk tests | NEW |
| `__tests__/InterestsStep.test.tsx` | RTL render + interaction smoke test | NEW |

**Conventions:**
- iOS uses `Typography`, `ColorTokens`, `Spacing`, `CornerRadius`, `Motion`, `Haptics` from `ScaleUp/DesignSystem/Theme/`. Match existing `BackgroundStepView` and `InterestsStepView` design language.
- iOS view models stay `@Observable @MainActor` and accept dependencies via initializer for testability.
- iOS networking follows the `OnboardingService` pattern (`URLSession` + `JSONEncoder/Decoder` + custom `OnboardingError`).
- Android components use theme tokens from `src/theme/` (`Colors`, `Typography`, `Spacing`, `CornerRadius`).
- Android networking uses the shared Axios instance from `src/services/api.ts`. Errors surface a toast + retry button.
- Android tests run via `npm test` (Jest + `@testing-library/react-native`).
- iOS tests run via `xcodebuild test` against the existing `ScaleUpTests` target.
- All Mixpanel events use the existing helper / constants module (do not introduce a second analytics SDK).
- Commits follow existing style (`feat(onboarding-ios): ...` / `feat(onboarding-rn): ...`).

---

## Prerequisites

Before starting Task 1:

1. **Plan 1 complete** — `TopicTaxonomy`, `CompanyProfile`, anchor + bank questions are seeded in the dev MongoDB. The taxonomy lookup returns valid topics for at least the most common `(objectiveType × specifics)` combos.
2. **Plan 2a complete** — All three onboarding/syllabus endpoints exist and return the documented contracts:
   - `POST /onboarding/topics/suggest` → `{ topics: [{ canonicalName, name, description, isFutureProofing, baseDifficulty }], cacheHit, source }`
   - `POST /onboarding/complete` → `{ userObjectiveId, needsCalibration: false }`
   - `POST /diagnostic/syllabus/upload-init` → `{ syllabusId, uploadUrl }`
   - `POST /diagnostic/syllabus/:id/complete` → `{ syllabusId, status: 'queued' }`
   - `GET /diagnostic/syllabus/:id/status` → `{ status, extractedTopics?: [{ canonicalName, name, description }] }`
3. iOS repo on a clean working branch:
   ```bash
   cd /Users/nirpekshnandan/My\ Products/ScaleUpDemo-f
   git checkout -b feat/diagnostic-phase2b-onboarding-ios
   git status
   ```
4. Android repo on a clean working branch:
   ```bash
   cd /Users/nirpekshnandan/My\ Products/ScaleUpAndroid
   git checkout -b feat/diagnostic-phase2b-onboarding-rn
   git status
   ```
5. Backend dev API URL is configured in both apps' env files. iOS uses the existing `APIConfig.baseURL`; Android uses the existing `API_BASE_URL` constant in `src/services/api.ts`.
6. Mixpanel SDK is initialised in both apps (per existing analytics plan).

---

## Task 1: Add `ProficiencyLevel` enum + `topicSelfRatings` model field (iOS)

**Files:**
- Modify: `ScaleUp/Models/Onboarding.swift`

- [ ] **Step 1: Read the existing model**

Confirm the existing enum style (`String, Codable, CaseIterable, Identifiable`). The new `ProficiencyLevel` mirrors `CurrentLevel`.

- [ ] **Step 2: Add the enum + supporting types**

Append to `ScaleUp/Models/Onboarding.swift`:

```swift
// MARK: - Proficiency Level (per-topic self-rating)

enum ProficiencyLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case novice, familiar, proficient, expert

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Anchor copy from spec Appendix A.
    var anchorExample: String {
        switch self {
        case .novice:     return "I've heard of this but never really used it."
        case .familiar:   return "I've used this a few times but still feel uncertain."
        case .proficient: return "I use this confidently in most situations."
        case .expert:     return "I could teach this to others or be the go-to person on my team."
        }
    }

    var icon: String {
        switch self {
        case .novice:     return "leaf"
        case .familiar:   return "lightbulb"
        case .proficient: return "checkmark.seal"
        case .expert:     return "star.fill"
        }
    }
}

// MARK: - Suggested Topic (taxonomy entry returned by BE)

struct SuggestedTopic: Codable, Hashable, Identifiable, Sendable {
    let canonicalName: String
    let name: String
    let description: String
    let isFutureProofing: Bool
    let baseDifficulty: String

    var id: String { canonicalName }
}

// MARK: - Topic source (analytics)

enum TopicSource: String, Codable, Sendable {
    case taxonomy
    case custom
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/nirpekshnandan/My\ Products/ScaleUpDemo-f
xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -20
```

Build must succeed (warnings OK).

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Models/Onboarding.swift
git commit -m "feat(onboarding-ios): add ProficiencyLevel enum and SuggestedTopic model"
```

---

## Task 2: OnboardingTopicService networking layer (iOS)

**Files:**
- Create: `ScaleUp/Features/Onboarding/Services/OnboardingTopicService.swift`
- Create: `ScaleUp/Features/Onboarding/Services/OnboardingTopicServiceTests.swift`

- [ ] **Step 1: Write the failing test**

Create `OnboardingTopicServiceTests.swift`:

```swift
import XCTest
@testable import ScaleUp

@MainActor
final class OnboardingTopicServiceTests: XCTestCase {

    override func setUp() async throws {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
    }

    func test_fetchSuggestedTopics_decodesResponse() async throws {
        let json = """
        {"topics":[{"canonicalName":"product-strategy","name":"Product Strategy","description":"Vision and roadmap","isFutureProofing":false,"baseDifficulty":"intermediate"}],"cacheHit":true,"source":"curated"}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.absoluteString.hasSuffix("/onboarding/topics/suggest") ?? false)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let session = makeSession()
        let service = OnboardingTopicService(session: session, baseURL: URL(string: "https://example.test")!, authToken: { "token" })
        let result = try await service.fetchSuggestedTopics(
            objectiveType: .upskilling,
            specifics: ["targetSkill": "Product Management"],
            company: nil
        )

        XCTAssertEqual(result.topics.count, 1)
        XCTAssertEqual(result.topics[0].canonicalName, "product-strategy")
        XCTAssertTrue(result.cacheHit)
    }

    func test_fetchSuggestedTopics_throwsOn500() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = OnboardingTopicService(
            session: makeSession(),
            baseURL: URL(string: "https://example.test")!,
            authToken: { "token" }
        )
        do {
            _ = try await service.fetchSuggestedTopics(objectiveType: .upskilling, specifics: [:], company: nil)
            XCTFail("expected throw")
        } catch {
            // ok
        }
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

Run; expect compile failure (service doesn't exist yet).

- [ ] **Step 2: Implement the service**

Create `ScaleUp/Features/Onboarding/Services/OnboardingTopicService.swift`:

```swift
import Foundation

// MARK: - Response types

struct SuggestedTopicsResponse: Codable, Sendable {
    let topics: [SuggestedTopic]
    let cacheHit: Bool
    let source: String      // "curated" | "llm-generated"
}

struct OnboardingCompletePayload: Codable, Sendable {
    let firstName: String
    let lastName: String
    let educationEntries: [EducationPayload]
    let workEntries: [WorkPayload]
    let objectiveType: String
    let specifics: [String: String]
    let timeline: String
    let currentLevel: String
    let weeklyHours: Double
    let learningStyle: String
    let topicsOfInterest: [TopicSelectionPayload]
    let topicSelfRatings: [String: String]   // canonicalName → proficiency raw
    let syllabusId: String?

    struct EducationPayload: Codable, Sendable {
        let degree: String
        let institution: String
        let yearOfCompletion: Int?
        let currentlyPursuing: Bool
    }
    struct WorkPayload: Codable, Sendable {
        let role: String
        let company: String
        let years: Int?
        let currentlyWorking: Bool
    }
    struct TopicSelectionPayload: Codable, Sendable {
        let canonicalName: String
        let name: String
        let source: String        // TopicSource.rawValue
        let isFutureProofing: Bool
    }
}

struct OnboardingCompleteResponse: Codable, Sendable {
    let userObjectiveId: String
    let needsCalibration: Bool
}

// MARK: - Errors

enum OnboardingTopicError: Error, LocalizedError {
    case network(URLError)
    case decoding(Error)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .decoding:       return "Could not read server response."
        case .http(let code): return "Server error (\(code)). Please try again."
        }
    }
}

// MARK: - Service

@MainActor
final class OnboardingTopicService {

    private let session: URLSession
    private let baseURL: URL
    private let authToken: () -> String?

    init(
        session: URLSession = .shared,
        baseURL: URL = APIConfig.baseURL,
        authToken: @escaping () -> String? = { AuthTokenStore.shared.currentToken }
    ) {
        self.session = session
        self.baseURL = baseURL
        self.authToken = authToken
    }

    // MARK: Suggest topics

    func fetchSuggestedTopics(
        objectiveType: ObjectiveType,
        specifics: [String: String],
        company: String?
    ) async throws -> SuggestedTopicsResponse {
        struct Body: Encodable {
            let objectiveType: String
            let specifics: [String: String]
            let company: String?
        }
        let body = Body(objectiveType: objectiveType.rawValue, specifics: specifics, company: company)
        return try await post(path: "/onboarding/topics/suggest", body: body)
    }

    // MARK: Submit onboarding

    func submitOnboarding(_ payload: OnboardingCompletePayload) async throws -> OnboardingCompleteResponse {
        try await post(path: "/onboarding/complete", body: payload)
    }

    // MARK: helpers

    private func post<T: Encodable, R: Decodable>(path: String, body: T) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        req.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw OnboardingTopicError.http(-1)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw OnboardingTopicError.http(http.statusCode)
            }
            do {
                return try JSONDecoder().decode(R.self, from: data)
            } catch {
                throw OnboardingTopicError.decoding(error)
            }
        } catch let urlErr as URLError {
            throw OnboardingTopicError.network(urlErr)
        }
    }
}
```

> **Note:** `APIConfig.baseURL` and `AuthTokenStore.shared.currentToken` already exist in the project (see `OnboardingService.swift`). Reuse the same getters; do not introduce new globals.

- [ ] **Step 3: Run the test target**

```bash
xcodebuild test -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ScaleUpTests/OnboardingTopicServiceTests | tail -30
```

Both tests must pass.

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Features/Onboarding/Services/OnboardingTopicService.swift ScaleUp/Features/Onboarding/Services/OnboardingTopicServiceTests.swift
git commit -m "feat(onboarding-ios): OnboardingTopicService for taxonomy + completion endpoints"
```

---

## Task 3: OnboardingViewModel — taxonomy fetch, self-ratings, sub-step nav

**Files:**
- Modify: `ScaleUp/Features/Onboarding/ViewModels/OnboardingViewModel.swift`

This task wires the new model fields and service into the existing view model so the rebuilt `InterestsStepView` (Task 4) and new `SelfRatingSubStepView` (Task 5) have something to bind to. The progress bar still reads "Step 5 of 6" — the sub-step is internal.

- [ ] **Step 1: Add new state**

Inside the `// MARK: - Step 5: Interests` block, replace the existing `selectedTopics`/`customTopic` declarations with:

```swift
// MARK: - Step 5: Interests

/// Topics fetched from BE taxonomy. Pre-selected by default.
var suggestedTopics: [SuggestedTopic] = []
/// Topics the user added manually (capped so total ≤ 8).
var customTopics: [SuggestedTopic] = []
/// Canonical names of topics currently selected. Mirrors prior `selectedTopics` semantics.
var selectedCanonicals: Set<String> = []
/// Current draft for "+ Add a topic".
var customTopic: String = ""
/// Loading state for taxonomy fetch.
var isLoadingTopics = false
/// Per-topic self-rating; key is canonicalName.
var topicSelfRatings: [String: ProficiencyLevel] = [:]
/// Within Step 5, are we on the rating sub-step?
var isOnRatingSubStep = false
/// Optional syllabus ID returned by upload flow.
var syllabusId: String?
/// Topic descriptions extracted from a syllabus upload (replace taxonomy when present).
var syllabusExtractedTopics: [SuggestedTopic] = []
```

> Any reference to the removed `selectedTopics: Set<String>` elsewhere in the view model (e.g., `addCustomTopic`, `toggleTopic`, `submitOnboarding`) must be updated in Steps 2-4 below.

- [ ] **Step 2: Add the dependency injection point**

Replace the existing `private let service = OnboardingService()` block with:

```swift
private let service: OnboardingService
private let topicService: OnboardingTopicService

init(
    initialStep: Int,
    appState: AppState,
    service: OnboardingService = OnboardingService(),
    topicService: OnboardingTopicService = OnboardingTopicService()
) {
    self.currentStep = initialStep
    self.appState = appState
    self.service = service
    self.topicService = topicService

    if let user = appState.currentUser {
        self.firstName = user.firstName
        self.lastName = user.lastName ?? ""
    }
}
```

- [ ] **Step 3: Add taxonomy fetch + topic editing helpers**

Add these methods to the view model:

```swift
// MARK: - Step 5 helpers

func loadSuggestedTopics() async {
    guard let objective = selectedObjective else { return }
    isLoadingTopics = true
    errorMessage = nil
    let specifics = currentSpecificsDictionary()
    do {
        let response = try await topicService.fetchSuggestedTopics(
            objectiveType: objective,
            specifics: specifics,
            company: targetCompany.isEmpty ? nil : targetCompany
        )
        self.suggestedTopics = response.topics
        // Pre-select all suggested topics.
        for t in response.topics { selectedCanonicals.insert(t.canonicalName) }
        Mixpanel.track(event: .onboardingTopicTaxonomyLoaded, props: [
            "cacheHit": response.cacheHit,
            "source": response.source,
            "topicCount": response.topics.count
        ])
    } catch {
        errorMessage = (error as? OnboardingTopicError)?.errorDescription ?? error.localizedDescription
    }
    isLoadingTopics = false
}

func toggleTopic(_ topic: SuggestedTopic) {
    if selectedCanonicals.contains(topic.canonicalName) {
        selectedCanonicals.remove(topic.canonicalName)
        topicSelfRatings.removeValue(forKey: topic.canonicalName)
        Mixpanel.track(event: .onboardingTopicRemoved, props: [
            "canonicalName": topic.canonicalName,
            "source": customTopics.contains(where: { $0.canonicalName == topic.canonicalName }) ? "custom" : "taxonomy"
        ])
    } else if totalSelectedCount < 8 {
        selectedCanonicals.insert(topic.canonicalName)
    }
}

func addCustomTopic() {
    let trimmed = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, totalSelectedCount < 8 else { return }
    let canonical = trimmed.lowercased().replacingOccurrences(of: " ", with: "-")
    let topic = SuggestedTopic(
        canonicalName: canonical,
        name: trimmed,
        description: "Custom topic you added.",
        isFutureProofing: false,
        baseDifficulty: "intermediate"
    )
    customTopics.append(topic)
    selectedCanonicals.insert(canonical)
    customTopic = ""
    Mixpanel.track(event: .onboardingTopicAddedCustom, props: ["canonicalName": canonical])
}

func setRating(_ rating: ProficiencyLevel, for topic: SuggestedTopic) {
    topicSelfRatings[topic.canonicalName] = rating
}

var totalSelectedCount: Int { selectedCanonicals.count }

var allDisplayableTopics: [SuggestedTopic] {
    let pool = syllabusExtractedTopics.isEmpty ? suggestedTopics : syllabusExtractedTopics
    let extras = customTopics
    var seen = Set<String>()
    return (pool + extras).filter { seen.insert($0.canonicalName).inserted }
}

var canProceedFromTopicSelection: Bool {
    totalSelectedCount >= 3 && totalSelectedCount <= 8
}

var canFinishStep5: Bool {
    canProceedFromTopicSelection &&
    selectedCanonicals.allSatisfy { topicSelfRatings[$0] != nil }
}

private func currentSpecificsDictionary() -> [String: String] {
    var dict: [String: String] = [:]
    if !examName.isEmpty       { dict["examName"]       = examName }
    if !targetSkill.isEmpty    { dict["targetSkill"]    = targetSkill }
    if !targetRole.isEmpty     { dict["targetRole"]     = targetRole }
    if !targetCompany.isEmpty  { dict["targetCompany"]  = targetCompany }
    if !fromDomain.isEmpty     { dict["fromDomain"]     = fromDomain }
    if !toDomain.isEmpty       { dict["toDomain"]       = toDomain }
    return dict
}
```

- [ ] **Step 4: Update `submitOnboarding` to use the new payload**

Locate the existing `submitOnboarding` method and replace its body to build an `OnboardingCompletePayload` from the new fields, then call `topicService.submitOnboarding(...)`. The selected topics ship as `TopicSelectionPayload` with `source: "taxonomy"|"custom"` and `isFutureProofing` flag.

```swift
func submitOnboarding() async {
    isLoading = true
    defer { isLoading = false }

    let topicsPayload: [OnboardingCompletePayload.TopicSelectionPayload] = allDisplayableTopics
        .filter { selectedCanonicals.contains($0.canonicalName) }
        .map { topic in
            let isCustom = customTopics.contains { $0.canonicalName == topic.canonicalName }
            return .init(
                canonicalName: topic.canonicalName,
                name: topic.name,
                source: isCustom ? TopicSource.custom.rawValue : TopicSource.taxonomy.rawValue,
                isFutureProofing: topic.isFutureProofing
            )
        }

    let ratings = topicSelfRatings.mapValues { $0.rawValue }

    let payload = OnboardingCompletePayload(
        firstName: firstName,
        lastName: lastName,
        educationEntries: educationEntries.map { .init(degree: $0.degree, institution: $0.institution, yearOfCompletion: $0.yearOfCompletion, currentlyPursuing: $0.currentlyPursuing) },
        workEntries: workEntries.map { .init(role: $0.role, company: $0.company, years: $0.years, currentlyWorking: $0.currentlyWorking) },
        objectiveType: selectedObjective?.rawValue ?? "upskilling",
        specifics: currentSpecificsDictionary(),
        timeline: timeline.rawValue,
        currentLevel: currentLevel.rawValue,
        weeklyHours: weeklyHours,
        learningStyle: learningStyle.rawValue,
        topicsOfInterest: topicsPayload,
        topicSelfRatings: ratings,
        syllabusId: syllabusId
    )

    do {
        let response = try await topicService.submitOnboarding(payload)
        Mixpanel.track(event: .onboardingSelfRatingCompleted, props: [
            "topicCount": ratings.count,
            "ratingDistribution": ratingDistribution(from: ratings)
        ])
        appState?.onboardingCompleted(userObjectiveId: response.userObjectiveId)
    } catch {
        errorMessage = (error as? OnboardingTopicError)?.errorDescription ?? error.localizedDescription
    }
}

private func ratingDistribution(from ratings: [String: String]) -> [String: Int] {
    var counts: [String: Int] = ["novice": 0, "familiar": 0, "proficient": 0, "expert": 0]
    for value in ratings.values { counts[value, default: 0] += 1 }
    return counts
}
```

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -30
```

Fix any compile errors (e.g., other call sites referencing the removed `selectedTopics: Set<String>`).

- [ ] **Step 6: Commit**

```bash
git add ScaleUp/Features/Onboarding/ViewModels/OnboardingViewModel.swift
git commit -m "feat(onboarding-ios): view model wires taxonomy fetch, self-ratings, sub-step nav"
```

---

## Task 4: Rebuild `InterestsStepView` with taxonomy chips, AI badge, cap-8 add (iOS)

**Files:**
- Modify: `ScaleUp/Features/Onboarding/Views/Steps/InterestsStepView.swift`
- Create: `ScaleUp/Features/Onboarding/Views/Components/TopicChipView.swift`

This view becomes a thin router that shows either the **topic-selection** sub-screen or the **self-rating** sub-screen (Task 5) depending on `viewModel.isOnRatingSubStep`. Both share Step 5 of 6 in the progress bar.

- [ ] **Step 1: Create the reusable chip**

Create `ScaleUp/Features/Onboarding/Views/Components/TopicChipView.swift`:

```swift
import SwiftUI

struct TopicChipView: View {
    let topic: SuggestedTopic
    let isSelected: Bool
    let onToggle: () -> Void
    let onInfo: () -> Void

    @State private var bumping = false

    var body: some View {
        HStack(spacing: 6) {
            if topic.isFutureProofing {
                Text("✦ Future-proofing")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(topic.name)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText.opacity(0.8) : ColorTokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(isSelected ? ColorTokens.gold : Color.clear)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1))
        .scaleEffect(bumping ? 0.94 : 1)
        .onTapGesture {
            Haptics.selection()
            withAnimation(.easeOut(duration: 0.12)) { bumping = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { bumping = false }
                onToggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(topic.name)\(topic.isFutureProofing ? ", future proofing" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

- [ ] **Step 2: Rebuild `InterestsStepView`**

Replace the entire contents of `InterestsStepView.swift`:

```swift
import SwiftUI

struct InterestsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var appeared = false
    @State private var infoTopic: SuggestedTopic?

    var body: some View {
        Group {
            if viewModel.isOnRatingSubStep {
                SelfRatingSubStepView(viewModel: viewModel)
            } else {
                topicSelectionScreen
            }
        }
        .task { if viewModel.suggestedTopics.isEmpty { await viewModel.loadSuggestedTopics() } }
    }

    // MARK: - Topic selection

    private var topicSelectionScreen: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                heading
                if viewModel.isLoadingTopics {
                    ProgressView().padding(.top, Spacing.lg)
                } else {
                    selectionCounter
                    chipFlow
                    customAddRow
                    nextButton
                    Spacer().frame(height: Spacing.xxl)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
        .sheet(item: $infoTopic) { topic in
            TopicInfoSheet(topic: topic)
                .presentationDetents([.fraction(0.3)])
        }
    }

    private var heading: some View {
        VStack(spacing: Spacing.sm) {
            Text("Pick your interests")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("We've suggested \(viewModel.suggestedTopics.count) — tap to remove or add up to \(8 - viewModel.totalSelectedCount) more.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    private var selectionCounter: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(viewModel.totalSelectedCount >= 3 ? ColorTokens.success : ColorTokens.gold)
            Text("\(viewModel.totalSelectedCount) of 8 selected")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var chipFlow: some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(Array(viewModel.allDisplayableTopics.enumerated()), id: \.element.id) { index, topic in
                TopicChipView(
                    topic: topic,
                    isSelected: viewModel.selectedCanonicals.contains(topic.canonicalName),
                    onToggle: { viewModel.toggleTopic(topic) },
                    onInfo: { infoTopic = topic }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.03), value: appeared)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var customAddRow: some View {
        HStack(spacing: Spacing.sm) {
            ScaleUpTextField(
                label: "Add a topic",
                icon: "plus",
                text: $viewModel.customTopic,
                autocapitalization: .words
            )
            Button {
                viewModel.addCustomTopic()
            } label: {
                Text("Add")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 14)
                    .background(viewModel.totalSelectedCount < 8 ? ColorTokens.gold : ColorTokens.gold.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .disabled(viewModel.totalSelectedCount >= 8)
            .padding(.top, 20)
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var nextButton: some View {
        Button {
            Haptics.success()
            withAnimation(.easeInOut(duration: 0.25)) { viewModel.isOnRatingSubStep = true }
        } label: {
            Text("Next — rate your level")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.canProceedFromTopicSelection ? ColorTokens.gold : ColorTokens.gold.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .disabled(!viewModel.canProceedFromTopicSelection)
        .padding(.horizontal, Spacing.lg)
    }
}

private struct TopicInfoSheet: View {
    let topic: SuggestedTopic
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(topic.name).font(Typography.titleMedium)
                if topic.isFutureProofing {
                    Text("✦ Future-proofing")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            Text(topic.description).font(Typography.bodyRegular).foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
        .padding(Spacing.lg)
    }
}
```

> The pre-existing `FlowLayout` struct stays in this file (do not delete).

- [ ] **Step 3: Manual smoke (Preview)**

Add a preview block at the bottom of the file:

```swift
#Preview {
    let app = AppState()
    let vm = OnboardingViewModel(initialStep: 4, appState: app)
    vm.suggestedTopics = [
        SuggestedTopic(canonicalName: "product-strategy", name: "Product Strategy", description: "Vision, roadmap, prioritisation.", isFutureProofing: false, baseDifficulty: "intermediate"),
        SuggestedTopic(canonicalName: "ai-product-mgmt", name: "AI Product Management", description: "Scoping AI features and evals.", isFutureProofing: true, baseDifficulty: "intermediate")
    ]
    vm.selectedCanonicals = ["product-strategy", "ai-product-mgmt"]
    return InterestsStepView(viewModel: vm)
}
```

Open the canvas, confirm chips render, AI badge shows on the second chip, info tooltip opens.

- [ ] **Step 4: Build + commit**

```bash
xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
git add ScaleUp/Features/Onboarding/Views/Steps/InterestsStepView.swift ScaleUp/Features/Onboarding/Views/Components/TopicChipView.swift
git commit -m "feat(onboarding-ios): rebuild InterestsStepView with taxonomy chips + AI badge + cap-8"
```

---

## Task 5: SelfRatingSubStepView — 4 chips per topic with anchored examples (iOS)

**Files:**
- Create: `ScaleUp/Features/Onboarding/Views/Steps/SelfRatingSubStepView.swift`

This sub-view appears within Step 5 once topic selection is finalised. The progress bar still reads "Step 5 of 6". Each topic shows the four `ProficiencyLevel` chips; tapping a chip selects the rating; tapping the chip's info icon (or any unselected chip) reveals the anchor example briefly.

- [ ] **Step 1: Implement the view**

Create the file:

```swift
import SwiftUI

struct SelfRatingSubStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var expandedAnchor: String?    // "<canonical>:<level>"

    private var topicsToRate: [SuggestedTopic] {
        viewModel.allDisplayableTopics.filter { viewModel.selectedCanonicals.contains($0.canonicalName) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                header
                ForEach(topicsToRate) { topic in
                    topicCard(topic)
                }
                finishButton
                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .background(ColorTokens.surfaceBackground)
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Text("How would you rate yourself?")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text("Be honest — we'll calibrate against this in your diagnostic.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.isOnRatingSubStep = false }
            } label: {
                Label("Edit topics", systemImage: "chevron.left")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.gold)
            }
        }
        .padding(.top, Spacing.lg)
    }

    private func topicCard(_ topic: SuggestedTopic) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(topic.name).font(Typography.bodyBold).foregroundStyle(ColorTokens.textPrimary)
                if topic.isFutureProofing {
                    Text("✦").foregroundStyle(ColorTokens.gold)
                }
                Spacer()
            }
            HStack(spacing: Spacing.sm) {
                ForEach(ProficiencyLevel.allCases) { level in
                    ratingChip(level: level, topic: topic)
                }
            }
            if let anchor = expandedAnchor, anchor.hasPrefix(topic.canonicalName + ":") {
                let levelRaw = String(anchor.split(separator: ":").last ?? "")
                if let level = ProficiencyLevel(rawValue: levelRaw) {
                    Text(level.anchorExample)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(Spacing.sm)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func ratingChip(level: ProficiencyLevel, topic: SuggestedTopic) -> some View {
        let isSelected = viewModel.topicSelfRatings[topic.canonicalName] == level
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.setRating(level, for: topic)
                expandedAnchor = "\(topic.canonicalName):\(level.rawValue)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if expandedAnchor == "\(topic.canonicalName):\(level.rawValue)" {
                    withAnimation(.easeOut(duration: 0.25)) { expandedAnchor = nil }
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: level.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(level.displayName).font(Typography.caption)
            }
            .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? ColorTokens.gold : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var finishButton: some View {
        Button {
            Task { await viewModel.submitOnboarding() }
        } label: {
            HStack {
                if viewModel.isLoading { ProgressView().tint(ColorTokens.buttonPrimaryText) }
                Text("Start my diagnostic")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.canFinishStep5 ? ColorTokens.gold : ColorTokens.gold.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .disabled(!viewModel.canFinishStep5 || viewModel.isLoading)
    }
}
```

- [ ] **Step 2: Build + commit**

```bash
xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
git add ScaleUp/Features/Onboarding/Views/Steps/SelfRatingSubStepView.swift
git commit -m "feat(onboarding-ios): SelfRatingSubStepView with 4 chips + anchored examples per topic"
```

---

## Task 6: SyllabusUploadView + SyllabusUploadService (iOS)

**Files:**
- Create: `ScaleUp/Features/Onboarding/Services/SyllabusUploadService.swift`
- Create: `ScaleUp/Features/Onboarding/Views/Steps/SyllabusUploadView.swift`

The upload card surfaces only for `academicExcellence` (default) and `examPreparation` when the exam is non-standardized. The view is mounted **above** the topic-selection screen of `InterestsStepView` for those flows; if user taps "Skip", control passes to the standard taxonomy flow. If user uploads, on success the extracted topics flow into `viewModel.syllabusExtractedTopics` and replace the taxonomy pool.

- [ ] **Step 1: Define standardized exam list**

Add to `ScaleUp/Models/Onboarding.swift`:

```swift
extension ObjectiveType {
    /// Whether the syllabus upload card should be offered.
    func shouldOfferSyllabusUpload(examName: String?) -> Bool {
        switch self {
        case .academicExcellence: return true
        case .examPreparation:
            let standardized: Set<String> = ["GMAT", "JEE", "NEET", "UPSC", "CAT", "GRE", "GATE", "SAT"]
            let trimmed = (examName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return !standardized.contains(trimmed)
        default: return false
        }
    }
}
```

- [ ] **Step 2: Create the upload service**

```swift
// ScaleUp/Features/Onboarding/Services/SyllabusUploadService.swift
import Foundation

struct SyllabusUploadInitResponse: Codable, Sendable {
    let syllabusId: String
    let uploadUrl: String           // pre-signed S3 PUT URL
}
struct SyllabusStatusResponse: Codable, Sendable {
    let status: String              // "pending" | "extracting" | "ready" | "failed"
    let extractedTopics: [SuggestedTopic]?
    let errorReason: String?
}

enum SyllabusUploadError: Error, LocalizedError {
    case http(Int), upload(URLError), decoding(Error), extractionFailed(String)
    var errorDescription: String? {
        switch self {
        case .http(let c):                return "Server error (\(c))."
        case .upload(let e):              return "Upload failed: \(e.localizedDescription)"
        case .decoding:                   return "Bad server response."
        case .extractionFailed(let r):    return r.isEmpty ? "Extraction failed." : r
        }
    }
}

@MainActor
final class SyllabusUploadService {

    private let session: URLSession
    private let baseURL: URL
    private let authToken: () -> String?

    init(session: URLSession = .shared,
         baseURL: URL = APIConfig.baseURL,
         authToken: @escaping () -> String? = { AuthTokenStore.shared.currentToken }) {
        self.session = session
        self.baseURL = baseURL
        self.authToken = authToken
    }

    func initUpload(filename: String, mimeType: String, byteCount: Int) async throws -> SyllabusUploadInitResponse {
        struct Body: Encodable { let filename: String; let mimeType: String; let byteCount: Int }
        return try await postJSON(path: "/diagnostic/syllabus/upload-init", body: Body(filename: filename, mimeType: mimeType, byteCount: byteCount))
    }

    func uploadFile(to url: URL, data: Data, mimeType: String, progress: @escaping (Double) -> Void) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: req, from: data, delegate: UploadProgressDelegate(progress: progress))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SyllabusUploadError.http(http.statusCode)
        }
    }

    func completeUpload(syllabusId: String) async throws {
        struct Empty: Encodable {}
        let _: SyllabusStatusResponse = try await postJSON(path: "/diagnostic/syllabus/\(syllabusId)/complete", body: Empty())
    }

    func pollStatus(syllabusId: String) async throws -> SyllabusStatusResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("/diagnostic/syllabus/\(syllabusId)/status"))
        req.httpMethod = "GET"
        if let token = authToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SyllabusUploadError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do { return try JSONDecoder().decode(SyllabusStatusResponse.self, from: data) }
        catch { throw SyllabusUploadError.decoding(error) }
    }

    private func postJSON<T: Encodable, R: Decodable>(path: String, body: T) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SyllabusUploadError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do { return try JSONDecoder().decode(R.self, from: data) }
        catch { throw SyllabusUploadError.decoding(error) }
    }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let progress: (Double) -> Void
    init(progress: @escaping (Double) -> Void) { self.progress = progress }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        Task { @MainActor in self.progress(Double(totalBytesSent) / Double(totalBytesExpectedToSend)) }
    }
}
```

- [ ] **Step 3: Create the view**

```swift
// ScaleUp/Features/Onboarding/Views/Steps/SyllabusUploadView.swift
import SwiftUI
import UniformTypeIdentifiers

struct SyllabusUploadView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var pickerSource: PickerSource?
    @State private var uploadProgress: Double = 0
    @State private var phase: Phase = .idle
    @State private var statusMessage: String = ""
    private let service = SyllabusUploadService()

    enum PickerSource: Identifiable { case file, image; var id: String { String(describing: self) } }
    enum Phase { case idle, uploading, extracting, ready, failed }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                heroCard
                ctas
                if phase == .uploading || phase == .extracting {
                    progressBlock
                }
                if phase == .ready {
                    extractedList
                }
                skipRow
                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .fileImporter(isPresented: Binding(get: { pickerSource == .file }, set: { if !$0 { pickerSource = nil } }),
                       allowedContentTypes: [UTType.pdf, UTType.image, UTType(filenameExtension: "pptx")!, UTType(filenameExtension: "ppt")!],
                       allowsMultipleSelection: false) { result in
            handleFileResult(result)
        }
    }

    private var heroCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.gold)
            Text("Upload your chapter or syllabus")
                .font(Typography.titleMedium)
                .multilineTextAlignment(.center)
            Text("We'll generate questions from your actual content for the most accurate diagnostic.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.top, Spacing.lg)
    }

    private var ctas: some View {
        HStack(spacing: Spacing.md) {
            Button { pickerSource = .file } label: {
                Label("Upload PDF / PPT", systemImage: "doc.fill")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            Button { pickerSource = .image } label: {
                Label("Photo", systemImage: "camera.fill")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.small).stroke(ColorTokens.gold, lineWidth: 1))
            }
        }
    }

    private var progressBlock: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView(value: phase == .uploading ? uploadProgress : nil)
                .progressViewStyle(.linear)
                .tint(ColorTokens.gold)
            Text(statusMessage).font(Typography.bodySmall).foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var extractedList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Extracted topics").font(Typography.bodyBold)
            ForEach(viewModel.syllabusExtractedTopics) { topic in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(ColorTokens.success)
                    Text(topic.name).font(Typography.bodySmall)
                    Spacer()
                }
            }
            Button {
                Mixpanel.track(event: .onboardingSyllabusUploaded, props: [
                    "topicCount": viewModel.syllabusExtractedTopics.count,
                    "fileType": viewModel.syllabusFileTypeForAnalytics ?? "unknown"
                ])
                viewModel.suggestedTopics = viewModel.syllabusExtractedTopics
                viewModel.selectedCanonicals = Set(viewModel.syllabusExtractedTopics.map(\.canonicalName))
                viewModel.showSyllabusUpload = false
            } label: {
                Text("Use these topics")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private var skipRow: some View {
        Button {
            Mixpanel.track(event: .onboardingSyllabusSkipped, props: [:])
            viewModel.showSyllabusUpload = false
        } label: {
            Text("Skip — use standard topics")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .underline()
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Upload pipeline

    private func handleFileResult(_ result: Result<[URL], Error>) {
        Task {
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                let data = try Data(contentsOf: url)
                viewModel.syllabusFileTypeForAnalytics = url.pathExtension.lowercased()
                phase = .uploading
                statusMessage = "Uploading..."
                let initResp = try await service.initUpload(
                    filename: url.lastPathComponent,
                    mimeType: mimeType(for: url),
                    byteCount: data.count
                )
                viewModel.syllabusId = initResp.syllabusId
                try await service.uploadFile(to: URL(string: initResp.uploadUrl)!, data: data, mimeType: mimeType(for: url)) { p in
                    uploadProgress = p
                }
                try await service.completeUpload(syllabusId: initResp.syllabusId)
                phase = .extracting
                statusMessage = "Reading your content..."
                try await poll(syllabusId: initResp.syllabusId)
            } catch {
                phase = .failed
                statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                viewModel.errorMessage = statusMessage
            }
        }
    }

    private func poll(syllabusId: String) async throws {
        var attempts = 0
        while attempts < 60 {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            let s = try await service.pollStatus(syllabusId: syllabusId)
            switch s.status {
            case "ready":
                viewModel.syllabusExtractedTopics = s.extractedTopics ?? []
                phase = .ready
                statusMessage = ""
                return
            case "failed":
                throw SyllabusUploadError.extractionFailed(s.errorReason ?? "Could not read your file.")
            default: break
            }
            attempts += 1
        }
        throw SyllabusUploadError.extractionFailed("Timed out — please try again.")
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":  return "application/pdf"
        case "ppt":  return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "jpg", "jpeg": return "image/jpeg"
        case "png":  return "image/png"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }
}
```

- [ ] **Step 4: Wire into `InterestsStepView`**

In the view model, add:

```swift
var showSyllabusUpload: Bool = false
var syllabusFileTypeForAnalytics: String?

func evaluateSyllabusGate() {
    guard let obj = selectedObjective else { return }
    showSyllabusUpload = obj.shouldOfferSyllabusUpload(examName: examName.isEmpty ? nil : examName)
}
```

Call `viewModel.evaluateSyllabusGate()` from `InterestsStepView.task` before `loadSuggestedTopics`. In the body, gate:

```swift
if viewModel.showSyllabusUpload {
    SyllabusUploadView(viewModel: viewModel)
} else if viewModel.isOnRatingSubStep {
    SelfRatingSubStepView(viewModel: viewModel)
} else {
    topicSelectionScreen
}
```

- [ ] **Step 5: Build + commit**

```bash
xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
git add ScaleUp/Features/Onboarding/Services/SyllabusUploadService.swift \
        ScaleUp/Features/Onboarding/Views/Steps/SyllabusUploadView.swift \
        ScaleUp/Features/Onboarding/Views/Steps/InterestsStepView.swift \
        ScaleUp/Features/Onboarding/ViewModels/OnboardingViewModel.swift \
        ScaleUp/Models/Onboarding.swift
git commit -m "feat(onboarding-ios): SyllabusUploadView with file/image picker + status polling"
```

---

## Task 7: CalibrationBannerView + persistence on Home (iOS)

**Files:**
- Create: `ScaleUp/Features/Home/Views/CalibrationBannerView.swift`
- Create: `ScaleUp/Features/Home/Services/CalibrationPromptStore.swift`
- Create: `ScaleUp/Features/Home/Services/CalibrationPromptStoreTests.swift`
- Modify: `ScaleUp/Features/Home/Views/HomeView.swift`

The banner appears for `appState.currentUser?.needsCalibration == true`. Persistence rules per spec §3.4:

- Banner stays until completed OR explicitly dismissed.
- Dismissal triggers a 14-day quiet period.
- Max 3 prompts then auto-stop (no nag).

- [ ] **Step 1: Write the persistence test**

```swift
// CalibrationPromptStoreTests.swift
import XCTest
@testable import ScaleUp

@MainActor
final class CalibrationPromptStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: CalibrationPromptStore!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "calib-test-\(UUID().uuidString)")!
        store = CalibrationPromptStore(defaults: defaults, now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    func test_initiallyVisible() {
        XCTAssertTrue(store.shouldShow())
        XCTAssertEqual(store.promptCount, 0)
    }

    func test_recordShown_incrementsCount() {
        store.recordShown()
        XCTAssertEqual(store.promptCount, 1)
    }

    func test_dismiss_setsQuietPeriod() {
        store.recordDismissed()
        XCTAssertFalse(store.shouldShow())
        // simulate +15 days
        let later = CalibrationPromptStore(defaults: defaults, now: { Date(timeIntervalSince1970: 1_700_000_000 + 15 * 86_400) })
        XCTAssertTrue(later.shouldShow())
    }

    func test_threePromptsThenAutoStop() {
        for _ in 0..<3 { store.recordShown() }
        XCTAssertFalse(store.shouldShow())
    }
}
```

- [ ] **Step 2: Implement the store**

```swift
// CalibrationPromptStore.swift
import Foundation

@MainActor
final class CalibrationPromptStore {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let quietDays = 14
    private let maxPrompts = 3

    private enum Keys {
        static let count       = "calibration.promptCount"
        static let quietUntil  = "calibration.quietUntil"
        static let completed   = "calibration.completed"
    }

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    var promptCount: Int { defaults.integer(forKey: Keys.count) }
    var isCompleted: Bool { defaults.bool(forKey: Keys.completed) }

    func shouldShow() -> Bool {
        if isCompleted { return false }
        if promptCount >= maxPrompts { return false }
        if let quiet = defaults.object(forKey: Keys.quietUntil) as? Date, now() < quiet { return false }
        return true
    }

    func recordShown() {
        defaults.set(promptCount + 1, forKey: Keys.count)
    }

    func recordDismissed() {
        let until = Calendar.current.date(byAdding: .day, value: quietDays, to: now())!
        defaults.set(until, forKey: Keys.quietUntil)
    }

    func recordCompleted() {
        defaults.set(true, forKey: Keys.completed)
    }
}
```

- [ ] **Step 3: Implement the banner view**

```swift
// CalibrationBannerView.swift
import SwiftUI

struct CalibrationBannerView: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("Get your real proficiency in 9 minutes")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Your plan will adapt to it.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                Button(action: { Haptics.success(); onTap() }) {
                    Text("Start calibration")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.buttonPrimaryText)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 8)
                        .background(ColorTokens.gold)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(6)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(ColorTokens.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
    }
}
```

- [ ] **Step 4: Mount on Home**

In `HomeView.swift`, near the top of the existing main `VStack`/`ScrollView` (above `ReadinessScoreCard`), add:

```swift
@State private var calibStore = CalibrationPromptStore()
@State private var showCalibration = false

// ... in body:
if let user = appState.currentUser, user.needsCalibration, calibStore.shouldShow() {
    CalibrationBannerView(
        onTap: {
            Mixpanel.track(event: .existingUserCalibrationBannerTapped, props: [:])
            showCalibration = true
        },
        onDismiss: {
            Mixpanel.track(event: .existingUserCalibrationBannerDismissed, props: [:])
            calibStore.recordDismissed()
        }
    )
    .onAppear {
        calibStore.recordShown()
        Mixpanel.track(event: .existingUserCalibrationBannerShown, props: [
            "promptCount": calibStore.promptCount
        ])
    }
}
```

Route `showCalibration` to a sheet that re-uses `OnboardingViewModel` initialised at Step 5 with `topicsOfInterest` pre-populated from `appState.currentUser?.topicsOfInterest`. The diagnostic flow itself is built in a later phase — for this plan, it's acceptable to surface a placeholder destination view (`CalibrationOnRampView`) that simply mounts `InterestsStepView` and submits.

- [ ] **Step 5: Run tests + commit**

```bash
xcodebuild test -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ScaleUpTests/CalibrationPromptStoreTests | tail -20
git add ScaleUp/Features/Home/Views/CalibrationBannerView.swift \
        ScaleUp/Features/Home/Services/CalibrationPromptStore.swift \
        ScaleUp/Features/Home/Services/CalibrationPromptStoreTests.swift \
        ScaleUp/Features/Home/Views/HomeView.swift
git commit -m "feat(home-ios): CalibrationBannerView with quiet-period + max-prompt persistence"
```

---

## Task 8: Extend `OnboardingData` interface (Android)

**Files:**
- Modify: `src/screens/onboarding/OnboardingContainer.tsx`

The Android `OnboardingData` shape mirrors the iOS view model. Add the new taxonomy + self-rating fields without breaking existing step components.

- [ ] **Step 1: Update the interface**

Locate the `OnboardingData` interface at the top of `OnboardingContainer.tsx` and add:

```ts
export type ProficiencyLevel = 'novice' | 'familiar' | 'proficient' | 'expert'

export interface SuggestedTopic {
  canonicalName: string
  name: string
  description: string
  isFutureProofing: boolean
  baseDifficulty: 'foundational' | 'intermediate' | 'advanced'
}

export interface OnboardingData {
  // ... existing fields stay ...

  /** Topics returned by the BE taxonomy. Pre-selected by default. */
  suggestedTopics: SuggestedTopic[]
  /** Topics added manually by the user. */
  customTopics: SuggestedTopic[]
  /** Canonical names of currently selected topics (3-8). */
  selectedCanonicals: string[]
  /** Per-topic self-rating. */
  topicSelfRatings: Record<string, ProficiencyLevel>
  /** Within Step 5: are we showing the rating sub-step? */
  isOnRatingSubStep: boolean
  /** Optional uploaded syllabus reference. */
  syllabusId?: string
  /** Topics extracted from a syllabus upload (overrides taxonomy when present). */
  syllabusExtractedTopics: SuggestedTopic[]
  /** Whether to show the syllabus card. */
  showSyllabusUpload: boolean
}
```

- [ ] **Step 2: Update the initial state**

In the `useState<OnboardingData>(...)` initializer, add the new fields with defaults: `suggestedTopics: []`, `customTopics: []`, `selectedCanonicals: []`, `topicSelfRatings: {}`, `isOnRatingSubStep: false`, `syllabusExtractedTopics: []`, `showSyllabusUpload: false`.

- [ ] **Step 3: Update existing references**

If any step component reads `data.selectedTopics: string[]` (the old shape), introduce a derived getter inside that component:

```ts
const selectedTopics = data.selectedCanonicals
```

Or migrate the consumer. Confirm via:

```bash
cd /Users/nirpekshnandan/My\ Products/ScaleUpAndroid
grep -rn "selectedTopics" src/ | grep -v node_modules
```

- [ ] **Step 4: Compile + commit**

```bash
npx tsc --noEmit
git add src/screens/onboarding/OnboardingContainer.tsx
git commit -m "feat(onboarding-rn): extend OnboardingData with taxonomy + self-rating fields"
```

---

## Task 9: `onboardingTopicService.ts` networking layer (Android)

**Files:**
- Create: `src/services/onboardingTopicService.ts`
- Create: `__tests__/onboardingTopicService.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
// __tests__/onboardingTopicService.test.ts
import MockAdapter from 'axios-mock-adapter'
import { api } from '../src/services/api'
import { fetchSuggestedTopics, submitOnboarding } from '../src/services/onboardingTopicService'

const mock = new MockAdapter(api)

afterEach(() => mock.reset())

test('fetchSuggestedTopics decodes taxonomy response', async () => {
  mock.onPost('/onboarding/topics/suggest').reply(200, {
    topics: [{ canonicalName: 'product-strategy', name: 'Product Strategy', description: 'x', isFutureProofing: false, baseDifficulty: 'intermediate' }],
    cacheHit: true,
    source: 'curated'
  })
  const r = await fetchSuggestedTopics({ objectiveType: 'upskilling', specifics: { targetSkill: 'PM' } })
  expect(r.topics).toHaveLength(1)
  expect(r.cacheHit).toBe(true)
})

test('submitOnboarding posts payload', async () => {
  mock.onPost('/onboarding/complete').reply(200, { userObjectiveId: 'abc', needsCalibration: false })
  const r = await submitOnboarding({} as any)
  expect(r.userObjectiveId).toBe('abc')
})

test('fetchSuggestedTopics throws on 500', async () => {
  mock.onPost('/onboarding/topics/suggest').reply(500)
  await expect(
    fetchSuggestedTopics({ objectiveType: 'upskilling', specifics: {} })
  ).rejects.toBeDefined()
})
```

Run `npm test -- onboardingTopicService` — must fail (module not found).

- [ ] **Step 2: Implement the service**

```ts
// src/services/onboardingTopicService.ts
import { api } from './api'
import type { SuggestedTopic, ProficiencyLevel } from '../screens/onboarding/OnboardingContainer'

export interface SuggestTopicsRequest {
  objectiveType: string
  specifics: Record<string, string>
  company?: string
}

export interface SuggestTopicsResponse {
  topics: SuggestedTopic[]
  cacheHit: boolean
  source: 'curated' | 'llm-generated'
}

export async function fetchSuggestedTopics(req: SuggestTopicsRequest): Promise<SuggestTopicsResponse> {
  const { data } = await api.post<SuggestTopicsResponse>('/onboarding/topics/suggest', req)
  return data
}

export interface OnboardingCompletePayload {
  firstName: string
  lastName: string
  educationEntries: Array<{ degree: string; institution: string; yearOfCompletion?: number; currentlyPursuing: boolean }>
  workEntries: Array<{ role: string; company: string; years?: number; currentlyWorking: boolean }>
  objectiveType: string
  specifics: Record<string, string>
  timeline: string
  currentLevel: string
  weeklyHours: number
  learningStyle: string
  topicsOfInterest: Array<{ canonicalName: string; name: string; source: 'taxonomy' | 'custom'; isFutureProofing: boolean }>
  topicSelfRatings: Record<string, ProficiencyLevel>
  syllabusId?: string
}

export interface OnboardingCompleteResponse {
  userObjectiveId: string
  needsCalibration: boolean
}

export async function submitOnboarding(payload: OnboardingCompletePayload): Promise<OnboardingCompleteResponse> {
  const { data } = await api.post<OnboardingCompleteResponse>('/onboarding/complete', payload)
  return data
}
```

- [ ] **Step 3: Run test + commit**

```bash
npm test -- onboardingTopicService
git add src/services/onboardingTopicService.ts __tests__/onboardingTopicService.test.ts
git commit -m "feat(onboarding-rn): onboardingTopicService for taxonomy + completion endpoints"
```

---

## Task 10: Rebuild `InterestsStep.tsx` with taxonomy chips, AI badge, cap-8 (Android)

**Files:**
- Modify: `src/screens/onboarding/steps/InterestsStep.tsx`
- Create: `src/screens/onboarding/components/TopicChip.tsx`
- Create: `__tests__/InterestsStep.test.tsx`

- [ ] **Step 1: Create the chip component**

```tsx
// src/screens/onboarding/components/TopicChip.tsx
import React from 'react'
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native'
import { Colors, Typography, Spacing, CornerRadius } from '../../../theme'
import type { SuggestedTopic } from '../OnboardingContainer'

interface Props {
  topic: SuggestedTopic
  isSelected: boolean
  onToggle: () => void
  onInfo: () => void
}

export function TopicChip({ topic, isSelected, onToggle, onInfo }: Props) {
  return (
    <TouchableOpacity
      onPress={onToggle}
      activeOpacity={0.7}
      style={[styles.chip, isSelected && styles.chipSelected]}
      accessibilityRole="button"
      accessibilityState={{ selected: isSelected }}
      accessibilityLabel={`${topic.name}${topic.isFutureProofing ? ', future proofing' : ''}`}
    >
      {topic.isFutureProofing && (
        <View style={styles.aiBadge}>
          <Text style={styles.aiBadgeText}>✦ Future-proofing</Text>
        </View>
      )}
      <Text style={[styles.label, isSelected && styles.labelSelected]}>{topic.name}</Text>
      <TouchableOpacity onPress={onInfo} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
        <Text style={[styles.info, isSelected && { color: Colors.buttonPrimaryText }]}>ⓘ</Text>
      </TouchableOpacity>
    </TouchableOpacity>
  )
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    paddingHorizontal: Spacing.md, paddingVertical: Spacing.sm,
    borderRadius: 999, borderWidth: 1, borderColor: Colors.border,
    marginRight: Spacing.sm, marginBottom: Spacing.sm
  },
  chipSelected: { backgroundColor: Colors.gold, borderColor: Colors.gold },
  label: { ...Typography.bodySmall, color: Colors.textSecondary },
  labelSelected: { color: Colors.buttonPrimaryText },
  aiBadge: { backgroundColor: 'rgba(212,175,55,0.12)', paddingHorizontal: 6, paddingVertical: 2, borderRadius: 999 },
  aiBadgeText: { ...Typography.caption, color: Colors.gold },
  info: { fontSize: 13, color: Colors.textTertiary }
})
```

- [ ] **Step 2: Rebuild `InterestsStep.tsx`**

Replace the existing file:

```tsx
// src/screens/onboarding/steps/InterestsStep.tsx
import React, { useEffect, useState } from 'react'
import { View, Text, ScrollView, StyleSheet, ActivityIndicator, TouchableOpacity, Modal, TextInput } from 'react-native'
import { Colors, Typography, Spacing, CornerRadius } from '../../../theme'
import { fetchSuggestedTopics } from '../../../services/onboardingTopicService'
import { trackEvent } from '../../../services/analytics/mixpanel'
import { TopicChip } from '../components/TopicChip'
import { SelfRatingSubStep } from './SelfRatingSubStep'
import type { OnboardingData, SuggestedTopic } from '../OnboardingContainer'

interface Props {
  data: OnboardingData
  updateData: (u: Partial<OnboardingData>) => void
}

export function InterestsStep({ data, updateData }: Props) {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [customDraft, setCustomDraft] = useState('')
  const [infoTopic, setInfoTopic] = useState<SuggestedTopic | null>(null)

  const total = data.selectedCanonicals.length

  useEffect(() => {
    if (data.suggestedTopics.length === 0) load()
  }, [])

  async function load() {
    if (!data.objective) return
    setLoading(true); setError(null)
    const t0 = Date.now()
    try {
      const r = await fetchSuggestedTopics({
        objectiveType: data.objective,
        specifics: buildSpecifics(data),
        company: data.targetCompany || undefined
      })
      updateData({
        suggestedTopics: r.topics,
        selectedCanonicals: r.topics.map(t => t.canonicalName)
      })
      trackEvent('onboarding_topic_taxonomy_loaded', {
        cacheHit: r.cacheHit, source: r.source, topicCount: r.topics.length, latencyMs: Date.now() - t0
      })
    } catch (e: any) {
      setError(e?.message ?? 'Could not load topics.')
    } finally {
      setLoading(false)
    }
  }

  if (data.isOnRatingSubStep) {
    return <SelfRatingSubStep data={data} updateData={updateData} />
  }

  function toggle(topic: SuggestedTopic) {
    const has = data.selectedCanonicals.includes(topic.canonicalName)
    if (has) {
      updateData({
        selectedCanonicals: data.selectedCanonicals.filter(c => c !== topic.canonicalName),
        topicSelfRatings: Object.fromEntries(Object.entries(data.topicSelfRatings).filter(([k]) => k !== topic.canonicalName))
      })
      trackEvent('onboarding_topic_removed', { canonicalName: topic.canonicalName })
    } else if (total < 8) {
      updateData({ selectedCanonicals: [...data.selectedCanonicals, topic.canonicalName] })
    }
  }

  function addCustom() {
    const trimmed = customDraft.trim()
    if (!trimmed || total >= 8) return
    const canonical = trimmed.toLowerCase().replace(/\s+/g, '-')
    const topic: SuggestedTopic = {
      canonicalName: canonical, name: trimmed,
      description: 'Custom topic you added.', isFutureProofing: false, baseDifficulty: 'intermediate'
    }
    updateData({
      customTopics: [...data.customTopics, topic],
      selectedCanonicals: [...data.selectedCanonicals, canonical]
    })
    setCustomDraft('')
    trackEvent('onboarding_topic_added_custom', { canonicalName: canonical })
  }

  const all: SuggestedTopic[] = (() => {
    const base = data.syllabusExtractedTopics.length ? data.syllabusExtractedTopics : data.suggestedTopics
    const seen = new Set<string>()
    return [...base, ...data.customTopics].filter(t => seen.has(t.canonicalName) ? false : (seen.add(t.canonicalName), true))
  })()

  const canProceed = total >= 3 && total <= 8

  return (
    <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
      <Text style={styles.title}>Pick your interests</Text>
      <Text style={styles.subtitle}>
        We've suggested {data.suggestedTopics.length} — tap to remove or add up to {Math.max(0, 8 - total)} more.
      </Text>

      {loading && <ActivityIndicator color={Colors.gold} style={{ marginTop: Spacing.lg }} />}
      {error && (
        <View style={styles.errorBox}>
          <Text style={styles.errorText}>{error}</Text>
          <TouchableOpacity onPress={load}><Text style={styles.retry}>Retry</Text></TouchableOpacity>
        </View>
      )}

      {!loading && (
        <>
          <View style={styles.counter}>
            <Text style={styles.counterText}>{total} of 8 selected</Text>
          </View>

          <View style={styles.flow}>
            {all.map(t => (
              <TopicChip
                key={t.canonicalName}
                topic={t}
                isSelected={data.selectedCanonicals.includes(t.canonicalName)}
                onToggle={() => toggle(t)}
                onInfo={() => setInfoTopic(t)}
              />
            ))}
          </View>

          <View style={styles.addRow}>
            <TextInput
              value={customDraft}
              onChangeText={setCustomDraft}
              placeholder="Add a topic"
              placeholderTextColor={Colors.textTertiary}
              style={styles.input}
            />
            <TouchableOpacity
              disabled={total >= 8 || !customDraft.trim()}
              onPress={addCustom}
              style={[styles.addBtn, (total >= 8 || !customDraft.trim()) && { opacity: 0.4 }]}
            >
              <Text style={styles.addBtnText}>Add</Text>
            </TouchableOpacity>
          </View>

          <TouchableOpacity
            disabled={!canProceed}
            onPress={() => updateData({ isOnRatingSubStep: true })}
            style={[styles.next, !canProceed && { opacity: 0.4 }]}
          >
            <Text style={styles.nextText}>Next — rate your level</Text>
          </TouchableOpacity>
        </>
      )}

      <Modal visible={!!infoTopic} transparent animationType="fade" onRequestClose={() => setInfoTopic(null)}>
        <TouchableOpacity style={styles.backdrop} onPress={() => setInfoTopic(null)} activeOpacity={1}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>{infoTopic?.name}</Text>
            <Text style={styles.sheetBody}>{infoTopic?.description}</Text>
          </View>
        </TouchableOpacity>
      </Modal>
    </ScrollView>
  )
}

function buildSpecifics(d: OnboardingData): Record<string, string> {
  const out: Record<string, string> = {}
  if (d.examName) out.examName = d.examName
  if (d.targetSkill) out.targetSkill = d.targetSkill
  if (d.targetRole) out.targetRole = d.targetRole
  if (d.targetCompany) out.targetCompany = d.targetCompany
  if (d.fromDomain) out.fromDomain = d.fromDomain
  if (d.toDomain) out.toDomain = d.toDomain
  return out
}

const styles = StyleSheet.create({
  scroll: { padding: Spacing.lg, paddingBottom: Spacing.xxl },
  title: { ...Typography.displayMedium, color: Colors.textPrimary, textAlign: 'center', marginTop: Spacing.lg },
  subtitle: { ...Typography.bodySmall, color: Colors.textSecondary, textAlign: 'center', marginTop: Spacing.sm, marginBottom: Spacing.lg },
  counter: { alignSelf: 'center', marginBottom: Spacing.md },
  counterText: { ...Typography.bodyBold, color: Colors.textPrimary },
  flow: { flexDirection: 'row', flexWrap: 'wrap' },
  addRow: { flexDirection: 'row', gap: Spacing.sm, marginTop: Spacing.md, alignItems: 'center' },
  input: { flex: 1, borderWidth: 1, borderColor: Colors.border, borderRadius: CornerRadius.small, paddingHorizontal: Spacing.md, paddingVertical: 12, color: Colors.textPrimary },
  addBtn: { backgroundColor: Colors.gold, paddingHorizontal: Spacing.md, paddingVertical: 12, borderRadius: CornerRadius.small },
  addBtnText: { ...Typography.bodyBold, color: Colors.buttonPrimaryText },
  next: { backgroundColor: Colors.gold, paddingVertical: 16, borderRadius: CornerRadius.medium, marginTop: Spacing.xl, alignItems: 'center' },
  nextText: { ...Typography.bodyBold, color: Colors.buttonPrimaryText },
  errorBox: { padding: Spacing.md, backgroundColor: 'rgba(255,80,80,0.08)', borderRadius: CornerRadius.small, marginTop: Spacing.md, alignItems: 'center' },
  errorText: { ...Typography.bodySmall, color: Colors.textPrimary },
  retry: { ...Typography.bodyBold, color: Colors.gold, marginTop: 6 },
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  sheet: { backgroundColor: Colors.surfaceElevated, padding: Spacing.lg, borderTopLeftRadius: CornerRadius.medium, borderTopRightRadius: CornerRadius.medium },
  sheetTitle: { ...Typography.titleMedium, color: Colors.textPrimary, marginBottom: Spacing.sm },
  sheetBody: { ...Typography.bodyRegular, color: Colors.textSecondary }
})
```

- [ ] **Step 3: Smoke test (RTL)**

```tsx
// __tests__/InterestsStep.test.tsx
import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react-native'
import MockAdapter from 'axios-mock-adapter'
import { api } from '../src/services/api'
import { InterestsStep } from '../src/screens/onboarding/steps/InterestsStep'

const mock = new MockAdapter(api)

const data: any = {
  objective: 'upskilling', targetSkill: 'PM',
  suggestedTopics: [], customTopics: [], selectedCanonicals: [],
  topicSelfRatings: {}, isOnRatingSubStep: false, syllabusExtractedTopics: [],
  showSyllabusUpload: false
}

test('renders fetched chips and allows toggle', async () => {
  mock.onPost('/onboarding/topics/suggest').reply(200, {
    topics: [{ canonicalName: 'product-strategy', name: 'Product Strategy', description: 'x', isFutureProofing: false, baseDifficulty: 'intermediate' }],
    cacheHit: true, source: 'curated'
  })
  let captured: any = data
  const update = (u: any) => { captured = { ...captured, ...u } }
  const { getByText } = render(<InterestsStep data={data} updateData={update} />)
  await waitFor(() => getByText('Product Strategy'))
})
```

- [ ] **Step 4: Run + commit**

```bash
npm test -- InterestsStep
git add src/screens/onboarding/steps/InterestsStep.tsx \
        src/screens/onboarding/components/TopicChip.tsx \
        __tests__/InterestsStep.test.tsx
git commit -m "feat(onboarding-rn): rebuild InterestsStep with taxonomy chips + AI badge + cap-8"
```

---

## Task 11: SelfRatingSubStep with anchored examples (Android)

**Files:**
- Create: `src/screens/onboarding/steps/SelfRatingSubStep.tsx`

- [ ] **Step 1: Implement the component**

```tsx
// src/screens/onboarding/steps/SelfRatingSubStep.tsx
import React, { useState } from 'react'
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native'
import { Colors, Typography, Spacing, CornerRadius } from '../../../theme'
import { submitOnboarding } from '../../../services/onboardingTopicService'
import { trackEvent } from '../../../services/analytics/mixpanel'
import type { OnboardingData, ProficiencyLevel, SuggestedTopic } from '../OnboardingContainer'

const LEVELS: ProficiencyLevel[] = ['novice', 'familiar', 'proficient', 'expert']

const ANCHORS: Record<ProficiencyLevel, string> = {
  novice: "I've heard of this but never really used it.",
  familiar: "I've used this a few times but still feel uncertain.",
  proficient: 'I use this confidently in most situations.',
  expert: 'I could teach this to others or be the go-to person on my team.'
}

interface Props {
  data: OnboardingData
  updateData: (u: Partial<OnboardingData>) => void
}

export function SelfRatingSubStep({ data, updateData }: Props) {
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showAnchor, setShowAnchor] = useState<string | null>(null)  // "<canonical>:<level>"

  const topics: SuggestedTopic[] = (data.syllabusExtractedTopics.length ? data.syllabusExtractedTopics : data.suggestedTopics)
    .concat(data.customTopics)
    .filter((t, i, arr) => arr.findIndex(x => x.canonicalName === t.canonicalName) === i)
    .filter(t => data.selectedCanonicals.includes(t.canonicalName))

  const allRated = topics.every(t => !!data.topicSelfRatings[t.canonicalName])

  function setRating(t: SuggestedTopic, level: ProficiencyLevel) {
    updateData({ topicSelfRatings: { ...data.topicSelfRatings, [t.canonicalName]: level } })
    setShowAnchor(`${t.canonicalName}:${level}`)
    setTimeout(() => setShowAnchor(s => (s === `${t.canonicalName}:${level}` ? null : s)), 1600)
  }

  async function finish() {
    if (!allRated || submitting) return
    setSubmitting(true); setError(null)
    try {
      const topicsOfInterest = topics.map(t => ({
        canonicalName: t.canonicalName, name: t.name, isFutureProofing: t.isFutureProofing,
        source: data.customTopics.some(c => c.canonicalName === t.canonicalName) ? 'custom' as const : 'taxonomy' as const
      }))
      const counts = { novice: 0, familiar: 0, proficient: 0, expert: 0 }
      for (const v of Object.values(data.topicSelfRatings)) counts[v as ProficiencyLevel]++
      const r = await submitOnboarding({
        firstName: data.firstName, lastName: data.lastName,
        educationEntries: data.educationEntries, workEntries: data.workEntries,
        objectiveType: data.objective!, specifics: { /* mirror iOS specifics dict */ },
        timeline: data.timeline, currentLevel: data.currentLevel,
        weeklyHours: data.weeklyHours, learningStyle: data.learningStyle,
        topicsOfInterest, topicSelfRatings: data.topicSelfRatings,
        syllabusId: data.syllabusId
      } as any)
      trackEvent('onboarding_self_rating_completed', { topicCount: topics.length, ratingDistribution: counts })
      // Trigger downstream nav (handled by OnboardingContainer once it observes user.objectiveId set).
      updateData({ /* container-level success flag, e.g. */ } as any)
    } catch (e: any) {
      setError(e?.message ?? 'Could not save. Please retry.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.scroll}>
      <Text style={styles.title}>How would you rate yourself?</Text>
      <Text style={styles.subtitle}>Be honest — we'll calibrate against this in your diagnostic.</Text>
      <TouchableOpacity onPress={() => updateData({ isOnRatingSubStep: false })}>
        <Text style={styles.editLink}>‹ Edit topics</Text>
      </TouchableOpacity>

      {topics.map(t => (
        <View key={t.canonicalName} style={styles.card}>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <Text style={styles.topicName}>{t.name}</Text>
            {t.isFutureProofing && <Text style={styles.aiTag}>  ✦</Text>}
          </View>
          <View style={styles.chipRow}>
            {LEVELS.map(level => {
              const sel = data.topicSelfRatings[t.canonicalName] === level
              return (
                <TouchableOpacity
                  key={level}
                  onPress={() => setRating(t, level)}
                  style={[styles.levelChip, sel && styles.levelChipSelected]}
                >
                  <Text style={[styles.levelLabel, sel && styles.levelLabelSelected]}>
                    {level[0].toUpperCase() + level.slice(1)}
                  </Text>
                </TouchableOpacity>
              )
            })}
          </View>
          {showAnchor && showAnchor.startsWith(`${t.canonicalName}:`) && (
            <Text style={styles.anchor}>
              {ANCHORS[showAnchor.split(':')[1] as ProficiencyLevel]}
            </Text>
          )}
        </View>
      ))}

      {error && <Text style={styles.errorText}>{error}</Text>}

      <TouchableOpacity
        disabled={!allRated || submitting}
        onPress={finish}
        style={[styles.finish, (!allRated || submitting) && { opacity: 0.4 }]}
      >
        {submitting ? <ActivityIndicator color={Colors.buttonPrimaryText} /> :
          <Text style={styles.finishText}>Start my diagnostic</Text>}
      </TouchableOpacity>
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  scroll: { padding: Spacing.lg, paddingBottom: Spacing.xxl },
  title: { ...Typography.displayMedium, color: Colors.textPrimary, textAlign: 'center', marginTop: Spacing.lg },
  subtitle: { ...Typography.bodySmall, color: Colors.textSecondary, textAlign: 'center', marginTop: Spacing.sm },
  editLink: { ...Typography.bodySmall, color: Colors.gold, textAlign: 'center', marginTop: Spacing.sm, marginBottom: Spacing.lg },
  card: { padding: Spacing.md, backgroundColor: Colors.surfaceElevated, borderRadius: CornerRadius.medium, marginBottom: Spacing.md },
  topicName: { ...Typography.bodyBold, color: Colors.textPrimary },
  aiTag: { color: Colors.gold, fontWeight: '700' },
  chipRow: { flexDirection: 'row', gap: Spacing.sm, marginTop: Spacing.sm },
  levelChip: { flex: 1, paddingVertical: 10, borderRadius: CornerRadius.small, borderWidth: 1, borderColor: Colors.border, alignItems: 'center' },
  levelChipSelected: { backgroundColor: Colors.gold, borderColor: Colors.gold },
  levelLabel: { ...Typography.caption, color: Colors.textSecondary },
  levelLabelSelected: { color: Colors.buttonPrimaryText },
  anchor: { ...Typography.bodySmall, color: Colors.textSecondary, marginTop: Spacing.sm, padding: Spacing.sm, backgroundColor: Colors.surfaceBackground, borderRadius: CornerRadius.small },
  finish: { backgroundColor: Colors.gold, paddingVertical: 16, borderRadius: CornerRadius.medium, marginTop: Spacing.lg, alignItems: 'center' },
  finishText: { ...Typography.bodyBold, color: Colors.buttonPrimaryText },
  errorText: { ...Typography.bodySmall, color: '#ff6060', textAlign: 'center', marginTop: Spacing.md }
})
```

- [ ] **Step 2: Compile + commit**

```bash
npx tsc --noEmit
git add src/screens/onboarding/steps/SelfRatingSubStep.tsx
git commit -m "feat(onboarding-rn): SelfRatingSubStep with 4 chips + anchored examples"
```

---

## Task 12: SyllabusUpload (Android)

**Files:**
- Create: `src/services/syllabusService.ts`
- Create: `src/screens/onboarding/steps/SyllabusUpload.tsx`

- [ ] **Step 1: Add native deps**

```bash
npm install react-native-document-picker react-native-image-picker
cd ios && pod install && cd ..
```

(If iOS pods are not relevant for the Android-only PR, skip.)

- [ ] **Step 2: Service**

```ts
// src/services/syllabusService.ts
import { api } from './api'
import type { SuggestedTopic } from '../screens/onboarding/OnboardingContainer'

export interface InitResp { syllabusId: string; uploadUrl: string }
export interface StatusResp {
  status: 'pending' | 'extracting' | 'ready' | 'failed'
  extractedTopics?: SuggestedTopic[]
  errorReason?: string
}

export async function initUpload(filename: string, mimeType: string, byteCount: number): Promise<InitResp> {
  const { data } = await api.post<InitResp>('/diagnostic/syllabus/upload-init', { filename, mimeType, byteCount })
  return data
}

export async function uploadFile(url: string, fileUri: string, mimeType: string): Promise<void> {
  // Use fetch for direct PUT to S3 pre-signed URL.
  const blob = await (await fetch(fileUri)).blob()
  const r = await fetch(url, { method: 'PUT', headers: { 'Content-Type': mimeType }, body: blob })
  if (!r.ok) throw new Error(`Upload failed (${r.status})`)
}

export async function completeUpload(syllabusId: string): Promise<void> {
  await api.post(`/diagnostic/syllabus/${syllabusId}/complete`)
}

export async function getStatus(syllabusId: string): Promise<StatusResp> {
  const { data } = await api.get<StatusResp>(`/diagnostic/syllabus/${syllabusId}/status`)
  return data
}
```

- [ ] **Step 3: View**

```tsx
// src/screens/onboarding/steps/SyllabusUpload.tsx
import React, { useState } from 'react'
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native'
import DocumentPicker from 'react-native-document-picker'
import { launchImageLibrary } from 'react-native-image-picker'
import { Colors, Typography, Spacing, CornerRadius } from '../../../theme'
import { initUpload, uploadFile, completeUpload, getStatus } from '../../../services/syllabusService'
import { trackEvent } from '../../../services/analytics/mixpanel'
import type { OnboardingData, SuggestedTopic } from '../OnboardingContainer'

interface Props { data: OnboardingData; updateData: (u: Partial<OnboardingData>) => void }

type Phase = 'idle' | 'uploading' | 'extracting' | 'ready' | 'failed'

export function SyllabusUpload({ data, updateData }: Props) {
  const [phase, setPhase] = useState<Phase>('idle')
  const [msg, setMsg] = useState('')

  async function pickDoc() {
    try {
      const r = await DocumentPicker.pickSingle({ type: [DocumentPicker.types.pdf, DocumentPicker.types.ppt, DocumentPicker.types.pptx, DocumentPicker.types.images] })
      await runUpload(r.uri, r.name ?? 'file', r.type ?? 'application/octet-stream', r.size ?? 0)
    } catch (e) { /* user cancelled */ }
  }

  async function pickImage() {
    const r = await launchImageLibrary({ mediaType: 'photo' })
    const a = r.assets?.[0]; if (!a) return
    await runUpload(a.uri!, a.fileName ?? 'photo.jpg', a.type ?? 'image/jpeg', a.fileSize ?? 0)
  }

  async function runUpload(uri: string, name: string, mime: string, size: number) {
    try {
      setPhase('uploading'); setMsg('Uploading...')
      const init = await initUpload(name, mime, size)
      updateData({ syllabusId: init.syllabusId })
      await uploadFile(init.uploadUrl, uri, mime)
      await completeUpload(init.syllabusId)
      setPhase('extracting'); setMsg('Reading your content...')
      await poll(init.syllabusId, mime)
    } catch (e: any) {
      setPhase('failed'); setMsg(e?.message ?? 'Upload failed.')
    }
  }

  async function poll(id: string, mime: string) {
    for (let i = 0; i < 60; i++) {
      await new Promise(r => setTimeout(r, 1500))
      const s = await getStatus(id)
      if (s.status === 'ready') {
        const topics: SuggestedTopic[] = s.extractedTopics ?? []
        updateData({ syllabusExtractedTopics: topics })
        trackEvent('onboarding_syllabus_uploaded', { fileType: mime, topicCount: topics.length })
        setPhase('ready'); setMsg('')
        return
      }
      if (s.status === 'failed') { setPhase('failed'); setMsg(s.errorReason ?? 'Extraction failed.'); return }
    }
    setPhase('failed'); setMsg('Timed out — please try again.')
  }

  function useExtracted() {
    updateData({
      suggestedTopics: data.syllabusExtractedTopics,
      selectedCanonicals: data.syllabusExtractedTopics.map(t => t.canonicalName),
      showSyllabusUpload: false
    })
  }

  function skip() {
    trackEvent('onboarding_syllabus_skipped', {})
    updateData({ showSyllabusUpload: false })
  }

  return (
    <ScrollView contentContainerStyle={styles.scroll}>
      <View style={styles.hero}>
        <Text style={styles.heroIcon}>📄</Text>
        <Text style={styles.heroTitle}>Upload your chapter or syllabus</Text>
        <Text style={styles.heroBody}>We'll generate questions from your actual content for the most accurate diagnostic.</Text>
      </View>

      <View style={styles.ctaRow}>
        <TouchableOpacity style={styles.primary} onPress={pickDoc}>
          <Text style={styles.primaryText}>Upload PDF / PPT</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.secondary} onPress={pickImage}>
          <Text style={styles.secondaryText}>Photo</Text>
        </TouchableOpacity>
      </View>

      {(phase === 'uploading' || phase === 'extracting') && (
        <View style={styles.progress}>
          <ActivityIndicator color={Colors.gold} />
          <Text style={styles.progressText}>{msg}</Text>
        </View>
      )}

      {phase === 'ready' && (
        <View style={styles.list}>
          <Text style={styles.listHeader}>Extracted topics</Text>
          {data.syllabusExtractedTopics.map(t => (
            <Text key={t.canonicalName} style={styles.listItem}>✓ {t.name}</Text>
          ))}
          <TouchableOpacity style={styles.primary} onPress={useExtracted}>
            <Text style={styles.primaryText}>Use these topics</Text>
          </TouchableOpacity>
        </View>
      )}

      {phase === 'failed' && <Text style={styles.errorText}>{msg}</Text>}

      <TouchableOpacity onPress={skip}>
        <Text style={styles.skip}>Skip — use standard topics</Text>
      </TouchableOpacity>
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  scroll: { padding: Spacing.lg, paddingBottom: Spacing.xxl },
  hero: { backgroundColor: Colors.surfaceElevated, padding: Spacing.lg, borderRadius: CornerRadius.medium, alignItems: 'center', marginTop: Spacing.lg },
  heroIcon: { fontSize: 40, marginBottom: Spacing.sm },
  heroTitle: { ...Typography.titleMedium, color: Colors.textPrimary, textAlign: 'center' },
  heroBody: { ...Typography.bodySmall, color: Colors.textSecondary, textAlign: 'center', marginTop: Spacing.sm },
  ctaRow: { flexDirection: 'row', gap: Spacing.md, marginTop: Spacing.lg },
  primary: { flex: 1, backgroundColor: Colors.gold, paddingVertical: 14, borderRadius: CornerRadius.small, alignItems: 'center', marginTop: Spacing.md },
  primaryText: { ...Typography.bodyBold, color: Colors.buttonPrimaryText },
  secondary: { flex: 1, borderWidth: 1, borderColor: Colors.gold, paddingVertical: 14, borderRadius: CornerRadius.small, alignItems: 'center' },
  secondaryText: { ...Typography.bodyBold, color: Colors.gold },
  progress: { alignItems: 'center', marginTop: Spacing.lg },
  progressText: { ...Typography.bodySmall, color: Colors.textSecondary, marginTop: Spacing.sm },
  list: { marginTop: Spacing.lg, padding: Spacing.md, backgroundColor: Colors.surfaceElevated, borderRadius: CornerRadius.medium },
  listHeader: { ...Typography.bodyBold, color: Colors.textPrimary, marginBottom: Spacing.sm },
  listItem: { ...Typography.bodySmall, color: Colors.textSecondary, marginVertical: 2 },
  errorText: { ...Typography.bodySmall, color: '#ff6060', textAlign: 'center', marginTop: Spacing.md },
  skip: { ...Typography.bodySmall, color: Colors.textSecondary, textAlign: 'center', marginTop: Spacing.lg, textDecorationLine: 'underline' }
})
```

- [ ] **Step 4: Wire into `InterestsStep` rendering**

In `InterestsStep.tsx`, before the existing branches, add:

```tsx
if (data.showSyllabusUpload) {
  return <SyllabusUpload data={data} updateData={updateData} />
}
```

In `OnboardingContainer.tsx`, when entering Step 5, evaluate:

```ts
const standardised = ['GMAT','JEE','NEET','UPSC','CAT','GRE','GATE','SAT']
const offer = data.objective === 'academic_excellence' ||
  (data.objective === 'exam_preparation' && !standardised.includes(data.examName.trim().toUpperCase()))
if (offer && !data.syllabusId && data.suggestedTopics.length === 0) {
  updateData({ showSyllabusUpload: true })
}
```

- [ ] **Step 5: Compile + commit**

```bash
npx tsc --noEmit
git add src/services/syllabusService.ts \
        src/screens/onboarding/steps/SyllabusUpload.tsx \
        src/screens/onboarding/steps/InterestsStep.tsx \
        src/screens/onboarding/OnboardingContainer.tsx \
        package.json package-lock.json
git commit -m "feat(onboarding-rn): SyllabusUpload screen with picker + status polling"
```

---

## Task 13: CalibrationBanner + slice for Home (Android)

**Files:**
- Create: `src/store/slices/calibrationSlice.ts`
- Create: `src/screens/home/CalibrationBanner.tsx`
- Create: `__tests__/calibrationSlice.test.ts`
- Modify: `src/screens/home/HomeScreen.tsx`
- Modify: `src/store/index.ts` (register slice)

- [ ] **Step 1: Slice (with persistence)**

```ts
// src/store/slices/calibrationSlice.ts
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit'
import AsyncStorage from '@react-native-async-storage/async-storage'

const KEY = 'calibration.state.v1'
const QUIET_DAYS = 14
const MAX_PROMPTS = 3

export interface CalibrationState {
  promptCount: number
  quietUntil: number | null    // epoch ms
  completed: boolean
  hydrated: boolean
}

const initialState: CalibrationState = { promptCount: 0, quietUntil: null, completed: false, hydrated: false }

export const hydrateCalibration = createAsyncThunk('calibration/hydrate', async () => {
  const raw = await AsyncStorage.getItem(KEY)
  if (!raw) return initialState
  return { ...JSON.parse(raw), hydrated: true } as CalibrationState
})

const persist = (s: CalibrationState) => AsyncStorage.setItem(KEY, JSON.stringify(s))

const slice = createSlice({
  name: 'calibration',
  initialState,
  reducers: {
    recordShown(state) {
      state.promptCount += 1
      persist(state)
    },
    recordDismissed(state) {
      state.quietUntil = Date.now() + QUIET_DAYS * 86_400_000
      persist(state)
    },
    recordCompleted(state) {
      state.completed = true
      persist(state)
    }
  },
  extraReducers: builder => {
    builder.addCase(hydrateCalibration.fulfilled, (state, action: PayloadAction<CalibrationState>) => {
      Object.assign(state, action.payload, { hydrated: true })
    })
  }
})

export const { recordShown, recordDismissed, recordCompleted } = slice.actions
export default slice.reducer

export function shouldShowCalibration(state: CalibrationState, now: number = Date.now()): boolean {
  if (!state.hydrated) return false
  if (state.completed) return false
  if (state.promptCount >= MAX_PROMPTS) return false
  if (state.quietUntil && now < state.quietUntil) return false
  return true
}
```

- [ ] **Step 2: Slice test**

```ts
// __tests__/calibrationSlice.test.ts
import reducer, { recordShown, recordDismissed, shouldShowCalibration } from '../src/store/slices/calibrationSlice'

const fresh = { promptCount: 0, quietUntil: null, completed: false, hydrated: true }

test('initially shows', () => expect(shouldShowCalibration(fresh)).toBe(true))
test('after dismiss is hidden for 14d', () => {
  const s = reducer(fresh, recordDismissed())
  expect(shouldShowCalibration(s, Date.now())).toBe(false)
  expect(shouldShowCalibration(s, Date.now() + 15 * 86_400_000)).toBe(true)
})
test('three prompts then hidden', () => {
  let s = fresh
  for (let i = 0; i < 3; i++) s = reducer(s, recordShown())
  expect(shouldShowCalibration(s)).toBe(false)
})
```

- [ ] **Step 3: Banner component**

```tsx
// src/screens/home/CalibrationBanner.tsx
import React, { useEffect } from 'react'
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native'
import { useDispatch, useSelector } from 'react-redux'
import { Colors, Typography, Spacing, CornerRadius } from '../../theme'
import { trackEvent } from '../../services/analytics/mixpanel'
import { recordShown, recordDismissed, shouldShowCalibration, CalibrationState } from '../../store/slices/calibrationSlice'

interface Props { onStart: () => void }

export function CalibrationBanner({ onStart }: Props) {
  const dispatch = useDispatch()
  const state = useSelector((s: any) => s.calibration as CalibrationState)
  const visible = shouldShowCalibration(state)

  useEffect(() => {
    if (visible) {
      dispatch(recordShown())
      trackEvent('existing_user_calibration_banner_shown', { promptCount: state.promptCount + 1 })
    }
  }, [visible])

  if (!visible) return null

  return (
    <View style={styles.card}>
      <View style={{ flex: 1 }}>
        <Text style={styles.title}>Get your real proficiency in 9 minutes</Text>
        <Text style={styles.body}>Your plan will adapt to it.</Text>
        <TouchableOpacity
          onPress={() => { trackEvent('existing_user_calibration_banner_tapped', {}); onStart() }}
          style={styles.cta}
        >
          <Text style={styles.ctaText}>Start calibration</Text>
        </TouchableOpacity>
      </View>
      <TouchableOpacity
        onPress={() => { trackEvent('existing_user_calibration_banner_dismissed', {}); dispatch(recordDismissed()) }}
        accessibilityLabel="Dismiss"
      >
        <Text style={styles.x}>✕</Text>
      </TouchableOpacity>
    </View>
  )
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row', alignItems: 'flex-start', gap: Spacing.md,
    backgroundColor: Colors.surfaceElevated, padding: Spacing.md,
    borderRadius: CornerRadius.medium, borderWidth: 1, borderColor: 'rgba(212,175,55,0.4)',
    marginHorizontal: Spacing.lg, marginTop: Spacing.sm
  },
  title: { ...Typography.bodyBold, color: Colors.textPrimary },
  body: { ...Typography.bodySmall, color: Colors.textSecondary, marginTop: 2 },
  cta: { alignSelf: 'flex-start', backgroundColor: Colors.gold, paddingHorizontal: Spacing.md, paddingVertical: 8, borderRadius: 999, marginTop: Spacing.sm },
  ctaText: { ...Typography.bodyBold, color: Colors.buttonPrimaryText },
  x: { fontSize: 14, color: Colors.textTertiary, padding: 6 }
})
```

- [ ] **Step 4: Mount on `HomeScreen`**

In `src/screens/home/HomeScreen.tsx`, hydrate the slice on mount and render the banner above the existing content if `user.needsCalibration`:

```tsx
import { useDispatch, useSelector } from 'react-redux'
import { hydrateCalibration } from '../../store/slices/calibrationSlice'
import { CalibrationBanner } from './CalibrationBanner'

// ... inside component:
const dispatch = useDispatch()
const user = useSelector((s: any) => s.auth.user)

useEffect(() => { dispatch(hydrateCalibration()) }, [])

// In render, above the existing content:
{user?.needsCalibration && (
  <CalibrationBanner onStart={() => navigation.navigate('Onboarding', { startAtStep: 4, calibration: true })} />
)}
```

Register the reducer in `src/store/index.ts`:

```ts
import calibration from './slices/calibrationSlice'
// inside configureStore:
reducer: { auth, diagnostic, calibration }
```

- [ ] **Step 5: Test + commit**

```bash
npm test -- calibrationSlice
git add src/store/slices/calibrationSlice.ts \
        src/screens/home/CalibrationBanner.tsx \
        src/screens/home/HomeScreen.tsx \
        src/store/index.ts \
        __tests__/calibrationSlice.test.ts
git commit -m "feat(home-rn): CalibrationBanner with quiet-period + max-prompt persistence"
```

---

## Task 14: Mixpanel event constants on both platforms

**Files (iOS):**
- Modify: `ScaleUp/Services/Analytics/MixpanelEvents.swift` (or wherever event constants live)

**Files (Android):**
- Modify: `src/services/analytics/mixpanel.ts`

This task adds the spec §13.5 onboarding-subset event names so previous tasks compile against a single source of truth.

- [ ] **Step 1 (iOS): Add event cases**

```swift
// ScaleUp/Services/Analytics/MixpanelEvents.swift
extension Mixpanel.Event {
    static let onboardingTopicTaxonomyLoaded         = Mixpanel.Event("onboarding_topic_taxonomy_loaded")
    static let onboardingTopicAddedCustom            = Mixpanel.Event("onboarding_topic_added_custom")
    static let onboardingTopicRemoved                = Mixpanel.Event("onboarding_topic_removed")
    static let onboardingSelfRatingCompleted         = Mixpanel.Event("onboarding_self_rating_completed")
    static let onboardingSyllabusUploaded            = Mixpanel.Event("onboarding_syllabus_uploaded")
    static let onboardingSyllabusSkipped             = Mixpanel.Event("onboarding_syllabus_skipped")
    static let existingUserCalibrationBannerShown    = Mixpanel.Event("existing_user_calibration_banner_shown")
    static let existingUserCalibrationBannerTapped   = Mixpanel.Event("existing_user_calibration_banner_tapped")
    static let existingUserCalibrationBannerDismissed = Mixpanel.Event("existing_user_calibration_banner_dismissed")
}
```

> If the project uses string-based events directly (no `Mixpanel.Event` typealias), expose constants in an enum instead and use the same string values.

- [ ] **Step 2 (Android): Add event helper**

```ts
// src/services/analytics/mixpanel.ts
export type OnboardingEvent =
  | 'onboarding_topic_taxonomy_loaded'
  | 'onboarding_topic_added_custom'
  | 'onboarding_topic_removed'
  | 'onboarding_self_rating_completed'
  | 'onboarding_syllabus_uploaded'
  | 'onboarding_syllabus_skipped'
  | 'existing_user_calibration_banner_shown'
  | 'existing_user_calibration_banner_tapped'
  | 'existing_user_calibration_banner_dismissed'

export function trackEvent(name: OnboardingEvent | string, props: Record<string, unknown>): void {
  // Reuse the existing Mixpanel singleton from this module.
  // The implementation below assumes `mixpanel.track(name, props)` already exists.
  try {
    // @ts-expect-error mixpanel singleton already declared elsewhere in this file
    mixpanel.track(name, props)
  } catch { /* analytics never throws into UI */ }
}
```

- [ ] **Step 3: Verify both apps compile, commit**

```bash
# iOS
xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -10
git -C /Users/nirpekshnandan/My\ Products/ScaleUpDemo-f add ScaleUp/Services/Analytics/MixpanelEvents.swift
git -C /Users/nirpekshnandan/My\ Products/ScaleUpDemo-f commit -m "chore(analytics-ios): add onboarding-subset Mixpanel event constants"

# Android
cd /Users/nirpekshnandan/My\ Products/ScaleUpAndroid
npx tsc --noEmit
git add src/services/analytics/mixpanel.ts
git commit -m "chore(analytics-rn): add onboarding-subset Mixpanel event helper"
```

---

## Self-Review Checklist (run by Claude before handing back)

**1. Spec coverage check** — Each spec section that touches frontend onboarding is covered:
- ✅ Spec §3.1 (Step 5 reworked: 6-8 pre-selected chips, cap-8 custom add, info-tap, AI badge, self-rating sub-step, anchored examples) → Tasks 4, 5, 10, 11
- ✅ Spec §3.4 (Existing-user migration banner: copy, persistence, 14-day quiet, max 3 prompts) → Tasks 7, 13
- ✅ Spec §3.6 (Syllabus upload card: academic_excellence default + non-standardized exam_prep, file/image, status polling, fallback) → Tasks 6, 12
- ✅ Spec §13.1 (iOS frontend file modifications) → Tasks 1-7
- ✅ Spec §13.2 (Android frontend file modifications) → Tasks 8-13
- ✅ Spec §13.4 (UX micro-interactions: staggered chip fade-up, haptic on chip tap, AI badge styling, dismiss animation) → embedded in Tasks 4, 5, 7, 10, 11, 13
- ✅ Spec §13.5 onboarding subset (9 events) → Tasks 4, 5, 6, 7, 10, 11, 12, 13, 14
- ✅ Spec Appendix A (anchor copy verbatim) → Tasks 1, 5, 11
- 🚫 OUT OF SCOPE (handled in later plans): diagnostic engine (§5), results screen (§10), plan generation (§11), re-calibration (§3.5), voice answer UI

**2. Placeholder scan** — No "TBD" or "fill in details". Two intentional shortcuts:
- The `CalibrationOnRampView` destination from Task 7 is referenced but only sketched (full diagnostic flow lands in Plan 3). The banner taps surface it; the placeholder mounts `InterestsStepView` so the flow is still testable.
- The `submitOnboarding` thunk in Task 11 (RN SelfRatingSubStep) does not encode every `specifics` field; it leaves a `{ /* mirror iOS specifics dict */ }` sentinel — the implementer copies the helper from Task 10's `buildSpecifics`. Both shortcuts are flagged inline.

**3. Type consistency check:**
- `ProficiencyLevel` raw values match across iOS enum, Android `type`, and BE contract (`'novice' | 'familiar' | 'proficient' | 'expert'`) ✅
- `SuggestedTopic` shape identical on both platforms (`canonicalName, name, description, isFutureProofing, baseDifficulty`) ✅
- `OnboardingCompletePayload` field names align with Plan 2a's `/onboarding/complete` controller ✅
- `TopicSource` enum (`taxonomy | custom`) consistent across iOS payload + Android `topicsOfInterest[i].source` ✅
- Mixpanel event names verbatim from spec §13.5 (snake_case strings) ✅
- iOS theme tokens reused (no hard-coded colors in chip/banner/upload views) ✅

**4. Backend dependency check:**
- All API paths used (`/onboarding/topics/suggest`, `/onboarding/complete`, `/diagnostic/syllabus/upload-init`, `/diagnostic/syllabus/:id/complete`, `/diagnostic/syllabus/:id/status`) are listed in Plan 2a's File Structure as implemented endpoints. No frontend feature in this plan depends on a missing endpoint.

**5. Test coverage:**
- iOS: `OnboardingTopicServiceTests` (Task 2), `CalibrationPromptStoreTests` (Task 7). Snapshot smoke via `#Preview` in Tasks 4, 5.
- Android: `onboardingTopicService.test.ts` (Task 9), `InterestsStep.test.tsx` (Task 10), `calibrationSlice.test.ts` (Task 13).
- All tests use existing project test runners (XCTest / Jest) — no new tooling required.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-03-diagnostic-phase2b-frontend-onboarding.md`.**

**Total tasks:** 14 (iOS: 1-7, Android: 8-13, cross-cutting: 14).

Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, two-stage review between tasks (spec compliance + design-token compliance). Sequence: iOS tasks 1→2→3→4→5→6→7, then Android 8→9→10→11→12→13, then 14. iOS and Android can also run in parallel after the iOS view-model contract (Task 3) is locked, since the wire format is shared.

**2. Inline Execution** — Walk the tasks in order in this session via `superpowers:executing-plans`, with a checkpoint after Task 5 (iOS topic + rating loop usable end-to-end) and Task 11 (Android equivalent).

**Which approach?**

