# Rollback — Plan 4 (Plan + Recalibration + Admin) Merge (2026-05-07)

This document captures rollback procedures for the three repos that received the Plan 4 merge on 2026-05-07. Use this if a regression is detected after merge.

## What was merged

| Repo | Branch merged | Pre-merge HEAD | Squash merge SHA | Pre-merge tag |
|---|---|---|---|---|
| Backend (`scaleup-backend` / `ScaleUpDemo-b`) | `feat/diagnostic-phase4-plan-recal-admin` | `848be5f` | `00b7d2c80e7d8e13632ad5844ed4009e9243d848` | `backup/pre-plan4-2026-05-07` |
| iOS (`ScaleUpDemo-f`) | `feat/diagnostic-phase4-plan-recal-admin` | `4166801` | `ae06b2897aecf1dd8cd4942ea6d31a6387afdf90` | `backup/pre-plan4-2026-05-07` |
| Android (`ScaleUpDemo-f-Android`) | `feat/diagnostic-phase4-plan-recal-admin` | `7937754` | `d87fb0eaead0bace3b83c14d90878564d5f21d2a` | `backup/pre-plan4-2026-05-07` |

## What lands in each repo

- **Backend (16 tasks):** Plan model + planGeneration BullMQ queue. `planGenerationService` (gpt-4o + json_schema strict + 60s timeout + deterministic template fallback enforcing §11.3 constraints). `planReadyNotificationService` for FCM/APNs push. `planGenerationWorker` runs from BullMQ on every `finishAttemptV2`. `/plan/status` + `/plan/current` endpoints. `journeyGenerationService.generateFromPlan` consumes new structure. Re-calibration suite: `recalibrationEligibilityService` per spec §3.5, `GET /diagnostic/recalibration/eligible`, `POST /diagnostic/recalibration/start`, `recalibrationResultsService` (growth math + new gaps), daily 04:00 IST cron. Admin suite: `adminAuth` middleware, 5 admin endpoints (queue/approve/edit/reject/stats), AdminQuestionDecision model, `adminTrainingSignalService` (few-shot exports every 100 decisions), BE-served HTML+vanilla-JS dashboard at `/admin/dashboard.html`, weekly Monday 09:00 IST email digest cron. Schema: `Plan` model, `DiagnosticAttempt.{planId, recalibrationGrowth}` added.
- **iOS (10 tasks):** PlanService + PlanTabViewModel. PlanBrewingPill on Home with 5s polling. Push handler routes `plan_ready` → Plan tab. PlanTabView wholesale rebuild with WeeklyAllocationCard + MilestonePreview. Root TabView swaps `MyPlanView` → `PlanTabView`. Recalibration: ViewModel + Card on Progress + Nudge on Plan + OrchestrationView wrapping diagnostic flow + ResultsView per spec §10.4 (animated GrowthBarRow). 7 new typed AnalyticsEvent cases.
- **Android (8 tasks):** RN mirrors of iOS Plan tab + recalibration. Same screen-for-screen structure, same event-name strings. **Note:** push handler is a documented stub — see Known Limitations below.

## Known limitations (Plan 5 work)

1. **Android FCM push handler is a stub.** `@react-native-firebase/messaging` is NOT installed in the Android repo. The push handler code is in place but the FCM listeners do nothing until the package is added + dev-client rebuilt. To activate:
   ```bash
   cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
   npm install @react-native-firebase/app @react-native-firebase/messaging
   cd android && ./gradlew assembleDebug
   ```
   Then uncomment the FCM listener calls in `src/services/pushNotifications.ts` and wire `navigationRef` into `NavigationContainer` in `AppNavigator.tsx`.

2. **Android recalibration → results routing gap.** After the recalibration diagnostic completes, `DiagnosticContainer` routes to the standard `ResultsScreen` instead of `RecalibrationResultsScreen`. Wiring this requires adding an `isRecalibration` flag to `diagnosticSlice` and branching in `DiagnosticContainer.tsx`. iOS does NOT have this gap — `RecalibrationOrchestrationView` routes directly to `RecalibrationResultsView`.

3. **No user has `role: 'admin'` yet.** The admin dashboard endpoints + email digest cron will silently 0-result until at least one User document has `role: 'admin'`. Manually set this in the DB for Nirpeksh's user before testing the admin flow:
   ```js
   db.users.updateOne({ email: 'nirpeksh@scaleupapp.club' }, { $set: { role: 'admin' } })
   ```
   Then log out + back in to get a fresh JWT with `role: 'admin'` in the payload.

## Rollback procedures (in order of preference)

### Method 0 — Backend feature flag (FASTEST, no git, ~30s)

Plan 4's backend changes only fire on the V2 codepath, gated by `FEATURE_DAY1_DIAGNOSTIC_V2`. The fastest emergency rollback for ANY Plan 3+/Plan 4 backend regression is **toggle the flag off**:

```bash
# On EC2 host
unset FEATURE_DAY1_DIAGNOSTIC_V2  # or set to anything other than 'true'
pm2 reload all
```

V1 logic — preserved byte-for-byte — takes over again. Insights generation, plan generation, and recalibration all stop firing because they're all part of the V2 codepath.

The new endpoints (`/plan/*`, `/diagnostic/recalibration/*`, `/admin/diagnostic-questions/*`) remain mounted unconditionally, but they only return data for V2 attempts. With V2 off, they return empty results. Harmless.

If the regression is in the new endpoints themselves (e.g., a 500 on `/plan/current`), use Method 1.

### Method 1 — `git revert` (RECOMMENDED for app regressions, non-destructive)

Creates a new commit that undoes the merge. Safe even after others have pulled. History preserved.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 00b7d2c80e7d8e13632ad5844ed4009e9243d848
git push origin master
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 ae06b2897aecf1dd8cd4942ea6d31a6387afdf90
git push origin master
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 d87fb0eaead0bace3b83c14d90878564d5f21d2a
git push origin main
```

The `-m 1` selects the first parent (the base branch state) as the mainline to revert to.

### Method 2 — `git reset --hard` to pre-merge tag (DESTRUCTIVE, only if Method 1 fails)

Wipes the merge commit entirely. **Requires `--force` push.** Only do this if (a) Method 1 fails for some reason, AND (b) no one has pulled the merged changes yet, AND (c) you accept that anyone who has pulled will need to reset their local copies too.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan4-2026-05-07
git push origin master --force
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan4-2026-05-07
git push origin master --force
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git fetch --tags
git reset --hard backup/pre-plan4-2026-05-07
git push origin main --force
```

## Production deployment notes

After this merge lands, the new code is **on master/main but not deployed**:

- **Backend:** EC2 instance still runs the pre-merge code. Deployment requires `git pull && pm2 reload all` on the instance. Then `FEATURE_DAY1_DIAGNOSTIC_V2=true` for V2 logic to route. The plan generation worker also needs to be running — it auto-registers when `npm start` boots `src/workers/index.js`. Verify the worker is alive: `pm2 list | grep worker`.

  - **New cron jobs registered:**
    - `recalibrationOffer` — daily 04:00 IST (UTC `30 22 * * *`)
    - `adminQuestionDigest` — Monday 09:00 IST (UTC `30 3 * * 1`)
  - These start automatically when the cron worker boots; no manual scheduling needed.

  - **New env var:** `ADMIN_DASHBOARD_URL` (optional, defaults to `https://api.scaleup.app/admin/dashboard.html`) — used in the digest email's CTA link.

- **iOS:** No production impact until you submit a new build to App Store Connect. TestFlight builds will include the new code. `Mixpanel` events fire on real devices — verify in Mixpanel Live View before going to prod.

- **Android:** No production impact until you upload a new APK to Play Console. **For push notifications to work**, install `@react-native-firebase/messaging` and rebuild the dev client first (see Known Limitations §1).

Recommended order: merge → smoke test on staging/TestFlight → deploy backend → flip `FEATURE_DAY1_DIAGNOSTIC_V2=true` on staging → run a fresh diagnostic, verify plan brewing pill appears on Home, verify Plan tab populates after ~45s → ship apps.

If you skip staging and deploy directly, the rollback ladder is:
1. **Toggle `FEATURE_DAY1_DIAGNOSTIC_V2=false` + `pm2 reload all`** (~30 seconds — Method 0). Solves any V2-only backend regression instantly.
2. Revert the backend merge commit + redeploy (~5 minutes via Method 1).
3. Halt iOS/Android phased rollouts in their respective consoles.
4. (If needed) `git revert -m 1` on iOS + Android merges.

## Schema migration impact

The new Mongoose schema additions are **additive with safe defaults**:
- `Plan` (new collection — empty until first plan generates)
- `AdminQuestionDecision` (new collection — empty until first admin decision)
- `DiagnosticAttempt.{planId, recalibrationGrowth}` (new fields, default null)

Reverting the backend code does NOT require a database migration — old attempts simply have these fields as null, and reverted code ignores them.

If you also want to remove the new Plan + AdminQuestionDecision collections after a hard rollback (not normally necessary):
```js
// node script (one-off, run from scaleup-backend with .env loaded)
require('dotenv').config()
const mongoose = require('mongoose')
;(async () => {
  await mongoose.connect(process.env.MONGODB_URI)
  await mongoose.connection.collection('plans').drop().catch(() => {})
  await mongoose.connection.collection('adminquestiondecisions').drop().catch(() => {})
  await mongoose.connection.collection('diagnosticattempts').updateMany(
    {},
    { $unset: { planId: '', recalibrationGrowth: '' } }
  )
  await mongoose.disconnect()
})()
```

⚠️ Only do this if you really want it gone.

## Quick rollback (copy-paste, soft method)

```bash
# Backend
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 00b7d2c80e7d8e13632ad5844ed4009e9243d848
git push origin master

# iOS
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 ae06b2897aecf1dd8cd4942ea6d31a6387afdf90
git push origin master

# Android
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 d87fb0eaead0bace3b83c14d90878564d5f21d2a
git push origin main
```
