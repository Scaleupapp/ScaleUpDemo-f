# Rollback — Plan 3a Diagnostic Engine Merge (2026-05-06)

This document captures rollback procedures for the three repos that received the Plan 3a (Diagnostic Engine) merge on 2026-05-06. Use this if a regression is detected after merge.

## What was merged

| Repo | Branch merged | Pre-merge HEAD | Squash merge SHA | Pre-merge tag |
|---|---|---|---|---|
| Backend (`scaleup-backend` / `ScaleUpDemo-b`) | `feat/diagnostic-phase3a-engine` | `932be2a` | `2bef58b348769fcb2b76b280b2d858715a3e0c80` | `backup/pre-plan3a-2026-05-06` |
| iOS (`ScaleUpDemo-f`) | `feat/diagnostic-phase3a-engine` | `2ecd406` | `7229d8d34e2334dc290eae89f56a73d5ab0c0e6b` | `backup/pre-plan3a-2026-05-06` |
| Android (`ScaleUpDemo-f-Android`) | `feat/diagnostic-phase3a-engine` | `2ddb22d` | `7fba57d2bf0a59c8b15bc46b7eb55c584716342d` | `backup/pre-plan3a-2026-05-06` |

## What lands in each repo

- **Backend:** Plan 3a Tasks 1–8. Path C question selection, voice answer service (Whisper + GPT-4o), real-time question generation with Tier 1 validator gate, taxonomy-driven `assemblePool` with realtime fallback, daily taxonomy refresh worker, `POST /diagnostic/voice/upload` endpoint, V2 orchestration in `diagnosticService` gated by `FEATURE_DAY1_DIAGNOSTIC_V2`. V1 path preserved byte-for-byte and routed via feature flag — **zero behavior change to current production flow until `FEATURE_DAY1_DIAGNOSTIC_V2=true`** on the host.
- **iOS:** Plan 3a Tasks 9–13. `TopicProgressChip` + `TopicTransitionCard` components, `DiagnosticViewModel` per-topic state and voice routing, `DiagnosticVoiceAnswerView` (AVAudioRecorder + waveform + multipart upload + fallback), light-impact haptic on submit, restrained `CompletionConfettiView` on results, Mixpanel events helper + wiring for 5 new diagnostic events.
- **Android:** Plan 3a Tasks 14–16. RN mirrors of iOS work. `TopicProgressChip` + `TopicTransitionCard`, `diagnosticSlice` extended, `VoiceAnswerScreen` (AudioRecorderPlayer + multipart upload), `react-native-haptic-feedback` + `react-native-confetti-cannon` (dev-client rebuild required for haptic), Mixpanel events helper + wiring.

## Rollback procedures (in order of preference)

### Method 1 — `git revert` (RECOMMENDED, non-destructive)

Creates a new commit that undoes the merge. Safe even after others have pulled. History preserved.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 2bef58b348769fcb2b76b280b2d858715a3e0c80
git push origin master
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 7229d8d34e2334dc290eae89f56a73d5ab0c0e6b
git push origin master
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 7fba57d2bf0a59c8b15bc46b7eb55c584716342d
git push origin main
```

The `-m 1` selects the first parent (the base branch state) as the mainline to revert to. Squash-merge friendly.

### Method 2 — `git reset --hard` to pre-merge tag (DESTRUCTIVE, only if revert fails)

Wipes the merge commit entirely. **Requires `--force` push.** Only do this if (a) Method 1 fails, AND (b) no one has pulled the merged changes yet, AND (c) you accept that anyone who has pulled will need to reset their local copies too.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan3a-2026-05-06
git push origin master --force
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git fetch --tags
git reset --hard backup/pre-plan3a-2026-05-06
git push origin master --force
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git fetch --tags
git reset --hard backup/pre-plan3a-2026-05-06
git push origin main --force
```

## Backend — feature flag is the cleanest rollback

The Plan 3a backend changes are gated by `FEATURE_DAY1_DIAGNOSTIC_V2`. The simplest rollback is **toggle the flag off** — no git revert required:

```bash
# On EC2 host
unset FEATURE_DAY1_DIAGNOSTIC_V2  # or set to anything other than 'true'
pm2 reload all
```

The new V2 codepaths stop being reached. V1 logic (preserved byte-for-byte) takes over again. Use this as the first line of defense for backend regressions.

The new endpoint `POST /diagnostic/voice/upload` is mounted unconditionally and will continue to exist when the flag is off — but if no client is configured to call it, it has no effect. If the endpoint itself is the regression, use Method 1 to revert.

## Production deployment notes (post-merge, pre-rollback awareness)

After this merge lands, the new code is **on master/main but not deployed**:

- **Backend:** EC2 instance still runs the pre-merge code. Deployment requires `pm2 reload all` after `git pull` on the instance. Until then, the production API is unchanged. Even after deployment, `FEATURE_DAY1_DIAGNOSTIC_V2` must be set to `true` for V2 logic to route. So the backend has a **two-step gate**: deploy + flag flip.
- **iOS:** No production impact until you submit a new build to App Store Connect. TestFlight builds will include the new code.
- **Android:** No production impact until you upload a new APK to Play Console. **Note:** RN haptic-feedback has a native module — a dev-client rebuild is required before haptic works on device. Confetti is JS-only.

Recommended order: merge → smoke test on staging/TestFlight → deploy backend → flip `FEATURE_DAY1_DIAGNOSTIC_V2=true` on staging → verify → flip on prod → ship apps.

If you skip staging and deploy directly, the rollback ladder is:

1. Flip `FEATURE_DAY1_DIAGNOSTIC_V2` off + `pm2 reload all` (~30 seconds)
2. If that's not enough, revert the backend merge commit + redeploy (~5 minutes via Method 1)
3. Halt iOS/Android phased rollouts in their respective consoles
4. (If needed) `git revert -m 1` on iOS + Android merges

## Quick rollback (copy-paste, soft method)

```bash
# Backend
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master && git pull
git revert -m 1 2bef58b348769fcb2b76b280b2d858715a3e0c80
git push origin master

# iOS
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master && git pull
git revert -m 1 7229d8d34e2334dc290eae89f56a73d5ab0c0e6b
git push origin master

# Android
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main && git pull
git revert -m 1 7fba57d2bf0a59c8b15bc46b7eb55c584716342d
git push origin main
```
