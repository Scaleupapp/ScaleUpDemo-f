# Competition Pipeline Overhaul — Design Spec

> **Status:** Draft
> **Date:** 2026-03-24
> **Scope:** Backend pipeline automation + iOS leaderboard UX

---

## Problem Statement

The current competition system has 6 critical issues:

1. **Cost bomb at scale** — `generateWeeklyCandidates()` pulls ALL topics from ALL `KnowledgeProfile` documents. At scale (5,000+ users), this means hundreds of topics × 130 questions each × GPT-4o = massive cost and time.
2. **Admin required for activation** — `autoAssignQuestions()` must be manually called per candidate bank. Nothing automatic bridges generation → assignment → activation.
3. **Live events never created** — Questions get assigned to live event slots in `ChallengeCandidateBank`, but no code auto-creates `LiveEvent` documents from them.
4. **No topic scoping** — Generation doesn't consider which topics users actually have as active objectives. It generates for every topic any user has ever touched.
5. **Leaderboard topic switching missing on iOS** — The API supports `?topic=X` but the iOS `LeaderboardView` doesn't expose objective-level switching.
6. **All-time leaderboard empty until first Sunday** — `getAllTimeLeaderboard()` only aggregates `finalized: true` weekly boards, so it shows nothing until the first weekly finalization.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Topic scoping | Active objectives from `UserObjective` only | Tightest loop — users chose these, they'll compete on them |
| Automation level | Fully automated, zero admin | Admin review doesn't scale, generation quality comes from prompt quality |
| Cost strategy | On-demand daily generation (not weekly batch) | Spreads cost evenly, eliminates waste, scales with objectives not users |
| Competition level | Objective-level (not sub-topic) | Larger participant pools, fewer generations, sub-topics used for question variety |
| Sub-topic handling | Union of all sub-topics across users with that objective | Shared questions for everyone, level playing field |
| Question repetition | Include last 7 days of questions in GPT-4o prompt as exclusion list | Cheap safeguard, hard guarantee against repeats |
| Quiz length | 15 questions per challenge | Longer than 10, but not so long users skip it |
| Time limit | 12 minutes total, no per-question limit | Flexible — users self-allocate time across easy/hard questions |
| Question types | Conceptual MCQs only, no code snippets | Mobile-friendly, reliable to generate, competition is about knowledge breadth |
| Difficulty labels | Removed — GPT-4o naturally varies complexity | Pre-labeled difficulty was unreliable and subjective |
| Live events | Keep, fully automated | Created the night before, cron handles full lifecycle |
| Multiple challenges/day | One per objective per day | Scarcity drives habit, clear single leaderboard |
| All-time leaderboard | Include current week's running totals | Never empty — users see standings from day 1 |
| Topic normalization | Lowercase + trim, one-time migration + enforce on write | Clean break, avoids perpetual query complexity |
| Leaderboard visibility | Only user's own objective(s) | Users only see leaderboards for objectives they are enrolled in. No browsing other objectives. |

**Constraint assumption:** At scale (50,000 users), the number of distinct active objectives is expected to stay under ~20. This assumption is load-bearing for the cost model. If objectives grow beyond 30, consider batching GPT-4o calls or adding a popularity threshold.

---

## Architecture

### Sub-project A: Backend Pipeline Automation

#### 1. Topic Model

- Competitions run at the **objective level** (e.g., "Product Management"), not sub-topic level (e.g., "roadmapping")
- Topic names are **normalized** (lowercase + trim) at all storage and query points
- One-time migration script normalizes existing data (see Migration section below)
- All future service-layer writes enforce normalization before save via a shared `normalizeTopic(str)` utility: `str.trim().toLowerCase()`

#### 2. Sub-Topic Collection

To collect the union of sub-topics for an objective:

1. Query `UserObjective.find({ objective: normalizedObjective, status: 'active' })` → get list of `userId`s
2. Query `KnowledgeProfile.find({ userId: { $in: userIds } })` → for each profile, iterate `topicMastery` (a Mongoose Map keyed by topic name)
3. Collect all unique topic names from the Map keys across all profiles
4. **Cap at 20 sub-topics** — if the union exceeds 20, take the 20 most common (by user count). This prevents the GPT-4o prompt from becoming too large.
5. **If no sub-topics exist** (new objective, no users have studied anything yet) — use the objective name itself as the sole topic for question generation. GPT-4o generates questions about the objective broadly.

#### 3. Daily Pipeline (fully automated, single cron job)

**Cron: `generateAndActivateDaily` — Every day at midnight IST (18:30 UTC previous day)**

This is a **single cron job** that handles both daily challenges and live event creation (with a day-of-week branch for live events). There is no separate `createLiveEvents` cron.

**Steps:**

1. Query distinct active objectives: `UserObjective.distinct('objective', { status: 'active' })` → normalize each
2. For each objective, collect sub-topic union (see Section 2 above)
3. Fetch last 7 days of questions: `DailyChallenge.find({ topic: objective, date: { $gte: 7daysAgo } })` → extract all question texts
4. **One GPT-4o API call** per objective:
   - Prompt: "Generate 15 multiple-choice questions about {objective} covering these sub-topics: {sub-topics}. Each question has 4 options (A/B/C/D) with one correct answer and an explanation. Mix recall, application, and analytical questions. Vary complexity naturally. No code snippets. Do not repeat any of these questions: {exclusion list}"
   - Response format: `response_format: { type: 'json_object' }` → JSON array of 15 question objects
   - **On failure:** Retry up to 2 times with exponential backoff (1s, 3s). If all 3 attempts fail, log error, skip this objective for today, send alert to admin Slack webhook. Users for that objective get no challenge today — this is acceptable for a rare failure.
5. Create `DailyChallenge` with status `active`, `timeLimitSeconds: 720`
6. Close yesterday's challenge: `DailyChallenge.updateMany({ topic: objective, date: yesterday, status: 'active' }, { status: 'closed' })`
7. Send "Today's Challenge is Live!" push notification to all users with that objective via `notificationQueue`

**Live event branch (runs within the same job on Sun/Tue/Thu — eve of Mon/Wed/Fri):**

8. Check if today is Sunday, Tuesday, or Thursday
9. If yes: generate 15 additional questions per objective (separate GPT-4o call, same de-duplication including today's daily questions). Same retry/failure strategy.
10. Create `LiveEvent` documents: `{ topic, scheduledAt: tomorrow 8 PM IST, questions, status: 'scheduled' }`

#### 4. Scoring (simplified)

```
baseScore = correctAnswers × levelBonus
speedBonus = baseScore × 0.10 × speedFactor   (where 0 ≤ speedFactor ≤ 1)
finalScore = baseScore + speedBonus
```

| Component | Value | Source |
|-----------|-------|--------|
| `correctAnswers` | 0–15 (raw count) | From `ChallengeAttempt.answers` array |
| `levelBonus` | beginner: 1.20, intermediate: 1.10, advanced: 1.00, expert: 0.95 | From `CompetitionProfile.level` for the user (defaults to `beginner` if no profile exists) |
| `speedFactor` | `max(0, (medianTime - userTime) / medianTime)` — proportional to how far under the median the user finished. Capped at 1.0. If `userTime >= medianTime`, speedFactor = 0. | Calculated at daily finalization using all `ChallengeAttempt.timeTaken` values for that day's challenge |
| `speedBonus` | `baseScore × 0.10 × speedFactor` — maximum 10% bonus for instant completion, proportional reduction as time approaches median | Calculated at daily finalization |
| `timeLimitSeconds` | 720 (12 minutes) — stored on `DailyChallenge` document, iOS client reads it from the API response | |

**Provisional vs final score:** When a user completes a challenge, the API immediately returns `baseScore` (correctAnswers × levelBonus) as a provisional score. The speed bonus is added during daily finalization (00:30 IST). The weekly leaderboard is updated with the provisional score immediately, then adjusted during finalization. iOS shows "Score: 13.2" immediately; after finalization it might become "Score: 14.5" — the delta is small (max 10%) and users typically don't notice.

#### 5. Live Events (fully automated)

- **Schedule:** Mon/Wed/Fri at 8 PM IST — one event per objective
- **Creation:** Auto-created the night before during daily pipeline (steps 8-10 above)
- **Lifecycle via cron:**
  - 7:30 PM IST — Send "Live Event Tonight!" reminder notification
  - 7:55 PM IST — Open lobby (status → `lobby`)
  - 8:00 PM IST — Start event (status → `live`), set `startedAt` to now, schedule completion
  - 8:20 PM IST — Auto-complete all active live events (status → `completed`), build leaderboard, notify top 3
- **Questions:** 15 per event (same format as daily challenges)
- **Scoring:** Same formula as daily challenges
- **Auto-complete mechanism:** The `startLiveEvent` cron at 8:00 PM adds a delayed BullMQ job `completeLiveEvent` with a 20-minute delay. This ensures completion happens exactly 20 minutes after start regardless of participant activity. Additionally, a safety cron at 8:20 PM catches any events that weren't completed by the delayed job.

#### 6. Leaderboards

**Weekly leaderboard (per objective):**
- Updated **synchronously** during challenge completion: when `competitionService.completeChallenge()` is called, it writes the user's score to the `WeeklyLeaderboard` entry in the same request. This is safe because each user writes only their own entry (no contention between users).
- Entries track: `totalScore`, `challengesCompleted`, `bestDayScore`, `rank`, `percentile`
- **Finalized** every Monday at 00:30 IST (for the previous week):
  - Sort all entries by `totalScore` descending
  - Assign `rank` (1-indexed) and `percentile` (`Math.round((1 - (rank - 1) / totalEntries) * 100)`)
  - Top 3 per objective get push notification
  - Mark board `finalized: true`

**All-time leaderboard (per objective):**
- Aggregates all `finalized: true` weekly boards **plus the current week's running totals**
- MongoDB aggregation: `$match` on `{ topic, $or: [{ finalized: true }, { weekStart: currentWeekStart }] }` → `$unwind` entries → `$group` by userId → `$sum` totalScore and challengesCompleted → `$sort` → `$limit 50`
- **Never empty** — shows data from day 1 of competition

#### 7. What Gets Removed

| Component | Reason |
|-----------|--------|
| `ChallengeCandidateBank` model usage for daily flow | No weekly pre-generation; daily challenges created directly |
| `autoAssignQuestions()` | No assignment step needed |
| `generateWeeklyCandidates()` | Replaced by daily on-demand generation |
| Admin review/approval endpoints for candidates | Fully automated pipeline |
| Difficulty labels on generated questions | Removed — GPT-4o naturally varies complexity |
| Sunday night generation cron | Replaced by daily midnight cron |
| `_selectBalanced()` difficulty balancing | No difficulty categories to balance |
| Separate `createLiveEvents` cron | Folded into `generateAndActivateDaily` with day-of-week branch |

**Note:** The `ChallengeCandidateBank` model and existing data remain in the database (not deleted), but the daily pipeline no longer reads from or writes to it. Existing admin endpoints can be deprecated or removed.

#### 8. Cost Model

Cost scales with **number of active objectives**, not number of users.

| Scenario | Active Objectives | Daily GPT-4o Calls (non-live day) | Daily GPT-4o Calls (live day) | Weekly Total | Est. Cost/Week |
|----------|-------------------|-----------------------------------|-------------------------------|-------------|----------------|
| Early (10 users) | 6 | 6 | 12 | 60 | ~$0.60 |
| Growth (1,000 users) | 6 | 6 | 12 | 60 | ~$0.60 |
| Scale (5,000 users) | 6 | 6 | 12 | 60 | ~$0.60 |
| Max (50,000 users) | ~15 | 15 | 30 | 150 | ~$1.50 |

Previous system: 178 topics × 7 batches = 1,246 calls/week. New system: 60–150 calls/week.

---

### Sub-project B: iOS Leaderboard UX

#### 1. Default Leaderboard View

- When user opens `LeaderboardView`, show their **own objective's weekly leaderboard** by default
- Users can **only** see leaderboards for objectives they are enrolled in — no browsing other objectives
- If user has a single objective (current state): show that objective's leaderboard directly, no picker needed
- If user has multiple objectives (future): show a picker/dropdown to switch between their own objectives only

#### 2. All-Time Tab

- Leaderboard has two tabs/segments: **"This Week"** and **"All Time"**
- "This Week" — current weekly board (live, updated after each challenge completion)
- "All Time" — aggregated across all weeks including current running totals
- Both tabs always have data (never empty) because current week is always included

#### 3. Challenge Format Updates

- Update challenge UI to show 15 questions (was 10)
- Add 12-minute countdown timer (total, not per-question) — read `timeLimitSeconds` from the `DailyChallenge` API response
- Timer visible but not obtrusive — shows remaining time
- When timer expires, auto-submit with answers given so far (unanswered = incorrect)
- Remove any difficulty badge/label from question UI (no more easy/medium/hard indicators)

---

## Schema Changes

### `DailyChallenge` model — modifications

```
questions: [{ ... }]  // Array size changes from 10 to 15 (no schema constraint, just generation change)
// Remove from question sub-document:
-  difficulty: { type: String, enum: ['easy', 'medium', 'hard'] }
// Add to root:
+  timeLimitSeconds: { type: Number, default: 720 }
```

The `difficulty` field on existing question sub-documents can be left in place (Mongoose ignores extra fields if not in schema), or removed during the migration. New questions will not have it.

### `ChallengeAttempt` model — verify existing fields

The `ChallengeAttempt` model must have `timeTaken` (Number, seconds) stored when the user completes a challenge. This field already exists in the current schema. It is **required** for speed bonus calculation during daily finalization. The `answers` array stores per-question responses — already exists.

### `LiveEvent` model — no changes needed

Questions array already supports variable length. The `completedAt` and `leaderboard` fields already exist.

### `WeeklyLeaderboard` model — field rename

```
// Rename for clarity (matches new scoring):
-  totalHandicappedScore → totalScore
-  handicappedScore → score  (in leaderboard entries)
```

Or keep existing field names and just repurpose them — the values stored will be the new `finalScore` instead of the old handicapped score. **Decision: keep existing field names to avoid migration complexity.** The field `totalHandicappedScore` will store the new `finalScore` values. Document this in code comments.

### `CompetitionProfile` model — verify `level` field

The `level` field (enum: beginner/intermediate/advanced/expert) must exist on `CompetitionProfile`. This is the source for `levelBonus` in scoring. If a user has no `CompetitionProfile`, default to `beginner` (1.20 bonus).

---

## Migration Plan

### One-Time Topic Normalization Script

**Run BEFORE deploying new code** (so both old and new data are consistent when new code goes live).

```javascript
// Script: scripts/normalize-topics.js
// Idempotent — safe to re-run (lowercasing an already-lowercase string is a no-op)

const collections = [
  { model: 'DailyChallenge', field: 'topic' },
  { model: 'WeeklyLeaderboard', field: 'topic' },
  { model: 'LiveEvent', field: 'topic' },
  { model: 'ChallengeCandidateBank', field: 'topic' },
];

for (const { model, field } of collections) {
  // Update all documents: set topic = lowercase(trim(topic))
  await Model.updateMany({}, [{ $set: { [field]: { $toLower: { $trim: { input: `$${field}` } } } } }]);
}

// KnowledgeProfile.topicMastery is a Map — needs per-document iteration
// UserObjective topic fields — normalize objective and topic fields
```

**Ordering:**
1. Run migration script on production MongoDB
2. Deploy new backend code
3. Verify daily pipeline runs successfully

**In-flight documents:** Active `DailyChallenge` and `WeeklyLeaderboard` documents mid-week will have their topics lowercased. Since the new code also lowercases, lookups will match. No data loss.

---

## Cron Schedule (revised)

All competition crons are managed via BullMQ repeatable jobs, registered in `cronJobs.js`.

| Cron (UTC) | IST | Job Name | What it does |
|-----------|-----|----------|-------------|
| `30 18 * * *` | Daily midnight | `generateAndActivateDaily` | Generate 15 questions per objective, create + activate DailyChallenge, close yesterday's, send notifications. On Sun/Tue/Thu also generates live event questions and creates LiveEvent documents for next day. |
| `0 19 * * *` | Daily 00:30 | `finalizeDailyRankings` | Calculate speed bonuses for yesterday's closed challenge (median time from all attempts, proportional bonus), update finalScores on WeeklyLeaderboard entries |
| `0 19 * * 0` | Monday 00:30 | `finalizeWeeklyLeaderboard` | Rank all entries in previous week's boards, calculate percentiles, notify top 3, mark finalized |
| `30 15 * * *` | Daily 21:00 | `streakReminderNotification` | Remind users with active streaks who haven't completed today's challenge |
| `0 14 * * 1,3,5` | Mon/Wed/Fri 19:30 | `liveEventReminder` | Send "Live Event Tonight!" notifications to users with matching objectives |
| `25 14 * * 1,3,5` | Mon/Wed/Fri 19:55 | `openLiveEventLobby` | Set live event status to `lobby` |
| `30 14 * * 1,3,5` | Mon/Wed/Fri 20:00 | `startLiveEvent` | Set status to `live`, add delayed `completeLiveEvent` job (20 min delay) |
| `50 14 * * 1,3,5` | Mon/Wed/Fri 20:20 | `completeLiveEventSafety` | Safety net: complete any live events still in `live` status (catches missed delayed jobs) |

**Timing clarification for daily finalization:**
- Midnight: new challenge activated, yesterday's closed
- 00:30 AM: `finalizeDailyRankings` processes the **just-closed** challenge (the one from yesterday). By this point, the challenge has been live for 24 hours and is now closed — all attempts are in. The median time is calculated from all `ChallengeAttempt` documents for that challenge, and speed bonuses are applied.

---

## Sample Walkthrough

**Setup:** 5,000 users, 6 active objectives (Product Management, Software Engineering, Data Science, UX Design, Marketing, Entrepreneurship).

**Monday midnight IST:**
1. `generateAndActivateDaily` cron fires
2. Queries `UserObjective` → 6 active objectives
3. For "Product Management" (1,200 users): collect sub-topics union → roadmapping, prioritization, user research, metrics, product-market fit (5 sub-topics, under cap of 20)
4. Fetch last 7 days PM questions → 105 questions to exclude
5. GPT-4o call: generate 15 MCQs about PM covering those sub-topics, excluding previous questions
6. Create `DailyChallenge` for PM, status `active`, `timeLimitSeconds: 720`
7. Close Sunday's PM challenge (status → `closed`)
8. Repeat for 5 other objectives → 6 total API calls
9. Today is Monday (live event day), and it's the eve-check: actually Sunday night is the eve of Monday. The cron runs at midnight Monday IST = end of Sunday. Check: is today Sunday? Yes (in UTC it's still Sunday 18:30). → Generate 6 more sets of 15 questions for live events → 6 more API calls
10. Create 6 `LiveEvent` documents for Monday 8 PM IST
11. Send ~5,000 push notifications (one per user for their objective)
12. **Total: 12 GPT-4o calls**

**Monday 10 AM — User A plays:**
1. Opens app, sees "Product Management" daily challenge
2. 15 questions, 12-minute countdown timer starts
3. Completes in 6 minutes, gets 11/15 correct
4. Provisional score: 11 × 1.20 (beginner) = 13.2 (speed bonus added at 00:30 tomorrow)
5. Weekly leaderboard updated with provisional score — currently #45 out of 312 who've played today
6. Taps "All Time" tab — sees running totals (same as this week since it's week 1)

**Monday 8 PM — Live event:**
1. 7:30 PM: reminder notification sent
2. 7:55 PM: lobby opens, users join
3. 8:00 PM: event starts, 15 questions, real-time progression
4. 8:20 PM: `completeLiveEvent` delayed job fires — event completes, leaderboard built, top 3 notified

**Tuesday 00:30 AM — Daily finalization:**
1. `finalizeDailyRankings` processes Monday's now-closed challenge
2. Median completion time for PM challenge: 7.5 minutes (from all 312 attempts)
3. User A completed in 6 minutes: speedFactor = (7.5 - 6) / 7.5 = 0.20
4. Speed bonus = 13.2 × 0.10 × 0.20 = 0.264
5. Final score: 13.2 + 0.264 = 13.464
6. Weekly leaderboard updated with final score

**Sunday 00:30 AM IST — Weekly finalization:**
1. For each objective, sort all entries by `totalScore` descending
2. Assign ranks and percentiles
3. Top 3 notified: "You finished #1 this week in Product Management!"
4. Board marked `finalized: true`
5. All-time leaderboard now includes this finalized week + next week's running data
