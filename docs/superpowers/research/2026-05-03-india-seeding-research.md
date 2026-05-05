# India Seeding Research — Master Synthesis (2026 and Beyond)

**Phase:** Phase 0 deliverable for the Day-1 Diagnostic Foundational Redesign.
**Date:** 2026-05-03
**Prepared by:** Research dispatch (3 parallel research streams).
**Status:** Ready for Nirpeksh review → unblocks Phase 0.5 (taxonomy + question bank seeding).

---

## How to use this document

This is the master synthesis. It collapses ~2,150 lines across three detail files into one decision-ready overview. The detail files are the source of truth — read those when you need the underlying entries.

| Detail file | Scope | Lines |
|---|---|---|
| [`india-skills-research.md`](./2026-05-03-india-skills-research.md) | Top 30 in-demand skills + AI literacy across 10 domains | 361 |
| [`india-exams-curricula-research.md`](./2026-05-03-india-exams-curricula-research.md) | 64 exam entries (~50 distinct exam taxonomies) + 14 boards + 10 UG/professional streams | 979 |
| [`india-companies-careers-research.md`](./2026-05-03-india-companies-careers-research.md) | 62 companies + 25 career transition patterns | 815 |

All three are sourced primarily from Indian / India-focused publications: NASSCOM, LinkedIn India, Naukri JobSpeak, WEF FoJ India cut, India Skills Report 2026, official conducting bodies (UPSC, NTA, NMC, ICAI, CISCE, CBSE, IBO, Consortium of NLUs), Naukri/Inc42/YourStory, IIMA reports, Big-4 publications. ~150 unique sources cited across the three files.

---

## 1. Headline signals — the India hiring/learning market in 2026

The numbers below are the load-bearing data points that should shape what we seed and how we frame it to users.

### Workforce / hiring climate

- **Naukri JobSpeak FY26 closed at +8% YoY**, the strongest job growth in 3 years. Feb 2026 index hit 3,233 (+12% YoY). White-collar hiring momentum is real, not just AI noise.
- **AI/ML hiring +49% YoY** (Naukri); **Indian MNCs grew AI hiring +82% YoY vs +43% for foreign MNCs** — a striking signal that domestic firms are out-investing global ones in AI talent.
- **Fresher hiring (0-3 yrs) +17% YoY**; the **20+ LPA band grew +23%** — barbell hiring (juniors + senior IC), squeeze on mid-level.
- **GCC count crossed 2,100 with ~2M professionals.** Bengaluru ~37%, Hyderabad ~21%, Pune/Gurugram/Chennai growing. Net 4.25-4.5L new GCC jobs projected in FY26 (Flexiple/JLL/Persol).
- **IT services net headcount fell ~7,400 across TCS+Infy+Wipro+HCL+TechM in FY26.** TCS plans 25k freshers in FY27 (down from 40k), Infosys plans 20k. **Slowing, not collapsing** — still the largest absolute hirers.

### Skills / talent gaps

- **NASSCOM: India needs 1M+ AI professionals by 2026.** Current AI talent gap is ~1M.
- **Cybersecurity: ~1M needed against ~80K qualified.** RBI 24x7 SOC mandate + 6-hour CERT-In incident reporting drives this.
- **WEF: ~44% of core skills will change by 2026.** Analytical thinking, AI/ML application, tech literacy are the global top 3, all confirmed for India.
- **LinkedIn India: ~60% YoY growth in AI hiring.** AI Engineer + Prompt Engineer top "Jobs on the Rise" 2026.
- **38% of Indian job seekers feel unprepared for current tech shifts; 74% of recruiters report difficulty finding qualified talent** (LinkedIn India 2026).
- **Skills > degrees: ~85% of Indian employers now prioritise skills over degrees** in at least some hires (India Skills Report 2026).

### Compliance / regulatory (uniquely Indian)

- **2026 is the DPDP Act execution year** (Rules notified Nov 2025). Every regulated entity needs DPOs.
- **RBI 2FA mandate goes live 1 April 2026.** Plus continued GST + Ind AS / IFRS convergence + SEBI BRSR Core for top 1,000 listed entities.
- **The compliance/finance niche (DPDP, RBI, SEBI, GST, Ind AS) is uniquely Indian** — no global skill substitutes — and structurally growing.

### Sectoral tailwinds

- **Semiconductors:** India Semiconductor Mission targets ~10L new jobs by 2026. Tata Dholera fab + Micron Sanand + 20+ fabless design centres hiring.
- **Green / EV:** SEBI BRSR Core mandate + PLI Auto/ACC + Green Hydrogen Mission. Green talent gap of 1.5-2M against 7.29M projected base by FY28.
- **Vernacular / Bharat:** ONDC, Bhashini, account-aggregator unlocking the next 500M users in regional languages. Sarvam/Krutrim/CoRover hiring Indic-NLP roles.

### IPO/funding-driven hiring re-energy

2025-26 IPOs that are actively hiring: Meesho, Ather, Urban Company, Lenskart, Groww, Pine Labs, PhysicsWallah. 2026 H1 IPO pipeline: Aye Finance, Fractal, Amagi, Shadowfax, SEDEMAC.

---

## 2. Top skills for seeding (collapsed from 30)

Full ranked list with descriptions in [`india-skills-research.md`](./2026-05-03-india-skills-research.md). Tiering: **Critical** (severe shortage + cross-sector demand) · **High** (strong, multi-sector) · **Emerging** (growing fast, smaller base).

### Critical (must-seed for v1)
- Generative AI & LLM application building
- Prompt engineering & AI workflow design
- Cloud architecture (AWS/Azure/GCP)
- Cybersecurity ops & SOC engineering
- Data engineering (Spark/Snowflake/Databricks/dbt)
- Applied ML & MLOps
- Full-stack software development (MERN / Java Spring Boot + React + AWS)
- Data analytics & SQL storytelling
- RBI/SEBI/DPDP compliance & data privacy (DPO)
- Stakeholder communication & executive storytelling
- Critical thinking & structured problem-solving
- Adaptability & continuous learning

### High (must-seed)
- DevOps, SRE & platform engineering
- Product management (B2B SaaS & AI products)
- UX / product design (Figma + AI design)
- Performance marketing (Google + Meta + attribution)
- AI product engineering (RAG, agents, vector DBs)
- Semiconductor / VLSI design
- FP&A and corporate finance modelling
- IFRS / Ind AS reporting
- GST, Indian tax & regulatory advisory
- Enterprise B2B sales & account management
- Leadership & people management (first-time manager)
- Customer success & retention
- Project & program management (Agile + PMP)

### Emerging (seed selectively, watch for demand growth)
- SEO & AI-search optimisation (GEO/AEO)
- Sustainability, ESG reporting & climate risk (BRSR)
- EV, battery & renewable energy engineering
- Workforce/people analytics & HR tech
- Vernacular / Bharat-market content & voice AI

### AI literacy per domain

10 domains covered with 3-5 specific tools/skills each:
1. Product Management — Claude/ChatGPT for PRDs, Dovetail AI, Linear AI, Claude Agent SDK, Braintrust evals
2. Software Engineering — Claude Code, Cursor, Copilot, RAG with Pinecone/pgvector, AI debugging
3. Data Science — Snowflake Cortex, Databricks Genie, Hex Magic, ThoughtSpot Sage, Power BI Copilot
4. Marketing — Meta Advantage+, Pencil, Adcreative.ai, Profound (GEO/AEO), Lifesight
5. Design — Figma AI, Magician, Midjourney, Adobe Firefly, Dovetail AI, AI-native UX patterns
6. Sales — Gong, Chorus, Clay, Apollo AI, Salesforce Einstein, HubSpot Breeze
7. HR — Textio, Eightfold, HireVue, Visier, Workday Illuminate, Leena AI (Indian)
8. Finance — Rossum, Vic.ai, Datarails, Pigment AI, Taxmann AI (Indian), Excel Copilot
9. Consulting — Perplexity Pro, Claude with web, Gamma, Tome, custom GPTs / Claude Projects
10. Founder — Claude Code/Lovable/Bolt for MVPs, CoRover/Yellow.ai (Indian), Zapier AI/n8n

Indian AI tooling deliberately surfaced where applicable (Sarvam, Krutrim, CoRover, Yellow.ai, Leena AI, Taxmann AI).

---

## 3. Top exams for seeding (50 across 14 categories)

Full breakdown with topic taxonomies and aspirant volumes in [`india-exams-curricula-research.md`](./2026-05-03-india-exams-curricula-research.md). Each exam entry includes the testable subjects/sections — **these are the ready-to-use diagnostic topic lists**.

### Tier-1 priority — highest aspirant volume (must-seed for v1)

| Exam | Conducting body | Annual aspirants | India context |
|---|---|---|---|
| **JEE Main** | NTA | ~14-15 lakh | Engineering entrance — biggest STEM funnel |
| **NEET UG** | NTA | ~24 lakh | Medical entrance — largest single exam in India |
| **CUET UG** | NTA | ~13-14 lakh | Replacing many university entrance exams under NEP |
| **UPSC CSE** | UPSC | ~10-13 lakh | The civil services aspiration — highest preparation depth |
| **CAT** | IIMs | ~3-3.5 lakh | MBA gateway — IIM admissions |
| **GATE** | IIT (rotating) | ~9-10 lakh | M.Tech/PSU/research gateway |
| **SSC CGL** | SSC | ~30-35 lakh registered | Largest govt clerk-level exam |
| **IBPS PO + SBI PO** | IBPS / SBI | ~15-20 lakh combined | Banking gateway |

### Tier-2 priority — strong aspirant volume + clear seeding value

- **Engineering:** JEE Advanced, BITSAT, VITEEE, MET, COMEDK, state CETs (KCET, MHT-CET, AP/TS EAMCET, WBJEE)
- **Medical:** NEET PG, AIIMS PG, INI-CET, FMGE, NEET MDS
- **Management:** XAT, NMAT, SNAP, CMAT, MAT, IIFT, TISSNET
- **Defense/Civil:** NDA, CDS, AFCAT, INET, State PSCs (UPPSC, BPSC, MPPSC, MPSC, TNPSC, KPSC, RPSC, etc.)
- **Banking/Insurance:** IBPS Clerk, SBI Clerk, RBI Grade B, RBI Assistant, NABARD, LIC AAO
- **SSC/Railway:** SSC CHSL, SSC MTS, SSC JE, RRB NTPC, RRB Group D, RRB JE
- **Professional:** CA Foundation/Inter/Final (New Scheme — 8→6 Final papers), CS Executive/Professional, CMA Foundation/Inter/Final
- **Finance certs:** CFA L1/L2/L3 (new pathway model at L3), FRM Part 1/2, ACCA, CIMA, CPA (US)
- **Abroad studies:** GMAT (Focus Edition — no Sentence Correction/AWA, Data Insights replaces IR), GRE, IELTS, TOEFL, PTE, Duolingo English Test
- **Tech certs:** GATE branches (CSE, ECE, EE, ME, CE, plus new XE-I Energy Science 2026), AWS, Azure, GCP, CKA/CKAD, PMP, Scrum Master
- **Law:** CLAT, AILET, LSAT India (new BNS/BNSS/BSA replacing IPC/CrPC/IEA in curricula)
- **Teaching:** CTET, state TETs, NET/SET, JRF
- **Design/Architecture:** NID, NIFT, NATA, JEE Architecture (B.Arch)

### Key 2025-26 syllabus changes captured in detail file

- **CA New Scheme:** 8 → 6 Final papers
- **GMAT Focus Edition:** No Sentence Correction/AWA; Data Insights replaces IR
- **CFA L3:** New specialised pathways (Portfolio Mgmt, Private Wealth, Private Markets)
- **GATE 2026:** New XE-I Energy Science section
- **Law curricula:** BNS/BNSS/BSA replacing IPC/CrPC/IEA across syllabi
- **CUET expansion:** Replacing many university-specific entrance exams under NEP
- **CBSE:** Twice-yearly Class 10 boards
- **NEET UG 2026:** New syllabus released by NMC

These are reflected in the topic taxonomies in the detail file — important for question bank generation accuracy.

---

## 4. Academic boards & curricula (Section B + C of detail file)

### Boards covered

- CBSE (Central) — most widely seeded (largest reach)
- ICSE / ISC (Council)
- IB DP (International Baccalaureate India)
- Cambridge IGCSE / AS / A Level
- 10 major state boards: Maharashtra (MSBSHSE), Tamil Nadu, Karnataka (KSEEB/PUE), UP Board, AP, Telangana (BIE), Rajasthan (RBSE), West Bengal (WBBSE/WBCHSE), Gujarat (GSHSEB), Kerala (DHSE)

For each board: Class 9-10 subjects + Class 11-12 stream-wise subjects (Science PCM, Science PCB, Commerce, Arts/Humanities). Standard chapter-level topic breakdowns provided for major CBSE Class 12 subjects.

### UG / professional streams covered (Section C)

10 streams with core subjects:
- Computer Science / IT (B.Tech, BCA, B.Sc CS)
- Electrical Engineering
- Mechanical Engineering
- Civil Engineering
- Electronics & Communication
- Commerce (B.Com, BBA)
- Arts (BA — Economics, Psychology, History, Pol Sci, English Lit)
- Medical (MBBS — preclinical/paraclinical/clinical, NMC competency-based phases)
- Law (LLB, BA LLB — with BNS/BNSS/BSA updates)
- Pharmacy (B.Pharm)

**Note for v1:** academic_excellence taxonomy at undergrad level is broad — actual curricula vary heavily by university. The detail file gives common foundations; user-uploaded syllabus (per spec §3.6) becomes the precise input for these users.

---

## 5. Top companies for seeding (62 across 7 categories)

Full breakdown with India presence, hiring patterns, signature interview elements, and INR LPA compensation tiers in [`india-companies-careers-research.md`](./2026-05-03-india-companies-careers-research.md).

### Tier-1 priority — Big Tech with India presence (12)
Google, Microsoft, Amazon, Meta, Apple, NVIDIA, Adobe, Salesforce, Oracle, IBM, Intel, Qualcomm

### Tier-1 priority — Indian unicorns (19)
Flipkart, Zomato, Swiggy, Razorpay, CRED, PhonePe, Paytm, Meesho, Postman, Freshworks, Zerodha, Nykaa, Lenskart, Dream11, Ola, Groww, Pine Labs, Cars24, Urban Company, Delhivery

### Tier-2 priority — IT services (9, slowing but largest absolute hirers)
TCS, Infosys, Wipro, HCL, Tech Mahindra, LTIMindtree, Cognizant, Capgemini, Accenture

### Tier-1 priority — Consulting (5)
McKinsey, BCG, Bain, Deloitte, Big-4 (KPMG/EY/PwC) consulting practices

### Tier-1 priority — Finance (5)
Goldman Sachs, JPMorgan, Morgan Stanley + HDFC Bank, ICICI Bank

### Emerging priority — AI-native (4)
OpenAI (India hiring expanding), Anthropic (limited India), Sarvam AI ($1.5B val), Krutrim ($1B+ val)

### Tier-2 priority — Newer / less obvious major hirers (7)
ServiceNow India, Atlassian India, Walmart Global Tech India, Stripe India, Palo Alto Networks India, Eli Lilly Hyderabad, Sanofi India

**Key insight:** Each company entry includes its **signature interview elements** — e.g., "Amazon: Leadership Principles drive 50%+ of behavioural; Bar Raiser; STAR mandatory." These directly become the `signatureInterviewElements` field in the `CompanyProfile` model and shape per-company question generation.

---

## 6. Career transitions for seeding (25)

Full breakdown with timelines, transferable skills, entry points, and difficulty ratings in [`india-companies-careers-research.md`](./2026-05-03-india-companies-careers-research.md). The 25 patterns cover:

### High-volume India transitions
1. IT Services Engineer → Product Manager
2. Software Engineer → Engineering Manager
3. Investment Banking Analyst → Product Manager
4. Mechanical/Civil Engineer → Software Engineer
5. Marketing Analyst → Data Scientist
6. Marketing → Product Marketing Manager
7. Consulting → Tech / Product / Founder
8. Government Job (PSU) → Corporate
9. Teacher → Corporate L&D / EdTech roles
10. CA → Investment Banking / Equity Research / FP&A (grounded in Big-4 Deal Advisory bridge)

### Strong-volume India transitions
11. Doctor → MedTech / Healthcare Product / MBA (grounded in MBA-after-MBBS trend)
12. Sales → Customer Success
13. Customer Support → Product Operations
14. Business Analyst → Product Manager
15. QA Engineer → SDET / Developer
16. Data Analyst → Data Scientist → ML Engineer (the data career ladder)
17. Designer → Design Manager / Product
18. Founder (failed startup) → Senior IC at unicorn / VC
19. Family business successor → Corporate prep
20. Defense/Armed Forces → Corporate (grounded in IIMA Armed Forces Programme)

### Niche / emerging transitions
21. HR Generalist → HR Business Partner / People Analytics
22. Account Manager → Strategy / Revenue Ops
23. Journalist → Content Strategy / PR
24. Architect (building) → UX Design / Product
25. Lawyer → Legal Tech / Compliance / GRC

### Bonus (de-prioritised but noted)
- Banker → Fintech
- Hospitality → Customer Experience roles
- PSU → EV/Renewables

---

## 7. Cross-cutting insights for spec / seeding decisions

### A. India-MNCs are the AI hiring leader, not foreign MNCs

`+82% YoY AI hiring at Indian MNCs vs +43% at foreign MNCs.` This means our **company profile prioritization** should weight Indian unicorns + Indian-MNC tech arms (TCS Research, Infosys ER&D, Wipro Lab45) higher than I initially thought. Also surfaces a generational opportunity: ScaleUp users targeting Indian MNCs need different prep than those targeting foreign MNCs.

### B. The "compliance" topic family is uniquely Indian

DPDP + RBI 2FA + GST + Ind AS + SEBI BRSR — none have global substitutes. **Recommend a dedicated "Indian Compliance & Regulatory" topic cluster** under upskilling × Finance and a sub-cluster under upskilling × Legal/HR. This is differentiated content competitors won't have because global LMS platforms don't focus on it.

### C. Vernacular/Bharat is a real career axis, not a niche

Sarvam, Krutrim, CoRover, PhonePe, ShareChat all hiring Indic-NLP/vernacular-PM roles. **Recommend adding a "Bharat-market" lens** as a cross-cutting consideration in PM, Marketing, and Design topic taxonomies — not a separate objective type.

### D. Voice/AI literacy should not be a separate domain — it should be embedded everywhere

The AI literacy research (Section B of skills file) makes clear: every domain has 3-5 AI tools that practitioners are using daily in 2026. The spec's approach of injecting AI literacy as a topic per applicable (objective × target) is right — this research validates the specific tools and skills to inject.

### E. Exam syllabus changes in 2025-26 require careful question bank generation

Several major exam syllabuses changed: GMAT (Focus Edition), CA (New Scheme), CFA L3 (pathways), Law (BNS/BNSS/BSA). **The seed batch generation must use 2026-current syllabus references**, not historical. Detail file flags these changes for each affected exam.

### F. State boards matter more than I'd assumed

Maharashtra (MSBSHSE), Tamil Nadu, Karnataka, UP — each state board has 5-15+ lakh Class 10 + Class 12 students annually. **CBSE is not the only must-seed board.** Recommend prioritizing CBSE + ICSE + Maharashtra + Tamil Nadu + Karnataka + UP + AP/Telangana for v1, others for v1.1.

### G. IT services aren't dying — they're slowing and shifting

TCS+Infy+Wipro+HCL+TechM lost ~7,400 net headcount in FY26 but are still planning ~70k freshers in FY27 combined. They're **the largest absolute hirers in India.** Career transitions FROM IT services (→ product, → tech, → MBA) deserve heavy seeding. Career upskilling WITHIN IT services (cloud, AI, data) also matters.

### H. The 20+ LPA hiring band grew +23% — high-end ICs are in demand

Senior IC roles (Staff Engineer, Principal PM, Senior Data Scientist) are hiring strongly. The interview_preparation × Senior PM × FAANG combination matters as much as new-grad SWE × Top startup. **Don't only seed for fresher/early-career.**

---

## 8. Priorities for Phase 0.5 (taxonomy + question bank seeding)

Based on this research, recommended seeding sequence:

### Wave 1 — must-launch (covers ~70% of expected user base)

**Skills/objective combinations:**
- Upskilling × {PM, SWE, Data Science, Marketing, Design, Sales, Founder} — 7 highest-volume targets
- Interview_prep × {SWE, PM, Data Science, Designer, Consultant} × {FAANG, Top startups, Indian unicorns, MBB+Big-4 consulting} — 5 roles × 4 tiers = 20 combinations
- Career_switch × {top 10 transitions from §6 above}
- Exam_prep × {JEE Main, NEET UG, CUET UG, UPSC CSE Prelims, CAT, SSC CGL, IBPS PO, GATE} — 8 highest-volume exams
- Academic_excellence × CBSE × Grade 12 × {Science PCM, Science PCB, Commerce} — 3 most-served streams

**Companies for company-profile seeding:**
- 12 Big Tech + 19 Indian unicorns + 5 Consulting = 36 profiles minimum

**Estimated topics from Wave 1:** ~600-700 topics
**Estimated questions from Wave 1:** ~8,000-10,000 (covers the majority of v1 user paths)

### Wave 2 — within first month post-launch

- Add: All remaining objective × target combos in §6
- Add: Tier-2 priority exams (Tier-2 list in §3 above)
- Add: ICSE + IB + Maharashtra + Tamil Nadu + Karnataka boards × Grade 11-12
- Add: 5 finance company profiles + 4 AI-native profiles
- **Estimated to reach the full ~1,400 taxonomy + ~16,800 question target.**

### Wave 3 — daily refresh + on-demand for everything else

- All "emerging" tier skills
- State board long-tail
- Less common career transitions
- LLM-generated for genuinely novel goals

---

## 9. Locked decisions (post-Nirpeksh review, 2026-05-03)

All six review questions answered. Decisions below are now load-bearing for Phase 0.5 seed scripts.

### Decision 1: Seeding approach — Wave 1 launch (70%) + scheduled plan to 100%
- Pre-launch Wave 1 covers ~70% of expected user paths (~700 topics, ~8-10k questions).
- Scheduled completion plan reaches 100% coverage by **launch + 8 weeks** (full schedule in §11 below).

### Decision 2: India-context split — content-type adaptive (see §10)
- Not a single percentage. Varies by content type, with Indian-unique categories at 100% and globally-shared skills using Indian examples at 50-70% weighting. Net platform-wide: ~65-70% explicit India lens, ~30-35% globally-framed content Indians need anyway.
- Full split table with rationale in §10.

### Decision 3: Wave 1 boards — CBSE + ICSE
- Both CBSE and ICSE Grade 11-12 in Wave 1.
- Maharashtra + Tamil Nadu + Karnataka in Wave 2 (week 3 post-launch).
- Other state boards in Wave 3+ as user signal warrants.

### Decision 4: Academic_excellence at undergrad — limited streams + syllabus upload primary
- Wave 1 seeds undergrad taxonomy for **only**: Computer Science / IT, Electrical Engineering, Mechanical Engineering, Commerce (B.Com, BBA).
- All other undergrad/professional streams rely on the syllabus upload path (spec §3.6) for accurate diagnostics.
- This is realistic given the variability of Indian university curricula.

### Decision 5: AI-native company profiles in v1 — included
- OpenAI, Anthropic, Sarvam AI, Krutrim AI all get dedicated v1 company profiles despite small India headcount, given disproportionate aspirational brand draw.
- Sarvam + Krutrim profiles especially important — they signal that ScaleUp recognises the Indian AI ecosystem.

### Decision 6: Research depth — sufficient for v1
- No additional research commissioned. The three deliverables + this synthesis are accepted as the basis for seeding.
- Per-state board topic depth, per-exam past-paper pattern analysis, and per-company Glassdoor-grade interview intelligence remain v1.1 candidates if needed.

---

## 10. India-context split — full table

| Content type | India weight | Global weight | Rationale |
|---|---|---|---|
| Indian compliance / regulatory (DPDP, RBI, SEBI, GST, Ind AS) | **100%** | 0% | No global substitute. Topics exist only in Indian context. |
| Indian exams (JEE, NEET, UPSC, CAT, GATE, all Indian exams) | **100%** | 0% | India-only audience by definition. |
| Indian academic boards (CBSE, ICSE, state boards) | **100%** | 0% | India-only audience. |
| Globally-shared technical skills (Cloud, AI/ML, Data Eng, Cybersecurity, Full-stack) | **60%** | 40% | Skills are universal; examples should resonate. Use Razorpay/Flipkart/Zomato/Sarvam over Stripe/Amazon/OpenAI. Salaries in INR. RBI/DPDP context baked into fintech/security examples. |
| Globally-shared business/soft skills (Stakeholder Comm, Critical Thinking, PM frameworks, Sales) | **50%** | 50% | Concepts universal. Indian workplace dynamics (hierarchy, GCC vs product-co cultures, hybrid work norms) matter — but global frameworks (MEDDIC, RICE, OKRs) needed too. |
| Career switches | **80%** | 20% | Most major Indian transitions (IT services → product, PSU → corporate, defense → corporate) are uniquely Indian. Some (founder → VC, IB → tech) are global. |
| Company-specific interview prep | **Adaptive** | — | Indian unicorns: 100% India. Indian arms of MNCs (Google India, Microsoft Hyderabad): 60/40. Foreign-only-target (Google US, Stripe HQ): 30/70. Match framing to user's actual destination. |
| Founder / Entrepreneurship | **70%** | 30% | Indian startup ecosystem (DPIIT, ESOP norms, Indian VCs, Bharat-market, Tier-2/3 GTM) is distinctly characterised. Global founder content (YC, Stripe Press) for ambition setting. |
| AI literacy per domain | **70%** | 30% | Surface Indian tools (Sarvam, Krutrim, Yellow.ai, CoRover, Leena AI, Taxmann AI, Tally + AI). Inherently-global tools (Claude, Cursor, Copilot, Figma AI) framed in Indian work contexts. |

**Net platform-wide blend:** ~65-70% explicit India lens, ~30-35% globally-framed content Indians need anyway.

**Why not 100% Indian:** A user targeting Google India needs Google's global bar PLUS India-specific compensation/culture context. A user upskilling in Cloud needs AWS/Azure/GCP global certifications but Indian RBI/DPDP fluency for fintech roles. Walling users off from international content would be parochial and would underserve the GCC-bound majority of our likely user base.

**Why not 50/50 or less Indian:** Generic global content already exists everywhere (Coursera, Udemy, LinkedIn Learning, YouTube). ScaleUp's wedge is **content that takes the Indian working professional/student seriously** — Indian examples, Indian salaries, Indian compliance, Indian career patterns. If we lose that, we lose the wedge.

---

## 11. Scheduled plan to reach 100% coverage

### Wave 1 — Pre-launch (Phase 0.5, ~3-5 days)
- Topics: **~700 entries** (Tier-1 priority only)
- Questions: **~8,000-10,000** (gpt-4o-mini, json_schema strict, anchor-question few-shot)
- Companies: **40 profiles** (12 Big Tech + 19 Indian unicorns + 5 Consulting + 4 AI-native — OpenAI, Anthropic, Sarvam, Krutrim)
- Boards: **CBSE + ICSE Grade 11-12**
- Skills covered: All "Critical" tier from §2 + top 8 "High" tier
- Estimated LLM cost: **~$50-60**

### Wave 2 — Launch +1 to +4 weeks (scheduled batch crons)
- **Week 1 post-launch:** Daily refresh active. On-demand LLM generation for any user-encountered miss. Tier 1 validator running on all new questions. Mixpanel `topic_taxonomy_lookup_miss` and `question_bank_lookup_miss` events tracked.
- **Week 2 post-launch:** Wave 2 batch script #1 — adds remaining objective × target combinations from §6 (Tier-2 priority exams, less common career switches). **+~400 topics, +~5,000 questions.**
- **Week 3 post-launch:** Wave 2 batch script #2 — adds Maharashtra (MSBSHSE) + Tamil Nadu + Karnataka boards Grade 11-12. **+~150 topics, +~1,500 questions.**
- **Week 4 post-launch:** Wave 2 batch script #3 — adds remaining 5 finance company profiles + tier-2 exam categories (CFA, FRM, CMA, all banking exams beyond IBPS PO + SBI PO). **+~100 topics, +~1,200 questions.**

### Wave 3 — Launch +5 to +8 weeks (quality + gap-fill)
- **Week 5 post-launch:** Tier 1 validator backfill on any low-confidence Wave 1 questions; Tier 2 admin review queue worked through.
- **Week 6 post-launch:** Gap analysis — query `topic_taxonomy_lookup_miss` and `question_bank_lookup_miss` Mixpanel events from first month; targeted fill of real-user-hit gaps.
- **Week 7 post-launch:** State board long-tail (UP Board, Rajasthan, Gujarat, Kerala, AP, Telangana, WB) — added as user signal warrants.
- **Week 8 post-launch:** **100% coverage milestone reached.** Total: ~1,400 topics + ~16,800 questions + ~50 company profiles.

### Wave 4 — Ongoing (post-month-2)
- Daily refresh closes any remaining long-tail gaps based on real-user signal.
- Quarterly manual review of top 30 curated company profiles.
- Anchor-question bank grows organically as new topics emerge.
- New AI tools / new exams / new companies added as the market shifts.

### Total cost across all waves
**~$150 LLM compute.** Trivial relative to product impact.

### Tracking the plan
A `seedingProgress.md` file in `docs/superpowers/research/` will be maintained week-by-week post-launch with:
- Topics covered count vs target (1,400)
- Questions in bank vs target (16,800)
- Validator queue depth
- Top 5 user-encountered misses from previous week
- Coverage by objective type

---

## 10. Sources used (consolidated count)

- ~50 sources in skills research (LinkedIn India, NASSCOM, Naukri JobSpeak, WEF, India Skills Report 2026, Taggd, HuntingCube, PwC India, RBI/MediaNama, GCC reports)
- ~50 sources in exams research (UPSC, NTA, NMC, ICAI, CISCE, CBSE, IBO, Consortium of NLUs, IIT-Guwahati, mba.com, IBPS, Careers360, Shiksha, Adda247, Vajiram, Vedantu, Allen, PW)
- ~50 sources in companies/careers research (Naukri, Inc42, YourStory, r/developersIndia wiki, IIMA, Big-4 publications, IT-services press, MBB placement reports, AmbitionBox, LinkedIn India, Tracxn)

Total: **~150 unique sources cited.** Full URL lists at the end of each detail file.

---

## What happens next

Phase 0 complete. All decisions locked. Ready to proceed.

1. **Phase 0.5 — Seed scripts** (next): write `seedTopicTaxonomy.js`, `seedCompanyProfiles.js`, `seedAnchorQuestions.js`, `seedQuestionBank.js`. Use the locked decisions in §9-11 + the detail-file content as the seed source.
2. **Run Wave 1 seed batch.** ~$50-60 LLM cost, ~6-8 hrs compute over 1-2 days.
3. **Begin implementation Phase 1 per the spec** (backend models + normalization + API scaffolding).
4. **Wave 2 + 3 batch scripts** scheduled to run as crons per the timeline in §11.
