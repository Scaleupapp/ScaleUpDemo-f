# Day-1 Diagnostic — E2E Test Plan

**Version:** 1.0  
**Date:** 2026-05-03  
**Scope:** All 7 objective types, all platforms (iOS primary, Android parity)  
**Run when:** Before launch, after any diagnostic service change, after any frontend diagnostic screen change.

---

## Overview

The diagnostic flow has 7 distinct objective types, each with its own question pool, competency taxonomy, and insight template. This plan covers a full happy-path E2E run for each type plus cross-cutting suites for edge cases.

**Objective types:**
1. `upskilling` — grow skills in current role
2. `job_change` — move to a new role
3. `interview_preparation` — prep for a specific interview
4. `certification` — pass a certification exam
5. `switching_domains` — career pivot to a new domain
6. `promotion` — get promoted internally
7. `side_project` — build a specific side project

---

## Test Environment Setup

- iOS Simulator: iPhone 15 Pro, iOS 17+
- Android Emulator: Pixel 7, API 33+
- Backend: staging (`https://api-staging.scaleupapp.club`)
- Feature flag: `FEATURE_DAY1_DIAGNOSTIC_V2=true` must be on in staging
- Test user accounts: one per objective type (pre-created, no prior diagnostic)
- Clean slate: each test run uses a fresh account OR resets via `DELETE /diagnostic/attempts` admin endpoint

---

## Suite A — Upskilling × PM Happy Path

**Objective type:** `upskilling`  
**Target skill:** Product Management  
**Self-rating:** All competencies → Novice  

### Steps

- [ ] A1. Open app → onboarding Step 5 (Objective)
- [ ] A2. Select "Grow in my current role"
- [ ] A3. Select role "Product Manager"
- [ ] A4. Confirm taxonomy chips load (strategy, data analysis, stakeholder mgmt, roadmapping, communication)
- [ ] A5. Tap "Start Diagnostic"
- [ ] A6. Self-rating screen renders all competencies
- [ ] A7. Rate all competencies "Novice" → submit
- [ ] A8. Loader appears with rotating fact cards
- [ ] A9. First question renders with 4 options, timer visible
- [ ] A10. Answer all questions (correct answers to force upward band movement)
- [ ] A11. "Generating insights…" screen appears after last answer
- [ ] A12. Hero insight card appears (non-empty, not placeholder text)
- [ ] A13. Results screen: each competency shows assessed band + calibration delta
- [ ] A14. At least one competency shows `calibrationClass = 'undersells'` (rated novice, scored familiar)
- [ ] A15. "Continue to your plan" CTA navigates to Journey tab

### Assertions
- Result `status === 'completed'`
- `results` array length === number of competencies assessed
- `insights.hero` non-empty string
- `insights.patterns` array length >= 1
- `insights.breakdown` array length === `results` array length
- Mixpanel event `diagnostic_completed` fired with `objectiveType: 'upskilling'`

---

## Suite B — Job Change × Data Science

**Objective type:** `job_change`  
**Target role:** Data Scientist  
**Self-rating:** Mixed (some familiar, some novice)  

### Steps

- [ ] B1. Onboarding Step 5 → "Move to a new role"
- [ ] B2. Select target role "Data Scientist"
- [ ] B3. Taxonomy chips: Python, SQL, Statistics, ML fundamentals, Data viz
- [ ] B4. Self-rate: Python=familiar, SQL=novice, Statistics=novice, ML=novice, Viz=novice
- [ ] B5. Pool generation completes (loader ≤ 8s on staging)
- [ ] B6. Answer all questions
- [ ] B7. Results: Python band is at or above familiar (matches self-rating)
- [ ] B8. Results: SQL band reflects actual score (not pinned to self-rating)
- [ ] B9. Insights hero references the target role "Data Scientist"

### Assertions
- `objectiveType === 'job_change'` on persisted attempt
- Calibration delta for Python is small (self-rating was accurate)
- Calibration delta for SQL reflects gap or improvement

---

## Suite C — Interview Preparation × Software Engineer

**Objective type:** `interview_preparation`  
**Target:** Software Engineer at FAANG  
**Self-rating:** Mid-level across all  

### Steps

- [ ] C1. Step 5 → "Prepare for an interview"
- [ ] C2. Enter company name or select "General SWE"
- [ ] C3. Taxonomy: DSA, System Design, Behavioural, CS fundamentals, Communication
- [ ] C4. Self-rate: all "Familiar"
- [ ] C5. Answer all questions
- [ ] C6. Results: DSA and System Design show up as primary competencies
- [ ] C7. Insights include readiness score / interview-specific framing
- [ ] C8. "Your plan" references interview prep milestones

### Assertions
- Attempt `objectiveSnapshot.objectiveType === 'interview_preparation'`
- `insights.hero` contains readiness framing (not generic growth framing)

---

## Suite D — Certification × AWS Solutions Architect

**Objective type:** `certification`  
**Target:** AWS Solutions Architect Associate  
**Self-rating:** Varies by competency  

### Steps

- [ ] D1. Step 5 → "Pass a certification"
- [ ] D2. Select "AWS Solutions Architect Associate" from exam picker
- [ ] D3. Taxonomy: Compute, Storage, Networking, Security, Architecture
- [ ] D4. Self-rate: Compute=familiar, others=novice
- [ ] D5. Answer all questions
- [ ] D6. Results show exam-domain-specific bands
- [ ] D7. Insights reference the exam name explicitly

### Assertions
- `objectiveSnapshot.specifics.examName` populated
- Question pool draws from certification-specific bank (not generic PM/SWE pool)

---

## Suite E — Switching Domains × Tech to Finance

**Objective type:** `switching_domains`  
**Target:** Finance (from Tech)  
**Self-rating:** All novice (expected for switcher)  

### Steps

- [ ] E1. Step 5 → "Switch to a new field"
- [ ] E2. Select target domain "Finance"
- [ ] E3. Taxonomy: Financial modelling, Excel, Accounting basics, Corporate finance, Valuation
- [ ] E4. Self-rate all novice
- [ ] E5. Answer all questions (expected lower scores)
- [ ] E6. Results show realistic bands (mostly novice/beginner)
- [ ] E7. Insights acknowledge the pivot context, not punitive framing

### Assertions
- Bands ≤ familiar for most competencies (domain is new)
- `insights.hero` does not use negative language
- Plan generated reflects a "foundation first" structure

---

## Suite F — Promotion × Engineering Manager

**Objective type:** `promotion`  
**Target:** IC to Engineering Manager  
**Self-rating:** Technical=expert, Leadership=novice  

### Steps

- [ ] F1. Step 5 → "Get promoted"
- [ ] F2. Select "Engineering Manager"
- [ ] F3. Taxonomy: Technical leadership, People management, Delivery, Strategy, Communication
- [ ] F4. Self-rate: Technical leadership=expert, People management=novice, Delivery=familiar, rest=novice
- [ ] F5. Answer all questions
- [ ] F6. Technical leadership band is high (matches expert self-rating + good answers)
- [ ] F7. People management band low (novice self-rating + potentially weak answers)
- [ ] F8. Insights highlight the technical→leadership transition gap

### Assertions
- Calibration delta for Technical leadership is near zero (self-aware)
- Calibration delta for People management is notable (gap exposed)
- Insights reference promotion-specific framing

---

## Suite G — Side Project × SaaS App

**Objective type:** `side_project`  
**Target:** Build a SaaS app  
**Self-rating:** Technical=familiar, Business=novice  

### Steps

- [ ] G1. Step 5 → "Build a side project"
- [ ] G2. Describe project: "SaaS app for freelancers"
- [ ] G3. Taxonomy: Product thinking, Frontend, Backend, Marketing, Financial basics
- [ ] G4. Self-rate: Frontend=familiar, Backend=familiar, others=novice
- [ ] G5. Answer all questions
- [ ] G6. Results reflect the build-focused competency set
- [ ] G7. Plan includes "build" milestones, not just "learn" milestones

### Assertions
- `objectiveType === 'side_project'` on attempt
- Insights framing is builder-oriented

---

## Suite X — Cross-Cutting: Existing User Migration

**Precondition:** User has completed onboarding before V2 flag shipped (no diagnostic attempt).

- [ ] X1. Existing user logs in → sees diagnostic prompt on Journey tab (not forced into onboarding)
- [ ] X2. Tapping "Take diagnostic" starts flow at self-rating (objective already known from profile)
- [ ] X3. Completes diagnostic → results applied to existing profile (does not reset journey plan)
- [ ] X4. `KnowledgeProfile` updated with new bands
- [ ] X5. Journey plan regenerated with diagnostic bands incorporated

---

## Suite Y — Re-calibration

**Precondition:** User has a completed diagnostic attempt (at least 7 days old, or force via admin).

- [ ] Y1. User navigates to Diagnostic tab → sees "Re-calibrate" option
- [ ] Y2. Starts recalibration → skips onboarding steps, goes straight to self-rating
- [ ] Y3. New self-ratings may differ from original
- [ ] Y4. New question pool generated (fresh, not cached from prior attempt)
- [ ] Y5. Completes → results show delta vs prior diagnostic
- [ ] Y6. `calibrationDelta` on each competency reflects the shift
- [ ] Y7. Journey plan regenerated

---

## Suite Z — Admin Review

**Precondition:** Admin account with `/admin/diagnostic` access.

- [ ] Z1. Admin dashboard shows pending insights review queue
- [ ] Z2. Admin can view a specific attempt's raw answers + generated insights
- [ ] Z3. Admin can approve or flag insights for manual revision
- [ ] Z4. Flagged insights trigger fallback copy for the user
- [ ] Z5. `insightsStatus` on attempt is `'approved'` or `'fallback'` as appropriate

---

## Suite P — Performance Budgets

Run on a throttled network (Slow 3G simulation or Charles proxy at 400kbps down).

- [ ] P1. Pool generation (self-rating → first question) completes within 15s on Slow 3G
- [ ] P2. Each question renders within 2s of previous answer submission
- [ ] P3. Insights generation screen appears immediately after last answer (no blank screen)
- [ ] P4. Full flow (start → results) completes within 4 minutes on Slow 3G

---

## Suite FM — Failure Modes

- [ ] FM1. Network drop during pool generation → retry prompt appears, does not crash
- [ ] FM2. Network drop during question fetch → question cached locally, user can continue
- [ ] FM3. OpenAI insights generation fails → fallback insights copy shown, `insightsStatus = 'fallback'`
- [ ] FM4. User force-quits app mid-diagnostic → resumes at last answered question on re-open
- [ ] FM5. User submits answer twice (double-tap) → second submission ignored (idempotent)
- [ ] FM6. Attempt ID not found (deleted on server) → graceful error screen, not crash
- [ ] FM7. All questions exhausted before `done: true` returned → `finishAttempt` called proactively

---

## Suite MX — Mixpanel Event Verification

Use Mixpanel Live Events view during a test run to verify event taxonomy.

| Event | Required Properties |
|---|---|
| `diagnostic_started` | `objectiveType`, `userId`, `attemptId` |
| `diagnostic_self_rating_submitted` | `attemptId`, `competencyCount` |
| `diagnostic_question_answered` | `attemptId`, `questionId`, `timeTaken`, `isCorrect` |
| `diagnostic_completed` | `attemptId`, `objectiveType`, `questionCount`, `durationMs` |
| `diagnostic_insights_viewed` | `attemptId`, `insightsStatus` |
| `diagnostic_results_viewed` | `attemptId`, `bandDistribution` |
| `diagnostic_recalibration_started` | `attemptId`, `daysSinceLast` |

- [ ] MX1. All 7 events fire in a complete happy-path run (Suite A)
- [ ] MX2. No duplicate events on double-tap or retry
- [ ] MX3. `timeTaken` on question_answered is within ±500ms of actual elapsed time
- [ ] MX4. Events fire on Android with identical schema to iOS

---

## Definition of Done

A release is considered QA-complete for the diagnostic flow when:

1. Suites A–G each pass on iOS (at least one objective type per suite fully green)
2. Suite X and Y pass on staging with real DB
3. Suite FM: FM1–FM5 verified (FM6–FM7 verified if time allows)
4. Suite MX: all 7 events verified in Mixpanel Live Events
5. Suite P: P1 and P3 budgets met (P4 is advisory)
6. Zero crash reports in Crashlytics for the diagnostic flow on the release build

---

*Living document — update assertions when API contracts change.*
