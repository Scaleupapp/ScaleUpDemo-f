# Day-1 Diagnostic — Foundational Redesign Spec

**Status:** Draft for review
**Date:** 2026-05-03
**Owner:** Nirpeksh
**Replaces:** Existing Day-1 Diagnostic implementation (Build 109)

---

## 1. Why we're rebuilding

The current Day-1 Diagnostic shipped, but it has foundational issues that polish can't fix:

- **Generic, not personalized.** Topics suggested in onboarding are static rule-based lists. A PM aspirant and a marketing analyst get topics that aren't actually assessable or differentiated.
- **Results are useless.** "Novice 25/100" tells the user nothing they can act on. There's no calibration, no pattern, no "here's what this means for your plan."
- **Diagnostic length and reliability problems.** Question 31 of 30. Spinners that never resolve. Cascading bugs from canonical-name mismatches.
- **Plan integration is invisible.** The user finishes the diagnostic and lands somewhere generic. The diagnostic doesn't visibly shape Home, Plan, or Progress.

**The product thesis:** A user who joins ScaleUp should, within 5-9 minutes of finishing onboarding, get a calibrated read on where they actually stand — measured against where they think they stand — and have the entire platform (Home, Plan, Progress, Content) personalized to that read. Without this, two users with identical objectives but different starting levels get the same generic plan. That's the bug.

**Marketing positioning:** *"Get your real proficiency, your gaps, and your personalized plan within 9 minutes of signup."*

---

## 2. Goals & Non-goals

### Goals (v1)

- Onboarding-to-personalized-platform in under 12 minutes total (onboarding + diagnostic).
- Diagnostic shape that varies meaningfully across the 5 diagnostic-bearing objective types.
- Results screen that delivers structured, interactive, wow-worthy insights — not just scores.
- Plan generation that respects timeline + hours/week + diagnostic gaps + (optional) milestones.
- Voice answers as a first-class input where naturally applicable (interview behavioral, leadership scenarios).
- Topic taxonomy that adapts daily to what real users enter.
- Company-specific customization for the top 30-40 named companies.
- AI literacy injection as future-proofing in applicable objective types.
- **Existing-user migration path** — users who joined before this rebuild get a frictionless on-ramp into the diagnostic.
- **Re-calibration after 30 days** — short, focused re-test of topics the user has worked on, with growth visualization and plan auto-rebalance.
- **Syllabus / chapter PDF upload** for academic_excellence (default path) and exam_preparation (university / professional cert exams) — leveraging existing notes PDF extraction infrastructure.
- **India-centric seeding** for skills, exams, companies, career paths, and academic boards — researched for 2026 and beyond.
- **Two-tier question quality validation** — automated validator + lightweight admin review dashboard.
- **Interactive, hooked UX** with micro-interactions, animations, voice-aware feedback, and Mixpanel instrumentation.

### Non-goals (deferred to v1.1+)

- Cohort comparison ("you vs other PMs at your level"). *Deferred — interesting, but builds on v1 calibration data.*
- Voice expansion beyond designated scenarios (interview behavioral, leadership scenarios in upskilling/career_switch).
- Web platform support.
- Diagnostic-driven content recommendations beyond topic-level personalization. *(Today: content suggested by topic. Beyond: content suggested by specific concept missed within a topic — requires concept-level question tagging.)*
- Community / power-user question review system.
- Custom diagnostic creation by users.

---

## 3. Onboarding changes

**Steps 1-4 and 6 are unchanged.** Only Step 5 (Interests) is reworked, and the backend gains a normalization pass on Step 3 specifics.

### 3.1 Step 5 (Interests) — reworked

Today: rule-based static topic chips with min 3, no max, free-text custom add.

New behavior:

1. **Topic suggestions come from the daily-refreshed taxonomy.** Lookup key: `(objectiveType × canonicalSpecifics × optionalCompany)`.
2. **6-8 topics shown, all pre-selected.** User can tap to remove or tap `[+ Add a topic]` to add custom (cap total at 8).
3. **Each topic shows a 1-line description on tap-info.** So the user knows what "Stakeholder Management" means before keeping or removing it.
4. **AI literacy topic is included** for applicable objective types (see §7), marked with a `✦ Future-proofing` badge.
5. **After topic selection is finalized, a self-rating sub-step appears in the same step** (no new entry in the progress bar — still "Step 5 of 6"). For each chosen topic, user picks one of 4 chips: **Novice / Familiar / Proficient / Expert**, with one-line anchored examples on tap.
6. **Validation:** min 3 topics, max 8 topics. All topics must have a self-rating before proceeding.

### 3.2 Step 3 (Objective) — backend normalization, no UI change

Today: free-text fields for examName, targetSkill, targetRole, targetCompany, fromDomain, toDomain.

New behavior: **frontend unchanged.** On submission, the backend runs a lightweight LLM normalization pass:

- Input: `"Prod Mgmt"` → canonical `"Product Management"`
- Input: `"GMAT exam"` → canonical `"GMAT"`
- Input: `"Vedic Math"` → canonical `"Vedic Mathematics"`

Normalized values are stored in a new `specificsCanonical` field. Original `specifics` field is preserved for display. Canonical values become cache keys for the taxonomy lookup.

**Failure mode:** If normalization fails or times out (3s budget), fall back to using the raw input as canonical. Worst case is a slightly worse taxonomy match.

### 3.3 What does NOT change

- Number of onboarding steps stays at 6.
- Steps 1, 2, 4, 6: untouched.
- Step 3 UI: untouched.
- The 7 objective types: all preserved.
- `currentLevel` (beginner/intermediate/advanced) at the objective level: still captured. It's a different signal from per-topic self-rating — overall confidence vs topic-specific.
- `topicsOfInterest` field: still used; just populated from taxonomy now instead of static rules.

### 3.4 Existing-user migration path

Users who completed onboarding before this rebuild have `topicsOfInterest` but no `topicSelfRatings`. They get a calibration on-ramp:

- **Backend migration:** every existing `UserObjective` without `topicSelfRatings` gets `needsCalibration: true` flag.
- **Home banner** (replaces the existing tune-up banner): *"Get your real proficiency in 9 minutes — your plan will adapt to it."* Tap CTA: "Start calibration."
- **On tap, skip to a compressed Step 5** — pre-populated with their existing `topicsOfInterest`, asks them to confirm/edit + add self-rating per topic. Then drops into the diagnostic.
- **No re-doing Steps 1-4 or 6** — that data is already captured.
- **Banner persistence:** stays until completed OR explicitly dismissed. Dismissal triggers a 14-day quiet period; max 3 prompts then auto-stop (no nag).
- **Plan refresh** runs automatically on completion.

### 3.5 Re-calibration (rolling, every 30 days)

After 30 days from last completed diagnostic, the user gets a "Re-calibrate" surface — never blocking, never on Home (the Home banner is reserved for the first-time calibration).

- **Surface location:** card on the Progress tab + a one-time gentle nudge in the Plan tab on day 30.
- **What gets re-tested** (much shorter than the first diagnostic, ~4-5 min, 8-12 questions):
  - Topics where the user has spent ≥5 plan hours since last diagnostic
  - Topics the user explicitly self-flags ("I've grown here, retest me")
  - Topics with the largest original calibration gap (re-validate progress on weaknesses)
- **Results screen for re-calibration** has a different shape from first-time:
  - **Growth bars per topic:** old measured score vs new measured score, with delta
  - **Hero callout:** biggest growth area — *"Your Stakeholder Mgmt jumped from Novice to Familiar in 4 weeks. That's the fastest growth we've seen on this topic for someone with your hours/week."*
  - **New gaps surfaced** if any (topics that drifted)
  - **Plan auto-rebalances:** hours shift away from topics that grew, toward new gaps or unfinished work. User sees the rebalance with a before/after view.
- **Optional nudges:** day 30, day 45, day 60. After 60, falls quiet until the user opens Progress tab.
- **Re-calibration history** is preserved in `DiagnosticAttempt` documents (each attempt gets `attemptType: 'initial' | 'recalibration'` and `previousAttemptId`).

### 3.6 Syllabus / document upload (academic_excellence default, exam_prep optional)

For academic_excellence and certain exam_prep cases (university semester exams, professional certifications), the system-generated topic taxonomy may not match what the user is actually studying. They get an upload path:

- **academic_excellence flow:** Step 5 leads with an upload card — *"Upload your chapter, syllabus, or notes for the most accurate diagnostic. We'll generate questions from your actual content."* Two CTAs: "Upload" / "Skip — use standard topics for [board × grade]."
- **exam_prep flow:** Same upload card, surfaced only for non-standardized exams (university sem, certifications). Standardized exams (GMAT, JEE, NEET, UPSC) skip this — those have stable curricula.
- **Accepted formats:** PDF, image (JPG/PNG/HEIC), PPTX/PPT. Up to 4 GB.
- **Backend pipeline** reuses existing notes infrastructure (`uploadService.js`, `ocrProcessor.js`, BullMQ queue):
  1. User uploads → S3 → `DiagnosticSyllabus` model created with `extractionStatus: 'pending'`.
  2. Worker picks up via existing OCR queue (`pdf-parse` for text PDFs, GPT-4o Vision for scanned/handwritten/PPT — already proven).
  3. Extracted text stored in `DiagnosticSyllabus.extractedText`.
  4. LLM (json_schema strict) generates topic list from the extracted content (typically 6-12 sub-topics per uploaded chapter).
  5. LLM generates questions for those sub-topics, using the source text as context for high-fidelity question generation.
  6. User proceeds to self-rating once topics are extracted (~30-90s wait, with progress UI).
- **Caching:** content hash deduplication. If two students upload the same NCERT Class 12 Mechanics chapter PDF, the second user reuses the first user's extraction + topic generation + question batch. Massive cost saving for popular textbooks.
- **Failure mode:** If extraction yields <100 chars (corrupted PDF, blurry image), gracefully fall back to standard taxonomy + apologetic toast.
- **Cost estimate:** Text PDFs free (pdf-parse), scanned ~$0.01-0.03/page (Vision), question generation ~$0.005/question. Realistic per-upload cost: $0.10-0.50 for first user, near-zero for cache hits.

---

## 4. Backend data model changes

### 4.1 UserObjective (modified)

Add two fields:

```js
topicSelfRatings: {
  type: Map,
  of: { type: String, enum: ['novice', 'familiar', 'proficient', 'expert'] },
  default: () => new Map(),
}

specificsCanonical: {
  examName: String,
  targetSkill: String,
  targetRole: String,
  targetCompany: String,
  fromDomain: String,
  toDomain: String,
}
```

`topicsOfInterest` and `specifics` stay as-is.

### 4.2 TopicTaxonomy (new model)

```js
{
  _id: ObjectId,
  objectiveType: String,            // 'upskilling' | 'interview_preparation' | ...
  targetKey: String,                // canonical hash: e.g. 'upskilling::product-management'
  topics: [{
    name: String,                   // 'Product Strategy'
    canonicalName: String,          // 'product-strategy'
    description: String,            // one-liner shown in UI
    baseDifficulty: String,         // 'foundational' | 'intermediate' | 'advanced'
    isFutureProofing: Boolean,      // true for AI literacy topics
    sortOrder: Number,
  }],
  source: String,                   // 'curated' | 'llm-generated'
  lastRefreshedAt: Date,
  refreshCount: Number,
  userEditSignal: {                 // tracked for daily refresh decisions
    timesRemoved: { type: Map, of: Number },
    timesAdded: { type: Map, of: Number },
  },
}
```

Indexed on `(objectiveType, targetKey)` unique.

### 4.3 CompanyProfile (new model)

```js
{
  _id: ObjectId,
  name: String,                     // display name: 'Google'
  normalizedName: String,           // 'google' (lookup key)
  industry: String,                 // 'Big Tech' | 'Consulting' | ...
  applicableObjectives: [String],   // ['interview_preparation', 'upskilling']
  signatureInterviewElements: [String], // free-form: ['Googleyness', 'System design depth']
  topicWeightOverrides: {
    type: Map,
    of: Number,                     // 0.5 = de-emphasize, 1.5 = emphasize, 1.0 = neutral
  },
  examplesContext: String,          // injected into question generation prompts
  source: String,                   // 'curated' | 'llm-generated'
  lastRefreshedAt: Date,
}
```

Indexed on `normalizedName` unique.

### 4.4 DiagnosticAttempt (existing, with cleanups)

Keep existing structure. Cleanups required during this rebuild:

- Standardize `selfRatings` as a Map of `canonicalTopicName → ProficiencyLevel`.
- Standardize `answers` array with consistent shape: `{ questionId, topicCanonicalName, answer, correct, difficulty, timeMs, answeredAt }`.
- Standardize `results` as a Map of `canonicalTopicName → { measuredScore, band, calibrationDelta, questionsAsked, answerPattern }`.
- Add `insightsJson` field to store generated insights for fast retrieval.
- Add `planGenerationStatus` enum: `pending | generating | ready | failed`.

### 4.5 DiagnosticQuestionBank (existing, expanded with validation fields)

Schema additions:

```js
verificationStatus: {
  type: String,
  enum: ['pending', 'auto_verified', 'human_verified', 'flagged_for_review', 'rejected'],
  default: 'pending',
}

validatorScore: Number,           // 0-100 from automated Tier 1 validator
validatorCritique: String,        // LLM critique output (used in admin dashboard)
humanReviewedBy: ObjectId,        // ref User (admin who approved/rejected)
humanReviewedAt: Date,
humanReviewNotes: String,
generationSource: {
  type: String,
  enum: ['curated', 'seed_batch', 'llm_realtime', 'syllabus_derived'],
}
sourceContext: ObjectId,          // ref DiagnosticSyllabus if syllabus_derived
```

**Coverage targets:**
- v1 launch: **15,000-18,000 MCQ questions + ~450 voice scenario prompts**
- 90-day target: 20,000-25,000 (via daily refresh + real-time generation closing the gap)
- Math: ~1,400 topics × 3 difficulties × ~4 questions per (topic × difficulty) = ~16,800 baseline

**Generation strategy:**
- Pre-launch Phase 0.5: dedicated batch generation using existing parallel pattern (4 questions per LLM call, 6 calls in parallel = ~24 questions/min). Throughput: 18k questions in ~12-15 hours of compute, run over 2-3 days.
- One-time seed cost estimate: ~$90 (gpt-4o-mini, json_schema strict).
- All seed-batch questions enter as `verificationStatus: 'pending'` and pass through Tier 1 validation immediately.

### 4.6 DiagnosticSyllabus (new model)

```js
{
  _id: ObjectId,
  userId: ObjectId,                 // ref User (uploader)
  userObjectiveId: ObjectId,        // ref UserObjective
  s3Key: String,                    // raw file location
  contentType: String,              // mime type
  fileSizeBytes: Number,
  contentHash: String,              // sha256 for dedup cache lookup
  extractionStatus: {
    type: String,
    enum: ['pending', 'processing', 'completed', 'failed'],
    default: 'pending',
  },
  extractedText: String,            // full text content
  pageCount: Number,
  extractedTopics: [{               // LLM-derived from extractedText
    canonicalName: String,
    displayName: String,
    description: String,
  }],
  derivedQuestionIds: [ObjectId],   // ref DiagnosticQuestionBank
  reusedFromHash: String,           // if this is a cache hit, points at original
  failureReason: String,
  createdAt: Date,
  completedAt: Date,
}
```

Indexed on `(userId, createdAt)` and `contentHash` (unique).

### 4.7 QuestionReviewQueue (new — view layer for admin dashboard)

Not a Mongoose model — a view query backed by `DiagnosticQuestionBank` with `verificationStatus = 'flagged_for_review'`. Surfaced via admin API endpoint (§12.5).

---

## 5. The diagnostic engine

### 5.1 Question selection algorithm (Path C, refined)

Inputs: list of 3-8 chosen topics with their self-ratings + objective type + (optional) company profile.

For each topic, select questions based on self-rating:

| Self-rating | # questions | Difficulty mix |
|---|---|---|
| Novice | 2 | 2 easy |
| Familiar | 3 | 1 easy, 1 medium, 1 hard |
| Proficient | 3 | 1 medium, 2 hard |
| Expert | 3 | 1 hard, 2 hard-with-scenario |

**Total range:** 6-24 questions (3 topics all-Novice → 8 topics all-Expert), realistically 14-21.
**Time budget:** ~7-9 min total. MCQ ≈ 25s, scenario MCQ ≈ 40s, voice ≈ 60s.

If company profile present, apply `topicWeightOverrides`:
- Weight ≥ 1.5: bump self-rated band by one for question selection (e.g., Familiar → Proficient question mix).
- Weight ≤ 0.5: drop one question from the topic's allocation (minimum 1).
- Other weights: no change.

### 5.2 Per-objective-type variations

| Objective type | Question types | Voice? | Timer per Q | Notes |
|---|---|---|---|---|
| upskilling | MCQ + scenario MCQ | Yes for stakeholder/leadership topics | None | Mixed pace |
| interview_preparation | MCQ + scenario MCQ + voice | Yes for behavioral | None for MCQ, soft for voice | Tier-aware difficulty via company profile |
| exam_preparation | MCQ only | No | **Strict per-question timer** mimicking exam | No scenario, no voice — exam itself is written |
| career_switch | MCQ + scenario MCQ | Yes for leverage topics if leadership-relevant | None | Topics flagged "leverage" vs "build" |
| academic_excellence | MCQ + short application | No | None below college; soft for college+ | School/college appropriate framing |
| casual_learning | **No diagnostic** | — | — | Affinity card stack instead (§9.6) |
| networking | **No diagnostic** | — | — | Intent + style picker instead (§9.7) |

### 5.3 Question source

1. **Pre-seeded `DiagnosticQuestionBank`** for known (objective × target × topic × difficulty) combinations.
2. **LLM-generated on-demand** for new combinations, with caching into the bank for future use.
3. **Daily refresh** scans new user objectives and proactively generates question batches for new combinations using the same per-competency json_schema strict generation pattern that's already proven (4-question batches in parallel groups of 6).

### 5.4 Voice answer handling

Voice questions present as a scenario prompt. User taps mic, records 30-60s answer, transcription happens via existing Whisper pipeline (already proven on Android), scoring via GPT-4o with a structured rubric:

- Structure (STAR/CARL adherence where applicable)
- Specificity (concrete examples vs abstract)
- Relevance (addresses the prompt)
- Articulation (clarity, flow)

Scored 0-100, mapped to band like MCQ scoring. Voice failures (transcription error, no audio) gracefully fall back to a typed answer field. Live waveform feedback during recording.

### 5.5 Two-tier question quality validation

Real-time and seed-generated questions cannot be trusted blindly. Every question entering the bank goes through a validation pipeline.

#### Tier 1 — Automated validator (no human in loop)

Runs within 24h of question creation (immediately for batch-seed questions; queued for LLM-realtime questions). Uses a stricter LLM prompt (different from generation prompt) to critique:

- **Correctness:** Is the marked answer actually correct? Are other options unambiguously wrong?
- **Difficulty calibration:** Does the stated difficulty match the actual difficulty? (E.g., "easy" question marked but actually requires advanced reasoning.)
- **Language quality:** Grammar, clarity, no double negatives, no leading wording.
- **Single-correct-answer guarantee:** No two options that could both be defensible.
- **No ambiguous wording:** Question stem unambiguous, scenario complete enough to answer.
- **No offensive / culturally insensitive content.**
- **India-context appropriateness:** Examples and references make sense for Indian learners (where applicable).

Validator outputs a `validatorScore` (0-100) and a `validatorCritique` (1-3 sentence explanation).

| Validator score | Action |
|---|---|
| ≥ 90 | Auto-promote to `auto_verified`. Available in rotation. |
| 70-89 | Keep in rotation as `pending`. Re-validate in 7 days (LLM models improve; may pass next time). |
| < 70 | **Remove from rotation immediately.** Set `verificationStatus: 'flagged_for_review'`. Surface in admin queue. |

#### Tier 2 — Admin review (you, weekly)

Lightweight admin dashboard at `/admin/diagnostic-questions` (gated by `User.isAdmin = true`). Initially: only Nirpeksh.

**Per-question view shows:**
- Question text + options + marked correct answer
- `validatorScore` + `validatorCritique`
- Generation source + topic + difficulty + objective type
- (If applicable) sample user answers from before flagging

**Three actions per question:**
- **Approve** — force-promote to `human_verified` despite low validator score (your judgment overrides).
- **Edit** — inline edit the question/options/correct answer, then approve.
- **Reject** — delete from bank + log reason. Optionally trigger regeneration of a replacement question for that (topic × difficulty) slot.

**Weekly digest email** (Monday morning) to admin: *"5 questions need your review. ~12 minutes."* Direct link to dashboard.

**Training signal loop:** every approve/reject decision is logged. After 100+ decisions, those become few-shot examples in the Tier 1 validator prompt — making the automated tier smarter over time and reducing the human queue.

#### Edge case — user encounters a flagged question

If a user hits a question between generation and validation completion (24h window):
- The answer is recorded but tagged `questionWasLowConfidence: true`.
- For diagnostic results: low-confidence questions are excluded from band calculation if there are at least 2 other answers in that topic. Otherwise kept with a footnote in insights.
- If the question is later rejected, affected users' attempt records are flagged for optional silent rescore (rare, only if it would change a band).

#### Scaling beyond v1

- Phase 1 (now → 1k users): Nirpeksh only, ~10-15 min/week.
- Phase 2 (1k-10k users): hire 1 part-time QA contractor, ~3-4 hrs/week.
- Phase 3 (10k+): community reviewer system (deferred to v2).

---

## 6. Topic taxonomy

### 6.0 Phase 0 — Research deliverable (pre-implementation)

Before any seeding scripts run, produce a comprehensive research document covering India-centric demand for 2026 and beyond. Deliverable scope:

- **Top 30 high-demand skills in India 2026** — sourced from NASSCOM Future of Work, LinkedIn India Workforce Report, Naukri Insights, McKinsey India, WEF Future of Jobs (India cut). AI/ML, Cloud, Cybersecurity, Data Engineering, Product Mgmt, UX/UI, Digital Marketing, Sales Enablement, Financial Analysis, etc.
- **Top 50 exams Indians prepare for in 2026** — UPSC (CSE, ESE, CDS, NDA), JEE (Main, Adv), NEET (UG, PG), GATE, CAT, XAT, CMAT, GMAT, GRE, Bank PO/Clerk (IBPS PO, SBI PO, RBI Grade B), SSC CGL/CHSL, RRB NTPC, State PSCs (UPPSC, MPPSC, MPSC, TNPSC, KPSC), CA (Foundation/Inter/Final), CS, CMA, CFA L1/L2/L3, FRM, ACCA, IELTS, TOEFL, PTE, defense (NDA, CDS, AFCAT, INET), and emerging exams (CUET).
- **Top 50 companies actively hiring in India 2026** — Big Tech India (Google, Microsoft, Amazon, Meta, Apple India), Indian unicorns (Flipkart, Zomato, Razorpay, CRED, PhonePe, Paytm, Meesho, Postman, Freshworks, Zerodha, Nykaa, Lenskart, Dream11, Swiggy, Ola, upGrad, BharatPe, Pine Labs, Groww, Cars24, Mamaearth, etc.), top consulting (McKinsey India, BCG India, Bain India, Deloitte, Accenture, TCS Consulting, Infosys Consulting), top finance (Goldman India, JPM India, Morgan Stanley India, BlackRock India, HDFC, ICICI, Kotak), AI-native firms with India presence (OpenAI, Anthropic, Sarvam, Krutrim, Gnani).
- **Top 25 career transition patterns in India 2026** — IT services → product, engineering → MBA, finance → tech, government → corporate, teaching → corporate L&D, traditional roles → AI-augmented roles, etc.
- **AI literacy skills per domain** — 2-3 specific skills/tools per knowledge-work domain.
- **Indian academic boards + grade subject lists** — CBSE, ICSE, IB, plus major state boards (Maharashtra, Tamil Nadu, Karnataka, Uttar Pradesh, Andhra Pradesh, Telangana, Rajasthan, West Bengal, Gujarat, Kerala) for Grades 9-12.
- **Indian undergrad / professional curricula** — common subjects per stream (CS, EE, Mech, Civil, Commerce, BBA, Arts, Medical, Law).

Deliverable format: a structured markdown document (~3,000-5,000 words) saved to `docs/superpowers/research/2026-05-XX-india-seeding-research.md`, with citations and source links where available.

**Owner:** Claude (general-purpose / web research). ~1-2 days of focused work. Output reviewed by Nirpeksh before seeding scripts run.

### 6.1 Seed strategy (v1 hand-curated, informed by Phase 0 research)

Seed before launch. **Not based on existing test user data.** Built from first principles for likely real-world entries, India-centric, validated against Phase 0 research.

| Objective type | Seed coverage | Approx topic count |
|---|---|---|
| upskilling | 12 target domains × ~7 topics | ~84 |
| interview_preparation | 12 targets × 4 company tiers × ~7 topics | ~330 |
| exam_preparation | ~25 exams × 4-6 sub-topics | ~125 |
| career_switch | ~25 from→to matrices × ~7 topics | ~175 |
| academic_excellence | ~40 board×grade×subject profiles × ~8 sub-topics | ~320 |
| casual_learning | 12 curiosity domains × ~5 sub-areas | ~60 |
| networking | 5 intent profiles × ~4 sub-areas | ~20 |
| **Company-specific overrides** | 40 companies × ~7 topics | ~280 |
| **Total seed taxonomy** | | **~1,400 entries** |

Each topic in the seed has: name, description, baseDifficulty, sortOrder, isFutureProofing flag, applicableObjectives.

Seeded via a `seedTopicTaxonomy.js` script (similar to existing `seedDiagnosticBank.js`), informed by Phase 0 research.

**Question bank seeding** runs in Phase 0.5 immediately after taxonomy seed:
- Target: ~16,800 MCQ + ~450 voice scenario prompts at v1 launch.
- ~$90 one-time generation cost (gpt-4o-mini, json_schema strict).
- All seed-batch questions enter `verificationStatus: 'pending'` and pass through Tier 1 validator.

### 6.2 Daily refresh

Cron at 03:00 IST (`refreshTopicTaxonomy.js`):

1. Scan `UserObjective` documents created in last 24h.
2. For new `(objectiveType, targetKey)` combinations not yet in taxonomy: queue LLM generation (json_schema strict, 12s timeout per call).
3. For existing combinations with significant user-edit signal (>20% of users in last 7 days removed a topic, OR >20% added a custom topic with same canonical name): regenerate that combination.
4. For company profiles: regenerate top 50 by submission volume monthly (separate cron).
5. All LLM-generated entries marked `source: 'llm-generated'`. Manual override possible.

### 6.3 LLM generation contract

Strict json_schema response format. Inputs:
- objectiveType
- specificsCanonical
- (optional) companyName + industry context

Output:
```json
{
  "topics": [
    {
      "name": "Product Strategy",
      "description": "Defining product vision, prioritizing initiatives, making bet vs. play decisions",
      "baseDifficulty": "intermediate",
      "isFutureProofing": false,
      "sortOrder": 1
    },
    ...
  ]
}
```

Always 6-8 topics. AI literacy topic auto-injected via prompt instruction for applicable objective types.

### 6.4 India-centric framing in all LLM prompts

Both topic generation and question generation prompts include explicit India-context instructions:

- **Topic generation:** *"Prioritize topics relevant to the Indian market. Use Indian company examples where relevant (e.g., Flipkart, Razorpay, Zomato — not just Amazon, Stripe). Salary/scale references in INR. For exam prep and academic, default to Indian curricula."*
- **Question generation:** *"Use India-context scenarios where natural. Examples: 'You're a PM at Razorpay tasked with...', 'Your team at TCS is debating...', 'A Bengaluru-based startup wants...'. For exam prep questions, mirror Indian exam style and difficulty. Avoid US-centric salary figures, US-only product references, or US legal/regulatory contexts unless the user's target is explicitly US-based.'*
- **Insight generation:** Same — frame insights in India-relevant career context where applicable.

International coverage is preserved (the user might target a US/EU company), but the **default** lens is Indian.

### 6.5 Real-world question quality (anchor-question pattern)

To prevent textbook-rote questions:

- During Phase 0.5 seeding, **2-3 hand-written anchor questions per topic** are committed to the bank manually. These are gold-standard examples of the difficulty + style we want.
- LLM generation prompts use these anchor questions as **few-shot examples**: *"Generate 4 questions in the style and difficulty of these examples: [anchor 1] [anchor 2] [anchor 3]"*.
- Tier 1 validator checks for textbook-style language and flags questions that read like definitions or pure recall.
- Anchor questions per topic stored in a `QuestionAnchor` collection (or as a flag `isAnchor: true` on `DiagnosticQuestionBank`).
- ~1,400 topics × 2-3 anchors = ~3,500-4,200 hand-written anchor questions. **This is significant manual work** — Phase 0 research includes recruiting domain anchors (potentially via Fiverr/Upwork India for ~$2/question = ~$8k budget, OR LLM-generated then heavily reviewed in Tier 2 batch).
- Decision: hybrid — LLM-generate anchors with strict review, then promote good ones. Pure manual is too expensive for v1.

---

## 7. AI literacy injection

### 7.1 Where it applies

| Objective × target | AI topic injected |
|---|---|
| upskilling × PM | "AI Product Strategy & Building with LLMs" |
| upskilling × SWE | "AI-Augmented Engineering" (Copilot, Cursor, prompt patterns, building with LLMs) |
| upskilling × Marketing | "AI for Marketers" (content, SEO, analytics with AI) |
| upskilling × Data Science | "LLM-Augmented Analytics" (semantic queries, code gen, summarization) |
| upskilling × Design | "AI in the Design Workflow" (Figma AI, Midjourney, AI handoffs) |
| upskilling × Sales | "AI for Sales Workflows" (outreach, qualification, summaries) |
| upskilling × HR/Ops/Finance | "AI for [Domain]" (automation, drafting, analysis) |
| interview_preparation × PM | "Building with AI" |
| interview_preparation × SWE | "AI-Assisted Development" |
| career_switch × any tech-target | AI literacy as a "build" topic |

### 7.2 Where it does NOT apply

- exam_preparation (irrelevant to standardized exam content)
- academic_excellence (especially below undergrad)
- casual_learning (user-driven content)
- networking (different shape entirely)

### 7.3 UI treatment

Topic shows with `✦ Future-proofing` badge. Tooltip: *"Roles in your target field increasingly expect AI fluency. We've included this so your plan keeps you ahead."* Removable like any other topic — no guilt-trip.

### 7.4 Plan integration

Beyond the topic itself, **content for every other topic gradually layers in AI tooling guidance.** Example: Roadmapping plan content includes "Using LLMs to draft and stress-test your roadmap." Stakeholder Mgmt includes "AI for meeting prep and stakeholder summaries." This is content-level, not topic-level — doesn't affect the diagnostic.

---

## 8. Company profile system

### 8.1 v1 hand-curated coverage (~30-40 profiles)

**Big Tech:** Google, Meta, Amazon, Apple, Microsoft, Netflix, OpenAI, Anthropic, NVIDIA
**Top startups:** Stripe, Uber, Airbnb, ByteDance/TikTok, Spotify, Pinterest, Discord, Notion, Figma, Linear
**Indian unicorns:** Flipkart, Zomato, Swiggy, Razorpay, CRED, PhonePe, Paytm, Meesho, Postman, Freshworks
**Consulting:** McKinsey, BCG, Bain, Deloitte, Accenture
**Finance:** Goldman Sachs, JPMorgan, Morgan Stanley, BlackRock, Citadel

Each profile contributes:
- `topicWeightOverrides` per applicable (objective × target).
- `signatureInterviewElements` (e.g., Amazon "Leadership Principles drive 50%+ of behavioral").
- `examplesContext` injected into question generation prompts to make scenarios feel company-relevant.

### 8.2 LLM fallback

For unrecognized companies (e.g., user enters "Postman" before we've curated it):
- Trigger LLM generation of profile using public knowledge.
- Cache for future users.
- Quality-check via daily review of newly-generated profiles before promoting from `llm-generated` to `curated`.

### 8.3 What it changes

- Diagnostic question selection (via topic weights).
- Question framing (examples drawn from company's domain).
- Plan emphasis (front-loads topics company emphasizes).
- Insights language (mentions company-specific patterns where relevant).

---

## 9. Per-objective-type flows (concise)

Common: all 7 types share Steps 1-4 + Step 6 of onboarding. Step 5 differs per type.

### 9.1 upskilling

Step 5: 6-8 topics from taxonomy (objective × targetSkill) + AI literacy topic + self-rating.
Diagnostic: MCQ + scenario MCQ + voice for leadership/stakeholder topics. 14-21 questions, 7-9 min.
Results: hero + calibration + per-topic bars + 2-3 patterns + plan headline.
Plan: ~hours/week × timeline budget, weighted by gaps + future-proofing.

### 9.2 interview_preparation

Step 5: 6-8 topics from taxonomy (objective × targetRole × tier) + AI topic if applicable + self-rating.
If `targetCompany` is named, apply company profile overrides.
Diagnostic: MCQ + scenario MCQ + voice for behavioral. 16-21 questions, 8-9 min.
Results: emphasis on interview-specific risks (e.g., "Behavioral structure is your interview-day risk").
Plan: tightly bound to interview date; front-loads weakest interview-impacting topics.

### 9.3 exam_preparation

Step 5: subjects auto-derived from exam (e.g., GMAT → Quant, Verbal, Data Insights, AWA). User can deprioritize but not remove. Self-rating per subject.
Diagnostic: MCQ-only, **strict per-question timer** mimicking exam conditions. 18-30 questions depending on subject count. ~9 min.
Results: section-level read with target-score gap analysis.
Plan: tied to exam date as hard deadline; mock test cadence baked in.

### 9.4 career_switch

Step 5: 6-8 topics split into "leverage" (from current domain) and "build" (for target domain). AI literacy injected if target is tech. Self-rating.
Diagnostic: MCQ + scenario MCQ. Leverage topics get questions that test transferability. 14-20 questions.
Results: explicit framing of transferable strengths + build areas.
Plan: long-runway emphasis on build topics, periodic leverage practice.

### 9.5 academic_excellence

Step 5: subjects + sub-topics (chapters/areas) from taxonomy keyed by board × grade. Self-rating per sub-topic.
Diagnostic: MCQ + short application. 16-20 questions.
Results: subject-level + sub-topic-level read; exam-prep framing if `specificExam` set.
Plan: aligned to academic calendar / exam date if set; mock test cadence.

### 9.6 casual_learning (no diagnostic)

Step 5: replaced by **affinity card stack** — 10-15 cards swiped right (more like this) or skipped. Builds a taste profile, no rating, no test.
Output: Home becomes a curated daily/weekly feed. No plan, no goals, no test.

### 9.7 networking (no diagnostic)

Step 5: replaced by **intent + style picker** — networking intent (mentors / peers / hiring / community), who to meet, communication style, 30-day goal.
Output: Home shows weekly people to engage with, conversation prompts, message templates, light tracking.

---

## 10. Results & insights screen

### 10.1 Score → band mapping

| Band | Score range |
|---|---|
| Novice | 0-30 |
| Familiar | 30-55 |
| Proficient | 55-80 |
| Expert | 80-100 |

Self-rating maps directly: Novice band, Familiar band, etc. (Expert maps to 80-100 expectation.)

### 10.2 Calibration computation

For each topic:
- `selfRatedMidpoint` = midpoint of self-rated band (Novice=15, Familiar=42, Proficient=67, Expert=90)
- `calibrationDelta = measuredScore - selfRatedMidpoint`
- Classify:
  - `well-calibrated`: |delta| ≤ 15
  - `overestimates`: delta < -15
  - `undersells`: delta > +15

### 10.3 Insights generation (LLM-powered)

After all answers submitted, generate insights via single LLM call (json_schema strict, 15s timeout):

**Input:** all topics + self-ratings + measured scores + calibration deltas + objective type + canonical specifics + timeline + hours/week + (optional) company profile + answer pattern (which difficulty levels missed).

**Output schema:**
```json
{
  "hero": "One sentence positioning the user.",
  "calibration": "One sentence on overall calibration pattern.",
  "patterns": [
    "Cross-cutting observation 1",
    "Cross-cutting observation 2"
  ],
  "topicTakeaways": {
    "product-strategy": "One-line takeaway",
    "user-research": "One-line takeaway",
    ...
  },
  "planHeadline": "3-4 sentences explaining what the plan will do, factoring timeline, hours/week, and optional milestones."
}
```

**Failure mode:** If LLM call fails or times out, fall back to template-based insights derived from calibration math alone. Less rich but never empty.

### 10.4 UI structure (wow-worthy, interactive, animated)

The results screen is the moment that earns trust. It must feel like a finished product, not a report.

#### First-time results screen (initial diagnostic)

1. **3-screen story-style hero reveal** (first view only, swipeable, ~5s each with skip):
   - Screen 1: *"Here's where you stand."* (animated progress meter from 0 to overall calibration position)
   - Screen 2: *"Here's what surprised us."* (the single most striking insight — e.g., biggest calibration gap or strongest hidden strength)
   - Screen 3: *"Here's what we recommend."* (one sentence preview of plan direction)
   - Tap-through fast or auto-advance; lands on the main results layout.

2. **Hero card** (sticky top): one-sentence positioning, bold, with a small share icon.

3. **Calibration card**: one number ("Well-calibrated on 5 of 7 topics") + the calibration sentence + a confidence-vs-reality visualization — shaded delta band between self-rated and measured score, color-coded green (well-calibrated) / amber (overestimates) / blue (undersells).

4. **Per-topic cards** (collapsed by default, tap to expand):
   - **Closed:** two side-by-side bars animated on first reveal (count-up animation), 1-line topic takeaway, gap indicator color.
   - **Expanded:** which difficulty levels were missed, specific concept to focus on (templated from question metadata), "Strongest moment" (best-answered hard question with brief explanation) + "Stretch moment" (hardest miss with explanation).

5. **Pattern insights**: 2-3 cross-cutting observations as cards. Tap-to-expand for evidence.

6. **Question-by-question replay** (collapsed section "Review your answers"): scroll through every question with your answer + correct answer + 1-line "why."

7. **Plan preview**: planHeadline text + estimated milestones list (placeholder while plan generates).

8. **Shareable summary card** (opt-in): auto-generated image with hero insight + 3 topic bars + ScaleUp branding. Share to WhatsApp/LinkedIn/Instagram.

9. **CTA**: "See your plan" → navigates to Plan tab. If plan still generating, brief "almost there" (~10-15s); if user navigates to Home instead, push notification arrives when plan is ready.

#### Re-calibration results screen (different shape)

Same layout as first-time but with **growth visualization replacing baseline visualization**:

1. **Hero**: *"Your Stakeholder Mgmt jumped from Novice to Familiar in 4 weeks."*
2. **Growth bars per topic**: old measured → new measured, animated arrow showing direction + magnitude.
3. **Biggest jump callout**: most-improved topic, framed as celebration.
4. **New gaps surfaced** if any: amber callout for topics that drifted.
5. **Plan rebalance preview**: before/after view of weekly hour allocations.

### 10.5 Insights generation phase UX (the 8-15s wait)

Triggered after user submits final diagnostic answer. Single LLM call (json_schema strict, 15s timeout) generates the full insights JSON.

**During the wait:** a polished `InsightsGeneratingView` (similar visual language to existing `DiagnosticPreparingView` but tuned for completion phase):

- **Three-stage rotating progress text:**
  - 0-3s: *"Analyzing your answers..."*
  - 3-7s: *"Comparing your self-rating to actual performance..."*
  - 7-15s: *"Generating personalized insights..."*
- **Background animation**: subtle bar-chart-shape rendering hint, building toward the actual visualization
- **2-3 rotating fact cards** about calibration/learning ("Most learners discover one major blind spot in their first calibration..." / "People who get calibrated learn 2-3x faster than those who don't.")
- **No skip button** — generation must finish (or timeout).

**Timing reality:**
- p50: ~9 seconds
- p90: ~13 seconds
- Hard timeout: 15 seconds → graceful fallback to template-based insights derived from calibration math alone (less rich, never empty)

**Transition:** when insights ready, smooth crossfade into the 3-screen story-style hero reveal.

### 10.6 What this replaces

- Today's "Novice 25/100" cards.
- Today's missing pattern analysis.
- Today's missing plan integration on the results screen.
- Today's static, non-interactive results.

---

## 11. Plan generation contract

### 11.1 Inputs

After diagnostic completion, plan generator receives:

```js
{
  userId,
  objectiveId,
  diagnosticAttemptId,
  objectiveType,
  specificsCanonical,
  companyProfile,                    // optional
  timeline,                          // weeks
  weeklyCommitHours,
  topicResults: [{
    canonicalName,
    selfRating,
    measuredScore,
    measuredBand,
    calibrationDelta,
    calibrationClass,                // 'well-calibrated' | 'overestimates' | 'undersells'
    questionsAsked,
    answerPattern,                   // missed difficulty distribution
    isFutureProofing,
  }],
  userMilestoneHints,                // optional, from onboarding free text if any
}
```

### 11.2 Outputs

```js
{
  planId,
  weeklySchedule: [{
    week: 1,
    allocations: [{ topicCanonicalName, hours, focusActivity }],
    weeklyGoal: "...",
  }, ...],
  milestones: [{
    week: N,
    title: "...",
    measurableCriteria: "...",
    isUserStated: false,             // true if from userMilestoneHints
  }],
  planHeadline: "...",               // 1-2 sentences for display
  estimatedTotalHours: Number,
  bufferRecommendation: "...",       // e.g., "We've left 15% buffer for life events"
}
```

### 11.3 Constraints

- Total allocated hours ≤ `timeline_weeks × weeklyCommitHours × 0.85` (15% buffer).
- Topics with `calibrationClass = overestimates` get +20% hours over baseline.
- Topics with `measuredBand = Novice` get foundational sequencing (cannot be in week 1 if dependencies exist).
- Future-proofing topics get a baseline of 8-10% of total hours minimum.
- Milestones spaced at meaningful intervals (every 4-8 weeks for short timelines, every 8-12 for long).

### 11.4 Async execution + timing

Plan generation runs as a **background job** triggered when diagnostic completes (parallel with insights generation; insights are the foreground priority).

**Realistic timing:**
- Insights generation: **8-15 seconds** (foreground, blocks results reveal — see §10.5)
- Plan generation: **30-60 seconds** (background, never blocks user)
- Hard cap on plan: 3 minutes → timeout fallback to template plan

**User experience during plan generation:**

1. After insights reveal, results screen shows plan preview placeholder + planHeadline text + a chip: *"Your plan is brewing — usually ~45s"*.
2. User reads insights at their own pace (typical: 60-90s on results screen — well within plan generation time).
3. When user taps "See plan":
   - If plan ready → navigate to Plan tab.
   - If still generating → brief "almost there..." overlay (~10-15s additional in rare cases).
4. If user navigates to **Home tab** instead:
   - Home shows seeded content from `topicsOfInterest` (already working today).
   - A subtle "Your plan is brewing" pill at the top with live progress.
   - Push notification arrives when plan ready: *"Your personalized plan is ready. Tap to view."*

**Failure mode:** If LLM plan generation fails or times out, fall back to a template plan derived from calibration math + timeline + hours allocation rules (no LLM). User sees the plan immediately; we silently retry the LLM-enhanced version in background and replace the plan if successful.

**No blank screen ever.** Insights screen is rich enough to read for 60-90s, which is the plan generation budget. Home tab is alive immediately. The user is never staring at a spinner with nothing to do.

---

## 12. API endpoints

### 12.1 Onboarding

| Method | Path | Purpose |
|---|---|---|
| POST | `/onboarding/topics/suggest` | Given objective + canonical specifics + optional company, return suggested topics from taxonomy. Triggers LLM generation if no entry exists. |
| POST | `/onboarding/complete` | Atomic save of all onboarding data with normalization pass. Returns `userObjectiveId`. |

### 12.2 Diagnostic (refined from existing)

| Method | Path | Purpose |
|---|---|---|
| POST | `/diagnostic/attempts/start` | Returns `{ attemptId, totalEstimatedQuestions, estimatedDurationSec, flowType }`. Triggers async pool assembly. |
| POST | `/diagnostic/attempts/:id/self-rating` | (Now redundant — self-ratings come from onboarding. Kept for backward compat in case of re-rating.) |
| GET | `/diagnostic/attempts/:id/next-question` | Returns `{ question: { _id, prompt, options, difficulty, type }, progress: { current, total } }` or `{ done: true }`. |
| POST | `/diagnostic/attempts/:id/answers` | `{ questionId, answer, timeMs, audioUrl? }`. Returns `{ accepted: true }`. |
| POST | `/diagnostic/attempts/:id/finish` | Triggers async insights generation + plan generation. Returns `{ status: 'completed', insightsStatus: 'generating' }`. |
| GET | `/diagnostic/attempts/:id/results` | Returns `{ status, results: [...], insights: {...} or null if still generating, planStatus }`. |

### 12.3 Plan

| Method | Path | Purpose |
|---|---|---|
| GET | `/plan/status` | Quick poll for plan readiness. |
| GET | `/plan/current` | Full plan with milestones. |

### 12.4 Voice

| Method | Path | Purpose |
|---|---|---|
| POST | `/diagnostic/voice/upload` | Upload audio blob, returns `audioUrl` and `transcription`. Used inline in voice answers. |

### 12.5 Syllabus upload

| Method | Path | Purpose |
|---|---|---|
| POST | `/diagnostic/syllabus/upload-init` | Returns presigned S3 URL for direct upload + `syllabusId`. |
| POST | `/diagnostic/syllabus/:id/complete` | Triggers extraction worker. Returns `{ status: 'processing' }`. |
| GET | `/diagnostic/syllabus/:id/status` | Returns extraction status + (if completed) extractedTopics for user to confirm/edit before diagnostic. |

### 12.6 Admin (question review dashboard)

All endpoints gated by `User.isAdmin = true`.

| Method | Path | Purpose |
|---|---|---|
| GET | `/admin/diagnostic-questions/queue` | Returns paginated list of `flagged_for_review` questions with validator critique. |
| POST | `/admin/diagnostic-questions/:id/approve` | Force-promote to `human_verified`. |
| POST | `/admin/diagnostic-questions/:id/edit` | Edit question content + approve. |
| POST | `/admin/diagnostic-questions/:id/reject` | Delete from bank, log reason, optionally trigger regeneration. |
| GET | `/admin/diagnostic-questions/stats` | Dashboard stats: queue depth, validator pass rate, recent decisions. |

Frontend: minimal admin web page (could be simple HTML+vanilla JS served from BE, or React if a base admin app exists). Not part of iOS/Android apps.

---

## 13. Frontend changes

### 13.1 iOS (SwiftUI)

**Modified:**
- `InterestsStepView.swift` — taxonomy-backed topic suggestions, custom add capped at 8, info tap, AI badge.
- `InterestsStepView.swift` — new self-rating sub-step within same step.
- `OnboardingViewModel.swift` — fetch taxonomy on demand, store self-ratings.
- `DiagnosticOrchestrationView` (and child views) — adapted for per-topic flow; voice answer support.
- `DiagnosticResultsView.swift` — completely rebuilt per §10 structure.

**New:**
- `DiagnosticVoiceAnswerView.swift` — record/playback/retry UI.
- `InsightCard` components — hero, calibration, pattern, topic.

**Unchanged:**
- `DiagnosticPreparingView.swift` — keep existing loader.
- All other onboarding step views.

### 13.2 Android (React Native)

Mirror iOS structure exactly:
- `InterestsStep.tsx` — taxonomy-backed, self-rating sub-step.
- `OnboardingContainer.tsx` — fetch taxonomy, store self-ratings.
- Diagnostic screens — per-topic flow + voice.
- Results screen — rebuilt.
- New voice answer screen.

Keep `PreparingScreen.tsx` as-is.

### 13.3 Shared frontend contracts

- Topic chip component: name + description tooltip + future-proofing badge + selected/unselected state + remove button.
- Self-rating row component: topic name + 4 chips with anchored examples on tap.
- Insight cards: hero, calibration, pattern, topic-comparison-bar, growth-bar (re-calibration only), shareable-summary-card.

### 13.4 UX micro-interactions and animations

The diagnostic and results screens must feel alive. Specific interactions:

**Onboarding Step 5:**
- Topic chips animate in on screen entry (staggered fade-up).
- Tapping a chip to remove triggers a brief shake-then-fade.
- Adding a custom topic shows a small green checkmark pulse.
- Self-rating chips: tap shows brief glow + haptic feedback (iOS).

**Diagnostic flow:**
- Topic-by-topic progress chip at top: *"3 of 7 topics — on Stakeholder Mgmt now"*. Updates with smooth slide animation between topics.
- Brief celebratory transition card between topic batches: *"Nice — moving to Strategy"* with subtle gold accent (~1s).
- Voice answer recording: live waveform feedback while recording (existing pattern from notes feature can be reused).
- Subtle haptic feedback on iOS for answer submission.
- Answer reveal animation: option chip fills with color on selection.
- On diagnostic completion: brief confetti micro-animation (restrained, not gaudy — gold sparks ~1.5s).

**Insights generation phase:**
- See §10.5 — three-stage rotating text + background animation hint.

**Results screen:**
- Bar charts animate with count-up (numbers tick up from 0 to final value over ~1s).
- Per-topic cards: smooth height animation on expand/collapse.
- Hero 3-screen reveal: smooth horizontal swipe with progress dots.
- Pull-to-refresh on results screen if insights still generating (rare).
- Shareable card generation: tap "Share" → brief loading shimmer → image preview → share sheet.

**Re-calibration results:**
- Growth bars animate from old value to new value (visible "growth" motion).
- Biggest jump callout: brief celebration animation on first reveal.

**Cross-cutting:**
- All transitions respect iOS reduced-motion accessibility setting.
- All animations cap at 1.5s — never blocking interaction.
- No gaudy effects — restrained, premium feel matching existing app design language.

### 13.5 Mixpanel event instrumentation

All events tracked via existing Mixpanel infrastructure (per existing analytics plan). Naming follows existing convention.

**Onboarding-related (new):**
- `onboarding_topic_taxonomy_loaded` — taxonomy fetch on Step 5 entry, with `cacheHit: true|false`, `latencyMs`
- `onboarding_topic_added_custom` — user added a custom topic
- `onboarding_topic_removed` — user removed a suggested topic
- `onboarding_self_rating_completed` — user finished self-rating sub-step, with `topicCount`, `ratingDistribution`
- `onboarding_syllabus_uploaded` — user uploaded a syllabus, with `fileType`, `pageCount`, `cacheHit`
- `onboarding_syllabus_skipped` — user skipped the syllabus upload option

**Diagnostic flow:**
- `diagnostic_started` — diagnostic kicked off, with `objectiveType`, `topicCount`, `flowType: initial|recalibration|existing_user_migration`
- `diagnostic_question_shown` — each question, with `topicCanonical`, `difficulty`, `questionType: mcq|scenario|voice`
- `diagnostic_question_answered` — each answer, with `correct`, `timeMs`, `usedVoice: true|false`
- `diagnostic_voice_used` — voice answer recorded
- `diagnostic_voice_failed_fallback_typed` — voice failure → typed fallback
- `diagnostic_topic_completed` — finished all questions for a topic
- `diagnostic_completed` — full diagnostic done, with `totalQuestions`, `totalDurationSec`, `voiceAnswersCount`
- `diagnostic_abandoned` — user left mid-diagnostic, with `lastQuestionIndex`, `topicsCompleted`

**Insights & results:**
- `insights_generation_started` — LLM call kicked off
- `insights_generation_completed` — successful completion, with `latencyMs`
- `insights_generation_fallback` — fell back to template, with `reason: timeout|error`
- `diagnostic_results_viewed` — results screen first view
- `diagnostic_hero_reveal_completed` — user completed the 3-screen story (or skipped)
- `diagnostic_topic_card_expanded` — user expanded a per-topic card, with `topicCanonical`
- `diagnostic_replay_section_opened` — user opened question-by-question replay
- `diagnostic_results_shared` — user generated and shared the summary card, with `shareDestination` if available

**Plan-related:**
- `plan_brewing_seen` — user saw the "plan brewing" indicator
- `plan_ready_notification_tapped` — user tapped the push notification
- `plan_generation_completed` — successful, with `latencyMs`
- `plan_generation_fallback` — fell back to template plan

**Re-calibration:**
- `recalibration_offered` — user saw the re-calibration card on Progress tab
- `recalibration_started` — user started re-calibration
- `recalibration_completed` — finished, with `topicsRetested`, `growthScore`

**Quality / coverage monitoring:**
- `topic_taxonomy_lookup_miss` — taxonomy didn't have the (objective × target) — triggered LLM generation
- `question_bank_lookup_miss` — question bank didn't have the slot — triggered real-time generation
- `question_flagged_for_review` — Tier 1 validator flagged a question (admin-tracked)

**Existing-user migration:**
- `existing_user_calibration_banner_shown`
- `existing_user_calibration_banner_tapped`
- `existing_user_calibration_banner_dismissed`

---

## 14. Risks & mitigations

| Risk | Mitigation |
|---|---|
| LLM latency in insights generation degrades UX | json_schema strict + 15s timeout + template fallback + polished generation phase UX (§10.5) |
| Question bank coverage thin for new (objective × target) combos | Daily refresh + on-demand LLM generation with caching; substantial pre-seed (~16,800 questions) covering top 1,400 topic entries |
| **Real-time-generated questions could be wrong / ambiguous** | **Two-tier validation system (§5.5): automated Tier 1 + admin review Tier 2 + low-confidence question handling for users who hit them in the validation window** |
| Plan generation latency blocks user | Non-blocking background job + push notification + Home is usable immediately + insights screen rich enough to read for 60-90s |
| Company profile accuracy | Quarterly manual review of top 30 curated profiles; flag LLM-generated profiles for review before promotion |
| Voice transcription failures | Graceful fallback to typed answer field + live waveform feedback during recording |
| User's normalized specifics map to wrong canonical | Display normalized form back to user during onboarding ("We saved this as 'Product Management' — change?") with one-tap edit |
| Cascading bugs from canonical naming (the v1 problem) | Single source of truth for canonical names; integration tests covering full happy path + edge cases per objective type |
| **Syllabus extraction fails on poor-quality scans** | **Existing notes infra handles via GPT-4o Vision fallback. If <100 chars extracted, graceful fallback to standard taxonomy with apologetic toast.** |
| **Anchor question generation cost blows budget** | **Hybrid: LLM-generate anchors → strict review → promote good ones. Avoid pure manual sourcing for v1.** |
| **Existing users ignore the calibration prompt** | **Banner persistence + 14-day quiet period + max 3 prompts. Re-frame value clearly: "9-min calibration to make your plan actually work for you."** |
| **Re-calibration becomes annoying nag** | **Never on Home (Progress tab + Plan tab only). 30-day delay. Quiet after day 60 if ignored. Always dismissible.** |
| **Phase 0 research scope creep** | **Time-box to 1-2 days. Output is a structured markdown doc, not a perfect dataset. Daily refresh closes gaps post-launch.** |

---

## 15. Implementation phasing

### Phase 0: Seeding research (week 0, ~1-2 days)
- India-centric 2026+ research deliverable (per §6.0).
- Top skills, top exams, top companies, common career transitions, AI literacy mapping, Indian boards × subjects.
- Output: structured markdown doc reviewed by Nirpeksh.

### Phase 0.5: Taxonomy + question bank seeding (week 0-1, ~3-5 days)
- `seedTopicTaxonomy.js` — hand-curate ~1,400 topic entries from Phase 0 research.
- `seedCompanyProfiles.js` — ~30-40 company profiles.
- `seedAnchorQuestions.js` — generate + curate 2-3 anchor questions per topic via hybrid LLM+review.
- `seedQuestionBank.js` — batch-generate ~16,800 MCQ + ~450 voice prompts using anchors as few-shot examples.
- All seed-batch questions enter Tier 1 validation.
- ~$90 LLM cost.

### Phase 1: Foundation (week 1-2)
- Backend models: `TopicTaxonomy`, `CompanyProfile`, `DiagnosticSyllabus`, `UserObjective` updates, `DiagnosticQuestionBank` schema additions.
- Existing-user migration script (set `needsCalibration: true`).
- Normalization pass for Step 3 specifics.
- API endpoints scaffolding (incl. admin endpoints).
- Two-tier validation pipeline scaffolding (Tier 1 validator LLM call + queue).

### Phase 2: Onboarding (week 2-3)
- iOS Step 5 rework + self-rating sub-step.
- Android Step 5 mirror.
- Topic suggestion endpoint live.
- Syllabus upload UI on Step 5 (academic_excellence default, exam_prep optional).
- Existing-user calibration banner on Home.

### Phase 3: Diagnostic engine (week 3-4)
- Question selection algorithm per §5.
- Per-objective-type variations.
- Voice answer pipeline (leverage existing Whisper integration).
- Daily refresh cron (taxonomy + question bank).
- Real-time question generation with caching.
- Tier 1 validator runs on all newly generated questions.

### Phase 4: Results & insights (week 4-5)
- LLM insights generation with json_schema.
- `InsightsGeneratingView` (8-15s wait phase UX).
- Results screen rebuild on iOS + Android (incl. 3-screen story-style hero, animated bars, per-topic expand, replay section, shareable card).
- Template fallback insights.
- Mixpanel events instrumented.

### Phase 5: Plan integration (week 5-6)
- Plan generation contract + background job.
- Home tab "plan brewing" indicator.
- Plan tab consumes new structure.
- Push notification on plan readiness.
- Template plan fallback.

### Phase 6: Re-calibration + admin dashboard (week 6-7)
- Re-calibration flow (selection logic, shorter diagnostic, growth visualization).
- Re-calibration card on Progress tab + Plan tab nudge.
- Admin question review dashboard (web).
- Weekly digest email cron.

### Phase 7: Polish + launch (week 7-8)
- Company profile coverage expansion.
- Question bank gap-filling based on early user paths.
- End-to-end QA across all 7 objective types + existing-user migration + re-calibration flow.
- Marketing copy updates ("9-minute personalized plan").
- App Store + Play Store screenshots refresh.

**Total estimated build:** ~7-8 weeks (incl. Phase 0 research + Phase 0.5 seeding + 7 implementation phases).

---

## 16. Success metrics

Tracked via Mixpanel (per existing analytics plan):

- **Activation:** % users who complete the full diagnostic flow once started (target: ≥80%).
- **D1 retention:** users who completed diagnostic vs those who skipped (target: +15-20%).
- **Time to plan:** median minutes from signup to viewing personalized plan (target: <12 min).
- **Plan engagement:** sessions opened in first 7 days post-diagnostic (target: 4+).
- **Sentiment proxy:** % users who tap into a per-topic expanded card on results screen (target: ≥60% — indicates the insights are interesting).
- **Calibration coverage:** % attempts where insights generation succeeded vs fell back to template (target: ≥95%).

---

## 17. Open questions for review

None blocking — all major decisions agreed in brainstorming. These are nice-to-have decisions to confirm during implementation:

1. **Should the affinity card stack for casual_learning also surface for users who pick upskilling but score very low engagement after week 1?** (Adaptive degradation to softer mode.) — Defer to post-launch.
2. **On-demand re-calibration before the 30-day mark?** v1 has the 30-day rolling re-calibration. Should users be able to manually trigger one earlier? — Default v1: 30-day cadence locked. On-demand button deferred to v1.1.
3. **Voice prompt library:** how many prompts per topic? Start with 3 per voice-eligible topic, expand based on usage.
4. **Anchor question sourcing:** v1 plan is hybrid LLM-generate + admin-review. If quality is insufficient post-launch, consider sourcing from domain experts via Indian freelance platforms.
5. **Admin dashboard tech stack:** simplest is BE-served HTML+vanilla JS (no new build pipeline). Confirm OR adopt a base admin React app if preferred.

---

## Appendix A: Anchored self-rating examples

| Level | Anchor |
|---|---|
| Novice | "I've heard of this but never really used it." |
| Familiar | "I've used this a few times but still feel uncertain." |
| Proficient | "I use this confidently in most situations." |
| Expert | "I could teach this to others or be the go-to person on my team." |

## Appendix B: Hero insight tone examples

- Calibrated: *"You've got a solid foundation. The next 6-8 weeks should focus on sharpening strategy."*
- Overestimating: *"You're stronger than the test suggests in some areas, weaker in others — calibration is your first win to claim."*
- Undersellers: *"You've underrated yourself across the board — you're more ready than you think."*
- Mixed: *"You're strongest where it matters least for your goal. Let's redirect."*

## Appendix C: AI literacy topic naming reference

See §7.1 table for the canonical name per (objective × target). All marked `isFutureProofing: true` in taxonomy.
