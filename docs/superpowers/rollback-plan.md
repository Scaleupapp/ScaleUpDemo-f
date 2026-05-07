# Rollback Plan — Day-1 Diagnostic V2

This document is the holistic playbook for rolling back the Day-1 Diagnostic V2 feature after launch. It covers triage, backend, iOS, Android, data, re-launch criteria, and user communication.

For surgical per-phase reverts (scoped to a single plan's code), use the per-merge rollback docs listed below.

---

## Per-Merge Rollback Docs

These documents contain the exact `git revert -m 1 <SHA>` commands for each plan's merge across all three repos (backend, iOS, Android). Use these when an issue is scoped to a specific plan's changes.

| Doc | Merged | Backend SHA | iOS SHA | Android SHA |
|-----|--------|-------------|---------|-------------|
| `ROLLBACK-day1-diagnostic-2026-05-04.md` | 2026-05-04 | `932be2a` | `ddca955` | `2ddb22d` |
| `ROLLBACK-plan3a-2026-05-06.md` | 2026-05-06 | `2bef58b` | `7229d8d` | `7fba57d` |
| `ROLLBACK-plan3b-2026-05-07.md` | 2026-05-07 | `848be5f` | `8007996` | `7937754` |
| `ROLLBACK-plan4-2026-05-07.md` | 2026-05-07 | `00b7d2c` | `ae06b28` | `d87fb0e` |

If the issue spans multiple plans, follow this document's holistic procedure instead.

---

## Decision Tree

```
Issue reported after launch
        |
        v
Is it isolated to one user / device?
  YES --> Check per-user data in MongoDB. Likely bad attempt record.
          Fix inline. No rollback needed.
  NO  --> continue
        |
        v
Is the error rate elevated across all users?
  YES --> continue
  NO  --> Monitor. Set alert threshold. Do not roll back on noise.
        |
        v
Is the symptom backend (API errors, 5xx, plan not generating)?
  YES --> BACKEND ROLLBACK (see below). Done in ~5 minutes.
  NO  --> continue
        |
        v
Is the symptom iOS only?
  YES --> iOS ROLLBACK (see below). Pause phased release.
  NO  --> continue
        |
        v
Is the symptom Android only?
  YES --> ANDROID ROLLBACK (see below). Halt staged rollout.
  NO  --> continue
        |
        v
Is data corrupted (attempts missing fields, insights null at scale)?
  YES --> DATA ROLLBACK (see below). Last resort.
```

---

## Backend Rollback — 5-Minute Procedure

The entire V2 backend codepath is gated by `FEATURE_DAY1_DIAGNOSTIC_V2`. **Toggling the flag is always Step 1** — no git revert required.

```bash
# On the EC2 instance:
# 1. Edit .env — set FEATURE_DAY1_DIAGNOSTIC_V2=false
nano /home/ubuntu/scaleup-backend/.env

# 2. Reload without downtime
pm2 reload all

# 3. Verify — the V2 route should return 404 or fall through to V1
curl -s https://api.scaleupapp.club/diagnostic/syllabus/health | jq .
```

Expected outcome: all traffic reverts to V1 logic. V1 users are unaffected. New V2 users get a graceful fallback (old onboarding flow).

If the flag toggle is not enough (e.g. the regression is in shared V1+V2 code or the new GET endpoint itself):

```bash
# Backend — revert Plan 4 (most recent; contains plan generation worker)
git revert -m 1 00b7d2c80e7d8e13632ad5844ed4009e9243d848
git push origin master
# On EC2: git pull && pm2 reload all
```

If Plan 4 revert is not enough, continue reverting earlier plans in reverse order:

```bash
# Plan 3b (insights + results endpoint)
git revert -m 1 848be5f9fe5c985a5ff468b26daac5bf63303972

# Plan 3a (diagnostic engine + voice upload endpoint)
git revert -m 1 2bef58b348769fcb2b76b280b2d858715a3e0c80

# Plan 2 (diagnostic foundation — topics/suggest, onboarding/complete, syllabus routes)
git revert -m 1 932be2a95f245742937ae51c30da9947423cf27c
```

Each revert is a separate commit. Push and redeploy after each, verifying the specific symptom is resolved before reverting further.

---

## iOS Rollback

iOS is distributed via App Store phased release (7-day rollout). Rollback options in order of speed:

1. **Pause phased release** — In App Store Connect → your app → Phased Release → Pause. Stops new users from receiving the build. Existing installs keep it. Takes effect within minutes. Do this first while diagnosing.

2. **Halt the release** — In App Store Connect → remove the build from sale / halt rollout entirely. New App Store downloads revert to the previous version.

3. **Expedited review for hotfix** — Submit a hotfix build with the issue patched. Request expedited review via Resolution Center. Typical turnaround: 24–48 hours.

4. **Git revert iOS code** (if the issue is code-level and you have a hotfix ready):

```bash
# Revert Plan 4 iOS merge
git revert -m 1 ae06b2897aecf1dd8cd4942ea6d31a6387afdf90

# If needed, revert Plan 3b iOS merge
git revert -m 1 80079967ff8931e82a44445abcdc88fad9b44036

# If needed, revert Plan 3a iOS merge
git revert -m 1 7229d8d34e2334dc290eae89f56a73d5ab0c0e6b

# If needed, revert Plan 2 iOS merge
git revert -m 1 ddca955bff675cba17324750ce45e17efd42336e
```

Push, build, upload to TestFlight, submit for expedited review.

---

## Android Rollback

Android is distributed via Play Console staged rollout (10% or less on day 1). Rollback options:

1. **Halt the rollout** — Play Console → Release → Production → Halt rollout. Immediately stops the staged rollout. Users already updated keep the build; new installs get the previous version.

2. **Rollback to previous release** — Play Console allows rolling back to the previous production release if the new one has not yet reached 100%.

3. **Git revert Android code** (for a hotfix build):

```bash
# Revert Plan 4 Android merge
git revert -m 1 d87fb0eaead0bace3b83c14d90878564d5f21d2a

# If needed, revert Plan 3b Android merge
git revert -m 1 79377542129957a7528d3f8556a83819ea6c3049

# If needed, revert Plan 3a Android merge
git revert -m 1 7fba57d2bf0a59c8b15bc46b7eb55c584716342d

# If needed, revert Plan 2 Android merge
git revert -m 1 2ddb22d2442ce4c01bf74ca5911a2544747f072d
```

Note: Plans 3b and 4 added native modules (`react-native-pager-view`, `react-native-view-shot`, `react-native-share`). A full `./gradlew assembleRelease` rebuild is required after reverting those plans — a plain JS bundle update is not sufficient.

---

## Data Rollback

**Last resort.** Only if MongoDB records are corrupted at scale and cannot be patched inline.

Pre-conditions before proceeding:
- Backend flag is already set to `FEATURE_DAY1_DIAGNOSTIC_V2=false`
- All three app releases are paused / halted
- You have confirmed the pre-launch backup label (e.g. `pre-launch-v2-2026-05-07`)

```bash
# Stop the backend to prevent writes during restore
pm2 stop all

# Restore from the pre-launch snapshot
mongorestore --uri="$MONGODB_URI" \
  --drop \
  --nsInclude="scaleup.*" \
  /path/to/backup/pre-launch-v2-2026-05-07/

# Restart
pm2 start all
```

`--drop` removes the current collection before restoring. This is destructive — all V2 diagnostic attempts created after the backup are lost. Confirm with Nirpeksh before running.

After restore, verify:
- `db.diagnosticattempts.countDocuments()` matches the pre-launch count
- `db.users.countDocuments()` is unchanged
- A spot-check of 3 user records shows no V2 fields (`insightsJson`, `planJson`) that would indicate stale V2 data

---

## Re-Launch Criteria

Before re-enabling `FEATURE_DAY1_DIAGNOSTIC_V2=true` after a rollback:

- [ ] Root cause identified and documented
- [ ] Fix merged to master, passing all tests on all three repos
- [ ] Fix verified on staging with a full end-to-end diagnostic attempt (start → voice → finish → insights → plan)
- [ ] The specific symptom that triggered rollback is confirmed resolved on staging
- [ ] Pre-launch checklist re-run in full (at minimum the affected sections)
- [ ] If data was rolled back: migration path for any V2 attempts lost in the restore is decided (discard vs. replay)
- [ ] Nirpeksh on-call and available for the first 4 hours post re-launch

---

## User Communication Template

Use this template for in-app or push notification communication if users experience visible failures.

**Subject / notification title:** We're fixing something — hang tight

**Body:**

> We noticed a hiccup with the new Superpower Diagnostic. We've paused it while we fix the issue — your progress is safe. We'll notify you as soon as it's back up, usually within a few hours.

**Follow-up (once resolved):**

> The Superpower Diagnostic is back up. Tap here to pick up where you left off.

If the issue lasts more than 4 hours, send a second message acknowledging the wait and giving an estimated resolution time.

---

_Last updated: 2026-05-07. Plan 5 Task 20._
