# ScaleUp Platform Audit — 2026-05-29

**Audience:** CEO + CPO (you)
**Purpose:** Single source-of-truth of every capability on the platform, ahead of (a) pitch-website rewrite and (b) personalised investor outreach.
**Tone:** Honest. No sugarcoating. Things that are half-built are called half-built.

---

## 0. About this document

**Audited surfaces:**
- **iOS** — `ScaleUpDemo-f` (SwiftUI, build 172, marketing 1.0.0, iOS 17+)
- **Android** — `ScaleUpAndroid` (React Native + TypeScript; named "Android" but is actually RN cross-codebase)
- **Backend** — `ScaleUpDemo/scaleup-backend` (Node/Express on AWS EC2 + MongoDB Atlas + Redis + S3)

**Not in scope of this audit** (next steps will use them but won't be inventoried here): `scaleup-web`, `scaleup-landingwebsite`, `scaleup-pitch-v2`, `scaleup-keynote`.

**Tagging convention for every feature below:**
- **V2-ACTIVE** — current primary product, in front of users today
- **V1-LEGACY** — old code still present and (often) still reachable as a fallback for users on the V1 feature-flag bucket. Slated for removal.
- **DORMANT** — code exists, no obvious user entry point
- **INCOMPLETE** — explicitly half-built ("Coming soon" placeholders, TODOs in the user path)
- **HIDDEN** — built and live, but the user has to dig to find it

**V2 rollout state.** Both apps run a server-driven feature flag (`v2_enabled`). Existing V1-bucket users still see the V1 5-tab IA. New registrations are forced into V2 (4-tab IA: Home / Learn / Compass / You). iOS has a `LEGACY_V1.md` removal plan dated **2026-06-15 → 2026-06-30**.

---

## 1. Executive snapshot

### What ScaleUp actually is, told back from the code

ScaleUp is a **goal-driven, AI-coached learning + career-prep platform for Indian users aged 18–25.** A user tells the app a real-world objective ("crack GMAT", "land an SDE role at Google", "get into IIM-A"), the platform diagnoses where they are, generates a multi-week structured plan, and then drives daily action through a single AI surface ("Compass"). The four user-facing primitives behind every day are: **a) Quizzes, b) AI Interview practice, c) Coding drills + capstones, d) Notes/content study.** A creator economy, a competition layer (daily challenges + scheduled live events), and a social follow-graph sit on top.

### Core loops (in plain English)

1. **Onboard → diagnose → plan.** Free-text objective → NLU parse → topic selection → per-topic self-rating → adaptive diagnostic → readiness baseline → multi-week plan.
2. **Daily action.** V2 Home is a "plan cockpit": today's 5 tasks, a readiness trajectory bar, a coding drill, a capstone milestone, a weekly forecast. Tap a task, do it (quiz / watch / interview / read / drill / capstone), come back, see progress move.
3. **Conversational AI everywhere.** Compass is a single AI surface that can tutor on a piece of content, configure a quiz/interview, coach the user's week/month/all-time, build a resume (placeholder), make a note, plan a day, or run a coding drill — all routed from the same chat.

### Status of monetisation

**Zero.** No paywall, no subscription product, no payment provider, no entitlement model. A single comment in `compassOrchestrator.js:111` reads `"Free tier 50k tokens/day. Pro tier 200k tokens/day (TODO: wire to subscription)"`. That is the entire revenue surface in the codebase.

### Platform maturity matrix

| Surface | iOS | Android | Backend | Note |
|---|---|---|---|---|
| Phone OTP auth | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Aligned with stated policy |
| Email auth (legacy) | V1-LEGACY (still reachable) | V1-LEGACY (still reachable) | V1-LEGACY routes still mounted | Policy says phone-only; code disagrees |
| V2 Home / Plan cockpit | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Iso-feature on both apps |
| Compass (AI coach) | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Replaces 11 fragmented V1 AI surfaces |
| Quizzes | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Daily top-gap auto-seed + on-demand |
| Coding Drills | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Adaptive difficulty + calibration |
| Coding Capstones | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Latest dev focus (builds 167–172) |
| AI Interview | V2-ACTIVE (Gemini Live / OpenAI Realtime — see §6) | V2-ACTIVE (Whisper + GPT-4o + TTS) | V2-ACTIVE (both pipelines) | Platforms diverge intentionally |
| Notes upload + AI artifacts | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Some sub-features dropped on V2 Android |
| Daily challenges / Live events | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Live-event lifecycle fully crontabbed |
| Resume Builder | INCOMPLETE | INCOMPLETE | not built | "Coming soon" chip on both apps |
| Social: Follow graph | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | |
| Social: DMs | not built | not built | not built | No messaging primitive anywhere |
| Creator Hub | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | 3-tier system (rising/core/anchor) |
| Admin tools | V2-ACTIVE | V2-ACTIVE | V2-ACTIVE | Static HTML + role-gated app surfaces |
| Monetisation | none | none | none | Single TODO comment |
| TPO / college dashboards | not built | not built | scaffolding only (CompanyProfile model, CohortDirectory cron, no routes) | README promises it; code doesn't ship it |

---

## 2. Feature inventory (the heart)

### 2.1 Acquisition & Onboarding

#### Splash + cold boot
- **Capability:** Branded gold-glow opening screen; hydrates auth token; routes user to the right state (welcome / onboarding / diagnostic / home).
- **Used for:** Hides cold-start latency and keeps the user in the right journey on every relaunch.
- **How it's used:** Auto-runs on every app open. User sees a one-second logo.
- **Status:** V2-ACTIVE on both apps.

#### Welcome screen
- **Capability:** Three entry options — Get Started (email register), Sign in with Phone OTP, Sign In with Email.
- **Used for:** Funnel entry. Converts a first-time visitor into an authenticated user.
- **How it's used:** First screen for a logged-out user.
- **Status:** V2-ACTIVE for "Get Started" + "Phone OTP". The "Sign In with Email" link is V1-LEGACY — the stated auth policy is phone-only, but email is still reachable on both apps.

#### Phone OTP authentication (primary path)
- **Capability:** +91 phone → 6-digit SMS code → if account exists, login; if not, signal `needsRegistration` and send the user to onboarding.
- **Used for:** Lowest-friction sign-in for the 18–25 mobile-first cohort.
- **How it's used:** User taps "Sign in with Phone OTP" on Welcome → enters phone → enters OTP → routed to home or onboarding.
- **Status:** V2-ACTIVE everywhere. Twilio SMS + Redis OTP cache + per-IP rate limiting.

#### Email register / login / forgot-password (legacy)
- **Capability:** Classic email+password register / login / forgot-password / reset flows + Google ID-token login on the backend.
- **Used for:** Originally the primary path in V1; retained for legacy accounts.
- **How it's used:** Still reachable through the "Sign In with Email" link on Welcome and through the email-first registration flow. Backend routes still mounted and rate-limited.
- **Status:** V1-LEGACY on both apps + backend. The Google sign-in dependency (`GoogleSignIn` SPM) is declared in iOS `project.yml` but the live auth flow doesn't use it.

#### Phone-linking for already-authed (email-first) users
- **Capability:** A user who originally signed up with email can add a phone number to their account.
- **Used for:** Bridging V1 email accounts to the V2 phone-first identity model.
- **How it's used:** Forced phone-verification step after email register, with a "Skip for now" branch.
- **Status:** V2-ACTIVE (transitional). The "Skip" branch creates accounts with no phone on file — a soft edge.

#### Account deactivation + 30-day grace + reactivation
- **Capability:** Soft-delete on `DELETE /users/me`; reactivate on next login within 30 days; permanent purge after.
- **Used for:** GDPR-style self-service account control + the legal right to be forgotten.
- **How it's used:** Settings → Danger zone → Deactivate. Reactivation prompt auto-appears on login attempt within grace period.
- **Status:** V2-ACTIVE on both apps + backend, with email reminders cron'd at 7 days and 1 day to purge.

#### V1 Onboarding (6 steps)
- **Capability:** Profile → Background (education/work) → Objective (exam/upskilling/etc.) → Preferences (learning style + weekly hours) → Interests (topic taxonomy + self-rating + optional syllabus PDF upload) → Completion.
- **Used for:** Originally the V1 onboarding path.
- **How it's used:** Still served to existing V1-bucket users.
- **Status:** V1-LEGACY (live on both apps for V1-bucket users).

#### V2 Onboarding (4 screens)
- **Capability:** Free-text objective → AI-parsed confirmation gate → Topic Selection → Per-topic proficiency rating with computed weekly-hours.
- **Used for:** Converts "I want to crack GMAT" into a structured goal + topic graph that the plan engine uses.
- **How it's used:** Fresh registrations are forced onto V2. After the four screens, the user is dropped into the diagnostic.
- **Status:** V2-ACTIVE. **Note:** Reality Check + Calibration Insights screens exist on Android as files (`V2RealityCheckScreen.tsx`, `V2CalibrationInsightsScreen.tsx`) but **may not be wired into `V2OnboardingFlow.tsx`** — iOS wires them in via `V2DiagnosticResultsBridge`. **This is a parity gap to verify.**

#### Adaptive diagnostic
- **Capability:** Multi-topic adaptive baseline. Phases: Welcome → Self-Rating → Preparing → Question loop (MCQ + voice-answered questions) → Topic transitions → Results + Hero Reveal + Insights Generation + Shareable card.
- **Used for:** Establishes a real readiness number + an honest "calibration gap" (where you think you are vs. where you actually are) per topic.
- **How it's used:** Runs once at the end of onboarding; can be re-run as "Recalibration" later when the user is due (daily cron seeds eligibility).
- **Status:** V2-ACTIVE everywhere. Voice answers via OpenAI Whisper; insights generation via Anthropic; OCR worker handles syllabus PDFs.

#### Plan generation (post-Reality Check)
- **Capability:** Generates a multi-week structured plan (`weeklySchedule[].tasks[]`) targeting the user's objective.
- **Used for:** The thing every other surface in V2 consumes — the day-by-day schedule.
- **How it's used:** Generated after diagnostic; user can also re-trigger; daily cron auto-promotes the next week when the current one is clean-done.
- **Status:** V2-ACTIVE. Anthropic-backed. BullMQ `planGeneration` queue.

---

### 2.2 Home (V2 Plan Cockpit)

#### V2 Home (the "plan cockpit")
- **Capability:** Single daily-action surface. Sections: greeting + objective pill + bell, **Readiness Status Bar** (current% → target%, tap to see trajectory chart), **TODAY** (hero task card + compact "also today" rows), **Coding Drill card** + **Coding Capstone milestone card**, **THIS WEEK** card (tap → multi-week sheet with dots), **PENDING / GET AHEAD / PUSH HARDER** chip row with inline task expansion, **FOR YOU** horizontal rail from Learn.
- **Used for:** Eliminates the V1 "wall of choices" problem — answers "what should I do today?" without scrolling.
- **How it's used:** Default landing tab. User taps a task → routes to the right detail screen (quiz / interview / capstone / drill / content / external link / Compass review). Completion auto-marks on return.
- **Status:** V2-ACTIVE on both apps. Backed by `/api/v2/plan/today`.

#### V1 Home (the legacy dashboard)
- **Capability:** Greeting + objective picker, calibration banner, diagnostic tune-up banner, plan-brewing pill, plan-generation banner, next action, Continue Watching row, Recommendations rail, Trending rail, Trending Notes, Quizzes-for-you, daily challenge / live event card, "all content" feed.
- **Status:** V1-LEGACY on both apps. Rendered only for V1-bucket users.

#### Notifications inbox
- **Capability:** Pull-to-refresh paginated list of in-app notifications (plan_ready, challenge_live, weekly_results, live_event_reminder, streak_reminder, social_comment, competition_results). Mark-one or mark-all read. Deep-link routing.
- **Used for:** Re-engagement surface inside the app, plus the destination for any tapped push.
- **How it's used:** Bell icon in Home header. Also push-driven from FCM (Android) / APNs (iOS).
- **Status:** V2-ACTIVE.

---

### 2.3 Compass (the AI coach surface — the biggest UX bet)

#### Compass shell
- **Capability:** Persistent gold floating action button on every non-Compass tab, plus a dedicated Compass tab. Three modes: (1) **default** — open chat with 8 quick-action chips; (2) **Tutor** — scoped to a piece of content; (3) **Coach** — retrospective with scope chips (Week / Month / All-time / Topic + free-text topic picker). Replies can carry inline configurator cards (topic / format / difficulty / count) or action cards.
- **Used for:** Single-pane-of-glass AI assistant. Replaces 11 fragmented V1 AI surfaces (per-feature shortcuts, AI tutor sheets, etc.). The single biggest UX bet in V2.
- **How it's used:** Tap FAB anywhere → chat sheet. Type a natural-language request ("quiz me on graphs hard 10 questions") → Compass builds a config card → Start launches the quiz. Or tap a chip → dedicated home opens.
- **Status:** V2-ACTIVE on both apps. Powered by `/api/v2/compass` with Anthropic Claude Sonnet 4, per-user daily token cap (50k free / 200k pro placeholder), Redis-backed.

#### Compass quick-action: Quiz me
- **Capability:** Quiz library home — pending generated quizzes, history with scores, "Generate New" sheet (topic + count + assessment type + "count toward objective" toggle).
- **Status:** V2-ACTIVE.

#### Compass quick-action: Practice interview
- **Capability:** Mock interview history, resume in-progress session, Start New → Interview Setup → Live session.
- **Status:** V2-ACTIVE.

#### Compass quick-action: Make a note
- **Capability:** Two-tab home: Upload new (PDF / PPT / image) + browse "My notes".
- **Status:** V2-ACTIVE.

#### Compass quick-action: Build my resume
- **Capability:** **Coming soon placeholder.** Lists planned features (LinkedIn import, ATS tuning, role-targeted versions). "Got it" button just closes.
- **Used for:** Nothing — this is a dead chip.
- **Status:** **INCOMPLETE** on both apps. Chip is live, destination is not. **Major credibility risk on the headline AI surface.**

#### Compass quick-action: Plan my days
- **Capability:** Slim version of the day cockpit — today's tasks + this-week summary + reshuffle skipped tasks + "View full Home" CTA.
- **Status:** V2-ACTIVE.

#### Compass quick-action: Compete today
- **Capability:** Today's challenge banner + competition history rails. Routes into Challenge Session or Competition Hub.
- **Status:** V2-ACTIVE.

#### Compass quick-action: Coding drill
- **Capability:** On-demand drill picker (Prompt / Bug Hunt / Decompose, plus difficulty). Submits to `/drills/request` → Drill Modal.
- **Status:** V2-ACTIVE.

#### Compass quick-action: Coding capstone
- **Capability:** Capstone home with summary, in-progress nudge, mastery axes, last 5 graded capstones with retry CTA, "Start a capstone" → `/capstones/request` → Capstone Preflight.
- **Status:** V2-ACTIVE.

#### Compass natural-language routing
- **Capability:** Any free-text turns into either conversational answer, a config card (e.g., "make it 10 questions") that the user confirms, or an action card that opens a sub-home.
- **Used for:** Discovery primitive in V2 — replaces a lot of conventional navigation.
- **Status:** V2-ACTIVE.

#### Compass conversation history
- **Capability:** Per-session conversation history with full transcript replay.
- **Status:** V2-ACTIVE. Surfaced from You tab → "My Compass activity". **Note:** `scope` is currently a placeholder field on listed sessions — the iOS coach-mode scope chip is not yet powered by real per-thread data.

---

### 2.4 Quizzes

#### Quiz library (V2)
- **Capability:** Pending quizzes (auto-seeded), past quizzes with scores, ability to generate a new quiz on demand.
- **Used for:** Bite-sized, topic-targeted self-assessment.
- **How it's used:** Reached from Compass → Quiz Home, or from a Home plan task, or from a content viewer's post-completion "Quiz on this?" prompt.
- **Status:** V2-ACTIVE.

#### Quiz session (timed MCQ + voice answer)
- **Capability:** Run a quiz, answer MCQs (and the occasional voice-answered question with Whisper STT fallback), see scored results with per-question review and explanations, retry.
- **Status:** V2-ACTIVE.

#### Daily top-gap auto-seeded quizzes
- **Capability:** Backend cron at 00:15 IST seeds 3× 10-question quizzes per active V2 user from their weakest topics + topics of interest.
- **Used for:** Forces daily engagement on the user's actual weak spots.
- **Status:** V2-ACTIVE backend cron.

#### V1 Quiz browsing (`QuizListView` / `QuizDetailView` on iOS, `QuizList` in V1 Plan stack on Android)
- **Capability:** Older flat list of available quizzes.
- **Status:** V1-LEGACY. The engine (session + results) is shared with V2; only the browsing UI is legacy.

---

### 2.5 AI Interview Practice (the platform-divergent feature)

#### Interview Setup
- **Capability:** Pick interview type (MBA admissions / placement HR / placement technical / case study / behavioral), target role / company / difficulty / objective scenario.
- **Status:** V2-ACTIVE.

#### Interview Live (the actual practice session)
- **Capability:** Voice-first mock interview. AI asks questions, user answers via mic, live transcript shown, end-of-session evaluation with rubric, per-question feedback including role/company-tailored model answers.
- **Used for:** Mock interview practice without paying for a coach.
- **How it's used:** Reached from Compass "Practice interview" / V2 You "Mock interviews & analytics" / V1 Profile stack.
- **Status:** V2-ACTIVE — but the **pipeline is different on each platform**:
  - **iOS:** uses `OpenAILiveManager.swift` (OpenAI Realtime API) according to the iOS code audit, with a token-vending backend endpoint. **However**, both the backend code and the project memory describe iOS as **Gemini Live**. This is a discrepancy to verify — see §6.
  - **Android:** Whisper STT → GPT-4o → TTS async pipeline. Audio recorded with `react-native-audio-recorder-player`, uploaded via signed S3 URL, processed at `/interviews/:id/process-answer`.
- **Status:** V2-ACTIVE on both, with the divergence above.

#### Interview Results + History + Analytics
- **Capability:** Per-session scorecard, full history list, aggregate analytics (`InterviewAnalyticsScreen` on Android marked V1-LEGACY).
- **Status:** Results + history V2-ACTIVE. Standalone analytics screen V1-LEGACY on Android (V2 You aggregates it).

---

### 2.6 Coding Drills

#### Drill request + briefing + input + submission
- **Capability:** Bite-sized coding exercises in three subtypes — **Prompt** (write a prompt to solve a task), **Bug Hunt / Verify** (find/fix bugs), **Decompose** (break a problem down). Briefing screen → input view per subtype → submit → poll → result with rubric bars + mastery delta.
- **Used for:** Daily skill-building between full capstones; trains meta-skills (prompting, debugging, decomposition).
- **How it's used:** Reached from V2 Home drill card, Compass "💻 Start a coding drill" chip, or V2 You-tab "Coding drills & practice".
- **Status:** V2-ACTIVE everywhere.

#### Calibration sequence
- **Capability:** First-use 4-bundle calibration that sets a baseline difficulty before recommending a daily drill.
- **Status:** V2-ACTIVE.

#### Daily quota gating
- **Capability:** "Done for today" card with the next-available time after the user finishes their daily drill.
- **Status:** V2-ACTIVE.

#### Mastery deep-dive (You tab)
- **Capability:** Per-meta-skill mastery axes (prompting, debugging, decomposition, refactoring), recent attempts list, "Take today's drill" gold button + "Practice another" picker.
- **Status:** V2-ACTIVE.

#### Drill grading (backend)
- **Capability:** Claude Haiku 4.5 grades Prompt/Verify/Decompose, Claude Sonnet 4.6 grades Refactor. BullMQ `drillGrader` worker. `/drills/:id/submit` returns 202 with `poll_url`.
- **Status:** V2-ACTIVE.

---

### 2.7 Coding Capstones (the newest, most differentiating feature)

#### Capstone library + brief
- **Capability:** Browse + filter by difficulty / role-track (SWE / DS / AI-ML).
- **Status:** V2-ACTIVE.

#### Preflight
- **Capability:** Anti-cheat banner + capstone brief + language + stack variant + time budget (60 / 75 / 90 min).
- **Status:** V2-ACTIVE.

#### Pair (the cross-device hand-off)
- **Capability:** Mobile shows a 6-digit code and QR. The user opens `scaleup-web-seven.vercel.app/capstone` on a laptop, enters the code, and the laptop becomes the coding surface. Mobile is the "command surface" (status, controls, heartbeats, pause/abort).
- **Used for:** Real-coding skill assessment that is hard to game — the candidate codes on a real keyboard while mobile preserves attestation/anti-cheat.
- **How it's used:** From Preflight → Pair → wait-for-pair polling → Live.
- **Status:** V2-ACTIVE. **Productionisation gap:** the laptop URL is a hard-coded Vercel preview URL, not a branded custom domain. Reads as not-yet-productionised.

#### Live session
- **Capability:** WebSocket-driven status / heartbeats / counters / paused-total / lifecycle events. ~10s heartbeats. Pause / Resume / Abort controls. Append-events stream (max 200 per call). Terminal run-in-sandbox via `@e2b/code-interpreter`.
- **Status:** V2-ACTIVE.

#### Result (six-dimension scorer)
- **Capability:** Detailed scorer analysis with `evidence_notes` ("Detailed analysis" in the UI, build 170+). Six-dimension Claude Sonnet 4.6 grading.
- **Status:** V2-ACTIVE.

#### Voice Reflection
- **Capability:** 60-second voice-reflection capture after the result; re-evaluated by backend.
- **Used for:** Forces metacognition + gives the scorer a second signal to update mastery.
- **Status:** V2-ACTIVE — but HIDDEN (only reachable post-result; no other entry point).

#### Replay
- **Capability:** Post-result analysis screen replaying the session.
- **Status:** V2-ACTIVE on both apps. (Worth confirming the result screen actually surfaces the Replay CTA.)

#### History (You tab)
- **Capability:** List of past capstones with retry CTA. iOS recently (build 172) replaced a `CapstoneStatsCard` with a plain nav row to match the You-tab list style.
- **Status:** V2-ACTIVE.

#### Compass Coder (AI pair-programmer inside coding)
- **Capability:** Chat / turn (tool-use loop) / resolve / budget — an AI pair-programmer that lives inside drills and capstones. Per-user daily token budget.
- **Status:** V2-ACTIVE backend (Claude Sonnet 4.6).

#### Coding admin dashboard (operator-side)
- **Capability:** Anchor drift (scorer vs. anchors agreement), human-review queue, cost summary (per-model LLM spend), recent sessions.
- **Status:** Backend ACTIVE; frontend admin HTML wiring of these views is unverified.

---

### 2.8 Notes

#### Note upload + AI artifact generation
- **Capability:** Upload a PDF / slide deck / image → backend runs OCR + AI summary + audio narration + mind map + flashcards + auto-generated quiz.
- **Used for:** Turn a user's study materials into a fully-featured study environment without manual effort.
- **How it's used:** Reached from Compass "Make a note" / V2 You "My notes & flashcards".
- **Status:** V2-ACTIVE. Backed by S3 presigned multipart upload + BullMQ `flashcardGeneration`, `mindMapGeneration`, `audioSummaryGeneration` workers.

#### Note reader
- **Capability:** Detailed reader with all generated artifacts — flashcards deck, mind map, audio summary playback, AI-generated quiz, reading-time tracking, like/save/share.
- **Status:** V2-ACTIVE. Reuses the older `NotesDetailView` / `NotesDetail` screens.

#### Flashcard study
- **Capability:** Spaced-repetition flashcard study deck with daily 09:00 IST review-reminder cron.
- **Status:** Engine V2-ACTIVE on iOS. On Android, `MyFlashcards` + `FlashcardStudy` are marked V1-LEGACY ("not in V2 surface") — the V2 redesign dropped the standalone flashcard browsing UI.

#### Mind map viewer
- **Capability:** AI-generated mind map of the note's structure.
- **Status:** Engine V2-ACTIVE. Standalone `MindMapScreen` (Android) marked V1-LEGACY.

#### Notes Requests (community demand board)
- **Capability:** A user posts a request for notes on a topic; others upvote, claim, fulfil. Sort by recent/popular, status badges.
- **Status:** V1-LEGACY on Android (explicitly dropped from V2 surface). On iOS the user-facing request entry isn't surfaced in V2 either, but the admin "Review Notes" queue is V2-ACTIVE. Backend routes are V2-ACTIVE.

#### Notes analytics (creator-facing)
- **Capability:** Per-note + aggregate views, reads, completion, engagement.
- **Status:** V2-ACTIVE backend. Standalone `NotesAnalyticsScreen` (Android) V1-LEGACY.

---

### 2.9 Daily Challenges & Live Events

#### Daily challenge
- **Capability:** Today's objective-relevant challenge pinned, "other challenges" list, leaderboard, share scorecard as image. Backend cron generates challenges + finalises daily/weekly rankings + sends streak reminders.
- **Used for:** Competitive social pressure + daily streak hook.
- **How it's used:** Reached from V2 Compass "Compete today" / V2 You "Daily challenges & competition" / V1 Home banner.
- **Status:** V2-ACTIVE everywhere.

#### Live events (scheduled live competitions)
- **Capability:** Lobby → scheduled start → session → results. Full lifecycle is cron'd Mon / Wed / Fri 19:30 → 20:20 IST: reminder → open lobby → start → safety-net completion.
- **Used for:** Real-time, scheduled cohort competition — strongest engagement primitive.
- **How it's used:** Today only surfaces inside Competition Hub. No standalone tab. No push prompt to nudge first-time discovery.
- **Status:** V2-ACTIVE backend; HIDDEN in the app — built but easily missed by new users.

---

### 2.10 Plan (the structured day)

#### V2 Plan Detail
- **Capability:** Per-week plan breakdown, milestone strip, full timeline, summary, weeks remaining, invested vs. estimated hours. Reshuffle skipped tasks.
- **Status:** V2-ACTIVE. Backed by `/api/v2/you/plan/detail`.

#### V2 Plan Home (Compass version)
- **Capability:** Slim cockpit (called from Compass "Plan my days").
- **Status:** V2-ACTIVE.

#### V1 Journey
- **Capability:** Multi-phase journey doc with milestones, weekly plans, pause/resume, dashboard, today/week views.
- **Used for:** Original V1 structured-day model.
- **Status:** V1-LEGACY. Backend routes still mounted; `runJourneyAdvancement` cron still runs daily; `Journey` model is still read by `/api/v2/you/overview` as a readiness fallback.

#### Recalibration (eligibility + re-take)
- **Capability:** Detect when a user is "due" for a fresh diagnostic, surface the offer, run a targeted recalibration. Daily cron seeds eligibility.
- **Status:** V2-ACTIVE engine; V2 surfaces it only through Compass-driven prompts. The legacy banner surface is V1-only.

---

### 2.11 Discover / Learn (open content library)

#### V2 Learn (App Store "Today" style)
- **Capability:** Inline search → editorial TODAY hero → themed "FOR YOUR {OBJECTIVE}" rails → MASTER YOUR #1 GAP path card → 5-MIN WINS → CONTINUE WHERE YOU LEFT OFF → "Explore the full library →" CTA (opens V1 Discover as a sheet).
- **Used for:** Pure objective-bound curation; nothing exploratory unless the user explicitly taps "Explore."
- **Status:** V2-ACTIVE on both apps.

#### Discover (open library)
- **Capability:** YouTube-style continuous feed — type chips (All / Videos / Notes / Articles / Infographics / Quick / Long), Top Creators strip, Trending This Week rail, infinite "For You" cards, search, filter chips (type, difficulty).
- **Used for:** Open exploration outside the goal-bound plan.
- **Status:** V2-ACTIVE as a sheet inside V2 Learn; V1-LEGACY as a standalone tab.

#### Recommendations engine
- **Capability:** Personalised feed, similar-content, objective-aligned, gap-filling, trending content + trending notes, "next actions" rail, post-quiz follow-ons.
- **Status:** V2-ACTIVE.

#### Audio summaries
- **Capability:** Generate (and fetch) a short audio summary of a content item.
- **Status:** V2-ACTIVE.

#### Content streaming
- **Capability:** Presigned S3 URLs with short TTL for video playback.
- **Status:** V2-ACTIVE.

---

### 2.12 Player + AI Tutor (legacy in-content AI)

#### Player (video / article / infographic)
- **Capability:** Video player with seek / speed / fullscreen / Up Next overlay, About / Comments tabs. Article + infographic equivalents.
- **Status:** V2-ACTIVE. Shared by V1 and V2.

#### AI Tutor sheet (per-content)
- **Capability:** In-content Q&A scoped to the current piece of content. Conversation persists per content item.
- **Used for:** Asking targeted questions about what the user is currently watching/reading.
- **Status:** V1-LEGACY surface — V2 routes the user to Compass Tutor mode instead. Backend `/api/v1/tutor/*` routes still mounted; `Conversation` history feeds V2 You-tab activity feed (the routes can't be deleted yet without rewiring history).

#### "Quiz on this?" post-completion prompt
- **Capability:** After completing a content item in V2, a prompt offers an auto-generated quiz on the topic.
- **Status:** V2-ACTIVE.

---

### 2.13 Social

#### Follow graph
- **Capability:** Follow / unfollow other users; view follower / following lists. New users auto-follow the ScaleUp admin account so their feed isn't empty.
- **Used for:** Building a creator-following layer + seeding cold-start feeds.
- **How it's used:** V2 You-tab header → tap counts → `FollowListSheet`. Creator profile pages have a Follow button.
- **Status:** V2-ACTIVE.

#### Creator profiles
- **Capability:** Public profile per creator with their content + follow CTA.
- **Status:** V2-ACTIVE (transitively reachable from Discover/Player).

#### Public profile + contributor card
- **Capability:** Public profile for any user; "contributor card" projection used in note/content attribution.
- **Status:** V2-ACTIVE.

#### Comments (on content)
- **Capability:** Post / edit / delete / reply / like comments on content, with pagination.
- **Status:** V2-ACTIVE.

#### Direct messages (DMs)
- **Capability:** None — no DM model, no routes, no UI on any platform.
- **Note:** Notable gap for an 18-25 community/learning app.

#### Circles (study groups)
- **Capability:** Was planned. Only file present is `Features/Circles/Views/TextSourceSheet.swift` on iOS with a comment header saying "Circles feature was never shipped."
- **Status:** DORMANT / never-shipped.

---

### 2.14 Profile / You tab

#### V2 You tab
- **Capability:** A single screen that bundles identity + history + every learning surface in one place. Sections: avatar + name + @username + bio + follower counts → Readiness ring (big % gauge) → stats block (This week, Streak, Top gap, Time invested) → **My Library** chip strip (Saved / Liked / Playlists / History) → **My Learning** rows (My objectives, My plan, Progress & analytics, My notes & flashcards, Mock interviews & analytics, Coding capstones & history, Coding drills & practice, Daily challenges & competition, My Compass activity, All my activities) → optional **Inference panel** ("How we're personalising for you" with thumbs-up/down) → role-gated **Creator Hub** / **Admin Tools** → Become-a-Creator card → Settings → footer.
- **Status:** V2-ACTIVE on both apps. The single largest screen in the V2 app (~1000+ LOC).

#### V2 You Analytics
- **Capability:** Quiz trend chart, mastery list (with level + trend + quizzes taken + last assessed), cognitive block (best time of day, preferred format, session style, learner type), activity entries, achievements grid.
- **Status:** V2-ACTIVE.

#### V2 Activities Detail
- **Capability:** Aggregate stats across quizzes, interviews, content, AI tutor; mastery map; strengths/weaknesses; cognitive insights.
- **Status:** V2-ACTIVE. **Note:** Android response shape is fully nullable — backend isn't always returning data.

#### Add Objective
- **Capability:** Type, exam name, target skill / role / company, timeline, current level, weekly hours.
- **Status:** V2-ACTIVE.

#### Objectives sheet
- **Capability:** List user's objectives; per-row Set Primary / Pause / Resume / Delete.
- **Status:** V2-ACTIVE.

#### Library sheet
- **Capability:** Tabs Saved / Liked / Playlists / History with 2-col grid.
- **Status:** V2-ACTIVE.

#### Edit Profile + Avatar crop
- **Capability:** Name, bio, avatar upload (JPEG/PNG/HEIC, 5 MB cap, audit-logged).
- **Status:** V2-ACTIVE.

#### V1 Profile tab
- **Capability:** Avatar/name, multiple objectives picker, role badge, liked/saved/history tabs, creator profile + application status, user inference panel.
- **Status:** V1-LEGACY on both apps. iOS keeps it mainly because it defines `FollowListSheet` that V2 still uses.

#### Compass History (covered in §2.3)

---

### 2.15 Notifications & Engagement

#### Push notifications
- **iOS:** Native APNs (no SDK like OneSignal or Firebase). Token registered with backend.
- **Android:** Firebase Cloud Messaging permission + cold-start / background-tap / foreground listeners. `plan_ready` deep-links to MyPlan. Limited deep-link wiring overall.
- **Backend:** Best-effort push with automatic FCM-vs-raw-APNs token detection; always also persists an in-app `Notification`.
- **Used for:** Re-engagement.
- **Status:** V2-ACTIVE. Categories: plan_ready, challenge_live, weekly_results, live_event_reminder, live_event_results, streak_reminder, social_comment, competition_results.

#### Streaks
- **Capability:** Current + longest streak surfaced on V2 Home (THIS WEEK card), V2 You (stat row), plan sheets. `streak_reminder` push. Daily streak reset cron at 01:30 UTC.
- **Status:** V2-ACTIVE.

#### Badges / Achievements
- **Capability:** Badge grid in V2 You analytics (earned vs. un-earned).
- **Status:** V2-ACTIVE.

#### Email
- **Capability:** Welcome email, password reset, account-deletion reminders (7-day + 1-day), Mixpanel daily digest, breach notification.
- **Status:** V2-ACTIVE backend (SMTP via nodemailer).

#### Coach marks + Welcome carousel (V1)
- **Capability:** First-launch onboarding overlay carousel, plus per-tab coach-mark popovers.
- **Status:** V1-LEGACY — V2 tab roots don't apply `.coachMark(...)`. Carousel only triggered from V1 `MainTabView`.

---

### 2.16 Search & Discovery

#### Search in V2 Learn
- **Capability:** Library search scoped to the user's content; fall-through "Search the full library" → Discover sheet with the same query pre-filled.
- **Status:** V2-ACTIVE.

#### Search in Discover
- **Capability:** Full-catalogue search with debounce, results list.
- **Status:** V2-ACTIVE.

#### Compass natural-language routing
- **Capability:** "Quiz me on graphs at hard difficulty" → Compass builds a config card → Start launches the quiz.
- **Status:** V2-ACTIVE (the primary discovery mechanism in V2).

#### College directory search
- **Capability:** Type-ahead lookup of Indian colleges/IIMs for the onboarding step.
- **Status:** V2-ACTIVE.

---

### 2.17 Settings & Account

#### Settings
- **Capability:** Account (email / phone / auth provider — read-only), Profile (member-since, role), App (dark mode hardcoded on iOS), Privacy & Data (Privacy Policy + Terms web views, **Download My Data** GDPR export), Danger (Log Out, Deactivate Account).
- **Status:** V2-ACTIVE.

#### Notification settings
- **Capability:** Per-category notification toggles (iOS). Android shows "Enabled" only with no granularity.
- **Status:** V2-ACTIVE.

#### Privacy / GDPR
- **Capability:** Self-service data export (Article 15+20) to JSON via share sheet; consent get/update/withdraw; self-service audit-log view; admin breach-notify endpoint. Legal docs served from static handler with version metadata.
- **Status:** V2-ACTIVE. **Note:** Privacy Policy + ToS are hardcoded in the route file (LAST_UPDATED = '2026-03-29') — no admin UI to update.

---

### 2.18 Creator Hub

#### Become a Creator
- **Capability:** Multi-step application — domain + specializations → experience + motivation → sample links + portfolio + LinkedIn / Twitter / YouTube / Website → Review / Submit. Shows pending / rejected status after submit.
- **Status:** V2-ACTIVE.

#### Creator Hub (role-gated)
- **Capability:** Tier header (rising / core / anchor) + stats strip (Content / Views / Followers / Rating), "Create Content" button, "My Content" library. Core/Anchor tiers also see "Review Applications".
- **Status:** V2-ACTIVE.

#### Create / Edit / My Content
- **Capability:** Multi-step form with thumbnail, video URL, type, difficulty, topics. Backed by presigned S3 multipart upload + BullMQ `contentProcessing` worker.
- **Status:** V2-ACTIVE.

#### Tier promotion (operator-side)
- **Capability:** Cron weekly (Sunday 00:00 UTC) promotes rising → core → anchor based on content count + rating + followers.
- **Status:** V2-ACTIVE.

---

### 2.19 Admin / Operator tools

#### Admin app surfaces (role-gated)
- **Capability:** Six in-app admin screens accessible from V2 You → Admin Tools: Dashboard, User Management (search/list/ban/unban), Creator Promotions, Content Moderation (reports queue), Creator Applications, Review Notes.
- **Status:** V2-ACTIVE on both apps.

#### Admin Dashboard (static HTML)
- **Capability:** `/admin/dashboard.html` (63-line HTML page served as static). API at `/api/v1/admin/*`: applications, user ban/unban, content moderation, creator listing + tier promotion, pending notes queue, platform stats.
- **Status:** V2-ACTIVE.

#### Diagnostic question moderation
- **Capability:** Pending question queue, stats, approve/edit/reject. Drives the `AdminQuestionDecision` model. Weekly Monday digest emails the queue state.
- **Status:** V2-ACTIVE.

#### YouTube ingestion (admin-only)
- **Capability:** Import a YouTube video / channel / playlist into the Content corpus. Backend pulls metadata, transcripts, re-hosts assets in S3.
- **Status:** V2-ACTIVE backend.

#### Competition admin
- **Capability:** Browse generated challenge candidates, approve, manually trigger daily generation.
- **Status:** V2-ACTIVE backend.

#### Coding admin dashboard
- **Capability:** Anchor drift, human-review queue, cost summary (per-model LLM spend), recent sessions.
- **Status:** V2-ACTIVE backend.

---

## 3. Cross-cutting capabilities (the platform plumbing)

### 3.1 AI / LLM stack

ScaleUp uses **three frontier LLM providers in parallel**, each for what it's best at:

| Provider | Model | Used for |
|---|---|---|
| **Anthropic** | Claude Opus 4.7 | Capstone content generation, reference-solving |
| **Anthropic** | Claude Sonnet 4.6 | Capstone scoring (6-dim), Compass Coder, refactor drill grading, post-interview evaluation |
| **Anthropic** | Claude Haiku 4.5 | Prompt / Verify / Decompose drill grading |
| **Anthropic** | Claude Sonnet 4 | Compass (every chat turn) |
| **OpenAI** | GPT-4o | Quiz generation, content processing, Android interview pipeline, mind map generation |
| **OpenAI** | Whisper | Voice answers (diagnostic + interview + capstone reflection), content transcription |
| **OpenAI** | TTS | Android AI Interview voice |
| **Google** | Gemini 2.5 Pro | Coding content cross-validation, hidden test generation |
| **Google** | Gemini Live | iOS AI Interview realtime streaming (per backend + memory; iOS code may differ — see §6) |

**Token budgeting.** Compass + Compass Coder both enforce per-user daily token caps (50k free / 200k pro placeholder). Redis-backed. **Pro tier is not wired to any subscription.**

### 3.2 Infrastructure stack
- **Hosting:** AWS EC2
- **Database:** MongoDB Atlas
- **Cache + queue:** Redis (with BullMQ)
- **Object storage:** AWS S3 (presigned URLs, multipart upload)
- **Sandbox:** e2b (`@e2b/code-interpreter`) — single provider, no failover today
- **Push:** Firebase Admin SDK for FCM (Android), raw APNs (iOS) — no OneSignal anywhere
- **SMS:** Twilio
- **Email:** SMTP via nodemailer
- **Analytics:** Mixpanel (server-side digest cron + client-side events)

### 3.3 Background workers (BullMQ)

Worker queues actually running: contentProcessing, quizGeneration, quizAnalysis, journeyGeneration, journeyAdaptation, youtubeImport, whisperTranscription, notifications, ocrProcessing, flashcardGeneration, audioSummaryGeneration, interviewEvaluation, planGeneration, drillGrader, contentGenerator, contentValidator, sandbox-gc, capstoneEval, capstoneFollowup, voiceReflection.

### 3.4 Scheduled jobs (cron)

| Time (IST unless noted) | Job |
|---|---|
| Sunday 18:00 | Weekly review quiz |
| Daily 00:00 UTC | Retention check |
| Daily 00:15 | Daily top-gap quizzes (3× 10-Q per active V2 user) |
| Daily 01:00 UTC | Quiz expiry |
| Daily 01:30 UTC | Streak reset |
| Daily 02:00 UTC | Account deletion (reminders + permanent purge) |
| Daily 02:30 | Cohort directory housekeeping |
| Daily 03:00 | Weekly auto-calibration |
| Monday 03:00 | Validator backfill |
| Daily 04:00 | Recalibration offer + Diagnostic health check |
| Daily 09:00 | Mixpanel daily digest email + Flashcard review reminders |
| Monday 09:00 | Admin question digest email |
| Daily 10:00 | Re-engagement push |
| Daily midnight | Journey week advancement (V1) |
| Sunday 00:00 UTC | Creator tier check |
| Mon/Wed/Fri 19:30→20:20 | Live event lifecycle |
| Daily | Competition: generate daily challenges, finalise daily/weekly rankings, streak reminders |

### 3.5 Analytics taxonomy
Client-side Mixpanel events fired on both apps cover: app/session lifecycle, activation funnel, content engagement, quiz / interview / note / flashcard / mindmap / audio-summary / AI-tutor events, C2O transitions, retention (streaks), competition, discovery (search / recs / objective-switched), errors (incl. `network_timeout`), diagnostic flow, plan flow, coding drills. **GA4 is not integrated server-side anywhere** (per the analytics plan, GA4 is web-only).

---

## 4. V1 fossils inventory (what's still in the codebases)

### iOS V1 fossils (per `LEGACY_V1.md`, removal scheduled 2026-06-15 → 2026-06-30)
- **V1 tab roots:** `MainTabView.swift`, `HomeView.swift` + `HomeViewModel`, `PlanTabView.swift`, `ProgressTabView.swift`, `ProfileTabView.swift` (1700 LOC — only `FollowListSheet` is reused).
- **V1 Onboarding:** `Features/Onboarding/Views/Steps/*`.
- **V1 Auth:** `LoginView.swift`, `RegisterView.swift` email path, `ForgotPasswordView.swift`.
- **V1 Journey:** `Features/Journey/Views/*` (MyPlan, Milestones, GenerateJourney, AddMilestoneSheet, ObjectiveBrief).
- **V1 Quiz browsing:** `QuizListView.swift`, `QuizDetailView.swift`, `QuizListViewModel.swift`.
- **V1 Discover orphans:** `ContentDetailView.swift`, `ExploreGridView.swift`.
- **V1 Plan components:** ~13 files under `Features/Plan/Views/Components/*`.
- **V1 Progress drill-downs:** `GapsView.swift`, `ConsumptionHistoryView.swift`, `TopicDetailView.swift`, `RecalibrationCard.swift`.
- **V1 Competition orphans:** `DailyChallengeCarousel.swift`, `CompetitionStatsSection.swift`.
- **Circles:** entire `Features/Circles/` — never shipped.
- **AI Tutor History:** `AITutorHistoryView.swift` — Compass History supersedes it.
- **GoogleSignIn SPM dependency** — declared but unused.
- **Coach marks + Welcome carousel infrastructure** — V2 doesn't wire them but `Core/CoachMarks/*` remains.

### Android V1 fossils
- **High-confidence dead (deprecated, dangling imports):** `PlaceholderScreen.tsx`, `MyPlanScreen.tsx`.
- **Live as V1 fallback, retire when flag flips everyone:** all of `screens/home/*` except shared ChallengeSession / Review / CompetitionHub, all of `screens/discover/*` except CreatorProfile, all `screens/plan/components/*`, all `screens/progress/*`, V1 `ProfileScreen` + `LegalPageScreen` + `AITutorHistoryScreen`, the dropped V2-Notes surfaces (`NoteRequests`, `CreateNoteRequest`, `NoteRequestDetail`, `NotesAnalytics`, `MyFlashcards`, `MindMapScreen`, `FlashcardStudy`, `NoteManage`), and `InterviewAnalyticsScreen`.
- **Not deprecated despite age:** all auth screens, all onboarding (V1 still runs for non-V2 users), all diagnostic, all services, slices, models, shared components, and `MainTabNavigator.tsx` itself.

### Backend V1 endpoints still mounted but with no obvious V2 consumer
- `/api/v1/journey/*` — V2 Plan replaced this; cron still runs daily; readiness fallback still reads `Journey`.
- `/api/v1/learning-paths/*` — no V2 surface consumes them.
- `/api/v1/social/playlists/*` — playlist CRUD; not in V2.
- `/api/v1/auth/register | login | google | forgot-password | reset-password` — V1 email/Google flows.
- `/api/v1/auth/phone/verify` — phone-link for already-authed email accounts.
- `/api/v1/tutor/*` — per-content AI Tutor. Overlaps with Compass `tutor` mode but routes can't be deleted yet because V2 You-tab activity feed still reads the legacy `Conversation` collection.
- Old `/api/v1/plan/*` routes (status, current, mastery, markTaskComplete) — V2 plan routes at `/api/v2/plan/*` are richer.

### Cleanup scope estimate
At rough count, roughly **40+% of iOS code and 35+% of Android code is V1-legacy still loaded**. The team has an explicit plan and date; the gating event is the server-side V2 flag rollout to 100% of users.

---

## 5. Hidden / dormant capabilities (built, not exposed)

Things shipped but most users will never find:

- **Capstone Voice Reflection** — 60-second voice capture re-evaluated by backend. Only entry point is post-result.
- **Capstone Replay** — fully-built post-result analysis screen on Android. Unclear if the result screen actually surfaces a Replay CTA.
- **User Inference panel** ("How we're personalising for you") — collapsible on V2 You; most users probably never expand it.
- **Download My Data** GDPR export — buried in Settings → Privacy & Data.
- **Compass Coach scope=topic free-text picker** — only appears after tapping "Topic" chip in Coach mode.
- **Live Events** — fully built backend + cron lifecycle, only surfaces through Competition Hub. No standalone tab, no first-time discovery push.
- **Reshuffle skipped tasks** — only appears in the "day_done" empty state on V2 Home.
- **CompanyProfile model** — exists in `src/models/CompanyProfile.js` with a test file. **No routes reference it.** Likely intended for TPO/college placement flow.
- **CohortDirectory** — has a service, daily housekeeping cron, and bootstrap script (`scripts/bootstrap-cohort-directory.js`). **No `/api/v1/cohort/*` routes mounted.**
- **TPO/college dashboards** — README references it. Only consumer-side surface in code is `/api/v1/colleges/search` for typeahead. No TPO-specific route group mounted in `app.js`.
- **Capstone admin dashboard backend** — `/api/coding/admin/*` (anchor-drift, human-review, cost-summary, recent-sessions) backend exists; admin HTML wiring unverified.
- **Compass `scope` field** on history — placeholder, not yet powered per-thread.

---

## 6. CPO critique — what's broken, redundant, divergent, or missing

### Broken / half-built
1. **Resume Builder is a dead chip.** Compass surfaces a "Build my resume" quick action on both apps that opens a "Coming soon" placeholder. The headline AI surface promises a feature it can't deliver. **This is the single most credibility-damaging gap on the platform right now.**
2. **V2 task types `mock_exam`, `reflection`, `notes_create`, `conversation`** (iOS `V2TaskRouter`) return `unavailable: "Coming next: dedicated <taskType> screen."` Backend may emit these; user hits a dead-end.
3. **Compass ConfigCardView "change ▾" affordance is misleading.** Code comment explicitly admits the field wasn't tappable; users must type free-form text to change a quiz field. Discoverability problem.
4. **Capstone laptop URL is a Vercel preview URL** (`scaleup-web-seven.vercel.app/capstone`). Hard-coded with Info.plist override on iOS. Reads as not productionised. Needs custom domain + branding before investor demos.
5. **Skip phone verification path** after email register sends user into onboarding with no phone on file; recovery is unclear.
6. **Notes Requests** contributor flow is in the codebase but the user-facing "Request notes on this topic" entry point isn't surfaced in V2.
7. **Compass coach-mode scope** chip on iOS isn't yet powered by real per-thread data — placeholder.
8. **V2 RealityCheck + Calibration Insights** screens on Android exist as files but appear not wired into `V2OnboardingFlow.tsx` — likely DORMANT despite iOS having them live.
9. **Android build config** ships `versionCode 1`, `versionName "1.0"`, debug signing on release, ProGuard disabled, no CI workflow. iOS has a real automated TestFlight pipeline; Android is a development build template.

### Redundant / duplicate
1. **Multiple capstone entry points** — iOS Home Capstone card + Compass "Coding capstone" chip → `V2CodingHomeView` + You-tab "Coding capstones & history" → `CapstoneHistoryView` + standalone `CapstoneLibraryView`. Four overlapping flows.
2. **Plan surface duplication** — V2 Home (plan cockpit) + V2 You "My plan" (`V2PlanDetailView`) + Compass "Plan my days" (`V2PlanHomeView`). All three render overlapping data.
3. **Quiz entry points** — Compass chip + Home plan tasks + You-tab navigation + Compass Quiz Home + post-content "Quiz on this?" prompt + Note → "Generate quiz". Six paths to the same engine.
4. **Settings access** duplicated on iOS V2 You — gear in header AND a Settings row at the bottom of the same screen.
5. **Two competition home surfaces** — `V2CompetitionHomeView` (Compass) and `CompetitionHubView` (You-tab) cover similar territory.
6. **Analytics overlap** — `V2YouAnalyticsView` + `V2ActivitiesDetailView` surface overlapping data shapes.
7. **Three drill request paths** — `V2CodingDrillRequestView` sheet, `V2CodingMasteryView` PracticeAnotherSheet, Compass action card.
8. **Two onboarding flows** (V1 6-step + V2 4-step) running on the same backend user model.
9. **Two AI Tutor histories** — V1 `AITutorHistoryView` + V2 `V2CompassHistoryView`. Same conceptual feature, two backends.
10. **Two upload pipelines into S3** — creator-gated content upload + open notes upload.

### Cross-platform divergence (iOS vs Android)
1. **AI Interview pipeline:** iOS = streaming realtime (the iOS code audit reported OpenAI Realtime via `OpenAILiveManager.swift`; backend + memory describe it as Gemini Live). Android = async Whisper + GPT-4o + TTS. **Investigation needed** — is iOS actually on OpenAI Realtime, did it migrate off Gemini Live, or is the backend route serving a different provider's token than the file name suggests?
2. **V2 onboarding completeness:** iOS wires Reality Check + Calibration Insights; Android has the files but the flow may skip them.
3. **Build / release maturity:** iOS has automated TestFlight (per the build-pipeline memo); Android has manual Gradle + debug signing on release builds.
4. **V1 surfaces dropped from V2 Android** that may still ship on iOS V1: Note Requests, Mind Map, Flashcard study, Notes analytics, Interview analytics. The V2 redesign is iOS-led; Android has caught up but at slightly different cuts.
5. **Push category coverage:** iOS handles 7+ notification categories with deep links. Android wires only `plan_ready` deep link explicitly.

### Notable platform gaps (for the positioning)
1. **Zero monetisation.** No paywall, no subscription, no payment provider, no entitlement model. Single TODO comment is the only revenue surface in code.
2. **No DMs / messaging.** For an 18-25 community/learning app this is a meaningful gap — peer chat, study-buddy chat, mentor chat are all absent.
3. **TPO / college dashboards** are promised in README but not built. CompanyProfile model + CohortDirectory cron exist; no API or admin UI surfaces them. If positioning includes "B2B2C via colleges," this is the biggest delivery gap.
4. **Circles (study groups)** never shipped.
5. **Resume Builder** is the most visible "promised but not delivered" feature today.
6. **Privacy Policy + ToS are hardcoded** in the route file with no admin UI to update.
7. **Compass scope-by-topic** is the kind of differentiated UX investors notice on demos — but discoverability is poor (you have to tap Coach → "Topic" chip → type a free-text topic).
8. **Phone-only auth is policy but email is still in code** — Welcome screen surfaces email login on both apps despite the documented decision.

---

## 7. Risk surface

### Single biggest dependency: Anthropic Claude
Used for: every Compass chat turn, every capstone scoring pass, every drill grading run, refactor grader, content generation, objective parser, diagnostic insights, plan generation, interview evaluation, knowledge-profile updates. **Outage = the product becomes a static notes/content app.** Cost surface scales linearly with active users (capstone Sonnet calls + Compass Coder turns + drill grading).

### OpenAI
GPT-4o (content processing, quiz generation, Android interview, mind maps) + Whisper (every voice flow). Outage = no new quizzes, no Android interview support, no voice flows.

### Google Gemini
Gemini 2.5 Pro for coding content cross-validation + hidden test generation. Gemini Live for iOS interview streaming. Outage degrades but does not kill interviews (per the backup plan, iOS falls back to Whisper+GPT-4o).

### e2b sandbox
**The only sandbox provider** for capstones. Comment notes "possibly Daytona later" — no failover today. If e2b goes down or hikes prices, the entire capstone product is offline.

### Twilio
SMS OTP. Outage = nobody can sign in or sign up on V2 (since phone-first is the V2 path).

### Infra
AWS S3 + MongoDB Atlas + Redis. Redis outage is partially mitigated (rate-limiter "fails open", Compass budget "fails open"), but BullMQ queues stop functioning — no quiz generation, no plan generation, no notifications.

### Rate limiter (per project memory)
`src/middleware/rateLimiter.js` is **still keyed on `req.ip`** (line 5: `` `${keyPrefix}:${req.ip}` ``). The earlier "all users behind nginx share one IP" lockout has been mitigated at the proxy layer (`app.set('trust proxy', 1)`), so today the proxy hands Express the real client IP and the per-IP limiter works for normal users. **However, users behind shared NAT (campus Wi-Fi, large ISPs) can still throttle each other.** The coding subsystem already uses a user-id-keyed `codingRateLimit.js`; the general middleware has not been migrated. This is the "real fix pending" state.

### Production-readiness gaps (per the "prod readiness bar" memo)
1. Capstone laptop URL on Vercel preview domain — not branded.
2. Android release build template (versionCode 1, debug signing, no CI) — not production-grade.
3. Resume Builder dead chip — promises a feature that doesn't exist.
4. V2 task types returning `unavailable` placeholders.
5. Privacy/ToS hardcoded with no admin UI.

---

## 8. What this audit suggests we brainstorm next

We agreed the next step is critique + brainstorm before touching the pitch site. Putting the strongest signals at the top:

1. **The Compass bet.** Compass is the single biggest UX bet in V2 — it replaces 11 fragmented V1 features. If users grok it, we have a defensible UX story for investors. If they don't, our whole V2 IA is in trouble. **What's the evidence we have today that users grok Compass?** What's the activation metric? What's the failure-to-discover-an-action rate?

2. **The Resume Builder credibility problem.** Today the most prominent AI chip on Compass leads to a "Coming soon" screen. Three options: (a) ship a real one in the next sprint, (b) hide the chip until we ship, (c) replace it with a lightweight "Resume polishing" tutor mode that uses Compass to give resume feedback on a pasted resume. Which is the right call given pitch timing?

3. **Monetisation strategy.** Zero revenue surface in the code. The 50k/200k token cap is the natural pricing primitive. **Do we ship a Pro tier before investor outreach, or do we pitch on growth/retention and treat monetisation as Series-A milestone?** This is a positioning call.

4. **The TPO/college angle.** README and stored data models hint at a B2B2C play through colleges that isn't built in any user-facing surface. **Is this part of our positioning or not?** If yes — what's the MVP we can ship in 4 weeks? If no — strip the references.

5. **Capstone as the demo headline.** Capstones are the freshest, most differentiating feature in the codebase. Six-dimension AI grading, cross-device hand-off, anti-cheat, voice reflection. **This is the strongest investor-demo story we have right now.** The Vercel preview URL needs to be replaced before any demo.

6. **Audience cut within 18–25.** The platform tries to serve placement-prep (SDE / case / HR), MBA admissions, upskilling, exam-prep simultaneously. Each is a different sub-segment of 18–25 with different willingness to pay and different distribution channels. **Are we calling our positioning on a single sub-segment for the pitch, or running a horizontal narrative?**

7. **Cross-platform reality.** Android has caught up on V2 but isn't production-grade. **Should investor demos show only iOS until Android is hardened, or is dual-platform parity part of the narrative?**

8. **Cleanup sequencing.** V1 fossils are ~40% of iOS and ~35% of Android. The team has a removal date (2026-06-30). **Should we ship the V1 removal before or after the pitch refresh / investor outreach?** Cleaner codebase = cleaner due-diligence answer.

9. **Hidden capabilities worth surfacing.** Live Events, Compass Coach scope-by-topic, Download My Data — built and good, basically invisible. Cheap wins for the demo narrative.

10. **The iOS interview pipeline mystery.** iOS audit reports OpenAI Realtime; backend audit + project memory both describe it as Gemini Live. We need to **verify which provider is actually being called in production** before any investor conversation — this is the kind of detail that gets caught in technical due diligence.

---

## 9. Capstone — updates since this audit (addendum, 2026-05-31)

This audit is a 2026-05-29 snapshot. In the two days since, the Capstone subsystem
gained a Phase-3 feature set, a UX consolidation, and a long fix-chain that took
on-demand generation from "always errored" to "provably working." Read §2.7 and
§6 together with this addendum.

### 9.1 On-demand Capstone Generator — now WORKING (was the headline gap)
- **Capability:** Any eligible learner pastes a job description (or topic) and picks
  difficulty (Auto / Easy / Medium / Hard); the platform builds a *bespoke* capstone.
  Two-step AI verification: **Claude Opus drafts → the reference solution is proven
  in a sandbox** (must pass every visible + hidden test; a corrupted copy must fail)
  **→ a second model (Gemini) reviews quality →** only then is it activated.
- **Status:** V2-ACTIVE, confirmed end-to-end (a server-side run reached `ready`,
  Gemini-approved). Open to all eligible learners; 5/hour per-user cap; deterministic
  language by track (SWE→JS, DS/AI→Python).
- **History (why it never worked before):** nine layered bugs were fixed —
  malformed `tools` payload (HTTP 400 `tools.0: Input should be an object`),
  4096-token output truncation, a validator `.lean()` crash, a 15s validation
  timeout that killed `npm install`, `--silent` hiding failures from the retry
  critique, validating the reference solution *without* the starter_repo (npm
  ENOENT on package.json), `NODE_ENV=production` skipping devDependencies (jest not
  found), no retry on the quality gate, and the model not always declaring its test
  deps. The two Gemini gates were then rebalanced to block only **genuine** defects
  (unsolvable / unfair hidden tests / internal contradictions / untested criteria)
  rather than stylistic nitpicks — so legitimate capstones pass while the sandbox
  proof still guarantees they actually run.

### 9.2 Async "submit & walk away" generation
- **Capability:** Generation legitimately takes ~3–5 min, so the learner can submit
  and leave. A push fires on completion (`CODING_CAPSTONE_GENERATED` /
  `CODING_CAPSTONE_GENERATION_FAILED`), and the Coding hub's Capstones tab shows a
  "Your generated capstones" strip (Building… / Start / Retry) via
  `GET /api/coding/capstones/generations`.
- **Status:** Backend V2-ACTIVE; iOS build 176.

### 9.3 Auto-assembled Capstone Tracks
- **Capability:** A per-learner, difficulty-ramping sequence (easy→hard, up to 5
  steps) auto-assembled from the learner's role-track, skipping already-graded
  bundles. Unlock-on-grade; self-heals past retired steps; one active track per user
  (partial-unique index).
- **Status:** V2-ACTIVE (backend + iOS/Android), surfaced in the Coding hub.

### 9.4 Recruiter / public share
- **Capability:** A learner mints a public, no-auth profile link from history showing
  **scores + competency only — no code, no full briefs, no PII beyond first name**.
  Revocable / expirable; invalid, revoked, and expired tokens all return an identical
  404 (no information leak). Web page is SSR + `noindex`.
- **Status:** V2-ACTIVE (backend + web profile page + iOS/Android share button).

### 9.5 Multi-language
- **Capability:** Capstone language support extended beyond JS / TS / Python / Java /
  SQL to **Go, Rust, Kotlin, Swift, C++** (bundle schema, evaluator lint + install
  steps, e2b template env-vars with graceful fallback, web Monaco mapping).
- **Status:** V2-ACTIVE. Locked-egress templates for the new languages still pending
  (need Docker) — they fall back to the default open-egress image today.

### 9.6 Mid-session crash recovery
- **Capability:** S3 snapshots let a dropped capstone session restore its files; the
  web IDE shows a recovery banner and offers to restore.
- **Status:** V2-ACTIVE (backend + web).

### 9.7 UX consolidation — the unified Coding hub
- **Capability:** One `V2CodingHubView` with **Practice | Capstones | Progress**
  segments (per-segment explainer copy). Practice = today's drill + recent drills;
  Capstones = track + start + generate + your-generations + history/share; Progress =
  the single mastery view.
- **Resolves prior issues:** §6 "Redundant / duplicate" **#1** (*Multiple capstone
  entry points* — the four overlapping flows) and **#7** (*Three drill request
  paths*). The You-tab's two coding rows are now one "Coding" entry; the Compass chip
  deep-links into the hub's Capstones segment. Also fixed: the "data couldn't be read
  because it is missing" crash on the coding home (an unstarted session serialized
  without `expires_at`), and stale never-started sessions blocking new starts (GC now
  reaps them).
- **Status:** V2-ACTIVE, iOS build 175.

### 9.8 Status changes to issues flagged above
- **§6 Broken #4 / §7 prod-readiness #1 — Capstone laptop Vercel preview URL:** the
  raw `api.scaleupapp.club` and the Vercel domain are now hidden behind Vercel
  rewrites; a branded custom domain remains the ideal end-state.
- **Start hang:** a warm-pool bug that handed out already-reaped (dead) sandboxes —
  surfacing as an endless "Setting up your sandbox…" — is fixed (age-eviction of
  stale warm entries + fall-through to a fresh provision instead of aborting).
- **§5 Hidden — Voice Reflection / Replay:** unchanged (still post-result only).

### 9.9 Builds
- iOS **175** (unified Coding hub) and **176** (async generation UX). Backend fully
  deployed (auto-deploy on push to `master`).

---

*End of audit. Last updated: 2026-05-29 (Capstone addendum 2026-05-31, §9).*
