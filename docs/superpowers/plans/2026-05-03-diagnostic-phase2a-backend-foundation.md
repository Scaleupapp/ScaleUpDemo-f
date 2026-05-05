# Day-1 Diagnostic — Plan 2a: Phase 1 Backend Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay the Phase 1 backend foundation for the redesigned Day-1 Diagnostic — the model fields, services, and API endpoints that everything else (engine, results, plan, recalibration) builds on. Strictly backend (Node.js / Mongoose). No diagnostic engine, no results screen, no frontend.

**Architecture:** Three additive field changes to `UserObjective`, four additive field changes to `DiagnosticAttempt`, one new model (`DiagnosticSyllabus`), one new LLM-backed service (`specificsNormalizationService`), three new API endpoints (`/onboarding/topics/suggest`, `/onboarding/complete`, `/diagnostic/syllabus/*`), and a one-shot migration script that flags every existing user objective as needing calibration. Reuses Plan 1's `TopicTaxonomy` and existing notes upload + OCR worker infrastructure.

**Tech Stack:**
- Node.js + Mongoose 8.x
- Express (existing routing patterns in `src/routes/`)
- OpenAI SDK 4.x — `gpt-4o-mini`, `response_format: { type: 'json_schema', strict: true }`, hard 3 s timeout
- BullMQ (existing OCR queue) for syllabus extraction handoff
- AWS S3 via existing helpers in `src/config/s3.js`
- node:test + node:assert (matches existing project convention)

**Source documents (read-only references):**
- Spec: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/specs/2026-05-03-day1-diagnostic-redesign-design.md`
  - §3.4 Existing-user migration
  - §3.6 Syllabus upload
  - §4.1 UserObjective additions
  - §4.4 DiagnosticAttempt cleanup
  - §4.6 DiagnosticSyllabus
  - §12.1 Onboarding endpoints
  - §12.5 Syllabus endpoints
- Plan 1 (style/format reference): `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/plans/2026-05-03-diagnostic-phase0.5-seed-scripts.md`

**Backend repo path (all file paths in this plan are relative to here):**
`/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`

---

## File Structure (decisions locked here)

| Path | Responsibility | Status |
|---|---|---|
| `src/models/UserObjective.js` | Existing model | MODIFY (add `topicSelfRatings`, `specificsCanonical`, `needsCalibration`) |
| `src/models/UserObjective.test.js` | Schema tests for new fields | NEW |
| `src/models/DiagnosticAttempt.js` | Existing model | MODIFY (add `insightsJson`, `planGenerationStatus`, `attemptType`, `previousAttemptId`) |
| `src/models/DiagnosticAttempt.test.js` | Existing tests | MODIFY (add tests for new field defaults / enums) |
| `src/models/DiagnosticSyllabus.js` | New model per spec §4.6 | NEW |
| `src/models/DiagnosticSyllabus.test.js` | Schema validation tests | NEW |
| `src/services/diagnostic/specificsNormalizationService.js` | LLM-backed canonicalization of `specifics` (gpt-4o-mini, json_schema strict, 3 s timeout, raw fallback) | NEW |
| `src/services/diagnostic/specificsNormalizationService.test.js` | Tests with mocked OpenAI client | NEW |
| `src/controllers/onboardingController.js` | Existing controller | MODIFY (add `suggestTopics`, replace/extend `completeOnboarding`) |
| `src/controllers/onboardingController.test.js` | Integration tests for the two endpoints | NEW |
| `src/routes/onboarding.js` | Existing router | MODIFY (mount the two new routes) |
| `src/controllers/diagnosticSyllabusController.js` | Three syllabus endpoints (init, complete, status) | NEW |
| `src/controllers/diagnosticSyllabusController.test.js` | Integration tests with mocked S3 + queue | NEW |
| `src/routes/diagnostic.js` | Existing router | MODIFY (mount the three syllabus routes) |
| `scripts/migrate/setNeedsCalibration.js` | One-shot migration: flag pre-rebuild objectives | NEW |
| `scripts/migrate/setNeedsCalibration.test.js` | Test for the migration's pure function | NEW |

**Conventions:**
- All tests use `node:test` and `node:assert` (matches existing project convention).
- Tests run via `npm test` (which invokes `node scripts/run-tests.js`).
- All scripts are runnable via `node scripts/migrate/<script>.js` with a `--dry-run` flag for validation without writes.
- LLM calls always use `json_schema` strict response format with explicit timeouts. No retries in v1 — fall back to raw input on any error.
- Mongoose models are `delete require.cache[...]`'d in tests to force fresh load (matches existing pattern in `KnowledgeProfile.test.js`, `DiagnosticAttempt.test.js`).
- OpenAI is mocked by mutating `require.cache` for the `openai` module before requiring the service under test (matches existing pattern in `diagnosticPoolService.test.js`).

---

## Prerequisites

Before starting Task 1, the following must be true:

1. **Plan 1 (Phase 0.5 seed scripts) is complete and merged.** This plan depends on `TopicTaxonomy` and `CompanyProfile` models existing, plus the `DiagnosticQuestionBank` validation fields.
2. The backend repo at `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/` is on a clean working branch (no uncommitted changes).
3. `OPENAI_API_KEY` is set in `.env`.
4. MongoDB connection string in `.env`, S3 credentials present (`AWS_REGION`, `S3_BUCKET_NAME`, etc.) — already exist for the notes feature.
5. `node_modules` is installed (`npm install`).

Run from the backend repo root:
```bash
git checkout -b feat/diagnostic-phase2a-backend
git status   # verify clean
npm test     # verify baseline green before adding anything
```

---

## Task 1: Add `topicSelfRatings` Map to UserObjective

**Files:**
- Modify: `src/models/UserObjective.js`
- Create: `src/models/UserObjective.test.js` (no tests exist yet for this model)

- [ ] **Step 1: Write the failing test**

Create `src/models/UserObjective.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

delete require.cache[require.resolve('./UserObjective')];
const UserObjective = require('./UserObjective');

const baseDoc = () => ({
  userId: new mongoose.Types.ObjectId(),
  objectiveType: 'upskilling',
  timeline: '3_months',
  currentLevel: 'beginner',
  weeklyCommitHours: 5,
});

test('UserObjective: topicSelfRatings defaults to empty Map', () => {
  const doc = new UserObjective(baseDoc());
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.ok(doc.topicSelfRatings instanceof Map);
  assert.strictEqual(doc.topicSelfRatings.size, 0);
});

test('UserObjective: topicSelfRatings accepts valid proficiency levels', () => {
  const doc = new UserObjective({
    ...baseDoc(),
    topicSelfRatings: new Map([
      ['product-strategy', 'novice'],
      ['user-research', 'familiar'],
      ['roadmapping', 'proficient'],
      ['analytics', 'expert'],
    ]),
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.topicSelfRatings.get('product-strategy'), 'novice');
  assert.strictEqual(doc.topicSelfRatings.get('analytics'), 'expert');
});

test('UserObjective: topicSelfRatings rejects invalid proficiency level', () => {
  const doc = new UserObjective({
    ...baseDoc(),
    topicSelfRatings: new Map([['x', 'wizard']]),
  });
  const err = doc.validateSync();
  assert.ok(err, 'invalid enum should fail validation');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="UserObjective: topicSelfRatings"
```

Expected: FAIL — `topicSelfRatings` is undefined on the document; the second test errors because the Map field doesn't exist.

- [ ] **Step 3: Implement the field**

In `src/models/UserObjective.js`, immediately after the `topicsOfInterest` field (around line 48 — see `// --- Topics ---` comment) add:

```js
  topicSelfRatings: {
    type: Map,
    of: {
      type: String,
      enum: ['novice', 'familiar', 'proficient', 'expert'],
    },
    default: () => new Map(),
  },
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="UserObjective: topicSelfRatings"
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/UserObjective.js src/models/UserObjective.test.js
git commit -m "feat(diagnostic): add topicSelfRatings map to UserObjective"
```

---

## Task 2: Add `specificsCanonical` nested object to UserObjective

**Files:**
- Modify: `src/models/UserObjective.js`
- Modify: `src/models/UserObjective.test.js`

- [ ] **Step 1: Write the failing test**

Append to `src/models/UserObjective.test.js`:

```js
test('UserObjective: specificsCanonical defaults to empty subdoc', () => {
  const doc = new UserObjective(baseDoc());
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.ok(doc.specificsCanonical, 'subdoc should exist');
  assert.strictEqual(doc.specificsCanonical.examName, undefined);
});

test('UserObjective: specificsCanonical persists all six normalized fields', () => {
  const doc = new UserObjective({
    ...baseDoc(),
    specifics: { examName: 'jee', targetCompany: 'goog' },
    specificsCanonical: {
      examName: 'JEE Advanced',
      targetSkill: 'System Design',
      targetRole: 'Backend Engineer',
      targetCompany: 'Google',
      fromDomain: 'Frontend',
      toDomain: 'Backend',
    },
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.specificsCanonical.examName, 'JEE Advanced');
  assert.strictEqual(doc.specificsCanonical.targetCompany, 'Google');
  assert.strictEqual(doc.specificsCanonical.fromDomain, 'Frontend');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="UserObjective: specificsCanonical"
```

Expected: FAIL — `specificsCanonical` is undefined on the document.

- [ ] **Step 3: Implement the field**

In `src/models/UserObjective.js`, immediately after the existing `specifics: { ... }` block (around line 22) add:

```js
  specificsCanonical: {
    examName: { type: String, trim: true },
    targetSkill: { type: String, trim: true },
    targetRole: { type: String, trim: true },
    targetCompany: { type: String, trim: true },
    fromDomain: { type: String, trim: true },
    toDomain: { type: String, trim: true },
  },
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="UserObjective: specificsCanonical"
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/UserObjective.js src/models/UserObjective.test.js
git commit -m "feat(diagnostic): add specificsCanonical to UserObjective"
```

---

## Task 3: Add `needsCalibration` boolean to UserObjective

**Files:**
- Modify: `src/models/UserObjective.js`
- Modify: `src/models/UserObjective.test.js`

- [ ] **Step 1: Write the failing test**

Append to `src/models/UserObjective.test.js`:

```js
test('UserObjective: needsCalibration defaults to false', () => {
  const doc = new UserObjective(baseDoc());
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.needsCalibration, false);
});

test('UserObjective: needsCalibration accepts true', () => {
  const doc = new UserObjective({ ...baseDoc(), needsCalibration: true });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.needsCalibration, true);
});

test('UserObjective: needsCalibration coerces or rejects non-boolean', () => {
  const doc = new UserObjective({ ...baseDoc(), needsCalibration: 'yes' });
  // Mongoose coerces strings to boolean — assert never raw string.
  doc.validateSync();
  assert.notStrictEqual(typeof doc.needsCalibration, 'string');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="UserObjective: needsCalibration"
```

Expected: FAIL — `needsCalibration` undefined.

- [ ] **Step 3: Implement the field**

In `src/models/UserObjective.js`, immediately after the `topicSelfRatings` field added in Task 1, add:

```js
  needsCalibration: { type: Boolean, default: false, index: true },
```

The `index: true` lets the existing-user banner query (`{ needsCalibration: true }`) hit an index — this query runs on Home tab open for legacy users.

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="UserObjective: needsCalibration"
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/UserObjective.js src/models/UserObjective.test.js
git commit -m "feat(diagnostic): add needsCalibration flag to UserObjective"
```

---

## Task 4: Create the DiagnosticSyllabus model

**Files:**
- Create: `src/models/DiagnosticSyllabus.js`
- Create: `src/models/DiagnosticSyllabus.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/models/DiagnosticSyllabus.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

delete require.cache[require.resolve('./DiagnosticSyllabus')];
const DiagnosticSyllabus = require('./DiagnosticSyllabus');

const validDoc = () => ({
  userId: new mongoose.Types.ObjectId(),
  userObjectiveId: new mongoose.Types.ObjectId(),
  s3Key: 'syllabi/u123/abc.pdf',
  contentType: 'application/pdf',
  fileSizeBytes: 1024 * 512,
  contentHash: 'sha256-deadbeef',
});

test('DiagnosticSyllabus: defaults extractionStatus to pending', () => {
  const doc = new DiagnosticSyllabus(validDoc());
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.extractionStatus, 'pending');
  assert.deepStrictEqual(doc.extractedTopics.toObject(), []);
  assert.deepStrictEqual(doc.derivedQuestionIds.toObject(), []);
});

test('DiagnosticSyllabus: requires userId', () => {
  const d = validDoc();
  delete d.userId;
  const doc = new DiagnosticSyllabus(d);
  const err = doc.validateSync();
  assert.ok(err && err.errors.userId);
});

test('DiagnosticSyllabus: requires contentHash', () => {
  const d = validDoc();
  delete d.contentHash;
  const doc = new DiagnosticSyllabus(d);
  const err = doc.validateSync();
  assert.ok(err && err.errors.contentHash);
});

test('DiagnosticSyllabus: rejects invalid extractionStatus', () => {
  const doc = new DiagnosticSyllabus({ ...validDoc(), extractionStatus: 'wat' });
  const err = doc.validateSync();
  assert.ok(err && err.errors.extractionStatus);
});

test('DiagnosticSyllabus: stores extractedTopics subdocs', () => {
  const doc = new DiagnosticSyllabus({
    ...validDoc(),
    extractionStatus: 'completed',
    extractedText: 'Chapter 5: Mechanics. Newtons laws...',
    pageCount: 22,
    extractedTopics: [
      { canonicalName: 'newtons-laws', displayName: 'Newton\'s Laws', description: 'Three laws.' },
      { canonicalName: 'work-energy', displayName: 'Work & Energy', description: 'WE theorem.' },
    ],
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.extractedTopics.length, 2);
  assert.strictEqual(doc.extractedTopics[0].canonicalName, 'newtons-laws');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="DiagnosticSyllabus"
```

Expected: FAIL — `Cannot find module './DiagnosticSyllabus'`.

- [ ] **Step 3: Implement the model**

Create `src/models/DiagnosticSyllabus.js`:

```js
const mongoose = require('mongoose');

const EXTRACTION_STATUSES = ['pending', 'processing', 'completed', 'failed'];

const extractedTopicSchema = new mongoose.Schema(
  {
    canonicalName: { type: String, required: true },
    displayName: { type: String, required: true },
    description: { type: String, default: '' },
  },
  { _id: false }
);

const diagnosticSyllabusSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    userObjectiveId: { type: mongoose.Schema.Types.ObjectId, ref: 'UserObjective', required: true },
    s3Key: { type: String, required: true },
    contentType: { type: String, required: true },
    fileSizeBytes: { type: Number, required: true, min: 0 },
    contentHash: { type: String, required: true },
    extractionStatus: { type: String, enum: EXTRACTION_STATUSES, default: 'pending', index: true },
    extractedText: { type: String, default: '' },
    pageCount: { type: Number, default: 0 },
    extractedTopics: { type: [extractedTopicSchema], default: [] },
    derivedQuestionIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'DiagnosticQuestionBank' }],
    reusedFromHash: { type: String, default: null },
    failureReason: { type: String, default: null },
    completedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

diagnosticSyllabusSchema.index({ userId: 1, createdAt: -1 });
diagnosticSyllabusSchema.index({ contentHash: 1 }, { unique: true });

module.exports = mongoose.model('DiagnosticSyllabus', diagnosticSyllabusSchema);
module.exports.EXTRACTION_STATUSES = EXTRACTION_STATUSES;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="DiagnosticSyllabus"
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/DiagnosticSyllabus.js src/models/DiagnosticSyllabus.test.js
git commit -m "feat(diagnostic): add DiagnosticSyllabus model"
```

---

## Task 5: Build the specifics normalization service

**Files:**
- Create: `src/services/diagnostic/specificsNormalizationService.js`
- Create: `src/services/diagnostic/specificsNormalizationService.test.js`

**Behaviour contract:**
- Input: `{ objectiveType, specifics: { examName?, targetSkill?, targetRole?, targetCompany?, fromDomain?, toDomain? } }`.
- Output: `{ examName?, targetSkill?, targetRole?, targetCompany?, fromDomain?, toDomain? }` — same keys, all values normalized to canonical proper-cased forms (e.g. `"jee"` → `"JEE Advanced"`, `"goog"` → `"Google"`).
- Hard 3 s timeout on the LLM call (use AbortController).
- On any error (timeout, parse failure, network, missing key) — fall back to returning the raw input unchanged. Log a `console.warn` with reason. Never throw.
- LLM: `gpt-4o-mini`, `response_format: { type: 'json_schema', strict: true, ... }`, temperature 0.

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/specificsNormalizationService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');

const SERVICE_PATH = path.resolve(__dirname, './specificsNormalizationService.js');

function loadServiceWith(mockOpenAI) {
  delete require.cache[SERVICE_PATH];
  // Mock the openai module the service requires.
  const openaiModulePath = require.resolve('openai');
  delete require.cache[openaiModulePath];
  require.cache[openaiModulePath] = {
    id: openaiModulePath,
    filename: openaiModulePath,
    loaded: true,
    exports: mockOpenAI,
  };
  return require(SERVICE_PATH);
}

const makeOpenAIMock = (impl) => {
  function MockOpenAI() {
    this.chat = { completions: { create: impl } };
  }
  return { OpenAI: MockOpenAI, default: MockOpenAI };
};

test('normalizeSpecifics: returns canonical fields from LLM response', async () => {
  const mock = makeOpenAIMock(async () => ({
    choices: [{
      message: {
        content: JSON.stringify({
          examName: 'JEE Advanced',
          targetCompany: 'Google',
        }),
      },
    }],
  }));
  const svc = loadServiceWith(mock);
  const out = await svc.normalizeSpecifics({
    objectiveType: 'exam_preparation',
    specifics: { examName: 'jee', targetCompany: 'goog' },
  });
  assert.strictEqual(out.examName, 'JEE Advanced');
  assert.strictEqual(out.targetCompany, 'Google');
});

test('normalizeSpecifics: returns raw input when LLM throws', async () => {
  const mock = makeOpenAIMock(async () => { throw new Error('boom'); });
  const svc = loadServiceWith(mock);
  const raw = { examName: 'jee', targetCompany: 'goog' };
  const out = await svc.normalizeSpecifics({
    objectiveType: 'exam_preparation',
    specifics: raw,
  });
  assert.deepStrictEqual(out, raw);
});

test('normalizeSpecifics: returns raw input when LLM returns invalid JSON', async () => {
  const mock = makeOpenAIMock(async () => ({
    choices: [{ message: { content: 'not json {{' } }],
  }));
  const svc = loadServiceWith(mock);
  const raw = { targetSkill: 'sys design' };
  const out = await svc.normalizeSpecifics({
    objectiveType: 'upskilling',
    specifics: raw,
  });
  assert.deepStrictEqual(out, raw);
});

test('normalizeSpecifics: returns empty object when input has no fields', async () => {
  const mock = makeOpenAIMock(async () => {
    throw new Error('should not be called');
  });
  const svc = loadServiceWith(mock);
  const out = await svc.normalizeSpecifics({
    objectiveType: 'casual_learning',
    specifics: {},
  });
  assert.deepStrictEqual(out, {});
});

test('normalizeSpecifics: returns raw input when LLM exceeds 3s timeout', async () => {
  const mock = makeOpenAIMock(async (_args, opts) => {
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => resolve({ choices: [{ message: { content: '{}' } }] }), 5000);
      if (opts && opts.signal) {
        opts.signal.addEventListener('abort', () => {
          clearTimeout(t);
          const err = new Error('Aborted');
          err.name = 'AbortError';
          reject(err);
        });
      }
    });
  });
  const svc = loadServiceWith(mock);
  const raw = { examName: 'cat' };
  const out = await svc.normalizeSpecifics({
    objectiveType: 'exam_preparation',
    specifics: raw,
  });
  assert.deepStrictEqual(out, raw);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="normalizeSpecifics"
```

Expected: FAIL — `Cannot find module './specificsNormalizationService'`.

- [ ] **Step 3: Implement the service**

Create `src/services/diagnostic/specificsNormalizationService.js`:

```js
const { OpenAI } = require('openai');

const TIMEOUT_MS = 3000;
const MODEL = 'gpt-4o-mini';

const SCHEMA = {
  name: 'normalized_specifics',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    properties: {
      examName: { type: ['string', 'null'] },
      targetSkill: { type: ['string', 'null'] },
      targetRole: { type: ['string', 'null'] },
      targetCompany: { type: ['string', 'null'] },
      fromDomain: { type: ['string', 'null'] },
      toDomain: { type: ['string', 'null'] },
    },
    required: ['examName', 'targetSkill', 'targetRole', 'targetCompany', 'fromDomain', 'toDomain'],
  },
};

let _client = null;
function client() {
  if (!_client) _client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  return _client;
}

function hasAnyValue(obj) {
  return obj && Object.values(obj).some((v) => typeof v === 'string' && v.trim().length > 0);
}

function stripNulls(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (typeof v === 'string' && v.trim()) out[k] = v.trim();
  }
  return out;
}

const SYSTEM_PROMPT = `You are a normalization helper for an Indian learning app.
Given a user's onboarding "specifics" (free-text fields they typed), return canonical, properly-cased forms.
Examples:
  "jee" -> "JEE Advanced"
  "goog" / "google india" -> "Google"
  "sys design" -> "System Design"
  "fe" -> "Frontend"
  "ml engineer" -> "Machine Learning Engineer"
Preserve the field semantics. Use null for fields the user did not provide.
For any field you cannot confidently normalize, return the user's input verbatim (do NOT invent values).`;

async function normalizeSpecifics({ objectiveType, specifics }) {
  const raw = specifics || {};
  if (!hasAnyValue(raw)) return {};

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const resp = await client().chat.completions.create({
      model: MODEL,
      temperature: 0,
      response_format: { type: 'json_schema', json_schema: SCHEMA },
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        {
          role: 'user',
          content: JSON.stringify({ objectiveType, specifics: raw }),
        },
      ],
    }, { signal: controller.signal });

    clearTimeout(timer);

    const content = resp && resp.choices && resp.choices[0] && resp.choices[0].message && resp.choices[0].message.content;
    if (!content) {
      console.warn('[specificsNormalization] empty LLM content, falling back to raw');
      return stripNulls(raw);
    }
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.warn('[specificsNormalization] JSON parse failed, falling back to raw:', e.message);
      return stripNulls(raw);
    }
    return stripNulls(parsed);
  } catch (err) {
    clearTimeout(timer);
    console.warn('[specificsNormalization] LLM call failed, falling back to raw:', err.message);
    return stripNulls(raw);
  }
}

module.exports = { normalizeSpecifics };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="normalizeSpecifics"
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnostic/specificsNormalizationService.js src/services/diagnostic/specificsNormalizationService.test.js
git commit -m "feat(diagnostic): add LLM-backed specifics normalization service"
```

---

## Task 6: Add cleanup fields to DiagnosticAttempt

Per spec §4.4: add `insightsJson`, `planGenerationStatus` (enum), `attemptType`, `previousAttemptId`. The spec also calls out standardizing the existing Map-shaped fields (`selfRatings`, `answers`, `results`) — those standardizations are already represented in the current model and are out of scope for this plan; this task only ADDS the four missing fields.

**Files:**
- Modify: `src/models/DiagnosticAttempt.js`
- Modify: `src/models/DiagnosticAttempt.test.js`

- [ ] **Step 1: Write the failing test**

Append to `src/models/DiagnosticAttempt.test.js`:

```js
test('DiagnosticAttempt: insightsJson defaults to null', () => {
  delete require.cache[require.resolve('./DiagnosticAttempt')];
  const DA = require('./DiagnosticAttempt');
  const doc = new DA({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'new_user',
  });
  doc.validateSync();
  assert.strictEqual(doc.insightsJson, null);
});

test('DiagnosticAttempt: planGenerationStatus defaults to pending', () => {
  delete require.cache[require.resolve('./DiagnosticAttempt')];
  const DA = require('./DiagnosticAttempt');
  const doc = new DA({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'new_user',
  });
  doc.validateSync();
  assert.strictEqual(doc.planGenerationStatus, 'pending');
});

test('DiagnosticAttempt: planGenerationStatus rejects invalid value', () => {
  delete require.cache[require.resolve('./DiagnosticAttempt')];
  const DA = require('./DiagnosticAttempt');
  const doc = new DA({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'new_user',
    planGenerationStatus: 'maybe',
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.planGenerationStatus);
});

test('DiagnosticAttempt: attemptType defaults to initial', () => {
  delete require.cache[require.resolve('./DiagnosticAttempt')];
  const DA = require('./DiagnosticAttempt');
  const doc = new DA({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'new_user',
  });
  doc.validateSync();
  assert.strictEqual(doc.attemptType, 'initial');
});

test('DiagnosticAttempt: attemptType accepts recalibration with previousAttemptId', () => {
  delete require.cache[require.resolve('./DiagnosticAttempt')];
  const DA = require('./DiagnosticAttempt');
  const prev = new mongoose.Types.ObjectId();
  const doc = new DA({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'existing_user_tune',
    attemptType: 'recalibration',
    previousAttemptId: prev,
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(String(doc.previousAttemptId), String(prev));
});

test('DiagnosticAttempt: attemptType rejects invalid enum value', () => {
  delete require.cache[require.resolve('./DiagnosticAttempt')];
  const DA = require('./DiagnosticAttempt');
  const doc = new DA({
    userId: new mongoose.Types.ObjectId(),
    flowType: 'new_user',
    attemptType: 'practice',
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.attemptType);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="DiagnosticAttempt: (insightsJson|planGenerationStatus|attemptType)"
```

Expected: FAIL — fields undefined / not enum-validated.

- [ ] **Step 3: Implement the field additions**

In `src/models/DiagnosticAttempt.js`, inside the main schema object (just before `}, { timestamps: true });` if present, otherwise at the end of the field list before `module.exports`), add:

```js
  // --- Insights & plan handoff (spec §4.4) ---
  insightsJson: {
    type: mongoose.Schema.Types.Mixed,
    default: null,
  },
  planGenerationStatus: {
    type: String,
    enum: ['pending', 'generating', 'ready', 'failed'],
    default: 'pending',
    index: true,
  },

  // --- Attempt provenance (spec §3.5 / §4.4) ---
  attemptType: {
    type: String,
    enum: ['initial', 'recalibration'],
    default: 'initial',
    index: true,
  },
  previousAttemptId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'DiagnosticAttempt',
    default: null,
  },
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="DiagnosticAttempt: (insightsJson|planGenerationStatus|attemptType)"
```

Expected: 6 tests pass. Run the full file too — `npm test -- src/models/DiagnosticAttempt.test.js` — and verify no pre-existing tests broke.

- [ ] **Step 5: Commit**

```bash
git add src/models/DiagnosticAttempt.js src/models/DiagnosticAttempt.test.js
git commit -m "feat(diagnostic): add insights/plan/recalibration fields to DiagnosticAttempt"
```

---

## Task 7: Topic suggestion endpoint (`POST /onboarding/topics/suggest`)

Per spec §12.1: given `{ objectiveType, specifics, targetCompany? }`, return suggested topics from the seeded `TopicTaxonomy`. The spec calls for triggering LLM generation when no entry exists — **for this plan, return HTTP 404 with a `code: 'TAXONOMY_MISSING'` body so the frontend can show a graceful empty state**. Realtime LLM generation is owned by Plan 3a; this controller will be extended there.

**Files:**
- Modify: `src/controllers/onboardingController.js` (add `suggestTopics` exported handler)
- Modify: `src/routes/onboarding.js` (mount the route)
- Create: `src/controllers/onboardingController.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/controllers/onboardingController.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');

const CONTROLLER_PATH = path.resolve(__dirname, './onboardingController.js');

function buildReqRes({ body = {}, params = {}, user = { _id: 'u1' } } = {}) {
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  return [{ body, params, user }, res];
}

// Stub the TopicTaxonomy model so we don't hit Mongo.
function stubModel(modelRelPath, stub) {
  const abs = require.resolve(path.resolve(__dirname, '..', 'models', modelRelPath));
  delete require.cache[abs];
  require.cache[abs] = { id: abs, filename: abs, loaded: true, exports: stub };
}

function loadController() {
  delete require.cache[CONTROLLER_PATH];
  return require(CONTROLLER_PATH);
}

test('suggestTopics: returns 400 when objectiveType missing', async () => {
  stubModel('TopicTaxonomy', { findOne: async () => null });
  const ctrl = loadController();
  const [req, res] = buildReqRes({ body: { specifics: {} } });
  await ctrl.suggestTopics(req, res);
  assert.strictEqual(res.statusCode, 400);
});

test('suggestTopics: returns 404 with TAXONOMY_MISSING when no entry', async () => {
  stubModel('TopicTaxonomy', { findOne: async () => null });
  const ctrl = loadController();
  const [req, res] = buildReqRes({
    body: { objectiveType: 'upskilling', specifics: { targetSkill: 'Product Management' } },
  });
  await ctrl.suggestTopics(req, res);
  assert.strictEqual(res.statusCode, 404);
  assert.strictEqual(res.body.code, 'TAXONOMY_MISSING');
});

test('suggestTopics: returns topics when taxonomy exists', async () => {
  const fakeTopics = [
    { name: 'Product Strategy', canonicalName: 'product-strategy', description: 'd', baseDifficulty: 'intermediate', isFutureProofing: false, sortOrder: 1 },
    { name: 'AI for PMs', canonicalName: 'ai-for-pms', description: 'd', baseDifficulty: 'foundational', isFutureProofing: true, sortOrder: 2 },
  ];
  stubModel('TopicTaxonomy', {
    findOne: async ({ objectiveType, targetKey }) => {
      assert.strictEqual(objectiveType, 'upskilling');
      assert.ok(targetKey.startsWith('upskilling::'));
      return { topics: fakeTopics, source: 'curated' };
    },
  });
  const ctrl = loadController();
  const [req, res] = buildReqRes({
    body: { objectiveType: 'upskilling', specifics: { targetSkill: 'Product Management' } },
  });
  await ctrl.suggestTopics(req, res);
  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.topics.length, 2);
  assert.strictEqual(res.body.source, 'curated');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="suggestTopics"
```

Expected: FAIL — `ctrl.suggestTopics is not a function`.

- [ ] **Step 3: Implement the controller handler**

In `src/controllers/onboardingController.js`, add (do not remove existing exports):

```js
const TopicTaxonomy = require('../models/TopicTaxonomy');

// Build a deterministic taxonomy lookup key.
// Mirrors Plan 1's targetKey convention: '<objectiveType>::<slug>'.
function buildTargetKey(objectiveType, specifics, targetCompany) {
  const slugify = (s) => String(s || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

  const parts = [];
  if (specifics) {
    if (specifics.examName) parts.push(slugify(specifics.examName));
    else if (specifics.targetSkill) parts.push(slugify(specifics.targetSkill));
    else if (specifics.targetRole) parts.push(slugify(specifics.targetRole));
    else if (specifics.toDomain) parts.push(slugify(specifics.toDomain));
  }
  if (targetCompany) parts.push(slugify(targetCompany));
  const tail = parts.filter(Boolean).join('-') || 'general';
  return `${objectiveType}::${tail}`;
}

exports.suggestTopics = async function suggestTopics(req, res) {
  const { objectiveType, specifics = {}, targetCompany } = req.body || {};
  if (!objectiveType) {
    return res.status(400).json({ error: 'objectiveType required' });
  }
  const targetKey = buildTargetKey(objectiveType, specifics, targetCompany);
  const entry = await TopicTaxonomy.findOne({ objectiveType, targetKey });
  if (!entry) {
    // NOTE: Plan 3a will extend this to trigger realtime LLM generation here.
    return res.status(404).json({
      code: 'TAXONOMY_MISSING',
      message: 'No taxonomy entry yet for this objective + specifics. LLM generation arrives in Plan 3a.',
      targetKey,
    });
  }
  return res.status(200).json({
    targetKey,
    source: entry.source,
    topics: entry.topics,
  });
};

exports._buildTargetKey = buildTargetKey; // exported for testing
```

- [ ] **Step 4: Mount the route**

In `src/routes/onboarding.js`, add (preserve existing routes):

```js
const onboardingController = require('../controllers/onboardingController');
// ... existing routes ...
router.post('/topics/suggest', onboardingController.suggestTopics);
```

If the file uses `authMiddleware` for protected routes, follow the same pattern used by other onboarding routes. Confirm by reading the file before editing.

- [ ] **Step 5: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="suggestTopics"
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/controllers/onboardingController.js src/controllers/onboardingController.test.js src/routes/onboarding.js
git commit -m "feat(onboarding): topic suggestion endpoint backed by TopicTaxonomy"
```

---

## Task 8: Onboarding completion endpoint (`POST /onboarding/complete`)

Per spec §12.1: atomic save of all onboarding data with normalization pass. Single endpoint that:

1. Validates the payload (`objectiveType`, `timeline`, `currentLevel`, `weeklyCommitHours`, `topicsOfInterest`, `topicSelfRatings`, `specifics?`).
2. Calls `specificsNormalizationService.normalizeSpecifics()` to produce `specificsCanonical` (best-effort; if it falls back, that's fine).
3. Upserts `UserObjective` for `(userId, isPrimary: true)` — one objective per user in v1.
4. Returns `{ userObjectiveId }`.

**Files:**
- Modify: `src/controllers/onboardingController.js` (add `completeOnboarding`)
- Modify: `src/routes/onboarding.js` (mount the route)
- Modify: `src/controllers/onboardingController.test.js`

- [ ] **Step 1: Write the failing test**

Append to `src/controllers/onboardingController.test.js`:

```js
function stubService(relPath, stub) {
  const abs = require.resolve(path.resolve(__dirname, '..', 'services', relPath));
  delete require.cache[abs];
  require.cache[abs] = { id: abs, filename: abs, loaded: true, exports: stub };
}

test('completeOnboarding: 400 when required fields missing', async () => {
  stubModel('UserObjective', class {});
  stubService('diagnostic/specificsNormalizationService', { normalizeSpecifics: async () => ({}) });
  const ctrl = loadController();
  const [req, res] = buildReqRes({ body: { objectiveType: 'upskilling' } });
  await ctrl.completeOnboarding(req, res);
  assert.strictEqual(res.statusCode, 400);
});

test('completeOnboarding: persists, normalizes, returns userObjectiveId', async () => {
  let captured = null;

  // Fake UserObjective acts like a Mongoose model: `findOneAndUpdate` returns a plain doc.
  const FakeUO = {
    findOneAndUpdate: async (filter, update, opts) => {
      captured = { filter, update, opts };
      return { _id: 'objective-id-xyz', ...update.$set };
    },
  };
  stubModel('UserObjective', FakeUO);
  stubService('diagnostic/specificsNormalizationService', {
    normalizeSpecifics: async ({ specifics }) => {
      // Returns canonical version.
      return { ...specifics, examName: specifics.examName ? 'JEE Advanced' : undefined };
    },
  });

  const ctrl = loadController();
  const [req, res] = buildReqRes({
    user: { _id: 'user-1' },
    body: {
      objectiveType: 'exam_preparation',
      timeline: '6_months',
      currentLevel: 'beginner',
      weeklyCommitHours: 8,
      topicsOfInterest: ['mechanics', 'thermodynamics'],
      topicSelfRatings: { mechanics: 'familiar', thermodynamics: 'novice' },
      specifics: { examName: 'jee' },
    },
  });
  await ctrl.completeOnboarding(req, res);

  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.userObjectiveId, 'objective-id-xyz');
  assert.strictEqual(captured.filter.userId, 'user-1');
  assert.strictEqual(captured.update.$set.specificsCanonical.examName, 'JEE Advanced');
  assert.strictEqual(captured.update.$set.topicSelfRatings.mechanics, 'familiar');
  assert.strictEqual(captured.update.$set.needsCalibration, false);
});

test('completeOnboarding: still saves even if normalization throws', async () => {
  const FakeUO = {
    findOneAndUpdate: async (_f, update) => ({ _id: 'oid', ...update.$set }),
  };
  stubModel('UserObjective', FakeUO);
  stubService('diagnostic/specificsNormalizationService', {
    normalizeSpecifics: async () => { throw new Error('llm down'); },
  });
  const ctrl = loadController();
  const [req, res] = buildReqRes({
    user: { _id: 'user-1' },
    body: {
      objectiveType: 'upskilling',
      timeline: '3_months',
      currentLevel: 'intermediate',
      weeklyCommitHours: 6,
      topicsOfInterest: ['x'],
      topicSelfRatings: { x: 'novice' },
      specifics: { targetSkill: 'PM' },
    },
  });
  await ctrl.completeOnboarding(req, res);
  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.userObjectiveId, 'oid');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="completeOnboarding"
```

Expected: FAIL — handler not exported.

- [ ] **Step 3: Implement the handler**

Append to `src/controllers/onboardingController.js`:

```js
const UserObjective = require('../models/UserObjective');
const { normalizeSpecifics } = require('../services/diagnostic/specificsNormalizationService');

const REQUIRED_FIELDS = ['objectiveType', 'timeline', 'currentLevel', 'weeklyCommitHours', 'topicsOfInterest', 'topicSelfRatings'];

exports.completeOnboarding = async function completeOnboarding(req, res) {
  const userId = req.user && req.user._id;
  if (!userId) return res.status(401).json({ error: 'unauthenticated' });

  const body = req.body || {};
  const missing = REQUIRED_FIELDS.filter((f) => body[f] === undefined || body[f] === null);
  if (missing.length) {
    return res.status(400).json({ error: 'missing fields', fields: missing });
  }

  // Best-effort normalization. Service has its own internal fallback, but we still
  // wrap in try/catch as belt-and-braces: nothing should block onboarding completion.
  let specificsCanonical = {};
  try {
    specificsCanonical = await normalizeSpecifics({
      objectiveType: body.objectiveType,
      specifics: body.specifics || {},
    });
  } catch (err) {
    console.warn('[onboarding.complete] normalization threw, continuing without canonical specifics:', err.message);
    specificsCanonical = body.specifics || {};
  }

  const $set = {
    userId,
    objectiveType: body.objectiveType,
    timeline: body.timeline,
    currentLevel: body.currentLevel,
    weeklyCommitHours: body.weeklyCommitHours,
    topicsOfInterest: body.topicsOfInterest,
    topicSelfRatings: body.topicSelfRatings,
    specifics: body.specifics || {},
    specificsCanonical,
    needsCalibration: false, // freshly onboarded user has self-ratings
    isPrimary: true,
    status: 'active',
  };
  if (body.preferredLearningStyle) $set.preferredLearningStyle = body.preferredLearningStyle;
  if (body.targetDate) $set.targetDate = body.targetDate;

  const saved = await UserObjective.findOneAndUpdate(
    { userId, isPrimary: true },
    { $set },
    { new: true, upsert: true, setDefaultsOnInsert: true }
  );

  return res.status(200).json({ userObjectiveId: saved._id });
};
```

- [ ] **Step 4: Mount the route**

In `src/routes/onboarding.js`, add:

```js
router.post('/complete', authMiddleware, onboardingController.completeOnboarding);
```

(Use whatever auth middleware name the file already imports — match the existing pattern.)

- [ ] **Step 5: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="completeOnboarding"
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/controllers/onboardingController.js src/controllers/onboardingController.test.js src/routes/onboarding.js
git commit -m "feat(onboarding): atomic complete endpoint with specifics normalization"
```

---

## Task 9: Syllabus upload endpoints (init / complete / status)

Per spec §3.6 + §12.5: three endpoints that gate-keep syllabus upload, hand off to the existing OCR worker, and let the client poll status.

**Files:**
- Create: `src/controllers/diagnosticSyllabusController.js`
- Create: `src/controllers/diagnosticSyllabusController.test.js`
- Modify: `src/routes/diagnostic.js` (mount three routes)

**Endpoint contracts:**

| Endpoint | Body | Returns |
|---|---|---|
| `POST /diagnostic/syllabus/upload-init` | `{ userObjectiveId, contentType, fileSizeBytes }` | `{ syllabusId, uploadUrl, s3Key }` |
| `POST /diagnostic/syllabus/:id/complete` | `{ contentHash }` | `{ status: 'processing' }` (queues extraction) |
| `GET /diagnostic/syllabus/:id/status` | — | `{ status, extractedTopics?, failureReason? }` |

Reuse existing `src/config/s3.js#generateUploadURL` and existing OCR queue from `src/config/queue.js`.

- [ ] **Step 1: Write the failing test**

Create `src/controllers/diagnosticSyllabusController.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');

const CTRL_PATH = path.resolve(__dirname, './diagnosticSyllabusController.js');

function buildReqRes({ body = {}, params = {}, user = { _id: 'u1' } } = {}) {
  const res = {
    statusCode: 200, body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  return [{ body, params, user }, res];
}

function stubAt(absPath, exports_) {
  delete require.cache[absPath];
  require.cache[absPath] = { id: absPath, filename: absPath, loaded: true, exports: exports_ };
}

function loadCtrl({ s3, queue, model }) {
  stubAt(require.resolve(path.resolve(__dirname, '..', 'config', 's3.js')), s3 || {
    generateUploadURL: async () => ({ uploadURL: 'https://s3/url', key: 's3/key/abc' }),
  });
  stubAt(require.resolve(path.resolve(__dirname, '..', 'config', 'queue.js')), queue || {
    ocrProcessingQueue: { add: async () => ({ id: 'job-1' }) },
  });
  stubAt(require.resolve(path.resolve(__dirname, '..', 'models', 'DiagnosticSyllabus.js')), model);
  delete require.cache[CTRL_PATH];
  return require(CTRL_PATH);
}

test('initSyllabusUpload: 400 when fileSizeBytes missing', async () => {
  const created = [];
  const FakeModel = class { constructor(d) { Object.assign(this, d); } async save() { this._id = 'syl-1'; created.push(this); return this; } };
  const ctrl = loadCtrl({ model: FakeModel });
  const [req, res] = buildReqRes({ body: { userObjectiveId: 'o1', contentType: 'application/pdf' } });
  await ctrl.initSyllabusUpload(req, res);
  assert.strictEqual(res.statusCode, 400);
});

test('initSyllabusUpload: returns presigned URL + creates DiagnosticSyllabus', async () => {
  const saved = [];
  const FakeModel = class {
    constructor(d) { Object.assign(this, d); }
    async save() { this._id = 'syl-1'; saved.push(this); return this; }
  };
  const s3Calls = [];
  const ctrl = loadCtrl({
    model: FakeModel,
    s3: { generateUploadURL: async (...args) => { s3Calls.push(args); return { uploadURL: 'https://s3/up', key: 's3/key/xyz' }; } },
  });
  const [req, res] = buildReqRes({
    user: { _id: 'u1' },
    body: { userObjectiveId: 'obj-1', contentType: 'application/pdf', fileSizeBytes: 1024 },
  });
  await ctrl.initSyllabusUpload(req, res);
  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.syllabusId, 'syl-1');
  assert.strictEqual(res.body.uploadUrl, 'https://s3/up');
  assert.strictEqual(res.body.s3Key, 's3/key/xyz');
  assert.strictEqual(saved.length, 1);
  assert.strictEqual(saved[0].extractionStatus, 'pending');
});

test('completeSyllabusUpload: queues extraction and marks processing', async () => {
  const updated = [];
  const FakeModel = {
    findOneAndUpdate: async (filter, update) => {
      updated.push({ filter, update });
      return { _id: filter._id, extractionStatus: update.$set.extractionStatus, contentHash: update.$set.contentHash };
    },
  };
  const queueAdds = [];
  const ctrl = loadCtrl({
    model: FakeModel,
    queue: { ocrProcessingQueue: { add: async (name, payload) => { queueAdds.push({ name, payload }); return { id: 'job-1' }; } } },
  });
  const [req, res] = buildReqRes({
    user: { _id: 'u1' },
    params: { id: 'syl-1' },
    body: { contentHash: 'sha256-abc' },
  });
  await ctrl.completeSyllabusUpload(req, res);
  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.status, 'processing');
  assert.strictEqual(updated[0].update.$set.extractionStatus, 'processing');
  assert.strictEqual(queueAdds.length, 1);
  assert.strictEqual(queueAdds[0].payload.syllabusId, 'syl-1');
});

test('completeSyllabusUpload: 404 when syllabus not found / not owned', async () => {
  const FakeModel = { findOneAndUpdate: async () => null };
  const ctrl = loadCtrl({ model: FakeModel });
  const [req, res] = buildReqRes({ params: { id: 'syl-x' }, body: { contentHash: 'h' } });
  await ctrl.completeSyllabusUpload(req, res);
  assert.strictEqual(res.statusCode, 404);
});

test('getSyllabusStatus: returns status + topics when completed', async () => {
  const FakeModel = {
    findOne: async () => ({
      _id: 'syl-1',
      extractionStatus: 'completed',
      extractedTopics: [{ canonicalName: 'a', displayName: 'A', description: 'd' }],
      failureReason: null,
    }),
  };
  const ctrl = loadCtrl({ model: FakeModel });
  const [req, res] = buildReqRes({ params: { id: 'syl-1' } });
  await ctrl.getSyllabusStatus(req, res);
  assert.strictEqual(res.statusCode, 200);
  assert.strictEqual(res.body.status, 'completed');
  assert.strictEqual(res.body.extractedTopics.length, 1);
});

test('getSyllabusStatus: 404 when not found', async () => {
  const FakeModel = { findOne: async () => null };
  const ctrl = loadCtrl({ model: FakeModel });
  const [req, res] = buildReqRes({ params: { id: 'syl-x' } });
  await ctrl.getSyllabusStatus(req, res);
  assert.strictEqual(res.statusCode, 404);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="initSyllabusUpload|completeSyllabusUpload|getSyllabusStatus"
```

Expected: FAIL — `Cannot find module './diagnosticSyllabusController'`.

- [ ] **Step 3: Implement the controller**

Create `src/controllers/diagnosticSyllabusController.js`:

```js
const crypto = require('crypto');
const DiagnosticSyllabus = require('../models/DiagnosticSyllabus');
const { generateUploadURL } = require('../config/s3');
const { ocrProcessingQueue } = require('../config/queue');

const ALLOWED_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/heic',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation', // pptx
  'application/vnd.ms-powerpoint', // ppt
]);
const MAX_BYTES = 4 * 1024 * 1024 * 1024; // 4 GB per spec

exports.initSyllabusUpload = async function initSyllabusUpload(req, res) {
  const userId = req.user && req.user._id;
  if (!userId) return res.status(401).json({ error: 'unauthenticated' });

  const { userObjectiveId, contentType, fileSizeBytes } = req.body || {};
  if (!userObjectiveId || !contentType || typeof fileSizeBytes !== 'number') {
    return res.status(400).json({ error: 'userObjectiveId, contentType, fileSizeBytes required' });
  }
  if (!ALLOWED_TYPES.has(contentType)) {
    return res.status(415).json({ error: 'unsupported content type', contentType });
  }
  if (fileSizeBytes <= 0 || fileSizeBytes > MAX_BYTES) {
    return res.status(413).json({ error: 'file too large', maxBytes: MAX_BYTES });
  }

  const ext = contentType.split('/')[1] || 'bin';
  const objectKey = `syllabi/${userId}/${Date.now()}-${crypto.randomBytes(6).toString('hex')}.${ext}`;
  const { uploadURL, key } = await generateUploadURL(objectKey, contentType);

  // Pre-create the doc with a placeholder contentHash so we can return its id immediately.
  // The hash is replaced on complete.
  const placeholderHash = `pending:${objectKey}`;
  const doc = new DiagnosticSyllabus({
    userId,
    userObjectiveId,
    s3Key: key,
    contentType,
    fileSizeBytes,
    contentHash: placeholderHash,
    extractionStatus: 'pending',
  });
  await doc.save();

  return res.status(200).json({
    syllabusId: doc._id,
    uploadUrl: uploadURL,
    s3Key: key,
  });
};

exports.completeSyllabusUpload = async function completeSyllabusUpload(req, res) {
  const userId = req.user && req.user._id;
  if (!userId) return res.status(401).json({ error: 'unauthenticated' });

  const { id } = req.params;
  const { contentHash } = req.body || {};
  if (!contentHash) return res.status(400).json({ error: 'contentHash required' });

  // Cache lookup: if another user already extracted this exact file, mark as a cache reuse.
  const cached = await DiagnosticSyllabus.findOne({
    contentHash,
    extractionStatus: 'completed',
  }).lean();

  const updated = await DiagnosticSyllabus.findOneAndUpdate(
    { _id: id, userId },
    {
      $set: {
        contentHash,
        extractionStatus: cached ? 'completed' : 'processing',
        ...(cached
          ? {
              extractedText: cached.extractedText,
              extractedTopics: cached.extractedTopics,
              pageCount: cached.pageCount,
              reusedFromHash: cached.contentHash,
              completedAt: new Date(),
            }
          : {}),
      },
    },
    { new: true }
  );
  if (!updated) return res.status(404).json({ error: 'syllabus not found' });

  if (!cached) {
    await ocrProcessingQueue.add('extract-syllabus', {
      syllabusId: String(updated._id),
      userId: String(userId),
      s3Key: updated.s3Key,
      contentType: updated.contentType,
    });
  }

  return res.status(200).json({
    status: updated.extractionStatus,
    cacheHit: Boolean(cached),
  });
};

exports.getSyllabusStatus = async function getSyllabusStatus(req, res) {
  const userId = req.user && req.user._id;
  if (!userId) return res.status(401).json({ error: 'unauthenticated' });
  const doc = await DiagnosticSyllabus.findOne({ _id: req.params.id, userId }).lean();
  if (!doc) return res.status(404).json({ error: 'syllabus not found' });
  return res.status(200).json({
    status: doc.extractionStatus,
    extractedTopics: doc.extractedTopics || [],
    failureReason: doc.failureReason || null,
  });
};
```

- [ ] **Step 4: Mount the routes**

In `src/routes/diagnostic.js`, add:

```js
const syllabusController = require('../controllers/diagnosticSyllabusController');
// ... existing routes ...
router.post('/syllabus/upload-init', authMiddleware, syllabusController.initSyllabusUpload);
router.post('/syllabus/:id/complete', authMiddleware, syllabusController.completeSyllabusUpload);
router.get('/syllabus/:id/status', authMiddleware, syllabusController.getSyllabusStatus);
```

(Match the auth middleware name in use elsewhere in the file.)

> **Worker note (out of scope for this plan):** the `extract-syllabus` job processed by `src/workers/ocrProcessor.js` — the worker handler that turns extracted text into topics + questions is implemented in Plan 3a. For now, queueing is enough; the worker may simply log + no-op until Plan 3a ships.

- [ ] **Step 5: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="initSyllabusUpload|completeSyllabusUpload|getSyllabusStatus"
```

Expected: 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/controllers/diagnosticSyllabusController.js src/controllers/diagnosticSyllabusController.test.js src/routes/diagnostic.js
git commit -m "feat(diagnostic): syllabus upload endpoints (init/complete/status)"
```

---

## Task 10: Existing-user migration script (`setNeedsCalibration`)

Per spec §3.4: every existing `UserObjective` without `topicSelfRatings` (or with an empty Map) gets `needsCalibration: true`. Idempotent. Supports `--dry-run`.

**Files:**
- Create: `scripts/migrate/setNeedsCalibration.js`
- Create: `scripts/migrate/setNeedsCalibration.test.js`

- [ ] **Step 1: Write the failing test**

Create `scripts/migrate/setNeedsCalibration.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');

const SCRIPT_PATH = path.resolve(__dirname, './setNeedsCalibration.js');

function load() {
  delete require.cache[SCRIPT_PATH];
  return require(SCRIPT_PATH);
}

test('migrate: targets only objectives missing topicSelfRatings', async () => {
  const calls = [];
  const FakeModel = {
    countDocuments: async (filter) => { calls.push({ op: 'count', filter }); return 42; },
    updateMany: async (filter, update) => { calls.push({ op: 'update', filter, update }); return { matchedCount: 42, modifiedCount: 42 }; },
  };
  const { runMigration } = load();
  const result = await runMigration({ Model: FakeModel, dryRun: false });
  assert.strictEqual(result.matched, 42);
  assert.strictEqual(result.modified, 42);
  // Filter must capture both "no field" and "empty map" cases.
  const updateCall = calls.find((c) => c.op === 'update');
  assert.ok(updateCall, 'updateMany should be called');
  assert.strictEqual(updateCall.update.$set.needsCalibration, true);
  // Filter shape: $or covering missing or empty
  assert.ok(Array.isArray(updateCall.filter.$or));
});

test('migrate: dry-run only counts, does not write', async () => {
  let updateCalled = false;
  const FakeModel = {
    countDocuments: async () => 7,
    updateMany: async () => { updateCalled = true; return { modifiedCount: 7 }; },
  };
  const { runMigration } = load();
  const result = await runMigration({ Model: FakeModel, dryRun: true });
  assert.strictEqual(result.matched, 7);
  assert.strictEqual(result.modified, 0);
  assert.strictEqual(updateCalled, false);
});

test('migrate: returns zero when nothing to migrate', async () => {
  const FakeModel = {
    countDocuments: async () => 0,
    updateMany: async () => { throw new Error('should not be called'); },
  };
  const { runMigration } = load();
  const result = await runMigration({ Model: FakeModel, dryRun: false });
  assert.strictEqual(result.matched, 0);
  assert.strictEqual(result.modified, 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="migrate:"
```

Expected: FAIL — script doesn't exist.

- [ ] **Step 3: Implement the script**

Create `scripts/migrate/setNeedsCalibration.js`:

```js
#!/usr/bin/env node
/**
 * One-shot migration: flag every existing UserObjective without
 * topicSelfRatings as `needsCalibration: true` so the legacy-user
 * banner can prompt them to calibrate.
 *
 * Usage:
 *   node scripts/migrate/setNeedsCalibration.js [--dry-run]
 *
 * Idempotent: re-running is safe (only matches docs missing the field
 * or with an empty topicSelfRatings map).
 */

const FILTER = {
  $or: [
    { topicSelfRatings: { $exists: false } },
    { topicSelfRatings: null },
    { topicSelfRatings: { $size: 0 } }, // arrays just in case (Mongoose Map serializes oddly)
    { $expr: { $eq: [{ $size: { $ifNull: [{ $objectToArray: '$topicSelfRatings' }, []] } }, 0] } },
  ],
};

async function runMigration({ Model, dryRun = false, log = () => {} }) {
  const matched = await Model.countDocuments(FILTER);
  log(`Matched ${matched} UserObjective documents.`);
  if (dryRun) {
    log('--dry-run: no writes performed.');
    return { matched, modified: 0 };
  }
  if (matched === 0) return { matched: 0, modified: 0 };
  const result = await Model.updateMany(FILTER, { $set: { needsCalibration: true } });
  const modified = result.modifiedCount ?? result.nModified ?? 0;
  log(`Modified ${modified} documents.`);
  return { matched, modified };
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const mongoose = require('mongoose');
  const UserObjective = require('../../src/models/UserObjective');

  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    console.error('MONGODB_URI not set'); process.exit(1);
  }
  await mongoose.connect(mongoUri);
  try {
    const result = await runMigration({
      Model: UserObjective,
      dryRun,
      log: (msg) => console.log(msg),
    });
    console.log('DONE', JSON.stringify(result));
  } finally {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
}

module.exports = { runMigration, FILTER };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="migrate:"
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/migrate/setNeedsCalibration.js scripts/migrate/setNeedsCalibration.test.js
git commit -m "feat(diagnostic): migration script — flag legacy UserObjectives for calibration"
```

- [ ] **Step 6: Dry-run against the staging database (manual smoke)**

```bash
MONGODB_URI=$STAGING_MONGO node scripts/migrate/setNeedsCalibration.js --dry-run
```

Inspect the matched count. If it looks correct (= total active legacy users), schedule the real run during a low-traffic window:

```bash
MONGODB_URI=$STAGING_MONGO node scripts/migrate/setNeedsCalibration.js
```

Note in the team channel: from this moment, the legacy-user banner will start appearing in the iOS/Android home tab as soon as Plan 4 ships its UI.

---

## Self-review checklist (run before opening PR)

- [ ] All ten tasks have a passing test suite. Run the entire suite once:

  ```bash
  npm test
  ```

  Expected: green. If any pre-existing test broke, investigate — these changes should be additive only.

- [ ] `git log --oneline` shows ten focused commits, one per task, with the prefixes `feat(diagnostic)` and `feat(onboarding)`.

- [ ] `git diff master --stat` shows the expected files and roughly the right line counts:
  - `src/models/UserObjective.js` — small additive (~15 lines)
  - `src/models/UserObjective.test.js` — new (~80 lines)
  - `src/models/DiagnosticAttempt.js` — small additive (~20 lines)
  - `src/models/DiagnosticAttempt.test.js` — additive
  - `src/models/DiagnosticSyllabus.js` — new (~50 lines)
  - `src/models/DiagnosticSyllabus.test.js` — new (~70 lines)
  - `src/services/diagnostic/specificsNormalizationService.js` — new (~95 lines)
  - `src/services/diagnostic/specificsNormalizationService.test.js` — new (~110 lines)
  - `src/controllers/onboardingController.js` — additive (two handlers)
  - `src/controllers/onboardingController.test.js` — new
  - `src/controllers/diagnosticSyllabusController.js` — new (~120 lines)
  - `src/controllers/diagnosticSyllabusController.test.js` — new
  - `src/routes/onboarding.js` — two added lines
  - `src/routes/diagnostic.js` — three added lines
  - `scripts/migrate/setNeedsCalibration.js` — new (~70 lines)
  - `scripts/migrate/setNeedsCalibration.test.js` — new (~60 lines)

- [ ] Manual sanity-check with `node`:

  ```bash
  node -e "const M = require('./src/models/UserObjective'); const d = new M({userId: require('mongoose').Types.ObjectId(), objectiveType:'upskilling', timeline:'3_months', currentLevel:'beginner', weeklyCommitHours:5}); console.log({needsCalibration: d.needsCalibration, hasMap: d.topicSelfRatings instanceof Map, hasCanonical: !!d.specificsCanonical});"
  ```

  Expected output: `{ needsCalibration: false, hasMap: true, hasCanonical: true }`.

- [ ] Manual API smoke-test using `curl` against a local server (needs `npm run dev` in another shell):

  ```bash
  # Topic suggest — expect 404 TAXONOMY_MISSING (until Plan 1 seed data is loaded for this key)
  curl -X POST http://localhost:3000/api/onboarding/topics/suggest \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"objectiveType":"upskilling","specifics":{"targetSkill":"Product Management"}}'

  # Onboarding complete — expect { userObjectiveId: "..." }
  curl -X POST http://localhost:3000/api/onboarding/complete \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
      "objectiveType":"upskilling","timeline":"3_months","currentLevel":"beginner",
      "weeklyCommitHours":5,
      "topicsOfInterest":["product-strategy"],
      "topicSelfRatings":{"product-strategy":"familiar"},
      "specifics":{"targetSkill":"Product Management"}
    }'

  # Syllabus init — expect { syllabusId, uploadUrl, s3Key }
  curl -X POST http://localhost:3000/api/diagnostic/syllabus/upload-init \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"userObjectiveId":"<id-from-above>","contentType":"application/pdf","fileSizeBytes":102400}'
  ```

- [ ] Migration dry-run against staging shows a sane match count (every legacy user with no self-ratings).

---

## Execution handoff

When all ten tasks are complete and the self-review checklist is green:

1. Push the branch:

   ```bash
   git push -u origin feat/diagnostic-phase2a-backend
   ```

2. Open a PR titled **"feat(diagnostic): phase 2a backend foundation"** with body:

   ```
   Implements Plan 2a — Phase 1 backend foundation for the Day-1 Diagnostic redesign.

   Adds:
   - UserObjective: topicSelfRatings (Map), specificsCanonical (subdoc), needsCalibration (Bool, indexed)
   - DiagnosticAttempt: insightsJson, planGenerationStatus (enum), attemptType (enum), previousAttemptId
   - DiagnosticSyllabus model
   - specificsNormalizationService (LLM-backed, 3s timeout, raw fallback)
   - POST /onboarding/topics/suggest
   - POST /onboarding/complete (atomic save with normalization)
   - POST /diagnostic/syllabus/upload-init
   - POST /diagnostic/syllabus/:id/complete
   - GET  /diagnostic/syllabus/:id/status
   - scripts/migrate/setNeedsCalibration.js (dry-run supported)

   Strictly additive — no existing behaviour modified.

   Spec: docs/superpowers/specs/2026-05-03-day1-diagnostic-redesign-design.md
   Plan: docs/superpowers/plans/2026-05-03-diagnostic-phase2a-backend-foundation.md

   Follow-up plans:
   - Plan 2b: frontend onboarding (iOS + Android Step 5 rebuild)
   - Plan 3a: diagnostic engine + syllabus worker handler + realtime LLM topic generation
   - Plan 4: legacy-user banner UI consuming `needsCalibration`
   ```

3. Schedule the migration to run in a low-traffic window after merge. Coordinate with the Plan 2b / Plan 4 frontend rollout so the banner doesn't appear before its handling UI exists.

4. **Do not run the migration in production until Plan 4 banner UI is shipped** — flagging objectives without a path to act on it would be confusing for users (the field is silently set, but iOS/Android need a release that surfaces the banner).

---

## Out of scope (explicit non-goals for this plan)

These belong to other plans and must not creep in here:

- **Diagnostic engine** (question pool assembly, selection, scoring) — Plan 3a.
- **Results / insights generation** — Plan 3b/4.
- **Plan generation pipeline integration** — Plan 5.
- **Recalibration scheduling and surfaces** — Plan 6.
- **Any iOS or Android code** — Plans 2b, 4.
- **Realtime LLM topic generation** when taxonomy missing — Plan 3a (this plan returns 404).
- **Syllabus extraction worker handler** (extracted-text → topics → questions) — Plan 3a (this plan only enqueues the job).
- **Admin question review dashboard** — Plan 6.
- **Legacy-user banner UI** consuming `needsCalibration` — Plan 4.
- **Mixpanel instrumentation** for the new endpoints — Plan 7 polish.

