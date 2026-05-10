# Plan Tab Redesign — Phase 3: Interview / Competition / Manual + Completion Sheet

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the remaining task types — `ai_interview` (gated on objectiveType ∈ {`interview_preparation`, `career_switch`}), `competition` (all objectives), and `manual` (fallback when no in-app resource matches a topic). Wire auto-completion for interview/competition via existing write sites. Add a manual-completion path with self-rating chips for `manual` and `external_link` (the latter ships in Phase 4 but the wiring is shared).

**Architecture:**
- Backend generator emits the three new task types in the same post-processor that emits quiz + content tasks. Interview/competition tasks are *abstract* — payload carries scenario/topic hints, not entity IDs (because interview sessions are user-generated, and daily competition challenges rotate). Tap-to-launch routes the user into the existing setup screens with the topic prefilled.
- `planProgressService` gains three new functions: `onInterviewComplete`, `onCompetitionPlayed`, and `markManualComplete(taskId, selfRating)`. The first two follow the same matcher rule as `onQuizComplete`. Manual completion is keyed by explicit task ID from the client.
- New HTTP endpoint `POST /api/v1/plan/tasks/:taskId/complete` accepts `{ selfRating: 1-5 }` and calls `markManualComplete`. Used by the iOS/Android completion sheet.
- iOS + Android both gain a `ManualCompletionSheet` component (5 chips, confirm) wired to the new endpoint. Tap routing extended for the new task types.

**Tech Stack:** Node 18 + Mongoose + Express, `node:test`; Swift 5 + SwiftUI; React Native + TypeScript.

**Spec:** `docs/superpowers/specs/2026-05-09-plan-tab-redesign-design.md` (commit `df0068f`). Phase 3 covers spec §4 task types matrix (interview/competition/manual rows) and §7 phase 3.

**Phase 1 + 2 + 2.5 prerequisite (all on master/main):**
- Backend: Phase 2 acceptance HEAD `e7ab2af`
- iOS: Phase 2.5 tap-to-launch HEAD `543ea19`
- Android: Phase 2.5 follow-ups HEAD `ee05895`

**Repo layout:**
- Backend: `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/`
- Android: `/Users/nirpekshnandan/My Products/ScaleUpAndroid/`

---

## File Structure

**Created:**
- `ScaleUp/Features/Plan/Views/Components/ManualCompletionSheet.swift`
- `ScaleUp/Features/Plan/Services/PlanCompletionService.swift` (or method on existing `PlanService`)
- `ScaleUpAndroid/src/screens/plan/components/ManualCompletionSheet.tsx`

**Modified:**
- `scaleup-backend/src/services/diagnostic/planGenerationService.js` — extend post-processor for 3 new task types.
- `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`
- `scaleup-backend/src/services/plan/planProgressService.js` — add `onInterviewComplete`, `onCompetitionPlayed`, `markManualComplete`.
- `scaleup-backend/src/services/plan/planProgressService.test.js`
- `scaleup-backend/src/services/interviewService.js` — call `planProgressService.onInterviewComplete` after eval.
- `scaleup-backend/src/services/competitionService.js` — call `planProgressService.onCompetitionPlayed` from `completeChallenge`.
- `scaleup-backend/src/controllers/planController.js` — add `markTaskComplete` handler.
- `scaleup-backend/src/controllers/planController.test.js`
- `scaleup-backend/src/routes/plan.js` — wire `POST /tasks/:taskId/complete`.
- `scaleup-backend/openapi.yaml` — document the new endpoint.
- `ScaleUp/Features/Plan/Services/PlanService.swift` — add `markTaskComplete(taskId:selfRating:)` method.
- `ScaleUp/Features/Plan/Views/PlanTabView.swift` — extend `handleTaskTap` for interview/competition/manual.
- `ScaleUpAndroid/src/services/planService.ts` — add `markTaskComplete` function.
- `ScaleUpAndroid/src/screens/plan/PlanTabScreen.tsx` — extend `handleTaskTap` + present completion sheet.

Each task ends with a commit. Backend tests use `node:test`.

---

## Task 1: Backend — generator emits `ai_interview`, `competition`, `manual`

**Files:**
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.js`
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`

The existing post-processor (Phase 2) walks `weeklySchedule[i].allocations[]` and emits `quiz` + `in_app_content` tasks. Extend it:

- For each allocation, ALSO emit:
  - `ai_interview` task IF `input.objectiveType` is `'interview_preparation'` OR `'career_switch'`. Payload: `{ scenario, estimatedMinutes }` where `scenario` is derived from objective specifics (default `'placement_behavioral'`; `'placement_technical'` if specifics suggest a tech role; `'mba_admissions'` if objective specifics include an MBA hint).
  - `competition` task ALWAYS. Payload: `{ topicCanonicalName, estimatedMinutes: 8 }`. Tap launches the competition tab filtered by topic.
- If a topic resolves to NO `quiz` AND NO `content` AND NO `ai_interview` (i.e., the only thing emitted would be a competition), ALSO emit a `manual` task. Payload: `{ title: \`Practice \${displayName} on your own\`, description: \`Spend ~30 minutes deepening your understanding of \${displayName}. Reading, exercises, or applying it to a real problem all count.\`, estimatedMinutes: 30 }`. Manual tasks have `completion: { mode: 'manual', requiresSelfRating: true }`.

This keeps the per-allocation task count bounded: 0-4 tasks per topic per week (quiz, content, interview, competition) plus an optional manual fallback.

- [ ] **Step 1: Add failing tests**

Append to `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`:

```javascript
test('generate: emits ai_interview task only when objectiveType is interview_preparation or career_switch', async () => {
  const planService = require('./planGenerationService');
  const mongoose = require('mongoose');
  const openai = require('../../config/openai');
  const origCreate = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('test stub'); };

  const taskCatalogService = require('../plan/taskCatalogService');
  const origResolve = taskCatalogService.resolveTopic;
  taskCatalogService.resolveTopic = async () => ({
    quizId: 'qz1', quizMinutes: 10,
    contentId: 'c1', contentType: 'article', contentMinutes: 12,
  });

  try {
    for (const objType of ['interview_preparation', 'career_switch']) {
      const out = await planService.generate({
        userId: new mongoose.Types.ObjectId(),
        objectiveId: new mongoose.Types.ObjectId(),
        diagnosticAttemptId: new mongoose.Types.ObjectId(),
        objectiveType: objType,
        specificsCanonical: { targetRole: 'product-manager' },
        timeline: 2, weeklyCommitHours: 5,
        topicResults: [{ canonicalName: 'product-strategy', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false }],
      });
      const w0 = out.weeklySchedule[0];
      assert.ok(w0.tasks.some(t => t.type === 'ai_interview'), `${objType} should emit ai_interview`);
    }

    const out2 = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'upskilling',
      specificsCanonical: { targetSkill: 'react' },
      timeline: 2, weeklyCommitHours: 5,
      topicResults: [{ canonicalName: 'react-hooks', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false }],
    });
    const w0b = out2.weeklySchedule[0];
    assert.ok(!w0b.tasks.some(t => t.type === 'ai_interview'), 'upskilling should NOT emit ai_interview');
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
  }
});

test('generate: emits competition task for every topic regardless of objective', async () => {
  const planService = require('./planGenerationService');
  const mongoose = require('mongoose');
  const openai = require('../../config/openai');
  const origCreate = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('test stub'); };

  const taskCatalogService = require('../plan/taskCatalogService');
  const origResolve = taskCatalogService.resolveTopic;
  taskCatalogService.resolveTopic = async () => ({ quizId: 'qz1', quizMinutes: 10, contentId: null });

  try {
    const out = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'casual_learning',
      specificsCanonical: {},
      timeline: 2, weeklyCommitHours: 5,
      topicResults: [{ canonicalName: 'general-knowledge', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false }],
    });
    const w0 = out.weeklySchedule[0];
    const competitionTask = w0.tasks.find(t => t.type === 'competition');
    assert.ok(competitionTask, 'every topic should emit a competition task');
    assert.strictEqual(competitionTask.payload.topicCanonicalName, 'general-knowledge');
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
  }
});

test('generate: emits manual fallback when topic has no quiz/content/interview', async () => {
  const planService = require('./planGenerationService');
  const mongoose = require('mongoose');
  const openai = require('../../config/openai');
  const origCreate = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('test stub'); };

  const taskCatalogService = require('../plan/taskCatalogService');
  const origResolve = taskCatalogService.resolveTopic;
  taskCatalogService.resolveTopic = async () => ({ quizId: null, contentId: null });

  try {
    const out = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'upskilling', // not eligible for interview
      specificsCanonical: { targetSkill: 'rare-skill' },
      timeline: 2, weeklyCommitHours: 5,
      topicResults: [{ canonicalName: 'unmapped-topic', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false }],
    });
    const w0 = out.weeklySchedule[0];
    const manualTask = w0.tasks.find(t => t.type === 'manual');
    assert.ok(manualTask, 'should emit manual fallback when nothing else resolved');
    assert.strictEqual(manualTask.completion.mode, 'manual');
    assert.strictEqual(manualTask.completion.requiresSelfRating, true);
    assert.ok(manualTask.payload.title, 'manual task needs a title');
    assert.ok(manualTask.payload.estimatedMinutes > 0);
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
  }
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/diagnostic/planGenerationService.test.js
```

Expected: 3 new tests fail.

- [ ] **Step 3: Extend the post-processor**

Open `scaleup-backend/src/services/diagnostic/planGenerationService.js`. Find the existing post-processor (the `for (const week of plan.weeklySchedule)` loop added in Phase 2 Task 2). Inside the inner loop after the `if (resolved.contentId)` block, BEFORE the `}` that closes the per-allocation loop, insert:

```javascript
      // ai_interview — gated on interview-style objectives
      const interviewObjectives = ['interview_preparation', 'career_switch'];
      const emitsInterview = interviewObjectives.includes(input.objectiveType);
      if (emitsInterview) {
        // Pick a scenario from objective specifics. Default: behavioral.
        const targetRoleLower = String(input.specificsCanonical?.targetRole || '').toLowerCase();
        let scenario = 'placement_behavioral';
        if (input.objectiveType === 'interview_preparation' && targetRoleLower.includes('mba')) {
          scenario = 'mba_admissions';
        } else if (/engineer|developer|programmer|data|ml|software/.test(targetRoleLower)) {
          scenario = 'placement_technical';
        }
        tasks.push({
          type: 'ai_interview',
          topic: topicShape,
          payload: { scenario, estimatedMinutes: 15 },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
        });
      }

      // competition — emit for every topic; payload is abstract (filter by topic at tap time)
      tasks.push({
        type: 'competition',
        topic: topicShape,
        payload: { topicCanonicalName: alloc.topicCanonicalName, estimatedMinutes: 8 },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      });

      // manual fallback — only when nothing else resolved for this topic
      const emittedNonCompetition = !!resolved.quizId || !!resolved.contentId || emitsInterview;
      if (!emittedNonCompetition) {
        tasks.push({
          type: 'manual',
          topic: topicShape,
          payload: {
            title: `Practice ${displayName} on your own`,
            description: `Spend ~30 minutes deepening your understanding of ${displayName}. Reading, exercises, or applying it to a real problem all count.`,
            estimatedMinutes: 30,
          },
          completion: { mode: 'manual', requiresSelfRating: true },
          progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
        });
      }
```

(Make sure these blocks are positioned where `topicShape` and `displayName` are still in scope — same loop level as the existing quiz/content emissions.)

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/diagnostic/planGenerationService.test.js
```

Expected: ALL tests pass.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/diagnostic/planGenerationService.js src/services/diagnostic/planGenerationService.test.js
git commit -m "feat(plan): generator emits ai_interview, competition, manual tasks"
```

---

## Task 2: Backend — `planProgressService` adds 3 new functions

**Files:**
- Modify: `scaleup-backend/src/services/plan/planProgressService.js`
- Modify: `scaleup-backend/src/services/plan/planProgressService.test.js`

Add three new exports:
- `onInterviewComplete({ userId, sessionId, topic })` — same matcher rule as `onQuizComplete` but matches `type === 'ai_interview'`. Marks complete with `sourceEventId = String(sessionId)`.
- `onCompetitionPlayed({ userId, challengeId, topic })` — matches `type === 'competition'`. Marks complete with `sourceEventId = String(challengeId)`.
- `markManualComplete({ userId, taskId, selfRating })` — different shape: takes a specific `taskId`, finds the matching task across the active plan (any week), validates the user owns the plan, validates `selfRating` is in 1-5, marks complete with `progress.selfRating = selfRating` and `progress.sourceEventId = 'manual_' + Date.now()`. Returns `{ matched: true, planId, weekNumber, taskId }` on success or `{ matched: false, reason }`.

`markManualComplete` should ALSO accept tasks of type `external_link` (Phase 4 will use it). The function shouldn't restrict by type — only the API endpoint will gate which task types are completable manually.

`markManualComplete` must update `KnowledgeProfile.topicSelfRatings[canonicalName]` with the new self-rating value. Apply the same lazy-require pattern used elsewhere:

```javascript
try {
  const KnowledgeProfile = require('../../models/KnowledgeProfile');
  await KnowledgeProfile.updateOne(
    { userId },
    { $set: { [`topicSelfRatings.${task.topic.canonicalName}`]: selfRating } },
    { upsert: true }
  );
} catch (err) {
  console.warn('[planProgressService] KnowledgeProfile update failed:', err.message);
}
```

Reuse the existing `withVersionRetry` helper from Fix 3.

- [ ] **Step 1: Add failing tests**

Append to `scaleup-backend/src/services/plan/planProgressService.test.js`:

```javascript
function makePlanWithInterviewTask() {
  return {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'g',
      allocations: [],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'ai_interview',
        topic: { canonicalName: 'product-strategy', displayName: 'Product Strategy' },
        payload: { scenario: 'placement_behavioral', estimatedMinutes: 15 },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    save: async function () { this._saved = true; return this; },
  };
}

function makePlanWithCompetitionTask() {
  return {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'g',
      allocations: [],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'competition',
        topic: { canonicalName: 'product-strategy', displayName: 'Product Strategy' },
        payload: { topicCanonicalName: 'product-strategy', estimatedMinutes: 8 },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    save: async function () { this._saved = true; return this; },
  };
}

function makePlanWithManualTask() {
  return {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'g',
      allocations: [],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'manual',
        topic: { canonicalName: 'product-strategy', displayName: 'Product Strategy' },
        payload: { title: 'Practice on your own', description: 'x', estimatedMinutes: 30 },
        completion: { mode: 'manual', requiresSelfRating: true },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    save: async function () { this._saved = true; return this; },
  };
}

test('onInterviewComplete: matches ai_interview task and marks complete', async () => {
  const plan = makePlanWithInterviewTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });
  try {
    const out = await planProgressService.onInterviewComplete({
      userId: plan.userId.toString(),
      sessionId: 'sess-99',
      topic: 'product-strategy',
    });
    assert.strictEqual(out.matched, true);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.status, 'complete');
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.sourceEventId, 'sess-99');
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('onCompetitionPlayed: matches competition task and marks complete', async () => {
  const plan = makePlanWithCompetitionTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });
  try {
    const out = await planProgressService.onCompetitionPlayed({
      userId: plan.userId.toString(),
      challengeId: 'ch-99',
      topic: 'product-strategy',
    });
    assert.strictEqual(out.matched, true);
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.status, 'complete');
    assert.strictEqual(plan.weeklySchedule[0].tasks[0].progress.sourceEventId, 'ch-99');
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('markManualComplete: marks task complete with selfRating', async () => {
  const plan = makePlanWithManualTask();
  const taskId = plan.weeklySchedule[0].tasks[0]._id.toString();

  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });
  try {
    const out = await planProgressService.markManualComplete({
      userId: plan.userId.toString(),
      taskId,
      selfRating: 4,
    });
    assert.strictEqual(out.matched, true);
    const task = plan.weeklySchedule[0].tasks[0];
    assert.strictEqual(task.progress.status, 'complete');
    assert.strictEqual(task.progress.selfRating, 4);
    assert.ok(task.progress.completedAt instanceof Date);
    assert.ok(typeof task.progress.sourceEventId === 'string' && task.progress.sourceEventId.startsWith('manual_'));
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('markManualComplete: rejects selfRating outside 1-5', async () => {
  const plan = makePlanWithManualTask();
  const taskId = plan.weeklySchedule[0].tasks[0]._id.toString();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });
  try {
    const out = await planProgressService.markManualComplete({
      userId: plan.userId.toString(),
      taskId,
      selfRating: 99,
    });
    assert.strictEqual(out.matched, false);
    assert.strictEqual(out.reason, 'invalid_self_rating');
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('markManualComplete: returns matched=false when taskId not in plan', async () => {
  const plan = makePlanWithManualTask();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });
  try {
    const out = await planProgressService.markManualComplete({
      userId: plan.userId.toString(),
      taskId: new mongoose.Types.ObjectId().toString(),
      selfRating: 3,
    });
    assert.strictEqual(out.matched, false);
    assert.strictEqual(out.reason, 'task_not_found');
  } finally {
    Plan.findOne = origFindOne;
  }
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/planProgressService.test.js
```

Expected: 5 new tests fail.

- [ ] **Step 3: Implement the three functions**

Edit `scaleup-backend/src/services/plan/planProgressService.js`. Add three new functions, mirroring the structure of `onQuizComplete`. Use the existing `withVersionRetry`, `findCurrentWeekIndex`, and `findPendingTaskInWeek` helpers.

```javascript
async function onInterviewComplete({ userId, sessionId, topic }) {
  const topicKey = canonicalize(topic);
  if (!topicKey) return { matched: false, reason: 'no_topic' };

  return withVersionRetry(
    () => Plan.findOne({ userId, isActive: true }).sort({ updatedAt: -1 }),
    async (plan) => {
      const startIdx = findCurrentWeekIndex(plan);
      if (startIdx === null) return { matched: false, reason: 'all_weeks_complete' };
      for (let i = startIdx; i < plan.weeklySchedule.length; i++) {
        const week = plan.weeklySchedule[i];
        const match = findPendingTaskInWeek(
          week,
          t => t.type === 'ai_interview' && canonicalize(t.topic?.canonicalName) === topicKey,
        );
        if (match) {
          const snap = snapshotProgress(match);
          match.progress.status = 'complete';
          match.progress.completedAt = new Date();
          match.progress.sourceEventId = String(sessionId);
          await saveWithRevert(plan, match, snap);
          return { matched: true, planId: String(plan._id), weekNumber: week.week, taskId: String(match._id) };
        }
      }
      return { matched: false, reason: 'no_matching_task' };
    },
  );
}

async function onCompetitionPlayed({ userId, challengeId, topic }) {
  const topicKey = canonicalize(topic);
  if (!topicKey) return { matched: false, reason: 'no_topic' };

  return withVersionRetry(
    () => Plan.findOne({ userId, isActive: true }).sort({ updatedAt: -1 }),
    async (plan) => {
      const startIdx = findCurrentWeekIndex(plan);
      if (startIdx === null) return { matched: false, reason: 'all_weeks_complete' };
      for (let i = startIdx; i < plan.weeklySchedule.length; i++) {
        const week = plan.weeklySchedule[i];
        const match = findPendingTaskInWeek(
          week,
          t => t.type === 'competition' && canonicalize(t.topic?.canonicalName) === topicKey,
        );
        if (match) {
          const snap = snapshotProgress(match);
          match.progress.status = 'complete';
          match.progress.completedAt = new Date();
          match.progress.sourceEventId = String(challengeId);
          await saveWithRevert(plan, match, snap);
          return { matched: true, planId: String(plan._id), weekNumber: week.week, taskId: String(match._id) };
        }
      }
      return { matched: false, reason: 'no_matching_task' };
    },
  );
}

async function markManualComplete({ userId, taskId, selfRating }) {
  const rating = Number(selfRating);
  if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
    return { matched: false, reason: 'invalid_self_rating' };
  }

  return withVersionRetry(
    () => Plan.findOne({ userId, isActive: true }).sort({ updatedAt: -1 }),
    async (plan) => {
      // Find the task across all weeks (not just current — manual completes
      // can be back-fills of a missed week). Validate the task belongs to
      // this plan (it must, since the query was scoped to userId).
      let foundWeek = null;
      let foundTask = null;
      for (const week of plan.weeklySchedule) {
        for (const task of (week.tasks || [])) {
          if (String(task._id) === String(taskId)) {
            foundWeek = week;
            foundTask = task;
            break;
          }
        }
        if (foundTask) break;
      }
      if (!foundTask) return { matched: false, reason: 'task_not_found' };

      const snap = snapshotProgress(foundTask);
      foundTask.progress.status = 'complete';
      foundTask.progress.completedAt = new Date();
      foundTask.progress.selfRating = rating;
      foundTask.progress.sourceEventId = `manual_${Date.now()}`;
      await saveWithRevert(plan, foundTask, snap);

      // Best-effort: update KnowledgeProfile.topicSelfRatings[canonical] = rating.
      try {
        const KnowledgeProfile = require('../../models/KnowledgeProfile');
        await KnowledgeProfile.updateOne(
          { userId },
          { $set: { [`topicSelfRatings.${foundTask.topic.canonicalName}`]: rating } },
          { upsert: true },
        );
      } catch (err) {
        console.warn('[planProgressService] KnowledgeProfile update failed:', err.message);
      }

      return { matched: true, planId: String(plan._id), weekNumber: foundWeek.week, taskId: String(foundTask._id) };
    },
  );
}
```

Update `module.exports` to include all three:

```javascript
module.exports = {
  onQuizComplete,
  onContentProgress,
  onInterviewComplete,
  onCompetitionPlayed,
  markManualComplete,
  _internal: { findCurrentWeekIndex, findPendingTaskInWeek, CONTENT_COMPLETE_THRESHOLD, withVersionRetry, MAX_RETRIES },
};
```

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/planProgressService.test.js
```

Expected: ALL tests pass (existing 13 + 5 new = 18).

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/plan/
git commit -m "feat(plan): planProgressService — interview, competition, manual"
```

---

## Task 3: Backend — wire interview + competition into existing write sites

**Files:**
- Modify: `scaleup-backend/src/services/interviewService.js` — call `planProgressService.onInterviewComplete` after a session is evaluated.
- Modify: `scaleup-backend/src/services/competitionService.js` — call `planProgressService.onCompetitionPlayed` after a challenge is completed.

The interview write site is at `interviewService.js:366` (`session.status = 'evaluated'`). The competition write site is `competitionController.js:57` calling `competitionService.completeChallenge`.

- [ ] **Step 1: Inspect both write sites to find the right insertion points**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
grep -n "session.status = 'evaluated'\|return session\|module.exports" src/services/interviewService.js | head -10
grep -n "completeChallenge\|return result\|module.exports" src/services/competitionService.js | head -10
```

For interview: insert AFTER `session.status = 'evaluated';` and AFTER any save call that persists it. Just before the function returns, call `planProgressService.onInterviewComplete`. The `session` should have a `topic` or be derivable from the targetRole/objective. If there's no clear topic key on the session, use `session.targetRole` after canonicalization — it's a best-effort match.

For competition: similar — after `competitionService.completeChallenge` does its work, call `planProgressService.onCompetitionPlayed`. The challenge should have a `topic` field — competition challenges are topic-tagged per the existing `objective-topic` route.

- [ ] **Step 2: Patch `interviewService.js`**

Find the function that contains line 366 (the `session.status = 'evaluated';` line). Just before that function returns (after the save), insert:

```javascript
    // Best-effort: mark matching plan task complete.
    try {
      const planProgressService = require('./plan/planProgressService');
      // Use targetRole as the topic key (best-effort — interviews aren't
      // topic-tagged today, but the plan's interview task uses the
      // allocation's topicCanonicalName which usually mirrors targetRole).
      const topic = session.targetRole || session.targetCompany || '';
      if (topic) {
        await planProgressService.onInterviewComplete({
          userId: String(session.userId),
          sessionId: String(session._id),
          topic,
        });
      }
    } catch (err) {
      console.warn('[interviewService] planProgressService.onInterviewComplete failed:', err.message);
    }
```

Note: `interviewService.js` lives in `src/services/interviewService.js`. The require path is `./plan/planProgressService`.

If the function doesn't have a clear "after save, before return" point (e.g., it's an event handler that doesn't return anything meaningful), insert after the last DB write involving `session`.

- [ ] **Step 3: Patch `competitionService.js`**

Find `completeChallenge` (likely takes `userId`, `challengeId` and updates a `Participation` or similar doc). After the completion is persisted, insert:

```javascript
    try {
      const planProgressService = require('./plan/planProgressService');
      // Try to find the challenge's topic. Fall back to skipping the call
      // if the challenge doc doesn't expose a topic.
      const Challenge = require('../models/Challenge');
      const challenge = await Challenge.findById(challengeId).lean();
      const topic = challenge?.topic || challenge?.canonicalTopic || '';
      if (topic) {
        await planProgressService.onCompetitionPlayed({
          userId: String(userId),
          challengeId: String(challengeId),
          topic,
        });
      }
    } catch (err) {
      console.warn('[competitionService] planProgressService.onCompetitionPlayed failed:', err.message);
    }
```

If the project uses a different model name for challenges (check with `ls src/models/ | grep -i chall`), substitute. If `challengeId` isn't the parameter name, adapt.

- [ ] **Step 4: Verify both files parse**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
node -e "require('./src/services/interviewService.js'); console.log('interview ok')"
node -e "require('./src/services/competitionService.js'); console.log('competition ok')"
```

Expected: both print `ok`.

- [ ] **Step 5: Run any existing service tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
ls src/services/interviewService.test.js src/services/competitionService.test.js 2>/dev/null
node --test src/services/interviewService.test.js 2>&1 | tail -10
node --test src/services/competitionService.test.js 2>&1 | tail -10
```

If tests don't exist, skip. If they exist and pass, good. If they exist and fail because of your changes, fix.

- [ ] **Step 6: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/interviewService.js src/services/competitionService.js
git commit -m "feat(plan): wire planProgressService into interview + competition completion"
```

---

## Task 4: Backend — manual completion API endpoint + OpenAPI

**Files:**
- Modify: `scaleup-backend/src/controllers/planController.js` — add `markTaskComplete` handler.
- Modify: `scaleup-backend/src/controllers/planController.test.js`
- Modify: `scaleup-backend/src/routes/plan.js` — wire the route.
- Modify: `scaleup-backend/openapi.yaml` — document `POST /plan/tasks/{taskId}/complete`.

The endpoint accepts `{ selfRating: 1-5 }`, validates ownership (user matches the active plan), calls `planProgressService.markManualComplete`, and returns `{ success, data: { taskId, planId, weekNumber } }` on success or 4xx with a typed reason on failure.

- [ ] **Step 1: Add a failing test**

Append to `scaleup-backend/src/controllers/planController.test.js`:

```javascript
test('markTaskComplete: 200 with taskId on successful manual completion', async () => {
  const userId = new mongoose.Types.ObjectId();
  const taskId = new mongoose.Types.ObjectId();
  activePlan = {
    _id: new mongoose.Types.ObjectId(),
    userId,
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'x',
    estimatedTotalHours: 10,
    weeklySchedule: [{
      week: 1, weeklyGoal: 'g', allocations: [],
      tasks: [{
        _id: taskId,
        type: 'manual',
        topic: { canonicalName: 'p', displayName: 'P' },
        payload: { title: 'do x', estimatedMinutes: 30 },
        completion: { mode: 'manual', requiresSelfRating: true },
        progress: { status: 'pending' },
      }],
    }],
    milestones: [],
    source: 'llm-generated',
    save: async function () { this._saved = true; return this; },
  };
  // For markManualComplete, Plan.findOne returns the doc directly (not via .sort().lean()).
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => activePlan });

  let captured;
  const res = { status: () => res, json: (b) => { captured = b; return res; } };
  const req = {
    user: { userId: userId.toString() },
    params: { taskId: taskId.toString() },
    body: { selfRating: 4 },
  };
  try {
    await markTaskComplete(req, res);
    assert.strictEqual(captured.success, true);
    assert.strictEqual(captured.data.taskId, taskId.toString());
    assert.strictEqual(activePlan.weeklySchedule[0].tasks[0].progress.status, 'complete');
    assert.strictEqual(activePlan.weeklySchedule[0].tasks[0].progress.selfRating, 4);
  } finally {
    Plan.findOne = origFindOne;
  }
});

test('markTaskComplete: 400 when selfRating is invalid', async () => {
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => activePlan });
  let captured, statusCode;
  const res = {
    status: (c) => { statusCode = c; return res; },
    json: (b) => { captured = b; return res; },
  };
  const req = {
    user: { userId: new mongoose.Types.ObjectId().toString() },
    params: { taskId: new mongoose.Types.ObjectId().toString() },
    body: { selfRating: 99 },
  };
  try {
    await markTaskComplete(req, res);
    assert.strictEqual(statusCode, 400);
    assert.strictEqual(captured.success, false);
    assert.ok(captured.error || captured.message);
  } finally {
    Plan.findOne = origFindOne;
  }
});
```

Add `markTaskComplete` to the imports at the top of the test file (mirror the pattern of `getCurrent`, `getStatus`).

- [ ] **Step 2: Run test to verify failure**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/controllers/planController.test.js
```

Expected: new tests fail (function not exported).

- [ ] **Step 3: Implement the controller handler**

In `src/controllers/planController.js`, add at the bottom (before `module.exports`):

```javascript
async function markTaskComplete(req, res) {
  const userId = req.user.userId;
  const { taskId } = req.params;
  const { selfRating } = req.body || {};

  const planProgressService = require('../services/plan/planProgressService');
  const result = await planProgressService.markManualComplete({ userId, taskId, selfRating });

  if (result.matched) {
    return res.status(200).json(apiResponse.success({
      taskId: result.taskId,
      planId: result.planId,
      weekNumber: result.weekNumber,
    }));
  }

  // Map service-level reasons to HTTP status codes.
  const statusByReason = {
    invalid_self_rating: 400,
    task_not_found: 404,
    no_active_plan: 404,
    concurrent_update: 409,
  };
  const status = statusByReason[result.reason] || 400;
  return res.status(status).json(apiResponse.error(result.reason || 'unknown_error'));
}
```

Update the `module.exports` to include `markTaskComplete`.

- [ ] **Step 4: Wire the route**

In `src/routes/plan.js` (find with `cat src/routes/plan.js`), add:

```javascript
router.post('/tasks/:taskId/complete', auth, c.markTaskComplete);
```

Match the existing route style. If the controller is imported as `c`, that's the variable to use; otherwise mirror the existing route file.

- [ ] **Step 5: Update OpenAPI**

In `openapi.yaml`, find where the plan paths are documented (search for `/api/v1/plan/current`). Add a new operation:

```yaml
  /api/v1/plan/tasks/{taskId}/complete:
    post:
      tags: [plan]
      summary: Mark a manual or external task complete with a self-rating
      operationId: markPlanTaskComplete
      security:
        - bearerAuth: []
      parameters:
        - in: path
          name: taskId
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [selfRating]
              properties:
                selfRating:
                  type: integer
                  minimum: 1
                  maximum: 5
      responses:
        '200':
          description: Task marked complete
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ApiSuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        type: object
                        required: [taskId, planId, weekNumber]
                        properties:
                          taskId: { type: string }
                          planId: { type: string }
                          weekNumber: { type: integer }
        '400':
          description: Invalid request (e.g., selfRating out of range)
        '404':
          description: Task or active plan not found
        '409':
          description: Concurrent update — retry
```

Match the indent of sibling operations. Use `allOf` if other endpoints use it, or whatever envelope pattern the file already uses.

- [ ] **Step 6: Lint OpenAPI**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm run openapi:lint 2>&1 | tail -10
```

Expected: 0 errors.

- [ ] **Step 7: Run controller tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/controllers/planController.test.js
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/controllers/planController.js src/controllers/planController.test.js src/routes/plan.js openapi.yaml
git commit -m "feat(plan): POST /tasks/:taskId/complete for manual completion"
```

---

## Task 5: iOS — `ManualCompletionSheet` + tap routing for new task types

**Files:**
- Create: `ScaleUp/Features/Plan/Views/Components/ManualCompletionSheet.swift`
- Modify: `ScaleUp/Features/Plan/Services/PlanService.swift` — add `markTaskComplete(taskId:selfRating:)` async method.
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift` — extend `handleTaskTap` for `.manual` (open completion sheet), `.aiInterview` (launch existing interview setup), `.competition` (route to competition tab).
- Modify: `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift` — add a `refresh()` async method that calls `load()` (or just reuse existing) so the sheet's onComplete can trigger a re-fetch.

The completion sheet shows the task title, a 5-chip self-rating row (1=Just learned, 5=Mastery), and a Confirm button. On confirm, calls the new endpoint. On success, dismisses + triggers plan reload so the task shows as complete.

For interview tasks, route to `InterviewSessionView` (or whatever the existing setup screen is — verify with `grep -rn "InterviewSessionView\|InterviewSetup" ScaleUp/Features/Interview`). Pass the topic + scenario from the task payload as initial values.

For competition tasks, route to the Competition tab — likely `RootTabView` has a way to switch tabs. If switching tabs from inside a sub-view is hard, fall back to presenting `ChallengeListView` as a sheet.

- [ ] **Step 1: Add `markTaskComplete` to `PlanService`**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
grep -n "func fetch\|func mark\|extension PlanService" ScaleUp/Features/Plan/Services/PlanService.swift
```

Add a method near `fetchCurrent`:

```swift
    @discardableResult
    func markTaskComplete(taskId: String, selfRating: Int) async throws -> APIMarkPlanTaskComplete200ResponseData {
        struct Body: Encodable { let selfRating: Int }
        let body = Body(selfRating: selfRating)
        let response: APIMarkPlanTaskComplete200Response = try await api.post(
            path: "/plan/tasks/\(taskId)/complete",
            body: body
        )
        return response.data
    }
```

Adapt the type names to match what regen produces. After Task 4 ships, run regen first:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && bash scripts/regenerate-openapi-types.sh 2>&1 | tail -10
```

Inspect the generated response type:

```bash
ls ScaleUp/Generated/OpenAPI/ | grep -i markplan
cat ScaleUp/Generated/OpenAPI/APIMarkPlanTaskComplete200Response*.swift 2>/dev/null | head -30
```

If the generated type is shaped differently (e.g., `APIPlanTasksTaskIdComplete200Response`), use that exact name.

If `APIClient.post(path:body:)` doesn't exist with that exact signature, inspect the existing API client and adapt. Most likely there's a `request(method:path:body:)` or similar.

- [ ] **Step 2: Create `ManualCompletionSheet.swift`**

```swift
import SwiftUI

struct ManualCompletionSheet: View {
    let task: APIPlanTask
    let onComplete: () -> Void  // called after successful POST

    @State private var selectedRating: Int = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let service = PlanService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    Text("Mark complete")
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(task.topic.displayName)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.top, Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("How confident do you feel about this topic now?")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    HStack(spacing: Spacing.sm) {
                        ForEach(1...5, id: \.self) { i in
                            ratingChip(i)
                        }
                    }
                    Text(ratingLabel(selectedRating))
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }

                PrimaryButton(title: isSubmitting ? "Saving..." : "Confirm") {
                    Task { await submit() }
                }
                .disabled(selectedRating == 0 || isSubmitting)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func ratingChip(_ value: Int) -> some View {
        let isSelected = value == selectedRating
        return Button(action: { selectedRating = value }) {
            Text("\(value)")
                .font(Typography.bodyBold)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? ColorTokens.gold : ColorTokens.gold.opacity(0.10))
                )
                .foregroundStyle(isSelected ? .white : ColorTokens.gold)
                .overlay(
                    Circle()
                        .stroke(ColorTokens.gold.opacity(0.30), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "1 — Just learned"
        case 2: return "2 — Getting comfortable"
        case 3: return "3 — Solid grasp"
        case 4: return "4 — Confident"
        case 5: return "5 — Mastery"
        default: return "Pick a rating"
        }
    }

    private func submit() async {
        guard selectedRating >= 1 && selectedRating <= 5 else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            _ = try await service.markTaskComplete(taskId: task.taskId, selfRating: selectedRating)
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
```

If `PlanService.shared` doesn't exist (Task 1 of Phase 1's notes said `PlanService` is a struct/actor — verify), instantiate per-view as the iOS tap-to-launch task did with `QuizService`.

- [ ] **Step 3: Wire the sheet + new task types into `handleTaskTap`**

In `PlanTabView.swift`, add new state vars near `presentedQuizId`:

```swift
    @State private var presentedManualTask: APIPlanTask?
    @State private var presentedInterviewScenario: String?
    @State private var presentingCompetitionRoute = false
```

(Adapt to the actual nav/tab-switch pattern in the project. If `APIPlanTask` is `Identifiable`, use it directly; otherwise wrap in a small `IdentifiedTask: Identifiable` like was done for `IdentifiedString`.)

Add a `.sheet(item:)` for the manual completion sheet:

```swift
        .sheet(item: $presentedManualTask) { task in
            ManualCompletionSheet(task: task, onComplete: {
                Task { await viewModel.load() }
            })
        }
```

Add a `.sheet(item:)` for interview if you take that route, OR navigate via tab switch.

Update `handleTaskTap`:

```swift
    private func handleTaskTap(_ task: APIPlanTask) {
        let typeRaw = task.type.rawValue
        AnalyticsService.shared.track(.planTaskTapped(taskType: typeRaw, taskId: task.taskId))

        switch task.type {
        case .quiz:
            if let quizId = task.payload?["quizId"]?.value as? String {
                presentedQuizId = quizId
            }
        case .inAppContent:
            if let contentId = task.payload?["contentId"]?.value as? String {
                presentedContentType = task.payload?["contentType"]?.value as? String
                presentedContentId = contentId
            }
        case .aiInterview:
            // Launch interview setup with the scenario hint from the payload.
            // For Phase 3, route to existing InterviewSessionView via a sheet.
            if let scenario = task.payload?["scenario"]?.value as? String {
                presentedInterviewScenario = scenario
            }
        case .competition:
            // Route to the Competition tab. If app uses an EnvironmentObject
            // selectedTab, set it here. Otherwise present ChallengeListView.
            presentingCompetitionRoute = true
        case .manual, .externalLink:
            presentedManualTask = task
        }
    }
```

If `APIPlanTask` doesn't conform to `Identifiable`, add an extension at the bottom of the file:

```swift
extension APIPlanTask: Identifiable {
    public var id: String { taskId }
}
```

For interview scenario presentation, add a sheet. The exact view to push depends on the existing interview entry point — inspect `InterviewSessionView` constructor:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && grep -n "struct InterviewSessionView\|init.*scenario\|init.*interviewType" ScaleUp/Features/Interview/Views/InterviewSessionView.swift | head -5
```

Use whatever constructor it offers.

For competition routing, look for a tab-switch pattern in `RootTabView` or similar:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && grep -rn "selectedTab\|currentTab" ScaleUp/App ScaleUp/Features 2>/dev/null | head -5
```

If switching tabs from a child view requires plumbing, fall back to presenting `ChallengeListView` as a sheet.

- [ ] **Step 4: Parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse \
  ScaleUp/Features/Plan/Views/Components/ManualCompletionSheet.swift \
  ScaleUp/Features/Plan/Views/PlanTabView.swift \
  ScaleUp/Features/Plan/Services/PlanService.swift 2>&1 | tail -10
```

Expected: silent. Likely failure modes:
- `PlanService.shared` API mismatch
- `APIClient.post(...)` signature mismatch — adapt to whatever exists
- `APIMarkPlanTaskComplete200ResponseData` type name — match what regen produced

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/ ScaleUp/Generated/
git commit -m "feat(ios-plan): ManualCompletionSheet + interview/competition tap routing"
```

---

## Task 6: Android — `ManualCompletionSheet` + tap routing for new task types

**Files:**
- Create: `src/screens/plan/components/ManualCompletionSheet.tsx`
- Modify: `src/services/planService.ts` — add `markTaskComplete(taskId, selfRating)` function.
- Modify: `src/screens/plan/PlanTabScreen.tsx` — extend `handleTaskTap` for the new task types + present the sheet.

The sheet uses a `Modal` (or `react-native`'s `Modal` component). Same UX as iOS: 5 chips, confirm, calls API on submit, dismisses + triggers refresh.

- [ ] **Step 1: Add `markTaskComplete` to `planService.ts`**

```typescript
export const PlanService = {
  fetchStatus: () => api.get<PlanStatus>('/plan/status'),
  fetchCurrent: () => api.get<Plan>('/plan/current'),
  markTaskComplete: (taskId: string, selfRating: number) =>
    api.post<{taskId: string; planId: string; weekNumber: number}>(
      `/plan/tasks/${taskId}/complete`,
      {selfRating},
    ),
}
```

If the existing `api` client doesn't have a `.post<T>(url, body)` signature, adapt to whatever it has (e.g., `api.request('POST', url, {body})`). Inspect:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && head -40 src/services/api.ts
```

- [ ] **Step 2: Create `ManualCompletionSheet.tsx`**

```tsx
import React, {useState} from 'react'
import {View, Text, StyleSheet, TouchableOpacity, Modal, Alert, ActivityIndicator} from 'react-native'
import {Colors, Spacing, CornerRadius, Typography} from '../../../theme'
import {PrimaryButton} from '../../../components/PrimaryButton'
import {PlanService} from '../../../services/planService'
import type {Task} from '../../../services/planService'

interface Props {
  task: Task | null
  onClose: () => void
  onComplete: () => void
}

export const ManualCompletionSheet: React.FC<Props> = ({task, onClose, onComplete}) => {
  const [selectedRating, setSelectedRating] = useState(0)
  const [submitting, setSubmitting] = useState(false)

  if (!task) return null

  const submit = async () => {
    if (selectedRating < 1 || selectedRating > 5) return
    setSubmitting(true)
    try {
      await PlanService.markTaskComplete(task.taskId, selectedRating)
      onComplete()
      onClose()
      setSelectedRating(0)
    } catch {
      Alert.alert("Couldn't save", 'Please try again in a moment.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <Modal animationType="slide" transparent visible={!!task} onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <View style={styles.sheet}>
          <View style={styles.headerRow}>
            <TouchableOpacity onPress={onClose}>
              <Text style={styles.cancel}>Cancel</Text>
            </TouchableOpacity>
            <View style={{flex: 1}} />
          </View>

          <Text style={styles.title}>Mark complete</Text>
          <Text style={styles.subtitle}>{task.topic.displayName}</Text>

          <Text style={styles.prompt}>How confident do you feel about this topic now?</Text>

          <View style={styles.chipRow}>
            {[1, 2, 3, 4, 5].map(v => (
              <TouchableOpacity
                key={v}
                style={[styles.chip, selectedRating === v && styles.chipSelected]}
                onPress={() => setSelectedRating(v)}
              >
                <Text style={[styles.chipText, selectedRating === v && styles.chipTextSelected]}>
                  {v}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <Text style={styles.ratingLabel}>{ratingLabel(selectedRating)}</Text>

          <View style={styles.confirmWrap}>
            {submitting ? (
              <ActivityIndicator color={Colors.gold} />
            ) : (
              <PrimaryButton title="Confirm" onPress={submit} />
            )}
          </View>
        </View>
      </View>
    </Modal>
  )
}

function ratingLabel(r: number): string {
  switch (r) {
    case 1: return '1 — Just learned'
    case 2: return '2 — Getting comfortable'
    case 3: return '3 — Solid grasp'
    case 4: return '4 — Confident'
    case 5: return '5 — Mastery'
    default: return 'Pick a rating'
  }
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,0.4)' },
  sheet: {
    backgroundColor: Colors.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: Spacing.lg,
    paddingBottom: Spacing.xxl,
  },
  headerRow: { flexDirection: 'row', alignItems: 'center', marginBottom: Spacing.md },
  cancel: { color: Colors.gold, fontSize: 14 },
  title: { color: Colors.textPrimary, fontSize: 20, fontWeight: '700' },
  subtitle: { color: Colors.textSecondary, fontSize: 14, marginTop: 4 },
  prompt: { color: Colors.textPrimary, fontSize: 14, fontWeight: '600', marginTop: Spacing.lg },
  chipRow: { flexDirection: 'row', gap: Spacing.sm, marginTop: Spacing.md, justifyContent: 'space-between' },
  chip: {
    width: 44, height: 44, borderRadius: 22,
    backgroundColor: 'rgba(232,184,75,0.10)',
    borderWidth: 1, borderColor: 'rgba(232,184,75,0.30)',
    alignItems: 'center', justifyContent: 'center',
  },
  chipSelected: { backgroundColor: Colors.gold },
  chipText: { color: Colors.gold, fontSize: 16, fontWeight: '700' },
  chipTextSelected: { color: '#0F0F0F' },
  ratingLabel: { color: Colors.textSecondary, fontSize: 12, marginTop: Spacing.sm },
  confirmWrap: { marginTop: Spacing.xl },
})
```

If color/spacing tokens differ, swap.

- [ ] **Step 3: Wire into `PlanTabScreen.tsx`**

Add state for the sheet:

```typescript
const [completionTask, setCompletionTask] = useState<Task | null>(null)
```

Render the sheet near the bottom of the component (alongside other modals if any):

```tsx
<ManualCompletionSheet
  task={completionTask}
  onClose={() => setCompletionTask(null)}
  onComplete={loadPlan}
/>
```

Add the import:

```typescript
import {ManualCompletionSheet} from './components/ManualCompletionSheet'
```

Update `handleTaskTap`:

```typescript
function handleTaskTap(task: Task) {
  AnalyticsService.track({
    type: 'plan_task_tapped',
    task_type: task.type,
    task_id: task.taskId,
    topic_canonical: task.topic.canonicalName,
  })
  switch (task.type) {
    case 'quiz': /* existing */ break
    case 'in_app_content': /* existing */ break
    case 'ai_interview': {
      const scenario = (task.payload as any)?.scenario
      // Android has interview screens — navigate to the entry point.
      navigation.navigate('InterviewSetup' as never, {scenario} as never)
      break
    }
    case 'competition':
      // Android may not have a competition tab yet. Show alert as graceful fallback.
      Alert.alert(
        'Competition not yet available',
        'The competition feature is coming to Android soon. For now, mark this task complete after you play on the iOS app or web.',
      )
      break
    case 'manual':
    case 'external_link':
      setCompletionTask(task)
      break
    default:
      break
  }
}
```

Inspect actual interview route name first:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && grep -n "Stack.Screen.*Interview\|name=.Interview" src/navigation/AppNavigator.tsx | head
```

If the route is named differently (e.g. `'InterviewSession'`), use that.

- [ ] **Step 4: TypeScript check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npx tsc --noEmit 2>&1 | grep -E "src/(services/planService|screens/plan)" | head -20
```

Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git add src/screens/plan/ src/services/planService.ts
git commit -m "feat(android-plan): ManualCompletionSheet + interview/competition/manual tap routing"
```

---

## Task 7: Phase 3 acceptance — full sweep

- [ ] **Step 1: Backend full test sweep**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test 2>&1 | tail -30
```

Expected: pre-existing `diagnostic-e2e-upskilling.test.js` timeout is the only failure; everything else passes.

- [ ] **Step 2: OpenAPI lint + contract test**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
npm run openapi:lint 2>&1 | tail -10
npm run openapi:contract-test 2>&1 | tail -20
```

Expected: 0 errors.

- [ ] **Step 3: iOS regen + build**

If openapi was regenerated already in Task 5, skip. Otherwise:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && bash scripts/regenerate-openapi-types.sh 2>&1 | tail -10
```

Then build (or parse-only if simulator missing):

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -20
```

Or:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && find ScaleUp/Features/Plan ScaleUp/Generated/OpenAPI -name "*.swift" -print0 | xargs -0 xcrun swiftc -parse 2>&1 | tail -10
```

- [ ] **Step 4: Android typecheck**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npx tsc --noEmit 2>&1 | grep -E "src/(services|screens/plan)" | head -20
```

Expected: no new errors.

- [ ] **Step 5: No commit needed.** Acceptance only.

---

## What Phase 3 ships

After this plan executes:
- Plans now persist tasks of all 6 types: `quiz`, `in_app_content`, `ai_interview`, `competition`, `manual`, with `external_link` reserved for Phase 4.
- Interview/competition tasks auto-complete via the existing scoring/completion paths.
- Manual tasks (and external links from Phase 4) are completable via a new `POST /plan/tasks/:taskId/complete` endpoint with a self-rating.
- The self-rating value flows into `KnowledgeProfile.topicSelfRatings` so the next recalibration sees the updated belief.
- iOS Plan tab can launch interview / competition / completion-sheet directly from a task tap.
- Android Plan tab can launch interview directly; competition shows a graceful "coming soon" alert; completion sheet works.

**What Phase 3 does NOT ship:**
- LLM-as-judge external content links (Phase 4).
- Journey timeline horizontal week strip (Phase 5).
- Android competition feature parity (separate Android-side work, not Plan-tab scoped).

Phase 4 is next: external link curation via LLM-as-judge with whitelist enforcement and the `ExternalContentTouch` collection for capture-on-completion.

---

## Self-review checklist

- ✅ Spec coverage: §4 task types matrix rows for ai_interview, competition, manual all map to tasks; §7 phase-3 deliverables all covered.
- ✅ Placeholder scan: clean.
- ✅ Type consistency: task `progress` shape matches Phase 1+2; payload keys for new types (`scenario`, `topicCanonicalName`, `title`/`description`/`estimatedMinutes`) are documented per task.
- ✅ Phase 1+2 dependencies: `planProgressService` helpers (`withVersionRetry`, `findCurrentWeekIndex`, `findPendingTaskInWeek`, `canonicalize`, `saveWithRevert`, `snapshotProgress`) all exist on master after Phase 1+2 fixes.
