# "Next Step" Loop — Implementation Plan (iOS-first)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Every insight screen ends with a single "Do this next →" card that names the user's biggest gap and routes them straight into the fix — turning ~9 dead-end screens into action loops. Plus: explain the interview's 4 sub-scores in plain English (#5).

**Architecture:** One reusable `NextStepCard` view + one global `NextStepCoordinator` that decouples the card from each screen's presentation context. A screen's card fires a typed *intent* (`launchQuiz(topic:)`, `launchDrill(subtype:)`, `tutorOn(topic:)`, `openPlan`, `reviewQuiz(quizId:)`, `startInterview`) and dismisses itself; the app root (`V2MainTabView`) observes the coordinator and performs the real navigation. This avoids sheet-over-sheet breakage and works uniformly whether a screen is a sheet, a fullScreenCover, a NavigationStack push, or a Compass card.

**Tech stack:** SwiftUI, Swift 6 strict concurrency, xcodegen (folder-globbed — new files auto-include), `V2TaskRouter` (existing central router), `ColorTokens`/`V2Theme`/`PrimaryButton` (existing design system).

**Verify:** `/opt/homebrew/bin/xcodegen generate && xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug -derivedDataPath /tmp/scaleup_dd build CODE_SIGNING_ALLOWED=NO`

---

## Phase 0 — Infrastructure (build + verify before any surface)

### Task 0.1: `NextStepCard` component
**File:** Create `ScaleUp/Features/V2/Components/NextStepCard.swift`
- Gold-tinted card: `ColorTokens.gold.opacity(0.08)` bg + `ColorTokens.gold.opacity(0.3)` 1px stroke, radius 14, padding 16.
- Contents: eyebrow `"NEXT STEP"` (`.v2Eyebrow()`), insight line (`V2Theme.bodyMedium`, `textSecondary` with the gap name in `textPrimary`/gold), then a `PrimaryButton(title:icon:action:)`.
- API: `NextStepCard(insight: AttributedString or (lead:String, highlight:String), actionTitle: String, actionIcon: String? = "arrow.right", action: @escaping () -> Void, secondary: (title:String, action:()->Void)? = nil)`.
- Pure presentational — no navigation knowledge.

### Task 0.2: `NextStepCoordinator` + intents
**File:** Create `ScaleUp/Features/V2/Core/NextStepCoordinator.swift`
- `@Observable @MainActor final class NextStepCoordinator` (singleton `.shared`, also injectable).
- `enum Intent: Equatable { case launchQuiz(topic: String), launchDrill(subtype: String?), tutorOn(topic: String), openPlan, reviewQuiz(quizId: String), startInterview }`
- `var pending: Intent?` + `func fire(_ intent: Intent)`.
- Helper on call sites: `fire` then the screen `dismiss()`es itself.

### Task 0.3: Root handler (intent → navigation)
**File:** Modify `ScaleUp/Features/V2/Core/V2MainTabView.swift`
- Observe `NextStepCoordinator.shared.pending`; `.onChange`, after the active sheet dismisses, translate each intent into existing navigation:
  - `.launchQuiz(topic)` → `taskRouter.route = .quizByTopic(topic: topic, weekNumber: nil)`
  - `.startInterview` → `taskRouter.route = .interview(scenarioId: nil)`
  - `.reviewQuiz(id)` → present `QuizResultsView(quizId: id, attempt: nil)` (add `.quizResultsReview(quizId:)` route case to `V2TaskRouter` + handle in `V2TaskSheet`)
  - `.launchDrill(subtype)` → present `V2CodingDrillRequestView` (add `preselectedSubtype` init param) via a new `.codingDrill(subtype:)` route case
  - `.tutorOn(topic)` → `nav.selectedTab = .you`? No — present `V2CompassSheetView(coachContext: .init(scope: .topic, topic: topic))`; add `.topicTutor(topic:)` route case
  - `.openPlan` → `nav.selectedTab = .you` + a `V2NavState` flag `openPlanOnAppear` that `V2YouView` consumes to push `V2PlanDetailView()`
- Clear `pending` after handling.

### Task 0.4: Router case additions
**File:** Modify `ScaleUp/Features/V2/Core/V2TaskRouter.swift` + `V2TaskSheet`
- Add `Route` cases: `.codingDrill(subtype: String?)`, `.topicTutor(topic: String)`, `.quizResultsReview(quizId: String)`. Wire each in `V2TaskSheet` to present the right view.

**✅ Verify build green after Phase 0.**

---

## Phase 1 — Prove the pattern end-to-end on Quiz Results (highest-traffic)

### Task 1.1: Quiz Results "Next Step" card
**File:** Modify `ScaleUp/Features/Quiz/Views/QuizResultsView.swift`
- Compute the gap: `viewModel.analysis?.missedConcepts?.first?.concept` ?? `viewModel.topicBreakdown.min(by: { $0.percentage < $1.percentage })?.topic` ?? `viewModel.analysis?.weaknesses?.first`.
- Insert a `NextStepCard` directly above `bottomActions`:
  - If a missed concept with `contentId` exists → adaptive: low overall score → "Fix your weakest concept: {X}" → existing `navigateToContentId` deeplink; else "Practice {weakTopic}" → `NextStepCoordinator.shared.fire(.launchQuiz(topic: weakTopic))` then dismiss.
- Keep the existing generic buttons below (demoted visually if needed).

**✅ Verify build green. This proves card + coordinator + root navigation end-to-end before scaling.**

---

## Phase 2 — Remaining 8 surfaces (one task each; gap-fields confirmed in exploration)

For each: insert `NextStepCard` at the documented insertion point, compute the gap from the named field, fire the intent.

- [ ] **2.1 Diagnostic Results** — `DiagnosticResultsView.swift`; gap = `focusTopic?.displayName`/`.canonicalName` (computed var exists); card after `seePlanButton`; intent `.launchQuiz(topic: focusTopic.canonicalName)` ("Start with {focusTopic}").
- [ ] **2.2 Recalibration Results** — `RecalibrationResultsView.swift`; gap = `recalibrationGrowth.newGaps.first` ?? `growthBars.min(by:{$0.newScore<$1.newScore}).canonicalName`; card in `planRebalanceSection`; intent `.launchQuiz(topic:)`.
- [ ] **2.3 Analytics Mastery Map** — `V2YouAnalyticsView.swift`; gap = `a.weaknesses.first` ?? `entries.sorted{$0.score<$1.score}.first.topic`; card before final Spacer; intent `.launchQuiz(topic:)`.
- [ ] **2.4 Readiness Breakdown** — `V2ReadinessBreakdownSheet.swift`; gap = `assessed.min(by:{$0.score<$1.score}).name`; card after last `competencySection`; intent `.launchQuiz(topic:)`.
- [ ] **2.5 Interview Results (#1)** — `InterviewResultsView.swift`; gap = lowest of `evaluation.{communication,content,structure,confidence}.score`; card before "Back to Profile"; intent `.openPlan` ("Add {weakDim} practice this week") or `.startInterview` ("Redo after practice").
- [ ] **2.6 Interview Results (#5 score explainers)** — same file; add a one-line plain-English definition under each of the 4 sub-scores, tied to interview type (e.g. "Confidence = steady pace + directness"). Static copy map.
- [ ] **2.7 Coding Drill Result** — `DrillResultView.swift`; gap = `grade.rubricBreakdown.min(by:{$0.score<$1.score}).dimension`; card after `whatYouMissedSection`; intent `.launchDrill(subtype: weakAxis)` ("Practice {axis} again").
- [ ] **2.8 Capstone Result** — `CapstoneResultView.swift`; gap = `result.gaps.first` ?? weakest `dimensionRows`; card before `actionButtons`; intent `.launchDrill(subtype:)` ("Drill your weakest area").
- [ ] **2.9 Live-Event Results** — `LiveEventResultsView.swift`; no sub-gap data → use `topic`; promote a "Review answers" action + card "Practice {topic}" → `.launchQuiz(topic:)`.
- [ ] **2.10 Compass Weak-Topics Card** — `CompassCardViews.swift`; make each `CompassWeakTopic` row tappable → `.launchQuiz(topic: row.topic)` or `.tutorOn(topic:)` (Compass already has router access — may not need the coordinator).

**✅ Verify build green after Phase 2.**

---

## Phase 3 — Polish + parity
- [ ] Full build-verify; manual smoke (simulator) of 2-3 key flows (quiz result → quiz launches; drill result → drill launches).
- [ ] Android parity: port `NextStepCard` + the same intents/surfaces to `ScaleUpAndroid` (RN), reusing the existing `V2TaskRouterStore` (which already has most routes).

## Notes / risks
- **Sheet-over-sheet timing:** the coordinator must navigate only AFTER the current sheet finishes dismissing. Use the intent-pending + root-onChange pattern; if a race appears, add a one-runloop delay in the root handler.
- **Router scope:** screens outside the V2 environment (Quiz/Interview/Coding/Competition/Diagnostic results) rely on the coordinator singleton, NOT direct `taskRouter` access — that's the whole point of the coordinator.
- **Strict concurrency:** coordinator is `@MainActor`; intents are value types.
