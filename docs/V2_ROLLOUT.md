# ScaleUp v2 — Rollout & Rollback Playbook

This document describes how to test the v2 redesign in parallel with the existing app, and how to roll back if it doesn't land with users.

## Branches

| Repo | Branch | Status |
|---|---|---|
| Backend (`scaleup-backend`) | `v2-redesign` | New `/api/v2/*` routes, v1 untouched |
| iOS (`ScaleUpDemo-f`) | `v2-redesign` | New `Features/V2/*` files, v1 untouched |
| Android (`ScaleUpAndroid`) | `v2-redesign` | Plan doc only; implementation deferred to Session 2 |

**Master branches remain shippable at all times.**

## How to ship v2 to testers

### Backend
1. Merge `v2-redesign` to `staging`.
2. Deploy. v1 endpoints (`/api/v1/*`) keep serving production traffic.
3. v2 endpoints (`/api/v2/*`) are live for any client that calls them.
4. The mount can be removed at any time via the single line in `src/app.js` line 90.

### iOS
1. From `v2-redesign`, run `xcodegen generate` and archive a TestFlight build.
2. Distribute to test group as usual.
3. In the app, the v2 experience is **OFF by default**.
4. Tester instructions:
   - Open Profile → Settings → Developer (or wherever you wire `V2DevSettingsView`)
   - Toggle "Try v2 redesign" ON
   - Optional: toggle "Also use v2 onboarding" ON (for new-tester flows)
   - Force-close and relaunch the app
5. Tester now sees v2 — 4 tabs, Compass FAB, new screens.

### Android
- Build scheduled for Session 2 once iOS testing yields feedback.

## How to roll back (any time)

### Per-tester
- Open Profile → Developer → "Roll back to v1 now"
- Or toggle "Try v2 redesign" OFF
- Relaunch — v1 returns exactly as before.

### App-wide (TestFlight cohort)
- Push a config update or a new build with the flag default reset.
- No code revert needed; v1 surfaces are intact in the same binary.

### Backend
- Remove the `app.use('/api/v2', ...)` line in `src/app.js` and redeploy.
- Or merge the v1 routes back to master if `v2-redesign` is abandoned: `git checkout master`.

### Full kill
- Delete the `v2-redesign` branch from all three repos.
- Master is untouched; no migration needed.

## What v2 changes for the tester

| Surface | v1 today | v2 |
|---|---|---|
| Tab structure | 5 tabs (Home/Discover/Plan/Progress/Profile) | 4 tabs (Home/Learn/Compass/You) |
| Home | Multi-banner noticeboard with carousels | One hero task + greeting + trajectory bar |
| AI | 11 fragmented surfaces | One named "Compass" — FAB everywhere + own tab |
| Profile + Progress | Two tabs, 15+ sections | One "You" tab — readiness ring + 4 facts above fold |
| Onboarding (if enabled) | 6 steps, ~25 min | Text-led objective + Reality Check + Calibration insights |
| Time commitment | Asked of user | Computed from objective + timeline |
| Diagnostic insights | Score + per-topic | "You said vs you actually" + behavioral patterns + trajectory + top-3 actions |
| Streak | Loud flame banner | Quiet "12 days" stat |
| Carousels (trending/recommended) | Stacked on Home | Moved to Learn tab |

## What v2 does NOT change

- All v1 backend services are still live (`/api/v1/*`)
- All v1 iOS screens still exist and are reachable when the flag is OFF
- All user data, plans, content, conversations remain intact
- All cron jobs and workers continue to run
- All admin / TPO infra (where it exists) is unchanged

## Feedback signals to watch from testers

1. **Time to first task completion** — should drop vs v1 (one-hero is unambiguous)
2. **Compass interaction rate** — % of testers who tap the FAB at least once per session
3. **"Where do I go to take a quiz?"** type questions — should decrease (Compass tab now obvious)
4. **Onboarding completion** — should rise (shorter, more honest)
5. **Reactions to Reality Check screen** — biggest emotional moment; capture qualitative reactions

If retention or engagement drops, roll back and iterate. The branch keeps the diff isolated.

## v2 files reference

### Backend new files
```
src/routes/v2/
  index.js
  objective.js
  diagnostic.js
  plan.js
  insights.js
  compass.js

src/services/v2/
  requiredTimeService.js
  trajectoryService.js
  predictedImpactService.js
  compassOrchestrator.js
```

### iOS new files
```
ScaleUp/Features/V2/
  Core/
    V2FeatureFlag.swift
    V2RootView.swift
    V2Tab.swift
    V2MainTabView.swift
    V2Theme.swift
    V2APIClient.swift
    V2DevSettingsView.swift
  Home/
    V2HomeView.swift
    V2HomeViewModel.swift
  Learn/
    V2LearnView.swift
  Compass/
    CompassFAB.swift
    V2CompassView.swift
    CompassViewModel.swift
  You/
    V2YouView.swift
  Onboarding/
    V2ObjectiveSetupView.swift
    V2RealityCheckView.swift
    V2OnboardingFlowView.swift
  Diagnostic/
    V2CalibrationInsightsView.swift
```

### iOS touched files (one line each)
- `App/ScaleUpApp.swift` — `case .home` now uses `V2RootView()` which auto-falls-through to `MainTabView()` when flag is OFF

### Android new files
- `V2_REDESIGN_PLAN.md` (planning doc only)

## Session 2 follow-ups

- Wire `V2DevSettingsView` into the existing Settings screen so testers can find the toggle
- Connect `V2HomeViewModel.load()` to live `/api/v2/plan/today` (currently falls back to sample data)
- Connect `CompassViewModel` to live `POST /api/v2/compass`
- Wire `V2RealityCheckView` to `POST /api/v2/objective/required-time`
- Wire `V2CalibrationInsightsView` to `GET /api/v2/diagnostic/:attemptId/insights`
- Implement Android v2 per the plan doc
- Add unit tests for v2 services (requiredTime, trajectory, predictedImpact)
