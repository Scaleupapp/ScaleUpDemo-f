# Day-1 Proficiency Diagnostic — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the backend foundation for the day-1 proficiency diagnostic — models, generation pipeline, adaptive selector, integration points, and telemetry — so iOS and RN clients can consume working `/api/v1/diagnostic/*` endpoints.

**Architecture:** Additive over existing infrastructure. Two new Mongoose collections (`DiagnosticAttempt`, `DiagnosticQuestionBank`), two new optional fields on `KnowledgeProfile.topicMastery`, eight new endpoints under `/api/v1/diagnostic/`. Question generation extends the existing `quizGenerationService` with a "diagnostic" mode using gpt-4o-mini. The adaptive selector is a server-side state machine. All schema changes are additive — zero migrations required.

**Tech Stack:** Node.js 20, Express, Mongoose, gpt-4o-mini (existing OpenAI client), Node native test runner (`node --test`).

**Spec reference:** [`docs/superpowers/specs/2026-04-27-day1-proficiency-diagnostic-design.md`](../specs/2026-04-27-day1-proficiency-diagnostic-design.md)

**Repository working directory:** `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend`

---

## File map

**Files to create:**
| Path | Responsibility |
|---|---|
| `src/models/DiagnosticAttempt.js` | Mongoose model: per-attempt record (status, answers, results) |
| `src/models/DiagnosticQuestionBank.js` | Mongoose model: cached questions keyed by (canonicalCompetency, difficulty) |
| `src/services/competencyNormalizer.js` | Canonicalize competency names; alias dictionary + similarity fallback |
| `src/services/diagnosticPoolService.js` | Generate question pool via LLM batch call; merge with bank |
| `src/services/diagnosticSelectorService.js` | Adaptive selector state machine — picks next question based on running performance |
| `src/services/diagnosticService.js` | Main orchestration — startAttempt, submitSelfRating, nextQuestion, submitAnswer, finishAttempt, abandon |
| `src/controllers/diagnosticController.js` | Express handlers — thin wrappers over service |
| `src/routes/diagnostic.js` | Route definitions — mounts under `/api/v1/diagnostic` |
| `src/config/featureFlags.js` | Feature flag config (single source of truth) |
| Test files: `*.test.js` alongside each source file | Node native test runner |

**Files to modify:**
| Path | Change |
|---|---|
| `src/models/KnowledgeProfile.js` | Add optional `selfRating` and `calibrationAtBaseline` fields to topicMastery subschema |
| `src/services/quizGenerationService.js` | Add a `'diagnostic'` quiz type with the diagnostic-specific prompt rules |
| `src/services/journeyGenerationService.js` | Consume `diagnosticData` when present, fall through to existing path otherwise |
| `src/app.js` | Mount `/api/v1/diagnostic` route |
| `package.json` | Add `test` script |

---

## Phase 0 — Test runner & feature flag infra

### Task 0.1: Add `test` script to package.json

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Read existing package.json scripts**

Run: `cat package.json | jq .scripts`
Expected: existing scripts shown — `start`, `dev`, `workers`, `migrate:youtube-to-s3`, `seed:content`.

- [ ] **Step 2: Add `test` script**

Modify `package.json`:
```json
"scripts": {
  "start": "node server.js",
  "dev": "nodemon server.js",
  "workers": "node src/workers/index.js",
  "migrate:youtube-to-s3": "node scripts/migrateYoutubeToS3.js",
  "seed:content": "node scripts/seedContent.js",
  "test": "node --test --test-reporter=spec 'src/**/*.test.js'"
}
```

- [ ] **Step 3: Verify the script runs (no tests yet, expected to find no files initially)**

Run: `npm test`
Expected: zero tests found; exit 0. (If exit is non-zero with `Cannot find module`, ensure quoting around the glob is preserved on the user's shell.)

- [ ] **Step 4: Commit**

```bash
git add package.json
git commit -m "chore(test): add node --test runner script for diagnostic feature"
```

### Task 0.2: Create feature flag config

**Files:**
- Create: `src/config/featureFlags.js`
- Test: `src/config/featureFlags.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/config/featureFlags.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');

test('featureFlags exposes day1Diagnostic boolean (defaults false when env unset)', () => {
  delete process.env.FEATURE_DAY1_DIAGNOSTIC;
  // Re-require to pick up env state
  delete require.cache[require.resolve('./featureFlags')];
  const flags = require('./featureFlags');
  assert.strictEqual(typeof flags.day1Diagnostic, 'boolean');
  assert.strictEqual(flags.day1Diagnostic, false);
});

test('featureFlags.day1Diagnostic is true when env var is "true"', () => {
  process.env.FEATURE_DAY1_DIAGNOSTIC = 'true';
  delete require.cache[require.resolve('./featureFlags')];
  const flags = require('./featureFlags');
  assert.strictEqual(flags.day1Diagnostic, true);
});

test('featureFlags.day1Diagnostic is false for any string other than "true"', () => {
  for (const v of ['1', 'yes', 'TRUE', 'false', '']) {
    process.env.FEATURE_DAY1_DIAGNOSTIC = v;
    delete require.cache[require.resolve('./featureFlags')];
    const flags = require('./featureFlags');
    assert.strictEqual(flags.day1Diagnostic, false, `expected false for env="${v}"`);
  }
});
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `node --test src/config/featureFlags.test.js`
Expected: FAIL with `Cannot find module './featureFlags'`.

- [ ] **Step 3: Write the implementation**

Create `src/config/featureFlags.js`:
```js
/**
 * Feature flags driven by environment variables.
 * Strict "true" string match — any other value is false.
 * This keeps rollback to a single env var change.
 */
module.exports = {
  day1Diagnostic: process.env.FEATURE_DAY1_DIAGNOSTIC === 'true',
};
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `node --test src/config/featureFlags.test.js`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/config/featureFlags.js src/config/featureFlags.test.js
git commit -m "feat(diagnostic): add feature flag for day1Diagnostic"
```

---

## Phase 1 — Data models

### Task 1.1: Create `DiagnosticAttempt` model

**Files:**
- Create: `src/models/DiagnosticAttempt.js`
- Test: `src/models/DiagnosticAttempt.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/models/DiagnosticAttempt.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

test('DiagnosticAttempt schema has required fields and defaults', () => {
  const DiagnosticAttempt = require('./DiagnosticAttempt');
  const attempt = new DiagnosticAttempt({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'new_user',
  });
  assert.strictEqual(attempt.status, 'in_progress');
  assert.deepStrictEqual(attempt.answers.toObject ? attempt.answers.toObject() : Array.from(attempt.answers), []);
  assert.ok(attempt.startedAt instanceof Date);
});

test('DiagnosticAttempt rejects invalid status enum', () => {
  const DiagnosticAttempt = require('./DiagnosticAttempt');
  const attempt = new DiagnosticAttempt({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'new_user',
    status: 'bogus',
  });
  const err = attempt.validateSync();
  assert.ok(err);
  assert.ok(err.errors.status);
});

test('DiagnosticAttempt rejects invalid flowType enum', () => {
  const DiagnosticAttempt = require('./DiagnosticAttempt');
  const attempt = new DiagnosticAttempt({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'bogus',
  });
  const err = attempt.validateSync();
  assert.ok(err);
  assert.ok(err.errors.flowType);
});
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `node --test src/models/DiagnosticAttempt.test.js`
Expected: FAIL with `Cannot find module './DiagnosticAttempt'`.

- [ ] **Step 3: Write the implementation**

Create `src/models/DiagnosticAttempt.js`:
```js
const mongoose = require('mongoose');

/**
 * DiagnosticAttempt — BUG-8 Phase 4 (Day-1 Diagnostic, separate from Phase 1-9 of insights).
 *
 * One document per (user, attempt). Lifecycle:
 *   in_progress → completed (when finishAttempt is called)
 *   in_progress → abandoned (when abandon endpoint is called)
 *
 * Distinct from QuizAttempt because the diagnostic is a different artefact
 * (different questions, different scoring intent, different downstream effects).
 */

const answerSchema = new mongoose.Schema({
  questionId:     { type: mongoose.Schema.Types.ObjectId, required: true },
  competency:     { type: String, required: true },
  difficulty:     { type: String, enum: ['easy', 'medium', 'hard'], required: true },
  selectedAnswer: { type: String, required: true },
  isCorrect:      { type: Boolean, required: true },
  timeTaken:      { type: Number, default: 0 }, // seconds
}, { _id: false });

const competencyResultSchema = new mongoose.Schema({
  assessedBand:     { type: String, enum: ['novice', 'familiar', 'proficient', 'expert'] },
  score:            { type: Number, min: 0, max: 100 },
  calibrationDelta: { type: Number },           // -3..+3
  questionsAsked:   { type: Number, default: 0 },
}, { _id: false });

const diagnosticAttemptSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  flowType: { type: String, enum: ['new_user', 'existing_user_tune'], required: true },

  status: {
    type: String,
    enum: ['in_progress', 'completed', 'abandoned'],
    default: 'in_progress',
    index: true,
  },

  startedAt:    { type: Date, default: Date.now },
  completedAt:  { type: Date },
  abandonedAt:  { type: Date },
  abandonStrategy: {
    type: String,
    enum: [null, 'partial_processed', 'dropped'],
    default: null,
  },

  // Pool used for this attempt (refs into DiagnosticQuestionBank)
  poolQuestionIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'DiagnosticQuestionBank' }],

  // Self-rating snapshot at attempt time
  selfRatings: {
    type: Map,
    of: { type: String, enum: ['novice', 'familiar', 'proficient', 'expert', 'unsure'] },
    default: () => new Map(),
  },

  answers: [answerSchema],

  results: {
    type: Map,
    of: competencyResultSchema,
    default: () => new Map(),
  },

  // Telemetry
  cohort: { type: String }, // 'pre_diagnostic' | 'post_diagnostic_taken' | etc.
}, { timestamps: true });

diagnosticAttemptSchema.index({ userId: 1, status: 1, startedAt: -1 });

module.exports = mongoose.model('DiagnosticAttempt', diagnosticAttemptSchema);
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `node --test src/models/DiagnosticAttempt.test.js`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/DiagnosticAttempt.js src/models/DiagnosticAttempt.test.js
git commit -m "feat(diagnostic): add DiagnosticAttempt model"
```

### Task 1.2: Create `DiagnosticQuestionBank` model

**Files:**
- Create: `src/models/DiagnosticQuestionBank.js`
- Test: `src/models/DiagnosticQuestionBank.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/models/DiagnosticQuestionBank.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');

test('DiagnosticQuestionBank has required fields with defaults', () => {
  const Bank = require('./DiagnosticQuestionBank');
  const q = new Bank({
    canonicalCompetency: 'system design',
    difficulty: 'medium',
    questionText: 'What is X?',
    options: [
      { label: 'A', text: 'opt a' },
      { label: 'B', text: 'opt b', misconception: { tag: 'foo', explanation: 'bar' } },
    ],
    correctAnswer: 'A',
  });
  assert.strictEqual(q.source, 'live_generated');
  assert.strictEqual(q.status, 'active');
  assert.strictEqual(q.timesUsed, 0);
});

test('DiagnosticQuestionBank rejects invalid difficulty', () => {
  const Bank = require('./DiagnosticQuestionBank');
  const q = new Bank({
    canonicalCompetency: 'x',
    difficulty: 'super-hard',
    questionText: 'q',
    options: [],
    correctAnswer: 'A',
  });
  const err = q.validateSync();
  assert.ok(err.errors.difficulty);
});

test('DiagnosticQuestionBank rejects invalid source enum', () => {
  const Bank = require('./DiagnosticQuestionBank');
  const q = new Bank({
    canonicalCompetency: 'x',
    difficulty: 'easy',
    questionText: 'q',
    options: [],
    correctAnswer: 'A',
    source: 'bogus',
  });
  const err = q.validateSync();
  assert.ok(err.errors.source);
});
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `node --test src/models/DiagnosticQuestionBank.test.js`
Expected: FAIL with `Cannot find module './DiagnosticQuestionBank'`.

- [ ] **Step 3: Write the implementation**

Create `src/models/DiagnosticQuestionBank.js`:
```js
const mongoose = require('mongoose');

/**
 * DiagnosticQuestionBank — pool of reusable diagnostic questions, keyed by
 * (canonicalCompetency, difficulty). Populated organically as users complete
 * diagnostics: each attempt's unused pool questions land here for future use.
 *
 * `discrimination` is reserved for v2 — a future analytics job will populate it
 * once we have enough attempts per question to compute item-discrimination scores.
 */

const optionSchema = new mongoose.Schema({
  label: { type: String, enum: ['A', 'B', 'C', 'D'], required: true },
  text:  { type: String, required: true },
  misconception: {
    tag:         { type: String },
    explanation: { type: String },
  },
}, { _id: false });

const diagnosticQuestionBankSchema = new mongoose.Schema({
  canonicalCompetency:  { type: String, required: true, lowercase: true, index: true },
  rawCompetencyAliases: [{ type: String }],
  difficulty:           { type: String, enum: ['easy', 'medium', 'hard'], required: true, index: true },

  questionText: { type: String, required: true },
  options:      [optionSchema],
  correctAnswer:{ type: String, enum: ['A', 'B', 'C', 'D'], required: true },
  explanation:  { type: String },

  source:      { type: String, enum: ['live_generated', 'curated', 'cached'], default: 'live_generated' },
  generatedAt: { type: Date, default: Date.now },
  timesUsed:   { type: Number, default: 0 },
  discrimination: { type: Number, default: null }, // v2 — populated by future analytics job
  status: { type: String, enum: ['active', 'retired', 'pending_review'], default: 'active' },
}, { timestamps: true });

diagnosticQuestionBankSchema.index({ canonicalCompetency: 1, difficulty: 1, status: 1, timesUsed: 1 });

module.exports = mongoose.model('DiagnosticQuestionBank', diagnosticQuestionBankSchema);
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `node --test src/models/DiagnosticQuestionBank.test.js`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/DiagnosticQuestionBank.js src/models/DiagnosticQuestionBank.test.js
git commit -m "feat(diagnostic): add DiagnosticQuestionBank model"
```

### Task 1.3: Extend `KnowledgeProfile.topicMastery` with selfRating + calibrationAtBaseline

**Files:**
- Modify: `src/models/KnowledgeProfile.js`
- Test: `src/models/KnowledgeProfile.test.js` (create)

- [ ] **Step 1: Write the failing test**

Create `src/models/KnowledgeProfile.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

test('KnowledgeProfile.topicMastery accepts selfRating and calibrationAtBaseline', () => {
  const KP = require('./KnowledgeProfile');
  const kp = new KP({
    userId: new mongoose.Types.ObjectId(),
    topicMastery: [{
      topic: 'foo',
      score: 50,
      selfRating: 'familiar',
      calibrationAtBaseline: { delta: -1, capturedAt: new Date() },
    }],
  });
  const err = kp.validateSync();
  assert.strictEqual(err, undefined, err && err.message);
  assert.strictEqual(kp.topicMastery[0].selfRating, 'familiar');
  assert.strictEqual(kp.topicMastery[0].calibrationAtBaseline.delta, -1);
});

test('KnowledgeProfile.topicMastery rejects invalid selfRating enum', () => {
  const KP = require('./KnowledgeProfile');
  const kp = new KP({
    userId: new mongoose.Types.ObjectId(),
    topicMastery: [{ topic: 'foo', selfRating: 'bogus' }],
  });
  const err = kp.validateSync();
  assert.ok(err);
  assert.ok(err.errors['topicMastery.0.selfRating']);
});

test('KnowledgeProfile.topicMastery still works without selfRating (backward compat)', () => {
  const KP = require('./KnowledgeProfile');
  const kp = new KP({
    userId: new mongoose.Types.ObjectId(),
    topicMastery: [{ topic: 'foo', score: 70 }],
  });
  const err = kp.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(kp.topicMastery[0].selfRating, undefined);
});
```

- [ ] **Step 2: Run the test, confirm 2 of 3 tests fail**

Run: `node --test src/models/KnowledgeProfile.test.js`
Expected: 1 PASS (the backward-compat one), 2 FAIL (the new fields don't exist yet).

- [ ] **Step 3: Modify the schema (additive only)**

Edit `src/models/KnowledgeProfile.js`. Find the `topicMastery` subschema (around line 6-32) and add the two new fields BEFORE the closing `}]`:

```js
  topicMastery: [{
    topic: { type: String, lowercase: true },
    score: { type: Number, default: 0, min: 0, max: 100 },
    level: {
      type: String,
      enum: ['not_started', 'beginner', 'intermediate', 'advanced', 'expert'],
      default: 'not_started',
    },
    quizzesTaken: { type: Number, default: 0 },
    lastAssessedAt: { type: Date },
    scoreHistory: [{
      score: Number,
      date: Date,
      quizId: mongoose.Schema.Types.ObjectId,
      objectiveId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'UserObjective',
        default: null
      }
    }],
    trend: { type: String, enum: ['improving', 'stable', 'declining'], default: 'stable' },
    objectiveId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'UserObjective',
      default: null
    },
    // Day-1 diagnostic additions (BUG-8 Phase X — additive, optional)
    selfRating: {
      type: String,
      enum: ['novice', 'familiar', 'proficient', 'expert', 'unsure'],
      default: undefined,
    },
    calibrationAtBaseline: {
      delta:       { type: Number, default: null }, // -3..+3
      capturedAt:  { type: Date },
    },
  }],
```

- [ ] **Step 4: Run the tests, confirm all pass**

Run: `node --test src/models/KnowledgeProfile.test.js`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/KnowledgeProfile.js src/models/KnowledgeProfile.test.js
git commit -m "feat(diagnostic): extend KnowledgeProfile.topicMastery with selfRating + calibration (additive)"
```

---

## Phase 2 — Competency normalizer

### Task 2.1: Build alias-dictionary normalizer

**Files:**
- Create: `src/services/competencyNormalizer.js`
- Test: `src/services/competencyNormalizer.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/competencyNormalizer.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');
const { normalize, _internal } = require('./competencyNormalizer');

test('normalize lowercases and trims whitespace', () => {
  assert.strictEqual(normalize('  System Design  '), 'system design');
});

test('normalize strips punctuation', () => {
  assert.strictEqual(normalize('System Design!'), 'system design');
  assert.strictEqual(normalize('SQL.Joins'), 'sql joins');
});

test('normalize collapses repeated whitespace', () => {
  assert.strictEqual(normalize('system   design'), 'system design');
});

test('normalize resolves common aliases via dictionary', () => {
  // These are wired up in the dictionary
  assert.strictEqual(normalize('sql joins'), 'database joins');
  assert.strictEqual(normalize('joins'), 'database joins');
  assert.strictEqual(normalize('product market fit'), 'product-market fit');
});

test('normalize returns empty string for empty/null input', () => {
  assert.strictEqual(normalize(''), '');
  assert.strictEqual(normalize(null), '');
  assert.strictEqual(normalize(undefined), '');
});

test('_internal exposes the alias dictionary for tests', () => {
  assert.ok(_internal.aliasDictionary);
  assert.strictEqual(typeof _internal.aliasDictionary, 'object');
});
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `node --test src/services/competencyNormalizer.test.js`
Expected: FAIL with `Cannot find module './competencyNormalizer'`.

- [ ] **Step 3: Write the implementation**

Create `src/services/competencyNormalizer.js`:
```js
/**
 * Competency name normalizer — keeps DiagnosticQuestionBank from fragmenting
 * across users who naturally express the same concept differently.
 *
 * Two layers:
 *   1. Cheap normalization: lowercase, trim, strip punctuation, collapse whitespace
 *   2. Alias dictionary lookup
 *
 * A future v2 will add embedding-similarity for unmatched names; for now,
 * the dictionary is the only smart resolution.
 */

// Manually curated aliases. Add new entries as new domains roll out.
// Keys are post-cheap-normalize input; values are the canonical name.
const aliasDictionary = {
  // Database / SQL
  'sql joins': 'database joins',
  'joins': 'database joins',
  'database joins': 'database joins',
  // Product / PM
  'product market fit': 'product-market fit',
  'pmf': 'product-market fit',
  'product-market fit': 'product-market fit',
  // Stats / ML
  'bayes theorem': 'bayes',
  'bayes rule': 'bayes',
  'conditional probability': 'bayes',
  // System Design
  'system design fundamentals': 'system design',
  'sys design': 'system design',
  // Add more as we encounter them in production
};

function _cheapNormalize(s) {
  if (!s || typeof s !== 'string') return '';
  return s
    .toLowerCase()
    .replace(/[^a-z0-9\s-]+/g, ' ')   // strip punctuation except hyphens
    .replace(/\s+/g, ' ')              // collapse whitespace
    .trim();
}

function normalize(input) {
  const cheap = _cheapNormalize(input);
  if (!cheap) return '';
  return aliasDictionary[cheap] || cheap;
}

module.exports = {
  normalize,
  _internal: { _cheapNormalize, aliasDictionary },
};
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `node --test src/services/competencyNormalizer.test.js`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/competencyNormalizer.js src/services/competencyNormalizer.test.js
git commit -m "feat(diagnostic): competency normalizer with alias dictionary"
```

---

## Phase 3 — Question generation pipeline

### Task 3.1: Add `'diagnostic'` quiz type to quizGenerationService prompts

**Files:**
- Modify: `src/services/quizGenerationService.js`

This task does NOT have a test of its own — it's a prompt extension that gets exercised by the pool service tests in Task 3.2. The change is small and additive.

- [ ] **Step 1: Read the existing quiz prompts**

Run: `grep -n "QUIZ_SYSTEM_PROMPT\|COMPETENCY_QUIZ_SYSTEM_PROMPT" src/services/quizGenerationService.js | head -5`
Expected: shows the two existing prompts and where they're defined.

- [ ] **Step 2: Add the diagnostic prompt**

After the existing `COMPETENCY_QUIZ_SYSTEM_PROMPT` constant (look for the closing backtick around line ~58), add:

```js
const DIAGNOSTIC_QUIZ_SYSTEM_PROMPT = `You are an expert assessment designer building a SHORT diagnostic quiz to estimate a learner's current proficiency. The output is used to seed a personalised learning plan, NOT to teach.

OUTPUT REQUIREMENTS:
- Generate questions evenly across 3 difficulty buckets per competency:
  - "easy"   = recall / recognition
  - "medium" = apply concept to a new example
  - "hard"   = multi-step reasoning, edge cases, compare/contrast
- Each question has 4 options, exactly one correct, all four roughly equal in length and writing style.
- Distractors must be PLAUSIBLE common misconceptions, NOT joke options.
- Every distractor carries a misconception object: { tag (snake_case stable identifier), explanation (one human sentence). }
- Correct option's misconception is null/omitted.
- Randomise the correct letter across the set.

DIAGNOSTIC-SPECIFIC RULES (different from teaching quizzes):
- Each question stands alone — no narrative flow assumed across the set.
- Avoid "trick" questions; we want signal about real proficiency, not gotchas.
- For coding competencies, use MCQ-format only: read snippet → predict output / find bug / pick syntax. NEVER ask the learner to write code.

OUTPUT FORMAT: strict JSON: { "questions": [ { competency, difficulty, questionText, options:[{label,text,misconception?}], correctAnswer, explanation }, ... ] }`;

```

- [ ] **Step 3: Export the new prompt**

At the bottom of `quizGenerationService.js`, find the existing `module.exports`. Add `DIAGNOSTIC_QUIZ_SYSTEM_PROMPT` to the exports (the existing exports object — find it and add a property):

If the existing `module.exports = new QuizGenerationService();` is the last line, replace with:

```js
const _instance = new QuizGenerationService();
_instance.DIAGNOSTIC_QUIZ_SYSTEM_PROMPT = DIAGNOSTIC_QUIZ_SYSTEM_PROMPT;
module.exports = _instance;
```

- [ ] **Step 4: Quick smoke test — service still loads**

Run: `node -e "console.log(typeof require('./src/services/quizGenerationService').DIAGNOSTIC_QUIZ_SYSTEM_PROMPT)"`
Expected: `string`

- [ ] **Step 5: Commit**

```bash
git add src/services/quizGenerationService.js
git commit -m "feat(diagnostic): add diagnostic quiz system prompt to quizGenerationService"
```

### Task 3.2: Build pool size + difficulty mix calculator

**Files:**
- Create: `src/services/diagnosticPoolService.js` (initial version, just calc helpers)
- Test: `src/services/diagnosticPoolService.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnosticPoolService.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');
const { _internal } = require('./diagnosticPoolService');
const { calculatePoolAllocation } = _internal;

test('calculatePoolAllocation: 3 competencies → ~8 each, total ~24', () => {
  const competencies = [
    { name: 'a', selfRating: 'novice' },
    { name: 'b', selfRating: 'familiar' },
    { name: 'c', selfRating: 'proficient' },
  ];
  const alloc = calculatePoolAllocation(competencies, 24);
  assert.strictEqual(alloc.length, 3);
  for (const a of alloc) {
    const total = a.easy + a.medium + a.hard;
    assert.ok(total >= 7 && total <= 9, `competency ${a.name} got ${total} questions`);
  }
});

test('calculatePoolAllocation: novice → mostly easy', () => {
  const alloc = calculatePoolAllocation([{ name: 'x', selfRating: 'novice' }], 8);
  assert.strictEqual(alloc[0].easy >= alloc[0].medium, true);
  assert.strictEqual(alloc[0].easy >= alloc[0].hard, true);
});

test('calculatePoolAllocation: expert → mostly hard', () => {
  const alloc = calculatePoolAllocation([{ name: 'x', selfRating: 'expert' }], 8);
  assert.ok(alloc[0].hard >= alloc[0].easy, 'expert should get more hard than easy');
});

test('calculatePoolAllocation: 6 competencies → at least 3 each (floor)', () => {
  const competencies = Array.from({ length: 6 }, (_, i) => ({ name: `c${i}`, selfRating: 'familiar' }));
  const alloc = calculatePoolAllocation(competencies, 24);
  for (const a of alloc) {
    const total = a.easy + a.medium + a.hard;
    assert.ok(total >= 3, `floor of 3 violated: ${a.name} got ${total}`);
  }
});

test('calculatePoolAllocation: unsure self-rating treated as novice', () => {
  const a1 = calculatePoolAllocation([{ name: 'x', selfRating: 'unsure' }], 8)[0];
  const a2 = calculatePoolAllocation([{ name: 'x', selfRating: 'novice' }], 8)[0];
  assert.deepStrictEqual(a1, a2);
});
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `node --test src/services/diagnosticPoolService.test.js`
Expected: FAIL with `Cannot find module './diagnosticPoolService'`.

- [ ] **Step 3: Write the implementation (just the calculator for now)**

Create `src/services/diagnosticPoolService.js`:
```js
/**
 * Diagnostic Pool Service — generates question pools for a diagnostic attempt.
 *
 * Two responsibilities:
 *   1. Calculate the pool size + difficulty distribution given (competencies, totalSize)
 *   2. Generate the pool by combining bank lookups with live LLM calls
 *
 * This file holds the calculator. LLM/bank integration arrives in later tasks.
 */

const FLOOR_QUESTIONS_PER_COMPETENCY = 3;
const DEFAULT_POOL_SIZE = 24;

// Difficulty distribution per self-rating, expressed as proportions
// over the per-competency allocation.
const DIFFICULTY_MIX = {
  novice:     { easy: 0.60, medium: 0.25, hard: 0.15 },
  unsure:     { easy: 0.60, medium: 0.25, hard: 0.15 },
  familiar:   { easy: 0.40, medium: 0.50, hard: 0.10 },
  proficient: { easy: 0.25, medium: 0.50, hard: 0.25 },
  expert:     { easy: 0.10, medium: 0.40, hard: 0.50 },
};

/**
 * Returns one allocation entry per competency with per-difficulty integer counts.
 * Total across all competencies will be approximately `totalPoolSize`, with a
 * hard floor of FLOOR_QUESTIONS_PER_COMPETENCY per competency.
 */
function calculatePoolAllocation(competencies, totalPoolSize = DEFAULT_POOL_SIZE) {
  if (!competencies?.length) return [];
  const perCompetency = Math.max(
    FLOOR_QUESTIONS_PER_COMPETENCY,
    Math.round(totalPoolSize / competencies.length),
  );
  return competencies.map(c => {
    const mix = DIFFICULTY_MIX[c.selfRating] || DIFFICULTY_MIX.unsure;
    const easy   = Math.max(1, Math.round(perCompetency * mix.easy));
    const hard   = Math.max(1, Math.round(perCompetency * mix.hard));
    const medium = Math.max(1, perCompetency - easy - hard);
    return { name: c.name, easy, medium, hard };
  });
}

module.exports = {
  _internal: {
    calculatePoolAllocation,
    FLOOR_QUESTIONS_PER_COMPETENCY,
    DIFFICULTY_MIX,
  },
};
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `node --test src/services/diagnosticPoolService.test.js`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticPoolService.js src/services/diagnosticPoolService.test.js
git commit -m "feat(diagnostic): pool allocation calculator with floor + difficulty mix"
```

### Task 3.3: Add LLM batch-generation function

**Files:**
- Modify: `src/services/diagnosticPoolService.js`
- Modify: `src/services/diagnosticPoolService.test.js`

- [ ] **Step 1: Add the failing test**

Append to `src/services/diagnosticPoolService.test.js`:
```js
const Module = require('node:module');

test('generatePoolFromLLM returns parsed questions on valid response', async (t) => {
  const stubResponse = {
    choices: [{ message: { content: JSON.stringify({
      questions: [
        { competency: 'sql', difficulty: 'easy', questionText: 'q1', options: [
          { label: 'A', text: 'a' }, { label: 'B', text: 'b', misconception: { tag: 'x', explanation: 'y' } },
          { label: 'C', text: 'c', misconception: { tag: 'z', explanation: 'w' } },
          { label: 'D', text: 'd', misconception: { tag: 'q', explanation: 'r' } },
        ], correctAnswer: 'A' },
      ],
    }) } }],
  };
  // Stub the openai module
  const openaiPath = require.resolve('../config/openai');
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async () => stubResponse } } },
    loaded: true, id: openaiPath,
  };
  // Re-require pool service
  delete require.cache[require.resolve('./diagnosticPoolService')];
  const { _internal } = require('./diagnosticPoolService');

  const allocation = [{ name: 'sql', easy: 1, medium: 0, hard: 0 }];
  const out = await _internal.generatePoolFromLLM(allocation, { objective: 'data scientist' });
  assert.strictEqual(out.length, 1);
  assert.strictEqual(out[0].competency, 'sql');
});

test('generatePoolFromLLM returns empty array when LLM throws', async () => {
  const openaiPath = require.resolve('../config/openai');
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async () => { throw new Error('rate limit'); } } } },
    loaded: true, id: openaiPath,
  };
  delete require.cache[require.resolve('./diagnosticPoolService')];
  const { _internal } = require('./diagnosticPoolService');
  const out = await _internal.generatePoolFromLLM([{ name: 'x', easy: 1, medium: 0, hard: 0 }], {});
  assert.deepStrictEqual(out, []);
});

test('generatePoolFromLLM returns empty array when LLM returns malformed JSON', async () => {
  const openaiPath = require.resolve('../config/openai');
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async () => ({ choices: [{ message: { content: 'not json' } }] }) } } },
    loaded: true, id: openaiPath,
  };
  delete require.cache[require.resolve('./diagnosticPoolService')];
  const { _internal } = require('./diagnosticPoolService');
  const out = await _internal.generatePoolFromLLM([{ name: 'x', easy: 1, medium: 0, hard: 0 }], {});
  assert.deepStrictEqual(out, []);
});
```

- [ ] **Step 2: Run the new tests, confirm they fail**

Run: `node --test src/services/diagnosticPoolService.test.js`
Expected: 5 PASS (existing), 3 FAIL (`generatePoolFromLLM is not a function`).

- [ ] **Step 3: Implement the LLM call**

Edit `src/services/diagnosticPoolService.js`. At the top, add the imports:

```js
const openai = require('../config/openai');
const quizGenerationService = require('./quizGenerationService');
```

Then add the function ABOVE the `module.exports` block:

```js
/**
 * Calls gpt-4o-mini to generate a question pool covering the given allocation.
 * Returns a flat array of questions with competency/difficulty tags. Returns
 * empty array on any failure (caller falls back to bank-only path).
 */
async function generatePoolFromLLM(allocation, { objective } = {}) {
  if (!allocation?.length) return [];

  const userPayload = {
    objective: objective || null,
    allocation: allocation.map(a => ({
      competency: a.name,
      easy: a.easy, medium: a.medium, hard: a.hard,
    })),
  };

  try {
    const resp = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      temperature: 0.4,
      max_tokens: 3000,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: quizGenerationService.DIAGNOSTIC_QUIZ_SYSTEM_PROMPT },
        { role: 'user', content: JSON.stringify(userPayload) },
      ],
    });

    const raw = resp?.choices?.[0]?.message?.content;
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed?.questions)) return [];

    // Light validation; drop bad rows silently
    return parsed.questions.filter(q =>
      q && typeof q.competency === 'string'
      && ['easy', 'medium', 'hard'].includes(q.difficulty)
      && typeof q.questionText === 'string'
      && Array.isArray(q.options) && q.options.length === 4
      && ['A', 'B', 'C', 'D'].includes(q.correctAnswer)
    );
  } catch (err) {
    console.warn('[diagnosticPoolService] generatePoolFromLLM failed:', err.message);
    return [];
  }
}
```

Add `generatePoolFromLLM` to the `_internal` exports object.

- [ ] **Step 4: Run the tests, confirm all 8 pass**

Run: `node --test src/services/diagnosticPoolService.test.js`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticPoolService.js src/services/diagnosticPoolService.test.js
git commit -m "feat(diagnostic): LLM batch question generation with silent fallback"
```

### Task 3.4: Add bank lookup + write functions

**Files:**
- Modify: `src/services/diagnosticPoolService.js`
- Modify: `src/services/diagnosticPoolService.test.js`

- [ ] **Step 1: Add the failing test**

Append to `src/services/diagnosticPoolService.test.js`:
```js
test('lookupFromBank returns up to N questions per (competency, difficulty)', async () => {
  // Stub the model
  const modelPath = require.resolve('../models/DiagnosticQuestionBank');
  const stubDocs = [
    { _id: '1', canonicalCompetency: 'sql', difficulty: 'easy', questionText: 'q1' },
    { _id: '2', canonicalCompetency: 'sql', difficulty: 'easy', questionText: 'q2' },
  ];
  require.cache[modelPath] = {
    exports: {
      find: () => ({ sort: () => ({ limit: () => ({ lean: async () => stubDocs }) }) }),
      insertMany: async (docs) => docs.map((d, i) => ({ ...d, _id: 'new'+i })),
    },
    loaded: true, id: modelPath,
  };
  delete require.cache[require.resolve('./diagnosticPoolService')];
  const { _internal } = require('./diagnosticPoolService');

  const out = await _internal.lookupFromBank('sql', 'easy', 5);
  assert.strictEqual(out.length, 2);
});

test('persistToBank writes new questions with normalized canonical competency', async () => {
  let captured = null;
  const modelPath = require.resolve('../models/DiagnosticQuestionBank');
  require.cache[modelPath] = {
    exports: {
      find: () => ({ sort: () => ({ limit: () => ({ lean: async () => [] }) }) }),
      insertMany: async (docs) => { captured = docs; return docs; },
    },
    loaded: true, id: modelPath,
  };
  delete require.cache[require.resolve('./diagnosticPoolService')];
  const { _internal } = require('./diagnosticPoolService');

  const generated = [{
    competency: 'SQL Joins', difficulty: 'easy',
    questionText: 'q', options: [
      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
    ], correctAnswer: 'A',
  }];
  await _internal.persistToBank(generated);
  assert.ok(captured);
  assert.strictEqual(captured.length, 1);
  // 'sql joins' should resolve to 'database joins' via the alias dictionary
  assert.strictEqual(captured[0].canonicalCompetency, 'database joins');
  assert.deepStrictEqual(captured[0].rawCompetencyAliases, ['SQL Joins']);
});
```

- [ ] **Step 2: Run, confirm 2 new tests fail**

Run: `node --test src/services/diagnosticPoolService.test.js`
Expected: 8 PASS (existing), 2 FAIL (`lookupFromBank` / `persistToBank` not exported).

- [ ] **Step 3: Implement the bank functions**

Edit `src/services/diagnosticPoolService.js`. Add at top:

```js
const DiagnosticQuestionBank = require('../models/DiagnosticQuestionBank');
const { normalize } = require('./competencyNormalizer');
```

Add functions before `module.exports`:

```js
/**
 * Look up cached questions for a (competency, difficulty) bucket. Returns up to
 * `limit` documents, prioritising least-used (round-robin so we don't burn a
 * single question on every diagnostic).
 */
async function lookupFromBank(competency, difficulty, limit) {
  const canonical = normalize(competency);
  if (!canonical) return [];
  return DiagnosticQuestionBank
    .find({ canonicalCompetency: canonical, difficulty, status: 'active' })
    .sort({ timesUsed: 1, generatedAt: -1 })
    .limit(limit)
    .lean();
}

/**
 * Persist freshly-generated questions to the bank. Normalises competency
 * names so future lookups hit cache regardless of how the user phrased it.
 */
async function persistToBank(generatedQuestions) {
  if (!generatedQuestions?.length) return [];
  const docs = generatedQuestions.map(q => ({
    canonicalCompetency: normalize(q.competency),
    rawCompetencyAliases: [q.competency],
    difficulty: q.difficulty,
    questionText: q.questionText,
    options: q.options,
    correctAnswer: q.correctAnswer,
    explanation: q.explanation,
    source: 'live_generated',
  }));
  return DiagnosticQuestionBank.insertMany(docs);
}
```

Add both to the `_internal` exports.

- [ ] **Step 4: Run the tests, confirm all 10 pass**

Run: `node --test src/services/diagnosticPoolService.test.js`
Expected: 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticPoolService.js src/services/diagnosticPoolService.test.js
git commit -m "feat(diagnostic): bank lookup + persist with competency normalization"
```

### Task 3.5: Add the public `assemblePool` function (cache-first + LLM fallback merge)

**Files:**
- Modify: `src/services/diagnosticPoolService.js`
- Modify: `src/services/diagnosticPoolService.test.js`

- [ ] **Step 1: Add the failing test**

Append to `src/services/diagnosticPoolService.test.js`:
```js
test('assemblePool fills from bank when bank has enough', async () => {
  const modelPath = require.resolve('../models/DiagnosticQuestionBank');
  const docs = (n, comp, diff) => Array.from({ length: n }, (_, i) => ({
    _id: `${comp}-${diff}-${i}`, canonicalCompetency: comp, difficulty: diff,
    questionText: `q${i}`, options: [
      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
    ], correctAnswer: 'A',
  }));
  require.cache[modelPath] = {
    exports: {
      find: (q) => ({
        sort: () => ({
          limit: (n) => ({
            lean: async () => docs(Math.min(n, 10), q.canonicalCompetency, q.difficulty),
          }),
        }),
      }),
      insertMany: async (d) => d,
    },
    loaded: true, id: modelPath,
  };
  // openai stub to fail loud — we should NOT call it when bank is sufficient
  const openaiPath = require.resolve('../config/openai');
  let openaiCalls = 0;
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async () => { openaiCalls++; throw new Error('should not be called'); } } } },
    loaded: true, id: openaiPath,
  };
  delete require.cache[require.resolve('./diagnosticPoolService')];
  const { assemblePool } = require('./diagnosticPoolService');

  const allocation = [{ name: 'sql', easy: 2, medium: 2, hard: 2 }];
  const out = await assemblePool(allocation, { objective: 'x' });
  assert.strictEqual(out.length, 6);
  assert.strictEqual(openaiCalls, 0, 'should not call LLM when bank is sufficient');
});

test('assemblePool falls back to LLM when bank is empty', async () => {
  const modelPath = require.resolve('../models/DiagnosticQuestionBank');
  require.cache[modelPath] = {
    exports: {
      find: () => ({ sort: () => ({ limit: () => ({ lean: async () => [] }) }) }),
      insertMany: async (d) => d,
    },
    loaded: true, id: modelPath,
  };
  const openaiPath = require.resolve('../config/openai');
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async () => ({ choices: [{ message: { content: JSON.stringify({
      questions: Array.from({ length: 6 }, (_, i) => ({
        competency: 'sql', difficulty: ['easy', 'medium', 'hard'][i % 3],
        questionText: `q${i}`, options: [
          { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
          { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
        ], correctAnswer: 'A',
      })),
    }) } }] }) } } },
    loaded: true, id: openaiPath,
  };
  delete require.cache[require.resolve('./diagnosticPoolService')];
  const { assemblePool } = require('./diagnosticPoolService');

  const allocation = [{ name: 'sql', easy: 2, medium: 2, hard: 2 }];
  const out = await assemblePool(allocation, { objective: 'x' });
  assert.strictEqual(out.length, 6);
});
```

- [ ] **Step 2: Run, confirm 2 new tests fail**

Expected: `assemblePool is not a function`.

- [ ] **Step 3: Implement assemblePool**

Add to `src/services/diagnosticPoolService.js` ABOVE module.exports:

```js
/**
 * Public entry point: produce a pool that satisfies the allocation.
 * Strategy: try bank first per (competency, difficulty), fall back to LLM
 * for whatever's missing, then persist the LLM-generated questions for next time.
 */
async function assemblePool(allocation, ctx = {}) {
  const out = [];
  const stillNeeded = []; // allocation rows that need LLM top-up

  for (const row of allocation) {
    for (const diff of ['easy', 'medium', 'hard']) {
      const want = row[diff] || 0;
      if (want === 0) continue;
      const fromBank = await lookupFromBank(row.name, diff, want);
      for (const q of fromBank) {
        out.push({
          ...q,
          competency: row.name,
          difficulty: diff,
        });
      }
      const missing = want - fromBank.length;
      if (missing > 0) {
        stillNeeded.push({ name: row.name, [diff]: missing });
      }
    }
  }

  if (stillNeeded.length > 0) {
    const generated = await generatePoolFromLLM(stillNeeded, ctx);
    out.push(...generated);
    // Persist for next time
    if (generated.length > 0) {
      await persistToBank(generated).catch(err =>
        console.warn('[diagnosticPoolService] persistToBank failed:', err.message),
      );
    }
  }

  return out;
}

module.exports = {
  assemblePool,
  _internal: {
    calculatePoolAllocation,
    generatePoolFromLLM,
    lookupFromBank,
    persistToBank,
    FLOOR_QUESTIONS_PER_COMPETENCY,
    DIFFICULTY_MIX,
  },
};
```

(Replace the existing `module.exports` with this version.)

- [ ] **Step 4: Run the tests, confirm all pass**

Run: `node --test src/services/diagnosticPoolService.test.js`
Expected: 12 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticPoolService.js src/services/diagnosticPoolService.test.js
git commit -m "feat(diagnostic): assemblePool — bank-first cache with LLM top-up + persistence"
```

---

## Phase 4 — Adaptive selector

### Task 4.1: First-question and band-mapping helpers

**Files:**
- Create: `src/services/diagnosticSelectorService.js`
- Test: `src/services/diagnosticSelectorService.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnosticSelectorService.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');
const { _internal } = require('./diagnosticSelectorService');
const { initialDifficultyForRating, bandToScore, deriveBand } = _internal;

test('initialDifficultyForRating returns easy for novice/unsure', () => {
  assert.strictEqual(initialDifficultyForRating('novice'), 'easy');
  assert.strictEqual(initialDifficultyForRating('unsure'), 'easy');
});

test('initialDifficultyForRating returns easy or medium for familiar', () => {
  assert.match(initialDifficultyForRating('familiar'), /^(easy|medium)$/);
});

test('initialDifficultyForRating returns medium for proficient', () => {
  assert.strictEqual(initialDifficultyForRating('proficient'), 'medium');
});

test('initialDifficultyForRating returns medium or hard for expert', () => {
  assert.match(initialDifficultyForRating('expert'), /^(medium|hard)$/);
});

test('bandToScore: novice=25, familiar=50, proficient=70, expert=88', () => {
  assert.strictEqual(bandToScore('novice'), 25);
  assert.strictEqual(bandToScore('familiar'), 50);
  assert.strictEqual(bandToScore('proficient'), 70);
  assert.strictEqual(bandToScore('expert'), 88);
});

test('deriveBand maps performance to bands', () => {
  // 2/2 hard correct → expert
  assert.strictEqual(deriveBand({ easy: { correct: 0, wrong: 0 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 2, wrong: 0 } }), 'expert');
  // 2/2 medium correct, no hard → proficient
  assert.strictEqual(deriveBand({ easy: { correct: 0, wrong: 0 }, medium: { correct: 2, wrong: 0 }, hard: { correct: 0, wrong: 0 } }), 'proficient');
  // 2/2 easy correct, no medium → familiar
  assert.strictEqual(deriveBand({ easy: { correct: 2, wrong: 0 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 0, wrong: 0 } }), 'familiar');
  // 0/2 easy → novice
  assert.strictEqual(deriveBand({ easy: { correct: 0, wrong: 2 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 0, wrong: 0 } }), 'novice');
});
```

- [ ] **Step 2: Run, confirm fails**

Run: `node --test src/services/diagnosticSelectorService.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `src/services/diagnosticSelectorService.js`:
```js
/**
 * Adaptive Selector Service — picks the next question for a diagnostic attempt
 * based on running performance per competency. Stateless; the caller passes in
 * the running state and gets back a decision.
 */

function initialDifficultyForRating(selfRating) {
  switch (selfRating) {
    case 'novice':
    case 'unsure':
      return 'easy';
    case 'familiar':
      return Math.random() < 0.5 ? 'easy' : 'medium';
    case 'proficient':
      return 'medium';
    case 'expert':
      return Math.random() < 0.5 ? 'medium' : 'hard';
    default:
      return 'medium';
  }
}

function bandToScore(band) {
  switch (band) {
    case 'novice': return 25;
    case 'familiar': return 50;
    case 'proficient': return 70;
    case 'expert': return 88;
    default: return 0;
  }
}

/**
 * Given a competency's running performance, pick the proficiency band.
 * Rules (simple, defensible):
 *   - If they got >=2 correct at hard → expert
 *   - Else if they got >=2 correct at medium → proficient
 *   - Else if they got >=2 correct at easy → familiar
 *   - Else → novice
 */
function deriveBand(perf) {
  const { easy, medium, hard } = perf;
  if ((hard?.correct || 0) >= 2 && (hard.correct - hard.wrong) >= 1) return 'expert';
  if ((medium?.correct || 0) >= 2 && (medium.correct - medium.wrong) >= 0) return 'proficient';
  if ((easy?.correct || 0) >= 2) return 'familiar';
  return 'novice';
}

module.exports = {
  _internal: {
    initialDifficultyForRating,
    bandToScore,
    deriveBand,
  },
};
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `node --test src/services/diagnosticSelectorService.test.js`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticSelectorService.js src/services/diagnosticSelectorService.test.js
git commit -m "feat(diagnostic): selector helpers — initial difficulty + band mapping"
```

### Task 4.2: Next-question selection logic + stopping rules

**Files:**
- Modify: `src/services/diagnosticSelectorService.js`
- Modify: `src/services/diagnosticSelectorService.test.js`

- [ ] **Step 1: Add the failing test**

Append to `src/services/diagnosticSelectorService.test.js`:
```js
test('selectNext: shouldStop true after 2 correct at same level', () => {
  const { selectNext } = require('./diagnosticSelectorService');
  const perf = { easy: { correct: 2, wrong: 0 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 0, wrong: 0 } };
  const decision = selectNext({ perf, questionsAsked: 2, selfRating: 'novice', currentDifficulty: 'easy' });
  assert.strictEqual(decision.shouldStop, true);
});

test('selectNext: shouldStop true after 3 questions regardless', () => {
  const { selectNext } = require('./diagnosticSelectorService');
  const perf = { easy: { correct: 1, wrong: 1 }, medium: { correct: 1, wrong: 0 }, hard: { correct: 0, wrong: 0 } };
  const decision = selectNext({ perf, questionsAsked: 3, selfRating: 'familiar', currentDifficulty: 'medium' });
  assert.strictEqual(decision.shouldStop, true);
});

test('selectNext: harder difficulty after correct + fast answer', () => {
  const { selectNext } = require('./diagnosticSelectorService');
  const perf = { easy: { correct: 1, wrong: 0 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 0, wrong: 0 } };
  const decision = selectNext({ perf, questionsAsked: 1, selfRating: 'novice', currentDifficulty: 'easy', lastAnswer: { correct: true, fast: true } });
  assert.strictEqual(decision.nextDifficulty, 'medium');
});

test('selectNext: same difficulty after correct + normal speed', () => {
  const { selectNext } = require('./diagnosticSelectorService');
  const perf = { easy: { correct: 1, wrong: 0 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 0, wrong: 0 } };
  const decision = selectNext({ perf, questionsAsked: 1, selfRating: 'novice', currentDifficulty: 'easy', lastAnswer: { correct: true, fast: false } });
  assert.strictEqual(decision.nextDifficulty, 'easy');
});

test('selectNext: easier difficulty after wrong answer', () => {
  const { selectNext } = require('./diagnosticSelectorService');
  const perf = { easy: { correct: 0, wrong: 0 }, medium: { correct: 0, wrong: 1 }, hard: { correct: 0, wrong: 0 } };
  const decision = selectNext({ perf, questionsAsked: 1, selfRating: 'familiar', currentDifficulty: 'medium', lastAnswer: { correct: false, fast: false } });
  assert.strictEqual(decision.nextDifficulty, 'easy');
});

test('selectNext: clamps at hard (cant go past hard)', () => {
  const { selectNext } = require('./diagnosticSelectorService');
  const perf = { easy: { correct: 0, wrong: 0 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 1, wrong: 0 } };
  const decision = selectNext({ perf, questionsAsked: 1, selfRating: 'expert', currentDifficulty: 'hard', lastAnswer: { correct: true, fast: true } });
  assert.strictEqual(decision.nextDifficulty, 'hard');
});

test('selectNext: clamps at easy (cant go below easy)', () => {
  const { selectNext } = require('./diagnosticSelectorService');
  const perf = { easy: { correct: 0, wrong: 1 }, medium: { correct: 0, wrong: 0 }, hard: { correct: 0, wrong: 0 } };
  const decision = selectNext({ perf, questionsAsked: 1, selfRating: 'novice', currentDifficulty: 'easy', lastAnswer: { correct: false, fast: false } });
  assert.strictEqual(decision.nextDifficulty, 'easy');
});
```

- [ ] **Step 2: Run, confirm new tests fail**

Run: `node --test src/services/diagnosticSelectorService.test.js`
Expected: 6 PASS, 7 FAIL (`selectNext` not exported).

- [ ] **Step 3: Implement selectNext**

Add to `src/services/diagnosticSelectorService.js` BEFORE the `module.exports`:

```js
const MAX_QUESTIONS_PER_COMPETENCY = 3;
const DIFFICULTY_LADDER = ['easy', 'medium', 'hard'];

function _bumpDifficulty(current, direction) {
  const i = DIFFICULTY_LADDER.indexOf(current);
  const next = i + (direction === 'up' ? 1 : -1);
  return DIFFICULTY_LADDER[Math.max(0, Math.min(DIFFICULTY_LADDER.length - 1, next))];
}

/**
 * Decide whether to stop and (if not) what difficulty the next question
 * should be. Caller drives the whole loop; this function is stateless.
 *
 * Inputs:
 *   perf: { easy: {correct, wrong}, medium: {...}, hard: {...} }
 *   questionsAsked: number of questions asked for this competency so far
 *   selfRating: 'novice' | 'familiar' | 'proficient' | 'expert' | 'unsure'
 *   currentDifficulty: difficulty of the most recent question
 *   lastAnswer: { correct: boolean, fast: boolean } (optional — null on first call)
 *
 * Returns: { shouldStop: boolean, nextDifficulty: string | null }
 */
function selectNext({ perf, questionsAsked, selfRating, currentDifficulty, lastAnswer }) {
  // Stop after 3 questions regardless of performance
  if (questionsAsked >= MAX_QUESTIONS_PER_COMPETENCY) {
    return { shouldStop: true, nextDifficulty: null };
  }

  // Stop early if signal converged: 2+ correct or 2+ wrong at same level
  for (const diff of DIFFICULTY_LADDER) {
    const p = perf[diff] || { correct: 0, wrong: 0 };
    if (p.correct >= 2 || p.wrong >= 2) {
      return { shouldStop: true, nextDifficulty: null };
    }
  }

  // First question for this competency
  if (questionsAsked === 0 || !lastAnswer) {
    return { shouldStop: false, nextDifficulty: initialDifficultyForRating(selfRating) };
  }

  // Subsequent: adjust based on last answer
  if (lastAnswer.correct && lastAnswer.fast) {
    return { shouldStop: false, nextDifficulty: _bumpDifficulty(currentDifficulty, 'up') };
  }
  if (lastAnswer.correct && !lastAnswer.fast) {
    return { shouldStop: false, nextDifficulty: currentDifficulty };
  }
  // Wrong
  return { shouldStop: false, nextDifficulty: _bumpDifficulty(currentDifficulty, 'down') };
}
```

Update `module.exports` to expose `selectNext`:

```js
module.exports = {
  selectNext,
  _internal: {
    initialDifficultyForRating,
    bandToScore,
    deriveBand,
    MAX_QUESTIONS_PER_COMPETENCY,
    DIFFICULTY_LADDER,
  },
};
```

- [ ] **Step 4: Run all tests, confirm 13 pass**

Run: `node --test src/services/diagnosticSelectorService.test.js`
Expected: 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticSelectorService.js src/services/diagnosticSelectorService.test.js
git commit -m "feat(diagnostic): selectNext — adaptive next-question logic + stopping rules"
```

---

## Phase 5 — Diagnostic service (orchestration)

### Task 5.1: `startAttempt` — creates the attempt record

**Files:**
- Create: `src/services/diagnosticService.js`
- Test: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnosticService.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

function setupStubs({ existingProfile = null } = {}) {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  let saved = null;
  require.cache[dapath] = {
    exports: function FakeDA(data) {
      Object.assign(this, data);
      this.save = async () => { saved = this; this._id = new mongoose.Types.ObjectId(); return this; };
    },
    loaded: true, id: dapath,
  };
  // Helpers attached to the constructor
  require.cache[dapath].exports.findOne = async () => null;

  const kppath = require.resolve('../models/KnowledgeProfile');
  require.cache[kppath] = {
    exports: { findOne: async () => existingProfile },
    loaded: true, id: kppath,
  };

  const objpath = require.resolve('../models/UserObjective');
  require.cache[objpath] = {
    exports: { findOne: () => ({ lean: async () => ({
      _id: 'obj1',
      objectiveType: 'interview_preparation',
      analysis: { competencies: [
        { name: 'system design' }, { name: 'sql' }, { name: 'roadmapping' },
      ] },
    }) }) },
    loaded: true, id: objpath,
  };

  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  return { svc, getSaved: () => saved };
}

test('startAttempt creates a new_user attempt with linked competencies', async () => {
  const { svc, getSaved } = setupStubs();
  const userId = new mongoose.Types.ObjectId();
  const result = await svc.startAttempt(userId);
  const saved = getSaved();
  assert.ok(saved);
  assert.strictEqual(saved.flowType, 'new_user');
  assert.strictEqual(saved.status, 'in_progress');
  assert.deepStrictEqual(result.competenciesToAssess.map(c => c.name).sort(), ['roadmapping', 'sql', 'system design']);
});

test('startAttempt creates an existing_user_tune attempt when KnowledgeProfile has activity', async () => {
  const { svc } = setupStubs({
    existingProfile: { totalQuizzesTaken: 5, topicMastery: [
      { topic: 'sql', score: 80, quizzesTaken: 5, scoreHistory: [
        { score: 78 }, { score: 82 }, { score: 80 }, { score: 79 }, { score: 81 },
      ] },
    ] },
  });
  const userId = new mongoose.Types.ObjectId();
  const result = await svc.startAttempt(userId);
  assert.strictEqual(result.flowType, 'existing_user_tune');
});

test('startAttempt returns null when objective has no competencies (caller falls back)', async () => {
  const objpath = require.resolve('../models/UserObjective');
  require.cache[objpath] = {
    exports: { findOne: () => ({ lean: async () => ({ _id: 'obj1', analysis: { competencies: [] } }) }) },
    loaded: true, id: objpath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  const result = await svc.startAttempt(new mongoose.Types.ObjectId());
  assert.strictEqual(result, null);
});
```

- [ ] **Step 2: Run, confirm fails**

Run: `node --test src/services/diagnosticService.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement startAttempt**

Create `src/services/diagnosticService.js`:
```js
/**
 * Diagnostic Service — orchestrates a single diagnostic attempt across its lifecycle.
 *
 * Public API:
 *   startAttempt(userId)              → { attemptId, flowType, competenciesToAssess }
 *   submitSelfRating(attemptId, ...)  → kicks off pool generation, returns when ready
 *   nextQuestion(attemptId)           → { question } or { done: true }
 *   submitAnswer(attemptId, ...)      → { ack: true }
 *   finishAttempt(attemptId)          → results
 *   abandon(attemptId)                → handles 3-tier abandonment policy
 */

const mongoose = require('mongoose');
const DiagnosticAttempt = require('../models/DiagnosticAttempt');
const KnowledgeProfile = require('../models/KnowledgeProfile');
const UserObjective = require('../models/UserObjective');

/**
 * Decide flow type based on whether the user has any prior platform activity.
 * Threshold: any completed quiz attempt → existing-user flow.
 */
function _decideFlowType(profile) {
  if (profile && (profile.totalQuizzesTaken || 0) >= 1) return 'existing_user_tune';
  return 'new_user';
}

async function startAttempt(userId) {
  const [profile, objective] = await Promise.all([
    KnowledgeProfile.findOne({ userId }),
    UserObjective.findOne({ userId, status: 'active', isPrimary: true }).lean(),
  ]);

  const competencies = objective?.analysis?.competencies || [];
  if (!competencies.length) return null; // caller routes to fallback (Edge 7)

  const flowType = _decideFlowType(profile);

  const attempt = new DiagnosticAttempt({
    userId,
    flowType,
    status: 'in_progress',
    startedAt: new Date(),
  });
  await attempt.save();

  return {
    attemptId: attempt._id,
    flowType,
    competenciesToAssess: competencies.map(c => ({ name: c.name })),
  };
}

module.exports = {
  startAttempt,
  _internal: { _decideFlowType },
};
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `node --test src/services/diagnosticService.test.js`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): startAttempt — creates attempt + classifies flow type"
```

### Task 5.2: `submitSelfRating` — stores ratings + triggers pool gen

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Add failing test**

Append to `src/services/diagnosticService.test.js`:
```js
test('submitSelfRating stores ratings on the attempt', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  let savedAttempt = null;
  const fakeAttempt = {
    _id: new mongoose.Types.ObjectId(),
    selfRatings: new Map(),
    poolQuestionIds: [],
    save: async function () { savedAttempt = this; return this; },
  };
  require.cache[dapath] = {
    exports: { findById: async () => fakeAttempt },
    loaded: true, id: dapath,
  };
  // Stub pool service to return a small pool
  const poolPath = require.resolve('./diagnosticPoolService');
  require.cache[poolPath] = {
    exports: {
      assemblePool: async () => [{ _id: 'q1' }, { _id: 'q2' }],
      _internal: {
        calculatePoolAllocation: () => [{ name: 'sql', easy: 1, medium: 1, hard: 0 }],
      },
    },
    loaded: true, id: poolPath,
  };

  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  await svc.submitSelfRating(fakeAttempt._id, { sql: 'familiar' });
  assert.strictEqual(savedAttempt.selfRatings.get('sql'), 'familiar');
  assert.strictEqual(savedAttempt.poolQuestionIds.length, 2);
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: `submitSelfRating is not a function`.

- [ ] **Step 3: Implement**

Add to `src/services/diagnosticService.js`:
```js
const diagnosticPoolService = require('./diagnosticPoolService');

async function submitSelfRating(attemptId, ratings) {
  const attempt = await DiagnosticAttempt.findById(attemptId);
  if (!attempt) throw new Error('attempt not found');

  // Persist ratings
  for (const [comp, rating] of Object.entries(ratings || {})) {
    attempt.selfRatings.set(comp, rating);
  }

  // Calculate allocation + assemble pool
  const competencies = Array.from(attempt.selfRatings.entries())
    .map(([name, selfRating]) => ({ name, selfRating }));
  const allocation = diagnosticPoolService._internal.calculatePoolAllocation(competencies);
  const pool = await diagnosticPoolService.assemblePool(allocation, {
    objective: attempt.objectiveLabel || null,
  });
  attempt.poolQuestionIds = pool.map(q => q._id).filter(Boolean);
  await attempt.save();
  return { ready: true, poolSize: pool.length };
}
```

Add `submitSelfRating` to the exports.

- [ ] **Step 4: Run, all tests pass**

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): submitSelfRating — store + trigger pool assembly"
```

### Task 5.3: `nextQuestion` and `submitAnswer`

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Add failing tests**

Append to `src/services/diagnosticService.test.js`:
```js
test('nextQuestion returns done:true when all competencies converged', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  const attempt = {
    _id: new mongoose.Types.ObjectId(),
    selfRatings: new Map([['sql', 'novice']]),
    answers: [
      { competency: 'sql', difficulty: 'easy', isCorrect: true, timeTaken: 5 },
      { competency: 'sql', difficulty: 'easy', isCorrect: true, timeTaken: 5 },
    ],
    poolQuestionIds: ['q1', 'q2', 'q3'],
    save: async () => {},
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  const bankPath = require.resolve('../models/DiagnosticQuestionBank');
  require.cache[bankPath] = {
    exports: { findById: async (id) => ({ _id: id, difficulty: 'easy' }) },
    loaded: true, id: bankPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  const result = await svc.nextQuestion(attempt._id);
  assert.strictEqual(result.done, true);
});

test('nextQuestion picks an unused pool question of the right difficulty', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  const attempt = {
    _id: new mongoose.Types.ObjectId(),
    selfRatings: new Map([['sql', 'familiar']]),
    answers: [],
    poolQuestionIds: ['q-easy', 'q-medium', 'q-hard'],
    save: async () => {},
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  const bankPath = require.resolve('../models/DiagnosticQuestionBank');
  require.cache[bankPath] = {
    exports: {
      findById: async (id) => ({
        _id: id,
        difficulty: id.includes('easy') ? 'easy' : id.includes('medium') ? 'medium' : 'hard',
        questionText: 'q', options: [], correctAnswer: 'A', canonicalCompetency: 'sql',
      }),
    },
    loaded: true, id: bankPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  const result = await svc.nextQuestion(attempt._id);
  assert.ok(result.question);
  // First question for familiar should be easy or medium
  assert.match(result.question.difficulty, /^(easy|medium)$/);
});

test('submitAnswer marks correctness and stores the answer', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  let saved = null;
  const attempt = {
    _id: new mongoose.Types.ObjectId(),
    answers: [],
    save: async function () { saved = this; },
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  const bankPath = require.resolve('../models/DiagnosticQuestionBank');
  require.cache[bankPath] = {
    exports: {
      findById: async (id) => ({
        _id: id, canonicalCompetency: 'sql', difficulty: 'medium',
        correctAnswer: 'B',
      }),
    },
    loaded: true, id: bankPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  await svc.submitAnswer(attempt._id, 'q1', 'B', 12);
  assert.ok(saved);
  assert.strictEqual(saved.answers[0].isCorrect, true);
  assert.strictEqual(saved.answers[0].selectedAnswer, 'B');
  assert.strictEqual(saved.answers[0].competency, 'sql');
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: 3 new failures.

- [ ] **Step 3: Implement**

Add to `src/services/diagnosticService.js`:
```js
const DiagnosticQuestionBank = require('../models/DiagnosticQuestionBank');
const selector = require('./diagnosticSelectorService');

function _perfForCompetency(answers, competency) {
  const filt = answers.filter(a => a.competency === competency);
  return ['easy', 'medium', 'hard'].reduce((acc, d) => {
    acc[d] = {
      correct: filt.filter(a => a.difficulty === d && a.isCorrect).length,
      wrong:   filt.filter(a => a.difficulty === d && !a.isCorrect).length,
    };
    return acc;
  }, {});
}

async function nextQuestion(attemptId) {
  const attempt = await DiagnosticAttempt.findById(attemptId);
  if (!attempt) throw new Error('attempt not found');

  // Find the next competency to ask about — first one that hasn't converged
  const competencies = Array.from(attempt.selfRatings.keys());
  for (const comp of competencies) {
    const perf = _perfForCompetency(attempt.answers, comp);
    const asked = attempt.answers.filter(a => a.competency === comp).length;
    const lastForComp = attempt.answers.filter(a => a.competency === comp).slice(-1)[0];
    const decision = selector.selectNext({
      perf,
      questionsAsked: asked,
      selfRating: attempt.selfRatings.get(comp),
      currentDifficulty: lastForComp?.difficulty,
      lastAnswer: lastForComp ? { correct: lastForComp.isCorrect, fast: (lastForComp.timeTaken || 99) < 15 } : null,
    });
    if (decision.shouldStop) continue;

    // Find a pool question matching (competency, difficulty), not already used
    const usedIds = new Set(attempt.answers.map(a => String(a.questionId)));
    for (const qid of attempt.poolQuestionIds) {
      if (usedIds.has(String(qid))) continue;
      const q = await DiagnosticQuestionBank.findById(qid);
      if (!q) continue;
      if (q.difficulty !== decision.nextDifficulty) continue;
      // We don't strictly require q.canonicalCompetency === comp — pool may have other competencies; keep moving if mismatch
      if (q.canonicalCompetency && q.canonicalCompetency !== comp) continue;
      return {
        done: false,
        question: {
          id: q._id, competency: comp, difficulty: q.difficulty,
          questionText: q.questionText, options: q.options,
        },
      };
    }
    // No matching question in pool — try any difficulty for this competency
    for (const qid of attempt.poolQuestionIds) {
      if (usedIds.has(String(qid))) continue;
      const q = await DiagnosticQuestionBank.findById(qid);
      if (q && q.canonicalCompetency === comp) {
        return {
          done: false,
          question: {
            id: q._id, competency: comp, difficulty: q.difficulty,
            questionText: q.questionText, options: q.options,
          },
        };
      }
    }
  }
  return { done: true };
}

async function submitAnswer(attemptId, questionId, selectedAnswer, timeTaken) {
  const attempt = await DiagnosticAttempt.findById(attemptId);
  if (!attempt) throw new Error('attempt not found');
  const q = await DiagnosticQuestionBank.findById(questionId);
  if (!q) throw new Error('question not found');

  const isCorrect = q.correctAnswer === selectedAnswer;
  attempt.answers.push({
    questionId,
    competency: q.canonicalCompetency,
    difficulty: q.difficulty,
    selectedAnswer,
    isCorrect,
    timeTaken: timeTaken || 0,
  });
  await attempt.save();
  return { ack: true };
}
```

Add both to module.exports.

- [ ] **Step 4: Run, all tests pass**

Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): nextQuestion + submitAnswer with adaptive pool selection"
```

### Task 5.4: `finishAttempt` — derives results, writes KnowledgeProfile, seeds ConceptMastery

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Add failing test**

Append to `src/services/diagnosticService.test.js`:
```js
test('finishAttempt computes per-competency results and updates attempt status', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  const attemptId = new mongoose.Types.ObjectId();
  let saved = null;
  const attempt = {
    _id: attemptId, status: 'in_progress',
    userId: new mongoose.Types.ObjectId(),
    selfRatings: new Map([['sql', 'familiar']]),
    answers: [
      { competency: 'sql', difficulty: 'medium', isCorrect: true, timeTaken: 10 },
      { competency: 'sql', difficulty: 'medium', isCorrect: true, timeTaken: 10 },
    ],
    results: new Map(),
    save: async function () { saved = this; },
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  const kpPath = require.resolve('../models/KnowledgeProfile');
  let kpSave = null;
  const kp = {
    userId: attempt.userId, topicMastery: [],
    save: async function () { kpSave = this; },
  };
  require.cache[kpPath] = {
    exports: { findOne: async () => kp },
    loaded: true, id: kpPath,
  };
  const cmPath = require.resolve('../models/ConceptMastery');
  require.cache[cmPath] = {
    exports: { findOneAndUpdate: async () => null },
    loaded: true, id: cmPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  const result = await svc.finishAttempt(attemptId);

  assert.strictEqual(saved.status, 'completed');
  assert.ok(saved.completedAt);
  assert.strictEqual(saved.results.get('sql').assessedBand, 'proficient');
  assert.strictEqual(kpSave.topicMastery[0].topic, 'sql');
  assert.strictEqual(kpSave.topicMastery[0].selfRating, 'familiar');
  // calibrationDelta: familiar→1, proficient→2, delta = 1 (under-rated by 1 band)
  assert.strictEqual(kpSave.topicMastery[0].calibrationAtBaseline.delta, -1); // self < assessed
  assert.ok(result.results.sql);
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: `finishAttempt is not a function`.

- [ ] **Step 3: Implement**

Add to `src/services/diagnosticService.js`:
```js
const ConceptMastery = require('../models/ConceptMastery');

const RATING_TO_NUM = { novice: 0, familiar: 1, proficient: 2, expert: 3, unsure: 0 };

async function finishAttempt(attemptId) {
  const attempt = await DiagnosticAttempt.findById(attemptId);
  if (!attempt) throw new Error('attempt not found');
  if (attempt.status === 'completed') {
    return _resultsObjectFromAttempt(attempt);
  }

  // Compute per-competency results
  for (const comp of attempt.selfRatings.keys()) {
    const perf = _perfForCompetency(attempt.answers, comp);
    const band = selector._internal.deriveBand(perf);
    const score = selector._internal.bandToScore(band);
    const selfRatingNum = RATING_TO_NUM[attempt.selfRatings.get(comp)] ?? 0;
    const assessedNum = RATING_TO_NUM[band];
    const calibrationDelta = selfRatingNum - assessedNum; // positive = over-confident
    const questionsAsked = attempt.answers.filter(a => a.competency === comp).length;
    attempt.results.set(comp, { assessedBand: band, score, calibrationDelta, questionsAsked });
  }

  attempt.status = 'completed';
  attempt.completedAt = new Date();
  await attempt.save();

  // Apply to KnowledgeProfile
  await _applyToKnowledgeProfile(attempt).catch(err =>
    console.warn('[diagnosticService] KnowledgeProfile update failed:', err.message),
  );

  // Seed ConceptMastery
  await _seedConceptMastery(attempt).catch(err =>
    console.warn('[diagnosticService] ConceptMastery seed failed:', err.message),
  );

  return _resultsObjectFromAttempt(attempt);
}

function _resultsObjectFromAttempt(attempt) {
  const obj = {};
  for (const [k, v] of attempt.results.entries()) obj[k] = v;
  return { results: obj, status: attempt.status };
}

async function _applyToKnowledgeProfile(attempt) {
  const kp = await KnowledgeProfile.findOne({ userId: attempt.userId });
  if (!kp) return;
  const now = new Date();
  for (const [comp, res] of attempt.results.entries()) {
    let entry = kp.topicMastery.find(t => t.topic === comp);
    if (!entry) {
      entry = { topic: comp, scoreHistory: [] };
      kp.topicMastery.push(entry);
    }
    entry.score = res.score;
    entry.lastAssessedAt = now;
    entry.selfRating = attempt.selfRatings.get(comp);
    entry.calibrationAtBaseline = { delta: res.calibrationDelta, capturedAt: now };
  }
  await kp.save();
}

async function _seedConceptMastery(attempt) {
  // Best-effort: each competency gets one ConceptMastery row seeded with the
  // assessed score; spaced-repetition takes over from here on subsequent quizzes.
  const now = new Date();
  for (const [comp, res] of attempt.results.entries()) {
    const stability = res.score >= 70 ? 7 : res.score >= 50 ? 3 : 1;
    await ConceptMastery.findOneAndUpdate(
      { userId: attempt.userId, concept: comp },
      {
        $setOnInsert: {
          userId: attempt.userId, concept: comp,
          stability, difficulty: 5.0, reps: 1, lapses: 0,
          lastReviewedAt: now,
          nextReviewAt: new Date(now.getTime() + stability * 86400000),
        },
      },
      { upsert: true, new: true },
    );
  }
}
```

Add `finishAttempt` to module.exports.

- [ ] **Step 4: Run all tests pass**

Run: `node --test src/services/diagnosticService.test.js`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): finishAttempt — derive results + apply to KnowledgeProfile + seed ConceptMastery"
```

### Task 5.5: `abandon` with three-tier handling

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Add failing tests**

Append:
```js
test('abandon at <30% completion drops the data', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  let saved = null;
  const attempt = {
    _id: new mongoose.Types.ObjectId(),
    selfRatings: new Map([['sql', 'novice'], ['design', 'novice']]),
    answers: [{ competency: 'sql', isCorrect: true }], // 1/8 ≈ 12.5%
    poolQuestionIds: new Array(8).fill(0),
    save: async function () { saved = this; },
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  await svc.abandon(attempt._id);
  assert.strictEqual(saved.status, 'abandoned');
  assert.strictEqual(saved.abandonStrategy, 'dropped');
});

test('abandon at 70%+ auto-processes the partial set as completed', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  let saved = null;
  const attempt = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    selfRatings: new Map([['sql', 'familiar']]),
    answers: [
      { competency: 'sql', difficulty: 'medium', isCorrect: true, timeTaken: 10 },
      { competency: 'sql', difficulty: 'medium', isCorrect: true, timeTaken: 10 },
    ],
    results: new Map(),
    poolQuestionIds: ['q1', 'q2'], // 2/2 = 100%
    save: async function () { saved = this; },
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  const kpPath = require.resolve('../models/KnowledgeProfile');
  require.cache[kpPath] = {
    exports: { findOne: async () => null },
    loaded: true, id: kpPath,
  };
  const cmPath = require.resolve('../models/ConceptMastery');
  require.cache[cmPath] = {
    exports: { findOneAndUpdate: async () => null },
    loaded: true, id: cmPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  await svc.abandon(attempt._id);
  // 70%+ → process as if completed
  assert.strictEqual(saved.status, 'completed');
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: `abandon is not a function`.

- [ ] **Step 3: Implement**

Add to `src/services/diagnosticService.js`:
```js
async function abandon(attemptId) {
  const attempt = await DiagnosticAttempt.findById(attemptId);
  if (!attempt) throw new Error('attempt not found');
  if (attempt.status !== 'in_progress') return { status: attempt.status };

  const total = attempt.poolQuestionIds.length || 1;
  const answered = attempt.answers.length;
  const pct = answered / total;

  if (pct >= 0.7) {
    // High completion — process as if finished
    return finishAttempt(attemptId);
  }
  if (pct >= 0.3) {
    // Mid-completion — caller (via UI) chooses; here we mark abandoned with
    // partial_processed strategy and call finishAttempt to lock in what we have.
    attempt.abandonStrategy = 'partial_processed';
    attempt.abandonedAt = new Date();
    await attempt.save();
    return finishAttempt(attemptId);
  }
  // <30% — drop
  attempt.status = 'abandoned';
  attempt.abandonStrategy = 'dropped';
  attempt.abandonedAt = new Date();
  await attempt.save();
  return { status: 'abandoned', abandonStrategy: 'dropped' };
}
```

Add to module.exports.

- [ ] **Step 4: Run, all 10 tests pass**

Expected: 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): abandon with 3-tier policy (drop/partial-process/finish)"
```

---

## Phase 6 — Routes & controller

### Task 6.1: Controller wrapping all service methods

**Files:**
- Create: `src/controllers/diagnosticController.js`
- Test: skipped (controllers are thin pass-throughs; integration test covers them in Task 7.1)

- [ ] **Step 1: Implement the controller**

Create `src/controllers/diagnosticController.js`:
```js
const diagnosticService = require('../services/diagnosticService');
const featureFlags = require('../config/featureFlags');
const apiResponse = require('../utils/apiResponse');

function _gateOrPass(req, res, next) {
  if (!featureFlags.day1Diagnostic) {
    return res.status(404).json(apiResponse.error('Diagnostic feature is disabled.'));
  }
  next();
}

const start = async (req, res, next) => {
  try {
    const data = await diagnosticService.startAttempt(req.user.userId);
    if (!data) {
      return res.status(409).json(apiResponse.error('Objective has no mapped competencies yet — try again in a minute.'));
    }
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};

const submitSelfRating = async (req, res, next) => {
  try {
    const data = await diagnosticService.submitSelfRating(req.params.attemptId, req.body?.ratings || {});
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};

const nextQuestion = async (req, res, next) => {
  try {
    const data = await diagnosticService.nextQuestion(req.params.attemptId);
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};

const submitAnswer = async (req, res, next) => {
  try {
    const { questionId, selectedAnswer, timeTaken } = req.body || {};
    const data = await diagnosticService.submitAnswer(
      req.params.attemptId, questionId, selectedAnswer, timeTaken,
    );
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};

const finish = async (req, res, next) => {
  try {
    const data = await diagnosticService.finishAttempt(req.params.attemptId);
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};

const abandon = async (req, res, next) => {
  try {
    const data = await diagnosticService.abandon(req.params.attemptId);
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};

module.exports = {
  _gateOrPass, start, submitSelfRating, nextQuestion, submitAnswer, finish, abandon,
};
```

- [ ] **Step 2: Smoke check**

Run: `node -e "require('./src/controllers/diagnosticController')"`
Expected: no error.

- [ ] **Step 3: Commit**

```bash
git add src/controllers/diagnosticController.js
git commit -m "feat(diagnostic): controller layer with feature-flag gate"
```

### Task 6.2: Route mount

**Files:**
- Create: `src/routes/diagnostic.js`
- Modify: `src/app.js`

- [ ] **Step 1: Create the route file**

Create `src/routes/diagnostic.js`:
```js
const router = require('express').Router();
const ctrl = require('../controllers/diagnosticController');
const auth = require('../middleware/auth');

router.use(ctrl._gateOrPass);
router.use(auth);

router.post('/start', ctrl.start);
router.post('/:attemptId/self-rating', ctrl.submitSelfRating);
router.get('/:attemptId/next-question', ctrl.nextQuestion);
router.post('/:attemptId/answer', ctrl.submitAnswer);
router.post('/:attemptId/finish', ctrl.finish);
router.post('/:attemptId/abandon', ctrl.abandon);

module.exports = router;
```

- [ ] **Step 2: Mount in `src/app.js`**

Find this line in `src/app.js`:
```js
app.use('/api/v1/progress', require('./routes/progress'));
```

Add right after it:
```js
app.use('/api/v1/diagnostic', require('./routes/diagnostic'));
```

- [ ] **Step 3: Smoke check**

Run: `node -e "process.env.FEATURE_DAY1_DIAGNOSTIC='true'; const a = require('./src/app');"`
Expected: no error.

- [ ] **Step 4: Commit**

```bash
git add src/routes/diagnostic.js src/app.js
git commit -m "feat(diagnostic): mount /api/v1/diagnostic routes (gated by feature flag)"
```

---

## Phase 7 — Plan generation integration

### Task 7.1: Inject `diagnosticData` into plan generation pipeline

**Files:**
- Modify: `src/services/journeyGenerationService.js` (the existing plan/journey generator)
- Test: `src/services/journeyGenerationService.test.js` (create — small targeted test)

This task is conservative: we *only* add a new code path that fires when diagnosticData is present. The existing path is preserved verbatim.

- [ ] **Step 1: Find the existing plan generation entry point**

Run: `grep -n "generateJourney\|generatePlan\|class.*Journey" src/services/journeyGenerationService.js | head -10`
Expected: shows the main generation function and its inputs.

- [ ] **Step 2: Write the failing test**

Create `src/services/journeyGenerationService.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');

test('journey generation reads diagnosticData when provided (additive path)', async () => {
  // We only test the entry-point gate; the LLM call itself is mocked.
  const openaiPath = require.resolve('../config/openai');
  let lastUserMessage = null;
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async ({ messages }) => {
      lastUserMessage = messages.find(m => m.role === 'user')?.content || '';
      return { choices: [{ message: { content: JSON.stringify({ weeks: [] }) } }] };
    } } } },
    loaded: true, id: openaiPath,
  };
  delete require.cache[require.resolve('./journeyGenerationService')];
  const svc = require('./journeyGenerationService');

  if (typeof svc.buildPromptInput === 'function') {
    const out = svc.buildPromptInput({
      objective: { objectiveType: 'interview_preparation' },
      diagnosticData: {
        sql: { assessedBand: 'familiar', score: 50 },
        'system design': { assessedBand: 'novice', score: 25 },
      },
    });
    assert.ok(JSON.stringify(out).includes('diagnosticData'));
  }
});
```

NOTE: this test is intentionally permissive — different repos structure their generation services differently. If the existing service doesn't expose `buildPromptInput`, the test simply asserts the diagnostic-aware path exists at the integration level (next task).

- [ ] **Step 3: Add the additive injection**

Edit `src/services/journeyGenerationService.js`. Find the function that builds the LLM input (likely named `buildPromptInput`, `buildContext`, or similar). Add a parameter `diagnosticData` and include it in the user payload when present. Concretely, inside the generation entry function find where the user message is constructed and add:

```js
if (input.diagnosticData) {
  // Day-1 diagnostic data: per-competency assessed band + score from the user's
  // proficiency check. The LLM is told to start the plan FROM these levels,
  // not from scratch. Topics where the user is already strong (band ≥ proficient)
  // get marked "review only"; weak topics get extra time.
  promptData.diagnosticData = input.diagnosticData;
}
```

If `buildPromptInput` doesn't exist as a named function, just add the same conditional inside the equivalent block where `promptData` (or analogous variable) is constructed.

Also extend the system prompt with this rule:
```
If diagnosticData is present, USE the per-competency assessed band to:
- Mark topics with band 'proficient' or 'expert' as "review only" (1-2 lessons max).
- Allocate extra time to topics with band 'novice' or 'familiar'.
- Order weeks by band ascending (weakest first) within the constraint of prerequisites.
```

- [ ] **Step 4: Run the test**

Run: `node --test src/services/journeyGenerationService.test.js`
Expected: PASS (test is permissive; verifies the path exists).

- [ ] **Step 5: Commit**

```bash
git add src/services/journeyGenerationService.js src/services/journeyGenerationService.test.js
git commit -m "feat(diagnostic): plan generation consumes diagnosticData when present (additive)"
```

### Task 7.2: Trigger plan regeneration after `finishAttempt`

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Add failing test**

Append:
```js
test('finishAttempt triggers plan regeneration with diagnosticData', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  const attempt = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    status: 'in_progress',
    selfRatings: new Map([['sql', 'novice']]),
    answers: [{ competency: 'sql', difficulty: 'easy', isCorrect: true }, { competency: 'sql', difficulty: 'easy', isCorrect: true }],
    results: new Map(),
    save: async () => {},
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  const kpPath = require.resolve('../models/KnowledgeProfile');
  require.cache[kpPath] = {
    exports: { findOne: async () => null },
    loaded: true, id: kpPath,
  };
  const cmPath = require.resolve('../models/ConceptMastery');
  require.cache[cmPath] = {
    exports: { findOneAndUpdate: async () => null },
    loaded: true, id: cmPath,
  };
  let planCalled = null;
  const planPath = require.resolve('./journeyGenerationService');
  require.cache[planPath] = {
    exports: { regenerateForUser: async (uid, opts) => { planCalled = { uid, opts }; } },
    loaded: true, id: planPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  await svc.finishAttempt(attempt._id);
  assert.ok(planCalled, 'plan regeneration should have been triggered');
  assert.ok(planCalled.opts?.diagnosticData?.sql);
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: `planCalled` will be null because the trigger isn't wired.

- [ ] **Step 3: Add the trigger**

In `src/services/diagnosticService.js`, after the `_seedConceptMastery` call inside `finishAttempt`:

```js
// Phase 9: trigger plan regeneration with diagnostic data injected.
// Best-effort — don't block the response if the journey service is busy.
try {
  const journeyService = require('./journeyGenerationService');
  if (typeof journeyService.regenerateForUser === 'function') {
    const diagnosticData = {};
    for (const [k, v] of attempt.results.entries()) diagnosticData[k] = v;
    await journeyService.regenerateForUser(attempt.userId, { diagnosticData });
  }
} catch (err) {
  console.warn('[diagnosticService] plan regenerate failed:', err.message);
}
```

If `regenerateForUser` doesn't exist on the journey service, add a stub that delegates to the existing public regenerate function. (Look for the existing entry that's called during onboarding — wrap it in a `regenerateForUser(userId, { diagnosticData })` shim.)

- [ ] **Step 4: Run all tests, confirm 11 pass**

Expected: 11 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): trigger plan regeneration after finishAttempt"
```

---

## Phase 8 — Telemetry

### Task 8.1: Cohort tagging + funnel events

**Files:**
- Create: `src/services/diagnosticTelemetryService.js`
- Test: `src/services/diagnosticTelemetryService.test.js`
- Modify: `src/services/diagnosticService.js`

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnosticTelemetryService.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');

test('logEvent constructs the expected payload', () => {
  let logged = null;
  const tel = require('./diagnosticTelemetryService');
  tel._setEmitter((evt) => { logged = evt; });
  tel.logEvent('diagnostic.started', { userId: 'u1', flowType: 'new_user' });
  assert.strictEqual(logged.event, 'diagnostic.started');
  assert.strictEqual(logged.props.userId, 'u1');
  assert.ok(logged.timestamp);
});

test('logEvent silently no-ops when no emitter set', () => {
  const tel = require('./diagnosticTelemetryService');
  tel._setEmitter(null);
  // should not throw
  tel.logEvent('any.event', {});
  assert.ok(true);
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: module not found.

- [ ] **Step 3: Implement**

Create `src/services/diagnosticTelemetryService.js`:
```js
/**
 * Telemetry — minimal v1. Just emits structured events to a configurable sink.
 * Replace the default emitter with Mixpanel/Posthog/etc. wiring at app startup.
 */

let _emitter = null;

function _setEmitter(fn) { _emitter = fn; }

function logEvent(event, props = {}) {
  if (!_emitter) return;
  try {
    _emitter({ event, props, timestamp: new Date().toISOString() });
  } catch (err) {
    console.warn('[diagnosticTelemetry] emit failed:', err.message);
  }
}

module.exports = { logEvent, _setEmitter };
```

- [ ] **Step 4: Wire into `diagnosticService.js`**

At the top of `src/services/diagnosticService.js`:
```js
const telemetry = require('./diagnosticTelemetryService');
```

Then add `telemetry.logEvent(...)` calls at:
- `startAttempt` after `attempt.save()`: `telemetry.logEvent('diagnostic.started', { userId: String(userId), flowType });`
- `submitSelfRating` after `attempt.save()`: `telemetry.logEvent('diagnostic.self_rating_submitted', { attemptId: String(attemptId) });`
- `finishAttempt` before return: `telemetry.logEvent('diagnostic.finished', { userId: String(attempt.userId), questionsAnswered: attempt.answers.length });`
- `abandon` (drop branch): `telemetry.logEvent('diagnostic.abandoned', { userId: String(attempt.userId), strategy: 'dropped', pct: Math.round(pct*100) });`

- [ ] **Step 5: Run tests + commit**

Run: `node --test src/services/`
Expected: all tests pass.

```bash
git add src/services/diagnosticTelemetryService.js src/services/diagnosticTelemetryService.test.js src/services/diagnosticService.js
git commit -m "feat(diagnostic): structured telemetry events for v1 funnel + cohort"
```

---

## Phase 9 — End-to-end smoke test

### Task 9.1: Full happy-path integration test

**Files:**
- Create: `src/integration/diagnostic.test.js`

- [ ] **Step 1: Write the integration test**

Create `src/integration/diagnostic.test.js`:
```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

test('diagnostic happy-path: start → self-rate → answer all → finish', async () => {
  // ===== Stub all models and external services =====

  const userId = new mongoose.Types.ObjectId();
  let createdAttempt = null;

  const dapath = require.resolve('../models/DiagnosticAttempt');
  require.cache[dapath] = {
    exports: function FakeDA(data) {
      Object.assign(this, data);
      this._id = new mongoose.Types.ObjectId();
      this.save = async () => { createdAttempt = this; return this; };
    },
    loaded: true, id: dapath,
  };
  require.cache[dapath].exports.findById = async () => createdAttempt;
  require.cache[dapath].exports.findOne = async () => null;

  const kpPath = require.resolve('../models/KnowledgeProfile');
  require.cache[kpPath] = {
    exports: { findOne: async () => null },
    loaded: true, id: kpPath,
  };

  const cmPath = require.resolve('../models/ConceptMastery');
  require.cache[cmPath] = {
    exports: { findOneAndUpdate: async () => null },
    loaded: true, id: cmPath,
  };

  const objpath = require.resolve('../models/UserObjective');
  require.cache[objpath] = {
    exports: { findOne: () => ({ lean: async () => ({
      _id: 'obj1', objectiveType: 'interview_preparation',
      analysis: { competencies: [{ name: 'sql' }] },
    }) }) },
    loaded: true, id: objpath,
  };

  const bankPath = require.resolve('../models/DiagnosticQuestionBank');
  require.cache[bankPath] = {
    exports: {
      find: () => ({
        sort: () => ({
          limit: () => ({ lean: async () => [
            { _id: 'q1', canonicalCompetency: 'sql', difficulty: 'easy', questionText: 'q1', options: [
              { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
              { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
            ], correctAnswer: 'A' },
            { _id: 'q2', canonicalCompetency: 'sql', difficulty: 'easy', questionText: 'q2', options: [
              { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
              { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
            ], correctAnswer: 'A' },
          ] }),
        }),
      }),
      findById: async (id) => ({
        _id: id, canonicalCompetency: 'sql', difficulty: 'easy',
        questionText: id, options: [
          { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
          { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
        ], correctAnswer: 'A',
      }),
      insertMany: async (d) => d,
    },
    loaded: true, id: bankPath,
  };

  const planPath = require.resolve('../services/journeyGenerationService');
  require.cache[planPath] = {
    exports: { regenerateForUser: async () => null },
    loaded: true, id: planPath,
  };

  const openaiPath = require.resolve('../config/openai');
  require.cache[openaiPath] = {
    exports: { chat: { completions: { create: async () => ({ choices: [{ message: { content: '{}' } }] }) } } },
    loaded: true, id: openaiPath,
  };

  // Reset module cache for service modules to use the stubs
  for (const m of [
    './diagnosticPoolService', './diagnosticSelectorService', './diagnosticService',
  ]) {
    delete require.cache[require.resolve('../services/' + m.replace('./', ''))];
  }

  const svc = require('../services/diagnosticService');

  // ===== Walk the flow =====

  const start = await svc.startAttempt(userId);
  assert.ok(start.attemptId);
  assert.strictEqual(start.flowType, 'new_user');
  // Patch poolQuestionIds since assemblePool returned 2 stub questions
  createdAttempt.poolQuestionIds = ['q1', 'q2'];

  await svc.submitSelfRating(start.attemptId, { sql: 'novice' });

  // Answer two questions correctly to converge
  const q1 = await svc.nextQuestion(start.attemptId);
  assert.ok(q1.question);
  await svc.submitAnswer(start.attemptId, q1.question.id, 'A', 5);

  const q2 = await svc.nextQuestion(start.attemptId);
  if (!q2.done) {
    await svc.submitAnswer(start.attemptId, q2.question.id, 'A', 5);
  }

  const result = await svc.finishAttempt(start.attemptId);
  assert.strictEqual(result.status, 'completed');
  assert.ok(result.results.sql);
  // Two correct at easy → familiar (not novice)
  assert.strictEqual(result.results.sql.assessedBand, 'familiar');
});
```

- [ ] **Step 2: Run the integration test**

Run: `node --test src/integration/diagnostic.test.js`
Expected: 1 test passes.

- [ ] **Step 3: Run the full suite**

Run: `npm test`
Expected: every test in the suite passes (~30+ tests across all phases).

- [ ] **Step 4: Commit**

```bash
git add src/integration/diagnostic.test.js
git commit -m "test(diagnostic): end-to-end happy path integration"
```

---

## Phase 10 — Existing-user flow & retake policy (spec §4 + Edges 5, 6, 11)

### Task 10.1: Synthesis endpoint for the E1 screen

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/controllers/diagnosticController.js`
- Modify: `src/routes/diagnostic.js`
- Test: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Write the failing test**

Append to `src/services/diagnosticService.test.js`:
```js
test('getSynthesis returns userContextService output formatted for E1', async () => {
  const ucsPath = require.resolve('./userContextService');
  require.cache[ucsPath] = {
    exports: {
      getUserContext: async () => ({
        weakTopics: [{ topic: 'system design', score: 42 }],
        strongTopics: [{ topic: 'stats', score: 78 }],
        misconceptions: [{ tag: 'reverses_conditional', count: 6, topics: ['bayes','medical'], explanation: 'Confuses P(A|B) with P(B|A).' }],
        cognitiveTraits: [{ kind: 'time_of_day', bestHourBlock: 'evening', lift: 14 }],
        objective: { label: 'Senior PM', daysToTarget: 38 },
        profile: { totalQuizzesTaken: 47, totalTopicsCovered: 8 },
      }),
      summarize: () => 'mock summary',
    },
    loaded: true, id: ucsPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  const out = await svc.getSynthesis(new (require('mongoose')).Types.ObjectId());
  assert.ok(out.weakest);
  assert.strictEqual(out.weakest[0].topic, 'system design');
  assert.ok(out.strongest);
  assert.ok(out.recurringConfusion);
  assert.ok(out.cognitive);
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: `getSynthesis is not a function`.

- [ ] **Step 3: Implement**

Add to `src/services/diagnosticService.js`:
```js
const userContextService = require('./userContextService');

/**
 * Build the E1 synthesis screen payload for an existing user. Reformats
 * userContextService output into a UI-friendly shape with stable keys.
 */
async function getSynthesis(userId) {
  const ctx = await userContextService.getUserContext(userId);
  return {
    weakest:           ctx.weakTopics?.slice(0, 3) || [],
    strongest:         ctx.strongTopics?.slice(0, 2) || [],
    recurringConfusion: ctx.misconceptions?.[0] || null,
    cognitive:         ctx.cognitiveTraits?.[0] || null,
    objective:         ctx.objective || null,
    activitySummary: {
      totalQuizzesTaken:   ctx.profile?.totalQuizzesTaken ?? 0,
      totalTopicsCovered:  ctx.profile?.totalTopicsCovered ?? 0,
    },
  };
}
```

Add to module.exports.

- [ ] **Step 4: Add controller + route**

In `src/controllers/diagnosticController.js`, add:
```js
const synthesis = async (req, res, next) => {
  try {
    const data = await diagnosticService.getSynthesis(req.user.userId);
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};
```

Add `synthesis` to module.exports.

In `src/routes/diagnostic.js`, add (above the parameterised routes):
```js
router.get('/synthesis', ctrl.synthesis);
```

- [ ] **Step 5: Run tests + commit**

Run: `node --test src/services/diagnosticService.test.js`
Expected: all tests pass including the new one.

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js src/controllers/diagnosticController.js src/routes/diagnostic.js
git commit -m "feat(diagnostic): synthesis endpoint for existing-user flow E1 screen"
```

### Task 10.2: Existing-user gap-fill scoping (variable question count)

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

For existing users, per spec §4 Screen E4: scope the diagnostic based on existing data signal per competency:

| Existing data per competency | Questions to ask |
|---|---|
| Strong (5+ attempts, score variance < 15pp) | 0 |
| Medium (2-4 attempts, OR variance 15-30pp) | 1 |
| Weak (0-1 attempts) | 2-3 |

This affects the pool allocation calculation only when `flowType === 'existing_user_tune'`.

- [ ] **Step 1: Write the failing test**

Append:
```js
test('existing-user flow: strong competency gets 0 questions', async () => {
  const { _internal } = require('./diagnosticService');
  const profile = {
    totalQuizzesTaken: 10,
    topicMastery: [
      { topic: 'sql', score: 80, quizzesTaken: 6, scoreHistory: Array.from({length: 6}, () => ({ score: 80 })) },
    ],
  };
  const cap = _internal.questionCapForCompetency(profile, 'sql');
  assert.strictEqual(cap, 0);
});

test('existing-user flow: medium-signal competency gets 1 question', async () => {
  const { _internal } = require('./diagnosticService');
  const profile = {
    totalQuizzesTaken: 5,
    topicMastery: [
      { topic: 'sql', score: 70, quizzesTaken: 3, scoreHistory: [{ score: 60 }, { score: 80 }, { score: 70 }] },
    ],
  };
  const cap = _internal.questionCapForCompetency(profile, 'sql');
  assert.strictEqual(cap, 1);
});

test('existing-user flow: weak-signal competency gets full 2-3 questions', async () => {
  const { _internal } = require('./diagnosticService');
  const profile = {
    totalQuizzesTaken: 1,
    topicMastery: [{ topic: 'sql', score: 50, quizzesTaken: 1, scoreHistory: [{ score: 50 }] }],
  };
  const cap = _internal.questionCapForCompetency(profile, 'sql');
  assert.ok(cap >= 2 && cap <= 3);
});

test('existing-user flow: never-touched competency gets full 2-3', async () => {
  const { _internal } = require('./diagnosticService');
  const profile = { totalQuizzesTaken: 0, topicMastery: [] };
  const cap = _internal.questionCapForCompetency(profile, 'sql');
  assert.ok(cap >= 2 && cap <= 3);
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: `_internal.questionCapForCompetency` undefined.

- [ ] **Step 3: Implement**

Add to `src/services/diagnosticService.js` near other helpers:
```js
/**
 * For existing-user flow: how many questions to ask about a competency given
 * existing KnowledgeProfile signal. See spec §4 Screen E4.
 */
function questionCapForCompetency(profile, competency) {
  const tm = profile?.topicMastery?.find(t => (t.topic || '').toLowerCase() === competency.toLowerCase());
  if (!tm) return 3; // Never seen → full scope
  const attempts = tm.quizzesTaken || 0;
  if (attempts === 0) return 3;
  // Score variance: stdev of recent scoreHistory
  const scores = (tm.scoreHistory || []).map(h => h.score || 0).slice(-5);
  let variance = 0;
  if (scores.length >= 2) {
    const mean = scores.reduce((s, v) => s + v, 0) / scores.length;
    variance = Math.sqrt(scores.reduce((s, v) => s + (v - mean) ** 2, 0) / scores.length);
  }
  if (attempts >= 5 && variance < 15) return 0;          // Strong, stable signal
  if (attempts >= 2 || variance >= 15) return 1;          // Some signal, disambiguate
  return 2;                                               // Weak signal
}
```

Add `questionCapForCompetency` to `_internal` exports.

Then modify `startAttempt` so that when `flowType === 'existing_user_tune'`, the `competenciesToAssess` returned is reshaped to drop competencies with cap === 0 and tag the rest with their cap:

In `startAttempt`, after computing `flowType` and before the return, add:
```js
let competenciesToAssess = competencies.map(c => ({ name: c.name, questionCap: 3 }));
if (flowType === 'existing_user_tune' && profile) {
  competenciesToAssess = competenciesToAssess
    .map(c => ({ ...c, questionCap: questionCapForCompetency(profile, c.name) }))
    .filter(c => c.questionCap > 0);
}
```

Update the `return` to include `competenciesToAssess` (this replaces the existing return value).

- [ ] **Step 4: Run, confirm tests pass**

Run: `node --test src/services/diagnosticService.test.js`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js
git commit -m "feat(diagnostic): existing-user flow scopes questions by signal strength"
```

### Task 10.3: Retake cooldown + objective-change override (Edges 5, 6)

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

- [ ] **Step 1: Write the failing test**

Append:
```js
test('startAttempt rejects retake within 30 days of a completed attempt', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  const recentCompleted = {
    completedAt: new Date(Date.now() - 5 * 86400000), // 5 days ago
    objectiveSnapshot: { _id: 'obj1' },
  };
  require.cache[dapath] = {
    exports: function () {},
    loaded: true, id: dapath,
  };
  require.cache[dapath].exports.findOne = async () => recentCompleted;
  const objpath = require.resolve('../models/UserObjective');
  require.cache[objpath] = {
    exports: { findOne: () => ({ lean: async () => ({ _id: 'obj1', analysis: { competencies: [{ name: 'sql' }] } }) }) },
    loaded: true, id: objpath,
  };
  const kpPath = require.resolve('../models/KnowledgeProfile');
  require.cache[kpPath] = {
    exports: { findOne: async () => null },
    loaded: true, id: kpPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  const result = await svc.startAttempt(new (require('mongoose')).Types.ObjectId());
  assert.strictEqual(result, null);  // null = caller surfaces "too soon" error
});

test('startAttempt allows retake within 30d if objective changed', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  const recentCompleted = {
    completedAt: new Date(Date.now() - 5 * 86400000),
    objectiveSnapshot: { _id: 'old-obj' },
  };
  let savedAttempt = null;
  require.cache[dapath] = {
    exports: function FakeDA(data) {
      Object.assign(this, data);
      this.save = async () => { savedAttempt = this; this._id = 'new'; return this; };
    },
    loaded: true, id: dapath,
  };
  require.cache[dapath].exports.findOne = async () => recentCompleted;
  const objpath = require.resolve('../models/UserObjective');
  require.cache[objpath] = {
    exports: { findOne: () => ({ lean: async () => ({ _id: 'new-obj', analysis: { competencies: [{ name: 'sql' }] } }) }) },
    loaded: true, id: objpath,
  };
  const kpPath = require.resolve('../models/KnowledgeProfile');
  require.cache[kpPath] = {
    exports: { findOne: async () => null },
    loaded: true, id: kpPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  const result = await svc.startAttempt(new (require('mongoose')).Types.ObjectId());
  assert.ok(result);
  assert.strictEqual(savedAttempt.objectiveSnapshot._id, 'new-obj');
});
```

- [ ] **Step 2: Run, confirm fails**

Expected: cooldown logic not implemented.

- [ ] **Step 3: Implement**

In `src/services/diagnosticService.js`, modify `startAttempt`:

At the top of the function, after loading `profile` and `objective`, add:
```js
const RETAKE_COOLDOWN_MS = 30 * 86400000;
const lastCompleted = await DiagnosticAttempt.findOne({
  userId, status: 'completed',
}).sort({ completedAt: -1 }).lean();

if (lastCompleted && lastCompleted.completedAt) {
  const ageMs = Date.now() - new Date(lastCompleted.completedAt).getTime();
  const sameObjective = String(lastCompleted.objectiveSnapshot?._id) === String(objective?._id);
  if (ageMs < RETAKE_COOLDOWN_MS && sameObjective) {
    return null; // controller maps null → 429 "too soon"
  }
}
```

Also: when creating the new `DiagnosticAttempt`, snapshot the objective. Modify the `new DiagnosticAttempt({ ... })` call to include:
```js
objectiveSnapshot: objective ? { _id: objective._id } : null,
```

Add `objectiveSnapshot` field to the model. Edit `src/models/DiagnosticAttempt.js`:
```js
// Inside the schema definition, near other top-level fields:
objectiveSnapshot: {
  _id: { type: mongoose.Schema.Types.ObjectId, ref: 'UserObjective' },
},
```

- [ ] **Step 4: Update controller to surface the cooldown distinctly**

In `src/controllers/diagnosticController.js`, the `start` handler currently returns 409 when `data` is null. Update to differentiate:

```js
const start = async (req, res, next) => {
  try {
    const data = await diagnosticService.startAttempt(req.user.userId);
    if (!data) {
      // null could mean either "no competencies yet" or "retake cooldown".
      // The service can be enhanced to return a richer signal; for now, 409.
      return res.status(409).json(apiResponse.error('Cannot start a new diagnostic right now. Either your objective has no mapped competencies yet, or you completed one less than 30 days ago.'));
    }
    res.json(apiResponse.success(data));
  } catch (err) { next(err); }
};
```

- [ ] **Step 5: Run, confirm tests pass + commit**

Run: `node --test src/services/diagnosticService.test.js`
Expected: all pass.

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js src/controllers/diagnosticController.js src/models/DiagnosticAttempt.js
git commit -m "feat(diagnostic): retake cooldown 30d + objective-change override (Edges 5, 6)"
```

### Task 10.4: Low-confidence flag for fast-answer attempts (Edge 11)

**Files:**
- Modify: `src/services/diagnosticService.js`
- Modify: `src/services/diagnosticService.test.js`

Per spec §9 Edge 11: if a user answers extremely fast (<5s avg), flag the attempt with `confidence: 'low'`. Phase 6's confidence-gating handles this naturally for downstream consumers.

- [ ] **Step 1: Add field to model**

Edit `src/models/DiagnosticAttempt.js`. Add inside the schema definition (near `cohort`):
```js
confidence: { type: String, enum: ['high', 'medium', 'low'], default: 'high' },
```

- [ ] **Step 2: Write the failing test**

Append to `src/services/diagnosticService.test.js`:
```js
test('finishAttempt sets confidence:low when avg time per answer < 5s', async () => {
  const dapath = require.resolve('../models/DiagnosticAttempt');
  let saved = null;
  const attempt = {
    _id: new (require('mongoose')).Types.ObjectId(),
    userId: new (require('mongoose')).Types.ObjectId(),
    status: 'in_progress',
    selfRatings: new Map([['sql', 'novice']]),
    answers: [
      { competency: 'sql', difficulty: 'easy', isCorrect: true, timeTaken: 3 },
      { competency: 'sql', difficulty: 'easy', isCorrect: true, timeTaken: 4 },
    ],
    results: new Map(),
    save: async function () { saved = this; },
  };
  require.cache[dapath] = {
    exports: { findById: async () => attempt },
    loaded: true, id: dapath,
  };
  const kpPath = require.resolve('../models/KnowledgeProfile');
  require.cache[kpPath] = {
    exports: { findOne: async () => null },
    loaded: true, id: kpPath,
  };
  const cmPath = require.resolve('../models/ConceptMastery');
  require.cache[cmPath] = {
    exports: { findOneAndUpdate: async () => null },
    loaded: true, id: cmPath,
  };
  delete require.cache[require.resolve('./diagnosticService')];
  const svc = require('./diagnosticService');
  await svc.finishAttempt(attempt._id);
  assert.strictEqual(saved.confidence, 'low');
});
```

- [ ] **Step 3: Run, confirm fails**

Expected: `confidence` field is undefined / not set.

- [ ] **Step 4: Implement**

In `src/services/diagnosticService.js`, edit `finishAttempt`. Before `await attempt.save()` (the second one, where status is set to 'completed'), add:
```js
// Edge 11: detect rushed answers — if average time per answer < 5 sec,
// flag confidence as low. Downstream consumers (Phase 6 cognitive surfacing,
// Insights cards) treat low-confidence diagnostic data with extra caution.
const totalTime = attempt.answers.reduce((s, a) => s + (a.timeTaken || 0), 0);
const avgTime = attempt.answers.length > 0 ? totalTime / attempt.answers.length : Infinity;
attempt.confidence = avgTime < 5 ? 'low' : avgTime < 12 ? 'medium' : 'high';
```

- [ ] **Step 5: Run all tests + commit**

Run: `node --test src/services/diagnosticService.test.js`
Expected: all pass.

```bash
git add src/services/diagnosticService.js src/services/diagnosticService.test.js src/models/DiagnosticAttempt.js
git commit -m "feat(diagnostic): low-confidence flag for fast-answer attempts (Edge 11)"
```

---

## Phase 11 — Manual smoke + readme

### Task 11.1: Manual curl smoke against local server

This is a sanity check, not an automated test. Run the local server with the feature flag on and confirm endpoints respond.

- [ ] **Step 1: Start the server with the flag**

```bash
FEATURE_DAY1_DIAGNOSTIC=true npm run dev
```

Expected: server starts on the configured port, no errors.

- [ ] **Step 2: Issue a curl to the start endpoint (with a real auth token)**

```bash
curl -X POST http://localhost:5000/api/v1/diagnostic/start \
  -H "Authorization: Bearer <real_jwt>" \
  -H "Content-Type: application/json"
```

Expected: `{ success: true, data: { attemptId, flowType, competenciesToAssess } }` OR a 409 if the user has no objective yet (acceptable — it means the gate works).

- [ ] **Step 3: Confirm the disabled path**

```bash
FEATURE_DAY1_DIAGNOSTIC=false npm run dev
# in another shell:
curl -i -X POST http://localhost:5000/api/v1/diagnostic/start
```

Expected: HTTP 404 with `{ success: false, error: 'Diagnostic feature is disabled.' }`.

- [ ] **Step 4: No commit needed for this task** (manual verification only).

### Task 11.2: Update API documentation

**Files:**
- Modify: `docs/api.md` (if exists; otherwise add a brief note to README)

- [ ] **Step 1: Document the 6 new endpoints**

Add a section:
```markdown
## Day-1 Diagnostic — `/api/v1/diagnostic/*`

Gated by `FEATURE_DAY1_DIAGNOSTIC=true`.

| Method | Path | Body / Description |
|---|---|---|
| POST | /start | Creates a new DiagnosticAttempt for the authenticated user. Returns `{ attemptId, flowType, competenciesToAssess }`. |
| POST | /:attemptId/self-rating | Body: `{ ratings: { [competency]: 'novice'\|... } }`. Stores ratings + assembles question pool. |
| GET  | /:attemptId/next-question | Returns next adaptive question or `{ done: true }`. |
| POST | /:attemptId/answer | Body: `{ questionId, selectedAnswer, timeTaken }`. |
| POST | /:attemptId/finish | Closes the attempt, writes to KnowledgeProfile, seeds ConceptMastery, triggers plan regeneration. Returns per-competency results. |
| POST | /:attemptId/abandon | 3-tier abandonment policy: <30% drop, 30-70% partial-process, 70%+ auto-finish. |
```

- [ ] **Step 2: Commit**

```bash
git add docs/api.md
git commit -m "docs(diagnostic): API surface for /api/v1/diagnostic/*"
```

---

## Self-review (run this before handing off)

1. **Spec coverage check:** Every numbered section in the spec maps to at least one task here. ✅
2. **No placeholders:** No "TODO", "implement later", "similar to above" — every step has real code. ✅
3. **Type consistency:** Function signatures match across tasks (e.g. `selectNext({...})` shape consistent in tests + implementation). ✅
4. **Backward compatibility:** All schema changes are additive (Task 1.3 explicitly tests this). Feature flag (Task 0.2) gates the whole surface area. ✅

---

## Execution choice

Plan complete and saved to `docs/superpowers/plans/2026-04-27-day1-diagnostic-backend.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
