# Rollback — Plan 5 (Polish + Launch) Merge (2026-05-07)

This document captures rollback procedures for the three repos that received the Plan 5 merge on 2026-05-07. Use this if a regression is detected after merge.

## What was merged

| Repo | Branch merged | Pre-merge HEAD | Squash merge SHA | Pre-merge tag |
|---|---|---|---|---|
| Backend (`scaleup-backend` / `ScaleUpDemo-b`) | `feat/diagnostic-phase5-polish-launch` | `00b7d2c` | `bd3d908c810767804786981a65828317efe3e97d` | `backup/pre-plan5-2026-05-07` |
| iOS (`ScaleUpDemo-f`) | `feat/diagnostic-phase5-polish-launch` | `6ab5ad9` | `49ae666a66c1289b603244331df42cf7c222f938` | `backup/pre-plan5-2026-05-07` |
| Android (`ScaleUpDemo-f-Android`) | `feat/diagnostic-phase5-polish-launch` | `d87fb0e` | `c5b302c06a461b5b7cb61a39ac6e3e0b64d6c6ca` | `backup/pre-plan5-2026-05-07` |

## What lands in each repo

Plan 5 is **almost entirely additive** — coverage scripts, QA tests, marketing/launch docs, Mixpanel dashboard setup, feature flag accessor. Reverting is safe; nothing in Plan 5 is on the critical user-facing path.

- **Backend (12 commits):**
  - Wave 2 batch scripts (Tasks 1-3) — runWave2Batch{1,2,3}.js + JSON data files (starter content, expand before scheduling crons)
  - Validator backfill worker (Task 4) — Mondays 03:00 IST, re-runs Tier 1 validator on `pending` questions
  - Coverage gap analysis (Task 5) — Mixpanel-driven script that ranks top 30 coverage misses
  - Gap-fill batch (Task 6) — generates taxonomy + anchors + questions for missing canonicalTargets
  - Wave 3 state board long-tail (Task 7) — UP/RJ/GJ/KL/AP/TS/WB
  - Seeding progress tracker (Task 8) — markdown doc + refresh shell script
  - E2E integration test (Task 10) — full diagnostic walk against real Mongo (manual run)
  - Mixpanel dashboard setup (Task 16) — one-shot script creating 7 Insights reports
  - Mixpanel daily digest worker (Task 17) — daily 09:00 IST email cron with `fetchMetrics` stub
  - Feature flag accessor (Task 18) — `featureFlags.js` with `isEnabled(flag)` helper
- **iOS (6 commits):**
  - E2E test plan (Task 9) — comprehensive manual QA checklist
  - Marketing copy (Task 13) — App Store + Play Store + in-app + email copy
  - iOS UI test (Task 11) — XCUITest covering happy path; needs app-side test-mode hooks
  - Pre-launch checklist (Task 19), rollback plan (Task 20), launch day runbook (Task 21)
- **Android (1 commit):**
  - RN UI test (Task 12) — component-level test using @testing-library/react-native

## Known limitations (manual setup required before deployment)

1. **Wave 2/3 JSON data files are starter content** — 6-10 entries per file demonstrating the pattern. Before scheduling the cron jobs at launch+14d/21d/28d/49d, expand these to the full ~25-50 entries per the original spec. Files:
   - `scripts/seed/data/wave2-topics.json` (T1 — 10/40 entries)
   - `scripts/seed/data/wave2-state-boards.json` (T2 — 8/35 entries)
   - `scripts/seed/data/wave2-finance-exams.json` (T3 — 8/25 entries)
   - `scripts/seed/data/wave2-companies.json` (T3 — 5/5 entries; OK)
   - `scripts/seed/data/wave3-state-boards-longtail.json` (T7 — 8/50 entries)

2. **`generateTaxonomyForTargetKey` is unimplemented** — the gap-fill batch (Task 6) throws at runtime for missing-taxonomy cases. Implement on `topicTaxonomyService` before running gap-fill in production. (Plan 3a deliverable that drifted.)

3. **Mixpanel `fetchMetrics` is a stub** — the daily digest worker (Task 17) returns zero metrics until you wire real Mixpanel JQL queries. `buildDigestBody` is fully wired; only `fetchMetrics` needs backfill. Do this once production traffic is flowing.

4. **iOS UI test (T11) needs app-side hooks** — the test uses `UITEST_OBJECTIVE_TYPE` + `UITEST_TARGET_SKILL` launch env vars. Add a test-mode branch in the app's launch sequence to seed test state and skip Steps 1-4 before the test will run green.

5. **Android UI test (T12) needs `@testing-library/react-native`** — `npm install --save-dev @testing-library/react-native` before running. Pre-existing repo-level jest/jsx config issues affect all existing test files (not unique to this PR).

6. **No App Store / Play Store screenshots** — these were explicitly skipped from Plan 5. Screenshot generation (T14, T15 in the original plan) is user-owned manual work.

## Rollback procedures (in order of preference)

### Method 1 — `git revert` (RECOMMENDED, non-destructive)

Plan 5 is purely additive. A revert removes the new files and Mixpanel/coverage tooling without touching any production code path.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 bd3d908c810767804786981a65828317efe3e97d
git push origin master
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 49ae666a66c1289b603244331df42cf7c222f938
git push origin master
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 c5b302c06a461b5b7cb61a39ac6e3e0b64d6c6ca
git push origin main
```

### Method 2 — `git reset --hard` to pre-merge tag (DESTRUCTIVE, only if Method 1 fails)

```bash
# Backend
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan5-2026-05-07
git push origin master --force

# iOS
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan5-2026-05-07
git push origin master --force

# Android
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git fetch --tags
git reset --hard backup/pre-plan5-2026-05-07
git push origin main --force
```

### Method 3 — Selective revert (preferred for granular issues)

Plan 5 commits don't depend on each other deeply. If one specific change is problematic (e.g., the validator backfill worker is misbehaving), you can revert just that commit:

```bash
# Find the SHA in the squash commit's body, OR fall back to the per-commit branch
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git log --grep="validator backfill" --oneline
# Pick the SHA of that specific commit on the feature branch (cherry-revert if already merged)
```

Since the merges are squashes, individual commit SHAs are only available in the feature branches (`feat/diagnostic-phase5-polish-launch`). To selectively revert one Plan 5 change after the squash merge:
1. `git revert -m 1 <plan5-merge-sha>` to undo everything
2. Re-apply the parts you want via `git cherry-pick <feat-branch-commit-sha>`

This is more involved but lets you keep most of Plan 5 while removing the problematic piece.

## What does NOT need rolling back

The pre-existing system was untouched by Plan 5. Specifically:
- No production code paths changed (Plan 5 is scripts + tests + docs)
- No schema changes
- No new endpoints exposed (the Mixpanel + coverage scripts are operational tools, not server endpoints)
- No new background workers auto-registered (the new workers are scheduled via cron, not auto-booted)

If Plan 5 introduces an issue, it's almost certainly in one of:
1. The new feature flag accessor — but `diagnosticService._useV2()` reads the env var directly, so the new module is decoupled
2. A new cron schedule was added to crontab and is misbehaving — comment out the cron line on the host
3. The integration test (`diagnostic-e2e-upskilling.test.js`) timing out in CI — `npm test` returns exit 1 because of it. Move the test to a separate `npm run test:integration` script if this is a CI gate problem.

## Quick rollback (copy-paste)

```bash
# Backend
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 bd3d908c810767804786981a65828317efe3e97d
git push origin master

# iOS
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 49ae666a66c1289b603244331df42cf7c222f938
git push origin master

# Android
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 c5b302c06a461b5b7cb61a39ac6e3e0b64d6c6ca
git push origin main
```
