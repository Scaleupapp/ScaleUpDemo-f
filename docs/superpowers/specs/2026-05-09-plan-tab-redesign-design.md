# Plan Tab Redesign — Orchestration Hub Spec

**Status:** Draft for review
**Date:** 2026-05-09
**Owner:** Nirpeksh
**Replaces:** Existing Plan tab (descriptive, read-only — Build 113)

---

## 1. Why we're rebuilding

The current Plan tab is a **descriptive artifact**, not an actionable hub. It shows the diagnostic-derived weekly schedule (focus topics, hours, milestones) as text. The user reads it and closes the app — the page has no "what do I do next?" affordance.

User's words: *"I literally hate this page."*

The diagnostic gives us a calibrated read on where the user is. Onboarding gives us their objective, timeline, and weekly commit hours. The platform already has quizzes, in-app content, an AI interview module, notes, competitions, knowledge profile updates from quiz attempts, and content consumption tracking. **None of that flows back into the Plan tab.** The Plan tab should be the place where every other surface's progress is reflected, and the place that tells the user what their *next concrete action* is.

**The product thesis:** Plan is the orchestration layer. Diagnostic + onboarding seed it; quiz attempts, content consumption, AI interview sessions, notes, and competition participation update it; recalibration adjusts it weekly. The user opens the Plan tab to (a) remember why they're on the platform, (b) see what they're doing this week, (c) mark progress, and (d) trust that the plan is current.

---

## 2. Goals & Non-goals

### Goals (v1)

- Plan tab as a **task-driven hub**: this-week tasks with a clear next action.
- **Heterogeneous tasks**: quiz / in-app content / AI interview / external link / competition / manual.
- **Two-way completion**: in-platform tasks auto-mark via existing event sources; out-of-platform via manual mark + self-rating.
- **Adaptive replanning**: weekly recalibration cadence (30→7 days minimum gap), event-driven mid-week adjustments where signal is strong.
- **External content via LLM-as-judge**: gen-time second pass evaluates whether in-app coverage is sufficient; emits 0..N curated external links *only when needed*. Whitelisted domains.
- **Objective brief always visible** — collapsed by default, expandable. The "why" is one tap away.
- **Next check-in pill** — countdown to the next recalibration so the user trusts the plan stays current.

### Non-goals (deferred to v1.1+)

- AI-generated personalized content (we curate existing in-app content + vetted external links).
- Cross-user comparisons or cohort benchmarking on the Plan tab.
- Calendar integrations / external reminders.
- Editable plans — user marks complete and self-rates, but does not author tasks.
- Per-task time-tracking / pomodoro-style timers.

---

## 3. Architecture

### 3.1 Plan as orchestration hub

The Plan model expands from a descriptive `weeklySchedule[]` (focus topics + hours + milestones) to an **actionable schedule** of structured tasks, each with a `type`, `payload`, `completion`, and `progress` shape.

```
diagnostic.finishAttempt
        │
        ▼
planGenerationQueue ──► planGenerationService.generate ──► Plan{tasks[]}
                                                              │
quiz.complete        ─┐                                       │
content.viewProgress ─┤                                       ▼
interview.complete   ─┼──► planProgressService ◄──── Plan tab UI
notes.created        ─┤        (event listener)              ▲
competition.played   ─┘                                       │
                                                              │
recalibrationScheduler (weekly cadence) ──► recalibration ────┘
```

### 3.2 Plan model expansion

The existing `weeklySchedule[]` keeps `weekNumber`, `focusTopics`, `hours`, `milestone`. We add `tasks[]` per week.

```js
// Plan.weeklySchedule[i].tasks[j]
{
  taskId: ObjectId,
  type: 'quiz' | 'in_app_content' | 'ai_interview' | 'external_link' | 'competition' | 'manual',
  topic: { canonicalName, displayName },
  payload: {
    // shape depends on `type` — see §4
  },
  completion: {
    mode: 'auto' | 'manual',           // auto = listened from event; manual = user taps "Mark done"
    requiresSelfRating: Boolean,        // manual tasks always true; auto tasks usually false
  },
  progress: {
    status: 'pending' | 'in_progress' | 'complete' | 'skipped',
    completedAt: Date | null,
    selfRating: Number | null,          // 1-5, only for manual completes
    sourceEventId: String | null,       // links to QuizAttempt._id, ContentProgress._id, etc.
  },
  generatedAt: Date,
}
```

The single Plan document holds tasks (not a separate collection). Reasons: tasks are tightly bound to a Plan version; recalibration creates a *new* Plan and supersedes the old; we never need cross-plan task queries; embedded keeps the iOS/Android decode shape simple.

### 3.3 New service: planProgressService

A single subscriber that listens to existing event sources and updates the matching Plan task. Lives at `src/services/plan/planProgressService.js`.

Event sources (all already emitted by their respective controllers):
- `quiz.complete(userId, quizId, score)` → match against tasks of type `quiz`.
- `content.progress(userId, contentId, percent)` → mark `in_app_content` complete at ≥80%.
- `interview.complete(userId, sessionId, summary)` → mark `ai_interview` complete.
- `notes.created(userId, noteId)` → bonus signal (does not directly mark complete; informs recalibration).
- `competition.played(userId, competitionId, rank)` → mark `competition` complete.

Matching rule: find the active Plan, find the first task in the *current week* with matching `type` + topic; if none, search future weeks; if still none, ignore. Do not retroactively complete past-week tasks.

### 3.4 Recalibration cadence change

Today: `MIN_DAYS_SINCE_LAST = 30`. Change to `7`. Eligibility logic (`recalibrationEligibilityService`) is otherwise unchanged. The Plan tab surfaces a **"Next check-in: in N days"** pill computed from `lastRecalibrationAt + 7d`.

When a user completes a recalibration, the planProgressService receives a `recalibration.complete` event and triggers `planGenerationService.generate` with a `mode: 'recalibration'` flag — produces a new Plan with `isActive: true` and supersedes the old one.

---

## 4. Task types

Each task type has a defined source, payload shape, and completion mechanism.

| Type | Source | Payload | Completion |
|---|---|---|---|
| `quiz` | Topic taxonomy → quiz id lookup at gen time | `{ quizId, estimatedMinutes }` | Auto on `quiz.complete` |
| `in_app_content` | Content recommendation service | `{ contentId, contentType, estimatedMinutes }` | Auto at ≥80% progress |
| `ai_interview` | Conditional on objectiveType ∈ {interview_preparation, career_switch} | `{ scenario, estimatedMinutes }` | Auto on `interview.complete` |
| `external_link` | LLM-as-judge gen-time pass (§5) | `{ url, title, source, why, estimatedMinutes }` | Manual + self-rating (1-5) |
| `competition` | CompetitionService pick by topic+level | `{ competitionId, opensAt }` | Auto on `competition.played` |
| `manual` | Generator-emitted "do this offline" (e.g. "talk to 3 PMs in your network") | `{ title, description, estimatedMinutes }` | Manual + self-rating (1-5) |

**Interview tasks are gated** on objectiveType: only `interview_preparation` and `career_switch` users see them. Other objectives don't get interview-typed tasks even if their topics overlap.

**Self-rating prompt** (manual completion only): a 1-5 chip row on tap with the question *"How confident do you feel about this topic now?"*. The rating updates `KnowledgeProfile.topicSelfRatings[canonicalName]` directly — feeding the next recalibration.

---

## 5. External content via LLM-as-judge

The plan generator already produces a list of focus topics per week. For each topic, before the plan is finalized, a **second LLM pass** evaluates:

> "Given the user's objective `<X>`, target context `<targetKey>`, current band `<band>`, and the in-app content available for topic `<topic>` (titles + summaries), is the in-app coverage *sufficient* for the user to advance one band? If not, what specific gaps exist, and what 0-3 external resources from `<whitelist>` would close those gaps?"

The judge returns:
```json
{
  "inAppCoverageAdequate": true | false,
  "gaps": ["..."],
  "externalLinks": [
    { "url": "...", "title": "...", "source": "...", "why": "...", "estimatedMinutes": 15 }
  ]
}
```

Rules:
- **Variable count.** 0 if coverage is fine, up to 3 if there are clear gaps. The user must not feel link-spammed.
- **Whitelist enforcement.** External URLs must match a domain whitelist (`config/externalContentWhitelist.js`): MIT OCW, freeCodeCamp, Khan Academy, Coursera (free audit), edX (free audit), official docs (mongodb.com/docs, reactnative.dev, etc.), reputable engineering blogs (Stripe, Cloudflare, Netflix Tech), and a small curated list of YouTube channels (3blue1brown, Computerphile, etc.). LLM-emitted URLs not on the whitelist are dropped.
- **Capture-on-completion.** When the user marks an external_link complete, store `{ url, topic, selfRating, completedAt }` in a new `ExternalContentTouch` collection. Future recalibrations can reference this in the prompt ("user has consumed X external content on topic Y, rated themselves Z").

---

## 6. UI structure

The Plan tab becomes a single scrollable view with five vertical sections.

### 6.1 Hero — objective brief (collapsed by default)

A compact card showing:
- Objective headline (e.g. *"Crack a Product Manager role at Razorpay"*)
- Timeline + weekly commit chip (*"12 weeks · 5 hrs/week"*)
- Tap to expand: full specifics, top 3 measured strengths, top 3 measured gaps from the latest diagnostic.

### 6.2 Next check-in pill

Sticky-ish row beneath the hero:
- *"Next check-in: in 5 days"* with a tap target → opens recalibration eligibility view.
- If eligible *now*: pill becomes *"Recalibrate now →"* CTA.

### 6.3 This week — tasks list

The current week's tasks, ordered: pending first, in-progress second, complete last.

Each task row:
- Type icon + topic display name + estimated minutes.
- Title (e.g. *"Quiz: Stakeholder Management — Intermediate"*).
- Status chip: pending / in-progress / complete.
- Tap → task detail (kicks off the action: opens quiz, content, interview, external URL in in-app browser, etc.).
- Long-press on manual/external_link → "Mark complete" sheet with self-rating chips.

### 6.4 Journey timeline — week-by-week

A horizontally-scrollable strip of weeks 1..N. Each week is a card showing:
- Week number + label (*"Week 3 · Stakeholder mgmt + roadmapping"*).
- Progress ring (% of tasks complete).
- Tap → that week's tasks (scrolls the main list to that week, or stacks).

### 6.5 Milestone footer

Existing milestone list — unchanged in shape, refreshed visually to match new card style. Each milestone shows target week and completion status.

### 6.6 Failed-state UX

If the latest plan generation failed (`DiagnosticAttempt.planGenerationStatus = 'failed'`), the Plan tab shows a recoverable error card with a "Retry plan generation" button. (Currently iOS falls through to the generating spinner — explicit fix.)

---

## 7. Build phasing

Five phases. Phases 1+2 ship the real product. Phases 3-5 layer scope and polish.

### Phase 1 — Foundation (~2 days)

- Plan model: add `tasks[]` to `weeklySchedule[i]`.
- planProgressService skeleton + event subscriptions for `quiz.complete`, `content.progress`.
- Recalibration cadence: `MIN_DAYS_SINCE_LAST` 30 → 7.
- Plan controller: surface `nextCheckInAt` in plan response.
- iOS: handle `planGenerationStatus = 'failed'` (recoverable error card).

### Phase 2 — Quiz + content tasks (~3 days)

- planGenerationService emits `quiz` + `in_app_content` tasks per topic per week (using existing topic→quiz, topic→content lookups).
- iOS Plan tab: hero objective brief + next check-in pill + this-week task list with quiz/content rows.
- Manual completion sheet (self-rating chips) — even though Phase 2 tasks auto-complete, the sheet needs the wiring for Phase 3 task types.
- Android RN: same shape, lower priority polish.

### Phase 3 — Interview + competition + manual (~2 days)

- planGenerationService emits `ai_interview` (gated on objectiveType), `competition`, `manual` tasks.
- planProgressService listens for `interview.complete`, `competition.played`.
- iOS task detail screens for interview/competition/manual.

### Phase 4 — External links via LLM-as-judge (~2 days)

- `externalContentWhitelist.js` config.
- LLM-as-judge second pass in planGenerationService.
- `ExternalContentTouch` collection + capture-on-completion.
- iOS in-app browser for external URLs + self-rating capture.

### Phase 5 — Journey timeline + UI polish (~1 day)

- Week-by-week horizontal strip.
- Milestone footer redesign.
- Animations, micro-interactions, empty states.
- Mixpanel instrumentation: task_started / task_completed / external_link_opened / recalibration_offered_from_plan.

---

## 8. Data migration

Existing Plans (created pre-redesign) have `weeklySchedule[i]` *without* `tasks[]`. Migration approach: **lazy backfill**. When a user opens the Plan tab and their active Plan has no `tasks` field on any week, the controller enqueues a background `planTaskBackfillWorker` job that runs the Phase-2 generator pass over the existing weeks (preserving topics + hours + milestones) and emits `tasks[]`. The user sees the spinner state for one cycle (~10s) and then the new shape.

A one-shot script `scripts/migrate/backfillPlanTasks.js` will run the same logic for all active Plans nightly until the lazy path covers everyone.

---

## 9. Open questions / risks

- **Recalibration frequency at 7 days may be too aggressive** — risk of the user feeling pestered. Mitigation: the *eligibility* gap is 7 days, but the *prompting* cadence on the Plan tab pill respects user dismissal (snooze 7 days on "Not now").
- **External link whitelist maintenance** — the whitelist will rot. Mitigation: log every LLM-emitted URL (kept and dropped) so we can review and grow the list weekly.
- **Auto-completion false positives** — a user opening a content item briefly should not auto-complete. The ≥80% progress threshold protects this, but quiz tasks complete on `quiz.complete` regardless of score. Decision: completing a quiz with any score counts as "did it" — the *score* feeds KnowledgeProfile separately.
- **Embedded tasks document size** — 12 weeks × ~5 tasks/week × ~500 bytes = ~30KB per Plan. Well under MongoDB's 16MB cap. No issue.

---

## 10. Success criteria

- Plan tab open-rate (Mixpanel) at 7-day mark per active user goes from baseline (today: post-diagnostic spike then drop-off) to a sustained ≥3 opens/week.
- ≥40% of users complete at least one task per week in their first 4 weeks.
- ≥25% of users complete a recalibration within the first 30 days post-diagnostic.
- Time-to-first-action from Plan tab open: median <10s (the user taps a task, not just reads the page).
