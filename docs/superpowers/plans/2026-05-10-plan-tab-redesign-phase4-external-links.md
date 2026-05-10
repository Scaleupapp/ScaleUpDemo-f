# Plan Tab Redesign — Phase 4: External Links via LLM-as-Judge

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a topic's in-app coverage isn't sufficient to advance the user one band, the plan generator emits 0-3 curated external content links per week per topic. Links are vetted by an LLM-as-judge against a domain whitelist. Users tap a link → open in browser → confirm completion with a self-rating chip → the URL + rating + topic is stored in a new `ExternalContentTouch` collection so future recalibrations know what they've consumed.

**Architecture:**
- Backend gen-time: a new `externalContentJudgeService` runs after `taskCatalogService.resolveTopic` for each allocation. The judge is given the topic, the user's measured band, the in-app coverage (titles/summaries of the matched quiz + content), and the objective context. It returns `{ inAppCoverageAdequate, gaps, externalLinks }` with 0-3 links. Whitelist enforcement drops any URL whose domain isn't approved.
- The `planGenerationService` post-processor adds `external_link` tasks for every returned link.
- New `ExternalContentTouch` collection captures `{ userId, taskId, url, topic, selfRating, completedAt }` when the user marks an `external_link` task complete via the existing `POST /plan/tasks/:taskId/complete` endpoint.
- iOS: tapping an `external_link` task opens the URL in the system browser via `UIApplication.shared.open(_:)` (no in-app browser dependency), then immediately presents the existing `ManualCompletionSheet` so the user can self-rate. Same flow on Android via `Linking.openURL` + the existing `ManualCompletionSheet`.

**Tech Stack:** Node 18 + Express + Mongoose, OpenAI client (existing pattern), `node:test`; Swift 5 + SwiftUI; React Native + TypeScript.

**Spec:** `docs/superpowers/specs/2026-05-09-plan-tab-redesign-design.md` §5 (LLM-as-judge), §7 phase 4. The spec also calls for the manual completion sheet to record `selfRating` into `KnowledgeProfile.topicSelfRatings` — Phase 3's `markManualComplete` already does this; Phase 4 just adds the parallel write to `ExternalContentTouch`.

**Phase 1+2+3 prerequisite (all on master/main):**
- Backend: `3cacd28` (Phase 3 manual completion endpoint)
- iOS: `f989185` (Phase 3 follow-up: interview scenario seed)
- Android: `88c76ad` (Phase 3 follow-up: competition cross-tab nav)

**Repo layout:**
- Backend: `/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend/`
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/`
- Android: `/Users/nirpekshnandan/My Products/ScaleUpAndroid/`

---

## File Structure

**Created:**
- `scaleup-backend/src/config/externalContentWhitelist.js` — curated domain list.
- `scaleup-backend/src/services/plan/externalContentJudgeService.js` — LLM-as-judge.
- `scaleup-backend/src/services/plan/externalContentJudgeService.test.js`
- `scaleup-backend/src/models/ExternalContentTouch.js`
- `scaleup-backend/src/models/ExternalContentTouch.test.js`

**Modified:**
- `scaleup-backend/src/services/diagnostic/planGenerationService.js` — call the judge per allocation, emit `external_link` tasks.
- `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`
- `scaleup-backend/src/services/plan/planProgressService.js` — `markManualComplete` writes an `ExternalContentTouch` row when the task type is `external_link`.
- `scaleup-backend/src/services/plan/planProgressService.test.js`
- `ScaleUp/Features/Plan/Views/PlanTabView.swift` — `external_link` tap opens URL externally then presents `ManualCompletionSheet`.
- `ScaleUpAndroid/src/screens/plan/PlanTabScreen.tsx` — same pattern for `external_link`.

Each task ends with a commit. Backend tests use `node:test`.

---

## Task 1: Backend — `externalContentWhitelist` config

**Files:**
- Create: `scaleup-backend/src/config/externalContentWhitelist.js`

A curated list of trusted domains the LLM-judge can recommend from. Anything outside the list is dropped. The list spans free, India-relevant, and globally reputable sources.

- [ ] **Step 1: Create the config**

Create `scaleup-backend/src/config/externalContentWhitelist.js`:

```javascript
/**
 * Curated whitelist of domains the LLM external-content judge may recommend.
 *
 * Keep this list small and trustworthy. Each entry is a hostname (no scheme,
 * no path). Subdomains are matched: 'mit.edu' matches 'ocw.mit.edu'.
 *
 * Add new entries only after a human review of: content quality, free
 * accessibility (no paywall), India-friendliness (or globally relevant),
 * and source reputation.
 */

const ALLOWED_DOMAINS = [
  // Open courseware + structured learning (free)
  'ocw.mit.edu',
  'cs50.harvard.edu',
  'freecodecamp.org',
  'khanacademy.org',
  'developer.mozilla.org',
  'web.dev',

  // MOOC platforms — free audit tracks only; the judge prompt must specify
  // "no paid courses"
  'coursera.org',
  'edx.org',
  'nptel.ac.in',
  'swayam.gov.in',

  // Official documentation
  'react.dev',
  'reactnative.dev',
  'nodejs.org',
  'docs.python.org',
  'docs.mongodb.com',
  'kubernetes.io',
  'docs.aws.amazon.com',
  'cloud.google.com',
  'docs.microsoft.com',

  // Engineering blogs (reputable)
  'engineering.fb.com',
  'netflixtechblog.com',
  'stripe.com',
  'cloudflare.com',
  'highscalability.com',

  // PM / interview prep (free articles)
  'lennysnewsletter.com',
  'productschool.com',
  'svpg.com',

  // Academic content (free)
  'arxiv.org',
  'distill.pub',

  // Curated YouTube channels (judge prompt must specify channel-not-random)
  'youtube.com/@3blue1brown',
  'youtube.com/@computerphile',
  'youtube.com/@LexFridman',
  'youtube.com/@TwoMinutePapers',
];

/**
 * Returns true if the hostname (or any of its parent domains) appears in the whitelist.
 * Examples:
 *   isAllowed('https://ocw.mit.edu/courses/x') -> true
 *   isAllowed('https://random-blog.io/post')   -> false
 */
function isAllowed(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return false;
  let url;
  try { url = new URL(rawUrl); } catch { return false; }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return false;
  const host = url.hostname.toLowerCase();
  // YouTube channel allow-listing — match host + first path segment
  if (host === 'youtube.com' || host === 'www.youtube.com') {
    const firstSegment = url.pathname.split('/').filter(Boolean)[0] || '';
    const channelKey = `youtube.com/${firstSegment}`;
    return ALLOWED_DOMAINS.includes(channelKey);
  }
  // Standard domain match: exact OR subdomain of an allowed entry.
  return ALLOWED_DOMAINS.some(entry => {
    if (entry.includes('/')) return false; // YouTube-style entries handled above
    return host === entry || host.endsWith(`.${entry}`);
  });
}

module.exports = { ALLOWED_DOMAINS, isAllowed };
```

- [ ] **Step 2: Quick smoke test** (no test file — this is config + a tiny pure helper)

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node -e "
const { isAllowed } = require('./src/config/externalContentWhitelist');
const cases = [
  ['https://ocw.mit.edu/courses/x', true],
  ['https://docs.mongodb.com/manual', true],
  ['https://www.youtube.com/@3blue1brown/videos', true],
  ['https://www.youtube.com/@randomCreator/videos', false],
  ['https://random-blog.io/post', false],
  ['ftp://ocw.mit.edu/file', false],
  ['not-a-url', false],
  [null, false],
];
let pass = 0, fail = 0;
for (const [u, expect] of cases) {
  const got = isAllowed(u);
  if (got === expect) pass++;
  else { fail++; console.log('FAIL', u, 'expected', expect, 'got', got); }
}
console.log(\`smoke: \${pass}/\${pass + fail} pass\`);
process.exit(fail === 0 ? 0 : 1);
"
```

Expected: `smoke: 8/8 pass`.

- [ ] **Step 3: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/config/externalContentWhitelist.js
git commit -m "feat(plan): external content domain whitelist + isAllowed helper"
```

---

## Task 2: Backend — `externalContentJudgeService`

**Files:**
- Create: `scaleup-backend/src/services/plan/externalContentJudgeService.js`
- Create: `scaleup-backend/src/services/plan/externalContentJudgeService.test.js`

Single function `judgeTopic({ objectiveType, targetKey, topic, measuredBand, inAppContent })`. Calls OpenAI with a structured-output prompt; returns `{ inAppCoverageAdequate, gaps, externalLinks }`. URLs failing `isAllowed(...)` are dropped before returning. On any LLM failure, returns the safe-default `{ inAppCoverageAdequate: true, gaps: [], externalLinks: [] }` so plan generation continues.

`inAppContent` is `[{ title: string, summary?: string, type: 'quiz' | 'content' }]` describing what's already in the plan for this topic.

- [ ] **Step 1: Add failing tests**

Create `scaleup-backend/src/services/plan/externalContentJudgeService.test.js`:

```javascript
const test = require('node:test');
const assert = require('node:assert');

delete require.cache[require.resolve('./externalContentJudgeService')];
const judgeService = require('./externalContentJudgeService');

const openai = require('../../config/openai');

function withStubbedLLM(returnValue, fn) {
  const orig = openai.chat.completions.create;
  openai.chat.completions.create = async () => ({
    choices: [{ message: { content: JSON.stringify(returnValue) } }],
  });
  return fn().finally(() => { openai.chat.completions.create = orig; });
}

test('judgeTopic: returns adequate=true with empty links when LLM says coverage is fine', async () => {
  await withStubbedLLM(
    { inAppCoverageAdequate: true, gaps: [], externalLinks: [] },
    async () => {
      const out = await judgeService.judgeTopic({
        objectiveType: 'upskilling',
        targetKey: 'upskilling::react',
        topic: 'react-hooks',
        measuredBand: 'developing',
        inAppContent: [{ title: 'React Hooks Quiz', type: 'quiz' }],
      });
      assert.strictEqual(out.inAppCoverageAdequate, true);
      assert.deepStrictEqual(out.externalLinks, []);
    },
  );
});

test('judgeTopic: filters out external links not on the whitelist', async () => {
  await withStubbedLLM(
    {
      inAppCoverageAdequate: false,
      gaps: ['advanced patterns missing'],
      externalLinks: [
        { url: 'https://ocw.mit.edu/courses/foo', title: 'MIT OCW Foo', source: 'mit', why: 'reason', estimatedMinutes: 30 },
        { url: 'https://random-spam-blog.io/foo', title: 'Spam', source: 'spam', why: 'r', estimatedMinutes: 10 },
        { url: 'not-a-url', title: 'broken', source: 'x', why: 'r', estimatedMinutes: 5 },
      ],
    },
    async () => {
      const out = await judgeService.judgeTopic({
        objectiveType: 'upskilling',
        targetKey: 'upskilling::react',
        topic: 'react-hooks',
        measuredBand: 'developing',
        inAppContent: [],
      });
      assert.strictEqual(out.inAppCoverageAdequate, false);
      assert.strictEqual(out.externalLinks.length, 1, 'only the MIT link should survive');
      assert.strictEqual(out.externalLinks[0].url, 'https://ocw.mit.edu/courses/foo');
    },
  );
});

test('judgeTopic: caps externalLinks at 3 even if LLM returns more', async () => {
  await withStubbedLLM(
    {
      inAppCoverageAdequate: false,
      gaps: ['gap'],
      externalLinks: Array.from({ length: 5 }, (_, i) => ({
        url: `https://ocw.mit.edu/courses/${i}`,
        title: `MIT ${i}`,
        source: 'mit',
        why: 'r',
        estimatedMinutes: 20,
      })),
    },
    async () => {
      const out = await judgeService.judgeTopic({
        objectiveType: 'upskilling',
        targetKey: 'k',
        topic: 'react-hooks',
        measuredBand: 'developing',
        inAppContent: [],
      });
      assert.strictEqual(out.externalLinks.length, 3);
    },
  );
});

test('judgeTopic: returns safe default on LLM failure', async () => {
  const orig = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('LLM down'); };
  try {
    const out = await judgeService.judgeTopic({
      objectiveType: 'upskilling',
      targetKey: 'k',
      topic: 'react-hooks',
      measuredBand: 'developing',
      inAppContent: [],
    });
    assert.strictEqual(out.inAppCoverageAdequate, true, 'failure mode = treat as adequate (no spam)');
    assert.deepStrictEqual(out.externalLinks, []);
  } finally {
    openai.chat.completions.create = orig;
  }
});
```

- [ ] **Step 2: Run to verify failure**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/externalContentJudgeService.test.js
```

Expected: 4 tests fail with `Cannot find module`.

- [ ] **Step 3: Implement the service**

Create `scaleup-backend/src/services/plan/externalContentJudgeService.js`:

```javascript
const openai = require('../../config/openai');
const { isAllowed } = require('../../config/externalContentWhitelist');

const MODEL = 'gpt-4o-mini';
const TIMEOUT_MS = 12000;
const MAX_LINKS = 3;

const SYSTEM_PROMPT = `You evaluate whether ScaleUp's in-app content is sufficient for a learner to advance one proficiency band on a given topic. If gaps exist, recommend 0-3 free, high-quality external resources from a curated whitelist of domains.

CONSTRAINTS:
- Only recommend resources that are FREE (no paywall, no required signup beyond a free account).
- Only recommend from these domains (or their subdomains): MIT OpenCourseWare (ocw.mit.edu), Harvard CS50 (cs50.harvard.edu), freeCodeCamp, Khan Academy, MDN, web.dev, official docs (react.dev, reactnative.dev, nodejs.org, python.org, mongodb.com/docs, kubernetes.io, AWS docs, GCP docs, MS docs), engineering blogs (Stripe, Cloudflare, Netflix Tech, Meta Engineering, High Scalability), Lenny's Newsletter, Product School, SVPG, arXiv, Distill.pub, Coursera/edX/NPTEL/SWAYAM (free audit only), and curated YouTube channels (3blue1brown, Computerphile, Lex Fridman, Two Minute Papers).
- For Coursera/edX, only suggest the free-audit version.
- For YouTube, ONLY suggest from the listed channels — never random uploads.
- If in-app coverage is sufficient, return { "inAppCoverageAdequate": true, "gaps": [], "externalLinks": [] }.
- Tailor recommendations to the user's measured band (novice/developing/proficient/expert) — don't suggest 'advanced patterns' content for a novice.
- Each link must include url, title, source (the domain or platform name), why (1 sentence explaining why this fills the gap), estimatedMinutes (10-90).`;

const RESPONSE_SCHEMA = {
  type: 'json_schema',
  json_schema: {
    name: 'external_content_judgment',
    strict: true,
    schema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        inAppCoverageAdequate: { type: 'boolean' },
        gaps: { type: 'array', items: { type: 'string' } },
        externalLinks: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              url: { type: 'string' },
              title: { type: 'string' },
              source: { type: 'string' },
              why: { type: 'string' },
              estimatedMinutes: { type: 'integer' },
            },
            required: ['url', 'title', 'source', 'why', 'estimatedMinutes'],
          },
        },
      },
      required: ['inAppCoverageAdequate', 'gaps', 'externalLinks'],
    },
  },
};

const SAFE_DEFAULT = Object.freeze({
  inAppCoverageAdequate: true,
  gaps: [],
  externalLinks: [],
});

async function judgeTopic({ objectiveType, targetKey, topic, measuredBand, inAppContent }) {
  const inAppDescription = (inAppContent || [])
    .map(c => `- ${c.type}: ${c.title}${c.summary ? ` — ${c.summary}` : ''}`)
    .join('\n') || '(none)';

  const userMessage = [
    `Objective type: ${objectiveType}`,
    `Target context: ${targetKey}`,
    `Topic: ${topic}`,
    `Measured band: ${measuredBand}`,
    'In-app content available for this topic:',
    inAppDescription,
    '',
    'Question: is the in-app coverage above sufficient for the user to advance one band on this topic? If not, what specific gaps exist, and what 0-3 external resources from the whitelist would close those gaps?',
  ].join('\n');

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const resp = await openai.chat.completions.create({
      model: MODEL,
      temperature: 0.3,
      response_format: RESPONSE_SCHEMA,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userMessage },
      ],
    }, { signal: controller.signal });
    clearTimeout(timer);

    const content = resp?.choices?.[0]?.message?.content;
    if (!content) return { ...SAFE_DEFAULT };

    let parsed;
    try { parsed = JSON.parse(content); }
    catch (e) {
      console.warn('[externalContentJudgeService] JSON parse failed:', e.message);
      return { ...SAFE_DEFAULT };
    }

    const filteredLinks = (parsed.externalLinks || [])
      .filter(link => link && typeof link.url === 'string' && isAllowed(link.url))
      .slice(0, MAX_LINKS)
      .map(link => ({
        url: link.url,
        title: String(link.title || '').slice(0, 200),
        source: String(link.source || '').slice(0, 80),
        why: String(link.why || '').slice(0, 280),
        estimatedMinutes: Number.isFinite(link.estimatedMinutes) ? Math.max(5, Math.min(180, link.estimatedMinutes)) : 30,
      }));

    return {
      inAppCoverageAdequate: !!parsed.inAppCoverageAdequate,
      gaps: Array.isArray(parsed.gaps) ? parsed.gaps.slice(0, 5) : [],
      externalLinks: filteredLinks,
    };
  } catch (err) {
    clearTimeout(timer);
    console.warn('[externalContentJudgeService] judge failed, returning safe default:', err.message);
    return { ...SAFE_DEFAULT };
  }
}

module.exports = { judgeTopic, _internal: { MAX_LINKS, SAFE_DEFAULT } };
```

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/externalContentJudgeService.test.js
```

Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/plan/externalContentJudgeService.js src/services/plan/externalContentJudgeService.test.js
git commit -m "feat(plan): externalContentJudgeService with whitelist filtering"
```

---

## Task 3: Backend — generator emits `external_link` tasks

**Files:**
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.js`
- Modify: `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`

In the existing per-allocation post-processor, AFTER all other task emissions (quiz, in_app_content, ai_interview, competition, manual), call the judge with the in-app coverage we already collected for this topic, and emit one `external_link` task per returned link.

Each external_link task:
- `type: 'external_link'`
- `topic: topicShape`
- `payload: { url, title, source, why, estimatedMinutes }`
- `completion: { mode: 'manual', requiresSelfRating: true }`
- `progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null }`

The judge call is best-effort — wrap in try/catch and treat as `{ externalLinks: [] }` on failure. Keep latency reasonable: in production this adds ~1-3s per topic per week. For an 8-topic 12-week plan that's potentially a 2-3 minute LLM cost. **For Phase 4, gate the judge behind `process.env.FEATURE_EXTERNAL_CONTENT_JUDGE === 'true'`** — disabled by default until we observe cost/latency in staging.

The pre-existing pre-allocation `band` info: derive measuredBand from `input.topicResults` (find the entry for this topic — `topicResults.find(t => t.canonicalName === alloc.topicCanonicalName)?.measuredBand || 'developing'`).

- [ ] **Step 1: Add failing tests**

Append to `scaleup-backend/src/services/diagnostic/planGenerationService.test.js`:

```javascript
test('generate: emits external_link tasks when judge returns links AND feature flag is on', async () => {
  process.env.FEATURE_EXTERNAL_CONTENT_JUDGE = 'true';
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

  const judgeService = require('../plan/externalContentJudgeService');
  const origJudge = judgeService.judgeTopic;
  judgeService.judgeTopic = async () => ({
    inAppCoverageAdequate: false,
    gaps: ['advanced patterns'],
    externalLinks: [
      { url: 'https://ocw.mit.edu/courses/x', title: 'MIT OCW: X', source: 'mit', why: 'patterns deep dive', estimatedMinutes: 45 },
    ],
  });

  try {
    const out = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'upskilling',
      specificsCanonical: { targetSkill: 'react' },
      timeline: 2, weeklyCommitHours: 5,
      topicResults: [{ canonicalName: 'react-hooks', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false }],
    });
    const w0 = out.weeklySchedule[0];
    const externalLinkTasks = w0.tasks.filter(t => t.type === 'external_link');
    assert.strictEqual(externalLinkTasks.length, 1);
    assert.strictEqual(externalLinkTasks[0].payload.url, 'https://ocw.mit.edu/courses/x');
    assert.strictEqual(externalLinkTasks[0].completion.mode, 'manual');
    assert.strictEqual(externalLinkTasks[0].completion.requiresSelfRating, true);
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
    judgeService.judgeTopic = origJudge;
    delete process.env.FEATURE_EXTERNAL_CONTENT_JUDGE;
  }
});

test('generate: emits NO external_link tasks when feature flag is off (default)', async () => {
  delete process.env.FEATURE_EXTERNAL_CONTENT_JUDGE;
  const planService = require('./planGenerationService');
  const mongoose = require('mongoose');

  const openai = require('../../config/openai');
  const origCreate = openai.chat.completions.create;
  openai.chat.completions.create = async () => { throw new Error('test stub'); };

  const taskCatalogService = require('../plan/taskCatalogService');
  const origResolve = taskCatalogService.resolveTopic;
  taskCatalogService.resolveTopic = async () => ({ quizId: 'qz1', contentId: 'c1', contentType: 'article', quizMinutes: 8, contentMinutes: 12 });

  const judgeService = require('../plan/externalContentJudgeService');
  const origJudge = judgeService.judgeTopic;
  let judgeCalls = 0;
  judgeService.judgeTopic = async () => { judgeCalls++; return { inAppCoverageAdequate: false, gaps: [], externalLinks: [{ url: 'https://ocw.mit.edu/x', title: 't', source: 's', why: 'w', estimatedMinutes: 30 }] }; };

  try {
    const out = await planService.generate({
      userId: new mongoose.Types.ObjectId(),
      objectiveId: new mongoose.Types.ObjectId(),
      diagnosticAttemptId: new mongoose.Types.ObjectId(),
      objectiveType: 'upskilling',
      specificsCanonical: { targetSkill: 'react' },
      timeline: 1, weeklyCommitHours: 5,
      topicResults: [{ canonicalName: 'react-hooks', selfRating: 'familiar', measuredScore: 50, measuredBand: 'developing', calibrationDelta: 0, calibrationClass: 'well-calibrated', questionsAsked: 4, answerPattern: {}, isFutureProofing: false }],
    });
    const w0 = out.weeklySchedule[0];
    assert.strictEqual(w0.tasks.filter(t => t.type === 'external_link').length, 0);
    assert.strictEqual(judgeCalls, 0, 'judge must not be called when feature flag is off');
  } finally {
    openai.chat.completions.create = origCreate;
    taskCatalogService.resolveTopic = origResolve;
    judgeService.judgeTopic = origJudge;
  }
});
```

- [ ] **Step 2: Run to verify failure**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/diagnostic/planGenerationService.test.js
```

Expected: 2 new tests fail.

- [ ] **Step 3: Add the judge call to the post-processor**

In `src/services/diagnostic/planGenerationService.js`, at the top with the other requires, add:

```javascript
const externalContentJudgeService = require('../plan/externalContentJudgeService');
```

Inside the per-allocation block (after the `manual` fallback emission, still inside the `for (const alloc of ...)` loop), add:

```javascript
      // external_link tasks via LLM-as-judge — gated behind feature flag
      // because of latency/cost. When enabled, evaluates if in-app coverage
      // is enough for the user to advance one band; emits 0-3 vetted external
      // links if there are gaps.
      if (process.env.FEATURE_EXTERNAL_CONTENT_JUDGE === 'true') {
        const inAppContent = [];
        if (resolved.quizId) inAppContent.push({ type: 'quiz', title: `Quiz on ${displayName}` });
        if (resolved.contentId) inAppContent.push({ type: 'content', title: `Content on ${displayName}` });
        const measuredBand = (input.topicResults || [])
          .find(t => t.canonicalName === alloc.topicCanonicalName)?.measuredBand || 'developing';
        try {
          const judgment = await externalContentJudgeService.judgeTopic({
            objectiveType: input.objectiveType,
            targetKey: `${input.objectiveType}::${input.specificsCanonical?.targetRole || input.specificsCanonical?.targetSkill || 'general'}`,
            topic: alloc.topicCanonicalName,
            measuredBand,
            inAppContent,
          });
          for (const link of (judgment.externalLinks || [])) {
            tasks.push({
              type: 'external_link',
              topic: topicShape,
              payload: {
                url: link.url,
                title: link.title,
                source: link.source,
                why: link.why,
                estimatedMinutes: link.estimatedMinutes,
              },
              completion: { mode: 'manual', requiresSelfRating: true },
              progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
            });
          }
        } catch (err) {
          console.warn('[planGenerationService] externalContentJudge failed:', err.message);
        }
      }
```

(`topicShape`, `displayName`, `resolved`, `alloc`, `tasks`, `input` are all in scope at this point.)

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/diagnostic/planGenerationService.test.js
```

Expected: ALL tests pass (existing 11 + 2 new). The Phase 3 tests should still pass since they don't set `FEATURE_EXTERNAL_CONTENT_JUDGE`.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/diagnostic/planGenerationService.js src/services/diagnostic/planGenerationService.test.js
git commit -m "feat(plan): generator emits external_link tasks via LLM-judge (feature-flagged)"
```

---

## Task 4: Backend — `ExternalContentTouch` model

**Files:**
- Create: `scaleup-backend/src/models/ExternalContentTouch.js`
- Create: `scaleup-backend/src/models/ExternalContentTouch.test.js`

A small append-only collection that records every external link the user marked complete. Future recalibrations consult this collection to factor in external consumption.

- [ ] **Step 1: Create the model**

Create `scaleup-backend/src/models/ExternalContentTouch.js`:

```javascript
const mongoose = require('mongoose');

const externalContentTouchSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  taskId: { type: mongoose.Schema.Types.ObjectId, required: true },
  url: { type: String, required: true },
  title: { type: String, default: '' },
  source: { type: String, default: '' },
  topicCanonicalName: { type: String, required: true, index: true },
  selfRating: { type: Number, min: 1, max: 5, required: true },
  completedAt: { type: Date, default: Date.now, index: true },
}, { timestamps: true });

externalContentTouchSchema.index({ userId: 1, topicCanonicalName: 1 });
externalContentTouchSchema.index({ userId: 1, completedAt: -1 });

module.exports = mongoose.model('ExternalContentTouch', externalContentTouchSchema);
```

- [ ] **Step 2: Create the model test**

Create `scaleup-backend/src/models/ExternalContentTouch.test.js`:

```javascript
const test = require('node:test');
const assert = require('node:assert');
const mongoose = require('mongoose');

delete require.cache[require.resolve('./ExternalContentTouch')];
const ExternalContentTouch = require('./ExternalContentTouch');

test('ExternalContentTouch: validates with required fields', () => {
  const doc = new ExternalContentTouch({
    userId: new mongoose.Types.ObjectId(),
    taskId: new mongoose.Types.ObjectId(),
    url: 'https://ocw.mit.edu/x',
    title: 'MIT OCW: X',
    source: 'mit',
    topicCanonicalName: 'react-hooks',
    selfRating: 4,
  });
  const err = doc.validateSync();
  assert.strictEqual(err, undefined);
  assert.strictEqual(doc.selfRating, 4);
  assert.ok(doc.completedAt instanceof Date);
});

test('ExternalContentTouch: rejects selfRating outside 1-5', () => {
  const doc = new ExternalContentTouch({
    userId: new mongoose.Types.ObjectId(),
    taskId: new mongoose.Types.ObjectId(),
    url: 'https://ocw.mit.edu/x',
    topicCanonicalName: 'react-hooks',
    selfRating: 99,
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.selfRating, 'selfRating range should be enforced');
});

test('ExternalContentTouch: requires url', () => {
  const doc = new ExternalContentTouch({
    userId: new mongoose.Types.ObjectId(),
    taskId: new mongoose.Types.ObjectId(),
    topicCanonicalName: 'react-hooks',
    selfRating: 3,
  });
  const err = doc.validateSync();
  assert.ok(err && err.errors.url, 'url required');
});
```

- [ ] **Step 3: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/models/ExternalContentTouch.test.js
```

Expected: 3/3 pass.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/models/ExternalContentTouch.js src/models/ExternalContentTouch.test.js
git commit -m "feat(plan): ExternalContentTouch model for capture-on-completion"
```

---

## Task 5: Backend — `markManualComplete` writes ExternalContentTouch for external_link tasks

**Files:**
- Modify: `scaleup-backend/src/services/plan/planProgressService.js`
- Modify: `scaleup-backend/src/services/plan/planProgressService.test.js`

When `markManualComplete` succeeds AND the completed task's type is `external_link`, also insert an `ExternalContentTouch` row. Best-effort — wrapped in try/catch with `console.warn`.

- [ ] **Step 1: Add a failing test**

Append to `scaleup-backend/src/services/plan/planProgressService.test.js`:

```javascript
test('markManualComplete: writes ExternalContentTouch when task type is external_link', async () => {
  const ExternalContentTouch = require('../../models/ExternalContentTouch');
  const inserted = [];
  const origCreate = ExternalContentTouch.create;
  ExternalContentTouch.create = async (doc) => { inserted.push(doc); return doc; };

  const plan = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    weeklySchedule: [{
      week: 1, weeklyGoal: 'g', allocations: [],
      tasks: [{
        _id: new mongoose.Types.ObjectId(),
        type: 'external_link',
        topic: { canonicalName: 'react-hooks', displayName: 'React Hooks' },
        payload: { url: 'https://ocw.mit.edu/x', title: 'MIT OCW: X', source: 'mit', why: 'r', estimatedMinutes: 30 },
        completion: { mode: 'manual', requiresSelfRating: true },
        progress: { status: 'pending', completedAt: null, selfRating: null, sourceEventId: null },
      }],
    }],
    save: async function () { this._saved = true; return this; },
  };
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
    assert.strictEqual(inserted.length, 1, 'should insert one ExternalContentTouch');
    assert.strictEqual(inserted[0].url, 'https://ocw.mit.edu/x');
    assert.strictEqual(inserted[0].selfRating, 4);
    assert.strictEqual(inserted[0].topicCanonicalName, 'react-hooks');
    assert.strictEqual(String(inserted[0].userId), plan.userId.toString());
  } finally {
    Plan.findOne = origFindOne;
    ExternalContentTouch.create = origCreate;
  }
});

test('markManualComplete: does NOT write ExternalContentTouch for non-external_link tasks', async () => {
  const ExternalContentTouch = require('../../models/ExternalContentTouch');
  const inserted = [];
  const origCreate = ExternalContentTouch.create;
  ExternalContentTouch.create = async (doc) => { inserted.push(doc); return doc; };

  const plan = makePlanWithManualTask(); // existing factory from Phase 3 tests
  const taskId = plan.weeklySchedule[0].tasks[0]._id.toString();
  const origFindOne = Plan.findOne;
  Plan.findOne = () => ({ sort: () => plan });

  try {
    await planProgressService.markManualComplete({
      userId: plan.userId.toString(),
      taskId,
      selfRating: 3,
    });
    assert.strictEqual(inserted.length, 0, 'manual tasks should not produce ExternalContentTouch rows');
  } finally {
    Plan.findOne = origFindOne;
    ExternalContentTouch.create = origCreate;
  }
});
```

- [ ] **Step 2: Run to verify failure**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/planProgressService.test.js
```

Expected: the external_link test fails (no insert happens).

- [ ] **Step 3: Patch `markManualComplete`**

In `src/services/plan/planProgressService.js`, find the existing `markManualComplete` function. After the existing `KnowledgeProfile.updateOne(...)` block (still inside the `applyFn` lambda, BEFORE the `return { matched: true, ... }`), add:

```javascript
      // For external_link tasks, also append a row to ExternalContentTouch
      // so future recalibrations know the user touched this URL.
      if (foundTask.type === 'external_link') {
        try {
          const ExternalContentTouch = require('../../models/ExternalContentTouch');
          await ExternalContentTouch.create({
            userId,
            taskId: foundTask._id,
            url: foundTask.payload?.url || '',
            title: foundTask.payload?.title || '',
            source: foundTask.payload?.source || '',
            topicCanonicalName: foundTask.topic.canonicalName,
            selfRating: rating,
            completedAt: foundTask.progress.completedAt,
          });
        } catch (err) {
          console.warn('[planProgressService] ExternalContentTouch.create failed:', err.message);
        }
      }
```

- [ ] **Step 4: Run tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/planProgressService.test.js
```

Expected: ALL pass (existing 18 + 2 new = 20).

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/plan/
git commit -m "feat(plan): markManualComplete writes ExternalContentTouch for external_link tasks"
```

---

## Task 6: iOS — external_link tap opens URL + presents completion sheet

**Files:**
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift`

When the user taps an `external_link` task, open the URL via `UIApplication.shared.open(_:)` (iOS handles routing to Safari/installed apps). Immediately AFTER opening, present the existing `ManualCompletionSheet` so the user can self-rate when they return.

The current `handleTaskTap` for `.externalLink` falls into the same branch as `.manual` (both open the completion sheet). We need to ALSO open the URL externally for `.externalLink` BEFORE setting `presentedManualTask`.

- [ ] **Step 1: Read the current handleTaskTap**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
grep -n "case .externalLink\|case .manual\|presentedManualTask" ScaleUp/Features/Plan/Views/PlanTabView.swift | head -10
```

The current code likely groups `.manual, .externalLink` in a single case that just sets `presentedManualTask = task`.

- [ ] **Step 2: Split the cases and add URL open**

Find:
```swift
        case .manual, .externalLink:
            presentedManualTask = task
```

Replace with:
```swift
        case .externalLink:
            // Open the URL externally first so the user can read the resource,
            // then present the completion sheet immediately so they can
            // self-rate when they tap back into the app.
            if let urlString = task.payload?["url"]?.value as? String,
               let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
            presentedManualTask = task
        case .manual:
            presentedManualTask = task
```

If `UIApplication` isn't already imported (it usually is via SwiftUI's umbrella), add `import UIKit` at the top of the file.

- [ ] **Step 3: Parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse \
  ScaleUp/Features/Plan/Views/PlanTabView.swift 2>&1 | tail -10
```

Expected: silent.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/Views/PlanTabView.swift
git commit -m "feat(ios-plan): external_link tap opens URL and presents completion sheet"
```

---

## Task 7: Android — external_link tap opens URL + presents completion sheet

**Files:**
- Modify: `src/screens/plan/PlanTabScreen.tsx`

Same pattern: split the `'manual' | 'external_link'` case so external_link first calls `Linking.openURL(...)` then sets the completion task.

- [ ] **Step 1: Read the current handleTaskTap**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
grep -n "external_link\|case 'manual'\|setCompletionTask" src/screens/plan/PlanTabScreen.tsx | head -10
```

- [ ] **Step 2: Split the cases**

Find:
```typescript
case 'manual':
case 'external_link':
  setCompletionTask(task)
  break
```

Replace with:
```typescript
case 'external_link': {
  const url = (task.payload as any)?.url
  if (typeof url === 'string') {
    Linking.openURL(url).catch(() => {
      Alert.alert("Couldn't open link", 'Please try again or open the URL manually.')
    })
  }
  setCompletionTask(task)
  break
}
case 'manual':
  setCompletionTask(task)
  break
```

Add `Linking` to the `react-native` imports if not already imported:
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && grep -n "^import.*react-native\|Linking" src/screens/plan/PlanTabScreen.tsx | head -5
```

If `Linking` is missing from the import, add it. `Alert` should already be there from earlier phases.

- [ ] **Step 3: TypeScript check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npx tsc --noEmit 2>&1 | grep -E "src/screens/plan" | head -10
```

Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git add src/screens/plan/PlanTabScreen.tsx
git commit -m "feat(android-plan): external_link tap opens URL and presents completion sheet"
```

---

## Task 8: Phase 4 acceptance — full sweep

- [ ] **Step 1: Backend tests**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/ src/services/diagnostic/planGenerationService.test.js src/models/ExternalContentTouch.test.js src/controllers/planController.test.js 2>&1 | tail -10
```

Expected: every test passes.

- [ ] **Step 2: Full backend npm test**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm test 2>&1 | tail -10
```

Expected: pre-existing `diagnostic-e2e-upskilling.test.js` timeout is the only failure.

- [ ] **Step 3: OpenAPI lint** (no new endpoints — should be clean from Phase 3)

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && npm run openapi:lint 2>&1 | tail -5
```

Expected: 0 errors.

- [ ] **Step 4: iOS parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && find ScaleUp/Features/Plan -name "*.swift" -print0 | xargs -0 xcrun swiftc -parse 2>&1 | tail -10
```

Expected: silent.

- [ ] **Step 5: Android typecheck**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npx tsc --noEmit 2>&1 | grep -E "src/screens/plan|src/services/plan|src/models/competition" | head -10
```

Expected: 0 errors in Plan-related files.

- [ ] **Step 6: No commit needed.** Acceptance only.

---

## What Phase 4 ships

After this plan executes:
- The plan generator (when `FEATURE_EXTERNAL_CONTENT_JUDGE=true`) calls an LLM-as-judge per topic per week to decide if the in-app coverage needs supplementing.
- The judge returns 0-3 external links from a curated whitelist; non-whitelisted URLs are dropped server-side.
- Plans persist `external_link` tasks alongside the other 5 task types from Phase 3.
- Tapping an `external_link` task on iOS or Android opens the URL externally AND immediately surfaces the completion sheet so the user can self-rate when they return.
- Each completed external_link writes an `ExternalContentTouch` row capturing `{ userId, taskId, url, title, source, topicCanonicalName, selfRating, completedAt }`.

**What Phase 4 does NOT ship:**
- The judge is feature-flagged OFF by default. Production rollout requires setting `FEATURE_EXTERNAL_CONTENT_JUDGE=true` in env after observing latency/cost in staging.
- No retroactive judge run for plans created before Phase 4. The backfill script from Phase 2 stays as-is; if you want existing plans to gain external_link tasks, run the backfill again with the flag on.
- No analytics on which external links convert (clicks vs completions). That's a Phase 5+ improvement.
- No web client (still iOS + Android only).

Phase 5 is next: journey timeline horizontal week strip, milestone footer redesign, micro-interactions, and Mixpanel instrumentation per spec §7 phase 5.

---

## Self-review checklist

- ✅ Spec coverage: §5 LLM-as-judge (whitelist, capture-on-completion, variable count) + §7 phase 4 deliverables (whitelist config, judge service, ExternalContentTouch, browser open) all map to tasks.
- ✅ Placeholder scan: clean.
- ✅ Type consistency: `payload.url`/`title`/`source`/`why`/`estimatedMinutes` consistent across generator → API → iOS → Android. `selfRating` consistent (1-5). `topicCanonicalName` flows from task → ExternalContentTouch.
- ✅ Phase 1+2+3 dependencies: `planProgressService.markManualComplete`, `withVersionRetry`, `taskCatalogService`, `canonicalize`, generator post-processor — all in place.
- ✅ Feature flag protects rollout: `FEATURE_EXTERNAL_CONTENT_JUDGE=true` required.
