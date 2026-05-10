# Phase 7 — Intelligence

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining quality + intelligence gaps surfaced after Phase 6: lazy quiz generation when no quiz exists, direct Plan→QuizSession nav, Topic Mastery section on Plan tab, auto-calibration soft-realignment worker, external content fetcher feeding the LLM judge, then turn the LLM judge on.

**Architecture summary:**
- **Lazy quiz gen** — `taskCatalogService.resolveTopic` synchronously generates a quiz via existing `quizGenerationService.generateQuiz` when none exists (with a 15s timeout fallback to no-quiz). Plan generation is already async via the worker, so user-invisible.
- **Direct Plan→play** — `PlanTaskQuizLoaderSheet` (iOS) and the Android equivalent skip `QuizDetailView`/`QuizDetailScreen` and go straight to `QuizSession`/`QuizSessionScreen`. Saves 1-2 taps.
- **Topic Mastery section** — new endpoint `GET /plan/mastery` aggregates `KnowledgeProfile.topicMastery`, `ContentProgress`, `ExternalContentTouch`, `InterviewSession`, `KnowledgeProfile.topicInterviewMastery` per topic. iOS+Android render a collapsible section between JourneyTimelineStrip and Milestones.
- **Auto-calibration** — new `weeklyAutoCalibrationWorker.js` cron job runs nightly; for users with `daysSinceLastAttempt >= 7` AND signal score >= 5, soft-realigns the existing plan by re-running the post-processor on remaining weeks (no new diagnostic). Pushes "Your plan adapted to this week's progress 🎯".
- **External content fetcher** — `externalContentFetcherService.js` scrapes HTML via `node-html-parser` + Mozilla Readability, falls back to YouTube transcripts via `youtube-transcript`. Cached in new `ExternalContentSnapshot` collection (TTL 30 days). Judge prompt now includes the fetched excerpt instead of just URL+title.
- **Turn on judge** — set `FEATURE_EXTERNAL_CONTENT_JUDGE=true` in EC2 env.

**Phase 1-6 prerequisite:**
- Backend HEAD: `a506c9c` (Phase 6 interview redesign)
- iOS HEAD: `81fcd25`
- Android HEAD: `a70c7f2`

---

## File Structure

**Created:**
- `scaleup-backend/src/workers/weeklyAutoCalibrationWorker.js` + `.test.js`
- `scaleup-backend/src/services/plan/externalContentFetcherService.js` + `.test.js`
- `scaleup-backend/src/models/ExternalContentSnapshot.js` + `.test.js`
- `scaleup-backend/src/services/plan/topicMasteryService.js` + `.test.js`
- `ScaleUp/Features/Plan/Views/Components/TopicMasterySection.swift`
- `ScaleUpAndroid/src/screens/plan/components/TopicMasterySection.tsx`

**Modified:**
- `scaleup-backend/src/services/plan/taskCatalogService.js` — lazy quiz gen
- `scaleup-backend/src/services/plan/taskCatalogService.test.js`
- `scaleup-backend/src/services/plan/externalContentJudgeService.js` — pass excerpt to judge prompt
- `scaleup-backend/src/services/plan/externalContentJudgeService.test.js`
- `scaleup-backend/src/controllers/planController.js` — `getMastery` handler
- `scaleup-backend/src/controllers/planController.test.js`
- `scaleup-backend/src/routes/plan.js`
- `scaleup-backend/openapi.yaml` — `GET /plan/mastery`
- `scaleup-backend/src/workers/index.js` — register the cron worker
- `scaleup-backend/src/workers/cronJobs.js` — wire weekly auto-cal cron
- `scaleup-backend/package.json` — `node-html-parser`, `@mozilla/readability`, `youtube-transcript`, `axios`
- `ScaleUp/Features/Plan/Views/Components/PlanTaskQuizLoaderSheet.swift` — direct to QuizSession (skip Detail)
- `ScaleUp/Features/Plan/Views/PlanTabView.swift` — render TopicMasterySection
- `ScaleUpAndroid/src/screens/plan/PlanTabScreen.tsx` — same Android wiring
- `ScaleUpAndroid/src/services/planService.ts` — `fetchMastery()`

---

## Task 1 — Lazy quiz generation in taskCatalogService

**Files:** `taskCatalogService.js` + its test.

When `Quiz.findOne({topic, objectiveId})` and the global fallback both return null, **synchronously** call `quizGenerationService.generateQuiz({userId, topic, contentIds: [], type: 'plan_seed', questionCount: 5})` with a 15-second timeout. On success, return the new quiz's `_id`. On timeout/failure, return `quizId: null` (existing behavior — manual fallback fires).

- [ ] **Step 1: Inspect `quizGenerationService.generateQuiz` signature**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
grep -n "async generateQuiz\|^function generateQuiz\|module.exports" src/services/quizGenerationService.js | head -10
```

Confirm it returns a saved `Quiz` document (with `_id`).

- [ ] **Step 2: Patch `resolveTopic`**

In `src/services/plan/taskCatalogService.js`, after the 2-tier `Quiz.findOne` lookup but BEFORE the content lookup, add:

```javascript
  // Phase 7: lazy quiz generation — if no quiz exists, generate one on demand.
  // Synchronous wait with a hard timeout. Plan generation is already async via
  // the worker, so the latency hit is invisible to the user.
  if (!quiz && objectiveId) {
    try {
      const quizGenerationService = require('../quizGenerationService');
      const userId = arguments[0]?.userId; // not currently in signature — see below
      // We need userId — extend resolveTopic signature
      const generated = await Promise.race([
        quizGenerationService.generateQuiz({
          userId,
          objectiveId,
          topic: key,
          contentIds: [],
          type: 'plan_seed',
          questionCount: 5,
        }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('lazy_gen_timeout')), 15000)),
      ]);
      if (generated && generated._id) {
        quiz = generated;
      }
    } catch (err) {
      console.warn('[taskCatalogService] lazy quiz gen failed:', err.message);
    }
  }
```

This requires extending `resolveTopic`'s signature to accept `userId`. Update:

```javascript
async function resolveTopic({ topicCanonicalName, objectiveType, objectiveId, userId }) {
  // ... existing logic ...
}
```

Also update **the caller** in `src/services/diagnostic/planGenerationService.js`. Find the existing `taskCatalogService.resolveTopic({...})` call inside the per-allocation loop. Add `userId: input.userId` to the args object.

- [ ] **Step 3: Update tests**

In `src/services/plan/taskCatalogService.test.js`, the existing test "returns nulls when neither quiz nor content found" needs adapting — it now triggers lazy gen. Stub `quizGenerationService.generateQuiz`:

```javascript
test('resolveTopic: lazy-generates quiz when none exists', async () => {
  const quizGenerationService = require('../quizGenerationService');
  const orig = quizGenerationService.generateQuiz;
  const generatedQuizId = new mongoose.Types.ObjectId();
  quizGenerationService.generateQuiz = async () => ({ _id: generatedQuizId, topic: 'foo', estimatedMinutes: 8 });

  const origQuizFind = Quiz.findOne;
  Quiz.findOne = () => makeQuery(null);
  const origContentFind = Content.findOne;
  Content.findOne = () => makeQuery(null);

  try {
    const out = await taskCatalogService.resolveTopic({
      topicCanonicalName: 'foo',
      objectiveType: 'upskilling',
      objectiveId: new mongoose.Types.ObjectId(),
      userId: new mongoose.Types.ObjectId(),
    });
    assert.strictEqual(out.quizId, String(generatedQuizId));
  } finally {
    Quiz.findOne = origQuizFind;
    Content.findOne = origContentFind;
    quizGenerationService.generateQuiz = orig;
  }
});

test('resolveTopic: returns null quizId when lazy gen times out', async () => {
  const quizGenerationService = require('../quizGenerationService');
  const orig = quizGenerationService.generateQuiz;
  // Never resolves — forces the 15s timeout. Use a smaller timeout via env if the production timeout is too long for tests.
  // For tests, instead simulate immediate failure:
  quizGenerationService.generateQuiz = async () => { throw new Error('synthetic fail'); };

  const origQuizFind = Quiz.findOne;
  Quiz.findOne = () => makeQuery(null);
  const origContentFind = Content.findOne;
  Content.findOne = () => makeQuery(null);

  try {
    const out = await taskCatalogService.resolveTopic({
      topicCanonicalName: 'foo',
      objectiveType: 'upskilling',
      objectiveId: new mongoose.Types.ObjectId(),
      userId: new mongoose.Types.ObjectId(),
    });
    assert.strictEqual(out.quizId, null);
  } finally {
    Quiz.findOne = origQuizFind;
    Content.findOne = origContentFind;
    quizGenerationService.generateQuiz = orig;
  }
});
```

The existing "returns nulls when neither quiz nor content found" test should be updated to either stub `generateQuiz` to fail OR expect the new behavior (quiz now gets generated).

- [ ] **Step 4: Test, commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
node --test src/services/plan/taskCatalogService.test.js src/services/diagnostic/planGenerationService.test.js
git add src/services/plan/taskCatalogService.js src/services/plan/taskCatalogService.test.js src/services/diagnostic/planGenerationService.js
git commit -m "feat(plan): taskCatalogService lazy-generates quiz when missing"
```

---

## Task 2 — Plan→QuizSession direct nav (skip QuizDetailView)

**iOS:** modify `PlanTaskQuizLoaderSheet.swift` to present `QuizSessionView` (or whatever the play screen is named) instead of `QuizDetailView`. Inspect first:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
grep -rn "QuizSessionView\|struct QuizSession" ScaleUp/Features/Quiz | head -5
```

If `QuizSessionView(quiz:)` exists, replace `QuizDetailView(quiz: quiz)` in the loader sheet with `QuizSessionView(quiz: quiz)`. If the session screen needs additional setup (e.g., a viewmodel), inspect how `QuizDetailView`'s "Start" button does it and replicate that.

If nav is more complex (Detail → Session via a `NavigationLink`), consider keeping the Detail view but auto-tapping Start on appear. Easier: keep this Phase 7 scope to "as direct as possible without redesigning Quiz feature".

**Android:** same — `'QuizDetail'` → `'QuizSession'` route swap in `PlanTabScreen.tsx`'s `handleTaskTap`. The route already exists in `MyPlanStackParamList`.

```typescript
case 'quiz': {
  // Existing fetch-then-navigate flow. Change destination from QuizDetail to QuizSession.
  QuizService.fetchQuizDetail(quizId)
    .then(quiz => navigation.navigate('QuizSession' as never, {quiz} as never))  // was 'QuizDetail'
    .catch(() => Alert.alert("Couldn't open quiz", "..."))
}
```

- [ ] **Step 1: iOS — read existing detail/session structure**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
grep -n "struct QuizSessionView\|struct QuizDetailView\|init(quiz:" ScaleUp/Features/Quiz/Views/QuizSessionView.swift ScaleUp/Features/Quiz/Views/QuizDetailView.swift 2>/dev/null
```

- [ ] **Step 2: iOS — patch loader sheet**

In `ScaleUp/Features/Plan/Views/Components/PlanTaskQuizLoaderSheet.swift`, replace `QuizDetailView(quiz: quiz)` with whatever directly starts the quiz. If `QuizSessionView` requires more setup, the safe minimum is to keep `QuizDetailView` but auto-advance on appear — though the cleaner option is to use the session view directly.

If unable to find a clean direct-entry path in <15 minutes of investigation, **leave QuizDetailView** and add a comment note for follow-up:
```swift
// TODO Phase 7+: skip QuizDetailView and go directly to QuizSessionView when
// the Quiz feature exposes a single-call session entry. Today QuizDetailView
// → tap Start → QuizSession is the established pattern.
```

- [ ] **Step 3: Android — patch handleTaskTap**

In `src/screens/plan/PlanTabScreen.tsx`, find the `'quiz'` branch in `handleTaskTap`. Change `navigate('QuizDetail', {quiz})` to `navigate('QuizSession', {quiz})`. The QuizSession route already takes `{quiz: Quiz}` per `MyPlanStackParamList`.

- [ ] **Step 4: Parse + tsc, commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcrun swiftc -parse ScaleUp/Features/Plan/Views/Components/PlanTaskQuizLoaderSheet.swift 2>&1 | tail -5
git add ScaleUp/Features/Plan/
git commit -m "feat(ios-plan): direct Plan→QuizSession (skip QuizDetailView)"

cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
npx tsc --noEmit 2>&1 | grep -E "src/screens/plan" | head -5
git add src/screens/plan/PlanTabScreen.tsx
git commit -m "feat(android-plan): direct Plan→QuizSession (skip QuizDetail)"
```

---

## Task 3 — Topic Mastery section (backend + iOS + Android)

### Part A — Backend: `topicMasteryService` + `GET /plan/mastery`

- [ ] **Step 1: Create `topicMasteryService.js`**

`src/services/plan/topicMasteryService.js`:

```javascript
const KnowledgeProfile = require('../../models/KnowledgeProfile');
const ContentProgress = require('../../models/ContentProgress');
const Content = require('../../models/Content');
const ExternalContentTouch = require('../../models/ExternalContentTouch');
const InterviewSession = require('../../models/InterviewSession');
const Plan = require('../../models/Plan');

/**
 * Aggregates per-topic mastery + objective-level interview mastery for the
 * Plan tab's Topic Mastery section.
 *
 * Returns:
 *   {
 *     topics: [{
 *       canonicalName, displayName, level, score,
 *       quizzesTaken, contentConsumed, externalTouches,
 *       lastAssessedAt, scoreHistory, trend,
 *     }],
 *     interview: {
 *       totalSessions, averageScore, trend, perTopic: [{topic, score, sessions, trend}],
 *     },
 *   }
 */
async function getMasterySummary(userId) {
  const [profile, plan] = await Promise.all([
    KnowledgeProfile.findOne({ userId }).lean(),
    Plan.findOne({ userId, isActive: true }).lean(),
  ]);

  // Build display-name lookup from plan tasks (plan tasks carry topic.displayName)
  const displayByCanonical = new Map();
  if (plan?.weeklySchedule) {
    for (const week of plan.weeklySchedule) {
      for (const task of (week.tasks || [])) {
        if (task.topic?.canonicalName) {
          displayByCanonical.set(task.topic.canonicalName, task.topic.displayName);
        }
      }
    }
  }

  // Per-topic content consumed counts: ContentProgress filtered by topic
  // is expensive to compute precisely; use a heuristic — count completed
  // ContentProgress rows whose linked Content.topics array intersects the
  // user's topic set.
  const topicNames = (profile?.topicMastery || []).map(t => t.topic);
  const contentProgressByTopic = await contentCountsPerTopic(userId, topicNames);
  const externalTouchByTopic = await externalTouchCounts(userId, topicNames);

  const topics = (profile?.topicMastery || []).map(t => ({
    canonicalName: t.topic,
    displayName: displayByCanonical.get(t.topic) || titleCase(t.topic),
    level: t.level,
    score: t.score,
    quizzesTaken: t.quizzesTaken || 0,
    contentConsumed: contentProgressByTopic[t.topic] || 0,
    externalTouches: externalTouchByTopic[t.topic] || 0,
    lastAssessedAt: t.lastAssessedAt || null,
    scoreHistory: (t.scoreHistory || []).slice(-10).map(s => ({ score: s.score, date: s.date })),
    trend: t.trend || 'stable',
  }));

  // Objective-level interview rollup
  const interviewSessions = await InterviewSession.find({
    userId,
    status: { $in: ['completed', 'evaluated'] },
  }).sort({ completedAt: -1 }).limit(20).lean();

  const totalSessions = interviewSessions.length;
  const averageScore = totalSessions > 0
    ? Math.round(
        (interviewSessions.reduce((s, sess) => s + (sess.evaluation?.overallScore || 0), 0) / totalSessions) * 10
      ) / 10
    : 0;
  const interviewTrend = computeTrendFromScores(
    interviewSessions.slice(0, 6).map(s => s.evaluation?.overallScore || 0).reverse()
  );

  // Per-topic interview rollup from KnowledgeProfile.topicInterviewMastery
  const perTopic = [];
  const mastery = profile?.topicInterviewMastery || {};
  const masteryEntries = mastery instanceof Map ? mastery.entries() : Object.entries(mastery);
  for (const [topic, m] of masteryEntries) {
    perTopic.push({
      topic,
      displayName: displayByCanonical.get(topic) || titleCase(topic),
      score: m.score || 0,
      sessions: m.sessions || 0,
      trend: m.trend || 'stable',
    });
  }
  perTopic.sort((a, b) => b.sessions - a.sessions);

  return {
    topics,
    interview: { totalSessions, averageScore, trend: interviewTrend, perTopic },
  };
}

async function contentCountsPerTopic(userId, topicNames) {
  if (!topicNames.length) return {};
  const progresses = await ContentProgress.find({ userId, isCompleted: true })
    .populate('contentId', 'topics')
    .lean();
  const counts = {};
  for (const t of topicNames) counts[t] = 0;
  for (const p of progresses) {
    const topics = p.contentId?.topics || [];
    for (const t of topics) {
      if (counts[t] !== undefined) counts[t]++;
    }
  }
  return counts;
}

async function externalTouchCounts(userId, topicNames) {
  if (!topicNames.length) return {};
  const counts = {};
  for (const t of topicNames) counts[t] = 0;
  const touches = await ExternalContentTouch.find({ userId, topicCanonicalName: { $in: topicNames } })
    .select('topicCanonicalName').lean();
  for (const t of touches) {
    if (counts[t.topicCanonicalName] !== undefined) counts[t.topicCanonicalName]++;
  }
  return counts;
}

function titleCase(canonical) {
  return String(canonical || '').replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

function computeTrendFromScores(scores) {
  if (!scores || scores.length < 3) return 'stable';
  const recent = scores.slice(-3);
  const earlier = scores.slice(-6, -3);
  if (earlier.length === 0) return 'stable';
  const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
  const earlierAvg = earlier.reduce((a, b) => a + b, 0) / earlier.length;
  if (recentAvg - earlierAvg > 5) return 'improving';
  if (earlierAvg - recentAvg > 5) return 'declining';
  return 'stable';
}

module.exports = { getMasterySummary };
```

- [ ] **Step 2: Test the service**

`topicMasteryService.test.js` — 1-2 tests with stubbed model finds. Stub `KnowledgeProfile.findOne`, `Plan.findOne`, `ContentProgress.find`, `ExternalContentTouch.find`, `InterviewSession.find`. Assert the shape and aggregation logic.

- [ ] **Step 3: Add controller + route + openapi**

In `src/controllers/planController.js` add:

```javascript
async function getMastery(req, res) {
  try {
    const topicMasteryService = require('../services/plan/topicMasteryService');
    const summary = await topicMasteryService.getMasterySummary(req.user.userId);
    return res.status(200).json(apiResponse.success(summary));
  } catch (err) {
    console.error('[planController.getMastery]', err);
    return res.status(500).json(apiResponse.error('internal_error'));
  }
}
```

Export it. Add route `router.get('/mastery', ctrl.getMastery)` in `src/routes/plan.js`.

OpenAPI: add `/api/v1/plan/mastery` GET operation with response schema matching the service return shape.

- [ ] **Step 4: Commit backend Topic Mastery**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/plan/topicMasteryService.js src/services/plan/topicMasteryService.test.js src/controllers/planController.js src/controllers/planController.test.js src/routes/plan.js openapi.yaml
git commit -m "feat(plan): topicMasteryService + GET /plan/mastery endpoint"
```

### Part B — iOS TopicMasterySection

- [ ] **Step 5: regen iOS types** so `APIPlanMastery*` types appear:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && bash scripts/regenerate-openapi-types.sh 2>&1 | tail -10
```

- [ ] **Step 6: PlanService gains `fetchMastery()`**

Add a new endpoint case + method to `PlanService.swift`:

```swift
private enum PlanEndpoints: Endpoint {
    case status, current, markTaskComplete(taskId: String), mastery
    var path: String {
        switch self {
        // ... existing ...
        case .mastery: return "/plan/mastery"
        }
    }
    var method: HTTPMethod {
        switch self {
        case .status, .current, .mastery: return .get
        case .markTaskComplete: return .post
        }
    }
}

extension PlanService {
    func fetchMastery() async throws -> APIPlanMastery {  // adapt to actual generated type name
        try await api.request(PlanEndpoints.mastery)
    }
}
```

- [ ] **Step 7: Create `TopicMasterySection.swift`**

A collapsible section between JourneyTimelineStrip and Milestones. Top row shows objective-level interview rollup (when relevant). Below it, a horizontal chip row of topics colored by band; tap a chip → expands to show per-topic stats card (level, sparkline of scoreHistory, quizzesTaken/contentConsumed/externalTouches, last assessed).

Skeleton (adapt design tokens):

```swift
struct TopicMasterySection: View {
    let mastery: APIPlanMastery
    @State private var selectedTopic: String?
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Eyebrow
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("YOUR PROGRESS BY TOPIC")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }

            if isExpanded {
                if mastery.interview.totalSessions > 0 {
                    interviewRollupCard
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(mastery.topics, id: \.canonicalName) { t in
                            topicChip(t)
                        }
                    }
                }
                if let sel = selectedTopic, let detail = mastery.topics.first(where: { $0.canonicalName == sel }) {
                    topicDetailCard(detail)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // ... topicChip, topicDetailCard, interviewRollupCard helpers ...
}
```

Wire into `PlanTabView.planContent(_:)` between the JourneyTimelineStrip ForEach block and the milestones section. Load mastery in the view model and pass it down.

- [ ] **Step 8: Commit iOS**

### Part C — Android TopicMasterySection

- [ ] **Step 9: regen Android types**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npm run openapi:regen
```

- [ ] **Step 10: Add `fetchMastery` to `planService.ts`**

```typescript
fetchMastery: () => api.get<PlanMastery>('/plan/mastery'),
```

(Re-export `PlanMastery` from `api.ts`.)

- [ ] **Step 11: Create `TopicMasterySection.tsx`**

Mirror iOS. Collapsible header + interview rollup card + horizontal topic chips + per-topic detail expansion. Use existing tokens.

- [ ] **Step 12: Wire into PlanTabScreen + commit**

---

## Task 4 — Auto-calibration soft-realignment worker

**File:** `src/workers/weeklyAutoCalibrationWorker.js`

**Strategy:** "soft" realignment — re-run the post-processor on the existing plan's REMAINING weeks (current week + future). DON'T regenerate the whole plan; preserve `weeklyGoal` and `allocations`, just refresh `tasks[]` based on current `KnowledgeProfile`. This is cheaper than a full LLM regen and matches the user's expectation that "weekly realignment happens".

Trigger: cron at 03:00 IST nightly. For each user with active plan + `daysSinceLastAttempt >= 7` AND signal score >= 5, run soft realignment.

Signal score = `tasksCompletedLast7d + 0.5*hoursSpentLast7d + 2*interviewsLast7d + externalTouchesLast7d`. For inactive users (signal=0), skip silently. For semi-active (1-4), skip too (not enough signal for meaningful realignment).

- [ ] **Step 1: Create the worker**

`src/workers/weeklyAutoCalibrationWorker.js`:

```javascript
const Plan = require('../models/Plan');
const KnowledgeProfile = require('../models/KnowledgeProfile');
const QuizAttempt = require('../models/QuizAttempt');
const ContentProgress = require('../models/ContentProgress');
const InterviewSession = require('../models/InterviewSession');
const ExternalContentTouch = require('../models/ExternalContentTouch');
const DiagnosticAttempt = require('../models/DiagnosticAttempt');
const taskCatalogService = require('../services/plan/taskCatalogService');
const externalContentJudgeService = require('../services/plan/externalContentJudgeService');
const { notificationQueue } = require('../config/queue');

const SIGNAL_THRESHOLD = 5;
const MIN_DAYS_SINCE_LAST_ATTEMPT = 7;

async function computeSignal(userId, since) {
  const [tasksCompleted, contentProgresses, interviews, externalTouches] = await Promise.all([
    QuizAttempt.countDocuments({ userId, completedAt: { $gte: since } }),
    ContentProgress.countDocuments({ userId, isCompleted: true, completedAt: { $gte: since } }),
    InterviewSession.countDocuments({ userId, status: 'evaluated', completedAt: { $gte: since } }),
    ExternalContentTouch.countDocuments({ userId, completedAt: { $gte: since } }),
  ]);
  // hoursSpent is harder to compute exactly — skip for v1, use task counts
  return tasksCompleted + 2 * interviews + externalTouches;
}

async function softRealignPlan(plan, userId, objectiveType, specificsCanonical) {
  // Find the current week index — first week with any pending/in_progress task
  let currentIdx = 0;
  for (let i = 0; i < plan.weeklySchedule.length; i++) {
    const hasOpen = (plan.weeklySchedule[i].tasks || []).some(t =>
      t.progress?.status === 'pending' || t.progress?.status === 'in_progress'
    );
    if (hasOpen) { currentIdx = i; break; }
  }

  // Re-emit tasks for currentIdx onwards. Preserve weekly goal + allocations.
  for (let i = currentIdx; i < plan.weeklySchedule.length; i++) {
    const week = plan.weeklySchedule[i];
    const refreshedTasks = [];
    for (const alloc of (week.allocations || [])) {
      const resolved = await taskCatalogService.resolveTopic({
        topicCanonicalName: alloc.topicCanonicalName,
        objectiveType,
        objectiveId: plan.objectiveId,
        userId: String(userId),
      });
      const displayName = alloc.topicCanonicalName.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
      const topicShape = { canonicalName: alloc.topicCanonicalName, displayName };

      if (resolved.quizId) {
        refreshedTasks.push({
          type: 'quiz', topic: topicShape,
          payload: { quizId: resolved.quizId, estimatedMinutes: resolved.quizMinutes },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending' },
        });
      }
      if (resolved.contentId) {
        refreshedTasks.push({
          type: 'in_app_content', topic: topicShape,
          payload: { contentId: resolved.contentId, contentType: resolved.contentType, estimatedMinutes: resolved.contentMinutes },
          completion: { mode: 'auto', requiresSelfRating: false },
          progress: { status: 'pending' },
        });
      }
      // Skip interview/competition/manual/external_link emission in soft realignment —
      // those are objective-level (interview) or already-stable.
    }
    // Preserve completed tasks; replace pending/in_progress ones.
    const completed = (week.tasks || []).filter(t => t.progress?.status === 'complete');
    week.tasks = [...completed, ...refreshedTasks];
  }
  await plan.save();
}

async function runWeeklyAutoCalibration() {
  console.log('[weeklyAutoCalibration] starting');
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const cursor = Plan.find({ isActive: true }).cursor();

  let touched = 0, skipped = 0;
  for await (const plan of cursor) {
    const lastAttempt = await DiagnosticAttempt.findOne({ userId: plan.userId, status: 'completed' })
      .sort({ completedAt: -1 }).select('completedAt').lean();
    if (!lastAttempt) { skipped++; continue; }
    const daysSince = (Date.now() - new Date(lastAttempt.completedAt).getTime()) / 86400000;
    if (daysSince < MIN_DAYS_SINCE_LAST_ATTEMPT) { skipped++; continue; }

    const signal = await computeSignal(plan.userId, sevenDaysAgo);
    if (signal < SIGNAL_THRESHOLD) { skipped++; continue; }

    try {
      const UserObjective = require('../models/UserObjective');
      const obj = await UserObjective.findById(plan.objectiveId).lean();
      if (!obj) { skipped++; continue; }
      await softRealignPlan(plan, plan.userId, obj.objectiveType, obj.specificsCanonical || obj.specifics || {});
      touched++;
      try {
        await notificationQueue.add('send', {
          userId: String(plan.userId),
          title: 'Your plan adapted to this week 🎯',
          body: 'Tasks refreshed based on your recent progress. Open Plan to see what\'s new.',
          data: { type: 'plan_auto_realigned', planId: String(plan._id) },
        });
      } catch (_) { /* best-effort notification */ }
    } catch (err) {
      console.warn(`[weeklyAutoCalibration] failed for plan ${plan._id}:`, err.message);
    }
  }
  console.log(`[weeklyAutoCalibration] done. touched=${touched} skipped=${skipped}`);
}

module.exports = { runWeeklyAutoCalibration, _internal: { computeSignal, softRealignPlan, SIGNAL_THRESHOLD } };
```

- [ ] **Step 2: Test the worker**

Stub `Plan.find().cursor()`, `DiagnosticAttempt.findOne`, the count queries. Assert touched/skipped counts based on signal.

- [ ] **Step 3: Wire into cronJobs**

In `src/workers/cronJobs.js`, register the worker on a schedule. Inspect existing cron registrations — add a daily 03:00 IST cron that calls `runWeeklyAutoCalibration`.

- [ ] **Step 4: Commit**

---

## Task 5 — External content fetcher + judge integration

### Part A — Fetcher service

- [ ] **Step 1: Add deps**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
npm install --save axios node-html-parser youtube-transcript
# Mozilla Readability is a separate package: @mozilla/readability + jsdom
npm install --save @mozilla/readability jsdom
```

(If any package install fails — note version conflicts and fall back to `node-html-parser` only.)

- [ ] **Step 2: Create `ExternalContentSnapshot` model**

`src/models/ExternalContentSnapshot.js`:

```javascript
const mongoose = require('mongoose');

const externalContentSnapshotSchema = new mongoose.Schema({
  url: { type: String, required: true, unique: true, index: true },
  title: { type: String, default: '' },
  excerpt: { type: String, default: '' },          // capped at 8000 chars
  contentType: { type: String, default: 'unknown' }, // article|youtube|pdf|other
  wordCount: { type: Number, default: 0 },
  fetchedAt: { type: Date, default: Date.now },
  fetchError: { type: String, default: null },
}, { timestamps: true });

// TTL: re-fetch after 30 days
externalContentSnapshotSchema.index({ fetchedAt: 1 }, { expireAfterSeconds: 30 * 24 * 60 * 60 });

module.exports = mongoose.model('ExternalContentSnapshot', externalContentSnapshotSchema);
```

- [ ] **Step 3: Create `externalContentFetcherService.js`**

```javascript
const axios = require('axios');
const { parse } = require('node-html-parser');
const { Readability } = require('@mozilla/readability');
const { JSDOM } = require('jsdom');
const { YoutubeTranscript } = require('youtube-transcript');
const ExternalContentSnapshot = require('../../models/ExternalContentSnapshot');

const FETCH_TIMEOUT_MS = 8000;
const MAX_EXCERPT = 8000;
const USER_AGENT = 'Mozilla/5.0 (compatible; ScaleUpBot/1.0; +https://scaleupapp.club)';

async function fetchSnapshot(url) {
  // Cache check
  const cached = await ExternalContentSnapshot.findOne({ url }).lean();
  if (cached && !cached.fetchError) return cached;

  let snapshot = { url, title: '', excerpt: '', contentType: 'unknown', wordCount: 0, fetchedAt: new Date() };

  try {
    if (/youtube\.com|youtu\.be/.test(url)) {
      snapshot = await fetchYouTube(url);
    } else if (/\.pdf$/i.test(url)) {
      snapshot.contentType = 'pdf';
      snapshot.fetchError = 'pdf_unsupported';
    } else {
      snapshot = await fetchHtml(url);
    }
  } catch (err) {
    snapshot.fetchError = err.message;
  }

  // Upsert
  await ExternalContentSnapshot.findOneAndUpdate({ url }, snapshot, { upsert: true, new: true });
  return snapshot;
}

async function fetchHtml(url) {
  const res = await axios.get(url, {
    timeout: FETCH_TIMEOUT_MS,
    headers: { 'User-Agent': USER_AGENT },
    maxContentLength: 5 * 1024 * 1024,
  });
  const dom = new JSDOM(res.data, { url });
  const reader = new Readability(dom.window.document);
  const parsed = reader.parse();
  if (!parsed) {
    // Fallback: extract first 5 paragraphs via node-html-parser
    const root = parse(res.data);
    const paragraphs = root.querySelectorAll('p').slice(0, 5).map(p => p.text).join('\n\n');
    return {
      url,
      title: root.querySelector('title')?.text?.trim() || '',
      excerpt: paragraphs.slice(0, MAX_EXCERPT),
      contentType: 'article',
      wordCount: paragraphs.split(/\s+/).length,
      fetchedAt: new Date(),
    };
  }
  return {
    url,
    title: parsed.title || '',
    excerpt: (parsed.textContent || '').slice(0, MAX_EXCERPT).trim(),
    contentType: 'article',
    wordCount: parsed.length || 0,
    fetchedAt: new Date(),
  };
}

async function fetchYouTube(url) {
  const transcript = await YoutubeTranscript.fetchTranscript(url);
  const text = transcript.map(t => t.text).join(' ');
  return {
    url,
    title: '', // youtube-transcript doesn't give title; could enrich via oembed but skip for v1
    excerpt: text.slice(0, MAX_EXCERPT),
    contentType: 'youtube',
    wordCount: text.split(/\s+/).length,
    fetchedAt: new Date(),
  };
}

module.exports = { fetchSnapshot, _internal: { MAX_EXCERPT, FETCH_TIMEOUT_MS } };
```

- [ ] **Step 4: Test (mock axios + youtube-transcript)**

`externalContentFetcherService.test.js` — stub `axios.get` with a fake HTML response, assert excerpt extraction. Stub `ExternalContentSnapshot.findOne/findOneAndUpdate`.

- [ ] **Step 5: Update `externalContentJudgeService.js` to use snapshots**

In the existing judge service, BEFORE calling the LLM, fetch snapshots for any URL the judge would consider. Then pass excerpts to the LLM prompt.

Wait — the judge generates URL recommendations. It doesn't START with URLs. The flow is:
1. LLM proposes URLs from its training-data knowledge of the whitelist
2. We filter by whitelist
3. **NEW Phase 7**: For each URL that passes the filter, fetch the snapshot
4. Re-prompt the LLM (or score locally): "here's what's actually at this URL — does it match the user's band and fill the gap?"
5. Drop URLs where the snapshot doesn't match

This adds a SECOND LLM call per accepted URL → more cost. Alternative: have the LLM emit URLs as before, and on capture-on-completion side, store the snapshot in `ExternalContentTouch` so future recalibrations have grounding. Simpler.

**Phase 7 scope decision:** ship the fetcher + snapshot model, but call the fetcher **only on completion** (when user marks an `external_link` task complete via `markManualComplete`). Future Phase 8 can use the snapshot to regrind the judge.

So: in `planProgressService.markManualComplete`, when type is `external_link`, ALSO `fetchSnapshot(payload.url)` + store the snapshot ref on the `ExternalContentTouch` row.

- [ ] **Step 6: Update `markManualComplete`**

After the existing `ExternalContentTouch.create({...})` call, fire a best-effort fetch:

```javascript
        if (foundTask.type === 'external_link') {
          try {
            const externalContentFetcherService = require('./externalContentFetcherService');
            const snap = await externalContentFetcherService.fetchSnapshot(foundTask.payload?.url || '');
            // Optionally enrich the touch with snapshot fields. Keep schema flexible.
          } catch (err) {
            console.warn('[planProgressService] external content fetch failed:', err.message);
          }
        }
```

- [ ] **Step 7: Commit**

---

## Task 6 — Turn on `FEATURE_EXTERNAL_CONTENT_JUDGE`

**Operator step.** No code change. After Tasks 1-5 ship to staging:

```
ssh -i ~/.ssh/scaleup-backend-key.pem ubuntu@15.207.72.150
# Edit env:
sudo nano /etc/scaleup-backend.env  # or wherever env vars live for pm2
# Add: FEATURE_EXTERNAL_CONTENT_JUDGE=true
pm2 restart scaleup-backend
```

Trigger one plan generation (e.g., a new test user diagnostic) and observe pm2 logs for judge calls + latency.

---

## Task 7 — Phase 7 acceptance sweep

- [ ] Backend tests across all touched services
- [ ] OpenAPI lint
- [ ] iOS parse for Plan + Components
- [ ] Android tsc for plan/services

---

## What Phase 7 ships

- Plans no longer have manual-fallback tasks for topics with no quiz — quizzes generate on demand
- iOS+Android Plan→play in 1 tap (skip Detail intermediate)
- Topic Mastery section gives users per-topic visibility (band, score history, content/quiz/external counts) + objective-level interview rollup
- Auto-calibration runs nightly: active users get refreshed task lists each week without needing to manually recalibrate
- External content the LLM-judge recommends gets its actual content captured server-side at completion time → grounds future recalibrations
- The LLM-judge is live in production
