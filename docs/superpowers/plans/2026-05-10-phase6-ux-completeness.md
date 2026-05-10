# Phase 6 — UX Completeness

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close UX gaps surfaced after Phase 5: skip-assessment plan tab, home banner during plan generation, topic-aware home recommendations from day 1, redesigned interview as ONE weekly objective-level task with adaptive topic weighting. Plus: run the Phase 2 backfill against prod.

**Architecture summary:**
- Backend `/plan/status` gains a `'no_diagnostic'` status; iOS+Android map it to a recoverable error card with "Start diagnostic" CTA
- Home tab gets a `<PlanGenerationBanner>` that polls `/plan/status` while the plan is being built; tap when ready jumps to Plan tab
- Backend planGenerationService emits ONE `ai_interview` task per week (not per topic per week), with `payload.scenario` derived from objective + role and `payload.topicWeights` for adaptive weighting
- `KnowledgeProfile` extends with `topicInterviewMastery` map; `interviewService.startInterview` accepts `topicWeights` and biases question selection; `planProgressService.onInterviewComplete` updates per-topic interview scores from `perQuestionEval`
- The Phase 2 backfill is run against prod (operator-coordinated)

**Spec:** Builds on `docs/superpowers/specs/2026-05-09-plan-tab-redesign-design.md`. The interview redesign supersedes Phase 3's per-topic emission rule. The diagnostic-incomplete state was defined in Phase 3 but never reached — Phase 6 wires it.

**Phase 1-5 prerequisite (all on master/main):**
- Backend: `42312b9`
- iOS: `d9a4cb9`
- Android: `7d4defb`

---

## File Structure

**Created:**
- (none — all changes touch existing files)

**Modified:**
- `scaleup-backend/src/controllers/planController.js` — `getStatus` returns `'no_diagnostic'` when no completed attempt exists
- `scaleup-backend/src/controllers/planController.test.js`
- `scaleup-backend/openapi.yaml` — document the new status enum value
- `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift` — handle `"no_diagnostic"` case
- `ScaleUp/Features/Plan/Views/PlanTabView.swift` — diagnostic-incomplete error path triggers diagnostic start
- `ScaleUpAndroid/src/screens/plan/PlanTabScreen.tsx` — same Android handling
- `ScaleUp/Features/Home/Views/HomeView.swift` — render `PlanGenerationBanner`
- `ScaleUp/Features/Home/Views/Components/PlanGenerationBanner.swift` — NEW
- `ScaleUpAndroid/src/screens/home/HomeScreen.tsx` — same banner mirror
- `ScaleUpAndroid/src/screens/home/components/PlanGenerationBanner.tsx` — NEW
- `scaleup-backend/src/services/diagnostic/planGenerationService.js` — emit ONE ai_interview task per WEEK (not per allocation), with topicWeights
- `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`
- `scaleup-backend/src/models/KnowledgeProfile.js` — add `topicInterviewMastery` map
- `scaleup-backend/src/services/interviewService.js` — accept `topicWeights` param, use it for question prompt
- `scaleup-backend/src/services/plan/planProgressService.js` — `onInterviewComplete` updates `topicInterviewMastery` from session.perQuestionEval
- `scaleup-backend/src/services/plan/planProgressService.test.js`

---

## Task 1 — Skip-assessment plan tab UX (#6)

**Files:**
- Modify: `scaleup-backend/src/controllers/planController.js`
- Modify: `scaleup-backend/src/controllers/planController.test.js`
- Modify: `scaleup-backend/openapi.yaml`
- Modify: `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift`
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift`
- Modify: `ScaleUpAndroid/src/screens/plan/PlanTabScreen.tsx`

**Steps:**

- [ ] **Step 1: Backend — extend `getStatus`**

In `scaleup-backend/src/controllers/planController.js`, find the existing `getStatus` function. Today it returns `'pending'` when no `DiagnosticAttempt` exists. Differentiate:

```javascript
async function getStatus(req, res) {
  const userId = req.user.userId;
  const activePlan = await Plan.findOne({ userId, isActive: true })
    .sort({ updatedAt: -1 })
    .lean();
  if (activePlan) {
    return res.status(200).json(apiResponse.success({
      status: 'ready',
      planId: String(activePlan._id),
      source: activePlan.source,
      updatedAt: activePlan.updatedAt,
    }));
  }
  const latestAttempt = await DiagnosticAttempt.findOne({ userId, status: 'completed' })
    .sort({ completedAt: -1 })
    .select('planGenerationStatus planId')
    .lean();
  if (!latestAttempt) {
    // No completed diagnostic at all → user must take the diagnostic before a plan can exist.
    return res.status(200).json(apiResponse.success({ status: 'no_diagnostic', planId: null }));
  }
  return res.status(200).json(apiResponse.success({
    status: latestAttempt.planGenerationStatus || 'pending',
    planId: latestAttempt.planId ? String(latestAttempt.planId) : null,
  }));
}
```

- [ ] **Step 2: Test the new branch**

Add to `scaleup-backend/src/controllers/planController.test.js`:

```javascript
test('getStatus: returns no_diagnostic when no completed attempt exists', async () => {
  const origPlanFind = Plan.findOne;
  Plan.findOne = () => ({ sort: () => ({ lean: async () => null }) });
  const origAttemptFind = DiagnosticAttempt.findOne;
  DiagnosticAttempt.findOne = () => ({ sort: () => ({ select: () => ({ lean: async () => null }) }) });

  let captured;
  const res = { status: () => res, json: (b) => { captured = b; return res; } };
  const req = { user: { userId: new mongoose.Types.ObjectId().toString() } };

  try {
    await getStatus(req, res);
    assert.strictEqual(captured.success, true);
    assert.strictEqual(captured.data.status, 'no_diagnostic');
    assert.strictEqual(captured.data.planId, null);
  } finally {
    Plan.findOne = origPlanFind;
    DiagnosticAttempt.findOne = origAttemptFind;
  }
});
```

Run: `cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/controllers/planController.test.js` — expect all pass.

- [ ] **Step 3: Update OpenAPI**

In `openapi.yaml`, find the `PlanStatus` schema (or wherever the status enum is). Add `'no_diagnostic'` to the enum values. Run `npm run openapi:lint` to confirm 0 errors.

- [ ] **Step 4: iOS — handle the new status**

Edit `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift`. The existing switch handles `"ready"`, `"completed"`, `"generating"`, `"pending"`, `"failed"`. Add:

```swift
            case "no_diagnostic":
                loadState = .error(.diagnosticIncomplete, "Take your 7-minute diagnostic to unlock your personalized plan.")
                AnalyticsService.shared.track(.planGenerationFallback(reason: "no_diagnostic"))
```

- [ ] **Step 5: iOS — error card CTA changes by kind**

In `ScaleUp/Features/Plan/Views/PlanTabView.swift`, find the `errorState(kind:message:)` helper. Change the button to switch on kind:

```swift
            // After the message Text, replace the existing PrimaryButton with:
            switch kind {
            case .diagnosticIncomplete:
                PrimaryButton(title: "Start diagnostic") {
                    presentingDiagnostic = true  // or whatever pattern Home uses to launch diagnostic
                }
            case .planGenerationFailed, .loadFailed:
                PrimaryButton(title: "Try again") {
                    Task { await viewModel.retry() }
                }
            }
```

Add the state var to `PlanTabView`:

```swift
@State private var presentingDiagnostic = false
```

And the `.fullScreenCover`:

```swift
.fullScreenCover(isPresented: $presentingDiagnostic) {
    DiagnosticContainerView()
        .environment(appState)  // adapt to whatever environment Home uses
}
```

If `DiagnosticContainerView()` requires more env objects, mirror what `HomeView.swift:87` does (already wires diagnostic).

Parse-check, commit:
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcrun swiftc -parse ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift ScaleUp/Features/Plan/Views/PlanTabView.swift 2>&1 | tail -10
git add ScaleUp/Features/Plan/
```

- [ ] **Step 6: Android — same**

In `src/screens/plan/PlanTabScreen.tsx`, the existing `loadPlan` switches on `status.status`. Add the `no_diagnostic` branch:

```typescript
if (status.status === 'no_diagnostic') {
  setScreenState('error')
  setErrorKind('diagnosticIncomplete')
  setErrorMsg('Take your 7-minute diagnostic to unlock your personalized plan.')
  return
}
```

Add `'diagnosticIncomplete'` to the `ErrorKind` union:
```typescript
type ErrorKind = 'loadFailed' | 'planGenerationFailed' | 'diagnosticIncomplete'
```

Update the error UI block — branch the headline AND the button label/action by kind:

```typescript
if (screenState === 'error') {
  const headline = errorKind === 'planGenerationFailed' ? "We couldn't build your plan"
    : errorKind === 'diagnosticIncomplete' ? "Your diagnostic isn't done yet"
    : "Couldn't load your plan"
  const buttonLabel = errorKind === 'diagnosticIncomplete' ? 'Start diagnostic' : 'Try again'
  const buttonAction = errorKind === 'diagnosticIncomplete'
    ? () => navigation.navigate('Diagnostic' as never)  // or whatever the route is — verify
    : loadPlan
  return (
    /* existing JSX, replace PrimaryButton onPress with buttonAction and title with buttonLabel */
  )
}
```

Verify the diagnostic route name:
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && grep -n "name=\"Diagnostic\|navigate.*Diagnostic" src/navigation/AppNavigator.tsx src/navigation/MainTabNavigator.tsx 2>/dev/null | head -5
```

Use the actual route name found.

- [ ] **Step 7: Commit each side**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/controllers/planController.js src/controllers/planController.test.js openapi.yaml
git commit -m "feat(plan): /plan/status returns no_diagnostic when assessment skipped"

cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/
git commit -m "feat(ios-plan): no-diagnostic state shows Start diagnostic CTA"

cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git add src/screens/plan/PlanTabScreen.tsx
git commit -m "feat(android-plan): no-diagnostic state shows Start diagnostic CTA"
```

---

## Task 2 — Run Phase 2 backfill against prod (#10)

**Files:** None — operational task. The script already exists at `scripts/migrate/backfillPlanTasks.js`.

**Steps:**

- [ ] **Step 1: Local dry-run sanity**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
# Verify the script is the version shipped in Phase 2:
git log --oneline -- scripts/migrate/backfillPlanTasks.js | head -3
# Try a syntax/load check:
node -c scripts/migrate/backfillPlanTasks.js && echo "syntax ok"
```

- [ ] **Step 2: Operator coordination — STOP HERE FOR USER**

This step requires SSH access to the prod EC2 box. Print this block for the user:

```
To run the backfill against prod:

ssh -i ~/.ssh/scaleup-backend-key.pem ubuntu@15.207.72.150
cd <backend repo path on EC2>
git pull origin master  # ensure script is present
node scripts/migrate/backfillPlanTasks.js --dry-run | tail -20
# If output looks reasonable (seen=N touched=M tasks=T):
node scripts/migrate/backfillPlanTasks.js | tail -20
# Spot-check by running this in mongosh against the prod DB:
mongosh "$MONGODB_URI" --eval "db.plans.findOne({isActive:true},{weeklySchedule:{tasks:1}})"
```

The implementer subagent should NOT run this — return BLOCKED with status "operator coordination required" and the instructions above. The user runs it manually.

---

## Task 3 — Home banner during plan generation (#4, iOS)

**Files:**
- Create: `ScaleUp/Features/Home/Views/Components/PlanGenerationBanner.swift`
- Modify: `ScaleUp/Features/Home/Views/HomeView.swift`

**Behavior:** Polls `/plan/status` every 5s while the user has any non-ready state. When state is `'generating'` or `'pending'`, shows a slim banner with a thin animated progress bar. When state flips to `'ready'`, banner morphs into a gold "Your plan is ready 🎉 [View →]" CTA. Tapping switches to the Plan tab. Banner is dismissable while in the "ready" state (after view).

**Steps:**

- [ ] **Step 1: Create the component**

Create `ScaleUp/Features/Home/Views/Components/PlanGenerationBanner.swift`:

```swift
import SwiftUI

@MainActor
@Observable
final class PlanGenerationBannerViewModel {
    enum State { case hidden, generating, ready }
    var state: State = .hidden
    var planId: String?

    private var pollTask: Task<Void, Never>?
    private let service = PlanService.shared

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !(Task.isCancelled) {
                guard let self else { return }
                do {
                    let status = try await self.service.fetchStatus()
                    switch status.status {
                    case "ready", "completed":
                        self.state = .ready
                        self.planId = status.planId
                        return  // stop polling once ready
                    case "generating", "pending":
                        self.state = .generating
                    case "no_diagnostic", "failed":
                        self.state = .hidden
                        return
                    default:
                        self.state = .hidden
                    }
                } catch {
                    // transient error — keep polling
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5s
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func dismiss() {
        state = .hidden
        stopPolling()
    }
}

struct PlanGenerationBanner: View {
    @State private var viewModel = PlanGenerationBannerViewModel()
    let onTapReady: () -> Void

    var body: some View {
        Group {
            switch viewModel.state {
            case .hidden:
                EmptyView()
            case .generating:
                generatingView
            case .ready:
                readyView
            }
        }
        .task { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
    }

    private var generatingView: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(ColorTokens.gold)
            Text("Building your personalized plan…")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorTokens.surface.opacity(0.5))
        )
        .padding(.horizontal, Spacing.lg)
    }

    private var readyView: some View {
        Button(action: { viewModel.dismiss(); onTapReady() }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("Your plan is ready 🎉")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Text("View →")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.gold.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ColorTokens.gold.opacity(0.30), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
```

- [ ] **Step 2: Wire into HomeView**

In `ScaleUp/Features/Home/Views/HomeView.swift`, find the top of the home content scroll (after the header / above the first content section). Insert:

```swift
PlanGenerationBanner(onTapReady: {
    // Switch to Plan tab. The exact API depends on how the app routes tabs.
    // Typically: appState.selectedTab = .plan  OR  rootRouter.selectTab(.plan)
    appState.switchToTab(.plan)  // adapt to actual tab-switch API
})
```

Find how Home triggers tab switches today. Likely `appState` (`@Environment(AppState.self)` or similar) — inspect:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && grep -n "@Environment\|selectedTab\|switchTo" ScaleUp/App/AppState.swift ScaleUp/Features/Home/Views/HomeView.swift 2>/dev/null | head -10
```

If there's no clean tab-switch API, post a `NotificationCenter.default.post(name: .planTabRequested, object: nil)` and have the root tab observer switch. Or hand off the simplest path that works.

- [ ] **Step 3: Parse-check, commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcrun swiftc -parse ScaleUp/Features/Home/Views/Components/PlanGenerationBanner.swift ScaleUp/Features/Home/Views/HomeView.swift 2>&1 | tail -10
git add ScaleUp/Features/Home/
git commit -m "feat(ios-home): plan-generation banner polls status, morphs to ready CTA"
```

---

## Task 4 — Home banner during plan generation (#4, Android)

**Files:**
- Create: `src/screens/home/components/PlanGenerationBanner.tsx`
- Modify: `src/screens/home/HomeScreen.tsx`

**Steps:**

- [ ] **Step 1: Create the banner**

```tsx
// src/screens/home/components/PlanGenerationBanner.tsx
import React, {useEffect, useRef, useState} from 'react'
import {View, Text, StyleSheet, TouchableOpacity, ActivityIndicator} from 'react-native'
import Icon from 'react-native-vector-icons/Ionicons'
import {Colors, Spacing, CornerRadius} from '../../../theme'
import {PlanService} from '../../../services/planService'

type State = 'hidden' | 'generating' | 'ready'

interface Props {
  onTapReady: () => void
}

export const PlanGenerationBanner: React.FC<Props> = ({onTapReady}) => {
  const [state, setState] = useState<State>('hidden')
  const pollIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  useEffect(() => {
    const tick = async () => {
      try {
        const s = await PlanService.fetchStatus()
        switch (s.status) {
          case 'ready':
          case 'completed':
            setState('ready')
            if (pollIntervalRef.current) {
              clearInterval(pollIntervalRef.current)
              pollIntervalRef.current = null
            }
            return
          case 'generating':
          case 'pending':
            setState('generating')
            return
          case 'no_diagnostic':
          case 'failed':
            setState('hidden')
            if (pollIntervalRef.current) clearInterval(pollIntervalRef.current)
            return
          default:
            setState('hidden')
        }
      } catch {
        // transient — keep polling
      }
    }
    tick()
    pollIntervalRef.current = setInterval(tick, 5000)
    return () => {
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current)
    }
  }, [])

  if (state === 'hidden') return null

  if (state === 'generating') {
    return (
      <View style={styles.generating}>
        <ActivityIndicator size="small" color={Colors.gold} />
        <Text style={styles.generatingText}>Building your personalized plan…</Text>
      </View>
    )
  }

  return (
    <TouchableOpacity style={styles.ready} onPress={() => { setState('hidden'); onTapReady() }} activeOpacity={0.85}>
      <Icon name="sparkles" size={14} color={Colors.gold} />
      <Text style={styles.readyTitle}>Your plan is ready 🎉</Text>
      <View style={{flex: 1}} />
      <Text style={styles.readyCta}>View →</Text>
    </TouchableOpacity>
  )
}

const styles = StyleSheet.create({
  generating: {
    flexDirection: 'row', alignItems: 'center', gap: Spacing.sm,
    paddingHorizontal: Spacing.md, paddingVertical: Spacing.sm,
    marginHorizontal: Spacing.lg,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderRadius: CornerRadius.medium,
  },
  generatingText: { color: Colors.textSecondary, fontSize: 13 },
  ready: {
    flexDirection: 'row', alignItems: 'center', gap: Spacing.sm,
    paddingHorizontal: Spacing.md, paddingVertical: Spacing.sm,
    marginHorizontal: Spacing.lg,
    backgroundColor: 'rgba(232,184,75,0.10)',
    borderColor: 'rgba(232,184,75,0.30)', borderWidth: 1,
    borderRadius: CornerRadius.medium,
  },
  readyTitle: { color: Colors.gold, fontSize: 14, fontWeight: '700' },
  readyCta: { color: Colors.gold, fontSize: 12 },
})
```

- [ ] **Step 2: Wire into HomeScreen**

In `src/screens/home/HomeScreen.tsx`, near the top of the rendered content (above the first content section), insert:

```tsx
<PlanGenerationBanner onTapReady={() => navigation.navigate('MyPlan' as never)} />
```

Add the import. Verify the tab name `'MyPlan'` matches what's in `MainTabNavigator.tsx` (per earlier recon, that's correct).

- [ ] **Step 3: TypeScript check, commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
npx tsc --noEmit 2>&1 | grep -E "src/screens/home" | head -5
git add src/screens/home/
git commit -m "feat(android-home): plan-generation banner polls status, morphs to ready CTA"
```

---

## Task 5 — Interview redesign: ONE per week, objective-level, adaptive (#2 + #5)

This is the largest piece. Has 4 sub-steps that span backend.

**Files:**
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.js`
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`
- Modify: `scaleup-backend/src/models/KnowledgeProfile.js`
- Modify: `scaleup-backend/src/services/interviewService.js`
- Modify: `scaleup-backend/src/services/plan/planProgressService.js`
- Modify: `scaleup-backend/src/services/plan/planProgressService.test.js`

**Steps:**

- [ ] **Step 1: Generator — ONE ai_interview task per WEEK**

In `planGenerationService.js`, the existing post-processor emits `ai_interview` per allocation. Move it OUT of the allocation loop and into the WEEK loop.

Find the existing block (Phase 3 Task 1):
```javascript
// ai_interview — gated on interview-style objectives
const interviewObjectives = ['interview_preparation', 'career_switch'];
const emitsInterview = interviewObjectives.includes(input.objectiveType);
if (emitsInterview) { ... tasks.push({ type: 'ai_interview', topic: topicShape, ... }); }
```

Delete the block from inside the per-allocation loop. After the for loop closes (still inside the per-week loop, AFTER all per-allocation work), insert:

```javascript
    // Phase 6: ONE ai_interview task per WEEK at the objective level (not per topic).
    // Gated on objectives that genuinely call for interview practice.
    const isInterviewQualified = (() => {
      const t = input.objectiveType;
      if (t === 'interview_preparation') return true;
      // career_switch only if specifics indicate active interview prep (target role set,
      // timeline ≤ 16 weeks). Long-tail career switches don't need a behavioral interview yet.
      if (t === 'career_switch') {
        const hasTargetRole = !!input.specificsCanonical?.targetRole;
        const wks = Number(input.timeline) || 0;
        return hasTargetRole && wks > 0 && wks <= 16;
      }
      return false;
    })();

    if (isInterviewQualified) {
      const targetRoleLower = String(input.specificsCanonical?.targetRole || '').toLowerCase();
      // Scenario rule:
      let scenario = 'placement_behavioral';
      if (input.objectiveType === 'interview_preparation' && /mba|admissions/.test(targetRoleLower)) {
        scenario = 'mba_admissions';
      } else if (/engineer|developer|sde|backend|frontend|fullstack|data\b|ml\b|ai\b/.test(targetRoleLower)) {
        // Alternate technical/behavioral by week
        scenario = (week.week % 2 === 0) ? 'placement_technical' : 'placement_behavioral';
      } else if (/product manager|^pm\b|growth|strategy|consulting|case/.test(targetRoleLower)) {
        scenario = (week.week % 2 === 0) ? 'case_study' : 'placement_behavioral';
      } else if (input.objectiveType === 'interview_preparation' && /(^|\b)hr|people|recruiter/.test(targetRoleLower)) {
        scenario = 'placement_hr';
      }

      // topicWeights: read from prior interview mastery if available, else seed equal weight.
      // Phase 6 leaves the weights blank at gen-time — interviewService.startInterview computes
      // weights at start-time using the latest KnowledgeProfile, since plan-gen happens once
      // but interview scheduling reads live data.
      const topicHints = (week.allocations || []).map(a => a.topicCanonicalName).slice(0, 6);

      tasks.push({
        type: 'ai_interview',
        topic: { canonicalName: '_objective', displayName: 'Mock interview' },
        payload: {
          scenario,
          estimatedMinutes: 15,
          topicHints, // weeks's allocation topics — used as starting candidates for question selection
        },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      });
    }
```

(Note `topic.canonicalName: '_objective'` is a sentinel — the matcher in `planProgressService.onInterviewComplete` will treat objective-level tasks specially.)

- [ ] **Step 2: Update tests for the new shape**

The old Phase 3 test asserted "every topic gets ai_interview when objectiveType qualifies". Replace with:

```javascript
test('generate: emits ONE ai_interview task per week (not per topic) for interview_preparation', async () => {
  process.env.FEATURE_EXTERNAL_CONTENT_JUDGE = 'false';
  // Stub LLM + catalog to return predictable output
  const planService = require('./planGenerationService');
  const mongoose = require('mongoose');
  const openai = require('../../config/openai');
  const origCreate = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('test stub'); };
  const taskCatalogService = require('../plan/taskCatalogService');
  const origResolve = taskCatalogService.resolveTopic;
  taskCatalogService.resolveTopic = async () => ({ quizId: 'q', quizMinutes: 8, contentId: 'c', contentType: 'article', contentMinutes: 12 });

  try {
    const out = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'interview_preparation',
      specificsCanonical: { targetRole: 'product manager' },
      timeline: 4, weeklyCommitHours: 5,
      topicResults: [
        { canonicalName: 'a', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false },
        { canonicalName: 'b', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false },
      ],
    });
    // Each week should have exactly 1 ai_interview task
    for (const w of out.weeklySchedule) {
      const interviewTasks = w.tasks.filter(t => t.type === 'ai_interview');
      assert.strictEqual(interviewTasks.length, 1, `week ${w.week} should have 1 ai_interview, got ${interviewTasks.length}`);
      assert.strictEqual(interviewTasks[0].topic.canonicalName, '_objective');
      assert.ok(interviewTasks[0].payload.topicHints.length > 0);
    }
    // Scenario alternates for PM role: even weeks case_study, odd weeks behavioral
    const w1 = out.weeklySchedule[0]; // week 1 (odd)
    const w2 = out.weeklySchedule[1]; // week 2 (even)
    assert.strictEqual(w1.tasks.find(t => t.type === 'ai_interview').payload.scenario, 'placement_behavioral');
    assert.strictEqual(w2.tasks.find(t => t.type === 'ai_interview').payload.scenario, 'case_study');
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
  }
});

test('generate: career_switch with no targetRole does NOT emit interview tasks', async () => {
  const planService = require('./planGenerationService');
  const mongoose = require('mongoose');
  const openai = require('../../config/openai');
  const origCreate = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('test stub'); };
  const taskCatalogService = require('../plan/taskCatalogService');
  const origResolve = taskCatalogService.resolveTopic;
  taskCatalogService.resolveTopic = async () => ({ quizId: 'q', contentId: null });

  try {
    const out = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'career_switch',
      specificsCanonical: {},  // no targetRole
      timeline: 4, weeklyCommitHours: 5,
      topicResults: [{ canonicalName: 'a', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false }],
    });
    for (const w of out.weeklySchedule) {
      assert.strictEqual(w.tasks.filter(t => t.type === 'ai_interview').length, 0);
    }
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
  }
});
```

The OLD Phase 3 ai_interview test ("emits ai_interview task only when objectiveType is interview_preparation or career_switch") may need adaptation — the new contract is "1 per week" not "1 per allocation". Update its expectations to match.

- [ ] **Step 3: KnowledgeProfile gets `topicInterviewMastery`**

In `scaleup-backend/src/models/KnowledgeProfile.js`, find the `topicMastery` array. Add a parallel field:

```javascript
  topicInterviewMastery: {
    type: Map,
    of: new mongoose.Schema({
      score: { type: Number, default: 0 },          // average score 0-10
      sessions: { type: Number, default: 0 },        // count
      lastScoredAt: { type: Date },
      trend: { type: String, enum: ['improving', 'stable', 'declining'], default: 'stable' },
      scoreHistory: [{
        score: Number,
        sessionId: mongoose.Schema.Types.ObjectId,
        scoredAt: Date,
      }],
    }, { _id: false }),
    default: () => new Map(),
  },
```

Note this is a Map keyed by topic canonicalName. Mongoose stores it as an embedded document.

- [ ] **Step 4: `planProgressService.onInterviewComplete` updates `topicInterviewMastery`**

Today, `onInterviewComplete` matches an `ai_interview` task by `topic.canonicalName === topic`. With the new contract, the plan task has `canonicalName: '_objective'` and the matcher needs to find ANY pending ai_interview in the current week (objective-level).

Update the function:

```javascript
async function onInterviewComplete({ userId, sessionId, topic, perQuestionEval }) {
  return withVersionRetry(
    () => Plan.findOne({ userId, isActive: true }).sort({ updatedAt: -1 }),
    async (plan) => {
      const startIdx = findCurrentWeekIndex(plan);
      if (startIdx === null) return { matched: false, reason: 'all_weeks_complete' };

      // New: match any pending ai_interview task in the current week — they're objective-level now
      let matched = null;
      let matchedWeek = null;
      for (let i = startIdx; i < plan.weeklySchedule.length; i++) {
        const week = plan.weeklySchedule[i];
        const t = (week.tasks || []).find(t => t.type === 'ai_interview' && t.progress?.status === 'pending');
        if (t) { matched = t; matchedWeek = week; break; }
      }
      if (!matched) return { matched: false, reason: 'no_matching_task' };

      const snap = snapshotProgress(matched);
      matched.progress.status = 'complete';
      matched.progress.completedAt = new Date();
      matched.progress.sourceEventId = String(sessionId);
      await saveWithRevert(plan, matched, snap);

      // Update topicInterviewMastery from per-question scores aggregated by concept/topic.
      try {
        if (Array.isArray(perQuestionEval) && perQuestionEval.length > 0) {
          const KnowledgeProfile = require('../../models/KnowledgeProfile');
          // Aggregate mean score per concept (topic). perQuestionEval entries have { questionNumber, question, answer, score, ... }.
          // The question generator should have annotated each with a `concept` field — fall back to 'general' if absent.
          const byConcept = {};
          for (const ev of perQuestionEval) {
            const c = canonicalize(ev.concept || 'general') || 'general';
            if (!byConcept[c]) byConcept[c] = { sum: 0, n: 0 };
            byConcept[c].sum += Number(ev.score) || 0;
            byConcept[c].n += 1;
          }
          const profile = await KnowledgeProfile.findOne({ userId });
          if (profile) {
            for (const [concept, agg] of Object.entries(byConcept)) {
              const newAvg = agg.sum / agg.n;
              const existing = profile.topicInterviewMastery.get(concept) || { score: 0, sessions: 0, scoreHistory: [], trend: 'stable' };
              const blended = (existing.score * existing.sessions + newAvg) / (existing.sessions + 1);
              const history = (existing.scoreHistory || []).concat([{ score: newAvg, sessionId, scoredAt: new Date() }]).slice(-20);
              const trend = computeTrend(history.map(h => h.score));
              profile.topicInterviewMastery.set(concept, {
                score: blended,
                sessions: existing.sessions + 1,
                lastScoredAt: new Date(),
                trend,
                scoreHistory: history,
              });
            }
            await profile.save();
          }
        }
      } catch (err) {
        console.warn('[planProgressService] topicInterviewMastery update failed:', err.message);
      }

      return { matched: true, planId: String(plan._id), weekNumber: matchedWeek.week, taskId: String(matched._id) };
    },
  );
}

function computeTrend(scores) {
  if (!scores || scores.length < 3) return 'stable';
  const recent = scores.slice(-3);
  const earlier = scores.slice(-6, -3);
  if (earlier.length === 0) return 'stable';
  const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
  const earlierAvg = earlier.reduce((a, b) => a + b, 0) / earlier.length;
  if (recentAvg - earlierAvg > 0.5) return 'improving';
  if (earlierAvg - recentAvg > 0.5) return 'declining';
  return 'stable';
}
```

The caller — `interviewService.js` line ~393 area, where Phase 3 wired `planProgressService.onInterviewComplete` — needs to ALSO pass `perQuestionEval`. Update that call:

```javascript
        await planProgressService.onInterviewComplete({
          userId: String(session.userId),
          sessionId: String(session._id),
          topic: session.targetRole || session.targetCompany || '',  // legacy — kept for back-compat
          perQuestionEval: session.evaluation?.perQuestionEval || [],
        });
```

- [ ] **Step 5: `interviewService.startInterview` accepts `topicWeights`**

Update `startInterview(userId, opts)` to accept `topicWeights` (an optional object `{topic: weight}`). When generating the system instruction, include topic-priority guidance:

```javascript
async startInterview(userId, { interviewType, targetRole, targetCompany, difficulty = 'moderate', objectiveId, topicWeights = null }) {
  // ... existing logic ...

  // Compute topicWeights from KnowledgeProfile.topicInterviewMastery if not provided.
  if (!topicWeights && objectiveId) {
    try {
      const KnowledgeProfile = require('../models/KnowledgeProfile');
      const profile = await KnowledgeProfile.findOne({ userId }).lean();
      if (profile?.topicInterviewMastery) {
        const weights = {};
        for (const [topic, m] of Object.entries(profile.topicInterviewMastery)) {
          // Inverse weighting: lower score → higher weight (more questions next time)
          // score 0-10. Weight: 4 if score<4, 2 if 4-7, 1 if >=7
          const s = m.score || 0;
          weights[topic] = s < 4 ? 4 : s < 7 ? 2 : 1;
        }
        topicWeights = weights;
      }
    } catch { /* fall back to no weighting */ }
  }

  // Build topic priority block for the system instruction
  let topicPriorityBlock = '';
  if (topicWeights && Object.keys(topicWeights).length > 0) {
    const sorted = Object.entries(topicWeights).sort((a, b) => b[1] - a[1]);
    topicPriorityBlock = `\nTOPIC PRIORITY for this session (weight = how many questions to ask):\n`
      + sorted.map(([t, w]) => `  - ${t}: ${w}`).join('\n')
      + `\nFocus more questions on higher-weighted topics. Topics not listed should appear at most once.`;
  }

  // Append topicPriorityBlock to the systemInstruction (before the existing TYPE_GUIDELINES)
  // Existing code:
  // const systemInstruction = `You are a professional ${typeLabel} interviewer ...`;
  // Replace its construction to include topicPriorityBlock.
```

The exact integration depends on `startInterview`'s current shape — read it first and slot the topic-priority block into the existing systemInstruction string at a sensible point.

- [ ] **Step 6: Test `topicInterviewMastery` update**

Add to `planProgressService.test.js`:

```javascript
test('onInterviewComplete: updates KnowledgeProfile.topicInterviewMastery from perQuestionEval', async () => {
  const KnowledgeProfile = require('../../models/KnowledgeProfile');
  let savedProfile = null;
  const fakeProfile = {
    userId: new mongoose.Types.ObjectId(),
    topicInterviewMastery: new Map(),
    save: async function () { savedProfile = this; return this; },
  };
  const origFind = KnowledgeProfile.findOne;
  KnowledgeProfile.findOne = () => fakeProfile;

  // Plan with one objective-level ai_interview task pending in week 1
  const plan = {
    _id: new mongoose.Types.ObjectId(),
    userId: fakeProfile.userId,
    weeklySchedule: [{
      week: 1, weeklyGoal: 'g', allocations: [],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'ai_interview',
        topic: { canonicalName: '_objective', displayName: 'Mock interview' },
        payload: { scenario: 'placement_behavioral', estimatedMinutes: 15 },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    save: async function () { return this; },
  };
  const origPlanFind = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    const out = await planProgressService.onInterviewComplete({
      userId: fakeProfile.userId.toString(),
      sessionId: 'sess-1',
      topic: 'product manager',
      perQuestionEval: [
        { questionNumber: 1, concept: 'stakeholder-management', score: 8 },
        { questionNumber: 2, concept: 'stakeholder-management', score: 6 },
        { questionNumber: 3, concept: 'roadmapping', score: 4 },
      ],
    });
    assert.strictEqual(out.matched, true);
    assert.ok(savedProfile, 'KnowledgeProfile.save should have been called');
    const sm = fakeProfile.topicInterviewMastery.get('stakeholder-management');
    assert.ok(sm);
    assert.strictEqual(sm.sessions, 1);
    assert.strictEqual(Math.round(sm.score), 7);  // (8+6)/2 = 7
    const rd = fakeProfile.topicInterviewMastery.get('roadmapping');
    assert.strictEqual(rd.sessions, 1);
    assert.strictEqual(rd.score, 4);
  } finally {
    Plan.findOne = origPlanFind;
    KnowledgeProfile.findOne = origFind;
  }
});
```

- [ ] **Step 7: Run all backend tests, commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
node --test src/services/plan/ src/services/diagnostic/planGenerationService.test.js src/controllers/planController.test.js src/models/ 2>&1 | tail -10
git add src/services/diagnostic/planGenerationService.js src/services/diagnostic/planGenerationService.test.js src/models/KnowledgeProfile.js src/services/interviewService.js src/services/plan/planProgressService.js src/services/plan/planProgressService.test.js
git commit -m "feat(plan): redesign ai_interview as 1-per-week objective-level + adaptive weighting"
```

---

## Task 6 — Phase 6 acceptance sweep

- [ ] Backend tests: `node --test src/...` — all pass
- [ ] OpenAPI: `npm run openapi:lint` — 0 errors
- [ ] iOS parse: all touched .swift files
- [ ] Android tsc: 0 errors in plan/home paths

No commit; sanity check only.

---

## What Phase 6 ships

- Skipping the diagnostic shows a clear "Start diagnostic" CTA on the Plan tab instead of an infinite spinner
- Day-1 users who navigate to Home see a banner confirming their plan is being built; banner morphs to a tap-to-open CTA when ready
- `ai_interview` tasks redesigned: ONE per week per qualifying objective, scenario derived from objective + role, with adaptive topic weighting from prior interview performance
- Phase 2 backfill executed against prod (operator-coordinated)
