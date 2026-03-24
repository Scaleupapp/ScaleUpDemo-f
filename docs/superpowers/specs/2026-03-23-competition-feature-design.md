# Competition Feature — Phase 1 Design Spec

**Date**: 2026-03-23
**Status**: Draft
**Goal**: Add daily challenges, weekly leaderboards, personal bests, and share cards to drive retention, viral growth, and learning effectiveness.

---

## Context

ScaleUp is a pre-launch (<100 users) AI-powered learning platform with quiz generation, knowledge profiles, readiness scores, streaks, and learning journeys. There is no existing competition or leaderboard feature. The platform targets Indian learners (IST timezone).

### Goals (ordered by priority)
1. **Retention** — Users open the app daily to not lose rank/streak position
2. **Viral growth** — Users invite friends to compete, driving sign-ups
3. **Learning effectiveness** — Competition makes users study harder and score better

### Design Decisions
- Competition surfaces are woven into existing tabs (Home, Progress, Quiz flow) — no new tab
- Handicapped scoring rewards growth at every level
- Daily + weekly competitive cycles (daily habit feeds weekly payoff)
- Multiple share formats (score card, rank, challenge invite)
- Graceful empty-room handling: personal bests → percentile → raw ranks as user base grows
- **Separation principle**: Competition reads from the learning system but never writes back. Scores do not update KnowledgeProfile or objective competencies.

---

## 1. Data Model

### New Models

#### DailyChallenge
```
topic: String (required, indexed)
date: Date (required, indexed, one per topic per day)
questions: [ChallengeQuestion] (exactly 10)
  - questionText: String
  - questionType: String (recall | application | conceptual | critical_thinking)
  - options: [{ label: String (A/B/C/D), text: String }]
  - correctAnswer: String (A/B/C/D)
  - explanation: String
  - difficulty: String (easy | medium | hard)
  - concept: String
difficulty: String (mixed — always mixed for fairness)
status: String (draft | approved | active | closed)
participantCount: Number (denormalized, default 0)
createdFrom: ObjectId (ref: ChallengeCandidateBank)
activatesAt: Date (midnight IST of `date`)
closesAt: Date (23:59:59 IST of `date`)
```

#### ChallengeAttempt
```
userId: ObjectId (ref: User, required, indexed)
challengeId: ObjectId (ref: DailyChallenge, required, indexed)
answers: [{
  questionIndex: Number
  selectedAnswer: String (A/B/C/D)
  timeSpent: Number (seconds for this question)
  answeredAt: Date
}]
rawScore: Number (0-100, percentage correct)
handicappedScore: Number (adjusted score)
timeTaken: Number (total seconds)
isPersonalBest: Boolean
completedAt: Date
questionOrder: [Number] (shuffled question indices for this user)
optionOrders: [[String]] (shuffled option labels per question, e.g., [["C","A","D","B"], ...])
```
**Unique constraint**: `(userId, challengeId)` — one attempt per user per challenge.

#### ChallengeCandidateBank
```
topic: String (required)
weekOf: Date (Monday of the target week)
candidates: [ChallengeQuestion] (~100 questions)
status: String (pending_review | curated | used)
generatedAt: Date
curatedBy: ObjectId (ref: User, admin who approved)
curatedAt: Date
approvedQuestions: [{
  date: Date (which day this question is assigned to)
  questionIndex: Number (index into candidates array)
}]
```

#### WeeklyLeaderboard
```
topic: String ("global" for combined board, or specific topic)
weekStart: Date (Monday 00:00 IST)
weekEnd: Date (Sunday 23:59:59 IST)
entries: [{
  userId: ObjectId (ref: User)
  totalHandicappedScore: Number
  challengesCompleted: Number (out of 7)
  bestDayScore: Number
  rank: Number (calculated on finalization)
  percentile: Number (0-100)
}]
finalized: Boolean (locked after week ends)
participantCount: Number
```

#### LiveEvent
```
topic: String (required, indexed)
scheduledAt: Date (required — Mon/Wed/Fri 8:00 PM IST)
questions: [ChallengeQuestion] (10 questions — separate from daily challenge)
status: String (scheduled | lobby | live | completed)
participantCount: Number (denormalized, users who joined lobby)
startedAt: Date (actual start time)
completedAt: Date
duration: Number (total event duration in seconds)
leaderboard: [{
  userId: ObjectId (ref: User)
  handicappedScore: Number
  rawScore: Number
  timeTaken: Number
  rank: Number
  completedAt: Date
}]
```

#### LiveEventAttempt
```
userId: ObjectId (ref: User, required, indexed)
eventId: ObjectId (ref: LiveEvent, required, indexed)
answers: [{
  questionIndex: Number
  selectedAnswer: String (A/B/C/D)
  timeSpent: Number (seconds)
  answeredAt: Date
}]
rawScore: Number (0-100)
handicappedScore: Number
timeTaken: Number (total seconds)
rank: Number (assigned after event completes)
completedAt: Date
questionOrder: [Number]
optionOrders: [[String]]
```
**Unique constraint**: `(userId, eventId)` — one attempt per user per event.

#### CompetitionProfile (subdocument on User or standalone)
```
userId: ObjectId (ref: User, unique)
personalBests: Map<String, {  // keyed by topic
  bestDailyScore: Number
  bestDailyDate: Date
  bestWeeklyScore: Number
  bestWeeklyWeekStart: Date
}>
totalChallengesCompleted: Number (lifetime)
currentChallengeStreak: Number (consecutive days)
longestChallengeStreak: Number
titlesEarned: [{
  title: String (e.g., "Finance Weekly Champion — Mar 2026")
  earnedAt: Date
  topic: String
}]
```

### Interaction with Existing Models

| Existing Model | Relationship | Direction |
|---|---|---|
| KnowledgeProfile | Read `topicMastery.level` for handicap calculation | Read-only |
| UserObjective | Read active objective topics for carousel ordering | Read-only |
| Quiz / QuizAttempt | No relationship — separate flow entirely | None |
| User | CompetitionProfile added as ref or subdocument | Extended |
| Journey | No relationship — challenge does not count as journey progress | None |
| Streak (learning) | Separate from competition streak — two independent streaks | None |

### Nudge System (non-automatic)
- If user scores 90%+ on challenges for a topic where they're marked "beginner" for 3+ consecutive days → surface suggestion: "You're crushing {topic} challenges — take a skill assessment to update your level?"
- If user has an active objective → show "Your PM journey is going well — try today's challenge!" nudge on Home

---

## 2. Challenge Generation & Curation Pipeline

### Weekly Batch Generation
**Cron**: Sunday 23:00 IST

For each active topic (topics where ≥1 user has mastery data):
1. Call GPT-4o with `CHALLENGE_GENERATION_PROMPT` to generate **130 candidate questions** per topic in batches of 20 (100 for daily challenges = 10/day × 7 days + 30 surplus, plus 30 for live events = 10/event × 3 events/week)
2. Questions are standardized: clear single correct answer, no ambiguity, fair for all levels
3. Difficulty mix: 30% easy, 40% medium, 30% hard
4. Store as `ChallengeCandidateBank` with `status: pending_review`
5. Daily and live event questions are drawn from the same bank but **never overlap** — curation assigns each question to either a daily challenge date or a live event date

### CHALLENGE_GENERATION_PROMPT
```
You are an expert educational assessment creator specializing in standardized competitive quizzes.

Generate questions for a daily learning challenge. These questions will be the SAME for all participants regardless of their skill level, so they must be:
1. Unambiguous — exactly one clearly correct answer
2. Self-contained — no external context needed
3. Fair — testable through reasoning, not obscure memorization
4. Varied — mix of recall, application, and conceptual questions
5. Exactly 4 options (A, B, C, D)

Difficulty distribution: 30% easy, 40% medium, 30% hard.

Return valid JSON with a "questions" array where each question has:
- questionText, questionType (recall | application | conceptual | critical_thinking),
  options (array of {label, text}), correctAnswer (A/B/C/D),
  explanation, difficulty (easy | medium | hard), concept
```

### Curation Flow
Admin endpoints for reviewing and approving candidates:
- `GET /api/v1/admin/challenge-candidates?week=2026-03-23` — list candidate banks
- `PUT /api/v1/admin/challenge-candidates/:id/approve` — approve questions, assign to dates

**Auto-assign fallback**: If no curation by 23:00 IST the night before, system auto-picks 10 questions from the candidate pool: 3 easy, 4 medium, 3 hard, no duplicate concepts.

### Daily Activation
**Cron**: Daily 00:00 IST
1. Create `DailyChallenge` from approved/auto-assigned questions for today
2. Set `status: active`, close yesterday's challenge (`status: closed`)
3. Push notification: "Today's {topic} Challenge is live! ⚡"
4. Calculate and finalize previous day's rankings (speed bonuses require all attempts)

### Timezone
Fixed **IST (UTC+5:30)**. Daily window: 00:00 IST to 23:59:59 IST. All users get the same absolute window.

---

## 3. Handicapped Scoring

### Formula
```
rawScore = (correctAnswers / totalQuestions) × 100

questionDifficultyScore = average(per-question weight)
  easy = 0.8, medium = 1.0, hard = 1.3

levelBonus (from KnowledgeProfile.topicMastery.level):
  beginner     = 1.20  (+20%)
  intermediate = 1.10  (+10%)
  advanced     = 1.00  (no bonus)
  expert       = 0.95  (-5%)

speedBonus (0 to 0.10):
  Calculated post-hoc after challenge closes.
  Based on user's avg time per question vs median of all participants.
  Faster than median = up to +10%, slower = 0%.

handicappedScore = rawScore × questionDifficultyScore × levelBonus + (speedBonus × 10)
```

### Example Scenarios

| User | Level | Raw | Difficulty Avg | Level Bonus | Speed Bonus | Final |
|------|-------|-----|---------------|-------------|-------------|-------|
| Beginner Rahul | beginner | 70% | 1.0 | 1.20 | 0.05 | 84.5 |
| Intermediate Priya | intermediate | 80% | 1.0 | 1.10 | 0.03 | 88.3 |
| Expert Arjun | expert | 85% | 1.0 | 0.95 | 0.08 | 81.6 |

A beginner improving fast can outscore a coasting expert. Growth is rewarded.

### Anti-Gaming & Anti-Cheating Protections
- **One attempt per challenge per user** — no retakes
- **Question order randomized** per user
- **Option order randomized** per user (A/B/C/D shuffled)
- **Tiered time caps per question** — Easy: 20s, Medium: 35s, Hard: 45s. Too fast for screenshot → ChatGPT → answer round-trip.
- **App background detection** — If user leaves the app (switches to ChatGPT, camera, etc.), auto-submit current question as wrong and advance to next. iOS `scenePhase` / `UIApplication.didEnterBackgroundNotification` triggers this.
- **Speed-weighted scoring** — Answers in <10s get maximum speed credit. 10-20s normal. 20s+ diminishing. Someone using AI assistance consistently answers 30-40s (screenshot + AI latency), tanking their speed score.
- **Speed bonus calculated post-hoc** — can't game it by knowing the median
- **No back button** — can't revisit previous questions

---

## 4. Weekly Leaderboard & Personal Bests

### Weekly Aggregation
Window: Monday 00:00 IST → Sunday 23:59:59 IST

**Weekly score** = sum of daily handicapped scores. Missed days = 0 points (no penalty beyond missing points).

### Two Board Types
- **Global board** — all users, all topics pooled. Primary board (always active).
- **Per-topic boards** — activated when a topic has 50+ weekly participants. Below threshold, topic doesn't get its own board.

### Leaderboard Entry Fields
- Rank (shown only when 20+ participants)
- Percentile (always shown)
- Challenges completed this week (out of 7)
- Total weekly handicapped score
- Trend arrow (↑↓→ vs last week)

### Empty Room Thresholds

| Weekly Active Users | What They See |
|---|---|
| 1-9 | Personal bests only. "Beat your best score." Global board exists but no rank/percentile. |
| 10-19 | Global board with percentiles. "Top 30% this week." No raw rank numbers. |
| 20+ | Global board with rank + percentile. "#7 of 34 — Top 21%." |
| 50+ per topic | Per-topic boards unlock alongside global. |

### Weekly Finalization
**Cron**: Monday 00:30 IST
1. Lock previous week's leaderboard (`finalized: true`)
2. Calculate final ranks and percentiles
3. Award title to #1: "{Topic} Weekly Champion — {Month Year}"
4. Push notification to top 3: "You finished #{rank} in {topic} this week!"
5. Push notification to all participants: "Your weekly results are in — Top {percentile}%"

### Personal Bests
Tracked per topic on CompetitionProfile:
- **Best daily score** — highest handicapped score ever on a single challenge
- **Best weekly score** — highest weekly total
- **Best streak** — most consecutive days completing a challenge
- **Improvement rate** — rolling 4-week trend of weekly scores

Notification on new personal best: "New personal best! You scored {score} in {topic} — up from {previous}"

---

## 5. iOS Integration — Where Competition Surfaces

No new tab. Competition weaves into three existing surfaces.

### Home Tab

#### Daily Challenge Carousel (swipeable cards)
- Position: below header, above content feed
- **Swipeable horizontal carousel** with page dots
- Each card: compact, LIVE badge, topic name, question count, participant count, "Challenge →" CTA
- **Objective topics appear first** in carousel (with subtle "Your Goal" indicator)
- Other active topics follow after
- Gold accent border for untaken challenges, green for completed
- Completed cards show: score, percentile, personal best badge, Share/View Board CTAs

#### Weekly Summary Card
- Appears Monday after finalization, above the carousel
- Shows: rank/percentile, challenges completed, vs prior week trend
- Dismissable

### Progress Tab

#### Competition Stats Strip
Horizontally scrolling chips (matching existing Progress tab style):
- "{N}-Day Streak 🔥"
- "Top {X}% This Week"
- "{N}/7 Challenges Done"
- "Best: {score} ({topic abbrev})"

#### Weekly Leaderboard Preview Card
- Your highlighted row (avatar, name, score, rank)
- Top 3 rows (gold/silver/bronze accent)
- "See Full Board →" link

#### Full Leaderboard View (pushed navigation)
- Segmented control: Global / per-topic (when available)
- Tab bar: This Week / Last Week / All Time
- Your row pinned at top with "You" label
- Each row: rank, avatar, name, handicapped score, challenges completed, trend arrow
- Pull to refresh

### Quiz Flow — Challenge Mode

#### Pre-Challenge Screen
- Topic, date, rules ("10 questions, 20-45s each, one attempt")
- Personal best for this topic (if exists)
- "Begin Challenge" CTA

#### During Challenge
- Reuses `QuizSessionView` layout with modifications:
  - No skip button
  - Tiered timer per question: Easy 20s, Medium 35s, Hard 45s (auto-submit on expiry = wrong)
  - App background detection: leaving the app auto-submits current question as wrong
  - No back button
  - Gold accent on timer bar
  - Question counter: "Q 4/10"

#### Post-Challenge Results
- Animated handicapped score reveal with breakdown tooltip
- Personal best comparison
- Live rank / percentile
- Question review (expandable)
- Three CTAs: Share Score / View Leaderboard / Done

---

## 6. Share System

### Share Formats

#### Score Card (image)
Designed for Instagram stories, WhatsApp:
- ScaleUp branding
- Date, topic
- Gold ring with score
- Percentile, accuracy
- Personal best badge (if applicable)
- "Can you beat my score? →" CTA
- App link

#### Challenge Invite (deep link)
"I scored 88.3 on today's PM challenge. Beat me! scaleup.app/challenge/{challengeId}"
- Recipient opens app → taken directly to the same daily challenge
- If not a user → app store → onboard → challenge

#### Copy Score (plain text)
"I scored 88.3 (Top 15%) on today's Product Management challenge on ScaleUp! 🏆"

---

## 7. Backend API Endpoints

### Competition Routes (`/api/v1/competition/`)

```
GET  /challenges/today              → today's active challenges (all topics)
GET  /challenges/:id                → single challenge details
POST /challenges/:id/start          → begin attempt (creates ChallengeAttempt, returns questions with randomized order)
PUT  /challenges/:id/answer         → submit single answer with timestamp
POST /challenges/:id/complete       → finish attempt, calculate handicapped score, check personal best
GET  /challenges/:id/results        → results + current ranking + personal best comparison

GET  /leaderboard/weekly            → current week (global by default, ?topic=X for topic-specific)
GET  /leaderboard/weekly/:weekStart → historical week
GET  /leaderboard/alltime           → all-time rankings (?topic=X optional)

GET  /profile                       → CompetitionProfile (personal bests, streaks, titles)
GET  /stats                         → stats strip data (streak, percentile, challenges done this week)
```

### Admin Routes (`/api/v1/admin/competition/`)

```
GET  /challenge-candidates           → candidate banks for curation (?week=YYYY-MM-DD)
PUT  /challenge-candidates/:id       → approve questions, assign to dates
POST /challenges/generate            → manually trigger generation for a topic/week
```

### Cron Jobs

| Schedule (IST) | Job | Description |
|---|---|---|
| Sunday 23:00 | `generateChallengeCandidates` | AI generates 100 candidates per active topic |
| Daily 00:00 | `activateDailyChallenge` | Create today's challenge, close yesterday's, send push |
| Daily 00:30 | `finalizeDailyRankings` | Calculate speed bonuses, finalize daily ranks |
| Monday 00:30 | `finalizeWeeklyLeaderboard` | Lock weekly board, calculate percentiles, award titles, send notifications |
| Daily 21:00 | `streakReminderNotification` | Remind users who haven't taken today's challenge |

---

## 8. Push Notifications

| Trigger | Title | Body | Timing |
|---|---|---|---|
| Challenge goes live | "Today's Challenge is Live! ⚡" | "Test your {topic} skills — {count} others already playing" | 00:00 IST |
| Challenge completed | "Nice! You scored {score}" | "You're in the Top {percentile}% for {topic} today" | Immediate |
| New personal best | "New Personal Best! 🏆" | "{score} in {topic} — up from {previous}" | Immediate |
| Weekly results | "Your Week in Review 📊" | "Top {percentile}% — {completed}/7 challenges done" | Monday 08:00 IST |
| Friend via invite | "{name} beat your challenge!" | "They scored {score} on today's {topic} challenge" | Immediate |
| Streak at risk | "Don't lose your streak! 🔥" | "{streak} days straight — today's {topic} challenge is waiting" | 21:00 IST |

---

## 9. Learning System Integration

### Separation Principle
Competition is a **read-only consumer** of the learning system. It never writes back.

| Aspect | Competition → Learning | Learning → Competition |
|---|---|---|
| Score impact | None (does not update KnowledgeProfile) | Mastery level sets handicap bonus |
| Journey progress | None (does not count as journey activity) | No dependency |
| Topic visibility | All topics visible, objective topics prioritized first | Active objective determines carousel order |
| Streak | Separate competition streak | Separate learning streak |
| Nudges only | "Crushing {topic} challenges — take a skill assessment?" | "Journey going well — try today's challenge!" |

### Two Independent Streaks
- **Learning streak**: consecutive days with content completion OR quiz completion (existing)
- **Competition streak**: consecutive days with a daily challenge completed (new)

Both displayed separately. A user doing only challenges is not "learning" and vice versa.

---

## 10. Live Events

### Overview
Mon/Wed/Fri at 8:00 PM IST — a scheduled live quiz event. Separate question set from the daily challenge (users can do both). Strict start — miss 8:00 PM, you miss the event entirely. Creates "appointment TV" urgency on top of the daily async challenge.

### Schedule
- **Days**: Monday, Wednesday, Friday
- **Time**: 8:00 PM IST (14:30 UTC)
- **Duration**: ~8-12 minutes (10 questions with tiered timers + lobby)
- **Topic**: Rotates across active topics. Schedule announced in advance (e.g., Mon=PM, Wed=Finance, Fri=Data Science)

### Event Lifecycle

#### 1. Scheduled (created by cron)
- `LiveEvent` record created with `status: scheduled`
- Questions pre-assigned from the candidate bank (separate pool from daily)
- Push notification at 7:30 PM IST: "Live Event in 30 minutes! {topic} — be there at 8 PM"

#### 2. Lobby (7:55 PM - 8:00 PM)
- 5-minute lobby opens at 7:55 PM
- `status: lobby`
- Users enter the lobby screen — see participant count rising, topic, countdown timer
- Push notification at 7:55 PM: "Lobby is open! {count} players waiting for tonight's {topic} event"
- **Strict cutoff**: At 8:00 PM, lobby closes. No new entrants after this point.

#### 3. Live (8:00 PM)
- `status: live`
- All participants receive Question 1 simultaneously
- Same tiered timers as daily challenge (Easy 20s, Medium 35s, Hard 45s)
- Same anti-cheating: background detection, randomized order, no back button
- **Real-time progress**: After each question, show:
  - Your answer (correct/wrong)
  - How many got it right (percentage)
  - Your current position (rank among participants)
- Questions advance on a **fixed timer** — everyone moves to the next question at the same time, regardless of when they answered. This keeps everyone in sync.
  - If timer expires before answering: auto-submit as wrong
  - If answered early: wait screen until timer advances everyone

#### 4. Completed
- `status: completed`
- Final leaderboard revealed with animation
- Top 3 highlighted (gold/silver/bronze)
- Your rank, score, and question-by-question breakdown
- "Share Results" with special live event share card
- Same handicapped scoring as daily challenges

### iOS Integration

#### Home Tab — Live Event Card
- Appears in the challenge carousel but with distinct styling:
  - Purple/violet gradient border (vs gold for daily challenges)
  - "LIVE EVENT" badge instead of "LIVE"
  - Countdown timer: "Starts in 2h 34m" or "Lobby Open — Join Now!"
  - After event: "Completed — You finished #4" with green border
- Takes priority position in carousel (appears first, before daily challenges)

#### Live Event Screens

**Lobby Screen** (pushed from card):
- Topic name, participant count (updating in real-time)
- Countdown: "Starting in 3:42"
- Participant avatars scrolling in (like a waiting room)
- Rules reminder: "10 questions, strict timer, no going back"
- "Leave Lobby" option

**Live Quiz Screen**:
- Similar to challenge mode but with additions:
  - "LIVE" indicator with pulse animation
  - Participant count: "47 playing"
  - After each question: brief results overlay (2-3s) showing correct %, your rank so far
  - Synced question timer (everyone sees same countdown)

**Results Screen**:
- Full leaderboard (all participants)
- Your highlighted row
- Question-by-question review
- "Share Live Results" — special share card with "LIVE EVENT" branding
- "Next Live Event: Wednesday 8 PM — Finance"

### Backend — Live Event Specifics

#### API Endpoints (under `/api/v1/competition/`)
```
GET  /live-events/upcoming        → next scheduled live events
GET  /live-events/:id             → event details + status
POST /live-events/:id/join        → join lobby (only during lobby phase)
GET  /live-events/:id/lobby       → lobby state (participant count, countdown)
POST /live-events/:id/start       → (system only) transitions from lobby to live
GET  /live-events/:id/question    → current question for the event (synced by server time)
PUT  /live-events/:id/answer      → submit answer for current question
GET  /live-events/:id/results     → final results + leaderboard
GET  /live-events/:id/question-results → after each question: correct %, your rank
```

#### Cron Jobs (additions)
| Schedule (IST) | Job | Description |
|---|---|---|
| Mon/Wed/Fri 19:30 | `liveEventReminder` | Push notification: "Live event in 30 minutes" |
| Mon/Wed/Fri 19:55 | `openLiveEventLobby` | Set event status to `lobby`, send "lobby open" push |
| Mon/Wed/Fri 20:00 | `startLiveEvent` | Close lobby, set status to `live`, begin question sequence |

#### Real-Time Communication
- **Polling-based** (not WebSocket) for Phase 1 — simpler, works with existing Express stack
- Lobby: poll `/lobby` every 3s for participant count
- During event: poll `/question` every 2s for current question + timer state
- After each question: poll `/question-results` for correct % and rank
- **Phase 2 upgrade path**: Replace polling with Socket.IO/WebSocket for true real-time feel

#### Question Synchronization
- Server is the source of truth for timing
- Each question has a `startsAt` and `endsAt` timestamp (calculated from event start + cumulative timer)
- Client requests current question → server returns the question active at `now()`
- If client is slightly behind (network lag), they get less time on that question — acceptable tradeoff for simplicity

### Push Notifications (additions)

| Trigger | Title | Body | Timing |
|---|---|---|---|
| 30min before event | "Live Event Tonight! 🎯" | "{topic} starts at 8 PM — don't miss it!" | 19:30 IST |
| Lobby opens | "Lobby is Open! 🏟️" | "{count} players waiting — join now before it starts" | 19:55 IST |
| Event completed | "Live Event Results! 🏆" | "You finished #{rank} out of {total} in {topic}" | Immediate |
| Missed event (was active in last 24h) | "You Missed Tonight's Event 😢" | "{total} players competed in {topic} — next one is {nextDay}" | 20:30 IST |

### Live Event vs Daily Challenge Comparison

| Aspect | Daily Challenge | Live Event |
|---|---|---|
| Frequency | Every day | Mon/Wed/Fri |
| Time window | All day (midnight to midnight IST) | Strict 8:00 PM start, ~10 min |
| Question set | Separate pool | Separate pool (neither shares with the other) |
| Entry | Anytime during the day | Must join lobby by 8:00 PM |
| Experience | Solo, async | Synchronized, see others' progress |
| Scoring | Same handicapped formula | Same handicapped formula |
| Leaderboard | Daily + weekly rollup | Per-event only (does NOT feed into weekly board) |
| Weekly board impact | Yes — daily scores sum into weekly | No — live events are bonus, standalone |
| Share card | Gold theme | Purple/violet "LIVE EVENT" theme |

---

## 11. Technical Considerations

### Question Randomization
When `/challenges/:id/start` is called:
- Generate a per-user random seed from `hash(userId + challengeId)`
- Use seed to shuffle question order and option order
- Store the mapping on `ChallengeAttempt` so answers can be correctly evaluated
- Same user retrying the endpoint gets the same shuffle (idempotent)

### Scoring Timing
- `rawScore` and partial `handicappedScore` (without speed bonus) calculated immediately on `/complete`
- `speedBonus` calculated by the daily 00:30 IST cron after all attempts are in
- Until speed bonus is applied, show "Score: 84.0 (final speed bonus pending)" on results

### Participant Count
- Denormalized on `DailyChallenge.participantCount`
- Incremented atomically on `/challenges/:id/start` (not `/complete`, so "23 playing" includes in-progress)
- Used for display only, not for scoring

### All-Time Leaderboard
- Computed on-the-fly by aggregating `WeeklyLeaderboard` entries — no separate model
- Query: group by userId across all finalized weekly boards, sum totalHandicappedScore
- Cache result in Redis with 1-hour TTL (invalidated on weekly finalization)

### Speed Bonus Edge Case
- Minimum 3 participants required for speed bonus calculation
- Below 3 participants: speed bonus = 0 for everyone (raw handicapped score only)

### Share Card Image Generation
- Generated client-side using SwiftUI snapshot rendering (no server dependency)
- SwiftUI view renders the score card → `ImageRenderer` produces a `UIImage` → shared via `UIActivityViewController`

### Push Notification Infrastructure
- Push notifications already exist in the platform (FCM tokens on User model, `notificationQueue` in BullMQ)
- Competition notifications use the same `notificationQueue.add('send', {...})` pattern as existing quiz notifications

### Deep Links for Sharing
- Format: `scaleup.app/challenge/{challengeId}`
- Universal link → iOS app if installed, App Store if not
- On open: if challenge is still active and user hasn't attempted → navigate to pre-challenge screen
- If challenge is closed → show results / "This challenge has ended"

---

## 12. UI Card Design

### Daily Challenge Card (Swipeable Carousel)
- Style: compact card, dark background (#111), rounded corners (16px)
- LIVE badge: gold background pill, top-right
- Trophy emoji as visual anchor
- Topic name: 16px bold white
- Meta line: "10 Qs · {count} playing · Ends midnight" in 12px gray
- CTA: gold gradient "Challenge →" button (primary topic) or gold outline (secondary topics)
- Page dots below carousel
- Objective-linked topics appear first with optional "Your Goal" micro-badge

### Completed Card
- Border changes to green (#22c55e)
- "✓ Completed" badge replaces "LIVE"
- Stats bar: Score (gold) | Rank/Percentile (white) | Accuracy (white)
- "🏆 New Best!" badge when applicable
- CTAs: Share Score (gold fill) | View Board (outline) | Link icon (outline)

### Live Event Card (in carousel)
- Style: compact card, dark background (#111), rounded corners (16px)
- **Purple/violet gradient border** (distinct from gold daily challenge)
- "LIVE EVENT" badge: purple background pill, top-right
- Trophy emoji as visual anchor
- Topic name: 16px bold white
- Countdown: "Starts in 2h 34m" or "Lobby Open!" in purple accent
- CTA: purple gradient "Join →" button
- Takes first position in carousel (before daily challenges)
- After completion: green border, "You finished #4" result

### Share Card (generated image)
- Dark gradient background with gold accents
- ScaleUp wordmark at top
- Date + topic
- Gold-bordered circle with score
- Percentile + accuracy text
- Personal best badge
- "Can you beat my score? →" CTA
- App URL at bottom
