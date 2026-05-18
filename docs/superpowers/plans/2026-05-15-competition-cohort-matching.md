# Competition Cohort Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the locked design from `docs/superpowers/specs/2026-05-15-competition-cohort-matching-design.md` — users with similar objectives compete on the same daily challenge via LLM-canonicalized topics, per-user shuffle defeats screenshot-sharing, ghost participants populate tiny cohorts, and competition score moves the Home readiness number.

**Architecture:** Two backend repos (ScaleUpDemo/scaleup-backend for API + workers, ScaleUpDemo-f for iOS). New canonicalization service + `CohortDirectory` model on backend; existing `DailyChallenge` / `ChallengeAttempt` / `WeeklyLeaderboard` models stay, but their effective cohort key changes from "derived-from-specifics" to `canonicalTopic`. iOS surface changes are minimal — a hint line + ghost-row honoring on existing screens.

**Tech Stack:** Node.js + Express + Mongoose + BullMQ on backend; OpenAI `gpt-4o-mini` for canonicalization; `node:test` for backend tests; SwiftUI on iOS.

---

## Conventions

- **All backend paths** are relative to `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`.
- **All iOS paths** are relative to `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/`.
- **Test runner:** `npm test` (executes `scripts/run-tests.js`).
- **Run a single test file:** `node --test src/services/<name>.test.js`.
- **iOS build verify:** `cd <ios-root> && xcodegen && xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Debug -destination "generic/platform=iOS" build`.
- **Commit cadence:** after each task. Branch is `master` for backend (auto-deploys to EC2) and `v2-redesign` for iOS.
- **All commits end with:** `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

## File Structure

**Backend — to be created:**
- `src/config/canonicalTopics.js` — curated taxonomy + objective-type mappings
- `src/services/topicCanonicalizationService.js` — LLM-backed canonicalizer with cache + fallback
- `src/services/topicCanonicalizationService.test.js` — unit tests
- `src/models/CohortDirectory.js` — Mongoose model
- `src/services/cohortDirectoryService.js` — upsert/decrement/refresh logic
- `src/services/cohortDirectoryService.test.js` — unit tests
- `src/workers/cohortDirectoryHousekeepingWorker.js` — nightly drift correction
- `src/services/challengeShuffleService.js` — deterministic per-user shuffle + inverse
- `src/services/challengeShuffleService.test.js` — unit tests
- `src/services/ghostLeaderboardService.js` — synthetic entry generation
- `src/services/ghostLeaderboardService.test.js` — unit tests
- `scripts/backfill-canonical-topics.js` — one-shot backfill
- `scripts/bootstrap-cohort-directory.js` — one-shot directory seeding

**Backend — to be modified:**
- `src/models/UserObjective.js` — add `canonicalTopic` fields + pre-save hook
- `src/services/challengeGenerationService.js` — read cohorts from directory, not raw objectives
- `src/services/competitionService.js` — shuffle on start, inverse on answer, mastery bridge on complete, ghost composition on leaderboard
- `src/controllers/competitionController.js` — `/competition/relevant` returns cohort size + cohortPlayedToday
- `src/services/knowledgeService.js` — add `source` + `weight` parameters to `updateMastery`
- `src/workers/cronJobs.js` — register `cohortDirectoryHousekeeping` cron

**iOS — to be modified:**
- `ScaleUp/Features/V2/Compass/V2CompetitionHomeView.swift` — render cohort size hint
- `ScaleUp/Features/Competition/Views/WeeklyLeaderboardView.swift` (or equivalent) — italic ghost rows + long-press subtext
- `ScaleUp/Features/Competition/Models/*.swift` — add `ghostKind` to leaderboard entry decode

---

## Phase 1 — Canonical Topic Foundation

### Task 1: Curated taxonomy file

**Files:**
- Create: `src/config/canonicalTopics.js`

- [ ] **Step 1: Write the file**

```js
/**
 * Canonical taxonomy used by topicCanonicalizationService to map a user's
 * free-text objective into a fixed cohort key. Each entry is keyed by its
 * canonical slug and lists the objectiveTypes it is valid for. Aliases
 * exist purely as hints to the LLM prompt — they are NOT used for exact
 * string matching (that's the LLM's job).
 *
 * Adding a new canonical topic:
 *   1. Add an entry below.
 *   2. List the objectiveTypes it applies to.
 *   3. (Optional) List a few common aliases to help the LLM choose it.
 *
 * Display names are seeded here for the CohortDirectory; the LLM-titled
 * version on the directory wins when present.
 */

const CANONICAL_TOPICS = [
  // Exam prep
  { slug: 'gmat', display: 'GMAT', objectiveTypes: ['exam_preparation'], aliases: ['gmat focus', 'gmat exam'] },
  { slug: 'gre', display: 'GRE', objectiveTypes: ['exam_preparation'], aliases: [] },
  { slug: 'cat', display: 'CAT', objectiveTypes: ['exam_preparation'], aliases: ['common admission test'] },
  { slug: 'upsc', display: 'UPSC', objectiveTypes: ['exam_preparation'], aliases: ['ias', 'civil services'] },
  { slug: 'ielts', display: 'IELTS', objectiveTypes: ['exam_preparation'], aliases: [] },
  { slug: 'toefl', display: 'TOEFL', objectiveTypes: ['exam_preparation'], aliases: [] },
  { slug: 'sat', display: 'SAT', objectiveTypes: ['exam_preparation'], aliases: [] },
  { slug: 'jee', display: 'JEE', objectiveTypes: ['exam_preparation'], aliases: ['iit-jee'] },
  { slug: 'neet', display: 'NEET', objectiveTypes: ['exam_preparation'], aliases: [] },

  // Interview prep — engineering
  { slug: 'software-engineer', display: 'Software Engineer', objectiveTypes: ['interview_preparation'], aliases: ['sde', 'swe', 'developer'] },
  { slug: 'frontend-engineer', display: 'Frontend Engineer', objectiveTypes: ['interview_preparation'], aliases: ['frontend dev', 'ui engineer'] },
  { slug: 'backend-engineer', display: 'Backend Engineer', objectiveTypes: ['interview_preparation'], aliases: ['backend dev', 'server engineer'] },
  { slug: 'mobile-engineer', display: 'Mobile Engineer', objectiveTypes: ['interview_preparation'], aliases: ['ios engineer', 'android engineer'] },
  { slug: 'devops-engineer', display: 'DevOps Engineer', objectiveTypes: ['interview_preparation'], aliases: ['sre', 'platform engineer'] },
  { slug: 'data-engineer', display: 'Data Engineer', objectiveTypes: ['interview_preparation'], aliases: [] },
  { slug: 'machine-learning-engineer', display: 'ML Engineer', objectiveTypes: ['interview_preparation'], aliases: ['ml engineer', 'mle'] },

  // Interview prep — business / data
  { slug: 'product-manager', display: 'Product Manager', objectiveTypes: ['interview_preparation'], aliases: ['pm', 'product management', 'apm'] },
  { slug: 'data-scientist', display: 'Data Scientist', objectiveTypes: ['interview_preparation'], aliases: ['ds'] },
  { slug: 'data-analyst', display: 'Data Analyst', objectiveTypes: ['interview_preparation'], aliases: [] },
  { slug: 'consultant', display: 'Consultant', objectiveTypes: ['interview_preparation'], aliases: ['management consultant', 'mbb'] },
  { slug: 'investment-banker', display: 'Investment Banker', objectiveTypes: ['interview_preparation'], aliases: ['ib', 'banking'] },

  // Admissions
  { slug: 'mba-admissions', display: 'MBA Admissions', objectiveTypes: ['interview_preparation'], aliases: ['mba'] },

  // Upskilling — broad domains
  { slug: 'system-design', display: 'System Design', objectiveTypes: ['upskilling'], aliases: ['distributed systems', 'architecture'] },
  { slug: 'machine-learning', display: 'Machine Learning', objectiveTypes: ['upskilling'], aliases: ['ml', 'deep learning'] },
  { slug: 'data-science', display: 'Data Science', objectiveTypes: ['upskilling'], aliases: [] },
  { slug: 'product-strategy', display: 'Product Strategy', objectiveTypes: ['upskilling'], aliases: ['product thinking'] },
  { slug: 'cloud-engineering', display: 'Cloud Engineering', objectiveTypes: ['upskilling'], aliases: ['aws', 'gcp', 'azure'] },
  { slug: 'cybersecurity', display: 'Cybersecurity', objectiveTypes: ['upskilling'], aliases: ['infosec', 'security'] },

  // Career switch — broad target buckets
  { slug: 'switch-to-tech', display: 'Switch to Tech', objectiveTypes: ['career_switch'], aliases: ['career change to tech'] },
  { slug: 'switch-to-product', display: 'Switch to Product', objectiveTypes: ['career_switch'], aliases: [] },
  { slug: 'switch-to-data', display: 'Switch to Data', objectiveTypes: ['career_switch'], aliases: [] },

  // Universal fallback bucket — never user-facing as a goal, but used when
  // the LLM can't find a confident match for the user's free-text input.
  { slug: 'general-learning', display: 'General Learning', objectiveTypes: ['exam_preparation', 'interview_preparation', 'upskilling', 'career_switch'], aliases: [] },
];

function topicsForObjectiveType(objectiveType) {
  return CANONICAL_TOPICS.filter(t => t.objectiveTypes.includes(objectiveType));
}

function findBySlug(slug) {
  if (!slug) return null;
  return CANONICAL_TOPICS.find(t => t.slug === slug) || null;
}

module.exports = { CANONICAL_TOPICS, topicsForObjectiveType, findBySlug };
```

- [ ] **Step 2: Sanity-check it loads**

Run: `node -e "console.log(require('./src/config/canonicalTopics').topicsForObjectiveType('exam_preparation').length)"`
Expected: `9`

- [ ] **Step 3: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/config/canonicalTopics.js
git commit -m "feat(competition): canonical topic taxonomy

Curated list of ~30 cohort topics tagged by objectiveType plus a universal
general-learning fallback bucket. Consumed by topicCanonicalizationService
to constrain the LLM's choice when canonicalizing a user's free-text goal.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Canonicalization service — tests first

**Files:**
- Create: `src/services/topicCanonicalizationService.test.js`

- [ ] **Step 1: Write the failing tests**

```js
const test = require('node:test');
const assert = require('node:assert');
const Module = require('module');

// Stub openai before requiring the service.
const openaiPath = require.resolve('../config/openai');
let mockOpenAICreate;
require.cache[openaiPath] = {
  exports: { chat: { completions: { create: (...args) => mockOpenAICreate(...args) } } },
  loaded: true, id: openaiPath,
};

const svc = require('./topicCanonicalizationService');

test('canonicalize: returns LLM canonical slug on confident match', async () => {
  mockOpenAICreate = async () => ({
    choices: [{ message: { content: JSON.stringify({ canonicalTopic: 'product-manager', confidence: 0.93 }) } }],
  });
  svc._internal.clearCache();
  const r = await svc.canonicalize('Senior PM at FAANG', 'interview_preparation');
  assert.equal(r.canonicalTopic, 'product-manager');
  assert.equal(r.source, 'llm');
  assert.ok(r.confidence >= 0.9);
});

test('canonicalize: cache hit on identical input', async () => {
  let calls = 0;
  mockOpenAICreate = async () => {
    calls++;
    return { choices: [{ message: { content: JSON.stringify({ canonicalTopic: 'gmat', confidence: 0.95 }) } }] };
  };
  svc._internal.clearCache();
  await svc.canonicalize('GMAT 720', 'exam_preparation');
  await svc.canonicalize('GMAT 720', 'exam_preparation');
  assert.equal(calls, 1, 'LLM should have been called exactly once for cached input');
});

test('canonicalize: invalid LLM slug falls back to general-learning', async () => {
  mockOpenAICreate = async () => ({
    choices: [{ message: { content: JSON.stringify({ canonicalTopic: 'made-up-slug-that-is-not-in-taxonomy', confidence: 0.9 }) } }],
  });
  svc._internal.clearCache();
  const r = await svc.canonicalize('Niche thing', 'upskilling');
  assert.equal(r.canonicalTopic, 'general-learning');
  assert.equal(r.source, 'llm-coerced');
});

test('canonicalize: LLM throws → fallback to normalizeTopic of raw text', async () => {
  mockOpenAICreate = async () => { throw new Error('openai down'); };
  svc._internal.clearCache();
  const r = await svc.canonicalize('  My Custom Topic  ', 'upskilling');
  assert.equal(r.canonicalTopic, 'my custom topic');
  assert.equal(r.source, 'fallback');
});

test('canonicalize: empty input returns general-learning, no LLM call', async () => {
  let called = false;
  mockOpenAICreate = async () => { called = true; return { choices: [] }; };
  svc._internal.clearCache();
  const r = await svc.canonicalize('', 'upskilling');
  assert.equal(r.canonicalTopic, 'general-learning');
  assert.equal(called, false);
});
```

- [ ] **Step 2: Run to confirm they fail**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
node --test src/services/topicCanonicalizationService.test.js
```

Expected: failures — `Cannot find module './topicCanonicalizationService'`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add src/services/topicCanonicalizationService.test.js
git commit -m "test(competition): canonicalization service spec

Tests for confident match, cache hit, invalid-slug coercion, LLM failure
fallback, and empty-input short-circuit. All failing pending implementation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Canonicalization service — implementation

**Files:**
- Create: `src/services/topicCanonicalizationService.js`

- [ ] **Step 1: Write the service**

```js
const openai = require('../config/openai');
const { CANONICAL_TOPICS, topicsForObjectiveType, findBySlug } = require('../config/canonicalTopics');
const normalizeTopic = require('../utils/normalizeTopic');

const CACHE_TTL_MS = 90 * 24 * 60 * 60 * 1000; // 90 days
const CACHE_MAX_ENTRIES = 5000;
const _cache = new Map(); // key → { value, expiresAt }

function _cacheKey(rawText, objectiveType) {
  return `${objectiveType}::${(rawText || '').trim().toLowerCase()}`;
}

function _cacheGet(key) {
  const entry = _cache.get(key);
  if (!entry || entry.expiresAt < Date.now()) {
    if (entry) _cache.delete(key);
    return null;
  }
  return entry.value;
}

function _cacheSet(key, value) {
  if (_cache.size >= CACHE_MAX_ENTRIES) {
    // Simple eviction: drop the oldest 10%.
    const drop = Math.floor(CACHE_MAX_ENTRIES * 0.1);
    let i = 0;
    for (const k of _cache.keys()) {
      _cache.delete(k);
      if (++i >= drop) break;
    }
  }
  _cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
}

function _buildPrompt(rawText, objectiveType) {
  const choices = topicsForObjectiveType(objectiveType);
  const list = choices
    .map(c => `- ${c.slug}${c.aliases.length ? ` (also: ${c.aliases.join(', ')})` : ''}`)
    .join('\n');
  return `Map this user's free-text goal to ONE canonical topic slug from the list below.

User's objective type: ${objectiveType}
User's free-text goal: "${rawText}"

Allowed canonical topics for this objective type:
${list}

Rules:
- Return ONLY a JSON object: {"canonicalTopic": "<slug>", "confidence": 0.0-1.0}.
- Pick the most specific slug that fits.
- If nothing fits with confidence >= 0.5, return {"canonicalTopic": "general-learning", "confidence": 0.5}.
- Do not invent a slug that is not in the list.`;
}

/**
 * Canonicalize a user's free-text objective into a cohort key.
 *
 * @param {string} rawText - User's free-text goal (e.g., "Senior PM at FAANG").
 * @param {string} objectiveType - One of exam_preparation, interview_preparation, upskilling, career_switch.
 * @returns {Promise<{canonicalTopic: string, confidence: number, source: 'llm'|'cache'|'llm-coerced'|'fallback'|'empty'}>}
 */
async function canonicalize(rawText, objectiveType) {
  if (!rawText || !rawText.trim()) {
    return { canonicalTopic: 'general-learning', confidence: 0.5, source: 'empty' };
  }

  const cacheKey = _cacheKey(rawText, objectiveType);
  const cached = _cacheGet(cacheKey);
  if (cached) return { ...cached, source: 'cache' };

  let parsed = null;
  let llmError = null;
  try {
    const resp = await openai.chat.completions.create({
      model: process.env.CANONICALIZATION_MODEL || 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You map free-text goals to canonical cohort slugs. Output only JSON.' },
        { role: 'user', content: _buildPrompt(rawText, objectiveType) },
      ],
      response_format: { type: 'json_object' },
      temperature: 0,
      max_tokens: 60,
    });
    const text = resp.choices?.[0]?.message?.content || '{}';
    parsed = JSON.parse(text);
  } catch (err) {
    llmError = err;
  }

  if (llmError || !parsed || typeof parsed.canonicalTopic !== 'string') {
    const fallback = normalizeTopic(rawText) || 'general-learning';
    const result = { canonicalTopic: fallback, confidence: 0, source: 'fallback' };
    // Do NOT cache fallback — the LLM might recover next time.
    return result;
  }

  // Validate the returned slug against the allowed taxonomy for this type.
  const allowed = new Set(topicsForObjectiveType(objectiveType).map(t => t.slug));
  if (!allowed.has(parsed.canonicalTopic)) {
    const result = { canonicalTopic: 'general-learning', confidence: Number(parsed.confidence) || 0.3, source: 'llm-coerced' };
    _cacheSet(cacheKey, result);
    return result;
  }

  const result = {
    canonicalTopic: parsed.canonicalTopic,
    confidence: Math.max(0, Math.min(1, Number(parsed.confidence) || 0)),
    source: 'llm',
  };
  _cacheSet(cacheKey, result);
  return result;
}

module.exports = {
  canonicalize,
  _internal: {
    clearCache: () => _cache.clear(),
    cacheSize: () => _cache.size,
  },
};
```

- [ ] **Step 2: Run tests to confirm they pass**

```bash
node --test src/services/topicCanonicalizationService.test.js
```

Expected: 5/5 pass.

- [ ] **Step 3: Commit**

```bash
git add src/services/topicCanonicalizationService.js
git commit -m "feat(competition): topicCanonicalizationService

LLM-backed canonicalizer that maps free-text objectives to a fixed taxonomy.
Caches identical (rawText, objectiveType) inputs for 90 days. Coerces
out-of-taxonomy LLM responses to general-learning. Falls back to
normalizeTopic when the LLM is unreachable. Empty input short-circuits.

All five spec tests pass.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: UserObjective schema — canonicalTopic fields

**Files:**
- Modify: `src/models/UserObjective.js`

- [ ] **Step 1: Read the current schema to find the right insertion point**

```bash
grep -n "Schema\|status:\|isPrimary" src/models/UserObjective.js | head -20
```

- [ ] **Step 2: Add the three new fields immediately before `timestamps: true`**

Open `src/models/UserObjective.js`. Find the existing fields block and add — adjacent to `topicsOfInterest` or wherever objective-level metadata lives:

```js
  // Canonical cohort key — resolved by topicCanonicalizationService from
  // (specifics, objectiveType). Used as the (DailyChallenge.topic) value
  // and the CohortDirectory.canonicalTopic key. Lowercase, indexed.
  canonicalTopic: { type: String, lowercase: true, index: true },
  canonicalTopic_needsReview: { type: Boolean, default: false },
  canonicalTopic_lastResolvedAt: { type: Date },
```

- [ ] **Step 3: Add the pre-save hook below the schema definition**

In the same file, after the schema is defined (just before `module.exports`):

```js
/**
 * Resolve canonicalTopic whenever objectiveType or specifics changes.
 * Failure is non-fatal — the canonicalizer's own fallback ensures we
 * always have a string to store.
 */
userObjectiveSchema.pre('save', async function preResolveCanonicalTopic(next) {
  try {
    if (!this.isModified('objectiveType') && !this.isModified('specifics') && this.canonicalTopic) {
      return next();
    }
    const topicCanonicalizationService = require('../services/topicCanonicalizationService');
    const derivedRaw =
      this.specifics?.targetRole ||
      this.specifics?.examName ||
      this.specifics?.targetSkill ||
      this.specifics?.toDomain ||
      (this.topicsOfInterest && this.topicsOfInterest[0]) ||
      this.objectiveType;
    const result = await topicCanonicalizationService.canonicalize(derivedRaw, this.objectiveType);
    this.canonicalTopic = result.canonicalTopic;
    this.canonicalTopic_needsReview = result.source === 'fallback';
    this.canonicalTopic_lastResolvedAt = new Date();
    return next();
  } catch (err) {
    // Non-fatal: log and proceed. The lazy backfill or housekeeping job
    // will pick this up on the next read.
    console.warn('[UserObjective.preSave] canonicalize failed:', err.message);
    this.canonicalTopic_needsReview = true;
    return next();
  }
});
```

(If the file's schema name isn't `userObjectiveSchema`, use the actual name found in Step 1.)

- [ ] **Step 4: Verify the file still loads**

```bash
node --check src/models/UserObjective.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add src/models/UserObjective.js
git commit -m "feat(competition): canonicalTopic on UserObjective + pre-save hook

Adds canonicalTopic (indexed), canonicalTopic_needsReview, and
canonicalTopic_lastResolvedAt to UserObjective. Pre-save hook runs the
canonicalization service whenever objectiveType or specifics changes;
failure is non-fatal and flags the document for review.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2 — CohortDirectory

### Task 5: CohortDirectory model

**Files:**
- Create: `src/models/CohortDirectory.js`

- [ ] **Step 1: Write the schema**

```js
const mongoose = require('mongoose');

const personaGhostSchema = new mongoose.Schema({
  name: { type: String, required: true },
  medianOffset: { type: Number, required: true },
  seed: { type: String, required: true },
}, { _id: false });

const historicalStatsSchema = new mongoose.Schema({
  last30dAverageScore: { type: Number, default: 0 },
  last30dP90Score: { type: Number, default: 0 },
  sampleSize: { type: Number, default: 0 },
  refreshedAt: { type: Date },
}, { _id: false });

const cohortDirectorySchema = new mongoose.Schema({
  canonicalTopic: { type: String, required: true, unique: true, index: true, lowercase: true },
  displayName: { type: String },
  objectiveTypes: [{ type: String }],
  memberCount: { type: Number, default: 0, min: 0 },
  weeklyAttempts: { type: Number, default: 0, min: 0 },
  lastChallengeDate: { type: Date },
  lastAttemptAt: { type: Date },
  isActive: { type: Boolean, default: true, index: true },
  personaGhosts: { type: [personaGhostSchema], default: [] },
  historicalStats: { type: historicalStatsSchema, default: () => ({}) },
}, { timestamps: true });

module.exports = mongoose.model('CohortDirectory', cohortDirectorySchema);
```

- [ ] **Step 2: Sanity-check it loads**

```bash
node -e "require('./src/models/CohortDirectory'); console.log('OK')"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add src/models/CohortDirectory.js
git commit -m "feat(competition): CohortDirectory model

Authoritative active-cohort registry. Indexed by canonicalTopic, tracks
memberCount, weeklyAttempts, lastChallengeDate, lastAttemptAt, isActive,
plus persona ghosts and a 30-day historical stats blob used by the ghost
leaderboard composer.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: cohortDirectoryService — tests first

**Files:**
- Create: `src/services/cohortDirectoryService.test.js`

- [ ] **Step 1: Write the failing tests**

```js
const test = require('node:test');
const assert = require('node:assert');

// Pre-stub openai so requiring the canonicalizer chain doesn't fail.
{
  const openaiPath = require.resolve('../config/openai');
  if (!require.cache[openaiPath]) {
    require.cache[openaiPath] = {
      exports: { chat: { completions: { create: async () => ({ choices: [] }) } } },
      loaded: true, id: openaiPath,
    };
  }
}

const svc = require('./cohortDirectoryService');

test('generatePersonaGhosts: produces 3 stable personas with distinct offsets', () => {
  const a = svc._internal.generatePersonaGhosts('gmat');
  const b = svc._internal.generatePersonaGhosts('gmat');
  assert.equal(a.length, 3);
  assert.deepEqual(a, b, 'same cohort key must produce identical personas');
  const offsets = new Set(a.map(p => p.medianOffset));
  assert.equal(offsets.size, 3, 'three personas should have three distinct offsets');
});

test('generatePersonaGhosts: different cohort keys produce different personas', () => {
  const a = svc._internal.generatePersonaGhosts('gmat');
  const b = svc._internal.generatePersonaGhosts('product-manager');
  assert.notDeepEqual(a.map(p => p.name), b.map(p => p.name));
});

test('personaScoreForWeek: stable for (persona, weekStart)', () => {
  const persona = { name: 'Aanya', medianOffset: 8, seed: 'gmat:0' };
  const week = new Date('2026-05-11');
  const s1 = svc._internal.personaScoreForWeek(persona, week, 70);
  const s2 = svc._internal.personaScoreForWeek(persona, week, 70);
  assert.equal(s1, s2);
});

test('personaScoreForWeek: drifts across weeks within plausible band', () => {
  const persona = { name: 'Aanya', medianOffset: 8, seed: 'gmat:0' };
  const w1 = new Date('2026-05-11');
  const w2 = new Date('2026-05-18');
  const s1 = svc._internal.personaScoreForWeek(persona, w1, 70);
  const s2 = svc._internal.personaScoreForWeek(persona, w2, 70);
  assert.notEqual(s1, s2);
  assert.ok(Math.abs(s1 - s2) <= 10, `drift too large: ${s1} vs ${s2}`);
});
```

- [ ] **Step 2: Run to confirm failure**

```bash
node --test src/services/cohortDirectoryService.test.js
```

Expected: failure — `Cannot find module './cohortDirectoryService'`.

- [ ] **Step 3: Commit failing tests**

```bash
git add src/services/cohortDirectoryService.test.js
git commit -m "test(competition): cohortDirectoryService spec

Tests for persona generation determinism (per-cohort + cross-cohort)
and weekly score determinism + bounded drift. Failing pending impl.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: cohortDirectoryService — implementation (persona + score helpers)

**Files:**
- Create: `src/services/cohortDirectoryService.js`

- [ ] **Step 1: Write the service**

```js
const crypto = require('crypto');
const CohortDirectory = require('../models/CohortDirectory');
const { findBySlug } = require('../config/canonicalTopics');

const PERSONA_NAME_POOL = [
  'Aanya', 'Vikram', 'Priya', 'Rohan', 'Sneha', 'Karan', 'Meera', 'Arjun',
  'Diya', 'Ishaan', 'Ananya', 'Reyansh', 'Saanvi', 'Aarav', 'Anika', 'Kabir',
];

function _hash(s) {
  return crypto.createHash('sha256').update(s).digest();
}

function _seededInt(seedBuf, byteOffset, mod) {
  // Read 4 bytes as an unsigned int and mod down. byteOffset wraps.
  const i = seedBuf.readUInt32BE(byteOffset % (seedBuf.length - 4));
  return i % mod;
}

/**
 * Three stable personas per cohort. Names picked from a fixed pool with the
 * cohort-seeded index; offsets deterministic per persona slot.
 */
function generatePersonaGhosts(canonicalTopic) {
  const seedBuf = _hash(`persona:${canonicalTopic}`);
  // Three personas with distinct offsets: +8, +2, -5 from cohort median.
  const OFFSETS = [8, 2, -5];
  const picked = [];
  const used = new Set();
  let cursor = 0;
  for (let slot = 0; slot < 3; slot++) {
    let idx;
    do {
      idx = _seededInt(seedBuf, cursor, PERSONA_NAME_POOL.length);
      cursor = (cursor + 4) % (seedBuf.length - 4);
    } while (used.has(idx));
    used.add(idx);
    picked.push({
      name: PERSONA_NAME_POOL[idx],
      medianOffset: OFFSETS[slot],
      seed: `${canonicalTopic}:${slot}`,
    });
  }
  return picked;
}

/**
 * Deterministic per-(persona, week) score. Same persona drifts ±5 within a
 * plausible band week over week so the user sees stable competitors slowly
 * shifting position.
 */
function personaScoreForWeek(persona, weekStart, cohortMedian) {
  const week = new Date(weekStart).toISOString().slice(0, 10);
  const buf = _hash(`${persona.seed}:${week}`);
  // Jitter in range [-5, +5].
  const jitter = (buf.readUInt8(0) % 11) - 5;
  return Math.max(0, Math.round(cohortMedian + persona.medianOffset + jitter));
}

/**
 * Upsert a cohort directory entry on objective save. Idempotent.
 * memberCount is incremented only when a new (userId, canonicalTopic) link
 * is being established; the caller is responsible for that contract.
 */
async function recordMemberJoin(canonicalTopic, objectiveType) {
  const meta = findBySlug(canonicalTopic);
  const update = {
    $setOnInsert: {
      canonicalTopic,
      displayName: meta?.display || canonicalTopic,
      personaGhosts: generatePersonaGhosts(canonicalTopic),
    },
    $addToSet: { objectiveTypes: objectiveType },
    $inc: { memberCount: 1 },
    $set: { isActive: true },
  };
  return CohortDirectory.findOneAndUpdate(
    { canonicalTopic },
    update,
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
}

async function recordMemberLeave(canonicalTopic) {
  const doc = await CohortDirectory.findOne({ canonicalTopic });
  if (!doc) return null;
  doc.memberCount = Math.max(0, (doc.memberCount || 0) - 1);
  return doc.save();
}

async function recordAttempt(canonicalTopic) {
  return CohortDirectory.findOneAndUpdate(
    { canonicalTopic },
    { $inc: { weeklyAttempts: 1 }, $set: { lastAttemptAt: new Date() } },
    { new: true }
  );
}

async function markChallengeGenerated(canonicalTopic, date) {
  return CohortDirectory.findOneAndUpdate(
    { canonicalTopic },
    { $set: { lastChallengeDate: date } },
    { new: true }
  );
}

module.exports = {
  recordMemberJoin,
  recordMemberLeave,
  recordAttempt,
  markChallengeGenerated,
  _internal: { generatePersonaGhosts, personaScoreForWeek },
};
```

- [ ] **Step 2: Run tests to confirm they pass**

```bash
node --test src/services/cohortDirectoryService.test.js
```

Expected: 4/4 pass.

- [ ] **Step 3: Commit**

```bash
git add src/services/cohortDirectoryService.js
git commit -m "feat(competition): cohortDirectoryService

Provides recordMemberJoin/Leave, recordAttempt, markChallengeGenerated.
Internal helpers generate three stable persona ghosts per cohort (with
distinct medianOffsets) and deterministic per-week scores bounded by a
±5 jitter so personas drift but never wildly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Wire UserObjective pre-save → cohortDirectoryService

**Files:**
- Modify: `src/models/UserObjective.js`

- [ ] **Step 1: Extend the pre-save hook to call the directory**

Open `src/models/UserObjective.js`. Locate the pre-save hook added in Task 4 and append the directory bookkeeping:

```js
userObjectiveSchema.pre('save', async function preResolveCanonicalTopic(next) {
  try {
    if (!this.isModified('objectiveType') && !this.isModified('specifics') && this.canonicalTopic) {
      return next();
    }
    const topicCanonicalizationService = require('../services/topicCanonicalizationService');
    const cohortDirectoryService = require('../services/cohortDirectoryService');

    const derivedRaw =
      this.specifics?.targetRole ||
      this.specifics?.examName ||
      this.specifics?.targetSkill ||
      this.specifics?.toDomain ||
      (this.topicsOfInterest && this.topicsOfInterest[0]) ||
      this.objectiveType;

    const oldCanonical = this.canonicalTopic;
    const result = await topicCanonicalizationService.canonicalize(derivedRaw, this.objectiveType);
    this.canonicalTopic = result.canonicalTopic;
    this.canonicalTopic_needsReview = result.source === 'fallback';
    this.canonicalTopic_lastResolvedAt = new Date();

    // Directory bookkeeping — only when the canonical topic actually changes
    // and only for primary+active objectives (they're the cohort-eligible ones).
    if (this.status === 'active' && this.isPrimary && this.canonicalTopic !== oldCanonical) {
      if (oldCanonical) {
        await cohortDirectoryService.recordMemberLeave(oldCanonical).catch(() => null);
      }
      await cohortDirectoryService.recordMemberJoin(this.canonicalTopic, this.objectiveType).catch(() => null);
    }
    return next();
  } catch (err) {
    console.warn('[UserObjective.preSave] canonicalize failed:', err.message);
    this.canonicalTopic_needsReview = true;
    return next();
  }
});
```

- [ ] **Step 2: Verify syntax**

```bash
node --check src/models/UserObjective.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add src/models/UserObjective.js
git commit -m "feat(competition): wire pre-save canonicalTopic to CohortDirectory

When a primary+active objective's canonicalTopic changes, decrement the old
cohort's memberCount and increment the new one's. Errors are swallowed so
directory bookkeeping never blocks user saves; the housekeeping cron
corrects drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3 — Migration scripts

### Task 9: Backfill canonical topics script

**Files:**
- Create: `scripts/backfill-canonical-topics.js`

- [ ] **Step 1: Write the script**

```js
#!/usr/bin/env node
/**
 * One-shot backfill: walk every UserObjective without canonicalTopic
 * (or with canonicalTopic_needsReview=true) and resolve via the
 * canonicalization service. Idempotent — re-running is a no-op for
 * already-canonicalized documents.
 *
 * Usage:
 *   NODE_ENV=production node scripts/backfill-canonical-topics.js [--dry-run]
 */

require('dotenv').config();
const mongoose = require('mongoose');
const UserObjective = require('../src/models/UserObjective');
const topicCanonicalizationService = require('../src/services/topicCanonicalizationService');

const DRY = process.argv.includes('--dry-run');

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log(`[Backfill] connected. dry=${DRY}`);

  const filter = {
    $or: [
      { canonicalTopic: { $exists: false } },
      { canonicalTopic: null },
      { canonicalTopic: '' },
      { canonicalTopic_needsReview: true },
    ],
  };
  const total = await UserObjective.countDocuments(filter);
  console.log(`[Backfill] ${total} objectives to process`);

  let processed = 0;
  let resolved = 0;
  let flagged = 0;

  const cursor = UserObjective.find(filter).cursor();
  for (let doc = await cursor.next(); doc; doc = await cursor.next()) {
    processed++;
    const derivedRaw =
      doc.specifics?.targetRole ||
      doc.specifics?.examName ||
      doc.specifics?.targetSkill ||
      doc.specifics?.toDomain ||
      (doc.topicsOfInterest && doc.topicsOfInterest[0]) ||
      doc.objectiveType;

    try {
      const r = await topicCanonicalizationService.canonicalize(derivedRaw, doc.objectiveType);
      if (DRY) {
        console.log(`  [${processed}/${total}] DRY ${doc._id} raw="${derivedRaw}" → ${r.canonicalTopic} (${r.source})`);
      } else {
        doc.canonicalTopic = r.canonicalTopic;
        doc.canonicalTopic_needsReview = r.source === 'fallback';
        doc.canonicalTopic_lastResolvedAt = new Date();
        await doc.save();
      }
      if (r.source === 'fallback') flagged++;
      resolved++;
    } catch (err) {
      console.warn(`  [${processed}/${total}] ${doc._id} failed: ${err.message}`);
    }

    if (processed % 50 === 0) {
      console.log(`[Backfill] progress: ${processed}/${total}`);
    }
  }

  console.log(`[Backfill] done. processed=${processed} resolved=${resolved} flagged=${flagged}`);
  await mongoose.disconnect();
}

main().catch(err => {
  console.error('[Backfill] fatal:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Sanity-check it parses**

```bash
node --check scripts/backfill-canonical-topics.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add scripts/backfill-canonical-topics.js
git commit -m "feat(competition): backfill canonical topics script

Walks UserObjective documents missing canonicalTopic (or flagged for
review) and resolves them via the canonicalization service. --dry-run
prints intended writes without persisting. Idempotent: re-running on
already-canonicalized docs is a no-op.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Bootstrap CohortDirectory script

**Files:**
- Create: `scripts/bootstrap-cohort-directory.js`

- [ ] **Step 1: Write the script**

```js
#!/usr/bin/env node
/**
 * One-shot bootstrap: aggregate UserObjective by canonicalTopic, seed
 * CohortDirectory with one entry per. memberCount from group size,
 * weeklyAttempts from a 7-day ChallengeAttempt aggregate, historicalStats
 * from a 30-day aggregate, personaGhosts generated and persisted.
 *
 * Usage:
 *   NODE_ENV=production node scripts/bootstrap-cohort-directory.js [--dry-run]
 */

require('dotenv').config();
const mongoose = require('mongoose');
const UserObjective = require('../src/models/UserObjective');
const ChallengeAttempt = require('../src/models/ChallengeAttempt');
const DailyChallenge = require('../src/models/DailyChallenge');
const CohortDirectory = require('../src/models/CohortDirectory');
const cohortDirectoryService = require('../src/services/cohortDirectoryService');
const { findBySlug } = require('../src/config/canonicalTopics');

const DRY = process.argv.includes('--dry-run');

function _weeksAgo(n) { return new Date(Date.now() - n * 7 * 24 * 60 * 60 * 1000); }

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log(`[Bootstrap] connected. dry=${DRY}`);

  // Group active+primary objectives by canonicalTopic.
  const groups = await UserObjective.aggregate([
    { $match: { status: 'active', isPrimary: true, canonicalTopic: { $exists: true, $ne: null, $ne: '' } } },
    { $group: {
        _id: '$canonicalTopic',
        memberCount: { $sum: 1 },
        objectiveTypes: { $addToSet: '$objectiveType' },
    } },
  ]);
  console.log(`[Bootstrap] ${groups.length} cohorts to seed`);

  // 7-day attempt counts.
  const weekAgo = _weeksAgo(1);
  const attemptAgg = await ChallengeAttempt.aggregate([
    { $match: { completedAt: { $gte: weekAgo } } },
    { $lookup: { from: 'dailychallenges', localField: 'challengeId', foreignField: '_id', as: 'challenge' } },
    { $unwind: '$challenge' },
    { $group: { _id: '$challenge.topic', count: { $sum: 1 } } },
  ]);
  const weeklyAttemptsByTopic = new Map(attemptAgg.map(a => [a._id, a.count]));

  // 30-day historical stats (average + p90 of handicappedScore).
  const monthAgo = _weeksAgo(4);
  const statsAgg = await ChallengeAttempt.aggregate([
    { $match: { completedAt: { $gte: monthAgo }, handicappedScore: { $exists: true } } },
    { $lookup: { from: 'dailychallenges', localField: 'challengeId', foreignField: '_id', as: 'challenge' } },
    { $unwind: '$challenge' },
    { $group: { _id: '$challenge.topic', scores: { $push: '$handicappedScore' } } },
  ]);
  const statsByTopic = new Map();
  for (const s of statsAgg) {
    const sorted = [...s.scores].sort((a, b) => a - b);
    const avg = sorted.reduce((a, b) => a + b, 0) / sorted.length;
    const p90 = sorted[Math.floor(sorted.length * 0.9)] || sorted[sorted.length - 1] || 0;
    statsByTopic.set(s._id, { avg, p90, sampleSize: sorted.length });
  }

  let created = 0, updated = 0;
  for (const g of groups) {
    const canonicalTopic = g._id;
    const meta = findBySlug(canonicalTopic);
    const personas = cohortDirectoryService._internal.generatePersonaGhosts(canonicalTopic);
    const stats = statsByTopic.get(canonicalTopic) || { avg: 0, p90: 0, sampleSize: 0 };
    const payload = {
      canonicalTopic,
      displayName: meta?.display || canonicalTopic,
      objectiveTypes: g.objectiveTypes,
      memberCount: g.memberCount,
      weeklyAttempts: weeklyAttemptsByTopic.get(canonicalTopic) || 0,
      isActive: true,
      personaGhosts: personas,
      historicalStats: {
        last30dAverageScore: Math.round(stats.avg),
        last30dP90Score: Math.round(stats.p90),
        sampleSize: stats.sampleSize,
        refreshedAt: new Date(),
      },
    };
    if (DRY) {
      console.log(`  DRY ${canonicalTopic} members=${payload.memberCount} attempts=${payload.weeklyAttempts}`);
      continue;
    }
    const existed = await CohortDirectory.exists({ canonicalTopic });
    await CohortDirectory.updateOne({ canonicalTopic }, { $set: payload }, { upsert: true });
    if (existed) updated++; else created++;
  }

  console.log(`[Bootstrap] done. created=${created} updated=${updated}`);
  await mongoose.disconnect();
}

main().catch(err => {
  console.error('[Bootstrap] fatal:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Sanity-check it parses**

```bash
node --check scripts/bootstrap-cohort-directory.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add scripts/bootstrap-cohort-directory.js
git commit -m "feat(competition): bootstrap CohortDirectory script

Aggregates active+primary UserObjective by canonicalTopic, seeds one
CohortDirectory entry per with memberCount (group size), weeklyAttempts
(7-day count), historicalStats (30-day average + p90), and three persona
ghosts. --dry-run prints intended writes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4 — Challenge generation refactor

### Task 11: Switch challenge generation to CohortDirectory

**Files:**
- Modify: `src/services/challengeGenerationService.js`

- [ ] **Step 1: Replace `_getActiveObjectives` source**

Open `src/services/challengeGenerationService.js`. Find the `_getActiveObjectives` method (around line 145). Replace its body:

```js
  async _getActiveObjectives() {
    const CohortDirectory = require('../models/CohortDirectory');
    const docs = await CohortDirectory.find(
      { isActive: true, memberCount: { $gt: 0 } },
      { canonicalTopic: 1, displayName: 1 }
    ).lean();
    return docs.map(d => d.canonicalTopic);
  }
```

- [ ] **Step 2: Use CohortDirectory.displayName in the title path**

Find `_generateDisplayTitle` and its caller (`titleMap[objective] = await this._generateDisplayTitle(objective);`). Replace the title resolution block with a directory-first lookup:

```js
    // Use cached displayName from CohortDirectory when present; otherwise
    // call the LLM titler and write the result back so we never re-pay.
    const CohortDirectory = require('../models/CohortDirectory');
    const titleMap = {};
    await Promise.all(objectives.map(async (objective) => {
      try {
        const dir = await CohortDirectory.findOne({ canonicalTopic: objective }).select('displayName').lean();
        if (dir?.displayName && dir.displayName !== objective) {
          titleMap[objective] = dir.displayName;
        } else {
          titleMap[objective] = await this._generateDisplayTitle(objective);
          await CohortDirectory.updateOne(
            { canonicalTopic: objective },
            { $set: { displayName: titleMap[objective] } }
          );
        }
      } catch (err) {
        console.warn(`[ChallengeGen] title failed for ${objective}: ${err.message}`);
        titleMap[objective] = objective;
      }
    }));
```

(Locate the existing `titleMap` block and replace it. Preserve surrounding code that uses `titleMap[objective]`.)

- [ ] **Step 3: Mark challenge generated on directory**

After a `DailyChallenge.create({ ... })` succeeds inside the cohort loop, add:

```js
      await CohortDirectory.updateOne(
        { canonicalTopic: objective },
        { $set: { lastChallengeDate: today } }
      ).catch(() => null);
```

- [ ] **Step 4: Verify syntax**

```bash
node --check src/services/challengeGenerationService.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add src/services/challengeGenerationService.js
git commit -m "feat(competition): generate challenges from CohortDirectory

Cron now walks CohortDirectory.find({isActive: true, memberCount > 0})
instead of scanning UserObjective directly. Display titles come from the
directory's cached displayName when present; LLM-generated titles are
written back so we don't re-pay. lastChallengeDate is updated on the
directory after each create.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: `/competition/relevant` exact-match + cohort hints

**Files:**
- Modify: `src/controllers/competitionController.js`

- [ ] **Step 1: Replace the topic match in `getRelevantForUser`**

Open `src/controllers/competitionController.js`. Find `getRelevantForUser`. Replace the objectiveTopic derivation block (currently a switch on `objectiveType`) with a direct read of `canonicalTopic`:

```js
    const objective = await UserObjective.findOne(
      { userId: req.user.userId, status: 'active', isPrimary: true },
      { canonicalTopic: 1, objectiveType: 1 }
    ).lean();

    const canonicalTopic = objective?.canonicalTopic || null;
```

Then replace the substring matcher with exact equality:

```js
    const matchByTopic = canonicalTopic
      ? (allToday || []).find(c => c.topic === canonicalTopic)
      : null;
    const challenge = matchByTopic || (allToday && allToday[0]) || null;
```

- [ ] **Step 2: Add cohort hints to the response**

Below the existing `alreadyPlayed` block, add:

```js
    // Cohort hints surfaced under the iOS challenge card.
    const CohortDirectory = require('../models/CohortDirectory');
    const ChallengeAttempt = require('../models/ChallengeAttempt');
    let cohortMemberCount = 0;
    let cohortPlayedToday = 0;
    if (canonicalTopic) {
      const dir = await CohortDirectory.findOne({ canonicalTopic }).select('memberCount').lean();
      cohortMemberCount = dir?.memberCount || 0;
      if (challenge) {
        cohortPlayedToday = await ChallengeAttempt.countDocuments({
          challengeId: challenge._id, status: 'completed',
        });
      }
    }
```

Update the `return res.json(...)` to include both fields:

```js
    return res.json(apiResponse.success({
      status,
      objectiveTopic: canonicalTopic,
      topicMatch: !!matchByTopic,
      cohortMemberCount,
      cohortPlayedToday,
      todayChallenge: challenge ? { /* unchanged */ } : null,
      nextLiveEvent: /* unchanged */,
    }));
```

(Keep the existing `todayChallenge` and `nextLiveEvent` shaping code unchanged.)

- [ ] **Step 3: Verify syntax**

```bash
node --check src/controllers/competitionController.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add src/controllers/competitionController.js
git commit -m "feat(competition): exact canonicalTopic match + cohort hints

/competition/relevant now uses the user's canonicalTopic for exact match
against today's challenges (no more substring includes) and returns
cohortMemberCount + cohortPlayedToday so iOS can show 'N in your cohort,
M played today'.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5 — Per-user shuffle

### Task 13: challengeShuffleService — tests first

**Files:**
- Create: `src/services/challengeShuffleService.test.js`

- [ ] **Step 1: Write the failing tests**

```js
const test = require('node:test');
const assert = require('node:assert');
const svc = require('./challengeShuffleService');

test('buildShuffle: same seed → same permutation', () => {
  const a = svc.buildShuffle('user1', 'chal1', 15);
  const b = svc.buildShuffle('user1', 'chal1', 15);
  assert.deepEqual(a, b);
});

test('buildShuffle: different users → different permutations', () => {
  const a = svc.buildShuffle('user1', 'chal1', 15);
  const b = svc.buildShuffle('user2', 'chal1', 15);
  assert.notDeepEqual(a.questionOrder, b.questionOrder);
});

test('buildShuffle: questionOrder is a valid permutation', () => {
  const s = svc.buildShuffle('user1', 'chal1', 15);
  assert.equal(s.questionOrder.length, 15);
  const set = new Set(s.questionOrder);
  assert.equal(set.size, 15);
  for (const i of s.questionOrder) assert.ok(i >= 0 && i < 15);
});

test('buildShuffle: optionLabelMap rotates A/B/C/D', () => {
  const s = svc.buildShuffle('user1', 'chal1', 15);
  for (let q = 0; q < 15; q++) {
    const map = s.optionLabelMap[q];
    const values = new Set(Object.values(map));
    assert.deepEqual([...values].sort(), ['A', 'B', 'C', 'D']);
    assert.deepEqual(Object.keys(map).sort(), ['A', 'B', 'C', 'D']);
  }
});

test('translateAnswer: inverse mapping round-trips', () => {
  const s = svc.buildShuffle('user1', 'chal1', 15);
  // User sees question position 3, selects label "C" — what was the canonical?
  const orig = svc.translateAnswer(s, 3, 'C');
  // Round-trip: forward-translate the canonical back via optionLabelMap.
  const forward = s.optionLabelMap[orig.originalQuestionIdx][orig.originalLabel];
  assert.equal(forward, 'C');
});
```

- [ ] **Step 2: Run to confirm failure**

```bash
node --test src/services/challengeShuffleService.test.js
```

Expected: `Cannot find module './challengeShuffleService'`.

- [ ] **Step 3: Commit failing tests**

```bash
git add src/services/challengeShuffleService.test.js
git commit -m "test(competition): challengeShuffleService spec

Tests determinism by (userId, challengeId), per-user divergence, valid
permutation shape, complete A/B/C/D rotation per question, and inverse
mapping round-trip. Failing pending impl.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: challengeShuffleService — implementation

**Files:**
- Create: `src/services/challengeShuffleService.js`

- [ ] **Step 1: Write the service**

```js
const crypto = require('crypto');

const LABELS = ['A', 'B', 'C', 'D'];

function _hash(s) { return crypto.createHash('sha256').update(s).digest(); }

/**
 * Seeded Fisher-Yates. Mutates and returns `arr`.
 * Uses sequential bytes from `seedBuf` as the source of randomness so the
 * permutation is reproducible given the same buffer.
 */
function _fisherYates(arr, seedBuf) {
  let cursor = 0;
  for (let i = arr.length - 1; i > 0; i--) {
    if (cursor >= seedBuf.length) cursor = 0;
    const r = seedBuf.readUInt8(cursor) % (i + 1);
    cursor++;
    const tmp = arr[i]; arr[i] = arr[r]; arr[r] = tmp;
  }
  return arr;
}

/**
 * Build the deterministic shuffle for (userId, challengeId).
 *
 * @returns {{
 *   questionOrder: number[],                       // shuffledIdx → originalIdx
 *   optionLabelMap: Object[]                       // [originalQIdx]{canonical→userFacing}
 * }}
 */
function buildShuffle(userId, challengeId, questionCount) {
  const baseSeed = _hash(`${userId}:${challengeId}`);

  const order = _fisherYates(
    Array.from({ length: questionCount }, (_, i) => i),
    baseSeed
  );

  const optionLabelMap = [];
  for (let qOrig = 0; qOrig < questionCount; qOrig++) {
    const qSeed = _hash(Buffer.concat([baseSeed, Buffer.from(`:q${qOrig}`)]));
    const shuffledLabels = _fisherYates([...LABELS], qSeed);
    // Canonical label → user-facing label. Index 0 of LABELS is "A", etc.
    const map = {};
    for (let i = 0; i < LABELS.length; i++) {
      map[LABELS[i]] = shuffledLabels[i];
    }
    optionLabelMap.push(map);
  }

  return { questionOrder: order, optionLabelMap };
}

/**
 * Translate a user-space (shuffledQuestionIdx, userFacingLabel) tuple back
 * to canonical (originalQuestionIdx, originalLabel). Used by submitAnswer
 * to score against the canonical correctAnswer.
 */
function translateAnswer(shuffle, shuffledQuestionIdx, userFacingLabel) {
  const originalQuestionIdx = shuffle.questionOrder[shuffledQuestionIdx];
  const map = shuffle.optionLabelMap[originalQuestionIdx];
  // Invert: find the canonical label that maps to the user-facing one.
  let originalLabel = null;
  for (const canonical of LABELS) {
    if (map[canonical] === userFacingLabel) { originalLabel = canonical; break; }
  }
  return { originalQuestionIdx, originalLabel };
}

/**
 * Apply a shuffle to a challenge document for serving. Returns a new
 * questions array reordered + with options re-labeled per the shuffle.
 * The correctAnswer field is NOT included.
 */
function applyShuffleForServe(questions, shuffle) {
  return shuffle.questionOrder.map((origIdx) => {
    const q = questions[origIdx];
    const map = shuffle.optionLabelMap[origIdx];
    const newOptions = q.options.map(opt => ({
      ...opt.toObject ? opt.toObject() : opt,
      label: map[opt.label],
    }));
    // Sort by new label so options render A/B/C/D in order.
    newOptions.sort((a, b) => LABELS.indexOf(a.label) - LABELS.indexOf(b.label));
    const out = { ...(q.toObject ? q.toObject() : q), options: newOptions };
    delete out.correctAnswer;
    delete out.explanation;  // hide until results page
    return out;
  });
}

module.exports = { buildShuffle, translateAnswer, applyShuffleForServe };
```

- [ ] **Step 2: Run tests to confirm they pass**

```bash
node --test src/services/challengeShuffleService.test.js
```

Expected: 5/5 pass.

- [ ] **Step 3: Commit**

```bash
git add src/services/challengeShuffleService.js
git commit -m "feat(competition): challengeShuffleService

Deterministic per-user shuffle: questionOrder (Fisher-Yates seeded by
sha256(userId:challengeId)) and per-question optionLabelMap (Fisher-Yates
seeded by sha256(base:qN)). translateAnswer inverts the shuffle for
scoring. applyShuffleForServe shapes the user-facing questions array
without correctAnswer or explanation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Persist shuffle on attempt start, translate on answer

**Files:**
- Modify: `src/models/ChallengeAttempt.js`
- Modify: `src/services/competitionService.js`

- [ ] **Step 1: Add shuffle fields to ChallengeAttempt schema**

Open `src/models/ChallengeAttempt.js`. Locate the schema definition and add:

```js
  questionOrder: { type: [Number], default: [] },
  optionLabelMap: { type: [mongoose.Schema.Types.Mixed], default: [] },
```

(Placed before `timestamps: true`.)

- [ ] **Step 2: Wire shuffle into `startChallenge`**

Open `src/services/competitionService.js`. Find `startChallenge`. After the attempt is created/loaded and before returning the challenge to the user, add:

```js
    const shuffleService = require('./challengeShuffleService');
    let shuffle;
    if (attempt.questionOrder && attempt.questionOrder.length === challenge.questions.length) {
      // Resume: re-derive from persisted maps (or rebuild from seed — both work).
      shuffle = {
        questionOrder: attempt.questionOrder,
        optionLabelMap: attempt.optionLabelMap,
      };
    } else {
      shuffle = shuffleService.buildShuffle(
        userId.toString(),
        challenge._id.toString(),
        challenge.questions.length
      );
      attempt.questionOrder = shuffle.questionOrder;
      attempt.optionLabelMap = shuffle.optionLabelMap;
      await attempt.save();
    }
    const serveQuestions = shuffleService.applyShuffleForServe(challenge.questions, shuffle);
```

Return `serveQuestions` instead of `challenge.questions` to the client. (Locate the existing return shape and substitute.)

- [ ] **Step 3: Translate the answer in `submitAnswer`**

In the same file, find `submitAnswer`. Before scoring (where the code compares `selectedAnswer` to `question.correctAnswer`), translate via shuffle:

```js
    const shuffleService = require('./challengeShuffleService');
    const shuffle = {
      questionOrder: attempt.questionOrder || [],
      optionLabelMap: attempt.optionLabelMap || [],
    };
    let canonicalQuestionIdx = questionIndex;
    let canonicalLabel = selectedAnswer;
    if (shuffle.questionOrder.length === challenge.questions.length) {
      const t = shuffleService.translateAnswer(shuffle, questionIndex, selectedAnswer);
      canonicalQuestionIdx = t.originalQuestionIdx;
      canonicalLabel = t.originalLabel;
    }
    const question = challenge.questions[canonicalQuestionIdx];
    const correct = canonicalLabel === question.correctAnswer;
```

(Adapt to the actual variable names and surrounding code present.)

- [ ] **Step 4: Verify syntax**

```bash
node --check src/models/ChallengeAttempt.js && node --check src/services/competitionService.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add src/models/ChallengeAttempt.js src/services/competitionService.js
git commit -m "feat(competition): persist per-user shuffle, translate on answer

ChallengeAttempt gains questionOrder + optionLabelMap. startChallenge
builds the shuffle on first attempt, persists it, and returns reordered
relabeled questions (without correctAnswer/explanation) to the client.
submitAnswer translates user-space (questionIndex, selectedAnswer) back
to canonical before scoring. Resume reuses the persisted shuffle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 6 — Ghost leaderboard

### Task 16: ghostLeaderboardService — tests first

**Files:**
- Create: `src/services/ghostLeaderboardService.test.js`

- [ ] **Step 1: Write the failing tests**

```js
const test = require('node:test');
const assert = require('node:assert');
const svc = require('./ghostLeaderboardService');

const cohort = {
  canonicalTopic: 'gmat',
  personaGhosts: [
    { name: 'Aanya', medianOffset: 8, seed: 'gmat:0' },
    { name: 'Vikram', medianOffset: 2, seed: 'gmat:1' },
    { name: 'Priya', medianOffset: -5, seed: 'gmat:2' },
  ],
  historicalStats: { last30dAverageScore: 65, last30dP90Score: 88, sampleSize: 200 },
};

test('compose: returns real entries unchanged when cohort >= 10', () => {
  const real = Array.from({ length: 12 }, (_, i) => ({ userId: `u${i}`, handicappedScore: 100 - i, ghostKind: null }));
  const out = svc.compose({ cohort, realEntries: real, weekStart: new Date('2026-05-11') });
  assert.equal(out.length, 12);
  assert.ok(out.every(e => !e.ghostKind));
});

test('compose: adds historical anchors and personas when cohort < 10', () => {
  const real = Array.from({ length: 3 }, (_, i) => ({ userId: `u${i}`, handicappedScore: 70 - i * 5, ghostKind: null }));
  const out = svc.compose({ cohort, realEntries: real, weekStart: new Date('2026-05-11') });
  const kinds = out.map(e => e.ghostKind);
  assert.equal(kinds.filter(k => k === 'historical').length, 2);
  assert.equal(kinds.filter(k => k === 'persona').length, 3);
  assert.equal(kinds.filter(k => k == null).length, 3);
});

test('compose: ghosts never occupy #1 when real entries exist', () => {
  const real = [{ userId: 'u1', handicappedScore: 30, ghostKind: null }];
  const out = svc.compose({ cohort, realEntries: real, weekStart: new Date('2026-05-11') });
  assert.ok(out[0].ghostKind == null || out[0].userId === 'u1',
    `top spot should be a real user when reals exist; got ${JSON.stringify(out[0])}`);
});

test('compose: sorts by handicappedScore descending', () => {
  const real = [{ userId: 'u1', handicappedScore: 50, ghostKind: null }];
  const out = svc.compose({ cohort, realEntries: real, weekStart: new Date('2026-05-11') });
  for (let i = 1; i < out.length; i++) {
    assert.ok(out[i - 1].handicappedScore >= out[i].handicappedScore,
      `unsorted at ${i}: ${out[i-1].handicappedScore} < ${out[i].handicappedScore}`);
  }
});
```

- [ ] **Step 2: Run to confirm failure**

```bash
node --test src/services/ghostLeaderboardService.test.js
```

Expected: `Cannot find module './ghostLeaderboardService'`.

- [ ] **Step 3: Commit failing tests**

```bash
git add src/services/ghostLeaderboardService.test.js
git commit -m "test(competition): ghostLeaderboardService spec

Tests for cohort>=10 short-circuit, ghost composition (2 historical + 3
persona) when cohort<10, ghost-not-at-#1 rule, and final sort order.
Failing pending impl.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 17: ghostLeaderboardService — implementation

**Files:**
- Create: `src/services/ghostLeaderboardService.js`

- [ ] **Step 1: Write the service**

```js
const cohortDirectoryService = require('./cohortDirectoryService');

const GHOST_THRESHOLD = 10;

/**
 * Compose a final leaderboard list by merging real entries with ghosts
 * when the cohort is small. Never persists.
 *
 * @param {{ cohort: object, realEntries: Array<{userId, handicappedScore}>, weekStart: Date }} args
 * @returns {Array<{userId, handicappedScore, ghostKind, displayName?}>}
 */
function compose({ cohort, realEntries, weekStart }) {
  const reals = (realEntries || []).map(e => ({ ...e, ghostKind: e.ghostKind || null }));
  if (reals.length >= GHOST_THRESHOLD) {
    return reals.sort((a, b) => b.handicappedScore - a.handicappedScore);
  }

  const ghosts = [];

  // Historical anchors — drop silently if we have no stats yet.
  const stats = cohort.historicalStats || {};
  if (stats.sampleSize && stats.last30dP90Score != null) {
    ghosts.push({
      userId: `ghost-historical-p90-${cohort.canonicalTopic}`,
      displayName: 'Cohort top 10% (last month)',
      handicappedScore: stats.last30dP90Score,
      ghostKind: 'historical',
    });
  }
  if (stats.sampleSize && stats.last30dAverageScore != null) {
    ghosts.push({
      userId: `ghost-historical-avg-${cohort.canonicalTopic}`,
      displayName: 'Cohort average (last month)',
      handicappedScore: stats.last30dAverageScore,
      ghostKind: 'historical',
    });
  }

  // Persona ghosts — score derived from the cohort's running median (use
  // historical average as a stand-in when no per-week real signal exists).
  const median = stats.last30dAverageScore || 50;
  for (const persona of cohort.personaGhosts || []) {
    ghosts.push({
      userId: `ghost-persona-${cohort.canonicalTopic}-${persona.seed}`,
      displayName: persona.name,
      handicappedScore: cohortDirectoryService._internal.personaScoreForWeek(persona, weekStart, median),
      ghostKind: 'persona',
    });
  }

  // Merge + sort desc.
  let combined = [...reals, ...ghosts].sort((a, b) => b.handicappedScore - a.handicappedScore);

  // #1 honesty rule: if a ghost outranks the top real and reals exist,
  // swap the ghost down one slot.
  if (reals.length > 0 && combined[0].ghostKind != null) {
    const topRealIdx = combined.findIndex(e => e.ghostKind == null);
    if (topRealIdx > 0) {
      const [topReal] = combined.splice(topRealIdx, 1);
      combined.unshift(topReal);
    }
  }

  return combined;
}

module.exports = { compose };
```

- [ ] **Step 2: Run tests to confirm they pass**

```bash
node --test src/services/ghostLeaderboardService.test.js
```

Expected: 4/4 pass.

- [ ] **Step 3: Commit**

```bash
git add src/services/ghostLeaderboardService.js
git commit -m "feat(competition): ghostLeaderboardService

Composes leaderboards from real entries + (when cohort<10) historical
anchor rows + persona ghosts. Personas score via deterministic
per-(seed, weekStart) jitter. #1 slot is reserved for a real user
whenever any reals exist.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 18: Wire ghosts into the weekly leaderboard endpoint

**Files:**
- Modify: `src/services/competitionService.js`

- [ ] **Step 1: Compose ghosts in `getWeeklyLeaderboard`**

Open `src/services/competitionService.js`. Find `getWeeklyLeaderboard(topic, weekStart)`. After the real leaderboard rows are loaded but before they're returned, add:

```js
    const ghostLeaderboardService = require('./ghostLeaderboardService');
    const CohortDirectory = require('../models/CohortDirectory');
    const cohort = await CohortDirectory.findOne({ canonicalTopic: topic }).lean();
    if (cohort) {
      const composed = ghostLeaderboardService.compose({
        cohort,
        realEntries: realRows.map(r => ({
          userId: String(r.userId),
          handicappedScore: r.totalHandicappedScore ?? r.handicappedScore ?? 0,
          displayName: r.displayName,
          ghostKind: null,
        })),
        weekStart,
      });
      return composed;
    }
```

(Adapt `realRows` to whatever variable holds the loaded entries in the existing implementation.)

- [ ] **Step 2: Verify syntax**

```bash
node --check src/services/competitionService.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add src/services/competitionService.js
git commit -m "feat(competition): ghost-composed weekly leaderboard

getWeeklyLeaderboard now loads the CohortDirectory entry and runs the
result through ghostLeaderboardService.compose so small cohorts get a
populated leaderboard. Real-only cohorts (>=10) pass through unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 7 — Readiness pipeline

### Task 19: knowledgeService.updateMastery — accept source + weight

**Files:**
- Modify: `src/services/knowledgeService.js`

- [ ] **Step 1: Inspect current signature**

```bash
grep -n "updateMastery\|function update\|module.exports" src/services/knowledgeService.js | head
```

- [ ] **Step 2: Add a `source`/`weight` parameter, default to current behavior**

Edit `updateMastery` (or the equivalent function that takes a `topicBreakdown` and bumps mastery). Add a third options parameter:

```js
/**
 * Update topic mastery from a quiz-like attempt.
 *
 * @param {string} userId
 * @param {Array<{topic, correct, total, percentage}>} topicBreakdown
 * @param {{source?: 'quiz'|'competition'|'interview', weight?: number}} [opts]
 *   - source: documents where the update came from. Logged only.
 *   - weight: multiplier on the mastery delta. Defaults to:
 *       quiz=1.0, competition=0.5, interview=1.0, unknown=1.0
 */
async function updateMastery(userId, topicBreakdown, opts = {}) {
  const source = opts.source || 'quiz';
  const defaultWeight = source === 'competition' ? 0.5 : 1.0;
  const weight = typeof opts.weight === 'number' ? opts.weight : defaultWeight;
  // ... existing logic, but where it computes a delta on a topic's score,
  // multiply by `weight` before applying.
}
```

Locate the existing delta-application line(s) in the function body and multiply by `weight`. (If multiple sites compute deltas, multiply at each one.)

- [ ] **Step 3: Verify syntax**

```bash
node --check src/services/knowledgeService.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add src/services/knowledgeService.js
git commit -m "feat(competition): updateMastery accepts source + weight

knowledgeService.updateMastery now takes an options object with `source`
('quiz'|'competition'|'interview') and `weight` (default: quiz=1.0,
competition=0.5, interview=1.0). Competition attempts are weighted lower
because they're timed and shorter than a solo quiz, so the per-question
diagnostic signal is weaker. Default-args preserve all existing callers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 20: Bridge `completeChallenge` → updateMastery

**Files:**
- Modify: `src/services/competitionService.js`

- [ ] **Step 1: After scoring in `completeChallenge`, feed mastery**

Find `completeChallenge` in `src/services/competitionService.js`. After `handicappedScore` is computed and the attempt + leaderboard updates land, before returning, add:

```js
    // Bridge competition result → KnowledgeProfile mastery so completing
    // a challenge visibly moves the Home readiness number.
    try {
      const knowledgeService = require('./knowledgeService');
      const byConcept = new Map();
      for (let i = 0; i < challenge.questions.length; i++) {
        const q = challenge.questions[i];
        const conceptKey = (q.concept || challenge.topic || '').toString();
        if (!conceptKey) continue;
        const ans = attempt.answers?.[i];
        const isCorrect = ans?.isCorrect === true;
        const entry = byConcept.get(conceptKey) || { topic: conceptKey, correct: 0, total: 0 };
        entry.total += 1;
        if (isCorrect) entry.correct += 1;
        byConcept.set(conceptKey, entry);
      }
      const topicBreakdown = [...byConcept.values()].map(e => ({
        ...e,
        percentage: e.total ? Math.round((e.correct / e.total) * 100) : 0,
      }));
      if (topicBreakdown.length > 0) {
        await knowledgeService.updateMastery(userId, topicBreakdown, {
          source: 'competition',
          weight: 0.5,
        });
      }

      // Also bump CohortDirectory.weeklyAttempts so the directory stays warm.
      const cohortDirectoryService = require('./cohortDirectoryService');
      await cohortDirectoryService.recordAttempt(challenge.topic).catch(() => null);
    } catch (err) {
      // Non-fatal — the user has already finished, scoring is persisted.
      console.warn('[completeChallenge] mastery bridge failed:', err.message);
    }
```

- [ ] **Step 2: Verify syntax**

```bash
node --check src/services/competitionService.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add src/services/competitionService.js
git commit -m "feat(competition): completeChallenge feeds KnowledgeProfile mastery

After scoring, builds a topicBreakdown grouped by question.concept
(fallback to challenge.topic) and calls knowledgeService.updateMastery
with source=competition, weight=0.5. Misconception tracking and spaced
repetition automatically pick up patterns through the same path. Also
bumps CohortDirectory.weeklyAttempts.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 8 — Housekeeping cron

### Task 21: cohortDirectoryHousekeepingWorker

**Files:**
- Create: `src/workers/cohortDirectoryHousekeepingWorker.js`
- Modify: `src/workers/cronJobs.js`

- [ ] **Step 1: Write the worker**

```js
/**
 * Nightly drift-correction for CohortDirectory.
 *
 * - Recomputes memberCount from UserObjective (active+primary, by canonicalTopic).
 * - Recomputes weeklyAttempts from ChallengeAttempt (last 7 days, joined via DailyChallenge.topic).
 * - Refreshes historicalStats from a 30-day attempt aggregate.
 * - Marks isActive=false for cohorts with no attempts and no members for 30 days;
 *   reactivates anything with a fresh member or attempt.
 */
const UserObjective = require('../models/UserObjective');
const ChallengeAttempt = require('../models/ChallengeAttempt');
const CohortDirectory = require('../models/CohortDirectory');

const DAY_MS = 24 * 60 * 60 * 1000;

async function run() {
  const t0 = Date.now();

  const memberAgg = await UserObjective.aggregate([
    { $match: { status: 'active', isPrimary: true, canonicalTopic: { $exists: true, $ne: null, $ne: '' } } },
    { $group: { _id: '$canonicalTopic', count: { $sum: 1 } } },
  ]);
  const memberMap = new Map(memberAgg.map(g => [g._id, g.count]));

  const weekAgo = new Date(Date.now() - 7 * DAY_MS);
  const monthAgo = new Date(Date.now() - 30 * DAY_MS);

  const weeklyAgg = await ChallengeAttempt.aggregate([
    { $match: { completedAt: { $gte: weekAgo } } },
    { $lookup: { from: 'dailychallenges', localField: 'challengeId', foreignField: '_id', as: 'challenge' } },
    { $unwind: '$challenge' },
    { $group: { _id: '$challenge.topic', count: { $sum: 1 } } },
  ]);
  const weeklyMap = new Map(weeklyAgg.map(g => [g._id, g.count]));

  const statsAgg = await ChallengeAttempt.aggregate([
    { $match: { completedAt: { $gte: monthAgo }, handicappedScore: { $exists: true } } },
    { $lookup: { from: 'dailychallenges', localField: 'challengeId', foreignField: '_id', as: 'challenge' } },
    { $unwind: '$challenge' },
    { $group: { _id: '$challenge.topic', scores: { $push: '$handicappedScore' } } },
  ]);
  const statsMap = new Map();
  for (const s of statsAgg) {
    const sorted = [...s.scores].sort((a, b) => a - b);
    const avg = sorted.reduce((a, b) => a + b, 0) / sorted.length;
    const p90 = sorted[Math.floor(sorted.length * 0.9)] || sorted[sorted.length - 1] || 0;
    statsMap.set(s._id, { avg: Math.round(avg), p90: Math.round(p90), sampleSize: sorted.length });
  }

  const allCohorts = await CohortDirectory.find({}).lean();
  let updated = 0;
  for (const c of allCohorts) {
    const newMembers = memberMap.get(c.canonicalTopic) || 0;
    const newWeekly = weeklyMap.get(c.canonicalTopic) || 0;
    const stats = statsMap.get(c.canonicalTopic);
    const noActivity = newMembers === 0 && newWeekly === 0 && (!c.lastAttemptAt || c.lastAttemptAt < monthAgo);

    const setObj = {
      memberCount: newMembers,
      weeklyAttempts: newWeekly,
      isActive: !noActivity,
    };
    if (stats) {
      setObj.historicalStats = {
        last30dAverageScore: stats.avg,
        last30dP90Score: stats.p90,
        sampleSize: stats.sampleSize,
        refreshedAt: new Date(),
      };
    }
    await CohortDirectory.updateOne({ _id: c._id }, { $set: setObj });
    updated++;
  }

  console.log(`[CohortDirectoryHousekeeping] updated=${updated} elapsedMs=${Date.now() - t0}`);
}

module.exports = { run };
```

- [ ] **Step 2: Register the cron entry**

Open `src/workers/cronJobs.js`. After the existing `weeklyAutoCalibration` registration, add:

```js
  // 17. Cohort directory housekeeping — Daily 02:30 IST (21:00 UTC prev day).
  cronQueue.add('cohortDirectoryHousekeeping', {}, {
    repeat: { pattern: '0 21 * * *' },
    removeOnComplete: true,
  });
```

And in the worker switch, add the case alongside the others:

```js
      case 'cohortDirectoryHousekeeping':
        await require('./cohortDirectoryHousekeepingWorker').run();
        break;
```

- [ ] **Step 3: Verify syntax**

```bash
node --check src/workers/cohortDirectoryHousekeepingWorker.js && node --check src/workers/cronJobs.js && echo "OK"
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add src/workers/cohortDirectoryHousekeepingWorker.js src/workers/cronJobs.js
git commit -m "feat(competition): nightly CohortDirectory housekeeping

Rebuilds memberCount + weeklyAttempts from source-of-truth aggregates,
refreshes historicalStats from a 30-day window, and marks cohorts
inactive when they've had no members and no attempts for 30 days.
Cron fires 02:30 IST (21:00 UTC prev day) via the cronJobs queue.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 9 — iOS surfaces

### Task 22: Cohort hint line on V2CompetitionHomeView

**Files:**
- Modify: `ScaleUp/Features/V2/Compass/V2CompetitionHomeView.swift`

- [ ] **Step 1: Extend `RelevantResponse` to decode the new fields**

In `V2CompetitionHomeView.swift`, locate the `RelevantResponse` struct (added in build 138/139). Add two fields:

```swift
private struct RelevantResponse: Codable {
    let status: String
    let objectiveTopic: String?
    let topicMatch: Bool?
    let cohortMemberCount: Int?
    let cohortPlayedToday: Int?
    let todayChallenge: TodayChallenge?
    let nextLiveEvent: LiveEvent?
}
```

- [ ] **Step 2: Store them on the view**

Add two `@State` vars near the existing ones (e.g., below `topicMatch`):

```swift
@State private var cohortMemberCount: Int = 0
@State private var cohortPlayedToday: Int = 0
```

In `load()` after decoding `data`, assign them:

```swift
cohortMemberCount = data.cohortMemberCount ?? 0
cohortPlayedToday = data.cohortPlayedToday ?? 0
```

- [ ] **Step 3: Render the hint under the challenge card title**

In `challengeCard(_:)`, inside the `VStack(alignment: .leading, spacing: 2)` that holds the title + meta line, add **between** the title `Text(...)` and the existing `Text(metaLine(c))`:

```swift
if cohortMemberCount > 0 {
    Text("\(cohortMemberCount) in your cohort · \(cohortPlayedToday) played today")
        .font(.system(size: 10))
        .foregroundStyle(ColorTokens.gold)
}
```

- [ ] **Step 4: Build verify**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Debug -destination "generic/platform=iOS" build 2>&1 | grep -E "error:|BUILD " | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ScaleUp/Features/V2/Compass/V2CompetitionHomeView.swift
git commit -m "feat(v2): cohort size hint on competition card

V2CompetitionHomeView decodes cohortMemberCount + cohortPlayedToday from
/competition/relevant and renders \"N in your cohort · M played today\"
under the challenge title so the user feels the community is real.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 23: Ghost-aware leaderboard rendering

**Files:**
- Inspect first, then modify: `ScaleUp/Features/Competition/`

- [ ] **Step 1: Find the leaderboard view + entry model**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
grep -rn "WeeklyLeaderboard\|weekly.*Leaderboard\|LeaderboardEntry\|handicappedScore" ScaleUp/Features/Competition --include="*.swift" | head
```

Note the exact file path of the leaderboard view and the entry struct. Call them `<LeaderboardView.swift>` and `<LeaderboardEntry.swift>` below.

- [ ] **Step 2: Add `ghostKind` + `displayName` to the entry decode**

Open the entry model file. Add (with backward-compatible decoding for fields absent in legacy responses):

```swift
let ghostKind: String?    // "historical" | "persona" | nil
let displayName: String?
```

If the struct has a `CodingKeys` enum, add the two cases there too:

```swift
case ghostKind, displayName
```

- [ ] **Step 3: Render ghost rows with italic + long-press subtext**

In the leaderboard row view, wrap the existing row body:

```swift
.italic(entry.ghostKind != nil)
.contextMenu {
    if entry.ghostKind == "persona" {
        Text("Synthetic competitor — see how you stack against the cohort historically.")
    } else if entry.ghostKind == "historical" {
        Text("Historical benchmark from your cohort's last 30 days.")
    }
}
```

If `.italic(_:)` isn't directly available on the row's container, apply it to the user's name `Text`. Avoid adding any visible badge; the design specifies *long-press only* (`.contextMenu` is iOS's long-press menu).

If the row currently renders a username via `entry.userId` or fetches it, prefer `entry.displayName ?? <existingFallback>`.

- [ ] **Step 4: Build verify**

```bash
xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Debug -destination "generic/platform=iOS" build 2>&1 | grep -E "error:|BUILD " | head -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ScaleUp/Features/Competition/
git commit -m "feat(v2): ghost-aware leaderboard rendering

Leaderboard entries now decode ghostKind + displayName. Ghost rows render
italic and surface their nature only on long-press via a contextMenu
subtext — so the UI looks consistent but the user can verify nothing's
fake-padded above them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 10 — Deploy + verify

### Task 24: Deploy backend + run backfill

**Files:** none (operational)

- [ ] **Step 1: Push backend to master to trigger CI deploy**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git push origin master
```

- [ ] **Step 2: Wait for deploy to land (poll health)**

```bash
until curl -sS https://api.scaleupapp.club/health | grep -q '"status":"ok"'; do sleep 5; done && echo "API live"
```

- [ ] **Step 3: Trigger backfill via the SSH-deployed scripts**

The GitHub Actions deploy step runs `deploy.sh` on EC2, which leaves the scripts on the host. SSH in (or trigger via the `run-migration.yml` workflow if it's set up for arbitrary scripts), then:

```bash
# On the EC2 box, inside the app dir:
NODE_ENV=production node scripts/backfill-canonical-topics.js --dry-run
# Review output. If sane:
NODE_ENV=production node scripts/backfill-canonical-topics.js
NODE_ENV=production node scripts/bootstrap-cohort-directory.js --dry-run
NODE_ENV=production node scripts/bootstrap-cohort-directory.js
```

- [ ] **Step 4: Verify via the live endpoints with the test account**

```bash
RESP=$(curl -sS -X POST 'https://api.scaleupapp.club/api/v1/auth/login' \
  -H "Content-Type: application/json" \
  -d '{"email":"claudetest_1778774728@scaleuptest.club","password":"TestPass123!"}')
TOKEN=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['accessToken'])")
echo "=== /competition/relevant ==="
curl -sS "https://api.scaleupapp.club/api/v1/competition/relevant" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

Expected: response contains `cohortMemberCount`, `cohortPlayedToday`, and `objectiveTopic` is a canonical slug from the taxonomy.

```bash
echo "=== Weekly leaderboard for cohort ==="
TOPIC=$(echo "$RESP" | python3 -c "import sys,json; print('gmat')")  # or whatever the test account resolves to
curl -sS "https://api.scaleupapp.club/api/v1/competition/leaderboard/weekly?topic=$TOPIC" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool | head -50
```

Expected: top entries include `ghostKind: "historical"` or `"persona"` if the cohort has fewer than 10 real entries this week.

- [ ] **Step 5: Bump iOS build, archive, upload**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
# Update project.yml: CURRENT_PROJECT_VERSION: 140
xcodegen
xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp -configuration Release -destination "generic/platform=iOS" -archivePath "./build/ScaleUp-140.xcarchive" archive
xcodebuild -exportArchive -archivePath "./build/ScaleUp-140.xcarchive" -exportOptionsPlist ExportOptions.plist -exportPath "./build/ScaleUp-140-export" -allowProvisioningUpdates -authenticationKeyPath "/Users/nirpekshnandan/.private_keys/AuthKey_A4MNMMCCVB.p8" -authenticationKeyID "A4MNMMCCVB" -authenticationKeyIssuerID "0bbf6f7f-a7cf-4b88-8759-4c85e5c0f240"
```

Expected: `** EXPORT SUCCEEDED **`.

- [ ] **Step 6: Final commit on iOS with the build bump**

```bash
git add project.yml
git commit -m "chore(ios): bump build to 140 for competition cohort matching release

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push origin v2-redesign
```

---

## Success criteria (mirror of spec §14)

After Task 24 lands, manually verify:

- Two test users with raw inputs "PM" and "Product Manager" land in the same canonical cohort (`product-manager`) and `/competition/relevant` returns the same `todayChallenge._id` for both.
- A solo new user in a fresh cohort sees a 5-row leaderboard (self + 2 historical + 2 personas) — not a 1-row leaderboard.
- Two users share the same Q3 question text but different `correctAnswer` labels in the response shape (verify by inspecting `/challenges/:id/start` responses for two different `userId`s).
- Finishing a daily challenge moves the user's `KnowledgeProfile.topicMastery[canonicalTopic].score` by a non-zero amount (delta should be ~half of what an equivalent solo quiz would produce, per the 0.5× weight).
- `CohortDirectory.memberCount` matches the active-objective count within ±1 after the next housekeeping cron pass.

---

## Out of scope (do NOT implement in this plan)

These are explicitly deferred per spec §12. Do not start them:

- Skill-level sub-cohorts.
- ChatGPT-resistance via live-only format.
- External perks / rewards.
- Discussion threads per challenge.
- Compass "popular cohort" discovery surface.
