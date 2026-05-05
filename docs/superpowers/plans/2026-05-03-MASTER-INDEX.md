# Day-1 Diagnostic — Master Plan Index

**Date:** 2026-05-03
**Spec:** [`2026-05-03-day1-diagnostic-redesign-design.md`](../specs/2026-05-03-day1-diagnostic-redesign-design.md)
**Research:** [`2026-05-03-india-seeding-research.md`](../research/2026-05-03-india-seeding-research.md)

The full Day-1 Diagnostic redesign is broken into 7 sub-plans. Each plan produces working, testable software on its own — execute in the order shown below.

---

## Sub-plans (execute in order)

| # | Plan | Tasks | Lines | Scope |
|---|---|---|---|---|
| 1 | [`phase0.5-seed-scripts.md`](./2026-05-03-diagnostic-phase0.5-seed-scripts.md) | 13 | 2,351 | TopicTaxonomy + CompanyProfile models, validator service, Wave 1 hand-curated seed data, anchor + bulk question generation scripts, Wave 1 production run |
| 2 | [`phase2a-backend-foundation.md`](./2026-05-03-diagnostic-phase2a-backend-foundation.md) | 10 | 1,863 | UserObjective additions, DiagnosticSyllabus model, normalization service, DiagnosticAttempt cleanup, onboarding/syllabus API endpoints, existing-user migration |
| 3 | [`phase2b-frontend-onboarding.md`](./2026-05-03-diagnostic-phase2b-frontend-onboarding.md) | 14 | 2,860 | iOS + Android Step 5 rework (taxonomy chips + AI badge + cap-8 custom + self-rating sub-step), syllabus upload UI, Home calibration banner |
| 4 | [`phase3a-diagnostic-engine.md`](./2026-05-03-diagnostic-phase3a-diagnostic-engine.md) | 16 | 2,163 | Path C selection, per-type variations, voice answer service, real-time question generation w/ Tier 1 validation, daily refresh cron, iOS + Android orchestration view rebuild |
| 5 | [`phase3b-results-insights.md`](./2026-05-03-diagnostic-phase3b-results-insights.md) | 16 | 3,386 | Insights generation service (LLM + template fallback), calibration math, results endpoint, iOS + Android results screen rebuild w/ 3-screen hero, animated bars, replay, shareable |
| 6 | [`phase5-6-plan-recalibration-admin.md`](./2026-05-03-diagnostic-phase5-6-plan-recalibration-admin.md) | 35 | 5,500 | Plan generation contract + background job, push notif, Plan tab, 30-day re-calibration flow, growth viz, admin question review dashboard, weekly digest email |
| 7 | [`phase7-polish-launch.md`](./2026-05-03-diagnostic-phase7-polish-launch.md) | 21 | 2,729 | Wave 2 + Wave 3 batch crons, gap-fill scripts, E2E QA test plan, marketing copy, App Store + Play Store screenshots, Mixpanel dashboard, launch checklist + rollback + runbook |

**Totals:** 125 tasks · 20,852 lines of plan · ~7-8 weeks of dev work · ~$150 LLM cost (taxonomy + question bank seed + insights/plan generation runtime).

---

## Cross-plan dependencies

Each plan declares its own prerequisites. Quick reference:

```
Plan 1 (Seeding)              → no prerequisites (kicks off the project)
Plan 2a (Backend Foundation)  → Plan 1
Plan 2b (Frontend Onboarding) → Plans 1, 2a
Plan 3a (Diagnostic Engine)   → Plans 1, 2a, 2b
Plan 3b (Results & Insights)  → Plans 1, 2a, 2b, 3a
Plan 4 (Plan + Recal + Admin) → Plans 1, 2a, 2b, 3a, 3b
Plan 5 (Polish + Launch)      → Plans 1, 2a, 2b, 3a, 3b, 4
```

---

## Cross-plan consistency notes

These are the load-bearing identifiers that appear in multiple plans. **They must stay aligned** — if you change one in any plan, change it everywhere.

### Backend identifiers

| Identifier | Defined in | Used in |
|---|---|---|
| `OBJECTIVE_TYPES` enum (7 values) | Plan 1 (TopicTaxonomy model) | All plans |
| `DIFFICULTIES` enum (foundational/intermediate/advanced for taxonomy; easy/medium/hard for questions) | Plan 1 | Plans 3a, 3b, 4, 5 |
| `verificationStatus` enum (pending/auto_verified/human_verified/flagged_for_review/rejected) | Plan 1 | Plans 3a, 4, 5 |
| `generationSource` enum (curated/seed_batch/llm_realtime/syllabus_derived) | Plan 1 | Plans 3a, 5 |
| `topicSelfRatings` Map field on UserObjective | Plan 2a | Plans 3a, 3b, 4 |
| `attemptType` enum (initial/recalibration) on DiagnosticAttempt | Plan 2a | Plan 4 |
| `previousAttemptId` field on DiagnosticAttempt | Plan 2a | Plan 4 |
| `insightsJson` field on DiagnosticAttempt | Plan 2a | Plan 3b |
| `planGenerationStatus` enum (pending/generating/ready/failed) | Plan 2a | Plan 4 |
| `needsCalibration` boolean on UserObjective | Plan 2a | Plan 2b (banner) |
| `topicTaxonomyService.buildTargetKey/canonicalize` | Plan 1 | Plans 2a, 3a |
| `questionValidatorService.validateQuestion/classifyScore` | Plan 1 | Plans 3a (realtime gen), 5 (backfill) |
| `ProficiencyLevel` enum (novice/familiar/proficient/expert) | Plan 2b (iOS) + Plan 2a (BE Map enum) | Plans 3a, 3b, 4 |
| `FEATURE_DAY1_DIAGNOSTIC_V2` flag | Plan 5 | All plans (rollback gate) |

### API endpoints

| Endpoint | Defined in | Notes |
|---|---|---|
| `POST /onboarding/topics/suggest` | Plan 2a | Returns 404 if missing in Plan 2a; Plan 3a Task 4 adds realtime LLM fallback |
| `POST /onboarding/complete` | Plan 2a | Atomic save with normalization |
| `POST /diagnostic/syllabus/upload-init` | Plan 2a | Returns presigned S3 URL |
| `POST /diagnostic/syllabus/:id/complete` | Plan 2a | Triggers extraction worker (existing notes infra) |
| `GET /diagnostic/syllabus/:id/status` | Plan 2a | Polling endpoint |
| `POST /diagnostic/attempts/start` | Plan 3a refactor | Existing endpoint, refactored |
| `GET /diagnostic/attempts/:id/next-question` | Plan 3a refactor | Existing |
| `POST /diagnostic/attempts/:id/answers` | Plan 3a refactor | Existing |
| `POST /diagnostic/attempts/:id/finish` | Plan 3a + Plan 3b | Plan 3a wires services; Plan 3b adds insights generation |
| `GET /diagnostic/attempts/:id/results` | Plan 3b | Returns insights JSON when ready |
| `POST /diagnostic/voice/upload` | Plan 3a | New endpoint |
| `GET /plan/status` | Plan 4 | Polling for plan readiness |
| `GET /plan/current` | Plan 4 | Full plan with milestones |
| `GET /diagnostic/recalibration/eligible` | Plan 4 | Re-calibration eligibility |
| `GET /admin/diagnostic-questions/queue` + 4 admin endpoints | Plan 4 | Admin dashboard backend |

### Mixpanel events

All events in spec §13.5 are split across plans by domain:

- **Onboarding events** (`onboarding_topic_*`, `onboarding_self_rating_completed`, `onboarding_syllabus_*`, `existing_user_calibration_*`): Plan 2b
- **Diagnostic events** (`diagnostic_started/_question_shown/_answered/_voice_used/_voice_failed_fallback_typed/_topic_completed/_completed/_abandoned`): Plan 3a
- **Insights/Results events** (`insights_generation_*`, `diagnostic_results_*`, `diagnostic_hero_reveal_completed`, `diagnostic_topic_card_expanded`, `diagnostic_replay_section_opened`, `diagnostic_results_shared`): Plan 3b
- **Plan events** (`plan_brewing_seen`, `plan_ready_notification_tapped`, `plan_generation_*`): Plan 4
- **Re-calibration events** (`recalibration_offered/_started/_completed`): Plan 4
- **Coverage monitoring** (`topic_taxonomy_lookup_miss`, `question_bank_lookup_miss`, `question_flagged_for_review`): Plan 3a (taxonomy + question miss) + Plan 1 (validator)

### Frontend file paths

| Path pattern | Repo | Used in |
|---|---|---|
| `ScaleUp/Features/Onboarding/Views/Steps/*.swift` | iOS | Plan 2b |
| `ScaleUp/Features/Diagnostic/Views/*.swift` | iOS | Plans 3a, 3b |
| `ScaleUp/Features/Diagnostic/Views/Components/*.swift` | iOS | Plans 3a, 3b |
| `ScaleUp/Features/Plan/Views/*.swift` | iOS | Plan 4 |
| `ScaleUp/Features/Progress/Views/*.swift` | iOS | Plan 4 |
| `ScaleUp/Features/Home/Views/*.swift` | iOS | Plans 2b, 4 |
| `src/screens/onboarding/steps/*.tsx` | Android | Plan 2b |
| `src/screens/diagnostic/*.tsx` | Android | Plans 3a, 3b |
| `src/screens/plan/*.tsx` | Android | Plan 4 |
| `src/screens/progress/*.tsx` | Android | Plan 4 |
| `src/screens/home/*.tsx` | Android | Plans 2b, 4 |

---

## Recommended execution mode

Per each plan's "Execution Handoff" section: **Subagent-Driven Development** is recommended.

Workflow:
1. Pick a plan (start with Plan 1).
2. Use the `superpowers:subagent-driven-development` skill.
3. For each task: dispatch implementer subagent → spec reviewer → code quality reviewer → mark complete.
4. After each plan completes, deploy to staging + verify before starting the next plan.

For plans with UI/UX tasks (3a/3b/4), some tasks may be faster inline since you can preview in Xcode/simulator yourself.

---

## Operational rollout (combines all plans)

Suggested timeline (one plan per week):

| Week | Phase | Output |
|---|---|---|
| 1 | Phase 0.5 (Plan 1) | Seeded production database, ~8-10k validated questions |
| 2 | Phase 1 (Plan 2a) | Backend models + APIs ready, existing users marked for calibration |
| 3 | Phase 2 (Plan 2b) | New onboarding live in TestFlight + Play internal testing (still behind feature flag) |
| 4 | Phase 3 part A (Plan 3a) | Diagnostic engine working end-to-end in staging |
| 5 | Phase 3 part B (Plan 3b) | Results screen + insights working in staging |
| 6 | Phase 5+6 (Plan 4) | Plan generation + re-calibration + admin dashboard live in staging |
| 7 | Phase 7 (Plan 5) | Wave 2 batch crons scheduled, marketing copy + screenshots ready, launch checklist green |
| 8 | Launch | Toggle `FEATURE_DAY1_DIAGNOSTIC_V2=true`, monitor per launch day runbook |
| 9-12 | Wave 2 + Wave 3 | Batch generation crons run, coverage grows from 70% → 100% |

---

## What to do next

You have three options:

1. **Start executing Plan 1** — kick off Wave 1 seeding. ~3-5 days dev + 1-2 days LLM compute. End state: seeded production DB.
2. **Review one or more plans first** — read through and flag anything you want adjusted before code starts. Plans 3b and 5 are the longest; Plans 1 and 2a are the foundational ones to scrutinize.
3. **Pause and pick up later** — everything is saved. The spec, research, and 7 plans constitute the complete roadmap.

Recommendation: **Option 2** — read Plan 1 + Plan 2a end-to-end (~30 min combined) before kicking off execution. These two plans set the data + model contracts everything else inherits, so catching issues here is cheapest.
