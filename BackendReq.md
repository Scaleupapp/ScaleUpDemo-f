# ScaleUp C2O Platform — Frontend Development Bible

> **Version:** 1.0 | **Platform:** iOS (primary), Android (future) | **Backend Base URL:** `http://localhost:5001/api/v1`
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
8. [Quizzes & Assessment](#8-quizzes--assessment)
9. [Knowledge Profile](#9-knowledge-profile)
10. [Learning Journey](#10-learning-journey)
11. [Creator Experience](#11-creator-experience)
12. [Social & Community](#12-social--community)
13. [Search & Explore](#13-search--explore)
14. [User Profile & Settings](#14-user-profile--settings)
15. [Admin Panel](#15-admin-panel)
16. [API Reference (Complete)](#16-api-reference-complete)
17. [Data Models Reference](#17-data-models-reference)
18. [Error Handling & Edge Cases](#18-error-handling--edge-cases)
19. [Push Notifications](#19-push-notifications)
20. [Offline & Caching Strategy](#20-offline--caching-strategy)
21. [Analytics Events](#21-analytics-events)

---

## 1. Product Vision & Design Philosophy

### What is ScaleUp?

ScaleUp is a **Content-to-Outcome (C2O)** learning platform. Users don't just consume content — they set objectives, follow adaptive learning journeys, take AI-generated quizzes, and build a measurable knowledge profile. The platform closes the loop between "watching a video" and "actually learning something."

### The C2O Flywheel

```
Set Objective → Discover Content → Consume → Quiz Triggered →
AI Generates Quiz → Score & Analyze → Knowledge Profile Updates →
Journey Adapts → Better Recommendations → Loop
```

### Design DNA: Netflix + Spotify + Apple + Masterclass

| Inspiration | What We Take | Where It Applies |
|-------------|-------------|-----------------|
| **Netflix** | Cinematic thumbnails, autoplay previews, "Because you watched X" rows, horizontal scroll carousels, dark immersive UI | Content discovery, feed, recommendations |
| **Spotify** | Personalized playlists, "Daily Mix" concept, wrapped/stats, progress tracking, smooth transitions | Learning paths, knowledge profile, progress stats |
| **Apple** | Minimal typography, generous whitespace, buttery 60fps animations, haptic feedback, system-native feel | Overall UI framework, interactions, gestures |
| **Masterclass** | Premium feel, full-bleed hero videos, creator spotlight, aspirational imagery, class-based navigation | Creator profiles, content player, onboarding |

### Core Design Principles

1. **Dark-first, content-forward** — Content thumbnails and video are the hero. UI chrome recedes.
2. **Effortless consumption** — One-tap to play. Swipe to next. Zero friction between discovery and learning.
3. **Progress is visible everywhere** — Streaks, scores, milestones, journey progress — always present but never cluttered.
4. **Intelligence feels magical** — The AI recommendations, quiz triggers, and journey adaptations should feel seamlessly personalized, not algorithmic.
5. **Premium but not pretentious** — Masterclass-level polish with an approachable, non-elitist tone.

---

## 2. Design System & Brand Guidelines

### Color Palette

```
// Primary
Primary:          #6C5CE7 (Violet — intelligence, premium)
Primary Light:    #A29BFE
Primary Dark:     #4A3ABA

// Background (Dark Mode — Default)
Background:       #0A0A0F
Surface:          #16161E
Surface Elevated: #1E1E2A
Card:             #22222E

// Background (Light Mode)
Background:       #F8F9FA
Surface:          #FFFFFF
Surface Elevated: #FFFFFF (with shadow)
Card:             #FFFFFF

// Text
Text Primary:     #FFFFFF (dark) / #1A1A2E (light)
Text Secondary:   #8E8EA0 (dark) / #6B7280 (light)
Text Tertiary:    #52526B (dark) / #9CA3AF (light)

// Accents
Success:          #00C48C
Warning:          #FFB347
Error:            #FF6B6B
Info:             #4DA6FF

// Creator Tiers
Anchor Gold:      #FFD700
Core Silver:      #C0C0C0
Rising Bronze:    #CD7F32

// Gradients
Hero Gradient:    linear-gradient(135deg, #6C5CE7, #A29BFE, #FD79A8)
Card Overlay:     linear-gradient(180deg, transparent 40%, rgba(0,0,0,0.85) 100%)
Progress Bar:     linear-gradient(90deg, #6C5CE7, #00C48C)
```

### Typography

```
// iOS: SF Pro Display + SF Pro Text
// Android (future): Google Sans / Inter

Display Large:    SF Pro Display Bold 34pt     — Hero titles
Display Medium:   SF Pro Display Semibold 28pt — Section headers
Title Large:      SF Pro Display Semibold 22pt — Screen titles
Title Medium:     SF Pro Text Semibold 18pt    — Card titles
Body:             SF Pro Text Regular 16pt     — Primary text
Body Small:       SF Pro Text Regular 14pt     — Secondary text
Caption:          SF Pro Text Regular 12pt     — Metadata, timestamps
Micro:            SF Pro Text Medium 10pt      — Tags, badges
Mono:             SF Mono Regular 14pt         — Scores, timers
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

// Curves
Spring:   spring(1, 80, 12)  — bouncy, playful (quiz results, confetti)
Ease Out: cubic-bezier(0.16, 1, 0.3, 1)  — enter animations
Ease In:  cubic-bezier(0.7, 0, 0.84, 0)  — exit animations
```

### Haptics

```
Selection:  UIImpactFeedbackGenerator(.light)   — tab switches, toggles
Success:    UINotificationFeedbackGenerator(.success) — quiz correct, milestone
Warning:    UINotificationFeedbackGenerator(.warning) — quiz wrong answer
Error:      UINotificationFeedbackGenerator(.error)   — API errors
Heavy:      UIImpactFeedbackGenerator(.heavy)   — long press, drag
```

### Component Library Overview

| Component | Description | Reference |
|-----------|-------------|-----------|
| ContentCard | 16:9 thumbnail, gradient overlay, title, creator, duration badge | Netflix tile |
| ContentCardWide | Full-width card with metadata row below thumbnail | Masterclass hero |
| CreatorAvatar | Circular avatar with tier color ring (gold/silver/bronze) | Custom |
| ProgressRing | Circular progress indicator with percentage center | Apple Activity |
| ScoreGauge | Animated circular gauge 0-100 with color gradient | Custom |
| QuizOption | A/B/C/D pill buttons with select/correct/wrong states | Custom |
| MilestoneChip | Pill with icon + label + checkmark for completed | Spotify wrapped |
| StreakBadge | Fire icon + streak count, pulsing animation when active | Duolingo-inspired |
| KnowledgeBar | Horizontal topic bar with gradient fill based on mastery | Custom |
| JourneyTimeline | Vertical timeline with phase nodes and progress line | Custom |
| BottomSheet | Pull-up sheet with detents (half, full) for context menus | Apple Maps |
| SkeletonLoader | Shimmer animation placeholder matching card shapes | Standard |

---

## 3. App Architecture & Navigation

### Navigation Structure

```
TabBar (5 tabs)
├── Home (Dashboard)
│   ├── Today's Plan
│   ├── Continue Watching
│   ├── Readiness Score Widget
│   ├── Active Journey Summary
│   └── Upcoming Quizzes
├── Discover (Feed + Explore)
│   ├── Personalized Feed (vertical scroll)
│   ├── Category Rows (horizontal scroll)
│   ├── Trending
│   ├── Creator Spotlight
│   └── Search
├── Journey (Learning Journey)
│   ├── Active Journey Map
│   ├── Weekly Plan
│   ├── Milestones
│   └── Generate New Journey
├── Progress (Knowledge Profile)
│   ├── Overall Score
│   ├── Topic Mastery Grid
│   ├── Quiz History
│   ├── Strengths & Weaknesses
│   ├── Learning Stats
│   └── Consumption Graph
└── Profile
    ├── My Profile
    ├── My Playlists
    ├── My Learning Paths
    ├── Saved Content
    ├── Settings
    ├── Creator Dashboard (if creator)
    └── Admin Panel (if admin)
```

### Tab Bar Design

- **Dark translucent background** with blur effect
- **Active tab:** Primary violet icon + label
- **Inactive tabs:** Grey icons, no labels
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

---

## 4. Authentication & Onboarding

### Auth Flow

```
Launch → Splash (2s, animated logo) → Auth Check
├── Has valid token → Home
├── Token expired → Silent refresh → Home (or login)
└── No token → Welcome Screen
```

### Welcome Screen

**Design:** Full-bleed background video/animation showcasing creators and content. ScaleUp logo centered. Two CTAs at bottom.

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
```

### Onboarding Flow (Post-Registration)

6-step guided flow. Progress bar at top. Skip option where applicable. Can go forward only.

**Step 1: Profile Setup**
```
UI: Avatar upload + first/last name confirmation
API: PUT /api/v1/onboarding/profile
Body: { firstName, lastName, profilePicture }
```

**Step 2: Background**
```
UI: Education picker + work experience input
API: PUT /api/v1/onboarding/background
Body: { education, workExperience }
```

**Step 3: Set Your Objective**
```
UI: Objective type selector (7 options as illustrated cards)
    Then specifics form based on selected type
    Then timeline picker + level selector + weekly hours slider

Objective Types:
- exam_preparation    → examName input
- upskilling          → targetSkill input
- interview_preparation → targetRole + targetCompany
- career_switch       → fromDomain + toDomain
- academic_excellence → (general)
- casual_learning     → (general)
- networking          → (general)

Timelines: 1_month, 3_months, 6_months, 1_year, no_deadline
Levels: beginner, intermediate, advanced
Weekly Hours: slider 1-40

API: POST /api/v1/onboarding/objective
Body: { objectiveType, specifics, timeline, currentLevel, weeklyCommitHours }
Status: 201
```

**Step 4: Learning Preferences**
```
UI: Learning style cards (video/article/interactive/mix) + weekly hours confirmation
API: PUT /api/v1/onboarding/preferences
Body: { preferredLearningStyle, weeklyCommitHours }
```

**Step 5: Topic Interests**
```
UI: Tag cloud / chip selector for skills and topics
API: PUT /api/v1/onboarding/interests
Body: { skills: [], topicsOfInterest: [] }
```

**Step 6: Complete**
```
UI: Success animation + "Start Learning" CTA
API: POST /api/v1/onboarding/complete
Status: 201
→ Navigate to Home
```

**Get Onboarding Status (on app open if not complete):**
```
API: GET /api/v1/onboarding
Response: { onboardingStep, onboardingComplete, profile data }
```

---

## 5. Home & Dashboard

### Dashboard Screen

**Design Reference:** Netflix Home meets Apple Fitness. Dark background, card-heavy, vertical scroll with horizontal carousels.

```
API: GET /api/v1/dashboard
Response:
{
  objectives: [...],
  readinessScore: 72,
  knowledgeProfile: { overallScore, strengths, weaknesses, topicMastery },
  journey: { title, currentPhase, currentWeek, progress, streak },
  weeklyStats: { contentConsumed, totalContentConsumed, dominantTopics },
  nextActions: [{ type, message, data }],
  upcomingMilestones: [...],
  pendingQuizzes: 3
}
```

### Dashboard Layout (top to bottom)

**1. Greeting Header**
```
"Good morning, Rahul" + date
Streak badge (fire icon + count) at top right
```

**2. Readiness Score Hero Card**
```
Large circular gauge (0-100) with gradient fill
Labeled: "Exam Readiness" or "Learning Score"
Calculated: (knowledge * 0.4) + (journey * 0.3) + (consistency * 0.3)
Tap → Navigate to Knowledge Profile
```

**3. Today's Plan Card** (if journey active)
```
API: GET /api/v1/journey/today
Shows: Phase name, today's topics, assigned content (1-2 items), estimated time
Each content item is tappable → opens player
"Mark Complete" button for each item
```

**4. Continue Watching Row** (horizontal carousel)
```
API: GET /api/v1/progress/history?limit=10
Filter: isCompleted = false
Shows: Content cards with progress bar overlay
```

**5. Pending Quizzes Card**
```
If pendingQuizzes > 0:
  "You have {n} quiz(es) ready" with CTA to quiz list
API: GET /api/v1/quizzes (status = ready/delivered)
```

**6. Knowledge Snapshot** (horizontal scroll of topic bars)
```
From dashboard.knowledgeProfile.topicMastery
Shows: Topic name + score bar + level badge
Tap → Knowledge Profile tab
```

**7. Recommended For You** (horizontal carousel)
```
API: GET /api/v1/recommendations/feed?limit=10
Content cards sorted by recommendation score
```

**8. Weekly Stats Card**
```
From dashboard.weeklyStats
"This week: {n} lessons completed | {topics} explored"
Bar chart or ring chart visualization
```

---

## 6. Content Discovery & Feed

### Feed Screen (Discover Tab - Primary View)

**Design:** Netflix-style vertical scroll with horizontal carousels. Dark background, large thumbnails.

**Layout:**

**1. Search Bar** (sticky top)
```
Tappable search input → navigates to Search screen
```

**2. Hero Banner** (full-width, 16:9 aspect ratio)
```
Autoplay/loop featured content preview
Gradient overlay with title + creator name
"Play" and "Add to List" buttons
Source: First item from /api/v1/recommendations/feed
```

**3. "Picked For You" Row**
```
API: GET /api/v1/recommendations/feed?limit=15
Horizontal scroll of ContentCard components
Each card: thumbnail + title + creator + duration badge
Items include _recommendationScore (not shown to user)
```

**4. "Fill Your Knowledge Gaps" Row**
```
API: GET /api/v1/recommendations/gaps?limit=10
Shows content targeting weak topics from knowledge profile
Label: "Strengthen Your Weak Spots"
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
Trending badge on cards
```

**7. Creator Spotlight Row**
```
API: GET /api/v1/creator/search?limit=5
Circular creator avatars with tier ring color
Creator name + domain underneath
Tap → Creator profile screen
```

**8. "Because You Watched X" Row**
```
API: GET /api/v1/recommendations/similar/{lastWatchedContentId}?limit=10
Personalized similarity-based recommendations
```

### Explore View (Toggle within Discover tab)

```
Toggle: "For You" | "Explore"

Explore shows filterable grid:
- Domain filter chips (horizontal scroll)
- Difficulty filter (all/beginner/intermediate/advanced)
- Sort by: Relevance, Newest, Most Popular

API: GET /api/v1/content/explore?domain=X&difficulty=Y&search=Z&page=1&limit=20
Response: { items: Content[], pagination }
```

### Content Card Design

```
┌──────────────────────────┐
│                          │
│    Thumbnail (16:9)      │
│    with gradient overlay │
│                          │
│  ┌──────┐                │
│  │12:30 │   ── duration  │
│  └──────┘                │
├──────────────────────────┤
│ Title (2 lines max)      │
│ Creator Name • Domain    │
│ ★ 4.5 • 12K views       │
└──────────────────────────┘

States:
- Default
- With progress bar (continue watching)
- With "NEW" badge (< 7 days old)
- YouTube source indicator (small YT icon)
```

---

## 7. Content Player & Consumption

### Player Screen

**Design Reference:** Netflix player + Masterclass lesson view. Full-screen immersive. Minimal chrome.

### Video Player (YouTube Content)

```
Use YouTube iframe or WebView to embed YouTube video player
URL format: https://youtube.com/watch?v={youtubeVideoId}

On entering player:
API: GET /api/v1/content/{id}
Response: Full content object with aiData, sourceAttribution, creatorId populated

Resume position from ContentProgress:
API: GET /api/v1/progress/history (or local cache)
```

### Content Detail View (below/alongside player)

```
Layout (scrollable below player):
1. Title (large)
2. Creator row: Avatar + Name + Tier Badge + Follow button
3. Stats row: Views • Likes • Rating • Comments
4. Action bar: Like ❤️ | Save 🔖 | Rate ⭐ | Share 📤
5. AI Summary section (collapsible):
   - aiData.summary (2-3 sentences)
   - Key Concepts chips (from aiData.keyConcepts)
   - Prerequisites (from aiData.prerequisites)
6. Description (expandable)
7. "Similar Content" horizontal row
8. Comments section

If YouTube content:
   Source attribution: "This content is sourced from YouTube..."
   Original creator link
```

### Player Interactions

**Progress Tracking (send every 10-15 seconds while playing):**
```
API: PUT /api/v1/progress/{contentId}
Body: { currentPosition: 245, totalDuration: 720 }
Response: { percentageCompleted, currentPosition, totalDuration, isCompleted }
```

**Mark Complete (when video ends or user taps):**
```
API: POST /api/v1/progress/{contentId}/complete
Response: { isCompleted: true, completedAt }
Important: This triggers quiz checks server-side
```

**Like (toggle):**
```
API: POST /api/v1/content/{id}/like
Response: { liked: true/false, likeCount }
Haptic: Selection on toggle
```

**Save/Bookmark (toggle):**
```
API: POST /api/v1/content/{id}/save
Response: { saved: true/false, saveCount }
```

**Rate (1-5 stars):**
```
API: POST /api/v1/content/{id}/rate
Body: { value: 4 }
Response: { rating, averageRating, ratingCount }
```

**Comments:**
```
GET  /api/v1/content/{id}/comments?page=1&limit=20
POST /api/v1/content/{id}/comments  Body: { text, parentId? }

Comment UI:
- Avatar + Name + Time ago
- Comment text
- Reply button (creates threaded comment with parentId)
- Delete own comments (swipe left)
```

**Similar Content:**
```
API: GET /api/v1/recommendations/similar/{contentId}?limit=10
Horizontal carousel below player
```

---

## 8. Quizzes & Assessment

### Quiz Flow Overview

```
Content Consumed → Server detects threshold (3+ items on topic) →
Quiz generated by AI → Appears in user's quiz list →
User starts quiz → Answers questions one by one →
Submits → Scored → Results shown → Knowledge profile updated
```

### Quiz List Screen

**Design:** Card-based list. Each quiz card shows type icon, topic, question count, status.

```
API: GET /api/v1/quizzes
Response: Array of quizzes (status: ready, delivered, in_progress)
Note: Answers are NOT included until quiz is completed

Quiz Card:
┌──────────────────────────────────┐
│ 📝 Topic Consolidation           │
│ React Hooks                      │
│ 10 Questions • ~10 min           │
│ Expires in 5 days                │
│                   [Start Quiz →] │
└──────────────────────────────────┘
```

### Quiz Detail (Before Starting)

```
API: GET /api/v1/quizzes/{id}
Response: Quiz object WITHOUT correctAnswer fields

Shows:
- Quiz title + type
- Topic
- Question count + estimated time
- Source content links
- "Start Quiz" CTA

Note: First GET marks quiz as "delivered"
```

### Start Quiz

```
API: POST /api/v1/quizzes/{id}/start
Status: 201
Response: QuizAttempt { _id, quizId, status: "in_progress", startedAt }
```

### Quiz Question Screen

**Design:** One question per screen. Clean, focused. Progress bar at top. Timer optional.

```
Layout:
- Progress: "3 of 10" + progress bar
- Question text (large, prominent)
- 4 option pills (A/B/C/D)
  - Default: outlined
  - Selected: filled primary
  - (After submit: green for correct, red for wrong — only shown after completing entire quiz)
- Skip button
- Next button (appears after selection)

Submit Answer:
API: PUT /api/v1/quizzes/{id}/answer
Body: { questionIndex: 2, selectedAnswer: "B", timeTaken: 23 }
Response: Updated attempt (no correct answer revealed yet)

Skip:
Same API with selectedAnswer: "skipped"
```

### Complete Quiz

```
API: POST /api/v1/quizzes/{id}/complete
Response: Full scored attempt with results

Shows Results Screen (celebration animation if score > 80%):
{
  score: { total: 10, correct: 7, incorrect: 2, skipped: 1, percentage: 70 },
  topicBreakdown: [{ topic, correct, total, percentage }],
  analysis: {
    strengths: ["react hooks", "state management"],
    weaknesses: ["useEffect cleanup"],
    missedConcepts: [{ concept, contentId, timestamp, suggestion }],
    confidenceScore: 80,
    comparisonToPrevious: { previousScore: 60, improvement: 10, trend: "improving" }
  }
}
```

### Quiz Results Screen

**Design:** Confetti animation on high scores. Detailed breakdown cards.

```
Layout:
1. Score Hero: Large percentage + circular gauge animation
2. Breakdown:
   - Correct ✓ / Incorrect ✗ / Skipped ○ counts
   - Topic breakdown bars
3. Strengths & Weaknesses chips
4. Missed Concepts (tappable → links back to content + timestamp)
5. Trend comparison: "↑ 10% improvement from last quiz"
6. CTA: "Review Answers" or "Back to Learning"

Review Answers:
API: GET /api/v1/quizzes/{id}/results
Response: Full quiz with correctAnswer + explanations visible
Shows each question with:
- Your answer (highlighted green/red)
- Correct answer
- Explanation text
- Source content link + timestamp
```

### Quiz History

```
API: GET /api/v1/quizzes/history
Response: Array of completed QuizAttempts

Shows: Date, topic, score percentage, trend arrow
Tappable → quiz results detail
```

### On-Demand Quiz Request

```
User can request a quiz on any topic:
API: POST /api/v1/quizzes/request
Body: { topic: "product management", contentIds: ["id1", "id2"] }
Response: { message: "Quiz generation started" }

Show: "Your quiz is being generated..." loading state
Poll GET /api/v1/quizzes periodically to check for new ready quiz
```

---

## 9. Knowledge Profile

### Knowledge Profile Screen (Progress Tab)

**Design Reference:** Apple Fitness rings + Spotify Wrapped. Visually rich, data-dense but clean.

### Top Section: Overall Score

```
API: GET /api/v1/knowledge/profile
Response: {
  overallScore: 65,
  totalTopicsCovered: 12,
  totalQuizzesTaken: 18,
  strengths: ["react", "product strategy", "user research"],
  weaknesses: ["system design", "sql"],
  topicMastery: [{ topic, score, level, trend, quizzesTaken, lastAssessedAt }]
}

UI: Large animated ScoreGauge (0-100)
    Subtitle: "12 topics covered • 18 quizzes taken"
```

### Topic Mastery Grid

```
Grid of KnowledgeBar components (2 columns):

┌──────────────────────┐
│ React          85/100 │
│ ██████████████░░░░░░ │
│ Advanced ↑ improving  │
├──────────────────────┤
│ SQL            35/100 │
│ ██████░░░░░░░░░░░░░░ │
│ Beginner ↓ declining  │
└──────────────────────┘

Tap topic → Topic Detail:
API: GET /api/v1/knowledge/topic/{topic}
Shows: Score history chart, quiz attempts, trend
```

### Mastery Level Indicators

```
Expert (90-100):    ⬛⬛⬛⬛⬛ Gold badge
Advanced (70-89):   ⬛⬛⬛⬛░ Purple badge
Intermediate (50-69): ⬛⬛⬛░░ Blue badge
Beginner (20-49):   ⬛⬛░░░ Grey badge
Not Started (0-19): ⬛░░░░ Outline only
```

### Strengths & Weaknesses

```
API: GET /api/v1/knowledge/strengths
API: GET /api/v1/knowledge/gaps

Strengths: Green-tinted chips with score
Weaknesses: Red-tinted chips with "Strengthen" CTA
Tapping weakness → gap-filling recommendations:
  API: GET /api/v1/recommendations/gaps
```

### Learning Stats Section

```
API: GET /api/v1/progress/stats
Response: {
  totalContentConsumed: 45,
  totalTimeSpent: 54000, // seconds
  dominantTopics: ["product management", "react"],
  topicCount: 12,
  topicBreakdown: [{ topic, contentConsumed, affinityScore }]
}

UI: Visual stats cards:
- "15 hours learned" (large number)
- "45 lessons completed"
- "12 topics explored"
- Topic distribution pie/bar chart
```

---

## 10. Learning Journey

### Journey Screen (Journey Tab)

**Design Reference:** Apple Fitness plan + game-like progression. Timeline/map aesthetic.

### No Active Journey State

```
Empty state illustration
"Generate your personalized learning plan"
CTA: "Create Journey"

Flow:
1. Select objective (from existing objectives)
   API: GET /api/v1/objectives
2. Tap "Generate Journey"
   API: POST /api/v1/journey/generate
   Body: { objectiveId: "..." }
   Status: 201
   Note: Generation takes ~10-20 seconds (AI call)
   Show: Animated loading ("Crafting your personalized plan...")
```

### Active Journey View

```
API: GET /api/v1/journey
Response: Full journey object

Layout:
1. Journey Title + Objective
2. Phase Timeline (horizontal, scrollable)
   Visual: Connected dots/nodes for each phase
   Current phase highlighted, completed phases checked
   Phases: foundation → building → strengthening → mastery → revision
3. Progress Stats Card:
   - Overall: {progress.overallPercentage}%
   - Content: {contentConsumed}/{contentAssigned}
   - Quizzes: {quizzesCompleted}/{quizzesAssigned}
   - Streak: 🔥 {currentStreak} days
   - Milestones: {milestonesCompleted}/{milestonesTotal}
4. This Week's Plan (expanded)
5. Milestones List
```

### Weekly Plan View

```
API: GET /api/v1/journey/week/{weekNumber}
Response: Weekly plan with dailyAssignments

Layout: 7-day view (Mon-Sun)
Each day shows:
- Topics for the day
- Assigned content (1-2 items, tappable)
- Estimated time
- Completed checkbox
- If today: highlighted/expanded

Today's Plan (shortcut):
API: GET /api/v1/journey/today
Response: { weekNumber, day, plan: dailyAssignment, weekGoals }
```

### Milestones

```
API: GET /api/v1/journey/milestones
Response: Array of milestones

Milestone types:
- topic_completion: "Complete all React content"
- score_target: "Score 80%+ on Product Management quiz"
- streak: "Maintain a 7-day learning streak"
- phase_completion: "Complete Foundation phase"

Milestone Card:
┌─────────────────────────────────┐
│ 🎯 Score 80% on PM Quiz         │
│ Target: 80% | Current: 72%      │
│ Status: In Progress              │
│ ████████████░░░░ 72%            │
└─────────────────────────────────┘
```

### Journey Controls

```
Pause:  PUT /api/v1/journey/pause
Resume: PUT /api/v1/journey/resume

Journey Progress:
API: GET /api/v1/journey/progress

Adaptation History:
API: GET /api/v1/journey/adaptations
Shows: How AI has adjusted the plan based on performance
```

---

## 11. Creator Experience

### Creator Application Flow

```
Any user can apply:
API: POST /api/v1/creator/apply
Body: {
  domain: "product management",
  specializations: ["product strategy", "user research"],
  experience: "5 years as PM at Google...",
  motivation: "I want to share my knowledge...",
  sampleContentLinks: ["https://youtube.com/...", "https://medium.com/..."],
  portfolioUrl: "https://mysite.com",
  socialLinks: { linkedin, twitter, youtube, website }
}
Status: 201

Check status:
API: GET /api/v1/creator/application
Response: Application with endorsements array and status
```

### Creator Approval (Peer-Based)

```
No admin approval needed. Peer endorsement system:
- 1 Anchor creator endorsement (same domain) → Auto-approved as Rising
- OR 2 Core creator endorsements (same domain) → Auto-approved as Rising

Existing creators browse applications:
API: GET /api/v1/creator/applications?page=1&limit=20
Response: Pending applications in their domain

Endorse:
API: POST /api/v1/creator/applications/{applicationId}/endorse
Body: { note: "Great sample content, would be valuable addition" }

Admin can only reject (not approve):
API: POST /api/v1/admin/applications/{id}/reject
Body: { reviewNote: "Insufficient experience" }
```

### Creator Dashboard (within Profile tab)

```
Only visible to users with role: 'creator'

API: GET /api/v1/creator/profile
Response: CreatorProfile { tier, domain, specializations, bio, stats }

Stats displayed:
- Total Content: stats.totalContent
- Total Views: stats.totalViews
- Total Followers: stats.totalFollowers
- Average Rating: stats.averageRating
- Creator Tier badge (Rising/Core/Anchor with color)

Tier Progression (display only, server-managed):
- Rising → Core: 20+ content, 4.0+ avg rating
- Core → Anchor: 50+ content, 4.5+ avg rating, 1000+ followers
```

### Content Upload (Creators Only)

```
Step 1: Request Upload
API: POST /api/v1/content/request-upload
Body: { contentType: "video", fileName: "lesson1.mp4", fileSize: 52428800 }
Response: { uploadUrl: "s3-presigned-url", contentId, fields }

Step 2: Upload file directly to S3 using presigned URL

Step 3: Complete Upload
API: POST /api/v1/content/complete-upload
Body: {
  contentId,
  title: "Understanding React Hooks",
  description: "...",
  domain: "web development",
  topics: ["react", "hooks"],
  difficulty: "intermediate",
  tags: ["frontend", "javascript"]
}
Status: 201
Response: Content object (status: "processing", aiStatus: "pending")

Step 4: AI processes content (automatic, background)
  → aiStatus moves: pending → processing → completed
  → status moves: processing → ready

Step 5: Publish
API: POST /api/v1/content/{id}/publish
Response: Content (status: "published")
```

### Creator's Content Management

```
API: GET /api/v1/content/my-content?page=1&limit=20
Response: Paginated list of creator's content (all statuses)

Update content:
API: PUT /api/v1/content/{id}
Body: { title, description, domain, topics, difficulty, tags }

Unpublish:
API: POST /api/v1/content/{id}/unpublish
```

### Creator Profile Update

```
API: PUT /api/v1/creator/profile
Body: { bio, specializations, domain }
```

---

## 12. Social & Community

### Follow System

```
Follow: POST /api/v1/social/follow/{userId}   (201)
Unfollow: DELETE /api/v1/social/follow/{userId}
Cannot follow yourself (400)
Duplicate follow (409)

Followers: GET /api/v1/social/followers/{userId}?page=1&limit=20
Following: GET /api/v1/social/following/{userId}?page=1&limit=20
Response: { followers/following: User[], pagination }
```

### Playlists

```
Create:  POST /api/v1/social/playlists
         Body: { title, description, isPublic }
List:    GET /api/v1/social/playlists
Detail:  GET /api/v1/social/playlists/{id}
Update:  PUT /api/v1/social/playlists/{id}
Delete:  DELETE /api/v1/social/playlists/{id}
Add:     POST /api/v1/social/playlists/{id}/items  Body: { contentId }
Remove:  DELETE /api/v1/social/playlists/{id}/items/{contentId}

Playlist UI: Vertical list of content items with drag-to-reorder
Play All button → sequential content player
```

### Learning Paths (Community)

```
Explore:  GET /api/v1/learning-paths/explore?page=1
Mine:     GET /api/v1/learning-paths/mine
Detail:   GET /api/v1/learning-paths/{id}
Create:   POST /api/v1/learning-paths Body: { title, description, domain, topics, difficulty }
Update:   PUT /api/v1/learning-paths/{id}
Publish:  POST /api/v1/learning-paths/{id}/publish
Archive:  POST /api/v1/learning-paths/{id}/archive
Add Item: POST /api/v1/learning-paths/{id}/items Body: { contentId, order }
Reorder:  PUT /api/v1/learning-paths/{id}/items/reorder Body: { orderedContentIds }
Remove:   DELETE /api/v1/learning-paths/{id}/items/{contentId}
Follow:   POST /api/v1/learning-paths/{id}/follow
Unfollow: DELETE /api/v1/learning-paths/{id}/follow
Rate:     POST /api/v1/learning-paths/{id}/rate Body: { rating: 1-5 }
```

### Comments

```
List:   GET /api/v1/content/{id}/comments?page=1&limit=20
Create: POST /api/v1/content/{id}/comments Body: { text, parentId? }
Delete: DELETE /api/v1/social/comments/{commentId} (own only)

Threaded: parentId creates reply chain
```

---

## 13. Search & Explore

### Search Screen

```
UI: Full-screen search with:
- Text input with clear button
- Recent searches (local storage)
- Suggested topics chips

API: GET /api/v1/content/explore?search={query}&page=1&limit=20
Response: { items: Content[], pagination }

Filters (bottom sheet):
- Domain: chips for each domain
- Difficulty: beginner / intermediate / advanced
- Content Type: video / article / infographic
- Sort: relevance / newest / most popular

Creator Search:
API: GET /api/v1/creator/search?q={query}&domain={domain}&tier={tier}
Response: Paginated creator list
```

---

## 14. User Profile & Settings

### My Profile

```
API: GET /api/v1/users/me
Response: Full user object (excluding password, refreshTokenHash)

Profile Screen Layout:
1. Profile picture + name
2. Bio
3. Stats: followers | following | content consumed
4. Skills chips
5. Education + Work Experience
6. Actions: Edit Profile, Settings, Logout
```

### Public Profile (Other Users)

```
API: GET /api/v1/users/{userId}
Response: Limited fields: firstName, lastName, username, profilePicture,
          bio, role, followersCount, followingCount, skills, createdAt

If creator → show CreatorProfile data (tier badge, domain, content count)
Follow/Unfollow button
```

### Edit Profile

```
API: PUT /api/v1/users/me
Allowed fields: firstName, lastName, username, bio, dateOfBirth, location,
                education, workExperience, skills, profilePicture, phone,
                deviceType, fcmToken
```

### Objectives Management

```
List:       GET /api/v1/objectives
Create:     POST /api/v1/objectives Body: { objectiveType, specifics, timeline, currentLevel, weeklyCommitHours }
Update:     PUT /api/v1/objectives/{id}
Pause:      PUT /api/v1/objectives/{id}/pause
Resume:     PUT /api/v1/objectives/{id}/resume
Set Primary: PUT /api/v1/objectives/{id}/set-primary
```

### Settings Screen

```
- Account: Email, Phone, Change Password
- Notifications: Push notification toggles
- Appearance: Dark/Light mode toggle
- Storage: Clear cache
- About: Version, Terms, Privacy
- Logout: POST /api/v1/auth/logout
- Deactivate Account: DELETE /api/v1/users/me (with confirmation dialog)
```

### Add/Verify Phone

```
API: POST /api/v1/auth/phone/verify
Body: { phone, otp }
Requires: auth token (user must be logged in)
Flow: Enter phone → receive OTP → verify
```

---

## 15. Admin Panel

Only accessible to users with `role: 'admin'`. Separate section within Profile tab.

### Admin Dashboard

```
API: GET /api/v1/admin/stats
Response: {
  totalUsers, totalCreators, totalContent, publishedContent
}
```

### User Management

```
List: GET /api/v1/admin/users?page=1&limit=20&role=creator&search=john
Ban:  PUT /api/v1/admin/users/{id}/ban
Unban: PUT /api/v1/admin/users/{id}/unban
```

### Creator Application Review

```
List: GET /api/v1/admin/applications?page=1&limit=20
Reject: POST /api/v1/admin/applications/{id}/reject
        Body: { reviewNote: "reason" }
Note: Admin cannot approve — only peer endorsement approves
```

### Content Moderation

```
API: PUT /api/v1/admin/content/{id}/moderate
Body: { moderationStatus: "approved" | "rejected" | "pending", moderationNote }
Note: Approved → status becomes published. Rejected → status becomes rejected.
```

### YouTube Import (Admin Only)

```
Import Video:    POST /api/v1/youtube/import/video    Body: { videoId, domain, topics }
Import Channel:  POST /api/v1/youtube/import/channel  Body: { channelId, domain, topics, maxVideos }
Import Playlist: POST /api/v1/youtube/import/playlist Body: { playlistId, domain, topics }
Search YouTube:  GET /api/v1/youtube/search?q={query}&maxResults=20
Import History:  GET /api/v1/youtube/imports?page=1&limit=50
```

---

## 16. API Reference (Complete)

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
  "data": {
    "items": [...],
    "pagination": {
      "total": 150,
      "page": 1,
      "limit": 20,
      "pages": 8,
      "hasMore": true
    }
  }
}

// Error
{
  "success": false,
  "message": "Invalid email or password",
  "error": { "code": "AUTH_FAILED", "details": {...} }
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
| POST | `/auth/phone/verify` | Add phone to account |
| POST | `/auth/logout` | Logout |

#### Onboarding (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/onboarding` | Get onboarding status |
| PUT | `/onboarding/profile` | Update profile (step 1) |
| PUT | `/onboarding/background` | Update background (step 2) |
| POST | `/onboarding/objective` | Set objective (step 3) |
| PUT | `/onboarding/preferences` | Set preferences (step 4) |
| PUT | `/onboarding/interests` | Set interests (step 5) |
| POST | `/onboarding/complete` | Complete onboarding (step 6) |

#### Dashboard (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/dashboard` | Get full dashboard data |

#### Content (Auth Required)
| Method | Path | Auth Level | Description |
|--------|------|-----------|-------------|
| GET | `/content/feed` | User | Personalized feed |
| GET | `/content/explore` | User | Explore with filters |
| GET | `/content/{id}` | User | Content detail |
| POST | `/content/{id}/like` | User | Toggle like |
| POST | `/content/{id}/save` | User | Toggle save |
| POST | `/content/{id}/rate` | User | Rate (1-5) |
| GET | `/content/{id}/comments` | User | Get comments |
| POST | `/content/{id}/comments` | User | Add comment |
| POST | `/content/request-upload` | Creator | Request S3 upload URL |
| POST | `/content/complete-upload` | Creator | Finalize upload |
| GET | `/content/my-content` | Creator | My created content |
| PUT | `/content/{id}` | Creator | Update content |
| POST | `/content/{id}/publish` | Creator | Publish |
| POST | `/content/{id}/unpublish` | Creator | Unpublish |

#### Recommendations (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/recommendations/feed` | Personalized recommendations |
| GET | `/recommendations/similar/{id}` | Similar content |
| GET | `/recommendations/objective/{objectiveId}` | Objective-based recs |
| GET | `/recommendations/gaps` | Gap-filling content |
| GET | `/recommendations/trending` | Trending content |

#### Progress (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| PUT | `/progress/{contentId}` | Update progress |
| POST | `/progress/{contentId}/complete` | Mark complete |
| GET | `/progress/history` | Learning history |
| GET | `/progress/stats` | Progress statistics |

#### Quizzes (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/quizzes` | List available quizzes |
| GET | `/quizzes/history` | Quiz attempt history |
| POST | `/quizzes/request` | Request on-demand quiz |
| GET | `/quizzes/{id}` | Quiz detail |
| POST | `/quizzes/{id}/start` | Start attempt |
| PUT | `/quizzes/{id}/answer` | Submit answer |
| POST | `/quizzes/{id}/complete` | Complete & score |
| GET | `/quizzes/{id}/results` | View results |

#### Knowledge (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/knowledge/profile` | Knowledge profile |
| GET | `/knowledge/topic/{topic}` | Topic detail |
| GET | `/knowledge/gaps` | Knowledge gaps |
| GET | `/knowledge/strengths` | Strengths |

#### Journey (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/journey` | Active journey |
| POST | `/journey/generate` | Generate journey |
| GET | `/journey/today` | Today's plan |
| GET | `/journey/week/{weekNumber}` | Week plan |
| PUT | `/journey/pause` | Pause journey |
| PUT | `/journey/resume` | Resume journey |
| GET | `/journey/milestones` | Milestones |
| GET | `/journey/progress` | Journey progress |
| GET | `/journey/adaptations` | Adaptation history |

#### Objectives (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/objectives` | List objectives |
| POST | `/objectives` | Create objective |
| PUT | `/objectives/{id}` | Update objective |
| PUT | `/objectives/{id}/pause` | Pause |
| PUT | `/objectives/{id}/resume` | Resume |
| PUT | `/objectives/{id}/set-primary` | Set as primary |

#### Creator (Auth Required)
| Method | Path | Auth Level | Description |
|--------|------|-----------|-------------|
| POST | `/creator/apply` | User | Apply as creator |
| GET | `/creator/application` | User | My application status |
| GET | `/creator/search` | User | Search creators |
| GET | `/creator/profile` | Creator | My creator profile |
| PUT | `/creator/profile` | Creator | Update creator profile |
| GET | `/creator/applications` | Creator | Browse pending apps |
| POST | `/creator/applications/{id}/endorse` | Creator | Endorse applicant |

#### Social (Auth Required)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/social/follow/{userId}` | Follow user |
| DELETE | `/social/follow/{userId}` | Unfollow user |
| GET | `/social/followers/{userId}` | User's followers |
| GET | `/social/following/{userId}` | User's following |
| DELETE | `/social/comments/{commentId}` | Delete comment |
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
| GET | `/learning-paths/explore` | Browse paths |
| GET | `/learning-paths/mine` | My paths |
| GET | `/learning-paths/{id}` | Path detail |
| POST | `/learning-paths` | Create path |
| PUT | `/learning-paths/{id}` | Update path |
| POST | `/learning-paths/{id}/publish` | Publish path |
| POST | `/learning-paths/{id}/archive` | Archive path |
| POST | `/learning-paths/{id}/items` | Add content |
| PUT | `/learning-paths/{id}/items/reorder` | Reorder items |
| DELETE | `/learning-paths/{id}/items/{contentId}` | Remove content |
| POST | `/learning-paths/{id}/follow` | Follow path |
| DELETE | `/learning-paths/{id}/follow` | Unfollow path |
| POST | `/learning-paths/{id}/rate` | Rate path |

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
| GET | `/admin/users` | List users |
| PUT | `/admin/users/{id}/ban` | Ban user |
| PUT | `/admin/users/{id}/unban` | Unban user |
| GET | `/admin/applications` | Pending applications |
| POST | `/admin/applications/{id}/reject` | Reject application |
| PUT | `/admin/content/{id}/moderate` | Moderate content |

#### YouTube (Admin Only)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/youtube/import/video` | Import video |
| POST | `/youtube/import/channel` | Import channel |
| POST | `/youtube/import/playlist` | Import playlist |
| GET | `/youtube/search` | Search YouTube |
| GET | `/youtube/imports` | Import history |

---

## 17. Data Models Reference

### Key Enums

```
User Roles:        consumer | creator | admin
Auth Providers:    local | google | linkedin | phone
Creator Tiers:     rising | core | anchor
Content Types:     video | article | infographic
Content Status:    draft | processing | ready | published | unpublished | rejected
AI Status:         pending | processing | completed | failed
Difficulty:        beginner | intermediate | advanced
Mastery Levels:    not_started | beginner | intermediate | advanced | expert
Objective Types:   exam_preparation | upskilling | interview_preparation |
                   networking | career_switch | academic_excellence | casual_learning
Timelines:         1_month | 3_months | 6_months | 1_year | no_deadline
Quiz Types:        topic_consolidation | weekly_review | milestone_assessment |
                   retention_check | on_demand | playlist_mastery
Quiz Status:       generating | ready | delivered | in_progress | completed | expired
Question Types:    conceptual | application | cross_content | recall | critical_thinking
Journey Status:    generating | active | paused | completed | abandoned
Journey Phases:    foundation | building | strengthening | mastery | revision | exam_prep
Learning Styles:   videos | articles | interactive | mix
Interaction Types: like | save | rate | share
Trends:            improving | stable | declining
App Status:        pending | endorsed | approved | rejected
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
  "title": "string",
  "description": "string",
  "contentType": "video | article | infographic",
  "contentURL": "string",
  "thumbnailURL": "string",
  "duration": 720,
  "sourceType": "original | youtube",
  "sourceAttribution": {
    "platform": "YouTube",
    "originalCreatorName": "string",
    "originalCreatorUrl": "string",
    "originalContentUrl": "string",
    "importDisclaimer": "string"
  },
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
    "autoTags": ["string"]
  },
  "status": "published",
  "publishedAt": "ISO8601",
  "viewCount": 1250,
  "likeCount": 89,
  "commentCount": 12,
  "saveCount": 45,
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
  "bio": "string | null",
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

## 18. Error Handling & Edge Cases

### HTTP Status Codes

| Code | Meaning | Frontend Action |
|------|---------|----------------|
| 200 | Success | Display data |
| 201 | Created | Display success + data |
| 400 | Bad Request | Show field-level validation errors |
| 401 | Unauthorized | Try token refresh → if fails, redirect to login |
| 403 | Forbidden | Show "Access denied" / banned screen |
| 404 | Not Found | Show "Not found" state |
| 409 | Conflict | Show "Already exists" message |
| 429 | Rate Limit | Show countdown timer (OTP: 60s) |
| 500 | Server Error | Show generic error + retry button |

### Token Expiry Flow

```
1. API call returns 401
2. Intercept in HTTP client
3. Call POST /auth/refresh-token with stored refreshToken
4. If 200 → store new tokens, retry original request
5. If 401 → token fully expired, navigate to login
6. Queue concurrent requests during refresh (don't fire multiple refreshes)
```

### Offline States

```
- No internet → Show offline banner + cached content
- API timeout → Show retry button
- Partial load → Show skeleton + retry failed sections
```

### Empty States (design each one)

```
- No content in feed → "Set your objectives to get personalized recommendations"
- No quizzes available → "Keep learning! Quizzes appear after consuming content"
- No journey → "Create your learning journey to get a personalized plan"
- No knowledge profile → "Complete quizzes to build your knowledge profile"
- No followers → "Follow creators and learners to build your community"
- No playlists → "Create playlists to organize your learning"
- No search results → "No results found. Try different keywords"
```

---

## 19. Push Notifications

### Setup

```
Store FCM token:
API: PUT /api/v1/users/me
Body: { fcmToken: "firebase_token", deviceType: "ios" }
```

### Notification Types

| Type | Trigger | Title | Body | Deep Link |
|------|---------|-------|------|-----------|
| Quiz Ready | Quiz generated | "Quiz Ready!" | "Your {topic} quiz is waiting" | /quizzes/{id} |
| Journey Update | Journey adaptation | "Journey Updated" | "Your plan has been adjusted" | /journey |
| Milestone | Milestone reached | "Milestone!" | "You completed {milestone}" | /journey/milestones |
| Streak Reminder | No activity today | "Don't break your streak!" | "You have a {n}-day streak" | /home |
| New Content | Creator publishes | "New from {creator}" | "{title} is now available" | /content/{id} |

---

## 20. Offline & Caching Strategy

### Cache Layers

```
1. Memory cache: Active session data (user profile, current journey)
2. Disk cache: Content metadata, thumbnails, last feed state
3. Keychain: Tokens only
```

### Cache Policy

| Data | Cache Duration | Strategy |
|------|---------------|----------|
| User profile | 5 min | Cache-then-network |
| Dashboard | 2 min | Cache-then-network |
| Feed | 5 min | Cache-then-network |
| Content detail | 30 min | Cache-first |
| Knowledge profile | 5 min | Cache-then-network |
| Journey | 5 min | Cache-then-network |
| Static enums | Forever | Cache-first |

### Progress Tracking Offline

```
- Store progress updates locally
- Sync when back online (batch PUT /progress)
- Show last-known progress from local cache
```

---

## 21. Analytics Events

Track these events for product analytics:

### Core Events

```
// Auth
user_registered        { method: "email|google|phone" }
user_logged_in         { method: "email|google|phone" }
onboarding_step_completed { step: 1-6 }
onboarding_completed   {}

// Content
content_viewed         { contentId, contentType, domain, sourceType }
content_started        { contentId, resumePosition }
content_completed      { contentId, totalTime, domain }
content_liked          { contentId, liked: true/false }
content_saved          { contentId, saved: true/false }
content_rated          { contentId, rating: 1-5 }
content_shared         { contentId, method }
content_comment_added  { contentId }

// Quiz
quiz_started           { quizId, type, topic }
quiz_answer_submitted  { quizId, questionIndex, timeTaken }
quiz_completed         { quizId, score, percentage, type }
quiz_requested         { topic }

// Journey
journey_generated      { objectiveId }
journey_paused         {}
journey_resumed        {}
daily_plan_completed   { weekNumber, day }
milestone_completed    { milestoneType, title }

// Social
user_followed          { followingId }
user_unfollowed        { followingId }
playlist_created       { playlistId }
playlist_item_added    { playlistId, contentId }
learning_path_followed { pathId }

// Navigation
tab_switched           { tab: "home|discover|journey|progress|profile" }
screen_viewed          { screenName }
search_performed       { query, filters, resultCount }

// Creator
creator_application_submitted { domain }
content_uploaded       { contentType }
content_published      { contentId }
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

| Domain | Topics | Videos Seeded |
|--------|--------|---------------|
| Product Management | product strategy, roadmapping, user research, prioritization, metrics, product-market fit | 12 |
| Entrepreneurship | startup, fundraising, business model, leadership | 12 |
| SAT Preparation | sat math, sat reading, sat writing, test strategy | 10 |
| Business Soft Skills | communication, negotiation, public speaking, emotional intelligence, leadership | 12 |
| Marketing | digital marketing, branding, content marketing, growth hacking | 12 |
| MBA Preparation | case study, finance basics, strategy, operations management | 12 |

---

## Appendix C: Recommendation Engine Scoring (for frontend context)

The feed is **not** chronological. Every content item has a **recommendation score (0-100)** computed from:

| Factor | Weight | What It Does |
|--------|--------|-------------|
| Topic Relevance | 40 pts | Matches user's objectives (primary = 70%, secondaries = 30%) |
| Difficulty Match | 20 pts | Calibrated to user's knowledge level |
| Quality Score | 15 pts | AI-assessed content quality (0-100 normalized) |
| Social Proof | 10 pts | Likes, saves, ratings from other users |
| Recency | 5 pts | Newer content scores higher |
| Diversity Penalty | -5 pts | Prevents single-topic domination |
| Gap Bonus | +10 pts | Boosts content for weak topics |

**Source fairness:** Feed alternates between YouTube and original creator content (50/50).

**Cold start:** New users with no consumption history get a simplified feed based on onboarding data.

The `_recommendationScore` field is returned on feed items but **should not be shown to users**. It exists for debugging and A/B testing.

---

*End of Document. This is the single source of truth for all frontend development on ScaleUp.*
