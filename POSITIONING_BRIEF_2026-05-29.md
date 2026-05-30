# ScaleUp Positioning Brief — 2026-05-29

**Purpose:** Bridge between the [Platform Audit](PLATFORM_AUDIT_2026-05-29.md) and the next two operational tracks: (1) `scaleup-pitch-v2` deck rewrite, (2) personalised HNI / angel / early-stage-VC investor outreach.
**Status:** Drafted from the 2026-05-29 brainstorm. Awaiting user review.
**Audience:** CEO + CPO (you).

---

## 1. Locked positioning

| Element | Lock |
|---|---|
| **Category** | Outcome-based AI-coached learning platform |
| **Mechanism** | The C2O loop — Content to Outcomes |
| **Hero one-liner** | **India's first AI-graded outcome-based learning platform.** |
| **Hero sub-line** | Built on a C2O loop — measured, personalised, proven. |
| **Eyebrow** | C2O = Content to Outcomes |
| **Hero flow** | 10-min expert drops → AI grades your work → you prove you're ready. |
| **Lead persona (hero)** | Aisha → Product Manager (current PM narrative is kept) |
| **Parallel persona (added)** | Rohan → SDE landing (powered by the Coding Capstone) |
| **Engine** | Compass (unified AI surface) + Plan (multi-week personalised) + Diagnostic (adaptive) — *one engine, many goals* |
| **Moat** | Outcome data + creator network + multi-LLM cost ledger + cross-device assessment |
| **Ask** | ₹6 Cr SAFE, closing Nov 2026 |
| **Proof strategy** | **Product-led, not traction-led.** Lead with operator-grade build + live demo. Beta runs in the background. Numbers come later, in deep dive only. |
| **Outreach strategy** | Single wave to all three tiers (HNI / angel / early-stage VC) with the same product-led email, personalised per recipient. |

**What stays sacred from the original pitch:**
- C2O as the core mechanism — it is genuinely what the product does
- The 5-step loop (Learn → Assess → Gap → Fix → Prove) — accurate to the codebase
- The 3-pillar framing (Curated content / C2O loop / Outcome data as moat) — defensible
- The ask shape (₹6 Cr SAFE, 13-month plan, M12–15 Seed-readiness target)
- The creator-economy tier model (Anchor / Core / Rising with equity bands)
- The Why-Now thesis (AI cost collapse + trust vacuum post-BYJU's + creator-economy maturity)

**What changes:**
- The hero one-liner gets sharpened (`AI-graded` qualifier added — audit-defensible, differentiated)
- The proof strategy flips from traction-led to product-led
- The Coding Capstone story gets surfaced as a parallel persona to PM
- Compass gets elevated as the unified AI surface (was treated as discrete features)
- Beta numbers come out of the public deck and into the closed deep-dive (or get replaced)

---

## 2. The deck change list (scaleup-pitch-v2)

Mapped to actual files in `/Users/nirpekshnandan/My Products/scaleup-pitch-v2`.

### 2.1 KEEP AS-IS (audit-validated)

| File | Why it works |
|---|---|
| `components/sections/TheGapSection.tsx` | Sets up the C2O thesis |
| `components/sections/AIThesisSection.tsx` | Why-Now three-curve argument is defensible |
| `components/sections/PillarsSection.tsx` | 3 pillars hold up against the audit |
| `components/sections/C2OLoopSection.tsx` | Aisha-PM narrative + 5-step loop is accurate to the product |
| `components/sections/CreatorModelSection.tsx` | Tier model + economics are accurate to the code |
| `components/sections/MarketSection.tsx` | TAM thesis stands (no claim audit needs to refute) |
| `components/sections/AskSection.tsx` | The ₹6 Cr ask + use-of-funds breakdown is unchanged |
| `components/sections/TeamTractionSection.tsx` | Team narrative is independent of the audit; **but** drop any "traction" numbers that are aspirational |
| `components/deep-dive/CreatorModelSection.tsx` | Deep-dive creator economics audit-confirmed |
| `components/deep-dive/SWOTSection.tsx` | Honest framing, leave intact |
| `components/deep-dive/UnitEconSection.tsx` | Modeling stays — these are *projections*, clearly framed as such |
| `components/deep-dive/ValuationSection.tsx` | Pre-money / cap-table math is unchanged |
| `components/deep-dive/FinancialsSection.tsx` | Financial model is forward-looking, not a traction claim |
| `components/deep-dive/RoadmapSection.tsx` | Mostly accurate; one line to fix (see EDIT list) |
| `components/deep-dive/GTMSection.tsx` | Structure stays; numbers tagged as targets, viral-coefficient softened |
| `components/deep-dive/WhyNowExtendedSection.tsx` | Three-curve detail is accurate |
| `components/deep-dive/TechAISection.tsx` | Multi-LLM routing matches the audit; one specific edit on caching claim |

### 2.2 EDIT (specific claim-level fixes)

**`components/sections/HeroSection.tsx`**
- Line 73–76: change `India's first <span class="gold-text">outcome-based</span><br/>learning platform` → **`India's first <span class="gold-text">AI-graded outcome-based</span><br/>learning platform`** (single-word addition; minimal layout impact).
- Line 152: replace `Learn with purpose. Achieve your goals.` italic tagline with a sharper line, e.g., `From content to outcomes. From learner to ready.` (open to user preference here.)

**`components/sections/PillarsSection.tsx`**
- Line 61: refresh the competitive frame. Current: *"Coursera has content. Scaler has outcomes (SWE-only). PW has scale (exam cram). ChatGPT has AI."* Consider replacing PW (exam cram) with a 2026-current Indian competitor or adding Unacademy's AI pivot to the comparison. Audit doesn't tell us who's current — user judgement call.

**`components/sections/TheGraveyardSection.tsx`**
- Review for any specific competitor claims that may have aged out since April 2026.

**`components/sections/MonetizationSection.tsx`** + **`SLIDE: HOW WE EARN`** in `docs/pitch-v2/01_main_deck_slide_copy.md`
- Add a clear "Launches M3 / M6 / M9" tag to each of the four revenue streams. Current copy already has "Launch" column in the table — verify the public-facing component renders this clearly so investors don't mistake the streams for live revenue.

**`components/deep-dive/RoadmapSection.tsx`** + Roadmap table in `docs/pitch-v2/02_deep_dive_structure.md`
- Phase 4 (M10–M13) — `"Android parity push"` is wrong framing. Android is already largely feature-parity (V2 redesign merged 2026-05-18). Replace with `"Android production hardening (CI, release signing, ProGuard, Play Store launch)"` — audit-truthful.
- Phase 4 (M10–M13) — `"Hindi UI"` claim: either commit to it as a real build (no i18n infrastructure today) or remove. User judgement.

**`components/deep-dive/TechAISection.tsx`** + Tech detail in `docs/pitch-v2/02_deep_dive_structure.md`
- Verify the `"Aggressive prompt caching (40% hit rate target)"` claim. The audit didn't find explicit prompt-caching infrastructure called out. Either the cache is implicit in the SDK, or this is an aspirational engineering goal. Mark as "target" if not currently in production.
- The voice interview line is accurate: `"Whisper + OpenAI Realtime → voice interview pipeline"` matches the iOS audit. (Side note: this also resolves a stale memory file — iOS is on OpenAI Realtime, not Gemini Live as the older project memory suggested. Update memory.)

**`app/page.tsx`** + section ordering
- Consider inserting a **"What's live today"** section directly under the C2O Loop section. Contents: Compass screenshots, Capstone scoring screenshot (with the `evidence_notes` "Detailed analysis" output), Plan cockpit, Diagnostic insights. This is the audit-confirmed product surface and the strongest pre-traction substitute for outcome numbers. Pulls weight that the removed Testimonials section was carrying.

### 2.3 REWRITE (full-section)

**`components/sections/C2OLoopSection.tsx`** — *partial extension*
- Keep Aisha-PM as the primary narrative (locked in brainstorm).
- Add a second persona card under the existing one: **Rohan, B.Tech Year 3, wants SDE at a top product company.** Walk the same 5-step loop with a coding flavour:
  - Learn → 10-min Anchor practitioner drop on "Designing for scale" by an ex-Flipkart engineer
  - Assess → AI-generated coding drill (Prompt / Verify / Decompose) with mastery axes feedback
  - Gap → Skill map shows weak on "system design tradeoffs" and "production debugging"
  - Fix → Targeted drills + a watch-list of 3 Anchor videos
  - Prove → **Coding Capstone** with cross-device pairing (mobile + laptop), 6-dimension AI grading (correctness, code quality, system design, edge cases, communication, time management), `evidence_notes` ("Detailed analysis") output the candidate can share with a recruiter
- Visual treatment: two compact persona panels side-by-side, or one larger Aisha panel with a smaller Rohan panel below as the "and it works for SDEs too" expansion.

**`components/deep-dive/OutcomesSection.tsx`** — *full replacement*
- Current: Before/after Readiness curves, retention curves, NPS, viral coefficient. **All of these are aspirational.**
- Replace with **"How we grade your work"** section:
  - The Readiness Score formula (keep — it's a real implemented mechanism, not a claim about user behaviour)
  - The 6-dimension Coding Capstone scorer (with rubric explanation)
  - The mastery-axes model for coding meta-skills (prompting / verify / decompose / refactor)
  - The Compass token-budgeted AI orchestrator (free 50k / pro 200k token caps)
  - The daily top-gap quiz cron (00:15 IST personalisation as a service)
  - The multi-LLM routing diagram with cost-ledger discipline
- Frame: *"We measure what learning platforms refuse to measure — and we built the machinery to do it at scale before we had a single paying user. Closed beta launching [date]; cohort outcome data follows."*

**`components/deep-dive/TestimonialsSection.tsx`** — *full replacement*
- Current: 4 testimonial cards with named quotes (Aarav, Riya, Shaurya, Meera) and the framing line *"We launched closed beta 4 weeks ago with 100 invited learners..."*. **Per the brainstorm, beta is still in flight or these are aspirational.**
- Replace with **"What's already shipped"** — a product-walkthrough section:
  - Screenshot: V2 Home plan cockpit with the Readiness trajectory
  - Screenshot: A graded Coding Capstone result with `evidence_notes`
  - Screenshot: Compass quick-action chips + a sample conversation
  - Screenshot: Diagnostic insights / Reality Check
  - Screenshot: Creator Hub with tier badge + content library
  - Short caption per screenshot — what it is, what it does
- Closing line: *"Closed beta opening [DATE]. Demo available on request."*

**`components/sections/MonetizationSection.tsx`** *and* the slide copy
- Soften any phrasing that implies the four revenue streams are live today. They are *launch-dated*. The deck already has dates in the table; just verify the section component renders those dates prominently so investors don't misread.

### 2.4 ADD (new content)

**New section: "What's live today" — between C2O Loop and Pillars**
- Compass demo strip (3 chips → 3 outcomes: quiz / interview / capstone)
- Live Capstone evidence_notes example
- Plan cockpit screenshot
- Daily-cron personalisation explainer
- Single line: *"This is the operator-grade build. Beta opens [DATE]."*

**New section in deep-dive: "Cross-device Capstone — the assessment moat"**
- The mobile-as-command-surface + laptop-as-coding-surface pairing
- 6-dimension AI scorer + voice reflection re-grader
- The anti-cheat preflight pattern
- Why this is hard for incumbents to copy (requires sandbox + multi-device sync + Compass-Coder agent + LLM cost discipline)

### 2.5 KILL / DEFER

- **Any quote attributed to a named beta user (Aarav / Riya / Shaurya / Meera) currently on the site.** Pull immediately. If real, frame them as "early-tester feedback (anonymised on request)"; if synthetic, remove.
- **Specific viral coefficient `1.4`** in `GTMSection.tsx`. Replace with channel-mix hypothesis (creator-pull 45% / ambassador 25% / paid 30%) and CAC bands. Reintroduce viral coefficient after beta has a measured one.
- **"+34 Readiness Score lift" / "73% completion (vs 6% industry)" / "D7 64% / D30 47%" / "NPS 52"** — pull from the public deck. Move to internal-only deck used in scheduled meetings, with appropriate caveats.

---

## 3. Investor email template (one master, personalised per recipient)

### Subject line — 4 variants to A/B

1. `ScaleUp — India's AI-graded learning platform (20-min demo?)`
2. `We built a six-dimension AI grader for coding capstones`
3. `Pre-seed: India's C2O learning platform for 18–25`
4. `[Mutual connection / past project]: would love your read on ScaleUp`

(#4 is the personalised hook for warm intros. #2 is the strongest hook for technical investors. #1 is the safe default.)

### Master email body (≈140 words)

> Hi [Name],
>
> I'm Nirpeksh, founder of ScaleUp — **India's first AI-graded outcome-based learning platform** for 18–25-year-olds prepping for product, SWE, MBA, or competitive-exam tracks.
>
> Most learning apps give you content. We give you a personalised plan, a unified AI coach (Compass), and AI-graded proof you're ready — including six-dimension grading on real coding capstones with cross-device hand-off. Built end-to-end on iOS + Android + a Node/Mongo/AWS backend with multi-LLM routing across Anthropic, OpenAI, and Google.
>
> Raising ₹6 Cr SAFE — closing Nov 2026 — to launch payments, cohorts, and four verticals (PM / Entrepreneurship / AI-Coding / CompExam). Closed beta opens [DATE].
>
> **[ONE personalised line — see below.]**
>
> Worth a 20-minute demo? I can come to you on Calendly: [link]. Deep dive (full financials, roadmap, tech): [link to pitch site].
>
> Best,
> Nirpeksh
> [phone] · [LinkedIn]

### The personalisation line (the part you'll feed me)

Every email gets **one** sentence above the CTA that's specific to that investor. Format depends on what we know about them:

- **Thesis match:** *"Saw your recent post on [thesis] — ScaleUp lines up tightly with [specific element]."*
- **Portfolio company adjacency:** *"You backed [Company X], which we share a wedge with on [angle]; we go deeper on the outcome-grading side."*
- **Operator background:** *"Your time as [role at company] is exactly the lens I'd want on our creator-economy build — would value your read."*
- **Recent Tweet / talk:** *"Your point on [recent take] is the exact gap we're attacking with [feature]."*
- **Mutual connection:** *"[Person] suggested you'd be a useful first read on this — they've been giving us early feedback."*

**Operational pattern:** when you (CEO) send me a batch of investor names + emails + LinkedIn, I'll generate the personalisation line per recipient based on what's public + what you tell me about the relationship. We don't send the master without it.

---

## 4. Beta-in-parallel plan

Per the brainstorm: outreach starts now; beta runs invisibly. But beta still needs to happen — VCs who say "we'd like to see a few weeks of data" need an answer in 4–6 weeks.

### Beta shape (recommended scope)

| Element | Lock |
|---|---|
| **Size** | 80–120 invited users (manageable cohort for clean data) |
| **Channels** | DJ Sanghvi network + IIT Bombay network + existing creator audience + ambassador-led campus pull |
| **Personas** | 40% PM-bound, 40% SWE-bound (Coding Capstone is the strongest demo asset for them), 20% MBA/exam |
| **Duration** | 4 weeks (matches the original "+34 Readiness lift in 4 weeks" claim shape, so when we publish, the framing is consistent) |
| **Key metrics instrumented** | Day-1 → Day-28 Readiness lift · Weekly completion · D7 / D30 retention · Capstone start-to-finish rate · Compass turn count per active user · NPS at Day-14 · Referral coefficient (tracked via invite codes) |
| **Owner** | (User to decide — likely founder-led, with the Mixpanel daily digest as the source of truth) |

### Operational guardrails
- **Mixpanel daily digest is already crontabbed at 09:00 IST** and emails the founder. Use it as the source of truth for the email-able numbers — don't compose ad-hoc.
- **Set the beta launch date this week.** Even if it's "in two weeks", having a specific date means cold emails can say "Closed beta opens [DATE]" with credibility.
- **Pre-write the "beta concluded, here's what happened" deep-dive update** before beta ends so we publish 24–48 hours after it concludes.

---

## 5. Outreach plan structure

### Target list segmentation (you give me names, I personalise)

| Tier | Target count Wave-1 | Conversion expectation | Email shape |
|---|---|---|---|
| **HNIs** | 20–30 | 10–20% reply | Lighter on tech, heavier on team + market thesis |
| **Angels (operator)** | 20–30 | 20–30% reply | Heavier on product build + Capstone demo + creator economy |
| **Early-stage VCs (micro-VC)** | 10–15 | 30–40% reply | Heavier on category + moat + cap table + ARR forecast |

Total Wave-1: ~60 personalised emails. At a 20% blended reply rate that's 12 conversations. At a 30% meeting-to-soft-commit rate that's 3–4 soft commits — enough to close ₹6 Cr if cheque sizes average ₹50–75 lakh.

### Cadence

- **Day 0:** Send personalised email + LinkedIn connect request (don't message on LinkedIn yet — the email is the open).
- **Day 4:** If no reply, follow up with a one-line nudge attaching one new artifact (e.g., a Capstone evidence_notes screenshot).
- **Day 10:** If still no reply, accept silence as no. Don't pursue further.
- **Reply received:** Reply within 4 hours, lock the meeting within 48 hours, send the deep-dive link.
- **Meeting booked:** Send a one-page pre-read (compressed deck slice) 24 hours before the call.
- **Post-meeting:** 48-hour thank-you with one specific follow-up artifact the investor asked for.

### What I'll generate per email batch you send me

1. Personalisation line per recipient (based on LinkedIn + public profile + your context)
2. Subject line variant selection per recipient
3. The one-line pre-read sentence for the deck link
4. A short "what to expect in their reply" briefing — pattern-match to their portfolio / past comments

### What you'll need from me (CEO)

1. The investor list with: name, email, LinkedIn, current role, fund/family-office, any prior interaction
2. Any private context that should colour the personalisation (e.g., "we met at X event", "they backed Y which is adjacent", "they passed on our seed round at Z previously")
3. The beta launch date (so the email line "Closed beta opens [DATE]" is real)
4. The pitch site URL once the deck rewrite ships
5. A current Calendly link for the 20-min demo

---

## 6. Open items / decisions deferred

These didn't block the brief but should be addressed in the deck-rewrite pass or in the next brainstorm round:

1. **Resume Builder** — Compass surfaces a "Build my resume" chip on both apps that opens "Coming soon." Decide: (a) ship a real one before any investor demo, (b) hide the chip until shipped, (c) replace with a Compass-tutor resume-feedback flow. **Affects:** what we show in the demo.
2. **Capstone laptop URL** — currently hard-coded `scaleup-web-seven.vercel.app/capstone` (Vercel preview domain). Must be a branded subdomain (e.g., `code.scaleupapp.club`) before any investor sees a live capstone demo.
3. **Email auth in code, phone-first in policy** — Welcome screen on both apps still surfaces "Sign in with email" even though the documented auth policy is phone-only. Cosmetic for the pitch; substantive for the founder's diligence answer. Decide: rip out the email surface or update the policy to "phone-first, email as secondary."
4. **TPO / college B2B2C angle** — README hints at it; backend has scaffolding (CompanyProfile model, CohortDirectory cron) but no UI/API. If this is part of the pitch, build a one-page mockup. If not, strip references.
5. **4-vertical content readiness** — pitch claims M1 launch of PM + Entrepreneurship + AI-Coding. Audit shows the *infrastructure* is general-purpose but no vertical-specific content (Anchor practitioners, branded paths, vertical-tuned diagnostics) exists yet. Acceptable as roadmap; needs an honest one-liner in the deck about content vs. infrastructure readiness.
6. **The competitive-quadrant refresh** — current frame (Coursera / Scaler / PW / ChatGPT) feels 2024-era. User judgement call on whether to refresh comparators now or in a Q3 refresh.
7. **Hero tagline replacement** — `Learn with purpose. Achieve your goals.` is soft. Brief proposes `From content to outcomes. From learner to ready.` — user can refine.

---

## 7. Approval gate

This brief is the source-of-truth for the next two operational tracks. Before I move on to either, I want your sign-off:

- ✅ / ❌ The locked positioning (§1)
- ✅ / ❌ The deck change list (§2) — particularly the KILL list (§2.5), since that's the most consequential
- ✅ / ❌ The investor email template (§3)
- ✅ / ❌ The beta-in-parallel plan (§4)
- ✅ / ❌ The outreach plan structure (§5)

Once you sign off (or push back on specific sections), the next step splits in two: **(A)** execute the deck rewrite against §2 in `scaleup-pitch-v2`, and **(B)** start receiving investor batches from you for personalisation per §3 + §5.

---

*End of brief. Drafted 2026-05-29 from brainstorm; awaiting CEO/CPO review.*
