# Rollback — Plan 3b Results & Insights Merge (2026-05-07)

This document captures rollback procedures for the three repos that received the Plan 3b (Results & Insights) merge on 2026-05-07. Use this if a regression is detected after merge.

## What was merged

| Repo | Branch merged | Pre-merge HEAD | Squash merge SHA | Pre-merge tag |
|---|---|---|---|---|
| Backend (`scaleup-backend` / `ScaleUpDemo-b`) | `feat/diagnostic-phase3b-results-insights` | `2bef58b` | `848be5f9fe5c985a5ff468b26daac5bf63303972` | `backup/pre-plan3b-2026-05-07` |
| iOS (`ScaleUpDemo-f`) | `feat/diagnostic-phase3b-results-insights` | `bc502cd` | `80079967ff8931e82a44445abcdc88fad9b44036` | `backup/pre-plan3b-2026-05-07` |
| Android (`ScaleUpDemo-f-Android`) | `feat/diagnostic-phase3b-results-insights` | `7fba57d` | `79377542129957a7528d3f8556a83819ea6c3049` | `backup/pre-plan3b-2026-05-07` |

## What lands in each repo

- **Backend:** Plan 3b Tasks 1–4. Pure calibration math utility; insights generation service (gpt-4o + json_schema strict + 15s timeout + deterministic template fallback); `finishAttemptV2` extended to use the calibration utility and run insights generation inline (foreground per spec §10.5) — V1 path untouched; `DiagnosticAttempt` schema gains `insightsJson` + `insightsStatus` + `insightsSource` + `insightsLatencyMs` + per-result `calibrationClass` (additive, defaults safe for V1); new endpoint `GET /diagnostic/:attemptId/results` returning the spec §12.2 shape.
- **iOS:** Plan 3b Tasks 5–10. `InsightsGeneratingView` (8-15s wait loader); `InsightCards.swift` (5 reusable cards + `DiagnosticTopicResult` DTO); `HeroStoryRevealView` (3-screen TabView story); `ShareableSummaryCardGenerator` (`ImageRenderer` + `UIActivityViewController`); 8 new typed `AnalyticsEvent` cases + `MixpanelDiagnostic` typed methods; **wholesale rewrite** of `DiagnosticResultsView` per spec §10.4 with new `DiagnosticResultsViewModel` polling the new GET endpoint (18s ceiling); `DiagnosticContainerView` updated to new init signature (navigation behavior unchanged).
- **Android:** Plan 3b Tasks 11–16. RN mirrors of iOS work. `InsightsGeneratingScreen`, `src/components/diagnostic/InsightCards.tsx` (5 components), `HeroStoryReveal` (react-native-pager-view), `ShareableSummaryCardGenerator` (react-native-view-shot offscreen capture + react-native-share system share sheet, host mounted at app root), 8 new typed `AnalyticsEvent` variants + `trackInsightsEvent` helper, **wholesale rewrite** of `ResultsScreen` per spec §10.4, `DiagnosticContainer` routes to it on `phase === 'results'`, `DiagnosticService.fetchDiagnosticResults` hits the new GET endpoint.

## Rollback procedures (in order of preference)

### Method 0 — Backend feature flag (FASTEST, no git, ~30s)

Plan 3b's backend changes only fire on the V2 codepath, which is gated by `FEATURE_DAY1_DIAGNOSTIC_V2`. The simplest rollback for backend regressions is **toggle the flag off** — no git revert required:

```bash
# On EC2 host
unset FEATURE_DAY1_DIAGNOSTIC_V2  # or set to anything other than 'true'
pm2 reload all
```

The new V2 codepaths (including insights generation in `finishAttemptV2` and the new GET endpoint's V2-shape result rows) stop being exercised. V1 logic — preserved byte-for-byte — takes over again. The new `GET /diagnostic/:attemptId/results` route is mounted unconditionally and continues to exist; if the regression is in the endpoint itself, use Method 1.

This is the first line of defense for any backend insights/results issue.

### Method 1 — `git revert` (RECOMMENDED for app regressions, non-destructive)

Creates a new commit that undoes the merge. Safe even after others have pulled. History preserved.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 848be5f9fe5c985a5ff468b26daac5bf63303972
git push origin master
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 80079967ff8931e82a44445abcdc88fad9b44036
git push origin master
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 79377542129957a7528d3f8556a83819ea6c3049
git push origin main
```

The `-m 1` selects the first parent (the base branch state) as the mainline to revert to. Squash-merge friendly.

### Method 2 — `git reset --hard` to pre-merge tag (DESTRUCTIVE, only if Method 1 fails)

Wipes the merge commit entirely. **Requires `--force` push.** Only do this if (a) Method 1 fails for some reason, AND (b) no one has pulled the merged changes yet, AND (c) you accept that anyone who has pulled will need to reset their local copies too.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan3b-2026-05-07
git push origin master --force
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan3b-2026-05-07
git push origin master --force
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git fetch --tags
git reset --hard backup/pre-plan3b-2026-05-07
git push origin main --force
```

## Production deployment notes (post-merge, pre-rollback awareness)

After this merge lands, the new code is **on master/main but not deployed**:

- **Backend:** EC2 instance still runs the pre-merge code. Deployment is `git pull && pm2 reload all` on the instance. Until then, the production API is unchanged. Even after deployment, `FEATURE_DAY1_DIAGNOSTIC_V2` must be `true` for the V2 path (and therefore insights generation) to run. Insights are generated inline during `finishAttemptV2` — expect added 2-15s latency on the finish endpoint when V2 is enabled. The new GET endpoint always exists post-deploy but only returns insights for attempts that went through V2 finish.
- **iOS:** No production impact until you submit a new build to App Store Connect. TestFlight builds will include the new code.
- **Android:** No production impact until you upload a new APK to Play Console. **Important:** Three new native modules were added (`react-native-pager-view`, `react-native-view-shot`, `react-native-share`). A dev-client rebuild is required before testing on device — `cd android && ./gradlew assembleDebug` (or Expo dev-client equivalent). Plain Metro bundle will crash on these imports.

Recommended order: merge → smoke test on staging → deploy backend → flip `FEATURE_DAY1_DIAGNOSTIC_V2=true` on staging → verify diagnostic full flow (start → finish → results screen shows real LLM insights) → flip on prod → ship apps.

If you skip staging and deploy directly, the rollback ladder is:
1. **Toggle `FEATURE_DAY1_DIAGNOSTIC_V2=false` + `pm2 reload all`** (~30 seconds — Method 0). Solves any V2-only backend regression instantly.
2. If insights cost is the issue but you want V2 question selection: temporarily comment out the `insightsGenerationService.generateInsights(...)` call in `finishAttemptV2` and redeploy — the template fallback will not fire either, so attempts will save with `insightsStatus: 'generating'` forever and the iOS/Android polls will hit the 18s ceiling and stay on the loader. **Not recommended** — prefer Method 0 or Method 1 wholesale.
3. Revert the backend merge commit + redeploy (5 minutes via Method 1).
4. Halt iOS/Android phased rollouts in their respective consoles.
5. (If needed) `git revert -m 1` on iOS + Android merges.

## Schema migration impact

The Mongoose schema additions (`insightsJson`, `insightsStatus`, `insightsSource`, `insightsLatencyMs`, `calibrationClass`) are all **additive with safe defaults**. Reverting the backend code does NOT require a database migration — old attempts simply have these fields as `null`/default values, and reverted code ignores them. New code (post-merge) handles missing fields gracefully via `?? null` chains in the controller.

If you also want to remove the persisted `insightsJson` data after a hard rollback (not normally necessary — it's just unread data):

```js
// node script (one-off, run from scaleup-backend with .env loaded)
require('dotenv').config()
const mongoose = require('mongoose')
;(async () => {
  await mongoose.connect(process.env.MONGODB_URI)
  const result = await mongoose.connection.collection('diagnosticattempts').updateMany(
    { insightsJson: { $exists: true } },
    { $unset: { insightsJson: '', insightsStatus: '', insightsSource: '', insightsLatencyMs: '' } }
  )
  console.log('Cleaned attempts:', result.modifiedCount)
  await mongoose.disconnect()
})()
```

⚠️ Only do this if you really want it gone. Leaving the data is harmless.

## Quick rollback (copy-paste, soft method)

```bash
# Backend
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 848be5f9fe5c985a5ff468b26daac5bf63303972
git push origin master

# iOS
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 80079967ff8931e82a44445abcdc88fad9b44036
git push origin master

# Android
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 79377542129957a7528d3f8556a83819ea6c3049
git push origin main
```
