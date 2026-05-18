# ScaleUp — Product Requirements Document
**Version 2.0 — Complete Rebuild Specification**

---

## How to use this document

This is a complete, ground-up specification for ScaleUp v2. Read it linearly the first time. Reference sections individually afterward. Sections are numbered for citation.

The document is intentionally exhaustive. It assumes you are designing the product from scratch but may leverage existing code where useful. It does not cover funding, marketing, hiring, GTM, or business operations — only product development.

The document is structured to be readable by both humans and AI. Hand it to a UX designer, an engineering lead, or another AI chat for design work, and they should be able to extract enough specificity to act.

**v2.0 changes from v1.0:**
- Home screen is activity-focused (multiple recommended activities), not single-task-focused
- Tab structure: Home / Learn / Compass / Profile (Compass replaces Practice)
- AI companion named: **Compass**
- Pre-populated objective taxonomy database
- Required time computed from objective (not asked from user)
- Customized assessment by objective type
- Rich diagnostic insights (calibration gap, behavioral patterns)
- Don't-wait-for-plan homepage UX
- In-content Q&A saved to Compass history
- Full context across all AI interactions
- Guardrails on conversational AI
- Creator content creation in Profile → Creator Hub

---

# Part I — Strategic Foundation

## 1. Product Vision

**One-sentence vision:** ScaleUp diagnoses where a learner is, builds an AI-personalized plan to where they need to be, and proves they are ready — measurably.

**One-paragraph vision:** ScaleUp is a mobile-first AI-personalized learning platform for Indian learners aged 18-25 working toward measurable career outcomes (placement, career switch, interview readiness, competitive exams, upskilling). The platform combines three things almost no edtech currently combines: adaptive diagnostic that produces a real plan, AI-generated personalized content the user actually owns, and a readiness score that compounds into a credential employers can eventually trust.

## 2. Core Thesis — Content-to-Outcome (C2O)

Most learning platforms optimize for engagement (watch more videos, take more quizzes, build streaks). ScaleUp optimizes for *outcome* (did the learner actually reach their stated goal?). Every product decision is filtered through one question: does this move the user measurably closer to their objective?

The C2O loop:
1. User declares an objective with a target timeline
2. System computes the time commitment required
3. Diagnostic establishes baseline (customized to objective type)
4. AI generates a personalized plan
5. User consumes content and completes activities from the plan
6. Auto-generated quizzes verify retention immediately after consumption
7. Plan recalibrates weekly based on real performance signals
8. Readiness score increases as objective is approached
9. Outcome (placement, switch, exam result) closes the loop and feeds the credential moat

Everything in this PRD serves the loop. Features that don't strengthen the loop are deferred or killed.

## 3. Positioning Statement

**For** learners aged 18-25 in tier 2/3 colleges and early-career professionals in India  
**Who** want to achieve specific, measurable career outcomes (placement, career switch, interview readiness, competitive exams)  
**ScaleUp is** an AI-personalized learning platform  
**That** diagnoses your starting point, builds an adaptive plan to your goal, walks you through varied daily activities with AI-personalized content and practice, and proves your readiness  
**Unlike** content libraries (Coursera, Udemy), short-form learning (Seekho), generic AI tutors, or social learning platforms (failed: Bluelearn)  
**Our product** is the only one that ties personalized content generation, adaptive planning, AI practice, and outcome measurement into one verified system.

## 4. Target Segments

### Primary Segments

**Segment A — College Placement (18-22)**
- Status: Final-year or pre-final-year engineering students in tier 2/3 colleges
- Pain: Placement deadline approaching, unsure of readiness, fragmented content, no plan
- Surfaced objective: "Get placement-ready"
- Sub-objectives: SDE prep, PM prep, Consulting prep, Analytics prep, Generic placement prep
- Buyer: Often the college (B2B2C) or parent; user is the student
- Urgency: High (seasonal, August-March placement window)

**Segment B — Career Switch (22-25)**
- Status: 1-3 years into first job, considering switching role/company/domain
- Pain: Unclear path, no structured prep, busy schedule, high stakes
- Surfaced objective: "Make my next career move"
- Sub-objectives: Service-to-Product, IC-to-Manager, Domain switch, Big Tech prep
- Buyer: Self
- Urgency: Medium (window-driven)

**Segment C — Interview Readiness (22-25)**
- Status: Actively job-hunting, interviewing at specific companies
- Pain: Need targeted preparation for known interview processes
- Surfaced objective: "Crack interviews at [specific company/role]"
- Buyer: Self
- Urgency: High (interviews scheduled)

**Segment D — Competitive Exam Prep (18-25)**
- Status: Preparing for CAT, GATE, GRE, GMAT, UPSC, banking exams, government exams, NEET (where applicable)
- Pain: Vast syllabus, no personalization in current options, high stakes
- Surfaced objective: "Crack [specific exam]"
- Buyer: Self or parent
- Urgency: High (exam dates fixed)

**Segment E — Upskilling (22-25)**
- Status: Working professional, wants to add specific skills (AI/ML, cloud, data engineering, etc.)
- Pain: Need structured learning path that fits around their job
- Surfaced objective: "Master [specific skill]"
- Buyer: Self
- Urgency: Low to Medium

### Secondary Stakeholder Segments

**Segment F — Training & Placement Officers (TPOs)** — B2B buyer at colleges; web dashboard
**Segment G — Creators** — Industry experts, educators, recent placements; mobile + web tools
**Segment H — Admins** — ScaleUp's internal team; admin web panel

## 5. What ScaleUp Is — What ScaleUp Is Not

**ScaleUp IS:**
- An outcome-driven personalized learning platform
- Mobile-first (consumer surface)
- AI-native (content generation, plan adaptation, conversational AI, automated assessment)
- A B2B SaaS for college TPOs (secondary surface)
- A measurement engine (readiness score)
- Multi-objective per user

**ScaleUp IS NOT:**
- A YouTube curation app
- A social learning platform (no global social graph, no public posting feed)
- A creator marketplace (creators are an acquisition channel; tier system exists for credibility)
- A short-form edutainment app
- A community-only platform
- A jobs board (hiring features are Phase 4+; output of readiness scores, not a separate market)
- A general consumer learning app (career outcomes, not hobbies)

---

# Part II — Design Principles

## 6. The Seven Design Principles

These principles override individual feature decisions. When a tradeoff is unclear, return to these.

**Principle 1 — Activity-focused, not task-restrictive**  
The home offers a varied palette of plan-aligned activities (content, quizzes, interviews, reflection, notes). The user picks what fits their mood, energy, and available time. The system recommends; it does not restrict.

**Principle 2 — The plan is the spine, not the cage**  
Every activity surfaced is plan-aligned. The plan determines what's relevant; the user determines what to do right now from that relevant set.

**Principle 3 — One Compass, not eleven AI features**  
All AI capabilities live under a single named companion (Compass) with contextual modes. The user develops a relationship with one entity.

**Principle 4 — Objective is the universal lens**  
Every screen reminds the user of their active objective. Readiness score is always visible. Users with multiple objectives can switch but always see one active at a time.

**Principle 5 — Progressive disclosure**  
A Day-1 user sees less. A Week-4 user has unlocked more. The platform's depth is revealed over time as progression, not loaded onto the new user as overwhelm.

**Principle 6 — Outcome posture, not engagement posture**  
Streaks and competitions exist but are quiet. They never overshadow the plan or readiness score. Daily engagement is a consequence of progress.

**Principle 7 — Transparent, not hidden**  
Users know when content is AI-generated, when scores are estimated, when curation is editorial. Trust is built by honesty about how the system works.

## 7. Progressive Disclosure Model

| Day | What's unlocked | Activity count on Home |
|---|---|---|
| Day 1-3 | Home, Learn (basic), Compass tutor mode | 2-3 activities |
| Day 3-7 | Compass tab (Quiz Me, Notes, Ask Compass), Profile basics | 3-4 activities |
| Day 7-14 | Profile deep-view (Progress drill-down), Creator following | 4-5 activities |
| Day 14-21 | AI Interview practice | 5-6 activities |
| Day 21-30 | Compete features, cohorts, multi-objective | 5-6 activities |
| Day 30+ | Full feature set | 5-7 activities |

Power users can override progressive unlock via Profile → Settings → App Preferences → "Show all features now."

## 8. Outcome-First, Engagement-Second

**Outcome-aligned features** (always promote): Plan execution, AI practice, diagnostic recalibration, readiness score, objective milestones, real outcome tracking.

**Engagement features as side effects** (allow but don't promote): Streaks (quiet indicator), event-based competitions (opt-in), cohort interactions (organic), creator follows (passive).

**Engagement features as anti-thesis** (never build): Always-on global leaderboards, infinite-scroll feeds, follow/like dopamine mechanics as primary surface, streak-loss panic notifications.

---

# Part III — Information Architecture

## 9. Surface Map

**Mobile App (iOS + Android)** — Primary consumer surface. All learner-facing features. Built on existing React Native codebase.

**Web Surface 1 — TPO Dashboard** — B2B college admin. Roster, mock exam upload, cohort analytics, reporting.

**Web Surface 2 — Creator Hub Web** — Desktop creator tools for content production, deep analytics, audience management.

**Web Surface 3 — Coding Evaluation (Phase 2)** — Ephemeral web sessions for coding assessments.

**Web Surface 4 — Admin Panel** — Internal ScaleUp team.

## 10. Mobile App Information Architecture

The mobile app has exactly four tabs, one persistent FAB, and one always-visible header element.

```
┌─────────────────────────────────────────────┐
│  🎯 [Active Objective] · [Timeline]  ⋮ 🔔   │  ← Objective pill + menu + notifications
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│              [ Tab Content ]                │
│                                             │
│                                             │
│                                  ┌────┐     │
│                                  │ 🧭 │     │  ← Compass FAB (always present)
│                                  └────┘     │
├─────────────────────────────────────────────┤
│    🏠       📚       🧭       👤            │
│   Home     Learn   Compass  Profile         │
└─────────────────────────────────────────────┘
```

**Header:**
- Objective pill (left): Active objective + timeline. Tappable to switch or manage objectives.
- Menu (middle-right): Three-dot menu for screen-specific actions.
- Notifications (right): Bell only appears when actionable item exists.

**Tabs:**
- **Home** — activity-focused daily palette
- **Learn** — content discovery (pull-based)
- **Compass** — all AI features in one place
- **Profile** — progress + plan + analytics + settings + creator hub

**Compass FAB:**
- Always visible across all tabs and screens
- Contextual mode based on current screen
- Tapping opens Compass in a slide-up sheet (keeps user oriented)

## 11. Cross-Surface Navigation

**Creator users:** "Creator Hub" entry inside Profile tab. Full creator tools on web.
**Admin users:** "Admin" entry inside Profile (RBAC-gated, invisible to others).
**TPO users:** Web dashboard only. No TPO mode in mobile app.

---

# Part IV — Objective Taxonomy & Pre-Populated Database

## 12. Objective Taxonomy — Overview

The objective taxonomy is a pre-populated, structured database that captures what users will most commonly want to work toward. This avoids LLM round-trips for the 95% common case and only invokes LLM expansion for genuine novelty.

The taxonomy is curated by the ScaleUp content team and refreshed quarterly.

## 13. Objective Taxonomy — Top-Level Structure

**Top-level objective categories:**
1. Campus Placement
2. Career Switch
3. Interview Preparation
4. Competitive Exam
5. Upskilling

Each top-level category has a curated subset of options below.

## 14. Pre-Populated Data — Campus Placement

**Target role families:**
- Software Development Engineer (SDE)
- Product Manager (PM)
- Data Scientist / Analyst
- Consulting Analyst
- Investment Banking Analyst
- UX / Product Designer
- Business Analyst
- Marketing / Brand
- Generic Placement (any role)

**Target companies (pre-populated tier 1 list):**
- Tech: Google, Microsoft, Amazon, Apple, Meta, Adobe, Oracle, Salesforce, Atlassian, Stripe
- Indian Tech: Flipkart, Razorpay, Swiggy, Zomato, Paytm, PhonePe, CRED, Zerodha, Groww, Meesho, Nykaa, ShareChat
- Consulting: McKinsey, BCG, Bain, Deloitte, KPMG, Accenture, EY, PwC
- Banking/Finance: Goldman Sachs, JP Morgan, Morgan Stanley, Citi, HSBC
- Product/Startups: Curated list of top 100 Indian and global product companies
- Mass Recruiters: TCS, Infosys, Wipro, Cognizant, Capgemini, HCL, Tech Mahindra
- (Refreshed quarterly)

**Associated skills per role family:**

Each role family has a pre-mapped skill tree. Examples:

*SDE skill tree:*
- Data Structures (Arrays, Linked Lists, Trees, Graphs, Hash Tables, Heaps)
- Algorithms (Sorting, Searching, Dynamic Programming, Greedy, Backtracking, Recursion)
- System Design (Basics, Scalability, Distributed Systems)
- Operating Systems
- Database Management Systems
- Computer Networks
- Object-Oriented Programming
- Programming Language (user picks: Java, Python, C++, JavaScript, etc.)
- Aptitude (Quantitative, Logical, Verbal)
- HR/Behavioral
- Communication

*PM skill tree:*
- Product Sense / Design
- Estimation
- Strategy
- Analytics & Metrics
- Behavioral / Leadership
- Technical Fundamentals (light)
- Communication
- Stakeholder Management
- Case Studies
- Domain Knowledge (user's target domain: fintech, e-commerce, SaaS, etc.)

(Similar trees pre-populated for all role families)

## 15. Pre-Populated Data — Career Switch

**Common switch paths (pre-mapped):**
- Service-based engineer → Product engineer at startup/big tech
- Backend engineer → Full-stack
- Engineer → Product Manager
- Engineer → Data Scientist
- PM → Senior PM at Big Tech
- Consultant → Strategy at startup
- Marketer → Product Marketing
- Analyst → Data Scientist
- IC → Manager (within same domain)
- Domain switch (e.g., finance → tech)

Each switch path has:
- Skill gap (what's needed for the target that's not in current role)
- Typical timeline
- Recommended interview prep style
- Recommended portfolio/resume positioning

## 16. Pre-Populated Data — Interview Preparation

**Pre-mapped company-specific interview processes:**

For top 30 most-asked-about companies, ScaleUp maintains:
- Number of rounds
- Types of rounds (DSA, system design, behavioral, case, etc.)
- Typical question patterns
- Specific topics emphasized
- Cultural/leadership principles (where applicable, e.g., Amazon's 16 LPs)
- Difficulty calibration
- Recency of process changes

Examples covered at launch:
- Google (SDE, PM, Cloud Engineer)
- Microsoft (SDE, PM)
- Amazon (SDE, PM, Operations)
- Meta (SDE, PM)
- Apple (SDE)
- Flipkart, Razorpay, Swiggy (SDE, PM)
- McKinsey, BCG, Bain (Consulting)
- Goldman, JP Morgan (Analyst)
- (Refreshed quarterly based on user signals)

## 17. Pre-Populated Data — Competitive Exams

**Pre-mapped exams:**

**Indian exams:**
- UPSC (Prelims, Mains, Personality Test)
- CAT
- GATE (by branch)
- NEET (UG, PG)
- JEE (Main, Advanced)
- CLAT
- CA Foundation / Inter / Final
- Banking: SBI PO, IBPS PO/Clerk, RBI Grade B
- SSC CGL, CHSL
- Railway exams
- State PSCs (top 5-7)

**International exams:**
- GMAT
- GRE
- TOEFL, IELTS, PTE
- SAT (for international undergrad)

Each exam has:
- Syllabus tree
- Section-wise weightage
- Typical preparation timeline
- Recommended daily hours by timeline
- Last 5 years' difficulty trends
- Cutoffs (where applicable)

## 18. Pre-Populated Data — Upskilling

**Most sought-after skills (refreshed quarterly based on industry signals):**

For 2026-2027:
- AI/ML Engineering (LLMs, foundation models, fine-tuning, RAG)
- Data Engineering (modern stack)
- Cloud (AWS, Azure, GCP — major certifications)
- Cybersecurity
- Full-stack development (modern frameworks)
- DevOps / Platform Engineering
- Product Management
- Product Design / UX
- Digital Marketing (performance + content + SEO)
- Data Analysis (SQL, Python, BI tools)
- Financial Modeling
- Communication Skills / English Fluency
- (List maintained and refreshed)

Each skill has:
- Sub-skill tree
- Recommended learning path
- Typical timeline by depth (intro / proficient / expert)
- Certification mapping (where applicable)
- Portfolio project recommendations

## 19. LLM Extension for Novel Objectives

When a user enters an objective not in the database:

1. System checks for close matches (fuzzy match + semantic similarity)
2. If close match exists, suggest it: "Did you mean [X]?"
3. If no match, LLM is invoked to generate a candidate taxonomy entry:
   - Sub-skills
   - Typical timeline
   - Recommended assessment type
   - Recommended content categories
4. Generated entry is written to a "pending review" queue
5. User can use the LLM-generated taxonomy immediately
6. ScaleUp content team reviews pending entries weekly
7. Approved entries become permanent taxonomy items

This ensures the taxonomy grows organically based on real user demand without forcing every user through an LLM call.

## 20. Required Time Computation

**Critical: the system computes required time. The user does not declare it.**

Logic:
- User declares: objective + target timeline
- System looks up taxonomy: this objective at this depth typically requires X total hours
- System adjusts for user's current proficiency (from diagnostic): proficient users need less time
- System computes: total_hours_needed / weeks_in_timeline = hours/week required
- System presents to user: "To crack UPSC in 6 months, you need to invest ~50 hours/week. Can you commit to this?"

**Response paths:**

- **User accepts:** Plan generated with this load.
- **User says "I can do less":** System surfaces the tradeoff:
  - "If you can do 30 hours/week, your realistic timeline is 12 months. Adjust?"
  - User picks a workable combination of timeline and intensity.
- **User says "I can do more":** System surfaces faster path:
  - "At 70 hours/week, you can target this in 4 months — but burnout risk is high."
  - User makes informed choice.

The system never accepts unrealistic combinations silently. If a user insists on "UPSC in 1 month at 2 hours/day," the system says:
- "This is unrealistic for the typical learner. The plan will focus on highest-impact topics only. You'll cover ~15% of the syllabus."
- User makes the call with full information.

This is psychological honesty. We don't pretend the impossible is possible.

---

# Part V — Onboarding & Diagnostic System

## 21. Onboarding Flow Overview

**Total target duration:** 8-15 minutes from app open to landing on Home.

**Stages:**
1. Account creation (1-2 min)
2. Objective selection (2-3 min, using pre-populated taxonomy)
3. Minimal background (1 min)
4. Required-time computation + commitment (1 min)
5. Customized adaptive diagnostic (5-10 min, varies by objective type)
6. Diagnostic insights reveal (1-2 min)
7. Landing on Home (immediate; plan generates in background if not ready)

## 22. Account Creation

**Required:**
- Phone number (OTP verification)
- Email (optional, for backup)
- Name
- Age

**Optional at this stage (capture in-context later):**
- Photo, gender, city, current institution, language preference

**Authentication:**
- Phone OTP primary
- Google SSO secondary
- Apple SSO (required for iOS App Store policy)
- No password creation

## 23. Objective Selection

Driven entirely by the pre-populated taxonomy. The user navigates a hierarchy:

**Step 1: Top-level category**
- Campus Placement / Career Switch / Interview Prep / Competitive Exam / Upskilling

**Step 2: Specific objective (from taxonomy)**
- Examples shown based on category
- Searchable
- Recently popular items surfaced first
- "Don't see your goal?" link triggers LLM extension flow

**Step 3: Target specifics (varies by category)**
- Campus Placement → target role + target companies (multi-select)
- Career Switch → current role + target role/domain
- Interview Prep → target company + target role
- Competitive Exam → which exam + target attempt date
- Upskilling → which skill + target depth (intro / proficient / expert)

**Step 4: Timeline**
- Preset: 1 month / 3 months / 6 months / 9 months / 12 months / Custom date
- Required field

## 24. Minimal Background

Only what's needed to seed the plan. Defer everything else.

**Captured:**
- Current academic year / years of experience
- Field of study / current domain
- (Career switch) Current job role

**Deferred to in-context micro-prompts:**
- Detailed work history
- Skills self-rating (covered by diagnostic instead)
- Specific tech stack
- Past projects

## 25. Required-Time Computation & Commitment

After Steps 1-4, system computes required hours/week.

User sees:

```
For [Objective] in [Timeline]:
   You'll need to invest about [X] hours/week.
   That's roughly [Y] hours/day if studying daily.

   ✓ I can commit to this
   ⚠ I can do less (adjust timeline or scope)
   ↑ I can do more (faster path possible)
```

The commitment is anchored to reality. Plan generates accordingly.

## 26. Customized Adaptive Diagnostic

**Critical: the diagnostic format depends on the objective type.**

**Format mapping:**

| Objective Type | Diagnostic Format |
|---|---|
| SDE / Technical Role | MCQ on DSA/CS fundamentals + 2-3 coding problems + system design conceptual |
| PM / Product Role | MCQ on product sense + 1-2 case-based questions + scenario response |
| Consulting / Business | Case-based questions + behavioral scenario + estimation |
| Competitive Exam (objective-driven, e.g., CAT, GATE) | Subject-wise MCQ matching exam pattern |
| UPSC / Civil Services | Current affairs + GS-style MCQ + essay-type response |
| Data Science / Analyst | SQL problems + statistical reasoning + case-based analysis |
| Design / UX | Portfolio prompt + design thinking case + behavioral |
| Sales / Business Development | Scenario-based + objection handling + behavioral |
| Marketing | Case-based + analytical reasoning + scenario |
| Upskilling (skill-specific) | Skill-specific assessment (technical for tech skills, applied for soft skills) |

The diagnostic engine routes the user to the appropriate flow based on objective category.

**Adaptive logic (common to all):**

For each topic in the skill tree:
- Start with 1 baseline question (medium difficulty)
- If correct: 1 harder question to find ceiling
  - If correct: mark "proficient/advanced," move on
  - If incorrect: mark "intermediate"
- If incorrect on baseline: 1 foundation question
  - If correct: mark "beginner"
  - If incorrect: mark "needs foundation"

**Pre-diagnostic self-rating:**

Before the questions begin, user self-rates each topic in the skill tree:
- Novice / Beginner / Intermediate / Proficient / Advanced

This self-rating is captured for one critical reason: comparing it later against actual diagnostic performance to surface the calibration gap.

**Typical user takes 12-25 questions across 10-15 topics in 5-10 minutes.**

## 27. Behavioral Signals Captured During Diagnostic

Beyond correctness, the system captures:
- **Time per question** — flag rushing vs deliberation
- **Time on read vs time on answer** — flag impulsive vs thoughtful
- **Confidence pattern** — does user mark high-confidence answers correctly?
- **Topic streaks** — does user collapse after 2-3 wrong in a row (psychological pattern)?
- **Question-type performance** — better at MCQ vs free-response vs case?
- **Difficulty curve handling** — does user choke when difficulty rises?

These signals feed the diagnostic insights.

## 28. Diagnostic Insights Reveal

This is psychological honesty, not validation. User sees:

```
DIAGNOSTIC COMPLETE

Where you said you were:
[Self-rating summary across topics]

Where you actually are:
[Actual performance across topics]

Calibration gap:
"You rated yourself proficient on dynamic programming. 
You scored 30%. This is a significant gap."

Patterns we noticed:
· You rush on quantitative questions (avg 18 sec, accuracy dropped)
· You over-think on case questions (avg 4 min, accuracy stayed high)
· When you got 2 wrong in a row, your next 3 were 60% likely to be wrong
· You're consistently strong on conceptual, weaker on application

Your baseline readiness: 32%

Reality check:
For your timeline, you need to move from 32% to 80%+ readiness.
This is achievable at your committed hours, but it requires:
· Focused work on [top 3 weak topics]
· Deliberate slow-down on quantitative
· Active recovery technique when you get questions wrong in a row

We've built your plan around these insights.
```

This screen is not gentle. It's accurate. Users learn more from an honest mirror than from soft praise.

## 29. Don't-Wait-For-Plan UX

After diagnostic insights, the user taps "Got it, let's start." Two things happen:

1. **Plan generation kicks off in background** (may take 30-90 seconds for complex objectives)
2. **User is immediately taken to Home**

Home shows:
- A friendly "Your plan is being personalized — meanwhile, here's content relevant to your goal" banner
- Content carousels filtered to the user's plan topics (computed from objective taxonomy even before plan is fully baked)
- User can start consuming content right away

When the plan is ready (typically <90 seconds), the banner replaces with:
- "Your plan is ready. Here's what we recommend for today"
- Home transitions into the full activity-focused view

The user never waits on a loading screen.

---

# Part VI — Home Tab Specification (Activity-Focused)

## 30. Home Tab — Overview

Home is the user's daily entry point. It surfaces a curated, varied set of plan-aligned activities. The user picks what fits their mood, energy, and available time.

**This is activity-focused, not task-restrictive.** Multiple recommended activities, all plan-aligned, with clear access to broader plan content if the user wants more.

## 31. Home Tab — Layout

```
[Objective pill — header]
[Notification bell — top right if actionable]

──────────────────────────────────────
🎯 Week 3, Day 2 · 3 of 7 weekly tasks done
──────────────────────────────────────

RECOMMENDED FOR TODAY

┌─────────────────────────────────────┐
│ 📺  Watch                            │
│ Estimation frameworks                │
│ 18 min · Critical for PM placement   │
│ → Begin                              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🧠  Quiz                             │
│ Funnel analysis recap                │
│ 5 min · Reinforces last week         │
│ → Start                              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🎙️  Practice Interview               │
│ Behavioral round                     │
│ 30 min · You're ready                │
│ → Begin                              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 📝  Review                           │
│ Your Week 2 notes                    │
│ 10 min · Spaced repetition           │
│ → Open                               │
└─────────────────────────────────────┘

──────────────────────────────────────

WANT TO DO MORE?

→ Explore content on your topics
→ Take a custom quiz on any topic
→ Talk to Compass
→ View your full plan

──────────────────────────────────────
```

**Components:**

- **Week progress indicator:** Quiet, top of screen. Not gamified, not loud.
- **Recommended for Today:** 2-6 activities (count varies by user stage). Each activity card is identical in visual weight — no hero. Each shows: type icon, title, duration, why-recommended, single CTA.
- **Want to Do More?** Escape hatch to broader features. 3-4 simple text links.

**Components explicitly NOT on Home:**
- No carousels of trending content
- No streak banners shouting at the user
- No social feeds
- No follow-creator suggestions
- No "discover" carousels
- No stacking nudges (max 1 contextual nudge if relevant)

## 32. Home Tab — Activity Composition Logic

The recommendation engine selects activities to surface based on:

1. **Plan position:** What's the user supposed to be working on this week?
2. **Recency:** What did they consume yesterday? Don't repeat unless reinforcing.
3. **Variety:** Mix content + practice + reflection. Don't surface 4 videos in a row.
4. **Difficulty:** Match user's mental energy (data-informed — if user typically struggles in mornings, surface easier morning activities).
5. **Time availability:** Mix short (5-min quiz) and longer (30-min interview). User picks what fits.
6. **Recalibration signals:** If user's weak in topic X, surface more X activities.

**Activity types that can appear:**
- Watch (video content)
- Listen (audio content / audiobook chapter)
- Read (notes, infographic)
- Quiz (auto-generated from past content OR plan-driven)
- Mock interview (when applicable to objective)
- Make a note (from uploaded material — relevant for exam users)
- Mock exam (for B2B college users when TPO assigns)
- Coding practice (Phase 2, for SDE)
- Resume update (when milestones triggered)
- Reflection/recap (review what you covered this week)
- Conversation with Compass on a specific topic

**Daily activity count by user stage:**
- Day 1-3: 2-3 activities (don't overwhelm new users)
- Day 4-7: 3-4 activities
- Day 8-14: 4-5 activities
- Day 14+: 5-6 activities (active users handle variety)
- Day 30+: 5-7 activities (power users)

User can opt to see more or less via Profile → Settings.

## 33. Home Tab — When All Recommended Activities Are Done

State:
```
🎉  You've completed everything we recommended today.

You're ahead. Want to:
→ Get a head start on tomorrow
→ Explore content beyond your plan
→ Take an extra quiz
→ Talk to Compass

Or just rest — see you tomorrow.
```

No guilt, no "you should do more." The state acknowledges achievement and offers options without pressure.

## 34. Home Tab — Fallback States

**State 1 — No plan yet (diagnostic incomplete):**
"Let's set you up — 10 min" with diagnostic CTA.

**State 2 — Plan generating (post-diagnostic, pre-plan-ready):**
"Your plan is being personalized. Meanwhile, here's content relevant to your goal."
Below: 4-6 content cards from the user's plan topics (computed pre-plan from taxonomy).

**State 3 — Plan paused:**
"Plan paused. Resume?" with CTA. Reason chip if applicable.

**State 4 — Objective completed:**
"Objective complete! What's next?" with options: extend, switch to outcome tracking, start new objective.

## 35. Home Tab — Notifications & Reminders

**Push notification rules:**
- Max 1 task reminder per day at user's preferred time
- Max 1 event/competition reminder per week
- Mock exam alerts (B2B users) — sent as scheduled
- Outcome notifications (interview results, etc.) — when generated
- No guilt notifications, no streak-loss notifications

**In-app banner rules:**
- Max 1 banner at a time
- Auto-dismisses after action or 24 hours

---

# Part VII — Learn Tab Specification

## 36. Learn Tab — Overview

Learn is pull-based content discovery. Users come here when they want to explore beyond what Home recommended.

## 37. Learn Tab — Layout

```
[Search bar — top]

[ Search topics, creators, videos... ]

──────────────────────────────────────

CONTINUE WATCHING
· Estimation frameworks (80%)
· Time complexity basics (45%)

──────────────────────────────────────

RECOMMENDED FOR YOU →
(plan-aware single carousel)

TRENDING IN [USER'S DOMAIN] →
(filtered to user's objective area)

CREATORS YOU FOLLOW →
(latest from followed creators)

NEW THIS WEEK →
(editorial curation)

──────────────────────────────────────

BROWSE BY TOPIC →
BROWSE BY CONTENT TYPE →
BROWSE BY CREATOR →
```

## 38. Learn Tab — Search

**Scope:** Content (video, audio, notes, infographics), Topics, Creators

**Behavior:**
- Instant results
- Filters: content type, duration, difficulty, language, creator tier
- Recent searches surfaced
- Empty state: suggestions tied to user's plan

## 39. Learn Tab — Content Detail Page

```
[Thumbnail / video preview]

[Title]
[Creator name + tier badge + topic tags]
[Duration · Difficulty · Language · Rating]

▶ Play

ABOUT
[2-3 sentence summary, AI-generated]

WHAT YOU'LL LEARN
· Concept 1
· Concept 2
· Concept 3

ACTIONS
👍 Like   💬 Comment   ⭐ Rate   🔖 Save to Playlist   📤 Share
🧭 Ask Compass about this

QUIZ ON THIS (after watching)
NOTES ON THIS (Compass can summarize)
RELATED CONTENT (in this topic)
```

## 40. Engagement Features Detail

**Like:** Private signal for recommendation engine. No public count.

**Comment:**
- Visible to other ScaleUp users
- Single-level threading (reply to comment; no reply-to-reply)
- Creator can pin, reply, delete inappropriate
- Comment moderation by admin available
- Users can report comments

**Rate:**
- 5-star rating
- Feeds content quality scoring algorithm
- Public aggregate visible

**Save to Playlist:**
- User creates and manages playlists in Profile → My Library
- Public playlists optional (Phase 2)

**Share:**
- Generates ScaleUp deep link
- Tracks attribution
- Sharing copy template: "Watch [content] on ScaleUp"

## 41. Learn Tab — Content Player

**Video player:**
- Full-screen mode
- Speed controls (0.75x, 1x, 1.25x, 1.5x, 2x)
- Caption toggle (auto-generated via Whisper)
- Quality selector (auto, 1080p, 720p, 480p)
- Picture-in-picture
- Background audio mode
- Compass FAB accessible from player
- Auto-generated chapter markers for long content

**Audio player:**
- Same controls as video, audio-only
- Lockscreen controls
- Background play default
- Speed controls

**Note/Infographic viewer:**
- Zoom + pan
- Linked sections for navigation
- Compass available for explanation

## 42. Learn Tab — In-Content Compass Interactions

When user invokes Compass during content playback:
- Common quick prompts: "Explain in simple terms," "Give me a real-life example," "Summarize so far," "I don't understand the last 30 seconds"
- Custom typed query supported
- Compass has full context: current content, timestamp, what user has consumed, what's in their plan
- All Q&A saved to Compass History (accessible in Compass tab)
- User can pause, ask, get answer, resume — no friction

## 43. Learn Tab — Creator Profile Page

```
[Cover banner]
[Avatar]
[Name] [Tier badge: "Anchor Creator · Top in Product Management Placement"]
[Bio / expertise]
[Follower count] [Follow / Following button]

CONTENT BY [CREATOR]
[Filterable list]

COMMUNITIES (Phase 2)
[Communities this creator runs]

COHORTS (Phase 3)
[Active cohorts]

MENTORSHIP (Phase 3)
[Book a 1:1 session if creator offers]
```

---

# Part VIII — Compass Tab Specification (All AI Features)

## 44. Compass Tab — Overview

Compass is the unified home of all AI features. One tab, one named companion, all AI capabilities organized here.

The same Compass that lives in the FAB (contextual mode) lives in this tab (as a destination for AI features). Both true simultaneously.

## 45. Compass Tab — Layout

```
🧭 COMPASS

What do you want to do?

┌─────────────┐  ┌─────────────┐
│ 🧠          │  │ 🎙️          │
│ Quiz Me     │  │ Practice    │
│             │  │ Interview   │
└─────────────┘  └─────────────┘

┌─────────────┐  ┌─────────────┐
│ 💬          │  │ 📝          │
│ Talk to     │  │ Make a Note │
│ Compass     │  │             │
└─────────────┘  └─────────────┘

┌─────────────┐  ┌─────────────┐
│ 📐          │  │ 📄          │
│ Code        │  │ Resume      │
│ (Phase 2)   │  │ Builder     │
└─────────────┘  └─────────────┘

┌─────────────┐  ┌─────────────┐
│ 🏆          │  │ 🎯          │
│ Compete     │  │ Mock Exam   │
│             │  │ (B2B users) │
└─────────────┘  └─────────────┘

──────────────────────────────────────

MY ACTIVITY

· 14 quizzes taken — view history & analytics
· 5 interviews completed — view recordings & feedback
· 18 notes created — view library
· 6 flashcard decks — review
· 4 mind maps — explore
· 23 Compass conversations — search & resume
· 2 resumes — manage
· In-content Q&A — view all questions asked during content

──────────────────────────────────────

NEW FEATURES UNLOCK AS YOU PROGRESS
```

**Compass is the home for:**
- All AI feature tiles (Quiz Me, Interview, Talk to Compass, Make a Note, Code, Resume, Compete, Mock Exam)
- All historical AI activity (quizzes taken, interviews, notes, conversations, in-content Q&A)
- All AI analytics (your performance trends across AI features)

## 46. Compass Tab — Quiz Me

**Flow:**
1. Tap "Quiz Me"
2. Select topic (from objective taxonomy or full taxonomy)
3. Select question format (see Section 47 for 7 formats)
4. Select difficulty (easy / medium / hard / adaptive)
5. Select question count (5, 10, 20, custom)
6. Tag to objective for readiness contribution? (yes/no)
7. Compass generates the quiz (with full context: user's level, recent activity, weak areas)
8. User takes quiz with inline feedback + Compass explanations on wrong answers
9. Results saved to history; readiness updated (if tagged)

## 47. Compass Tab — Quiz Question Formats

Seven formats available (existing infrastructure):
1. **Recall** — pure knowledge recall (definitions, facts)
2. **Conceptual** — understanding of concepts
3. **Application** — applying concept to a problem
4. **Scenario-based** — situational decision-making
5. **Case-based** — multi-part case with multiple sub-questions
6. **Framework** — structured analytical thinking
7. **Real-life application** — practical translation

User selects format(s) when creating their own quiz. System selects appropriately when auto-generating.

## 48. Compass Tab — Practice Interview

**Interview types:**
- Technical (DSA, system design, with code in chat)
- Behavioral / HR
- Case-based (consulting/business)
- Scenario-based (PM/strategy)
- Mixed (random sequence)

**Flow:**
1. Tap "Practice Interview"
2. Select type
3. Select target role/company (pre-filled from objective)
4. Select duration (15 / 30 / 45 / 60 min)
5. Select seniority level
6. Tag to objective for readiness contribution?
7. Compass generates interview script
8. Interview begins:
   - Voice or text input
   - Real-time follow-ups based on user's responses
   - LLM-driven dynamic questioning
9. Interview ends:
   - Detailed feedback (strengths, weaknesses, specific examples)
   - Suggested next prep topics
   - Recording + transcript saved
   - Feedback contributes to readiness

## 49. Compass Tab — Talk to Compass (Conversational AI)

**Free-form conversation with Compass.** This is the conversational learning surface.

**Use cases:**
- Open-ended Q&A on topics
- Conceptual deep-dives
- "Explain X like I'm five"
- "Quiz me on Y via conversation"
- "Help me think through this problem"
- Voice mode (Phase 2): user speaks, Compass speaks back

**Guardrails:**
- Topic detection: if user veers into off-topic conversation (entertainment, random chat, personal life), gentle redirect: "That's outside what I can help with. Want to get back to [objective topic]?"
- Content policy: refuse harmful, illegal, off-topic content. Refer to platform terms.
- Rate limiting: free tier has daily token/conversation cap. Pro tier has higher cap.
- Session timeouts: 30 min inactive = session ends, can be resumed
- No medical/legal/financial advice that requires a professional — Compass refers to a human
- No personal opinions on politics/religion/controversial topics
- Always identifies as AI when asked

**Persistence:**
- All conversations saved
- Searchable, resumable
- Filterable by topic, date
- Exportable

## 50. Compass Tab — Make a Note

**Flow:**
1. Tap "Make a Note"
2. Options: Upload PDF / Upload image / Upload audio / Type / Scan with camera
3. Compass processes:
   - OCR for images
   - Whisper transcription for audio
   - Text extraction for PDF
4. Compass auto-generates:
   - Summary (short + detailed)
   - Audio summary (TTS)
   - Mind map
   - Flashcards (spaced repetition)
   - Quiz (5-15 questions)
   - Audiobook-style narration of the note
5. User can edit AI output
6. Note saved to library (private by default)
7. Optional: share with specific cohort members

**Notes are NOT a public marketplace.** Sharing requires explicit user action to specific recipients.

## 51. Compass Tab — Resume Builder

**Phase 1 MVP:**
- 3-5 template options
- AI generates content from user's profile + diagnostic + activity
- User edits inline
- Export to PDF
- Save multiple versions

**Phase 2 advanced:**
- ATS scoring
- Role-specific optimization
- Multiple variant management
- Expert review option (Expert Sessions integration)

## 52. Compass Tab — Code (Phase 2)

Lightweight coding evaluation via web hand-off.

**Flow:**
1. Tap "Code"
2. Select practice mode / contest / assigned assessment
3. Select language + problem set
4. App generates QR code / link
5. User opens in browser
6. Web session: code editor + problem + test cases + submit
7. On submit, session ends, results sync to mobile
8. Web session deleted
9. Results saved to library + factor into readiness

## 53. Compass Tab — Compete

**Event types:**
- Weekly Friday Quiz Battle (8-9 PM IST, topic rotates)
- Monthly Grand Competition
- College vs college (Phase 2, B2B)
- Topic tournaments (Phase 2)

**Leaderboards:**
- Event-specific (visible during/after event, archived)
- College-cohort (always-on within signed college)
- No global all-time leaderboards

## 54. Compass Tab — Mock Exam (B2B College Users)

For students in colleges with active ScaleUp partnership:
- TPO uploads syllabus
- ScaleUp generates objective-aligned mock exam
- Student takes timed exam in app
- Results aggregate to TPO dashboard
- Individual results contribute to student's readiness

## 55. Compass Tab — In-Content Q&A History

All questions asked during content playback are saved here:
- Searchable
- Filterable by content piece, topic, date
- Each Q&A shows: what content was being watched, timestamp, question, Compass's answer
- User can replay the content moment from the Q&A

This is a critical reference for users reviewing what they learned.

## 56. Compass Tab — My Activity Section

Bottom of Compass tab — user's full AI activity:

- Quizzes (count + view history & analytics)
- Interviews (count + recordings & feedback)
- Notes (count + library)
- Flashcards (count + review schedule)
- Mind maps (count + browse)
- Conversations (count + search & resume)
- Resumes (count + manage)
- In-content Q&A (count + view all)

Each is tappable to drill in.

---

# Part IX — Compass System (AI Companion)

## 57. Compass — Overview

Compass is the user's named AI companion. All AI capabilities live under Compass with contextual modes. The user develops a relationship with one entity.

**Name rationale:** "Compass" evokes guidance, direction, and outcome-orientation. It aligns with the C2O thesis (a compass points you toward your goal). It's gender-neutral, unambiguous, and short enough to use frequently.

## 58. Compass — Modes

Compass detects context automatically:

**Tutor Mode** (in content player):
- Explain this concept
- Give me an example
- Why does this matter
- Summarize so far
- I'm lost on the last segment

**Conversation Mode** (Compass tab → Talk to Compass):
- Open Q&A
- Multi-turn discussions
- Conceptual deep-dives

**Quiz Mode** (Compass tab → Quiz Me):
- Generate quizzes
- Adaptive difficulty
- Explanations on wrong answers

**Note Mode** (Compass tab → Make a Note):
- Read uploaded content
- Generate summary, audio, mindmap, flashcards, quiz

**Interview Mode** (Compass tab → Practice Interview):
- Acts as interviewer
- Dynamic follow-ups
- Detailed eval

**Insight Mode** (Profile → Plan):
- Surface patterns
- Suggest plan adjustments
- "Here's what I noticed this week"

**Mentor Mode** (career guidance):
- Career strategy
- Role decisions
- "What should I target?"

**Coach Mode** (motivation, when needed):
- Encouragement after rough patches
- Reality checks when off track
- Goal recalibration

## 59. Compass — Full Context Across Platform

**This is critical.** Every interaction with Compass has access to:
- User's objective + timeline + target specifics
- Plan progress
- Recent content consumed
- Recent quiz performance
- Recent interview performance
- Notes user has created
- Past Compass conversations
- In-content questions asked
- Behavioral signals (rushing patterns, weak topics, etc.)

When Compass answers a question, generates a quiz, evaluates an interview, or has any conversation, it uses this full context.

**Result:** Compass feels like one intelligent system that knows the user, not disconnected AI features.

**Implementation:**
- User context store (server-side) maintained per user
- Updated in real-time as user activity occurs
- Provided as system prompt context to every LLM call
- Filtered/summarized to fit context windows (recent + relevant)

## 60. Compass — Personality

Consistent across modes:
- Knowledgeable but humble
- Honest about uncertainty
- Encouraging without being saccharine
- Concise (doesn't ramble)
- Adapts tone to user's level
- Has a name (Compass) and visual identity (icon: 🧭 or custom designed)

**Compass is NOT:**
- A pretend human (always identifies as AI when asked)
- A sycophant (will disagree, push back, correct user)
- An infinite-context companion (acknowledges memory limits transparently)
- A general chatbot (focused on learning + career outcomes)

## 61. Compass — Conversation History

Saved per user. Accessible via Compass tab → My Activity → Conversations.

Features:
- Search across conversations
- Filter by mode, date, topic
- Resume past conversations
- Export
- Delete specific or all

## 62. Compass — Multi-Provider AI Strategy

Different tasks need different models. Leverage existing multi-provider infrastructure (Anthropic + OpenAI + Whisper + ElevenLabs).

**Provider mapping:**
- Real-time low-latency (Tutor in content): fast mid-tier model
- High-stakes reasoning (Interview eval, plan generation): top-tier reasoning model
- Voice generation: ElevenLabs primary
- Voice transcription: Whisper
- Vision (OCR, infographics): vision-capable model
- Bulk content generation (videos): can use slower cheaper models

## 63. Compass — Guardrails

**Topic guardrails (covered in Section 49):**
- Off-topic detection + redirect
- Refuse harmful/illegal/professional-advice content

**Cost guardrails:**
- Token budget per user per day (free tier)
- Rate limiting
- Caching of common responses
- Pro tier higher cap

**Quality guardrails:**
- Confidence thresholds — if Compass is uncertain, says so
- Citation when possible (for facts that could be wrong)
- "I might be wrong here — let me know" framing

**Safety guardrails:**
- No personal info disclosure beyond what user provided
- No advice that requires professional credential (medical, legal, financial)
- Crisis resources surfaced if user mentions distress
- Always identifies as AI

---

# Part X — Plan System Specification

## 64. Plan System — Overview

The Plan is the spine of ScaleUp. Every user with an active objective has a Plan. Home shows daily activities from the Plan; users execute and progress.

**This replaces the existing Plan + Journey duplication.** v2 has one unified Plan system.

## 65. Plan System — Generation

After diagnostic:

1. Map objective to taxonomy tree (topics required)
2. Subtract proficient topics (from diagnostic)
3. Prioritize weak topics by objective impact
4. Allocate time across topics based on committed weekly hours + timeline
5. Sequence within weeks (foundation → application → review)
6. Select specific content for each topic (from ScaleUp Originals + AI-generated + creator content + commissioned content)
7. Embed auto-quizzes after each content piece
8. Insert practice activities (interviews, mock exams) at intervals
9. Build readiness curve projection

**Output:**
- Total plan duration
- Weekly milestones with topic focus
- Daily activity pool (system picks from this for Home recommendations)
- Estimated readiness curve
- Content gap flags (where AI generation or commissioning is needed)

## 66. Plan System — Daily Activity Pool

The plan generates a *pool* of activities per day, larger than what's shown on Home. The recommendation engine picks 2-6 activities to surface based on:
- Variety (mix types)
- Recency (don't repeat yesterday)
- Difficulty match (user's energy/time)
- Recalibration signals
- Random sampling for freshness

User completing an activity unlocks the next from the pool. User can also browse the full daily pool via "View today's full plan."

## 67. Plan System — Weekly Recalibration

Every 7 days:

1. Aggregate past week's performance:
   - Quiz scores by topic
   - Content completion rates
   - Time spent vs planned
   - Interview eval scores
   - Days active vs days planned
2. Compare to plan expectations
3. Identify deviations
4. Regenerate next week's tasks accordingly
5. Update readiness score
6. Surface adjustment to user: "Based on last week, we've added 2 hours of OS practice. You're ahead on aptitude — moving that time."

Recalibration is automatic but visible. Max 30% of upcoming week's tasks can change in one cycle.

## 68. Plan System — Plan Deep-View Location

The detailed plan view lives in **Profile → My Plan**.

**What user sees:**

```
MY PLAN — [Objective Name]

OVERVIEW
Total duration: 24 weeks
Current week: 3
Estimated readiness curve: [visual graph]

──────────────────────────────────────

THIS WEEK
[Day-by-day breakdown of activities, marked done/upcoming]

──────────────────────────────────────

WEEKS AHEAD
Week 4: [topic focus + activities preview]
Week 5: [topic focus + activities preview]
...
Week 24: [topic focus + activities preview]

──────────────────────────────────────

TOPIC-LEVEL DEEP DIVE
[For each topic in the plan:]
- Topic name
- Mastery level (current % + trend)
- Hours invested
- Hours remaining (estimated)
- Recent activities completed
- Recent quiz scores
- Recent insights from Compass
- Recommended next activities

──────────────────────────────────────

ACTIVITY LOG
[Chronological log of every activity completed]
```

This is reference material. Power users go deep here. Casual users may never visit.

## 69. Plan System — Multi-Objective Support

User can have up to 3 active objectives simultaneously.

- One marked primary (drives Home default)
- Others accessible via objective switcher in header
- Each objective has own plan
- Daily time allocated across active objectives by user-set weights
- Readiness score per objective (no aggregate)

**Lifecycle states:** Active / Paused / Completed / Archived

## 70. Plan System — Readiness Score

The single most important metric in the product.

**What it is:**
- 0-100 score representing readiness to achieve the objective
- Per-objective
- Updated continuously
- Visible on every screen (header pill, Profile prominently)

**How it's calculated:**
- Topic mastery (quiz + content + interview signals): primary
- Time invested vs plan: secondary
- Recency of practice (decay model): tertiary
- Outcome proxies (mock exam, interview eval): high-weight
- For B2B users: TPO-set benchmarks contribute

**Believability:**
- Calibrated against historical outcomes (once data exists)
- Pre-data: expert-defined rubrics
- Monthly survey: "Do you believe your readiness score?" — used for calibration

**As a credential (Phase 4):**
- High-readiness users can opt-in to public profile
- Employers query for users with X readiness in Y domain (Phase 4 hiring marketplace)

---

# Part XI — Content System Specification

## 71. Content System — Overview

Three content sources. All owned, controlled, or properly licensed. No YouTube embeds.

**Source 1: ScaleUp AI-Generated Originals (70-80%)** — Generated by ScaleUp's AI production pipeline. Owned. Ad-free. Refreshable. Personalizable (length/language/difficulty variants).

**Source 2: Creator-Produced Content (10-20%)** — Uploaded by approved creators. Creators retain copyright but grant ScaleUp usage rights. No exclusivity required (creators can post elsewhere too). Hosted on ScaleUp infrastructure. Ad-free.

**Source 3: ScaleUp Commissioned Originals (5-10%)** — Paid productions with industry experts for highest-stakes modules. Fully owned by ScaleUp.

**No YouTube curation. No third-party embeds.**

## 72. Content System — AI Generation Pipeline

**Stages:**

1. **Content Planning:** Topic taxonomy + objective + difficulty + duration → queue for production
2. **Script Generation:** LLM (Claude/GPT-4 class) generates structured scene-by-scene script
3. **Voiceover Generation:** ElevenLabs for high-quality narration; multi-language; consistent voice library per topic area
4. **Visual Generation:** Branched by approach:
   - **Approach A — AI Avatar (25%):** Synthesia/HeyGen for talking-head content (intros, summaries, soft topics)
   - **Approach B — Voiceover + Slides/Diagrams (70%):** Custom Python + Manim (math animations) + Carbon (code) + Pillow (slides)
   - **Approach C — Cinematic AI (5%):** Kling/Veo/Sora for hero intros on top modules only
5. **Assembly:** FFmpeg combines audio + visuals + transitions + branding
6. **Quality Control:**
   - Automated checks (audio, sync, rendering)
   - AI evaluation (accuracy, clarity, alignment — scored 0-10)
   - Human reviewer approval
   - Threshold: 8.0+ AI score + human approval to publish
7. **Indexing:** Upload S3, generate thumbnails, index in DB, send to recommendation engine

**Cost:** Approach A = ₹750-1,300/video; Approach B = ₹350-750/video; Approach C blend = ₹1,200-3,000/video. Blended average ~₹500-900 per 10-min video.

## 73. Content System — Creator Content Pipeline

**Upload flow (creator side):**
1. Open upload tool (web or mobile)
2. Drag/drop video/audio/document
3. Fill metadata (title, description, topic tags, difficulty)
4. Compass auto-generates: transcript (Whisper), summary, suggested tags
5. Creator reviews/edits AI suggestions
6. Submit for processing

**Processing:**
1. Upload to S3
2. Whisper transcribes
3. Compass generates summary + auto-quiz
4. Quality check (technical + AI scoring)
5. Goes live or flagged for review

**Creator control:**
- Schedule publication
- Edit metadata
- Pull content (with grace period for users mid-consumption)
- View performance per piece

## 74. Content System — Commissioned ScaleUp Originals

For top 20-30 highest-stakes modules.

**Process:**
- ScaleUp identifies gaps (e.g., "Google PM interview process")
- ScaleUp recruits domain expert (hiring manager, recent placement)
- ScaleUp produces (script, recording, post-production)
- Expert paid per piece (₹30K-1L)
- ScaleUp owns fully

**Branding:** "ScaleUp Originals" badge. Featured in Learn. Pro-tier value.

## 75. Content System — Quality Vetting

**Three layers:**

**Layer 1 — AI Quality Scoring (automated):**
- Factual accuracy, topic alignment, clarity, depth, engagement potential
- LLM analyzing transcript + metadata
- Threshold: 8.0+ for publication

**Layer 2 — Human Review:**
- Curation lead spot-checks
- Manual review for borderline AI-scored
- Manual curation for highest-stakes modules

**Layer 3 — Live Feedback:**
- Completion rate (target: 60%+)
- Quiz performance correlation
- Explicit ratings
- Compass interaction signals (high "I don't understand" = unclear content)
- Underperforming content pulled and regenerated

## 76. Content System — Content Types

**Video (primary):** 5-20 min average. 1080p default. Captions auto-generated. Speed control.

**Audio (Phase 1, leverages AI voice pipeline):** Derived from video or standalone. Podcast-style for long-form. Background play. Audiobook-style narration of notes/content.

**Notes / Infographics:** Static visual content. Searchable, zoomable. Compass can explain.

**Interactive (Phase 2):** Coding playgrounds. Interactive diagrams. Inline quiz embeds.

---

# Part XII — Creator System Specification

## 77. Creator System — Overview

Creators are an acquisition channel. The economic value is they bring existing audiences to ScaleUp.

**Creators ARE:** Quality-vetted (application + approval), tiered for credibility (Rising/Core/Anchor), compensated through rev share on referred users + paid features they offer.

**Creators are NOT:** Exclusive to ScaleUp, primary content source (AI generation is), paid retainers, required to produce frequently.

## 78. Creator System — Application Flow

1. User taps "Apply as Creator" in Profile → Settings (or marketing page)
2. Fills application:
   - Areas of expertise (multi-select from taxonomy)
   - Bio (300 chars)
   - Portfolio links (YouTube, LinkedIn, etc.)
   - Sample content (3 pieces)
   - Why ScaleUp? (short answer)
   - Audience size on existing platforms
3. Submits → pending queue

## 79. Creator System — Approval

**Routes:**
- Admin reviews and approves/rejects
- OR 2 Core creators in same expertise area
- OR 1 Anchor creator in same expertise area
- Admin override on peer approvals

**Criteria:**
- Sample content quality
- Relevance to ScaleUp audience
- Authenticity of expertise
- No conflicting promotional patterns
- Compliance with content guidelines

**Outcome:**
- Approved → Rising tier
- Rejected → notification with reason, can reapply after 60 days
- Needs more info → reviewer can request

## 80. Creator System — Tier System

Three tiers, visible to users as earned credibility badges with domain context.

**Rising Creator:**
- Starting tier after approval
- Quality demonstrated, limited track record on ScaleUp
- Full creator tools
- 10% rev share on referred Pro subscriptions for first 12 months
- Badge: "Rising Creator · [Domain]"

**Core Creator:**
- Promoted from Rising based on performance (content quality, audience growth, outcome attribution, consistency)
- Promoted by admin or 2 existing Core creators in same expertise
- Higher rev share, priority featuring, can run communities (Phase 2) and cohorts (Phase 3)
- 15% rev share on referred Pro subscriptions
- Badge: "Core Creator · [Domain]"

**Anchor Creator:**
- Top tier — established experts with strong audience pull
- Promoted from Core based on significant ScaleUp impact
- Promoted by admin or 1 Anchor in same expertise
- Best rev share, ScaleUp Originals consideration, mentorship offerings
- 20% rev share on referred Pro subscriptions
- Badge: "Anchor Creator · [Domain]"

**User-facing presentation:**
- Badges show tier + domain (e.g., "Anchor Creator · Top in Product Management Placement")
- Tier alone is meaningless; tier + domain is meaningful
- Tier promotions celebrated in-app

## 81. Creator System — Creator Hub (Profile → Creator Hub)

Available to all approved creators within the mobile app.

**Mobile Creator Hub (in Profile tab):**
- Quick content upload
- Recent content performance
- Audience metrics
- Recent comments to respond to
- Earnings summary
- Link to full Creator Hub (web)

**Web Creator Hub (full):**
- Content upload (advanced editor)
- Library management
- Detailed analytics per piece (views, completion, ratings, attribution, conversions)
- Audience demographics
- Earnings dashboard
- Payout history
- Tax docs (Form 16A)
- Community/Cohort/Mentorship management (when available)

## 82. Creator System — Creator Tools

**Content Upload (mobile and web):**
- Video, audio, documents, infographics
- Drag/drop on web
- Quick upload on mobile

**Editor:**
- Basic trim, splice, cover image selection
- Caption editing
- Tag/metadata editor
- Thumbnail picker

**Scheduling:**
- Publish immediately or schedule
- Series creation

**Analytics Dashboard:**
- Per-piece: views, completion rate, ratings, quiz attach rate
- Audience: age, location, college, objective
- Engagement: comments, follows, saves
- Outcome attribution: "users who consumed your content achieved X milestones"
- Earnings: rev share, payment history

**Audience Tools:**
- Pinned message
- Reply to comments
- DMs from followers (rate-limited, can be disabled)

**Communities (Phase 2 — Core+):**
- Create community
- Post text/links/polls
- Run AMAs
- Moderate

**Cohorts (Phase 3 — Core+):**
- Create paid cohort
- Set pricing
- Recruit members
- Live sessions
- Exclusive content

**Mentorship (Phase 3 — Core+):**
- Offer 1:1 sessions
- Set pricing, availability
- Integrated video calls

## 83. Creator System — Referral Attribution

**Referral link:** scaleup.app/c/[handle]

**Attribution:**
- 90-day cookie on initial install
- User permanently attributed to first creator who referred them
- Multiple links: first wins
- Survives reinstall (tied to phone/email)

**Tracking (creator dashboard):**
- New installs this month
- Conversion to active users
- Conversion to Pro
- Outcome attribution from referred users

## 84. Creator System — Revenue Share

**Pro tier subscription:**
- Rising: 10% for 12 months
- Core: 15% for 12 months
- Anchor: 20% for 12 months

**Expert Sessions (Phase 2):**
- Rising: 60% of session price
- Core: 70%
- Anchor: 80%

**Creator Cohorts (Phase 3):**
- Rising: 50%
- Core: 60%
- Anchor: 70%

**Mentorship (Phase 3):**
- Rising: 60%
- Core: 70%
- Anchor: 80%

**Payouts:**
- Monthly, 15th
- Minimum threshold: ₹500
- UPI / bank transfer
- TDS-deducted; Form 16A annually

---

# Part XIII — B2B College System Specification

## 85. TPO Dashboard — Overview

Web-based product for college Training & Placement Officers.

## 86. TPO Dashboard — Core Features

**Login & Setup:**
- TPO account (admin-invited or self-signup)
- College profile (name, type, placement window, target companies)
- Student roster import (CSV or API)

**Student Roster:**
- All students
- Filter by batch, department, placement status
- Individual student detail pages
- Bulk actions

**Mock Exam Creation:**
- TPO uploads syllabus (PDF or document)
- AI generates exam based on syllabus + objective + difficulty
- TPO reviews/edits questions
- Publishes with date/time
- Students take in ScaleUp app

**Cohort Analytics:**
- Aggregate readiness score
- Topic distribution (weak across batch)
- Engagement metrics
- Comparison vs other colleges (anonymized)
- Trend over time

**Individual Student View:**
- Profile, objective, plan progress
- Readiness history
- Quiz/interview history
- Topics mastered/weak
- Recommended interventions

**Reporting:**
- Placement-readiness reports (PDF) for stakeholders
- Raw data export (CSV)
- Custom reports

**Communication:**
- Announcements to all students or specific cohorts
- Schedule mock exams, drives, events

**Settings:**
- TPO account management
- Multi-TPO support
- Permissions (admin vs view-only)

## 87. TPO Dashboard — Mobile Integration

When college is signed:
- Students get "College" indicator in app
- TPO-assigned mock exams appear as Home priority activities
- College-cohort leaderboards visible (Compass → Compete)
- TPO announcements appear as notifications

---

# Part XIV — Notifications & Communications

## 88. Notification System — Overview

Minimal, actionable, respectful.

## 89. Notification Types

**Daily activity reminder:** 1x/day at user's preferred time, only if user hasn't engaged today.

**Weekly event reminder:** 1x/week max, for competitions/AMAs.

**Plan recalibration:** When weekly recalibration happens, summary of changes.

**Outcome notifications:** Mock exam results, interview eval ready, cohort competition results.

**Account/Security:** Login from new device, password changes, payment confirmations.

**Creator-related:** Comments on your content, new follower (batched daily), earnings updates (monthly), tier promotion announcements.

**Anti-patterns explicitly avoided:**
- Guilt notifications ("haven't seen you in X days")
- Streak-loss panic
- Generic trending pushes
- Social interaction notifications (likes etc.)

## 90. In-App Banners

- Max 1 banner at a time
- Clear action
- Auto-dismisses after action or 24h
- User can manually dismiss

---

# Part XV — Profile Tab Specification

## 91. Profile Tab — Overview

Profile is the user's home for everything personal — progress, plan, analytics, settings, creator hub.

## 92. Profile Tab — Layout

```
[Avatar + name + edit]

──────────────────────────────────────

         ╭───────╮
         │  74%  │   ← Readiness score (current primary objective)
         ╰───────╯
       On track for [Objective]
       [Target date] · [Weeks remaining]

──────────────────────────────────────

This week        ●●●○○○○  3 of 7 done
Streak           12 days 🔥 (quiet)
Top gap          Estimation frameworks
                 → Fix this

──────────────────────────────────────

SECTIONS

📊 My Progress & Analytics →
   Detailed mastery, activity timeline, performance trends

🎯 My Plan →
   Full week-by-week + topic-level deep view

🎓 My Objectives →
   All objectives, switcher, add new

🧭 My Compass Activity →
   (Shortcut to Compass tab → My Activity)

📺 My Content →
   Viewed, liked, saved, playlists

⚙️ Settings →
   Account, privacy, notifications, app preferences, help

🎬 Creator Hub (if approved creator) →
   Upload, analytics, audience, earnings

🛠️ Admin (if admin) →
   Internal tools
```

## 93. Profile Tab — My Progress & Analytics

**Detailed Mastery:**
- Topic-by-topic readiness
- Mastery curves over time
- Strong topics / Weak topics
- Recommended focus areas

**Activity Timeline:**
- Chronological log
- What done when
- Time spent per session

**Performance Trends:**
- Quiz performance over time
- Interview eval scores
- Content completion rates
- Engagement patterns

**Insights:**
- Compass-generated weekly insights
- Behavioral patterns identified
- Suggestions

## 94. Profile Tab — My Plan

**Full plan deep-view** (Section 68 detail):
- Overview (duration, current week, readiness curve)
- This week (day-by-day)
- Weeks ahead (preview)
- Topic-level deep dive
- Activity log

## 95. Profile Tab — My Objectives

- All objectives (active + paused + completed + archived)
- Switcher (set primary)
- Add new objective
- Edit objective settings
- Archive/delete

## 96. Profile Tab — My Content

User's content interactions:
- Recently viewed
- Liked content
- Saved / Playlists (create, manage, share if Phase 2)
- Followed creators
- Comments made

## 97. Profile Tab — Settings

**Account:**
- Edit profile (name, photo, email, phone, age, location, language)
- Change password/login methods
- 2FA

**Privacy & Data:**
- Data download (GDPR-compliant export)
- Data deletion (account deactivation with wipe option)
- Consent management
- Profile visibility (default private)

**Notifications:**
- Daily reminder time
- Weekly event reminders on/off
- Outcome notifications
- Push notifications global

**App Preferences:**
- Theme (light / dark / system)
- Default content type
- Auto-play next
- Default playback speed
- Captions auto-on/off
- Show all features (override progressive unlock)

**Help & Support:**
- FAQ
- Contact support
- Report bug
- Suggest feature

**About:**
- App version
- ToS
- Privacy policy
- Open-source licenses

## 98. Profile Tab — Creator Hub (If Approved)

Mobile-light version of full Creator Hub:
- Quick content upload
- Recent content performance
- Audience metrics summary
- Comments to respond to
- Earnings summary
- Link to full web Creator Hub

## 99. Profile Tab — Admin (If Admin)

RBAC-gated:
- Quick links to admin web panel sections
- Recent admin actions
- Pending queue summaries

---

# Part XVI — Admin System

## 100. Admin Panel — Overview

Internal ScaleUp web-based admin panel. RBAC.

## 101. Admin Roles

- **Super Admin:** Everything
- **Content Admin:** Content moderation, AI generation queue, curation, taxonomy management
- **Creator Admin:** Creator approval, tier management, payouts
- **Customer Support:** User support, account management, refund processing
- **Analytics:** Read-only metrics dashboards
- **TPO Liaison:** B2B college account management

## 102. Admin — Creator Moderation

- Pending application queue
- Approve / reject with reason
- Tier promotion / demotion
- Suspend (temporary) / Ban (permanent)
- View creator's full history

## 103. Admin — Content Moderation

- AI generation queue (review before publication)
- Flagged content review
- Pull content
- Manage featured content (editorial picks)

## 104. Admin — Taxonomy Management

- Review LLM-generated taxonomy entries from "pending review" queue
- Approve, edit, or reject
- Manually add new taxonomy items
- Refresh top company / top exam / top skill lists quarterly

## 105. Admin — User Support

- Search by phone/email/name
- View full account
- Reset password/login
- Refund processing
- Account deactivation/reactivation
- GDPR export handling
- Ticket queue

## 106. Admin — Analytics Dashboards

- DAU/WAU/MAU
- Retention curves by segment
- Funnel metrics (install → diagnostic → Day 7 → Pro conversion)
- Content performance
- Creator performance
- B2B metrics
- AI cost per active user
- Revenue metrics

## 107. Admin — Feature Flags

- Toggle features for cohorts
- A/B testing
- Gradual rollout
- Emergency kill switches

---

# Part XVII — Technical Architecture

## 108. Technical Architecture — Overview

Mobile-first with multiple web surfaces. AI-native. Multi-provider AI strategy.

## 109. Existing Code Audit

**Likely reusable:**
- Authentication (phone OTP, SSO)
- User data model
- Content storage + delivery (S3, presigned URLs)
- Whisper transcription
- Multi-provider AI integration layer
- Notes upload + AI processing
- Quiz generation (7 formats)
- Diagnostic core (needs UX redesign, not rebuild)
- Topic taxonomy database
- TopicTaxonomy LLM-extension
- BullMQ job queue + worker infra
- GDPR / audit log
- React Native mobile shell

**Needs consolidation:**
- Plan + Journey → single Plan
- 11 AI features → unified Compass

**Needs rebuild for new IA:**
- Home tab (activity-focused, replaces Home noticeboard)
- Compass tab (consolidates scattered AI features)
- Profile tab (consolidates Profile + Progress + Settings + Creator)
- Compass FAB
- Onboarding flow
- Diagnostic flow (objective-customized)
- Pre-populated taxonomy database structure

**Needs new build:**
- AI video generation pipeline
- TPO Dashboard
- Creator Hub web tools
- Referral attribution
- Revenue share calculation
- Coding evaluation web hand-off (Phase 2)

## 110. Mobile App Stack

- React Native (existing)
- State management (existing pattern)
- React Navigation
- Axios/Fetch with interceptors
- AsyncStorage/MMKV
- FCM for push
- Existing analytics pipeline
- AI server-mediated (cost control)

## 111. Web Surfaces Stack

- TPO Dashboard: Next.js + Tailwind + shadcn/ui
- Creator Hub: Next.js + Tailwind + shadcn/ui
- Admin Panel: Next.js + Tailwind + shadcn/ui
- Coding Eval (Phase 2): Monaco editor + Judge0 sandbox

## 112. Backend Services

**Existing (retain/refactor):**
- User, Content, Notes processing, AI orchestration, Quiz, Interview, Diagnostic, Notification, Analytics

**Needs work:**
- Plan service (consolidate Plan + Journey)
- Compass service (route AI requests by mode)

**New services:**
- AI content generation orchestrator
- TPO service
- Creator service
- Referral attribution service
- Revenue share calculation service
- Taxonomy service (pre-populated + LLM extension)

## 113. AI Integration Layer

**Multi-provider:**
- Anthropic Claude
- OpenAI GPT
- Whisper (transcription)
- ElevenLabs (voice generation)
- HeyGen/Synthesia (avatar)
- Kling/Veo/Sora (cinematic)

**Routing:**
- High-stakes: top-tier reasoning
- Real-time: fast mid-tier
- Batch: cheaper models
- Voice: ElevenLabs/Whisper hybrid
- Vision: vision-capable

**Cost management:**
- Cache common Compass responses
- Token budget per user per day (free tier)
- Pro tier higher cap
- Server-side rate limiting

## 114. Storage & Delivery

- MongoDB Atlas (existing) for user data
- S3 for video/audio/documents
- CloudFront CDN
- Redis for hot data
- Elasticsearch for content/creator search

## 115. Analytics Infrastructure

- Consistent event schema for all user actions
- Funnel analysis
- Cohort analysis by segment, college, source
- AI cost per user
- Content performance per piece
- Creator performance per piece
- Real-time dashboards
- Weekly business reviews

---

# Part XVIII — Progressive Unlock Implementation

## 116. Day 1-7 Phase

**Visible:**
- Home (activity-focused, 2-4 activities)
- Learn (basic — Continue Watching + Recommended + Browse by Topic)
- Compass FAB (tutor + Talk to Compass)
- Profile (minimal — readiness + this week + basic settings)

**Hidden:**
- Compass tab tiles (except Quiz Me + Talk to Compass + Make a Note)
- Profile drill-downs beyond basics
- Compete features
- Cohort features
- Creator following

## 117. Day 7-14 Phase

**Unlocks:**
- Compass tab fully (most tiles)
- Profile → My Progress drill-down
- Profile → My Plan deep view
- Creators You Follow surface
- First weekly recalibration

## 118. Day 14-21 Phase

**Unlocks:**
- Compass → Practice Interview tile
- Profile → Resume Builder (Phase 1.5)
- Full creator profile pages
- Comments on content

## 119. Day 21-30 Phase

**Unlocks:**
- Compass → Compete tile
- Event-based competitions
- Auto-formed peer cohorts
- Multi-objective support

## 120. Day 30+ Phase

**Full feature set available.**

## 121. Override

Profile → Settings → App Preferences → "Show all features now."

---

# Part XIX — Phased Roadmap

## 122. Phase 0 — Foundation Audit (Pre-development)

**Duration:** 2 weeks

**Activities:**
- Complete code audit
- Identify reusable vs consolidate vs rebuild
- Tech debt assessment (Plan vs Journey, fragmented AI)
- Architecture decision records for new builds
- Pre-populated taxonomy database design

**Deliverable:** Technical implementation plan with build vs reuse decisions

## 123. Phase 1 — Core MVP (Months 1-6)

### Goals
Ship the redesigned core product, AI content engine, B2B college dashboard, basic creator system. All 5 primary segments supported in product (Placement, Career Switch, Interview Prep, Competitive Exam, Upskilling).

### Engineering Builds

**Core App Restructure:**
- 4-tab IA: Home / Learn / Compass / Profile
- Activity-focused Home (varied recommended activities)
- Compass FAB consolidation (replace 11 AI features with named entity)
- Plan + Journey merge into single Plan system
- Pre-populated objective taxonomy database
- Required-time computation logic
- Customized adaptive diagnostic (varies by objective type)
- Rich diagnostic insights (calibration gap, behavioral patterns)
- Don't-wait-for-plan homepage UX
- Real-time plan building during diagnostic
- Auto-quiz inline at end of content

**AI Content Generation Pipeline:**
- Script generation service
- ElevenLabs integration (voiceover)
- HeyGen/Synthesia integration (avatar)
- Slide/diagram generation system (Manim, custom Python)
- FFmpeg assembly pipeline
- AI quality scoring system
- Human QA workflow
- First 300+ modules generated across all 5 segment categories

**B2B College System:**
- TPO Dashboard web app
- Student roster management
- Syllabus → mock exam pipeline (leverages existing OCR)
- Cohort analytics
- Reporting
- Mobile integration for assigned mock exams

**Creator System v1:**
- Application + approval workflow (admin + peer endorsement)
- Tier system (Rising/Core/Anchor with domain badges)
- Creator Hub mobile-light + web full
- Content upload tools
- Audience analytics
- Referral link generation
- Revenue share calculation engine
- Payout system

**Compass Tab Features (Phase 1):**
- Quiz Me
- Practice Interview
- Talk to Compass (conversational AI with guardrails)
- Make a Note (with all AI generation features)
- Compete (basic — weekly Friday quiz battle)
- Resume Builder MVP
- Mock Exam (B2B only)
- My Activity (history of all AI usage including in-content Q&A)
- Full context across all AI interactions

**Compass FAB Features:**
- Tutor mode in content player
- In-content Q&A (saved to history)
- Quick conversation from any screen
- Contextual mode detection

**Content Types:**
- Video (primary)
- Audio (derived + standalone, podcast-style)
- Audiobook-style narration of notes
- Notes / Infographics

**Onboarding Flow:**
- Account creation
- Objective selection (using pre-populated taxonomy + LLM extension)
- Minimal background
- Required-time computation + commitment
- Customized adaptive diagnostic
- Rich diagnostic insights reveal
- Land on Home (with plan-baking-in-background UX)

**Profile Tab:**
- Full settings panel
- Multi-objective support
- My Plan deep-view (week-by-week + topic-level)
- My Progress & Analytics
- My Content (viewed/liked/saved/playlists/followed)
- Creator Hub (if approved)
- Apply as Creator
- Data download / deletion (GDPR)
- Notification preferences

### Out of Phase 1
- Coding evaluation
- Creator communities
- Creator cohorts
- Expert sessions marketplace
- 1:1 mentorship
- Hireability badging
- Hiring marketplace
- Regional language expansion (Hindi only initially)
- User-generated public quizzes
- Public notes sharing

## 124. Phase 2 — Expand (Months 6-12)

### Goals
Unlock SDE coding segment, expand monetization, add creator monetization layers, regional language.

### Engineering Builds

**Coding Evaluation:**
- Web hand-off platform
- Code execution sandbox (Judge0 integration)
- Mobile-web sync
- Practice mode + assessment mode (B2B)
- Multi-language support

**Creator Communities (Core+):**
- Community creation tools
- Community feed (posts, polls, links)
- AMAs
- Moderation tools
- Community-only content

**Expert Sessions Marketplace:**
- Curated expert panel onboarding
- Session booking
- Payment processing
- Integrated video call (Zoom/Meet)
- Pre/post session flow
- Ratings/reviews
- Refund/dispute handling

**Resume Builder Advanced:**
- ATS scoring
- Role-specific optimization
- Multiple variant management
- Expert review option (Expert Sessions integration)

**Hindi Language Expansion:**
- Top 100 modules in Hindi
- UI localization
- Hindi Compass modes
- Hindi creator support

**Multi-tab Search:**
- Unified search across content, creators, topics, communities

**Content Type Additions:**
- Long-form audiobook content
- Podcast-format
- Interactive infographics

**Voice Mode for Compass (Phase 2 start):**
- Compass voice conversation
- Mobile-optimized
- Whisper + ElevenLabs pipeline

## 125. Phase 3 — Monetize & Compound (Months 12-18)

### Goals
Higher-margin monetization. Deeper creator engagement.

### Engineering Builds

**Creator-Led Cohorts (Core+):**
- Cohort creation tools
- Enrollment + payment
- Calendar/schedule
- Live session integration
- Exclusive cohort content
- Cohort-only quizzes/assessments
- Completion certificates

**1:1 Mentorship Marketplace (Core+):**
- Mentor onboarding
- Availability calendar
- Booking system
- Integrated video call
- Pre/post flow
- Ratings + feedback
- Recurring sessions

**Placement Guarantee Program:**
- High-ticket package management
- Enhanced features bundle
- Outcome tracking
- Refund guarantee processing
- Dedicated support tier

**Additional Languages:**
- Tamil, Telugu, Marathi
- Voice generation expansion
- UI localization

**Advanced Plan Features:**
- Multi-objective optimization
- Plan templates (curated)
- Custom plan editor (power user)

**User-Generated Public Quizzes:**
- Quiz sharing within cohorts
- Public quiz library (gated to Day 30+)
- Quiz rating + moderation

## 126. Phase 4 — Defensible Moat (Months 18-24+)

### Goals
Long-term advantages that compound.

### Engineering Builds

**Hireability Badging:**
- Verifiable readiness profiles
- Public profile generation (opt-in)
- Outcome correlation analytics
- Credential issuance system
- Employer-facing profile views

**Hiring Marketplace:**
- Employer onboarding (B2B)
- Candidate search + filter
- Outreach tools
- Interview scheduling
- Placement tracking
- Revenue share with placed candidates (optional)

**Advanced Creator Features:**
- Collaboration tools (co-created content)
- Creator subscriptions (creator-tier paywalls)
- Creator-led courses with certificates
- Brand partnerships (sponsored, disclosed)

**Compass 2.0:**
- Long-term memory across conversations
- Proactive interventions
- Improved interview eval (sub-second response)
- Multi-modal (image + voice + text seamless)

**International Expansion:**
- New geographies (Bangladesh, Sri Lanka, UAE, etc.)
- Localization
- Region-specific objective trees

**Platform APIs:**
- Public API (LMS, ATS, HR integrations)
- Webhook system
- Developer documentation

---

# Part XX — Explicit Exclusions

## 127. What's Killed (Will Not Be Built)

- **YouTube curation / embedding** — All content owned, creator-uploaded, or AI-generated
- **Public notes marketplace** — Notes personal, share only by explicit action to specific recipients
- **Global all-time leaderboards** — Only event-specific and college-cohort
- **Always-on streak gamification as a feature** — Streak is quiet indicator only
- **Daily challenges as a primary surface** — Competitions are event-based, opt-in
- **Creator marketplace UI (browsable marketplace)** — Creators browsed by domain + tier
- **Social graph / followers feed** — No Instagram-style feed
- **Public like/comment counts** — Engagement metrics creator-private
- **Infinite content scroll** — Structured carousels and grids only
- **General-purpose chat with Compass** — Focused on learning + career
- **Community voting on content quality** — AI scoring + curation + outcome signals only

## 128. What's Out of Scope for This PRD

- Pricing strategy (business decision)
- GTM and marketing
- Hiring and team structure
- Legal entity / regulatory
- Funding strategy
- Brand identity (visual design system separately)

---

# Part XXI — Success Metrics

## 129. Phase 1 Success Metrics

**Activation:**
- Time to first felt value: <8 min from install (target accounts for activity-focused home letting users start consuming content earlier)
- Diagnostic completion rate: >85% of those reaching it
- First activity completion rate: >70% of those completing diagnostic

**Retention:**
- Day 7 retention (B2C): >35%
- Day 7 retention (B2B college): >70%
- Day 30 retention (B2C): >15%
- Day 30 retention (B2B college): >50%

**Engagement Quality:**
- Auto-quiz attach rate: >60% of completed videos
- Plan adherence: >60% of users complete >70% of weekly recommended activities
- Multiple-activity rate: average user completes 2.5+ activities per active day
- Readiness score perceived accuracy: >70% in monthly survey

**Product Health:**
- Compass interaction rate: >40% of DAU interact with Compass daily
- In-content Q&A usage: >25% of completed videos have at least 1 Q&A
- Content quality scores: average >8.0/10
- AI cost per active user: <₹250/month

**B2B:**
- TPO demo to signed conversion: >25%
- First 10 colleges signed by Month 6
- College student MAU: >70% of enrolled students

**Creator System:**
- First 20 approved creators by Month 6
- Creator content quality (user ratings): avg >4.0/5
- Creator-attributed installs: >5% of total Phase 1 installs

## 130. Phase 2+ Success Metrics

**Phase 2:**
- Coding evaluation usage: >40% of SDE-objective users
- Expert session bookings: >100/month by Month 12
- Hindi adoption: >30% of users in Hindi-speaking states
- 22-25 segment % of MAU: >30%

**Phase 3:**
- Creator cohort enrollments: >500 cohort members
- Mentorship bookings: >200 sessions/month
- Pro tier conversion: >5%
- Placement guarantee enrollments: >50

**Phase 4:**
- Verified readiness profiles: >1000
- Employer integrations: >10
- Outcome data points: >5000 (statistically meaningful)

---

# Part XXII — Open Decisions

## 131. Open Decisions

1. **Hindi vs English first for AI-generated content** — Recommend English first, Hindi variants for top 100 modules in parallel.

2. **Free vs Pro tier feature split** — Recommend: Home / Learn / basic Compass free; advanced practice (unlimited interviews, unlimited Compass, expert sessions) paid.

3. **Creator tier promotion exact thresholds** — Data-driven thresholds after 6 months of data.

4. **AI provider routing per task** — Build framework Phase 0; specific decisions per build.

5. **B2B college pricing model** — Recommend ₹500-1000/student/year, multi-year discounts.

6. **Anchor creator recruitment list** — Decision needed before Phase 1 Month 6.

7. **Onboarding language** — Recommend English with Hindi UI toggle in Phase 1; bilingual content Phase 2.

8. **Plan recalibration aggressiveness** — Recommend max 30% upcoming-week change per cycle; user notification mandatory.

9. **User data retention** — Recommend lifetime for active accounts; 90 days post-deactivation; user-driven export rights.

10. **Coding evaluation build vs buy (Phase 2)** — Decision Phase 2 start.

11. **Pre-populated taxonomy refresh cadence** — Recommend quarterly.

12. **Compass visual identity** — Icon design needed (current placeholder: 🧭).

---

# Part XXIII — Glossary

**C2O (Content-to-Outcome):** Core thesis — content consumption must connect to measurable outcomes via auto-quiz, plan recalibration, and readiness scoring.

**Compass:** ScaleUp's unified AI companion with contextual modes; lives as FAB everywhere + as its own tab.

**Diagnostic:** Initial adaptive assessment customized by objective type to establish baseline.

**Plan:** AI-generated personalized roadmap from current state to objective achievement.

**Readiness Score:** 0-100 metric representing predicted likelihood of objective achievement.

**Objective:** User's declared goal with timeline (drawn from pre-populated taxonomy).

**Pre-Populated Taxonomy:** Curated database of objectives, target companies, exams, skills, and associated skill trees — avoids LLM round-trips for common cases.

**Required Time:** Hours/week computed from objective + timeline + current proficiency; not asked from user.

**Activity-Focused Home:** Home shows multiple recommended plan-aligned activities; user picks what fits their mood/energy/time.

**Calibration Gap:** Difference between user's self-rated proficiency and actual diagnostic performance; surfaced honestly in insights.

**Auto-Quiz:** Quiz automatically generated and presented immediately after content consumption.

**Anchor / Core / Rising Creator:** Three-tier creator credibility system with domain-specific badges.

**TPO (Training & Placement Officer):** B2B buyer at colleges.

**ScaleUp Originals:** ScaleUp-commissioned content with industry experts.

**Cohort:** Group of users (peer-formed, college-formed, or creator-led).

**Attribution:** System tracking which user came from which creator for revenue share.

**Hireability Badge (Phase 4):** Verifiable readiness credential employers can trust.

**In-Content Q&A:** Questions asked to Compass during content playback; saved to history for review.

**Full Context:** Every AI interaction has access to user's complete journey (objective, plan, progress, content consumed, performance, conversations).

---

**End of PRD v2.0**

This document is the foundation for ScaleUp's complete rebuild. It is intentionally comprehensive. Designers, engineers, and other AI assistants should use it as the source of truth.

Subsequent revisions should be tracked in a change log.
