# Day-1 Proficiency Diagnostic — Design Spec

**Date:** 2026-04-27
**Status:** Approved by product, awaiting implementation plan
**Author:** Brainstorming session with product owner
**Related:** BUG-8 personalisation system (Phases 1-9, already shipped)

---

## 1. Problem

A new user signs up, declares an objective (e.g. *"Senior PM in 3 months"*), picks interest tags, and is dropped into a generic plan. The plan looks the same for a junior PM with 6 months of experience and a senior PM with 8 years of experience targeting their next role. Neither person feels seen.

Worse, every personalisation system we just shipped (Phases 4-9: misconception fingerprinting, spaced repetition, cognitive fingerprint, prerequisite graph, cross-feature memory, transparent inference panel) needs *real activity data* to start working. Without it, those systems sit dormant for the first 2-3 weeks of a user's life on the platform — exactly the period where activation matters most.

This spec covers the design for a short, optional, value-framed proficiency diagnostic that runs as the final step of onboarding, calibrated to the user's declared objective. The diagnostic seeds every Phase 4-9 system with day-1 data and feeds into a plan that's actually built for the user's level.

A separate spec (deferred) will cover the related but distinct problem of out-of-coverage domain handling.

---

## 2. Goals & non-goals

**Goals (in scope):**

- Generate a meaningfully personalised plan on day 1, calibrated to the user's actual proficiency, not just their declared objective.
- Capture two distinct signals: (a) self-assessed proficiency per competency, (b) actual proficiency via a short adaptive diagnostic.
- Seed `KnowledgeProfile.topicMastery`, `ConceptMastery` (Phase 5 spaced-repetition state), and any other Phase 4-9 stores so personalisation activates immediately.
- Capture the *delta* between self-rating and assessed performance — a novel signal we don't have anywhere else.
- Provide a fundamentally different ("synthesis-first") flow for existing users who already have activity history.
- Hold zero perceived latency. The diagnostic must feel fast, even on first use of an obscure competency.
- Be fully backward-compatible: zero impact on existing users who choose not to engage with this feature.
- Be opt-out-able at every step. Skipping must never break the experience.

**Non-goals (out of scope for this spec):**

- Domain coverage gaps (what to do when an objective falls outside our content library) — separate spec.
- Real coding-exercise UI ("write your own function" prompts). The diagnostic uses MCQ-format only, including for coding domains.
- Re-architecting the existing `quizGenerationService` — diagnostic generation extends it, not replaces it.
- Mid-flow plan switching for users who change their objective during the diagnostic — we treat objective changes as a separate event handled outside the diagnostic.
- Localisation. v1 is English only; localisation follows the existing app-wide pattern when added.

---

## 3. The new-user flow

After existing onboarding (objective declared, interests captured, `UserObjective.analysis.competencies` mapped), insert five new screens.

### Screen 1 — The pitch

Header: *"Quick check before we build your plan"*

Body: *"ScaleUp is way more useful when we know where you're actually starting from. Take 5 minutes now and your plan will be built for your level — not a generic one."*

Buttons:
- `[Take the 5-min check]` (primary)
- `[Skip — I'll let it learn from my activity]` (secondary, less prominent but visible)

If skipped → existing flow path: generic plan, generic Insights cold-start card.

### Screen 2 — Self-rate

For each competency in `UserObjective.analysis.competencies`, present a 4-point scale plus an "unsure" option:

| Option | Stored as |
|---|---|
| Novice — never really done this | `novice` |
| Familiar — exposed to it | `familiar` |
| Proficient — can do it confidently | `proficient` |
| Expert — can teach it | `expert` |
| I'm honestly not sure | `unsure` |

~30-45 seconds total. Stored on `KnowledgeProfile.topicMastery[].selfRating` (new field).

**Critical timing detail:** As soon as Screen 2 loads, the backend fires the **pool-generation LLM call** (described in Section 5). The user's self-rating time is also the loading time for question generation. They should never see a spinner.

### Screen 3 — Adaptive diagnostic

8-10 questions drawn from a pre-generated pool, selected adaptively based on running performance (Section 6).

Per-question UI:
- Question text + 4 options
- 30-60 second timer (visible but subtle)
- After answer: 2-second flash of feedback ("Got it" / "Hmm, the answer was X — quick note: ...") then next question
- No big right/wrong reveal that breaks momentum
- Small progress bar showing position in quiz

User cannot skip mid-question (forces commitment), but can abandon the quiz (handled in Section 9).

### Screen 4 — Results

Per-competency display, two values side by side: *self-rating* vs *assessed*.

Three framings depending on the gap:

| Gap | Framing |
|---|---|
| Aligned (within 1 bucket) | *"You rated yourself proficient and you scored proficient — solid."* |
| Pleasant surprise (assessed > self-rated by 2+ buckets) | *"You rated yourself novice but scored intermediate — you know more than you think."* |
| Worth knowing (self-rated > assessed by 2+ buckets) | *"You rated yourself proficient but scored familiar — let's build accordingly."* |

The third framing is always kind, never "you were wrong."

CTA: `[Build my plan]`.

### Screen 5 — Plan reveal

The existing plan-generation pipeline runs, with `proficiencyData` (from steps 2 + 3) injected. Plan is ordered by gap-to-target, calibrated to the objective deadline. Topics where they're already strong are marked as "review" or skipped entirely. Weak topics get extra time.

---

## 4. The existing-user flow

For any user with `KnowledgeProfile.totalQuizzesTaken >= 1` OR who completed onboarding before this feature shipped, the new-user flow is wrong. Asking them to retake an "assessment" feels like the system has forgotten them. Instead they get a fundamentally different experience — *synthesis-first, then targeted gap-fill*.

The existing user is offered this flow via a one-time card on the Progress tab cold-start state (and an entry point in Profile → Settings). It is never auto-triggered.

CTA framing: **"Tune your plan"**, not "Take an assessment."

### Screen E1 — Synthesis ("Here's what we know about you")

A personalised card or short stack, built from `userContextService.getUserContext()` which already aggregates:

- Quiz history → strongest / weakest topics
- `MisconceptionLedger` → recurring confusions
- `ConceptMastery` → topics due for review
- `CognitiveProfile` → time-of-day / modality / session rhythm
- `UserObjective` → progress toward goal
- `Conversation` (AI Tutor) → recent topics asked about

Sample copy:

> *"Based on your 47 quizzes, 23 hours of content, and 8 AI Tutor sessions over the last 3 months, here's the picture:*
> - *Strongest: Statistics (78%) and Stakeholder Management (72%)*
> - *Weakest: System Design (42%) and Roadmapping (45%)*
> - *Recurring confusion: You consistently mix up P(A|B) and P(B|A) — shown up in 6 quizzes*
> - *You learn best in evening sessions (+14pp lift)*
> - *Almost there: 71% of the way to your Senior PM goal, 38 days remaining"*

This is value, not friction.

### Screen E2 — Goal check

Two questions:
- *"Goal still: Senior PM in 38 days?"* `[Yes]` `[Update]`
- *"Anything new you want to add to your focus?"* (free text or pick from competency list)

Two taps if everything's still right.

### Screen E3 — Self-rating (always)

Same as new-user flow. Even with 47 quizzes, we've never asked the user how confident they *feel*. The calibration delta is novel signal.

### Screen E4 — Targeted gap questions (variable length)

For each competency in their goal, the system decides how many questions to ask based on existing data signal:

| Existing data signal per competency | Questions asked |
|---|---|
| Strong (5+ attempts, score variance < 15pp) | 0 — trust existing data |
| Medium (2-4 attempts, OR variance 15-30pp) | 1 — disambiguator |
| Weak (0-1 attempts) | 2-3 — fill the gap |

Heavy existing user: 0-2 questions total, ~2 min flow.
Lightly active existing user: 4-6 questions, ~5 min.
Very active user with no goal-aligned competency gaps: skip questions entirely.

### Screen E5 — Refined plan

Plan-generation pipeline runs with the full input set: existing scores + new self-ratings + new diagnostic answers.

---

## 5. Question generation architecture

The core challenge: support *any* competency on day 1 with *zero* perceived latency.

**Strategy: pool generation during self-rating + adaptive selection from pool + cache as side-effect.**

### Pool generation

When the user enters Screen 2 (self-rating), the backend immediately fires **one batched LLM call** that generates a pool of ~20-25 questions covering all the user's linked competencies. This call uses gpt-4o-mini, takes 8-15 seconds, and is masked by the user's time on the self-rating screen (~30-45 seconds). They never see a spinner in the common case.

**Pool composition** is informed by self-rating per competency. The total pool size is fixed at ~24 questions; the per-competency allocation scales with how many competencies the user has (e.g., 3 competencies → ~8 questions each; 6 competencies → ~4 questions each, with a hard floor of 3).

Within each competency's allocation, the difficulty mix follows the self-rating:

| Self-rated as | Difficulty mix (proportions, applied to that competency's allocation) |
|---|---|
| Novice / Unsure | ~60% easy · 25% medium · 15% hard |
| Familiar | ~40% easy · 50% medium · 10% hard |
| Proficient | ~25% easy · 50% medium · 25% hard |
| Expert | ~10% easy · 40% medium · 50% hard |

So a user with 3 competencies (each with ~8 questions allocated) who self-rated Novice / Familiar / Proficient on the three would get a pool of ~24 questions distributed roughly: (5e/2m/1h) for the first, (3e/4m/1h) for the second, (2e/4m/2h) for the third.

The LLM is told to generate questions across all 3 buckets per competency; the *runtime selector* (Section 6) is what actually shows them in the right order based on running performance.

**LLM prompt structure:**

```
System: [Existing distractor-quality + misconception-tagging rules from Phase 4]
        + diagnostic-specific rules:
        - Generate {N} questions per competency, evenly across 3 difficulty buckets
        - "easy" = recall/recognition
        - "medium" = apply concept to a new example
        - "hard" = multi-step reasoning, edge cases, compare/contrast
        - Include misconception tags on every distractor (Phase 4 contract)

User: { competencies: [...], userObjective: "...", self_ratings: {...} }
```

**Failure mode:** if the LLM call exceeds ~20 sec or returns malformed JSON, fall through to a brief "preparing your questions..." spinner state. If failure persists after one retry, fall back to the cached `DiagnosticQuestionBank` (described next).

### Cache as side-effect

After every diagnostic completes, the pool's questions are saved to a `DiagnosticQuestionBank` keyed by `(canonicalCompetency, difficulty)`. Unused questions become seed data for future users.

The next user with overlapping competencies can pull partly from cache + top up via a smaller live call (faster, cheaper). Over weeks, common competencies build rich pools organically without speculative pre-generation.

### Competency name normalization

A normalization layer prevents bank fragmentation across users:

1. Lowercase, trim, strip punctuation
2. Resolve aliases via a small dictionary (`'sql joins'` ↔ `'joins'` ↔ `'database joins'`)
3. For unmatched names, embed and check cosine similarity against existing keys (>0.85 threshold = same key)

Stored as `canonicalCompetency` on each bank entry.

### Coding-domain handling

Coding domains (Python, JavaScript, SQL, etc.) use the *same* generation pipeline, but the prompt knows the competency type and produces code-readable MCQ questions:

- *"What does this snippet output?"*
- *"Which line has the bug?"*
- *"Pick the correct syntax for X"*
- *"Trace this loop — what's `i` after iteration 3?"*

No "write your own function" prompts. Real coding exercises belong in the post-onboarding practice flow, not in a 5-min day-1 baseline.

---

## 6. Adaptive selector logic

The pool generated in Section 5 contains more questions than we'll show. The selector picks the next question at runtime based on running performance.

### Selection rules

For each competency, the selector maintains running state: `[easy_correct, easy_wrong, medium_correct, medium_wrong, hard_correct, hard_wrong]`.

**First question per competency:** difficulty matches self-rating bucket:
- Novice / Unsure → easy
- Familiar → easy or medium (random)
- Proficient → medium
- Expert → medium or hard (random)

**Subsequent question selection:**
- If correct + answered in <½ allotted time → next question one bucket harder (clamped at hard)
- If correct + normal time → stay at current bucket
- If wrong → next question one bucket easier (clamped at easy)

**Stopping rule per competency:**
- After 2 consistent answers (both correct at same level, or both wrong at same level) → confident read, stop
- After 3 questions → stop regardless (avoid burning quiz budget on one competency)
- Total quiz capped at 10 questions across all competencies

### Output: per-competency proficiency band

After the selector runs, output one of: `novice` / `familiar` / `proficient` / `expert` per competency. This translates to a numeric score for `KnowledgeProfile.topicMastery`:

| Band | Score |
|---|---|
| novice | 25 |
| familiar | 50 |
| proficient | 70 |
| expert | 88 |

The exact score gets refined over time by actual quiz attempts; this is the day-1 baseline.

### Calibration signal

The selector's output, combined with the self-rating from Screen 2, produces the **calibration delta**:

- Same band → calibrated
- Self-rating > assessed by 1 band → mildly over-confident
- Self-rating > assessed by 2+ bands → significantly over-confident
- Assessed > self-rating → under-confident

Stored on `KnowledgeProfile.topicMastery[].calibrationAtBaseline`. The Insights system can later use this for tone-tuning ("you tend to under-rate yourself, this score is solid").

---

## 7. Data model changes

All changes are additive. No modifications to existing fields. No migrations required.

### Extended models

**`KnowledgeProfile.topicMastery[]`** gets two new optional fields:

```js
selfRating: {
  type: String,
  enum: [null, 'novice', 'familiar', 'proficient', 'expert', 'unsure'],
  default: null,
}
calibrationAtBaseline: {
  delta: { type: Number, default: null }, // -3 to +3
  capturedAt: { type: Date }
}
```

### New collections

**`DiagnosticAttempt`** — one document per attempt (separate from `QuizAttempt` because it's a different artefact with a different lifecycle):

```js
{
  userId: ObjectId,
  status: 'in_progress' | 'completed' | 'abandoned',
  startedAt: Date,
  completedAt: Date,

  // Pool used for this attempt
  poolQuestionIds: [ObjectId],  // refs into DiagnosticQuestionBank

  // What the user answered
  answers: [{
    questionId: ObjectId,
    competency: String,
    difficulty: 'easy' | 'medium' | 'hard',
    selectedAnswer: String,
    isCorrect: Boolean,
    timeTaken: Number,  // seconds
  }],

  // Self-rating snapshot at attempt time
  selfRatings: { [competency: string]: 'novice' | 'familiar' | 'proficient' | 'expert' | 'unsure' },

  // Computed output
  results: {
    [competency: string]: {
      assessedBand: 'novice' | 'familiar' | 'proficient' | 'expert',
      score: Number,  // 0-100
      calibrationDelta: Number,  // -3 to +3
      questionsAsked: Number,
    }
  },

  // For the existing-user flow
  flowType: 'new_user' | 'existing_user_tune',

  // For abandoned attempts
  abandonedAt: Date,
  abandonStrategy: 'partial_processed' | 'dropped' | null,
}
```

**`DiagnosticQuestionBank`** — the cache:

```js
{
  canonicalCompetency: String,    // normalized
  rawCompetencyAliases: [String],  // for analytics
  difficulty: 'easy' | 'medium' | 'hard',

  questionText: String,
  options: [{ label, text, misconception: { tag, explanation } | null }],
  correctAnswer: String,
  explanation: String,

  source: 'live_generated' | 'curated' | 'cached',
  generatedAt: Date,
  timesUsed: Number,
  // discrimination index — how well this question separates proficiency
  // levels. Field exists for v2; v1 leaves it null. Populated by a future
  // analytics job once we have enough attempts per question.
  discrimination: Number,
  status: 'active' | 'retired' | 'pending_review',
}
```

Index: `(canonicalCompetency, difficulty, status, timesUsed)` for fast pool lookups.

---

## 8. API surface

All new endpoints, additive. Mounted at `/api/v1/diagnostic`.

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/diagnostic/start` | Returns `{ attemptId, competenciesToAssess, selfRatingScreen }`. Triggers pool generation in background. |
| `POST` | `/diagnostic/:attemptId/self-rating` | Body: `{ ratings: { [competency]: 'novice'\|... } }`. Stores ratings. Returns when pool is ready (typically immediate). |
| `GET` | `/diagnostic/:attemptId/next-question` | Server-driven adaptive selector. Returns next question or `{ done: true }`. |
| `POST` | `/diagnostic/:attemptId/answer` | Body: `{ questionId, selectedAnswer, timeTaken }`. Stores answer. |
| `POST` | `/diagnostic/:attemptId/finish` | Closes the attempt. Triggers `KnowledgeProfile` update + plan generation. Returns results. |
| `GET` | `/diagnostic/:attemptId/results` | Returns Screen 4 data: per-competency assessed band, calibration delta. |
| `POST` | `/diagnostic/:attemptId/abandon` | Marks attempt as abandoned. Used when user explicitly opts out partway. |
| `GET` | `/diagnostic/last-attempt` | For resume flow: returns the user's most recent in-progress attempt or null. |

All endpoints require auth. Existing rate-limiter applies.

---

## 9. Edge cases

| # | Scenario | Handling |
|---|---|---|
| 1 | User skips at Screen 1 | No diagnostic data captured. Plan generation uses existing fallback path. Insights cold-start card surfaces a one-time, dismissible "Take a 5-min check to personalise" CTA on the next Progress tab visit; if dismissed, suppressed for 7 days. |
| 2 | User abandons at <30% (1-3 questions answered) | Drop the data silently. Treat as if skipped → generic plan. On next open: *"Want to try again? Takes 5 minutes."* (Optional offer, never required.) |
| 3 | User abandons at 30-70% (4-7 questions) | Banner on next app open: *"You're partway through your check. Finish it now (2 more min) or use what you've got — we'll personalise the topics you covered, the rest will calibrate as you use the app."* User chooses. Partial-process path stores `proficiencyData[unanswered] = null`; plan-generation handles nulls via existing fallback. |
| 4 | User abandons at 70%+ (8+ questions) | Auto-process the partial set, generate the plan, show results screen on next open. Don't make them re-engage. |
| 5 | User retakes diagnostic | Allowed only after 30 days OR if objective changes. Old `DiagnosticAttempt` retained for analytics; only the latest counts. UI: *"Your previous assessment was X. This will replace it — proceed?"* |
| 6 | User changes objective post-diagnostic | If new objective overlaps >50% with old, keep diagnostic data. If <50%, offer (not force) re-assessment for the new competencies. |
| 7 | User's objective has no `analysis.competencies` yet (the GPT mapping pipeline is still running) | Show a fallback at Screen 2: 3-question domain self-rating only ("How would you rate yourself in [domain] overall?"). Skip Screen 3 entirely. Mark `proficiencyData.source: 'self_rating_only'`. |
| 8 | Network failure mid-quiz | Each answer is POSTed individually as it's submitted. Local state preserves position. Auto-retry on next open. The attempt's `status: 'in_progress'` is recoverable. |
| 9 | LLM pool-generation call fails or times out | Brief spinner state ("preparing your questions..."). One retry. If still failing, fall back to `DiagnosticQuestionBank` cache (cached questions for the competencies, may be reduced quality if the bank is sparse for that competency). If cache also empty, gracefully skip the diagnostic and route to generic plan with a brief apology message. |
| 10 | Plan generation fails after diagnostic completes | Store the diagnostic data immediately. Show user the results screen. Plan generates async — *"Your plan is being built, ready in 1-2 minutes."* When ready, push notification. |
| 11 | User answers extremely fast (<5s per question) | Flag the attempt with `confidence: 'low'` in `DiagnosticAttempt.results`. Don't trust the data as strongly. Phase 6's confidence-gating handles this naturally for cognitive-trait surfacing. |
| 12 | User answers extremely slow (>3 min on one question) | Auto-skip after 2.5 min with a "we'll come back to this" — don't penalise. The skipped question gets `selectedAnswer: 'skipped'`. |
| 13 | User is mid-onboarding when feature ships | Complete current onboarding flow as before. Diagnostic offered post-onboarding via the existing-user offer card on Progress tab. Not auto-routed. |
| 14 | Existing user with all-strong competencies | Synthesis (E1) + goal-check (E2) + self-rating (E3) only. Skip the gap-question screen (E4) — no questions to ask. Regenerate plan (E5) from existing data + new self-rating. |
| 15 | New objective declared has competency that's never been seen before (zero cache, zero LLM history with it) | Live LLM generates pool from scratch. Slightly higher risk of mediocre questions on the first run. Cached after generation, future users benefit. |

---

## 10. Backward compatibility guarantees

**Hard guarantees (must hold):**

1. **No existing user is auto-routed into the diagnostic.** Detection rule: if `KnowledgeProfile.totalQuizzesTaken >= 1` OR `User.createdAt < featureLaunchDate`, the diagnostic is *offered only* via the dismissible card, never auto-triggered.
2. **All schema changes are additive.** Two new optional fields on `KnowledgeProfile.topicMastery[]`, two new collections (`DiagnosticAttempt`, `DiagnosticQuestionBank`). No modifications to existing models.
3. **All existing endpoints unchanged.** New endpoints are additive at `/api/v1/diagnostic/*`.
4. **Plan generation gracefully handles "no diagnostic data."** Existing path is preserved verbatim. New code path is purely additive: `if (diagnosticData) { useItToInformPlan() } else { existingFlow() }`.
5. **Feature-flag controlled.** A single boolean (`features.day1Diagnostic`) can disable the entire flow without code change. Disabled = onboarding routes around the new screens entirely.

**Soft guarantees (will hold unless explicit reason not to):**

6. Existing users see a one-time, dismissible offer card; never a modal interruption.
7. Users mid-onboarding when the feature ships complete their current flow first, then get the diagnostic offered.
8. Cohort telemetry: every user gets `onboardingCohort: 'pre_diagnostic' | 'post_diagnostic_taken' | 'post_diagnostic_skipped' | 'existing_offered'` for retention comparison.

---

## 11. Telemetry for v1

Four metrics that must be captured on day 1 of feature launch:

1. **Drop-off funnel per screen.** Count of users who *enter* each screen (1, 2, 3, 4, 5) and count who *complete* it. Identifies where bouncing happens.
2. **30-day retention by cohort.** `took_diagnostic` / `skipped` / `existing_user_offered_taken` / `existing_user_offered_dismissed`. The headline success metric.
3. **Plan-engagement rate by cohort.** % of plan items started + completed in the first 14 days post-onboarding. Tests whether better plans = more usage.
4. **Self-rating vs assessed delta distribution.** Histogram of `calibrationDelta` values. Both a product insight and the foundational metric for future Insights work.

Nice-to-have but skip for v1: per-question timing distributions, per-competency drop-off, diagnostic→first-quiz latency. Add in v2 if needed.

---

## 12. Reuse vs build

**Reuse (substantial leverage from existing infrastructure):**

- `quizGenerationService` — extend with a `'diagnostic'` quiz type (new prompt rules, but same LLM pipeline + caching infra)
- `KnowledgeProfile.topicMastery` — diagnostic results write directly here in one batch update at attempt completion
- `ConceptMastery` (Phase 5) — diagnostic seeds initial FSRS state per concept
- `UserObjective.analysis.competencies` — already provides the scoping for which competencies to assess
- `progressInsightsService` — already consumes `KnowledgeProfile`; gets day-1 data for free, no changes needed
- `userContextService` (Phase 8) — provides the synthesis content for Screen E1
- iOS + RN quiz attempt UI — diagnostic is a quiz "skin"; reuse the existing renderer with adjustments

**Build (the new work):**

- `DiagnosticAttempt` model + `DiagnosticQuestionBank` model
- `diagnosticController` + `diagnosticService` (~350 LOC)
- Adaptive selector state machine (~150 LOC, server-side)
- Self-rating capture endpoint
- Pool-generation prompt + LLM call wrapper (extends `quizGenerationService`)
- Competency name normalizer (~80 LOC + small alias dictionary)
- `/api/v1/diagnostic/*` routes
- 5 new screens on iOS + 5 on RN (the screen-by-screen flow above)
- Onboarding gate logic (when to insert the new flow)
- Existing-user offer card on Progress tab
- Plan-generation pipeline integration (`diagnosticData` injection point)
- Feature flag + telemetry instrumentation

**Effort estimate:**

| Component | Estimate |
|---|---|
| Backend (models, service, selector, endpoints, integration) | 4-5 days |
| iOS UI (5 screens + flow) | 3-4 days |
| RN UI (5 screens + flow) | 3-4 days |
| Telemetry + feature flag plumbing | 1 day |
| QA + dogfooding round | 2 days |
| **Total** | **~10-13 days, parallelisable to ~6-8 calendar days** |

---

## 13. Open questions / future work (deferred to v2)

- **Out-of-coverage domain handling.** What happens when a user's declared objective falls outside our content library. Separate spec required.
- **Question bank curation workflow.** Auto-cached questions graduate to "curated" status after analytics show they discriminate between proficiency levels well. Needs a small admin tool.
- **Re-diagnose on objective change.** Currently we offer (don't force) re-assessment. Worth measuring whether users want this auto-prompted instead.
- **Cross-user pattern detection.** Once we have many `DiagnosticAttempt` records, look for question-level patterns ("everyone who self-rates Expert in X but actually scores Familiar tends to fail this specific concept"). Could feed back into curriculum design.
- **Adaptive timing.** Currently every question gets the same 30-60 sec budget. Could vary by difficulty.

---

## 14. Approval & next steps

This spec was designed in collaborative brainstorming with the product owner on 2026-04-27. Key decisions:

- ✅ Friction tolerance: ~5-8 minutes for new users, optional skip with explicit value framing
- ✅ Question count: 8-10 adaptive
- ✅ Generation strategy: pool-during-self-rating + adaptive selection + organic cache
- ✅ Existing-user flow: synthesis-first with targeted gap-fill
- ✅ Coding domains: MCQ-format only via existing pipeline
- ✅ Self-rating + quiz: bundled (skipping is at the diagnostic level, not per-screen)
- ✅ Retake policy: 30-day cooldown OR objective change
- ✅ Three-tier abandonment handling
- ✅ Pre-cached question bank: build it (organic, side-effect of usage)
- ✅ Telemetry: drop-off funnel + 30d retention + plan engagement + calibration delta

Once this spec is approved by the user, the next step is invoking `superpowers:writing-plans` to produce a detailed implementation plan, broken into reviewable chunks with checkpoints.
