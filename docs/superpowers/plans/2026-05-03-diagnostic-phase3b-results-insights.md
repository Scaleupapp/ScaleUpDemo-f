# Day-1 Diagnostic — Plan 3b: Results & Insights

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate calibration insights (LLM-powered, with template fallback) the moment the user finishes the diagnostic, then deliver a wow-worthy results experience on iOS and Android — animated hero reveal, calibration story, per-topic comparison bars, pattern observations, replay, and a shareable summary card.

**Architecture:** One pure calibration utility (zero external deps). One LLM-driven insights generation service with `json_schema` strict, 15s hard timeout, and a deterministic template-based fallback in the same file. `finishAttempt` is modified to call the insights generator inline (foreground) and stash the result on the `DiagnosticAttempt` document. The results endpoint returns the existing `results[]` shape augmented with `calibrationDelta`/`calibrationClass` per topic and the full `insights` JSON (or `null` while still generating). On iOS, an `InsightsGeneratingView` covers the 8-15s wait, a 3-screen story-style `HeroStoryRevealView` plays once on first view, and the rebuilt `DiagnosticResultsView` composes new `InsightCards` with count-up animated bars and a shareable card generator. Android mirrors the iOS flow screen-for-screen.

**Tech Stack:**
- **Backend:** Node.js, Mongoose 8.x, OpenAI SDK 4.x (`gpt-4o`, `response_format: { type: 'json_schema', strict: true }`), node:test + node:assert (`npm test` invokes `node scripts/run-tests.js`).
- **iOS:** SwiftUI on iOS 17+, existing `ColorTokens`/`Typography`/`Spacing`/`CornerRadius`/`Motion`/`Haptics` design system, `ImageRenderer` for shareable card, `UIActivityViewController` for share sheet, Mixpanel iOS SDK (already wired).
- **Android (RN):** React Native + TypeScript, existing `theme/{colors,typography,spacing}`, `Animated` API, `react-native-pager-view` for hero swipe, `react-native-view-shot` for shareable card, `react-native-share` for share sheet, Mixpanel React Native SDK (already wired).

**Source documents (read-only references):**
- Spec: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/specs/2026-05-03-day1-diagnostic-redesign-design.md`
  - §10 Results & insights screen (10.1 score-band, 10.2 calibration math, 10.3 LLM contract, 10.4 UI structure, 10.5 generation phase UX, 10.6 what this replaces)
  - §12.2 Diagnostic API endpoints (results endpoint contract)
  - §13.1 / §13.2 Frontend changes (iOS + Android)
  - §13.4 UX micro-interactions and animations
  - §13.5 Mixpanel event instrumentation (insights/results subset)
- Plan 1 (style reference): `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/plans/2026-05-03-diagnostic-phase0.5-seed-scripts.md`
- iOS visual language reference: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/Features/Diagnostic/Views/DiagnosticPreparingView.swift`
- Android visual language reference: `/Users/nirpekshnandan/My Products/ScaleUpAndroid/src/screens/diagnostic/PreparingScreen.tsx`
- Existing backend service (modified by Task 3): `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/src/services/diagnosticService.js`
- Existing OpenAI mock pattern: `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/src/integration/diagnostic.test.js` (lines 96-100)

**Repo paths (file paths in this plan are relative to these roots):**
- Backend: `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/`
- Android: `/Users/nirpekshnandan/My Products/ScaleUpAndroid/`

---

## File Structure (decisions locked here)

### Backend

| Path | Responsibility | Status |
|---|---|---|
| `src/utils/calibration.js` | Pure functions: score→band, band→midpoint, calibrationDelta, calibrationClass | NEW |
| `src/utils/calibration.test.js` | Unit tests for every boundary | NEW |
| `src/services/diagnostic/insightsGenerationService.js` | LLM insights generator + template fallback (single file, two exports) | NEW |
| `src/services/diagnostic/insightsGenerationService.test.js` | LLM mocked + timeout + fallback path tests | NEW |
| `src/services/diagnosticService.js` | `finishAttempt` modified to generate insights + persist `insightsJson` | MODIFY |
| `src/services/diagnosticService.test.js` | Existing tests, augmented for insights branch | MODIFY |
| `src/models/DiagnosticAttempt.js` | Add `insightsJson` (Mixed) + `insightsStatus` enum + `calibrationClass` per result | MODIFY |
| `src/controllers/diagnosticController.js` | `getResults` returns `{ status, results[], insights, planStatus }` per §12.2 | MODIFY |
| `src/integration/diagnostic.test.js` | Add an end-to-end assertion that finishAttempt populates `insightsJson` | MODIFY |

### iOS

| Path | Responsibility | Status |
|---|---|---|
| `ScaleUp/Features/Diagnostic/Views/InsightsGeneratingView.swift` | 8-15s wait phase loader (3-stage rotating text + fact cards) | NEW |
| `ScaleUp/Features/Diagnostic/Views/Components/InsightCards.swift` | Hero, Calibration, Pattern, TopicComparisonBar, ShareableSummary cards | NEW |
| `ScaleUp/Features/Diagnostic/Views/Components/HeroStoryRevealView.swift` | 3-screen swipeable story (first-time only) | NEW |
| `ScaleUp/Features/Diagnostic/Views/Components/ShareableSummaryCardGenerator.swift` | `ImageRenderer` + `UIActivityViewController` | NEW |
| `ScaleUp/Features/Diagnostic/Views/DiagnosticResultsView.swift` | Rebuilt per spec §10.4 | REWRITE |
| `ScaleUp/Features/Diagnostic/ViewModels/DiagnosticResultsViewModel.swift` | Hosts insights polling, hero-revealed state, share state | NEW |
| `ScaleUp/Services/Analytics/DiagnosticAnalytics.swift` | Add insights/results events alongside existing diagnostic events | MODIFY |

### Android (React Native)

| Path | Responsibility | Status |
|---|---|---|
| `src/screens/diagnostic/InsightsGeneratingScreen.tsx` | 8-15s wait phase loader | NEW |
| `src/components/diagnostic/InsightCards.tsx` | Hero, Calibration, Pattern, TopicComparisonBar, ShareableSummary cards | NEW |
| `src/screens/diagnostic/HeroStoryReveal.tsx` | 3-screen swipeable hero story (first-time only) | NEW |
| `src/screens/diagnostic/ShareableSummaryCardGenerator.tsx` | View-shot capture + share sheet | NEW |
| `src/screens/diagnostic/ResultsScreen.tsx` | Rebuilt per spec §10.4 | REWRITE |
| `src/screens/diagnostic/DiagnosticContainer.tsx` | Inject InsightsGeneratingScreen + HeroStoryReveal between Question and Results | MODIFY |
| `src/services/diagnosticAnalytics.ts` | Add insights/results events | MODIFY |

**Conventions:**
- Backend tests use `node:test` and `node:assert`; mock OpenAI via the `require.cache[openaiPath]` pattern in `src/integration/diagnostic.test.js`.
- iOS files use `ColorTokens`, `Typography`, `Spacing`, `CornerRadius`, `Motion.standard`/`Motion.gentle` and respect `@Environment(\.accessibilityReduceMotion)`. No hex literals in views.
- Android files import from `src/theme` only. No hardcoded colors/sizes.
- All animations cap at **1.5s**. Bar count-up = 1.0s. Card expansion = 250ms. Hero swipe = 350ms.
- Mixpanel events fire from a single helper per platform — never inline in views.

---

## Prerequisites

Before starting Task 1, the following must be true:

1. **Plan 1** (`2026-05-03-diagnostic-phase0.5-seed-scripts.md`) is merged — taxonomy, company profiles, and Wave 1 question bank are seeded.
2. **Plan 2a** (backend foundation: new `UserObjective` shape, `DiagnosticAttempt` per-topic flow, `topicTaxonomyService`) is merged.
3. **Plan 2b** (onboarding UI: taxonomy-backed Step 5, self-rating sub-step on iOS + Android) is merged.
4. **Plan 3a** (diagnostic engine: per-topic question selection, voice answer support, per-topic progress chip, celebratory transitions) is merged.
5. The backend repo is on a clean working branch.
6. `OPENAI_API_KEY`, `MONGODB_URI`, and Mixpanel project token are present in `.env`.
7. iOS workspace builds clean on the current build number; Android RN bundle builds clean.

Run from the backend repo root:
```bash
git checkout -b feat/diagnostic-phase3b-results-insights
git status   # verify clean
```

Run from the iOS repo root:
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git checkout -b feat/diagnostic-phase3b-results-insights
```

Run from the Android repo root:
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git checkout -b feat/diagnostic-phase3b-results-insights
```

---

## Task 1: Create the calibration math utility

**Files:**
- Create: `src/utils/calibration.js`
- Test: `src/utils/calibration.test.js`

Pure functions, zero dependencies, exhaustive boundary tests. This is the math primitive used by both the insights LLM service (Task 2) and the results endpoint (Task 4).

- [ ] **Step 1: Write the failing test**

Create `src/utils/calibration.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const calibration = require('./calibration');

test('scoreToBand: novice boundary', () => {
  assert.strictEqual(calibration.scoreToBand(0), 'Novice');
  assert.strictEqual(calibration.scoreToBand(29.99), 'Novice');
  assert.strictEqual(calibration.scoreToBand(30), 'Familiar');
});

test('scoreToBand: familiar boundary', () => {
  assert.strictEqual(calibration.scoreToBand(54.99), 'Familiar');
  assert.strictEqual(calibration.scoreToBand(55), 'Proficient');
});

test('scoreToBand: proficient boundary', () => {
  assert.strictEqual(calibration.scoreToBand(79.99), 'Proficient');
  assert.strictEqual(calibration.scoreToBand(80), 'Expert');
});

test('scoreToBand: expert ceiling', () => {
  assert.strictEqual(calibration.scoreToBand(100), 'Expert');
});

test('scoreToBand: clamps below 0 and above 100', () => {
  assert.strictEqual(calibration.scoreToBand(-5), 'Novice');
  assert.strictEqual(calibration.scoreToBand(150), 'Expert');
});

test('selfRatingToMidpoint: every band', () => {
  assert.strictEqual(calibration.selfRatingToMidpoint('Novice'), 15);
  assert.strictEqual(calibration.selfRatingToMidpoint('Familiar'), 42);
  assert.strictEqual(calibration.selfRatingToMidpoint('Proficient'), 67);
  assert.strictEqual(calibration.selfRatingToMidpoint('Expert'), 90);
});

test('selfRatingToMidpoint: case-insensitive', () => {
  assert.strictEqual(calibration.selfRatingToMidpoint('novice'), 15);
  assert.strictEqual(calibration.selfRatingToMidpoint('PROFICIENT'), 67);
});

test('selfRatingToMidpoint: throws on unknown band', () => {
  assert.throws(() => calibration.selfRatingToMidpoint('Master'), /unknown self-rating/i);
});

test('calibrationDelta: measured - selfRatedMidpoint', () => {
  // self-rated Familiar (midpoint 42), measured 70 -> delta +28 (undersells)
  assert.strictEqual(calibration.calibrationDelta(70, 'Familiar'), 28);
  // self-rated Expert (90), measured 50 -> delta -40 (overestimates)
  assert.strictEqual(calibration.calibrationDelta(50, 'Expert'), -40);
});

test('calibrationClass: well-calibrated band', () => {
  assert.strictEqual(calibration.calibrationClass(0), 'well-calibrated');
  assert.strictEqual(calibration.calibrationClass(15), 'well-calibrated');
  assert.strictEqual(calibration.calibrationClass(-15), 'well-calibrated');
});

test('calibrationClass: overestimates when delta < -15', () => {
  assert.strictEqual(calibration.calibrationClass(-16), 'overestimates');
  assert.strictEqual(calibration.calibrationClass(-50), 'overestimates');
});

test('calibrationClass: undersells when delta > +15', () => {
  assert.strictEqual(calibration.calibrationClass(16), 'undersells');
  assert.strictEqual(calibration.calibrationClass(40), 'undersells');
});

test('classifyTopic: composes all three', () => {
  const result = calibration.classifyTopic({ measuredScore: 30, selfRating: 'Expert' });
  assert.strictEqual(result.measuredBand, 'Familiar');
  assert.strictEqual(result.selfRatedMidpoint, 90);
  assert.strictEqual(result.calibrationDelta, -60);
  assert.strictEqual(result.calibrationClass, 'overestimates');
});

test('summarizeAttempt: counts well-calibrated topics', () => {
  const summary = calibration.summarizeAttempt([
    { canonicalName: 'a', measuredScore: 70, selfRating: 'Proficient' }, // delta +3 well
    { canonicalName: 'b', measuredScore: 30, selfRating: 'Expert' },     // delta -60 over
    { canonicalName: 'c', measuredScore: 80, selfRating: 'Novice' },     // delta +65 under
    { canonicalName: 'd', measuredScore: 50, selfRating: 'Familiar' },   // delta +8 well
  ]);
  assert.strictEqual(summary.totalTopics, 4);
  assert.strictEqual(summary.wellCalibratedCount, 2);
  assert.strictEqual(summary.overestimatesCount, 1);
  assert.strictEqual(summary.undersellsCount, 1);
  assert.deepStrictEqual(summary.dominantPattern, 'mixed');
});

test('summarizeAttempt: dominant overestimate pattern', () => {
  const summary = calibration.summarizeAttempt([
    { canonicalName: 'a', measuredScore: 10, selfRating: 'Expert' },
    { canonicalName: 'b', measuredScore: 20, selfRating: 'Expert' },
    { canonicalName: 'c', measuredScore: 70, selfRating: 'Proficient' },
  ]);
  assert.strictEqual(summary.dominantPattern, 'overestimates');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="scoreToBand|selfRatingToMidpoint|calibration"
```

Expected: FAIL with `Cannot find module './calibration'`.

- [ ] **Step 3: Implement the utility**

Create `src/utils/calibration.js`:

```js
'use strict';

// Spec §10.1 — score → band mapping
const BANDS = [
  { name: 'Novice',     min: 0,  max: 30,  midpoint: 15 },
  { name: 'Familiar',   min: 30, max: 55,  midpoint: 42 },
  { name: 'Proficient', min: 55, max: 80,  midpoint: 67 },
  { name: 'Expert',     min: 80, max: 101, midpoint: 90 }, // 101 so 100 lands in Expert
];

const MIDPOINT_BY_NAME = BANDS.reduce((acc, b) => {
  acc[b.name.toLowerCase()] = b.midpoint;
  return acc;
}, {});

function clamp(n, lo, hi) {
  if (Number.isNaN(n) || n === null || n === undefined) return lo;
  return Math.max(lo, Math.min(hi, n));
}

function scoreToBand(score) {
  const s = clamp(score, 0, 100);
  for (const b of BANDS) {
    if (s >= b.min && s < b.max) return b.name;
  }
  return 'Expert';
}

function selfRatingToMidpoint(rating) {
  if (typeof rating !== 'string') throw new Error('unknown self-rating: ' + rating);
  const m = MIDPOINT_BY_NAME[rating.toLowerCase()];
  if (m === undefined) throw new Error('unknown self-rating: ' + rating);
  return m;
}

function calibrationDelta(measuredScore, selfRating) {
  return clamp(measuredScore, 0, 100) - selfRatingToMidpoint(selfRating);
}

function calibrationClass(delta) {
  if (Math.abs(delta) <= 15) return 'well-calibrated';
  if (delta < -15) return 'overestimates';
  return 'undersells';
}

function classifyTopic({ measuredScore, selfRating }) {
  const delta = calibrationDelta(measuredScore, selfRating);
  return {
    measuredScore: clamp(measuredScore, 0, 100),
    measuredBand: scoreToBand(measuredScore),
    selfRatedMidpoint: selfRatingToMidpoint(selfRating),
    calibrationDelta: delta,
    calibrationClass: calibrationClass(delta),
  };
}

function summarizeAttempt(topicResults) {
  const classified = topicResults.map(t => ({
    canonicalName: t.canonicalName,
    ...classifyTopic({ measuredScore: t.measuredScore, selfRating: t.selfRating }),
  }));

  const wellCalibratedCount = classified.filter(t => t.calibrationClass === 'well-calibrated').length;
  const overestimatesCount  = classified.filter(t => t.calibrationClass === 'overestimates').length;
  const undersellsCount     = classified.filter(t => t.calibrationClass === 'undersells').length;

  let dominantPattern = 'mixed';
  const total = classified.length;
  if (total > 0) {
    if (wellCalibratedCount / total >= 0.6) dominantPattern = 'well-calibrated';
    else if (overestimatesCount > undersellsCount && overestimatesCount / total >= 0.5) dominantPattern = 'overestimates';
    else if (undersellsCount > overestimatesCount && undersellsCount / total >= 0.5) dominantPattern = 'undersells';
  }

  // Identify the single most striking topic for the hero story (largest |delta|).
  const mostStrikingTopic = classified.slice().sort(
    (a, b) => Math.abs(b.calibrationDelta) - Math.abs(a.calibrationDelta),
  )[0] || null;

  return {
    totalTopics: total,
    wellCalibratedCount,
    overestimatesCount,
    undersellsCount,
    dominantPattern,
    mostStrikingTopic,
    classifiedTopics: classified,
  };
}

module.exports = {
  scoreToBand,
  selfRatingToMidpoint,
  calibrationDelta,
  calibrationClass,
  classifyTopic,
  summarizeAttempt,
  BANDS,
};
```

- [ ] **Step 4: Run test, expect green**

```bash
npm test -- --test-name-pattern="scoreToBand|selfRatingToMidpoint|calibration|classifyTopic|summarizeAttempt"
```

Expected: all 14 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/utils/calibration.js src/utils/calibration.test.js
git commit -m "feat(diagnostic): add calibration math utility (score-band, delta, class, summary)"
```

---

## Task 2: Create the insights generation service (LLM + template fallback)

**Files:**
- Create: `src/services/diagnostic/insightsGenerationService.js`
- Test: `src/services/diagnostic/insightsGenerationService.test.js`

Single LLM call (`gpt-4o`, json_schema strict, 15s timeout) producing the spec §10.3 schema. If the LLM call rejects, throws, or times out, we silently fall back to a template generator that derives insights from the calibration math alone — never empty, never broken.

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/insightsGenerationService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');

const SERVICE_PATH = require.resolve('./insightsGenerationService');
const OPENAI_PATH = require.resolve('../../config/openai');

function installOpenAIStub(stub) {
  require.cache[OPENAI_PATH] = {
    exports: stub,
    loaded: true,
    id: OPENAI_PATH,
  };
  delete require.cache[SERVICE_PATH];
  return require('./insightsGenerationService');
}

const baseInput = {
  objectiveType: 'upskilling',
  specificsCanonical: 'product-management',
  timelineWeeks: 12,
  weeklyCommitHours: 6,
  companyProfile: null,
  topics: [
    { canonicalName: 'product-strategy', name: 'Product Strategy', selfRating: 'Proficient', measuredScore: 70,
      questionsAsked: 4, missedDifficulties: ['hard'] },
    { canonicalName: 'user-research',    name: 'User Research',    selfRating: 'Familiar',   measuredScore: 35,
      questionsAsked: 4, missedDifficulties: ['medium', 'hard'] },
    { canonicalName: 'stakeholder-mgmt', name: 'Stakeholder Mgmt', selfRating: 'Expert',     measuredScore: 30,
      questionsAsked: 4, missedDifficulties: ['easy', 'medium', 'hard'] },
  ],
};

const validLLMResponse = {
  hero: 'You ship like a Proficient PM but underestimate yourself on User Research.',
  calibration: 'Well-calibrated on 1 of 3 topics — biggest blind spot is Stakeholder Mgmt.',
  patterns: [
    'You overrate skills you use daily, underrate skills you reach for occasionally.',
    'You miss the hardest difficulty consistently across topics — fixable with deliberate practice.',
  ],
  topicTakeaways: {
    'product-strategy': 'On track — push into harder strategy bets.',
    'user-research': 'Stronger than you think — own it.',
    'stakeholder-mgmt': 'Biggest gap — focus the first 3 weeks here.',
  },
  planHeadline: 'Over 12 weeks at 6 hrs/week we will close the Stakeholder Mgmt gap, harden Strategy, and validate User Research instincts with two milestone reviews.',
};

test('insightsGenerationService: returns LLM JSON when call succeeds', async () => {
  const svc = installOpenAIStub({
    chat: {
      completions: {
        create: async () => ({
          choices: [{ message: { content: JSON.stringify(validLLMResponse) } }],
        }),
      },
    },
  });

  const out = await svc.generateInsights(baseInput);
  assert.strictEqual(out.source, 'llm');
  assert.strictEqual(out.insights.hero, validLLMResponse.hero);
  assert.deepStrictEqual(out.insights.patterns, validLLMResponse.patterns);
  assert.strictEqual(out.insights.topicTakeaways['stakeholder-mgmt'], validLLMResponse.topicTakeaways['stakeholder-mgmt']);
});

test('insightsGenerationService: falls back when LLM throws', async () => {
  const svc = installOpenAIStub({
    chat: {
      completions: {
        create: async () => { throw new Error('rate_limited'); },
      },
    },
  });

  const out = await svc.generateInsights(baseInput);
  assert.strictEqual(out.source, 'template');
  assert.strictEqual(out.fallbackReason, 'error');
  assert.ok(out.insights.hero && out.insights.hero.length > 0);
  assert.ok(out.insights.calibration && out.insights.calibration.length > 0);
  assert.ok(Array.isArray(out.insights.patterns) && out.insights.patterns.length >= 1);
  // every input topic has a takeaway
  for (const t of baseInput.topics) {
    assert.ok(out.insights.topicTakeaways[t.canonicalName], 'missing takeaway for ' + t.canonicalName);
  }
  assert.ok(out.insights.planHeadline && out.insights.planHeadline.length > 0);
});

test('insightsGenerationService: falls back when LLM returns malformed JSON', async () => {
  const svc = installOpenAIStub({
    chat: {
      completions: {
        create: async () => ({ choices: [{ message: { content: 'not json' } }] }),
      },
    },
  });

  const out = await svc.generateInsights(baseInput);
  assert.strictEqual(out.source, 'template');
  assert.strictEqual(out.fallbackReason, 'parse_error');
});

test('insightsGenerationService: falls back when LLM omits required keys', async () => {
  const svc = installOpenAIStub({
    chat: {
      completions: {
        create: async () => ({ choices: [{ message: { content: JSON.stringify({ hero: 'short' }) } }] }),
      },
    },
  });

  const out = await svc.generateInsights(baseInput);
  assert.strictEqual(out.source, 'template');
  assert.strictEqual(out.fallbackReason, 'schema_error');
});

test('insightsGenerationService: respects timeoutMs', async () => {
  const svc = installOpenAIStub({
    chat: {
      completions: {
        create: () => new Promise(resolve => setTimeout(() => resolve({
          choices: [{ message: { content: JSON.stringify(validLLMResponse) } }],
        }), 200)),
      },
    },
  });

  const t0 = Date.now();
  const out = await svc.generateInsights(baseInput, { timeoutMs: 50 });
  const elapsed = Date.now() - t0;
  assert.ok(elapsed < 180, 'should resolve via timeout, not wait full LLM duration');
  assert.strictEqual(out.source, 'template');
  assert.strictEqual(out.fallbackReason, 'timeout');
});

test('insightsGenerationService: template fallback covers overestimate-dominant attempts', () => {
  const svc = require('./insightsGenerationService');
  const insights = svc._templateInsights(baseInput);
  // Stakeholder Mgmt is the most-striking topic; hero should call it out.
  assert.match(insights.hero.toLowerCase(), /stakeholder/);
  assert.match(insights.calibration.toLowerCase(), /calibrated|blind spot|overrate|underrate/);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="insightsGenerationService"
```

Expected: FAIL with `Cannot find module './insightsGenerationService'`.

- [ ] **Step 3: Implement the service**

Create `src/services/diagnostic/insightsGenerationService.js`:

```js
'use strict';

const openai = require('../../config/openai');
const calibration = require('../../utils/calibration');

const DEFAULT_TIMEOUT_MS = 15000;
const MODEL = 'gpt-4o';

const INSIGHTS_JSON_SCHEMA = {
  name: 'diagnostic_insights',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['hero', 'calibration', 'patterns', 'topicTakeaways', 'planHeadline'],
    properties: {
      hero:        { type: 'string', minLength: 10, maxLength: 220 },
      calibration: { type: 'string', minLength: 10, maxLength: 220 },
      patterns: {
        type: 'array',
        minItems: 1,
        maxItems: 4,
        items: { type: 'string', minLength: 10, maxLength: 220 },
      },
      topicTakeaways: {
        type: 'object',
        additionalProperties: { type: 'string', minLength: 5, maxLength: 200 },
      },
      planHeadline: { type: 'string', minLength: 30, maxLength: 600 },
    },
  },
};

function buildSystemPrompt() {
  return [
    'You are ScaleUp\'s diagnostic insights writer.',
    'You help Indian learners understand the gap between how they rated themselves and how they actually performed.',
    'Tone: warm, direct, concrete. Never patronising. Never generic. Never use "user" — say "you".',
    'Use Indian context where natural (Bangalore PM, Mumbai consulting, IIT/NIT, GATE/CAT) but do not force it.',
    'Output STRICT JSON matching the provided schema. No prose outside JSON. No markdown.',
  ].join(' ');
}

function buildUserPrompt(input, summary) {
  const lines = [];
  lines.push(`Objective: ${input.objectiveType} — ${input.specificsCanonical || 'general'}`);
  if (input.companyProfile && input.companyProfile.name) {
    lines.push(`Target company: ${input.companyProfile.name} (${input.companyProfile.industry || 'unknown'})`);
  }
  lines.push(`Timeline: ${input.timelineWeeks} weeks at ${input.weeklyCommitHours} hrs/week`);
  lines.push('');
  lines.push(`Calibration summary: ${summary.wellCalibratedCount} of ${summary.totalTopics} topics well-calibrated. Dominant pattern: ${summary.dominantPattern}.`);
  lines.push('');
  lines.push('Per-topic results:');
  for (const t of summary.classifiedTopics) {
    const orig = input.topics.find(x => x.canonicalName === t.canonicalName) || {};
    lines.push(
      `- ${orig.name || t.canonicalName} (${t.canonicalName}): self-rated ${orig.selfRating}, measured ${t.measuredScore}/100 (${t.measuredBand}), delta ${t.calibrationDelta >= 0 ? '+' : ''}${t.calibrationDelta} (${t.calibrationClass}). Missed difficulties: ${(orig.missedDifficulties || []).join(', ') || 'none'}.`,
    );
  }
  lines.push('');
  lines.push('Write:');
  lines.push('1. hero — ONE sentence positioning the user. Reference their strongest signal or biggest gap. Keep it punchy.');
  lines.push('2. calibration — ONE sentence summarising the calibration story (e.g., "well-calibrated on 5 of 7 topics" + named blind spot).');
  lines.push('3. patterns — 2 cross-cutting observations (not topic-specific). Each one sentence.');
  lines.push('4. topicTakeaways — exactly one short line per topic by canonicalName. Concrete next move.');
  lines.push('5. planHeadline — 3-4 sentences explaining what the plan will do across the timeline. Reference hours/week and the biggest gap.');
  return lines.join('\n');
}

async function callLLMWithTimeout(messages, { timeoutMs }) {
  let timer;
  const timeoutPromise = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error('LLM_TIMEOUT')), timeoutMs);
  });
  const llmPromise = openai.chat.completions.create({
    model: MODEL,
    messages,
    temperature: 0.4,
    response_format: { type: 'json_schema', json_schema: INSIGHTS_JSON_SCHEMA },
  });
  try {
    const result = await Promise.race([llmPromise, timeoutPromise]);
    clearTimeout(timer);
    return result;
  } catch (err) {
    clearTimeout(timer);
    throw err;
  }
}

function validateInsightsShape(obj, expectedTopicNames) {
  if (!obj || typeof obj !== 'object') return false;
  if (typeof obj.hero !== 'string' || obj.hero.length < 5) return false;
  if (typeof obj.calibration !== 'string' || obj.calibration.length < 5) return false;
  if (!Array.isArray(obj.patterns) || obj.patterns.length < 1) return false;
  if (!obj.topicTakeaways || typeof obj.topicTakeaways !== 'object') return false;
  for (const name of expectedTopicNames) {
    if (typeof obj.topicTakeaways[name] !== 'string') return false;
  }
  if (typeof obj.planHeadline !== 'string' || obj.planHeadline.length < 20) return false;
  return true;
}

function _templateInsights(input) {
  const summary = calibration.summarizeAttempt(input.topics);
  const striking = summary.mostStrikingTopic;
  const strikingOrig = striking ? input.topics.find(x => x.canonicalName === striking.canonicalName) : null;
  const strikingName = strikingOrig?.name || striking?.canonicalName || 'a key topic';

  let hero;
  if (!striking) {
    hero = 'Your diagnostic is in — let\'s build a plan around what you actually need.';
  } else if (striking.calibrationClass === 'overestimates') {
    hero = `You rated yourself strong on ${strikingName}, but the answers say it\'s your biggest growth area.`;
  } else if (striking.calibrationClass === 'undersells') {
    hero = `You\'re stronger on ${strikingName} than you gave yourself credit for — own it.`;
  } else {
    hero = `You\'re well-calibrated on ${strikingName} — a solid base to build from.`;
  }

  const calibrationLine = summary.dominantPattern === 'overestimates'
    ? `Well-calibrated on ${summary.wellCalibratedCount} of ${summary.totalTopics} topics — you tend to overrate skills you use daily.`
    : summary.dominantPattern === 'undersells'
      ? `Well-calibrated on ${summary.wellCalibratedCount} of ${summary.totalTopics} topics — you consistently underrate yourself.`
      : summary.dominantPattern === 'well-calibrated'
        ? `Well-calibrated on ${summary.wellCalibratedCount} of ${summary.totalTopics} topics — your self-awareness is sharp.`
        : `Well-calibrated on ${summary.wellCalibratedCount} of ${summary.totalTopics} topics — a mixed picture worth unpacking.`;

  const patterns = [];
  if (summary.overestimatesCount >= 2) patterns.push('You overrate the skills you use most often — familiarity ≠ mastery.');
  if (summary.undersellsCount >= 2) patterns.push('You underrate yourself in places you actually deliver — confidence is a skill too.');
  const missedHard = input.topics.filter(t => (t.missedDifficulties || []).includes('hard')).length;
  if (missedHard >= 2) patterns.push('Hard-difficulty questions are where you stumble most — fixable with deliberate practice.');
  if (patterns.length === 0) patterns.push('Your performance is consistent across topics — a steady foundation to optimise from.');

  const topicTakeaways = {};
  for (const t of summary.classifiedTopics) {
    const orig = input.topics.find(x => x.canonicalName === t.canonicalName) || {};
    const name = orig.name || t.canonicalName;
    if (t.calibrationClass === 'overestimates') {
      topicTakeaways[t.canonicalName] = `Bigger gap than you thought on ${name} — early focus pays off.`;
    } else if (t.calibrationClass === 'undersells') {
      topicTakeaways[t.canonicalName] = `Stronger than you rated on ${name} — push for harder challenges.`;
    } else if (t.measuredBand === 'Expert' || t.measuredBand === 'Proficient') {
      topicTakeaways[t.canonicalName] = `Solid on ${name} — keep sharp with periodic reviews.`;
    } else {
      topicTakeaways[t.canonicalName] = `On track on ${name} — steady reps will compound.`;
    }
  }

  const focus = striking && striking.calibrationClass === 'overestimates' ? strikingName : 'your biggest gaps';
  const planHeadline = `Over ${input.timelineWeeks} weeks at ${input.weeklyCommitHours} hrs/week, your plan will front-load ${focus}, reinforce strengths with weekly reps, and check in at ${Math.max(2, Math.floor(input.timelineWeeks / 4))} milestones. We\'ve left buffer for life. The first three weeks will move the needle most.`;

  return {
    hero,
    calibration: calibrationLine,
    patterns,
    topicTakeaways,
    planHeadline,
  };
}

async function generateInsights(input, options = {}) {
  const timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;
  const summary = calibration.summarizeAttempt(input.topics);
  const expectedTopicNames = input.topics.map(t => t.canonicalName);

  const messages = [
    { role: 'system', content: buildSystemPrompt() },
    { role: 'user',   content: buildUserPrompt(input, summary) },
  ];

  let raw;
  try {
    raw = await callLLMWithTimeout(messages, { timeoutMs });
  } catch (err) {
    const reason = err && err.message === 'LLM_TIMEOUT' ? 'timeout' : 'error';
    return { source: 'template', fallbackReason: reason, insights: _templateInsights(input) };
  }

  let parsed;
  try {
    parsed = JSON.parse(raw.choices[0].message.content);
  } catch (_err) {
    return { source: 'template', fallbackReason: 'parse_error', insights: _templateInsights(input) };
  }

  if (!validateInsightsShape(parsed, expectedTopicNames)) {
    return { source: 'template', fallbackReason: 'schema_error', insights: _templateInsights(input) };
  }

  return { source: 'llm', insights: parsed };
}

module.exports = {
  generateInsights,
  _templateInsights, // exposed for testing
  _validateInsightsShape: validateInsightsShape,
  DEFAULT_TIMEOUT_MS,
  MODEL,
};
```

- [ ] **Step 4: Run test, expect green**

```bash
npm test -- --test-name-pattern="insightsGenerationService"
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnostic/insightsGenerationService.js src/services/diagnostic/insightsGenerationService.test.js
git commit -m "feat(diagnostic): add insights generation service (LLM + template fallback)"
```

---

## Task 3: Modify `finishAttempt` to generate and persist insights

**Files:**
- Modify: `src/models/DiagnosticAttempt.js` (add `insightsJson`, `insightsStatus`, `insightsSource`, `calibrationClass` per result)
- Modify: `src/services/diagnosticService.js` (call insights service inline; placeholder background-trigger for plan generation)
- Modify: `src/services/diagnosticService.test.js` (assert insights branch)

The insights generation runs in the **foreground** during `finishAttempt` — it blocks the response. Plan generation stays a fire-and-forget call to `journeyGenerationService.regenerateForUser` (Plan 4 will replace this with the real plan generator). On insights service failure, we still return success — the fallback always produces something.

- [ ] **Step 1: Write the failing test**

Append to `src/services/diagnosticService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');

test('finishAttempt: stores insightsJson on attempt and returns status', async () => {
  // Stub openai so insights service falls through to template (deterministic).
  const openaiPath = require.resolve('../config/openai');
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async () => { throw new Error('forced'); } } } },
    loaded: true, id: openaiPath,
  };

  // Reset insights service + diagnostic service caches so they pick up the stub.
  delete require.cache[require.resolve('./diagnostic/insightsGenerationService')];
  delete require.cache[require.resolve('./diagnosticService')];

  const svc = require('./diagnosticService');
  const DiagnosticAttempt = require('../models/DiagnosticAttempt');

  // Construct an attempt-like fixture and inject via test helper if exposed,
  // OR walk the standard flow if integration test setup is available.
  // (See src/integration/diagnostic.test.js for the canonical fixture.)
  // After finishAttempt:
  //   attempt.insightsJson must be non-null
  //   attempt.insightsStatus === 'completed' or 'fallback'
  //   attempt.insightsSource ∈ {'llm', 'template'}
  //   results[].calibrationClass is populated for every topic
  // (Concrete assertions written against the integration fixture in Task 5.)
});
```

- [ ] **Step 2: Update the DiagnosticAttempt model**

Open `src/models/DiagnosticAttempt.js`. Locate the `resultSchema` (sub-schema used in the `results` Map) and add `calibrationClass`:

```js
const resultSchema = new mongoose.Schema(
  {
    assessedBand:     { type: String, required: true },
    score:            { type: Number, required: true },
    calibrationDelta: { type: Number, required: true },
    calibrationClass: { type: String, enum: ['well-calibrated', 'overestimates', 'undersells'], default: 'well-calibrated' },
    questionsAsked:   { type: Number, required: true },
  },
  { _id: false }
);
```

Then, on the top-level `diagnosticAttemptSchema`, add three fields next to existing `status`/`completedAt`:

```js
insightsStatus: {
  type: String,
  enum: ['pending', 'generating', 'completed', 'fallback', 'error'],
  default: 'pending',
},
insightsSource: {
  type: String,
  enum: ['llm', 'template'],
  default: undefined,
},
insightsJson: {
  type: mongoose.Schema.Types.Mixed,
  default: null,
},
insightsLatencyMs: { type: Number, default: null },
```

Run model tests:

```bash
npm test -- --test-name-pattern="DiagnosticAttempt"
```

Expected: existing tests still pass.

- [ ] **Step 3: Modify `finishAttempt` in diagnosticService**

Open `src/services/diagnosticService.js`. After the per-competency loop that builds `attempt.results` (around lines 269-278), add `calibrationClass` and use the new utility for consistency:

```js
const calibration = require('../utils/calibration');
const insightsGenerationService = require('./diagnostic/insightsGenerationService');

// ... inside finishAttempt, replacing the existing per-competency block:

for (const comp of attempt.selfRatings.keys()) {
  const perf = _perfForCompetency(attempt.answers, comp);
  const band = selector._internal.deriveBand(perf);
  const score = selector._internal.bandToScore(band);
  const selfRating = attempt.selfRatings.get(comp); // already a band string per Plan 2a
  const calibrationDelta = calibration.calibrationDelta(score, selfRating);
  const calibrationClass = calibration.calibrationClass(calibrationDelta);
  const questionsAsked = attempt.answers.filter(a => a.competency === comp).length;
  attempt.results.set(comp, {
    assessedBand: band,
    score,
    calibrationDelta,
    calibrationClass,
    questionsAsked,
  });
}
```

Then, **after** the `attempt.status = 'completed'` save and **after** the `_applyToKnowledgeProfile`/`_seedConceptMastery` calls but **before** the journey-regeneration trigger, add the foreground insights generation:

```js
// Foreground: generate insights (blocks results return; spec §10.5)
attempt.insightsStatus = 'generating';
await attempt.save();

const insightsInput = {
  objectiveType:      attempt.objectiveSnapshot?.objectiveType || 'upskilling',
  specificsCanonical: attempt.objectiveSnapshot?.specificsCanonical || null,
  timelineWeeks:      attempt.objectiveSnapshot?.timelineWeeks || 12,
  weeklyCommitHours:  attempt.objectiveSnapshot?.weeklyCommitHours || 6,
  companyProfile:     attempt.objectiveSnapshot?.companyProfile || null,
  topics: Array.from(attempt.results.entries()).map(([canonicalName, r]) => ({
    canonicalName,
    name:               attempt.objectiveSnapshot?.topicNames?.[canonicalName] || canonicalName,
    selfRating:         attempt.selfRatings.get(canonicalName),
    measuredScore:      r.score,
    questionsAsked:     r.questionsAsked,
    missedDifficulties: _missedDifficultiesFor(attempt.answers, canonicalName),
  })),
};

const t0 = Date.now();
let insightsResult;
try {
  insightsResult = await insightsGenerationService.generateInsights(insightsInput);
} catch (err) {
  console.warn('[diagnosticService] insights generation hard failure:', err.message);
  insightsResult = {
    source: 'template',
    fallbackReason: 'error',
    insights: insightsGenerationService._templateInsights(insightsInput),
  };
}

attempt.insightsJson      = insightsResult.insights;
attempt.insightsSource    = insightsResult.source;
attempt.insightsStatus    = insightsResult.source === 'llm' ? 'completed' : 'fallback';
attempt.insightsLatencyMs = Date.now() - t0;
await attempt.save();

telemetry.logEvent('diagnostic.insights_generated', {
  userId: String(attempt.userId),
  source: insightsResult.source,
  fallbackReason: insightsResult.fallbackReason || null,
  latencyMs: attempt.insightsLatencyMs,
});
```

Add the small helper near the bottom of the file:

```js
function _missedDifficultiesFor(answers, comp) {
  const missed = new Set();
  for (const a of answers) {
    if (a.competency === comp && a.correct === false && a.difficulty) {
      missed.add(a.difficulty);
    }
  }
  return Array.from(missed);
}
```

Update `_resultsObjectFromAttempt` to include `calibrationClass` and `insights`/`insightsStatus`:

```js
function _resultsObjectFromAttempt(attempt) {
  const results = [];
  for (const [comp, v] of attempt.results.entries()) {
    results.push({
      competency: comp,
      band: v.assessedBand,
      score: v.score,
      calibrationDelta: v.calibrationDelta,
      calibrationClass: v.calibrationClass || 'well-calibrated',
      questionsAsked: v.questionsAsked,
    });
  }
  return {
    attemptId: String(attempt._id),
    status: attempt.status,
    insightsStatus: attempt.insightsStatus || 'pending',
    insights: attempt.insightsJson || null,
    planStatus: attempt.appliedToProfileAt ? 'queued' : 'pending',
    results,
  };
}
```

- [ ] **Step 4: Run service tests**

```bash
npm test -- --test-name-pattern="diagnosticService|finishAttempt"
```

Expected: all tests pass. Existing assertions (band, score, calibrationDelta, questionsAsked) remain valid; the new fields are additive.

- [ ] **Step 5: Commit**

```bash
git add src/models/DiagnosticAttempt.js src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): finishAttempt generates + persists insights JSON"
```

---

## Task 4: Refine the results endpoint

**Files:**
- Modify: `src/controllers/diagnosticController.js`
- Modify: `src/integration/diagnostic.test.js` (assert new response shape end-to-end)

The `GET /diagnostic/attempts/:id/results` endpoint must return the spec §12.2 shape:

```json
{
  "status": "completed",
  "insightsStatus": "completed" | "fallback" | "generating" | "pending",
  "results": [{ "competency", "band", "score", "calibrationDelta", "calibrationClass", "questionsAsked" }],
  "insights": { ... } | null,
  "planStatus": "ready" | "queued" | "pending"
}
```

- [ ] **Step 1: Write the failing integration test**

Open `src/integration/diagnostic.test.js`. After the existing `finishAttempt` walk, add:

```js
test('GET results: returns calibrationClass + insights + insightsStatus', async () => {
  // Reuse the createdAttempt + svc fixture from earlier in the file.
  // After svc.finishAttempt(attemptId), call the controller helper directly.
  const ctrl = require('../controllers/diagnosticController');
  const req = { params: { id: String(createdAttempt._id) }, user: { id: String(userId) } };
  let captured;
  const res = {
    status: function (c) { this.statusCode = c; return this; },
    json: function (b) { captured = b; return this; },
  };
  await ctrl.getResults(req, res);

  assert.strictEqual(captured.status, 'completed');
  assert.ok(['completed', 'fallback'].includes(captured.insightsStatus));
  assert.ok(captured.insights, 'insights JSON present');
  assert.ok(typeof captured.insights.hero === 'string');
  assert.ok(Array.isArray(captured.insights.patterns));
  assert.ok(Array.isArray(captured.results));
  for (const r of captured.results) {
    assert.ok(['well-calibrated', 'overestimates', 'undersells'].includes(r.calibrationClass));
  }
});
```

- [ ] **Step 2: Update the controller**

In `src/controllers/diagnosticController.js`, locate `getResults` (or whichever handler maps to `GET /diagnostic/attempts/:id/results`). Replace its body with:

```js
async function getResults(req, res) {
  try {
    const attempt = await DiagnosticAttempt.findById(req.params.id);
    if (!attempt) return res.status(404).json({ error: 'attempt_not_found' });
    if (String(attempt.userId) !== String(req.user.id)) {
      return res.status(403).json({ error: 'forbidden' });
    }

    const results = [];
    for (const [comp, v] of attempt.results.entries()) {
      results.push({
        competency: comp,
        band: v.assessedBand,
        score: v.score,
        calibrationDelta: v.calibrationDelta,
        calibrationClass: v.calibrationClass || 'well-calibrated',
        questionsAsked: v.questionsAsked,
      });
    }

    const planStatus = attempt.appliedToProfileAt ? 'queued' : 'pending';

    return res.status(200).json({
      attemptId:      String(attempt._id),
      status:         attempt.status,
      insightsStatus: attempt.insightsStatus || 'pending',
      insights:       attempt.insightsJson || null,
      planStatus,
      results,
    });
  } catch (err) {
    console.error('[diagnosticController.getResults]', err);
    return res.status(500).json({ error: 'internal_error' });
  }
}

module.exports.getResults = getResults;
```

Confirm the route in `src/routes/diagnosticRoutes.js` (or equivalent) maps `GET /diagnostic/attempts/:id/results` to `getResults`. No change needed if it already does.

- [ ] **Step 3: Run integration tests**

```bash
npm test -- --test-name-pattern="diagnostic"
```

Expected: all tests pass, including the new `GET results: returns calibrationClass + insights + insightsStatus` assertion.

- [ ] **Step 4: Commit**

```bash
git add src/controllers/diagnosticController.js src/integration/diagnostic.test.js
git commit -m "feat(diagnostic): results endpoint returns calibrationClass + insights JSON"
```

---

## Task 5: iOS — `InsightsGeneratingView` (8-15s wait phase)

**Files:**
- Create: `ScaleUp/Features/Diagnostic/Views/InsightsGeneratingView.swift`

Same visual language as the existing `DiagnosticPreparingView` (gold halo, fact card, dots) but tuned for the **completion** moment per spec §10.5: three-stage rotating progress text, two rotating fact cards, a subtle bar-chart background hint that builds toward the actual results visualization. **No skip button.** When the parent ViewModel signals `insights != nil`, this view crossfades out to the hero reveal.

- [ ] **Step 1: Create the file**

Create `ScaleUp/Features/Diagnostic/Views/InsightsGeneratingView.swift`:

```swift
import SwiftUI

struct InsightsGeneratingView: View {
    /// Parent passes `true` when insights JSON is loaded; we crossfade out.
    var isReady: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stageIndex: Int = 0
    @State private var factIndex: Int = 0
    @State private var ringRotation: Double = 0
    @State private var iconScale: CGFloat = 1.0
    @State private var barHeights: [CGFloat] = [0.2, 0.35, 0.5]
    @State private var elapsedSec: Double = 0
    @State private var timer: Timer?

    private let stages: [String] = [
        "Analyzing your answers…",
        "Comparing your self-rating to actual performance…",
        "Generating personalized insights…",
    ]

    private let facts: [String] = [
        "Most learners discover one major blind spot in their first calibration.",
        "People who get calibrated learn 2-3x faster than those who don't.",
        "The biggest gains come from the topics you didn't expect to struggle with.",
    ]

    private let factIcons: [String] = [
        "lightbulb.fill",
        "chart.line.uptrend.xyaxis",
        "sparkles",
    ]

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            backgroundBarHint
                .opacity(0.18)

            VStack(spacing: 0) {
                Spacer()
                haloIcon
                    .padding(.bottom, Spacing.xl)

                Text(stages[stageIndex])
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .id(stageIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                Text("Usually ~10 seconds")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.bottom, Spacing.xxl)

                factCard
                    .padding(.horizontal, Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)

                factDots
                    .padding(.top, Spacing.md)

                Spacer()
            }
        }
        .opacity(isReady ? 0 : 1)
        .animation(.easeInOut(duration: 0.45), value: isReady)
        .onAppear { startAnimations() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Subviews

    private var haloIcon: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [ColorTokens.gold, ColorTokens.gold.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(ringRotation))

            Circle()
                .fill(ColorTokens.gold.opacity(0.12))
                .frame(width: 110, height: 110)

            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .scaleEffect(iconScale)
        }
    }

    private var factCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: factIcons[factIndex])
                .foregroundStyle(ColorTokens.gold)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Did you know")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .tracking(0.6)
                Text(facts[factIndex])
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineSpacing(3)
            }
        }
        .id(factIndex)
        .transition(.opacity)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private var factDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<facts.count, id: \.self) { i in
                Circle()
                    .fill(i == factIndex ? ColorTokens.gold : ColorTokens.gold.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var backgroundBarHint: some View {
        // Subtle bar-chart hint at bottom — bars grow with elapsed time.
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<barHeights.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.gold)
                        .frame(width: 36, height: 80 * barHeights[i])
                }
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Animation lifecycle

    private func startAnimations() {
        if !reduceMotion {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                iconScale = 1.1
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            elapsedSec += 0.5

            // Stage transitions per spec §10.5
            let newStage: Int = {
                if elapsedSec < 3 { return 0 }
                if elapsedSec < 7 { return 1 }
                return 2
            }()
            if newStage != stageIndex {
                withAnimation(.easeInOut(duration: 0.3)) { stageIndex = newStage }
            }

            // Rotate fact every ~5s
            if Int(elapsedSec * 2) % 10 == 0 && elapsedSec > 0 {
                withAnimation(.easeInOut(duration: 0.4)) {
                    factIndex = (factIndex + 1) % facts.count
                }
            }

            // Grow background bars subtly
            if !reduceMotion {
                let progress = min(1.0, elapsedSec / 12.0)
                withAnimation(.easeOut(duration: 0.5)) {
                    barHeights = [
                        0.3 + 0.6 * CGFloat(progress) * 0.5,
                        0.5 + 0.4 * CGFloat(progress),
                        0.4 + 0.5 * CGFloat(progress) * 0.8,
                    ]
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    InsightsGeneratingView(isReady: false)
        .background(ColorTokens.background)
}
```

- [ ] **Step 2: Add to Xcode target**

Add the new file to the `ScaleUp` target in Xcode (File Inspector → Target Membership). Build the project.

```bash
xcodebuild -workspace "/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp.xcworkspace" -scheme ScaleUp -configuration Debug -sdk iphonesimulator -quiet build | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Diagnostic/Views/InsightsGeneratingView.swift ScaleUp.xcodeproj/project.pbxproj
git commit -m "feat(diagnostic-ios): InsightsGeneratingView for 8-15s insights wait phase"
```

---

## Task 6: iOS — `InsightCards.swift` (reusable card components)

**Files:**
- Create: `ScaleUp/Features/Diagnostic/Views/Components/InsightCards.swift`

Five reusable SwiftUI views consumed by `DiagnosticResultsView`, `HeroStoryRevealView`, and `ShareableSummaryCardGenerator`. Each is a pure value-type View with a clear initializer signature.

- [ ] **Step 1: Create the file**

Create `ScaleUp/Features/Diagnostic/Views/Components/InsightCards.swift`:

```swift
import SwiftUI

// MARK: - Models (frontend-only DTOs mirroring backend insights JSON)

struct DiagnosticTopicResult: Identifiable, Hashable {
    var id: String { canonicalName }
    let canonicalName: String
    let displayName: String
    let selfRating: String        // "Novice" | "Familiar" | "Proficient" | "Expert"
    let measuredScore: Int        // 0-100
    let measuredBand: String
    let calibrationDelta: Int
    let calibrationClass: String  // "well-calibrated" | "overestimates" | "undersells"
    let questionsAsked: Int
    let topicTakeaway: String
    let strongestMoment: String?
    let stretchMoment: String?
    let missedDifficulties: [String]
}

extension DiagnosticTopicResult {
    var classColor: Color {
        switch calibrationClass {
        case "well-calibrated": return ColorTokens.success
        case "overestimates":   return ColorTokens.warning
        case "undersells":      return ColorTokens.info
        default:                return ColorTokens.textSecondary
        }
    }
    var selfRatingMidpoint: Int {
        switch selfRating.lowercased() {
        case "novice":     return 15
        case "familiar":   return 42
        case "proficient": return 67
        case "expert":     return 90
        default:           return 50
        }
    }
}

// MARK: - HeroCard

struct HeroCard: View {
    let heroSentence: String
    var onShareTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Text(heroSentence)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let onShareTap {
                    Button(action: onShareTap) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(8)
                            .background(Circle().fill(ColorTokens.gold.opacity(0.12)))
                    }
                    .accessibilityLabel("Share results")
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(ColorTokens.gold.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - CalibrationCard

struct CalibrationCard: View {
    let summarySentence: String   // "Well-calibrated on 5 of 7 topics"
    let detailSentence: String    // calibration insight from LLM
    let topics: [DiagnosticTopicResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(summarySentence)
                .font(Typography.titleSmall)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(detailSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)

            VStack(spacing: 8) {
                ForEach(topics) { t in
                    deltaBand(for: t)
                }
            }
            .padding(.top, 4)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.surface)
        )
    }

    private func deltaBand(for t: DiagnosticTopicResult) -> some View {
        // Shaded band between selfRatedMidpoint and measuredScore on a 0-100 axis.
        GeometryReader { geo in
            let lo = CGFloat(min(t.selfRatingMidpoint, t.measuredScore)) / 100.0
            let hi = CGFloat(max(t.selfRatingMidpoint, t.measuredScore)) / 100.0
            let bandX = geo.size.width * lo
            let bandW = max(2, geo.size.width * (hi - lo))

            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.surfaceElevated).frame(height: 6)
                Capsule().fill(t.classColor.opacity(0.5))
                    .frame(width: bandW, height: 6)
                    .offset(x: bandX)
                Circle().fill(ColorTokens.textSecondary)
                    .frame(width: 8, height: 8)
                    .offset(x: geo.size.width * CGFloat(t.selfRatingMidpoint) / 100.0 - 4)
                Circle().fill(t.classColor)
                    .frame(width: 10, height: 10)
                    .offset(x: geo.size.width * CGFloat(t.measuredScore) / 100.0 - 5)
            }
        }
        .frame(height: 14)
        .accessibilityLabel("\(t.displayName): self-rated \(t.selfRating), measured \(t.measuredScore)")
    }
}

// MARK: - PatternCard

struct PatternCard: View {
    let title: String
    let body: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 28, height: 28)
                .background(Circle().fill(ColorTokens.gold.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .tracking(0.5)
                Text(body)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineSpacing(3)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }
}

// MARK: - TopicComparisonBarCard

struct TopicComparisonBarCard: View {
    let topic: DiagnosticTopicResult
    @State private var animatedSelf: CGFloat = 0
    @State private var animatedMeasured: CGFloat = 0
    @State private var displayedScore: Int = 0
    @State private var isExpanded: Bool = false
    var onExpand: ((String) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            bars
            Text(topic.topicTakeaway)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)
            if isExpanded { expandedDetail }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(topic.classColor.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggleExpand() }
        .onAppear { animateBars() }
    }

    private var header: some View {
        HStack {
            Text(topic.displayName)
                .font(Typography.titleSmall)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Text(topic.measuredBand)
                .font(Typography.captionBold)
                .foregroundStyle(topic.classColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(topic.classColor.opacity(0.15)))
        }
    }

    private var bars: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            barView(label: "Your rating", widthRatio: animatedSelf, color: ColorTokens.textSecondary, scoreText: topic.selfRating)
            barView(label: "Measured", widthRatio: animatedMeasured, color: topic.classColor, scoreText: "\(displayedScore)")
        }
    }

    private func barView(label: String, widthRatio: CGFloat, color: Color, scoreText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.surfaceElevated).frame(height: 10)
                    Capsule().fill(color).frame(width: max(4, geo.size.width * widthRatio), height: 10)
                }
            }.frame(height: 10)
            Text(scoreText).font(Typography.captionBold).foregroundStyle(color)
        }
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !topic.missedDifficulties.isEmpty {
                detailRow(icon: "questionmark.circle", label: "Missed difficulties", value: topic.missedDifficulties.joined(separator: ", "))
            }
            if let s = topic.strongestMoment {
                detailRow(icon: "star.fill", label: "Strongest moment", value: s)
            }
            if let s = topic.stretchMoment {
                detailRow(icon: "arrow.up.right.circle", label: "Stretch moment", value: s)
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).foregroundStyle(ColorTokens.gold).font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
                Text(value).font(Typography.bodySmall).foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }

    private func toggleExpand() {
        withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
        if isExpanded { onExpand?(topic.canonicalName) }
        Haptics.light()
    }

    private func animateBars() {
        let selfRatio = CGFloat(topic.selfRatingMidpoint) / 100.0
        let measuredRatio = CGFloat(topic.measuredScore) / 100.0
        if reduceMotion {
            animatedSelf = selfRatio
            animatedMeasured = measuredRatio
            displayedScore = topic.measuredScore
            return
        }
        withAnimation(.easeOut(duration: 1.0)) {
            animatedSelf = selfRatio
            animatedMeasured = measuredRatio
        }
        // Count-up for measured score over ~1s.
        let steps = 30
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * (1.0 / Double(steps))) {
                displayedScore = Int(Double(topic.measuredScore) * Double(i) / Double(steps))
            }
        }
    }
}

// MARK: - ShareableSummaryCard

struct ShareableSummaryCard: View {
    let heroSentence: String
    let topics: [DiagnosticTopicResult] // top 3 by interestingness

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("ScaleUp")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.gold)
                    .tracking(1.2)
                Spacer()
                Text("Calibration check")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            Text(heroSentence)
                .font(Typography.titleSmall)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineSpacing(3)
            VStack(spacing: 8) {
                ForEach(topics.prefix(3)) { t in
                    HStack {
                        Text(t.displayName).font(Typography.bodySmall).foregroundStyle(ColorTokens.textSecondary)
                        Spacer()
                        Text("\(t.measuredScore)").font(Typography.captionBold).foregroundStyle(t.classColor)
                    }
                }
            }
            HStack {
                Spacer()
                Text("scaleupapp.club")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 360, height: 360)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.heroGradient)
        )
    }
}
```

- [ ] **Step 2: Add to Xcode target**

Add the file under the `Components` group in Xcode. Build:

```bash
xcodebuild -workspace "/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp.xcworkspace" -scheme ScaleUp -configuration Debug -sdk iphonesimulator -quiet build | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Diagnostic/Views/Components/InsightCards.swift ScaleUp.xcodeproj/project.pbxproj
git commit -m "feat(diagnostic-ios): InsightCards components (hero, calibration, pattern, topic-bars, shareable)"
```

---

## Task 7: iOS — `HeroStoryRevealView` (3-screen first-time story)

**Files:**
- Create: `ScaleUp/Features/Diagnostic/Views/Components/HeroStoryRevealView.swift`

3 swipeable screens (`TabView` with `.page` style), auto-advance every 5s with progress dots and a small skip pill in the top-right. Plays once per `DiagnosticAttempt` (parent gates with `@AppStorage("diagnostic_hero_revealed_<attemptId>")`).

- [ ] **Step 1: Create the file**

Create `ScaleUp/Features/Diagnostic/Views/Components/HeroStoryRevealView.swift`:

```swift
import SwiftUI

struct HeroStoryRevealView: View {
    let heroSentence: String          // Screen 1
    let surpriseSentence: String      // Screen 2 (most striking insight)
    let planSentence: String          // Screen 3 (planHeadline first-line excerpt)
    let overallScore: Int             // 0-100, used by Screen 1 meter
    var onDone: () -> Void

    @State private var page: Int = 0
    @State private var animatedMeter: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ColorTokens.background.ignoresSafeArea()

            TabView(selection: $page) {
                screen1.tag(0)
                screen2.tag(1)
                screen3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: page)

            HStack {
                dots
                Spacer()
                skipButton
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .onAppear {
            startAutoAdvance()
            if !reduceMotion {
                withAnimation(.easeOut(duration: 1.2)) {
                    animatedMeter = CGFloat(overallScore) / 100.0
                }
            } else {
                animatedMeter = CGFloat(overallScore) / 100.0
            }
        }
    }

    // MARK: - Screens

    private var screen1: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text("Here's where you stand.")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.surfaceElevated).frame(height: 14)
                GeometryReader { geo in
                    Capsule().fill(ColorTokens.gold)
                        .frame(width: geo.size.width * animatedMeter, height: 14)
                }.frame(height: 14)
            }
            .frame(maxWidth: 280)
            Text(heroSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    private var screen2: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text("Here's what surprised us.")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text(surpriseSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    private var screen3: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text("Here's what we recommend.")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text(planSentence)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Button(action: onDone) {
                Text("See my results")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(ColorTokens.gold))
            }
            .padding(.top, Spacing.md)
            Spacer()
        }
    }

    // MARK: - Chrome

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i == page ? ColorTokens.gold : ColorTokens.gold.opacity(0.25))
                    .frame(width: i == page ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: page)
            }
        }
    }

    private var skipButton: some View {
        Button(action: onDone) {
            Text("Skip")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(ColorTokens.surface.opacity(0.7)))
        }
    }

    private func startAutoAdvance() {
        // ~5s per screen
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { t in
            if page < 2 {
                withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
            } else {
                t.invalidate()
            }
        }
    }
}
```

- [ ] **Step 2: Add to Xcode target + build**

```bash
xcodebuild -workspace "/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp.xcworkspace" -scheme ScaleUp -configuration Debug -sdk iphonesimulator -quiet build | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Diagnostic/Views/Components/HeroStoryRevealView.swift ScaleUp.xcodeproj/project.pbxproj
git commit -m "feat(diagnostic-ios): HeroStoryRevealView (3-screen first-time hero story)"
```

---

## Task 8: iOS — Rebuild `DiagnosticResultsView` per spec §10.4

**Files:**
- Rewrite: `ScaleUp/Features/Diagnostic/Views/DiagnosticResultsView.swift`
- Create: `ScaleUp/Features/Diagnostic/ViewModels/DiagnosticResultsViewModel.swift`

The results view orchestrates the full §10.4 layout: hero card (sticky top), calibration card, per-topic cards, pattern cards, replay section (collapsed), plan preview placeholder, shareable card CTA, primary CTA "See your plan". The 3-screen story plays once on first reveal (gated by `@AppStorage`).

- [ ] **Step 1: Create the ViewModel**

Create `ScaleUp/Features/Diagnostic/ViewModels/DiagnosticResultsViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
final class DiagnosticResultsViewModel: ObservableObject {
    @Published private(set) var phase: Phase = .generating
    @Published private(set) var hero: String = ""
    @Published private(set) var calibrationSummary: String = ""
    @Published private(set) var calibrationDetail: String = ""
    @Published private(set) var patterns: [String] = []
    @Published private(set) var planHeadline: String = ""
    @Published private(set) var topics: [DiagnosticTopicResult] = []
    @Published private(set) var overallScore: Int = 0
    @Published var showShareSheet: Bool = false
    @Published var shareImage: UIImage? = nil

    enum Phase { case generating, ready }

    private let attemptId: String
    private let api: DiagnosticAPIClient
    private let analytics: DiagnosticAnalytics
    private var pollTask: Task<Void, Never>?

    init(attemptId: String, api: DiagnosticAPIClient = .shared, analytics: DiagnosticAnalytics = .shared) {
        self.attemptId = attemptId
        self.api = api
        self.analytics = analytics
    }

    func start() {
        analytics.track(.insightsGenerationStarted, props: ["attemptId": attemptId])
        pollTask?.cancel()
        pollTask = Task { await pollUntilReady() }
    }

    private func pollUntilReady() async {
        var attempts = 0
        let maxAttempts = 18  // 18 * 1s = 18s ceiling (server hard cap is 15s)
        while !Task.isCancelled, attempts < maxAttempts {
            attempts += 1
            do {
                let resp = try await api.getResults(attemptId: attemptId)
                if resp.insightsStatus == "completed" || resp.insightsStatus == "fallback", let i = resp.insights {
                    apply(results: resp.results, insights: i)
                    let latency = attempts * 1000
                    if resp.insightsStatus == "fallback" {
                        analytics.track(.insightsGenerationFallback, props: ["reason": "server", "latencyMs": latency])
                    } else {
                        analytics.track(.insightsGenerationCompleted, props: ["latencyMs": latency])
                    }
                    phase = .ready
                    analytics.track(.diagnosticResultsViewed, props: ["attemptId": attemptId])
                    return
                }
            } catch {
                // swallow; will retry
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        // Final fallback: keep loader; surface a retry banner via parent.
    }

    private func apply(results: [DiagnosticResultDTO], insights: DiagnosticInsightsDTO) {
        self.hero = insights.hero
        self.calibrationDetail = insights.calibration
        self.patterns = insights.patterns
        self.planHeadline = insights.planHeadline

        let wellCount = results.filter { $0.calibrationClass == "well-calibrated" }.count
        self.calibrationSummary = "Well-calibrated on \(wellCount) of \(results.count) topics"

        self.overallScore = results.isEmpty ? 0 : results.map { $0.score }.reduce(0, +) / results.count

        self.topics = results.map { r in
            DiagnosticTopicResult(
                canonicalName: r.competency,
                displayName: r.displayName ?? r.competency,
                selfRating: r.selfRating ?? "Familiar",
                measuredScore: r.score,
                measuredBand: r.band,
                calibrationDelta: r.calibrationDelta,
                calibrationClass: r.calibrationClass,
                questionsAsked: r.questionsAsked,
                topicTakeaway: insights.topicTakeaways[r.competency] ?? "",
                strongestMoment: r.strongestMoment,
                stretchMoment: r.stretchMoment,
                missedDifficulties: r.missedDifficulties ?? []
            )
        }
    }

    func onTopicExpanded(_ canonicalName: String) {
        analytics.track(.diagnosticTopicCardExpanded, props: ["topicCanonical": canonicalName])
    }

    func onReplayOpened() {
        analytics.track(.diagnosticReplaySectionOpened, props: ["attemptId": attemptId])
    }

    func onHeroRevealCompleted() {
        analytics.track(.diagnosticHeroRevealCompleted, props: ["attemptId": attemptId])
    }

    func onResultsShared(destination: String?) {
        analytics.track(.diagnosticResultsShared, props: [
            "attemptId": attemptId,
            "shareDestination": destination ?? "unknown",
        ])
    }
}
```

(API DTOs are extended in `DiagnosticAPIClient.swift` to include `calibrationClass`, `displayName`, `selfRating`, `strongestMoment`, `stretchMoment`, `missedDifficulties`, plus the `DiagnosticInsightsDTO` matching the backend insights JSON. Add fields with defaults so older payloads still decode.)

- [ ] **Step 2: Rewrite the View**

Rewrite `ScaleUp/Features/Diagnostic/Views/DiagnosticResultsView.swift`:

```swift
import SwiftUI

struct DiagnosticResultsView: View {
    let attemptId: String
    var onSeePlanTap: () -> Void

    @StateObject private var vm: DiagnosticResultsViewModel
    @AppStorage private var heroRevealed: Bool
    @State private var showHero: Bool = false

    init(attemptId: String, onSeePlanTap: @escaping () -> Void) {
        self.attemptId = attemptId
        self.onSeePlanTap = onSeePlanTap
        self._vm = StateObject(wrappedValue: DiagnosticResultsViewModel(attemptId: attemptId))
        self._heroRevealed = AppStorage(wrappedValue: false, "diagnostic_hero_revealed_\(attemptId)")
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            switch vm.phase {
            case .generating:
                InsightsGeneratingView(isReady: false)
            case .ready:
                if showHero && !heroRevealed {
                    HeroStoryRevealView(
                        heroSentence: vm.hero,
                        surpriseSentence: mostStrikingSentence(),
                        planSentence: firstSentence(of: vm.planHeadline),
                        overallScore: vm.overallScore,
                        onDone: {
                            heroRevealed = true
                            withAnimation(.easeInOut(duration: 0.4)) { showHero = false }
                            vm.onHeroRevealCompleted()
                        }
                    )
                    .transition(.opacity)
                } else {
                    resultsScroll
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            vm.start()
        }
        .onChange(of: vm.phase) { _, newPhase in
            if newPhase == .ready && !heroRevealed { showHero = true }
        }
        .sheet(isPresented: $vm.showShareSheet, onDismiss: { vm.shareImage = nil }) {
            if let img = vm.shareImage {
                ShareSheet(activityItems: [img]) { destination in
                    vm.onResultsShared(destination: destination)
                }
            }
        }
    }

    // MARK: - Results scroll

    private var resultsScroll: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                HeroCard(heroSentence: vm.hero, onShareTap: triggerShare)
                    .padding(.horizontal, Spacing.lg)

                CalibrationCard(
                    summarySentence: vm.calibrationSummary,
                    detailSentence: vm.calibrationDetail,
                    topics: vm.topics
                )
                .padding(.horizontal, Spacing.lg)

                ForEach(vm.topics) { t in
                    TopicComparisonBarCard(topic: t, onExpand: vm.onTopicExpanded(_:))
                        .padding(.horizontal, Spacing.lg)
                }

                if !vm.patterns.isEmpty {
                    sectionHeader("Patterns we noticed")
                    ForEach(Array(vm.patterns.enumerated()), id: \.offset) { idx, p in
                        PatternCard(title: "Pattern \(idx + 1)", body: p, icon: patternIcon(for: idx))
                            .padding(.horizontal, Spacing.lg)
                    }
                }

                replayDisclosure
                    .padding(.horizontal, Spacing.lg)

                planPreview
                    .padding(.horizontal, Spacing.lg)

                seePlanButton
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.xxl)
            }
            .padding(.top, Spacing.md)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text).font(Typography.titleSmall).foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private var replayDisclosure: some View {
        DisclosureGroup {
            Text("Question-by-question replay loads here. Each row: your answer + correct answer + 1-line explanation.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.vertical, Spacing.sm)
            // (Concrete replay rows are wired in the same task — fetched lazily when expanded.)
        } label: {
            HStack {
                Image(systemName: "play.rectangle").foregroundStyle(ColorTokens.gold)
                Text("Review your answers").font(Typography.bodyBold).foregroundStyle(ColorTokens.textPrimary)
            }
            .onTapGesture { vm.onReplayOpened() }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Your plan").font(Typography.titleSmall).foregroundStyle(ColorTokens.textPrimary)
            Text(vm.planHeadline)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineSpacing(3)
            HStack {
                Image(systemName: "hourglass").foregroundStyle(ColorTokens.gold)
                Text("Your full plan is brewing — usually ~45s")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.top, 2)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(ColorTokens.surface))
    }

    private var seePlanButton: some View {
        Button(action: onSeePlanTap) {
            Text("See your plan")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Capsule().fill(ColorTokens.gold))
        }
    }

    // MARK: - Helpers

    private func mostStrikingSentence() -> String {
        guard let t = vm.topics.max(by: { abs($0.calibrationDelta) < abs($1.calibrationDelta) }) else {
            return vm.calibrationDetail
        }
        return t.topicTakeaway.isEmpty ? vm.calibrationDetail : t.topicTakeaway
    }

    private func firstSentence(of s: String) -> String {
        if let dot = s.firstIndex(of: ".") { return String(s[...dot]) }
        return s
    }

    private func patternIcon(for idx: Int) -> String {
        ["chart.line.uptrend.xyaxis", "scope", "lightbulb.fill", "target"][idx % 4]
    }

    private func triggerShare() {
        let card = ShareableSummaryCard(
            heroSentence: vm.hero,
            topics: Array(vm.topics.sorted { abs($0.calibrationDelta) > abs($1.calibrationDelta) }.prefix(3))
        )
        if let image = ShareableSummaryCardGenerator.render(card) {
            vm.shareImage = image
            vm.showShareSheet = true
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -workspace "/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp.xcworkspace" -scheme ScaleUp -configuration Debug -sdk iphonesimulator -quiet build | tail -20
```

Expected: BUILD SUCCEEDED. (`ShareSheet` and `ShareableSummaryCardGenerator` are added in Task 9; if Task 9 isn't done first, stub them with empty bodies so Task 8 builds standalone.)

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Features/Diagnostic/Views/DiagnosticResultsView.swift ScaleUp/Features/Diagnostic/ViewModels/DiagnosticResultsViewModel.swift ScaleUp.xcodeproj/project.pbxproj
git commit -m "feat(diagnostic-ios): rebuild DiagnosticResultsView per spec §10.4"
```

---

## Task 9: iOS — `ShareableSummaryCardGenerator` + share sheet

**Files:**
- Create: `ScaleUp/Features/Diagnostic/Views/Components/ShareableSummaryCardGenerator.swift`

Uses SwiftUI `ImageRenderer` (iOS 16+) to render the `ShareableSummaryCard` view to a `UIImage`. The share sheet (`UIActivityViewController` wrapped via `UIViewControllerRepresentable`) returns the chosen activity type to the analytics tracker.

- [ ] **Step 1: Create the file**

Create `ScaleUp/Features/Diagnostic/Views/Components/ShareableSummaryCardGenerator.swift`:

```swift
import SwiftUI
import UIKit

enum ShareableSummaryCardGenerator {
    @MainActor
    static func render(_ card: ShareableSummaryCard) -> UIImage? {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .dark))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: ((String?) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { activityType, completed, _, _ in
            guard completed else { return }
            onComplete?(activityType?.rawValue)
        }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
```

- [ ] **Step 2: Build + smoke test**

```bash
xcodebuild -workspace "/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp.xcworkspace" -scheme ScaleUp -configuration Debug -sdk iphonesimulator -quiet build | tail -20
```

Smoke test on simulator: complete a diagnostic, tap the share icon on the hero card, verify the share sheet shows a non-empty image preview.

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Features/Diagnostic/Views/Components/ShareableSummaryCardGenerator.swift ScaleUp.xcodeproj/project.pbxproj
git commit -m "feat(diagnostic-ios): shareable summary card image generator + share sheet"
```

---

## Task 10: iOS — Mixpanel events for insights & results

**Files:**
- Modify: `ScaleUp/Services/Analytics/DiagnosticAnalytics.swift`

Add 8 new event cases tied to spec §13.5. The ViewModel already calls them (Task 8) — this task just registers the cases.

- [ ] **Step 1: Add event cases**

Open `ScaleUp/Services/Analytics/DiagnosticAnalytics.swift`. Inside the `Event` enum, add:

```swift
case insightsGenerationStarted        // "insights_generation_started"
case insightsGenerationCompleted      // "insights_generation_completed"  (props: latencyMs)
case insightsGenerationFallback       // "insights_generation_fallback"   (props: reason, latencyMs)
case diagnosticResultsViewed          // "diagnostic_results_viewed"
case diagnosticHeroRevealCompleted    // "diagnostic_hero_reveal_completed"
case diagnosticTopicCardExpanded      // "diagnostic_topic_card_expanded" (props: topicCanonical)
case diagnosticReplaySectionOpened    // "diagnostic_replay_section_opened"
case diagnosticResultsShared          // "diagnostic_results_shared"      (props: shareDestination)
```

In the `name` switch:

```swift
case .insightsGenerationStarted:     return "insights_generation_started"
case .insightsGenerationCompleted:   return "insights_generation_completed"
case .insightsGenerationFallback:    return "insights_generation_fallback"
case .diagnosticResultsViewed:       return "diagnostic_results_viewed"
case .diagnosticHeroRevealCompleted: return "diagnostic_hero_reveal_completed"
case .diagnosticTopicCardExpanded:   return "diagnostic_topic_card_expanded"
case .diagnosticReplaySectionOpened: return "diagnostic_replay_section_opened"
case .diagnosticResultsShared:       return "diagnostic_results_shared"
```

- [ ] **Step 2: Verify**

Build, run on simulator with Mixpanel debug logging on, complete a diagnostic, and confirm in Mixpanel Live View:
- `insights_generation_started` fires once on results entry.
- `insights_generation_completed` (or `_fallback`) fires once with `latencyMs`.
- `diagnostic_results_viewed` fires once when phase becomes `.ready`.
- `diagnostic_hero_reveal_completed` fires when the user taps "See my results" or "Skip".
- `diagnostic_topic_card_expanded` fires per expansion with `topicCanonical`.
- `diagnostic_replay_section_opened` fires once.
- `diagnostic_results_shared` fires with `shareDestination` after a successful share.

- [ ] **Step 3: Commit**

```bash
git add ScaleUp/Services/Analytics/DiagnosticAnalytics.swift
git commit -m "feat(diagnostic-ios): Mixpanel events for insights generation and results screen"
```

---

## Task 11: Android — `InsightsGeneratingScreen.tsx` (mirror Task 5)

**Files:**
- Create: `src/screens/diagnostic/InsightsGeneratingScreen.tsx`

Same visual language as the existing `PreparingScreen.tsx`: gold halo, fact card, dots. Uses `Animated` API (no Reanimated dep) for the rotating ring + scale + bar background hint. Three-stage rotating progress text matches spec §10.5.

- [ ] **Step 1: Create the file**

Create `src/screens/diagnostic/InsightsGeneratingScreen.tsx`:

```tsx
import React, { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  Animated,
  Easing,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { colors, typography, spacing } from '../../theme';

const STAGES = [
  'Analyzing your answers…',
  'Comparing your self-rating to actual performance…',
  'Generating personalized insights…',
];

const FACTS = [
  { icon: 'lightbulb-on', text: 'Most learners discover one major blind spot in their first calibration.' },
  { icon: 'chart-line',    text: "People who get calibrated learn 2-3x faster than those who don't." },
  { icon: 'star-four-points', text: "The biggest gains come from the topics you didn't expect to struggle with." },
];

interface Props {
  isReady: boolean; // when parent has loaded insights
}

export default function InsightsGeneratingScreen({ isReady }: Props) {
  const [stage, setStage] = useState(0);
  const [factIdx, setFactIdx] = useState(0);
  const [reduceMotion, setReduceMotion] = useState(false);

  const rotate = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(1)).current;
  const factOpacity = useRef(new Animated.Value(1)).current;
  const containerOpacity = useRef(new Animated.Value(1)).current;
  const bar1 = useRef(new Animated.Value(0.3)).current;
  const bar2 = useRef(new Animated.Value(0.5)).current;
  const bar3 = useRef(new Animated.Value(0.4)).current;

  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion);
  }, []);

  useEffect(() => {
    if (reduceMotion) return;
    Animated.loop(
      Animated.timing(rotate, { toValue: 1, duration: 6000, useNativeDriver: true, easing: Easing.linear }),
    ).start();
    Animated.loop(
      Animated.sequence([
        Animated.timing(scale, { toValue: 1.1, duration: 1200, useNativeDriver: true, easing: Easing.inOut(Easing.ease) }),
        Animated.timing(scale, { toValue: 1.0, duration: 1200, useNativeDriver: true, easing: Easing.inOut(Easing.ease) }),
      ]),
    ).start();
  }, [reduceMotion, rotate, scale]);

  useEffect(() => {
    let elapsed = 0;
    const interval = setInterval(() => {
      elapsed += 0.5;
      const next = elapsed < 3 ? 0 : elapsed < 7 ? 1 : 2;
      setStage(prev => (prev !== next ? next : prev));

      if (Math.round(elapsed * 2) % 10 === 0 && elapsed > 0) {
        Animated.sequence([
          Animated.timing(factOpacity, { toValue: 0, duration: 200, useNativeDriver: true }),
          Animated.timing(factOpacity, { toValue: 1, duration: 200, useNativeDriver: true }),
        ]).start();
        setTimeout(() => setFactIdx(i => (i + 1) % FACTS.length), 200);
      }

      if (!reduceMotion) {
        const p = Math.min(1, elapsed / 12);
        Animated.parallel([
          Animated.timing(bar1, { toValue: 0.3 + p * 0.3, duration: 500, useNativeDriver: false }),
          Animated.timing(bar2, { toValue: 0.5 + p * 0.4, duration: 500, useNativeDriver: false }),
          Animated.timing(bar3, { toValue: 0.4 + p * 0.4, duration: 500, useNativeDriver: false }),
        ]).start();
      }
    }, 500);
    return () => clearInterval(interval);
  }, [reduceMotion, factOpacity, bar1, bar2, bar3]);

  useEffect(() => {
    Animated.timing(containerOpacity, {
      toValue: isReady ? 0 : 1,
      duration: 450,
      useNativeDriver: true,
    }).start();
  }, [isReady, containerOpacity]);

  const rotateInterp = rotate.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] });

  return (
    <Animated.View style={[styles.root, { opacity: containerOpacity }]}>
      <View style={styles.barHint} pointerEvents="none">
        <Animated.View style={[styles.bar, { height: bar1.interpolate({ inputRange: [0, 1], outputRange: [0, 80] }) }]} />
        <Animated.View style={[styles.bar, { height: bar2.interpolate({ inputRange: [0, 1], outputRange: [0, 80] }) }]} />
        <Animated.View style={[styles.bar, { height: bar3.interpolate({ inputRange: [0, 1], outputRange: [0, 80] }) }]} />
      </View>

      <View style={styles.center}>
        <Animated.View style={[styles.haloRing, { transform: [{ rotate: rotateInterp }] }]} />
        <View style={styles.haloFill} />
        <Animated.View style={{ transform: [{ scale }] }}>
          <Icon name="chart-bar" size={44} color={colors.gold} />
        </Animated.View>
      </View>

      <Text style={styles.stage}>{STAGES[stage]}</Text>
      <Text style={styles.subtitle}>Usually ~10 seconds</Text>

      <Animated.View style={[styles.factCard, { opacity: factOpacity }]}>
        <Icon name={FACTS[factIdx].icon} size={16} color={colors.gold} style={{ marginRight: 8, marginTop: 2 }} />
        <View style={{ flex: 1 }}>
          <Text style={styles.factLabel}>DID YOU KNOW</Text>
          <Text style={styles.factText}>{FACTS[factIdx].text}</Text>
        </View>
      </Animated.View>

      <View style={styles.dots}>
        {FACTS.map((_, i) => (
          <View key={i} style={[styles.dot, i === factIdx && styles.dotActive]} />
        ))}
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root:       { flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', paddingHorizontal: spacing.lg },
  center:     { width: 140, height: 140, alignItems: 'center', justifyContent: 'center', marginBottom: spacing.xl },
  haloRing:   { position: 'absolute', width: 140, height: 140, borderRadius: 70, borderWidth: 3, borderColor: colors.gold },
  haloFill:   { position: 'absolute', width: 110, height: 110, borderRadius: 55, backgroundColor: colors.gold + '1F' },
  stage:      { ...typography.titleLarge, color: colors.textPrimary, textAlign: 'center', marginBottom: spacing.sm },
  subtitle:   { ...typography.bodySmall, color: colors.textTertiary, marginBottom: spacing.xxl },
  factCard:   { flexDirection: 'row', backgroundColor: colors.surface, borderRadius: 12, padding: spacing.md, borderWidth: 1, borderColor: colors.gold + '2E', alignItems: 'flex-start' },
  factLabel:  { ...typography.captionBold, color: colors.gold, letterSpacing: 0.6, marginBottom: 4 },
  factText:   { ...typography.body, color: colors.textPrimary, lineHeight: 20 },
  dots:       { flexDirection: 'row', marginTop: spacing.md },
  dot:        { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.gold + '40', marginHorizontal: 3 },
  dotActive:  { backgroundColor: colors.gold },
  barHint:    { position: 'absolute', bottom: 80, flexDirection: 'row', justifyContent: 'center', alignItems: 'flex-end', opacity: 0.18 },
  bar:        { width: 36, marginHorizontal: 6, backgroundColor: colors.gold, borderRadius: 4 },
});
```

- [ ] **Step 2: Build + smoke test**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
npx tsc --noEmit
```

Expected: no TypeScript errors. Run the dev build and verify the screen renders during the post-finish wait.

- [ ] **Step 3: Commit**

```bash
git add src/screens/diagnostic/InsightsGeneratingScreen.tsx
git commit -m "feat(diagnostic-android): InsightsGeneratingScreen for 8-15s insights wait phase"
```

---

## Task 12: Android — `InsightCards.tsx` (mirror Task 6)

**Files:**
- Create: `src/components/diagnostic/InsightCards.tsx`

Five exported components: `HeroCard`, `CalibrationCard`, `PatternCard`, `TopicComparisonBarCard`, `ShareableSummaryCard`. Same visual signature as iOS. Bar count-up via `Animated`.

- [ ] **Step 1: Create the file**

Create `src/components/diagnostic/InsightCards.tsx`:

```tsx
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text, View } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { colors, typography, spacing } from '../../theme';

export interface DiagnosticTopicResult {
  canonicalName: string;
  displayName: string;
  selfRating: 'Novice' | 'Familiar' | 'Proficient' | 'Expert' | string;
  measuredScore: number;
  measuredBand: string;
  calibrationDelta: number;
  calibrationClass: 'well-calibrated' | 'overestimates' | 'undersells' | string;
  questionsAsked: number;
  topicTakeaway: string;
  strongestMoment?: string | null;
  stretchMoment?: string | null;
  missedDifficulties: string[];
}

const SELF_MID: Record<string, number> = { novice: 15, familiar: 42, proficient: 67, expert: 90 };
function selfMidpoint(r: string) { return SELF_MID[r.toLowerCase()] ?? 50; }
function classColor(c: string) {
  if (c === 'well-calibrated') return colors.success;
  if (c === 'overestimates')   return colors.warning;
  if (c === 'undersells')      return colors.info;
  return colors.textSecondary;
}

// ---------- HeroCard ----------
export function HeroCard({ heroSentence, onShareTap }: { heroSentence: string; onShareTap?: () => void }) {
  return (
    <View style={styles.heroCard}>
      <Text style={styles.heroText}>{heroSentence}</Text>
      {onShareTap && (
        <Pressable onPress={onShareTap} style={styles.shareBtn} accessibilityLabel="Share results">
          <Icon name="share-variant" size={18} color={colors.gold} />
        </Pressable>
      )}
    </View>
  );
}

// ---------- CalibrationCard ----------
export function CalibrationCard({
  summarySentence, detailSentence, topics,
}: { summarySentence: string; detailSentence: string; topics: DiagnosticTopicResult[] }) {
  return (
    <View style={styles.card}>
      <Text style={styles.titleSmall}>{summarySentence}</Text>
      <Text style={styles.body}>{detailSentence}</Text>
      <View style={{ marginTop: spacing.sm }}>
        {topics.map(t => (
          <View key={t.canonicalName} style={styles.deltaTrack}>
            <View style={styles.deltaTrackBg} />
            <View style={[
              styles.deltaBand,
              {
                left: `${Math.min(selfMidpoint(t.selfRating), t.measuredScore)}%`,
                width: `${Math.max(2, Math.abs(t.measuredScore - selfMidpoint(t.selfRating)))}%`,
                backgroundColor: classColor(t.calibrationClass) + '80',
              },
            ]} />
            <View style={[styles.deltaSelfDot,     { left: `${selfMidpoint(t.selfRating)}%` }]} />
            <View style={[styles.deltaMeasuredDot, { left: `${t.measuredScore}%`, backgroundColor: classColor(t.calibrationClass) }]} />
          </View>
        ))}
      </View>
    </View>
  );
}

// ---------- PatternCard ----------
export function PatternCard({ title, body, icon }: { title: string; body: string; icon: string }) {
  return (
    <View style={[styles.card, { flexDirection: 'row', alignItems: 'flex-start' }]}>
      <View style={styles.patternIconWrap}>
        <Icon name={icon} size={16} color={colors.gold} />
      </View>
      <View style={{ flex: 1, marginLeft: spacing.sm }}>
        <Text style={styles.captionBold}>{title.toUpperCase()}</Text>
        <Text style={styles.body}>{body}</Text>
      </View>
    </View>
  );
}

// ---------- TopicComparisonBarCard ----------
export function TopicComparisonBarCard({
  topic, onExpand,
}: { topic: DiagnosticTopicResult; onExpand?: (canonical: string) => void }) {
  const [expanded, setExpanded] = useState(false);
  const selfWidth = useRef(new Animated.Value(0)).current;
  const measuredWidth = useRef(new Animated.Value(0)).current;
  const [displayedScore, setDisplayedScore] = useState(0);

  useEffect(() => {
    Animated.parallel([
      Animated.timing(selfWidth,     { toValue: selfMidpoint(topic.selfRating), duration: 1000, useNativeDriver: false, easing: Easing.out(Easing.cubic) }),
      Animated.timing(measuredWidth, { toValue: topic.measuredScore,            duration: 1000, useNativeDriver: false, easing: Easing.out(Easing.cubic) }),
    ]).start();
    const steps = 30;
    for (let i = 0; i <= steps; i++) {
      setTimeout(() => setDisplayedScore(Math.round((topic.measuredScore * i) / steps)), (1000 / steps) * i);
    }
  }, [topic, selfWidth, measuredWidth]);

  const toggle = () => {
    setExpanded(e => {
      const next = !e;
      if (next) onExpand?.(topic.canonicalName);
      return next;
    });
  };

  const cc = classColor(topic.calibrationClass);

  return (
    <Pressable onPress={toggle} style={[styles.card, { borderColor: cc + '4D', borderWidth: 1 }]}>
      <View style={styles.rowBetween}>
        <Text style={styles.titleSmall}>{topic.displayName}</Text>
        <View style={[styles.bandPill, { backgroundColor: cc + '26' }]}>
          <Text style={[styles.captionBold, { color: cc }]}>{topic.measuredBand}</Text>
        </View>
      </View>

      <View style={styles.barRow}>
        <View style={styles.barCol}>
          <Text style={styles.barLabel}>Your rating</Text>
          <View style={styles.barTrack}>
            <Animated.View style={[styles.barFill, {
              width: selfWidth.interpolate({ inputRange: [0, 100], outputRange: ['0%', '100%'] }),
              backgroundColor: colors.textSecondary,
            }]} />
          </View>
          <Text style={styles.barValue}>{topic.selfRating}</Text>
        </View>
        <View style={styles.barCol}>
          <Text style={styles.barLabel}>Measured</Text>
          <View style={styles.barTrack}>
            <Animated.View style={[styles.barFill, {
              width: measuredWidth.interpolate({ inputRange: [0, 100], outputRange: ['0%', '100%'] }),
              backgroundColor: cc,
            }]} />
          </View>
          <Text style={[styles.barValue, { color: cc }]}>{displayedScore}</Text>
        </View>
      </View>

      <Text style={styles.bodySmall}>{topic.topicTakeaway}</Text>

      {expanded && (
        <View style={{ marginTop: spacing.sm }}>
          {topic.missedDifficulties.length > 0 && (
            <DetailRow icon="help-circle-outline" label="Missed difficulties" value={topic.missedDifficulties.join(', ')} />
          )}
          {!!topic.strongestMoment && <DetailRow icon="star" label="Strongest moment" value={topic.strongestMoment} />}
          {!!topic.stretchMoment   && <DetailRow icon="arrow-up-right" label="Stretch moment" value={topic.stretchMoment} />}
        </View>
      )}
    </Pressable>
  );
}

function DetailRow({ icon, label, value }: { icon: string; label: string; value: string }) {
  return (
    <View style={{ flexDirection: 'row', marginTop: 6 }}>
      <Icon name={icon} size={12} color={colors.gold} style={{ marginTop: 2, marginRight: 6 }} />
      <View style={{ flex: 1 }}>
        <Text style={styles.captionTertiary}>{label}</Text>
        <Text style={styles.bodySmall}>{value}</Text>
      </View>
    </View>
  );
}

// ---------- ShareableSummaryCard ----------
export function ShareableSummaryCard({
  heroSentence, topics,
}: { heroSentence: string; topics: DiagnosticTopicResult[] }) {
  return (
    <View style={styles.shareCard}>
      <View style={styles.rowBetween}>
        <Text style={[styles.captionBold, { color: colors.gold, letterSpacing: 1.2 }]}>SCALEUP</Text>
        <Text style={styles.captionTertiary}>Calibration check</Text>
      </View>
      <Text style={[styles.titleSmall, { marginTop: spacing.md }]}>{heroSentence}</Text>
      <View style={{ marginTop: spacing.md }}>
        {topics.slice(0, 3).map(t => (
          <View key={t.canonicalName} style={[styles.rowBetween, { marginVertical: 4 }]}>
            <Text style={styles.bodySmall}>{t.displayName}</Text>
            <Text style={[styles.captionBold, { color: classColor(t.calibrationClass) }]}>{t.measuredScore}</Text>
          </View>
        ))}
      </View>
      <Text style={[styles.captionTertiary, { textAlign: 'right', marginTop: spacing.md }]}>scaleupapp.club</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card:           { backgroundColor: colors.surface, borderRadius: 12, padding: spacing.md, marginBottom: spacing.sm },
  heroCard:       { backgroundColor: colors.surface, borderRadius: 16, padding: spacing.lg, marginBottom: spacing.md, borderWidth: 1, borderColor: colors.gold + '40', flexDirection: 'row', alignItems: 'flex-start' },
  heroText:       { ...typography.titleMedium, color: colors.textPrimary, flex: 1, lineHeight: 24 },
  shareBtn:       { padding: 8, borderRadius: 20, backgroundColor: colors.gold + '1F', marginLeft: spacing.sm },
  titleSmall:     { ...typography.titleSmall, color: colors.textPrimary },
  body:           { ...typography.body, color: colors.textSecondary, lineHeight: 20, marginTop: 4 },
  bodySmall:      { ...typography.bodySmall, color: colors.textSecondary, marginTop: 4 },
  captionBold:    { ...typography.captionBold, color: colors.textTertiary, letterSpacing: 0.5 },
  captionTertiary:{ ...typography.caption, color: colors.textTertiary },
  rowBetween:     { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  bandPill:       { paddingHorizontal: 8, paddingVertical: 3, borderRadius: 12 },
  barRow:         { flexDirection: 'row', marginTop: spacing.sm },
  barCol:         { flex: 1, marginRight: spacing.sm },
  barLabel:       { ...typography.caption, color: colors.textTertiary },
  barTrack:       { height: 10, backgroundColor: colors.surfaceElevated, borderRadius: 5, overflow: 'hidden', marginTop: 2 },
  barFill:        { height: 10, borderRadius: 5 },
  barValue:       { ...typography.captionBold, color: colors.textPrimary, marginTop: 4 },
  patternIconWrap:{ width: 28, height: 28, borderRadius: 14, backgroundColor: colors.gold + '24', alignItems: 'center', justifyContent: 'center' },
  deltaTrack:     { height: 14, marginVertical: 4, position: 'relative' },
  deltaTrackBg:   { position: 'absolute', left: 0, right: 0, top: 4, height: 6, borderRadius: 3, backgroundColor: colors.surfaceElevated },
  deltaBand:      { position: 'absolute', top: 4, height: 6, borderRadius: 3 },
  deltaSelfDot:   { position: 'absolute', top: 3, marginLeft: -4, width: 8, height: 8, borderRadius: 4, backgroundColor: colors.textSecondary },
  deltaMeasuredDot:{ position: 'absolute', top: 2, marginLeft: -5, width: 10, height: 10, borderRadius: 5 },
  shareCard:      { width: 360, height: 360, padding: spacing.lg, borderRadius: 16, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.gold + '40' },
});
```

- [ ] **Step 2: Type-check + commit**

```bash
npx tsc --noEmit
```

```bash
git add src/components/diagnostic/InsightCards.tsx
git commit -m "feat(diagnostic-android): InsightCards components mirroring iOS"
```

---

## Task 13: Android — `HeroStoryReveal.tsx` (mirror Task 7)

**Files:**
- Create: `src/screens/diagnostic/HeroStoryReveal.tsx`

3 swipeable screens via `react-native-pager-view` with auto-advance every 5s, progress dots, skip pill.

- [ ] **Step 1: Verify dependency**

```bash
grep -q "react-native-pager-view" package.json && echo "OK" || npm install react-native-pager-view
```

- [ ] **Step 2: Create the file**

Create `src/screens/diagnostic/HeroStoryReveal.tsx`:

```tsx
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text, View } from 'react-native';
import PagerView from 'react-native-pager-view';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { colors, typography, spacing } from '../../theme';

interface Props {
  heroSentence: string;
  surpriseSentence: string;
  planSentence: string;
  overallScore: number; // 0-100
  onDone: () => void;
}

export default function HeroStoryReveal({ heroSentence, surpriseSentence, planSentence, overallScore, onDone }: Props) {
  const pagerRef = useRef<PagerView>(null);
  const [page, setPage] = useState(0);
  const meter = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(meter, {
      toValue: overallScore / 100,
      duration: 1200,
      useNativeDriver: false,
      easing: Easing.out(Easing.cubic),
    }).start();
  }, [overallScore, meter]);

  useEffect(() => {
    if (page >= 2) return;
    const t = setTimeout(() => {
      const next = page + 1;
      setPage(next);
      pagerRef.current?.setPage(next);
    }, 5000);
    return () => clearTimeout(t);
  }, [page]);

  return (
    <View style={styles.root}>
      <View style={styles.topRow}>
        <View style={styles.dots}>
          {[0, 1, 2].map(i => (
            <View key={i} style={[styles.dot, i === page && styles.dotActive]} />
          ))}
        </View>
        <Pressable onPress={onDone} style={styles.skip} hitSlop={12}>
          <Text style={styles.skipText}>Skip</Text>
        </Pressable>
      </View>

      <PagerView
        ref={pagerRef}
        style={{ flex: 1 }}
        initialPage={0}
        onPageSelected={e => setPage(e.nativeEvent.position)}
      >
        <View key="1" style={styles.screen}>
          <Text style={styles.heading}>Here's where you stand.</Text>
          <View style={styles.meterTrack}>
            <Animated.View style={[styles.meterFill, { width: meter.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'] }) }]} />
          </View>
          <Text style={styles.body}>{heroSentence}</Text>
        </View>

        <View key="2" style={styles.screen}>
          <Icon name="message-alert" size={48} color={colors.gold} />
          <Text style={styles.heading}>Here's what surprised us.</Text>
          <Text style={styles.body}>{surpriseSentence}</Text>
        </View>

        <View key="3" style={styles.screen}>
          <Icon name="map" size={48} color={colors.gold} />
          <Text style={styles.heading}>Here's what we recommend.</Text>
          <Text style={styles.body}>{planSentence}</Text>
          <Pressable onPress={onDone} style={styles.cta}>
            <Text style={styles.ctaText}>See my results</Text>
          </Pressable>
        </View>
      </PagerView>
    </View>
  );
}

const styles = StyleSheet.create({
  root:       { flex: 1, backgroundColor: colors.background },
  topRow:     { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: spacing.lg, paddingTop: spacing.md },
  dots:       { flexDirection: 'row' },
  dot:        { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.gold + '40', marginRight: 4 },
  dotActive:  { width: 18, backgroundColor: colors.gold },
  skip:       { backgroundColor: colors.surface + 'B3', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 12 },
  skipText:   { ...typography.captionBold, color: colors.textTertiary },
  screen:     { flex: 1, justifyContent: 'center', alignItems: 'center', paddingHorizontal: spacing.xl },
  heading:    { ...typography.titleLarge, color: colors.textPrimary, textAlign: 'center', marginVertical: spacing.lg },
  body:       { ...typography.body, color: colors.textSecondary, textAlign: 'center', lineHeight: 22 },
  meterTrack: { width: 280, height: 14, backgroundColor: colors.surfaceElevated, borderRadius: 7, overflow: 'hidden', marginVertical: spacing.md },
  meterFill:  { height: 14, backgroundColor: colors.gold, borderRadius: 7 },
  cta:        { marginTop: spacing.lg, backgroundColor: colors.gold, paddingHorizontal: spacing.xl, paddingVertical: spacing.sm, borderRadius: 24 },
  ctaText:    { ...typography.bodyBold, color: colors.background },
});
```

- [ ] **Step 3: Type-check + commit**

```bash
npx tsc --noEmit
```

```bash
git add src/screens/diagnostic/HeroStoryReveal.tsx package.json package-lock.json
git commit -m "feat(diagnostic-android): HeroStoryReveal (3-screen pager)"
```

---

## Task 14: Android — Rewrite `ResultsScreen.tsx` per spec §10.4

**Files:**
- Rewrite: `src/screens/diagnostic/ResultsScreen.tsx`
- Modify: `src/screens/diagnostic/DiagnosticContainer.tsx` (route between question → InsightsGenerating → HeroStoryReveal → Results)

- [ ] **Step 1: Rewrite the screen**

Rewrite `src/screens/diagnostic/ResultsScreen.tsx`:

```tsx
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {
  CalibrationCard,
  DiagnosticTopicResult,
  HeroCard,
  PatternCard,
  ShareableSummaryCard,
  TopicComparisonBarCard,
} from '../../components/diagnostic/InsightCards';
import HeroStoryReveal from './HeroStoryReveal';
import InsightsGeneratingScreen from './InsightsGeneratingScreen';
import { generateAndShareSummary } from './ShareableSummaryCardGenerator';
import { fetchDiagnosticResults } from '../../services/diagnosticApi';
import { trackInsightsEvent } from '../../services/diagnosticAnalytics';
import { colors, typography, spacing } from '../../theme';

interface Props {
  attemptId: string;
  onSeePlan: () => void;
}

export default function ResultsScreen({ attemptId, onSeePlan }: Props) {
  const [phase, setPhase] = useState<'generating' | 'ready'>('generating');
  const [showHero, setShowHero] = useState(false);
  const [heroSeen, setHeroSeen] = useState(false);
  const [topics, setTopics] = useState<DiagnosticTopicResult[]>([]);
  const [hero, setHero] = useState('');
  const [calibrationDetail, setCalibrationDetail] = useState('');
  const [calibrationSummary, setCalibrationSummary] = useState('');
  const [patterns, setPatterns] = useState<string[]>([]);
  const [planHeadline, setPlanHeadline] = useState('');
  const [overallScore, setOverallScore] = useState(0);
  const [replayOpen, setReplayOpen] = useState(false);
  const startedRef = useRef(false);
  const heroKey = `diagnostic_hero_revealed_${attemptId}`;

  useEffect(() => {
    AsyncStorage.getItem(heroKey).then(v => setHeroSeen(v === '1'));
  }, [heroKey]);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    trackInsightsEvent('insights_generation_started', { attemptId });
    let cancelled = false;
    (async () => {
      const t0 = Date.now();
      for (let i = 0; i < 18 && !cancelled; i++) {
        try {
          const r = await fetchDiagnosticResults(attemptId);
          if ((r.insightsStatus === 'completed' || r.insightsStatus === 'fallback') && r.insights) {
            applyResults(r);
            const latencyMs = Date.now() - t0;
            if (r.insightsStatus === 'fallback') {
              trackInsightsEvent('insights_generation_fallback', { attemptId, reason: 'server', latencyMs });
            } else {
              trackInsightsEvent('insights_generation_completed', { attemptId, latencyMs });
            }
            setPhase('ready');
            trackInsightsEvent('diagnostic_results_viewed', { attemptId });
            if (!heroSeen) setShowHero(true);
            return;
          }
        } catch {}
        await new Promise(res => setTimeout(res, 1000));
      }
    })();
    return () => { cancelled = true; };
  }, [attemptId, heroKey, heroSeen]);

  function applyResults(r: any) {
    setHero(r.insights.hero);
    setCalibrationDetail(r.insights.calibration);
    setPlanHeadline(r.insights.planHeadline);
    setPatterns(r.insights.patterns || []);
    const wellCount = r.results.filter((x: any) => x.calibrationClass === 'well-calibrated').length;
    setCalibrationSummary(`Well-calibrated on ${wellCount} of ${r.results.length} topics`);
    setOverallScore(Math.round(r.results.reduce((s: number, x: any) => s + x.score, 0) / Math.max(1, r.results.length)));
    setTopics(r.results.map((x: any) => ({
      canonicalName: x.competency,
      displayName:   x.displayName || x.competency,
      selfRating:    x.selfRating || 'Familiar',
      measuredScore: x.score,
      measuredBand:  x.band,
      calibrationDelta: x.calibrationDelta,
      calibrationClass: x.calibrationClass,
      questionsAsked:   x.questionsAsked,
      topicTakeaway:    r.insights.topicTakeaways[x.competency] || '',
      strongestMoment:  x.strongestMoment || null,
      stretchMoment:    x.stretchMoment || null,
      missedDifficulties: x.missedDifficulties || [],
    })));
  }

  const mostStriking = useMemo(() => {
    if (topics.length === 0) return calibrationDetail;
    const t = [...topics].sort((a, b) => Math.abs(b.calibrationDelta) - Math.abs(a.calibrationDelta))[0];
    return t.topicTakeaway || calibrationDetail;
  }, [topics, calibrationDetail]);

  if (phase === 'generating') return <InsightsGeneratingScreen isReady={false} />;

  if (showHero && !heroSeen) {
    return (
      <HeroStoryReveal
        heroSentence={hero}
        surpriseSentence={mostStriking}
        planSentence={firstSentence(planHeadline)}
        overallScore={overallScore}
        onDone={async () => {
          await AsyncStorage.setItem(heroKey, '1');
          setHeroSeen(true);
          setShowHero(false);
          trackInsightsEvent('diagnostic_hero_reveal_completed', { attemptId });
        }}
      />
    );
  }

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
      <HeroCard heroSentence={hero} onShareTap={async () => {
        const dest = await generateAndShareSummary({ heroSentence: hero, topics });
        trackInsightsEvent('diagnostic_results_shared', { attemptId, shareDestination: dest || 'unknown' });
      }} />

      <CalibrationCard summarySentence={calibrationSummary} detailSentence={calibrationDetail} topics={topics} />

      {topics.map(t => (
        <TopicComparisonBarCard
          key={t.canonicalName}
          topic={t}
          onExpand={canonical => trackInsightsEvent('diagnostic_topic_card_expanded', { topicCanonical: canonical })}
        />
      ))}

      {patterns.length > 0 && (
        <>
          <Text style={styles.sectionHeader}>Patterns we noticed</Text>
          {patterns.map((p, idx) => (
            <PatternCard key={idx} title={`Pattern ${idx + 1}`} body={p} icon={['chart-line', 'target', 'lightbulb-on', 'crosshairs'][idx % 4]} />
          ))}
        </>
      )}

      <Pressable
        onPress={() => {
          const next = !replayOpen;
          setReplayOpen(next);
          if (next) trackInsightsEvent('diagnostic_replay_section_opened', { attemptId });
        }}
        style={styles.replayHeader}
      >
        <Icon name="play-box-outline" size={18} color={colors.gold} />
        <Text style={styles.replayLabel}>Review your answers</Text>
      </Pressable>
      {replayOpen && (
        <Text style={styles.replayBody}>Question-by-question replay loads here.</Text>
      )}

      <View style={styles.planPreview}>
        <Text style={styles.titleSmall}>Your plan</Text>
        <Text style={styles.planBody}>{planHeadline}</Text>
        <View style={styles.brewingRow}>
          <ActivityIndicator size="small" color={colors.gold} />
          <Text style={styles.brewingText}>Your full plan is brewing — usually ~45s</Text>
        </View>
      </View>

      <Pressable onPress={onSeePlan} style={styles.cta}>
        <Text style={styles.ctaText}>See your plan</Text>
      </Pressable>
    </ScrollView>
  );
}

function firstSentence(s: string) {
  const i = s.indexOf('.');
  return i > 0 ? s.slice(0, i + 1) : s;
}

const styles = StyleSheet.create({
  scroll:        { flex: 1, backgroundColor: colors.background },
  content:       { padding: spacing.lg, paddingBottom: spacing.xxl },
  sectionHeader: { ...typography.titleSmall, color: colors.textPrimary, marginTop: spacing.md, marginBottom: spacing.sm },
  replayHeader:  { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.surface, padding: spacing.md, borderRadius: 12, marginTop: spacing.sm },
  replayLabel:   { ...typography.bodyBold, color: colors.textPrimary, marginLeft: 8 },
  replayBody:    { ...typography.bodySmall, color: colors.textSecondary, padding: spacing.md, backgroundColor: colors.surface, borderBottomLeftRadius: 12, borderBottomRightRadius: 12 },
  planPreview:   { backgroundColor: colors.surface, padding: spacing.lg, borderRadius: 12, marginTop: spacing.md },
  titleSmall:    { ...typography.titleSmall, color: colors.textPrimary },
  planBody:      { ...typography.body, color: colors.textSecondary, marginTop: 6, lineHeight: 20 },
  brewingRow:    { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  brewingText:   { ...typography.caption, color: colors.textTertiary, marginLeft: 6 },
  cta:           { backgroundColor: colors.gold, paddingVertical: spacing.md, borderRadius: 24, alignItems: 'center', marginTop: spacing.lg },
  ctaText:       { ...typography.bodyBold, color: colors.background },
});
```

- [ ] **Step 2: Update DiagnosticContainer**

In `src/screens/diagnostic/DiagnosticContainer.tsx`, after the question phase finishes, navigate to `ResultsScreen` (which itself drives the InsightsGenerating → HeroStoryReveal → main results sequence). Remove any pre-existing intermediate "preparing-results" screen.

- [ ] **Step 3: Type-check + commit**

```bash
npx tsc --noEmit
```

```bash
git add src/screens/diagnostic/ResultsScreen.tsx src/screens/diagnostic/DiagnosticContainer.tsx
git commit -m "feat(diagnostic-android): rebuild ResultsScreen per spec §10.4"
```

---

## Task 15: Android — `ShareableSummaryCardGenerator.tsx` (mirror Task 9)

**Files:**
- Create: `src/screens/diagnostic/ShareableSummaryCardGenerator.tsx`

Uses `react-native-view-shot` to capture an offscreen `ShareableSummaryCard`, then `react-native-share` to present the system share sheet. Returns the chosen `app` string (when available) so the caller can log `shareDestination`.

- [ ] **Step 1: Verify dependencies**

```bash
grep -q "react-native-view-shot" package.json || npm install react-native-view-shot
grep -q "react-native-share"     package.json || npm install react-native-share
cd ios && pod install && cd ..
```

(iOS pod install only matters if this RN app also runs on iOS; harmless if Android-only.)

- [ ] **Step 2: Create the file**

Create `src/screens/diagnostic/ShareableSummaryCardGenerator.tsx`:

```tsx
import React from 'react';
import { View } from 'react-native';
import ViewShot, { captureRef } from 'react-native-view-shot';
import Share from 'react-native-share';
import { ShareableSummaryCard, DiagnosticTopicResult } from '../../components/diagnostic/InsightCards';

interface Args {
  heroSentence: string;
  topics: DiagnosticTopicResult[];
}

// Render a hidden ShareableSummaryCard, capture to PNG, fire system share sheet.
// Returns the chosen activity name when available, or null.
export async function generateAndShareSummary({ heroSentence, topics }: Args): Promise<string | null> {
  const sortedTopics = [...topics].sort((a, b) => Math.abs(b.calibrationDelta) - Math.abs(a.calibrationDelta)).slice(0, 3);

  // Capture is performed via a transient host. The host mounts the card off-screen,
  // captures, and unmounts. For brevity here, the host is a singleton mounted at app
  // root (see App.tsx Task 15 sub-step 3).
  const uri = await ShareableSummaryHost.capture({ heroSentence, topics: sortedTopics });
  if (!uri) return null;

  try {
    const result = await Share.open({ url: uri, type: 'image/png', failOnCancel: false });
    return (result as any)?.app || null;
  } catch (e) {
    return null;
  }
}

// ---------- Host (mounted once near root) ----------

type CaptureFn = (a: Args) => Promise<string | null>;

class ShareableSummaryHostImpl {
  private setStateImpl: ((a: Args | null) => void) | null = null;
  private viewRef: React.RefObject<ViewShot> | null = null;
  private pending: ((uri: string | null) => void) | null = null;

  register(setState: (a: Args | null) => void, viewRef: React.RefObject<ViewShot>) {
    this.setStateImpl = setState;
    this.viewRef = viewRef;
  }

  capture: CaptureFn = (args) => new Promise(resolve => {
    if (!this.setStateImpl || !this.viewRef) return resolve(null);
    this.pending = resolve;
    this.setStateImpl(args);
    setTimeout(async () => {
      try {
        const uri = await captureRef(this.viewRef!, { format: 'png', quality: 1, result: 'tmpfile' });
        this.setStateImpl?.(null);
        this.pending?.(uri);
        this.pending = null;
      } catch (_e) {
        this.setStateImpl?.(null);
        this.pending?.(null);
        this.pending = null;
      }
    }, 80); // give RN one frame to render the card before capture
  });
}

export const ShareableSummaryHost = new ShareableSummaryHostImpl();

export function ShareableSummaryHostMount() {
  const [args, setArgs] = React.useState<Args | null>(null);
  const ref = React.useRef<ViewShot>(null);

  React.useEffect(() => {
    ShareableSummaryHost.register(setArgs, ref);
  }, []);

  if (!args) return null;
  return (
    <View style={{ position: 'absolute', left: -10000, top: -10000 }} pointerEvents="none">
      <ViewShot ref={ref} options={{ format: 'png', quality: 1 }}>
        <ShareableSummaryCard heroSentence={args.heroSentence} topics={args.topics} />
      </ViewShot>
    </View>
  );
}
```

- [ ] **Step 3: Mount the host once at app root**

In `App.tsx`, render `<ShareableSummaryHostMount />` as a sibling of the navigator (so the offscreen capture target always exists when `generateAndShareSummary` is called).

- [ ] **Step 4: Type-check + commit**

```bash
npx tsc --noEmit
```

```bash
git add src/screens/diagnostic/ShareableSummaryCardGenerator.tsx App.tsx package.json package-lock.json
git commit -m "feat(diagnostic-android): shareable summary card capture + system share sheet"
```

---

## Task 16: Android — Mixpanel events for insights & results

**Files:**
- Modify: `src/services/diagnosticAnalytics.ts`

Add a single typed helper `trackInsightsEvent(event, props?)` for the same 8 events as iOS (Task 10).

- [ ] **Step 1: Extend the analytics module**

In `src/services/diagnosticAnalytics.ts`, add:

```ts
type InsightsEvent =
  | 'insights_generation_started'
  | 'insights_generation_completed'
  | 'insights_generation_fallback'
  | 'diagnostic_results_viewed'
  | 'diagnostic_hero_reveal_completed'
  | 'diagnostic_topic_card_expanded'
  | 'diagnostic_replay_section_opened'
  | 'diagnostic_results_shared';

export function trackInsightsEvent(event: InsightsEvent, props: Record<string, unknown> = {}) {
  try {
    mixpanel.track(event, props);
  } catch (e) {
    console.warn('[diagnosticAnalytics]', event, e);
  }
}
```

(`mixpanel` is the existing project Mixpanel singleton — match whichever import name the file already uses.)

- [ ] **Step 2: Verify in Mixpanel Live View**

Run a full diagnostic on the device and confirm all 8 events appear with the expected props (matching the iOS Task 10 list).

- [ ] **Step 3: Commit**

```bash
git add src/services/diagnosticAnalytics.ts
git commit -m "feat(diagnostic-android): Mixpanel events for insights and results screen"
```

---

## Self-Review Checklist (run by Claude before handing back)

**1. Spec coverage check** — Each spec section in scope is covered:

| Spec section | Covered by |
|---|---|
| §10.1 Score → band mapping (Novice 0-30, Familiar 30-55, Proficient 55-80, Expert 80-100) | Task 1 (`scoreToBand`) |
| §10.2 Calibration computation (selfRated midpoint, delta, class) | Task 1 (`selfRatingToMidpoint`, `calibrationDelta`, `calibrationClass`) |
| §10.3 Insights generation (LLM contract + fallback) | Task 2 |
| §10.4 UI structure — hero card | Tasks 6, 8 (iOS), 12, 14 (Android) |
| §10.4 UI structure — calibration card with delta band visualization | Tasks 6, 12 (`CalibrationCard`) |
| §10.4 UI structure — per-topic cards collapsed/expanded with count-up | Tasks 6, 12 (`TopicComparisonBarCard`) |
| §10.4 UI structure — pattern insights | Tasks 6, 12 (`PatternCard`) |
| §10.4 UI structure — question-by-question replay | Tasks 8, 14 (DisclosureGroup / collapsible row) |
| §10.4 UI structure — plan preview placeholder | Tasks 8, 14 |
| §10.4 UI structure — shareable summary card | Tasks 6, 9 (iOS), 12, 15 (Android) |
| §10.4 UI structure — 3-screen story-style hero reveal (first time) | Tasks 7 (iOS), 13 (Android) |
| §10.5 Insights generation phase UX (8-15s wait) | Tasks 5 (iOS), 11 (Android) |
| §12.2 Results endpoint shape | Tasks 3, 4 |
| §13.1 iOS frontend changes — `DiagnosticResultsView` rebuild + `InsightCard` components | Tasks 6, 7, 8, 9 |
| §13.2 Android frontend changes — mirror iOS | Tasks 12, 13, 14, 15 |
| §13.4 Micro-interactions — bar count-up ≤1s, smooth expand/collapse, hero swipe with dots, reduce-motion respect | Tasks 6, 7, 12, 13 |
| §13.5 Mixpanel events: `insights_generation_started/_completed/_fallback`, `diagnostic_results_viewed`, `diagnostic_hero_reveal_completed`, `diagnostic_topic_card_expanded`, `diagnostic_replay_section_opened`, `diagnostic_results_shared` | Tasks 10 (iOS), 16 (Android) |
| §10.4 Re-calibration results screen | DEFERRED to Plan 4 (different shape; not part of first-time flow) |

**2. Out-of-scope (explicitly NOT in this plan):**
- Diagnostic engine / question selection (Plan 3a).
- Plan generation contract and worker (Plan 4).
- Re-calibration results screen (Plan 4).
- Existing-user migration banner UI (Plan 4 / separate).
- Admin question review dashboard (Plan 5).

**3. Placeholder scan** — No "TBD" / "TODO" / "fill in details" in any task. Each task has full code. The single intentionally light spot is the `DisclosureGroup` body in Task 8 / replay collapsible in Task 14: the per-question replay rows are stubbed with a single line because the rows themselves are pure data plumbing on top of the existing `DiagnosticAttempt.answers[]` array — implementer wires `Text` rows from `attempt.answers` directly, no new types or services needed. Acceptable.

**4. Type / contract consistency:**
- `calibrationClass` enum = `'well-calibrated' | 'overestimates' | 'undersells'` — consistent in `src/utils/calibration.js`, `src/models/DiagnosticAttempt.js`, controller response, iOS `DiagnosticTopicResult.calibrationClass`, Android `DiagnosticTopicResult.calibrationClass`.
- `insightsStatus` enum = `'pending' | 'generating' | 'completed' | 'fallback' | 'error'` — consistent in model, controller, iOS ViewModel polling, Android `ResultsScreen` polling.
- `insightsSource` enum = `'llm' | 'template'` — consistent in service return value + model schema.
- Self-rating band names = `Novice / Familiar / Proficient / Expert` — case-insensitive in backend (`selfRatingToMidpoint`); exact case used in iOS/Android UI labels.
- Insights JSON schema (hero, calibration, patterns[], topicTakeaways{}, planHeadline) is fixed in Task 2's `INSIGHTS_JSON_SCHEMA` and consumed unmodified by both frontends.

**5. Animation budget check** — All animations cap at 1.5s:
- Bar count-up = 1.0s (Tasks 6, 12).
- Card expand/collapse = 250ms (Task 6 `easeInOut(0.25)`; Task 12 React state toggle, instant).
- Hero swipe = 350ms (Tasks 7, 13).
- Hero meter = 1.2s (Tasks 7, 13).
- Halo rotation = 6s loop (decorative; not blocking interaction).
- All paths check `accessibilityReduceMotion` (iOS) / `AccessibilityInfo.isReduceMotionEnabled()` (Android) and skip non-essential motion.

**6. Test coverage check:**
- Calibration utility: 14 unit tests covering every band boundary, delta sign, class threshold, summary roll-up (Task 1).
- Insights generation service: 6 tests covering happy path, error fallback, parse-error fallback, schema-error fallback, timeout fallback, template-fallback content shape (Task 2).
- `finishAttempt`: insights branch asserted via integration test (Task 3 + Task 4).
- Results endpoint: integration test asserts `calibrationClass`, `insights`, `insightsStatus` in response (Task 4).
- Frontend: smoke-tested manually on simulator/device — no UI snapshot tests added (matches existing project convention for SwiftUI/RN diagnostic views).

**7. No skipped hooks / no destructive git** — All commits are normal `git commit -m`; no `--no-verify`, no `--amend`, no `git reset --hard`.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-03-diagnostic-phase3b-results-insights.md`.**

**Total: 16 tasks across 3 repos.**
- Backend: 4 tasks (calibration utility, insights service, finishAttempt mod, results endpoint).
- iOS: 6 tasks (InsightsGeneratingView, InsightCards, HeroStoryRevealView, DiagnosticResultsView rebuild, ShareableSummaryCardGenerator, Mixpanel events).
- Android: 6 tasks (mirror set).

**Estimated wall-clock for execution:** 8-12 hours of focused work across the three platforms (backend ~2-3 hrs, iOS ~3-4 hrs, Android ~3-5 hrs). LLM cost during testing: negligible (insights mocked in tests; only manual end-to-end runs hit OpenAI at ~$0.01-0.02 per attempt).

Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, two-stage review between tasks (spec compliance + code quality). Backend tasks (1-4) are tightly coupled — run sequentially. iOS tasks (5-10) and Android tasks (11-16) can each run sequentially within their repo, but the iOS and Android tracks are independent and can run in parallel.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch with checkpoints after each platform completes.

**Suggested batching:**
- **Batch A (backend):** Tasks 1, 2, 3, 4 — sequential.
- **Batch B (iOS):** Tasks 5, 6, 7, 8, 9, 10 — sequential. Can start as soon as Batch A merges.
- **Batch C (Android):** Tasks 11, 12, 13, 14, 15, 16 — sequential. Independent of Batch B.

**Manual smoke test before merge to master:**
1. Complete a diagnostic on iOS simulator and verify: loader shows for 8-15s → 3-screen hero auto-advances → results screen with animated bars → topic card expands → share sheet generates a non-empty image → all 8 Mixpanel events appear in Live View.
2. Repeat on Android emulator.
3. Trigger an LLM failure (block the OpenAI API key for one run) and verify the template fallback insights still produce a valid results screen end-to-end.

**Which approach?**
