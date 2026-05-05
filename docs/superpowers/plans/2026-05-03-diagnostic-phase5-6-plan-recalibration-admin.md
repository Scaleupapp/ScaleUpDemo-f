# Day-1 Diagnostic — Plan 4: Phase 5 + Phase 6 (Plan Integration, Re-calibration, Admin)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the diagnostic into a personalized weekly plan (Phase 5), then close the loop with rolling 30-day re-calibration and an admin dashboard for question quality (Phase 6).

**Architecture:**
- **Phase 5 (Plan integration):** A new `planGenerationService` consumes the standardized diagnostic output (per spec §11), produces a strict-JSON weekly schedule + milestones via gpt-4o, with template-based fallback. Runs as a BullMQ background job (`planGenerationWorker`) triggered when `finishAttempt` lands. A push notification fires on completion via existing FCM/APNs infra. Two new endpoints (`/plan/status`, `/plan/current`) expose the result. iOS Home shows a "plan brewing" pill; the Plan tab is rebuilt to consume the new structure (weeklySchedule + milestones + headline). Mirrored on Android RN.
- **Phase 6 (Re-calibration + Admin):** A daily cron worker (`recalibrationOfferWorker`) marks users eligible 30 days post-attempt. A new short diagnostic mode (`attemptType: 'recalibration'`) re-tests only topics the user has spent ≥5 plan hours on. Results are computed as growth bars (old → new). The plan auto-rebalances. iOS gets a Progress-tab card + Plan-tab nudge + redesigned re-calibration results screen per spec §10.4. The admin dashboard is a BE-served vanilla HTML+JS page (per spec Open Q5) gated by `User.role = 'admin'`, with five new endpoints (queue, approve, edit, reject, stats). A weekly digest email cron pings the admin Monday 09:00 IST.

**Tech Stack:**
- Node.js + Mongoose 8.x
- OpenAI SDK 4.x with `gpt-4o` and `json_schema` strict response format
- BullMQ (`Queue` + `Worker`) on Redis (existing `src/config/queue.js`)
- nodemailer (existing `src/services/emailService.js`)
- Firebase Admin SDK + APNs (existing `src/services/notificationService.js`)
- node:test for unit + integration tests, mocks via `require.cache[]`
- iOS: SwiftUI, existing `DesignSystem/Theme/` tokens, `AnalyticsService.shared.track(...)`
- Android: React Native + TypeScript, existing `src/services/analytics/AnalyticsService.ts`

**Source documents (read-only references):**
- Spec: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/specs/2026-05-03-day1-diagnostic-redesign-design.md`
  - §3.5 Re-calibration flow
  - §5.5 Tier 2 admin review
  - §10.4 Re-calibration results screen
  - §11 Plan generation contract
  - §12.3 Plan endpoints
  - §12.6 Admin endpoints
  - §13.1 + §13.2 + §13.4 + §13.5 Frontend changes + Mixpanel events
- Research: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/research/2026-05-03-india-seeding-research.md` §10 (India context split — referenced in plan generator system prompt).
- Plan 1 (style reference): `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/plans/2026-05-03-diagnostic-phase0.5-seed-scripts.md`

**Repo paths:**
- Backend: `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/`
- Android: `/Users/nirpekshnandan/My Products/ScaleUpAndroid/`

---

## File Structure (decisions locked here)

### Backend

| Path | Responsibility | Status |
|---|---|---|
| `src/services/diagnostic/planGenerationService.js` | Generate weekly schedule + milestones from diagnostic output (LLM + template fallback) | NEW |
| `src/services/diagnostic/planGenerationService.test.js` | Tests with mocked openai | NEW |
| `src/services/diagnostic/planReadyNotificationService.js` | Send push when plan ready | NEW |
| `src/services/diagnostic/planReadyNotificationService.test.js` | Push delivery tests | NEW |
| `src/workers/planGenerationWorker.js` | BullMQ worker invoked from `finishAttempt` | NEW |
| `src/workers/planGenerationWorker.test.js` | Worker integration test | NEW |
| `src/config/queue.js` | Add `planGenerationQueue` | MODIFY |
| `src/models/Plan.js` | New `Plan` Mongoose model (weeklySchedule + milestones) | NEW |
| `src/models/Plan.test.js` | Schema tests | NEW |
| `src/controllers/planController.js` | `getStatus`, `getCurrent` | NEW |
| `src/routes/plan.js` | Mounts `/plan/*` | NEW |
| `src/services/journeyGenerationService.js` | Modify to consume new Plan structure for downstream content matching | MODIFY |
| `src/services/diagnostic/recalibrationEligibilityService.js` | Determine which topics to re-test | NEW |
| `src/services/diagnostic/recalibrationEligibilityService.test.js` | Eligibility tests | NEW |
| `src/services/diagnosticService.js` | Accept `attemptType: 'recalibration'`; run shorter pool | MODIFY |
| `src/services/diagnostic/recalibrationResultsService.js` | Compute growth deltas vs `previousAttemptId` | NEW |
| `src/services/diagnostic/recalibrationResultsService.test.js` | Growth math tests | NEW |
| `src/workers/recalibrationOfferWorker.js` | Daily cron — mark users eligible | NEW |
| `src/workers/recalibrationOfferWorker.test.js` | Cron tests with mocked clock | NEW |
| `src/middleware/adminAuth.js` | Gate by `User.role === 'admin'` (wraps existing `auth` + `rbac`) | NEW |
| `src/middleware/adminAuth.test.js` | Auth tests | NEW |
| `src/controllers/diagnosticAdminController.js` | Queue / approve / edit / reject / stats | NEW |
| `src/controllers/diagnosticAdminController.test.js` | Controller tests | NEW |
| `src/routes/diagnosticAdmin.js` | Mounts `/admin/diagnostic-questions/*` | NEW |
| `src/admin/dashboard.html` | BE-served HTML+vanilla JS admin UI | NEW |
| `src/admin/dashboard.css` | Admin styles | NEW |
| `src/admin/dashboard.js` | Admin JS (fetch + render queue, approve/edit/reject) | NEW |
| `src/services/diagnostic/adminTrainingSignalService.js` | Log decisions; export few-shot examples after 100 | NEW |
| `src/services/diagnostic/adminTrainingSignalService.test.js` | Logging + export tests | NEW |
| `src/workers/adminDigestWorker.js` | Weekly email cron Monday 09:00 IST | NEW |
| `src/workers/adminDigestWorker.test.js` | Digest tests with mocked email | NEW |
| `src/services/emailService.js` | Add `sendAdminQuestionDigest` method | MODIFY |
| `src/workers/cronJobs.js` | Register `recalibrationOffer` + `adminQuestionDigest` cron entries | MODIFY |
| `src/workers/index.js` | Wire up new workers | MODIFY |
| `src/models/User.js` | Add `isAdmin` virtual (or rely on `role === 'admin'`) — verify | VERIFY |
| `src/models/AdminQuestionDecision.js` | Log of approve/reject decisions for training signal | NEW |
| `src/models/AdminQuestionDecision.test.js` | Schema tests | NEW |
| `src/app.js` | Mount `/plan`, `/admin/diagnostic-questions`, static `/admin/dashboard` | MODIFY |

### iOS

| Path | Responsibility | Status |
|---|---|---|
| `ScaleUp/Features/Home/Views/HomeView.swift` | Add "plan brewing" pill at top, polling | MODIFY |
| `ScaleUp/Features/Home/Views/PlanBrewingPill.swift` | The pill component | NEW |
| `ScaleUp/Features/Home/ViewModels/PlanBrewingViewModel.swift` | Polls `/plan/status` | NEW |
| `ScaleUp/Features/Notifications/PushNotificationRouter.swift` | Handle `plan_ready` deep-link (extends existing) | MODIFY |
| `ScaleUp/Features/Plan/Views/PlanTabView.swift` | New plan tab (replaces `MyPlanView` consumption of new structure) | NEW |
| `ScaleUp/Features/Plan/Views/Components/MilestonePreview.swift` | Animated milestone cards | NEW |
| `ScaleUp/Features/Plan/Views/Components/WeeklyAllocationCard.swift` | Per-week allocation card | NEW |
| `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift` | Loads + caches `/plan/current` | NEW |
| `ScaleUp/Features/Plan/Services/PlanService.swift` | API client | NEW |
| `ScaleUp/Features/Plan/Views/RecalibrationNudge.swift` | One-time day-30 nudge | NEW |
| `ScaleUp/Features/Progress/Views/RecalibrationCard.swift` | Progress-tab card when eligible | NEW |
| `ScaleUp/Features/Progress/Views/ProgressTabView.swift` | Insert RecalibrationCard | MODIFY |
| `ScaleUp/Features/Diagnostic/Views/RecalibrationOrchestrationView.swift` | Re-uses existing diagnostic flow; shorter pool | NEW |
| `ScaleUp/Features/Diagnostic/Views/RecalibrationResultsView.swift` | Per spec §10.4 — growth bars, hero, plan rebalance preview | NEW |
| `ScaleUp/Features/Diagnostic/ViewModels/RecalibrationViewModel.swift` | Eligibility check + results loader | NEW |
| `ScaleUp/Core/Analytics/AnalyticsEvent.swift` | Add new events | MODIFY |

### Android

| Path | Responsibility | Status |
|---|---|---|
| `src/screens/home/HomeScreen.tsx` | Add "plan brewing" pill | MODIFY |
| `src/screens/home/components/PlanBrewingPill.tsx` | The pill component | NEW |
| `src/services/pushNotifications.ts` | Handle `plan_ready` deep-link | MODIFY (or NEW if absent) |
| `src/screens/plan/PlanTabScreen.tsx` | New plan tab consuming new structure | NEW |
| `src/screens/plan/components/MilestonePreview.tsx` | Animated milestones | NEW |
| `src/screens/plan/components/WeeklyAllocationCard.tsx` | Per-week card | NEW |
| `src/screens/plan/RecalibrationNudge.tsx` | Day-30 nudge | NEW |
| `src/screens/progress/RecalibrationCard.tsx` | Progress-tab card | NEW |
| `src/screens/progress/ProgressScreen.tsx` | Insert RecalibrationCard | MODIFY |
| `src/screens/diagnostic/RecalibrationResultsScreen.tsx` | Per §10.4 | NEW |
| `src/services/planService.ts` | API client for `/plan/*` | NEW |
| `src/services/diagnosticService.ts` | Add re-calibration eligibility + start endpoints | MODIFY |
| `src/services/analytics/AnalyticsEvent.ts` | Add new events | MODIFY |

**Conventions:**
- Backend tests use `node:test` + `node:assert`, run via `npm test`. Mock dependencies via `delete require.cache[require.resolve('...')]` and reassigning module exports.
- All LLM calls use `gpt-4o` (insights/plan generation per spec §11) with `json_schema` strict and 60s timeout cap; mock `openai` in tests.
- iOS uses `ColorTokens`, `Typography`, `Spacing`, `CornerRadius`, `Motion`, `Haptics` from `DesignSystem/Theme/`.
- Android uses existing theme tokens from `src/theme/`.
- Commit style matches recent commits: `feat(diagnostic-be): ...`, `feat(diagnostic-ios): ...`, `feat(diagnostic-rn): ...`.

---

## Prerequisites

Before starting Task 1:

1. **Plan 3 (Phase 3+4) is merged or its branch is checked out.** This plan depends on:
   - `DiagnosticAttempt.planGenerationStatus` field (`pending | generating | ready | failed`).
   - `DiagnosticAttempt.attemptType` field (`initial | recalibration`) — added here if not yet present.
   - `DiagnosticAttempt.previousAttemptId` field (ref `DiagnosticAttempt`).
   - `DiagnosticAttempt.results` standardized as a Map (per spec §4.4).
   - `DiagnosticAttempt.insightsJson` field present.
   - `finishAttempt` triggers async insights + plan generation.
2. Backend repo at `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/` is on a clean branch.
3. `OPENAI_API_KEY`, `MONGODB_URI`, `REDIS_URL`, `SMTP_HOST`/`SMTP_USER`/`SMTP_PASS` are in `.env`.
4. `npm install` succeeded; `npm test` is green on the base branch.
5. iOS workspace builds; Android `npm run android` works.

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git checkout -b feat/diagnostic-phase5-6-plan-recalibration-admin
git status   # verify clean
```

---

## Task 1: Create the Plan model

**Files:**
- Create: `src/models/Plan.js`
- Test: `src/models/Plan.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/models/Plan.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

delete require.cache[require.resolve('./Plan')];
const Plan = require('./Plan');

test('Plan: validates with required fields', () => {
  const doc = new Plan({
    userId: new mongoose.Types.ObjectId(),
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'Six weeks to interview-ready PM.',
    estimatedTotalHours: 48,
    bufferRecommendation: "We've left 15% buffer for life events.",
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'Anchor your roadmapping fundamentals.',
      allocations: [
        { topicCanonicalName: 'product-strategy', hours: 3, focusActivity: 'Read + apply to your domain' },
      ],
    }],
    milestones: [{
      week: 4,
      title: 'Mock interview, behavioral round',
      measurableCriteria: 'Score 4/5 on STAR clarity rubric',
      isUserStated: false,
    }],
    source: 'llm-generated',
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined, 'should validate cleanly');
  assert.strictEqual(doc.weeklySchedule.length, 1);
  assert.strictEqual(doc.milestones[0].isUserStated, false);
});

test('Plan: requires userId', () => {
  const doc = new Plan({ planHeadline: 'x', estimatedTotalHours: 10, source: 'template' });
  const err = doc.validateSync();
  assert.ok(err && err.errors.userId, 'userId required');
});

test('Plan: rejects invalid source', () => {
  const doc = new Plan({
    userId: new mongoose.Types.ObjectId(),
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'x',
    estimatedTotalHours: 10,
    source: 'random',
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.source, 'invalid source enum');
});

test('Plan: defaults supersededAt to null and isActive to true', () => {
  const doc = new Plan({
    userId: new mongoose.Types.ObjectId(),
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'x',
    estimatedTotalHours: 10,
    source: 'template',
  });
  assert.strictEqual(doc.supersededAt, null);
  assert.strictEqual(doc.isActive, true);
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="Plan:"
```

Expected: FAIL "Cannot find module './Plan'".

- [ ] **Step 3: Implement the model**

Create `src/models/Plan.js`:

```js
const mongoose = require('mongoose');

const allocationSchema = new mongoose.Schema({
  topicCanonicalName: { type: String, required: true },
  hours: { type: Number, required: true, min: 0 },
  focusActivity: { type: String, required: true },
}, { _id: false });

const weeklyEntrySchema = new mongoose.Schema({
  week: { type: Number, required: true, min: 1 },
  weeklyGoal: { type: String, required: true },
  allocations: { type: [allocationSchema], default: [] },
}, { _id: false });

const milestoneSchema = new mongoose.Schema({
  week: { type: Number, required: true, min: 1 },
  title: { type: String, required: true },
  measurableCriteria: { type: String, required: true },
  isUserStated: { type: Boolean, default: false },
}, { _id: false });

const planSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  objectiveId: { type: mongoose.Schema.Types.ObjectId, ref: 'UserObjective', required: true },
  diagnosticAttemptId: { type: mongoose.Schema.Types.ObjectId, ref: 'DiagnosticAttempt', required: true },
  planHeadline: { type: String, required: true },
  estimatedTotalHours: { type: Number, required: true, min: 0 },
  bufferRecommendation: { type: String, default: '' },
  weeklySchedule: { type: [weeklyEntrySchema], default: [] },
  milestones: { type: [milestoneSchema], default: [] },
  source: {
    type: String,
    enum: ['llm-generated', 'template', 'rebalanced'],
    required: true,
  },
  llmLatencyMs: { type: Number, default: null },
  llmModel: { type: String, default: null },
  supersededAt: { type: Date, default: null },
  supersededByPlanId: { type: mongoose.Schema.Types.ObjectId, ref: 'Plan', default: null },
  isActive: { type: Boolean, default: true, index: true },
}, { timestamps: true });

planSchema.index({ userId: 1, isActive: 1 });
planSchema.index({ diagnosticAttemptId: 1 });

module.exports = mongoose.model('Plan', planSchema);
```

- [ ] **Step 4: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="Plan:"
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/Plan.js src/models/Plan.test.js
git commit -m "feat(diagnostic-be): add Plan model for diagnostic-driven plan output"
```

---

## Task 2: Add planGenerationQueue to queue config

**File:** `src/config/queue.js` (MODIFY)

- [ ] **Step 1: Modify the file**

Open `src/config/queue.js` and add the new queue. The full updated file:

```js
const { Queue } = require('bullmq');
const Redis = require('ioredis');

const connection = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: null });

const contentProcessingQueue = new Queue('contentProcessing', { connection });
const quizGenerationQueue = new Queue('quizGeneration', { connection });
const quizAnalysisQueue = new Queue('quizAnalysis', { connection });
const journeyGenerationQueue = new Queue('journeyGeneration', { connection });
const journeyAdaptationQueue = new Queue('journeyAdaptation', { connection });
const notificationQueue = new Queue('notifications', { connection });
const youtubeImportQueue = new Queue('youtubeImport', { connection });
const whisperTranscriptionQueue = new Queue('whisperTranscription', { connection });
const competitionQueue = new Queue('competition', { connection });
const ocrProcessingQueue = new Queue('ocrProcessing', { connection });
const flashcardGenerationQueue = new Queue('flashcardGeneration', { connection });
const audioSummaryQueue = new Queue('audioSummaryGeneration', { connection });
const interviewEvaluationQueue = new Queue('interviewEvaluation', { connection });
const planGenerationQueue = new Queue('planGeneration', { connection });

module.exports = {
  contentProcessingQueue,
  quizGenerationQueue,
  quizAnalysisQueue,
  journeyGenerationQueue,
  journeyAdaptationQueue,
  notificationQueue,
  youtubeImportQueue,
  whisperTranscriptionQueue,
  competitionQueue,
  ocrProcessingQueue,
  flashcardGenerationQueue,
  audioSummaryQueue,
  interviewEvaluationQueue,
  planGenerationQueue,
};
```

- [ ] **Step 2: Verify it parses**

```bash
node --check src/config/queue.js
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add src/config/queue.js
git commit -m "feat(diagnostic-be): add planGeneration BullMQ queue"
```

---

## Task 3: Implement planGenerationService (LLM + template fallback)

**Files:**
- Create: `src/services/diagnostic/planGenerationService.js`
- Test: `src/services/diagnostic/planGenerationService.test.js`

The service implements the spec §11 contract: takes diagnostic + objective context, calls gpt-4o with json_schema strict, falls back to a deterministic template plan if LLM fails. Enforces all §11.3 constraints in a final post-validate pass (clamps total hours <= timeline x hours/week x 0.85, +20% to overestimates topics, >=8% to future-proofing).

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/planGenerationService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

// Mock openai before requiring the service under test
const openaiPath = require.resolve('../../config/openai');
const fakeOpenAI = {
  chat: { completions: { create: async () => ({}) } },
};
require.cache[openaiPath] = { exports: fakeOpenAI };

delete require.cache[require.resolve('./planGenerationService')];
const svc = require('./planGenerationService');

const baseInput = () => ({
  userId: new mongoose.Types.ObjectId(),
  objectiveId: new mongoose.Types.ObjectId(),
  diagnosticAttemptId: new mongoose.Types.ObjectId(),
  objectiveType: 'interview_preparation',
  specificsCanonical: { targetRole: 'Product Manager', targetCompany: 'Razorpay' },
  companyProfile: null,
  timeline: 8,
  weeklyCommitHours: 6,
  topicResults: [
    { canonicalName: 'product-strategy', selfRating: 'familiar', measuredScore: 35, measuredBand: 'familiar', calibrationDelta: -7, calibrationClass: 'well-calibrated', questionsAsked: 3, answerPattern: { easy: 1, medium: 1, hard: 0 }, isFutureProofing: false },
    { canonicalName: 'stakeholder-mgmt', selfRating: 'proficient', measuredScore: 30, measuredBand: 'novice', calibrationDelta: -37, calibrationClass: 'overestimates', questionsAsked: 3, answerPattern: { easy: 1, medium: 0, hard: 0 }, isFutureProofing: false },
    { canonicalName: 'ai-product-strategy', selfRating: 'novice', measuredScore: 20, measuredBand: 'novice', calibrationDelta: 5, calibrationClass: 'well-calibrated', questionsAsked: 2, answerPattern: { easy: 0, medium: 0, hard: 0 }, isFutureProofing: true },
  ],
  userMilestoneHints: [],
});

test('planGenerationService.generate: builds plan from LLM JSON', async () => {
  fakeOpenAI.chat.completions.create = async () => ({
    choices: [{ message: { content: JSON.stringify({
      planHeadline: 'Eight weeks to interview-ready PM at Razorpay.',
      bufferRecommendation: "We've left 15% buffer for life events.",
      weeklySchedule: [
        { week: 1, weeklyGoal: 'Foundations', allocations: [
          { topicCanonicalName: 'stakeholder-mgmt', hours: 3, focusActivity: 'Foundations module' },
          { topicCanonicalName: 'product-strategy', hours: 2, focusActivity: 'Read + reflect' },
          { topicCanonicalName: 'ai-product-strategy', hours: 1, focusActivity: 'Build with LLMs primer' },
        ]},
        { week: 2, weeklyGoal: 'Apply', allocations: [
          { topicCanonicalName: 'stakeholder-mgmt', hours: 3, focusActivity: 'Practice' },
          { topicCanonicalName: 'product-strategy', hours: 2, focusActivity: 'Cases' },
          { topicCanonicalName: 'ai-product-strategy', hours: 1, focusActivity: 'Tools' },
        ]},
      ],
      milestones: [
        { week: 4, title: 'Mock behavioral', measurableCriteria: 'Score 4/5 STAR clarity', isUserStated: false },
      ],
    })}}],
    usage: { total_tokens: 1500 },
  });
  const out = await svc.generate(baseInput());
  assert.strictEqual(out.source, 'llm-generated');
  assert.strictEqual(out.weeklySchedule.length, 2);
  assert.strictEqual(out.milestones[0].title, 'Mock behavioral');
  assert.ok(out.planHeadline.includes('Razorpay'));
  assert.ok(out.estimatedTotalHours > 0);
});

test('planGenerationService.generate: falls back to template on LLM error', async () => {
  fakeOpenAI.chat.completions.create = async () => { throw new Error('ETIMEDOUT'); };
  const out = await svc.generate(baseInput());
  assert.strictEqual(out.source, 'template');
  assert.ok(out.weeklySchedule.length === 8, 'template uses full timeline weeks');
  assert.ok(out.planHeadline.length > 0);
});

test('planGenerationService.generate: caps total hours at 0.85 of capacity', async () => {
  fakeOpenAI.chat.completions.create = async () => ({
    choices: [{ message: { content: JSON.stringify({
      planHeadline: 'X',
      bufferRecommendation: 'Y',
      weeklySchedule: Array.from({ length: 8 }, (_, i) => ({
        week: i + 1,
        weeklyGoal: 'g',
        allocations: [
          { topicCanonicalName: 'product-strategy', hours: 8, focusActivity: 'a' },
          { topicCanonicalName: 'stakeholder-mgmt', hours: 8, focusActivity: 'a' },
        ],
      })),
      milestones: [],
    })}}],
  });
  const input = baseInput();
  const cap = input.timeline * input.weeklyCommitHours * 0.85;
  const out = await svc.generate(input);
  assert.ok(out.estimatedTotalHours <= cap + 0.5, `total ${out.estimatedTotalHours} > cap ${cap}`);
});

test('planGenerationService.generate: applies +20% to overestimates topics in template', async () => {
  fakeOpenAI.chat.completions.create = async () => { throw new Error('fail'); };
  const out = await svc.generate(baseInput());
  const totalsByTopic = {};
  out.weeklySchedule.forEach(w => w.allocations.forEach(a => {
    totalsByTopic[a.topicCanonicalName] = (totalsByTopic[a.topicCanonicalName] || 0) + a.hours;
  }));
  assert.ok(totalsByTopic['stakeholder-mgmt'] > totalsByTopic['product-strategy'],
    'overestimates topic should receive more hours');
});

test('planGenerationService.generate: future-proofing topics get >=8% of total', async () => {
  fakeOpenAI.chat.completions.create = async () => { throw new Error('fail'); };
  const out = await svc.generate(baseInput());
  const totalsByTopic = {};
  out.weeklySchedule.forEach(w => w.allocations.forEach(a => {
    totalsByTopic[a.topicCanonicalName] = (totalsByTopic[a.topicCanonicalName] || 0) + a.hours;
  }));
  const aiShare = (totalsByTopic['ai-product-strategy'] || 0) / out.estimatedTotalHours;
  assert.ok(aiShare >= 0.08, `future-proofing share ${aiShare} should be >= 0.08`);
});

test('planGenerationService.buildTemplate: novice topics appear in week 1', async () => {
  fakeOpenAI.chat.completions.create = async () => { throw new Error('fail'); };
  const out = await svc.generate(baseInput());
  const week1Topics = out.weeklySchedule[0].allocations.map(a => a.topicCanonicalName);
  assert.ok(week1Topics.includes('stakeholder-mgmt'), 'novice topic in week 1');
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="planGenerationService"
```

Expected: FAIL "Cannot find module './planGenerationService'".

- [ ] **Step 3: Implement the service**

Create `src/services/diagnostic/planGenerationService.js`:

```js
const openai = require('../../config/openai');

const BUFFER_FACTOR = 0.85;
const OVERESTIMATES_BUMP = 1.20;
const FUTURE_PROOFING_MIN_SHARE = 0.08;
const PLAN_LLM_TIMEOUT_MS = 60_000;
const LLM_MODEL = 'gpt-4o';

const SYSTEM_PROMPT = `You are an expert learning-plan designer for ScaleUp, an India-first learning platform.
Generate a personalized weekly schedule that respects the user's diagnostic results, timeline, and weekly hours.

CONSTRAINTS:
- Total allocated hours MUST be <= timeline_weeks * weeklyCommitHours * 0.85 (15% buffer for life events).
- Topics with calibrationClass = "overestimates" receive ~+20% hours over baseline (these are the user's blind spots).
- Topics with measuredBand = "novice" must appear early (foundational sequencing) — week 1 or 2.
- Topics with isFutureProofing: true must receive at least 8% of total hours.
- Milestones spaced meaningfully: every 4-8 weeks for short timelines (<= 12 weeks), every 8-12 for longer.
- If the user provided milestone hints, prefer those (mark isUserStated: true).

INDIA CONTEXT:
- Use Indian company examples (Razorpay, Flipkart, Zomato, TCS) where natural.
- For exam_preparation, mirror Indian exam style and dates.
- Avoid US-only product references unless target is explicitly US-based.

OUTPUT: weekly schedule (one entry per week 1..timeline), each with weeklyGoal + allocations (topic x hours x focusActivity).
Plan headline: 1-2 sentences, encouraging, specific.`;

const PLAN_RESPONSE_SCHEMA = {
  type: 'json_schema',
  json_schema: {
    name: 'generated_plan',
    strict: true,
    schema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        planHeadline: { type: 'string' },
        bufferRecommendation: { type: 'string' },
        weeklySchedule: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              week: { type: 'integer' },
              weeklyGoal: { type: 'string' },
              allocations: {
                type: 'array',
                items: {
                  type: 'object',
                  additionalProperties: false,
                  properties: {
                    topicCanonicalName: { type: 'string' },
                    hours: { type: 'number' },
                    focusActivity: { type: 'string' },
                  },
                  required: ['topicCanonicalName', 'hours', 'focusActivity'],
                },
              },
            },
            required: ['week', 'weeklyGoal', 'allocations'],
          },
        },
        milestones: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              week: { type: 'integer' },
              title: { type: 'string' },
              measurableCriteria: { type: 'string' },
              isUserStated: { type: 'boolean' },
            },
            required: ['week', 'title', 'measurableCriteria', 'isUserStated'],
          },
        },
      },
      required: ['planHeadline', 'bufferRecommendation', 'weeklySchedule', 'milestones'],
    },
  },
};

function buildUserPrompt(input) {
  const { objectiveType, specificsCanonical, companyProfile, timeline, weeklyCommitHours, topicResults, userMilestoneHints } = input;
  return JSON.stringify({
    objectiveType,
    specificsCanonical,
    companyContext: companyProfile ? {
      name: companyProfile.name,
      signatureInterviewElements: companyProfile.signatureInterviewElements || [],
      examplesContext: companyProfile.examplesContext || '',
    } : null,
    timeline,
    weeklyCommitHours,
    capacityHoursWithBuffer: Math.round(timeline * weeklyCommitHours * BUFFER_FACTOR * 100) / 100,
    topics: topicResults.map(t => ({
      canonicalName: t.canonicalName,
      selfRating: t.selfRating,
      measuredScore: t.measuredScore,
      measuredBand: t.measuredBand,
      calibrationClass: t.calibrationClass,
      isFutureProofing: !!t.isFutureProofing,
      missedDifficulty: t.answerPattern || {},
    })),
    userMilestoneHints: userMilestoneHints || [],
  }, null, 2);
}

async function callLLM(input) {
  const completion = await Promise.race([
    openai.chat.completions.create({
      model: LLM_MODEL,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: buildUserPrompt(input) },
      ],
      response_format: PLAN_RESPONSE_SCHEMA,
      temperature: 0.4,
    }),
    new Promise((_, reject) => setTimeout(() => reject(new Error('PLAN_LLM_TIMEOUT')), PLAN_LLM_TIMEOUT_MS)),
  ]);
  const raw = completion?.choices?.[0]?.message?.content;
  if (!raw) throw new Error('PLAN_LLM_EMPTY_RESPONSE');
  return JSON.parse(raw);
}

function clampToCapacity(plan, timeline, weeklyCommitHours) {
  const cap = timeline * weeklyCommitHours * BUFFER_FACTOR;
  let total = 0;
  plan.weeklySchedule.forEach(w => w.allocations.forEach(a => { total += a.hours; }));
  if (total <= cap) return total;
  const scale = cap / total;
  let newTotal = 0;
  plan.weeklySchedule.forEach(w => w.allocations.forEach(a => {
    a.hours = Math.round(a.hours * scale * 10) / 10;
    newTotal += a.hours;
  }));
  return newTotal;
}

function computeBaselineWeights(topicResults) {
  const weights = {};
  topicResults.forEach(t => {
    const baseInverse = Math.max(0.2, (100 - (t.measuredScore || 0)) / 100);
    let w = baseInverse;
    if (t.calibrationClass === 'overestimates') w *= OVERESTIMATES_BUMP;
    weights[t.canonicalName] = w;
  });
  return weights;
}

function buildTemplate(input) {
  const { timeline, weeklyCommitHours, topicResults, userMilestoneHints, objectiveType, specificsCanonical } = input;
  const cap = timeline * weeklyCommitHours * BUFFER_FACTOR;
  const weights = computeBaselineWeights(topicResults);
  const sumWeights = Object.values(weights).reduce((s, x) => s + x, 0) || 1;

  const totals = {};
  topicResults.forEach(t => {
    totals[t.canonicalName] = (weights[t.canonicalName] / sumWeights) * cap;
  });

  // Future-proofing minimum (>=8% of total)
  const fpMin = cap * FUTURE_PROOFING_MIN_SHARE;
  const fpTopics = topicResults.filter(t => t.isFutureProofing).map(t => t.canonicalName);
  fpTopics.forEach(name => {
    if (totals[name] < fpMin) {
      const deficit = fpMin - totals[name];
      totals[name] = fpMin;
      const nonFP = topicResults.filter(t => !t.isFutureProofing).map(t => t.canonicalName);
      const nonFPSum = nonFP.reduce((s, n) => s + totals[n], 0) || 1;
      nonFP.forEach(n => { totals[n] = Math.max(0, totals[n] - deficit * (totals[n] / nonFPSum)); });
    }
  });

  const noviceTopics = topicResults.filter(t => t.measuredBand === 'novice').map(t => t.canonicalName);

  const weeklySchedule = [];
  for (let w = 1; w <= timeline; w++) {
    const allocations = [];
    topicResults.forEach(t => {
      const perWeek = totals[t.canonicalName] / timeline;
      let hours = perWeek;
      if (noviceTopics.includes(t.canonicalName)) {
        hours = w === 1 ? perWeek * 1.4 : perWeek * 0.94;
      }
      if (hours >= 0.25) {
        allocations.push({
          topicCanonicalName: t.canonicalName,
          hours: Math.round(hours * 10) / 10,
          focusActivity: w === 1
            ? (t.measuredBand === 'novice' ? 'Foundations module + 1 application exercise' : 'Refresh + 1 applied scenario')
            : `Apply ${t.canonicalName.replace(/-/g, ' ')} to your ${specificsCanonical?.targetRole || objectiveType.replace(/_/g, ' ')} context`,
        });
      }
    });
    weeklySchedule.push({
      week: w,
      weeklyGoal: w === 1
        ? 'Anchor foundations on weakest topics'
        : (w === timeline ? 'Consolidate + final mock' : `Build depth — week ${w}`),
      allocations,
    });
  }

  const milestones = [];
  const intervals = timeline <= 6 ? [Math.ceil(timeline / 2), timeline] : [4, 8, 12].filter(w => w <= timeline);
  if (intervals[intervals.length - 1] !== timeline) intervals.push(timeline);
  intervals.forEach((w, i) => {
    milestones.push({
      week: w,
      title: i === intervals.length - 1 ? 'Final readiness checkpoint' : `Mid-plan checkpoint ${i + 1}`,
      measurableCriteria: 'Score >= 70 on review quiz across covered topics',
      isUserStated: false,
    });
  });
  (userMilestoneHints || []).forEach(h => {
    milestones.push({
      week: Math.min(timeline, h.week || timeline),
      title: h.title || 'User milestone',
      measurableCriteria: h.measurableCriteria || 'User-defined success criteria',
      isUserStated: true,
    });
  });
  milestones.sort((a, b) => a.week - b.week);

  return {
    planHeadline: `${timeline} weeks to your ${specificsCanonical?.targetRole || objectiveType.replace(/_/g, ' ')} goal — focused on your weakest areas first.`,
    bufferRecommendation: `We've reserved ~15% of your weekly time as buffer for life events.`,
    weeklySchedule,
    milestones,
  };
}

function sumTotalHours(plan) {
  let total = 0;
  plan.weeklySchedule.forEach(w => w.allocations.forEach(a => { total += a.hours; }));
  return Math.round(total * 10) / 10;
}

async function generate(input) {
  if (!input || !input.timeline || !input.weeklyCommitHours || !Array.isArray(input.topicResults)) {
    throw new Error('planGenerationService.generate: invalid input');
  }
  let plan;
  let source = 'llm-generated';
  let llmLatencyMs = null;
  try {
    const t0 = Date.now();
    plan = await callLLM(input);
    llmLatencyMs = Date.now() - t0;
  } catch (err) {
    console.warn('[planGenerationService] LLM failed, using template:', err.message);
    plan = buildTemplate(input);
    source = 'template';
  }
  clampToCapacity(plan, input.timeline, input.weeklyCommitHours);
  const estimatedTotalHours = sumTotalHours(plan);
  return {
    planHeadline: plan.planHeadline,
    bufferRecommendation: plan.bufferRecommendation,
    weeklySchedule: plan.weeklySchedule,
    milestones: plan.milestones,
    estimatedTotalHours,
    source,
    llmLatencyMs,
    llmModel: source === 'llm-generated' ? LLM_MODEL : null,
  };
}

module.exports = {
  generate,
  buildTemplate,
  clampToCapacity,
  _internal: { SYSTEM_PROMPT, LLM_MODEL, BUFFER_FACTOR },
};
```

- [ ] **Step 4: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="planGenerationService"
```

Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnostic/planGenerationService.js src/services/diagnostic/planGenerationService.test.js
git commit -m "feat(diagnostic-be): add plan generation service with LLM + template fallback"
```

---

## Task 4: Implement planReadyNotificationService (push)

**Files:**
- Create: `src/services/diagnostic/planReadyNotificationService.js`
- Test: `src/services/diagnostic/planReadyNotificationService.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/planReadyNotificationService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

// Mock notificationService
const notifPath = require.resolve('../notificationService');
const calls = [];
require.cache[notifPath] = {
  exports: {
    sendToUser: async (userId, payload) => {
      calls.push({ userId: String(userId), payload });
      return { success: true };
    },
  },
};

delete require.cache[require.resolve('./planReadyNotificationService')];
const svc = require('./planReadyNotificationService');

test('planReadyNotificationService.notify: sends push with deep link', async () => {
  calls.length = 0;
  const userId = new mongoose.Types.ObjectId();
  const planId = new mongoose.Types.ObjectId();
  const result = await svc.notify(userId, planId);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0].userId, String(userId));
  assert.strictEqual(calls[0].payload.title, 'Your personalized plan is ready');
  assert.ok(calls[0].payload.body.toLowerCase().includes('tap'));
  assert.strictEqual(calls[0].payload.data.type, 'plan_ready');
  assert.strictEqual(calls[0].payload.data.planId, String(planId));
  assert.strictEqual(calls[0].payload.data.deepLink, 'scaleup://plan');
  assert.ok(result.success);
});

test('planReadyNotificationService.notify: tolerates push failures gracefully', async () => {
  require.cache[notifPath].exports.sendToUser = async () => { throw new Error('FCM down'); };
  // Should not throw
  const out = await svc.notify(new mongoose.Types.ObjectId(), new mongoose.Types.ObjectId());
  assert.strictEqual(out.success, false);
  assert.ok(out.error);
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="planReadyNotificationService"
```

Expected: FAIL.

- [ ] **Step 3: Implement the service**

Create `src/services/diagnostic/planReadyNotificationService.js`:

```js
const notificationService = require('../notificationService');

/**
 * Sends the "your personalized plan is ready" push to the user.
 * Uses existing FCM/APNs infra from notificationService.sendToUser
 * (which also persists an in-app Notification record).
 *
 * Best-effort. Never throws — failures are logged and returned as { success: false }.
 */
async function notify(userId, planId) {
  try {
    await notificationService.sendToUser(userId, {
      title: 'Your personalized plan is ready',
      body: 'Tap to view your weekly schedule and milestones.',
      data: {
        type: 'plan_ready',
        planId: String(planId),
        deepLink: 'scaleup://plan',
      },
    });
    return { success: true };
  } catch (err) {
    console.error('[planReadyNotificationService] push failed:', err.message);
    return { success: false, error: err.message };
  }
}

module.exports = { notify };
```

- [ ] **Step 4: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="planReadyNotificationService"
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnostic/planReadyNotificationService.js src/services/diagnostic/planReadyNotificationService.test.js
git commit -m "feat(diagnostic-be): plan-ready push notification service"
```

---

## Task 5: Implement planGenerationWorker (BullMQ)

**Files:**
- Create: `src/workers/planGenerationWorker.js`
- Test: `src/workers/planGenerationWorker.test.js`

The worker:
1. Loads `DiagnosticAttempt` + `UserObjective` (+ optional `CompanyProfile`).
2. Marshals the spec §11 contract input.
3. Calls `planGenerationService.generate`.
4. Persists a new `Plan` doc, marks any prior `Plan` for the same objective as superseded.
5. Updates `DiagnosticAttempt.planGenerationStatus` -> `ready` or `failed`.
6. Calls `planReadyNotificationService.notify` on success.

- [ ] **Step 1: Write the failing test**

Create `src/workers/planGenerationWorker.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

// Mock dependencies
const planGenPath = require.resolve('../services/diagnostic/planGenerationService');
const notifyPath = require.resolve('../services/diagnostic/planReadyNotificationService');
const planModelPath = require.resolve('../models/Plan');
const attemptModelPath = require.resolve('../models/DiagnosticAttempt');
const objectiveModelPath = require.resolve('../models/UserObjective');
const companyModelPath = require.resolve('../models/CompanyProfile');

const planGenCalls = [];
require.cache[planGenPath] = {
  exports: {
    generate: async (input) => {
      planGenCalls.push(input);
      return {
        planHeadline: 'Test plan',
        bufferRecommendation: 'b',
        weeklySchedule: [{ week: 1, weeklyGoal: 'g', allocations: [{ topicCanonicalName: 'x', hours: 1, focusActivity: 'a' }] }],
        milestones: [],
        estimatedTotalHours: 1,
        source: 'llm-generated',
        llmLatencyMs: 1234,
        llmModel: 'gpt-4o',
      };
    },
  },
};

const notifyCalls = [];
require.cache[notifyPath] = {
  exports: { notify: async (userId, planId) => { notifyCalls.push({ userId: String(userId), planId: String(planId) }); return { success: true }; } },
};

// Stub Plan, DiagnosticAttempt, UserObjective, CompanyProfile models
let savedPlans = [];
let supersededIds = [];
require.cache[planModelPath] = {
  exports: Object.assign(
    function PlanCtor(data) { Object.assign(this, data); this._id = new mongoose.Types.ObjectId(); this.save = async () => { savedPlans.push(this); return this; }; },
    {
      updateMany: async (filter, update) => { supersededIds.push({ filter, update }); return { modifiedCount: 1 }; },
    }
  ),
};

let attemptDoc;
require.cache[attemptModelPath] = {
  exports: {
    findById: () => ({
      select: () => ({
        lean: async () => attemptDoc,
      }),
    }),
    updateOne: async (filter, update) => { Object.assign(attemptDoc, update.$set || {}); return { modifiedCount: 1 }; },
  },
};

let objectiveDoc;
require.cache[objectiveModelPath] = {
  exports: { findById: () => ({ lean: async () => objectiveDoc }) },
};

require.cache[companyModelPath] = {
  exports: { findOne: () => ({ lean: async () => null }) },
};

delete require.cache[require.resolve('./planGenerationWorker')];
const worker = require('./planGenerationWorker');

test('planGenerationWorker: full happy path persists Plan, marks attempt ready, notifies user', async () => {
  savedPlans = []; planGenCalls.length = 0; notifyCalls.length = 0; supersededIds = [];
  const userId = new mongoose.Types.ObjectId();
  const objectiveId = new mongoose.Types.ObjectId();
  const attemptId = new mongoose.Types.ObjectId();
  attemptDoc = {
    _id: attemptId,
    userId,
    objectiveSnapshot: { _id: objectiveId },
    results: new Map([
      ['product-strategy', { assessedBand: 'familiar', score: 40, calibrationDelta: -5, questionsAsked: 3 }],
    ]),
    selfRatings: new Map([['product-strategy', 'familiar']]),
    planGenerationStatus: 'generating',
  };
  objectiveDoc = {
    _id: objectiveId,
    userId,
    objectiveType: 'upskilling',
    specifics: { targetSkill: 'PM' },
    specificsCanonical: { targetSkill: 'product-management' },
    timeline: 8,
    weeklyCommitHours: 6,
    topicsOfInterest: ['product-strategy'],
  };

  await worker.processJob({ data: { attemptId: String(attemptId) } });

  assert.strictEqual(planGenCalls.length, 1, 'plan service called once');
  assert.strictEqual(savedPlans.length, 1, 'one Plan saved');
  assert.strictEqual(savedPlans[0].source, 'llm-generated');
  assert.strictEqual(attemptDoc.planGenerationStatus, 'ready');
  assert.ok(attemptDoc.planId, 'attempt linked to plan');
  assert.strictEqual(notifyCalls.length, 1);
  assert.strictEqual(notifyCalls[0].userId, String(userId));
});

test('planGenerationWorker: marks attempt failed if generator throws', async () => {
  savedPlans = []; notifyCalls.length = 0;
  require.cache[planGenPath].exports.generate = async () => { throw new Error('LLM dead'); };
  attemptDoc = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    objectiveSnapshot: { _id: new mongoose.Types.ObjectId() },
    results: new Map(),
    selfRatings: new Map(),
    planGenerationStatus: 'generating',
  };
  objectiveDoc = {
    _id: attemptDoc.objectiveSnapshot._id,
    objectiveType: 'upskilling',
    timeline: 4,
    weeklyCommitHours: 4,
    topicsOfInterest: [],
  };

  await worker.processJob({ data: { attemptId: String(attemptDoc._id) } });

  assert.strictEqual(attemptDoc.planGenerationStatus, 'failed');
  assert.strictEqual(savedPlans.length, 0, 'no plan persisted on failure');
  assert.strictEqual(notifyCalls.length, 0, 'no notification on failure');
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="planGenerationWorker"
```

Expected: FAIL.

- [ ] **Step 3: Implement the worker**

Create `src/workers/planGenerationWorker.js`:

```js
const planGenerationService = require('../services/diagnostic/planGenerationService');
const planReadyNotificationService = require('../services/diagnostic/planReadyNotificationService');
const Plan = require('../models/Plan');
const DiagnosticAttempt = require('../models/DiagnosticAttempt');
const UserObjective = require('../models/UserObjective');
const CompanyProfile = require('../models/CompanyProfile');

const SELF_RATED_MIDPOINT = { novice: 15, familiar: 42, proficient: 67, expert: 90 };

function classifyCalibration(delta) {
  if (delta < -15) return 'overestimates';
  if (delta > 15) return 'undersells';
  return 'well-calibrated';
}

function buildContractInput(attempt, objective, companyProfile) {
  const resultsObj = attempt.results instanceof Map
    ? Object.fromEntries(attempt.results)
    : (attempt.results || {});
  const selfRatingsObj = attempt.selfRatings instanceof Map
    ? Object.fromEntries(attempt.selfRatings)
    : (attempt.selfRatings || {});
  const topicResults = Object.entries(resultsObj).map(([canonicalName, r]) => {
    const selfRating = selfRatingsObj[canonicalName] || 'familiar';
    const measuredScore = r.measuredScore ?? r.score ?? 0;
    const calibrationDelta = r.calibrationDelta ?? (measuredScore - SELF_RATED_MIDPOINT[selfRating] || 0);
    return {
      canonicalName,
      selfRating,
      measuredScore,
      measuredBand: r.band || r.assessedBand,
      calibrationDelta,
      calibrationClass: classifyCalibration(calibrationDelta),
      questionsAsked: r.questionsAsked || 0,
      answerPattern: r.answerPattern || {},
      isFutureProofing: !!r.isFutureProofing,
    };
  });

  return {
    userId: attempt.userId,
    objectiveId: objective._id,
    diagnosticAttemptId: attempt._id,
    objectiveType: objective.objectiveType,
    specificsCanonical: objective.specificsCanonical || objective.specifics || {},
    companyProfile,
    timeline: objective.timeline || 8,
    weeklyCommitHours: objective.weeklyCommitHours || 5,
    topicResults,
    userMilestoneHints: objective.userMilestoneHints || [],
  };
}

async function processJob(job) {
  const { attemptId } = job.data;
  if (!attemptId) throw new Error('planGenerationWorker: attemptId required');

  const attempt = await DiagnosticAttempt.findById(attemptId)
    .select('_id userId objectiveSnapshot results selfRatings planGenerationStatus planId')
    .lean();
  if (!attempt) {
    console.warn(`[planGenerationWorker] attempt ${attemptId} not found`);
    return { skipped: true };
  }

  const objectiveId = attempt.objectiveSnapshot?._id;
  if (!objectiveId) {
    await DiagnosticAttempt.updateOne({ _id: attemptId }, { $set: { planGenerationStatus: 'failed' } });
    return { skipped: true, reason: 'no_objective' };
  }

  const objective = await UserObjective.findById(objectiveId).lean();
  if (!objective) {
    await DiagnosticAttempt.updateOne({ _id: attemptId }, { $set: { planGenerationStatus: 'failed' } });
    return { skipped: true, reason: 'objective_missing' };
  }

  let companyProfile = null;
  const companyName = objective.specificsCanonical?.targetCompany || objective.specifics?.targetCompany;
  if (companyName) {
    companyProfile = await CompanyProfile.findOne({ normalizedName: String(companyName).toLowerCase().trim() }).lean();
  }

  try {
    const input = buildContractInput(attempt, objective, companyProfile);
    const generated = await planGenerationService.generate(input);

    // Supersede any prior active plan for this objective
    await Plan.updateMany(
      { userId: attempt.userId, objectiveId, isActive: true },
      { $set: { isActive: false, supersededAt: new Date() } }
    );

    const plan = new Plan({
      userId: attempt.userId,
      objectiveId,
      diagnosticAttemptId: attempt._id,
      planHeadline: generated.planHeadline,
      estimatedTotalHours: generated.estimatedTotalHours,
      bufferRecommendation: generated.bufferRecommendation,
      weeklySchedule: generated.weeklySchedule,
      milestones: generated.milestones,
      source: generated.source,
      llmLatencyMs: generated.llmLatencyMs,
      llmModel: generated.llmModel,
      isActive: true,
    });
    await plan.save();

    await DiagnosticAttempt.updateOne(
      { _id: attemptId },
      { $set: { planGenerationStatus: 'ready', planId: plan._id } }
    );

    await planReadyNotificationService.notify(attempt.userId, plan._id);

    return { success: true, planId: plan._id };
  } catch (err) {
    console.error(`[planGenerationWorker] failed for attempt ${attemptId}:`, err.message);
    await DiagnosticAttempt.updateOne(
      { _id: attemptId },
      { $set: { planGenerationStatus: 'failed' } }
    );
    return { success: false, error: err.message };
  }
}

module.exports = { processJob, buildContractInput };
```

- [ ] **Step 4: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="planGenerationWorker"
```

Expected: 2 tests pass.

- [ ] **Step 5: Wire the worker into `src/workers/index.js`**

Open `src/workers/index.js` and find the worker registration block (it follows the existing pattern of `new Worker('queueName', handler, { connection })`). Add:

```js
const { Worker } = require('bullmq');
const Redis = require('ioredis');
const planGenerationWorker = require('./planGenerationWorker');

// Inside the existing init function, after the other Worker registrations:
const planGenerationConn = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: null });
new Worker('planGeneration', planGenerationWorker.processJob, {
  connection: planGenerationConn,
  concurrency: 4,
});
```

- [ ] **Step 6: Modify diagnosticService finishAttempt to enqueue**

Open `src/services/diagnosticService.js`. In the `finishAttempt` flow (which already triggers async insights), add an enqueue immediately after attempt status flips to `completed`:

```js
const { planGenerationQueue } = require('../config/queue');
// ... inside finishAttempt, after marking complete and before returning:
await DiagnosticAttempt.updateOne(
  { _id: attemptId },
  { $set: { planGenerationStatus: 'generating' } }
);
await planGenerationQueue.add(
  'generate',
  { attemptId: String(attemptId) },
  { attempts: 2, backoff: { type: 'exponential', delay: 5000 }, removeOnComplete: true, removeOnFail: 50 }
);
```

- [ ] **Step 7: Commit**

```bash
git add src/workers/planGenerationWorker.js src/workers/planGenerationWorker.test.js src/workers/index.js src/services/diagnosticService.js
git commit -m "feat(diagnostic-be): plan generation BullMQ worker + finishAttempt enqueue"
```

---

## Task 6: Plan endpoints (`/plan/status`, `/plan/current`)

**Files:**
- Create: `src/controllers/planController.js`
- Create: `src/routes/plan.js`
- Modify: `src/app.js`

- [ ] **Step 1: Write controller test**

Create `src/controllers/planController.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

// Stub models
const planModelPath = require.resolve('../models/Plan');
const attemptModelPath = require.resolve('../models/DiagnosticAttempt');

let activePlan = null;
let latestAttempt = null;
require.cache[planModelPath] = {
  exports: {
    findOne: (filter) => ({ sort: () => ({ lean: async () => activePlan }) }),
  },
};
require.cache[attemptModelPath] = {
  exports: {
    findOne: (filter) => ({ sort: () => ({ select: () => ({ lean: async () => latestAttempt }) }) }),
  },
};

delete require.cache[require.resolve('./planController')];
const ctrl = require('./planController');

function fakeRes() {
  const r = { _status: 200, _json: null };
  r.status = (s) => { r._status = s; return r; };
  r.json = (j) => { r._json = j; return r; };
  return r;
}

test('planController.getStatus: returns generating when no plan yet', async () => {
  activePlan = null;
  latestAttempt = { planGenerationStatus: 'generating' };
  const req = { user: { userId: new mongoose.Types.ObjectId() } };
  const res = fakeRes();
  await ctrl.getStatus(req, res);
  assert.strictEqual(res._json.status, 'generating');
});

test('planController.getStatus: returns ready when plan exists', async () => {
  activePlan = { _id: new mongoose.Types.ObjectId(), source: 'llm-generated', updatedAt: new Date() };
  latestAttempt = { planGenerationStatus: 'ready', planId: activePlan._id };
  const req = { user: { userId: new mongoose.Types.ObjectId() } };
  const res = fakeRes();
  await ctrl.getStatus(req, res);
  assert.strictEqual(res._json.status, 'ready');
  assert.ok(res._json.planId);
});

test('planController.getCurrent: returns the active plan', async () => {
  activePlan = {
    _id: new mongoose.Types.ObjectId(),
    planHeadline: 'h',
    estimatedTotalHours: 10,
    weeklySchedule: [],
    milestones: [],
    source: 'template',
  };
  const req = { user: { userId: new mongoose.Types.ObjectId() } };
  const res = fakeRes();
  await ctrl.getCurrent(req, res);
  assert.strictEqual(res._json.planHeadline, 'h');
  assert.strictEqual(res._json.source, 'template');
});

test('planController.getCurrent: returns 404 when no plan', async () => {
  activePlan = null;
  const req = { user: { userId: new mongoose.Types.ObjectId() } };
  const res = fakeRes();
  await ctrl.getCurrent(req, res);
  assert.strictEqual(res._status, 404);
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="planController"
```

Expected: FAIL.

- [ ] **Step 3: Implement the controller**

Create `src/controllers/planController.js`:

```js
const Plan = require('../models/Plan');
const DiagnosticAttempt = require('../models/DiagnosticAttempt');

async function getStatus(req, res) {
  const userId = req.user.userId;
  const activePlan = await Plan.findOne({ userId, isActive: true })
    .sort({ updatedAt: -1 })
    .lean();
  if (activePlan) {
    return res.status(200).json({
      status: 'ready',
      planId: String(activePlan._id),
      source: activePlan.source,
      updatedAt: activePlan.updatedAt,
    });
  }
  const latestAttempt = await DiagnosticAttempt.findOne({ userId, status: 'completed' })
    .sort({ completedAt: -1 })
    .select('planGenerationStatus planId')
    .lean();
  if (!latestAttempt) {
    return res.status(200).json({ status: 'pending' });
  }
  return res.status(200).json({
    status: latestAttempt.planGenerationStatus || 'pending',
    planId: latestAttempt.planId ? String(latestAttempt.planId) : null,
  });
}

async function getCurrent(req, res) {
  const userId = req.user.userId;
  const plan = await Plan.findOne({ userId, isActive: true })
    .sort({ updatedAt: -1 })
    .lean();
  if (!plan) return res.status(404).json({ message: 'No active plan' });
  return res.status(200).json({
    planId: String(plan._id),
    planHeadline: plan.planHeadline,
    estimatedTotalHours: plan.estimatedTotalHours,
    bufferRecommendation: plan.bufferRecommendation,
    weeklySchedule: plan.weeklySchedule,
    milestones: plan.milestones,
    source: plan.source,
    updatedAt: plan.updatedAt,
  });
}

module.exports = { getStatus, getCurrent };
```

- [ ] **Step 4: Create the route**

Create `src/routes/plan.js`:

```js
const router = require('express').Router();
const ctrl = require('../controllers/planController');
const auth = require('../middleware/auth');

router.use(auth);

router.get('/status', ctrl.getStatus);
router.get('/current', ctrl.getCurrent);

module.exports = router;
```

- [ ] **Step 5: Mount in `src/app.js`**

In `src/app.js`, find where other routes are mounted (look for `app.use('/diagnostic', ...)`) and add immediately after:

```js
app.use('/plan', require('./routes/plan'));
```

- [ ] **Step 6: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="planController"
```

Expected: 4 tests pass.

- [ ] **Step 7: Commit**

```bash
git add src/controllers/planController.js src/controllers/planController.test.js src/routes/plan.js src/app.js
git commit -m "feat(diagnostic-be): /plan/status and /plan/current endpoints"
```

---

## Task 7: Modify journeyGenerationService to consume new Plan structure

The existing `journeyGenerationService.js` produces content-aware learning journeys. After Phase 5, the *plan* is the source of truth for hours/topics, and the journey is now a downstream content-curation pass that pulls Content matching the plan's `weeklySchedule`.

**File:** `src/services/journeyGenerationService.js` (MODIFY)

- [ ] **Step 1: Inspect current implementation**

```bash
sed -n '50,200p' src/services/journeyGenerationService.js
```

- [ ] **Step 2: Add a new entrypoint that takes a Plan**

Append to `src/services/journeyGenerationService.js`:

```js
const Plan = require('../models/Plan');

/**
 * NEW: generateFromPlan — produces a Journey by consuming an existing Plan doc.
 * The Plan is the source of truth for which topics get how many hours.
 * Journey only adds Content selection per topic.
 *
 * Backwards compat: existing generateJourney(userId, objectiveId) keeps working.
 */
JourneyGenerationService.prototype.generateFromPlan = async function generateFromPlan(planId) {
  const plan = await Plan.findById(planId).lean();
  if (!plan) throw new Error(`Plan ${planId} not found`);

  // Aggregate per-topic total hours from the plan
  const topicHours = {};
  plan.weeklySchedule.forEach(w => w.allocations.forEach(a => {
    topicHours[a.topicCanonicalName] = (topicHours[a.topicCanonicalName] || 0) + a.hours;
  }));
  const planTopics = Object.keys(topicHours);

  // Reuse existing content matching path
  const Content = require('../models/Content');
  const availableContent = await Content.find({
    status: 'published',
    $or: [{ topics: { $in: planTopics } }, { domain: { $in: planTopics } }],
  })
    .sort({ 'aiData.qualityScore': -1 })
    .limit(200)
    .select('_id title topics difficulty domain durationMinutes')
    .lean();

  // Map each plan topic to the top 3 matching content items
  const journeyContent = planTopics.map(topic => {
    const matches = availableContent
      .filter(c => (c.topics || []).includes(topic) || c.domain === topic)
      .slice(0, 3);
    return {
      topicCanonicalName: topic,
      hoursAllocated: topicHours[topic],
      contentIds: matches.map(c => c._id),
    };
  });

  return {
    planId: plan._id,
    objectiveId: plan.objectiveId,
    weeklySchedule: plan.weeklySchedule,
    journeyContent,
  };
};
```

- [ ] **Step 3: Verify it parses**

```bash
node --check src/services/journeyGenerationService.js
```

- [ ] **Step 4: Add a smoke test**

Append to `src/services/journeyGenerationService.test.js`:

```js
test('JourneyGenerationService.generateFromPlan: maps plan topics to content', async () => {
  // Stub Plan.findById and Content.find
  const Plan = require('../models/Plan');
  const Content = require('../models/Content');
  Plan.findById = () => ({ lean: async () => ({
    _id: new (require('mongoose').Types.ObjectId)(),
    objectiveId: new (require('mongoose').Types.ObjectId)(),
    weeklySchedule: [{
      week: 1, weeklyGoal: 'g',
      allocations: [{ topicCanonicalName: 'product-strategy', hours: 3, focusActivity: 'a' }],
    }],
  })});
  Content.find = () => ({
    sort: () => ({ limit: () => ({ select: () => ({ lean: async () => [
      { _id: new (require('mongoose').Types.ObjectId)(), title: 'Strategy 101', topics: ['product-strategy'] },
    ]})})}),
  });
  const svc = new (require('./journeyGenerationService').constructor || function(){})();
  // The service is exported as a class instance pattern — adjust as needed:
  const journeyGenerationService = require('./journeyGenerationService');
  const out = await journeyGenerationService.generateFromPlan('any-id');
  assert.strictEqual(out.journeyContent.length, 1);
  assert.strictEqual(out.journeyContent[0].topicCanonicalName, 'product-strategy');
});
```

- [ ] **Step 5: Commit**

```bash
git add src/services/journeyGenerationService.js src/services/journeyGenerationService.test.js
git commit -m "feat(diagnostic-be): journey service consumes new Plan structure"
```

---

## Task 8: Re-calibration eligibility service

Per spec §3.5: re-test topics where the user has spent >=5 plan hours since last diagnostic, OR self-flagged "I've grown here", OR the largest original calibration gap.

**Files:**
- Create: `src/services/diagnostic/recalibrationEligibilityService.js`
- Test: `src/services/diagnostic/recalibrationEligibilityService.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/recalibrationEligibilityService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const attemptModelPath = require.resolve('../../models/DiagnosticAttempt');
const planModelPath = require.resolve('../../models/Plan');
const progressPath = require.resolve('../journeyProgressService');

let lastAttempt = null;
let activePlan = null;
let topicHoursSpent = {};

require.cache[attemptModelPath] = {
  exports: {
    findOne: () => ({ sort: () => ({ select: () => ({ lean: async () => lastAttempt }) }) }),
  },
};
require.cache[planModelPath] = {
  exports: {
    findOne: () => ({ sort: () => ({ lean: async () => activePlan }) }),
  },
};
require.cache[progressPath] = {
  exports: {
    getHoursSpentByTopic: async () => topicHoursSpent,
  },
};

delete require.cache[require.resolve('./recalibrationEligibilityService')];
const svc = require('./recalibrationEligibilityService');

const NOW = Date.now();

test('eligibility: not eligible if last attempt was <30 days ago', async () => {
  lastAttempt = {
    _id: new mongoose.Types.ObjectId(),
    completedAt: new Date(NOW - 20 * 24 * 3600 * 1000),
    results: new Map(),
  };
  const out = await svc.computeEligibility(new mongoose.Types.ObjectId());
  assert.strictEqual(out.eligible, false);
  assert.strictEqual(out.reason, 'too_recent');
});

test('eligibility: eligible after 30+ days; selects topics with >=5 hours spent', async () => {
  lastAttempt = {
    _id: new mongoose.Types.ObjectId(),
    completedAt: new Date(NOW - 35 * 24 * 3600 * 1000),
    results: new Map([
      ['product-strategy', { calibrationDelta: -25 }],
      ['stakeholder-mgmt', { calibrationDelta: -2 }],
      ['ai-product-strategy', { calibrationDelta: 3 }],
    ]),
  };
  activePlan = { _id: new mongoose.Types.ObjectId() };
  topicHoursSpent = { 'product-strategy': 6, 'stakeholder-mgmt': 1, 'ai-product-strategy': 7 };
  const out = await svc.computeEligibility(new mongoose.Types.ObjectId());
  assert.strictEqual(out.eligible, true);
  assert.ok(out.eligibleTopics.includes('product-strategy'), 'topic with 6h selected');
  assert.ok(out.eligibleTopics.includes('ai-product-strategy'), 'topic with 7h selected');
});

test('eligibility: always includes biggest-calibration-gap topic even if low hours', async () => {
  lastAttempt = {
    _id: new mongoose.Types.ObjectId(),
    completedAt: new Date(NOW - 35 * 24 * 3600 * 1000),
    results: new Map([
      ['product-strategy', { calibrationDelta: -40 }],   // biggest |delta|
      ['stakeholder-mgmt', { calibrationDelta: -2 }],
    ]),
  };
  topicHoursSpent = { 'product-strategy': 1, 'stakeholder-mgmt': 1 };
  const out = await svc.computeEligibility(new mongoose.Types.ObjectId());
  assert.strictEqual(out.eligible, true);
  assert.ok(out.eligibleTopics.includes('product-strategy'));
});

test('eligibility: respects user self-flag override', async () => {
  lastAttempt = {
    _id: new mongoose.Types.ObjectId(),
    completedAt: new Date(NOW - 35 * 24 * 3600 * 1000),
    results: new Map([['stakeholder-mgmt', { calibrationDelta: -1 }]]),
  };
  topicHoursSpent = { 'stakeholder-mgmt': 1 };
  const out = await svc.computeEligibility(new mongoose.Types.ObjectId(), {
    userFlaggedTopics: ['stakeholder-mgmt'],
  });
  assert.ok(out.eligibleTopics.includes('stakeholder-mgmt'));
});

test('eligibility: caps eligibleTopics at 6 (~12 questions / 4-5 min)', async () => {
  lastAttempt = {
    _id: new mongoose.Types.ObjectId(),
    completedAt: new Date(NOW - 35 * 24 * 3600 * 1000),
    results: new Map(Array.from({ length: 10 }, (_, i) => [`topic-${i}`, { calibrationDelta: -20 }])),
  };
  topicHoursSpent = Object.fromEntries(Array.from({ length: 10 }, (_, i) => [`topic-${i}`, 6]));
  const out = await svc.computeEligibility(new mongoose.Types.ObjectId());
  assert.ok(out.eligibleTopics.length <= 6, `should cap at 6, got ${out.eligibleTopics.length}`);
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="eligibility"
```

Expected: FAIL.

- [ ] **Step 3: Implement the service**

Create `src/services/diagnostic/recalibrationEligibilityService.js`:

```js
const DiagnosticAttempt = require('../../models/DiagnosticAttempt');
const Plan = require('../../models/Plan');

const RECALIBRATION_MIN_DAYS = 30;
const RECALIBRATION_MIN_HOURS_PER_TOPIC = 5;
const MAX_TOPICS = 6;

/**
 * Compute whether a user is eligible for re-calibration and which topics to re-test.
 * Per spec §3.5.
 *
 * @param {ObjectId|string} userId
 * @param {object} [opts]
 * @param {string[]} [opts.userFlaggedTopics] — topics the user explicitly asked to retest
 */
async function computeEligibility(userId, opts = {}) {
  const userFlagged = new Set(opts.userFlaggedTopics || []);

  const lastAttempt = await DiagnosticAttempt.findOne({
    userId,
    status: 'completed',
  })
    .sort({ completedAt: -1 })
    .select('_id completedAt results')
    .lean();

  if (!lastAttempt) {
    return { eligible: false, reason: 'no_prior_attempt' };
  }

  const ageDays = (Date.now() - new Date(lastAttempt.completedAt).getTime()) / (24 * 3600 * 1000);
  if (ageDays < RECALIBRATION_MIN_DAYS) {
    return { eligible: false, reason: 'too_recent', ageDays: Math.round(ageDays) };
  }

  // Determine hours spent per topic since lastAttempt.completedAt
  const journeyProgressService = require('../journeyProgressService');
  const activePlan = await Plan.findOne({ userId, isActive: true }).sort({ updatedAt: -1 }).lean();
  const hoursByTopic = activePlan
    ? await journeyProgressService.getHoursSpentByTopic(userId, activePlan._id, lastAttempt.completedAt)
    : {};

  const resultsObj = lastAttempt.results instanceof Map
    ? Object.fromEntries(lastAttempt.results)
    : (lastAttempt.results || {});

  // Candidate set: topics in last attempt
  const candidates = Object.keys(resultsObj);

  // Pick: any with >=5 hours spent OR user-flagged
  const picked = new Set();
  candidates.forEach(t => {
    if ((hoursByTopic[t] || 0) >= RECALIBRATION_MIN_HOURS_PER_TOPIC) picked.add(t);
    if (userFlagged.has(t)) picked.add(t);
  });

  // Always include the topic with the biggest absolute calibration gap from last attempt
  let biggestGapTopic = null;
  let biggestGapAbs = -1;
  candidates.forEach(t => {
    const d = Math.abs(resultsObj[t]?.calibrationDelta || 0);
    if (d > biggestGapAbs) { biggestGapAbs = d; biggestGapTopic = t; }
  });
  if (biggestGapTopic) picked.add(biggestGapTopic);

  const eligibleTopics = Array.from(picked).slice(0, MAX_TOPICS);

  if (eligibleTopics.length === 0) {
    return { eligible: false, reason: 'no_eligible_topics' };
  }

  return {
    eligible: true,
    previousAttemptId: lastAttempt._id,
    eligibleTopics,
    expectedDurationMin: Math.round(eligibleTopics.length * 0.8), // ~4-5 min for 6 topics
  };
}

module.exports = {
  computeEligibility,
  RECALIBRATION_MIN_DAYS,
  RECALIBRATION_MIN_HOURS_PER_TOPIC,
  MAX_TOPICS,
};
```

- [ ] **Step 4: Stub `journeyProgressService.getHoursSpentByTopic`**

Open `src/services/journeyProgressService.js` and add (if not present):

```js
/**
 * Sum minutes consumed per topic since `sinceDate`, keyed by canonical topic name.
 * Returns hours (minutes/60).
 */
async function getHoursSpentByTopic(userId, planId, sinceDate) {
  const ContentInteraction = require('../models/ContentInteraction');
  const interactions = await ContentInteraction.find({
    userId,
    completedAt: { $gte: sinceDate },
  }).populate('contentId', 'topics').lean();
  const byTopic = {};
  interactions.forEach(i => {
    const minutes = i.timeSpentMinutes || 0;
    (i.contentId?.topics || []).forEach(t => {
      byTopic[t] = (byTopic[t] || 0) + minutes / 60;
    });
  });
  return byTopic;
}

module.exports.getHoursSpentByTopic = getHoursSpentByTopic;
```

- [ ] **Step 5: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="eligibility"
```

Expected: 5 tests pass.

- [ ] **Step 6: Add endpoint `GET /diagnostic/recalibration/eligible`**

In `src/controllers/diagnosticController.js` add:

```js
const recalibrationEligibilityService = require('../services/diagnostic/recalibrationEligibilityService');

exports.getRecalibrationEligibility = async (req, res) => {
  const out = await recalibrationEligibilityService.computeEligibility(req.user.userId, {
    userFlaggedTopics: req.query.flagged ? String(req.query.flagged).split(',') : [],
  });
  res.status(200).json(out);
};
```

In `src/routes/diagnostic.js` add the route:

```js
router.get('/recalibration/eligible', ctrl.getRecalibrationEligibility);
```

- [ ] **Step 7: Commit**

```bash
git add src/services/diagnostic/recalibrationEligibilityService.js src/services/diagnostic/recalibrationEligibilityService.test.js src/services/journeyProgressService.js src/controllers/diagnosticController.js src/routes/diagnostic.js
git commit -m "feat(diagnostic-be): re-calibration eligibility service + endpoint"
```

---

## Task 9: Modify diagnosticService to support `attemptType: 'recalibration'`

The shorter diagnostic uses the same selection algorithm from Plan 3, but only for the eligible topic set, with reduced question counts (1-2 per topic instead of 2-3). Total: 8-12 questions.

**File:** `src/services/diagnosticService.js` (MODIFY)

- [ ] **Step 1: Locate the existing startAttempt / selection logic**

```bash
grep -n "startAttempt\|selectQuestions\|attemptType" src/services/diagnosticService.js | head -20
```

- [ ] **Step 2: Add a new entry point `startRecalibration`**

Append to `src/services/diagnosticService.js`:

```js
const recalibrationEligibilityService = require('./diagnostic/recalibrationEligibilityService');
const diagnosticSelectorService = require('./diagnosticSelectorService');

/**
 * Start a re-calibration attempt: shorter diagnostic limited to eligible topics.
 * Reuses the existing selector with override `questionsPerTopicCap: 2`.
 */
exports.startRecalibration = async function startRecalibration(userId, opts = {}) {
  const eligibility = await recalibrationEligibilityService.computeEligibility(userId, {
    userFlaggedTopics: opts.userFlaggedTopics || [],
  });
  if (!eligibility.eligible) {
    throw Object.assign(new Error('Not eligible for re-calibration'), { code: 'NOT_ELIGIBLE', meta: eligibility });
  }

  const previousAttempt = await DiagnosticAttempt.findById(eligibility.previousAttemptId).lean();
  const objectiveId = previousAttempt?.objectiveSnapshot?._id;
  const objective = await UserObjective.findById(objectiveId).lean();

  // Reuse selector but cap at 2 questions per topic and force topic set
  const pool = await diagnosticSelectorService.selectQuestions({
    userId,
    objective,
    onlyTopics: eligibility.eligibleTopics,
    questionsPerTopicCap: 2,
    skipAnchorBoost: true,
  });

  const attempt = await DiagnosticAttempt.create({
    userId,
    flowType: 'recalibration',
    attemptType: 'recalibration',
    previousAttemptId: eligibility.previousAttemptId,
    poolQuestionIds: pool.map(q => q._id),
    selfRatings: previousAttempt?.selfRatings || new Map(),
    objectiveSnapshot: { _id: objectiveId, label: objective?.specifics?.targetRole || objective?.objectiveType },
    status: 'in_progress',
    planGenerationStatus: 'pending',
  });

  return {
    attemptId: attempt._id,
    totalEstimatedQuestions: pool.length,
    estimatedDurationSec: pool.length * 25,
    flowType: 'recalibration',
  };
};
```

- [ ] **Step 3: Add controller + route**

In `src/controllers/diagnosticController.js`:

```js
exports.startRecalibration = async (req, res) => {
  try {
    const out = await require('../services/diagnosticService').startRecalibration(req.user.userId, {
      userFlaggedTopics: req.body?.flaggedTopics || [],
    });
    res.status(200).json(out);
  } catch (err) {
    if (err.code === 'NOT_ELIGIBLE') return res.status(409).json({ message: err.message, meta: err.meta });
    throw err;
  }
};
```

In `src/routes/diagnostic.js`:

```js
router.post('/recalibration/start', ctrl.startRecalibration);
```

- [ ] **Step 4: Add test**

Create `src/services/diagnosticService.recalibration.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const eligibilityPath = require.resolve('./diagnostic/recalibrationEligibilityService');
const selectorPath = require.resolve('./diagnosticSelectorService');
const attemptPath = require.resolve('../models/DiagnosticAttempt');
const objectivePath = require.resolve('../models/UserObjective');

require.cache[eligibilityPath] = {
  exports: {
    computeEligibility: async () => ({
      eligible: true,
      previousAttemptId: new mongoose.Types.ObjectId(),
      eligibleTopics: ['product-strategy', 'stakeholder-mgmt'],
    }),
  },
};

require.cache[selectorPath] = {
  exports: {
    selectQuestions: async () => ([{ _id: new mongoose.Types.ObjectId() }, { _id: new mongoose.Types.ObjectId() }]),
  },
};

let savedAttempt = null;
require.cache[attemptPath] = {
  exports: {
    findById: () => ({ lean: async () => ({ objectiveSnapshot: { _id: new mongoose.Types.ObjectId() }, selfRatings: new Map() }) }),
    create: async (data) => { savedAttempt = { ...data, _id: new mongoose.Types.ObjectId() }; return savedAttempt; },
  },
};
require.cache[objectivePath] = {
  exports: { findById: () => ({ lean: async () => ({ _id: new mongoose.Types.ObjectId(), objectiveType: 'upskilling', specifics: { targetRole: 'PM' }}) }) },
};

delete require.cache[require.resolve('./diagnosticService')];
const svc = require('./diagnosticService');

test('startRecalibration: creates attempt with attemptType=recalibration', async () => {
  const out = await svc.startRecalibration(new mongoose.Types.ObjectId());
  assert.strictEqual(out.flowType, 'recalibration');
  assert.strictEqual(savedAttempt.attemptType, 'recalibration');
  assert.ok(savedAttempt.previousAttemptId);
});

test('startRecalibration: throws NOT_ELIGIBLE when not eligible', async () => {
  require.cache[eligibilityPath].exports.computeEligibility = async () => ({ eligible: false, reason: 'too_recent' });
  delete require.cache[require.resolve('./diagnosticService')];
  const svc2 = require('./diagnosticService');
  try {
    await svc2.startRecalibration(new mongoose.Types.ObjectId());
    assert.fail('should have thrown');
  } catch (err) {
    assert.strictEqual(err.code, 'NOT_ELIGIBLE');
  }
});
```

- [ ] **Step 5: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="startRecalibration"
```

Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.recalibration.test.js src/controllers/diagnosticController.js src/routes/diagnostic.js
git commit -m "feat(diagnostic-be): re-calibration shorter diagnostic flow"
```

---

## Task 10: Re-calibration results service + plan auto-rebalance

Compute growth bars (old vs new measured score per topic, delta, biggest jump). Persist on the new attempt. Re-run plan generator with new measured scores. Mark old plan superseded.

**Files:**
- Create: `src/services/diagnostic/recalibrationResultsService.js`
- Test: `src/services/diagnostic/recalibrationResultsService.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/recalibrationResultsService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const attemptPath = require.resolve('../../models/DiagnosticAttempt');
const planWorkerPath = require.resolve('../../workers/planGenerationWorker');

let attempts = {};
require.cache[attemptPath] = {
  exports: {
    findById: (id) => ({ lean: async () => attempts[String(id)] }),
    updateOne: async (filter, update) => {
      const id = String(filter._id);
      attempts[id] = { ...attempts[id], ...update.$set };
      return { modifiedCount: 1 };
    },
  },
};

const planWorkerCalls = [];
require.cache[planWorkerPath] = {
  exports: {
    processJob: async (job) => { planWorkerCalls.push(job.data); return { success: true, planId: new mongoose.Types.ObjectId() }; },
  },
};

delete require.cache[require.resolve('./recalibrationResultsService')];
const svc = require('./recalibrationResultsService');

test('computeGrowth: per-topic delta + biggest jump', async () => {
  const newId = new mongoose.Types.ObjectId();
  const oldId = new mongoose.Types.ObjectId();
  attempts[String(newId)] = {
    _id: newId, attemptType: 'recalibration', previousAttemptId: oldId,
    results: new Map([
      ['product-strategy', { score: 60, assessedBand: 'proficient' }],
      ['stakeholder-mgmt', { score: 55, assessedBand: 'familiar' }],
    ]),
  };
  attempts[String(oldId)] = {
    _id: oldId, attemptType: 'initial',
    results: new Map([
      ['product-strategy', { score: 40, assessedBand: 'familiar' }],
      ['stakeholder-mgmt', { score: 30, assessedBand: 'novice' }],
    ]),
  };

  const out = await svc.computeGrowth(newId);
  assert.strictEqual(out.growthBars.length, 2);
  const ps = out.growthBars.find(g => g.canonicalName === 'product-strategy');
  assert.strictEqual(ps.oldScore, 40);
  assert.strictEqual(ps.newScore, 60);
  assert.strictEqual(ps.delta, 20);
  assert.strictEqual(ps.bandShift, 'familiar→proficient');
  assert.strictEqual(out.biggestJump.canonicalName, 'stakeholder-mgmt');
  assert.strictEqual(out.biggestJump.delta, 25);
});

test('computeGrowth: surfaces newly-emerged gaps (topic that drifted down)', async () => {
  const newId = new mongoose.Types.ObjectId();
  const oldId = new mongoose.Types.ObjectId();
  attempts[String(newId)] = {
    _id: newId, attemptType: 'recalibration', previousAttemptId: oldId,
    results: new Map([['product-strategy', { score: 25, assessedBand: 'novice' }]]),
  };
  attempts[String(oldId)] = {
    _id: oldId, attemptType: 'initial',
    results: new Map([['product-strategy', { score: 65, assessedBand: 'proficient' }]]),
  };
  const out = await svc.computeGrowth(newId);
  assert.ok(out.newGaps.includes('product-strategy'), 'large drop flagged as new gap');
});

test('rebalancePlan: triggers plan worker with new attempt id', async () => {
  planWorkerCalls.length = 0;
  await svc.rebalancePlan(new mongoose.Types.ObjectId(), 'attempt-id');
  assert.strictEqual(planWorkerCalls.length, 1);
  assert.strictEqual(planWorkerCalls[0].attemptId, 'attempt-id');
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="computeGrowth\|rebalancePlan"
```

- [ ] **Step 3: Implement the service**

Create `src/services/diagnostic/recalibrationResultsService.js`:

```js
const DiagnosticAttempt = require('../../models/DiagnosticAttempt');

const NEW_GAP_DROP_THRESHOLD = 20;

function bandShiftLabel(oldBand, newBand) {
  if (!oldBand || !newBand || oldBand === newBand) return null;
  return `${oldBand}→${newBand}`;
}

async function computeGrowth(newAttemptId) {
  const newAttempt = await DiagnosticAttempt.findById(newAttemptId).lean();
  if (!newAttempt) throw new Error('New attempt not found');
  if (newAttempt.attemptType !== 'recalibration') {
    throw new Error('computeGrowth: attempt is not a recalibration');
  }
  if (!newAttempt.previousAttemptId) {
    throw new Error('computeGrowth: previousAttemptId missing');
  }
  const oldAttempt = await DiagnosticAttempt.findById(newAttempt.previousAttemptId).lean();
  if (!oldAttempt) throw new Error('Previous attempt not found');

  const newResults = newAttempt.results instanceof Map ? Object.fromEntries(newAttempt.results) : (newAttempt.results || {});
  const oldResults = oldAttempt.results instanceof Map ? Object.fromEntries(oldAttempt.results) : (oldAttempt.results || {});

  const growthBars = [];
  const newGaps = [];

  Object.keys(newResults).forEach(topic => {
    const oldR = oldResults[topic] || {};
    const newR = newResults[topic] || {};
    const oldScore = oldR.score ?? oldR.measuredScore ?? null;
    const newScore = newR.score ?? newR.measuredScore ?? null;
    if (oldScore == null || newScore == null) return;
    const delta = newScore - oldScore;
    growthBars.push({
      canonicalName: topic,
      oldScore,
      newScore,
      delta,
      oldBand: oldR.assessedBand || oldR.band,
      newBand: newR.assessedBand || newR.band,
      bandShift: bandShiftLabel(oldR.assessedBand || oldR.band, newR.assessedBand || newR.band),
    });
    if (delta <= -NEW_GAP_DROP_THRESHOLD) newGaps.push(topic);
  });

  growthBars.sort((a, b) => b.delta - a.delta);
  const biggestJump = growthBars[0] || null;

  return {
    growthBars,
    biggestJump,
    newGaps,
    summary: biggestJump
      ? `Biggest growth: ${biggestJump.canonicalName} (+${biggestJump.delta} pts${biggestJump.bandShift ? `, ${biggestJump.bandShift}` : ''}).`
      : 'No measurable growth this cycle — keep going.',
  };
}

async function persistGrowth(newAttemptId) {
  const growth = await computeGrowth(newAttemptId);
  await DiagnosticAttempt.updateOne(
    { _id: newAttemptId },
    { $set: { recalibrationGrowth: growth } }
  );
  return growth;
}

/**
 * Re-runs the plan generator off the recalibration attempt so the plan rebalances
 * around the new measured scores. The worker handles superseding the previous active plan.
 */
async function rebalancePlan(userId, attemptId) {
  const planWorker = require('../../workers/planGenerationWorker');
  return planWorker.processJob({ data: { attemptId: String(attemptId) } });
}

module.exports = { computeGrowth, persistGrowth, rebalancePlan, NEW_GAP_DROP_THRESHOLD };
```

- [ ] **Step 4: Wire into finishAttempt for recalibration**

In `src/services/diagnosticService.js`, after the existing `finishAttempt` body, add a branch for recalibration:

```js
const recalibrationResultsService = require('./diagnostic/recalibrationResultsService');

// inside finishAttempt, after results are computed and persisted:
if (attempt.attemptType === 'recalibration') {
  await recalibrationResultsService.persistGrowth(attempt._id);
  // Plan rebalance runs in background via the same plan worker enqueue path
}
```

The existing plan-worker enqueue (Task 5 step 6) will handle plan re-generation since the recalibration attempt has its own `planGenerationStatus`.

- [ ] **Step 5: Add `recalibrationGrowth` field to DiagnosticAttempt**

In `src/models/DiagnosticAttempt.js`, add:

```js
recalibrationGrowth: {
  growthBars: [{
    canonicalName: String,
    oldScore: Number,
    newScore: Number,
    delta: Number,
    oldBand: String,
    newBand: String,
    bandShift: String,
  }],
  biggestJump: {
    canonicalName: String,
    delta: Number,
    bandShift: String,
  },
  newGaps: [String],
  summary: String,
},
attemptType: {
  type: String,
  enum: ['initial', 'recalibration'],
  default: 'initial',
},
previousAttemptId: { type: mongoose.Schema.Types.ObjectId, ref: 'DiagnosticAttempt', default: null },
planId: { type: mongoose.Schema.Types.ObjectId, ref: 'Plan', default: null },
```

(If Plan 3 already added `attemptType` / `previousAttemptId` / `planId`, leave those untouched and only add `recalibrationGrowth`.)

- [ ] **Step 6: Add results endpoint extension**

The existing `GET /diagnostic/attempts/:id/results` already returns insights + results. Extend the controller to include `recalibrationGrowth` if present:

In `src/controllers/diagnosticController.js`:

```js
// inside getAttemptResults:
if (attempt.attemptType === 'recalibration') {
  responseBody.recalibrationGrowth = attempt.recalibrationGrowth || null;
  responseBody.previousAttemptId = attempt.previousAttemptId;
}
```

- [ ] **Step 7: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="computeGrowth\|rebalancePlan"
```

Expected: 3 tests pass.

- [ ] **Step 8: Commit**

```bash
git add src/services/diagnostic/recalibrationResultsService.js src/services/diagnostic/recalibrationResultsService.test.js src/services/diagnosticService.js src/models/DiagnosticAttempt.js src/controllers/diagnosticController.js
git commit -m "feat(diagnostic-be): re-calibration growth computation + plan auto-rebalance"
```

---

## Task 11: Re-calibration offer cron worker

Daily cron at 04:00 IST identifies users completed initial diagnostic >=30 days ago without recalibration in last 30 days, marks them eligible (eligibility is computed on-demand by the service; the cron's job is to send the in-app notification card on Progress tab).

**Files:**
- Create: `src/workers/recalibrationOfferWorker.js`
- Test: `src/workers/recalibrationOfferWorker.test.js`
- Modify: `src/workers/cronJobs.js`

- [ ] **Step 1: Write the failing test**

Create `src/workers/recalibrationOfferWorker.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const attemptPath = require.resolve('../models/DiagnosticAttempt');
const notifPath = require.resolve('../services/notificationService');

let aggregateRows = [];
require.cache[attemptPath] = {
  exports: {
    aggregate: async () => aggregateRows,
  },
};

const calls = [];
require.cache[notifPath] = {
  exports: {
    createInApp: async (userId, payload) => { calls.push({ userId: String(userId), payload }); return { _id: new mongoose.Types.ObjectId() }; },
  },
};

delete require.cache[require.resolve('./recalibrationOfferWorker')];
const worker = require('./recalibrationOfferWorker');

test('recalibrationOfferWorker.run: notifies eligible users with in-app card', async () => {
  calls.length = 0;
  const u1 = new mongoose.Types.ObjectId();
  const u2 = new mongoose.Types.ObjectId();
  aggregateRows = [{ _id: u1 }, { _id: u2 }];
  const out = await worker.run();
  assert.strictEqual(out.notified, 2);
  assert.strictEqual(calls.length, 2);
  assert.strictEqual(calls[0].payload.type, 'recalibration_offer');
  assert.ok(calls[0].payload.title.toLowerCase().includes('re-calibrate'));
});

test('recalibrationOfferWorker.run: no-ops when no eligible users', async () => {
  calls.length = 0;
  aggregateRows = [];
  const out = await worker.run();
  assert.strictEqual(out.notified, 0);
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="recalibrationOfferWorker"
```

- [ ] **Step 3: Implement the worker**

Create `src/workers/recalibrationOfferWorker.js`:

```js
const DiagnosticAttempt = require('../models/DiagnosticAttempt');
const notificationService = require('../services/notificationService');

const RECALIBRATION_MIN_DAYS = 30;

/**
 * Daily cron — find users whose latest completed diagnostic is >=30 days old
 * AND who have not had a recalibration in the last 30 days. For each, drop an
 * in-app `recalibration_offer` notification (no push — card surfaces on Progress).
 */
async function run() {
  const cutoff = new Date(Date.now() - RECALIBRATION_MIN_DAYS * 24 * 3600 * 1000);
  const recentRecalCutoff = new Date(Date.now() - RECALIBRATION_MIN_DAYS * 24 * 3600 * 1000);

  // Aggregate: latest completed attempt per user is older than cutoff AND no recalibration since recentRecalCutoff
  const eligibleUsers = await DiagnosticAttempt.aggregate([
    { $match: { status: 'completed' } },
    { $sort: { completedAt: -1 } },
    { $group: {
        _id: '$userId',
        latestCompletedAt: { $first: '$completedAt' },
        latestAttemptType: { $first: '$attemptType' },
        attemptTypes: { $push: '$attemptType' },
        completedDates: { $push: '$completedAt' },
    }},
    { $match: { latestCompletedAt: { $lt: cutoff } } },
    // Filter to those who have NOT had a recalibration in the last 30 days
    { $addFields: {
        recentRecalibration: {
          $anyElementTrue: {
            $map: {
              input: { $range: [0, { $size: '$attemptTypes' }] },
              as: 'idx',
              in: {
                $and: [
                  { $eq: [{ $arrayElemAt: ['$attemptTypes', '$$idx'] }, 'recalibration'] },
                  { $gte: [{ $arrayElemAt: ['$completedDates', '$$idx'] }, recentRecalCutoff] },
                ],
              },
            },
          },
        },
    }},
    { $match: { recentRecalibration: { $ne: true } } },
    { $project: { _id: 1 } },
  ]);

  let notified = 0;
  for (const row of eligibleUsers) {
    try {
      await notificationService.createInApp(row._id, {
        type: 'recalibration_offer',
        title: 'Time to re-calibrate',
        message: 'See how much you have grown — 4-5 minute quick check-in.',
        deepLink: 'scaleup://progress?card=recalibration',
      });
      notified++;
    } catch (err) {
      console.error('[recalibrationOfferWorker] notify failed:', err.message);
    }
  }

  console.log(`[recalibrationOfferWorker] notified ${notified} users`);
  return { notified };
}

module.exports = { run, RECALIBRATION_MIN_DAYS };
```

- [ ] **Step 4: Register cron in `src/workers/cronJobs.js`**

Add to the `startCronJobs` function:

```js
// 10. Re-calibration offer — Daily 4:00 AM IST (22:30 UTC prev day)
cronQueue.add('recalibrationOffer', {}, {
  repeat: { pattern: '30 22 * * *' },
  removeOnComplete: true,
});
```

And in the cron worker handler block (the `new Worker('cronJobs', ...)` near the bottom), add a case:

```js
case 'recalibrationOffer':
  await require('./recalibrationOfferWorker').run();
  break;
```

- [ ] **Step 5: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="recalibrationOfferWorker"
```

Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/workers/recalibrationOfferWorker.js src/workers/recalibrationOfferWorker.test.js src/workers/cronJobs.js
git commit -m "feat(diagnostic-be): daily re-calibration offer cron worker"
```

---

## Task 12: Admin auth middleware

The existing `User.role` enum includes `'admin'`. Wrap the existing `auth` + `rbac('admin')` chain into a single `adminAuth` middleware for cleaner mounting.

**Files:**
- Create: `src/middleware/adminAuth.js`
- Test: `src/middleware/adminAuth.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/middleware/adminAuth.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');

const authPath = require.resolve('./auth');
const rbacPath = require.resolve('./rbac');

let authBehavior = (req, res, next) => { req.user = { userId: 'u1', role: 'consumer' }; next(); };
require.cache[authPath] = {
  exports: Object.assign(function (req, res, next) { return authBehavior(req, res, next); }, { clearCache: () => {} }),
};

require.cache[rbacPath] = {
  exports: (...roles) => (req, res, next) => {
    if (!roles.includes(req.user.role)) return next({ statusCode: 403, message: 'Insufficient permissions' });
    next();
  },
};

delete require.cache[require.resolve('./adminAuth')];
const adminAuth = require('./adminAuth');

test('adminAuth: 403 for non-admin user', async () => {
  authBehavior = (req, res, next) => { req.user = { userId: 'u1', role: 'consumer' }; next(); };
  let captured = null;
  const req = {}, res = {};
  const runChain = (chain) => new Promise((resolve) => {
    let i = 0;
    const next = (err) => { if (err) { captured = err; return resolve(); } i++; if (i >= chain.length) return resolve(); chain[i](req, res, next); };
    chain[0](req, res, next);
  });
  await runChain(adminAuth);
  assert.ok(captured, 'should have called next(err)');
  assert.strictEqual(captured.statusCode, 403);
});

test('adminAuth: passes for admin user', async () => {
  authBehavior = (req, res, next) => { req.user = { userId: 'u1', role: 'admin' }; next(); };
  let reachedEnd = false;
  const req = {}, res = {};
  const runChain = (chain) => new Promise((resolve) => {
    let i = 0;
    const next = (err) => { if (err) return resolve(err); i++; if (i >= chain.length) { reachedEnd = true; return resolve(); } chain[i](req, res, next); };
    chain[0](req, res, next);
  });
  const err = await runChain(adminAuth);
  assert.ok(reachedEnd && !err, 'should reach end of chain');
});
```

- [ ] **Step 2: Run test — confirm fail**

```bash
npm test -- --test-name-pattern="adminAuth"
```

- [ ] **Step 3: Implement the middleware**

Create `src/middleware/adminAuth.js`:

```js
const auth = require('./auth');
const rbac = require('./rbac');

/**
 * Admin auth chain: validates JWT, checks user is active, then enforces role === 'admin'.
 * Use as: router.use(adminAuth)
 *
 * Initially only Nirpeksh has role: 'admin' (see User model migration in docs/runbook).
 */
module.exports = [auth, rbac('admin')];
```

- [ ] **Step 4: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="adminAuth"
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/middleware/adminAuth.js src/middleware/adminAuth.test.js
git commit -m "feat(diagnostic-be): adminAuth middleware (auth + rbac admin)"
```

---

## Task 13: Admin question review endpoints

Per spec §12.6:
- `GET /admin/diagnostic-questions/queue`
- `POST /admin/diagnostic-questions/:id/approve`
- `POST /admin/diagnostic-questions/:id/edit`
- `POST /admin/diagnostic-questions/:id/reject`
- `GET /admin/diagnostic-questions/stats`

**Files:**
- Create: `src/controllers/diagnosticAdminController.js`
- Test: `src/controllers/diagnosticAdminController.test.js`
- Create: `src/routes/diagnosticAdmin.js`
- Create: `src/models/AdminQuestionDecision.js`
- Test: `src/models/AdminQuestionDecision.test.js`
- Modify: `src/app.js`

- [ ] **Step 1: AdminQuestionDecision model test**

Create `src/models/AdminQuestionDecision.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

delete require.cache[require.resolve('./AdminQuestionDecision')];
const AQD = require('./AdminQuestionDecision');

test('AdminQuestionDecision: validates with required fields', () => {
  const doc = new AQD({
    questionId: new mongoose.Types.ObjectId(),
    adminUserId: new mongoose.Types.ObjectId(),
    decision: 'approve',
    validatorScoreAtDecision: 65,
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
});

test('AdminQuestionDecision: invalid decision rejected', () => {
  const doc = new AQD({
    questionId: new mongoose.Types.ObjectId(),
    adminUserId: new mongoose.Types.ObjectId(),
    decision: 'maybe',
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.decision);
});
```

- [ ] **Step 2: Implement model**

Create `src/models/AdminQuestionDecision.js`:

```js
const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  questionId: { type: mongoose.Schema.Types.ObjectId, ref: 'DiagnosticQuestionBank', required: true, index: true },
  adminUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  decision: { type: String, enum: ['approve', 'edit', 'reject'], required: true },
  reason: { type: String, default: '' },
  editDiff: { type: Object, default: null }, // { before, after } when decision = edit
  validatorScoreAtDecision: { type: Number, default: null },
  validatorCritiqueAtDecision: { type: String, default: '' },
}, { timestamps: true });

schema.index({ adminUserId: 1, createdAt: -1 });

module.exports = mongoose.model('AdminQuestionDecision', schema);
```

- [ ] **Step 3: Controller test**

Create `src/controllers/diagnosticAdminController.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const qbPath = require.resolve('../models/DiagnosticQuestionBank');
const aqdPath = require.resolve('../models/AdminQuestionDecision');

let bank = [];
let lastUpdate = null;
require.cache[qbPath] = {
  exports: {
    find: (filter) => ({
      sort: () => ({ skip: () => ({ limit: () => ({ lean: async () => bank.filter(q => q.verificationStatus === filter.verificationStatus) }) }) }),
    }),
    countDocuments: async (filter) => bank.filter(q => Object.entries(filter || {}).every(([k, v]) => q[k] === v)).length,
    findById: (id) => ({ lean: async () => bank.find(q => String(q._id) === String(id)) }),
    updateOne: async (filter, update) => { lastUpdate = { filter, update }; return { modifiedCount: 1 }; },
    deleteOne: async (filter) => { bank = bank.filter(q => String(q._id) !== String(filter._id)); return { deletedCount: 1 }; },
    aggregate: async () => ([{ _id: 'auto_verified', count: 10 }, { _id: 'flagged_for_review', count: 3 }]),
  },
};
require.cache[aqdPath] = {
  exports: { create: async (d) => ({ ...d, _id: new mongoose.Types.ObjectId() }) },
};

delete require.cache[require.resolve('./diagnosticAdminController')];
const ctrl = require('./diagnosticAdminController');

const fakeRes = () => ({ _status: 200, _json: null, status(s){ this._status = s; return this; }, json(j){ this._json = j; return this; } });

test('getQueue: returns paginated flagged questions', async () => {
  const qid = new mongoose.Types.ObjectId();
  bank = [{ _id: qid, verificationStatus: 'flagged_for_review', questionText: 'Q', validatorScore: 60, validatorCritique: 'c' }];
  const req = { user: { userId: 'admin1', role: 'admin' }, query: {} };
  const res = fakeRes();
  await ctrl.getQueue(req, res);
  assert.strictEqual(res._status, 200);
  assert.strictEqual(res._json.questions.length, 1);
  assert.ok(res._json.pagination);
});

test('approve: promotes to human_verified and logs decision', async () => {
  const qid = new mongoose.Types.ObjectId();
  bank = [{ _id: qid, verificationStatus: 'flagged_for_review', validatorScore: 55, validatorCritique: 'eh' }];
  const req = { params: { id: String(qid) }, user: { userId: 'admin1' }, body: {} };
  const res = fakeRes();
  await ctrl.approve(req, res);
  assert.strictEqual(res._status, 200);
  assert.strictEqual(lastUpdate.update.$set.verificationStatus, 'human_verified');
});

test('edit: applies edits and approves', async () => {
  const qid = new mongoose.Types.ObjectId();
  bank = [{ _id: qid, verificationStatus: 'flagged_for_review', questionText: 'Old', options: [], correctAnswer: 'A' }];
  const req = {
    params: { id: String(qid) }, user: { userId: 'admin1' },
    body: { questionText: 'New', options: [{ label: 'A', text: 'a' }], correctAnswer: 'A' },
  };
  const res = fakeRes();
  await ctrl.edit(req, res);
  assert.strictEqual(res._status, 200);
  assert.strictEqual(lastUpdate.update.$set.verificationStatus, 'human_verified');
  assert.strictEqual(lastUpdate.update.$set.questionText, 'New');
});

test('reject: deletes question and logs decision', async () => {
  const qid = new mongoose.Types.ObjectId();
  bank = [{ _id: qid, verificationStatus: 'flagged_for_review' }];
  const req = { params: { id: String(qid) }, user: { userId: 'admin1' }, body: { reason: 'Wrong answer' } };
  const res = fakeRes();
  await ctrl.reject(req, res);
  assert.strictEqual(res._status, 200);
  assert.strictEqual(bank.length, 0);
});

test('getStats: returns queue depth + verification distribution', async () => {
  const req = { user: { userId: 'admin1' } };
  const res = fakeRes();
  await ctrl.getStats(req, res);
  assert.strictEqual(res._status, 200);
  assert.ok(typeof res._json.queueDepth === 'number');
  assert.ok(res._json.verificationDistribution);
});
```

- [ ] **Step 4: Implement controller**

Create `src/controllers/diagnosticAdminController.js`:

```js
const QuestionBank = require('../models/DiagnosticQuestionBank');
const AdminDecision = require('../models/AdminQuestionDecision');
const adminTrainingSignalService = require('../services/diagnostic/adminTrainingSignalService');

async function getQueue(req, res) {
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const pageSize = Math.min(50, parseInt(req.query.pageSize, 10) || 20);
  const filter = { verificationStatus: 'flagged_for_review' };

  const questions = await QuestionBank
    .find(filter)
    .sort({ createdAt: -1 })
    .skip((page - 1) * pageSize)
    .limit(pageSize)
    .lean();

  const total = await QuestionBank.countDocuments(filter);

  res.status(200).json({
    questions: questions.map(q => ({
      _id: q._id,
      questionText: q.questionText,
      options: q.options,
      correctAnswer: q.correctAnswer,
      difficulty: q.difficulty,
      canonicalCompetency: q.canonicalCompetency,
      objectiveType: q.objectiveType,
      generationSource: q.generationSource,
      validatorScore: q.validatorScore,
      validatorCritique: q.validatorCritique,
      createdAt: q.createdAt,
    })),
    pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) },
  });
}

async function approve(req, res) {
  const { id } = req.params;
  const q = await QuestionBank.findById(id).lean();
  if (!q) return res.status(404).json({ message: 'Question not found' });

  await QuestionBank.updateOne({ _id: id }, {
    $set: {
      verificationStatus: 'human_verified',
      humanReviewedBy: req.user.userId,
      humanReviewedAt: new Date(),
      humanReviewNotes: req.body?.notes || '',
    },
  });

  const decision = await AdminDecision.create({
    questionId: id,
    adminUserId: req.user.userId,
    decision: 'approve',
    reason: req.body?.notes || '',
    validatorScoreAtDecision: q.validatorScore,
    validatorCritiqueAtDecision: q.validatorCritique,
  });
  await adminTrainingSignalService.recordDecision(decision);

  res.status(200).json({ success: true });
}

async function edit(req, res) {
  const { id } = req.params;
  const q = await QuestionBank.findById(id).lean();
  if (!q) return res.status(404).json({ message: 'Question not found' });

  const before = {
    questionText: q.questionText,
    options: q.options,
    correctAnswer: q.correctAnswer,
  };

  const update = {
    verificationStatus: 'human_verified',
    humanReviewedBy: req.user.userId,
    humanReviewedAt: new Date(),
    humanReviewNotes: req.body?.notes || '',
  };
  if (req.body.questionText) update.questionText = req.body.questionText;
  if (req.body.options) update.options = req.body.options;
  if (req.body.correctAnswer) update.correctAnswer = req.body.correctAnswer;
  if (req.body.difficulty) update.difficulty = req.body.difficulty;

  await QuestionBank.updateOne({ _id: id }, { $set: update });

  const after = {
    questionText: update.questionText || q.questionText,
    options: update.options || q.options,
    correctAnswer: update.correctAnswer || q.correctAnswer,
  };

  const decision = await AdminDecision.create({
    questionId: id,
    adminUserId: req.user.userId,
    decision: 'edit',
    reason: req.body?.notes || '',
    editDiff: { before, after },
    validatorScoreAtDecision: q.validatorScore,
    validatorCritiqueAtDecision: q.validatorCritique,
  });
  await adminTrainingSignalService.recordDecision(decision);

  res.status(200).json({ success: true });
}

async function reject(req, res) {
  const { id } = req.params;
  const q = await QuestionBank.findById(id).lean();
  if (!q) return res.status(404).json({ message: 'Question not found' });

  await QuestionBank.deleteOne({ _id: id });

  const decision = await AdminDecision.create({
    questionId: id,
    adminUserId: req.user.userId,
    decision: 'reject',
    reason: req.body?.reason || '',
    validatorScoreAtDecision: q.validatorScore,
    validatorCritiqueAtDecision: q.validatorCritique,
  });
  await adminTrainingSignalService.recordDecision(decision);

  // Optional: trigger regeneration for the empty (topic, difficulty) slot
  if (req.body?.regenerate === true) {
    try {
      const { quizGenerationQueue } = require('../config/queue');
      await quizGenerationQueue.add('regenerateDiagnostic', {
        canonicalCompetency: q.canonicalCompetency,
        difficulty: q.difficulty,
        objectiveType: q.objectiveType,
      });
    } catch (err) {
      console.warn('regenerate enqueue failed:', err.message);
    }
  }

  res.status(200).json({ success: true });
}

async function getStats(req, res) {
  const queueDepth = await QuestionBank.countDocuments({ verificationStatus: 'flagged_for_review' });
  const distribution = await QuestionBank.aggregate([
    { $group: { _id: '$verificationStatus', count: { $sum: 1 } } },
  ]);

  const recentDecisions = await AdminDecision.find({})
    .sort({ createdAt: -1 })
    .limit(20)
    .lean();

  const totalProcessed = recentDecisions.length;
  const approveCount = recentDecisions.filter(d => d.decision === 'approve' || d.decision === 'edit').length;
  const validatorPassRate = totalProcessed === 0 ? null : approveCount / totalProcessed;

  res.status(200).json({
    queueDepth,
    verificationDistribution: distribution.reduce((acc, x) => { acc[x._id] = x.count; return acc; }, {}),
    recentDecisions: recentDecisions.map(d => ({
      _id: d._id,
      questionId: d.questionId,
      decision: d.decision,
      adminUserId: d.adminUserId,
      createdAt: d.createdAt,
    })),
    validatorPassRate,
  });
}

module.exports = { getQueue, approve, edit, reject, getStats };
```

- [ ] **Step 5: Routes**

Create `src/routes/diagnosticAdmin.js`:

```js
const router = require('express').Router();
const ctrl = require('../controllers/diagnosticAdminController');
const adminAuth = require('../middleware/adminAuth');

router.use(adminAuth);

router.get('/queue', ctrl.getQueue);
router.post('/:id/approve', ctrl.approve);
router.post('/:id/edit', ctrl.edit);
router.post('/:id/reject', ctrl.reject);
router.get('/stats', ctrl.getStats);

module.exports = router;
```

- [ ] **Step 6: Mount in `src/app.js`**

```js
app.use('/admin/diagnostic-questions', require('./routes/diagnosticAdmin'));
```

- [ ] **Step 7: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="AdminQuestionDecision\|getQueue\|approve\|edit:\|reject:\|getStats"
```

Expected: 7 tests pass.

- [ ] **Step 8: Commit**

```bash
git add src/models/AdminQuestionDecision.js src/models/AdminQuestionDecision.test.js src/controllers/diagnosticAdminController.js src/controllers/diagnosticAdminController.test.js src/routes/diagnosticAdmin.js src/app.js
git commit -m "feat(diagnostic-be): admin question review endpoints + decision log"
```

---

## Task 14: Admin training signal service

Per spec §5.5 ("Training signal loop"): every approve/reject decision is logged. After 100+ decisions, export them as few-shot examples for the next iteration of the Tier 1 validator prompt.

**Files:**
- Create: `src/services/diagnostic/adminTrainingSignalService.js`
- Test: `src/services/diagnostic/adminTrainingSignalService.test.js`

- [ ] **Step 1: Test**

Create `src/services/diagnostic/adminTrainingSignalService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');
const fs = require('node:fs');
const path = require('node:path');

const aqdPath = require.resolve('../../models/AdminQuestionDecision');
const qbPath = require.resolve('../../models/DiagnosticQuestionBank');

let decisions = [];
require.cache[aqdPath] = {
  exports: {
    countDocuments: async () => decisions.length,
    find: () => ({ sort: () => ({ limit: () => ({ lean: async () => decisions.slice(0, 200) }) }) }),
  },
};
require.cache[qbPath] = {
  exports: {
    findById: (id) => ({ lean: async () => ({
      _id: id, questionText: `Q for ${id}`, options: [], correctAnswer: 'A',
      validatorScore: 60, validatorCritique: 'meh', difficulty: 'medium',
    })}),
  },
};

delete require.cache[require.resolve('./adminTrainingSignalService')];
const svc = require('./adminTrainingSignalService');

test('recordDecision: no export below threshold', async () => {
  decisions = Array.from({ length: 50 }, (_, i) => ({ _id: i, questionId: i, decision: 'approve' }));
  const result = await svc.recordDecision({ _id: 51, questionId: 51, decision: 'approve' });
  assert.strictEqual(result.exported, false);
});

test('exportFewShotExamples: writes JSON file with approve + reject samples', async () => {
  decisions = Array.from({ length: 105 }, (_, i) => ({
    _id: i, questionId: i, decision: i % 2 === 0 ? 'approve' : 'reject',
    reason: 'sample', editDiff: null,
    validatorScoreAtDecision: 60, validatorCritiqueAtDecision: 'c',
    createdAt: new Date(),
  }));
  const tmpDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'fewshot-'));
  const out = await svc.exportFewShotExamples({ outDir: tmpDir });
  assert.ok(out.filePath.endsWith('.json'));
  const data = JSON.parse(fs.readFileSync(out.filePath, 'utf8'));
  assert.ok(Array.isArray(data.approveExamples));
  assert.ok(Array.isArray(data.rejectExamples));
  assert.ok(data.approveExamples.length > 0);
  assert.ok(data.rejectExamples.length > 0);
});
```

- [ ] **Step 2: Implement**

Create `src/services/diagnostic/adminTrainingSignalService.js`:

```js
const fs = require('node:fs');
const path = require('node:path');
const AdminDecision = require('../../models/AdminQuestionDecision');
const QuestionBank = require('../../models/DiagnosticQuestionBank');

const EXPORT_THRESHOLD = 100;

/**
 * Called after each admin decision (approve/edit/reject).
 * Returns { exported: true } when threshold crossed (caller may then call exportFewShotExamples).
 *
 * Note: per spec we do NOT auto-rewrite the Tier 1 validator prompt — admin reviews
 * the export and decides whether to fold examples in.
 */
async function recordDecision(decision) {
  const total = await AdminDecision.countDocuments({});
  if (total >= EXPORT_THRESHOLD && total % EXPORT_THRESHOLD === 0) {
    return { exported: true, total };
  }
  return { exported: false, total };
}

async function exportFewShotExamples(opts = {}) {
  const outDir = opts.outDir || path.join(__dirname, '../../../docs/training-signals');
  fs.mkdirSync(outDir, { recursive: true });

  const recent = await AdminDecision.find({})
    .sort({ createdAt: -1 })
    .limit(200)
    .lean();

  const approveExamples = [];
  const rejectExamples = [];

  for (const d of recent) {
    const q = await QuestionBank.findById(d.questionId).lean();
    if (!q) continue;
    const example = {
      questionText: q.questionText,
      options: q.options,
      correctAnswer: q.correctAnswer,
      difficulty: q.difficulty,
      validatorScore: d.validatorScoreAtDecision,
      validatorCritique: d.validatorCritiqueAtDecision,
      adminReason: d.reason,
    };
    if (d.decision === 'approve' || d.decision === 'edit') approveExamples.push(example);
    else if (d.decision === 'reject') rejectExamples.push(example);
  }

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filePath = path.join(outDir, `validator-fewshot-${stamp}.json`);
  fs.writeFileSync(filePath, JSON.stringify({
    generatedAt: new Date().toISOString(),
    sampleSize: recent.length,
    approveExamples: approveExamples.slice(0, 20),
    rejectExamples: rejectExamples.slice(0, 20),
    notes: 'Admin reviews + folds into next iteration of questionValidatorService.js prompt.',
  }, null, 2));

  return { filePath, approveCount: approveExamples.length, rejectCount: rejectExamples.length };
}

module.exports = { recordDecision, exportFewShotExamples, EXPORT_THRESHOLD };
```

- [ ] **Step 3: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="recordDecision\|exportFewShot"
```

Expected: 2 tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/services/diagnostic/adminTrainingSignalService.js src/services/diagnostic/adminTrainingSignalService.test.js
git commit -m "feat(diagnostic-be): admin training signal service for validator improvement"
```

---

## Task 15: Admin dashboard frontend (BE-served HTML+vanilla JS)

Per spec Open Q5 default: simplest is BE-served HTML+vanilla JS (no new build pipeline).

**Files:**
- Create: `src/admin/dashboard.html`
- Create: `src/admin/dashboard.css`
- Create: `src/admin/dashboard.js`
- Modify: `src/app.js`

- [ ] **Step 1: HTML shell**

Create `src/admin/dashboard.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>ScaleUp — Diagnostic Question Review</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="stylesheet" href="/admin/dashboard.css" />
</head>
<body>
  <header class="topbar">
    <h1>Diagnostic Question Review</h1>
    <div id="stats" class="stats">Loading…</div>
    <div class="auth">
      <input id="token" type="password" placeholder="Paste admin JWT token" />
      <button id="loadBtn">Load queue</button>
    </div>
  </header>

  <main id="queue">
    <p class="hint">Paste your admin JWT and click "Load queue".</p>
  </main>

  <template id="card-template">
    <article class="card">
      <header>
        <span class="topic"></span>
        <span class="difficulty"></span>
        <span class="score"></span>
      </header>
      <p class="question"></p>
      <ul class="options"></ul>
      <p class="correct"><strong>Correct:</strong> <span></span></p>
      <p class="critique"></p>
      <div class="actions">
        <button data-action="approve" class="btn approve">Approve</button>
        <button data-action="edit" class="btn edit">Edit</button>
        <button data-action="reject" class="btn reject">Reject</button>
      </div>
    </article>
  </template>

  <script src="/admin/dashboard.js"></script>
</body>
</html>
```

- [ ] **Step 2: CSS**

Create `src/admin/dashboard.css`:

```css
* { box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; background: #0B1E28; color: #f5f5f5; }
.topbar { padding: 16px 24px; background: #122D3A; display: flex; gap: 16px; align-items: center; flex-wrap: wrap; }
.topbar h1 { margin: 0; font-size: 20px; color: #E8B84B; }
.stats { font-size: 14px; opacity: 0.8; }
.auth input { padding: 6px 8px; border-radius: 6px; border: 1px solid #444; background: #0B1E28; color: #fff; min-width: 280px; }
.auth button, .actions .btn { padding: 6px 12px; border-radius: 6px; border: none; cursor: pointer; font-weight: 600; }
.auth button { background: #E8B84B; color: #122D3A; }
main { padding: 24px; max-width: 900px; margin: 0 auto; }
.card { background: #122D3A; border: 1px solid #1A3B4D; border-radius: 12px; padding: 16px; margin-bottom: 16px; }
.card header { display: flex; gap: 12px; font-size: 13px; opacity: 0.85; margin-bottom: 8px; }
.card .topic { color: #E8B84B; font-weight: 600; }
.card .question { font-size: 16px; margin: 8px 0; }
.card .options { list-style: none; padding: 0; margin: 0 0 8px; }
.card .options li { padding: 4px 0; }
.card .critique { font-size: 13px; color: #f5d980; margin: 8px 0 0; font-style: italic; }
.actions { display: flex; gap: 8px; margin-top: 12px; }
.actions .approve { background: #2ecc71; color: #0B1E28; }
.actions .edit { background: #f5d980; color: #0B1E28; }
.actions .reject { background: #e74c3c; color: #fff; }
.hint { opacity: 0.6; }
```

- [ ] **Step 3: Vanilla JS**

Create `src/admin/dashboard.js`:

```js
(function () {
  const queueEl = document.getElementById('queue');
  const statsEl = document.getElementById('stats');
  const tokenEl = document.getElementById('token');
  const loadBtn = document.getElementById('loadBtn');
  const tpl = document.getElementById('card-template');

  function authHeader() {
    return { Authorization: 'Bearer ' + tokenEl.value.trim() };
  }

  async function loadStats() {
    const r = await fetch('/admin/diagnostic-questions/stats', { headers: authHeader() });
    if (!r.ok) { statsEl.textContent = `Stats failed (${r.status})`; return; }
    const s = await r.json();
    statsEl.textContent = `Queue: ${s.queueDepth} • Pass rate: ${s.validatorPassRate ? Math.round(s.validatorPassRate * 100) + '%' : '—'}`;
  }

  async function loadQueue() {
    queueEl.innerHTML = '<p class="hint">Loading…</p>';
    const r = await fetch('/admin/diagnostic-questions/queue?page=1&pageSize=20', { headers: authHeader() });
    if (!r.ok) { queueEl.innerHTML = `<p class="hint">Failed (${r.status}).</p>`; return; }
    const { questions } = await r.json();
    queueEl.innerHTML = '';
    if (questions.length === 0) {
      queueEl.innerHTML = '<p class="hint">Queue empty.</p>';
      return;
    }
    questions.forEach(renderCard);
  }

  function renderCard(q) {
    const node = tpl.content.cloneNode(true);
    node.querySelector('.topic').textContent = q.canonicalCompetency || '—';
    node.querySelector('.difficulty').textContent = q.difficulty || '';
    node.querySelector('.score').textContent = q.validatorScore != null ? `Score: ${q.validatorScore}` : '';
    node.querySelector('.question').textContent = q.questionText;
    const ul = node.querySelector('.options');
    (q.options || []).forEach(o => {
      const li = document.createElement('li');
      li.textContent = `${o.label}. ${o.text}`;
      ul.appendChild(li);
    });
    node.querySelector('.correct span').textContent = q.correctAnswer;
    node.querySelector('.critique').textContent = q.validatorCritique || '';

    node.querySelectorAll('.btn').forEach(btn => {
      btn.addEventListener('click', () => handleAction(q._id, btn.dataset.action, btn));
    });

    queueEl.appendChild(node);
  }

  async function handleAction(id, action, btn) {
    btn.disabled = true;
    let body = {};
    if (action === 'reject') {
      const reason = prompt('Reason for reject:') || '';
      body = { reason };
    } else if (action === 'edit') {
      const newText = prompt('New question text (leave blank to skip):') || '';
      const newCorrect = prompt('New correct answer letter (leave blank to skip):') || '';
      if (newText) body.questionText = newText;
      if (newCorrect) body.correctAnswer = newCorrect;
    }
    const r = await fetch(`/admin/diagnostic-questions/${id}/${action}`, {
      method: 'POST',
      headers: { ...authHeader(), 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (r.ok) {
      btn.closest('.card').remove();
      loadStats();
    } else {
      alert(`Action failed (${r.status})`);
      btn.disabled = false;
    }
  }

  loadBtn.addEventListener('click', () => { loadStats(); loadQueue(); });
})();
```

- [ ] **Step 4: Mount static files in `src/app.js`**

Add near the top of route mounts:

```js
const path = require('path');
app.use('/admin/dashboard', express.static(path.join(__dirname, 'admin')));
```

The dashboard is then accessible at `https://api.scaleup.app/admin/dashboard/dashboard.html`. Admin pastes a JWT obtained from any normal login (their User has `role: 'admin'`).

- [ ] **Step 5: Smoke check**

```bash
node --check src/admin/dashboard.js
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add src/admin/dashboard.html src/admin/dashboard.css src/admin/dashboard.js src/app.js
git commit -m "feat(diagnostic-be): admin question review dashboard (HTML+vanilla JS)"
```

---

## Task 16: Weekly admin digest email cron

**Files:**
- Modify: `src/services/emailService.js`
- Create: `src/workers/adminDigestWorker.js`
- Test: `src/workers/adminDigestWorker.test.js`
- Modify: `src/workers/cronJobs.js`

- [ ] **Step 1: Add `sendAdminQuestionDigest` to emailService**

In `src/services/emailService.js`, add a new method:

```js
async sendAdminQuestionDigest(adminEmail, { queueDepth, estMinutes, dashboardUrl }) {
  await this.transporter.sendMail({
    from: this.from,
    to: adminEmail,
    subject: `ScaleUp — ${queueDepth} diagnostic questions need your review (~${estMinutes} min)`,
    html: `
      <h2>Weekly question review</h2>
      <p><strong>${queueDepth}</strong> questions are flagged for review. Estimated time: <strong>~${estMinutes} minutes</strong>.</p>
      <p><a href="${dashboardUrl}" style="background:#E8B84B;color:#122D3A;padding:10px 16px;border-radius:6px;text-decoration:none;font-weight:600;">Open dashboard</a></p>
      <p style="opacity:0.7;font-size:12px;margin-top:24px;">Each approve/reject decision trains the Tier 1 validator. Thanks for keeping the bar high.</p>
    `,
  });
}
```

- [ ] **Step 2: Worker test**

Create `src/workers/adminDigestWorker.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const userPath = require.resolve('../models/User');
const qbPath = require.resolve('../models/DiagnosticQuestionBank');
const emailPath = require.resolve('../services/emailService');

let admins = [];
let queueCount = 0;
let sent = [];

require.cache[userPath] = {
  exports: { find: () => ({ select: () => ({ lean: async () => admins }) }) },
};
require.cache[qbPath] = {
  exports: { countDocuments: async () => queueCount },
};
require.cache[emailPath] = {
  exports: { sendAdminQuestionDigest: async (email, payload) => { sent.push({ email, payload }); } },
};

delete require.cache[require.resolve('./adminDigestWorker')];
const worker = require('./adminDigestWorker');

test('adminDigestWorker.run: sends digest to each admin', async () => {
  sent = [];
  admins = [{ _id: new mongoose.Types.ObjectId(), email: 'admin1@example.com' }];
  queueCount = 7;
  const out = await worker.run();
  assert.strictEqual(out.sent, 1);
  assert.strictEqual(sent[0].email, 'admin1@example.com');
  assert.strictEqual(sent[0].payload.queueDepth, 7);
  assert.ok(sent[0].payload.estMinutes >= 1);
});

test('adminDigestWorker.run: skips when queue empty (no nag emails)', async () => {
  sent = [];
  admins = [{ _id: new mongoose.Types.ObjectId(), email: 'admin1@example.com' }];
  queueCount = 0;
  const out = await worker.run();
  assert.strictEqual(out.sent, 0);
  assert.strictEqual(out.skipped, 'queue_empty');
});
```

- [ ] **Step 3: Implement worker**

Create `src/workers/adminDigestWorker.js`:

```js
const User = require('../models/User');
const QuestionBank = require('../models/DiagnosticQuestionBank');
const emailService = require('../services/emailService');

const SECONDS_PER_QUESTION_ESTIMATE = 90;
const DASHBOARD_URL = process.env.ADMIN_DASHBOARD_URL || 'https://api.scaleup.app/admin/dashboard/dashboard.html';

async function run() {
  const queueDepth = await QuestionBank.countDocuments({ verificationStatus: 'flagged_for_review' });
  if (queueDepth === 0) {
    console.log('[adminDigestWorker] queue empty — skipping digest');
    return { sent: 0, skipped: 'queue_empty' };
  }
  const estMinutes = Math.max(1, Math.round((queueDepth * SECONDS_PER_QUESTION_ESTIMATE) / 60));

  const admins = await User.find({ role: 'admin' }).select('_id email').lean();
  let sent = 0;
  for (const a of admins) {
    if (!a.email) continue;
    try {
      await emailService.sendAdminQuestionDigest(a.email, {
        queueDepth,
        estMinutes,
        dashboardUrl: DASHBOARD_URL,
      });
      sent++;
    } catch (err) {
      console.error(`[adminDigestWorker] email failed for ${a.email}:`, err.message);
    }
  }
  return { sent, queueDepth, estMinutes };
}

module.exports = { run };
```

- [ ] **Step 4: Register cron in `src/workers/cronJobs.js`**

```js
// 11. Admin question digest — Monday 09:00 IST (03:30 UTC)
cronQueue.add('adminQuestionDigest', {}, {
  repeat: { pattern: '30 3 * * 1' },
  removeOnComplete: true,
});
```

In the cron worker case block:

```js
case 'adminQuestionDigest':
  await require('./adminDigestWorker').run();
  break;
```

- [ ] **Step 5: Run tests — confirm pass**

```bash
npm test -- --test-name-pattern="adminDigestWorker"
```

Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/services/emailService.js src/workers/adminDigestWorker.js src/workers/adminDigestWorker.test.js src/workers/cronJobs.js
git commit -m "feat(diagnostic-be): weekly admin question digest email cron"
```

---

## Task 17: iOS — PlanService API client + PlanTabViewModel

**Files:**
- Create: `ScaleUp/Features/Plan/Services/PlanService.swift`
- Create: `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift`

- [ ] **Step 1: PlanService**

Create `ScaleUp/Features/Plan/Services/PlanService.swift`:

```swift
import Foundation

struct PlanStatusDTO: Codable {
    let status: String  // pending | generating | ready | failed
    let planId: String?
    let source: String?
    let updatedAt: Date?
}

struct WeeklyAllocation: Codable, Identifiable {
    var id: String { topicCanonicalName }
    let topicCanonicalName: String
    let hours: Double
    let focusActivity: String
}

struct WeeklyEntry: Codable, Identifiable {
    var id: Int { week }
    let week: Int
    let weeklyGoal: String
    let allocations: [WeeklyAllocation]
}

struct PlanMilestone: Codable, Identifiable {
    var id: String { "\(week)-\(title)" }
    let week: Int
    let title: String
    let measurableCriteria: String
    let isUserStated: Bool
}

struct PlanDTO: Codable {
    let planId: String
    let planHeadline: String
    let estimatedTotalHours: Double
    let bufferRecommendation: String
    let weeklySchedule: [WeeklyEntry]
    let milestones: [PlanMilestone]
    let source: String
    let updatedAt: Date?
}

@MainActor
final class PlanService {
    static let shared = PlanService()
    private init() {}

    func fetchStatus() async throws -> PlanStatusDTO {
        try await APIClient.shared.get("/plan/status")
    }

    func fetchCurrent() async throws -> PlanDTO {
        try await APIClient.shared.get("/plan/current")
    }
}
```

- [ ] **Step 2: PlanTabViewModel**

Create `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
@Observable
final class PlanTabViewModel {
    enum LoadState: Equatable { case idle, loading, ready(PlanDTO), generating, error(String) }

    var state: LoadState = .idle

    func load() async {
        state = .loading
        do {
            let status = try await PlanService.shared.fetchStatus()
            switch status.status {
            case "ready":
                let plan = try await PlanService.shared.fetchCurrent()
                state = .ready(plan)
            case "generating", "pending":
                state = .generating
            case "failed":
                state = .error("Plan generation failed. Tap to retry.")
            default:
                state = .generating
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Plan/Services/PlanService.swift ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift
git commit -m "feat(diagnostic-ios): plan service + view model"
```

---

## Task 18: iOS — Home tab "plan brewing" pill + polling

**Files:**
- Create: `ScaleUp/Features/Home/Views/PlanBrewingPill.swift`
- Create: `ScaleUp/Features/Home/ViewModels/PlanBrewingViewModel.swift`
- Modify: `ScaleUp/Features/Home/Views/HomeView.swift`

- [ ] **Step 1: ViewModel (polls /plan/status every 5s while generating)**

Create `ScaleUp/Features/Home/ViewModels/PlanBrewingViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
@Observable
final class PlanBrewingViewModel {
    enum Visibility: Equatable { case hidden, brewing, ready }

    var visibility: Visibility = .hidden
    private var pollTask: Task<Void, Never>?

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.tick()
                if case .ready = self.visibility { return }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func tick() async {
        do {
            let status = try await PlanService.shared.fetchStatus()
            switch status.status {
            case "generating", "pending":
                if visibility == .hidden {
                    visibility = .brewing
                    AnalyticsService.shared.track(.planBrewingSeen)
                }
            case "ready":
                visibility = .ready
            default:
                visibility = .hidden
            }
        } catch {
            // Quiet failure — just retry next tick
        }
    }
}
```

- [ ] **Step 2: Pill view**

Create `ScaleUp/Features/Home/Views/PlanBrewingPill.swift`:

```swift
import SwiftUI

struct PlanBrewingPill: View {
    let onTap: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.s) {
                Circle()
                    .fill(ColorTokens.gold)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                Text("Your plan is brewing — usually ~45s")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundColor(ColorTokens.goldLight)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(
                Capsule().fill(ColorTokens.surface)
                    .overlay(Capsule().stroke(ColorTokens.gold.opacity(0.4), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
        .accessibilityLabel("Your plan is brewing")
    }
}
```

- [ ] **Step 3: Modify HomeView**

In `ScaleUp/Features/Home/Views/HomeView.swift`, add at the top of the main scroll content (before the existing first card):

```swift
@State private var brewingVM = PlanBrewingViewModel()

// inside body, near the top of the VStack:
if brewingVM.visibility == .brewing {
    PlanBrewingPill {
        // Show toast or no-op
        ToastCenter.shared.show("Your plan is being prepared — usually ~45s")
    }
    .transition(.opacity.combined(with: .move(edge: .top)))
}

// inside .task or .onAppear:
.task {
    brewingVM.start()
}
.onDisappear { brewingVM.stop() }
```

If `ToastCenter` doesn't exist, replace with a simple `print` or hookup to the existing snackbar pattern.

- [ ] **Step 4: Add Mixpanel events**

In `ScaleUp/Core/Analytics/AnalyticsEvent.swift`, add:

```swift
extension AnalyticsEvent {
    static let planBrewingSeen = AnalyticsEvent(name: "plan_brewing_seen", properties: [:])
    static func planReadyNotificationTapped(planId: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "plan_ready_notification_tapped", properties: ["planId": planId])
    }
    static let planGenerationCompleted = AnalyticsEvent(name: "plan_generation_completed", properties: [:])
    static let recalibrationOffered = AnalyticsEvent(name: "recalibration_offered", properties: [:])
    static let recalibrationStarted = AnalyticsEvent(name: "recalibration_started", properties: [:])
    static func recalibrationCompleted(topicsRetested: Int, biggestGrowth: Double) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "recalibration_completed",
            properties: ["topicsRetested": topicsRetested, "biggestGrowth": biggestGrowth]
        )
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add ScaleUp/Features/Home/Views/PlanBrewingPill.swift ScaleUp/Features/Home/ViewModels/PlanBrewingViewModel.swift ScaleUp/Features/Home/Views/HomeView.swift ScaleUp/Core/Analytics/AnalyticsEvent.swift
git commit -m "feat(diagnostic-ios): home plan-brewing pill + analytics events"
```

---

## Task 19: iOS — Push notification handler for plan_ready

**File:** `ScaleUp/Features/Notifications/PushNotificationRouter.swift` (MODIFY or CREATE if absent)

- [ ] **Step 1: Locate existing push handler**

```bash
grep -rn "didReceive\|userNotificationCenter\|plan_ready" "/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/" | head
```

- [ ] **Step 2: Add `plan_ready` case**

In the existing `userNotificationCenter(_:didReceive:withCompletionHandler:)` (typically in `AppDelegate.swift` or `PushNotificationRouter.swift`):

```swift
let userInfo = response.notification.request.content.userInfo
if let type = userInfo["type"] as? String, type == "plan_ready" {
    let planId = userInfo["planId"] as? String ?? ""
    Task { @MainActor in
        AnalyticsService.shared.track(.planReadyNotificationTapped(planId: planId))
        AppRouter.shared.deepLink(to: .planTab)
    }
}
```

If `AppRouter` doesn't exist, post a `Notification.Name("scaleup.deeplink.plan")` and have `RootTabView` observe it to switch to the Plan tab.

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Notifications/PushNotificationRouter.swift
git commit -m "feat(diagnostic-ios): handle plan_ready push deep-link"
```

---

## Task 20: iOS — Rebuild Plan tab to consume new structure

**Files:**
- Create: `ScaleUp/Features/Plan/Views/PlanTabView.swift`
- Create: `ScaleUp/Features/Plan/Views/Components/WeeklyAllocationCard.swift`

The existing `Features/Journey/Views/MyPlanView.swift` is left in place (the old "journey" view). The new `PlanTabView` becomes the surface for the new diagnostic-driven plan. Routing change in `RootTabView` (whichever file mounts the Plan tab) swaps `MyPlanView()` for `PlanTabView()`.

- [ ] **Step 1: WeeklyAllocationCard**

Create `ScaleUp/Features/Plan/Views/Components/WeeklyAllocationCard.swift`:

```swift
import SwiftUI

struct WeeklyAllocationCard: View {
    let entry: WeeklyEntry
    @State private var expanded = false

    var totalHours: Double { entry.allocations.reduce(0) { $0 + $1.hours } }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Week \(entry.week)")
                    .font(Typography.caption.weight(.bold))
                    .foregroundColor(ColorTokens.gold)
                Spacer()
                Text("\(String(format: "%.1f", totalHours)) h")
                    .font(Typography.caption)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            Text(entry.weeklyGoal)
                .font(Typography.body.weight(.semibold))
                .foregroundColor(ColorTokens.textPrimary)
            if expanded {
                ForEach(entry.allocations) { a in
                    HStack(alignment: .top, spacing: Spacing.s) {
                        Text("• \(a.topicCanonicalName.replacingOccurrences(of: "-", with: " "))")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundColor(ColorTokens.textPrimary)
                        Spacer()
                        Text("\(String(format: "%.1f", a.hours)) h")
                            .font(Typography.caption)
                            .foregroundColor(ColorTokens.gold)
                    }
                    Text(a.focusActivity)
                        .font(Typography.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                        .padding(.leading, Spacing.m)
                        .padding(.bottom, Spacing.xs)
                }
            }
        }
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
            Haptics.lightTap()
        }
    }
}
```

- [ ] **Step 2: PlanTabView**

Create `ScaleUp/Features/Plan/Views/PlanTabView.swift`:

```swift
import SwiftUI

struct PlanTabView: View {
    @State private var vm = PlanTabViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    switch vm.state {
                    case .idle, .loading:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    case .generating:
                        generatingView
                    case .ready(let plan):
                        readyView(plan)
                    case .error(let msg):
                        errorView(msg)
                    }
                }
                .padding(Spacing.l)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Your plan")
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    private var generatingView: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Your plan is being prepared")
                .font(Typography.headline)
                .foregroundColor(ColorTokens.textPrimary)
            Text("Usually ready in ~45 seconds. We will notify you when it is.")
                .font(Typography.body)
                .foregroundColor(ColorTokens.textSecondary)
            ProgressView().padding(.top, Spacing.m)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Could not load your plan").font(Typography.headline).foregroundColor(ColorTokens.textPrimary)
            Text(msg).font(Typography.body).foregroundColor(ColorTokens.textSecondary)
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.gold)
        }
    }

    private func readyView(_ plan: PlanDTO) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            // Hero
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(plan.planHeadline)
                    .font(Typography.title.weight(.bold))
                    .foregroundColor(ColorTokens.textPrimary)
                HStack(spacing: Spacing.m) {
                    label("Total", value: "\(Int(plan.estimatedTotalHours))h")
                    label("Weeks", value: "\(plan.weeklySchedule.count)")
                    label("Milestones", value: "\(plan.milestones.count)")
                }
                Text(plan.bufferRecommendation)
                    .font(Typography.caption)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(LinearGradient(colors: [ColorTokens.surfaceElevated, ColorTokens.surface], startPoint: .top, endPoint: .bottom))
            )

            // Weekly schedule
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Weekly schedule")
                    .font(Typography.headline)
                    .foregroundColor(ColorTokens.textPrimary)
                ForEach(plan.weeklySchedule) { entry in
                    WeeklyAllocationCard(entry: entry)
                }
            }

            // Milestones
            if !plan.milestones.isEmpty {
                MilestonePreview(milestones: plan.milestones)
            }
        }
    }

    private func label(_ k: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(Typography.caption).foregroundColor(ColorTokens.textSecondary)
            Text(value).font(Typography.body.weight(.bold)).foregroundColor(ColorTokens.gold)
        }
    }
}
```

- [ ] **Step 3: Swap the Plan tab in `RootTabView` (or wherever the tab is mounted)**

```swift
// Find the existing tab bar and replace MyPlanView() with PlanTabView()
TabView { /* ... */
    PlanTabView()
        .tabItem { Label("Plan", systemImage: "list.bullet.rectangle") }
}
```

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Features/Plan/Views/PlanTabView.swift ScaleUp/Features/Plan/Views/Components/WeeklyAllocationCard.swift
git commit -m "feat(diagnostic-ios): rebuild Plan tab around new diagnostic plan structure"
```

---

## Task 21: iOS — MilestonePreview animated component

**File:** Create `ScaleUp/Features/Plan/Views/Components/MilestonePreview.swift`

- [ ] **Step 1: Implementation**

```swift
import SwiftUI

struct MilestonePreview: View {
    let milestones: [PlanMilestone]
    @State private var revealedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Milestones")
                .font(Typography.headline)
                .foregroundColor(ColorTokens.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { idx, m in
                    HStack(alignment: .top, spacing: Spacing.m) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(m.isUserStated ? ColorTokens.gold : ColorTokens.goldLight)
                                .frame(width: 12, height: 12)
                                .opacity(idx < revealedCount ? 1 : 0)
                                .scaleEffect(idx < revealedCount ? 1 : 0.4)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(idx) * 0.08), value: revealedCount)
                            if idx < milestones.count - 1 {
                                Rectangle()
                                    .fill(ColorTokens.gold.opacity(0.3))
                                    .frame(width: 2, height: 36)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Spacing.xs) {
                                Text("Week \(m.week)").font(Typography.caption.weight(.bold)).foregroundColor(ColorTokens.gold)
                                if m.isUserStated {
                                    Text("YOUR GOAL")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(ColorTokens.gold.opacity(0.2)))
                                        .foregroundColor(ColorTokens.gold)
                                }
                            }
                            Text(m.title)
                                .font(Typography.body.weight(.semibold))
                                .foregroundColor(ColorTokens.textPrimary)
                            Text(m.measurableCriteria)
                                .font(Typography.caption)
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        .opacity(idx < revealedCount ? 1 : 0)
                        .offset(y: idx < revealedCount ? 0 : 10)
                        .animation(.easeOut(duration: 0.4).delay(Double(idx) * 0.08 + 0.05), value: revealedCount)
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            // Honor reduced motion
            if UIAccessibility.isReduceMotionEnabled {
                revealedCount = milestones.count
            } else {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    revealedCount = milestones.count
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ScaleUp/Features/Plan/Views/Components/MilestonePreview.swift
git commit -m "feat(diagnostic-ios): animated milestone preview component"
```

---

## Task 22: iOS — RecalibrationCard on Progress tab

**Files:**
- Create: `ScaleUp/Features/Diagnostic/ViewModels/RecalibrationViewModel.swift`
- Create: `ScaleUp/Features/Progress/Views/RecalibrationCard.swift`
- Modify: `ScaleUp/Features/Progress/Views/ProgressTabView.swift`

- [ ] **Step 1: ViewModel**

Create `ScaleUp/Features/Diagnostic/ViewModels/RecalibrationViewModel.swift`:

```swift
import Foundation

struct RecalibrationEligibility: Codable {
    let eligible: Bool
    let reason: String?
    let previousAttemptId: String?
    let eligibleTopics: [String]?
    let expectedDurationMin: Int?
}

struct RecalibrationStartResponse: Codable {
    let attemptId: String
    let totalEstimatedQuestions: Int
    let estimatedDurationSec: Int
    let flowType: String
}

@MainActor
@Observable
final class RecalibrationViewModel {
    var eligibility: RecalibrationEligibility?
    var loading = false
    var error: String?

    func checkEligibility() async {
        loading = true
        defer { loading = false }
        do {
            eligibility = try await APIClient.shared.get("/diagnostic/recalibration/eligible")
            if eligibility?.eligible == true {
                AnalyticsService.shared.track(.recalibrationOffered)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func start() async throws -> RecalibrationStartResponse {
        AnalyticsService.shared.track(.recalibrationStarted)
        return try await APIClient.shared.post("/diagnostic/recalibration/start", body: [String: String]())
    }
}
```

- [ ] **Step 2: Card**

Create `ScaleUp/Features/Progress/Views/RecalibrationCard.swift`:

```swift
import SwiftUI

struct RecalibrationCard: View {
    let eligibility: RecalibrationEligibility
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(ColorTokens.gold)
                Text("Re-calibrate")
                    .font(Typography.headline)
                    .foregroundColor(ColorTokens.textPrimary)
            }
            Text("See how much you have grown — \(eligibility.expectedDurationMin ?? 5) min, \((eligibility.eligibleTopics?.count ?? 0)) topics.")
                .font(Typography.body)
                .foregroundColor(ColorTokens.textSecondary)
            Button(action: onStart) {
                Text("Start re-calibration")
                    .font(Typography.body.weight(.semibold))
                    .foregroundColor(ColorTokens.background)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.s)
                    .background(Capsule().fill(ColorTokens.gold))
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
```

- [ ] **Step 3: Insert into ProgressTabView**

In `ScaleUp/Features/Progress/Views/ProgressTabView.swift`:

```swift
@State private var recalVM = RecalibrationViewModel()
@State private var showRecalibration = false

// inside the body's main VStack, near the top:
if let e = recalVM.eligibility, e.eligible {
    RecalibrationCard(eligibility: e) {
        showRecalibration = true
    }
    .padding(.horizontal, Spacing.l)
}

// inside .task:
.task { await recalVM.checkEligibility() }
.fullScreenCover(isPresented: $showRecalibration) {
    RecalibrationOrchestrationView(viewModel: recalVM)
}
```

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Features/Diagnostic/ViewModels/RecalibrationViewModel.swift ScaleUp/Features/Progress/Views/RecalibrationCard.swift ScaleUp/Features/Progress/Views/ProgressTabView.swift
git commit -m "feat(diagnostic-ios): re-calibration card on Progress tab"
```

---

## Task 23: iOS — RecalibrationNudge on Plan tab (one-time, day 30)

**File:** `ScaleUp/Features/Plan/Views/RecalibrationNudge.swift`

- [ ] **Step 1: Implementation**

```swift
import SwiftUI

struct RecalibrationNudge: View {
    let eligibility: RecalibrationEligibility
    let onTap: () -> Void
    let onDismiss: () -> Void

    @AppStorage("recalibrationNudgeDismissed") private var dismissed = false

    var body: some View {
        if dismissed { EmptyView() } else {
            HStack(alignment: .top, spacing: Spacing.s) {
                Image(systemName: "sparkles")
                    .foregroundColor(ColorTokens.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to see your growth?")
                        .font(Typography.body.weight(.semibold))
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("\((eligibility.expectedDurationMin ?? 5))-min re-calibration unlocks updated plan + growth bars.")
                        .font(Typography.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                    Button("Take it now", action: onTap)
                        .font(Typography.caption.weight(.bold))
                        .foregroundColor(ColorTokens.gold)
                        .padding(.top, 4)
                }
                Spacer()
                Button { dismissed = true; onDismiss() } label: {
                    Image(systemName: "xmark").foregroundColor(ColorTokens.textSecondary)
                }
            }
            .padding(Spacing.m)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
        }
    }
}
```

- [ ] **Step 2: Wire into PlanTabView (only show if eligible AND not dismissed)**

In `PlanTabView`'s `readyView(_:)`, before the hero card:

```swift
@State private var recalVM = RecalibrationViewModel()

// in readyView, near the top:
if let e = recalVM.eligibility, e.eligible {
    RecalibrationNudge(eligibility: e, onTap: { /* navigate */ }, onDismiss: {})
}

// in .task on PlanTabView:
.task {
    await vm.load()
    await recalVM.checkEligibility()
}
```

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Plan/Views/RecalibrationNudge.swift ScaleUp/Features/Plan/Views/PlanTabView.swift
git commit -m "feat(diagnostic-ios): re-calibration nudge on Plan tab"
```

---

## Task 24: iOS — RecalibrationOrchestrationView (re-uses diagnostic flow)

**File:** Create `ScaleUp/Features/Diagnostic/Views/RecalibrationOrchestrationView.swift`

The existing `DiagnosticContainerView` runs the full diagnostic. For re-calibration we initialize it with an `attemptId` from `POST /diagnostic/recalibration/start` and skip the welcome + self-rating screens (those came from the prior attempt).

- [ ] **Step 1: Implementation**

```swift
import SwiftUI

struct RecalibrationOrchestrationView: View {
    @Environment(\.dismiss) var dismiss
    let viewModel: RecalibrationViewModel
    @State private var attemptId: String?
    @State private var error: String?
    @State private var navigateToResults = false

    var body: some View {
        NavigationStack {
            Group {
                if let attemptId {
                    DiagnosticQuestionView(
                        attemptId: attemptId,
                        onComplete: { navigateToResults = true }
                    )
                } else if let error {
                    VStack(spacing: Spacing.m) {
                        Text("Could not start re-calibration")
                            .font(Typography.headline)
                        Text(error)
                            .font(Typography.body)
                            .foregroundColor(ColorTokens.textSecondary)
                        Button("Close") { dismiss() }
                    }
                } else {
                    ProgressView("Preparing your re-calibration…")
                        .tint(ColorTokens.gold)
                }
            }
            .navigationDestination(isPresented: $navigateToResults) {
                if let attemptId {
                    RecalibrationResultsView(attemptId: attemptId)
                }
            }
            .task {
                do {
                    let resp = try await viewModel.start()
                    attemptId = resp.attemptId
                } catch {
                    self.error = error.localizedDescription
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
        }
    }
}
```

(`DiagnosticQuestionView` is the existing component built in Plan 3 — its `onComplete` callback fires after `finishAttempt`.)

- [ ] **Step 2: Commit**

```bash
git add ScaleUp/Features/Diagnostic/Views/RecalibrationOrchestrationView.swift
git commit -m "feat(diagnostic-ios): re-calibration orchestration view"
```

---

## Task 25: iOS — RecalibrationResultsView per spec §10.4

Different shape from first-time results: hero biggest-growth callout, growth bars (old → new with animated arrow), new-gaps amber callout, plan rebalance preview.

**File:** Create `ScaleUp/Features/Diagnostic/Views/RecalibrationResultsView.swift`

- [ ] **Step 1: DTOs**

Append to `PlanService.swift` (or a `DiagnosticDTOs.swift`):

```swift
struct GrowthBar: Codable, Identifiable {
    var id: String { canonicalName }
    let canonicalName: String
    let oldScore: Double
    let newScore: Double
    let delta: Double
    let oldBand: String?
    let newBand: String?
    let bandShift: String?
}

struct RecalibrationGrowth: Codable {
    let growthBars: [GrowthBar]
    let biggestJump: GrowthBar?
    let newGaps: [String]
    let summary: String
}

struct RecalibrationResultsDTO: Codable {
    let recalibrationGrowth: RecalibrationGrowth?
    let previousAttemptId: String?
    let insights: InsightsDTO?
}
```

(`InsightsDTO` is defined in Plan 4-iOS / Plan 3 — reuse.)

- [ ] **Step 2: View**

Create `ScaleUp/Features/Diagnostic/Views/RecalibrationResultsView.swift`:

```swift
import SwiftUI

struct RecalibrationResultsView: View {
    let attemptId: String
    @State private var results: RecalibrationResultsDTO?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if loading {
                    ProgressView("Computing your growth…").tint(ColorTokens.gold).frame(maxWidth: .infinity, minHeight: 220)
                } else if let g = results?.recalibrationGrowth {
                    heroSection(g)
                    growthSection(g)
                    if !g.newGaps.isEmpty { newGapsSection(g.newGaps) }
                    rebalancePreviewSection
                }
            }
            .padding(Spacing.l)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("Your growth")
        .task { await load() }
    }

    private func load() async {
        defer { loading = false }
        do {
            results = try await APIClient.shared.get("/diagnostic/attempts/\(attemptId)/results")
            if let g = results?.recalibrationGrowth {
                AnalyticsService.shared.track(.recalibrationCompleted(
                    topicsRetested: g.growthBars.count,
                    biggestGrowth: g.biggestJump?.delta ?? 0
                ))
            }
        } catch {
            // Toast — fall through to empty state
        }
    }

    private func heroSection(_ g: RecalibrationGrowth) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(g.summary)
                .font(Typography.title.weight(.bold))
                .foregroundColor(ColorTokens.textPrimary)
            if let j = g.biggestJump {
                Text("Biggest jump: +\(Int(j.delta)) points on \(j.canonicalName.replacingOccurrences(of: "-", with: " "))")
                    .font(Typography.body)
                    .foregroundColor(ColorTokens.gold)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(LinearGradient(colors: [ColorTokens.gold.opacity(0.15), ColorTokens.surface], startPoint: .top, endPoint: .bottom))
        )
    }

    private func growthSection(_ g: RecalibrationGrowth) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Per-topic growth").font(Typography.headline).foregroundColor(ColorTokens.textPrimary)
            ForEach(g.growthBars) { bar in
                GrowthBarRow(bar: bar)
            }
        }
    }

    private func newGapsSection(_ gaps: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("New gaps to address").font(Typography.headline).foregroundColor(ColorTokens.textPrimary)
            }
            ForEach(gaps, id: \.self) { g in
                Text("• \(g.replacingOccurrences(of: "-", with: " "))")
                    .font(Typography.body)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            Text("Your plan will rebalance to focus more here.")
                .font(Typography.caption)
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium).fill(Color.orange.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        )
    }

    private var rebalancePreviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Plan rebalance").font(Typography.headline).foregroundColor(ColorTokens.textPrimary)
            Text("Your weekly plan is being updated to reflect your new measured scores. Open the Plan tab to view.")
                .font(Typography.body)
                .foregroundColor(ColorTokens.textSecondary)
            NavigationLink(destination: PlanTabView()) {
                Text("Go to plan")
                    .font(Typography.body.weight(.semibold))
                    .foregroundColor(ColorTokens.background)
                    .padding(.horizontal, Spacing.l).padding(.vertical, Spacing.s)
                    .background(Capsule().fill(ColorTokens.gold))
            }
        }
        .padding(Spacing.l)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(ColorTokens.surface))
    }
}

struct GrowthBarRow: View {
    let bar: GrowthBar
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(bar.canonicalName.replacingOccurrences(of: "-", with: " "))
                    .font(Typography.body.weight(.semibold))
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: bar.delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(bar.delta >= 0 ? "+" : "")\(Int(bar.delta))")
                }
                .font(Typography.caption.weight(.bold))
                .foregroundColor(bar.delta >= 0 ? .green : .orange)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(ColorTokens.surfaceElevated).frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [ColorTokens.goldDark, ColorTokens.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, animatedProgress * 240), height: 8)
                // Old marker
                Rectangle().fill(Color.white.opacity(0.6)).frame(width: 2, height: 14)
                    .offset(x: max(0, (bar.oldScore / 100.0) * 240) - 1)
            }
            .frame(maxWidth: 240, alignment: .leading)
            HStack {
                Text("Old: \(Int(bar.oldScore))").font(.caption2).foregroundColor(ColorTokens.textSecondary)
                Spacer()
                Text("New: \(Int(bar.newScore))").font(.caption2).foregroundColor(ColorTokens.gold)
            }
            .frame(maxWidth: 240)
        }
        .onAppear {
            let target = bar.newScore / 100.0
            if UIAccessibility.isReduceMotionEnabled {
                animatedProgress = target
            } else {
                withAnimation(.easeOut(duration: 0.9)) {
                    animatedProgress = target
                }
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Diagnostic/Views/RecalibrationResultsView.swift ScaleUp/Features/Plan/Services/PlanService.swift
git commit -m "feat(diagnostic-ios): re-calibration results screen with animated growth bars"
```

---

## Task 26: iOS — Mixpanel events for recalibration + plan

Already partially added in Task 18. Verify all spec §13.5 events present in `AnalyticsEvent.swift`:

- [ ] **Step 1: Confirm events present**

Required:
- `plan_brewing_seen` ✓
- `plan_ready_notification_tapped` ✓
- `plan_generation_completed` ✓
- `plan_generation_fallback` (add if missing)
- `recalibration_offered` ✓
- `recalibration_started` ✓
- `recalibration_completed` ✓

Add the missing one in `AnalyticsEvent.swift`:

```swift
extension AnalyticsEvent {
    static func planGenerationFallback(reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "plan_generation_fallback", properties: ["reason": reason])
    }
}
```

- [ ] **Step 2: Fire `plan_generation_completed` on transition `brewing -> ready`**

In `PlanBrewingViewModel.swift` `tick()`:

```swift
case "ready":
    if visibility == .brewing {
        AnalyticsService.shared.track(.planGenerationCompleted)
    }
    visibility = .ready
```

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Core/Analytics/AnalyticsEvent.swift ScaleUp/Features/Home/ViewModels/PlanBrewingViewModel.swift
git commit -m "feat(diagnostic-ios): complete Mixpanel coverage for plan + recalibration"
```

---

## Task 27: Android — PlanService + Plan tab screen + brewing pill

**Files:**
- Create: `src/services/planService.ts`
- Create: `src/screens/home/components/PlanBrewingPill.tsx`
- Modify: `src/screens/home/HomeScreen.tsx`
- Create: `src/screens/plan/PlanTabScreen.tsx`
- Create: `src/screens/plan/components/WeeklyAllocationCard.tsx`

- [ ] **Step 1: planService**

Create `src/services/planService.ts`:

```ts
import { api } from './api'

export type PlanStatus = 'pending' | 'generating' | 'ready' | 'failed'

export interface PlanStatusDTO {
  status: PlanStatus
  planId?: string | null
  source?: string
  updatedAt?: string
}

export interface WeeklyAllocation {
  topicCanonicalName: string
  hours: number
  focusActivity: string
}
export interface WeeklyEntry {
  week: number
  weeklyGoal: string
  allocations: WeeklyAllocation[]
}
export interface PlanMilestone {
  week: number
  title: string
  measurableCriteria: string
  isUserStated: boolean
}
export interface PlanDTO {
  planId: string
  planHeadline: string
  estimatedTotalHours: number
  bufferRecommendation: string
  weeklySchedule: WeeklyEntry[]
  milestones: PlanMilestone[]
  source: string
  updatedAt?: string
}

export const PlanService = {
  async fetchStatus(): Promise<PlanStatusDTO> {
    return api.get<PlanStatusDTO>('/plan/status')
  },
  async fetchCurrent(): Promise<PlanDTO> {
    return api.get<PlanDTO>('/plan/current')
  },
}
```

- [ ] **Step 2: PlanBrewingPill**

Create `src/screens/home/components/PlanBrewingPill.tsx`:

```tsx
import React, { useEffect, useRef } from 'react'
import { Animated, Pressable, StyleSheet, Text, View } from 'react-native'
import { theme } from '../../../theme'

interface Props { onPress: () => void }

export const PlanBrewingPill: React.FC<Props> = ({ onPress }) => {
  const scale = useRef(new Animated.Value(1)).current
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(scale, { toValue: 1.4, duration: 900, useNativeDriver: true }),
        Animated.timing(scale, { toValue: 1, duration: 900, useNativeDriver: true }),
      ])
    )
    loop.start()
    return () => loop.stop()
  }, [scale])

  return (
    <Pressable onPress={onPress} style={styles.pill} accessibilityLabel="Your plan is brewing">
      <Animated.View style={[styles.dot, { transform: [{ scale }] }]} />
      <Text style={styles.label}>Your plan is brewing — usually ~45s</Text>
    </Pressable>
  )
}

const styles = StyleSheet.create({
  pill: {
    flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start',
    paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999,
    backgroundColor: theme.colors.surface, borderColor: theme.colors.gold + '66', borderWidth: 1,
  },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: theme.colors.gold, marginRight: 8 },
  label: { color: theme.colors.goldLight, fontSize: 13, fontWeight: '600' },
})
```

- [ ] **Step 3: HomeScreen polling**

In `src/screens/home/HomeScreen.tsx` add:

```tsx
import { PlanBrewingPill } from './components/PlanBrewingPill'
import { PlanService } from '../../services/planService'
import { Analytics } from '../../services/analytics'

const [brewing, setBrewing] = useState<'hidden'|'brewing'|'ready'>('hidden')

useEffect(() => {
  let cancelled = false
  const tick = async () => {
    try {
      const s = await PlanService.fetchStatus()
      if (cancelled) return
      if (s.status === 'generating' || s.status === 'pending') {
        if (brewing === 'hidden') Analytics.track('plan_brewing_seen')
        setBrewing('brewing')
      } else if (s.status === 'ready') {
        if (brewing === 'brewing') Analytics.track('plan_generation_completed')
        setBrewing('ready')
      }
    } catch {}
  }
  tick()
  const id = setInterval(tick, 5000)
  return () => { cancelled = true; clearInterval(id) }
}, [brewing])

// Inside the JSX, near the top of the screen:
{brewing === 'brewing' && (
  <PlanBrewingPill onPress={() => {/* show toast */}} />
)}
```

- [ ] **Step 4: Commit**

```bash
git add src/services/planService.ts src/screens/home/components/PlanBrewingPill.tsx src/screens/home/HomeScreen.tsx
git commit -m "feat(diagnostic-rn): plan service + home brewing pill"
```

---

## Task 28: Android — Push notification handler for plan_ready

**File:** `src/services/pushNotifications.ts` (MODIFY or CREATE if not present)

- [ ] **Step 1: Add handler**

```ts
import messaging from '@react-native-firebase/messaging'
import { navigationRef } from '../navigation/navigationRef'
import { Analytics } from './analytics'

export function configurePushHandlers() {
  messaging().onNotificationOpenedApp(remoteMessage => {
    handleData(remoteMessage?.data)
  })
  messaging().getInitialNotification().then(remoteMessage => {
    if (remoteMessage) handleData(remoteMessage.data)
  })
}

function handleData(data?: { [k: string]: string }) {
  if (!data) return
  if (data.type === 'plan_ready') {
    Analytics.track('plan_ready_notification_tapped', { planId: data.planId })
    navigationRef.current?.navigate('PlanTab')
  }
}
```

Call `configurePushHandlers()` in `App.tsx` once on mount.

- [ ] **Step 2: Commit**

```bash
git add src/services/pushNotifications.ts App.tsx
git commit -m "feat(diagnostic-rn): handle plan_ready push deep-link"
```

---

## Task 29: Android — PlanTabScreen + WeeklyAllocationCard + MilestonePreview

**Files:**
- Create: `src/screens/plan/PlanTabScreen.tsx`
- Create: `src/screens/plan/components/WeeklyAllocationCard.tsx`
- Create: `src/screens/plan/components/MilestonePreview.tsx`

- [ ] **Step 1: WeeklyAllocationCard**

Create `src/screens/plan/components/WeeklyAllocationCard.tsx`:

```tsx
import React, { useState } from 'react'
import { Pressable, StyleSheet, Text, View } from 'react-native'
import { theme } from '../../../theme'
import type { WeeklyEntry } from '../../../services/planService'

export const WeeklyAllocationCard: React.FC<{ entry: WeeklyEntry }> = ({ entry }) => {
  const [expanded, setExpanded] = useState(false)
  const total = entry.allocations.reduce((s, a) => s + a.hours, 0)

  return (
    <Pressable onPress={() => setExpanded(!expanded)} style={styles.card}>
      <View style={styles.headerRow}>
        <Text style={styles.week}>Week {entry.week}</Text>
        <Text style={styles.total}>{total.toFixed(1)} h</Text>
      </View>
      <Text style={styles.goal}>{entry.weeklyGoal}</Text>
      {expanded && entry.allocations.map(a => (
        <View key={a.topicCanonicalName} style={styles.alloc}>
          <View style={styles.allocRow}>
            <Text style={styles.topic}>• {a.topicCanonicalName.replace(/-/g, ' ')}</Text>
            <Text style={styles.hours}>{a.hours.toFixed(1)} h</Text>
          </View>
          <Text style={styles.activity}>{a.focusActivity}</Text>
        </View>
      ))}
    </Pressable>
  )
}

const styles = StyleSheet.create({
  card: { backgroundColor: theme.colors.surface, borderRadius: 12, padding: 14, marginBottom: 10 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between' },
  week: { color: theme.colors.gold, fontWeight: '700', fontSize: 12 },
  total: { color: theme.colors.textSecondary, fontSize: 12 },
  goal: { color: theme.colors.textPrimary, fontWeight: '600', marginTop: 4, fontSize: 15 },
  alloc: { marginTop: 8 },
  allocRow: { flexDirection: 'row', justifyContent: 'space-between' },
  topic: { color: theme.colors.textPrimary, fontWeight: '600', fontSize: 13 },
  hours: { color: theme.colors.gold, fontSize: 13 },
  activity: { color: theme.colors.textSecondary, fontSize: 12, marginLeft: 12 },
})
```

- [ ] **Step 2: MilestonePreview**

Create `src/screens/plan/components/MilestonePreview.tsx`:

```tsx
import React, { useEffect, useRef } from 'react'
import { Animated, StyleSheet, Text, View } from 'react-native'
import { theme } from '../../../theme'
import type { PlanMilestone } from '../../../services/planService'

export const MilestonePreview: React.FC<{ milestones: PlanMilestone[] }> = ({ milestones }) => {
  const anims = useRef(milestones.map(() => new Animated.Value(0))).current

  useEffect(() => {
    Animated.stagger(80, anims.map(a =>
      Animated.timing(a, { toValue: 1, duration: 360, useNativeDriver: true })
    )).start()
  }, [anims])

  return (
    <View>
      <Text style={styles.section}>Milestones</Text>
      {milestones.map((m, i) => (
        <Animated.View key={`${m.week}-${m.title}`} style={[
          styles.row,
          { opacity: anims[i], transform: [{ translateY: anims[i].interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }] },
        ]}>
          <View style={styles.dot} />
          <View style={{ flex: 1 }}>
            <Text style={styles.weekLabel}>Week {m.week} {m.isUserStated ? '· YOUR GOAL' : ''}</Text>
            <Text style={styles.title}>{m.title}</Text>
            <Text style={styles.criteria}>{m.measurableCriteria}</Text>
          </View>
        </Animated.View>
      ))}
    </View>
  )
}

const styles = StyleSheet.create({
  section: { color: theme.colors.textPrimary, fontWeight: '700', fontSize: 16, marginBottom: 8 },
  row: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: 14 },
  dot: { width: 12, height: 12, borderRadius: 6, backgroundColor: theme.colors.gold, marginTop: 4, marginRight: 12 },
  weekLabel: { color: theme.colors.gold, fontWeight: '700', fontSize: 12 },
  title: { color: theme.colors.textPrimary, fontWeight: '600', marginTop: 2 },
  criteria: { color: theme.colors.textSecondary, fontSize: 12, marginTop: 2 },
})
```

- [ ] **Step 3: PlanTabScreen**

Create `src/screens/plan/PlanTabScreen.tsx`:

```tsx
import React, { useEffect, useState, useCallback } from 'react'
import { ActivityIndicator, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native'
import { theme } from '../../theme'
import { PlanService, type PlanDTO } from '../../services/planService'
import { WeeklyAllocationCard } from './components/WeeklyAllocationCard'
import { MilestonePreview } from './components/MilestonePreview'

export const PlanTabScreen: React.FC = () => {
  const [plan, setPlan] = useState<PlanDTO | null>(null)
  const [loading, setLoading] = useState(true)
  const [generating, setGenerating] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true); setError(null); setGenerating(false)
    try {
      const status = await PlanService.fetchStatus()
      if (status.status === 'ready') {
        const p = await PlanService.fetchCurrent()
        setPlan(p)
      } else if (status.status === 'generating' || status.status === 'pending') {
        setGenerating(true)
      } else {
        setError('Plan generation failed. Pull to retry.')
      }
    } catch (e: any) {
      setError(e?.message || 'Failed to load plan')
    } finally { setLoading(false) }
  }, [])

  useEffect(() => { load() }, [load])

  return (
    <ScrollView
      style={styles.container}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={theme.colors.gold} />}
      contentContainerStyle={{ padding: 18 }}
    >
      {loading && !plan && <ActivityIndicator color={theme.colors.gold} style={{ marginTop: 60 }} />}
      {generating && (
        <View style={styles.card}>
          <Text style={styles.headline}>Your plan is being prepared</Text>
          <Text style={styles.subtitle}>Usually ready in ~45 seconds. We will notify you when it is.</Text>
        </View>
      )}
      {error && <Text style={[styles.subtitle, { marginTop: 24 }]}>{error}</Text>}
      {plan && (
        <View>
          <View style={styles.heroCard}>
            <Text style={styles.headline}>{plan.planHeadline}</Text>
            <View style={styles.statsRow}>
              <Stat label="Total" value={`${Math.round(plan.estimatedTotalHours)}h`} />
              <Stat label="Weeks" value={`${plan.weeklySchedule.length}`} />
              <Stat label="Milestones" value={`${plan.milestones.length}`} />
            </View>
            <Text style={styles.buffer}>{plan.bufferRecommendation}</Text>
          </View>

          <Text style={styles.sectionHeader}>Weekly schedule</Text>
          {plan.weeklySchedule.map(e => <WeeklyAllocationCard key={e.week} entry={e} />)}

          {plan.milestones.length > 0 && <MilestonePreview milestones={plan.milestones} />}
        </View>
      )}
    </ScrollView>
  )
}

const Stat = ({ label, value }: { label: string; value: string }) => (
  <View style={{ marginRight: 18 }}>
    <Text style={{ color: theme.colors.textSecondary, fontSize: 12 }}>{label}</Text>
    <Text style={{ color: theme.colors.gold, fontWeight: '700', fontSize: 16 }}>{value}</Text>
  </View>
)

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: theme.colors.background },
  card: { backgroundColor: theme.colors.surface, padding: 18, borderRadius: 14, marginTop: 18 },
  heroCard: { backgroundColor: theme.colors.surfaceElevated, padding: 18, borderRadius: 14, marginBottom: 18 },
  headline: { color: theme.colors.textPrimary, fontSize: 20, fontWeight: '700' },
  subtitle: { color: theme.colors.textSecondary, marginTop: 6 },
  buffer: { color: theme.colors.textSecondary, fontSize: 12, marginTop: 8 },
  statsRow: { flexDirection: 'row', marginTop: 12 },
  sectionHeader: { color: theme.colors.textPrimary, fontWeight: '700', fontSize: 16, marginVertical: 10 },
})
```

- [ ] **Step 4: Commit**

```bash
git add src/screens/plan/PlanTabScreen.tsx src/screens/plan/components/WeeklyAllocationCard.tsx src/screens/plan/components/MilestonePreview.tsx
git commit -m "feat(diagnostic-rn): plan tab screen + components"
```

---

## Task 30: Android — Wire PlanTab in navigator

In `src/navigation/AppNavigator.tsx` (or whichever file mounts the bottom tab bar) replace the existing plan placeholder with `PlanTabScreen`:

```tsx
import { PlanTabScreen } from '../screens/plan/PlanTabScreen'
// ...
<Tab.Screen name="PlanTab" component={PlanTabScreen} options={{ title: 'Plan' }} />
```

- [ ] Commit:

```bash
git add src/navigation/AppNavigator.tsx
git commit -m "feat(diagnostic-rn): mount PlanTabScreen in tab navigator"
```

---

## Task 31: Android — RecalibrationCard on Progress + RecalibrationNudge on Plan

**Files:**
- Create: `src/services/recalibrationService.ts`
- Create: `src/screens/progress/RecalibrationCard.tsx`
- Create: `src/screens/plan/RecalibrationNudge.tsx`
- Modify: `src/screens/progress/ProgressScreen.tsx`
- Modify: `src/screens/plan/PlanTabScreen.tsx`

- [ ] **Step 1: Service**

Create `src/services/recalibrationService.ts`:

```ts
import { api } from './api'

export interface RecalibrationEligibility {
  eligible: boolean
  reason?: string
  previousAttemptId?: string
  eligibleTopics?: string[]
  expectedDurationMin?: number
}

export const RecalibrationService = {
  async getEligibility(): Promise<RecalibrationEligibility> {
    return api.get<RecalibrationEligibility>('/diagnostic/recalibration/eligible')
  },
  async start(flaggedTopics: string[] = []): Promise<{ attemptId: string; flowType: string }> {
    return api.post('/diagnostic/recalibration/start', { flaggedTopics })
  },
}
```

- [ ] **Step 2: RecalibrationCard**

Create `src/screens/progress/RecalibrationCard.tsx`:

```tsx
import React from 'react'
import { Pressable, StyleSheet, Text, View } from 'react-native'
import { theme } from '../../theme'
import type { RecalibrationEligibility } from '../../services/recalibrationService'

export const RecalibrationCard: React.FC<{ eligibility: RecalibrationEligibility; onStart: () => void }> = ({ eligibility, onStart }) => (
  <View style={styles.card}>
    <Text style={styles.title}>Re-calibrate</Text>
    <Text style={styles.body}>
      See how much you have grown — {eligibility.expectedDurationMin ?? 5} min, {eligibility.eligibleTopics?.length ?? 0} topics.
    </Text>
    <Pressable onPress={onStart} style={styles.btn}>
      <Text style={styles.btnLabel}>Start re-calibration</Text>
    </Pressable>
  </View>
)

const styles = StyleSheet.create({
  card: {
    backgroundColor: theme.colors.surfaceElevated,
    borderRadius: 14, padding: 18, margin: 16,
    borderColor: theme.colors.gold + '4D', borderWidth: 1,
  },
  title: { color: theme.colors.textPrimary, fontWeight: '700', fontSize: 18 },
  body: { color: theme.colors.textSecondary, marginTop: 6 },
  btn: { marginTop: 12, backgroundColor: theme.colors.gold, paddingHorizontal: 18, paddingVertical: 10, borderRadius: 999, alignSelf: 'flex-start' },
  btnLabel: { color: theme.colors.background, fontWeight: '700' },
})
```

- [ ] **Step 3: RecalibrationNudge**

Create `src/screens/plan/RecalibrationNudge.tsx`:

```tsx
import React, { useEffect, useState } from 'react'
import { Pressable, StyleSheet, Text, View } from 'react-native'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { theme } from '../../theme'
import type { RecalibrationEligibility } from '../../services/recalibrationService'

const STORAGE_KEY = 'recalibrationNudgeDismissed'

export const RecalibrationNudge: React.FC<{ eligibility: RecalibrationEligibility; onTap: () => void }> = ({ eligibility, onTap }) => {
  const [dismissed, setDismissed] = useState(false)
  useEffect(() => { AsyncStorage.getItem(STORAGE_KEY).then(v => setDismissed(v === '1')) }, [])
  if (dismissed) return null

  return (
    <View style={styles.row}>
      <View style={{ flex: 1 }}>
        <Text style={styles.title}>Ready to see your growth?</Text>
        <Text style={styles.body}>{eligibility.expectedDurationMin ?? 5}-min re-calibration unlocks updated plan + growth bars.</Text>
        <Pressable onPress={onTap}>
          <Text style={styles.cta}>Take it now</Text>
        </Pressable>
      </View>
      <Pressable onPress={async () => { await AsyncStorage.setItem(STORAGE_KEY, '1'); setDismissed(true) }}>
        <Text style={styles.x}>×</Text>
      </Pressable>
    </View>
  )
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'flex-start', backgroundColor: theme.colors.surface, borderRadius: 12, padding: 14, marginBottom: 14 },
  title: { color: theme.colors.textPrimary, fontWeight: '600' },
  body: { color: theme.colors.textSecondary, fontSize: 12, marginTop: 4 },
  cta: { color: theme.colors.gold, fontWeight: '700', marginTop: 6 },
  x: { color: theme.colors.textSecondary, fontSize: 22, paddingHorizontal: 6 },
})
```

- [ ] **Step 4: Wire into ProgressScreen + PlanTabScreen**

In `src/screens/progress/ProgressScreen.tsx`:

```tsx
import { RecalibrationCard } from './RecalibrationCard'
import { RecalibrationService, type RecalibrationEligibility } from '../../services/recalibrationService'
import { Analytics } from '../../services/analytics'

const [recal, setRecal] = useState<RecalibrationEligibility | null>(null)
useEffect(() => {
  RecalibrationService.getEligibility().then(e => {
    setRecal(e)
    if (e.eligible) Analytics.track('recalibration_offered')
  }).catch(() => {})
}, [])

// in JSX, near the top:
{recal?.eligible && (
  <RecalibrationCard eligibility={recal} onStart={() => navigation.navigate('RecalibrationFlow')} />
)}
```

In `src/screens/plan/PlanTabScreen.tsx` add:

```tsx
import { RecalibrationNudge } from './RecalibrationNudge'
import { RecalibrationService } from '../../services/recalibrationService'

const [recal, setRecal] = useState(null as any)
useEffect(() => { RecalibrationService.getEligibility().then(setRecal).catch(() => {}) }, [])

// in JSX, before the hero card:
{recal?.eligible && (
  <RecalibrationNudge eligibility={recal} onTap={() => navigation.navigate('RecalibrationFlow')} />
)}
```

- [ ] **Step 5: Commit**

```bash
git add src/services/recalibrationService.ts src/screens/progress/RecalibrationCard.tsx src/screens/plan/RecalibrationNudge.tsx src/screens/progress/ProgressScreen.tsx src/screens/plan/PlanTabScreen.tsx
git commit -m "feat(diagnostic-rn): re-calibration card + plan tab nudge"
```

---

## Task 32: Android — RecalibrationResultsScreen per spec §10.4

**File:** Create `src/screens/diagnostic/RecalibrationResultsScreen.tsx`

- [ ] **Step 1: Implementation**

```tsx
import React, { useEffect, useState } from 'react'
import { Animated, ScrollView, StyleSheet, Text, View } from 'react-native'
import { theme } from '../../theme'
import { api } from '../../services/api'
import { Analytics } from '../../services/analytics'

interface GrowthBar { canonicalName: string; oldScore: number; newScore: number; delta: number; bandShift?: string }
interface Growth { growthBars: GrowthBar[]; biggestJump: GrowthBar | null; newGaps: string[]; summary: string }

export const RecalibrationResultsScreen: React.FC<{ route: { params: { attemptId: string } }; navigation: any }> = ({ route, navigation }) => {
  const { attemptId } = route.params
  const [growth, setGrowth] = useState<Growth | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    (async () => {
      try {
        const r = await api.get<{ recalibrationGrowth: Growth }>(`/diagnostic/attempts/${attemptId}/results`)
        setGrowth(r.recalibrationGrowth)
        if (r.recalibrationGrowth) {
          Analytics.track('recalibration_completed', {
            topicsRetested: r.recalibrationGrowth.growthBars.length,
            biggestGrowth: r.recalibrationGrowth.biggestJump?.delta ?? 0,
          })
        }
      } finally { setLoading(false) }
    })()
  }, [attemptId])

  if (loading) return <Text style={styles.loading}>Computing your growth…</Text>
  if (!growth) return <Text style={styles.loading}>No growth data.</Text>

  return (
    <ScrollView style={styles.container} contentContainerStyle={{ padding: 18 }}>
      <View style={styles.hero}>
        <Text style={styles.heroText}>{growth.summary}</Text>
        {growth.biggestJump && (
          <Text style={styles.heroSub}>
            Biggest jump: +{Math.round(growth.biggestJump.delta)} points on {growth.biggestJump.canonicalName.replace(/-/g, ' ')}
          </Text>
        )}
      </View>

      <Text style={styles.section}>Per-topic growth</Text>
      {growth.growthBars.map(b => <GrowthBarRow key={b.canonicalName} bar={b} />)}

      {growth.newGaps.length > 0 && (
        <View style={styles.gapsCard}>
          <Text style={styles.gapsTitle}>New gaps to address</Text>
          {growth.newGaps.map(g => <Text key={g} style={styles.gapItem}>• {g.replace(/-/g, ' ')}</Text>)}
          <Text style={styles.gapsHint}>Your plan will rebalance to focus more here.</Text>
        </View>
      )}

      <View style={styles.rebalance}>
        <Text style={styles.section}>Plan rebalance</Text>
        <Text style={styles.body}>Your weekly plan is being updated. Tap to view.</Text>
        <Text style={styles.cta} onPress={() => navigation.navigate('PlanTab')}>Go to plan</Text>
      </View>
    </ScrollView>
  )
}

const GrowthBarRow: React.FC<{ bar: GrowthBar }> = ({ bar }) => {
  const w = useState(new Animated.Value(0))[0]
  useEffect(() => {
    Animated.timing(w, { toValue: bar.newScore / 100, duration: 900, useNativeDriver: false }).start()
  }, [w, bar.newScore])
  return (
    <View style={{ marginBottom: 12 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Text style={styles.topic}>{bar.canonicalName.replace(/-/g, ' ')}</Text>
        <Text style={[styles.delta, { color: bar.delta >= 0 ? '#2ecc71' : '#e67e22' }]}>
          {bar.delta >= 0 ? '+' : ''}{Math.round(bar.delta)}
        </Text>
      </View>
      <View style={styles.barTrack}>
        <Animated.View style={[styles.barFill, { width: w.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'] }) }]} />
        <View style={[styles.oldMarker, { left: `${(bar.oldScore / 100) * 100}%` }]} />
      </View>
      <View style={styles.scoreRow}>
        <Text style={styles.oldLabel}>Old: {Math.round(bar.oldScore)}</Text>
        <Text style={styles.newLabel}>New: {Math.round(bar.newScore)}</Text>
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: theme.colors.background },
  loading: { color: theme.colors.textSecondary, textAlign: 'center', marginTop: 80 },
  hero: { backgroundColor: theme.colors.surface, padding: 18, borderRadius: 14, marginBottom: 18 },
  heroText: { color: theme.colors.textPrimary, fontSize: 18, fontWeight: '700' },
  heroSub: { color: theme.colors.gold, marginTop: 6 },
  section: { color: theme.colors.textPrimary, fontWeight: '700', fontSize: 16, marginVertical: 10 },
  topic: { color: theme.colors.textPrimary, fontWeight: '600' },
  delta: { fontWeight: '700' },
  barTrack: { height: 8, backgroundColor: theme.colors.surfaceElevated, borderRadius: 4, marginTop: 6, overflow: 'visible', position: 'relative' },
  barFill: { height: 8, backgroundColor: theme.colors.gold, borderRadius: 4 },
  oldMarker: { position: 'absolute', top: -3, width: 2, height: 14, backgroundColor: 'rgba(255,255,255,0.6)' },
  scoreRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 4 },
  oldLabel: { color: theme.colors.textSecondary, fontSize: 11 },
  newLabel: { color: theme.colors.gold, fontSize: 11 },
  gapsCard: { backgroundColor: '#e67e2222', borderRadius: 12, padding: 14, marginTop: 14, borderColor: '#e67e22', borderWidth: 1 },
  gapsTitle: { color: theme.colors.textPrimary, fontWeight: '700' },
  gapItem: { color: theme.colors.textSecondary, marginTop: 4 },
  gapsHint: { color: theme.colors.textSecondary, marginTop: 6, fontSize: 12 },
  rebalance: { backgroundColor: theme.colors.surface, padding: 14, borderRadius: 12, marginTop: 18 },
  body: { color: theme.colors.textSecondary, marginTop: 4 },
  cta: { color: theme.colors.gold, fontWeight: '700', marginTop: 8 },
})
```

- [ ] **Step 2: Wire route in navigator**

In `src/navigation/AppNavigator.tsx`:

```tsx
import { RecalibrationResultsScreen } from '../screens/diagnostic/RecalibrationResultsScreen'
// ... in the stack:
<Stack.Screen name="RecalibrationResults" component={RecalibrationResultsScreen} />
<Stack.Screen name="RecalibrationFlow" component={RecalibrationFlowScreen} />
```

`RecalibrationFlowScreen` is a thin wrapper that calls `RecalibrationService.start()` and routes to `QuestionScreen` with the returned `attemptId`, then on completion navigates to `RecalibrationResults`.

- [ ] **Step 3: Commit**

```bash
git add src/screens/diagnostic/RecalibrationResultsScreen.tsx src/navigation/AppNavigator.tsx
git commit -m "feat(diagnostic-rn): re-calibration results screen with growth bars"
```

---

## Task 33: Android — RecalibrationFlowScreen wrapper

**File:** Create `src/screens/diagnostic/RecalibrationFlowScreen.tsx`

```tsx
import React, { useEffect, useState } from 'react'
import { ActivityIndicator, Text, View } from 'react-native'
import { theme } from '../../theme'
import { RecalibrationService } from '../../services/recalibrationService'
import { Analytics } from '../../services/analytics'

export const RecalibrationFlowScreen: React.FC<{ navigation: any }> = ({ navigation }) => {
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    (async () => {
      try {
        Analytics.track('recalibration_started')
        const r = await RecalibrationService.start()
        navigation.replace('QuestionScreen', {
          attemptId: r.attemptId,
          isRecalibration: true,
          onComplete: () => navigation.replace('RecalibrationResults', { attemptId: r.attemptId }),
        })
      } catch (e: any) {
        setError(e?.response?.data?.message || e.message || 'Could not start re-calibration')
      }
    })()
  }, [navigation])

  return (
    <View style={{ flex: 1, backgroundColor: theme.colors.background, justifyContent: 'center', alignItems: 'center' }}>
      {error ? <Text style={{ color: theme.colors.textPrimary }}>{error}</Text> : <ActivityIndicator color={theme.colors.gold} />}
    </View>
  )
}
```

- [ ] Commit:

```bash
git add src/screens/diagnostic/RecalibrationFlowScreen.tsx
git commit -m "feat(diagnostic-rn): re-calibration flow wrapper screen"
```

---

## Task 34: Android — Mixpanel events parity

**File:** `src/services/analytics/AnalyticsEvent.ts` (MODIFY)

- [ ] **Step 1: Ensure these event names are exported**

```ts
export const ANALYTICS_EVENTS = {
  PLAN_BREWING_SEEN: 'plan_brewing_seen',
  PLAN_READY_NOTIFICATION_TAPPED: 'plan_ready_notification_tapped',
  PLAN_GENERATION_COMPLETED: 'plan_generation_completed',
  PLAN_GENERATION_FALLBACK: 'plan_generation_fallback',
  RECALIBRATION_OFFERED: 'recalibration_offered',
  RECALIBRATION_STARTED: 'recalibration_started',
  RECALIBRATION_COMPLETED: 'recalibration_completed',
} as const
```

- [ ] **Step 2: Verify call sites use the constants (or string parity with iOS)**

Audit:

```bash
grep -rn "Analytics.track" src/screens/plan src/screens/progress src/screens/diagnostic src/services/pushNotifications.ts
```

All event-name strings must match the iOS strings exactly (case + underscores).

- [ ] **Step 3: Commit**

```bash
git add src/services/analytics/AnalyticsEvent.ts
git commit -m "feat(diagnostic-rn): Mixpanel event constants for plan + recalibration"
```

---

## Task 35: Run all tests + push branch

- [ ] **Step 1: Backend full test suite**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
npm test
```

Expected: all tests pass (existing + new).

- [ ] **Step 2: iOS build check**

Open Xcode workspace, build for any iOS simulator. Expect 0 errors. Confirm `PlanTabView` shows up when the Plan tab is tapped.

- [ ] **Step 3: Android typecheck + run**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
npm run typecheck
npm run android
```

Expected: typecheck clean, app launches, Plan tab renders the new screen.

- [ ] **Step 4: Push branches**

```bash
# backend
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git push -u origin feat/diagnostic-phase5-6-plan-recalibration-admin

# iOS (separate repo / branch as appropriate)
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git push -u origin feat/diagnostic-phase5-6-plan-recalibration-admin

# Android
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git push -u origin feat/diagnostic-phase5-6-plan-recalibration-admin
```

---

## Self-Review Checklist (run by Claude before handing back)

**1. Spec coverage check** — Each spec section in scope is covered:

| Spec section | Where addressed |
|---|---|
| §3.5 Re-calibration flow | Tasks 8 (eligibility), 9 (shorter diagnostic), 10 (results + auto-rebalance), 11 (offer cron) |
| §5.5 Tier 2 admin review | Tasks 12 (auth), 13 (endpoints), 14 (training signal), 15 (dashboard), 16 (digest) |
| §10.4 Re-calibration results screen (different shape) | Task 25 (iOS), Task 32 (Android) — biggest growth hero, growth bars old→new with arrow, new gaps amber callout, plan rebalance preview |
| §11 Plan generation contract (inputs/outputs/constraints) | Task 3 (LLM + template + clamp + 0.85 buffer + +20% overestimates + 8% future-proofing + foundational sequencing) |
| §11.4 Async background job + push + Home brewing | Tasks 5 (worker), 4 (push), 18 (iOS pill), 27 (Android pill) |
| §12.3 Plan endpoints | Task 6 (`/plan/status`, `/plan/current`) |
| §12.6 Admin endpoints | Task 13 (queue, approve, edit, reject, stats) |
| §13.1 iOS plan + recalibration UI | Tasks 17-26 |
| §13.2 Android plan + recalibration UI | Tasks 27-34 |
| §13.4 Re-calibration UX (animated growth bars) | Task 25 (iOS GrowthBarRow), Task 32 (Android GrowthBarRow) — both honor reduced-motion |
| §13.5 Mixpanel events (plan + recalibration) | Tasks 18, 26 (iOS), 27, 34 (Android) — `plan_brewing_seen`, `plan_ready_notification_tapped`, `plan_generation_completed`, `plan_generation_fallback`, `recalibration_offered`, `recalibration_started`, `recalibration_completed` |

**2. Type consistency check:**

- `Plan.source` enum: `'llm-generated' | 'template' | 'rebalanced'` — used in model (Task 1), service return (Task 3), worker persistence (Task 5), DTO (Task 17).
- `DiagnosticAttempt.attemptType` enum: `'initial' | 'recalibration'` — used in eligibility service (Task 8), startRecalibration (Task 9), results compute (Task 10), offer cron aggregate (Task 11).
- `DiagnosticAttempt.planGenerationStatus` enum: `'pending' | 'generating' | 'ready' | 'failed'` — surfaces in plan worker (Task 5), getStatus (Task 6), iOS PlanTabViewModel (Task 17), Android PlanTabScreen (Task 29).
- Mixpanel event names match exactly between iOS (`plan_brewing_seen`) and Android (string `'plan_brewing_seen'`).
- Push notification `data.type === 'plan_ready'` matches between BE notification service (Task 4), iOS handler (Task 19), Android handler (Task 28).
- Calibration class: `'well-calibrated' | 'overestimates' | 'undersells'` — service & worker (Tasks 3, 5).
- Growth bar shape (canonicalName/oldScore/newScore/delta/bandShift) consistent BE (Task 10) ↔ iOS DTO (Task 25) ↔ Android interface (Task 32).

**3. Placeholder scan** — No `TBD`, `TODO`, or "fill in details" markers. Where the plan refers to existing components (e.g. `DiagnosticQuestionView` from Plan 3, `APIClient.shared`, `theme.colors`, `Analytics.track`, `navigationRef`), those are dependencies from prior plans / existing code, not placeholders. Specifically `RecalibrationFlowScreen` and `RecalibrationOrchestrationView` thinly wrap the existing diagnostic question flow built in Plan 3 — the plan calls this out explicitly in Tasks 24 and 33.

**4. TDD discipline** — Every backend task that introduces new logic (Tasks 1, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 16) has Step 1 = failing test, Step 2 = run-and-confirm-fail, Step 3+ = implementation, then run-and-confirm-pass. iOS/Android tasks (Tasks 17-34) follow build-verification cadence (Task 35) since SwiftUI/RN view tests aren't standard in this project.

**5. LLM mocking** — Every task that calls `openai` (Task 3 plan generator) mocks via `require.cache[openaiPath] = { exports: fakeOpenAI }` before requiring the service under test. No live LLM calls in tests.

**6. Backwards compatibility** — `journeyGenerationService.generateJourney` (existing entry point) is preserved (Task 7); only a new `generateFromPlan` is added. Old `MyPlanView.swift` left in place; new `PlanTabView.swift` is the diagnostic-driven surface and replaces it via tab routing only.

**7. India-context lens** — Plan generator system prompt (Task 3) includes the India-context block (Razorpay, Flipkart, Zomato, TCS examples; Indian exam dates; INR-by-default) per spec §6.4 and research §10.

---

## Execution Handoff

**Plan complete and saved to** `docs/superpowers/plans/2026-05-03-diagnostic-phase5-6-plan-recalibration-admin.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, two-stage review between tasks (spec compliance + code quality). Best for the heavy backend-test surface in Tasks 1-16. Note: Tasks 17-34 (iOS + Android) have less testable surface — review them as visual diff PRs rather than test-pass gates.

**2. Inline Execution** — Run tasks in this session via superpowers:executing-plans with batch checkpoints. Slower but you stay closer to the work.

**Sequencing note:** Tasks 1-16 (backend) MUST land before Tasks 17-34 can be exercised end-to-end (the iOS/Android surfaces depend on the BE endpoints). The frontend plans can compile in isolation but only render real data once the BE branch is deployed to a staging environment.

**Operational follow-ups not in this plan:**
- Set `User.role = 'admin'` for Nirpeksh in production (one-off DB update).
- Set `ADMIN_DASHBOARD_URL` env var if the default differs from production hostname.
- Add `npm run worker` to the deploy script if not already running (the new BullMQ workers register on `src/workers/index.js` startup).

