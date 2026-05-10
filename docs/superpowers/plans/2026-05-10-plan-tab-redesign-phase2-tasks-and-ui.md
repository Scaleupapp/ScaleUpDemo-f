# Plan Tab Redesign — Phase 2: Tasks + UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Plan-tab orchestration hub real for the user. Plan generator emits `quiz` + `in_app_content` tasks per topic per week; iOS Plan tab renders the objective brief, next-check-in pill, and this-week task list with tap-to-launch.

**Architecture:**
- Backend: a small `taskCatalogService` resolves `(topic.canonicalName, objectiveType)` → best matching `quizId` + `contentId` from existing collections. `planGenerationService.generate()` post-processes the LLM/template output to populate `tasks[]` per week from each allocation's topic.
- API: `GET /plan/current` surfaces `tasks[]` per `weeklySchedule[i]`; OpenAPI spec is updated and iOS types regenerated so `APIPlanTask` is decodable.
- iOS: Plan tab gains three new components — `ObjectiveBriefCard` (collapsed by default), `NextCheckInPill` (uses Phase 1's `nextCheckInAt`), and `ThisWeekTasksList` (rows by task type with tap-to-launch into existing quiz/content viewers).
- Migration: existing plans get `tasks[]` lazily backfilled by a one-shot script (no live worker — the script is fast since plans are small).

**Tech Stack:** Node 18 + Express 4 + Mongoose, `node:test`; Swift 5 + SwiftUI / `@Observable`; OpenAPI 3.1.

**Spec:** `docs/superpowers/specs/2026-05-09-plan-tab-redesign-design.md` (commit `df0068f`). This plan covers spec §7 Phase 2 only. Phases 3-5 (interview/competition/manual, external links via LLM-judge, journey timeline) get their own plans. **Android RN deferred to Phase 2.5** — same data shape, lower-priority polish per spec §7.

**Phase 1 prerequisite:** Phase 1 is shipped (commits `415dcc94` backend, `15fa516` iOS, plus follow-ups `81c4a29`/`333a626` backend). `Plan.tasks[]` schema, `planProgressService`, recalibration cooldown 7d, and `nextCheckInAt` are all live. This plan builds on top.

**Repo layout:**
- Backend: `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/`

---

## File Structure

**Created:**
- `scaleup-backend/src/services/plan/taskCatalogService.js` — resolves topic → quizId/contentId.
- `scaleup-backend/src/services/plan/taskCatalogService.test.js`
- `scaleup-backend/scripts/migrate/backfillPlanTasks.js` — one-shot lazy backfill for existing plans.
- `ScaleUp/Features/Plan/Views/Components/ObjectiveBriefCard.swift`
- `ScaleUp/Features/Plan/Views/Components/NextCheckInPill.swift`
- `ScaleUp/Features/Plan/Views/Components/TaskRow.swift`
- `ScaleUp/Features/Plan/Views/Components/ThisWeekTasksList.swift`

**Modified:**
- `scaleup-backend/src/services/diagnostic/planGenerationService.js` — post-process `weeklySchedule` to add `tasks[]`.
- `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`
- `scaleup-backend/src/controllers/planController.js` — surface `tasks[]` in the response.
- `scaleup-backend/src/controllers/planController.test.js`
- `scaleup-backend/openapi.yaml` — `tasks[]` on `PlanWeeklyEntry`.
- `ScaleUp/Features/Plan/Views/PlanTabView.swift` — wire new components into `planContent(_:)`.
- `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift` — expose helpers (current week index, derived insights from diagnostic).
- `ScaleUp/Features/Plan/Services/PlanService.swift` — typealias updates if needed after regen.

Each task ends with a commit. Backend tests use `node:test` via `node --test`.

---

## Task 1: Backend — `taskCatalogService` (topic → quizId + contentId)

**Files:**
- Create: `scaleup-backend/src/services/plan/taskCatalogService.js`
- Create: `scaleup-backend/src/services/plan/taskCatalogService.test.js`

The service exposes `resolveTopic({ topicCanonicalName, objectiveType, objectiveId })` → `{ quizId, quizMinutes, contentId, contentType, contentMinutes } | { quizId: null, contentId: null }`.

Selection rules:
- **Quiz:** prefer `Quiz.findOne({ topic: canonicalize(topicCanonicalName), objectiveId })` first, fallback to `{ topic: canonicalize(topic) }` ignoring objectiveId. Sort by `createdAt: -1` so newest content wins. Estimated minutes default to 8 if not set on the doc.
- **Content:** `Content.findOne({ topics: canonicalize(topicCanonicalName), status: 'published' })` sorted by `publishedAt: -1`. Estimated minutes use `content.duration` (already in minutes per `Content.js`) or default to 12.

Both lookups are best-effort: if no row exists, return `null` for that side. Plan generator decides whether to emit a task at all.

- [ ] **Step 1: Create the test file with failing tests**

Create `scaleup-backend/src/services/plan/taskCatalogService.test.js`:

```javascript
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

delete require.cache[require.resolve('../../models/Quiz')];
const Quiz = require('../../models/Quiz');
delete require.cache[require.resolve('../../models/Content')];
const Content = require('../../models/Content');
delete require.cache[require.resolve('./taskCatalogService')];
const taskCatalogService = require('./taskCatalogService');

function makeQuery(value) {
  // Mock the chained `.sort().lean()` return shape Mongoose uses.
  return { sort: () => ({ lean: async () => value }) };
}

test('resolveTopic: finds quiz scoped to objective first', async () => {
  const objectiveId = new mongoose.Types.ObjectId();
  const expectedQuiz = { _id: new mongoose.Types.ObjectId(), topic: 'product-strategy', estimatedMinutes: 10 };
  const calls = [];
  const origQuiz = Quiz.findOne;
  Quiz.findOne = (filter) => { calls.push(filter); return makeQuery(expectedQuiz); };
  const origContent = Content.findOne;
  Content.findOne = () => makeQuery(null);

  try {
    const out = await taskCatalogService.resolveTopic({
      topicCanonicalName: 'Product Strategy',
      objectiveType: 'interview_preparation',
      objectiveId,
    });
    assert.strictEqual(out.quizId, String(expectedQuiz._id));
    assert.strictEqual(out.quizMinutes, 10);
    // First call is objective-scoped lookup
    assert.deepStrictEqual(calls[0], { topic: 'product-strategy', objectiveId });
  } finally {
    Quiz.findOne = origQuiz;
    Content.findOne = origContent;
  }
});

test('resolveTopic: falls back to global quiz when no objective-scoped match', async () => {
  const expectedQuiz = { _id: new mongoose.Types.ObjectId(), topic: 'roadmapping' };
  let call = 0;
  const origQuiz = Quiz.findOne;
  Quiz.findOne = () => { call++; return makeQuery(call === 1 ? null : expectedQuiz); };
  const origContent = Content.findOne;
  Content.findOne = () => makeQuery(null);

  try {
    const out = await taskCatalogService.resolveTopic({
      topicCanonicalName: 'roadmapping',
      objectiveType: 'interview_preparation',
      objectiveId: new mongoose.Types.ObjectId(),
    });
    assert.strictEqual(out.quizId, String(expectedQuiz._id));
    assert.strictEqual(out.quizMinutes, 8); // default fallback
    assert.strictEqual(call, 2);
  } finally {
    Quiz.findOne = origQuiz;
    Content.findOne = origContent;
  }
});

test('resolveTopic: returns content when found', async () => {
  const expectedContent = {
    _id: new mongoose.Types.ObjectId(),
    contentType: 'article',
    duration: 14,
    topics: ['product-strategy'],
  };
  const origQuiz = Quiz.findOne;
  Quiz.findOne = () => makeQuery(null);
  const origContent = Content.findOne;
  Content.findOne = (filter) => {
    assert.deepStrictEqual(filter, { topics: 'product-strategy', status: 'published' });
    return makeQuery(expectedContent);
  };

  try {
    const out = await taskCatalogService.resolveTopic({
      topicCanonicalName: 'product-strategy',
      objectiveType: 'interview_preparation',
      objectiveId: new mongoose.Types.ObjectId(),
    });
    assert.strictEqual(out.contentId, String(expectedContent._id));
    assert.strictEqual(out.contentType, 'article');
    assert.strictEqual(out.contentMinutes, 14);
  } finally {
    Quiz.findOne = origQuiz;
    Content.findOne = origContent;
  }
});

test('resolveTopic: returns nulls when neither quiz nor content found', async () => {
  const origQuiz = Quiz.findOne;
  Quiz.findOne = () => makeQuery(null);
  const origContent = Content.findOne;
  Content.findOne = () => makeQuery(null);

  try {
    const out = await taskCatalogService.resolveTopic({
      topicCanonicalName: 'unknown-topic',
      objectiveType: 'interview_preparation',
      objectiveId: new mongoose.Types.ObjectId(),
    });
    assert.strictEqual(out.quizId, null);
    assert.strictEqual(out.contentId, null);
  } finally {
    Quiz.findOne = origQuiz;
    Content.findOne = origContent;
  }
});

test('resolveTopic: empty topic returns nulls without DB call', async () => {
  let called = false;
  const origQuiz = Quiz.findOne;
  Quiz.findOne = () => { called = true; return makeQuery(null); };
  const origContent = Content.findOne;
  Content.findOne = () => { called = true; return makeQuery(null); };

  try {
    const out = await taskCatalogService.resolveTopic({
      topicCanonicalName: '',
      objectiveType: 'interview_preparation',
      objectiveId: new mongoose.Types.ObjectId(),
    });
    assert.strictEqual(out.quizId, null);
    assert.strictEqual(out.contentId, null);
    assert.strictEqual(called, false);
  } finally {
    Quiz.findOne = origQuiz;
    Content.findOne = origContent;
  }
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/taskCatalogService.test.js
```

Expected: FAIL — `Cannot find module './taskCatalogService'`.

- [ ] **Step 3: Implement the service**

Create `scaleup-backend/src/services/plan/taskCatalogService.js`:

```javascript
const Quiz = require('../../models/Quiz');
const Content = require('../../models/Content');
const { canonicalize } = require('../diagnostic/topicTaxonomyService');

const DEFAULT_QUIZ_MINUTES = 8;
const DEFAULT_CONTENT_MINUTES = 12;

async function resolveTopic({ topicCanonicalName, objectiveType, objectiveId }) {
  const key = canonicalize(topicCanonicalName);
  if (!key) return { quizId: null, contentId: null };

  // Quiz: prefer objective-scoped, fall back to global, newest first.
  let quiz = await Quiz.findOne({ topic: key, objectiveId }).sort({ createdAt: -1 }).lean();
  if (!quiz) {
    quiz = await Quiz.findOne({ topic: key }).sort({ createdAt: -1 }).lean();
  }

  const content = await Content.findOne({ topics: key, status: 'published' })
    .sort({ publishedAt: -1 })
    .lean();

  return {
    quizId: quiz ? String(quiz._id) : null,
    quizMinutes: quiz ? (quiz.estimatedMinutes || DEFAULT_QUIZ_MINUTES) : null,
    contentId: content ? String(content._id) : null,
    contentType: content ? content.contentType : null,
    contentMinutes: content ? (content.duration || DEFAULT_CONTENT_MINUTES) : null,
  };
}

module.exports = { resolveTopic, _internal: { DEFAULT_QUIZ_MINUTES, DEFAULT_CONTENT_MINUTES } };
```

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/taskCatalogService.test.js
```

Expected: 5/5 PASS.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/plan/taskCatalogService.js src/services/plan/taskCatalogService.test.js
git commit -m "feat(plan): taskCatalogService resolves topic to quiz+content"
```

---

## Task 2: Backend — `planGenerationService` emits `tasks[]`

**Files:**
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.js`
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`

Post-process the existing `weeklySchedule` after the LLM/template runs. For each week, walk `allocations[]` and call `taskCatalogService.resolveTopic` per allocation's topic. Append a `tasks[]` array to the week with one `quiz` task and/or one `in_app_content` task per topic that resolved.

Important: `tasks[]` is added IN ADDITION TO `allocations[]` (not replacing). `allocations` stays as the descriptive view; `tasks` is the actionable view. iOS will render tasks; allocations stay for the journey-timeline view in Phase 5.

The post-processor is idempotent — running on a plan that already has tasks does nothing (overwrites with the same shape).

- [ ] **Step 1: Add failing tests**

Append to `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`:

```javascript
test('generate: post-processes weeklySchedule to include tasks[] per topic', async () => {
  // Stub the LLM call to bypass network — return a known schedule shape.
  const planService = require('./planGenerationService');
  const mongoose = require('mongoose');

  // Stub the OpenAI call to throw — generate() falls back to template,
  // which always produces a valid weeklySchedule.
  const openai = require('../../config/openai');
  const origCreate = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('test stub'); };

  // Stub taskCatalogService.resolveTopic to return predictable results.
  const taskCatalogService = require('../plan/taskCatalogService');
  const origResolve = taskCatalogService.resolveTopic;
  taskCatalogService.resolveTopic = async ({ topicCanonicalName }) => {
    if (topicCanonicalName === 'product-strategy') {
      return {
        quizId: '64aaaaaaaaaaaaaaaaaaaaaa',
        quizMinutes: 10,
        contentId: '64bbbbbbbbbbbbbbbbbbbbbb',
        contentType: 'article',
        contentMinutes: 12,
      };
    }
    return { quizId: null, contentId: null };
  };

  try {
    const out = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'interview_preparation',
      specificsCanonical: { targetRole: 'product-manager' },
      timeline: 4,
      weeklyCommitHours: 5,
      topicResults: [
        { canonicalName: 'product-strategy', selfRating: 'familiar', measuredScore: 50,
          measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated',
          questionsAsked: 4, answerPattern: {}, isFutureProofing: false },
      ],
    });

    assert.ok(Array.isArray(out.weeklySchedule));
    assert.ok(out.weeklySchedule.length > 0);
    const w0 = out.weeklySchedule[0];
    assert.ok(Array.isArray(w0.tasks), 'each week should have a tasks[] array');
    assert.ok(w0.tasks.length >= 2, `expected quiz+content tasks, got ${w0.tasks.length}`);

    const quizTask = w0.tasks.find(t => t.type === 'quiz');
    const contentTask = w0.tasks.find(t => t.type === 'in_app_content');
    assert.ok(quizTask, 'quiz task missing');
    assert.ok(contentTask, 'in_app_content task missing');
    assert.strictEqual(quizTask.payload.quizId, '64aaaaaaaaaaaaaaaaaaaaaa');
    assert.strictEqual(quizTask.completion.mode, 'auto');
    assert.strictEqual(quizTask.progress.status, 'pending');
    assert.strictEqual(contentTask.payload.contentId, '64bbbbbbbbbbbbbbbbbbbbbb');
    assert.strictEqual(contentTask.topic.canonicalName, 'product-strategy');
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
  }
});

test('generate: emits no task for a topic with no quiz and no content', async () => {
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
      objectiveType: 'interview_preparation',
      specificsCanonical: { targetRole: 'pm' },
      timeline: 2,
      weeklyCommitHours: 5,
      topicResults: [
        { canonicalName: 'unmapped-topic', selfRating: 'familiar', measuredScore: 40,
          measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated',
          questionsAsked: 4, answerPattern: {}, isFutureProofing: false },
      ],
    });
    out.weeklySchedule.forEach(w => {
      assert.strictEqual((w.tasks || []).length, 0, `week ${w.week} should have no tasks`);
    });
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

Expected: 2 new tests FAIL — `tasks` is undefined on each week.

- [ ] **Step 3: Add the post-processor to `planGenerationService.js`**

Edit `scaleup-backend/src/services/diagnostic/planGenerationService.js`. At the top, add:

```javascript
const taskCatalogService = require('../plan/taskCatalogService');
```

Inside `generate(input)`, just before the final `return { ... }` block (after `const estimatedTotalHours = sumTotalHours(plan);`), insert:

```javascript
  // Post-process: populate tasks[] per week from each allocation's topic.
  // Best-effort — a topic with no matching quiz/content yields no tasks for
  // that topic this week, but the rest of the plan is unaffected.
  for (const week of plan.weeklySchedule) {
    const tasks = [];
    for (const alloc of (week.allocations || [])) {
      let resolved;
      try {
        resolved = await taskCatalogService.resolveTopic({
          topicCanonicalName: alloc.topicCanonicalName,
          objectiveType: input.objectiveType,
          objectiveId: input.objectiveId,
        });
      } catch (err) {
        console.warn('[planGenerationService] taskCatalogService.resolveTopic failed:', err.message);
        continue;
      }
      const displayName = alloc.topicCanonicalName.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
      const topicShape = { canonicalName: alloc.topicCanonicalName, displayName };
      if (resolved.quizId) {
        tasks.push({
          type: 'quiz',
          topic: topicShape,
          payload: { quizId: resolved.quizId, estimatedMinutes: resolved.quizMinutes },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
        });
      }
      if (resolved.contentId) {
        tasks.push({
          type: 'in_app_content',
          topic: topicShape,
          payload: {
            contentId: resolved.contentId,
            contentType: resolved.contentType,
            estimatedMinutes: resolved.contentMinutes,
          },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
        });
      }
    }
    week.tasks = tasks;
  }
```

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/diagnostic/planGenerationService.test.js
```

Expected: ALL tests PASS (existing + 2 new). If any pre-existing test broke (e.g., one that asserted `Object.keys(week)` shape), update it to allow the additional `tasks` field.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/diagnostic/planGenerationService.js src/services/diagnostic/planGenerationService.test.js
git commit -m "feat(plan): generator emits quiz+in_app_content tasks per topic"
```

---

## Task 3: Backend — surface `tasks[]` on `/plan/current`

**Files:**
- Modify: `scaleup-backend/src/controllers/planController.js`
- Modify: `scaleup-backend/src/controllers/planController.test.js`
- Modify: `scaleup-backend/openapi.yaml`

Today's controller maps `weeklySchedule[i]` to a flat shape with `weekNumber`, `weekLabel`, `totalHours`, `allocations` — and explicitly drops everything else. Add `tasks` to the projection.

- [ ] **Step 1: Add a failing test**

Append to `scaleup-backend/src/controllers/planController.test.js`:

```javascript
test('getCurrent: surfaces weeklySchedule[i].tasks[] on the response', async () => {
  const fakePlan = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    objectiveId: new mongoose.Types.ObjectId(),
    diagnosticAttemptId: new mongoose.Types.ObjectId(),
    planHeadline: 'x',
    estimatedTotalHours: 10,
    weeklySchedule: [{
      week: 1,
      weeklyGoal: 'g',
      allocations: [{ topicCanonicalName: 'product-strategy', hours: 3, focusActivity: 'practice' }],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'quiz',
        topic: { canonicalName: 'product-strategy', displayName: 'Product Strategy' },
        payload: { quizId: 'q-1', estimatedMinutes: 10 },
        completion: { mode: 'auto', requiresSelfRating: false },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    milestones: [],
    source: 'llm-generated',
    updatedAt: new Date(),
  };

  const origPlanFind = Plan.findOne;
  Plan.findOne = () => ({ sort: () => ({ lean: async () => fakePlan }) });
  attemptById = null;

  let captured;
  const res = { status: () => res, json: (body) => { captured = body; return res; } };
  const req = { user: { userId: fakePlan.userId.toString() } };

  try {
    await getCurrent(req, res);
    assert.strictEqual(captured.success, true);
    const week = captured.data.weeklySchedule[0];
    assert.ok(Array.isArray(week.tasks), 'tasks should be present on the response');
    assert.strictEqual(week.tasks.length, 1);
    assert.strictEqual(week.tasks[0].type, 'quiz');
    assert.strictEqual(week.tasks[0].payload.quizId, 'q-1');
    assert.strictEqual(week.tasks[0].progress.status, 'pending');
    assert.ok(week.tasks[0].taskId, 'taskId (string of _id) should be on the response');
  } finally {
    Plan.findOne = origPlanFind;
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/controllers/planController.test.js
```

Expected: FAIL — `week.tasks` is undefined.

- [ ] **Step 3: Update the controller**

In `scaleup-backend/src/controllers/planController.js`, find the `weeklySchedule.map(...)` block in `getCurrent`. Add a `tasks` field to the returned object:

```javascript
  const weeklySchedule = (plan.weeklySchedule || []).map(w => {
    const totalHours = (w.allocations || []).reduce((s, a) => s + (a.hours || 0), 0);
    return {
      weekNumber: w.week,
      weekLabel: w.weeklyGoal || `Week ${w.week}`,
      totalHours,
      allocations: (w.allocations || []).map(a => ({
        topic: displayByCanonical.get(a.topicCanonicalName) || a.topicCanonicalName,
        canonicalTopic: a.topicCanonicalName,
        hoursAllocated: a.hours,
        focusActivity: a.focusActivity,
      })),
      tasks: (w.tasks || []).map(t => ({
        taskId: String(t._id),
        type: t.type,
        topic: t.topic,
        payload: t.payload || {},
        completion: t.completion,
        progress: {
          status: t.progress?.status || 'pending',
          completedAt: t.progress?.completedAt || null,
          selfRating: t.progress?.selfRating || null,
        },
      })),
    };
  });
```

(Keep everything else in `getCurrent` unchanged — `nextCheckInAt` from Phase 1 still computes the same way.)

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/controllers/planController.test.js
```

Expected: ALL tests PASS.

- [ ] **Step 5: Update `openapi.yaml`**

Open `scaleup-backend/openapi.yaml`. Find the `PlanWeeklyEntry` schema (likely around the components section, near `PlanCurrent` at line 349). Add a `tasks` array property to its `properties:` block:

```yaml
                tasks:
                  type: array
                  items:
                    $ref: '#/components/schemas/PlanTask'
```

Then add a new schema `PlanTask` to the components:

```yaml
    PlanTask:
      type: object
      required: [taskId, type, topic, completion, progress]
      properties:
        taskId:
          type: string
          description: ObjectId of the task (stable across plan recalibrations within a single Plan document).
        type:
          type: string
          enum: [quiz, in_app_content, ai_interview, external_link, competition, manual]
        topic:
          type: object
          required: [canonicalName, displayName]
          properties:
            canonicalName: { type: string }
            displayName: { type: string }
        payload:
          type: object
          additionalProperties: true
          description: Type-discriminated. Quiz payload includes quizId, estimatedMinutes; in_app_content includes contentId, contentType, estimatedMinutes; etc.
        completion:
          type: object
          required: [mode, requiresSelfRating]
          properties:
            mode: { type: string, enum: [auto, manual] }
            requiresSelfRating: { type: boolean }
        progress:
          type: object
          required: [status]
          properties:
            status: { type: string, enum: [pending, in_progress, complete, skipped] }
            completedAt: { type: [string, 'null'], format: date-time }
            selfRating: { type: [integer, 'null'], minimum: 1, maximum: 5 }
```

- [ ] **Step 6: Lint OpenAPI**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm run openapi:lint 2>&1 | tail -20
```

Expected: 0 errors. If a new error appears that was caused by your additions, fix it (most common: indentation drift, or adding `nullable: true` instead of OAS 3.1's `type: [string, 'null']` form — match sibling schemas).

- [ ] **Step 7: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/controllers/planController.js src/controllers/planController.test.js openapi.yaml
git commit -m "feat(plan): surface tasks[] on /plan/current + openapi"
```

---

## Task 4: Backend — backfill script for existing plans

**Files:**
- Create: `scaleup-backend/scripts/migrate/backfillPlanTasks.js`

A small one-shot Node script that finds all active plans without `tasks` populated and runs the same post-processor `taskCatalogService.resolveTopic` for each allocation. Run manually after Task 2 ships.

- [ ] **Step 1: Create the script**

Create `scaleup-backend/scripts/migrate/backfillPlanTasks.js`:

```javascript
#!/usr/bin/env node
/**
 * Backfill tasks[] on existing active plans.
 *
 * Phase 2 introduces tasks[] to the Plan model. Plans created before this
 * migration have weeklySchedule[i].tasks empty. This script walks each
 * active plan, calls taskCatalogService.resolveTopic for every allocation,
 * and writes the resulting tasks[].
 *
 * Idempotent: skips weeks that already have a non-empty tasks array.
 *
 * Run: node scripts/migrate/backfillPlanTasks.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Plan = require('../../src/models/Plan');
const UserObjective = require('../../src/models/UserObjective');
const taskCatalogService = require('../../src/services/plan/taskCatalogService');

const DRY_RUN = process.argv.includes('--dry-run');

async function backfillOne(plan) {
  let touched = 0;
  let tasksAdded = 0;
  const objective = plan.objectiveId
    ? await UserObjective.findById(plan.objectiveId).lean()
    : null;
  const objectiveType = objective?.objectiveType || null;

  for (const week of plan.weeklySchedule) {
    if ((week.tasks || []).length > 0) continue; // idempotent skip
    const tasks = [];
    for (const alloc of (week.allocations || [])) {
      const resolved = await taskCatalogService.resolveTopic({
        topicCanonicalName: alloc.topicCanonicalName,
        objectiveType,
        objectiveId: plan.objectiveId,
      });
      const displayName = alloc.topicCanonicalName
        .replace(/-/g, ' ')
        .replace(/\b\w/g, c => c.toUpperCase());
      const topicShape = { canonicalName: alloc.topicCanonicalName, displayName };
      if (resolved.quizId) {
        tasks.push({
          type: 'quiz', topic: topicShape,
          payload: { quizId: resolved.quizId, estimatedMinutes: resolved.quizMinutes },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending' },
        });
        tasksAdded++;
      }
      if (resolved.contentId) {
        tasks.push({
          type: 'in_app_content', topic: topicShape,
          payload: {
            contentId: resolved.contentId,
            contentType: resolved.contentType,
            estimatedMinutes: resolved.contentMinutes,
          },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending' },
        });
        tasksAdded++;
      }
    }
    week.tasks = tasks;
    touched++;
  }
  if (touched > 0 && !DRY_RUN) {
    await plan.save();
  }
  return { weeksTouched: touched, tasksAdded };
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/scaleupdemo');
  console.log(`[backfillPlanTasks] connected; dryRun=${DRY_RUN}`);

  const cursor = Plan.find({ isActive: true }).cursor();
  let plansSeen = 0, plansTouched = 0, totalWeeks = 0, totalTasks = 0;

  for await (const plan of cursor) {
    plansSeen++;
    const { weeksTouched, tasksAdded } = await backfillOne(plan);
    if (weeksTouched > 0) {
      plansTouched++;
      totalWeeks += weeksTouched;
      totalTasks += tasksAdded;
      console.log(`  plan ${plan._id}: +${tasksAdded} tasks across ${weeksTouched} weeks`);
    }
  }

  console.log(`[backfillPlanTasks] done. seen=${plansSeen} touched=${plansTouched} weeks=${totalWeeks} tasks=${totalTasks}`);
  await mongoose.disconnect();
}

main().catch(err => {
  console.error('[backfillPlanTasks] fatal:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Smoke-test with `--dry-run` against the local DB if available**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node scripts/migrate/backfillPlanTasks.js --dry-run 2>&1 | tail -10
```

Expected: connects, prints summary line, exits 0. (Skip if no local Mongo — the script will be run by hand against staging/prod.)

- [ ] **Step 3: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add scripts/migrate/backfillPlanTasks.js
git commit -m "chore(plan): backfill script for tasks[] on existing plans"
```

---

## Task 5: iOS — regenerate types, verify `APIPlanTask` decodes

**Files:**
- Modify (auto): `ScaleUp/Generated/OpenAPI/APIPlanTask.swift` (and friends)
- Modify (auto): `ScaleUp/Generated/OpenAPI/APIPlanWeeklyEntry.swift`

The OpenAPI changes from Task 3 land. Regenerate iOS types so the new `tasks: [APIPlanTask]?` field appears on `APIPlanWeeklyEntry`.

- [ ] **Step 1: Run the regeneration script**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && bash scripts/regenerate-openapi-types.sh 2>&1 | tail -30
```

Expected: script exits 0; new files appear under `ScaleUp/Generated/OpenAPI/` (e.g. `APIPlanTask.swift`, `APIPlanTaskTopic.swift`, `APIPlanTaskCompletion.swift`, `APIPlanTaskProgress.swift`).

- [ ] **Step 2: Verify the generated `APIPlanTask` shape**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && cat ScaleUp/Generated/OpenAPI/APIPlanTask.swift 2>/dev/null | head -60
```

Confirm fields: `taskId: String`, `type: TypeEnum` (or similar enum), `topic`, `payload: [String: AnyCodable]?`, `completion`, `progress`. Also confirm `APIPlanWeeklyEntry` now has `tasks: [APIPlanTask]?`:

```bash
grep -n "tasks" ScaleUp/Generated/OpenAPI/APIPlanWeeklyEntry.swift
```

- [ ] **Step 3: Parse-check the generated files**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse ScaleUp/Generated/OpenAPI/APIPlanTask.swift ScaleUp/Generated/OpenAPI/APIPlanWeeklyEntry.swift 2>&1 | tail -10
```

Expected: silent (success) or no errors.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Generated/
git commit -m "feat(ios): regenerate types — APIPlanTask + APIPlanWeeklyEntry.tasks"
```

---

## Task 6: iOS — `ObjectiveBriefCard` component

**Files:**
- Create: `ScaleUp/Features/Plan/Views/Components/ObjectiveBriefCard.swift`
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift` — replace `heroCard(plan)` invocation with `ObjectiveBriefCard(plan: plan)`.

Collapsed by default: shows the plan headline and a small chip row (`12 weeks · 5 hrs/week`). Tap to expand — reveals timeline + commit hours in larger text. Spec §6.1 calls for diagnostic strengths/gaps too — defer those to Phase 5 since they require extra DTO fields.

- [ ] **Step 1: Create the component**

Create `ScaleUp/Features/Plan/Views/Components/ObjectiveBriefCard.swift`:

```swift
import SwiftUI

struct ObjectiveBriefCard: View {
    let plan: PlanDTO
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Eyebrow
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("YOUR OBJECTIVE")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Text(plan.planHeadline)
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.sm) {
                statChip(icon: "calendar", label: "\(plan.totalWeeks) weeks")
                statChip(icon: "clock", label: "\(plan.totalHours, specifier: "%g") hours")
                statChip(icon: "flag", label: "\(plan.milestoneCount) milestones")
            }

            if isExpanded {
                Divider().padding(.vertical, Spacing.xs)
                Text("Buffer: \(plan.bufferRecommendation ?? "We've reserved ~15% of your weekly time as buffer for life events.")")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        }
    }

    private func statChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(Typography.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(ColorTokens.gold.opacity(0.10)))
        .foregroundStyle(ColorTokens.textPrimary)
    }
}
```

If `Typography.displayMedium`, `Typography.micro`, or `ColorTokens.surface` don't exist exactly, swap for the closest equivalents in the project's design-token files. Inspect `ScaleUp/DesignSystem/` (or wherever the tokens live):

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && grep -rn "displayMedium\|titleLarge\|surface" ScaleUp/DesignSystem 2>/dev/null | head -10
```

- [ ] **Step 2: Wire the new component into `PlanTabView`**

In `ScaleUp/Features/Plan/Views/PlanTabView.swift`, find the `planContent(_:)` function. Replace the existing `heroCard(plan)` call with:

```swift
                ObjectiveBriefCard(plan: plan)
                    .padding(.horizontal, Spacing.lg)
```

Delete (or leave for now) the `heroCard(_:)` private function — it's superseded by `ObjectiveBriefCard`. Cleanest: delete it.

- [ ] **Step 3: Parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse ScaleUp/Features/Plan/Views/Components/ObjectiveBriefCard.swift ScaleUp/Features/Plan/Views/PlanTabView.swift 2>&1 | tail -10
```

Expected: silent.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/Views/Components/ObjectiveBriefCard.swift ScaleUp/Features/Plan/Views/PlanTabView.swift
git commit -m "feat(ios-plan): ObjectiveBriefCard with expand/collapse"
```

---

## Task 7: iOS — `NextCheckInPill` component

**Files:**
- Create: `ScaleUp/Features/Plan/Views/Components/NextCheckInPill.swift`
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift` — render the pill below the brief card.

Shows "Next check-in: in N days" computed from `plan.nextCheckInAt`. If eligible *now* (today >= nextCheckInAt), shows "Recalibrate now →" as a CTA that delegates to the existing `RecalibrationViewModel.eligibility` flow.

- [ ] **Step 1: Create the component**

Create `ScaleUp/Features/Plan/Views/Components/NextCheckInPill.swift`:

```swift
import SwiftUI

struct NextCheckInPill: View {
    let nextCheckInAt: Date?
    let isEligibleNow: Bool
    let onRecalibrateTap: () -> Void

    var body: some View {
        if isEligibleNow {
            Button(action: onRecalibrateTap) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Recalibrate now")
                        .font(Typography.bodyMedium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .foregroundStyle(ColorTokens.gold)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ColorTokens.gold.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(ColorTokens.gold.opacity(0.30), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(label)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.surface.opacity(0.5))
            )
        }
    }

    private var label: String {
        guard let date = nextCheckInAt else { return "Next check-in pending" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days <= 0 { return "Check-in available" }
        if days == 1 { return "Next check-in tomorrow" }
        return "Next check-in in \(days) days"
    }
}
```

- [ ] **Step 2: Wire it into `PlanTabView`**

In `planContent(_:)`, just below the `ObjectiveBriefCard` block:

```swift
                NextCheckInPill(
                    nextCheckInAt: plan.nextCheckInAt,
                    isEligibleNow: recalVM.eligibility?.eligible == true,
                    onRecalibrateTap: { showRecalibration = true }
                )
                .padding(.horizontal, Spacing.lg)
```

Confirm `plan.nextCheckInAt` exists on `PlanDTO` (Phase 1 added it via openapi regen). If `PlanDTO` is `typealias PlanDTO = APIPlanCurrent`, the field is auto-decoded as `Date?`. If hand-rolled, ensure `let nextCheckInAt: Date?` is present.

Also: with the new pill in place, the existing `RecalibrationNudge` component (currently shown above `heroCard`) is now redundant — its CTA duplicates the pill. Delete the `if let eligibility = recalVM.eligibility, eligibility.eligible { RecalibrationNudge(...) }` block from `planContent(_:)`.

- [ ] **Step 3: Parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse ScaleUp/Features/Plan/Views/Components/NextCheckInPill.swift ScaleUp/Features/Plan/Views/PlanTabView.swift 2>&1 | tail -10
```

Expected: silent.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/Views/Components/NextCheckInPill.swift ScaleUp/Features/Plan/Views/PlanTabView.swift
git commit -m "feat(ios-plan): NextCheckInPill replaces RecalibrationNudge"
```

---

## Task 8: iOS — `TaskRow` + `ThisWeekTasksList` + tap-to-launch

**Files:**
- Create: `ScaleUp/Features/Plan/Views/Components/TaskRow.swift`
- Create: `ScaleUp/Features/Plan/Views/Components/ThisWeekTasksList.swift`
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift`
- Modify: `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift` — expose a `currentWeekTasks` computed property.

Renders a row per task in the current week, ordered: pending → in_progress → complete. Tap a quiz row → push existing quiz player. Tap a content row → push existing content viewer. (Reuse the navigation patterns already used by Home tab; if those use `.navigationDestination(value:)` etc., follow that.)

- [ ] **Step 1: Add `currentWeekTasks` to the view model**

In `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift`, add:

```swift
extension PlanTabViewModel {
    /// Returns the tasks of the smallest week index that still has any pending or in_progress task.
    /// Mirrors backend `findCurrentWeekIndex` so the UI shows what the user should be doing now.
    func currentWeekTasks(in plan: PlanDTO) -> (weekNumber: Int, weekLabel: String, tasks: [APIPlanTask])? {
        for week in plan.weeklySchedule {
            let tasks = week.tasks ?? []
            if tasks.contains(where: { $0.progress.status == "pending" || $0.progress.status == "in_progress" }) {
                return (week.weekNumber, week.weekLabel, tasks)
            }
        }
        // All weeks complete — show the last week's tasks (all complete) so the user sees the wrap-up state.
        if let last = plan.weeklySchedule.last {
            return (last.weekNumber, last.weekLabel, last.tasks ?? [])
        }
        return nil
    }
}
```

(`APIPlanTask`'s `type` and `progress.status` may be enum types after regen. If so, replace `"pending"` with the enum case, e.g. `.pending`. Inspect the generated file to confirm.)

- [ ] **Step 2: Create `TaskRow`**

Create `ScaleUp/Features/Plan/Views/Components/TaskRow.swift`:

```swift
import SwiftUI

struct TaskRow: View {
    let task: APIPlanTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(rowTitle)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(typeLabel + " · " + task.topic.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                statusChip
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.surface)
            )
            .opacity(isComplete ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var isComplete: Bool { task.progress.status == "complete" }
    private var isInProgress: Bool { task.progress.status == "in_progress" }

    private var rowTitle: String {
        switch task.type {
        case "quiz": return "Quiz: \(task.topic.displayName)"
        case "in_app_content": return "Read: \(task.topic.displayName)"
        case "ai_interview": return "Mock interview: \(task.topic.displayName)"
        case "external_link": return (task.payload?["title"]?.value as? String) ?? task.topic.displayName
        case "competition": return "Compete: \(task.topic.displayName)"
        case "manual": return (task.payload?["title"]?.value as? String) ?? task.topic.displayName
        default: return task.topic.displayName
        }
    }

    private var typeLabel: String {
        switch task.type {
        case "quiz": return "Quiz"
        case "in_app_content": return "Content"
        case "ai_interview": return "Interview"
        case "external_link": return "External"
        case "competition": return "Competition"
        case "manual": return "Off-platform"
        default: return "Task"
        }
    }

    private var iconName: String {
        switch task.type {
        case "quiz": return "checkmark.circle"
        case "in_app_content": return "book"
        case "ai_interview": return "mic"
        case "external_link": return "arrow.up.right.square"
        case "competition": return "trophy"
        case "manual": return "hand.raised"
        default: return "circle"
        }
    }

    private var iconBackground: Color {
        isComplete ? ColorTokens.gold.opacity(0.05) : ColorTokens.gold.opacity(0.15)
    }

    private var iconForeground: Color {
        isComplete ? ColorTokens.textTertiary : ColorTokens.gold
    }

    @ViewBuilder
    private var statusChip: some View {
        if isComplete {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.gold)
        } else if isInProgress {
            Text("In progress")
                .font(Typography.micro)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(ColorTokens.gold.opacity(0.10)))
                .foregroundStyle(ColorTokens.gold)
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
}
```

(Note: `APIPlanTask.type` and `progress.status` are likely enum types with raw string values after regen — if so, compare via `.rawValue == "quiz"` or use the actual enum cases.)

- [ ] **Step 3: Create `ThisWeekTasksList`**

Create `ScaleUp/Features/Plan/Views/Components/ThisWeekTasksList.swift`:

```swift
import SwiftUI

struct ThisWeekTasksList: View {
    let weekNumber: Int
    let weekLabel: String
    let tasks: [APIPlanTask]
    let onTaskTap: (APIPlanTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("THIS WEEK · WEEK \(weekNumber)")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                if !tasks.isEmpty {
                    let done = tasks.filter { $0.progress.status == "complete" }.count
                    Text("\(done) / \(tasks.count) done")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }

            Text(weekLabel)
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            if tasks.isEmpty {
                Text("No tasks for this week. Open a topic from your plan and start anywhere.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.vertical, Spacing.md)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(orderedTasks, id: \.taskId) { task in
                        TaskRow(task: task, onTap: { onTaskTap(task) })
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var orderedTasks: [APIPlanTask] {
        // pending first, in_progress next, complete last; stable within each group.
        let priority: (String) -> Int = {
            switch $0 {
            case "pending": return 0
            case "in_progress": return 1
            case "complete": return 2
            default: return 3
            }
        }
        return tasks.sorted { priority($0.progress.status) < priority($1.progress.status) }
    }
}
```

- [ ] **Step 4: Wire into `PlanTabView`**

In `PlanTabView.swift`'s `planContent(_:)`, REPLACE the existing `weeklySection(plan.weeklySchedule)` call with:

```swift
                if let current = viewModel.currentWeekTasks(in: plan) {
                    ThisWeekTasksList(
                        weekNumber: current.weekNumber,
                        weekLabel: current.weekLabel,
                        tasks: current.tasks,
                        onTaskTap: { task in handleTaskTap(task) }
                    )
                }
```

Add the `handleTaskTap` helper to the view (private function on `PlanTabView`):

```swift
    private func handleTaskTap(_ task: APIPlanTask) {
        switch task.type {
        case "quiz":
            if let quizId = task.payload?["quizId"]?.value as? String {
                // TODO: navigate to quiz player. For now, fire an analytics event so we know the user tapped.
                AnalyticsService.shared.track(.planTaskTapped(taskType: "quiz", taskId: task.taskId))
                // Hand-off to existing quiz navigation. If the project uses a router/coordinator,
                // call it here. Otherwise inspect Home or Quizzes tabs for the launch pattern.
                _ = quizId
            }
        case "in_app_content":
            if let contentId = task.payload?["contentId"]?.value as? String {
                AnalyticsService.shared.track(.planTaskTapped(taskType: "in_app_content", taskId: task.taskId))
                _ = contentId
            }
        default:
            break
        }
    }
```

If `AnalyticsEvent.planTaskTapped(taskType:taskId:)` doesn't exist yet, add it to `AnalyticsEvent.swift` near the other `plan*` events (mirror the shape of `planGenerationFallback`).

- [ ] **Step 5: Wire actual navigation** (best-effort)

Find the existing quiz launcher and content launcher:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && grep -rn "QuizPlayerView\|ContentDetailView\|\\.navigationDestination" ScaleUp/Features/Quizzes ScaleUp/Features/Content 2>/dev/null | head -10
```

Replace the `_ = quizId` / `_ = contentId` placeholders with the project's existing navigation pattern (likely a sheet, NavigationLink, or coordinator method). If you can't find a clean integration in <10 minutes, leave the placeholders + analytics and report this as a follow-up — the visible task list is still the major Phase 2 win, and a "open" affordance can land in Phase 2.5.

- [ ] **Step 6: Parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse \
  ScaleUp/Features/Plan/Views/Components/TaskRow.swift \
  ScaleUp/Features/Plan/Views/Components/ThisWeekTasksList.swift \
  ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift \
  ScaleUp/Features/Plan/Views/PlanTabView.swift 2>&1 | tail -10
```

Expected: silent.

- [ ] **Step 7: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/ ScaleUp/Core/Analytics/AnalyticsEvent.swift 2>/dev/null
git diff --cached --quiet || git commit -m "feat(ios-plan): ThisWeekTasksList renders current-week tasks with tap-to-launch"
```

---

## Task 9: Phase 2 acceptance — full test sweep + e2e smoke

Final guardrail. Runs every backend test, lints OpenAPI, builds iOS (or parse-only smoke), and runs the backfill script in dry-run mode.

- [ ] **Step 1: Run full backend test suite**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test 2>&1 | tail -30
```

Expected: pre-existing `diagnostic-e2e-upskilling.test.js` timeout is the only failure. If anything else broke, investigate.

- [ ] **Step 2: Lint OpenAPI**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm run openapi:lint 2>&1 | tail -10
```

Expected: 0 errors.

- [ ] **Step 3: Run OpenAPI contract test** (already exists in the suite — explicit invocation as a Phase-2 gate)

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm run openapi:contract-test 2>&1 | tail -20
```

Expected: PASS. The new `tasks[]` field on the response should not break the contract test (contract test uses spec-described shape; we updated the spec in Task 3).

- [ ] **Step 4: Backfill dry-run** (against staging if you have access; against local Mongo if available)

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node scripts/migrate/backfillPlanTasks.js --dry-run 2>&1 | tail -10
```

Expected: connects, prints `seen=N touched=M weeks=W tasks=T`, exits 0.

- [ ] **Step 5: Build iOS** (full build if simulator available; else parse-only)

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -30
```

If simulator isn't installed:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && find ScaleUp/Features/Plan ScaleUp/Generated/OpenAPI -name "*.swift" -print0 | xargs -0 xcrun swiftc -parse 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED, or parse silent.

- [ ] **Step 6: No commit needed** (acceptance only).

---

## What Phase 2 ships

After this plan executes:
- Plans persist `tasks[]` per week, populated with `quiz` + `in_app_content` tasks resolved from the existing Quiz/Content collections.
- `GET /plan/current` returns those tasks in the response, OpenAPI-documented.
- iOS Plan tab shows: an objective brief (collapsible), a next-check-in pill, and a this-week tasks list ordered pending → in-progress → complete with auto-completion wired through Phase 1's `planProgressService`.
- Existing plans get tasks via the backfill script (run manually after deploy).

**What Phase 2 does NOT ship:**
- Interview / competition / external_link / manual task types. Phase 3.
- LLM-as-judge external link curation. Phase 4.
- Journey timeline (week-by-week strip). Phase 5.
- Manual completion sheet (no manual tasks yet to need it). Phase 3.
- Diagnostic strengths/gaps inside the objective brief expand state. Phase 5 polish.
- Android RN. Phase 2.5.

Phase 3 is the next plan: ai_interview (gated), competition, manual task types + the manual completion sheet with self-rating chips.

---

## Self-review checklist (already applied)

- ✅ Spec coverage: Phase-2 bullets from spec §7 all map to tasks. (Generator emits quiz+content → Tasks 1+2; objective brief → Task 6; next check-in pill → Task 7; this-week list → Task 8; manual completion sheet pre-staged → deferred to Phase 3 since no manual task types ship in Phase 2.)
- ✅ Placeholder scan: no TBD / TODO / "implement later" except the explicit "navigation TODO" in Task 8 step 5 with clear fallback.
- ✅ Type consistency: `topic.canonicalName` flows from generator → DB → API → iOS unchanged. `progress.status` enum values are consistent. `payload.quizId` / `payload.contentId` referenced consistently.
- ✅ Phase 1 dependencies: all assumed services (`planProgressService`, `nextCheckInAt`, `Plan.tasks[]` schema) exist on master at the SHAs referenced in the header.
