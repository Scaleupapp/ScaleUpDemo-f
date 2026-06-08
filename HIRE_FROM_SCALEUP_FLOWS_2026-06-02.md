# Hire from ScaleUp — End-to-End User Flow Guide

**Date:** 2026-06-02 · **Status:** Feature is BUILT + DEPLOYED + LIVE (flag on). This is the canonical step-by-step guide to how every persona moves through it.

> **The one-sentence story:** A learner who's *provably ready* opts in from the app → an employer searches an evidence-ranked, anonymized pool on the web → the employer expresses interest → the candidate approves → identity, contact, and verified proof are revealed mutually. **Nobody's identity leaks until they choose.**

---

## 0. The cast + the surfaces

| Persona | Surface | Where | What they do |
|---|---|---|---|
| **Candidate** (learner) | Mobile app (iOS / Android) | "You" tab → **Open to opportunities** | Opt in, set recruiter details, approve/decline employer interest |
| **Employer** (hiring manager) | Web | **`https://scaleup-web-seven.vercel.app/hire`** | Sign up, search, view candidates, express interest, connect |
| **Admin** (ScaleUp team) | Web admin / API | `/api/v1/admin/*` | Vet employers (grant "contact" tier), monitor connections |

**The 3 trust gates (memorize these — every flow respects them):**
1. **Gate 1 — Candidate opts in.** Nothing about a learner is discoverable until they flip the switch.
2. **Gate 2 — Employer is approved to contact.** Anyone can *browse* with a verified work email; only an admin-approved employer can *reach out*.
3. **Gate 3 — Candidate approves each connection.** Identity + contact are revealed only when the candidate says yes — per employer, per request.

---

# FLOW A — THE CANDIDATE (mobile app)

### A0. Prerequisite: who can even opt in
The feature is **self-gating and eligibility-gated**. Before a learner ever sees it, two things must be true:
- **The feature flag is on** (it is). The app silently checks `GET /api/v2/you/talent` when the You tab loads; a `404` (flag off) → the entry is hidden entirely.
- **The learner is eligible**, meaning:
  - Their primary goal is **career-intent** — `interview_preparation`, `career_switch`, or job-focused `upskilling`. (Exam-prep like NEET and casual learning are excluded — noise to a recruiter.)
  - They have **real evidence** — at least one completed assessment / capstone / interview. An empty profile never enters the pool.

If they're not eligible, they can still open the screen, but opting in returns a friendly nudge (see A2).

### A1. Discovering it — the entry point
- The learner opens the **"You" tab**.
- A new row appears: **"Open to opportunities"** (iOS: in a *Career* section of the You screen; Android: in the *My learning* section). It shows their current state (off / "You're discoverable") and a small **pending-count badge** if employers are waiting on them.
- *This row is invisible to anyone on an old app build or when the flag is off — so existing users see nothing change.*

### A2. Opting in — the "Open to Work" screen
Tapping the row opens **"Open to work"** (iOS `V2OpenToWorkView` / Android `V2OpenToWorkScreen`):

1. **The toggle** — *"Show me to employers."*
   - Flipping it **ON** → `POST /api/v2/you/talent/opt-in` with their recruiter details. The backend resolves their primary objective, **builds a snapshot from their live readiness** (reusing the same engine behind the verifiable proof badge), checks eligibility, and creates their **Talent Profile**.
   - Flipping it **OFF** → `POST /api/v2/you/talent/opt-out` → they're **instantly removed from search** (profile paused, prefs kept).
2. **The mandatory trust explainer** (this is the heart of consent — verbatim copy):
   - ✓ *"Employers see your readiness, skills & evidence — and why you rank."*
   - ✕ *"They never see your name, photo, phone or email until you approve a connection."*
3. **Recruiter details** (editable, saved by re-calling opt-in — there's no separate PATCH):
   - **City** (e.g. Bangalore)
   - **Notice period** (e.g. 30 days)
   - **Work preference** (Onsite / Remote / Hybrid)
4. A link through to the **connection inbox** (A4).
5. A reassurance line: *"Turn this off anytime and you instantly disappear from search."*

**If they're not eligible:** instead of a confusing error, the screen shows a friendly state — e.g. *"Take an assessment on a career goal to join the talent pool"* (from the backend's `NOT_ELIGIBLE` / `NO_SNAPSHOT` / `NO_OBJECTIVE` codes).

### A3. What an employer can and can't see (the candidate's mental model)
Once opted in, the candidate's profile is discoverable to **verified employers** as an **anonymized card**:
- ✅ Visible: readiness band + score vs. target, measured competencies, evidence counts (assessments / capstones / interviews), coverage %, city, notice period, work pref, and a stable pseudonym ("Candidate #483291").
- ❌ Never visible (pre-approval): name, photo, phone, email, or the actual proof-badge link.

### A4. Receiving interest — the push
When an employer expresses interest, the candidate gets a **real push notification** (+ in-app notification):
> *"A verified employer is interested — an employer wants to connect for [role]. Review and approve in your inbox."*

The employer's identity is **masked** even in the notification — no company name.

### A5. The connection inbox — approve or decline
Opening **"Interested employers"** (iOS `V2ConnectionInboxView` / Android `V2ConnectionInboxScreen`) — `GET /api/v2/you/talent/connections`:
- **Pending request card:** *"A verified employer"* + the role they're hiring for + the employer's short message + two buttons:
  - **Approve & connect** → `POST .../connections/:id/approve`
  - **Decline** → `POST .../connections/:id/decline`
  - Fine print: *"Approving shares your name + contact with this employer only."*
- **Approved card:** *"Connected"* — now showing the **revealed employer** (company name, contact person, email).
- **Declined:** greyed out.
- Footer reassurance: *"Three gates protect you: you opt in · employers are vetted · you approve each connection."*

### A6. After the candidate approves
- The **employer** is emailed (*"A candidate accepted your interest"*) and, on their dashboard, the candidate's **name, email, phone, and verified proof-badge link** are revealed — **to that one employer only**.
- The **candidate** sees the employer's company + contact in their inbox.
- This mutual reveal **is** the connection (an email-intro model; a full in-app chat is a future enhancement).

### A7. Staying in control
- **Edit details** anytime (re-saves via opt-in).
- **Withdraw** anytime (toggle off → instantly out of search; pending requests freeze).
- Every reveal is **logged** in a durable audit trail (DPDP compliance).

### Candidate-side states at a glance
| State | What the candidate sees |
|---|---|
| Ineligible | Friendly "take an assessment on a career goal" nudge |
| Opted out (default) | Toggle off; not in any search |
| Opted in, no interest yet | "You're discoverable"; empty inbox |
| Interest received | Push + a pending card + badge count |
| Approved | "Connected" + employer revealed |
| Declined | Greyed card; employer never learns who they were |

---

# FLOW B — THE EMPLOYER (web)

### B0. Arriving — the landing page
The employer goes to **`https://scaleup-web-seven.vercel.app/hire`**:
- Value-prop hero (*"Hire ScaleUp-ready talent"*) + a sign-in card.
- The whole `/hire` experience is a **light, LinkedIn-meets-Apple** product — distinct from the learner app's dark theme.

### B1. Sign up / sign in — passwordless magic link
1. Employer enters their **work email** (free providers like gmail are rejected; a corporate domain is required).
   - **New employer** → toggles "first time?" and adds **company + name** → `POST /api/employer/auth/signup`.
   - **Returning** → `POST /api/employer/auth/login`.
2. Screen shows *"Check your email for a sign-in link."*
3. They receive a **real email** (*"Your ScaleUp Hire sign-in link"*) with a button → opens **`/hire/auth/callback?token=…`**.
4. The callback verifies the token (`POST /auth/verify` → falls back to `/auth/complete`), stores their session JWT, and redirects to **`/hire/search`**. Links expire in 30 minutes and are single-use.

### B2. The two access tiers (this is Gate 2)
- **Browse tier** — granted automatically once their **work email is verified**. They can search and view full anonymized profiles + "why this rank."
- **Contact tier** — granted only after an **admin approves them** (Flow C). Until then, a banner reads *"Browsing enabled — contact access is under review (usually under a business day)."* The "Express interest" button is disabled with a clear "under review" state.
- A chip in the top nav always shows their tier: **BROWSE** or **CONTACT**.

### B3. Search & filter — `/hire/search`
- A **filter rail**: Readiness band (Exceptional / Strong / Competitive), Proof (Verified badge / Achieved outcome), Skills, Location.
- Results are an **evidence-ranked list of anonymized cards** (`GET /api/employer/search`). Each card:
  - Rank (#1, #2…), a 🔒 locked avatar, **Candidate #NNNNNN**, band pill, ✓ Achieved / ✓ Verified marks.
  - Role · city · notice period; skill chips.
  - A one-line **"Why #N"** (e.g. *"reported a confirmed offer, broadest evidence in the cohort, active this week"*).
  - Big **readiness score vs. target** + a **View profile** button.
- **Ranking order (deterministic):** Achieved outcome → Verified badge → Readiness band → score → evidence depth/coverage → recency. (Achievers always float to the top; ties break stably.)

### B4. The candidate profile — `/hire/candidates/[profileId]`
Tapping a card opens the anonymized profile (`GET /api/employer/candidates/:id`):
- **Header:** 🔒 handle, role · city · notice, band tag (Exceptional / Achieved / Verified), and a **readiness ring** (e.g. 88).
- **Measured competencies** — clean bars (System Design 91, Database Design 88…).
- **Evidence** — assessments / capstones / AI interviews / % of role measured.
- **"Why this rank" panel** (the differentiator nobody else can show) — each signal **backed by evidence**:
  - ✓ *Achieved their goal* — reported a confirmed outcome.
  - ✓ *Independently verifiable* — published a proof badge.
  - ▲ *Eight points clear of the bar* — 88 vs 80 target.
  - ◈ *Broadest evidence in the cohort* — 14 assessments across 9/10 competencies.
- Still **zero PII** at this stage.

### B5. Expressing interest (requires Contact tier — Gate 2)
- An **Express interest** card: a short message + the role they're hiring for.
- **Send** → `POST /api/employer/candidates/:id/interest` → creates a **connection request** (idempotent — re-sending doesn't duplicate).
- If they're only on the **browse** tier: the form is replaced by *"Contact access is under review."*
- If the candidate just opted out: *"This candidate just became unavailable."*
- Fine print: *"No contact details are shared until the candidate approves."*

### B6. The connections dashboard — `/hire/connections`
- Lists every interest they've sent (`GET /api/employer/connections`) with a status badge:
  - **Pending** → *"Awaiting the candidate's decision."* (still anonymized)
  - **Approved** → the **reveal block**: candidate's **name, email, phone**, and a **"View verified proof"** link to their badge.
  - **Declined** → greyed.
- When a candidate approves, the employer also gets an **email** (*"A candidate accepted your interest — sign in to see their details"*).

### B7. Reaching out
With the reveal, the employer emails/calls the candidate directly and can independently verify the proof badge. The intro is made; ScaleUp brokered it on the candidate's terms.

### Employer-side states at a glance
| State | What the employer sees |
|---|---|
| Signed up, email unverified | Must click the magic link |
| Browse tier | Search + profiles + "why"; can't contact yet |
| Contact tier (approved) | Everything + Express interest enabled |
| Interest sent | Pending card in Connections |
| Candidate approved | Email + revealed contact + proof link |
| Candidate declined / opted out | Greyed / "no longer available" |
| Feature flag off | Calm "Not available yet" on every page |

---

# FLOW C — THE ADMIN (vetting + monitoring)

### C1. Employer approval queue (Gate 2 in action)
**Who can do it:** any ScaleUp user whose account has `role: 'admin'`. The endpoints are guarded by `auth + rbac('admin')`, so the request's JWT must carry `role: 'admin'`. (Admin role is set on the User record — not self-serve.)

**Where they do it — in the app:** **Profile → Admin Dashboard → "Company Requests"** (right beside "Creator Applications"). Built into both apps (iOS `AdminEmployerRequestsView`, Android `AdminEmployerRequestsScreen`):
- The screen lists each pending company — **company name, contact person + title, work email, LinkedIn, applied date** (`GET /api/v1/admin/employers/pending`).
- The admin confirms it's a real hiring org, then taps:
  - **Approve** → `POST /api/v1/admin/employers/:id/approve` → grants the employer **contact tier** (they can now express interest).
  - **Reject** → `POST /api/v1/admin/employers/:id/reject`.
- Empty state: *"No pending company requests."*

This is the human trust checkpoint — two taps, no curl. Slow-but-bulletproof while volume is low; automate later.

### C2. Connections monitoring (abuse watch)
- `GET /api/v1/admin/connections` — a rollup of all connection requests (`{ total, byStatus, rows }`) so the team can spot abuse (e.g. an employer blasting interest).
- Every profile **view** and identity **reveal** is recorded in the `MarketplaceAuditLog` (DPDP trail).

---

# THE FULL END-TO-END TIMELINE (one journey, both sides)

1. **[Candidate]** Builds readiness on a career goal in the app (assessments, drills, interviews) → becomes eligible.
2. **[Candidate]** You tab → *Open to opportunities* → toggles **"Show me to employers"** on, sets city / notice / work-pref. → *Talent Profile created.*
3. **[Employer]** Goes to `…/hire` → enters work email → gets a magic link → signs in. → *Browse tier.*
4. **[Admin]** Sees the employer in the pending queue → approves. → *Employer gets Contact tier.*
5. **[Employer]** `/hire/search` → filters "Backend Engineer, Strong+, Bangalore, Verified" → sees a ranked, anonymized list.
6. **[Employer]** Opens a candidate → reads competencies, evidence, and **"why this rank"** → clicks **Express interest** with a note. → *Connection request created.*
7. **[Candidate]** Gets a **push**: *"A verified employer is interested."* → opens the inbox → sees the masked employer + message.
8. **[Candidate]** Taps **Approve & connect**. → *Mutual reveal + audit-logged.*
9. **[Employer]** Gets an **email**: *"A candidate accepted your interest"* → `/hire/connections` now shows the candidate's **name, email, phone, proof link**.
10. **[Both]** Connected. Employer reaches out, verifies the badge, and the hiring conversation begins — entirely on the candidate's terms.

---

# TRUST & PRIVACY MODEL (what's revealed, when)

| Stage | Employer sees about the candidate | Candidate sees about the employer |
|---|---|---|
| Candidate browsing the pool | Anonymized card (band, evidence, why) — **no PII** | — |
| Employer views full profile | Full evidence + "why" — **still no PII** | — |
| Interest sent (pending) | Still anonymized | "A verified employer" + role + message — **masked** |
| **Candidate approves** | **Name, email, phone, proof link** (this employer only) | **Company, contact person, email** |
| Candidate declines / withdraws | Nothing further; greyed | — |

- **Every reveal and every profile view is written to a durable audit log** (DPDP).
- Eligibility filtering + ranking integrity mean a recruiter never sees fabricated readiness — the "why this rank" is always evidence-backed (and doubles as anti-gaming).

---

# NOTIFICATIONS MATRIX

| Trigger | Who's notified | How | Copy |
|---|---|---|---|
| Employer expresses interest | Candidate | Push + in-app | "A verified employer is interested…" (employer masked) |
| Candidate approves | Employer | Email | "A candidate accepted your interest — sign in to see their details" |
| Employer signs up / logs in | Employer | Email (magic link) | "Your ScaleUp Hire sign-in link" (30-min, single-use) |
| Candidate declines | Employer | (none — silent; status just updates) | — |

*All notifications are best-effort — a delivery failure never breaks the underlying action.*

---

# APPENDIX — the endpoints behind each step (for QA / engineering)

**Candidate (learner JWT, all 404 when flag off):**
- `GET /api/v2/you/talent` — am I opted in? (also the self-gating probe)
- `POST /api/v2/you/talent/opt-in` `{city, noticePeriod, workPref}` — opt in / save prefs
- `POST /api/v2/you/talent/opt-out` — withdraw
- `GET /api/v2/you/talent/connections` — inbox
- `POST /api/v2/you/talent/connections/:id/approve` · `/decline`

**Employer (employer JWT; magic-link auth):**
- `POST /api/employer/auth/signup` · `/login` · `/verify` · `/complete`
- `GET /api/employer/search?bands=&skills=&city=&proof=&…` — ranked anonymized list
- `GET /api/employer/candidates/:id` — anonymized profile + why
- `POST /api/employer/candidates/:id/interest` `{message, roleContext}` — *(contact tier only)*
- `GET /api/employer/connections` — sent list + reveals

**Admin (admin JWT):**
- `GET /api/v1/admin/employers/pending` · `POST /api/v1/admin/employers/:id/approve` · `/reject`
- `GET /api/v1/admin/connections`

**Key data objects:** `TalentProfile` (consent + denormalized snapshot), `EmployerAccount` (emailVerified→browse, approvalStatus→contact), `ConnectionRequest` (requested→approved|declined), `MarketplaceAuditLog` (view/interest/reveal).

**Live surfaces:** Web `https://scaleup-web-seven.vercel.app/hire` · Backend `https://api.scaleupapp.club/api/employer/*` + `/api/v2/you/talent*` · Apps: iOS build 187 (TestFlight) + Android (main).

---

*Feature flag: `FEATURE_EMPLOYER_MARKETPLACE` (ON). Rollback: `scripts/ops/flip-employer-flag.sh off` via the Run-DB-Migration workflow.*
