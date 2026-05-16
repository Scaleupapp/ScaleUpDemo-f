# Competition Cohort Matching & Integrity — Design

**Date:** 2026-05-15
**Author:** Nirpeksh + Claude (brainstorm)
**Scope:** Make the daily competition feature meaningful by ensuring users with similar objectives actually compete on the same content, with deterministic per-user shuffle for anti-cheat, ghost participants for tiny cohorts, and a real readiness payoff when you win.

---

## 1. Problem statement

The V2 Competition surface (build 139) ships with a primitive matching rule: `challenge.topic.toLowerCase().includes(userObjectiveTopic.toLowerCase())`. This silently fragments cohorts ("PM" / "Product Manager" / "product-management" never meet), gives no story for cohorts of 1–3 users, and offers no integrity for the "everyone gets the same 15 questions" model (a screenshot or ChatGPT answer trivially boosts you up a time-ranked leaderboard). It also doesn't connect competition performance to the Home readiness number, so winning doesn't *do* anything in the user's main loop.

---

## 2. Decisions (locked during brainstorm)

| # | Question | Decision |
|---|----------|----------|
| 1 | Cohort grain | **Topic only** — one cohort per canonical topic. No skill-level sub-cohorts. |
| 2 | Tiny cohort handling | **Ghost participants** — historical averages + persona bots until real cohort ≥ 10. |
| 3 | Anti-cheat | **Per-user shuffled order + shuffled A/B/C/D labels**, deterministic by `(userId, challengeId)`. Accept ChatGPT cost. |
| 4 | Canonicalization | **Free text + LLM normalization at write time**, mapped to a curated taxonomy of ~30 canonical topics. |
| 5 | Stakes | **Streak + leaderboard rank + KnowledgeProfile mastery boost**. No external perks budget. |
| 6 | Approach | **Lean Phase 1 + Cohort Directory** (Approach B). |

---

## 3. Architecture overview

Three data-flow paths:

- **Objective write path** — user saves objective → `topicCanonicalizationService.canonicalize(rawText, objectiveType)` returns a canonical topic from a maintained list → written to `UserObjective.canonicalTopic` → `CohortDirectory` upserted (member count incremented).
- **Daily-challenge generation (00:30 IST cron)** — reads `CohortDirectory.find({isActive: true})` → one `DailyChallenge` per cohort per day, keyed by `(topic=canonicalTopic, date)`.
- **User play path** — `GET /competition/relevant` finds today's challenge for the user's `canonicalTopic` via exact match → `POST /challenges/:id/start` returns the challenge with questions shuffled deterministically per user → `PUT /challenges/:id/answer` translates the shuffled-label answer back to canonical before scoring → `POST /challenges/:id/complete` writes to `ChallengeAttempt`, `CompetitionProfile`, `WeeklyLeaderboard`, **and `KnowledgeProfile.topicMastery`** (new bridge). Leaderboard endpoint composes real entries + ghosts when cohort < 10.

Existing models that don't change: `ChallengeAttempt`, `WeeklyLeaderboard`, `CompetitionProfile`, `DailyChallenge` (schema unchanged; only the key meaning shifts to canonical).

---

## 4. Canonical topic + LLM normalization

### Model change

`UserObjective` gains:

```js
canonicalTopic: { type: String, lowercase: true, index: true }
canonicalTopic_needsReview: { type: Boolean, default: false }
canonicalTopic_lastResolvedAt: Date
```

### Service

New file: `src/services/topicCanonicalizationService.js`

```
canonicalize(rawText, objectiveType) → { canonicalTopic, confidence, source: 'llm'|'cache'|'fallback' }
```

- Curated taxonomy lives in `src/config/canonicalTopics.js`: ~30 entries (`gmat`, `gre`, `cat`, `upsc`, `product-manager`, `software-engineer`, `data-scientist`, `mba-admissions`, `ielts`, `toefl`, `frontend-engineer`, `devops-engineer`, etc.) each tagged with one or more `objectiveType` values they're valid for.
- LLM call (gpt-4o-mini, low cost) given the raw text + valid canonical options for the user's objective type. Output schema: `{canonicalTopic, confidence}`. If none fit, LLM returns the closest broader bucket from the type's allowed list.
- Result cached keyed by `(normalized(rawText), objectiveType)` — identical inputs are free thereafter. Cache TTL 90 days.
- **Fallback**: if LLM call fails, write `normalizeTopic(rawText)` (lowercase+trim) to `canonicalTopic`, set `canonicalTopic_needsReview: true`. The retry job revisits these.

### Triggers

- Objective `pre('save')` hook resolves canonical topic when `specifics` or `objectiveType` changes.
- Lazy backfill on read: any service that loads an objective and finds `!canonicalTopic` enqueues a fire-and-forget canonicalize and writes the result.
- Nightly job `retryCanonicalizationReview` walks `canonicalTopic_needsReview: true` and re-attempts.

---

## 5. `CohortDirectory` collection

New model: `src/models/CohortDirectory.js`

```js
{
  canonicalTopic: { type: String, unique: true, index: true },
  displayName: String,                       // "GMAT" — LLM-titled, cached
  objectiveTypes: [String],                  // which objective types map here
  memberCount: Number,                       // active members in last 30 days
  weeklyAttempts: Number,                    // rolling 7-day count
  lastChallengeDate: Date,
  lastAttemptAt: Date,
  isActive: { type: Boolean, default: true },
  personaGhosts: [{                          // populated on first creation
    name: String,
    medianOffset: Number,                    // score offset vs cohort median
    seed: String,                            // stable per-persona seed
  }],
  historicalStats: {                         // updated by weekly leaderboard cron
    last30dAverageScore: Number,
    last30dP90Score: Number,
    sampleSize: Number,
    refreshedAt: Date,
  },
}
```

### Maintenance

- **On objective save** with canonical topic resolved → `CohortDirectory.findOneAndUpdate({canonicalTopic}, {$setOnInsert: {...}, $inc: {memberCount: 1}}, {upsert: true})`. Persona ghosts are generated and persisted on insert (one-time, never regenerated).
- **On objective deactivate/change away** → `memberCount: -1` (floor at 0).
- **On `ChallengeAttempt` complete** → `weeklyAttempts: +1`, `lastAttemptAt: now`.
- **Nightly housekeeping cron `cohortDirectoryHousekeeping`** — rebuilds `memberCount` and `weeklyAttempts` from source-of-truth aggregates (drift correction). Refreshes `historicalStats` from rolling-window leaderboard data. Marks cohorts with no attempts in 30 days `isActive: false`; reactivates on next membership change.

---

## 6. Daily challenge generation — revised

`challengeGenerationService.generateAndActivateDaily()` changes:

- Source: replace `_getActiveObjectives()` (which scans `UserObjective`) with a query of `CohortDirectory.find({isActive: true, memberCount: {$gt: 0}})`.
- Loop: same logic — for each cohort, generate one `DailyChallenge(topic=canonicalTopic, date)`. Generation prompt and 15-question shape unchanged.
- Display title: prefer `CohortDirectory.displayName`; if absent, call existing `_generateDisplayTitle(topic)` and write back to the directory.
- Sub-topics: `_getSubTopicsForObjective(canonicalTopic)` queries `UserObjective.topicsOfInterest` for users whose `canonicalTopic === input`. Logic same, input cleaner.
- Cold-start: brand-new cohort with member count 1 and no past attempts is included as long as it's in the directory and active. Ghost leaderboard makes day 1 playable.
- Existing yesterday-close step preserved unchanged.

Cron schedule (00:30 IST via `competitionQueue`) is unchanged.

---

## 7. Per-user shuffle on serve

### Storage

`DailyChallenge.questions` stays in canonical order. `correctAnswer` stays as the canonical label (A/B/C/D pointing to the canonical option text).

### Shuffle generation

On `competitionService.startChallenge(userId, challengeId)`:

1. Derive `seed = sha256(userId + ":" + challengeId)`.
2. Fisher-Yates permute the 15 question indices using `seed` → `questionOrder: [origIdx0, origIdx1, ...]`.
3. For each question, derive a per-question sub-seed `sha256(seed + ":q" + origIdx)`, Fisher-Yates permute `["A","B","C","D"]` → `optionLabelMap[origIdx] = {A: <shuffledLabel>, B: ..., ...}` (mapping canonical label → label shown to user).
4. Persist `questionOrder` and `optionLabelMap` on the `ChallengeAttempt` document at start time.
5. Return to client: questions in shuffled order, with each question's options re-labeled. Client sees a fresh-looking quiz; never sees canonical order or correct-answer label.

### Resume

Same `(userId, challengeId)` produces the same seed deterministically. Even if persisted maps are lost, regeneration is identical. Paused/resumed attempts see the same arrangement.

### Answer submission

`PUT /challenges/:id/answer` receives `(questionIndex, selectedLabel)` — both in the user's shuffled space. Server:

1. Loads `ChallengeAttempt` → reads `questionOrder` and `optionLabelMap`.
2. `originalQuestionIdx = questionOrder[questionIndex]`.
3. `originalLabel = inverse(optionLabelMap[originalQuestionIdx])[selectedLabel]`.
4. Compare `originalLabel` to `challenge.questions[originalQuestionIdx].correctAnswer`.
5. Persist on the attempt: both the canonical answer (for scoring) and the user-facing tuple (for results display so explanation/options render correctly).

### What this defeats

- Screenshots and "Q3 is B" peer-sharing — your Q3 isn't your friend's Q3, and B doesn't mean what their B means.

### What this does NOT defeat (accepted)

- ChatGPT-ing the question text. Live-event format would be needed to close this; deferred.

---

## 8. Ghost leaderboard

Computed on read by the leaderboard endpoint. **Never persisted.** Tagged so the client can mark them visually.

### Trigger condition

Real entry count for `(canonicalTopic, weekStart)` is `< 10`. ≥ 10 → ghosts dropped, leaderboard is purely real.

### Two ghost kinds

**Historical anchors (2 rows):**
- Names: `Cohort top 10% (last month)`, `Cohort average (last month)`.
- Scores: read from `CohortDirectory.historicalStats.last30dP90Score` and `.last30dAverageScore`.
- `ghostKind: "historical"`. Italic display, no avatar.

**Persona ghosts (3 rows):**
- Names + medianOffset + seed are stored on `CohortDirectory.personaGhosts` at cohort creation (one-time).
- Weekly score: `cohortMedianThisWeek + persona.medianOffset + deterministicJitter(persona.seed, weekStart)`. Same persona drifts week-over-week within a plausible band — user sees themselves climbing past stable competitors over weeks.
- `ghostKind: "persona"`. Displayed identically to real rows except a long-press subtext: *"Synthetic competitor — see how you stack against the cohort historically."*

### Honesty rule

Ghosts never occupy #1 when there are real entries. If a persona's computed score would rank #1, it's bumped down one slot. User can verify via long-press that ranked-above rows aren't fake-padded.

### Composition order

Real entries by handicapped score → ghosts merged in by score → final sort.

---

## 9. Readiness pipeline

The user-visible payoff: completing a daily challenge moves the Home readiness number.

### Wiring

In `competitionService.completeChallenge`, after `handicappedScore` is computed and persisted:

1. Build a synthetic `topicBreakdown` from `challenge.questions` grouped by `question.concept` (fallback to `challenge.topic`). For each concept: `{topic: concept, correct: nCorrect, total: nAnswered, percentage}`.
2. Call `knowledgeService.updateMastery(userId, topicBreakdown, {source: 'competition', weight: 0.5})`.
3. `knowledgeService.updateMastery` gains a `source` and `weight` parameter:
   - `quiz` → weight 1.0 (current behavior, documented)
   - `competition` → weight 0.5 (timed, shorter, less diagnostic per question)
   - `interview` → reserved for future, default 1.0
4. The same path automatically feeds `misconceptionService` and `spacedRepetitionService`, so the existing cross-context personalization (Compass, quiz generation) picks up patterns from competition mistakes for free.

### User-visible result

`/plan/today` reads `KnowledgeProfile.topicMastery` to compute readiness. Finishing today's challenge → mastery bump → readiness tick → trajectory chart redraw on next Home refresh. Top-gap may shift if the challenge was on the user's worst area.

---

## 10. Migration

No stop-the-world. Backfill in three modes:

- **Lazy on read** — any code that loads `UserObjective` and finds `!canonicalTopic` enqueues a canonicalize job. The current request uses `normalizeTopic(derivedString)` as a stand-in so the user isn't blocked.
- **Bulk script `scripts/backfill-canonical-topics.js`** — walks active `UserObjective` documents missing `canonicalTopic`, canonicalizes, writes. Idempotent.
- **Bootstrap script `scripts/bootstrap-cohort-directory.js`** — after backfill, groups by `canonicalTopic`, creates one directory entry per, seeds `memberCount` from group size, `weeklyAttempts` from a 7-day `ChallengeAttempt` aggregate, `historicalStats` from 30-day aggregate, `personaGhosts` generated and persisted.

Existing `DailyChallenge` records keep their current `topic` values. Old and new co-exist via the unique `(topic, date)` key. Old expire naturally in 24h.

Zero downtime, zero data loss. If the canonicalizer is unreachable during backfill, entries stay unmigrated and retry via lazy-on-read or nightly housekeeping.

---

## 11. iOS changes

Minimal — V2CompetitionHomeView (build 139) already speaks the right shape.

- **Topic-match indicator** keeps its current UI; the `topicMatch` flag's semantics tighten from substring to exact canonical match. No code change needed.
- **Cohort size hint** (new): under the challenge card title, render `"<memberCount> in your cohort · <playedToday> played today"`. Backend adds `cohortMemberCount` and `cohortPlayedToday` fields to `/competition/relevant` response.
- **Leaderboard rendering**: existing `CompetitionHubView` weekly-leaderboard rows need to honor `entry.ghostKind` — italic label, long-press subtext for `"persona"` and `"historical"` rows. Backend tags entries server-side.

No new screens. No new Compass changes beyond the Compete chip that's already shipped. No Home changes beyond what's already shipped.

---

## 12. Out of scope (deferred)

- Skill-level sub-cohorts (e.g., GMAT 600-700 vs 700+). Re-open if cohorts grow large enough to make grain meaningful.
- ChatGPT-ing protection beyond shuffle (would require live-event-only format).
- External perks / rewards budget tied to leaderboard wins.
- Discussion threads per challenge.
- Compass-driven "popular cohort" discovery surface (the CohortDirectory makes this trivial to add later).

---

## 13. Open verification items

These need a quick code-check at plan time, not redesign:

- Does `knowledgeService.updateMastery` exist with the topicBreakdown signature, or does the bridge step need a small adapter? (Probably the latter — quiz scoring service updates mastery via its own internal flow.)
- Is `competitionQueue` already wired to receive the housekeeping job, or does the worker need a new handler registration?
- `CompetitionHubView` is v1 code — confirm we can add the `ghostKind` visual without breaking v1 leaderboard UX.

---

## 14. Success criteria

- Two users who type their objective as "PM" and "Product Manager" land in the same canonical cohort and see the same daily challenge.
- A solo new user in a fresh cohort sees a 5-row leaderboard (self + 2 historical + 2 personas) instead of a 1-row leaderboard.
- Two users sharing a Q3 screenshot can't trivially co-cheat — their shuffles differ.
- Finishing a daily challenge moves the user's Home readiness number measurably (1–3 points depending on score and topic weight).
- `CohortDirectory.memberCount` matches the active-objective count within ±1 after a housekeeping pass.
