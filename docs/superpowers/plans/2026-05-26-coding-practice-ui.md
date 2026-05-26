# ScaleUp Coding Practice — UI Implementation Plan (iOS + Android)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [`docs/superpowers/specs/2026-05-26-coding-practice-design.md`](../specs/2026-05-26-coding-practice-design.md)
**Predecessor plan:** [`docs/superpowers/plans/2026-05-26-coding-practice.md`](2026-05-26-coding-practice.md) — backend already executed (T1–T30, T44–T45, full WS4) and live in production.

**Goal:** Ship the mobile UI (iOS first to TestFlight, then Android to Internal Track) that lets a learner discover and complete coding drills — Prompt, Verify, Decompose — backed by the already-deployed `/api/coding/*` endpoints and 30 seed bundles.

**Architecture:**
- **iOS:** SwiftUI bottom-sheet modal launched from Home, V2 design system tokens, OpenAPI types regenerated from backend `openapi.yaml`. New module: `ScaleUp/Features/Coding/`.
- **Android:** React Native full-screen modal screen launched from Home, V1-equivalent design (Android stays on V1 for now). New module: `src/features/coding/`.
- **Sequential delivery:** iOS first (V2 already shipped, momentum). Validate with ~1 week of TestFlight feedback. Then Android port.

**Tech stack:**
- iOS: SwiftUI 6, Swift 6.0, Xcode 16, Nuke for image loading, Mixpanel for analytics, generated OpenAPI types
- Android: React Native 0.84.1, TypeScript 5.8, Redux Toolkit 2.11, openapi-typescript regen, Mixpanel React Native SDK

**Locked CTO decisions (from brainstorm session 2026-05-26):**
1. iOS first, Android second (sequential, not parallel)
2. iOS: bottom-sheet drill modal · Android: full-screen modal screen
3. Verify Drill UX: file + line + explanation row inputs (not in-line code tapping)
4. **Refactor drill HIDDEN in Phase A** — no laptop UI yet. Backend filters to 3 subtypes.
5. Calibration sequence: 3 drills × ~2 min each = ~6 min total (not 4 × 2 = 8)
6. Home tab card: secondary card below V2 hero (does NOT replace hero)
7. Sync grading with inline loader (~8 sec) — no push notification flow
8. Result screen depth: score + rubric + "what to try next" + "what you missed" educational reveal

---

## Plan structure

| Workstream | Tasks | Repo |
|---|---|---|
| **A — Backend prep** | UI-A1, UI-A2 | `scaleup-backend` |
| **B — iOS UI** | UI-B1 to UI-B9 | `ScaleUpDemo-f` |
| **C — Android UI** | UI-C1 to UI-C5 | `ScaleUpAndroid` |
| **D — QA + release** | UI-D1 to UI-D3 | All repos |

**Total: 19 tasks.** Estimated single-developer effort: ~3 focused days for iOS, ~2 days for Android.

---

## Conventions

- **Branching:** create `feat/coding-practice-ui-ios` in `ScaleUpDemo-f`, `feat/coding-practice-ui-android` in `ScaleUpAndroid`. Backend changes (Workstream A) can go on a small branch in `scaleup-backend` then merge to master before iOS work starts.
- **OpenAPI first:** any backend change updates `openapi.yaml` first, then both mobile clients regen.
- **Test framework:** iOS uses XCTest. Android uses Jest. Backend uses `node:test` (as established).
- **Commit style:** `<type>(<scope>): <subject>` per existing repo conventions.
- **iOS xcodegen gotcha:** always use the full Homebrew path (`/opt/homebrew/bin/xcodegen` on Apple Silicon, `/usr/local/bin/xcodegen` on Intel) — stale shell alias causes the bundle version not to apply, breaking TestFlight upload.
- **Each task ends with a commit.** Frequent commits, scoped per task.

---

## Workstream A — Backend prep (2 tasks)

These small backend changes make the mobile UX work for Phase A (without the Phase B web IDE).

### Task UI-A1: Filter `refactor` drills from Phase A selection

**Files to modify:**
- `scaleup-backend/src/coding/services/planIntegration.js`
- `scaleup-backend/src/coding/services/roleTrackMapper.js` (extend with phase filter)
- `scaleup-backend/src/coding/controllers/drills.controller.js` (`getToday` should also filter)

**Tests to update / add:**
- `scaleup-backend/src/test/coding/planIntegration.test.js`
- `scaleup-backend/src/test/coding/drills.api.test.js`

**TDD steps:**

- [ ] **Step 1: Add a feature constant for Phase A subtypes**

In `src/coding/services/roleTrackMapper.js`, add at the top:

```javascript
// Phase A ships drills without the web IDE for refactor; refactor drills
// require a laptop and the Phase B web IDE. Until then, mobile selects only
// from these three subtypes. Remove this constant when Phase B web IDE
// lands and refactor drills become servable.
const PHASE_A_DRILL_SUBTYPES = ['prompt', 'verify', 'decompose'];
```

Export it:

```javascript
module.exports = {
  mapObjectiveToRoleTrack,
  pickWeakestAxis,
  axisToSubtype,
  subtypeToAxis,
  OBJECTIVE_TO_TRACK,
  PHASE_A_DRILL_SUBTYPES, // <- new
};
```

- [ ] **Step 2: Update `pickWeakestAxis` to constrain to Phase A axes**

The axes correspond 1:1 to subtypes. Mastery axis `refactoring` corresponds to subtype `refactor` which is filtered out. Constrain the weakest-axis pick to the 3 valid axes:

```javascript
const PHASE_A_AXES = ['prompting', 'verification', 'decomposition'];

function pickWeakestAxis(mastery) {
  if (!mastery || !mastery.axes) return 'prompting';
  const axes = mastery.axes;
  let minName = 'prompting';
  let minVal = axes.prompting;
  for (const k of PHASE_A_AXES) {
    if (axes[k] < minVal) { minVal = axes[k]; minName = k; }
  }
  return minName;
}
```

- [ ] **Step 3: Update `getDrillCandidate` in planIntegration to filter ArtifactBundle query**

Locate the `ArtifactBundle.findOne` call and add the subtype filter:

```javascript
const bundle = await ArtifactBundle.findOne({
  type: 'drill',
  role_track,
  difficulty,
  drill_subtype: { $in: PHASE_A_DRILL_SUBTYPES }, // <- new
  status: 'active',
}).sort({ createdAt: -1 }).lean();
```

Also update the fallback query and the `ArtifactBundle.exists` precondition in `shouldOfferDrillToday` to use the same filter.

Import `PHASE_A_DRILL_SUBTYPES` from `./roleTrackMapper`.

- [ ] **Step 4: Same filter in `drills.controller.js`'s `getToday`**

In `getToday`, locate the `ArtifactBundle.findOne` and add the subtype filter identically. Import `PHASE_A_DRILL_SUBTYPES`.

- [ ] **Step 5: Add test cases**

In `planIntegration.test.js`, add:

```javascript
test('shouldOfferDrillToday — only checks for non-refactor bundles', async () => {
  // ... setup user with coding objective + no attempts today
  ArtifactBundle.exists = async (q) => {
    // Verify query includes drill_subtype $in filter excluding 'refactor'
    assert.ok(q.drill_subtype && q.drill_subtype.$in, 'expected $in filter');
    assert.ok(!q.drill_subtype.$in.includes('refactor'), 'refactor should be filtered');
    return true;
  };
  const ok = await shouldOfferDrillToday(userId);
  assert.equal(ok, true);
});

test('pickWeakestAxis — never returns refactoring even if it is weakest', () => {
  const mastery = { axes: { prompting: 80, verification: 60, decomposition: 70, refactoring: 30 } };
  const weakest = pickWeakestAxis(mastery);
  assert.notEqual(weakest, 'refactoring');
  assert.equal(weakest, 'verification'); // weakest among the 3 allowed
});
```

In `drills.api.test.js`, add a similar test that verifies `getToday` never returns a refactor bundle even if the picker would otherwise pick it.

- [ ] **Step 6: Run + commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
OPENAI_API_KEY=stub node --test src/test/coding/planIntegration.test.js src/test/coding/drills.api.test.js src/test/coding/roleTrackMapper.test.js
git add src/coding/services/planIntegration.js src/coding/services/roleTrackMapper.js src/coding/controllers/drills.controller.js src/test/coding/
git commit -m "feat(coding): filter refactor drills until Phase B web IDE (Phase A safety)"
```

---

### Task UI-A2: Calibration handles 3-subtype Phase A

**Files to modify:**
- `scaleup-backend/src/coding/controllers/drills.controller.js` (`startCalibration` + `getCalibrationResult`)
- `scaleup-backend/src/test/coding/calibration.api.test.js`

**TDD steps:**

- [ ] **Step 1: Update `startCalibration` to use Phase A subtypes**

Currently the controller iterates over 4 hardcoded subtypes. Change to import and use `PHASE_A_DRILL_SUBTYPES`:

```javascript
const { PHASE_A_DRILL_SUBTYPES } = require('../services/roleTrackMapper');

async function startCalibration(req, res) {
  // ... existing auth + role_track lookup ...

  const subtypesToFetch = PHASE_A_DRILL_SUBTYPES; // ['prompt', 'verify', 'decompose']
  const bundles = await Promise.all(subtypesToFetch.map(subtype =>
    ArtifactBundle.findOne({
      type: 'drill', role_track, drill_subtype: subtype,
      difficulty: 'easy', status: 'active',
    }).sort({ createdAt: -1 }).lean()
  ));

  if (bundles.some(b => !b)) {
    return res.status(503).json({ error: 'calibration_unavailable' });
  }

  // ... rest of existing logic ...
}
```

- [ ] **Step 2: Update `getCalibrationResult` to compute baseline over 3 axes**

The existing logic averages 4 axes. Change `baselineFromDrills` (in the same controller file) to average over the 3 Phase A axes only:

```javascript
function baselineFromDrills(drillAttempts) {
  const PHASE_A_AXES = ['prompting', 'verification', 'decomposition'];
  const axes = { prompting: 0, verification: 0, decomposition: 0, refactoring: 0 };
  for (const a of drillAttempts) {
    const axis = subtypeToAxis(a.drill_subtype);
    axes[axis] = a.grade.overall_score;
  }
  // Refactoring stays at 0 (unmeasured in Phase A)
  const measuredAxes = PHASE_A_AXES.map(k => axes[k]);
  const avg = measuredAxes.reduce((s, v) => s + v, 0) / measuredAxes.length;
  let recommended_difficulty = 'easy';
  if (avg > 90) recommended_difficulty = 'hard';
  else if (avg > 80) recommended_difficulty = 'medium';
  return { axes, recommended_difficulty, average: avg };
}
```

- [ ] **Step 3: Update calibration tests**

In `calibration.api.test.js`, update test expectations:
- Sequence has 3 entries, not 4
- baseline averages over 3 scores (not 4)
- Stub `ArtifactBundle.findOne` for 3 subtypes, not 4

- [ ] **Step 4: Run + commit**

```bash
OPENAI_API_KEY=stub node --test src/test/coding/calibration.api.test.js
git add src/coding/controllers/drills.controller.js src/test/coding/calibration.api.test.js
git commit -m "feat(coding): calibration uses 3-subtype Phase A sequence (refactor deferred)"
```

- [ ] **Step 5: Push backend branch + deploy**

```bash
git push origin feat/coding-practice-ui-prep   # or merge to master if you prefer one-step
```

Wait for GH Actions deploy to complete (~30 sec). Verify `curl http://15.207.72.150:5000/api/coding/health` returns 200 + the same response. Verify `/api/coding/drills/today` for a coding-objective user returns a non-refactor bundle (can spot-check via the iOS app once it lands).

---

## Workstream B — iOS Drill UI (9 tasks)

**Branch:** `feat/coding-practice-ui-ios` (off current `master` in `ScaleUpDemo-f`)
**Module location:** `ScaleUp/Features/Coding/`

### iOS module layout (target end state)

```
ScaleUp/Features/Coding/
├── Models/
│   ├── DrillViewState.swift          # enum: brief | input | submitting | result
│   ├── DrillSubmission.swift         # value types for each subtype
│   └── DrillSession.swift            # in-memory state for the sheet
├── Services/
│   ├── DrillService.swift            # API client wrapper
│   └── DrillAnalytics.swift          # Mixpanel events
├── Views/
│   ├── DrillModalView.swift          # bottom-sheet shell, state machine
│   ├── DrillBriefView.swift          # brief screen with Start CTA
│   ├── PromptDrillInputView.swift
│   ├── VerifyDrillInputView.swift
│   ├── DecomposeDrillInputView.swift
│   ├── DrillSubmittingView.swift     # 8-sec inline loader
│   ├── DrillResultView.swift         # score + rubric + what-you-missed
│   ├── CalibrationSequenceView.swift # 3-step nav stack
│   └── CodingDrillCard.swift         # secondary card on Home
└── Components/
    ├── DrillTimerBadge.swift
    ├── RubricBar.swift               # animated bar per criterion
    ├── MasteryDeltaBadge.swift       # "+4 prompting" floating badge
    └── BugLocationRow.swift          # for Verify input
```

---

### Task UI-B1: Regenerate OpenAPI types + DrillService

**Files to create:**
- `ScaleUp/Features/Coding/Services/DrillService.swift`
- `Tests/Coding/DrillServiceTests.swift`

**Files to modify:**
- `ScaleUp/Generated/` (regenerated from backend `openapi.yaml`)

**TDD steps:**

- [ ] **Step 1: Regenerate API types from backend**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
./scripts/regenerate-openapi-types.sh
```

This rewrites `ScaleUp/Generated/` from the backend's current `openapi.yaml` (which already has the coding endpoints). Verify that types like `CodingDrillToday`, `CodingDrillStart`, `CodingDrillSubmit`, `CodingDrillResult`, `CodingCalibrationStart`, `CodingCalibrationResult` (or whatever the generator names them) appear in the generated file. If a name is awkward, note it but don't hand-edit — the generator is source of truth.

- [ ] **Step 2: Write failing tests at `Tests/Coding/DrillServiceTests.swift`**

```swift
import XCTest
@testable import ScaleUp

final class DrillServiceTests: XCTestCase {
    func testFetchTodayParsesResponse() async throws {
        let mockClient = MockAPIClient()
        mockClient.stub(path: "/api/coding/drills/today", responseJSON: """
        {
          "bundle_id": "abc123",
          "brief": "Write a prompt...",
          "time_budget_minutes": 5,
          "drill_subtype": "prompt",
          "difficulty": "easy",
          "role_track": "swe",
          "language": "python",
          "acceptance_criteria": ["Criterion 1"]
        }
        """)
        let service = DrillService(client: mockClient)
        let drill = try await service.fetchTodayDrill()
        XCTAssertEqual(drill.drillSubtype, .prompt)
        XCTAssertEqual(drill.timeBudgetMinutes, 5)
    }

    func testStartDrillCreatesAttempt() async throws {
        // ... similar pattern for POST /:id/start
    }

    func testSubmitDrillReturns202() async throws {
        // ... POST /:id/submit returns 202 + attemptId + pollUrl
    }

    func testPollResultReturns202WhenNotReady() async throws {
        // GET /:id/result returns 202 when status != graded
    }

    func testPollResultReturns200WhenGraded() async throws {
        // GET /:id/result returns 200 + full grade payload
    }
}

final class MockAPIClient: APIClientProtocol {
    private var stubs: [String: String] = [:]
    func stub(path: String, responseJSON: String) { stubs[path] = responseJSON }
    func get<T: Decodable>(_ path: String) async throws -> T { /* impl */ }
    func post<T: Decodable>(_ path: String, body: Encodable?) async throws -> T { /* impl */ }
}
```

- [ ] **Step 3: Run tests — confirm fail**

```bash
xcodebuild test -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ScaleUpTests/DrillServiceTests
```

Expected: FAIL — `DrillService` not defined.

- [ ] **Step 4: Implement `DrillService`**

```swift
import Foundation

@MainActor
final class DrillService {
    private let client: APIClientProtocol

    init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    func fetchTodayDrill() async throws -> CodingDrillToday {
        try await client.get("/api/coding/drills/today")
    }

    func startDrill(bundleId: String) async throws -> CodingDrillStart {
        try await client.post("/api/coding/drills/\(bundleId)/start", body: nil)
    }

    func submitDrill(bundleId: String, submission: DrillSubmissionPayload) async throws -> CodingDrillSubmit {
        try await client.post("/api/coding/drills/\(bundleId)/submit", body: submission)
    }

    func pollResult(bundleId: String) async throws -> CodingDrillResultResponse {
        try await client.get("/api/coding/drills/\(bundleId)/result")
    }

    // Calibration
    func startCalibration() async throws -> CodingCalibrationStart {
        try await client.post("/api/coding/drills/calibration/start", body: nil)
    }

    func submitCalibration(calibrationId: String, submissions: [DrillSubmissionPayload]) async throws -> CodingCalibrationSubmit {
        try await client.post("/api/coding/drills/calibration/\(calibrationId)/submit", body: ["submissions": submissions])
    }

    func pollCalibrationResult(calibrationId: String) async throws -> CodingCalibrationResult {
        try await client.get("/api/coding/drills/calibration/\(calibrationId)/result")
    }
}
```

Adapt the exact generated type names to whatever the regen produces.

- [ ] **Step 5: Run tests — confirm pass + commit**

```bash
xcodebuild test -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ScaleUpTests/DrillServiceTests
git add ScaleUp/Features/Coding/Services ScaleUp/Generated Tests/Coding
git commit -m "feat(coding/ios): add DrillService + regen OpenAPI types"
```

---

### Task UI-B2: DrillModal bottom sheet + Brief view

**Files to create:**
- `ScaleUp/Features/Coding/Models/DrillViewState.swift`
- `ScaleUp/Features/Coding/Models/DrillSession.swift`
- `ScaleUp/Features/Coding/Views/DrillModalView.swift`
- `ScaleUp/Features/Coding/Views/DrillBriefView.swift`

**Steps:**

- [ ] **Step 1: Define the state machine**

```swift
// DrillViewState.swift
enum DrillViewState: Equatable {
    case loading        // fetching today's drill
    case brief          // showing the problem brief
    case input          // learner inputting answer
    case submitting     // submitted, waiting for grade
    case result(grade: DrillGrade)
    case error(String)
}
```

- [ ] **Step 2: Define the session object**

```swift
// DrillSession.swift
@Observable
final class DrillSession {
    var state: DrillViewState = .loading
    var todayDrill: CodingDrillToday?
    var attemptId: String?
    var startedAt: Date?
    var submission: DrillSubmissionPayload?

    private let service: DrillService

    init(service: DrillService = DrillService()) {
        self.service = service
    }

    @MainActor
    func loadToday() async {
        do {
            let drill = try await service.fetchTodayDrill()
            todayDrill = drill
            state = .brief
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    func start() async {
        guard let drill = todayDrill else { return }
        do {
            let started = try await service.startDrill(bundleId: drill.bundleId)
            attemptId = started.attemptId
            startedAt = Date()
            state = .input
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    func submit(_ payload: DrillSubmissionPayload) async {
        guard let drill = todayDrill else { return }
        submission = payload
        state = .submitting
        do {
            _ = try await service.submitDrill(bundleId: drill.bundleId, submission: payload)
            // Poll for result every 2 sec, up to 30 sec
            for _ in 0..<15 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let result = try await service.pollResult(bundleId: drill.bundleId)
                if result.status == "graded" {
                    state = .result(grade: result.toGrade())
                    return
                }
            }
            state = .error("Grading took too long. Try again.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 3: Implement the modal shell**

```swift
// DrillModalView.swift
struct DrillModalView: View {
    @State private var session = DrillSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .task { await session.loadToday() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .loading:
            ProgressView("Loading today's drill…")
        case .brief:
            DrillBriefView(drill: session.todayDrill!) {
                Task { await session.start() }
            }
        case .input:
            inputView
        case .submitting:
            DrillSubmittingView()
        case .result(let grade):
            DrillResultView(grade: grade, drill: session.todayDrill!) {
                dismiss()
            }
        case .error(let message):
            ContentUnavailableView("Something went wrong", systemImage: "exclamationmark.triangle", description: Text(message))
        }
    }

    @ViewBuilder
    private var inputView: some View {
        switch session.todayDrill?.drillSubtype {
        case .prompt:    PromptDrillInputView(session: session)
        case .verify:    VerifyDrillInputView(session: session)
        case .decompose: DecomposeDrillInputView(session: session)
        default: ContentUnavailableView("Unsupported drill type", systemImage: "questionmark.circle")
        }
    }

    private var navTitle: String {
        switch session.state {
        case .brief: return "Today's Drill"
        case .input, .submitting: return drillTitle
        case .result: return "Drill Result"
        default: return ""
        }
    }

    private var drillTitle: String {
        guard let subtype = session.todayDrill?.drillSubtype else { return "Drill" }
        switch subtype {
        case .prompt: return "Prompt Drill"
        case .verify: return "Bug Hunt"
        case .decompose: return "Decompose"
        case .refactor: return "Refactor"
        }
    }
}
```

- [ ] **Step 4: Implement the Brief view**

```swift
// DrillBriefView.swift
struct DrillBriefView: View {
    let drill: CodingDrillToday
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                badgeRow

                Text("Today's coding drill")
                    .font(.title2.weight(.semibold))

                Text(drill.brief)
                    .font(.body)
                    .lineSpacing(4)

                if let criteria = drill.acceptanceCriteria, !criteria.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What we're looking for")
                            .font(.headline)
                        ForEach(criteria, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.tint)
                                Text(item)
                            }
                        }
                    }
                }

                Spacer(minLength: 20)

                Button(action: onStart) {
                    HStack {
                        Text("Start")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    private var badgeRow: some View {
        HStack(spacing: 8) {
            Label(drill.drillSubtype.displayName, systemImage: drill.drillSubtype.iconName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gray.opacity(0.15)))

            Label("\(drill.timeBudgetMinutes) min", systemImage: "clock")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gray.opacity(0.15)))

            Label(drill.difficulty.capitalized, systemImage: "chart.bar.fill")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gray.opacity(0.15)))
        }
    }
}

extension DrillSubtype {
    var displayName: String {
        switch self {
        case .prompt: return "Prompt"
        case .verify: return "Bug Hunt"
        case .decompose: return "Decompose"
        case .refactor: return "Refactor"
        }
    }

    var iconName: String {
        switch self {
        case .prompt: return "text.bubble"
        case .verify: return "magnifyingglass"
        case .decompose: return "list.number"
        case .refactor: return "arrow.triangle.2.circlepath"
        }
    }
}
```

- [ ] **Step 5: Add a SwiftUI preview**

```swift
#Preview {
    DrillModalView()
}
```

- [ ] **Step 6: Manual smoke in simulator + commit**

```bash
/opt/homebrew/bin/xcodegen generate   # full path — see CLAUDE.md note
xcodebuild build -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 15'
# Launch app in simulator, manually trigger modal somewhere (will wire to Home in UI-B7)
git add ScaleUp/Features/Coding/Models ScaleUp/Features/Coding/Views/DrillModalView.swift ScaleUp/Features/Coding/Views/DrillBriefView.swift
git commit -m "feat(coding/ios): drill modal shell + brief view"
```

---

### Task UI-B3: Prompt Drill input view

**Files to create:**
- `ScaleUp/Features/Coding/Views/PromptDrillInputView.swift`
- `ScaleUp/Features/Coding/Models/DrillSubmission.swift`

**Steps:**

- [ ] **Step 1: Define submission payload**

```swift
// DrillSubmission.swift
struct DrillSubmissionPayload: Encodable {
    let drillSubtype: String
    let submission: SubmissionBody

    enum SubmissionBody: Encodable {
        case prompt(text: String)
        case verify(locations: [BugLocation])
        case decompose(steps: [DecompositionStep])

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicKey.self)
            switch self {
            case .prompt(let text):
                try container.encode(text, forKey: .init("prompt_text"))
            case .verify(let locations):
                try container.encode(locations, forKey: .init("bug_locations"))
            case .decompose(let steps):
                try container.encode(steps, forKey: .init("decomposition_steps"))
            }
        }
    }
}

struct BugLocation: Codable, Identifiable {
    var id = UUID()
    var file: String
    var line: Int
    var explanation: String

    enum CodingKeys: String, CodingKey {
        case file, line, explanation
    }
}

struct DecompositionStep: Codable, Identifiable {
    var id = UUID()
    var step: String
    var rationale: String

    enum CodingKeys: String, CodingKey {
        case step, rationale
    }
}
```

- [ ] **Step 2: Implement the prompt input view**

```swift
struct PromptDrillInputView: View {
    @Bindable var session: DrillSession
    @State private var promptText: String = ""
    @State private var showHint = false

    private var characterCount: Int { promptText.count }
    private let minChars = 30
    private let maxChars = 8000

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Compact brief recap (collapsible)
            DisclosureGroup("View brief", isExpanded: $showHint) {
                Text(session.todayDrill?.brief ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(8)
            .padding(.horizontal)

            // Input area
            VStack(alignment: .leading, spacing: 8) {
                Text("Your prompt")
                    .font(.headline)

                TextEditor(text: $promptText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                HStack {
                    Text("\(characterCount) / \(maxChars)")
                        .font(.caption)
                        .foregroundStyle(characterCount < minChars ? .red : .secondary)
                    Spacer()
                    if characterCount < minChars {
                        Text("Min \(minChars) characters")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            // Submit button
            Button {
                let payload = DrillSubmissionPayload(
                    drillSubtype: "prompt",
                    submission: .prompt(text: promptText)
                )
                Task { await session.submit(payload) }
            } label: {
                Text("Submit for grading")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .disabled(!canSubmit)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var canSubmit: Bool { characterCount >= minChars && characterCount <= maxChars }
}
```

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Coding/Views/PromptDrillInputView.swift ScaleUp/Features/Coding/Models/DrillSubmission.swift
git commit -m "feat(coding/ios): Prompt drill input view"
```

---

### Task UI-B4: Verify Drill input view

**Files to create:**
- `ScaleUp/Features/Coding/Views/VerifyDrillInputView.swift`
- `ScaleUp/Features/Coding/Components/BugLocationRow.swift`

**Steps:**

- [ ] **Step 1: BugLocationRow component**

```swift
// BugLocationRow.swift
struct BugLocationRow: View {
    @Binding var location: BugLocation
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("file (e.g. main.js)", text: $location.file)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .frame(maxWidth: .infinity)
                TextField("line", value: $location.line, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            TextField("Explain the bug…", text: $location.explanation, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
```

- [ ] **Step 2: Verify input view**

```swift
struct VerifyDrillInputView: View {
    @Bindable var session: DrillSession
    @State private var locations: [BugLocation] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Code viewer (read-only, monospaced)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review this code")
                        .font(.headline)
                        .padding(.horizontal)
                    Text(session.todayDrill?.brief ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                // Bug locations list
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bugs you found")
                            .font(.headline)
                        Spacer()
                        Text("\(locations.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach($locations) { $location in
                        BugLocationRow(location: $location) {
                            locations.removeAll { $0.id == location.id }
                        }
                    }

                    Button {
                        locations.append(BugLocation(file: "", line: 1, explanation: ""))
                    } label: {
                        Label("Add a bug location", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                let payload = DrillSubmissionPayload(
                    drillSubtype: "verify",
                    submission: .verify(locations: locations.map { BugLocation(file: $0.file, line: $0.line, explanation: $0.explanation) })
                )
                Task { await session.submit(payload) }
            } label: {
                Text("Submit for grading")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .disabled(!canSubmit)
            .padding()
            .background(.regularMaterial)
        }
    }

    private var canSubmit: Bool {
        !locations.isEmpty &&
        locations.allSatisfy {
            !$0.file.isEmpty &&
            $0.line > 0 &&
            $0.explanation.count >= 5
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Coding/Views/VerifyDrillInputView.swift ScaleUp/Features/Coding/Components/BugLocationRow.swift
git commit -m "feat(coding/ios): Verify drill input view (file/line/explanation rows)"
```

---

### Task UI-B5: Decompose Drill input view

**Files to create:**
- `ScaleUp/Features/Coding/Views/DecomposeDrillInputView.swift`

**Steps:**

- [ ] **Step 1: Implementation** (similar to Verify but for steps, not bug locations)

```swift
struct DecomposeDrillInputView: View {
    @Bindable var session: DrillSession
    @State private var steps: [DecompositionStep] = []

    private let minSteps = 3
    private let maxSteps = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Brief recap
                if let brief = session.todayDrill?.brief {
                    Text(brief)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                // Steps
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your decomposition")
                            .font(.headline)
                        Spacer()
                        Text("\(steps.count) / \(maxSteps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array($steps.enumerated()), id: \.element.id) { idx, $step in
                        StepRow(index: idx + 1, step: $step) {
                            steps.remove(at: idx)
                        }
                    }

                    if steps.count < maxSteps {
                        Button {
                            steps.append(DecompositionStep(step: "", rationale: ""))
                        } label: {
                            Label("Add step", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .bottom) {
            submitBar
        }
    }

    private var submitBar: some View {
        Button {
            let payload = DrillSubmissionPayload(
                drillSubtype: "decompose",
                submission: .decompose(steps: steps)
            )
            Task { await session.submit(payload) }
        } label: {
            Text(steps.count < minSteps ? "Add \(minSteps - steps.count) more step\(minSteps - steps.count > 1 ? "s" : "")" : "Submit for grading")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
                .cornerRadius(12)
        }
        .disabled(!canSubmit)
        .padding()
        .background(.regularMaterial)
    }

    private var canSubmit: Bool {
        steps.count >= minSteps &&
        steps.allSatisfy { !$0.step.isEmpty && !$0.rationale.isEmpty }
    }
}

private struct StepRow: View {
    let index: Int
    @Binding var step: DecompositionStep
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(index)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
            }
            TextField("What to do…", text: $step.step, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            TextField("Why this step exists…", text: $step.rationale, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ScaleUp/Features/Coding/Views/DecomposeDrillInputView.swift
git commit -m "feat(coding/ios): Decompose drill input view (step + rationale rows)"
```

---

### Task UI-B6: Submitting state + Result view + Mastery delta

**Files to create:**
- `ScaleUp/Features/Coding/Views/DrillSubmittingView.swift`
- `ScaleUp/Features/Coding/Views/DrillResultView.swift`
- `ScaleUp/Features/Coding/Components/RubricBar.swift`
- `ScaleUp/Features/Coding/Components/MasteryDeltaBadge.swift`

**Steps:**

- [ ] **Step 1: Submitting view (8-sec loader with rotating hint)**

```swift
struct DrillSubmittingView: View {
    @State private var hintIndex = 0
    private let hints = [
        "Compass is reading your answer…",
        "Checking against the rubric…",
        "Comparing to reference answers…",
        "Almost there…"
    ]

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .padding(.bottom, 20)
            Text(hints[hintIndex])
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .id(hintIndex)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation { hintIndex = (hintIndex + 1) % hints.count }
            }
        }
    }
}
```

- [ ] **Step 2: RubricBar component**

```swift
struct RubricBar: View {
    let dimension: String
    let score: Double  // 0-10
    let feedback: String?

    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dimension.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(score))/10")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: proxy.size.width * animatedWidth, height: 8)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                        animatedWidth = CGFloat(score) / 10.0
                    }
                }
            }
            .frame(height: 8)

            if let feedback = feedback, !feedback.isEmpty {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var barColor: Color {
        if score >= 8 { return .green }
        if score >= 6 { return .yellow }
        return .orange
    }
}
```

- [ ] **Step 3: Result view**

```swift
struct DrillResultView: View {
    let grade: DrillGrade
    let drill: CodingDrillToday
    let onDone: () -> Void
    @State private var animatedScore: Double = 0
    @State private var showWhatYouMissed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Animated overall score
                VStack(spacing: 4) {
                    Text("Score")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(Int(animatedScore))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("/ 100")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) {
                        animatedScore = Double(grade.overallScore)
                    }
                }

                // Rubric breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("How you did")
                        .font(.headline)
                    ForEach(grade.rubricBreakdown, id: \.dimension) { item in
                        RubricBar(dimension: item.dimension, score: Double(item.score), feedback: item.feedback)
                    }
                }

                // What to try next
                if let nextStep = grade.whatToTryNext, !nextStep.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What to try next time", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.tint)
                        Text(nextStep)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(12)
                }

                // What you missed (educational reveal)
                DisclosureGroup(isExpanded: $showWhatYouMissed) {
                    VStack(alignment: .leading, spacing: 12) {
                        // For verify drills, show seeded mistakes the learner didn't catch
                        // For prompt/decompose, show reference-answer elements they missed
                        // The backend includes a `what_you_missed` array in the graded response for v2
                        // For Phase A, just show a placeholder pointing to the bundle's expected_meta_skill_signals
                        Text("(Server-side support for revealing missed seeded mistakes lands in a backend follow-up; this section will populate then.)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                } label: {
                    Label("What you missed", systemImage: "eye.fill")
                        .font(.headline)
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .cornerRadius(12)

                Spacer()

                Button(action: onDone) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}
```

- [ ] **Step 4: Mastery delta badge** (floating toast that shows for ~3 sec after result appears)

```swift
struct MasteryDeltaBadge: View {
    let axis: String
    let delta: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.green)
            Text("+\(String(format: "%.1f", delta)) \(axis)")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
```

The badge is shown by `DrillResultView` as an overlay for 3 sec after appear. Implementation detail — wire it in.

- [ ] **Step 5: Commit**

```bash
git add ScaleUp/Features/Coding/Views/DrillSubmittingView.swift ScaleUp/Features/Coding/Views/DrillResultView.swift ScaleUp/Features/Coding/Components/RubricBar.swift ScaleUp/Features/Coding/Components/MasteryDeltaBadge.swift
git commit -m "feat(coding/ios): submitting + result views with rubric bars + mastery delta"
```

---

### Task UI-B7: Calibration sequence view (3-drill flow)

**Files to create:**
- `ScaleUp/Features/Coding/Views/CalibrationSequenceView.swift`
- `ScaleUp/Features/Coding/Models/CalibrationSession.swift`

**Steps:**

- [ ] **Step 1: CalibrationSession state machine** (similar to DrillSession but tracks 3 drills)

```swift
@Observable
final class CalibrationSession {
    enum State {
        case loading, inProgress(stepIndex: Int), submitting, result(CalibrationResult), error(String)
    }

    var state: State = .loading
    var calibrationId: String?
    var drills: [CodingCalibrationDrill] = []
    var submissions: [DrillSubmissionPayload] = []

    private let service: DrillService

    init(service: DrillService = DrillService()) {
        self.service = service
    }

    @MainActor
    func start() async {
        do {
            let started = try await service.startCalibration()
            calibrationId = started.calibrationId
            drills = started.drills
            state = .inProgress(stepIndex: 0)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    func submitStep(_ submission: DrillSubmissionPayload) {
        submissions.append(submission)
        if case .inProgress(let i) = state {
            if i + 1 < drills.count {
                state = .inProgress(stepIndex: i + 1)
            } else {
                Task { await submitAll() }
            }
        }
    }

    @MainActor
    private func submitAll() async {
        state = .submitting
        guard let id = calibrationId else { return }
        do {
            _ = try await service.submitCalibration(calibrationId: id, submissions: submissions)
            // Poll for result
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let result = try await service.pollCalibrationResult(calibrationId: id)
                if result.status == "graded" {
                    state = .result(result)
                    return
                }
            }
            state = .error("Calibration took too long.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: CalibrationSequenceView**

```swift
struct CalibrationSequenceView: View {
    @State private var session = CalibrationSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if case .inProgress = session.state {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }
        }
        .task { await session.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .loading:
            ProgressView("Setting up calibration…")
        case .inProgress(let stepIndex):
            VStack(spacing: 0) {
                ProgressBar(current: stepIndex + 1, total: session.drills.count)
                    .padding()
                drillInput(for: stepIndex)
            }
        case .submitting:
            VStack(spacing: 16) {
                ProgressView().scaleEffect(2)
                Text("Computing your baseline…")
                    .foregroundStyle(.secondary)
            }
        case .result(let result):
            CalibrationResultView(result: result) { dismiss() }
        case .error(let msg):
            ContentUnavailableView("Couldn't start calibration", systemImage: "exclamationmark.triangle", description: Text(msg))
        }
    }

    @ViewBuilder
    private func drillInput(for stepIndex: Int) -> some View {
        let drill = session.drills[stepIndex]
        // Each step uses the same input view as the regular drill but in compact mode
        // Use a wrapper that calls session.submitStep on submission
        // Implementation: factor input views to accept a "completion handler" param
        Text("Step \(stepIndex + 1): \(drill.drillSubtype) — implementation reuses input views")
        // Real impl: switch on drill.drillSubtype and embed the matching input view
    }
}

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Step \(current) of \(total)")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("~\(2 * (total - current + 1)) min left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule().fill(Color.accentColor).frame(width: proxy.size.width * CGFloat(current) / CGFloat(total))
                }
            }
            .frame(height: 4)
        }
    }
}
```

- [ ] **Step 3: CalibrationResultView** (shows baseline scores + recommended difficulty + "let's go" CTA)

```swift
struct CalibrationResultView: View {
    let result: CalibrationResult
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your baseline")
                    .font(.largeTitle.weight(.semibold))
                    .padding(.top, 20)

                Text("Based on these 3 drills, here's where you start.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Baseline axes as bars
                VStack(spacing: 12) {
                    ForEach(result.drills, id: \.drillSubtype) { drill in
                        RubricBar(dimension: drill.drillSubtype, score: Double(drill.overallScore ?? 0) / 10.0, feedback: nil)
                    }
                }
                .padding(.top, 12)

                // Recommended difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested starting difficulty")
                        .font(.headline)
                    HStack {
                        Text(result.recommendedDifficulty.capitalized)
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(8)
                        Spacer()
                        Text("You can change this anytime in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                Spacer()

                Button(action: onDone) {
                    Text("Start your daily drills")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Features/Coding/Views/CalibrationSequenceView.swift ScaleUp/Features/Coding/Models/CalibrationSession.swift
git commit -m "feat(coding/ios): calibration 3-drill sequence + baseline result view"
```

---

### Task UI-B8: Home tab card + analytics

**Files to create:**
- `ScaleUp/Features/Coding/Views/CodingDrillCard.swift`
- `ScaleUp/Features/Coding/Services/DrillAnalytics.swift`

**Files to modify:**
- `ScaleUp/Features/home/V2HomeView.swift` (locate the secondary card section + add CodingDrillCard)

**Steps:**

- [ ] **Step 1: CodingDrillCard**

```swift
struct CodingDrillCard: View {
    @State private var todayDrill: CodingDrillToday?
    @State private var showDrillModal = false
    @State private var showCalibration = false
    @State private var needsCalibration = false

    private let service = DrillService()

    var body: some View {
        Group {
            if let drill = todayDrill {
                drillCard(drill)
            } else if needsCalibration {
                calibrationCard
            } else {
                EmptyView()
            }
        }
        .task { await loadDrillOrCalibrationState() }
        .sheet(isPresented: $showDrillModal) {
            DrillModalView()
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationSequenceView()
        }
    }

    private func drillCard(_ drill: CodingDrillToday) -> some View {
        Button {
            DrillAnalytics.trackCardTapped(drill: drill)
            showDrillModal = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Today's coding drill", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                    Spacer()
                    Text("\(drill.timeBudgetMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(drill.brief)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text(drill.drillSubtype.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    Text(drill.difficulty.capitalized)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tint)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var calibrationCard: some View {
        Button {
            DrillAnalytics.trackCalibrationCardTapped()
            showCalibration = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label("New: coding practice for your objective", systemImage: "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
                Text("Take a 6-min calibration to see where you stand.")
                    .font(.subheadline)
                Text("Start →")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .padding()
            .background(LinearGradient(colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadDrillOrCalibrationState() async {
        do {
            let drill = try await service.fetchTodayDrill()
            todayDrill = drill
        } catch APIError.notFound(let code) where code == "calibration_required" {
            needsCalibration = true
        } catch {
            // Silent fail — drill card is best-effort, don't break Home
        }
    }
}
```

Note: the backend's `/api/coding/drills/today` returns 404 with various codes (`no_drill_available`, `no_coding_track_for_objective`). For calibration prompting, we may need a small backend tweak that returns a 404 with code `calibration_required` when the user has no MetaSkillMastery yet. Add this to the backend if not already present (see UI-B0 sub-note below).

> **Sub-note for backend:** if `getToday` returns 404 because the user has no MetaSkillMastery yet, change it to return a clear `'calibration_required'` code. 5-line tweak. Surface this as a tiny addendum to UI-A1 if not already done.

- [ ] **Step 2: DrillAnalytics**

```swift
import Mixpanel

enum DrillAnalytics {
    static func trackCardShown(drill: CodingDrillToday) {
        Mixpanel.mainInstance().track(event: "coding_drill_card_shown", properties: [
            "drill_subtype": drill.drillSubtype.rawValue,
            "difficulty": drill.difficulty,
            "role_track": drill.roleTrack,
        ])
    }

    static func trackCardTapped(drill: CodingDrillToday) {
        Mixpanel.mainInstance().track(event: "coding_drill_card_tapped", properties: [
            "drill_subtype": drill.drillSubtype.rawValue,
        ])
    }

    static func trackStarted(drill: CodingDrillToday) {
        Mixpanel.mainInstance().track(event: "coding_drill_started", properties: [
            "drill_subtype": drill.drillSubtype.rawValue,
        ])
    }

    static func trackSubmitted(drill: CodingDrillToday, timeTakenSeconds: Int) {
        Mixpanel.mainInstance().track(event: "coding_drill_submitted", properties: [
            "drill_subtype": drill.drillSubtype.rawValue,
            "time_taken_seconds": timeTakenSeconds,
        ])
    }

    static func trackResultViewed(drill: CodingDrillToday, score: Int) {
        Mixpanel.mainInstance().track(event: "coding_drill_result_viewed", properties: [
            "drill_subtype": drill.drillSubtype.rawValue,
            "score": score,
        ])
    }

    static func trackAbandoned(drill: CodingDrillToday, atState: String) {
        Mixpanel.mainInstance().track(event: "coding_drill_abandoned", properties: [
            "drill_subtype": drill.drillSubtype.rawValue,
            "abandoned_at": atState,
        ])
    }

    static func trackCalibrationCardTapped() {
        Mixpanel.mainInstance().track(event: "coding_calibration_card_tapped")
    }

    static func trackCalibrationCompleted(averageScore: Double, recommendedDifficulty: String) {
        Mixpanel.mainInstance().track(event: "coding_calibration_completed", properties: [
            "average_score": averageScore,
            "recommended_difficulty": recommendedDifficulty,
        ])
    }
}
```

Wire these calls into the respective views (`onAppear` for shown/viewed, button taps for started/submitted/tapped).

- [ ] **Step 3: Wire CodingDrillCard into V2HomeView**

Locate `V2HomeView.swift` and find the section where secondary cards (below the hero) are rendered. Add:

```swift
CodingDrillCard()
    .padding(.horizontal)
```

immediately after the hero task card. Use existing spacing convention.

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Features/Coding/Views/CodingDrillCard.swift ScaleUp/Features/Coding/Services/DrillAnalytics.swift ScaleUp/Features/home/V2HomeView.swift
git commit -m "feat(coding/ios): Home tab drill card + Mixpanel analytics"
```

---

### Task UI-B9: TestFlight build prep

**Files to modify:**
- `project.yml` (bump `CURRENT_PROJECT_VERSION`)

**Steps:**

- [ ] **Step 1: Bump build number**

In `project.yml`, find `CURRENT_PROJECT_VERSION: "157"` (or whatever the current is). Increment by 1 (e.g., to 158).

- [ ] **Step 2: Regenerate Xcode project — full path required**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
/opt/homebrew/bin/xcodegen generate
```

**Critical:** if you don't use the full path, a stale shell alias may silently fail to apply the bundle version, and TestFlight upload will reject with a version-collision error.

- [ ] **Step 3: Archive + upload via Xcode**

Open `ScaleUp.xcworkspace` (or `.xcodeproj`), select "Any iOS Device" as destination, Product → Archive. When the Organizer opens, click "Distribute App" → App Store Connect → Upload.

Alternatively, command-line:

```bash
xcodebuild -scheme ScaleUp -configuration Release archive -archivePath ./build/ScaleUp.xcarchive
xcodebuild -exportArchive -archivePath ./build/ScaleUp.xcarchive -exportPath ./build -exportOptionsPlist ExportOptions.plist
xcrun altool --upload-app -f ./build/ScaleUp.ipa -t ios -u <APPLE_ID> -p <APP_SPECIFIC_PASSWORD>
```

Or use App Store Connect API key (you have one — see local memory `reference_appstore_connect`):

```bash
xcrun altool --upload-app -f ./build/ScaleUp.ipa -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

- [ ] **Step 4: Wait for processing, add to TestFlight internal group, push to testers**

App Store Connect web UI:
1. TestFlight tab → new build appears (Processing → Ready)
2. Add to Internal Testing group
3. Save — testers get the build notification

- [ ] **Step 5: Commit version bump**

```bash
git add project.yml
git commit -m "chore(ios): bump build to 158 — coding drill UI ready for TestFlight"
```

- [ ] **Step 6: Merge iOS branch to master + push**

```bash
git checkout master
git merge --no-ff feat/coding-practice-ui-ios -m "feat(coding/ios): merge drill UI + TestFlight build 158"
git push origin master
```

---

## Workstream C — Android Drill UI (5 tasks)

**Branch:** `feat/coding-practice-ui-android` (off current `main` in `ScaleUpAndroid` — note Android uses `main`, not `master`)
**Module location:** `src/features/coding/`

### Android module layout (target end state)

```
src/features/coding/
├── api/
│   └── drillApi.ts                  # API client wrapper using openapi-typescript types
├── store/
│   └── codingSlice.ts               # Redux Toolkit slice for drill session state
├── screens/
│   ├── DrillModalScreen.tsx         # full-screen modal navigator
│   ├── DrillBriefScreen.tsx
│   ├── PromptDrillInputScreen.tsx
│   ├── VerifyDrillInputScreen.tsx
│   ├── DecomposeDrillInputScreen.tsx
│   ├── DrillSubmittingScreen.tsx
│   ├── DrillResultScreen.tsx
│   ├── CalibrationSequenceScreen.tsx
│   └── CalibrationResultScreen.tsx
├── components/
│   ├── DrillTimerBadge.tsx
│   ├── RubricBar.tsx
│   ├── MasteryDeltaBadge.tsx
│   ├── BugLocationRow.tsx
│   └── CodingDrillCard.tsx
└── services/
    └── drillAnalytics.ts            # Mixpanel wrapper
```

---

### Task UI-C1: openapi:regen + drillApi + Redux slice

**Files to create:**
- `src/features/coding/api/drillApi.ts`
- `src/features/coding/store/codingSlice.ts`
- `__tests__/coding/drillApi.test.ts`

**Steps:**

- [ ] **Step 1: Regenerate types**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
npm run openapi:regen
```

This rewrites `src/types/api.generated.ts` from the backend's `openapi.yaml`.

- [ ] **Step 2: drillApi.ts**

```typescript
import apiClient from '../../../config/apiClient';
import type { paths } from '../../../types/api.generated';

type TodayDrillResp = paths['/api/coding/drills/today']['get']['responses']['200']['content']['application/json'];
type StartDrillResp = paths['/api/coding/drills/{id}/start']['post']['responses']['200']['content']['application/json'];
type SubmitDrillResp = paths['/api/coding/drills/{id}/submit']['post']['responses']['202']['content']['application/json'];
type ResultResp = paths['/api/coding/drills/{id}/result']['get']['responses']['200']['content']['application/json'];

export const drillApi = {
  fetchTodayDrill: async (): Promise<TodayDrillResp> => {
    const { data } = await apiClient.get('/api/coding/drills/today');
    return data;
  },

  startDrill: async (bundleId: string): Promise<StartDrillResp> => {
    const { data } = await apiClient.post(`/api/coding/drills/${bundleId}/start`);
    return data;
  },

  submitDrill: async (bundleId: string, drillSubtype: string, submission: any): Promise<SubmitDrillResp> => {
    const { data } = await apiClient.post(`/api/coding/drills/${bundleId}/submit`, {
      drill_subtype: drillSubtype,
      submission,
    });
    return data;
  },

  pollResult: async (bundleId: string): Promise<ResultResp | { status: string; attempt_id: string }> => {
    const { data, status } = await apiClient.get(`/api/coding/drills/${bundleId}/result`);
    return data;
  },

  startCalibration: async () => {
    const { data } = await apiClient.post('/api/coding/drills/calibration/start');
    return data;
  },

  submitCalibration: async (calibrationId: string, submissions: any[]) => {
    const { data } = await apiClient.post(`/api/coding/drills/calibration/${calibrationId}/submit`, { submissions });
    return data;
  },

  pollCalibrationResult: async (calibrationId: string) => {
    const { data } = await apiClient.get(`/api/coding/drills/calibration/${calibrationId}/result`);
    return data;
  },
};
```

- [ ] **Step 3: codingSlice.ts**

```typescript
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { drillApi } from '../api/drillApi';

interface CodingState {
  todayDrill: any | null;
  attemptId: string | null;
  startedAt: number | null;
  currentState: 'idle' | 'brief' | 'input' | 'submitting' | 'result' | 'error';
  grade: any | null;
  error: string | null;
  needsCalibration: boolean;
  // Calibration
  calibrationId: string | null;
  calibrationDrills: any[];
  calibrationStepIndex: number;
  calibrationSubmissions: any[];
  calibrationResult: any | null;
}

const initialState: CodingState = {
  todayDrill: null,
  attemptId: null,
  startedAt: null,
  currentState: 'idle',
  grade: null,
  error: null,
  needsCalibration: false,
  calibrationId: null,
  calibrationDrills: [],
  calibrationStepIndex: 0,
  calibrationSubmissions: [],
  calibrationResult: null,
};

export const fetchTodayDrill = createAsyncThunk('coding/fetchTodayDrill', async () => {
  return await drillApi.fetchTodayDrill();
});

export const startDrill = createAsyncThunk('coding/startDrill', async (bundleId: string) => {
  return await drillApi.startDrill(bundleId);
});

export const submitDrillAndPoll = createAsyncThunk(
  'coding/submitDrillAndPoll',
  async ({ bundleId, drillSubtype, submission }: { bundleId: string; drillSubtype: string; submission: any }) => {
    await drillApi.submitDrill(bundleId, drillSubtype, submission);
    // Poll
    for (let i = 0; i < 15; i++) {
      await new Promise(r => setTimeout(r, 2000));
      const result = await drillApi.pollResult(bundleId);
      if ((result as any).status === 'graded') return result;
    }
    throw new Error('Grading took too long');
  }
);

const codingSlice = createSlice({
  name: 'coding',
  initialState,
  reducers: {
    resetSession: () => initialState,
    advanceCalibrationStep: (state, action: PayloadAction<any>) => {
      state.calibrationSubmissions.push(action.payload);
      state.calibrationStepIndex += 1;
    },
  },
  extraReducers: (builder) => {
    builder.addCase(fetchTodayDrill.fulfilled, (state, action) => {
      state.todayDrill = action.payload;
      state.currentState = 'brief';
    });
    builder.addCase(fetchTodayDrill.rejected, (state, action) => {
      if (action.error.message?.includes('calibration_required')) {
        state.needsCalibration = true;
      } else {
        state.error = action.error.message ?? null;
      }
    });
    builder.addCase(startDrill.fulfilled, (state, action) => {
      state.attemptId = action.payload.attempt_id;
      state.startedAt = Date.now();
      state.currentState = 'input';
    });
    builder.addCase(submitDrillAndPoll.pending, (state) => {
      state.currentState = 'submitting';
    });
    builder.addCase(submitDrillAndPoll.fulfilled, (state, action) => {
      state.grade = action.payload;
      state.currentState = 'result';
    });
    builder.addCase(submitDrillAndPoll.rejected, (state, action) => {
      state.currentState = 'error';
      state.error = action.error.message ?? null;
    });
  },
});

export const { resetSession, advanceCalibrationStep } = codingSlice.actions;
export default codingSlice.reducer;
```

- [ ] **Step 4: Test**

```typescript
// __tests__/coding/drillApi.test.ts
import { drillApi } from '../../src/features/coding/api/drillApi';
import apiClient from '../../src/config/apiClient';

jest.mock('../../src/config/apiClient');

describe('drillApi', () => {
  it('fetchTodayDrill calls correct endpoint', async () => {
    (apiClient.get as jest.Mock).mockResolvedValue({ data: { bundle_id: 'abc' } });
    const result = await drillApi.fetchTodayDrill();
    expect(apiClient.get).toHaveBeenCalledWith('/api/coding/drills/today');
    expect(result.bundle_id).toBe('abc');
  });
});
```

- [ ] **Step 5: Commit**

```bash
npm test -- --testPathPattern coding
git add src/features/coding/api src/features/coding/store src/types/api.generated.ts __tests__/coding
git commit -m "feat(coding/android): drillApi + Redux slice + regen API types"
```

---

### Task UI-C2: Drill modal + brief + per-subtype input screens

**Files to create:**
- `src/features/coding/screens/DrillModalScreen.tsx`
- `src/features/coding/screens/DrillBriefScreen.tsx`
- `src/features/coding/screens/PromptDrillInputScreen.tsx`
- `src/features/coding/screens/VerifyDrillInputScreen.tsx`
- `src/features/coding/screens/DecomposeDrillInputScreen.tsx`
- `src/features/coding/components/BugLocationRow.tsx`

**Steps:**

- [ ] **Step 1: DrillModalScreen (parent screen with sub-navigation by state)**

```tsx
import React, { useEffect } from 'react';
import { View, StyleSheet, Text, ActivityIndicator } from 'react-native';
import { useDispatch, useSelector } from 'react-redux';
import { fetchTodayDrill, resetSession } from '../store/codingSlice';
import type { RootState, AppDispatch } from '../../../store';
import DrillBriefScreen from './DrillBriefScreen';
import PromptDrillInputScreen from './PromptDrillInputScreen';
import VerifyDrillInputScreen from './VerifyDrillInputScreen';
import DecomposeDrillInputScreen from './DecomposeDrillInputScreen';
import DrillSubmittingScreen from './DrillSubmittingScreen';
import DrillResultScreen from './DrillResultScreen';

export default function DrillModalScreen({ navigation }: any) {
  const dispatch = useDispatch<AppDispatch>();
  const { todayDrill, currentState, grade, error } = useSelector((s: RootState) => s.coding);

  useEffect(() => {
    dispatch(fetchTodayDrill());
    return () => { dispatch(resetSession()); };
  }, [dispatch]);

  const renderContent = () => {
    switch (currentState) {
      case 'idle':
        return <ActivityIndicator size="large" />;
      case 'brief':
        return <DrillBriefScreen />;
      case 'input':
        if (todayDrill?.drill_subtype === 'prompt') return <PromptDrillInputScreen />;
        if (todayDrill?.drill_subtype === 'verify') return <VerifyDrillInputScreen />;
        if (todayDrill?.drill_subtype === 'decompose') return <DecomposeDrillInputScreen />;
        return <Text>Unsupported drill</Text>;
      case 'submitting':
        return <DrillSubmittingScreen />;
      case 'result':
        return <DrillResultScreen onDone={() => navigation.goBack()} />;
      case 'error':
        return <Text>{error}</Text>;
      default:
        return null;
    }
  };

  return <View style={styles.container}>{renderContent()}</View>;
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
});
```

- [ ] **Step 2: DrillBriefScreen + the 3 per-subtype input screens** (similar structure to iOS, adapted to RN — ScrollView + TextInput + Pressable buttons)

Each screen reads from `state.coding.todayDrill` and dispatches `startDrill` (brief screen) or `submitDrillAndPoll` (input screens).

- [ ] **Step 3: BugLocationRow component for Verify**

```tsx
export default function BugLocationRow({ location, onChange, onDelete }) {
  return (
    <View style={styles.row}>
      <View style={styles.fileLineRow}>
        <TextInput
          placeholder="file"
          value={location.file}
          onChangeText={f => onChange({ ...location, file: f })}
          style={styles.fileInput}
        />
        <TextInput
          placeholder="line"
          value={String(location.line || '')}
          onChangeText={l => onChange({ ...location, line: parseInt(l, 10) || 0 })}
          keyboardType="number-pad"
          style={styles.lineInput}
        />
        <Pressable onPress={onDelete}>
          <Text style={styles.deleteBtn}>×</Text>
        </Pressable>
      </View>
      <TextInput
        placeholder="Explain the bug…"
        value={location.explanation}
        onChangeText={e => onChange({ ...location, explanation: e })}
        multiline
        style={styles.explanationInput}
      />
    </View>
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add src/features/coding/screens src/features/coding/components/BugLocationRow.tsx
git commit -m "feat(coding/android): drill modal + brief + 3 input screens"
```

---

### Task UI-C3: Submitting + Result + Calibration screens

**Files to create:**
- `src/features/coding/screens/DrillSubmittingScreen.tsx`
- `src/features/coding/screens/DrillResultScreen.tsx`
- `src/features/coding/screens/CalibrationSequenceScreen.tsx`
- `src/features/coding/screens/CalibrationResultScreen.tsx`
- `src/features/coding/components/RubricBar.tsx`

**Steps:**

- [ ] Implementation follows iOS shape, with RN primitives. RubricBar uses `Animated.View` for the bar width animation.

- [ ] Commit:

```bash
git add src/features/coding/screens/Drill{Submitting,Result}Screen.tsx src/features/coding/screens/Calibration*.tsx src/features/coding/components/RubricBar.tsx
git commit -m "feat(coding/android): submitting + result + calibration screens"
```

---

### Task UI-C4: Home wiring + analytics

**Files to create:**
- `src/features/coding/components/CodingDrillCard.tsx`
- `src/features/coding/services/drillAnalytics.ts`

**Files to modify:**
- `src/screens/HomeScreen.tsx` (or whatever the V1-equivalent home is — locate via grep)
- `src/navigation/AppNavigator.tsx` (register DrillModalScreen + CalibrationSequenceScreen)

**Steps:**

- [ ] Add the modal screens to the root stack with `presentation: 'modal'`.
- [ ] CodingDrillCard fetches today's drill on mount, renders the card OR calibration prompt OR nothing.
- [ ] Wire into HomeScreen below the existing hero.
- [ ] Analytics events mirror iOS — same event names + properties for cross-platform consistency.

```bash
git add src/features/coding/components/CodingDrillCard.tsx src/features/coding/services/drillAnalytics.ts src/screens/HomeScreen.tsx src/navigation/AppNavigator.tsx
git commit -m "feat(coding/android): Home card + nav wiring + Mixpanel analytics"
```

---

### Task UI-C5: Internal Track release

**Files to modify:**
- `android/app/build.gradle` — bump `versionCode` and `versionName`
- `package.json` — bump `version`

**Steps:**

- [ ] Bump versions
- [ ] Build release AAB:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid/android"
./gradlew bundleRelease
```

- [ ] Upload to Play Store Console → Internal Testing → upload AAB → save → release
- [ ] Commit version bump:

```bash
git add android/app/build.gradle package.json
git commit -m "chore(android): bump version for coding drill UI internal track"
git checkout main
git merge --no-ff feat/coding-practice-ui-android
git push origin main
```

---

## Workstream D — QA + Acceptance gates (3 tasks)

### Task UI-D1: Internal alpha smoke test (iOS)

**Process gate, not code.**

- [ ] Install latest TestFlight build on a real device (yours + 1-2 internal testers)
- [ ] Run through the full drill flow for each subtype: Home card → Drill modal → Brief → Input → Submit → Result. Each subtype once. ~15 min total.
- [ ] Run the calibration flow once on a fresh user (or reset MetaSkillMastery for your user in prod via mongosh, see playbook).
- [ ] Note any bugs, UX issues, or backend issues. File as `bug(coding/ios): ...` commits on the iOS branch and `bug(coding): ...` on backend.
- [ ] Pass criterion: full flow completes without P0/P1 issues. P2 (minor visual/copy) issues are acceptable and tracked for the next sprint.

### Task UI-D2: Internal alpha smoke test (Android)

Same as UI-D1 but on Android Internal Track. Same pass criterion.

### Task UI-D3: Performance + cost monitoring (1 week post-launch)

- [ ] Mixpanel dashboard: drill activation rate (% of eligible users who tap the card within 7 days)
- [ ] Mixpanel: drill completion rate (% of started drills that submit)
- [ ] Mixpanel: calibration completion rate (% of users who start calibration → finish all 3 drills)
- [ ] Backend: drill grader anchor-drift report (run `npm run openapi:contract-test` augmented with anchor-drift check)
- [ ] LLM cost report from `llmRouter` metrics — average $/drill grade vs estimate
- [ ] If completion rate < 50% or grader drift > 5%, file a `fix(coding): ...` issue and pause feature rollout to wider audience

---

## Self-review checklist

| Spec section | Covered |
|---|---|
| §2 Scope — Drills 4 types | 3 covered (refactor deferred per CTO decision); UI-A1 enforces backend |
| §3.1 Drill types | Prompt (UI-B3), Verify (UI-B4), Decompose (UI-B5) |
| §3.4 Difficulty | Shown in Brief view (UI-B2); recommended by Calibration (UI-B7) |
| §5 Difficulty calibration | Initial flow in UI-B7; adaptive recalibration was T26 (backend done) |
| §7.1 Drill flow | UI-B1 to UI-B6 cover the full state machine |
| §11 Backfill | Backend-only (T44 done); UI surfaces calibration card via UI-B8 |

**Placeholder scan:** the "what you missed" section in `DrillResultView` references a `what_you_missed` field that doesn't exist in the backend yet. UI-B6 acknowledges this in a comment with a placeholder UI. **Backend follow-up needed** to populate this — adds richness in v2.

**Type consistency:** `DrillSubtype` enum, `BugLocation` struct, `DecompositionStep` struct, `DrillSubmissionPayload` enum, `DrillGrade` struct — all defined once in Models, used everywhere.

**Scope:** Phase A iOS + Android. Refactor drill + Capstones (web IDE) intentionally out of scope (Phase B).

---

## Execution handoff

After this plan is reviewed and approved, two execution options:

**1. Subagent-Driven (recommended)** — Same pattern as backend work: dispatch fresh subagent per task with full context, two-stage review (spec + code quality), no context pollution.

**2. Inline execution** — Execute tasks in this session with checkpoints. Faster iteration; burns context.

Recommend Subagent-Driven for iOS (T31-T38 = 9 tasks, each substantial). Android can go either way given it's largely mirroring iOS structure.
