# ScaleUp C2O Platform — Frontend Development Bible

> **Version:** 2.0 | **Platform:** iOS (primary), Android (future) | **Backend Base URL:** `http://localhost:5001/api/v1`
> **Last Updated:** February 2026

This document is the **single source of truth** for the frontend team. It covers every screen, every API endpoint, every data model, every user flow, and every design specification needed to build the ScaleUp mobile application.

---

## Table of Contents

1. [Product Vision & Design Philosophy](#1-product-vision--design-philosophy)
2. [Design System & Brand Guidelines](#2-design-system--brand-guidelines)
3. [App Architecture & Navigation](#3-app-architecture--navigation)
4. [Authentication & Onboarding](#4-authentication--onboarding)
5. [Home & Dashboard](#5-home--dashboard)
6. [Content Discovery & Feed](#6-content-discovery--feed)
7. [Content Player & Consumption](#7-content-player--consumption)
8. [AI Tutor (In-Content Assistant)](#8-ai-tutor-in-content-assistant)
9. [Quizzes & Assessment](#9-quizzes--assessment)
10. [Knowledge Profile & Mastery](#10-knowledge-profile--mastery)
11. [Learning Journey & Roadmap](#11-learning-journey--roadmap)
12. [Objectives Management](#12-objectives-management)
13. [Creator Experience](#13-creator-experience)
14. [Social & Community](#14-social--community)
15. [Notifications](#15-notifications)
16. [Search & Explore](#16-search--explore)
17. [User Profile & Settings](#17-user-profile--settings)
18. [Admin Panel](#18-admin-panel)
19. [API Reference (Complete)](#19-api-reference-complete)
20. [Data Models Reference](#20-data-models-reference)
21. [Error Handling & Edge Cases](#21-error-handling--edge-cases)
22. [Push Notifications & Deep Links](#22-push-notifications--deep-links)
23. [Offline & Caching Strategy](#23-offline--caching-strategy)
24. [Analytics Events](#24-analytics-events)
25. [Streaks & Gamification](#25-streaks--gamification)
26. [The C2O Loop — User Retention Engine](#26-the-c2o-loop--user-retention-engine)

---

## 1. Product Vision & Design Philosophy

### What is ScaleUp?

ScaleUp is a **Content-to-Outcome (C2O)** learning platform for **three audiences**:
1. **Working professionals** upskilling or switching careers
2. **Students** preparing for competitive exams (SAT, MBA, etc.) or academic excellence
3. **Creators** (Rising/Core/Anchor) who produce educational content

Users don't just consume content — they set objectives, follow AI-generated adaptive learning journeys, take AI-generated quizzes, and build a measurable knowledge profile. The platform closes the loop between "watching a video" and "actually achieving an outcome."

### The C2O Flywheel

```
Register → Set Objective → Discover Content → Consume →
Quiz Auto-Triggered (after 3+ items on a topic) →
AI Generates Quiz → Score & Analyze → Knowledge Profile Updates →
Journey Adapts → Better Recommendations → Streak Maintained →
Milestones Checked → Plan Recalibrated → Loop
```

**Every single action on the platform must either:**
1. Move the user **forward** toward their objective, OR
2. Show them the **previous step** that led them here

The user should never be confused about what to do next.

### Design DNA: Netflix + Duolingo + Gold Gradient Premium

| Inspiration | What We Take | Where It Applies |
|-------------|-------------|-----------------|
| **Netflix** | Cinematic thumbnails, "Because you watched X" rows, horizontal scroll carousels, immersive UI | Content discovery, feed, recommendations |
| **Duolingo** | Streaks, daily goals, progress tracking, gamification, habit-forming cadence, achievement celebrations | Journey, quizzes, streaks, milestones, daily plan |
| **Apple** | Minimal typography, generous whitespace, buttery 60fps animations, haptic feedback, system-native feel | Overall UI framework, interactions, gestures |
| **Masterclass** | Premium feel, full-bleed hero videos, creator spotlight, aspirational imagery | Creator profiles, content player, onboarding |

### Core Design Principles

1. **Dark-first with gold accents** — Premium feel. Content is the hero. UI chrome recedes. Gold gradient conveys achievement.
2. **Self-explanatory UX** — Every screen must make the next action obvious. Zero confusion. No support needed.
3. **Progress is visible everywhere** — Streaks, scores, milestones, journey progress — always present but never cluttered.
4. **Intelligence feels magical** — AI recommendations, quiz triggers, and journey adaptations should feel seamlessly personalized, not algorithmic.
5. **Forward momentum** — Every tap either advances the user's objective or shows them their path. Dead-end screens don't exist.
6. **Daily habit engine** — Like Duolingo, the platform should create a daily pull. Streaks, daily plans, pending quizzes, and reminders work together.

---

## 2. Design System & Brand Guidelines

### Color Palette

```
// Primary — Gold Gradient (Premium Achievement)
Gold:             #D4A843
Gold Light:       #F0D68A
Gold Dark:        #B8860B
Gold Gradient:    linear-gradient(135deg, #D4A843, #F0D68A, #D4A843)

// Background (Dark Mode — Default)
Background:       #0A0A0F
Surface:          #141418
Surface Elevated: #1C1C24
Card:             #22222E

// Background (Light Mode — Optional)
Background:       #FAFAFA
Surface:          #FFFFFF
Surface Elevated: #FFFFFF (with shadow)
Card:             #F5F5F5

// Text
Text Primary:     #FFFFFF (dark) / #1A1A1A (light)
Text Secondary:   #A0A0B0 (dark) / #6B7280 (light)
Text Tertiary:    #5A5A6E (dark) / #9CA3AF (light)
Text Gold:        #D4A843 (used for highlights, scores, achievements)

// Accents
Success:          #2ECC71 (greens for correct, streaks, positive trends)
Warning:          #F39C12
Error:            #E74C3C
Info:             #3498DB

// Creator Tier Colors (IMPORTANT — used for badge rings and tier indicators)
Anchor:           #D4A843 (Gold — premium, top-tier)
Core:             #C0C0C0 (Silver — established)
Rising:           #CD7F32 (Bronze — emerging)

// Progress & Journey
Progress Gradient:  linear-gradient(90deg, #D4A843, #2ECC71)
Streak Active:      #F39C12 (flame orange)
Streak Inactive:    #5A5A6E (dim)

// Gradients
Hero Gradient:      linear-gradient(135deg, #D4A843, #0A0A0F)
Card Overlay:       linear-gradient(180deg, transparent 40%, rgba(0,0,0,0.85) 100%)
Achievement Glow:   radial-gradient(circle, rgba(212,168,67,0.3), transparent 70%)
```

### Typography

```
// iOS: SF Pro Display + SF Pro Text
// Android (future): Google Sans / Inter

Display Large:    SF Pro Display Bold 34pt     — Hero titles, score numbers
Display Medium:   SF Pro Display Semibold 28pt — Section headers
Title Large:      SF Pro Display Semibold 22pt — Screen titles
Title Medium:     SF Pro Text Semibold 18pt    — Card titles
Body:             SF Pro Text Regular 16pt     — Primary text
Body Small:       SF Pro Text Regular 14pt     — Secondary text
Caption:          SF Pro Text Regular 12pt     — Metadata, timestamps
Micro:            SF Pro Text Medium 10pt      — Tags, badges
Mono:             SF Mono Regular 14pt         — Scores, timers, percentages
```

### Spacing Scale

```
xs:   4pt
sm:   8pt
md:   16pt
lg:   24pt
xl:   32pt
2xl:  48pt
3xl:  64pt
```

### Corner Radius

```
Small (tags, chips):    8pt
Medium (cards):         16pt
Large (modals, sheets): 24pt
Full (avatars, pills):  9999pt
```

### Motion & Animation

```
// Durations
Quick:    150ms  (micro-interactions, toggles)
Standard: 300ms  (page transitions, modals)
Smooth:   500ms  (hero animations, onboarding)
Celebration: 1200ms (confetti, milestone achievement)

// Curves
Spring:   spring(1, 80, 12)  — bouncy, playful (quiz results, confetti, streaks)
Ease Out: cubic-bezier(0.16, 1, 0.3, 1)  — enter animations
Ease In:  cubic-bezier(0.7, 0, 0.84, 0)  — exit animations
```

### Haptics

```
Selection:  UIImpactFeedbackGenerator(.light)   — tab switches, toggles
Success:    UINotificationFeedbackGenerator(.success) — quiz correct, milestone reached, streak extended
Warning:    UINotificationFeedbackGenerator(.warning) — quiz wrong answer
Error:      UINotificationFeedbackGenerator(.error)   — API errors
Heavy:      UIImpactFeedbackGenerator(.heavy)   — long press, drag
```

### Component Library Overview

| Component | Description | Reference |
|-----------|-------------|-----------|
| ContentCard | 16:9 thumbnail, gradient overlay, title, creator, duration badge, tier badge on creator | Netflix tile |
| ContentCardWide | Full-width card with metadata row below thumbnail | Masterclass hero |
| CreatorAvatar | Circular avatar with tier color ring (gold/silver/bronze) | Custom |
| TierBadge | Small pill badge: "Anchor" (gold), "Core" (silver), "Rising" (bronze) | Custom |
| ProgressRing | Circular progress indicator with percentage center, gold gradient fill | Apple Activity |
| ScoreGauge | Animated circular gauge 0-100 with gold gradient | Custom |
| QuizOption | A/B/C/D pill buttons with select/correct/wrong states | Custom |
| MilestoneChip | Pill with icon + label + checkmark for completed | Duolingo |
| StreakBadge | Fire icon + streak count, pulsing glow animation when active | Duolingo-inspired |
| KnowledgeBar | Horizontal topic bar with gradient fill based on mastery score | Custom |
| JourneyTimeline | Vertical timeline with phase nodes and progress line | Custom |
| DailyPlanCard | Card showing today's assigned content with checkboxes | Duolingo daily goal |
| NextActionBanner | Prominent CTA showing the next thing user should do | Custom |
| BottomSheet | Pull-up sheet with detents (half, full) for context menus | Apple Maps |
| SkeletonLoader | Shimmer animation placeholder matching card shapes | Standard |
| EmptyState | Illustration + message + CTA for empty data states | Custom |
| AchievementToast | Gold gradient toast shown on milestone/streak achievements | Duolingo |

---

## 3. App Architecture & Navigation

### Navigation Structure

```
TabBar (5 tabs)
├── Home (Dashboard)
│   ├── Greeting + Streak Badge
│   ├── "What's Next" Banner (single most important next action)
│   ├── Today's Plan Card (from journey)
│   ├── Continue Watching Row
│   ├── Readiness Score Widget
│   ├── Pending Quizzes Card
│   ├── Knowledge Snapshot (topic bars)
│   ├── Recommended For You Row
│   └── Weekly Stats Card
│
├── Discover (Feed + Explore)
│   ├── Search Bar (sticky)
│   ├── Hero Banner (top recommendation)
│   ├── "Picked For You" Row
│   ├── "Fill Your Knowledge Gaps" Row
│   ├── Domain-Specific Rows
│   ├── "Trending This Week" Row
│   ├── Creator Spotlight Row
│   ├── "Because You Watched X" Row
│   └── Explore Grid (toggle: For You | Explore)
│
├── Journey (Learning Journey + Objectives)
│   ├── Active Journey Map (timeline view)
│   ├── Phase Progress (horizontal nodes)
│   ├── Weekly Plan (7-day grid)
│   ├── Today's Assignments
│   ├── Milestones List
│   ├── Adaptation History
│   ├── Journey Controls (pause/resume)
│   └── Generate New Journey
│
├── Progress (Knowledge Profile + Stats)
│   ├── Overall Score Gauge
│   ├── Topic Mastery Grid
│   ├── Strengths & Weaknesses
│   ├── Quiz History
│   ├── Learning Stats
│   ├── Consumption Graph
│   └── Streak & Consistency Stats
│
└── Profile
    ├── My Profile (avatar, bio, stats)
    ├── My Objectives
    ├── My Playlists
    ├── My Learning Paths
    ├── Saved Content
    ├── Liked Content
    ├── Notifications
    ├── Settings
    ├── Creator Dashboard (if role = creator)
    │   ├── Creator Stats
    │   ├── My Content Management
    │   ├── Upload Content
    │   ├── Pending Applications to Review
    │   └── Creator Profile Edit
    └── Admin Panel (if role = admin)
        ├── Platform Stats
        ├── User Management
        ├── Content Moderation
        ├── Creator Application Review
        └── YouTube Import
```

### Tab Bar Design

- **Black background** with subtle top border (rgba(255,255,255,0.05))
- **Active tab:** Gold icon + gold label text
- **Inactive tabs:** Grey (#5A5A6E) icons, no labels
- **Slight bounce animation** on tap
- Icons: SF Symbols — `house.fill`, `safari.fill`, `map.fill`, `chart.bar.fill`, `person.fill`

### Screen Transitions

| Transition | Type | Duration |
|-----------|------|----------|
| Tab switch | Cross-dissolve | 150ms |
| Push screen | Slide from right | 300ms |
| Modal/Sheet | Slide from bottom | 300ms |
| Content player | Full-screen expand with matched geometry | 500ms |
| Quiz start | Scale + fade | 400ms |
| Achievement/Milestone | Gold glow pulse + confetti | 1200ms |

---

## 4. Authentication & Onboarding

### Auth Flow

```
Launch → Splash (2s, animated gold logo on black) → Auth Check
├── Has valid token → Check onboarding status
│   ├── onboardingComplete = true → Home
│   └── onboardingComplete = false → Resume at onboardingStep
├── Token expired → Silent refresh → Home (or login)
└── No token → Welcome Screen
```

### Welcome Screen

**Design:** Full-bleed dark background with subtle gold gradient animation. ScaleUp logo (gold text on black). Tagline: "Learn with purpose. Achieve your goals." Two CTAs at bottom.

**Interactions:**
- "Get Started" → Registration
- "Sign In" → Login
- "Continue with Google" → Google OAuth
- "Continue with Phone" → Phone OTP

### Registration Screen

```
Fields:
- First Name (required, 1-50 chars)
- Last Name (optional, 0-50 chars)
- Email (required, valid format)
- Password (required, 8-128 chars)

API: POST /api/v1/auth/register
Request:  { email, password, firstName, lastName }
Response: { success: true, data: { user, accessToken, refreshToken } }
Status: 201
```

### Login Screen

```
Fields:
- Email (required)
- Password (required)
- "Forgot Password?" link

API: POST /api/v1/auth/login
Request:  { email, password }
Response: { success: true, data: { user, accessToken, refreshToken } }
```

### Phone OTP Flow

```
Screen 1: Enter Phone Number
API: POST /api/v1/auth/phone/send-otp
Request:  { phone: "+919876543210" }
Response: { success: true, data: { message: "OTP sent" } }
Note: 10-digit numbers auto-prefixed with +91

Screen 2: Enter OTP (6-digit code input with auto-focus)
API: POST /api/v1/auth/phone/verify-otp
Request:  { phone, otp, firstName?, lastName? }
Response: { success: true, data: { user, accessToken, refreshToken, isNewUser } }

If isNewUser = true and no firstName → show name input before proceeding
Rate limit: 60 seconds between OTP requests (show countdown timer)
OTP expires: 5 minutes
```

### Google OAuth

```
API: POST /api/v1/auth/google
Request:  { idToken: "google_id_token" }
Response: { success: true, data: { user, accessToken, refreshToken } }
```

### Forgot Password

```
Screen 1: Enter Email
API: POST /api/v1/auth/forgot-password
Request:  { email }

Screen 2: Enter OTP + New Password
API: POST /api/v1/auth/reset-password
Request:  { email, otp, newPassword }
```

### Token Management

```
Access Token:  Stored in memory/keychain. Sent as: Authorization: Bearer <token>
Refresh Token: Stored securely in keychain. Valid 30 days.

On 401 response → call POST /api/v1/auth/refresh-token { refreshToken }
  → Success: store new tokens, retry original request
  → Failure: redirect to login screen

On app launch → validate stored access token
  → Expired → try refresh
  → No token → show welcome

IMPORTANT: Queue concurrent requests during refresh (don't fire multiple refreshes)
```

### Onboarding Flow (Post-Registration)

6-step guided flow. Progress bar at top (gold gradient). Back button on steps 2+. Can revisit completed steps.

**Check onboarding status on app open:**
```
API: GET /api/v1/onboarding
Response: { onboardingStep, onboardingComplete, profile data }
If not complete → resume at current step
```

**Step 1: Profile Setup**
```
UI: Avatar upload (optional) + first/last name confirmation
API: PUT /api/v1/onboarding/profile
Body: { firstName, lastName, profilePicture }
```

**Step 2: Background**
```
UI: Education picker (degree, institution, year, currently pursuing?)
    Work experience cards (role, company, years, currently working?)
    Both are optional arrays — user can add multiple or skip
API: PUT /api/v1/onboarding/background
Body: {
  education: [{ degree, institution, yearOfCompletion, currentlyPursuing }],
  workExperience: [{ role, company, years, currentlyWorking }]
}
```

**Step 3: Set Your Objective** (most critical step)
```
UI: Objective type selector (7 options displayed as illustrated cards)
    Then specifics form based on selected type
    Then timeline picker + level selector + weekly hours slider

Objective Types (show as large tappable cards with icons):
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  📝 Exam    │ │  📈 Upskill │ │  💼 Interview │
│ Preparation │ │             │ │ Preparation  │
└─────────────┘ └─────────────┘ └─────────────┘
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  🔄 Career  │ │  🎓 Academic│ │  📚 Casual  │
│   Switch    │ │ Excellence  │ │  Learning   │
└─────────────┘ └─────────────┘ └─────────────┘
┌─────────────┐
│  🤝 Network │
└─────────────┘

Specifics (changes based on objectiveType):
- exam_preparation    → examName input (e.g., "SAT", "CAT", "GRE")
- upskilling          → targetSkill input (e.g., "Product Management")
- interview_preparation → targetRole + targetCompany inputs
- career_switch       → fromDomain + toDomain inputs
- academic_excellence → (general — skip specifics)
- casual_learning     → (general — skip specifics)
- networking          → (general — skip specifics)

Timeline picker (segmented control):
  1_month | 3_months | 6_months | 1_year | no_deadline

Level selector:
  beginner | intermediate | advanced

Weekly hours slider: 1-40 hours (with hour labels)

API: POST /api/v1/onboarding/objective
Body: {
  objectiveType, specifics: { examName?, targetRole?, ... },
  timeline, currentLevel, weeklyCommitHours
}
Status: 201
```

**Step 4: Learning Preferences**
```
UI: Learning style cards (tap to select one):
  - Videos (video icon)
  - Articles (document icon)
  - Interactive (hands-on icon)
  - Mix of everything (grid icon) ← default/recommended

API: PUT /api/v1/onboarding/preferences
Body: { preferredLearningStyle: "mix", weeklyCommitHours: 10 }
```

**Step 5: Topic Interests**
```
UI: Tag cloud / chip selector for skills and topics of interest
    Show pre-populated suggestions based on chosen objective
    User can tap to select/deselect, or type to add custom topics

API: PUT /api/v1/onboarding/interests
Body: { skills: ["react", "javascript"], topicsOfInterest: ["web development", "system design"] }
```

**Step 6: Complete**
```
UI: Gold gradient success animation
    "Your learning journey begins now!"
    "Start Learning" CTA button (large, gold)

API: POST /api/v1/onboarding/complete
Status: 201
→ Navigate to Home (Dashboard)
```

---

## 5. Home & Dashboard

### Dashboard Screen

**Design:** Dark background, card-heavy, vertical scroll. The dashboard is the user's **command center** — it should answer "What should I do right now?" within 2 seconds of looking at it.

```
API: GET /api/v1/dashboard
Response:
{
  objectives: [{ _id, objectiveType, specifics, status, isPrimary, timeline, targetDate }],
  readinessScore: 72,
  knowledgeProfile: { overallScore, strengths, weaknesses, topicMastery: [{ topic, score, level, trend }] },
  journey: { title, currentPhase, currentWeek, progress: { overallPercentage, currentStreak, longestStreak, ... } },
  weeklyStats: { contentConsumed, totalContentConsumed, dominantTopics },
  nextActions: [{ type, message, data }],
  upcomingMilestones: [{ title, type, status, scheduledDate }],
  pendingQuizzes: 3,
  weeklyGrowth: { quizScoreImprovement, contentConsumed, newTopics }
}
```

### Dashboard Layout (top to bottom)

**1. Greeting Header + Streak**
```
Left: "Good morning, Rahul" + today's date
Right: StreakBadge component (🔥 12 — pulsing gold glow if streak is active)

If no streak:
  "Start your streak today!" (subtle prompt)
```

**2. "What's Next" Banner** (MOST IMPORTANT ELEMENT)
```
Source: nextActions[0] from dashboard API
Full-width gold-bordered card showing the single most important action:

Examples:
- "You have a quiz ready on Product Management" → CTA: "Take Quiz" → /quizzes/{id}
- "Continue watching: React Hooks Deep Dive" → CTA: "Resume" → /content/{id}
- "Today's plan: 2 lessons in Entrepreneurship" → CTA: "Start" → /journey/today
- "3 topics need review" → CTA: "Review" → /recommendations/gaps

This banner ensures the user always knows the ONE thing to do next.
```

**3. Today's Plan Card** (if journey active)
```
API: GET /api/v1/journey/today
Response: {
  weekNumber, day, plan: {
    day: 3,
    topics: ["product strategy"],
    contentIds: [{ _id, title, thumbnailURL, duration, contentType }],
    estimatedTime: 45,
    completed: false
  },
  weekGoals: ["Complete React fundamentals", "Score 70%+ on quiz"]
}

UI:
┌──────────────────────────────────────────┐
│ 📅 Today's Plan — Week 3, Day 3          │
│                                          │
│ □ Product Strategy: Building Roadmaps    │
│   ⏱ 12:30 • Video                       │
│                                          │
│ □ User Research Methods for PMs          │
│   ⏱ 8:45 • Video                        │
│                                          │
│ Estimated: 45 min                        │
│ ──────────── Progress Bar ────────────── │
└──────────────────────────────────────────┘

Each content item is tappable → opens player
Checkbox marks assignment complete:
  API: PUT /api/v1/journey/assignment/complete
  Body: { weekNumber, day }
```

**4. Continue Watching Row** (horizontal carousel)
```
API: GET /api/v1/progress/history?limit=10
Shows items where percentageCompleted > 0 and isCompleted = false
Content cards with progress bar overlay at bottom of thumbnail
```

**5. Readiness Score Hero**
```
From dashboard.readinessScore
Large circular ScoreGauge (0-100) with gold gradient fill
Label: "Exam Readiness" or "Learning Score" (based on objectiveType)
Calculated server-side: (knowledge * 0.4) + (journey * 0.3) + (consistency * 0.3)
Tap → Navigate to Progress tab
```

**6. Pending Quizzes Card**
```
If dashboard.pendingQuizzes > 0:
  Gold-bordered card: "You have {n} quiz(es) ready"
  CTA: "Take Quiz" → quiz list

API: GET /api/v1/quizzes/pending
Response: Array of quizzes with status = ready/delivered
```

**7. Knowledge Snapshot** (horizontal scroll of topic bars)
```
From dashboard.knowledgeProfile.topicMastery
Shows: Topic name + score bar (gold gradient fill) + level badge + trend arrow
Tap → Progress tab (Knowledge Profile)
```

**8. Recommended For You** (horizontal carousel)
```
API: GET /api/v1/recommendations/feed?limit=10
Content cards sorted by recommendation score
```

**9. Weekly Stats Card**
```
From dashboard.weeklyStats + weeklyGrowth
UI:
┌──────────────────────────────────────────┐
│ 📊 This Week                             │
│                                          │
│ 7 lessons completed  │ 3 topics explored │
│ +15% quiz scores     │ 🔥 12-day streak  │
└──────────────────────────────────────────┘
```

---

## 6. Content Discovery & Feed

### Feed Screen (Discover Tab — Primary View)

**Design:** Netflix-style. Dark background, large thumbnails, horizontal carousels. The feed is NOT chronological — it's ranked by recommendation score.

**Layout:**

**1. Search Bar** (sticky top)
```
Tappable search input → navigates to Search screen
Placeholder: "Search content, creators, topics..."
```

**2. Hero Banner** (full-width, 16:9 aspect ratio)
```
Featured content from first recommendation result
Gold gradient overlay at bottom with title + creator name + tier badge
"Play" and "Save" buttons overlaid
Source: First item from /api/v1/recommendations/feed
```

**3. "Picked For You" Row**
```
API: GET /api/v1/recommendations/feed?limit=15
Horizontal scroll of ContentCard components
Each card: thumbnail + title + creator name + tier badge + duration + source icon
```

**4. "Fill Your Knowledge Gaps" Row**
```
API: GET /api/v1/recommendations/gaps?limit=10
Content targeting weak topics from knowledge profile
Label: "Strengthen Your Weak Spots"
Only visible if user has knowledge profile (has taken at least 1 quiz)
```

**5. Domain-Specific Rows**
```
For each domain the user has objectives in:
"Product Management", "SAT Preparation", etc.
API: GET /api/v1/content/explore?domain={domain}&limit=10
```

**6. "Trending This Week" Row**
```
API: GET /api/v1/recommendations/trending?limit=10
Gold "Trending" badge on cards
Based on engagement in last 14 days
```

**7. Creator Spotlight Row**
```
API: GET /api/v1/creator/search?limit=8
Circular CreatorAvatar components with tier color ring:
  - Gold ring = Anchor
  - Silver ring = Core
  - Bronze ring = Rising
Creator name + domain underneath
Tap → Creator's public profile with their content
```

**8. "Because You Watched X" Row**
```
API: GET /api/v1/recommendations/similar/{lastWatchedContentId}?limit=10
Personalized similarity-based recommendations
Only show if user has consumed at least 1 content item
```

**9. "For Your Objective" Row**
```
API: GET /api/v1/recommendations/objective/{primaryObjectiveId}?limit=10
Content specifically aligned with user's primary objective
```

### Explore View (Toggle within Discover tab)

```
Toggle at top: "For You" | "Explore"

Explore shows filterable content grid:
- Domain filter chips (horizontal scroll at top)
- Difficulty filter: All / Beginner / Intermediate / Advanced
- Sort by: Relevance / Newest / Most Popular
- Creator filter (optional)

API: GET /api/v1/content/explore?domain=X&difficulty=Y&search=Z&creatorId=C&page=1&limit=20
Response: { success: true, data: { items: Content[], pagination } }

Grid: 2-column layout of ContentCards
Infinite scroll with pagination
```

### Content Card Design

```
┌──────────────────────────┐
│                          │
│    Thumbnail (16:9)      │
│    with gradient overlay │
│                          │
│  ┌──────┐    ┌────────┐  │
│  │12:30 │    │ Anchor │  │  ← tier badge (gold/silver/bronze)
│  └──────┘    └────────┘  │
├──────────────────────────┤
│ Title (2 lines max)      │
│ Creator Name • Domain    │
│ ★ 4.5 • 12K views       │
└──────────────────────────┘

Content Source Indicator (subtle):
- Original content: no special indicator
- YouTube sourced: small attribution text "Sourced from YouTube" below card

States:
- Default
- With progress bar (continue watching) — gold gradient bar at bottom
- With "NEW" badge (< 7 days old) — gold pill
- With completion checkmark (100% viewed)
```

---

## 7. Content Player & Consumption

### Player Screen

**Design:** Full-screen immersive. Dark background. Content is the focus.

### Video Player

```
Content is served as MP4 from S3 (both YouTube-sourced and creator uploads).
Use native AVPlayer (iOS) for all video content.

On entering player:
API: GET /api/v1/content/{id}
Response: Full content object with aiData, sourceAttribution, creatorId populated

For streaming URL (if needed):
API: GET /api/v1/content/{id}/stream
Response: { url: "signed-s3-url" }

Resume position from ContentProgress:
API: GET /api/v1/progress/history (filter by contentId, or use local cache)
Set player to currentPosition on load
```

### Content Detail View (below/alongside player)

```
Layout (scrollable below player):
1. Title (Display Medium, white)
2. Creator row: CreatorAvatar (with tier ring) + Name + Tier Badge + Follow/Unfollow button
3. Stats row: {viewCount} views • {likeCount} likes • ★ {averageRating} ({ratingCount})
4. Action bar: Like ❤️ | Save 🔖 | Rate ⭐ | Share 📤 | AI Tutor 🤖
5. AI Summary section (collapsible, default collapsed):
   - aiData.summary (2-3 sentences)
   - Key Concepts chips (from aiData.keyConcepts — each with concept name + importance)
   - Prerequisites list (from aiData.prerequisites)
   - Quality Score (shown as subtle indicator, not prominent)
6. Description (expandable, truncated to 3 lines by default)
7. Tags (horizontal scroll of tag chips)
8. Source Attribution (if YouTube):
   "This content is sourced from YouTube"
   "Original Creator: {sourceAttribution.originalCreatorName}"
   Link to original: {sourceAttribution.originalContentUrl}
   Disclaimer text: {sourceAttribution.importDisclaimer}
9. "Similar Content" horizontal row
10. Comments section (threaded)
```

### Player Interactions

**Progress Tracking (send every 10-15 seconds while playing):**
```
API: PUT /api/v1/progress/{contentId}
Body: { currentPosition: 245, totalDuration: 720 }
Response: {
  percentageCompleted: 34,
  currentPosition: 245,
  totalDuration: 720,
  isCompleted: false,
  totalTimeSpent: 245,
  sessionCount: 1
}

Note: timeSpent is optional. If not sent, defaults to 0.
```

**Mark Complete (when video ends or user manually taps):**
```
API: POST /api/v1/progress/{contentId}/complete
Response: { isCompleted: true, completedAt: "ISO8601" }

IMPORTANT: This triggers server-side effects:
1. Quiz generation check (if 3+ items consumed on same topic)
2. Journey assignment update (if content is part of active journey)
3. Consumption graph update
4. Streak update
5. Learning path progress update

Show success animation on completion (gold checkmark + "Well done!")
```

**Like (toggle):**
```
API: POST /api/v1/content/{id}/like
Response: { liked: true/false, likeCount: 90 }
Haptic: Selection on toggle
Animate: Heart icon fill/unfill
```

**Save/Bookmark (toggle):**
```
API: POST /api/v1/content/{id}/save
Response: { saved: true/false, saveCount: 46 }
```

**Rate (1-5 stars):**
```
API: POST /api/v1/content/{id}/rate
Body: { value: 4 }
Response: { rating: 4, averageRating: 4.3, ratingCount: 68 }
UI: 5 stars, tap to rate. Gold fill.
```

**Comments:**
```
GET  /api/v1/content/{id}/comments?page=1&limit=20
Response: Array of comments with populated userId (firstName, lastName, profilePicture)

POST /api/v1/content/{id}/comments
Body: { text: "Great explanation!", parentId?: "comment_id_for_reply" }

DELETE /api/v1/social/comments/{commentId} (own comments only)

Comment UI:
- Avatar + Name + Time ago
- Comment text (max 1000 chars)
- Reply button (creates threaded comment with parentId)
- Delete own comments (swipe left to reveal delete)
```

**Similar Content:**
```
API: GET /api/v1/recommendations/similar/{contentId}?limit=10
Horizontal carousel below player
```

---

## 8. AI Tutor (In-Content Assistant)

### Overview

Every content item has an AI tutor that can answer questions about the content. The tutor uses GPT-4o with the content's transcript and AI-extracted concepts as context.

### Tutor Tiers

```
Full Tier:    Content has transcript → tutor can reference specific moments, explain concepts in detail
Limited Tier: No transcript → tutor uses AI summary and metadata only, provides general guidance

Check tier:
API: GET /api/v1/ai-tutor/{contentId}/status
Response: {
  tutorTier: "full" | "limited",
  quickPrompts: [
    "Explain the main concept",
    "What are the key takeaways?",
    "Give me a real-world example",
    "Quiz me on this content"
  ]
}
```

### Chat Interface

```
Access: Tap "AI Tutor 🤖" button in content detail action bar
Opens: Bottom sheet or full-screen chat view

Get/Create Conversation:
API: GET /api/v1/ai-tutor/{contentId}
Response: {
  conversation: { messages: [{ role, content, contextMeta }], tutorTier },
  content: { title, domain }
}

Send Message:
API: POST /api/v1/ai-tutor/{contentId}/message
Body: { message: "Can you explain the concept at 4:30?" }
Response: {
  reply: "At 4:30, the speaker discusses...",
  contextMeta: {
    timestampRange: "4:12-5:30",
    conceptsReferenced: ["product-market fit"],
    tutorTier: "full"
  }
}

UI Design:
┌──────────────────────────────────────┐
│ 🤖 AI Tutor — React Hooks           │
│                                      │
│                   ┌─────────────────┐│
│                   │ What is useEffect│
│                   │ cleanup?        ││
│                   └─────────────────┘│
│ ┌───────────────────┐                │
│ │ useEffect cleanup  │               │
│ │ runs when the     │                │
│ │ component unmounts │               │
│ │ or before the     │                │
│ │ effect re-runs... │                │
│ │ 📌 4:12-5:30      │               │
│ └───────────────────┘                │
│                                      │
│ Quick prompts:                       │
│ [Explain main concept] [Key takeaways]│
│ [Real-world example] [Quiz me]       │
│                                      │
│ ┌──────────────────────┐  ┌───┐     │
│ │ Type your question...│  │ → │     │
│ └──────────────────────┘  └───┘     │
└──────────────────────────────────────┘

Features:
- Quick prompt chips at bottom for common questions
- Timestamp references are tappable → seek player to that position
- Concept references shown as chips
- Full conversation history preserved
```

### Conversation Management

```
List Conversations:
API: GET /api/v1/ai-tutor/conversations?page=1&limit=20
Response: Paginated list with content title, last message preview, message count

Delete Conversation:
API: DELETE /api/v1/ai-tutor/{contentId}
```

---

## 9. Quizzes & Assessment

### Quiz Flow Overview

```
Content Consumed → Server detects threshold (3+ items on same topic) →
Quiz auto-generated by GPT-4o → Notification sent →
Quiz appears in user's quiz list → User starts quiz →
Answers questions one by one (with timer per question) →
Submits → Scored → Results shown → Knowledge profile updated →
Journey adapts based on performance → Recommendations adjust
```

### Quiz Types (how they are triggered)

```
1. topic_consolidation: Auto-triggered after consuming 3+ items on a topic
2. weekly_review:       Auto-generated every Sunday for recently consumed topics (cron)
3. milestone_assessment: Generated when journey milestone requires quiz
4. retention_check:     Auto-generated daily for stale topics (7+ days since last quiz, score >= 20)
5. on_demand:           User manually requests a quiz on any topic
6. playlist_mastery:    Triggered after completing a playlist
```

### Quiz List Screen

```
API: GET /api/v1/quizzes
Response: Array of quizzes with status: ready | delivered | in_progress | completed

Also:
API: GET /api/v1/quizzes/pending
Response: Only ready/delivered quizzes

Quiz Card:
┌──────────────────────────────────────┐
│ 📝 Topic Consolidation               │
│ Product Management                   │
│ 10 Questions • ~10 min               │
│ Expires in 5 days                    │
│                                      │
│ Difficulty: Intermediate             │
│                         [Start Quiz →]│
└──────────────────────────────────────┘

Card states:
- Ready: Gold border, "Start Quiz" CTA
- In Progress: Blue border, "Continue" CTA
- Completed: Green checkmark, score shown, "Review" CTA
- Expired: Dim, "Expired" label
```

### Quiz Detail (Before Starting)

```
API: GET /api/v1/quizzes/{id}
Response: Quiz object with questions (but WITHOUT correctAnswer fields)

Shows:
- Quiz title + type badge
- Topic
- Question count + estimated time (totalQuestions × timePerQuestion seconds)
- Source content list (tappable → review content before quiz)
- Difficulty distribution (easy/medium/hard count)
- "Start Quiz" CTA (large, gold)

Note: First GET for a quiz marks its status as "delivered"
```

### Start Quiz

```
API: POST /api/v1/quizzes/{id}/start
Status: 201
Response: {
  _id: "attempt_id",
  quizId: "quiz_id",
  status: "in_progress",
  startedAt: "ISO8601"
}
```

### Quiz Question Screen

**Design:** One question per screen. Clean, focused. Dark background. Gold accent.

```
Layout:
┌──────────────────────────────────────┐
│ ← Back                  3 of 10  ⏱ 45│
│ ══════════░░░░░░░░░░░░░ (progress)  │
│                                      │
│ Which of the following best          │
│ describes the concept of             │
│ Product-Market Fit?                  │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ A) When a product has...         │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ B) When the market is...         │ │ ← selected (gold border)
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ C) When users actively...        │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ D) When revenue exceeds...       │ │
│ └──────────────────────────────────┘ │
│                                      │
│ [Skip]                      [Next →] │
└──────────────────────────────────────┘

Question types shown as subtle badge:
- conceptual, application, cross_content, recall, critical_thinking

Timer: Per-question countdown (default 60s, from quiz.timePerQuestion)
  - Show countdown in top-right
  - Auto-skip when timer reaches 0

Submit Answer:
API: PUT /api/v1/quizzes/{id}/answer
Body: { questionIndex: 2, selectedAnswer: "B", timeTaken: 23 }
Response: Updated attempt (no correct answer revealed yet!)

Skip:
Same API with selectedAnswer: "skipped"

IMPORTANT: Do NOT reveal correct/wrong status during the quiz.
Only reveal all answers after completing the entire quiz.
```

### Complete Quiz

```
After last question:
API: POST /api/v1/quizzes/{id}/complete
Response: Full scored attempt with results:
{
  score: { total: 10, correct: 7, incorrect: 2, skipped: 1, percentage: 70 },
  topicBreakdown: [{ topic: "product management", correct: 5, total: 7, percentage: 71 }],
  analysis: {
    strengths: ["product strategy", "user research"],
    weaknesses: ["metrics", "prioritization"],
    missedConcepts: [
      { concept: "RICE framework", contentId: "...", timestamp: "4:30", suggestion: "Review prioritization methods" }
    ],
    confidenceScore: 80,
    comparisonToPrevious: { previousScore: 60, improvement: 10, trend: "improving" }
  },
  startedAt, completedAt, totalTime
}

Server-side effects triggered:
1. Knowledge profile updated (topic mastery scores recalculated)
2. Journey adaptation queued (may modify plan if score indicates gaps)
3. Notification sent if milestone achieved
```

### Quiz Results Screen

**Design:** Celebration animation on high scores (>80%). Gold confetti burst. Detailed breakdown.

```
Layout:
1. Score Hero:
   - Large animated ScoreGauge (percentage, gold gradient)
   - If score >= 80%: Gold confetti animation + "Excellent!" text
   - If score 50-79%: "Good effort! Keep improving" text
   - If score < 50%: "Let's strengthen these topics" text + recommended content

2. Score Breakdown:
   ✓ 7 Correct  ✗ 2 Incorrect  ○ 1 Skipped
   Total time: 8m 45s

3. Topic Breakdown (horizontal bars):
   Product Strategy  ████████░░ 80%
   User Research     █████████░ 90%
   Metrics           ████░░░░░░ 40%  ← highlighted in red

4. Strengths (green chips): "product strategy", "user research"
5. Weaknesses (red chips): "metrics", "prioritization"
6. Missed Concepts (tappable cards):
   Each shows concept name + source content link + timestamp
   Tap → opens content player at that timestamp

7. Trend comparison:
   "↑ 10% improvement from last quiz on this topic" (green arrow)
   OR "↓ 5% decline — consider reviewing" (red arrow)
   OR "First quiz on this topic!" (neutral)

8. CTAs:
   "Review Answers" → detailed answer review
   "Strengthen Weak Topics" → GET /api/v1/recommendations/post-quiz?weakTopics=metrics,prioritization
   "Back to Learning" → Home
```

### Answer Review Screen

```
API: GET /api/v1/quizzes/{id}/results
Response: Full quiz with correctAnswer + explanations visible

For each question:
┌──────────────────────────────────────┐
│ Q3: Which framework is used for...   │
│                                      │
│ A) MoSCoW ← Your answer (❌ red)     │
│ B) RICE   ← Correct (✅ green)       │
│ C) Kano                              │
│ D) Jobs-to-be-Done                   │
│                                      │
│ 💡 Explanation: The RICE framework   │
│ (Reach, Impact, Confidence, Effort)  │
│ is commonly used for...              │
│                                      │
│ 📖 Source: "PM Prioritization" @ 4:30│
│    Tap to review →                   │
└──────────────────────────────────────┘
```

### On-Demand Quiz Request

```
User can request a quiz on any topic from:
- Knowledge Profile → tap a topic → "Generate Quiz"
- Journey screen → tap a topic → "Test Yourself"
- Profile → "Request Quiz" option

API: POST /api/v1/quizzes/request
Body: {
  topic: "product management",
  contentIds: ["id1", "id2"]  // optional — if omitted, server picks from consumption graph
}
Response: { success: true, message: "Quiz generation started", data: { triggerId } }

Show: Loading state "Generating your quiz..." with gold shimmer animation
Poll: GET /api/v1/quizzes/trigger/{triggerId} every 3 seconds
  Response: { status: "pending" | "generating" | "generated" }
  When generated → GET /api/v1/quizzes to find the new quiz

Alternatively, user will receive a push notification when quiz is ready.

Cap: User can select up to 20 questions when requesting (future — not yet in backend)
```

### Quiz History

```
API: GET /api/v1/quizzes/history
Response: Array of completed QuizAttempts with quiz details populated

Shows: Date, topic, type, score percentage, trend arrow (improving/declining/stable)
Tappable → full quiz results detail
```

---

## 10. Knowledge Profile & Mastery

### Knowledge Profile Screen (Progress Tab)

**Design:** Apple Fitness rings + gold gradient theme. Data-rich but organized.

### Top Section: Overall Score

```
API: GET /api/v1/knowledge/profile
Response: {
  overallScore: 65,
  totalTopicsCovered: 12,
  totalQuizzesTaken: 18,
  strengths: ["react", "product strategy"],
  weaknesses: ["system design", "sql"],
  topicMastery: [{
    topic: "product management",
    score: 78,
    level: "advanced",
    trend: "improving",
    quizzesTaken: 5,
    lastAssessedAt: "ISO8601",
    scoreHistory: [{ score: 60, date: "..." }, { score: 78, date: "..." }]
  }],
  learningVelocity: { topicsPerWeek, averageScoreImprovement, contentToMasteryRatio },
  retention: { averageRetentionRate, optimalReviewInterval },
  behavioralProfile: { type, averageAnswerTime, peakHours, consistencyScore }
}

UI: Large animated ScoreGauge (0-100, gold gradient)
    Subtitle: "12 topics covered • 18 quizzes taken"
    Behavioral type badge: "Accuracy Focused" / "Speed Focused" / "Balanced"
```

### Topic Mastery Grid

```
Grid of KnowledgeBar components (2 columns, scrollable):

┌────────────────────────┐ ┌────────────────────────┐
│ Product Mgmt     78/100│ │ React            85/100│
│ ████████████████░░░░░░ │ │ ██████████████████░░░░ │
│ Advanced ↑ improving   │ │ Advanced ↑ improving   │
├────────────────────────┤ ├────────────────────────┤
│ SQL              35/100│ │ System Design    42/100│
│ ██████░░░░░░░░░░░░░░░░ │ │ ████████░░░░░░░░░░░░░ │
│ Beginner ↓ declining   │ │ Beginner → stable      │
└────────────────────────┘ └────────────────────────┘

Tap topic → Topic Detail Screen:
API: GET /api/v1/knowledge/topic/{topic}
Response: {
  topic, score, level, trend, quizzesTaken, lastAssessedAt,
  scoreHistory: [{ score, date, quizId }]
}

Topic Detail shows:
- Score history line chart (gold line on dark background)
- Quiz attempts list for this topic
- "Generate Quiz" CTA for on-demand quiz
- "Recommended Content" for this topic
```

### Mastery Level Indicators

```
Expert (90-100):      ⬛⬛⬛⬛⬛  Gold badge + gold bar
Advanced (70-89):     ⬛⬛⬛⬛░  Green badge
Intermediate (50-69): ⬛⬛⬛░░  Blue badge
Beginner (20-49):     ⬛⬛░░░  Grey badge
Not Started (0-19):   ⬛░░░░  Outline only

Trend Arrows:
↑ improving (green)
→ stable (grey)
↓ declining (red)
```

### Strengths & Weaknesses

```
API: GET /api/v1/knowledge/strengths
Response: [{ topic, score, level, suggestion }]

API: GET /api/v1/knowledge/gaps
Response: [{ topic, score, level, suggestion, recommendedContentCount }]

Strengths: Gold-tinted chips with score
Weaknesses: Red-tinted chips with "Strengthen →" CTA
  Tapping weakness → gap-filling recommendations:
  API: GET /api/v1/recommendations/gaps?limit=10
```

### Learning Stats Section

```
API: GET /api/v1/progress/stats
Response: {
  totalContentConsumed: 45,
  dominantTopics: ["product management", "react"],
  topicCount: 12,
  topicBreakdown: [{ topic, contentConsumed, affinityScore }]
}

UI: Visual stats cards (gold accents):
┌──────────────┐ ┌──────────────┐
│     45       │ │    15 hrs    │
│   Lessons    │ │   Learned    │
│  Completed   │ │              │
├──────────────┤ ├──────────────┤
│     12       │ │     18       │
│   Topics     │ │   Quizzes    │
│  Explored    │ │   Taken      │
└──────────────┘ └──────────────┘

Topic distribution: Horizontal bar chart or pie chart
```

---

## 11. Learning Journey & Roadmap

### Journey Screen (Journey Tab)

**Design:** Game-like progression map with gold milestone nodes. Duolingo-inspired daily structure with Netflix-level production quality.

### No Active Journey State

```
Empty state:
- Gold gradient illustration of a path/roadmap
- "Your personalized learning roadmap awaits"
- "Based on your objectives, we'll create a week-by-week plan"
- CTA: "Create My Journey" (large, gold button)

Flow:
1. User must have at least one active objective
   If no objectives → redirect to create objective first
   API: GET /api/v1/objectives
   If empty → show "Set your learning objective first" with CTA

2. Select objective (if multiple):
   Show objective cards, user taps one

3. Generate Journey:
   API: POST /api/v1/journey/generate
   Body: { objectiveId: "..." }
   Status: 201
   Response: Journey object (status: "generating" initially)

   Show: Animated loading screen
   "Crafting your personalized learning plan..."
   Gold shimmer animation, ~10-20 seconds (AI call to GPT-4o)

   Poll: GET /api/v1/journey every 3 seconds
   When status changes to "active" → show the journey
```

### Active Journey View

```
API: GET /api/v1/journey
Response: Full journey object with phases, weeklyPlans, milestones, progress

Layout (scrollable):

1. Journey Title + Objective Badge
   "Product Management Mastery"
   Badge: "exam_preparation" | "upskilling" | etc.

2. Progress Overview Card (gold gradient border):
   ┌──────────────────────────────────────────┐
   │ Overall Progress: 45%                     │
   │ ████████████████████░░░░░░░░░░░░░ 45%    │
   │                                          │
   │ 📚 12/27 Content  │ 📝 3/8 Quizzes       │
   │ 🏆 2/6 Milestones │ 🔥 12-day Streak     │
   └──────────────────────────────────────────┘

3. Phase Timeline (horizontal scroll):
   ○──●──○──○──○──○
   Foundation → Building → Strengthening → Mastery → Revision → Exam Prep

   - Completed phases: Gold filled circle + checkmark
   - Current phase: Pulsing gold circle
   - Upcoming phases: Grey outline circles
   Each phase shows: name, durationDays, focusTopics

4. This Week's Plan (expandable, auto-expanded):
   API: GET /api/v1/journey/week/{currentWeek}
   Shows the 7-day plan for current week

5. Milestones Section

6. Adaptation History (collapsible)
```

### Weekly Plan View

```
API: GET /api/v1/journey/week/{weekNumber}
Response: {
  weekNumber, startDate, endDate, phaseIndex, status,
  dailyAssignments: [{
    day: 1,
    contentIds: [populated content objects],
    topics: ["product strategy"],
    estimatedTime: 30,
    completed: false,
    completedAt: null
  }],
  scheduledQuiz: { dayOfWeek, type, topics, quizId, completed },
  goals: ["Complete React fundamentals"],
  outcomes: ["Understand component lifecycle"]
}

UI: 7-day grid (horizontal tabs or vertical list)

Day Card:
┌──────────────────────────────────────┐
│ Monday (Day 1) — 30 min estimated    │
│                                      │
│ Topics: product strategy             │
│                                      │
│ □ Building Product Roadmaps          │
│   ⏱ 12:30 • Video • ★ 4.5           │
│                                      │
│ □ User Research Methods for PMs      │
│   ⏱ 8:45 • Video • ★ 4.2            │
│                                      │
│ [Mark Day Complete]                  │
└──────────────────────────────────────┘

If today: Highlighted with gold border
If completed: Green checkmark + dim

Tapping content → opens player
Mark assignment complete:
  API: PUT /api/v1/journey/assignment/complete
  Body: { weekNumber: 3, day: 1 }

Quiz day:
┌──────────────────────────────────────┐
│ Saturday (Day 6) — Quiz Day! 📝      │
│                                      │
│ Weekly Review Quiz                   │
│ Topics: product strategy, metrics    │
│                                      │
│ [Take Quiz →]                        │
└──────────────────────────────────────┘
```

### Today's Plan (Quick Access)

```
API: GET /api/v1/journey/today
Response: {
  weekNumber, day, plan: dailyAssignment,
  weekGoals, phase: { name, type }
}

Accessible from: Dashboard "Today's Plan" card, Journey tab
Shows: Today's assigned content with progress, estimated time, completion status
```

### Milestones

```
API: GET /api/v1/journey/milestones
Response: Array of milestones from journey

Milestone types:
- topic_completion: "Complete all React content"
- score_target: "Score 80%+ on Product Management quiz"
- streak: "Maintain a 7-day learning streak"
- phase_completion: "Complete Foundation phase"
- project: "Build a sample project" (future)
- final_assessment: "Pass final assessment with 85%+"

Milestone Card:
┌─────────────────────────────────────┐
│ 🎯 Score 80% on PM Quiz             │
│ Type: score_target                   │
│ Target: 80% | Current: 72%          │
│ Status: in_progress                  │
│ ████████████████░░░░ 72%             │
│ Scheduled: March 15, 2026            │
└─────────────────────────────────────┘

Statuses: upcoming | in_progress | completed | overdue | skipped
Completed milestones: Gold checkmark + gold glow animation
Overdue milestones: Red highlight + "Overdue" badge
```

### Journey Controls

```
Pause:  PUT /api/v1/journey/pause
Resume: PUT /api/v1/journey/resume

Show confirmation dialog before pausing:
"Pausing will freeze your streak and plan. Resume anytime."

Journey Progress:
API: GET /api/v1/journey/progress
Response: { overallPercentage, contentConsumed, contentAssigned, quizzesCompleted, etc. }

Adaptation History:
API: GET /api/v1/journey/adaptations
Response: [{
  date, trigger: "quiz_completed",
  changes: "Adjusted difficulty",
  details: { ... }
}]

Shows how the AI has adapted the journey based on:
- Quiz performance (low scores → more foundation content)
- Ahead of schedule → skip ahead
- Behind schedule → slow down
- Retention failures → reinforce topics

Journey Dashboard (alternative view):
API: GET /api/v1/journey/dashboard
Response: Aggregated journey stats, content progress, knowledge state
```

### User-Editable Milestones & Preferences

```
Users can:
1. Modify their objective (which may trigger journey recalibration):
   API: PUT /api/v1/objectives/{id}
   Body: { timeline: "6_months", weeklyCommitHours: 15, topicsOfInterest: [...] }
   Server checks if journey needs adaptation

2. Pause/resume journey
3. Set a different objective as primary → affects recommendation weights
4. Change weekly commitment hours → journey pace adjusts

After user modifies objective/preferences:
- Show "Recalibrating your plan..." loading
- Journey adaptation is queued via journeyAdaptationQueue
- Journey.adaptationHistory gets a new entry
```

---

## 12. Objectives Management

### Objectives Screen (within Profile or Journey tab)

```
API: GET /api/v1/objectives
Response: Array of UserObjective objects sorted by primary first, then recency

Objective Card:
┌──────────────────────────────────────┐
│ ⭐ PRIMARY                           │
│ Exam Preparation — SAT              │
│ Target: June 2026 | Intermediate     │
│ 10 hrs/week | Mix learning style     │
│ Topics: sat math, sat reading        │
│                                      │
│ Status: active                       │
│ [Edit] [Pause] [Set Primary]         │
└──────────────────────────────────────┘

Create new:
API: POST /api/v1/objectives
Body: {
  objectiveType: "upskilling",
  specifics: { targetSkill: "Data Science" },
  timeline: "6_months",
  currentLevel: "beginner",
  weeklyCommitHours: 8,
  preferredLearningStyle: "mix",
  topicsOfInterest: ["python", "machine learning", "statistics"]
}
Status: 201

Note: First objective auto-set as primary (weight=100).
Secondary objectives get weight=30.
System auto-rebalances weights.
Primary objective gets 70% weight in recommendations, secondaries share 30%.

Update:
API: PUT /api/v1/objectives/{id}
Body: { specifics, timeline, currentLevel, weeklyCommitHours, preferredLearningStyle, topicsOfInterest }

Pause:  PUT /api/v1/objectives/{id}/pause
Resume: PUT /api/v1/objectives/{id}/resume
Set Primary: PUT /api/v1/objectives/{id}/set-primary
```

---

## 13. Creator Experience

### Creator Hierarchy

```
Three tiers with distinct visual badges:

┌─────────────────────────────────────────────────────┐
│ ANCHOR (Gold 🥇)                                    │
│ Famous in their field. 50+ content, 4.5+ rating,    │
│ 1000+ followers. Gold badge ring on avatar.          │
├─────────────────────────────────────────────────────┤
│ CORE (Silver 🥈)                                    │
│ Established creator. 20+ content, 4.0+ rating.      │
│ Silver badge ring on avatar.                         │
├─────────────────────────────────────────────────────┤
│ RISING (Bronze 🥉)                                  │
│ New/emerging creator. Just approved.                 │
│ Bronze badge ring on avatar.                         │
└─────────────────────────────────────────────────────┘

Tier promotion is automated (weekly cron job):
- Rising → Core: 20+ content AND 4.0+ avg rating
- Core → Anchor: 50+ content AND 4.5+ rating AND 1000+ followers
```

### Creator Application Flow

```
Any user can apply to become a creator:

Application Form:
┌──────────────────────────────────────┐
│ Become a Creator                     │
│                                      │
│ Domain*: [Product Management    ▼]   │
│ Specializations*: [chips selector]   │
│                                      │
│ Experience*:                         │
│ [textarea — describe your expertise] │
│                                      │
│ Motivation*:                         │
│ [textarea — why you want to create]  │
│                                      │
│ Sample Content Links:                │
│ [+ Add link]                         │
│                                      │
│ Portfolio URL: [optional input]      │
│                                      │
│ Social Links (optional):             │
│ LinkedIn: [input]                    │
│ Twitter:  [input]                    │
│ YouTube:  [input]                    │
│ Website:  [input]                    │
│                                      │
│ [Submit Application]                 │
└──────────────────────────────────────┘

API: POST /api/v1/creator/apply
Body: {
  domain: "product management",
  specializations: ["product strategy", "user research"],
  experience: "5 years as PM at Google...",
  motivation: "I want to share my knowledge...",
  sampleContentLinks: ["https://youtube.com/...", "https://medium.com/..."],
  portfolioUrl: "https://mysite.com",
  socialLinks: { linkedin: "...", twitter: "...", youtube: "...", website: "..." }
}
Status: 201
```

### Creator Approval (Peer Endorsement System)

```
NO ADMIN APPROVAL NEEDED for becoming a creator.
Approval is peer-based:

To get approved, an applicant needs EITHER:
- 1 Anchor creator endorsement (in same domain) → Auto-approved as Rising
- OR 2 Core/Rising creator endorsements (in same domain) → Auto-approved as Rising

Check application status:
API: GET /api/v1/creator/application
Response: {
  status: "pending" | "endorsed" | "approved" | "rejected",
  endorsements: [{ creatorId, creatorTier, note, endorsedAt }],
  domain, specializations, experience, motivation, ...
}

If rejected → user remains a consumer. They can re-apply.

Existing creators see pending applications:
API: GET /api/v1/creator/applications?domain=product+management&page=1&limit=20
Response: Pending/endorsed applications in their domain

Endorse screen:
┌────────────────────────────────���─────┐
│ Application from Priya Sharma        │
│                                      │
│ Domain: Product Management           │
│ Experience: "5 years as PM..."       │
│ Sample Content: [link] [link]        │
│ Motivation: "I want to share..."     │
│                                      │
│ Endorsements: 0/2 needed             │
│                                      │
│ Note: [optional textarea]            │
│ [Endorse This Creator]               │
└──────────────────────────────────────┘

API: POST /api/v1/creator/applications/{applicationId}/endorse
Body: { note: "Great sample content, would be valuable addition" }

Admin can only reject (not approve):
API: POST /api/v1/admin/applications/{id}/reject
Body: { reviewNote: "Insufficient experience in this domain" }
```

### Creator Dashboard (within Profile tab)

```
Only visible to users with role: 'creator'

API: GET /api/v1/creator/profile
Response: {
  userId, tier: "rising", domain: "product management",
  specializations: ["product strategy", "user research"],
  bio: "...",
  stats: {
    totalContent: 8, totalViews: 12500,
    totalFollowers: 150, averageRating: 4.3,
    totalQuizzesGenerated: 12
  },
  isVerified: true, verifiedAt: "..."
}

Creator Dashboard Layout:
┌──────────────────────────────────────┐
│ 🥈 Core Creator                      │
│ Product Management                   │
│                                      │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐│
│ │  8   │ │12.5K │ │ 150  │ │ 4.3  ││
│ │Content│ │Views │ │Follow│ │Rating││
│ └──────┘ └──────┘ └──────┘ └──────┘│
│                                      │
│ Tier Progress:                       │
│ Core → Anchor: 8/50 content, 150/1K │
│ ████░░░░░░░░░░░░░░░ 16%             │
│                                      │
│ [Upload Content] [Manage Content]    │
│ [Review Applications] [Edit Profile] │
└──────────────────────────────────────┘
```

### Content Upload (Creators Only)

```
Step 1: Request Upload
API: POST /api/v1/content/request-upload
Body: {
  contentType: "video",   // video, article, infographic
  fileName: "lesson1.mp4",
  fileType: "video/mp4",  // video/mp4, video/quicktime, image/jpeg, image/png, application/pdf
  fileSize: 52428800      // bytes
}
Response: { uploadUrl: "s3-presigned-url", key: "content/uuid/filename" }

Step 2: Upload file directly to S3 using presigned URL (PUT request)
Show progress bar during upload

Step 3: Complete Upload
API: POST /api/v1/content/complete-upload
Body: {
  key: "content/uuid/filename",
  title: "Understanding React Hooks",
  description: "In this video, we explore...",
  contentType: "video",
  domain: "web development",
  topics: ["react", "hooks", "javascript"],
  tags: ["frontend", "javascript"],
  difficulty: "intermediate"
}
Status: 201
Response: Content object (status: "processing", aiStatus: "pending")

Step 4: AI processes content (automatic background worker)
  → aiStatus moves: pending → processing → completed
  → status moves: processing → ready
  Creator can see processing status in "My Content"

Step 5: Publish (manual — creator controls when to go live)
API: POST /api/v1/content/{id}/publish
Response: Content (status: "published")
Note: Can only publish when aiStatus = "completed"
```

### Creator's Content Management

```
API: GET /api/v1/content/my-content?page=1&limit=20&status=published
Response: Paginated list of creator's content (all statuses)

Content Management Card:
┌──────────────────────────────────────┐
│ Understanding React Hooks            │
│ Status: published ✅ | AI: completed │
│ 📊 1.2K views • 89 likes • ★ 4.3    │
│ Published: Feb 15, 2026              │
│                                      │
│ [Edit] [Unpublish]                   │
└──────────────────────────────────────┘

Update content:
API: PUT /api/v1/content/{id}
Body: { title, description, domain, topics, difficulty, tags, thumbnailURL }

Unpublish:
API: POST /api/v1/content/{id}/unpublish

NOTE: Every creator also has full consumer access.
They see the same Home, Discover, Journey, Progress screens as consumers.
```

### Creator Profile Edit

```
API: PUT /api/v1/creator/profile
Body: { bio: "Updated bio...", specializations: ["new spec"] }
```

---

## 14. Social & Community

### Follow System

```
Follow:   POST /api/v1/social/follow/{userId}   → 201
Unfollow: DELETE /api/v1/social/follow/{userId}  → 200
Cannot follow yourself (400)
Duplicate follow (409)

Followers: GET /api/v1/social/followers/{userId}?page=1&limit=20
Following: GET /api/v1/social/following/{userId}?page=1&limit=20
Response: { items: [{ _id, firstName, lastName, username, profilePicture, role }], pagination }

Follow button states:
- Not following: Gold outlined "Follow" button
- Following: Grey filled "Following" button, tap to unfollow (with confirmation)
```

### Playlists

```
Create:  POST /api/v1/social/playlists
         Body: { title: "My React Playlist", description: "...", isPublic: true }
List:    GET /api/v1/social/playlists
Detail:  GET /api/v1/social/playlists/{id}
Update:  PUT /api/v1/social/playlists/{id}
Delete:  DELETE /api/v1/social/playlists/{id}
Add:     POST /api/v1/social/playlists/{id}/items  Body: { contentId: "..." }
Remove:  DELETE /api/v1/social/playlists/{id}/items/{contentId}

Playlist UI:
- Vertical list of content items
- Each item: thumbnail + title + duration + creator
- Total duration shown at top
- "Play All" button → sequential content player (auto-advance)
- Add to playlist: From content player → Save icon → "Add to Playlist" bottom sheet
```

### Learning Paths (Community-Created)

```
Both consumers and creators can create learning paths.
Think of these as curated "courses" — ordered collections of content with a learning objective.

Explore:  GET /api/v1/learning-paths/explore?domain=X&objectiveType=Y&page=1
Mine:     GET /api/v1/learning-paths/mine
Detail:   GET /api/v1/learning-paths/{id}
Create:   POST /api/v1/learning-paths
          Body: {
            title: "Master Product Management in 30 Days",
            description: "...",
            domain: "product management",
            topics: ["product strategy", "user research"],
            difficulty: "intermediate",
            estimatedHours: 15,
            targetObjectiveType: "upskilling",
            targetSpecifics: "Product Management",
            items: [{ contentId: "...", order: 1, note: "Start here" }]
          }
Update:   PUT /api/v1/learning-paths/{id}
Publish:  POST /api/v1/learning-paths/{id}/publish (requires at least 1 item)
Archive:  POST /api/v1/learning-paths/{id}/archive
Add Item: POST /api/v1/learning-paths/{id}/items Body: { contentId, note, isOptional }
Reorder:  PUT /api/v1/learning-paths/{id}/items/reorder Body: { orderedContentIds: [...] }
Remove:   DELETE /api/v1/learning-paths/{id}/items/{contentId}
Follow:   POST /api/v1/learning-paths/{id}/follow (increments follower count)
Unfollow: DELETE /api/v1/learning-paths/{id}/follow
Rate:     POST /api/v1/learning-paths/{id}/rate Body: { rating: 4 }

Learning Path Card:
┌──────────────────────────────────────┐
│ Master Product Management            │
│ by Rahul Sharma (Core 🥈)            │
│ 12 items • 15 hrs • Intermediate     │
│ ★ 4.5 (23 ratings) • 150 followers   │
│ [Follow Path]                        │
└──────────────────────────────────────┘
```

### Comments (Threaded)

```
List:   GET /api/v1/content/{id}/comments?page=1&limit=20
Create: POST /api/v1/content/{id}/comments Body: { text: "Great!", parentId?: "..." }
Delete: DELETE /api/v1/social/comments/{commentId} (own only, soft delete)

Threaded: parentId creates reply chain (1 level deep recommended in UI)
Max comment length: 1000 characters
```

---

## 15. Notifications

### Notification Center

```
Access: Bell icon in Profile tab or via deep link

List:
API: GET /api/v1/notifications?page=1&limit=20
Response: [{
  _id, type, title, message, isRead, deepLink, createdAt
}]

Unread Count:
API: GET /api/v1/notifications/unread-count
Response: { count: 5 }
Show badge on bell icon if count > 0

Mark Read:
API: PUT /api/v1/notifications/{id}/read

Mark All Read:
API: POST /api/v1/notifications/read-all

Dismiss:
API: DELETE /api/v1/notifications/{id}
```

### Notification Types & Design

```
quiz_available:
  Icon: 📝 | Title: "Quiz Ready!" | Gold card
  Body: "Your Product Management quiz is waiting"
  Deep Link: /quizzes/{quizId}

milestone_reached:
  Icon: 🏆 | Title: "Milestone!" | Gold celebration card
  Body: "You completed 'Foundation Phase'"
  Deep Link: /journey/milestones

streak_reminder:
  Icon: 🔥 | Title: "Don't Lose Your Streak!"
  Body: "You have a 12-day streak. Learn today to keep it!"
  Deep Link: /home (or /journey/today)

journey_update:
  Icon: 🗺️ | Title: "Journey Adapted"
  Body: "Your plan has been adjusted based on your performance"
  Deep Link: /journey

social_follow:
  Icon: 👤 | Title: "New Follower"
  Body: "{name} started following you"
  Deep Link: /users/{userId}

social_comment:
  Icon: 💬 | Title: "New Comment"
  Body: "{name} commented on your content"
  Deep Link: /content/{contentId}
```

---

## 16. Search & Explore

### Search Screen

```
UI: Full-screen search with dark background

Layout:
- Search input with clear button (gold accent on focus)
- Recent searches (local storage, last 10)
- Suggested topics chips (from user's objective topics)

Results:
API: GET /api/v1/content/explore?search={query}&page=1&limit=20
Response: { items: Content[], pagination }

Filter bottom sheet:
- Domain: chips for each domain
- Difficulty: beginner / intermediate / advanced
- Content Type: video / article / infographic
- Creator Tier: anchor / core / rising
- Sort: relevance / newest / most popular

Creator Search (tab within search):
API: GET /api/v1/creator/search?search={query}&domain={domain}&tier={tier}&page=1&limit=20
Response: Paginated creator list with tier, domain, follower count
```

---

## 17. User Profile & Settings

### My Profile

```
API: GET /api/v1/users/me
Response: Full user object

Profile Screen Layout:
1. Avatar (large, centered) + name + username
2. Role badge: "Consumer" | "Creator (Rising 🥉)" | "Admin"
3. Bio (editable)
4. Stats row: {followersCount} Followers | {followingCount} Following
5. Skills chips
6. Education entries
7. Work Experience entries
8. Actions: Edit Profile | Objectives | Settings | Logout
```

### Public Profile (Other Users)

```
API: GET /api/v1/users/{userId}
Response: Limited fields: firstName, lastName, username, profilePicture,
          bio, role, followersCount, followingCount, skills, createdAt

If role = creator → also show:
  CreatorProfile data: tier badge (with color), domain, specializations, stats
  Their published content (API: GET /api/v1/content/explore?creatorId={userId})

Follow/Unfollow button
```

### Edit Profile

```
API: PUT /api/v1/users/me
Allowed fields: firstName, lastName, username, bio, dateOfBirth, location,
                education, workExperience, skills, profilePicture, phone,
                deviceType, fcmToken
```

### Settings Screen

```
- Account: Email, Phone (verify/add), Change Password
- Notifications: Push notification toggles (FCM token management)
- Appearance: Dark/Light mode toggle
- Learning: Weekly commitment hours, preferred learning style
- Storage: Clear cache
- About: Version, Terms, Privacy
- Logout: POST /api/v1/auth/logout
- Deactivate Account: DELETE /api/v1/users/me (with confirmation dialog)
```

### Add/Verify Phone

```
API: POST /api/v1/auth/phone/verify
Body: { phone: "+919876543210", otp: "123456" }
Requires: auth token (user must be logged in)
Flow: Enter phone → POST /api/v1/auth/phone/send-otp → receive OTP → verify
```

---

## 18. Admin Panel

Only accessible to users with `role: 'admin'`. Separate section within Profile tab.

### Admin Dashboard

```
API: GET /api/v1/admin/stats
Response: { totalUsers, totalCreators, totalContent, publishedContent }

Stats cards with gold accent numbers
```

### User Management

```
List: GET /api/v1/admin/users?page=1&limit=20&role=creator&search=john
Response: Paginated users with role, status, creation date

Ban:  PUT /api/v1/admin/users/{id}/ban
Unban: PUT /api/v1/admin/users/{id}/unban
```

### Creator Application Review

```
List: GET /api/v1/admin/applications?page=1&limit=20
Reject: POST /api/v1/admin/applications/{id}/reject
        Body: { reviewNote: "Insufficient experience" }
Note: Admin cannot approve — only peer endorsement approves
```

### Content Moderation

```
API: PUT /api/v1/admin/content/{id}/moderate
Body: {
  moderationStatus: "approved" | "rejected" | "pending",
  moderationNote: "Content meets quality standards"
}
Approved → status becomes published
Rejected → status becomes rejected
```

### YouTube Import (Admin Only)

```
Import Video:    POST /api/v1/youtube/import/video
                 Body: { videoId: "dQw4w9WgXcQ", domain: "product management", topics: ["strategy"] }
Import Channel:  POST /api/v1/youtube/import/channel
                 Body: { channelId: "UCxxx", domain: "...", topics: [...], maxVideos: 20 }
Import Playlist: POST /api/v1/youtube/import/playlist
                 Body: { playlistId: "PLxxx", domain: "...", topics: [...] }
Search YouTube:  GET /api/v1/youtube/search?q={query}&maxResults=20
Import History:  GET /api/v1/youtube/imports?page=1&limit=50

Note: YouTube videos are downloaded and re-hosted on S3 as MP4.
The mobile app plays them natively via AVPlayer — NO YouTube embeds.
```

---

## 19. API Reference (Complete)

### Base Configuration

```
Base URL: http://localhost:5001/api/v1
Content-Type: application/json
Authorization: Bearer <accessToken>

Health Check: GET /health → { status: "ok", timestamp }
```

### Standard Response Format

```json
// Success
{
  "success": true,
  "message": "Login successful",
  "data": { ... }
}

// Success with Pagination
{
  "success": true,
  "data": [array of items],
  "pagination": {
    "total": 150,
    "page": 1,
    "limit": 20,
    "totalPages": 8,
    "hasNextPage": true,
    "hasPrevPage": false
  }
}

// Error
{
  "success": false,
  "message": "Invalid email or password"
}
```

### Complete Endpoint List

#### Authentication (No Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register` | Register with email/password |
| POST | `/auth/login` | Login with email/password |
| POST | `/auth/google` | Login with Google |
| POST | `/auth/refresh-token` | Refresh access token |
| POST | `/auth/forgot-password` | Request password reset OTP |
| POST | `/auth/reset-password` | Reset password with OTP |
| POST | `/auth/phone/send-otp` | Send SMS OTP |
| POST | `/auth/phone/verify-otp` | Verify OTP and login/register |

#### Authentication (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/phone/verify` | Add/verify phone to existing account |
| POST | `/auth/logout` | Logout (revokes refresh tokens) |

#### Onboarding (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/onboarding` | Get onboarding status + current step |
| PUT | `/onboarding/profile` | Update profile (step 1) |
| PUT | `/onboarding/background` | Update education/work (step 2) |
| POST | `/onboarding/objective` | Set primary objective (step 3) |
| PUT | `/onboarding/preferences` | Set learning preferences (step 4) |
| PUT | `/onboarding/interests` | Set skills/topics (step 5) |
| POST | `/onboarding/complete` | Complete onboarding (step 6) |

#### Dashboard (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/dashboard` | Get full dashboard data |

#### Content (Auth Required)
| Method | Path | Auth Level | Description |
|--------|------|-----------|-------------|
| GET | `/content/feed` | User | Personalized feed (same as recommendations/feed) |
| GET | `/content/explore` | User | Explore with filters (domain, difficulty, search, creatorId) |
| GET | `/content/liked` | User | User's liked content |
| GET | `/content/saved` | User | User's saved content |
| GET | `/content/{id}` | User | Content detail with populated creator |
| GET | `/content/{id}/stream` | User | Get signed S3 streaming URL |
| POST | `/content/{id}/like` | User | Toggle like |
| POST | `/content/{id}/save` | User | Toggle save |
| POST | `/content/{id}/rate` | User | Rate 1-5 |
| GET | `/content/{id}/comments` | User | Get threaded comments |
| POST | `/content/{id}/comments` | User | Add comment/reply |
| POST | `/content/request-upload` | Creator | Request S3 presigned upload URL |
| POST | `/content/complete-upload` | Creator | Finalize upload with metadata |
| GET | `/content/my-content` | Creator | My created content (all statuses) |
| PUT | `/content/{id}` | Creator | Update content metadata |
| POST | `/content/{id}/publish` | Creator | Publish content |
| POST | `/content/{id}/unpublish` | Creator | Unpublish content |

#### Recommendations (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/recommendations/feed` | Personalized recommendations (7-factor scoring) |
| GET | `/recommendations/similar/{id}` | "Because you watched X" |
| GET | `/recommendations/objective/{objectiveId}` | Content for specific objective |
| GET | `/recommendations/gaps` | Gap-filling content for weak topics |
| GET | `/recommendations/trending` | Trending in user's topic areas |
| GET | `/recommendations/next-actions` | 5-priority list of what to do next |
| GET | `/recommendations/post-quiz` | Remediation content after quiz (query: ?weakTopics=x,y) |

#### Progress (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| PUT | `/progress/{contentId}` | Update progress (currentPosition, totalDuration) |
| POST | `/progress/{contentId}/complete` | Mark content complete (triggers quiz/streak/journey updates) |
| GET | `/progress/history` | Learning history (paginated) |
| GET | `/progress/stats` | Consumption statistics |

#### Quizzes (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/quizzes` | List all quizzes |
| GET | `/quizzes/pending` | Only ready/delivered quizzes |
| GET | `/quizzes/history` | Completed quiz attempts |
| POST | `/quizzes/request` | Request on-demand quiz generation |
| GET | `/quizzes/trigger/{triggerId}` | Check quiz generation status |
| GET | `/quizzes/{id}` | Quiz detail (marks as delivered on first view) |
| POST | `/quizzes/{id}/start` | Start quiz attempt |
| PUT | `/quizzes/{id}/answer` | Submit answer for one question |
| POST | `/quizzes/{id}/complete` | Complete quiz and get scored results |
| GET | `/quizzes/{id}/results` | View detailed results with explanations |

#### Knowledge (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/knowledge/profile` | Full knowledge profile |
| GET | `/knowledge/topic/{topic}` | Topic detail with score history |
| GET | `/knowledge/gaps` | Knowledge gaps (weak topics) |
| GET | `/knowledge/strengths` | Strong topics |

#### Journey (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/journey` | Active journey |
| POST | `/journey/generate` | Generate AI journey (takes ~10-20s) |
| GET | `/journey/today` | Today's plan |
| GET | `/journey/week/{weekNumber}` | Week plan with daily assignments |
| PUT | `/journey/pause` | Pause journey |
| PUT | `/journey/resume` | Resume journey |
| GET | `/journey/milestones` | All milestones |
| GET | `/journey/progress` | Journey progress stats |
| GET | `/journey/adaptations` | Adaptation history |
| GET | `/journey/dashboard` | Aggregated journey dashboard |
| PUT | `/journey/assignment/complete` | Mark daily assignment complete |

#### Objectives (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/objectives` | List all objectives |
| POST | `/objectives` | Create objective |
| PUT | `/objectives/{id}` | Update objective |
| PUT | `/objectives/{id}/pause` | Pause |
| PUT | `/objectives/{id}/resume` | Resume |
| PUT | `/objectives/{id}/set-primary` | Set as primary |

#### Creator (Auth Required)
| Method | Path | Auth Level | Description |
|--------|------|-----------|-------------|
| POST | `/creator/apply` | Any User | Submit creator application |
| GET | `/creator/application` | Any User | Check my application status |
| GET | `/creator/search` | Any User | Search/browse creators |
| GET | `/creator/profile` | Creator | My creator profile |
| PUT | `/creator/profile` | Creator | Update creator profile |
| GET | `/creator/applications` | Creator | Browse pending applications (in my domain) |
| POST | `/creator/applications/{id}/endorse` | Creator | Endorse an applicant |

#### Social (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/social/follow/{userId}` | Follow user |
| DELETE | `/social/follow/{userId}` | Unfollow user |
| GET | `/social/followers/{userId}` | User's followers |
| GET | `/social/following/{userId}` | User's following |
| DELETE | `/social/comments/{commentId}` | Delete own comment |
| POST | `/social/playlists` | Create playlist |
| GET | `/social/playlists` | My playlists |
| GET | `/social/playlists/{id}` | Playlist detail |
| PUT | `/social/playlists/{id}` | Update playlist |
| POST | `/social/playlists/{id}/items` | Add to playlist |
| DELETE | `/social/playlists/{id}/items/{contentId}` | Remove from playlist |
| DELETE | `/social/playlists/{id}` | Delete playlist |

#### Learning Paths (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/learning-paths/explore` | Browse published paths |
| GET | `/learning-paths/mine` | My created paths |
| GET | `/learning-paths/{id}` | Path detail with content |
| POST | `/learning-paths` | Create path |
| PUT | `/learning-paths/{id}` | Update path |
| POST | `/learning-paths/{id}/publish` | Publish (needs items) |
| POST | `/learning-paths/{id}/archive` | Archive |
| POST | `/learning-paths/{id}/items` | Add content item |
| PUT | `/learning-paths/{id}/items/reorder` | Reorder items |
| DELETE | `/learning-paths/{id}/items/{contentId}` | Remove content item |
| POST | `/learning-paths/{id}/follow` | Follow path |
| DELETE | `/learning-paths/{id}/follow` | Unfollow path |
| POST | `/learning-paths/{id}/rate` | Rate 1-5 |

#### AI Tutor (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/ai-tutor/conversations` | List my tutor conversations |
| GET | `/ai-tutor/{contentId}/status` | Get tutor tier + quick prompts |
| GET | `/ai-tutor/{contentId}` | Get/create conversation |
| POST | `/ai-tutor/{contentId}/message` | Send message, get AI reply |
| DELETE | `/ai-tutor/{contentId}` | Delete conversation |

#### Notifications (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/notifications` | List notifications (paginated) |
| GET | `/notifications/unread-count` | Unread notification count |
| PUT | `/notifications/{id}/read` | Mark as read |
| POST | `/notifications/read-all` | Mark all as read |
| DELETE | `/notifications/{id}` | Dismiss notification |

#### Users (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/users/me` | My profile |
| PUT | `/users/me` | Update profile |
| DELETE | `/users/me` | Deactivate account |
| GET | `/users/{userId}` | Public profile |

#### Admin (Admin Only)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/stats` | Platform stats |
| GET | `/admin/users` | List users with filters |
| PUT | `/admin/users/{id}/ban` | Ban user |
| PUT | `/admin/users/{id}/unban` | Unban user |
| GET | `/admin/applications` | Pending creator applications |
| POST | `/admin/applications/{id}/reject` | Reject application |
| PUT | `/admin/content/{id}/moderate` | Moderate content |

#### YouTube (Admin Only)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/youtube/import/video` | Import single video |
| POST | `/youtube/import/channel` | Import channel's videos |
| POST | `/youtube/import/playlist` | Import playlist's videos |
| GET | `/youtube/search` | Search YouTube |
| GET | `/youtube/imports` | Import history |

---

## 20. Data Models Reference

### Key Enums

```
User Roles:        consumer | creator | admin
Auth Providers:    local | google | linkedin | phone
Creator Tiers:     rising | core | anchor
Content Types:     video | article | infographic
Content Status:    draft | processing | ready | published | unpublished | rejected
Content Source:    original | youtube
AI Status:         pending | processing | completed | failed
Difficulty:        beginner | intermediate | advanced
Mastery Levels:    not_started | beginner | intermediate | advanced | expert
Objective Types:   exam_preparation | upskilling | interview_preparation |
                   networking | career_switch | academic_excellence | casual_learning
Timelines:         1_month | 3_months | 6_months | 1_year | no_deadline
Learning Styles:   videos | articles | interactive | mix
Quiz Types:        topic_consolidation | weekly_review | milestone_assessment |
                   retention_check | on_demand | playlist_mastery
Quiz Status:       generating | ready | delivered | in_progress | completed | expired
Question Types:    conceptual | application | cross_content | recall | critical_thinking
Journey Status:    generating | active | paused | completed | abandoned
Journey Phases:    foundation | building | strengthening | mastery | revision | exam_prep
Milestone Types:   topic_completion | score_target | streak | phase_completion | project | final_assessment
Milestone Status:  upcoming | in_progress | completed | overdue | skipped
Interaction Types: like | save | rate | share
Trends:            improving | stable | declining
Application Status: pending | endorsed | approved | rejected
Notification Types: quiz_available | milestone_reached | streak_reminder | journey_update | social_follow | social_comment
Behavioral Types:  speed_focused | accuracy_focused | balanced | inconsistent
```

### Content Object (Full Shape)

```json
{
  "_id": "string",
  "creatorId": {
    "_id": "string",
    "firstName": "string",
    "lastName": "string",
    "username": "string",
    "profilePicture": "string | null"
  },
  "title": "string (max 200 chars)",
  "description": "string (max 5000 chars)",
  "contentType": "video | article | infographic",
  "contentURL": "string (S3 URL for all content)",
  "thumbnailURL": "string (S3 URL)",
  "s3Key": "string",
  "thumbnailS3Key": "string",
  "duration": 720,
  "sourceType": "original | youtube",
  "sourceAttribution": {
    "platform": "YouTube",
    "originalCreatorName": "string",
    "originalCreatorUrl": "string",
    "originalContentUrl": "string",
    "importDisclaimer": "string"
  },
  "youtubeVideoId": "string (if youtube import)",
  "domain": "string",
  "topics": ["string"],
  "tags": ["string"],
  "difficulty": "beginner | intermediate | advanced",
  "aiData": {
    "summary": "string (max 500 chars)",
    "keyConcepts": [
      { "concept": "string", "description": "string", "timestamp": "MM:SS", "importance": 1-5 }
    ],
    "prerequisites": ["string"],
    "qualityScore": 0-100,
    "autoTags": ["string"],
    "moderationFlags": [{ "type": "string", "severity": "low|medium|high", "detail": "string" }]
  },
  "status": "published",
  "publishedAt": "ISO8601",
  "viewCount": 1250,
  "likeCount": 89,
  "commentCount": 12,
  "saveCount": 45,
  "shareCount": 0,
  "averageRating": 4.3,
  "ratingCount": 67,
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601"
}
```

### User Object (from /users/me)

```json
{
  "_id": "string",
  "email": "string",
  "phone": "string | null",
  "isPhoneVerified": false,
  "isEmailVerified": true,
  "firstName": "string",
  "lastName": "string",
  "username": "string | null",
  "profilePicture": "string | null",
  "bio": "string | null (max 300 chars)",
  "dateOfBirth": "ISO8601 | null",
  "location": "string | null",
  "education": [{ "degree": "string", "institution": "string", "yearOfCompletion": 2020, "currentlyPursuing": false }],
  "workExperience": [{ "role": "string", "company": "string", "years": 3, "currentlyWorking": true }],
  "skills": ["string"],
  "role": "consumer | creator | admin",
  "authProvider": "local | google | phone",
  "onboardingComplete": true,
  "onboardingStep": 5,
  "followersCount": 150,
  "followingCount": 45,
  "isActive": true,
  "isBanned": false,
  "lastLoginAt": "ISO8601",
  "createdAt": "ISO8601"
}
```

---

## 21. Error Handling & Edge Cases

### HTTP Status Codes

| Code | Meaning | Frontend Action |
|------|---------|----------------|
| 200 | Success | Display data |
| 201 | Created | Display success + data |
| 400 | Bad Request | Show field-level validation errors |
| 401 | Unauthorized | Try token refresh → if fails, redirect to login |
| 403 | Forbidden | Show "Access denied" or role-insufficient screen |
| 404 | Not Found | Show "Not found" state |
| 409 | Conflict | Show "Already exists" message (duplicate follow, etc.) |
| 429 | Rate Limit | Show countdown timer (OTP: 60s) |
| 500 | Server Error | Show generic error + retry button |

### Token Expiry Flow

```
1. API call returns 401
2. Intercept in HTTP client middleware
3. Call POST /auth/refresh-token with stored refreshToken
4. If 200 → store new tokens, retry original request
5. If 401 → token fully expired, navigate to login screen
6. Queue concurrent 401 requests during refresh (don't fire multiple refresh calls)
```

### Offline States

```
- No internet → Show offline banner + cached content
- API timeout → Show retry button
- Partial load → Show skeleton + retry failed sections
```

### Empty States (design each with illustration + message + CTA)

```
- No content in feed → "Set your objectives to get personalized recommendations" CTA: "Set Objective"
- No quizzes available → "Keep learning! Quizzes appear after consuming 3+ items on a topic" CTA: "Discover Content"
- No journey → "Create your learning journey to get a personalized plan" CTA: "Create Journey"
- No knowledge profile → "Complete quizzes to build your knowledge profile" CTA: "Take a Quiz"
- No followers → "Follow creators and learners to build your community" CTA: "Discover Creators"
- No playlists ��� "Create playlists to organize your learning" CTA: "Create Playlist"
- No search results → "No results found. Try different keywords"
- No objectives → "Set your first learning objective to get started" CTA: "Set Objective"
- No streak → "Start your streak today by completing a lesson!" CTA: "Start Learning"
- No consumption history → "Start watching to build your learning history" CTA: "Discover"
- Creator: no content → "Upload your first content piece" CTA: "Upload Content"
- Creator: no pending applications → "No applications to review right now"
```

---

## 22. Push Notifications & Deep Links

### FCM Token Setup

```
On app launch or login:
API: PUT /api/v1/users/me
Body: { fcmToken: "firebase_token", deviceType: "ios" }
```

### Notification Types & Deep Links

| Type | Trigger | Title | Body | Deep Link |
|------|---------|-------|------|-----------|
| quiz_available | Quiz auto-generated or on-demand ready | "Quiz Ready!" | "Your {topic} quiz is waiting" | /quizzes/{id} |
| milestone_reached | Journey milestone completed | "Milestone Achieved!" | "You completed '{title}'" | /journey/milestones |
| streak_reminder | No activity today (cron at 10 AM IST) | "Don't Lose Your Streak!" | "You have a {n}-day streak going" | /home |
| journey_update | Journey adapted by AI | "Journey Updated" | "Your plan has been adjusted" | /journey |
| social_follow | Someone follows user | "New Follower" | "{name} started following you" | /users/{userId} |
| social_comment | Someone comments on your content | "New Comment" | "{name} commented on your content" | /content/{contentId} |

### Re-engagement Push (Cron — daily 10 AM IST)
```
For users inactive 3+ days with valid FCM token:
Title: "We miss you!"
Body: "Your learning journey is waiting. Come back and keep growing!"
Deep Link: /home
```

### Deep Link Handling

```
On notification tap:
1. Parse deep link from notification data
2. If user is authenticated → navigate to target screen
3. If not authenticated → store deep link → show login → navigate after auth

Deep link format: /{screen}/{id}
Examples:
  /quizzes/abc123     → Quiz detail screen
  /content/abc123     → Content player
  /journey            → Journey tab
  /journey/milestones → Milestones screen
  /home               → Dashboard
  /users/abc123       → Public profile
```

---

## 23. Offline & Caching Strategy

### Cache Layers

```
1. Memory cache: Active session data (user profile, current journey)
2. Disk cache: Content metadata, thumbnails, last feed state
3. Keychain: Tokens only (never cache in UserDefaults)
```

### Cache Policy

| Data | Cache Duration | Strategy |
|------|---------------|----------|
| User profile | 5 min | Cache-then-network |
| Dashboard | 2 min | Cache-then-network |
| Feed / Recommendations | 5 min | Cache-then-network |
| Content detail | 30 min | Cache-first |
| Knowledge profile | 5 min | Cache-then-network |
| Journey | 5 min | Cache-then-network |
| Quiz list | 2 min | Network-first (time-sensitive) |
| Notifications | 1 min | Network-first |
| Static enums | Forever | Cache-first |

### Progress Tracking Offline

```
- Store progress updates locally (currentPosition, totalDuration)
- Sync when back online (batch PUT /progress for each tracked item)
- Show last-known progress from local cache
- Mark complete events are critical — queue and retry
```

---

## 24. Analytics Events

Track these events for product analytics (integrate with Mixpanel, Amplitude, or similar):

### Core Events

```
// Auth
user_registered         { method: "email|google|phone" }
user_logged_in          { method: "email|google|phone" }
onboarding_step_completed { step: 1-6, stepName: "profile|background|objective|preferences|interests|complete" }
onboarding_completed    { objectiveType, timeline }

// Content
content_viewed          { contentId, contentType, domain, sourceType, creatorTier }
content_started         { contentId, resumePosition }
content_progress        { contentId, percentageCompleted, position }
content_completed       { contentId, totalTime, domain }
content_liked           { contentId, liked: true/false }
content_saved           { contentId, saved: true/false }
content_rated           { contentId, rating: 1-5 }
content_shared          { contentId, method }
content_comment_added   { contentId, isReply: true/false }

// Quiz
quiz_started            { quizId, type, topic, totalQuestions }
quiz_answer_submitted   { quizId, questionIndex, timeTaken, questionType }
quiz_completed          { quizId, score, percentage, type, topic, totalTime }
quiz_requested          { topic }
quiz_results_reviewed   { quizId }

// Journey
journey_generated       { objectiveId, objectiveType }
journey_paused          { journeyId, weekNumber }
journey_resumed         { journeyId }
daily_plan_viewed       { weekNumber, day }
daily_plan_completed    { weekNumber, day }
milestone_completed     { milestoneType, title }
journey_adapted         { trigger, changes }

// Knowledge
knowledge_profile_viewed {}
topic_detail_viewed     { topic, score }
gap_content_tapped      { topic, contentId }

// Social
user_followed           { followingId, followingRole }
user_unfollowed         { followingId }
playlist_created        { playlistId }
playlist_item_added     { playlistId, contentId }
learning_path_followed  { pathId }
learning_path_rated     { pathId, rating }

// Creator
creator_application_submitted { domain }
content_uploaded        { contentType }
content_published       { contentId }
application_endorsed    { applicationId }

// AI Tutor
ai_tutor_opened         { contentId, tutorTier }
ai_tutor_message_sent   { contentId, messageLength }
ai_tutor_quick_prompt   { contentId, promptType }

// Navigation
tab_switched            { tab: "home|discover|journey|progress|profile" }
screen_viewed           { screenName }
search_performed        { query, filters, resultCount }
notification_tapped     { type, deepLink }

// Engagement
app_opened              { source: "direct|notification|deeplink" }
session_duration        { seconds }
streak_extended         { currentStreak }
streak_broken           {}
```

---

## 25. Streaks & Gamification

### Streak System

```
A streak counts consecutive days of learning activity.
Activity = completing any content piece.

Streak is displayed:
- Dashboard header (StreakBadge component)
- Journey progress card
- Profile

Streak states:
- Active today: Gold pulsing fire icon 🔥 + count
- Active but not today yet: Orange fire icon + count + "Don't lose it!" subtitle
- Broken: Grey fire icon + "Start a new streak!"
- New: "Start your streak today!"

Server manages streaks:
- Updated on content completion (consumptionService → streakService)
- Reset daily via cron job (1:30 AM UTC) for inactive users
- ensureStreakFresh() called on dashboard load

Celebration animations:
- 3-day streak: Small confetti
- 7-day streak: Gold confetti + "1 week!"
- 30-day streak: Full-screen celebration
- Milestone streaks: Push notification
```

### Gamification Elements (Duolingo-inspired)

```
1. Daily Goal: Complete today's plan → gold checkmark
2. Streak Counter: Consecutive days → fire badge
3. Milestone Celebrations: Achievement toasts with gold glow
4. Score Progression: Knowledge score moving up → animated gauge
5. Tier Badges: Creator tier badges as aspirational status symbols
6. Quiz Performance: Score comparisons to previous attempts → improvement arrows
7. Journey Phases: Phase completion → unlocking next phase animation
8. Topic Mastery: Level-up animations (beginner → intermediate → advanced → expert)
```

---

## 26. The C2O Loop — User Retention Engine

### How Everything Connects

```
This section explains to the frontend team how the backend orchestrates
the Content-to-Outcome loop, so you understand why every screen matters.

DAY 1 (Registration + Onboarding):
├── User registers
├── Sets objective (exam_preparation: SAT)
├── Sets topics of interest, timeline, weekly commitment
├── System creates UserObjective
└── Home shows cold-start recommendations based on onboarding data

DAY 1-3 (Discovery Phase):
├── User browses personalized feed (7-factor recommendation scoring)
├── Watches 3+ videos on "sat math"
├── Each completion triggers:
│   ├── ContentProgress update
│   ├── ConsumptionGraph update (topic nodes + edges)
│   ├── Streak update
│   └── Quiz trigger check
├── After 3rd video on "sat math" → quiz auto-generated (topic_consolidation)
└── Push notification: "Your SAT Math quiz is ready!"

DAY 3-5 (Quiz + Knowledge Building):
├── User takes quiz → 10 questions → scored
├── Results: 70% — weak on "geometry", strong on "algebra"
├── Knowledge profile updated:
│   ├── sat math: score 70, level intermediate
│   └── Weaknesses: ["geometry"]
├── Journey adaptation queued (if journey exists)
├── Recommendations adjust:
│   ├── Gap-filling: more geometry content surfaces
│   └── Difficulty calibrated to intermediate
└── User sees "Strengthen Weak Spots" row with geometry content

DAY 5-7 (Journey Generation):
├── User taps "Create My Journey"
├── GPT-4o generates personalized plan:
│   ├── Phase 1: Foundation (weeks 1-3) — focus on weak areas
│   ├── Phase 2: Building (weeks 4-6) — intermediate topics
│   ├── Phase 3: Mastery (weeks 7-8) — advanced practice
│   └── Phase 4: Exam Prep (weeks 9-10) — mock tests
├── Daily assignments: 2-3 content pieces per day
├── Weekly quizzes scheduled
├── Milestones set: "Score 80% on algebra", "Complete geometry module"
└── Dashboard now shows "Today's Plan" prominently

ONGOING LOOP:
├── Every day: User completes assigned content → streak extends
├── Every completion: Quiz trigger checks run
├── Every Sunday: Weekly review quiz auto-generated (cron)
├── Every 7 days: Retention check quiz for stale topics (cron)
├── After each quiz:
│   ├── Knowledge profile updates
│   ├── Journey may adapt (slow down, skip ahead, reinforce)
│   ├── Milestone progress checked
│   └── Recommendations recalibrate
├── If user slows down:
│   ├── Streak reminder push notification (10 AM IST daily)
│   ├── Re-engagement push after 3 days inactive
│   └── Journey pauses but preserves progress
├── If user speeds up:
│   ├── Journey adapts: skip ahead, harder content
│   ├── New milestones set
│   └── Level-up celebrations
└── Discovery tab always shows fresh content beyond their objective too

PLATFORM RULES:
1. Every screen has a "next action" — user never wonders what to do
2. Every action feeds back into the system (progress, knowledge, journey)
3. The system gets smarter with every interaction
4. Content from all tiers (Rising/Core/Anchor) is surfaced fairly (50/50 source fairness)
5. Creators are incentivized by tier progression and visibility
6. Platform is flexible — new features can plug into existing objective/knowledge/journey framework
```

---

## Appendix A: Test Accounts

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@scaleup.io | Admin@123456 |
| Consumer | rahul@test.com | Test@12345 |
| Consumer | priya@test.com | Test@12345 |
| Consumer | arjun@test.com | Test@12345 |
| Anchor Creator | anchor.pm@scaleup.io | Creator@123 |
| Anchor Creator | anchor.mba@scaleup.io | Creator@123 |
| Core Creator | core.entrepreneur@scaleup.io | Creator@123 |
| Core Creator | core.marketing@scaleup.io | Creator@123 |
| Rising Creator | rising.sat@scaleup.io | Creator@123 |
| Rising Creator | rising.softskills@scaleup.io | Creator@123 |

---

## Appendix B: Content Domains in Database

| Domain | Topics | Videos |
|--------|--------|--------|
| Product Management | product strategy, roadmapping, user research, prioritization, metrics, product-market fit | ~12 |
| Entrepreneurship | startup, fundraising, business model, leadership, lean startup | ~12 |
| SAT Preparation | sat math, sat reading, sat writing, test strategy | ~10 |
| Business Soft Skills | communication, negotiation, public speaking, emotional intelligence, leadership | ~12 |
| Marketing | digital marketing, branding, content marketing, growth hacking | ~12 |
| MBA Preparation | case study, finance basics, strategy, operations management | ~12 |

All content is served as MP4 from S3 (no YouTube embeds).

---

## Appendix C: Recommendation Engine Scoring

The feed is **not** chronological. Every content item has a **recommendation score (0-100)** computed from:

| Factor | Weight | What It Does |
|--------|--------|-------------|
| Topic Relevance | 40 pts | Matches user's objectives (primary = 70%, secondaries = 30%) |
| Difficulty Match | 20 pts | Calibrated to user's knowledge level from KnowledgeProfile |
| Quality Score | 15 pts | AI-assessed content quality (0-100 normalized) |
| Social Proof | 10 pts | Likes, saves, ratings from other users |
| Recency | 5 pts | Newer content scores higher |
| Diversity Penalty | -5 pts | Prevents single-topic domination in feed |
| Gap Bonus | +10 pts | Boosts content for weak topics from KnowledgeProfile |

**Source fairness:** Feed alternates between YouTube-sourced and original creator content (round-robin interleaving).

**Cold start:** New users with no consumption history get a simplified feed based on onboarding objectives data.

The `_recommendationScore` field is returned on feed items but **should not be shown to users**.

---

## Appendix D: Background Processes (Frontend Should Know About)

These happen server-side automatically. Frontend doesn't trigger them directly but should be aware of the effects:

| Process | When | User-Visible Effect |
|---------|------|-------------------|
| Content AI Processing | After upload/import | Content gets summary, concepts, quality score |
| Quiz Auto-Generation | After 3+ items on a topic | Push notification + quiz appears in list |
| Weekly Review Quiz | Every Sunday 6 PM IST | Push notification + quiz appears |
| Retention Check | Daily midnight | Quiz generated for stale topics |
| Journey Advancement | Daily midnight | Week/phase auto-advances |
| Creator Tier Promotion | Weekly Sunday | Tier badge updates automatically |
| Streak Reset | Daily 1:30 AM UTC | Streak drops to 0 if user was inactive |
| Re-engagement Push | Daily 10 AM IST | Push notification for 3+ day inactive users |
| Quiz Expiry | Daily 1 AM | Expired quizzes removed from pending list |
| Journey Adaptation | After quiz completion | Journey plan may change (see adaptation history) |

---

## Appendix E: Future Features (Keep Architecture Flexible)

These are planned but not yet built. The current architecture supports them:

1. **Mentorship** — Creators can offer 1:1 mentorship to learners
2. **Cohorts** — Creators start group learning programs for specific topics/objectives
3. **Live AMA Sessions** — Creators host live Q&A sessions
4. **Question count selection** — Users can choose quiz length (5/10/15/20) when requesting on-demand quiz
5. **Social features expansion** — Activity feed, likes on comments, content sharing
6. **Offline video download** — Download S3 content for offline viewing
7. **Article/Infographic content types** — Currently video-only, schema supports articles + infographics
8. **Multiple concurrent journeys** — Currently 1 active journey, model supports multiple

---

*End of Document. This is the single source of truth for all frontend development on ScaleUp.*
*Version 2.0 — February 2026*
