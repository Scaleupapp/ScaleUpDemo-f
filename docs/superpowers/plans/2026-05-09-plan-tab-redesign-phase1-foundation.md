# Plan Tab Redesign — Phase 1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay the foundation for the Plan-tab orchestration-hub redesign — expand the `Plan` model to carry actionable tasks, add a `planProgressService` that updates task progress when quizzes / content events happen, shorten the recalibration cooldown, surface "next check-in" on the plan response, and fix the iOS spinner-on-failure bug.

**Architecture:**
- `Plan.weeklySchedule[i].tasks[]` becomes the source of truth for "what should the user do this week."
- A new `src/services/plan/planProgressService.js` exposes imperative `onQuizComplete` / `onContentProgress` functions called from the existing write sites (`knowledgeService.updateFromQuizAttempt`, `consumptionService.updateProgress`, `consumptionService.markCompleted`). The codebase does not use Node's EventEmitter pub/sub — we extend the same imperative-call style.
- Recalibration eligibility cooldown drops from 30d → 7d.
- `GET /api/v1/plan/current` adds `nextCheckInAt = lastDiagnostic.completedAt + 7d`.
- iOS `PlanTabViewModel` adds explicit `failed` handling so users see a recoverable error card instead of an infinite spinner.

**Tech Stack:** Node 18 + Express 4 + Mongoose, `node:test` for backend tests; Swift 5 + SwiftUI / `@Observable` on iOS.

**Spec:** `docs/superpowers/specs/2026-05-09-plan-tab-redesign-design.md` (commit `df0068f`). This plan covers spec §7 Phase 1 only. Phases 2-5 will get their own plans.

**Repo layout (matters for paths):**
- Backend: `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/`
- Plans saved to: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/plans/`

---

## File Structure

**Created:**
- `scaleup-backend/src/services/plan/planProgressService.js` — imperative API for marking plan tasks complete from external trigger sites.
- `scaleup-backend/src/services/plan/planProgressService.test.js` — unit tests.

**Modified:**
- `scaleup-backend/src/models/Plan.js` — add `taskSchema` and embed `tasks[]` on `weeklyEntrySchema`.
- `scaleup-backend/src/models/Plan.test.js` — add tests for the new field.
- `scaleup-backend/src/services/diagnostic/recalibrationEligibilityService.js` — change `MIN_DAYS_SINCE_LAST` 30 → 7.
- `scaleup-backend/src/services/diagnostic/recalibrationEligibilityService.test.js` — update day-boundary assertions.
- `scaleup-backend/src/controllers/planController.js` — add `nextCheckInAt` to `getCurrent` response.
- `scaleup-backend/src/controllers/planController.test.js` — assert new field.
- `scaleup-backend/src/services/knowledgeService.js` — call `planProgressService.onQuizComplete` after `updateFromQuizAttempt` finishes.
- `scaleup-backend/src/services/consumptionService.js` — call `planProgressService.onContentProgress` from `updateProgress` and `markCompleted`.
- `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift` — add `failed` case.
- `ScaleUp/Features/Plan/Views/PlanTabView.swift` — render failed-state error card with retry CTA.

**Working directory for backend tasks:** `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`
**Working directory for iOS tasks:** `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/`

Each task ends with a commit. Tests use `node:test` (run via `npm test -- <path>` which calls `scripts/run-tests.js`).

---

## Task 1: Plan model — add `tasks[]` to weekly schedule

**Files:**
- Modify: `scaleup-backend/src/models/Plan.js`
- Test: `scaleup-backend/src/models/Plan.test.js`

The new `taskSchema` embeds inside each `weeklyEntrySchema.allocations` peer field. The schema must be permissive on `payload` (it varies by `type`) and strict on `type` / `status` enums.

- [ ] **Step 1: Write the failing test**

Append to `scaleup-backend/src/models/Plan.test.js`:

```javascript
test('Plan: accepts tasks[] on weeklySchedule with all six task types', () => {
  const types = ['quiz', 'in_app_content', 'ai_interview', 'external_link', 'competition', 'manual'];
  const doc = new Plan({
    userId: new mongoose.Types.ObjectId(),
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'x',
    estimatedTotalHours: 10,
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'Cover the basics',
      allocations: [],
      tasks: types.map((t, i) => ({
        type: t,
        topic: { canonicalName: 'product-strategy', displayName: 'Product Strategy' },
        payload: { stub: `payload-${i}` },
        completion: { mode: t === 'quiz' || t === 'in_app_content' || t === 'ai_interview' || t === 'competition' ? 'auto' : 'manual', requiresSelfRating: t === 'manual' || t === 'external_link' },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      })),
    }],
    source: 'llm-generated',
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined, 'should validate cleanly');
  assert.strictEqual(doc.weeklySchedule[0].tasks.length, 6);
  assert.strictEqual(doc.weeklySchedule[0].tasks[0].progress.status, 'pending');
});

test('Plan: rejects unknown task type', () => {
  const doc = new Plan({
    userId: new mongoose.Types.ObjectId(),
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'x',
    estimatedTotalHours: 10,
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'g',
      allocations: [],
      tasks: [{
        type: 'not_a_real_type',
        topic: { canonicalName: 'x', displayName: 'X' },
        completion: { mode: 'manual', requiresSelfRating: false },
        progress: { status: 'pending' },
      }],
    }],
    source: 'llm-generated',
  });
  const err = doc.validateSync();
  assert.ok(err, 'should fail validation on unknown type');
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/models/Plan.test.js
```

Expected: the new tests fail because `tasks` is silently dropped (Mongoose strips unknown paths).

- [ ] **Step 3: Update the schema**

Replace `scaleup-backend/src/models/Plan.js` with:

```javascript
const mongoose = require('mongoose');

const allocationSchema = new mongoose.Schema({
  topicCanonicalName: { type: String, required: true },
  hours: { type: Number, required: true, min: 0 },
  focusActivity: { type: String, required: true },
}, { _id: false });

const taskTopicSchema = new mongoose.Schema({
  canonicalName: { type: String, required: true },
  displayName: { type: String, required: true },
}, { _id: false });

const taskCompletionSchema = new mongoose.Schema({
  mode: { type: String, enum: ['auto', 'manual'], required: true },
  requiresSelfRating: { type: Boolean, default: false },
}, { _id: false });

const taskProgressSchema = new mongoose.Schema({
  status: { type: String, enum: ['pending', 'in_progress', 'complete', 'skipped'], default: 'pending' },
  completedAt: { type: Date, default: null },
  selfRating: { type: Number, min: 1, max: 5, default: null },
  sourceEventId: { type: String, default: null },
}, { _id: false });

const taskSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['quiz', 'in_app_content', 'ai_interview', 'external_link', 'competition', 'manual'],
    required: true,
  },
  topic: { type: taskTopicSchema, required: true },
  payload: { type: mongoose.Schema.Types.Mixed, default: {} },
  completion: { type: taskCompletionSchema, required: true },
  progress: { type: taskProgressSchema, default: () => ({ status: 'pending' }) },
  generatedAt: { type: Date, default: Date.now },
}, { _id: true });

const weeklyEntrySchema = new mongoose.Schema({
  week: { type: Number, required: true, min: 1 },
  weeklyGoal: { type: String, required: true },
  allocations: { type: [allocationSchema], default: [] },
  tasks: { type: [taskSchema], default: [] },
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

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/models/Plan.test.js
```

Expected: all Plan model tests PASS (existing four + new two).

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/models/Plan.js src/models/Plan.test.js
git commit -m "feat(plan): add tasks[] to weekly schedule"
```

---

## Task 2: Recalibration cooldown 30d → 7d

**Files:**
- Modify: `scaleup-backend/src/services/diagnostic/recalibrationEligibilityService.js:18`
- Test: `scaleup-backend/src/services/diagnostic/recalibrationEligibilityService.test.js`

- [ ] **Step 1: Inspect existing test for cooldown boundary**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && grep -n "30\|MIN_DAYS\|too_recent\|daysSinceLast" src/services/diagnostic/recalibrationEligibilityService.test.js | head -20
```

Note any existing tests that hard-code 30 — they will need updating in step 3.

- [ ] **Step 2: Write the failing test**

Append to `scaleup-backend/src/services/diagnostic/recalibrationEligibilityService.test.js`:

```javascript
test('eligibility: passes cooldown at day 8', async () => {
  // 8 days ago — was blocked under old 30d gate, must pass under new 7d gate
  const eightDaysAgo = new Date(Date.now() - 8 * 86400000);

  const fakeAttempt = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    completedAt: eightDaysAgo,
    results: { 'product-strategy': { score: 60, calibrationDelta: -10 } },
  };

  // Stub DiagnosticAttempt.findOne — chain returns lean()
  const origFindOne = DiagnosticAttempt.findOne;
  DiagnosticAttempt.findOne = () => ({ lean: async () => fakeAttempt });
  const origPlanFind = Plan.findOne;
  Plan.findOne = () => ({ lean: async () => null });

  try {
    const out = await computeEligibility(fakeAttempt.userId.toString());
    assert.strictEqual(out.eligible, true, `expected eligible=true at day 8; got ${JSON.stringify(out)}`);
  } finally {
    DiagnosticAttempt.findOne = origFindOne;
    Plan.findOne = origPlanFind;
  }
});
```

If the test file has no existing imports for `DiagnosticAttempt` / `Plan` / `computeEligibility`, add them at the top of the file:

```javascript
const DiagnosticAttempt = require('../../models/DiagnosticAttempt');
const Plan = require('../../models/Plan');
const { computeEligibility } = require('./recalibrationEligibilityService');
```

(Skip duplicates — check what's already there first.)

- [ ] **Step 3: Run test to verify it fails**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/services/diagnostic/recalibrationEligibilityService.test.js
```

Expected: the new test FAILS with `eligible=false` and `reason='too_recent'` because the constant is still 30.

- [ ] **Step 4: Update the constant**

In `scaleup-backend/src/services/diagnostic/recalibrationEligibilityService.js` line 18, change:

```javascript
const MIN_DAYS_SINCE_LAST = 30;
```

to:

```javascript
const MIN_DAYS_SINCE_LAST = 7;
```

- [ ] **Step 5: Update existing tests that hard-coded 30**

If step 1 surfaced any tests asserting `daysSinceLast === 30` or `minDaysRequired === 30`, update them to expect `7`. (If step 1 found none, skip this step.)

- [ ] **Step 6: Run all eligibility tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/services/diagnostic/recalibrationEligibilityService.test.js
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/diagnostic/recalibrationEligibilityService.js src/services/diagnostic/recalibrationEligibilityService.test.js
git commit -m "feat(diagnostic): shorten recalibration cooldown 30d -> 7d"
```

---

## Task 3: Plan controller — surface `nextCheckInAt`

**Files:**
- Modify: `scaleup-backend/src/controllers/planController.js`
- Test: `scaleup-backend/src/controllers/planController.test.js`

`GET /api/v1/plan/current` must return `nextCheckInAt = diagnosticAttempt.completedAt + 7d` (ISO string). The iOS pill uses this.

- [ ] **Step 1: Inspect existing test setup**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && head -60 src/controllers/planController.test.js
```

Note the stubbing pattern used (likely `Plan.findOne = ...` overrides with `.sort().lean()` chain).

- [ ] **Step 2: Write the failing test**

Append to `scaleup-backend/src/controllers/planController.test.js`:

```javascript
test('getCurrent: returns nextCheckInAt = diagnosticAttempt.completedAt + 7 days', async () => {
  const completedAt = new Date('2026-05-01T00:00:00Z');
  const expectedNext = new Date('2026-05-08T00:00:00Z').toISOString();

  const fakePlan = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'x',
    estimatedTotalHours: 10,
    weeklySchedule: [],
    milestones: [],
    source: 'llm-generated',
    updatedAt: new Date(),
  };

  const origPlanFind = Plan.findOne;
  Plan.findOne = () => ({ sort: () => ({ lean: async () => fakePlan }) });
  const DiagnosticAttempt = require('../models/DiagnosticAttempt');
  const origAttemptFind = DiagnosticAttempt.findById;
  DiagnosticAttempt.findById = () => ({ lean: async () => ({ completedAt }) });

  let captured;
  const res = {
    status: () => res,
    json: (body) => { captured = body; return res; },
  };
  const req = { user: { userId: fakePlan.userId.toString() } };

  try {
    await getCurrent(req, res);
    assert.strictEqual(captured.success, true);
    assert.strictEqual(captured.data.nextCheckInAt, expectedNext);
  } finally {
    Plan.findOne = origPlanFind;
    DiagnosticAttempt.findById = origAttemptFind;
  }
});
```

If the test file already has `getCurrent` imported, reuse that import — do not re-require.

- [ ] **Step 3: Run test to verify it fails**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/controllers/planController.test.js
```

Expected: FAIL — `captured.data.nextCheckInAt` is `undefined`.

- [ ] **Step 4: Implement `nextCheckInAt`**

Edit `scaleup-backend/src/controllers/planController.js` `getCurrent`. Replace the final `res.status(200).json(...)` block (currently at lines 74-84) with:

```javascript
  // Compute nextCheckInAt from the diagnostic attempt that produced this plan.
  // Falls back to plan.updatedAt if the attempt is missing (defensive only —
  // every plan should have a diagnosticAttemptId per the schema).
  let nextCheckInAt = null;
  try {
    const DiagnosticAttempt = require('../models/DiagnosticAttempt');
    const attempt = plan.diagnosticAttemptId
      ? await DiagnosticAttempt.findById(plan.diagnosticAttemptId).lean()
      : null;
    const anchor = attempt?.completedAt || plan.updatedAt;
    if (anchor) {
      nextCheckInAt = new Date(new Date(anchor).getTime() + 7 * 86400000).toISOString();
    }
  } catch (_) { /* leave null */ }

  return res.status(200).json(apiResponse.success({
    planId: String(plan._id),
    planHeadline: plan.planHeadline,
    totalWeeks: weeklySchedule.length,
    totalHours: plan.estimatedTotalHours || 0,
    milestoneCount: milestones.length,
    bufferRecommendation: plan.bufferRecommendation || null,
    weeklySchedule,
    milestones,
    source: plan.source,
    nextCheckInAt,
  }));
}
```

(Keep everything before the return block unchanged.)

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/controllers/planController.test.js
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/controllers/planController.js src/controllers/planController.test.js
git commit -m "feat(plan): surface nextCheckInAt on /plan/current"
```

---

## Task 4: Create `planProgressService` — quiz matcher

**Files:**
- Create: `scaleup-backend/src/services/plan/planProgressService.js`
- Create: `scaleup-backend/src/services/plan/planProgressService.test.js`

The service exposes `onQuizComplete({ userId, quizId, attemptId, topic })` and (Task 5) `onContentProgress({ userId, contentId, percent })`. This task implements `onQuizComplete` only.

Matching rule (per spec §3.3):
1. Find the user's active Plan.
2. Determine the "current week" — the smallest `week` whose `tasks[]` still contain a `pending` or `in_progress` task. If all earlier weeks are complete, use the next week with any task.
3. Within the current week, find the first task with `type === 'quiz'` and `topic.canonicalName === <quiz topic>` and `progress.status === 'pending'`. Mark it `complete`.
4. If no match in current week, search future weeks. If no match, return `{ matched: false }` — never retroactively complete past-week tasks.

- [ ] **Step 1: Create the test file with a failing test**

Create `scaleup-backend/src/services/plan/planProgressService.test.js`:

```javascript
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

delete require.cache[require.resolve('../../models/Plan')];
const Plan = require('../../models/Plan');
delete require.cache[require.resolve('./planProgressService')];
const planProgressService = require('./planProgressService');

function makePlanWithQuizTask({ status = 'pending', week = 1 } = {}) {
  return {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    weeklySchedule: [{
      week,
      weeklyGoal: 'g',
      allocations: [],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'quiz',
        topic: { canonicalName: 'product-strategy', displayName: 'Product Strategy' },
        payload: { quizId: 'qz-1' },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status, completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    save: async function () { this._saved = true; return this; },
  };
}

test('onQuizComplete: matches first pending quiz task in current week and marks complete', async () => {
  const plan = makePlanWithQuizTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    const out = await planProgressService.onQuizComplete({
      userId: plan.userId.toString(),
      quizId: 'qz-1',
      attemptId: 'att-99',
      topic: 'product-strategy',
    });
    assert.strictEqual(out.matched, true);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.status, 'complete');
    assert.ok(plan.weeklySchedule[0].tasks[0].progress.completedAt instanceof Date);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.sourceEventId, 'att-99');
    assert.strictEqual(plan._saved, true);
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('onQuizComplete: returns matched=false when no plan exists', async () => {
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => null });

  try {
    const out = await planProgressService.onQuizComplete({
      userId: new mongoose.Types.ObjectId().toString(),
      quizId: 'q', attemptId: 'a', topic: 't',
    });
    assert.strictEqual(out.matched, false);
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('onQuizComplete: returns matched=false when topic does not match any task', async () => {
  const plan = makePlanWithQuizTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    const out = await planProgressService.onQuizComplete({
      userId: plan.userId.toString(),
      quizId: 'qz-1', attemptId: 'a', topic: 'unrelated-topic',
    });
    assert.strictEqual(out.matched, false);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.status, 'pending');
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('onQuizComplete: does not retroactively complete past-week tasks', async () => {
  // Week 1 has a complete task; Week 2 has a pending non-matching task. A new
  // quiz event for the week-1 topic must NOT re-flip week 1.
  const plan = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    weeklySchedule: [
      {
        week: 1,
        weeklyGoal: 'g1',
        allocations: [],
        tasks: [{
          _id: new mongoose.Types.ObjectId(),
          type: 'quiz',
          topic: { canonicalName: 'product-strategy', displayName: 'Product Strategy' },
          payload: { quizId: 'qz-1' },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'complete', completedAt: new Date(), selfRating: null, sourceEventId: 'old' },
        }],
      },
      {
        week: 2,
        weeklyGoal: 'g2',
        allocations: [],
        tasks: [{
          _id: new mongoose.Types.ObjectId(),
          type: 'in_app_content',
          topic: { canonicalName: 'roadmapping', displayName: 'Roadmapping' },
          payload: { contentId: 'c1' },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending' },
        }],
      },
    ],
    save: async function () { this._saved = true; return this; },
  };
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    const out = await planProgressService.onQuizComplete({
      userId: plan.userId.toString(),
      quizId: 'qz-1', attemptId: 'new-att', topic: 'product-strategy',
    });
    assert.strictEqual(out.matched, false);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.sourceEventId, 'old');
  } finally {
    Plan.findOne = origFindOne;
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/services/plan/planProgressService.test.js
```

Expected: FAIL — `Cannot find module './planProgressService'`.

- [ ] **Step 3: Implement the service**

Create `scaleup-backend/src/services/plan/planProgressService.js`:

```javascript
const Plan = require('../../models/Plan');

const CONTENT_COMPLETE_THRESHOLD = 80;

// Find the "current week": the smallest week index that still has any
// pending/in_progress task. If every week is fully complete, returns null.
function findCurrentWeekIndex(plan) {
  for (let i = 0; i < plan.weeklySchedule.length; i++) {
    const w = plan.weeklySchedule[i];
    if ((w.tasks || []).some(t => t.progress?.status === 'pending' || t.progress?.status === 'in_progress')) {
      return i;
    }
  }
  return null;
}

// Find the first pending task in `week` matching predicate. Returns the task
// object (mutable, since plan is a hydrated mongoose doc) or null.
function findPendingTaskInWeek(week, predicate) {
  for (const task of (week.tasks || [])) {
    if (task.progress?.status !== 'pending') continue;
    if (predicate(task)) return task;
  }
  return null;
}

async function onQuizComplete({ userId, quizId, attemptId, topic }) {
  const plan = await Plan.findOne({ userId, isActive: true }).sort({ updatedAt: -1 });
  if (!plan) return { matched: false, reason: 'no_active_plan' };

  const startIdx = findCurrentWeekIndex(plan);
  if (startIdx === null) return { matched: false, reason: 'all_weeks_complete' };

  // Search current week first, then future weeks. Never search past weeks.
  for (let i = startIdx; i < plan.weeklySchedule.length; i++) {
    const week = plan.weeklySchedule[i];
    const match = findPendingTaskInWeek(
      week,
      t => t.type === 'quiz' && t.topic?.canonicalName === topic,
    );
    if (match) {
      match.progress.status = 'complete';
      match.progress.completedAt = new Date();
      match.progress.sourceEventId = String(attemptId);
      await plan.save();
      return { matched: true, planId: String(plan._id), weekNumber: week.week, taskId: String(match._id) };
    }
  }

  return { matched: false, reason: 'no_matching_task' };
}

module.exports = {
  onQuizComplete,
  // Internal exports for unit tests
  _internal: { findCurrentWeekIndex, findPendingTaskInWeek, CONTENT_COMPLETE_THRESHOLD },
};
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/services/plan/planProgressService.test.js
```

Expected: all four tests PASS.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/plan/
git commit -m "feat(plan): planProgressService.onQuizComplete with matching rule"
```

---

## Task 5: `planProgressService.onContentProgress` (≥80% threshold)

**Files:**
- Modify: `scaleup-backend/src/services/plan/planProgressService.js`
- Modify: `scaleup-backend/src/services/plan/planProgressService.test.js`

`onContentProgress({ userId, contentId, percent, topic })` marks the matching `in_app_content` task complete only when `percent ≥ 80`. Below threshold, it bumps `progress.status` from `pending` → `in_progress` so the UI can show "started" state, but does not mark complete.

- [ ] **Step 1: Add failing tests**

Append to `scaleup-backend/src/services/plan/planProgressService.test.js`:

```javascript
function makePlanWithContentTask() {
  return {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'g',
      allocations: [],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'in_app_content',
        topic: { canonicalName: 'roadmapping', displayName: 'Roadmapping' },
        payload: { contentId: 'c-42' },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    save: async function () { this._saved = true; return this; },
  };
}

test('onContentProgress: at 79% bumps pending -> in_progress (not complete)', async () => {
  const plan = makePlanWithContentTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    const out = await planProgressService.onContentProgress({
      userId: plan.userId.toString(),
      contentId: 'c-42', percent: 79, topic: 'roadmapping',
    });
    assert.strictEqual(out.matched, true);
    assert.strictEqual(out.completed, false);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.status, 'in_progress');
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.completedAt, null);
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('onContentProgress: at 80% marks complete', async () => {
  const plan = makePlanWithContentTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    const out = await planProgressService.onContentProgress({
      userId: plan.userId.toString(),
      contentId: 'c-42', percent: 80, topic: 'roadmapping',
    });
    assert.strictEqual(out.matched, true);
    assert.strictEqual(out.completed, true);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.status, 'complete');
    assert.ok(plan.weeklySchedule[0].tasks[0].progress.completedAt instanceof Date);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.sourceEventId, 'c-42');
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('onContentProgress: returns matched=false when contentId in payload does not match', async () => {
  const plan = makePlanWithContentTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    const out = await planProgressService.onContentProgress({
      userId: plan.userId.toString(),
      contentId: 'unrelated', percent: 90, topic: 'roadmapping',
    });
    assert.strictEqual(out.matched, false);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.status, 'pending');
  } finally {
    Plan.findOne = origFindOne;
  }
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/services/plan/planProgressService.test.js
```

Expected: 3 new tests FAIL — `planProgressService.onContentProgress is not a function`.

- [ ] **Step 3: Implement `onContentProgress`**

Edit `scaleup-backend/src/services/plan/planProgressService.js`. Add this function above `module.exports`:

```javascript
async function onContentProgress({ userId, contentId, percent, topic }) {
  const plan = await Plan.findOne({ userId, isActive: true }).sort({ updatedAt: -1 });
  if (!plan) return { matched: false, reason: 'no_active_plan' };

  const startIdx = findCurrentWeekIndex(plan);
  if (startIdx === null) return { matched: false, reason: 'all_weeks_complete' };

  for (let i = startIdx; i < plan.weeklySchedule.length; i++) {
    const week = plan.weeklySchedule[i];
    const match = findPendingTaskInWeek(
      week,
      t => t.type === 'in_app_content'
        && t.topic?.canonicalName === topic
        && String(t.payload?.contentId || '') === String(contentId),
    );
    if (!match) {
      // Also accept "in_progress" status — content may already have been bumped
      const inProgress = (week.tasks || []).find(
        t => t.type === 'in_app_content'
          && t.progress?.status === 'in_progress'
          && t.topic?.canonicalName === topic
          && String(t.payload?.contentId || '') === String(contentId),
      );
      if (!inProgress) continue;
      // Reuse the same flow with the in-progress task
      if (percent >= CONTENT_COMPLETE_THRESHOLD) {
        inProgress.progress.status = 'complete';
        inProgress.progress.completedAt = new Date();
        inProgress.progress.sourceEventId = String(contentId);
        await plan.save();
        return { matched: true, completed: true, planId: String(plan._id), weekNumber: week.week };
      }
      return { matched: true, completed: false, planId: String(plan._id), weekNumber: week.week };
    }

    if (percent >= CONTENT_COMPLETE_THRESHOLD) {
      match.progress.status = 'complete';
      match.progress.completedAt = new Date();
      match.progress.sourceEventId = String(contentId);
      await plan.save();
      return { matched: true, completed: true, planId: String(plan._id), weekNumber: week.week };
    }

    match.progress.status = 'in_progress';
    await plan.save();
    return { matched: true, completed: false, planId: String(plan._id), weekNumber: week.week };
  }

  return { matched: false, reason: 'no_matching_task' };
}
```

Update the `module.exports`:

```javascript
module.exports = {
  onQuizComplete,
  onContentProgress,
  _internal: { findCurrentWeekIndex, findPendingTaskInWeek, CONTENT_COMPLETE_THRESHOLD },
};
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test -- src/services/plan/planProgressService.test.js
```

Expected: all 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/plan/
git commit -m "feat(plan): planProgressService.onContentProgress with 80% threshold"
```

---

## Task 6: Wire `onQuizComplete` into knowledgeService

**Files:**
- Modify: `scaleup-backend/src/services/knowledgeService.js`

`updateFromQuizAttempt` is already called after quiz scoring. Append a non-blocking call to `planProgressService.onQuizComplete` so an unrelated failure inside the plan match doesn't poison the knowledge update.

- [ ] **Step 1: Find the right place to insert the call**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && grep -n "journeyAdaptationQueue\|return profile\|module.exports" src/services/knowledgeService.js | head -20
```

Find the line at the end of `updateFromQuizAttempt` (after the `journeyAdaptationQueue.add(...)` call, just before `return profile`).

- [ ] **Step 2: Add the lazy require at the top of the file**

In `scaleup-backend/src/services/knowledgeService.js`, do NOT add a top-level require (would break the existing test stubs). Use a lazy `require` inside the function — same pattern as `recalibrationEligibilityService.js:76`.

- [ ] **Step 3: Insert the call before `return profile;` in `updateFromQuizAttempt`**

Locate the final lines of `updateFromQuizAttempt` (just before `return profile;`). Insert:

```javascript
    // Update plan task progress for quiz completion (best-effort).
    // We use the quiz's main topic as the canonical match key; the task's
    // topic.canonicalName is set at plan-generation time from the same
    // topic taxonomy, so a string match is correct.
    try {
      const planProgressService = require('./plan/planProgressService');
      await planProgressService.onQuizComplete({
        userId,
        quizId: String(quiz._id),
        attemptId: String(attempt._id),
        topic: quiz.topic,
      });
    } catch (err) {
      console.warn('[knowledgeService] planProgressService.onQuizComplete failed:', err.message);
    }
```

- [ ] **Step 4: Verify the file still parses**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node -e "require('./src/services/knowledgeService.js'); console.log('ok')"
```

Expected: prints `ok` (no SyntaxError, no missing-module error).

- [ ] **Step 5: Run the existing knowledgeService tests, if any**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && ls src/services/knowledgeService.test.js 2>/dev/null && npm test -- src/services/knowledgeService.test.js || echo "no existing tests — skipping"
```

Expected: PASS or "no existing tests".

- [ ] **Step 6: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/knowledgeService.js
git commit -m "feat(plan): wire planProgressService into quiz scoring"
```

---

## Task 7: Wire `onContentProgress` into consumptionService

**Files:**
- Modify: `scaleup-backend/src/services/consumptionService.js`

Two integration points:
- `updateProgress` — fires per progress tick. Call `onContentProgress` with computed `percentageCompleted`.
- `markCompleted` — explicit completion. Call `onContentProgress` with `percent: 100`.

The content task carries `topic.canonicalName` set at plan-gen time. We pass the `Content.topics[0]` (existing field — see content model) as the topic key.

- [ ] **Step 1: Confirm `Content.topics` is the right field**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && grep -n "topics" src/models/Content.js | head -5
```

Expected: a `topics: [String]` field on the Content schema. (If the actual field name differs, use that name in step 3.)

- [ ] **Step 2: Find the insertion points**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && grep -n "await progress.save\|return progress\|isCompleted: true" src/services/consumptionService.js | head -10
```

You're targeting:
- End of `updateProgress` (just before `return progress;` at ~line 42).
- End of `markCompleted` (just before `await this.updateConsumptionGraph(...)` at ~line 52, OR at the very end before `return progress`/end of method).

- [ ] **Step 3: Patch `updateProgress`**

In `scaleup-backend/src/services/consumptionService.js`, just before `return progress;` at the end of `updateProgress`, insert:

```javascript
    // Best-effort plan task progress update.
    try {
      const planProgressService = require('./plan/planProgressService');
      const topic = (content?.topics && content.topics[0]) || null;
      if (topic) {
        await planProgressService.onContentProgress({
          userId,
          contentId: String(contentId),
          percent: progress.percentageCompleted || 0,
          topic,
        });
      }
    } catch (err) {
      console.warn('[consumptionService] planProgressService.onContentProgress failed:', err.message);
    }
```

- [ ] **Step 4: Patch `markCompleted`**

At the end of `markCompleted`, immediately before the `return progress;` (or at the very end of the method body if it doesn't currently return progress — check the file), insert:

```javascript
    try {
      const planProgressService = require('./plan/planProgressService');
      const Content = require('../models/Content');
      const content = await Content.findById(contentId).lean();
      const topic = (content?.topics && content.topics[0]) || null;
      if (topic) {
        await planProgressService.onContentProgress({
          userId,
          contentId: String(contentId),
          percent: 100,
          topic,
        });
      }
    } catch (err) {
      console.warn('[consumptionService] planProgressService.onContentProgress (markCompleted) failed:', err.message);
    }
```

- [ ] **Step 5: Verify the file parses**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node -e "require('./src/services/consumptionService.js'); console.log('ok')"
```

Expected: `ok`.

- [ ] **Step 6: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/consumptionService.js
git commit -m "feat(plan): wire planProgressService into content progress + completion"
```

---

## Task 8: iOS — handle `failed` plan status

**Files:**
- Modify: `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift`
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift`

Today the switch in `load()` defaults `failed` → `.generating`, so the user sees a permanent spinner. Add an explicit case that surfaces a recoverable error.

- [ ] **Step 1: Update the view model**

Edit `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift`. Replace the `switch status.status { ... }` block (lines 29-40) with:

```swift
            switch status.status {
            case "ready", "completed":
                let plan = try await service.fetchCurrent()
                loadState = .ready(plan)
                if plan.source == .template {
                    AnalyticsService.shared.track(.planGenerationFallback(reason: "server_template"))
                }
            case "generating", "pending":
                loadState = .generating
            case "failed":
                loadState = .error("We couldn't build your plan. Tap Retry to try again.")
                AnalyticsService.shared.track(.planGenerationFallback(reason: "server_failed"))
            default:
                loadState = .generating
            }
```

- [ ] **Step 2: Inspect how `.error` is currently rendered**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && grep -n "case .error\|PlanLoadState\|errorView\|error(let" ScaleUp/Features/Plan/Views/PlanTabView.swift | head -20
```

If `PlanTabView` already has an `.error(let message)` branch with a Retry button, this step is a no-op — skip to step 4.

- [ ] **Step 3: Add an error card if missing**

If step 2 showed no `.error` branch (or only a minimal one), in `ScaleUp/Features/Plan/Views/PlanTabView.swift`, find the `switch viewModel.loadState` block and ensure the `.error(let message)` case renders something like:

```swift
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Something went wrong")
                        .font(.title3.bold())
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await viewModel.retry() }
                    } label: {
                        Text("Retry")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
```

(Match existing project style — if the codebase has a reusable `ErrorView` component, use that instead of inlining.)

- [ ] **Step 4: Build the iOS app**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`. If the build fails on unrelated files, fix them or note that the change at minimum compiles within the Plan feature.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift ScaleUp/Features/Plan/Views/PlanTabView.swift
git commit -m "fix(ios-plan): handle failed plan status with recoverable error card"
```

---

## Task 9: Phase 1 acceptance — full test sweep

Final guardrail before declaring Phase 1 done. Runs every backend test that this phase touched plus a one-shot smoke that boots the server.

- [ ] **Step 1: Run the full backend test suite**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test 2>&1 | tail -50
```

Expected: every test passes. If a pre-existing test is red and unrelated to Phase 1, note it but do not fix here — it belongs to its own task.

- [ ] **Step 2: Lint OpenAPI spec (the new `nextCheckInAt` field)**

The OpenAPI spec for `GET /plan/current` should be updated to include the new field. Open `scaleup-backend/openapi.yaml`, find the response schema for `GET /api/v1/plan/current`, and add:

```yaml
                nextCheckInAt:
                  type: string
                  format: date-time
                  nullable: true
                  description: ISO timestamp of the next recalibration check-in (lastDiagnosticCompletedAt + 7 days). Null when the plan has no associated diagnostic attempt.
```

Then:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm run openapi:lint 2>&1 | tail -20
```

Expected: 0 errors. Warnings unrelated to this PR are fine.

- [ ] **Step 3: Regenerate iOS OpenAPI types so `nextCheckInAt` appears on `APIPlanCurrent` (or whatever the generated name is)**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && bash scripts/regenerate-openapi-types.sh 2>&1 | tail -20
```

(Path of the script is per the working directory's `scripts/` folder. If named differently, adjust.) Expected: script exits 0 and the generated Swift file diff shows the new field.

- [ ] **Step 4: Decode the new field on iOS**

In `ScaleUp/Features/Plan/Services/PlanService.swift` (or wherever `PlanDTO` is hand-rolled if the generated type isn't used), ensure `nextCheckInAt: Date?` (or `String?`) is part of the DTO. If it's already in the generated type and `PlanDTO` is a typealias to the generated type, no change is needed.

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && grep -n "PlanDTO\|nextCheckInAt" ScaleUp/Features/Plan/Services/PlanService.swift | head -10
```

If `PlanDTO` is hand-rolled and missing the field, add it as `let nextCheckInAt: String?`.

- [ ] **Step 5: Build iOS one more time**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit OpenAPI + iOS DTO updates**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add openapi.yaml
git commit -m "docs(openapi): document nextCheckInAt on /plan/current"

cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Generated ScaleUp/Features/Plan/Services/PlanService.swift 2>/dev/null
git diff --cached --quiet || git commit -m "feat(ios): regenerate types + decode nextCheckInAt on PlanDTO"
```

(The `git diff --cached --quiet || git commit` pattern skips an empty commit if the generator + DTO already had the field via Phase-0 wiring.)

---

## What Phase 1 ships

After this plan executes:
- Plans persist `tasks[]` per week (currently empty arrays — Phase 2 fills them).
- A user finishing a quiz on a topic auto-marks the matching `quiz` task complete (when one exists).
- A user reaching ≥80% on a piece of in-app content auto-marks the matching `in_app_content` task complete.
- `GET /plan/current` returns `nextCheckInAt` so iOS can render the "Next check-in: in N days" pill.
- `MIN_DAYS_SINCE_LAST = 7` means recalibration eligibility opens after one week.
- iOS no longer spins forever on failed plans — users see an error card with Retry.

**What Phase 1 does NOT ship:**
- Plans are still generated *without* `tasks[]` — the generator still emits the descriptive shape. Phase 2 changes the generator to emit quiz + content tasks.
- The Plan tab UI still renders the old descriptive layout. Phase 2 adds the task list UI.
- Interview / competition / external_link / manual tasks. Phases 3-4.

Phase 2 is the next plan. It fills `tasks[]` from `planGenerationService.generate` and renders the task list.

---

## Self-review checklist (already applied)

- ✅ Spec coverage: every Phase-1 bullet from spec §7 maps to at least one task. (Plan-model expansion → Task 1; planProgressService skeleton → Tasks 4+5; cooldown 30→7 → Task 2; nextCheckInAt → Task 3; iOS failed-state → Task 8.)
- ✅ Placeholder scan: no TBD / TODO / "implement later" left in the plan.
- ✅ Type consistency: `topic.canonicalName` matched on every call site; `progress.status` enum values consistent (`pending` / `in_progress` / `complete` / `skipped`); `payload.contentId` / `payload.quizId` referenced consistently.
