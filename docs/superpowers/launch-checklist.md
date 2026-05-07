# Pre-Launch Checklist — Day-1 Diagnostic V2

**Every box must be checked before flipping `FEATURE_DAY1_DIAGNOSTIC_V2=true` in production.**

---

## Code & Tests

- [ ] All five plan branches merged to master on all three repos (backend, iOS, Android)
- [ ] Backend: `npm test` passes green on master (unit + integration)
- [ ] iOS: all Xcode test targets pass on master
- [ ] Android: `./gradlew test` passes on master
- [ ] E2E test plan (`docs/superpowers/qa/`) signed off — all 7 objective types exercised on staging
- [ ] No open severity-1 or severity-2 bugs on the launch milestone
- [ ] Feature flag `FEATURE_DAY1_DIAGNOSTIC_V2` confirmed set to `false` in production `.env` (not yet flipped)

---

## Data State — Wave 1 Cohort

- [ ] Wave 1 user list finalised and loaded into the backend seed collection
- [ ] `superpower` taxonomy seed verified: all entries have `id`, `label`, `archetypes`, `evidence_keys`
- [ ] At least one full diagnostic attempt completed successfully on staging from start to finish (voice upload → finish → insights → plan generated)
- [ ] Staging DB inspection: `DiagnosticAttempt` record has `insightsStatus: 'ready'` and `planStatus: 'ready'` after the above attempt
- [ ] Pre-launch MongoDB backup taken (snapshot labelled `pre-launch-v2-YYYY-MM-DD`)

---

## Mixpanel & Monitoring

- [ ] Mixpanel project token confirmed in backend and iOS `Info.plist` / Android `BuildConfig` (see `reference_mixpanel.md`)
- [ ] `diagnostic_started`, `diagnostic_completed`, `insights_viewed`, `plan_viewed` events firing on staging — verify in Mixpanel Live View
- [ ] `diagnostic_step_completed` event fires for each of the 7 objective types on staging
- [ ] `plan_brewing_started`, `plan_ready` events visible in Mixpanel after a staging attempt
- [ ] Server error rate baseline checked on EC2 CloudWatch — no elevated 5xx before flip
- [ ] PM2 process list stable: `pm2 list` shows `online` for backend + worker, no restarts in the last hour

---

## Push Notifications

- [ ] APNs key (`.p8`) present on the EC2 instance at the path referenced in backend config
- [ ] APNs key ID and team ID confirmed in backend `.env`
- [ ] Push notification test sent to a real device on staging — "Your Superpower Plan is ready" notification received and taps to the Plan tab
- [ ] Android FCM credentials confirmed in backend `.env` and in Android `google-services.json`
- [ ] Android push test sent on staging — notification received and tapped correctly

---

## App Store + Play Store

- [ ] iOS build uploaded to App Store Connect TestFlight (see `reference_appstore_connect.md` for credentials)
- [ ] TestFlight internal group (Nirpeksh + testers) has access to the build — tested on a real device
- [ ] iOS build set for phased release (7-day rollout) — **do not release to 100% on day 1**
- [ ] Android APK / AAB uploaded to Play Console internal testing track and promoted to production with a staged rollout (10% or less on day 1)
- [ ] App Store screenshots prepared (deferred — user-owned manual work)
- [ ] Play Store screenshots prepared (deferred — user-owned manual work)

---

## Admin Readiness

- [ ] Admin dashboard accessible and loading without errors
- [ ] "Flip to admin" role-flip verified for Nirpeksh account (`role: 'admin'` in MongoDB)
- [ ] Wave 1 cohort visible in the admin user list
- [ ] Admin can view a completed `DiagnosticAttempt` with insights JSON and plan JSON inline
- [ ] Plan generation worker health endpoint (or `pm2 status`) confirmed reachable from admin context

---

## Existing-User Migration

- [ ] Migration script for existing users (null `diagnosticAttempt` → eligible for V2 onboarding) reviewed and dry-run on staging
- [ ] Dry-run output shows correct user count with no accidental overwrites
- [ ] Migration script run on production DB (or confirmed unnecessary if all prod users are pre-Wave-1 and will naturally hit V2 on next login)
- [ ] Post-migration: spot-check 3 existing user records in production MongoDB — fields as expected

---

## Documentation & Support

- [ ] This checklist reviewed end-to-end with no items skipped
- [ ] Rollback plan (`docs/superpowers/rollback-plan.md`) read and understood
- [ ] Launch day runbook (`docs/superpowers/launch-day-runbook.md`) read and on-screen during launch window
- [ ] Support team (or Nirpeksh, if solo) notified of the launch window and common issue responses

---

## Rollback Readiness

- [ ] `FEATURE_DAY1_DIAGNOSTIC_V2=false` + `pm2 reload all` rollback sequence rehearsed on staging — confirmed it reverts to V1 behaviour within 5 minutes
- [ ] Per-plan rollback docs confirmed present in `docs/superpowers/`:
  - `ROLLBACK-day1-diagnostic-2026-05-04.md`
  - `ROLLBACK-plan3a-2026-05-06.md`
  - `ROLLBACK-plan3b-2026-05-07.md`
  - `ROLLBACK-plan4-2026-05-07.md`
- [ ] Pre-launch MongoDB backup confirmed restorable (test restore to a scratch DB on staging)

---

## Final Go / No-Go

- [ ] All sections above are fully checked
- [ ] No open incidents on AWS (EC2, S3) or OpenAI status page
- [ ] Nirpeksh available and on-call for the next 24 hours post-flip
- [ ] **GO: flip `FEATURE_DAY1_DIAGNOSTIC_V2=true` in production `.env` → `pm2 reload all`**

---

_Last updated: 2026-05-07. Plan 5 Task 19._
