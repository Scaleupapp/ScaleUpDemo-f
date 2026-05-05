# Rollback — Day-1 Diagnostic Foundation Merge (2026-05-04)

This document captures rollback procedures for the three repos that received the Day-1 Diagnostic Foundation merge on 2026-05-04. Use this if a regression is detected after merge.

## What was merged

| Repo | Branch merged | Squash commit on base | Pre-merge tag |
|---|---|---|---|
| Backend (`scaleup-backend`) | `feat/diagnostic-phase0.5-seed` | _(see remote master)_ | `backup/pre-day1-diagnostic-2026-05-04` |
| iOS (`ScaleUpDemo-f`) | `feat/diagnostic-phase2b-frontend` | _(see remote master)_ | `backup/pre-day1-diagnostic-2026-05-04` |
| Android (`ScaleUpAndroid`) | `feat/diagnostic-phase2b-frontend` | _(see remote main)_ | `backup/pre-day1-diagnostic-2026-05-04` |

The actual merge commit SHAs and tags are listed at the bottom of this file after the merges complete.

## What lands in each repo

- **Backend:** Plans 1 (seed scripts) + 2a (foundation) + Wave 1 production seed already executed. New models (`TopicTaxonomy`, `CompanyProfile`, `DiagnosticSyllabus`), services, validator, normalization, syllabus + onboarding endpoints, migration script, retry/budget/idempotency hardening. Test suite at 161 passing.
- **iOS:** Plan 2b (frontend onboarding) — `OnboardingViewModel` rewired, new Step 5 with taxonomy chips + AI badge + cap-8 + per-topic self-rating, `SyllabusUploadView`, `CalibrationBannerView` on Home, 9 onboarding Mixpanel events. Plus the spec/research/plans docs.
- **Android:** Plan 2b (frontend onboarding) — RN mirrors of iOS work. `OnboardingData` extended, `InterestsStep` rebuilt with new chips, `SelfRatingSubStep`, `SyllabusUpload` (file/image picker + polling), Redux `calibrationSlice` + `CalibrationBanner` on Home, 9 onboarding events.

## Rollback procedures (in order of preference)

### Method 1 — `git revert` (RECOMMENDED, non-destructive)

Creates a new commit that undoes the merge. Safe even after others have pulled. History preserved.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master
git pull
git revert -m 1 <BACKEND_MERGE_SHA>
git push origin master
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master
git pull
git revert -m 1 <IOS_MERGE_SHA>
git push origin master
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main
git pull
git revert -m 1 <ANDROID_MERGE_SHA>
git push origin main
```

The `-m 1` selects the first parent (the base branch state) as the mainline to revert to. This is the squash-merge friendly option.

### Method 2 — `git reset --hard` to pre-merge tag (DESTRUCTIVE, only if revert fails)

Wipes the merge commit entirely. **Requires `--force` push.** Only do this if (a) Method 1 fails for some reason, AND (b) no one has pulled the merged changes yet, AND (c) you accept that anyone who has pulled will need to reset their local copies too.

**Backend:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout master
git fetch --tags
git reset --hard backup/pre-day1-diagnostic-2026-05-04
git push origin master --force
```

**iOS:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout master
git fetch --tags
git reset --hard backup/pre-day1-diagnostic-2026-05-04
git push origin master --force
```

**Android:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout main
git fetch --tags
git reset --hard backup/pre-day1-diagnostic-2026-05-04
git push origin main --force
```

### Database rollback (Backend only — important)

The Wave 1 production seed already wrote ~8,400 documents to MongoDB Atlas (`scaleupdemo` database, collections: `topictaxonomies`, `companyprofiles`, `diagnosticquestionbanks` with `isAnchor:true` or `generationSource:'seed_batch'`).

**The new feature endpoints (`/onboarding/topics/suggest`, `/onboarding/complete`, `/diagnostic/syllabus/*`) are gated by route mounting only — if you revert the backend code, the routes simply stop existing.** The seed data itself is harmless when the routes are unreachable: nothing reads it.

If you want to remove the seed data anyway:

```js
// node script (one-off, run from scaleup-backend with .env loaded)
require('dotenv').config()
const mongoose = require('mongoose')
;(async () => {
  await mongoose.connect(process.env.MONGODB_URI)
  const TopicTaxonomy = require('./src/models/TopicTaxonomy')
  const CompanyProfile = require('./src/models/CompanyProfile')
  const QuestionBank = require('./src/models/DiagnosticQuestionBank')
  console.log('Removing seed data…')
  console.log('Taxonomies:', (await TopicTaxonomy.deleteMany({})).deletedCount)
  console.log('Companies:', (await CompanyProfile.deleteMany({ source: 'curated' })).deletedCount)
  console.log('Bulk-generated questions:', (await QuestionBank.deleteMany({ generationSource: 'seed_batch' })).deletedCount)
  console.log('Anchor questions:', (await QuestionBank.deleteMany({ isAnchor: true })).deletedCount)
  await mongoose.disconnect()
})()
```

⚠️ Only run this if you're sure you don't want the seeded data. After deletion, re-running Wave 1 costs ~$60 in LLM compute.

## Production deployment notes (post-merge, pre-rollback awareness)

After the merge lands, the new code is **on master/main but not deployed**:

- **Backend:** EC2 instance still runs the pre-merge code. Deployment is a separate step (`pm2 reload all` after `git pull` on the instance). **Until then, the production API is unchanged** — the new endpoints don't exist yet on the live host. This means you have a buffer between merge and live exposure: rollback is just "don't deploy" rather than reverting.
- **iOS:** No production impact until you submit a new build to App Store Connect. TestFlight builds will include the new code.
- **Android:** No production impact until you upload a new APK to Play Console.

So: **the safest order is** merge → smoke test on staging/TestFlight → deploy backend → ship apps.

If you skip staging and deploy directly, the rollback ladder is:
1. Revert the backend merge commit + redeploy (5 minutes via Method 1)
2. Halt iOS/Android phased rollouts in their respective consoles
3. (If needed) Database cleanup per the snippet above

## Final SHAs (filled in after merges)

| Repo | Pre-merge tag SHA | Squash merge SHA |
|---|---|---|
| Backend | `<TBD>` | `<TBD>` |
| iOS | `<TBD>` | `<TBD>` |
| Android | `<TBD>` | `<TBD>` |
