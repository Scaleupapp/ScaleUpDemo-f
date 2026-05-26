# ScaleUp Coding Practice — Design Spec

**Author:** Claude (acting CTO) + Nirpeksh (founder)
**Date:** 2026-05-26
**Status:** Approved for implementation
**Repos affected:** `ScaleUpDemo-f` (iOS), `ScaleUpDemo/scaleup-backend`, `ScaleUpAndroid`, new `scaleup-web` (Next.js)

---

## 0. Executive Summary

ScaleUp adds a coding practice surface across mobile + web that trains the **meta-skills companies actually hire for in 2026**: prompting, verification, decomposition, refactoring with AI. Two formats:

- **Drills** — 10–15 min, mobile-first, daily; 4 types (Prompt / Verify / Decompose / Refactor-with-AI).
- **Capstones** — 60–90 min, laptop-required, weekly; realistic ticket in a starter repo with Compass-as-Coder embedded; recorded end-to-end; evaluated async; results, replay, and voice reflection on mobile.

Three role tracks: **SWE / Data Scientist / AI Engineer**. Three difficulty levels: **Easy / Medium / Hard**. Adaptive recalibration after each session.

The cold-start content problem is solved by a **system-generated Content Generator** (Claude Opus 4.7 + Code Execution + Gemini 2.5 cross-validator) that produces full Artifact Bundles validated by sandbox execution. Creators are a later multiplier, not a launch dependency.

Differentiation: every IDE has AI inline. **No IDE grades you, replays you, or maps your work to a Readiness Score against real interview parallels.** ScaleUp is the gym for AI-augmented coding.

**Decision:** Build. Coding feature first; TPO sales prep starts at month 3 with coding as the headline pitch.

**Timeline:** 3-day spike (Prompt Drill MVP) → 9-week full Drills launch → 21-week full Capstones launch. Single-developer (Claude-led) execution with founder review at each gate.

---

## 1. Strategic context

### 1.1 What the market does in 2026

| Segment | Current hiring format | Trend |
|---|---|---|
| Campus (TPO-driven) | DSA on CoCubes/HackerRank + 1–2 rounds | Top product cos add "build with AI" rounds |
| Lateral SWE 1–5 yrs | Take-home + live debug + system design + "code with Cursor/Claude in front of us" | AI-pair-programming demo is now a real round |
| DS / ML / AI Engineer | Notebook walkthroughs, 60-min RAG/agent builds, model deploys | Almost always laptop-based; very practical |
| Service cos (TCS/Infy/Wipro) | Aptitude + DSA + basic dev | Internal AI assistants standard; "use our AI" rounds appearing |

### 1.2 Meta-skills the market filters for

1. **Prompt decomposition** — break vague problems into AI-actionable pieces
2. **Verification discipline** — spot LLM mistakes; read the diff
3. **AI-handoff design** — what to delegate vs do yourself
4. **Debugging AI-generated code** — the most-failed skill
5. **System awareness** — does the AI's solution fit the codebase / scale / safety constraints

### 1.3 The wedge

| Every IDE has | ScaleUp adds |
|---|---|
| AI suggestions inline | Structured graded practice of meta-skills |
| You write code | Outcome-attributed Readiness Score with real interview parallels |
| Auto-save | Replay + reflection loop — watch yourself think |
| Free-form work | Curated role-track Capstones at calibrated difficulty |

**Pitch:** *ScaleUp is the gym for AI-augmented coding. The IDE is the real world.*

---

## 2. Scope

### 2.1 In scope at full launch

- 4 Drill types × 3 role tracks × 3 difficulty levels (mobile-first; web for Refactor-with-AI)
- Capstones × 3 role tracks × 3 difficulty levels (web IDE + sandbox + recording)
- Compass Coder mode (extension of existing Compass)
- Replay viewer on mobile (timeline scrubber over recorded session)
- Voice reflection loop (60-sec voice → auto-generated Note)
- Content Generator + Validator pipeline
- 120 launch bundles in the library (30 seed + 90 generated)
- Adaptive difficulty calibration
- Mobile↔web pairing via 6-digit code + QR
- Mastery extension (4 new meta-skill axes)
- Readiness Score weighting (gradual ramp)
- Backfill migration for existing users with coding-relevant objectives
- Plan integration (drill as daily activity, capstone as weekly milestone)
- Notes integration (auto-generated reflection note per capstone)
- iOS + Android parity at launch

### 2.2 Tier-1 languages + stacks (launch)

| Track | Languages | Stack variants |
|---|---|---|
| SWE | Python, JavaScript/TypeScript, Java, SQL | React+Node, Next.js, Python-FastAPI, Python-Django, Spring Boot |
| Data Scientist | Python, SQL | Jupyter+pandas+sklearn+PyTorch, Postgres+DuckDB |
| AI Engineer | Python, TypeScript | LangChain (Py+JS), FastAPI, OpenAI/Anthropic SDKs, Pinecone/Chroma |

### 2.3 Out of scope at launch (explicit)

- Tier-2 languages (Go, C++, C#, Kotlin) — Phase 4
- Tier-3 languages (Rust, Swift, Ruby, PHP, R, Julia) — Phase 5
- Creator-authored capstones — Phase 4
- TPO / recruiter share-view of replays — Phase 4
- Self-hosted Firecracker sandbox — Phase 5 (start on managed e2b/Daytona)
- Camera proctoring, keystroke biometrics — never
- Cross-user plagiarism detection — Phase 4

---

## 3. Product surfaces

### 3.1 Drill types

| Drill | What learner does | What we evaluate | Mobile/Laptop |
|---|---|---|---|
| **Prompt Drill** | Write a prompt that gets the LLM to do X correctly | Specificity, constraints declared, edge cases pre-empted, output fidelity | Mobile |
| **Verify Drill** | Spot the bug(s) in AI-generated code; mark location + explain | Detection accuracy, root-cause clarity, false-positive rate | Mobile |
| **Decompose Drill** | Break a real task into 3–7 AI-handoff steps with rationale | Granularity, dependency awareness, verification checkpoints | Mobile |
| **Refactor-with-AI Drill** | Refactor ugly code using Compass; defend each change | Correctness, readability gain, AI usage judgment | Laptop (web) |

### 3.2 Capstone shape

Every Capstone has:
- Brief (Jira-style ticket)
- Starter repo
- Acceptance criteria (visible)
- Compass-as-Coder available throughout
- 60 / 75 / 90 min timer by difficulty
- End-to-end recording (file edits, Compass turns, terminal commands, test runs)
- Voice reflection prompt at end
- Async evaluation → results land on mobile

### 3.3 Role tracks (content examples)

| Track | Drill example | Capstone example |
|---|---|---|
| **SWE** | Verify a buggy React hook / Decompose "add pagination to this endpoint" | Add webhook retries with backoff to a Node + React starter |
| **Data Scientist** | Prompt LLM to write correct GroupBy + window aggregation / Verify feature leak | EDA + model + writeup on a CSV given a business question |
| **AI Engineer** | Prompt-engineer a system prompt for an agent / Verify buggy RAG scoring | Build a small RAG or tool-using agent against provided corpus + eval harness |

### 3.4 Difficulty

| Level | What it means | Market anchor |
|---|---|---|
| Easy | New to stack / building confidence | LeetCode Easy, basic CRUD, single-file refactors |
| Medium | Can code on own; getting sharper | LeetCode Medium, service-co + early product-co rounds |
| Hard | Targeting top product cos / FAANG / wants to be tested | LeetCode Hard, Razorpay/Postman/CRED-tier, repo-wide refactors, ambiguous specs |

---

## 4. Content Generator subsystem

This is a first-class system, not an afterthought. It is the moat.

### 4.1 The Artifact Bundle (data contract)

Every Drill and Capstone in the library is a JSON-schema-validated bundle. Bundles are **immutable once shipped**; updates create new versions.

```typescript
interface ArtifactBundle {
  id: string;                           // ULID
  version: number;                      // monotonic per bundle
  type: 'drill' | 'capstone';
  drill_subtype?: 'prompt' | 'verify' | 'decompose' | 'refactor';
  role_track: 'swe' | 'ds' | 'ai_eng';
  language: 'python' | 'javascript' | 'typescript' | 'java' | 'sql';
  stack_variant?: string;               // e.g. 'nextjs', 'fastapi', 'jupyter-pytorch'
  difficulty: 'easy' | 'medium' | 'hard';
  time_budget_minutes: number;          // 10-15 drill, 60/75/90 capstone

  brief: string;                        // learner-facing problem statement
  acceptance_criteria: string[];        // learner-visible
  starter_repo?: FileTree;              // capstones + refactor drill
  reference_solution: FileTree;         // GOLDEN ANSWER — never shown to learner
  visible_tests: TestSpec[];            // run during session
  hidden_tests: TestSpec[];             // run only at submit
  seeded_mistakes: SeededMistake[];     // planted suggestions Compass might make
  rubric_anchors: RubricAnchor[];       // deterministic checks evaluator must pass
  expected_meta_skill_signals: {
    good_prompts_look_like: string[];
    common_verification_traps: string[];
    decomposition_reference: string[];
  };
  difficulty_signals: {
    token_count: number;
    branching_complexity: number;
    edge_cases: number;
    known_hard_patterns: string[];
  };
  interview_parallel?: string;          // "Razorpay backend lateral round"
  content_hash: string;                 // for caching + dedup
  status: 'draft' | 'validated' | 'active' | 'retired';
  generated_by: {
    generator_model: string;
    validator_model: string;
    validated_at: ISODate;
    human_reviewed?: boolean;
  };
}

interface SeededMistake {
  location: string;                     // file path / line
  bug_description: string;              // private
  why_compass_might_suggest_it: string; // private — model failure-mode reasoning
  detection_signals: string[];          // tests that catch it, lint rules that flag it
}

interface RubricAnchor {
  dimension: 'correctness' | 'code_quality' | 'ai_pair_effectiveness' |
             'verification_discipline' | 'decomposition' | 'reflection_quality';
  check: string;                         // human-readable
  deterministic_test?: string;          // optional executable assertion
  weight: number;                        // contribution to dimension score
}
```

### 4.2 Generation pipeline

```
┌─────────────────────────┐
│  Seed Library           │ ← 30 hand-crafted gold bundles (10 per role-track,
│  (immutable, versioned) │   distributed across difficulties)
└────────┬────────────────┘
         │ k-nearest-neighbor as in-context examples
         ▼
┌──────────────────────────────────────────────┐
│ GENERATOR — Claude Opus 4.7 + Code Execution │
│ Inputs: role_track, language, difficulty,    │
│         drill_subtype, requested_topic,      │
│         3 nearest seed bundles               │
│ Output: full ArtifactBundle (structured JSON)│
└────────┬─────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────┐
│ VALIDATOR — Sandbox + Gemini 2.5 Pro         │
│ Checks (all must pass):                      │
│  1. starter_repo builds without error        │
│  2. reference_solution passes all tests      │
│  3. random non-solution code fails tests     │
│  4. each seeded_mistake actually fails tests │
│  5. visible_tests + hidden_tests are distinct│
│  6. difficulty matches stated level          │
│     (Gemini independent judgment)            │
│  7. brief is unambiguous (Gemini check)      │
│  8. content_hash not duplicate in library    │
└────────┬─────────────────────────────────────┘
         │
   ┌─────┴──────┐
   │            │
PASSES       FAILS
   │            │
   │            ├─► REGENERATE with critique (max 3 retries)
   │            │
   │            └─► still failing → human_review_queue collection
   ▼
┌────────────────────┐
│ Library Deposit    │ → status: 'active', live to learners
│ (Mongo, immutable) │
└────────────────────┘
```

### 4.3 Seed Library — 30 hand-crafted gold bundles

| Role track | Easy | Medium | Hard | Total |
|---|---|---|---|---|
| SWE | 4 | 4 | 2 | 10 |
| Data Scientist | 4 | 4 | 2 | 10 |
| AI Engineer | 4 | 4 | 2 | 10 |

Authored by founder + Claude in collaboration. Reviewed by 3 external senior engineers (one per track) **before** generator-at-scale begins. Seed quality is the upper bound on generated quality — non-negotiable.

### 4.4 Library size targets

| Milestone | Target | Distribution |
|---|---|---|
| Launch | 120 bundles | 30 seed + 90 generated |
| Month 3 | 300 bundles | balanced across track × difficulty |
| Month 6 | 600 bundles | retired/refreshed cycle active |

At launch volume of 1 capstone/learner/week, repeat exposure begins only after ~40 weeks per role-track. Effectively never at month 3+.

### 4.5 Quality gates

- Seed Library passes blind review by 3 external senior engineers (one per track)
- Generator+Validator pipeline must hit **≥ 90% pass-on-first-try** before generator-at-scale begins
- 5% of generated bundles undergo human spot-check at launch (drops to 1% by month 3)
- Each bundle tracks learner-aggregate signals: completion rate, score distribution, time-to-complete, seeded-mistake catch rate. Outliers (too easy / too hard / unsolvable / cheatable) are auto-retired

---

## 5. Difficulty calibration

### 5.1 Initial baseline

After backfill or onboarding, learner picks Easy / Medium / Hard for their role-track. First Drill or Capstone of each type at that level.

### 5.2 Adaptive recalibration

After each session, recommend next difficulty using multi-signal model:

| Signal | Push direction |
|---|---|
| Score > 85% | Up |
| Score < 50% | Down |
| Used < 60% of time budget | Up |
| Used > 105% (auto-submit) | Down |
| AI-pair effectiveness exceeds rubric expectation | Up |
| Verification dimension < 5/10 | Stay (drill verification first) |
| Trajectory says objective deadline at risk | Stay or down |

Recommendation surfaced to learner with reasoning. Override always allowed. Override is logged as training signal.

### 5.3 Market calibration

Seed bundles calibrated against:
- LeetCode (DSA-flavored portions)
- Public take-home assignments from Razorpay, Sprinklr, Atlan, etc.
- SWE-bench, MLE-bench, HumanEval for AI-Eng tasks
- Recruiter-shared assignments where available

Tagged difficulty is honest against the market — not "hard by our opinion."

---

## 6. LLM model selection

Three-provider strategy. Cross-model validation is the primary defense against hallucinated content.

| Role | Model | Why |
|---|---|---|
| **Compass-as-Coder** (in-session pair) | Claude Sonnet 4.6 | Instruction-following + safety + latency; existing Anthropic billing |
| **Content Generator — drafting** | Claude Opus 4.7 + Code Execution Tool | Highest reasoning + self-validates via execution |
| **Content Generator — Validator (cross-model)** | Gemini 2.5 Pro + Code Execution | Different blind spots; 1M context for whole-repo |
| **Reference Solution Solver** | Claude Opus 4.7 + Code Execution | Self-consistency: solve what generator wrote |
| **Capstone Evaluator** | Claude Sonnet 4.6 | Long-context review of diff + Compass log |
| **Drill Grader — Prompt/Verify/Decompose** | Claude Haiku 4.5 | Fast, cheap (~$0.005/grade) |
| **Drill Grader — Refactor** | Claude Sonnet 4.6 | Needs code review chops |
| **Seeded-mistake Generator** | Claude Opus 4.7 | Plausible bugs that mimic real Compass outputs |
| **Hidden-test Generator (adversarial)** | Gemini 2.5 Pro | Different model than draft generator |

**Cost discipline:** model routing is wrapped in a single `llmRouter` service with per-task overrides. Migrate to DeepSeek V3/R1 for high-volume grading (Drills) once scale justifies. Track per-task cost and quality monthly.

---

## 7. End-to-end flows

### 7.1 Drill flow (mobile)

```
[Mobile Home]                  [Drill modal]              [Result]
"Today's Coding Drill"
   │
   tap
   ▼
Brief + timer + input
   │
   submit (< 8 sec grade for non-refactor)
   ▼
Score + per-criterion rubric + "what to try next" → Mastery vector updated → Plan recalibrates
```

State machine: `scheduled → in_progress → submitted → graded → recorded_to_mastery`. Abandoned drills revert to `scheduled` with no penalty.

**Refactor-with-AI exception:** brief shown on mobile, CTA = "Continue on laptop" (mini-handoff identical to Capstone scaled down).

### 7.2 Capstone flow (mobile + laptop)

Mobile is command surface; laptop is work surface.

**1. Recommendation (mobile)** — Plan places Capstone as weekly milestone. Brief preview shown. Learner schedules a time or defers.

**2. Pre-flight (mobile)** — One-screen checklist: laptop ready, 90 min uninterrupted, network OK. Tap **Start on laptop**.

**3. Handoff code (mobile)** — 6-digit code + QR + email link, valid 10 min. Backend opens WebSocket session room keyed to user.

**4. Pair (laptop)** — Open `app.scaleup.app/capstone`, enter code or scan QR. Session paired. Mobile flips to **Capstone Live** screen.

**5. Sandbox provisioning** — Backend spins container (Tier-1 image, ~6 sec cold start; warm pool kept for peak hours). Starter repo cloned in.

**6. Web IDE renders** — Monaco editor; layout: brief + timer (left), file tree + editor (center), Compass Coder (right), terminal + tests (bottom). Recording starts on render.

**7. Coding** — Learner codes with Compass. Every Compass turn logged with prompt, response, accept/edit/reject. Every save auto-commits to temp git repo on backend.

**8. Mobile monitoring** — Mobile receives `session.stats` every ~10 s (elapsed, files changed, Compass turns, tests passing/total). No editor mirror. Pause / Abort available.

**9. Submit** — Tap Submit or timer hits zero → auto-submit. Sandbox runs full test + lint + acceptance harness. Recording finalizes. Session locks.

**10. Async evaluation** — BullMQ job. Evaluator collects diff + Compass log + time-per-file + test results + (later) voice reflection. Claude Sonnet 4.6 scores 6 rubric dimensions. Latency: 3–10 min target. Push fires when done.

**11. Results (mobile)** — Capstone Results screen: overall score, per-criterion breakdown, top 3 strengths + top 3 gaps, interview parallel, **Replay** button.

**12. Reflection (mobile)** — Inline prompt: 60-sec voice reflection. Uses existing audio infra. Notes feature auto-generates structured note.

**13. System update** — Capstone score writes to Readiness (interview-weight). Mastery updates per role-track. Plan recalibrates. Compass surfaces follow-up Tutor session on weakest criterion.

### 7.3 Mobile↔web sync — four messages

| Message | Direction | Purpose |
|---|---|---|
| `session.pair` | laptop → server | Hand in 6-digit code |
| `session.stats` | server → mobile (~10 s) | Heartbeat + counters |
| `session.control` | mobile → server | Pause / resume / abort |
| `session.lifecycle` | server → both | `provisioning / ready / paused / submitted / evaluating / done` |

No full editor mirroring. No screen sharing. Cheap, resilient.

### 7.4 Replay

The mobile Capstone Results screen has Replay → timeline scrubber over Compass turns + file edits + test runs. Each moment renders current code snapshot. Watchable in 5–10 min.

Evaluator-flagged moments are highlighted ("here you accepted a buggy Compass suggestion without verifying"). Replay raw event stream lives in S3 for 90 days; pre-rendered artifact regenerated on demand if it fails.

---

## 8. Evaluation rubrics

### 8.1 Drill grading

All Drill grading is synchronous (target < 8 s; Refactor < 25 s due to sandbox).

| Drill | Inputs | Grader | Rubric (hidden) |
|---|---|---|---|
| Prompt | Learner prompt + sandboxed LLM output | (a) Run prompt; (b) compare output; (c) grader scores prompt quality | Specificity, constraints, edge-case awareness, output fidelity |
| Verify | Bug locations + explanations | Grader with ground truth from bundle | Detection accuracy, root-cause clarity, false-positive rate |
| Decompose | Step list + rationale | Grader against reference decomposition | Granularity, ordering, verification checkpoints, AI-handoff appropriateness |
| Refactor | Final code + Compass turns | (a) Tests; (b) static analysis; (c) grader on process | Correctness, readability gain, AI usage judgment |

### 8.2 Capstone evaluation — 6 dimensions

Each 0–10, weighted to one overall score.

| Dimension | Weight | Signal sources |
|---|---|---|
| Correctness | 25% | Test pass rate + acceptance harness + hidden tests |
| Code quality | 15% | Static analysis + Sonnet code-review on diff |
| **AI-pair effectiveness** | 20% | Compass log analysis: prompt quality, accept/edit/reject ratios, rework cycles |
| **Verification discipline** | 15% | Did they run tests? Did they catch seeded mistakes? Test-write cadence |
| Decomposition | 10% | Commit cadence + Compass turn structure + file-order traversal |
| **Reflection quality** | 15% | Voice reflection transcribed + scored for self-awareness |

The three bolded dimensions are the meta-skill differentiators. Combined 50% weight.

### 8.3 Anti-drift

Every Capstone has 3–5 deterministic **rubric anchors** (hidden tests, seeded mistakes, specific patterns). If LLM evaluator disagrees with anchors by > 2 points, report flagged for human review (1 in N initially) and evaluator re-run with stricter prompt.

### 8.4 Calibration model

After ~500 capstones with downstream outcomes (learners who later interviewed), train linear model on 6 dimensions to predict interview success. Use to rebalance dimension weights quarterly. This is the path to honest Readiness signal.

---

## 9. Architecture

### 9.1 System diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            MOBILE (iOS + Android)                       │
│   New screens: Capstone Live · Capstone Results · Replay · Drill modal  │
│   Reuses: Plan, Compass, Mastery, Readiness, Notes, Push                │
└──────────────┬──────────────────────────────────────────────────────────┘
               │ HTTPS (existing API) + WebSocket (new)
┌──────────────▼──────────────────────────────────────────────────────────┐
│                        scaleup-backend (extended)                       │
│  NEW routes:        /api/coding/drills · /api/coding/capstones         │
│                     /api/coding/sessions · /api/coding/library          │
│  NEW services:      sandboxOrchestrator · capstoneEvaluator             │
│                     pairingService · contentGenerator · llmRouter       │
│  NEW workers:       capstone-eval · sandbox-gc · drill-grader           │
│                     content-generator · content-validator               │
│  EXTENDS:           Compass (Coder mode), Mastery, Readiness            │
│  REUSES:            Auth, Plan, BullMQ, S3, Mongo, OpenAPI              │
└──┬─────────────────────────────────────┬────────────────────────────────┘
   │ WebSocket (pair/stats/control)      │ Eval jobs + Generator jobs
┌──▼──────────────────────┐    ┌─────────▼────────────────────────────────┐
│   WEB (NEW)             │    │   Sandbox runtime (NEW)                  │
│   app.scaleup.app       │    │   Per-session container                  │
│   Next.js + Monaco      │◄──►│   Tier-1 image (Py/Node/Java/SQL)        │
│   - Editor              │    │   CPU/mem/network/wall-clock limits      │
│   - Compass pane        │    │   Temp git repo (autocommit)             │
│   - Terminal + tests    │    │   Provider: e2b.dev (managed, MVP)       │
│   - Recording client    │    │                                          │
└─────────────────────────┘    └──────────────────────────────────────────┘
                                          │
                                          ▼
                              ┌───────────────────────────┐
                              │  S3 (existing)            │
                              │  - Event stream / replay  │
                              │  - Voice reflection       │
                              │  - Diff snapshots         │
                              └───────────────────────────┘
```

### 9.2 New backend services

| Service | Responsibility |
|---|---|
| `llmRouter` | Per-task model routing (Opus/Sonnet/Haiku/Gemini); cost tracking; retry/fallback |
| `pairingService` | 6-digit code generation, QR encoding, WebSocket room lifecycle |
| `sandboxOrchestrator` | Container provisioning, warm pool, lifecycle (provisioning → ready → submitted → torn-down), per-session resource limits |
| `contentGenerator` | Drafting Artifact Bundles using nearest-seed examples |
| `contentValidator` | Cross-model validation + sandbox-execution checks |
| `drillGrader` | Synchronous grading for the 4 drill types |
| `capstoneEvaluator` | Async pipeline: diff analysis, Compass log analysis, test results, voice transcription, rubric scoring |
| `compassCoder` | Compass extension with code-mode prompt + tool use (file read, file write, run tests) inside sandbox context |

### 9.3 New data models (Mongo collections)

| Collection | Purpose |
|---|---|
| `artifact_bundles` | The content library (drills + capstones) |
| `drill_attempts` | Learner drill submissions + grades |
| `capstone_sessions` | Active and completed capstone sessions |
| `capstone_recordings` | Event stream metadata; S3 keys for actual data |
| `meta_skill_mastery` | Per-user per-track vector of 4 meta-skill axes |
| `difficulty_state` | Per-user per-track current difficulty + recommendation history |
| `pairing_codes` | Short-lived 6-digit codes; auto-expire 10 min |
| `human_review_queue` | Bundles failing validator that need human eyes |
| `evaluation_anchors` | Cached anchor-test results for drift detection |

### 9.4 OpenAPI surface

All new endpoints documented in `scaleup-backend/openapi.yaml` **before implementation**. iOS + Android + web all code-gen from this single source. No exceptions.

### 9.5 Sandbox provider — managed first

| Provider | Cost/session | Operational burden | Use case |
|---|---|---|---|
| **e2b.dev** | ~$0.10–0.20 | Near zero | **MVP** |
| Daytona | ~$0.10–0.25 | Low | Alternative if e2b limits hit |
| Self-host Docker on EC2 | ~$0.03–0.08 | Medium | Phase 5 when bill > engineer-month |
| Self-host Firecracker / gVisor | ~$0.02 | High | Phase 5+ only at large scale |

---

## 10. Integration with existing surfaces

| Surface | Change |
|---|---|
| **Plan** | Drills as daily-task candidates; Capstones as weekly milestones |
| **Quiz** | Drills sibling format; share scheduling + instant-feedback infra |
| **Interview** | Capstones sibling format; share async evaluator plumbing |
| **Compass** | New Coder mode; daily token budget tracked identically |
| **Mastery** | 4 new axes: prompting / verification / decomposition / refactoring (per role-track) |
| **Readiness** | New meta-skill component; weight ramps 0.0 → 0.10 as user accumulates ≥ 5 drill attempts |
| **Creator Hub** | No change at launch; capstones are system-generated. Phase 4 lets creators author |
| **You tab** | New drill-down: "Coding readiness" per-track meta-skill breakdown |
| **Notes** | Auto-generates a learner reflection note after each Capstone |
| **Notifications** | New types: drill ready, capstone ready, capstone evaluated, reflection prompt |

**Zero new top-level navigation.** Everything plugs into existing Home / Learn / Compass / You.

---

## 11. Backfill plan (existing users)

### 11.1 Eligibility query

Match users where:
- `primary_objective.category IN ('software_engineering', 'backend', 'frontend', 'fullstack', 'mobile_dev', 'data_science', 'data_analyst', 'ml_engineer', 'ai_engineer', 'devops_sre')`
- `last_active_at >= now() - 60 days`
- `notification_preferences.product_updates = true`

### 11.2 Per-user actions

1. Silently add 4 new Mastery axes with `confidence: 0, value: null`
2. Readiness Score meta-skill component weight = **0.0** at backfill (no score change visible to user); ramps to 0.10 after ≥ 5 drill attempts
3. Single invitation push: "New for your objective: a 5-min Coding Drill to calibrate where you are"
4. First Drill = Calibration Drill (Easy difficulty, all 4 drill types in one 8-min sequence) to establish baseline
5. Post-calibration, learner picks Easy/Medium/Hard for their role-track (default = system recommendation)
6. Plan recalibrates on next daily worker cycle (drills compete on activity palette; existing tasks not removed)
7. Compass surfaces "Try a coding drill" as suggested action

### 11.3 What we explicitly do not do

- Auto-modify existing Plan to force a drill
- Auto-recompute Readiness Score visibly
- Push more than once per user
- Backfill dormant users on re-activation
- Force the Calibration Drill — optional
- Send drill data to TPO without opt-in

### 11.4 Execution

- Script: `scripts/backfill-coding-meta-skills.js`
- One-time job; explicit `--dry-run` flag first
- Idempotent (no double notifications, no duplicate Mastery rows)
- Batches of ~500/day to spread push load
- Rollback script: `scripts/rollback-coding-backfill.js`
- Logged batch-by-batch

---

## 12. Edge cases

### 12.1 Pre-session

| Edge case | Handling |
|---|---|
| Pair code expires | Generate new code; no penalty |
| Cellular only | Warn; allow start; lower-fidelity recording |
| Abandoned checklist | Capstone stays scheduled; re-recommended next week |
| Two laptops pair same code | First wins; second shown "already paired" message |

### 12.2 During session

| Edge case | Handling |
|---|---|
| Laptop network drop 5–60 s | Editor keeps working locally; WebSocket auto-reconnects; mobile shows "Reconnecting" |
| Laptop network drop > 60 s | Mobile shows "Paused (network)" + resume CTA; sandbox kept alive 15 min |
| Sandbox crash | Snapshot current state; spin fresh container with same git history; timer auto-extends by lost time |
| Mobile force-quit | Independent of laptop session; re-attaches on reopen |
| Learner walks away | Idle 5 min → push "Still going?"; 10 min → auto-pause; 30 min → auto-submit current state |
| Sandbox abuse (fork bomb, infinite loop) | Per-process CPU/mem/wall-clock limits; auto-kill; surface error; no penalty |
| Compass API outage | Compass pane shows "temporarily unavailable"; learner continues; AI-pair dimension scored on what they did before/after |
| Timer ends mid-thought | 60-sec grace warning + 30-sec hard buffer; auto-submit captures state |
| Wrong stack at submit | Enforced at provisioning time — can't happen |

### 12.3 Post-session

| Edge case | Handling |
|---|---|
| Evaluation pipeline fails | Job retries 2× with backoff; flag for on-call; learner not penalized; surfaces "still evaluating" |
| Learner disputes score | "Request human review" → admin queue; 24-hr SLA at launch |
| Replay artifact fails | Raw event stream in S3 90 days; can always reconstruct |
| Push notification fails | Result surfaces on next app open; email fallback |

### 12.4 Account-level

| Edge case | Handling |
|---|---|
| No laptop | Drills still work (3 of 4 are mobile); Capstones flagged as "requires laptop" at onboarding; Plan offers non-coding milestone alternative |
| Switches objective mid-week | Pending capstone preserved as optional; new objective gets its own capstone |
| Free tier | First capstone/month free; drills always free (final pricing TBD before launch) |
| TPO student | TPO sees aggregate; replay only with opt-in |
| GDPR deletion | Existing route extended to cascade through 9 new collections |

---

## 13. Anti-cheat / integrity

Honest stance: cannot stop a determined cheater on a laptop. Goal is making it not worth it + making results legible downstream.

### 13.1 Launch posture

1. Locked full-screen IDE; tab blur logged
2. Compass-only AI inside sandbox; outbound HTTP whitelisted (npm, pip)
3. Paste-event logging (size + timing); large pastes flagged not blocked
4. Seeded mistakes — every capstone has 1–2 deliberate traps
5. Voice reflection is much harder to fake than text; inconsistency between voice and code is a flag
6. Integrity confidence score (high/medium/low) on every result; low-confidence results flagged on any TPO/recruiter share

### 13.2 Explicit non-goals at launch

- Camera proctoring (creepy + low signal)
- Keystroke biometrics (fragile)
- Cross-user plagiarism (slow + expensive; Phase 4)

### 13.3 Learner-facing banner

"This session is recorded. You can use Compass freely; outside AI tools defeat the purpose and will lower your integrity score." Honest framing beats arms race.

---

## 14. Roadmap

### 14.1 Schedule

| Milestone | Scope | Duration | Cumulative |
|---|---|---|---|
| **3-day spike** | Prompt Drill MVP, iOS only, SWE only, 9 hand-authored bundles, Compass grades via existing Sonnet, plugged into Plan + Mastery + Readiness (weight 0) | 3 days | Day 3 |
| **Drill Launch — Phase A** | All 4 drill types, 3 role-tracks, Content Generator pipeline live with 50+ generated bundles, iOS + Android parity, Compass Coder mode | 9 weeks | Week 9 |
| **Capstone Launch — Phase B** | Web IDE + sandbox + recording + evaluator + replay + voice reflection. 3 role-tracks × 3 difficulties × Tier-1 stacks. Total 120-bundle library. | 12 weeks | Week 21 |
| **TPO Sales Prep** | Lightweight TPO dashboard (read-only); LOI pipeline | starts week 12; closes design partners by week 26 | parallel |
| **Phase 4 (post-launch)** | Tier-2 languages, creator-authored capstones, recruiter-share view, self-host sandbox migration | 12+ weeks | Week 33+ |

### 14.2 Quality gates (must pass to proceed)

| Gate | Criterion |
|---|---|
| **Spike → Phase A** | Founder approves spike on a real device; 5 internal users complete a Prompt Drill end-to-end without bug |
| **Generator-at-scale** | 30 seed bundles pass blind review by 3 external senior engineers (one per track) AND Generator+Validator pipeline ≥ 90% pass-on-first-try |
| **Drill Launch (Phase A end)** | 50+ bundles in library; backfill executed on staging; iOS + Android in TestFlight + Internal Track |
| **Capstone Launch (Phase B end)** | 120-bundle library; 30 internal full capstone walkthroughs without P0/P1; sandbox warm-pool stable under load test; evaluator anchor-drift < 5% |

### 14.3 3-day spike — day-by-day

| Day | Backend | iOS | Content |
|---|---|---|---|
| **1** | Mongo schemas (`artifact_bundles`, `drill_attempts`, `meta_skill_mastery` extension). Route `/api/coding/drills`. Extend Compass orchestrator with `gradePromptDrill()`. OpenAPI additions. | Drill modal sheet skeleton. API client stubs from regen. | Write 9 Prompt Drill bundles by hand. |
| **2** | Grader logic + rubric prompt + structured-output schema. Plan integration (drill candidate). Push notification template. | Drill modal complete: brief, input, submit, result. Mastery delta animation. Wire to API. | Review 9 bundles end-to-end against grader. Tune rubric. |
| **3** | E2E testing. Rate limit + abuse handling. Anchor tests for grader drift detection. Backfill script + dry-run. | Polish, error states, telemetry events. TestFlight build 158. | Final bundle pass. Internal demo script. |

---

## 15. Cost model

### 15.1 Per-session unit cost (Anthropic Sonnet 4.6 for eval; mid-tier 2026 pricing)

| Component | Per Drill | Per Capstone |
|---|---|---|
| Sandbox compute | $0 (3 of 4 drills) / $0.02 (Refactor) | $0.10–0.25 |
| In-session Compass | $0.005 | $0.05–0.20 |
| Grading / evaluation | $0.005 | $0.20–0.50 |
| Storage (S3 lifetime) | < $0.001 | ~$0.005 |
| Push + WebSocket | trivial | trivial |
| **Total** | **~$0.01–0.03** | **~$0.35–1.00** |

### 15.2 Content Generator cost

| Component | Per bundle |
|---|---|
| Generator (Opus + Code Exec) | ~$0.30 |
| Validator (Gemini Pro + Code Exec) | ~$0.15 |
| Sandbox execution checks | ~$0.05 |
| Avg with 1.3 retry rate | **~$0.65 / shipped bundle** |

120-bundle launch library cost: ~$80 in LLM + sandbox. Trivial.

### 15.3 Scenario math

| Volume | Monthly infra |
|---|---|
| 1,000 learners × 4 drills/wk + 1 capstone/wk | ~$2K–4K |
| 10,000 learners × same | ~$20K–40K |
| 100,000 learners × same | ~$200K–400K (self-host migration point) |

At ₹299/learner/month subscription, infra is < 5% of revenue. Cost is not the blocker.

---

## 16. Success metrics

### 16.1 Activation (Week 1)

- ≥ 40% of eligible (coding-objective) backfilled users complete the Calibration Drill within 7 days
- ≥ 25% of backfilled users complete at least 3 Drills within 14 days

### 16.2 Engagement (Month 1)

- Median drill completions per active coding-objective user: ≥ 8/month
- Capstone scheduling rate among eligible: ≥ 30%
- Capstone completion rate (started → submitted): ≥ 70%

### 16.3 Quality (Month 1–3)

- Drill grader anchor-drift: < 5%
- Capstone evaluator anchor-drift: < 5%
- Human-review queue volume from validator failures: < 10% of generated bundles
- Learner dispute rate on grading: < 3% of attempts

### 16.4 Outcome (Month 6+)

- Readiness Score predictive accuracy vs interview outcomes: target r > 0.5 within 6 months of accumulated data
- D2C premium-tier conversion lift from coding feature: ≥ 30% vs baseline
- TPO LOIs in pipeline by week 16: ≥ 5

### 16.5 Decision gates (kill / pivot signals)

- Drill completion rate < 15% after backfill → product thesis problem; pause Capstone build, investigate
- Generator pass-on-first-try < 70% after 2 weeks of tuning → content quality at risk; expand seed library before generator-at-scale
- Capstone completion rate < 50% in Phase B internal testing → UX problem; do not launch publicly until resolved

---

## 17. Risks + mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Generator produces subtly wrong content | High | Critical | Cross-model validator + sandbox execution + 30 hand-built seeds + human spot-check |
| Sandbox vendor outage during a capstone | Medium | High | Graceful pause + sandbox keep-alive 15 min + fallback provider relationship |
| Evaluator scores diverge from human judgment | Medium | High | Anchor tests + drift detection + human review queue + quarterly calibration |
| Anti-cheat criticism public | High | Medium | Honest banner + integrity confidence (not pass/fail) + don't oversell |
| Multi-LLM cost discipline slips | Medium | Medium | `llmRouter` with per-task cost tracking; monthly review; DeepSeek path for high-volume |
| 21-week scope slips | High | Medium | Quality gates at each phase; willing to delay rather than ship bad content |
| Android lag | Medium | Medium | Drill on Android in Phase A (uses existing screens); Capstone-Live on Android in Phase B |
| LLM model deprecation mid-build | Low | Medium | `llmRouter` allows hot-swap; no hardcoded model strings in app code |
| Learner trust collapses if first 100 capstones grade poorly | Medium | Critical | Internal-only Phase B end gate (30 walkthroughs); public launch only after gate passes |

---

## 18. Out of scope (revisit later)

- Tier-2/3 languages
- Creator-authored capstones
- TPO recruiter-share view
- Cross-user plagiarism detection
- Camera / biometric proctoring
- Self-hosted sandbox infrastructure
- Pair programming between two learners
- Live mentor review of capstone sessions
- Multi-language polyglot capstones in one session
- Mobile-only capstone variants
- Web-only learners (no mobile)
- Offline drill mode

---

## 19. Open questions (to resolve before implementation plan)

1. **Subscription tier strategy** — drills free forever vs daily quota? Capstones premium-only vs N free per month? Pricing TBD before Phase A launch.
2. **Push notification cadence** — Calibration invitation timing per region (don't push at 3 AM)
3. **Voice reflection language** — English only at launch, or Hindi + English? Whisper supports both; UX implication.
4. **TPO data sharing default** — opt-in (learner controls) vs opt-out (TPO sees aggregate by default for their cohort)
5. **Replay retention** — 90 days S3 hot, then? Cold storage vs delete?
6. **Generator topic prompt** — does Plan tell Generator "user needs to practice pagination"? Or does Plan pull from existing library only and Generator runs on a fixed cadence? Recommend: Generator runs as a scheduled worker producing a fixed weekly quota; Plan pulls only from existing library.

---

## 20. Acceptance criteria for this spec

This spec is considered complete and approved when:

1. ✅ Founder reviews and signs off on this document
2. Open questions in §19 have decisions captured (or explicitly deferred)
3. Spec is committed to git on `master`
4. Implementation plan generated by `writing-plans` skill references this spec

---

*End of spec.*
