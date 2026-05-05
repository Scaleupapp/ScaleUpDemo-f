₹# Day-1 Diagnostic — Plan 1: Phase 0.5 Seed Scripts

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data foundation for the new Day-1 Diagnostic — taxonomy models, company profiles, anchor questions, and a Wave 1 question bank of ~8,000-10,000 validated questions — covering ~70% of expected user paths at launch.

**Architecture:** Two new Mongoose models (`TopicTaxonomy`, `CompanyProfile`) + schema additions to existing `DiagnosticQuestionBank`. One new service for taxonomy lookup, one new service for the Tier 1 question quality validator. Four seed scripts that read hand-curated JSON data files (sourced from Phase 0 research) and populate the database, with the question-bank script using LLM batch generation gated by the validator. One orchestrator script runs Wave 1 end-to-end.

**Tech Stack:**
- Node.js + Mongoose 8.x
- OpenAI SDK 4.x with `gpt-4o-mini` and json_schema strict response format
- node:test for unit + integration tests
- Existing parallel-batch generation pattern from `seedDiagnosticBank.js`

**Source documents (read-only references):**
- Spec: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/specs/2026-05-03-day1-diagnostic-redesign-design.md`
- Research synthesis: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/research/2026-05-03-india-seeding-research.md`
- Skills detail: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/research/2026-05-03-india-skills-research.md`
- Exams detail: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/research/2026-05-03-india-exams-curricula-research.md`
- Companies detail: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/docs/superpowers/research/2026-05-03-india-companies-careers-research.md`

**Backend repo path (all file paths in this plan are relative to here):**
`/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`

---

## File Structure (decisions locked here)

| Path | Responsibility | Status |
|---|---|---|
| `src/models/TopicTaxonomy.js` | Topic taxonomy Mongoose model | NEW |
| `src/models/TopicTaxonomy.test.js` | Schema validation + defaults tests | NEW |
| `src/models/CompanyProfile.js` | Company profile Mongoose model | NEW |
| `src/models/CompanyProfile.test.js` | Schema validation + defaults tests | NEW |
| `src/models/DiagnosticQuestionBank.js` | Existing question bank model | MODIFY (add validation fields) |
| `src/models/DiagnosticQuestionBank.test.js` | Existing tests | MODIFY (add tests for new fields) |
| `src/services/diagnostic/topicTaxonomyService.js` | Lookup taxonomy by `(objectiveType × targetKey)`, normalize specifics | NEW |
| `src/services/diagnostic/topicTaxonomyService.test.js` | Lookup + normalization tests | NEW |
| `src/services/diagnostic/questionValidatorService.js` | Tier 1 validator — LLM critique of question quality | NEW |
| `src/services/diagnostic/questionValidatorService.test.js` | Validator tests with mocked LLM | NEW |
| `scripts/seed/data/wave1-topics.json` | Hand-curated ~700 topics from Phase 0 research | NEW |
| `scripts/seed/data/wave1-companies.json` | Hand-curated 40 company profiles | NEW |
| `scripts/seed/seedTopicTaxonomy.js` | Loads `wave1-topics.json` into TopicTaxonomy collection | NEW |
| `scripts/seed/seedCompanyProfiles.js` | Loads `wave1-companies.json` into CompanyProfile collection | NEW |
| `scripts/seed/seedAnchorQuestions.js` | LLM-generates 2-3 anchor questions per topic, marks `isAnchor: true` | NEW |
| `scripts/seed/seedQuestionBank.js` | Batch LLM-generates ~10k questions using anchors as few-shot examples | NEW |
| `scripts/seed/runWave1.js` | Orchestrates all 4 seed steps in order, with checkpoints | NEW |
| `scripts/seed/seedTopicTaxonomy.test.js` | Tests for the seed loader | NEW |
| `scripts/seed/seedCompanyProfiles.test.js` | Tests for the seed loader | NEW |
| `scripts/seed/seedAnchorQuestions.test.js` | Tests with mocked OpenAI | NEW |
| `scripts/seed/seedQuestionBank.test.js` | Tests with mocked OpenAI for one topic batch | NEW |

**Conventions:**
- All tests use `node:test` and `node:assert` (matches existing project convention).
- Tests run via `npm test` which invokes `node scripts/run-tests.js`.
- All scripts are runnable via `node scripts/seed/<script>.js` with `--dry-run` flag for validation without writes.
- LLM calls always use `json_schema` strict response format with explicit timeouts.
- Commits should use the existing project commit style (see recent commits for tone).

---

## Prerequisites

Before starting Task 1, the following must be true:

1. The backend repo at `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/` is on a clean working branch (no uncommitted changes).
2. `OPENAI_API_KEY` is set in `.env` (already exists for the existing diagnostic).
3. MongoDB connection string in `.env` (already exists).
4. `node_modules` is installed (`npm install`).

Run from the backend repo root:
```bash
git checkout -b feat/diagnostic-phase0.5-seed
git status   # verify clean
```

---

## Task 1: Create the TopicTaxonomy model

**Files:**
- Create: `src/models/TopicTaxonomy.js`
- Test: `src/models/TopicTaxonomy.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/models/TopicTaxonomy.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

// Force fresh module load
delete require.cache[require.resolve('./TopicTaxonomy')];
const TopicTaxonomy = require('./TopicTaxonomy');

test('TopicTaxonomy: creates with required fields', () => {
  const doc = new TopicTaxonomy({
    objectiveType: 'upskilling',
    targetKey: 'upskilling::product-management',
    topics: [
      {
        name: 'Product Strategy',
        canonicalName: 'product-strategy',
        description: 'Defining product vision and prioritising bets.',
        baseDifficulty: 'intermediate',
        isFutureProofing: false,
        sortOrder: 1,
      },
    ],
    source: 'curated',
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined, 'should validate cleanly');
  assert.strictEqual(doc.topics.length, 1);
  assert.strictEqual(doc.refreshCount, 0, 'refreshCount defaults to 0');
});

test('TopicTaxonomy: requires objectiveType', () => {
  const doc = new TopicTaxonomy({ targetKey: 'x', topics: [] });
  const err = doc.validateSync();
  assert.ok(err && err.errors.objectiveType, 'objectiveType required');
});

test('TopicTaxonomy: rejects invalid objectiveType enum', () => {
  const doc = new TopicTaxonomy({
    objectiveType: 'not_a_real_type',
    targetKey: 'x',
    topics: [],
    source: 'curated',
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.objectiveType, 'invalid enum should error');
});

test('TopicTaxonomy: rejects invalid baseDifficulty in topic', () => {
  const doc = new TopicTaxonomy({
    objectiveType: 'upskilling',
    targetKey: 'x',
    topics: [{
      name: 'X',
      canonicalName: 'x',
      description: 'd',
      baseDifficulty: 'super_hard',
      sortOrder: 1,
    }],
    source: 'curated',
  });
  const err = doc.validateSync();
  assert.ok(err, 'invalid difficulty should error');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="TopicTaxonomy"
```

Expected: FAIL with "Cannot find module './TopicTaxonomy'".

- [ ] **Step 3: Implement the model**

Create `src/models/TopicTaxonomy.js`:

```js
const mongoose = require('mongoose');

const OBJECTIVE_TYPES = [
  'upskilling',
  'interview_preparation',
  'exam_preparation',
  'career_switch',
  'academic_excellence',
  'casual_learning',
  'networking',
];

const DIFFICULTIES = ['foundational', 'intermediate', 'advanced'];

const topicSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    canonicalName: { type: String, required: true },
    description: { type: String, required: true },
    baseDifficulty: { type: String, enum: DIFFICULTIES, required: true },
    isFutureProofing: { type: Boolean, default: false },
    sortOrder: { type: Number, required: true },
    applicableObjectives: { type: [String], default: undefined },
  },
  { _id: false }
);

const userEditSignalSchema = new mongoose.Schema(
  {
    timesRemoved: { type: Map, of: Number, default: () => new Map() },
    timesAdded: { type: Map, of: Number, default: () => new Map() },
  },
  { _id: false }
);

const topicTaxonomySchema = new mongoose.Schema(
  {
    objectiveType: { type: String, enum: OBJECTIVE_TYPES, required: true },
    targetKey: { type: String, required: true },
    topics: { type: [topicSchema], default: [] },
    source: {
      type: String,
      enum: ['curated', 'llm-generated'],
      required: true,
    },
    lastRefreshedAt: { type: Date, default: Date.now },
    refreshCount: { type: Number, default: 0 },
    userEditSignal: { type: userEditSignalSchema, default: () => ({}) },
  },
  { timestamps: true }
);

topicTaxonomySchema.index({ objectiveType: 1, targetKey: 1 }, { unique: true });

module.exports = mongoose.model('TopicTaxonomy', topicTaxonomySchema);
module.exports.OBJECTIVE_TYPES = OBJECTIVE_TYPES;
module.exports.DIFFICULTIES = DIFFICULTIES;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="TopicTaxonomy"
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/TopicTaxonomy.js src/models/TopicTaxonomy.test.js
git commit -m "feat(diagnostic): add TopicTaxonomy model"
```

---

## Task 2: Create the CompanyProfile model

**Files:**
- Create: `src/models/CompanyProfile.js`
- Test: `src/models/CompanyProfile.test.js`

- [ ] **Step 1: Write the failing test**

Create `src/models/CompanyProfile.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');

delete require.cache[require.resolve('./CompanyProfile')];
const CompanyProfile = require('./CompanyProfile');

test('CompanyProfile: creates with required fields', () => {
  const doc = new CompanyProfile({
    name: 'Razorpay',
    normalizedName: 'razorpay',
    industry: 'Fintech',
    applicableObjectives: ['interview_preparation', 'upskilling'],
    signatureInterviewElements: ['API design depth', 'Payments domain knowledge'],
    topicWeightOverrides: new Map([['api-design', 1.5], ['system-design', 1.3]]),
    examplesContext: 'You are a backend engineer at Razorpay handling UPI flows.',
    source: 'curated',
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.normalizedName, 'razorpay');
  assert.strictEqual(doc.topicWeightOverrides.get('api-design'), 1.5);
});

test('CompanyProfile: requires normalizedName', () => {
  const doc = new CompanyProfile({ name: 'X', industry: 'Tech', source: 'curated' });
  const err = doc.validateSync();
  assert.ok(err && err.errors.normalizedName);
});

test('CompanyProfile: invalid source rejected', () => {
  const doc = new CompanyProfile({
    name: 'X',
    normalizedName: 'x',
    industry: 'T',
    source: 'random_source',
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.source);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="CompanyProfile"
```

Expected: FAIL with "Cannot find module './CompanyProfile'".

- [ ] **Step 3: Implement the model**

Create `src/models/CompanyProfile.js`:

```js
const mongoose = require('mongoose');

const companyProfileSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    normalizedName: { type: String, required: true, lowercase: true, trim: true },
    industry: { type: String, required: true },
    applicableObjectives: { type: [String], default: [] },
    signatureInterviewElements: { type: [String], default: [] },
    topicWeightOverrides: { type: Map, of: Number, default: () => new Map() },
    examplesContext: { type: String, default: '' },
    source: {
      type: String,
      enum: ['curated', 'llm-generated'],
      required: true,
    },
    lastRefreshedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

companyProfileSchema.index({ normalizedName: 1 }, { unique: true });

module.exports = mongoose.model('CompanyProfile', companyProfileSchema);
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="CompanyProfile"
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/models/CompanyProfile.js src/models/CompanyProfile.test.js
git commit -m "feat(diagnostic): add CompanyProfile model"
```

---

## Task 3: Add validation fields to DiagnosticQuestionBank

**Files:**
- Modify: `src/models/DiagnosticQuestionBank.js`
- Modify: `src/models/DiagnosticQuestionBank.test.js`

- [ ] **Step 1: Read the existing model**

```bash
cat src/models/DiagnosticQuestionBank.js
```

Note the existing schema fields. The new fields will be added without removing anything.

- [ ] **Step 2: Write the failing test**

Add to `src/models/DiagnosticQuestionBank.test.js` (append at the end of the file):

```js
test('DiagnosticQuestionBank: defaults verificationStatus to pending', () => {
  delete require.cache[require.resolve('./DiagnosticQuestionBank')];
  const QB = require('./DiagnosticQuestionBank');
  const doc = new QB({
    canonicalCompetency: 'product-strategy',
    difficulty: 'easy',
    questionText: 'What is product strategy?',
    options: [
      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
    ],
    correctAnswer: 'A',
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.verificationStatus, 'pending');
  assert.strictEqual(doc.isAnchor, false);
});

test('DiagnosticQuestionBank: rejects invalid verificationStatus', () => {
  delete require.cache[require.resolve('./DiagnosticQuestionBank')];
  const QB = require('./DiagnosticQuestionBank');
  const doc = new QB({
    canonicalCompetency: 'x',
    difficulty: 'easy',
    questionText: 'q',
    options: [
      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
    ],
    correctAnswer: 'A',
    verificationStatus: 'made_up_status',
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.verificationStatus);
});

test('DiagnosticQuestionBank: accepts generationSource enum', () => {
  delete require.cache[require.resolve('./DiagnosticQuestionBank')];
  const QB = require('./DiagnosticQuestionBank');
  const doc = new QB({
    canonicalCompetency: 'x',
    difficulty: 'easy',
    questionText: 'q',
    options: [
      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
    ],
    correctAnswer: 'A',
    generationSource: 'seed_batch',
    isAnchor: true,
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.isAnchor, true);
});
```

- [ ] **Step 3: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="DiagnosticQuestionBank"
```

Expected: 3 new tests fail (`verificationStatus is undefined`, etc.).

- [ ] **Step 4: Add the new fields to the schema**

Edit `src/models/DiagnosticQuestionBank.js`. Inside the `new mongoose.Schema({ ... })` definition, add these fields (alongside the existing fields):

```js
  verificationStatus: {
    type: String,
    enum: ['pending', 'auto_verified', 'human_verified', 'flagged_for_review', 'rejected'],
    default: 'pending',
    index: true,
  },
  validatorScore: { type: Number, min: 0, max: 100 },
  validatorCritique: { type: String },
  humanReviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  humanReviewedAt: { type: Date },
  humanReviewNotes: { type: String },
  generationSource: {
    type: String,
    enum: ['curated', 'seed_batch', 'llm_realtime', 'syllabus_derived'],
    default: 'seed_batch',
  },
  sourceContext: { type: mongoose.Schema.Types.ObjectId },
  isAnchor: { type: Boolean, default: false, index: true },
```

- [ ] **Step 5: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="DiagnosticQuestionBank"
```

Expected: All tests in the file pass (existing ones still pass + 3 new ones).

- [ ] **Step 6: Commit**

```bash
git add src/models/DiagnosticQuestionBank.js src/models/DiagnosticQuestionBank.test.js
git commit -m "feat(diagnostic): add validation fields to DiagnosticQuestionBank"
```

---

## Task 4: TopicTaxonomy lookup service

**Files:**
- Create: `src/services/diagnostic/topicTaxonomyService.js`
- Test: `src/services/diagnostic/topicTaxonomyService.test.js`

This service handles: (a) building canonical `targetKey` strings from `(objectiveType, specifics)`, and (b) looking up taxonomies. The seed scripts use `buildTargetKey` to assign keys; later phases will add the lookup methods.

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/topicTaxonomyService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');

delete require.cache[require.resolve('./topicTaxonomyService')];
const svc = require('./topicTaxonomyService');

test('buildTargetKey: upskilling with targetSkill', () => {
  const key = svc.buildTargetKey('upskilling', { targetSkill: 'Product Management' });
  assert.strictEqual(key, 'upskilling::product-management');
});

test('buildTargetKey: interview_preparation with targetRole + targetCompany tier', () => {
  const key = svc.buildTargetKey('interview_preparation', {
    targetRole: 'Software Engineer',
    targetCompany: 'FAANG',
  });
  assert.strictEqual(key, 'interview_preparation::software-engineer::faang');
});

test('buildTargetKey: exam_preparation with examName', () => {
  const key = svc.buildTargetKey('exam_preparation', { examName: 'JEE Main' });
  assert.strictEqual(key, 'exam_preparation::jee-main');
});

test('buildTargetKey: career_switch with from + to domains', () => {
  const key = svc.buildTargetKey('career_switch', {
    fromDomain: 'Investment Banking',
    toDomain: 'Product Management',
  });
  assert.strictEqual(key, 'career_switch::investment-banking::product-management');
});

test('buildTargetKey: academic_excellence with board + grade + subject', () => {
  const key = svc.buildTargetKey('academic_excellence', {
    board: 'CBSE',
    grade: '12',
    subject: 'Physics',
  });
  assert.strictEqual(key, 'academic_excellence::cbse::12::physics');
});

test('buildTargetKey: casual_learning falls back to generic', () => {
  const key = svc.buildTargetKey('casual_learning', {});
  assert.strictEqual(key, 'casual_learning::general');
});

test('canonicalize: lowercases and dasherizes', () => {
  assert.strictEqual(svc.canonicalize('Product Management'), 'product-management');
  assert.strictEqual(svc.canonicalize('JEE Main'), 'jee-main');
  assert.strictEqual(svc.canonicalize('  IT  Services  '), 'it-services');
  assert.strictEqual(svc.canonicalize('A&B/C'), 'a-b-c');
  assert.strictEqual(svc.canonicalize(''), '');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="buildTargetKey|canonicalize"
```

Expected: FAIL with "Cannot find module './topicTaxonomyService'".

- [ ] **Step 3: Create directory and implement service**

```bash
mkdir -p src/services/diagnostic
```

Create `src/services/diagnostic/topicTaxonomyService.js`:

```js
function canonicalize(s) {
  if (!s || typeof s !== 'string') return '';
  return s
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function buildTargetKey(objectiveType, specifics = {}) {
  const parts = [objectiveType];
  switch (objectiveType) {
    case 'upskilling':
      parts.push(canonicalize(specifics.targetSkill || 'general'));
      break;
    case 'interview_preparation':
      parts.push(canonicalize(specifics.targetRole || 'general'));
      if (specifics.targetCompany) {
        parts.push(canonicalize(specifics.targetCompany));
      }
      break;
    case 'exam_preparation':
      parts.push(canonicalize(specifics.examName || 'general'));
      break;
    case 'career_switch':
      parts.push(canonicalize(specifics.fromDomain || 'general'));
      parts.push(canonicalize(specifics.toDomain || 'general'));
      break;
    case 'academic_excellence':
      parts.push(canonicalize(specifics.board || 'general'));
      if (specifics.grade) parts.push(canonicalize(specifics.grade));
      if (specifics.subject) parts.push(canonicalize(specifics.subject));
      break;
    case 'casual_learning':
    case 'networking':
    default:
      parts.push(canonicalize(specifics.area || 'general'));
      break;
  }
  return parts.join('::');
}

module.exports = { canonicalize, buildTargetKey };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="buildTargetKey|canonicalize"
```

Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnostic/topicTaxonomyService.js src/services/diagnostic/topicTaxonomyService.test.js
git commit -m "feat(diagnostic): add topic taxonomy service with buildTargetKey + canonicalize"
```

---

## Task 5: Question quality validator service (Tier 1)

**Files:**
- Create: `src/services/diagnostic/questionValidatorService.js`
- Test: `src/services/diagnostic/questionValidatorService.test.js`

This service runs a stricter LLM call to critique a question. Used during seeding (validate every generated question) and later in production (real-time generation).

- [ ] **Step 1: Write the failing test**

Create `src/services/diagnostic/questionValidatorService.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');

const openaiPath = require.resolve('../../config/openai');
require.cache[openaiPath] = {
  exports: {
    chat: {
      completions: {
        create: async () => ({
          choices: [{
            message: {
              content: JSON.stringify({
                score: 92,
                critique: 'Question is clear, single correct answer, India-context appropriate.',
                issues: [],
              }),
            },
          }],
        }),
      },
    },
  },
  loaded: true,
  id: openaiPath,
};

delete require.cache[require.resolve('./questionValidatorService')];
const { validateQuestion, classifyScore } = require('./questionValidatorService');

test('classifyScore: ≥90 returns auto_verified', () => {
  assert.strictEqual(classifyScore(95), 'auto_verified');
  assert.strictEqual(classifyScore(90), 'auto_verified');
});

test('classifyScore: 70-89 returns pending', () => {
  assert.strictEqual(classifyScore(85), 'pending');
  assert.strictEqual(classifyScore(70), 'pending');
});

test('classifyScore: <70 returns flagged_for_review', () => {
  assert.strictEqual(classifyScore(69), 'flagged_for_review');
  assert.strictEqual(classifyScore(0), 'flagged_for_review');
});

test('validateQuestion: returns score + critique + status from LLM', async () => {
  const question = {
    questionText: 'What is product-market fit?',
    options: [
      { label: 'A', text: 'A perfect product' },
      { label: 'B', text: 'When customers pull product from you' },
      { label: 'C', text: 'High revenue' },
      { label: 'D', text: 'Good marketing' },
    ],
    correctAnswer: 'B',
    difficulty: 'easy',
    canonicalCompetency: 'product-strategy',
  };
  const result = await validateQuestion(question);
  assert.strictEqual(result.score, 92);
  assert.strictEqual(result.status, 'auto_verified');
  assert.ok(result.critique.length > 0);
  assert.deepStrictEqual(result.issues, []);
});

test('validateQuestion: handles malformed LLM response gracefully', async () => {
  const openaiPath = require.resolve('../../config/openai');
  require.cache[openaiPath] = {
    exports: {
      chat: {
        completions: {
          create: async () => ({
            choices: [{ message: { content: 'not valid json' } }],
          }),
        },
      },
    },
    loaded: true,
    id: openaiPath,
  };
  delete require.cache[require.resolve('./questionValidatorService')];
  const { validateQuestion } = require('./questionValidatorService');
  const result = await validateQuestion({
    questionText: 'q',
    options: [
      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
    ],
    correctAnswer: 'A',
    difficulty: 'easy',
    canonicalCompetency: 'x',
  });
  assert.strictEqual(result.status, 'flagged_for_review');
  assert.strictEqual(result.score, 0);
  assert.ok(result.critique.includes('parse'));
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="classifyScore|validateQuestion"
```

Expected: FAIL with "Cannot find module './questionValidatorService'".

- [ ] **Step 3: Implement the service**

Create `src/services/diagnostic/questionValidatorService.js`:

```js
const openai = require('../../config/openai');

const VALIDATOR_SCHEMA = {
  name: 'question_validation',
  strict: true,
  schema: {
    type: 'object',
    properties: {
      score: { type: 'integer', minimum: 0, maximum: 100 },
      critique: { type: 'string' },
      issues: {
        type: 'array',
        items: { type: 'string' },
      },
    },
    required: ['score', 'critique', 'issues'],
    additionalProperties: false,
  },
};

const SYSTEM_PROMPT = `You are a strict quality reviewer for diagnostic assessment questions used by Indian working professionals and students. Find what is wrong, not what is right.

Score 0-100 based on:
- Correctness: Is the marked answer unambiguously correct? Are other options unambiguously wrong?
- Difficulty calibration: Does the actual difficulty match the stated difficulty?
- Language quality: Grammar, clarity, no double negatives, no leading wording
- Single-correct-answer: No two options that could both be defensible
- No ambiguity: Question stem complete enough to answer
- No offensive content
- India context: Examples make sense for Indian learners (where applicable)
- Real-world feel: Not textbook-rote / definition-recall

Score guide:
- 90-100: ship as is
- 70-89: usable but has minor issues
- 0-69: do not use, list specific issues

Be honest. A textbook definition question scores 60-70 max.`;

function classifyScore(score) {
  if (score >= 90) return 'auto_verified';
  if (score >= 70) return 'pending';
  return 'flagged_for_review';
}

function buildUserPrompt(question) {
  const optionsText = question.options
    .map(o => `${o.label}. ${o.text}`)
    .join('\n');
  return `Topic: ${question.canonicalCompetency}
Stated difficulty: ${question.difficulty}

Question:
${question.questionText}

Options:
${optionsText}

Marked correct: ${question.correctAnswer}

Critique this question.`;
}

async function validateQuestion(question, opts = {}) {
  const timeoutMs = opts.timeoutMs || 12000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const completion = await openai.chat.completions.create(
      {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: buildUserPrompt(question) },
        ],
        response_format: { type: 'json_schema', json_schema: VALIDATOR_SCHEMA },
        temperature: 0.2,
        max_tokens: 500,
      },
      { signal: controller.signal }
    );

    const raw = completion.choices[0].message.content;
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      return {
        score: 0,
        critique: `Validator response failed to parse: ${e.message}`,
        issues: ['parse_failure'],
        status: 'flagged_for_review',
      };
    }
    return {
      score: parsed.score,
      critique: parsed.critique,
      issues: parsed.issues || [],
      status: classifyScore(parsed.score),
    };
  } catch (e) {
    return {
      score: 0,
      critique: `Validator failed: ${e.message}`,
      issues: ['validator_error'],
      status: 'flagged_for_review',
    };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = { validateQuestion, classifyScore };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="classifyScore|validateQuestion"
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/services/diagnostic/questionValidatorService.js src/services/diagnostic/questionValidatorService.test.js
git commit -m "feat(diagnostic): add Tier 1 question validator service"
```

---

## Task 6: Wave 1 topic taxonomy seed data file

**Files:**
- Create: `scripts/seed/data/wave1-topics.json`

This is a hand-curated JSON file derived from the Phase 0 research. It contains ~700 topic entries spanning the Wave 1 priority combinations from the research synthesis §11.

- [ ] **Step 1: Create directory**

```bash
mkdir -p scripts/seed/data
```

- [ ] **Step 2: Write the failing test**

Create `scripts/seed/data/wave1-topics.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const fs = require('fs');

test('wave1-topics.json: exists and parses', () => {
  const p = path.join(__dirname, 'wave1-topics.json');
  const raw = fs.readFileSync(p, 'utf8');
  const data = JSON.parse(raw);
  assert.ok(Array.isArray(data), 'must be an array');
  assert.ok(data.length >= 80, `expected ≥80 taxonomy entries, got ${data.length}`);
});

test('wave1-topics.json: every entry has required fields', () => {
  const data = require('./wave1-topics.json');
  for (const entry of data) {
    assert.ok(entry.objectiveType, 'objectiveType required');
    assert.ok(entry.targetKey, `targetKey required for ${entry.objectiveType}`);
    assert.ok(Array.isArray(entry.topics), 'topics array required');
    assert.ok(entry.topics.length >= 3 && entry.topics.length <= 12,
      `topics count out of range: ${entry.topics.length}`);
    for (const t of entry.topics) {
      assert.ok(t.name, 'topic.name required');
      assert.ok(t.canonicalName, 'topic.canonicalName required');
      assert.ok(t.description, 'topic.description required');
      assert.ok(['foundational', 'intermediate', 'advanced'].includes(t.baseDifficulty),
        `bad baseDifficulty: ${t.baseDifficulty}`);
      assert.ok(typeof t.sortOrder === 'number', 'sortOrder required');
    }
  }
});

test('wave1-topics.json: covers all 7 objective types', () => {
  const data = require('./wave1-topics.json');
  const types = new Set(data.map(e => e.objectiveType));
  for (const t of [
    'upskilling', 'interview_preparation', 'exam_preparation',
    'career_switch', 'academic_excellence', 'casual_learning', 'networking',
  ]) {
    assert.ok(types.has(t), `missing objective type: ${t}`);
  }
});

test('wave1-topics.json: includes AI literacy topic for upskilling × PM', () => {
  const data = require('./wave1-topics.json');
  const pmEntry = data.find(e =>
    e.objectiveType === 'upskilling' && e.targetKey === 'upskilling::product-management');
  assert.ok(pmEntry, 'upskilling::product-management entry must exist');
  const aiTopic = pmEntry.topics.find(t => t.isFutureProofing === true);
  assert.ok(aiTopic, 'AI literacy topic (isFutureProofing=true) must exist for PM');
});
```

- [ ] **Step 3: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="wave1-topics"
```

Expected: FAIL with "ENOENT" (file does not exist).

- [ ] **Step 4: Create the data file**

Create `scripts/seed/data/wave1-topics.json` with the Wave 1 entries. Use the research synthesis §11 Wave 1 list as the source. Sample structure for the first few entries (the full file should follow this pattern for all Wave 1 combinations):

```json
[
  {
    "objectiveType": "upskilling",
    "targetKey": "upskilling::product-management",
    "source": "curated",
    "topics": [
      { "name": "Product Strategy", "canonicalName": "product-strategy", "description": "Defining product vision, prioritising bets, making strategic tradeoffs.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 1 },
      { "name": "User Research & Discovery", "canonicalName": "user-research", "description": "Customer interviews, jobs-to-be-done, synthesizing insights.", "baseDifficulty": "foundational", "isFutureProofing": false, "sortOrder": 2 },
      { "name": "Roadmapping & Prioritisation", "canonicalName": "roadmapping", "description": "Quarterly planning, RICE/MoSCoW, balancing tech debt and features.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 3 },
      { "name": "Stakeholder Management", "canonicalName": "stakeholder-management", "description": "Managing engineering, design, sales, leadership across the product cycle.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 4 },
      { "name": "Data-Driven Decisions", "canonicalName": "data-driven-decisions", "description": "Defining metrics, instrumentation, A/B testing, reading dashboards.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 5 },
      { "name": "Execution & Delivery", "canonicalName": "execution-delivery", "description": "Sprint discipline, removing blockers, shipping on time.", "baseDifficulty": "foundational", "isFutureProofing": false, "sortOrder": 6 },
      { "name": "Cross-functional Leadership", "canonicalName": "cross-functional-leadership", "description": "Leading without authority, driving alignment across teams.", "baseDifficulty": "advanced", "isFutureProofing": false, "sortOrder": 7 },
      { "name": "AI Product Strategy & Building with LLMs", "canonicalName": "ai-product-strategy", "description": "Designing AI features, model selection, evals, hallucination handling.", "baseDifficulty": "intermediate", "isFutureProofing": true, "sortOrder": 8 }
    ]
  },
  {
    "objectiveType": "upskilling",
    "targetKey": "upskilling::software-engineering",
    "source": "curated",
    "topics": [
      { "name": "Programming Fundamentals (Python/JS/Java)", "canonicalName": "programming-fundamentals", "description": "Core language fluency, idiomatic patterns, debugging.", "baseDifficulty": "foundational", "isFutureProofing": false, "sortOrder": 1 },
      { "name": "Data Structures & Algorithms", "canonicalName": "dsa", "description": "Arrays, trees, graphs, hashing, sorting, common patterns.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 2 },
      { "name": "System Design Basics", "canonicalName": "system-design", "description": "Scaling, caching, queues, databases, tradeoffs.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 3 },
      { "name": "Web Development (REST + Frontend)", "canonicalName": "web-development", "description": "REST APIs, React/Vue, HTTP, state management.", "baseDifficulty": "foundational", "isFutureProofing": false, "sortOrder": 4 },
      { "name": "Databases & SQL", "canonicalName": "databases-sql", "description": "Relational modelling, indexing, transactions, NoSQL basics.", "baseDifficulty": "foundational", "isFutureProofing": false, "sortOrder": 5 },
      { "name": "Testing & Code Quality", "canonicalName": "testing", "description": "Unit, integration, e2e tests; CI; code review hygiene.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 6 },
      { "name": "DevOps & Cloud Basics (AWS/Azure)", "canonicalName": "devops-cloud", "description": "Containers, CI/CD pipelines, basic cloud deployment.", "baseDifficulty": "intermediate", "isFutureProofing": false, "sortOrder": 7 },
      { "name": "AI-Augmented Engineering", "canonicalName": "ai-augmented-engineering", "description": "Copilot/Cursor/Claude Code fluency, RAG, prompt patterns, building with LLMs.", "baseDifficulty": "intermediate", "isFutureProofing": true, "sortOrder": 8 }
    ]
  }
]
```

**Required Wave 1 entries to include:**

| Objective | TargetKeys to include (each with 6-8 topics + AI literacy where applicable) |
|---|---|
| upskilling | product-management, software-engineering, data-science, marketing, design, sales, founder, hr-operations, finance-accounting, consulting, customer-success, devops-platform |
| interview_preparation | software-engineer × {faang, top-startups, indian-unicorns, mid-tier}; product-manager × {faang, top-startups, indian-unicorns, mid-tier}; data-scientist × {faang, top-startups, indian-unicorns}; designer × {faang, top-startups, indian-unicorns}; consultant × {mbb, big4} |
| exam_preparation | jee-main, neet-ug, cuet-ug, upsc-cse-prelims, cat, ssc-cgl, ibps-po, gate-cse |
| career_switch | it-services-engineer::product-manager, software-engineer::engineering-manager, investment-banking-analyst::product-manager, mechanical-engineer::software-engineer, marketing-analyst::data-scientist, marketing::product-marketing-manager, consulting::product-management, government-job::corporate, teacher::corporate-l-and-d, ca::investment-banking |
| academic_excellence | cbse::12::physics, cbse::12::chemistry, cbse::12::mathematics, cbse::12::biology, cbse::12::accountancy, cbse::12::business-studies, cbse::12::economics, cbse::12::computer-science, cbse::11::physics, cbse::11::chemistry, cbse::11::mathematics, cbse::11::biology, icse::12::physics, icse::12::chemistry, icse::12::mathematics, icse::12::biology, icse::12::commerce |
| academic_excellence (UG) | undergrad::computer-science, undergrad::electrical-engineering, undergrad::mechanical-engineering, undergrad::commerce |
| casual_learning | tech, business, history, science, philosophy, wellness, languages, personal-finance, productivity, arts, indian-culture, current-affairs |
| networking | mentor-finding, peer-building, hiring-network, founder-investor, community-presence |

For each entry, write 6-8 topics. Reference the research detail files for topic names and descriptions (especially `india-skills-research.md` for upskilling and `india-exams-curricula-research.md` for exam topic taxonomies).

**India-context emphasis** (per research synthesis §10): use Indian company examples in descriptions (Razorpay, Flipkart, Zomato, etc.) for upskilling/career_switch topics; INR salary references where relevant; explicit Indian compliance topics where applicable (DPDP, GST, RBI compliance) under upskilling × Finance and upskilling × Legal.

The full file will be ~80-90 entries × 6-8 topics each ≈ ~600-700 topic objects. Write it carefully — this is the foundation for everything downstream.

- [ ] **Step 5: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="wave1-topics"
```

Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/seed/data/wave1-topics.json scripts/seed/data/wave1-topics.test.js
git commit -m "feat(diagnostic): add Wave 1 hand-curated topic taxonomy seed data"
```

---

## Task 7: Wave 1 company profiles seed data file

**Files:**
- Create: `scripts/seed/data/wave1-companies.json`

40 hand-curated company profiles per research synthesis §5 + Decision 5 (AI-native companies included).

- [ ] **Step 1: Write the failing test**

Create `scripts/seed/data/wave1-companies.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const fs = require('fs');

test('wave1-companies.json: exists and parses', () => {
  const p = path.join(__dirname, 'wave1-companies.json');
  const data = JSON.parse(fs.readFileSync(p, 'utf8'));
  assert.ok(Array.isArray(data));
  assert.ok(data.length >= 40, `expected ≥40 profiles, got ${data.length}`);
});

test('wave1-companies.json: every profile has required fields', () => {
  const data = require('./wave1-companies.json');
  for (const c of data) {
    assert.ok(c.name);
    assert.ok(c.normalizedName);
    assert.ok(c.industry);
    assert.ok(Array.isArray(c.applicableObjectives));
    assert.ok(c.applicableObjectives.length > 0);
    assert.ok(Array.isArray(c.signatureInterviewElements));
    assert.ok(c.signatureInterviewElements.length > 0);
    assert.ok(c.examplesContext);
    assert.strictEqual(c.source, 'curated');
  }
});

test('wave1-companies.json: includes the must-have companies', () => {
  const data = require('./wave1-companies.json');
  const names = new Set(data.map(c => c.normalizedName));
  for (const required of [
    'google', 'microsoft', 'amazon', 'meta', 'apple',
    'razorpay', 'flipkart', 'zomato', 'swiggy', 'cred', 'phonepe',
    'mckinsey', 'bcg', 'bain',
    'goldman-sachs', 'jpmorgan',
    'openai', 'anthropic', 'sarvam', 'krutrim',
  ]) {
    assert.ok(names.has(required), `missing required company: ${required}`);
  }
});

test('wave1-companies.json: amazon profile has Leadership Principles signature', () => {
  const data = require('./wave1-companies.json');
  const amazon = data.find(c => c.normalizedName === 'amazon');
  const hasLP = amazon.signatureInterviewElements.some(e =>
    /leadership principles/i.test(e));
  assert.ok(hasLP, 'Amazon must call out Leadership Principles');
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="wave1-companies"
```

Expected: FAIL with "ENOENT".

- [ ] **Step 3: Create the data file**

Create `scripts/seed/data/wave1-companies.json` with 40+ profiles. Use research detail file `india-companies-careers-research.md` Section A as the source — every entry has the signature interview elements already documented there. Sample structure:

```json
[
  {
    "name": "Google",
    "normalizedName": "google",
    "industry": "Big Tech",
    "applicableObjectives": ["interview_preparation", "upskilling"],
    "signatureInterviewElements": [
      "System design depth (L4+)",
      "Googleyness behavioural framework",
      "Coding rigor — 2 hard LeetCode-style rounds",
      "Cross-functional collaboration emphasis"
    ],
    "topicWeightOverrides": {
      "system-design": 1.5,
      "dsa": 1.4,
      "behavioural": 1.2
    },
    "examplesContext": "You are a SWE at Google India working on Search infrastructure or Cloud, dealing with global-scale systems and Indian regulatory context (DPDP) for India-region products.",
    "source": "curated"
  },
  {
    "name": "Razorpay",
    "normalizedName": "razorpay",
    "industry": "Fintech",
    "applicableObjectives": ["interview_preparation", "upskilling"],
    "signatureInterviewElements": [
      "API design depth — payments domain",
      "System design with regulatory constraints (RBI 2FA, settlement timelines)",
      "Coding (medium) — practical, not LeetCode-puzzle",
      "Behavioural — small-team, high-ownership culture"
    ],
    "topicWeightOverrides": {
      "api-design": 1.6,
      "system-design": 1.4,
      "rbi-compliance": 1.5,
      "dsa": 0.9
    },
    "examplesContext": "You are a backend engineer at Razorpay handling UPI flows, Razorpay Capital underwriting, or merchant onboarding, with RBI regulatory context.",
    "source": "curated"
  }
]
```

Write all 40 profiles. The required list (per the test):
- Big Tech (12): google, microsoft, amazon, meta, apple, nvidia, adobe, salesforce, oracle, ibm, intel, qualcomm
- Indian unicorns (15+): flipkart, zomato, swiggy, razorpay, cred, phonepe, paytm, meesho, postman, freshworks, zerodha, nykaa, lenskart, dream11, ola, groww, pine-labs, urban-company
- Consulting (5): mckinsey, bcg, bain, deloitte, kpmg
- Finance (4): goldman-sachs, jpmorgan, morgan-stanley, hdfc-bank, icici-bank
- AI-native (4): openai, anthropic, sarvam, krutrim

For each profile: pull `signatureInterviewElements` directly from the research detail file (per-company entries explicitly call these out); set `topicWeightOverrides` based on what each company emphasises; write `examplesContext` as one Indian-grounded sentence.

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="wave1-companies"
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/seed/data/wave1-companies.json scripts/seed/data/wave1-companies.test.js
git commit -m "feat(diagnostic): add Wave 1 hand-curated company profile seed data"
```

---

## Task 8: seedTopicTaxonomy.js script

**Files:**
- Create: `scripts/seed/seedTopicTaxonomy.js`
- Test: `scripts/seed/seedTopicTaxonomy.test.js`

- [ ] **Step 1: Write the failing test**

Create `scripts/seed/seedTopicTaxonomy.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const taxonomyPath = require.resolve('../../src/models/TopicTaxonomy');
const writes = [];

require.cache[taxonomyPath] = {
  exports: Object.assign(
    function FakeTaxonomy(data) {
      Object.assign(this, data);
      this._id = new mongoose.Types.ObjectId();
      this.save = async () => { writes.push({ ...this }); return this; };
    },
    {
      OBJECTIVE_TYPES: [
        'upskilling', 'interview_preparation', 'exam_preparation',
        'career_switch', 'academic_excellence', 'casual_learning', 'networking',
      ],
      DIFFICULTIES: ['foundational', 'intermediate', 'advanced'],
      bulkWrite: async (ops) => {
        for (const op of ops) {
          writes.push(op.replaceOne ? op.replaceOne.replacement : op);
        }
        return { upsertedCount: ops.length };
      },
    }
  ),
  loaded: true, id: taxonomyPath,
};

delete require.cache[require.resolve('./seedTopicTaxonomy')];
const { seedFromData } = require('./seedTopicTaxonomy');

test('seedFromData: writes one upsert per entry', async () => {
  writes.length = 0;
  const data = [
    {
      objectiveType: 'upskilling',
      targetKey: 'upskilling::pm',
      source: 'curated',
      topics: [{ name: 'X', canonicalName: 'x', description: 'd', baseDifficulty: 'intermediate', sortOrder: 1 }],
    },
    {
      objectiveType: 'exam_preparation',
      targetKey: 'exam_preparation::cat',
      source: 'curated',
      topics: [{ name: 'Quant', canonicalName: 'quant', description: 'd', baseDifficulty: 'advanced', sortOrder: 1 }],
    },
  ];
  const result = await seedFromData(data, { dryRun: false });
  assert.strictEqual(result.upserted, 2);
  assert.strictEqual(writes.length, 2);
});

test('seedFromData: dryRun does not write', async () => {
  writes.length = 0;
  const result = await seedFromData([
    {
      objectiveType: 'upskilling',
      targetKey: 'upskilling::pm',
      source: 'curated',
      topics: [{ name: 'X', canonicalName: 'x', description: 'd', baseDifficulty: 'intermediate', sortOrder: 1 }],
    },
  ], { dryRun: true });
  assert.strictEqual(result.upserted, 1);
  assert.strictEqual(writes.length, 0);
});

test('seedFromData: rejects entry with invalid objectiveType', async () => {
  await assert.rejects(
    seedFromData([{ objectiveType: 'invalid', targetKey: 'x', source: 'curated', topics: [] }]),
    /invalid objectiveType/i
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="seedFromData"
```

Expected: FAIL with "Cannot find module './seedTopicTaxonomy'".

- [ ] **Step 3: Implement the script**

Create `scripts/seed/seedTopicTaxonomy.js`:

```js
require('dotenv').config();
const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');
const TopicTaxonomy = require('../../src/models/TopicTaxonomy');

async function seedFromData(data, opts = {}) {
  if (!Array.isArray(data)) throw new Error('data must be an array');

  for (const entry of data) {
    if (!TopicTaxonomy.OBJECTIVE_TYPES.includes(entry.objectiveType)) {
      throw new Error(`invalid objectiveType: ${entry.objectiveType}`);
    }
  }

  if (opts.dryRun) {
    return { upserted: data.length, dryRun: true };
  }

  const ops = data.map(entry => ({
    replaceOne: {
      filter: { objectiveType: entry.objectiveType, targetKey: entry.targetKey },
      replacement: { ...entry, lastRefreshedAt: new Date() },
      upsert: true,
    },
  }));

  const result = await TopicTaxonomy.bulkWrite(ops);
  return { upserted: result.upsertedCount || ops.length };
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const dataPath = path.join(__dirname, 'data', 'wave1-topics.json');
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));

  if (!dryRun) {
    await mongoose.connect(process.env.MONGODB_URI);
  }
  console.log(`Seeding ${data.length} taxonomy entries (dryRun=${dryRun})...`);
  const result = await seedFromData(data, { dryRun });
  console.log(`Done. Upserted: ${result.upserted}`);
  if (!dryRun) await mongoose.disconnect();
}

if (require.main === module) {
  main().catch(e => { console.error(e); process.exit(1); });
}

module.exports = { seedFromData };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="seedFromData"
```

Expected: 3 tests pass.

- [ ] **Step 5: Dry-run the script**

```bash
node scripts/seed/seedTopicTaxonomy.js --dry-run
```

Expected: console output `Seeding NN taxonomy entries (dryRun=true)... Done. Upserted: NN` where NN matches the count in `wave1-topics.json`.

- [ ] **Step 6: Commit**

```bash
git add scripts/seed/seedTopicTaxonomy.js scripts/seed/seedTopicTaxonomy.test.js
git commit -m "feat(diagnostic): add seedTopicTaxonomy.js with dry-run support"
```

---

## Task 9: seedCompanyProfiles.js script

**Files:**
- Create: `scripts/seed/seedCompanyProfiles.js`
- Test: `scripts/seed/seedCompanyProfiles.test.js`

- [ ] **Step 1: Write the failing test**

Create `scripts/seed/seedCompanyProfiles.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

const cpPath = require.resolve('../../src/models/CompanyProfile');
const writes = [];
require.cache[cpPath] = {
  exports: Object.assign(
    function FakeCP(data) { Object.assign(this, data); },
    {
      bulkWrite: async (ops) => {
        for (const op of ops) writes.push(op.replaceOne.replacement);
        return { upsertedCount: ops.length };
      },
    }
  ),
  loaded: true, id: cpPath,
};

delete require.cache[require.resolve('./seedCompanyProfiles')];
const { seedCompaniesFromData } = require('./seedCompanyProfiles');

test('seedCompaniesFromData: writes one upsert per profile', async () => {
  writes.length = 0;
  const result = await seedCompaniesFromData([
    {
      name: 'Razorpay', normalizedName: 'razorpay', industry: 'Fintech',
      applicableObjectives: ['interview_preparation'],
      signatureInterviewElements: ['x'], examplesContext: 'y', source: 'curated',
    },
  ]);
  assert.strictEqual(result.upserted, 1);
  assert.strictEqual(writes.length, 1);
});

test('seedCompaniesFromData: rejects missing normalizedName', async () => {
  await assert.rejects(
    seedCompaniesFromData([{ name: 'X', industry: 'T', source: 'curated' }]),
    /normalizedName/i
  );
});

test('seedCompaniesFromData: dryRun does not write', async () => {
  writes.length = 0;
  const result = await seedCompaniesFromData([
    {
      name: 'X', normalizedName: 'x', industry: 'T',
      applicableObjectives: ['upskilling'], signatureInterviewElements: ['s'],
      examplesContext: 'c', source: 'curated',
    },
  ], { dryRun: true });
  assert.strictEqual(result.upserted, 1);
  assert.strictEqual(writes.length, 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="seedCompaniesFromData"
```

Expected: FAIL with "Cannot find module".

- [ ] **Step 3: Implement the script**

Create `scripts/seed/seedCompanyProfiles.js`:

```js
require('dotenv').config();
const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');
const CompanyProfile = require('../../src/models/CompanyProfile');

async function seedCompaniesFromData(data, opts = {}) {
  if (!Array.isArray(data)) throw new Error('data must be an array');
  for (const c of data) {
    if (!c.normalizedName) throw new Error('normalizedName required for every profile');
  }
  if (opts.dryRun) return { upserted: data.length, dryRun: true };

  const ops = data.map(c => ({
    replaceOne: {
      filter: { normalizedName: c.normalizedName },
      replacement: { ...c, lastRefreshedAt: new Date() },
      upsert: true,
    },
  }));
  const result = await CompanyProfile.bulkWrite(ops);
  return { upserted: result.upsertedCount || ops.length };
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const dataPath = path.join(__dirname, 'data', 'wave1-companies.json');
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  if (!dryRun) await mongoose.connect(process.env.MONGODB_URI);
  console.log(`Seeding ${data.length} company profiles (dryRun=${dryRun})...`);
  const result = await seedCompaniesFromData(data, { dryRun });
  console.log(`Done. Upserted: ${result.upserted}`);
  if (!dryRun) await mongoose.disconnect();
}

if (require.main === module) {
  main().catch(e => { console.error(e); process.exit(1); });
}

module.exports = { seedCompaniesFromData };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="seedCompaniesFromData"
```

Expected: 3 tests pass.

- [ ] **Step 5: Dry-run**

```bash
node scripts/seed/seedCompanyProfiles.js --dry-run
```

Expected: console output `Seeding NN company profiles (dryRun=true)... Done. Upserted: NN`.

- [ ] **Step 6: Commit**

```bash
git add scripts/seed/seedCompanyProfiles.js scripts/seed/seedCompanyProfiles.test.js
git commit -m "feat(diagnostic): add seedCompanyProfiles.js with dry-run support"
```

---

## Task 10: seedAnchorQuestions.js script

**Files:**
- Create: `scripts/seed/seedAnchorQuestions.js`
- Test: `scripts/seed/seedAnchorQuestions.test.js`

This script generates 2-3 anchor questions per topic via LLM. Anchors are stored with `isAnchor: true` and serve as few-shot examples for the bulk question generation in Task 11.

- [ ] **Step 1: Write the failing test**

Create `scripts/seed/seedAnchorQuestions.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');

const openaiPath = require.resolve('../../src/config/openai');
require.cache[openaiPath] = {
  exports: {
    chat: {
      completions: {
        create: async () => ({
          choices: [{
            message: {
              content: JSON.stringify({
                questions: [
                  {
                    questionText: 'Which framework helps prioritise features?',
                    options: [
                      { label: 'A', text: 'RICE' },
                      { label: 'B', text: 'SOLID' },
                      { label: 'C', text: 'STAR' },
                      { label: 'D', text: 'MEDDIC' },
                    ],
                    correctAnswer: 'A',
                    rationale: 'RICE = Reach × Impact × Confidence ÷ Effort',
                  },
                  {
                    questionText: 'PM at Razorpay must decide between two features. Best first step?',
                    options: [
                      { label: 'A', text: 'Ship both' },
                      { label: 'B', text: 'Define success metrics for each' },
                      { label: 'C', text: 'Ask CEO' },
                      { label: 'D', text: 'A/B test in prod' },
                    ],
                    correctAnswer: 'B',
                    rationale: 'Without metrics no decision can be evaluated.',
                  },
                ],
              }),
            },
          }],
        }),
      },
    },
  },
  loaded: true, id: openaiPath,
};

const qbPath = require.resolve('../../src/models/DiagnosticQuestionBank');
const writes = [];
require.cache[qbPath] = {
  exports: Object.assign(
    function FakeQB(data) { Object.assign(this, data); this.save = async () => { writes.push({ ...this }); return this; }; },
    { insertMany: async (docs) => { writes.push(...docs); return docs; } }
  ),
  loaded: true, id: qbPath,
};

delete require.cache[require.resolve('./seedAnchorQuestions')];
const { generateAnchorsForTopic } = require('./seedAnchorQuestions');

test('generateAnchorsForTopic: returns parsed questions tagged isAnchor', async () => {
  writes.length = 0;
  const topic = {
    canonicalName: 'product-strategy',
    name: 'Product Strategy',
    description: 'Defining product vision and prioritising bets.',
    baseDifficulty: 'intermediate',
  };
  const anchors = await generateAnchorsForTopic(topic, 'upskilling::product-management');
  assert.strictEqual(anchors.length, 2);
  for (const q of anchors) {
    assert.strictEqual(q.isAnchor, true);
    assert.strictEqual(q.canonicalCompetency, 'product-strategy');
    assert.strictEqual(q.generationSource, 'seed_batch');
    assert.ok(q.questionText);
    assert.strictEqual(q.options.length, 4);
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="generateAnchorsForTopic"
```

Expected: FAIL with "Cannot find module".

- [ ] **Step 3: Implement the script**

Create `scripts/seed/seedAnchorQuestions.js`:

```js
require('dotenv').config();
const mongoose = require('mongoose');
const openai = require('../../src/config/openai');
const TopicTaxonomy = require('../../src/models/TopicTaxonomy');
const QuestionBank = require('../../src/models/DiagnosticQuestionBank');

const ANCHOR_SCHEMA = {
  name: 'anchor_questions',
  strict: true,
  schema: {
    type: 'object',
    properties: {
      questions: {
        type: 'array',
        minItems: 2,
        maxItems: 3,
        items: {
          type: 'object',
          properties: {
            questionText: { type: 'string' },
            options: {
              type: 'array',
              minItems: 4,
              maxItems: 4,
              items: {
                type: 'object',
                properties: {
                  label: { type: 'string', enum: ['A', 'B', 'C', 'D'] },
                  text: { type: 'string' },
                },
                required: ['label', 'text'],
                additionalProperties: false,
              },
            },
            correctAnswer: { type: 'string', enum: ['A', 'B', 'C', 'D'] },
            rationale: { type: 'string' },
          },
          required: ['questionText', 'options', 'correctAnswer', 'rationale'],
          additionalProperties: false,
        },
      },
    },
    required: ['questions'],
    additionalProperties: false,
  },
};

const SYSTEM_PROMPT = `You write gold-standard diagnostic anchor questions for an Indian learning platform. These are the reference examples that downstream LLM-generation will mimic — quality matters.

Rules:
- Real-world scenarios, not textbook definitions
- Use Indian company examples where natural (Razorpay, Flipkart, Zomato, Sarvam, etc.)
- Salary references in INR
- Single unambiguously correct answer
- Other options should be plausible-but-wrong, not obviously absurd
- Match the stated difficulty
- No double negatives, no leading wording`;

async function generateAnchorsForTopic(topic, targetKey, opts = {}) {
  const timeoutMs = opts.timeoutMs || 30000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const completion = await openai.chat.completions.create(
      {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          {
            role: 'user',
            content: `Topic: ${topic.name} (${topic.canonicalName})
Topic context: ${topic.description}
Target user context: ${targetKey}
Difficulty: ${topic.baseDifficulty}

Generate 2-3 anchor questions. They will serve as few-shot examples for generating ~12 more questions on this topic.`,
          },
        ],
        response_format: { type: 'json_schema', json_schema: ANCHOR_SCHEMA },
        temperature: 0.6,
        max_tokens: 2000,
      },
      { signal: controller.signal }
    );

    const parsed = JSON.parse(completion.choices[0].message.content);
    return parsed.questions.map(q => ({
      ...q,
      canonicalCompetency: topic.canonicalName,
      difficulty: mapDifficulty(topic.baseDifficulty),
      isAnchor: true,
      generationSource: 'seed_batch',
      verificationStatus: 'pending',
    }));
  } finally {
    clearTimeout(timer);
  }
}

function mapDifficulty(baseDifficulty) {
  return { foundational: 'easy', intermediate: 'medium', advanced: 'hard' }[baseDifficulty] || 'medium';
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  const taxonomies = await TopicTaxonomy.find({}).lean();
  console.log(`Generating anchors for ${taxonomies.length} taxonomies...`);
  let totalAnchors = 0;
  let failures = 0;
  for (const tax of taxonomies) {
    for (const topic of tax.topics) {
      try {
        const anchors = await generateAnchorsForTopic(topic, tax.targetKey);
        await QuestionBank.insertMany(anchors);
        totalAnchors += anchors.length;
        console.log(`  ✓ ${tax.targetKey} :: ${topic.name} (+${anchors.length})`);
      } catch (e) {
        failures++;
        console.error(`  ✗ ${tax.targetKey} :: ${topic.name}: ${e.message}`);
      }
    }
  }
  console.log(`Done. Anchors: ${totalAnchors}, Failures: ${failures}`);
  await mongoose.disconnect();
}

if (require.main === module) {
  main().catch(e => { console.error(e); process.exit(1); });
}

module.exports = { generateAnchorsForTopic };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="generateAnchorsForTopic"
```

Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add scripts/seed/seedAnchorQuestions.js scripts/seed/seedAnchorQuestions.test.js
git commit -m "feat(diagnostic): add seedAnchorQuestions.js for gold-standard anchor questions"
```

---

## Task 11: seedQuestionBank.js — bulk question generation

**Files:**
- Create: `scripts/seed/seedQuestionBank.js`
- Test: `scripts/seed/seedQuestionBank.test.js`

This script generates ~10 questions per (topic × difficulty), in parallel batches of 6, using the anchor questions from Task 10 as few-shot examples. Each generated question is run through the Tier 1 validator (Task 5) and stored with the resulting `verificationStatus`.

- [ ] **Step 1: Write the failing test**

Create `scripts/seed/seedQuestionBank.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert');

const openaiPath = require.resolve('../../src/config/openai');
require.cache[openaiPath] = {
  exports: {
    chat: {
      completions: {
        create: async () => ({
          choices: [{
            message: {
              content: JSON.stringify({
                questions: [
                  {
                    questionText: 'Q1?',
                    options: [
                      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
                      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
                    ],
                    correctAnswer: 'A',
                    rationale: 'r',
                  },
                  {
                    questionText: 'Q2?',
                    options: [
                      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
                      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
                    ],
                    correctAnswer: 'B',
                    rationale: 'r',
                  },
                ],
              }),
            },
          }],
        }),
      },
    },
  },
  loaded: true, id: openaiPath,
};

const validatorPath = require.resolve('../../src/services/diagnostic/questionValidatorService');
require.cache[validatorPath] = {
  exports: {
    validateQuestion: async () => ({ score: 92, critique: 'good', issues: [], status: 'auto_verified' }),
    classifyScore: () => 'auto_verified',
  },
  loaded: true, id: validatorPath,
};

delete require.cache[require.resolve('./seedQuestionBank')];
const { generateBatch } = require('./seedQuestionBank');

test('generateBatch: returns validated questions tagged with status', async () => {
  const topic = {
    canonicalName: 'product-strategy',
    name: 'Product Strategy',
    description: 'Defining product vision.',
    baseDifficulty: 'intermediate',
  };
  const anchors = [
    { questionText: 'AnchorQ1', options: [
      { label: 'A', text: 'a' }, { label: 'B', text: 'b' },
      { label: 'C', text: 'c' }, { label: 'D', text: 'd' },
    ], correctAnswer: 'A', rationale: 'r' },
  ];
  const questions = await generateBatch(topic, 'upskilling::product-management', 'medium', anchors, 4);
  assert.strictEqual(questions.length, 2);
  for (const q of questions) {
    assert.strictEqual(q.verificationStatus, 'auto_verified');
    assert.strictEqual(q.validatorScore, 92);
    assert.strictEqual(q.canonicalCompetency, 'product-strategy');
    assert.strictEqual(q.difficulty, 'medium');
    assert.strictEqual(q.isAnchor, false);
    assert.strictEqual(q.generationSource, 'seed_batch');
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --test-name-pattern="generateBatch"
```

Expected: FAIL with "Cannot find module".

- [ ] **Step 3: Implement the script**

Create `scripts/seed/seedQuestionBank.js`:

```js
require('dotenv').config();
const mongoose = require('mongoose');
const openai = require('../../src/config/openai');
const TopicTaxonomy = require('../../src/models/TopicTaxonomy');
const QuestionBank = require('../../src/models/DiagnosticQuestionBank');
const { validateQuestion } = require('../../src/services/diagnostic/questionValidatorService');

const BATCH_SCHEMA = {
  name: 'question_batch',
  strict: true,
  schema: {
    type: 'object',
    properties: {
      questions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            questionText: { type: 'string' },
            options: {
              type: 'array',
              minItems: 4,
              maxItems: 4,
              items: {
                type: 'object',
                properties: {
                  label: { type: 'string', enum: ['A', 'B', 'C', 'D'] },
                  text: { type: 'string' },
                },
                required: ['label', 'text'],
                additionalProperties: false,
              },
            },
            correctAnswer: { type: 'string', enum: ['A', 'B', 'C', 'D'] },
            rationale: { type: 'string' },
          },
          required: ['questionText', 'options', 'correctAnswer', 'rationale'],
          additionalProperties: false,
        },
      },
    },
    required: ['questions'],
    additionalProperties: false,
  },
};

const SYSTEM_PROMPT = `You generate diagnostic questions for an Indian learning platform.
Rules:
- Real-world scenarios, not textbook definitions
- Indian company examples where natural (Razorpay, Flipkart, Zomato, etc.)
- INR salary references where relevant
- Single unambiguously correct answer
- Plausible-but-wrong distractors
- Match the stated difficulty exactly
- No double negatives, no leading wording`;

function buildAnchorsBlock(anchors) {
  return anchors
    .slice(0, 3)
    .map((a, i) => {
      const opts = a.options.map(o => `${o.label}. ${o.text}`).join('\n');
      return `Anchor ${i + 1}:\n${a.questionText}\n${opts}\nCorrect: ${a.correctAnswer}`;
    })
    .join('\n\n');
}

async function generateBatch(topic, targetKey, difficulty, anchors, count = 4, opts = {}) {
  const timeoutMs = opts.timeoutMs || 30000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const completion = await openai.chat.completions.create(
      {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          {
            role: 'user',
            content: `Topic: ${topic.name} (${topic.canonicalName})
Topic context: ${topic.description}
Target user context: ${targetKey}
Difficulty: ${difficulty}
Generate exactly ${count} questions in the same style and rigour as these anchors:

${buildAnchorsBlock(anchors)}`,
          },
        ],
        response_format: { type: 'json_schema', json_schema: BATCH_SCHEMA },
        temperature: 0.7,
        max_tokens: 2500,
      },
      { signal: controller.signal }
    );
    const parsed = JSON.parse(completion.choices[0].message.content);
    const validated = [];
    for (const q of parsed.questions) {
      const enriched = {
        ...q,
        canonicalCompetency: topic.canonicalName,
        difficulty,
        isAnchor: false,
        generationSource: 'seed_batch',
      };
      const v = await validateQuestion(enriched);
      validated.push({
        ...enriched,
        verificationStatus: v.status,
        validatorScore: v.score,
        validatorCritique: v.critique,
      });
    }
    return validated;
  } finally {
    clearTimeout(timer);
  }
}

async function runBatchesInParallel(jobs, concurrency = 6) {
  const results = [];
  for (let i = 0; i < jobs.length; i += concurrency) {
    const slice = jobs.slice(i, i + concurrency);
    const settled = await Promise.allSettled(slice.map(j => j()));
    results.push(...settled);
  }
  return results;
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  const taxonomies = await TopicTaxonomy.find({}).lean();
  const difficulties = ['easy', 'medium', 'hard'];

  const jobs = [];
  for (const tax of taxonomies) {
    for (const topic of tax.topics) {
      const anchors = await QuestionBank.find({
        canonicalCompetency: topic.canonicalName,
        isAnchor: true,
      }).lean();
      if (anchors.length === 0) {
        console.warn(`No anchors found for ${topic.canonicalName} — skipping`);
        continue;
      }
      for (const diff of difficulties) {
        jobs.push(async () => {
          const questions = await generateBatch(topic, tax.targetKey, diff, anchors, 4);
          await QuestionBank.insertMany(questions);
          return { targetKey: tax.targetKey, topic: topic.canonicalName, diff, count: questions.length };
        });
      }
    }
  }

  console.log(`Running ${jobs.length} generation jobs (concurrency=6)...`);
  const results = await runBatchesInParallel(jobs, 6);
  const ok = results.filter(r => r.status === 'fulfilled').length;
  const failed = results.filter(r => r.status === 'rejected').length;
  console.log(`Done. OK: ${ok}, Failed: ${failed}`);
  await mongoose.disconnect();
}

if (require.main === module) {
  main().catch(e => { console.error(e); process.exit(1); });
}

module.exports = { generateBatch, runBatchesInParallel };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --test-name-pattern="generateBatch"
```

Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add scripts/seed/seedQuestionBank.js scripts/seed/seedQuestionBank.test.js
git commit -m "feat(diagnostic): add seedQuestionBank.js with parallel batching + Tier 1 validation"
```

---

## Task 12: runWave1.js orchestrator

**Files:**
- Create: `scripts/seed/runWave1.js`

Orchestrates the 4 seeding steps in order, with manual checkpoints (prompt for confirmation between expensive LLM steps).

- [ ] **Step 1: Implement the orchestrator (no test needed — purely sequential script)**

Create `scripts/seed/runWave1.js`:

```js
require('dotenv').config();
const mongoose = require('mongoose');
const readline = require('readline');
const fs = require('fs');
const path = require('path');

const TopicTaxonomy = require('../../src/models/TopicTaxonomy');
const CompanyProfile = require('../../src/models/CompanyProfile');
const QuestionBank = require('../../src/models/DiagnosticQuestionBank');

const { seedFromData } = require('./seedTopicTaxonomy');
const { seedCompaniesFromData } = require('./seedCompanyProfiles');
const { generateAnchorsForTopic } = require('./seedAnchorQuestions');
const { generateBatch, runBatchesInParallel } = require('./seedQuestionBank');

function prompt(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(res => rl.question(q, ans => { rl.close(); res(ans); }));
}

async function main() {
  const skipPrompts = process.argv.includes('--yes');
  await mongoose.connect(process.env.MONGODB_URI);

  // Step 1: topics
  const topics = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'wave1-topics.json'), 'utf8'));
  console.log(`\n=== Step 1: Seed ${topics.length} taxonomy entries ===`);
  if (!skipPrompts && (await prompt('Proceed? (y/N) ')).toLowerCase() !== 'y') return;
  const r1 = await seedFromData(topics);
  console.log(`Upserted ${r1.upserted} taxonomy entries.`);

  // Step 2: companies
  const companies = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'wave1-companies.json'), 'utf8'));
  console.log(`\n=== Step 2: Seed ${companies.length} company profiles ===`);
  if (!skipPrompts && (await prompt('Proceed? (y/N) ')).toLowerCase() !== 'y') return;
  const r2 = await seedCompaniesFromData(companies);
  console.log(`Upserted ${r2.upserted} company profiles.`);

  // Step 3: anchors (LLM, ~$5-10)
  const allTopics = await TopicTaxonomy.find({}).lean();
  const totalTopicCount = allTopics.reduce((sum, t) => sum + t.topics.length, 0);
  console.log(`\n=== Step 3: Generate ${totalTopicCount * 2}-${totalTopicCount * 3} anchor questions (LLM, est. $5-10) ===`);
  if (!skipPrompts && (await prompt('Proceed? (y/N) ')).toLowerCase() !== 'y') return;
  let anchorCount = 0;
  for (const tax of allTopics) {
    for (const topic of tax.topics) {
      try {
        const anchors = await generateAnchorsForTopic(topic, tax.targetKey);
        await QuestionBank.insertMany(anchors);
        anchorCount += anchors.length;
        process.stdout.write(`\rAnchors generated: ${anchorCount}`);
      } catch (e) {
        console.error(`\nAnchor failure for ${tax.targetKey}::${topic.canonicalName}: ${e.message}`);
      }
    }
  }
  console.log(`\nTotal anchors: ${anchorCount}`);

  // Step 4: bulk questions (LLM, ~$50)
  console.log(`\n=== Step 4: Generate bulk questions for ~${totalTopicCount * 3} (topic × difficulty) slots (LLM, est. $50) ===`);
  if (!skipPrompts && (await prompt('Proceed? (y/N) ')).toLowerCase() !== 'y') return;
  const difficulties = ['easy', 'medium', 'hard'];
  const jobs = [];
  for (const tax of allTopics) {
    for (const topic of tax.topics) {
      const anchors = await QuestionBank.find({ canonicalCompetency: topic.canonicalName, isAnchor: true }).lean();
      if (!anchors.length) continue;
      for (const diff of difficulties) {
        jobs.push(async () => {
          const qs = await generateBatch(topic, tax.targetKey, diff, anchors, 4);
          await QuestionBank.insertMany(qs);
          return qs.length;
        });
      }
    }
  }
  console.log(`Running ${jobs.length} batches (concurrency=6)...`);
  const results = await runBatchesInParallel(jobs, 6);
  const ok = results.filter(r => r.status === 'fulfilled').length;
  const failed = results.filter(r => r.status === 'rejected').length;
  const totalQuestions = results
    .filter(r => r.status === 'fulfilled')
    .reduce((sum, r) => sum + r.value, 0);
  console.log(`\nDone. Batches OK: ${ok}, Failed: ${failed}. Total questions: ${totalQuestions}`);

  // Summary
  const taxCount = await TopicTaxonomy.countDocuments();
  const cpCount = await CompanyProfile.countDocuments();
  const qbCount = await QuestionBank.countDocuments();
  const verified = await QuestionBank.countDocuments({ verificationStatus: 'auto_verified' });
  const flagged = await QuestionBank.countDocuments({ verificationStatus: 'flagged_for_review' });
  console.log(`\n=== Wave 1 Summary ===`);
  console.log(`Taxonomies: ${taxCount}`);
  console.log(`Company profiles: ${cpCount}`);
  console.log(`Questions total: ${qbCount}`);
  console.log(`  auto_verified: ${verified}`);
  console.log(`  flagged_for_review: ${flagged}`);

  await mongoose.disconnect();
}

if (require.main === module) {
  main().catch(e => { console.error(e); process.exit(1); });
}
```

- [ ] **Step 2: Verify the script syntax-checks**

```bash
node --check scripts/seed/runWave1.js
```

Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add scripts/seed/runWave1.js
git commit -m "feat(diagnostic): add Wave 1 orchestrator script with checkpoints"
```

---

## Task 13: Run Wave 1 batch in production

This task runs the actual seed batch against the production MongoDB (or a designated staging DB). It is operational, not code-writing.

- [ ] **Step 1: Confirm `.env` has correct MONGODB_URI and OPENAI_API_KEY**

```bash
grep -E '^(MONGODB_URI|OPENAI_API_KEY)=' .env | wc -l
```

Expected: `2`. If less, add the missing var(s).

- [ ] **Step 2: Run all unit tests one more time to confirm green**

```bash
npm test
```

Expected: all tests pass. If any fail, fix before proceeding.

- [ ] **Step 3: Run the Wave 1 orchestrator interactively**

```bash
node scripts/seed/runWave1.js
```

You will be prompted before each of the 4 steps:
- Step 1 (taxonomy): instant, free.
- Step 2 (companies): instant, free.
- Step 3 (anchors): ~10-20 min, ~$5-10.
- Step 4 (bulk questions): ~3-5 hours, ~$50.

**Total wall-clock: ~3-5 hours. Total LLM cost: ~$50-60.**

If anything fails mid-run, the script can be re-run — it uses upserts for taxonomies and companies, and `insertMany` for questions (so re-running Step 4 will create duplicate questions; manually delete and re-run the affected batch if needed).

- [ ] **Step 4: Verify final counts**

```bash
node -e "
const mongoose = require('mongoose');
require('dotenv').config();
(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  const Tx = require('./src/models/TopicTaxonomy');
  const CP = require('./src/models/CompanyProfile');
  const QB = require('./src/models/DiagnosticQuestionBank');
  console.log('Taxonomies:', await Tx.countDocuments());
  console.log('Companies:', await CP.countDocuments());
  console.log('Questions total:', await QB.countDocuments());
  console.log('  auto_verified:', await QB.countDocuments({ verificationStatus: 'auto_verified' }));
  console.log('  pending:', await QB.countDocuments({ verificationStatus: 'pending' }));
  console.log('  flagged_for_review:', await QB.countDocuments({ verificationStatus: 'flagged_for_review' }));
  console.log('  isAnchor:', await QB.countDocuments({ isAnchor: true }));
  await mongoose.disconnect();
})();
"
```

Expected output (rough targets — adjust if Wave 1 final entry count differs):
- Taxonomies: 80-100
- Companies: 40
- Questions total: 8,000-10,000
- auto_verified: ≥7,000 (≥80% pass rate target)
- flagged_for_review: <500 (<5% target — these go into Tier 2 admin review queue, built in Plan 4)

- [ ] **Step 5: Sample-check 10 random questions for quality**

```bash
node -e "
const mongoose = require('mongoose');
require('dotenv').config();
(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  const QB = require('./src/models/DiagnosticQuestionBank');
  const samples = await QB.aggregate([{ \$sample: { size: 10 } }]);
  for (const q of samples) {
    console.log('---');
    console.log('Topic:', q.canonicalCompetency, '| Difficulty:', q.difficulty, '| Status:', q.verificationStatus, '| Score:', q.validatorScore);
    console.log('Q:', q.questionText);
    q.options.forEach(o => console.log(' ', o.label + '.', o.text));
    console.log('Correct:', q.correctAnswer);
  }
  await mongoose.disconnect();
})();
"
```

Manually inspect: do questions read like real-world scenarios (not textbook definitions)? Are Indian examples present? Do answers feel unambiguous?

If quality looks poor (e.g., textbook-rote questions dominate, no Indian examples), adjust the SYSTEM_PROMPT in `seedQuestionBank.js` and re-run a small subset to verify before re-running the full Wave 1.

- [ ] **Step 6: Commit a seeding completion record**

Create `scripts/seed/data/wave1-completion.md`:

```markdown
# Wave 1 Seeding Completion

**Date:** [today's date]
**Operator:** [your name]

## Final counts
- Taxonomies: [N]
- Companies: [N]
- Questions: [N total / N auto_verified / N flagged]
- Anchors: [N]

## Cost
- ~$[X] LLM compute

## Notes
- [Any anomalies, retries, manual fixes]
```

```bash
git add scripts/seed/data/wave1-completion.md
git commit -m "chore(diagnostic): record Wave 1 seeding completion"
```

- [ ] **Step 7: Push the branch**

```bash
git push -u origin feat/diagnostic-phase0.5-seed
```

---

## Self-Review Checklist (run by Claude before handing back)

**1. Spec coverage check** — Each spec section that touches seeding is covered:
- ✅ Spec §4.5 (DiagnosticQuestionBank schema additions) → Task 3
- ✅ Spec §4.6 (DiagnosticSyllabus model) → DEFERRED to Plan 2 (only needed for syllabus upload, not seeding)
- ✅ Spec §5.5 (Two-tier validation — Tier 1) → Task 5
- ✅ Spec §6.0 (Phase 0 research deliverable) → DONE in prior step
- ✅ Spec §6.1 (Hand-curated taxonomy seed) → Tasks 6, 8
- ✅ Spec §6.5 (Anchor-question pattern) → Tasks 10, 11
- ✅ Spec §8.1 (Hand-curated company profiles) → Tasks 7, 9
- ✅ Spec §15 Phase 0.5 → Tasks 1-13
- 🔁 Spec §6.4 (India-centric LLM prompt framing) → Embedded in SYSTEM_PROMPT for Tasks 10, 11

**2. Placeholder scan** — No "TBD", "TODO", or "fill in details" in any task. Each step shows complete code or exact commands. The data files (Tasks 6, 7) are partially shown with sample structure + a complete required-coverage table — implementer fills in remaining entries by referencing the cited research files. This is intentional: writing 700 topic descriptions inline would 5x the plan length. The structural pattern is fully shown, the test asserts coverage, and the source data file is the authority. Acceptable.

**3. Type consistency check:**
- `objectiveType` enum values consistent across TopicTaxonomy model + buildTargetKey + tests ✅
- `verificationStatus` enum consistent across DiagnosticQuestionBank model + validator service + seedQuestionBank ✅
- `generationSource` enum consistent across DiagnosticQuestionBank model + seed scripts ✅
- `baseDifficulty` (taxonomy: foundational/intermediate/advanced) maps to `difficulty` (questions: easy/medium/hard) via `mapDifficulty` in Task 10 ✅
- `canonicalName` used consistently as the topic identifier across models, services, and seed data ✅

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-03-diagnostic-phase0.5-seed-scripts.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, two-stage review between tasks (spec compliance + code quality), fast iteration. Best for code-heavy plans like this one.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Slower but you stay closer to the work.

**Which approach?**

(Note: Tasks 6 and 7 — the hand-curated JSON data files — are research-heavy and may take a subagent significantly longer than typical TDD tasks. Worth being aware.)
