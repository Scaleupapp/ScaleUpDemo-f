# Competition Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add daily challenges, weekly leaderboards, live events, personal bests, and share cards to the ScaleUp learning platform.

**Architecture:** Backend adds new Mongoose models, Express routes, BullMQ workers, and cron jobs. iOS adds a new Competition feature module (service, models, views, viewmodels) woven into existing Home, Progress, and Quiz flows. Competition reads from the learning system (KnowledgeProfile) but never writes back.

**Tech Stack:** Express.js, MongoDB/Mongoose, BullMQ/Redis, OpenAI GPT-4o (backend); SwiftUI, @Observable, actor-based services (iOS)

**Spec:** `docs/superpowers/specs/2026-03-23-competition-feature-design.md`

---

## File Map

### Backend — New Files
| File | Responsibility |
|------|---------------|
| `src/models/DailyChallenge.js` | Daily challenge schema (questions, status, date, topic) |
| `src/models/ChallengeAttempt.js` | User attempt on a daily challenge (answers, scores, randomization) |
| `src/models/ChallengeCandidateBank.js` | Weekly AI-generated candidate question pool |
| `src/models/WeeklyLeaderboard.js` | Weekly leaderboard entries per topic + global |
| `src/models/CompetitionProfile.js` | User's competition stats (personal bests, streaks, titles) |
| `src/models/LiveEvent.js` | Live event schema (scheduled, lobby, live, completed) |
| `src/models/LiveEventAttempt.js` | User attempt on a live event |
| `src/services/competitionService.js` | Challenge lifecycle, scoring, leaderboard calculation |
| `src/services/challengeGenerationService.js` | AI question generation + curation pipeline |
| `src/services/liveEventService.js` | Live event lifecycle (lobby, start, question sync, results) |
| `src/controllers/competitionController.js` | Request handlers for all competition endpoints |
| `src/routes/competition.js` | Route definitions for `/api/v1/competition/` |
| `src/workers/competitionWorker.js` | BullMQ worker for competition cron jobs |

### Backend — Modified Files
| File | Change |
|------|--------|
| `src/app.js` | Mount `/api/v1/competition` route |
| `src/config/queue.js` | Add `competitionQueue` |
| `src/workers/index.js` | Register competition worker |
| `src/workers/cronJobs.js` | Add competition cron schedules |

### iOS — New Files
| File | Responsibility |
|------|---------------|
| `ScaleUp/Models/Competition.swift` | All competition models (DailyChallenge, ChallengeAttempt, etc.) |
| `ScaleUp/Features/Competition/Services/CompetitionService.swift` | Actor-based API service for competition endpoints |
| `ScaleUp/Features/Competition/ViewModels/ChallengeViewModel.swift` | Daily challenge state + quiz session for challenges |
| `ScaleUp/Features/Competition/ViewModels/LeaderboardViewModel.swift` | Leaderboard + stats data |
| `ScaleUp/Features/Competition/ViewModels/LiveEventViewModel.swift` | Live event lobby, sync, results |
| `ScaleUp/Features/Competition/Views/DailyChallengeCarousel.swift` | Swipeable card carousel for Home tab |
| `ScaleUp/Features/Competition/Views/ChallengeSessionView.swift` | Challenge quiz session (reuses patterns from QuizSessionView) |
| `ScaleUp/Features/Competition/Views/ChallengeResultsView.swift` | Post-challenge results with share |
| `ScaleUp/Features/Competition/Views/LeaderboardView.swift` | Full leaderboard view (global/topic, weekly/all-time) |
| `ScaleUp/Features/Competition/Views/CompetitionStatsSection.swift` | Stats strip + leaderboard preview for Progress tab |
| `ScaleUp/Features/Competition/Views/LiveEventLobbyView.swift` | Live event lobby with countdown |
| `ScaleUp/Features/Competition/Views/LiveEventSessionView.swift` | Synchronized live quiz session |
| `ScaleUp/Features/Competition/Views/LiveEventResultsView.swift` | Live event final results |
| `ScaleUp/Features/Competition/Views/ShareScoreCardView.swift` | SwiftUI view for share card image generation |

### iOS — Modified Files
| File | Change |
|------|--------|
| `ScaleUp/Features/Home/Views/HomeView.swift` | Add DailyChallengeCarousel + LiveEvent card + WeeklySummary |
| `ScaleUp/Features/Home/ViewModels/HomeViewModel.swift` | Fetch today's challenges + live events |
| `ScaleUp/Features/Progress/ProgressTabView.swift` | Add CompetitionStatsSection at top |
| `ScaleUp/Features/Progress/ViewModels/ProgressViewModel.swift` | Fetch competition stats |
| `ScaleUp/App/MainTabView.swift` | Add navigation destinations for competition views |

---

## Task Sequence

### Task 1: Backend — Competition Models

**Files:**
- Create: `src/models/DailyChallenge.js`
- Create: `src/models/ChallengeAttempt.js`
- Create: `src/models/ChallengeCandidateBank.js`
- Create: `src/models/WeeklyLeaderboard.js`
- Create: `src/models/CompetitionProfile.js`
- Create: `src/models/LiveEvent.js`
- Create: `src/models/LiveEventAttempt.js`

- [ ] **Step 1: Create DailyChallenge model**

```javascript
// src/models/DailyChallenge.js
const mongoose = require('mongoose');

const challengeQuestionSchema = new mongoose.Schema({
  questionText: { type: String, required: true },
  questionType: {
    type: String,
    enum: ['recall', 'application', 'conceptual', 'critical_thinking'],
    default: 'conceptual',
  },
  options: [{
    label: { type: String, enum: ['A', 'B', 'C', 'D'], required: true },
    text: { type: String, required: true },
  }],
  correctAnswer: { type: String, enum: ['A', 'B', 'C', 'D'], required: true },
  explanation: { type: String },
  difficulty: { type: String, enum: ['easy', 'medium', 'hard'], default: 'medium' },
  concept: { type: String },
}, { _id: true });

const dailyChallengeSchema = new mongoose.Schema({
  topic: { type: String, required: true, index: true },
  date: { type: Date, required: true, index: true },
  questions: { type: [challengeQuestionSchema], validate: [arr => arr.length === 10, 'Must have exactly 10 questions'] },
  status: { type: String, enum: ['draft', 'approved', 'active', 'closed'], default: 'draft' },
  participantCount: { type: Number, default: 0 },
  createdFrom: { type: mongoose.Schema.Types.ObjectId, ref: 'ChallengeCandidateBank' },
  activatesAt: { type: Date },
  closesAt: { type: Date },
}, { timestamps: true });

dailyChallengeSchema.index({ topic: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('DailyChallenge', dailyChallengeSchema);
```

- [ ] **Step 2: Create ChallengeAttempt model**

```javascript
// src/models/ChallengeAttempt.js
const mongoose = require('mongoose');

const challengeAttemptSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  challengeId: { type: mongoose.Schema.Types.ObjectId, ref: 'DailyChallenge', required: true, index: true },
  answers: [{
    questionIndex: { type: Number, required: true },
    selectedAnswer: { type: String, enum: ['A', 'B', 'C', 'D'] },
    timeSpent: { type: Number }, // seconds
    answeredAt: { type: Date },
  }],
  rawScore: { type: Number, min: 0, max: 100 },
  handicappedScore: { type: Number },
  timeTaken: { type: Number }, // total seconds
  isPersonalBest: { type: Boolean, default: false },
  completedAt: { type: Date },
  questionOrder: [{ type: Number }],
  optionOrders: [[{ type: String }]],
}, { timestamps: true });

challengeAttemptSchema.index({ userId: 1, challengeId: 1 }, { unique: true });

module.exports = mongoose.model('ChallengeAttempt', challengeAttemptSchema);
```

- [ ] **Step 3: Create ChallengeCandidateBank model**

```javascript
// src/models/ChallengeCandidateBank.js
const mongoose = require('mongoose');

const candidateBankSchema = new mongoose.Schema({
  topic: { type: String, required: true },
  weekOf: { type: Date, required: true },
  candidates: [{
    questionText: String,
    questionType: { type: String, enum: ['recall', 'application', 'conceptual', 'critical_thinking'] },
    options: [{ label: String, text: String }],
    correctAnswer: { type: String, enum: ['A', 'B', 'C', 'D'] },
    explanation: String,
    difficulty: { type: String, enum: ['easy', 'medium', 'hard'] },
    concept: String,
    assignedTo: { type: String, enum: ['daily', 'live', null], default: null },
    assignedDate: { type: Date },
  }],
  status: { type: String, enum: ['pending_review', 'curated', 'used'], default: 'pending_review' },
  generatedAt: { type: Date, default: Date.now },
  curatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  curatedAt: { type: Date },
}, { timestamps: true });

candidateBankSchema.index({ topic: 1, weekOf: 1 });

module.exports = mongoose.model('ChallengeCandidateBank', candidateBankSchema);
```

- [ ] **Step 4: Create WeeklyLeaderboard model**

```javascript
// src/models/WeeklyLeaderboard.js
const mongoose = require('mongoose');

const leaderboardEntrySchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  totalHandicappedScore: { type: Number, default: 0 },
  challengesCompleted: { type: Number, default: 0 },
  bestDayScore: { type: Number, default: 0 },
  rank: { type: Number },
  percentile: { type: Number },
}, { _id: false });

const weeklyLeaderboardSchema = new mongoose.Schema({
  topic: { type: String, required: true }, // "global" or specific topic
  weekStart: { type: Date, required: true },
  weekEnd: { type: Date, required: true },
  entries: [leaderboardEntrySchema],
  finalized: { type: Boolean, default: false },
  participantCount: { type: Number, default: 0 },
}, { timestamps: true });

weeklyLeaderboardSchema.index({ topic: 1, weekStart: 1 }, { unique: true });

module.exports = mongoose.model('WeeklyLeaderboard', weeklyLeaderboardSchema);
```

- [ ] **Step 5: Create CompetitionProfile model**

```javascript
// src/models/CompetitionProfile.js
const mongoose = require('mongoose');

const personalBestSchema = new mongoose.Schema({
  bestDailyScore: { type: Number, default: 0 },
  bestDailyDate: { type: Date },
  bestWeeklyScore: { type: Number, default: 0 },
  bestWeeklyWeekStart: { type: Date },
}, { _id: false });

const competitionProfileSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true, index: true },
  personalBests: { type: Map, of: personalBestSchema, default: {} },
  totalChallengesCompleted: { type: Number, default: 0 },
  currentChallengeStreak: { type: Number, default: 0 },
  longestChallengeStreak: { type: Number, default: 0 },
  titlesEarned: [{
    title: String,
    earnedAt: Date,
    topic: String,
  }],
}, { timestamps: true });

module.exports = mongoose.model('CompetitionProfile', competitionProfileSchema);
```

- [ ] **Step 6: Create LiveEvent and LiveEventAttempt models**

```javascript
// src/models/LiveEvent.js
const mongoose = require('mongoose');

const liveEventSchema = new mongoose.Schema({
  topic: { type: String, required: true, index: true },
  scheduledAt: { type: Date, required: true, index: true },
  questions: [{
    questionText: String,
    questionType: { type: String, enum: ['recall', 'application', 'conceptual', 'critical_thinking'] },
    options: [{ label: String, text: String }],
    correctAnswer: { type: String, enum: ['A', 'B', 'C', 'D'] },
    explanation: String,
    difficulty: { type: String, enum: ['easy', 'medium', 'hard'] },
    concept: String,
  }],
  status: { type: String, enum: ['scheduled', 'lobby', 'live', 'completed'], default: 'scheduled' },
  participantCount: { type: Number, default: 0 },
  startedAt: { type: Date },
  completedAt: { type: Date },
  duration: { type: Number }, // total seconds
  leaderboard: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    handicappedScore: Number,
    rawScore: Number,
    timeTaken: Number,
    rank: Number,
    completedAt: Date,
  }],
}, { timestamps: true });

module.exports = mongoose.model('LiveEvent', liveEventSchema);
```

```javascript
// src/models/LiveEventAttempt.js
const mongoose = require('mongoose');

const liveEventAttemptSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'LiveEvent', required: true, index: true },
  answers: [{
    questionIndex: Number,
    selectedAnswer: { type: String, enum: ['A', 'B', 'C', 'D'] },
    timeSpent: Number,
    answeredAt: Date,
  }],
  rawScore: { type: Number, min: 0, max: 100 },
  handicappedScore: { type: Number },
  timeTaken: { type: Number },
  rank: { type: Number },
  completedAt: { type: Date },
  questionOrder: [Number],
  optionOrders: [[String]],
}, { timestamps: true });

liveEventAttemptSchema.index({ userId: 1, eventId: 1 }, { unique: true });

module.exports = mongoose.model('LiveEventAttempt', liveEventAttemptSchema);
```

- [ ] **Step 7: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/models/DailyChallenge.js src/models/ChallengeAttempt.js src/models/ChallengeCandidateBank.js src/models/WeeklyLeaderboard.js src/models/CompetitionProfile.js src/models/LiveEvent.js src/models/LiveEventAttempt.js
git commit -m "feat(competition): add data models for challenges, leaderboards, live events"
```

---

### Task 2: Backend — Competition Service (Scoring & Leaderboards)

**Files:**
- Create: `src/services/competitionService.js`

- [ ] **Step 1: Create competition service with scoring logic**

```javascript
// src/services/competitionService.js
const mongoose = require('mongoose');
const crypto = require('crypto');
const DailyChallenge = require('../models/DailyChallenge');
const ChallengeAttempt = require('../models/ChallengeAttempt');
const WeeklyLeaderboard = require('../models/WeeklyLeaderboard');
const CompetitionProfile = require('../models/CompetitionProfile');
const KnowledgeProfile = require('../models/KnowledgeProfile');

const DIFFICULTY_WEIGHTS = { easy: 0.8, medium: 1.0, hard: 1.3 };
const LEVEL_BONUS = { beginner: 1.20, intermediate: 1.10, advanced: 1.00, expert: 0.95 };
const TIERED_TIME_LIMITS = { easy: 20, medium: 35, hard: 45 };

class CompetitionService {

  // --- Randomization ---

  generateQuestionOrder(userId, challengeId, questionCount) {
    const seed = crypto.createHash('sha256').update(`${userId}${challengeId}`).digest('hex');
    const indices = Array.from({ length: questionCount }, (_, i) => i);
    // Fisher-Yates with seeded PRNG
    let seedNum = parseInt(seed.substring(0, 8), 16);
    for (let i = indices.length - 1; i > 0; i--) {
      seedNum = (seedNum * 1103515245 + 12345) & 0x7fffffff;
      const j = seedNum % (i + 1);
      [indices[i], indices[j]] = [indices[j], indices[i]];
    }
    return indices;
  }

  generateOptionOrders(userId, challengeId, questions) {
    const baseSeed = crypto.createHash('sha256').update(`${userId}${challengeId}opts`).digest('hex');
    return questions.map((_, qIdx) => {
      const labels = ['A', 'B', 'C', 'D'];
      let seedNum = parseInt(baseSeed.substring(qIdx * 2, qIdx * 2 + 8), 16);
      for (let i = labels.length - 1; i > 0; i--) {
        seedNum = (seedNum * 1103515245 + 12345) & 0x7fffffff;
        const j = seedNum % (i + 1);
        [labels[i], labels[j]] = [labels[j], labels[i]];
      }
      return labels;
    });
  }

  // --- Scoring ---

  calculateHandicappedScore(rawScore, questions, userLevel) {
    const avgDifficulty = questions.reduce((sum, q) => sum + (DIFFICULTY_WEIGHTS[q.difficulty] || 1.0), 0) / questions.length;
    const levelBonus = LEVEL_BONUS[userLevel] || 1.0;
    return rawScore * avgDifficulty * levelBonus;
  }

  calculateSpeedBonus(userAvgTime, medianTime) {
    if (medianTime <= 0) return 0;
    if (userAvgTime >= medianTime) return 0;
    const ratio = 1 - (userAvgTime / medianTime);
    return Math.min(ratio, 0.10);
  }

  // --- Challenge Lifecycle ---

  async getTodayChallenges() {
    const today = this._todayIST();
    return DailyChallenge.find({ date: today, status: 'active' }).select('-questions.correctAnswer -questions.explanation');
  }

  async getChallengeById(challengeId) {
    return DailyChallenge.findById(challengeId);
  }

  async startChallenge(userId, challengeId) {
    const challenge = await DailyChallenge.findById(challengeId);
    if (!challenge || challenge.status !== 'active') {
      throw new Error('Challenge not available');
    }

    // Check if already attempted
    const existing = await ChallengeAttempt.findOne({ userId, challengeId });
    if (existing) {
      throw new Error('Already attempted this challenge');
    }

    const questionOrder = this.generateQuestionOrder(userId, challengeId, challenge.questions.length);
    const optionOrders = this.generateOptionOrders(userId, challengeId, challenge.questions);

    const attempt = await ChallengeAttempt.create({
      userId, challengeId, questionOrder, optionOrders, answers: [],
    });

    // Increment participant count
    await DailyChallenge.findByIdAndUpdate(challengeId, { $inc: { participantCount: 1 } });

    // Return questions in randomized order with shuffled options, without correct answers
    const randomizedQuestions = questionOrder.map((origIdx, newIdx) => {
      const q = challenge.questions[origIdx];
      const optOrder = optionOrders[newIdx];
      const shuffledOptions = optOrder.map(label => q.options.find(o => o.label === label));
      return {
        questionIndex: newIdx,
        questionText: q.questionText,
        questionType: q.questionType,
        difficulty: q.difficulty,
        concept: q.concept,
        options: shuffledOptions.map((opt, i) => ({ label: ['A', 'B', 'C', 'D'][i], text: opt.text })),
        timeLimit: TIERED_TIME_LIMITS[q.difficulty] || 35,
      };
    });

    return { attemptId: attempt._id, questions: randomizedQuestions };
  }

  async submitAnswer(userId, challengeId, questionIndex, selectedAnswer, timeSpent) {
    const attempt = await ChallengeAttempt.findOne({ userId, challengeId });
    if (!attempt) throw new Error('No active attempt');
    if (attempt.completedAt) throw new Error('Challenge already completed');

    attempt.answers.push({ questionIndex, selectedAnswer, timeSpent, answeredAt: new Date() });
    await attempt.save();
    return { answersSubmitted: attempt.answers.length };
  }

  async completeChallenge(userId, challengeId) {
    const attempt = await ChallengeAttempt.findOne({ userId, challengeId });
    if (!attempt) throw new Error('No active attempt');
    if (attempt.completedAt) throw new Error('Already completed');

    const challenge = await DailyChallenge.findById(challengeId);
    const profile = await KnowledgeProfile.findOne({ userId });
    const topicMastery = profile?.topicMastery?.find(t => t.topic === challenge.topic);
    const userLevel = topicMastery?.level || 'beginner';

    // Calculate raw score by mapping back through randomization
    let correct = 0;
    for (const answer of attempt.answers) {
      const origQuestionIdx = attempt.questionOrder[answer.questionIndex];
      const question = challenge.questions[origQuestionIdx];
      // Map the user's answer back through option shuffling
      const optOrder = attempt.optionOrders[answer.questionIndex];
      const answerIdx = ['A', 'B', 'C', 'D'].indexOf(answer.selectedAnswer);
      const originalLabel = optOrder[answerIdx];
      if (originalLabel === question.correctAnswer) correct++;
    }

    const rawScore = (correct / challenge.questions.length) * 100;
    const handicappedScore = this.calculateHandicappedScore(rawScore, challenge.questions, userLevel);
    const timeTaken = attempt.answers.reduce((sum, a) => sum + (a.timeSpent || 0), 0);

    // Check personal best
    let compProfile = await CompetitionProfile.findOne({ userId });
    if (!compProfile) {
      compProfile = await CompetitionProfile.create({ userId });
    }

    const currentBest = compProfile.personalBests?.get(challenge.topic)?.bestDailyScore || 0;
    const isPersonalBest = handicappedScore > currentBest;

    if (isPersonalBest) {
      compProfile.personalBests.set(challenge.topic, {
        ...(compProfile.personalBests.get(challenge.topic) || {}),
        bestDailyScore: handicappedScore,
        bestDailyDate: new Date(),
      });
    }
    compProfile.totalChallengesCompleted += 1;

    // Update challenge streak
    await this._updateChallengeStreak(compProfile);
    await compProfile.save();

    // Update attempt
    attempt.rawScore = rawScore;
    attempt.handicappedScore = handicappedScore;
    attempt.timeTaken = timeTaken;
    attempt.isPersonalBest = isPersonalBest;
    attempt.completedAt = new Date();
    await attempt.save();

    // Update weekly leaderboard
    await this._updateWeeklyLeaderboard(userId, challenge.topic, handicappedScore);

    return {
      rawScore, handicappedScore, timeTaken, isPersonalBest,
      correct, total: challenge.questions.length,
      previousBest: currentBest,
    };
  }

  // --- Leaderboard ---

  async getWeeklyLeaderboard(topic = 'global', weekStart = null) {
    const ws = weekStart || this._currentWeekStartIST();
    const board = await WeeklyLeaderboard.findOne({ topic, weekStart: ws })
      .populate('entries.userId', 'firstName lastName username profilePicture');
    return board;
  }

  async getCompetitionProfile(userId) {
    let profile = await CompetitionProfile.findOne({ userId });
    if (!profile) profile = await CompetitionProfile.create({ userId });
    return profile;
  }

  async getCompetitionStats(userId) {
    const profile = await this.getCompetitionProfile(userId);
    const weekStart = this._currentWeekStartIST();

    const board = await WeeklyLeaderboard.findOne({ topic: 'global', weekStart });
    const myEntry = board?.entries?.find(e => e.userId.toString() === userId.toString());

    const todayChallenges = await this.getTodayChallenges();
    const todayAttempts = await ChallengeAttempt.find({
      userId,
      challengeId: { $in: todayChallenges.map(c => c._id) },
      completedAt: { $ne: null },
    });

    return {
      challengeStreak: profile.currentChallengeStreak,
      percentile: myEntry?.percentile || null,
      challengesThisWeek: myEntry?.challengesCompleted || 0,
      personalBests: Object.fromEntries(profile.personalBests || new Map()),
      todayCompleted: todayAttempts.length,
      todayTotal: todayChallenges.length,
    };
  }

  // --- Weekly Leaderboard Update ---

  async _updateWeeklyLeaderboard(userId, topic, handicappedScore) {
    const weekStart = this._currentWeekStartIST();
    const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000 - 1);

    // Update global board
    for (const boardTopic of ['global', topic]) {
      let board = await WeeklyLeaderboard.findOne({ topic: boardTopic, weekStart });
      if (!board) {
        board = await WeeklyLeaderboard.create({ topic: boardTopic, weekStart, weekEnd, entries: [] });
      }

      const entryIdx = board.entries.findIndex(e => e.userId.toString() === userId.toString());
      if (entryIdx >= 0) {
        board.entries[entryIdx].totalHandicappedScore += handicappedScore;
        board.entries[entryIdx].challengesCompleted += 1;
        board.entries[entryIdx].bestDayScore = Math.max(board.entries[entryIdx].bestDayScore, handicappedScore);
      } else {
        board.entries.push({
          userId, totalHandicappedScore: handicappedScore, challengesCompleted: 1, bestDayScore: handicappedScore,
        });
        board.participantCount += 1;
      }

      await board.save();
    }
  }

  // --- Challenge Results ---

  async getChallengeResults(userId, challengeId) {
    const attempt = await ChallengeAttempt.findOne({ userId, challengeId });
    if (!attempt) throw new Error('No attempt found');

    const challenge = await DailyChallenge.findById(challengeId);
    const compProfile = await CompetitionProfile.findOne({ userId });

    // Get current rank among all attempts for this challenge
    const allAttempts = await ChallengeAttempt.find({ challengeId, completedAt: { $ne: null } })
      .sort({ handicappedScore: -1 });
    const rank = allAttempts.findIndex(a => a.userId.toString() === userId.toString()) + 1;
    const totalParticipants = allAttempts.length;
    const percentile = totalParticipants > 0 ? Math.round(((totalParticipants - rank + 1) / totalParticipants) * 100) : null;

    return {
      rawScore: attempt.rawScore,
      handicappedScore: attempt.handicappedScore,
      timeTaken: attempt.timeTaken,
      isPersonalBest: attempt.isPersonalBest,
      correct: attempt.answers.filter((a, idx) => {
        const origIdx = attempt.questionOrder[idx];
        const q = challenge.questions[origIdx];
        const optOrder = attempt.optionOrders[idx];
        const ansIdx = ['A', 'B', 'C', 'D'].indexOf(a.selectedAnswer);
        return optOrder[ansIdx] === q.correctAnswer;
      }).length,
      total: challenge.questions.length,
      rank,
      percentile,
      totalParticipants,
      previousBest: compProfile?.personalBests?.get(challenge.topic)?.bestDailyScore || 0,
    };
  }

  // --- All-Time Leaderboard ---

  async getAllTimeLeaderboard(topic) {
    const boards = await WeeklyLeaderboard.find({
      topic: topic || 'global',
      finalized: true,
    });

    // Aggregate scores across all weeks
    const userScores = {};
    for (const board of boards) {
      for (const entry of board.entries) {
        const uid = entry.userId.toString();
        if (!userScores[uid]) {
          userScores[uid] = { userId: entry.userId, totalScore: 0, totalChallenges: 0 };
        }
        userScores[uid].totalScore += entry.totalHandicappedScore;
        userScores[uid].totalChallenges += entry.challengesCompleted;
      }
    }

    const sorted = Object.values(userScores).sort((a, b) => b.totalScore - a.totalScore);
    sorted.forEach((entry, idx) => { entry.rank = idx + 1; });

    // Populate user data for top 50
    const User = require('../models/User');
    const top50 = sorted.slice(0, 50);
    for (const entry of top50) {
      const user = await User.findById(entry.userId).select('firstName lastName username profilePicture');
      entry.user = user;
    }

    return { entries: top50, topic: topic || 'global' };
  }

  // --- Streak Management ---

  async _updateChallengeStreak(compProfile) {
    // Walk backward from today counting consecutive days with a completed challenge
    const today = this._todayIST();
    let streak = 0;
    let checkDate = today;

    while (true) {
      const challenges = await DailyChallenge.find({ date: checkDate });
      if (challenges.length === 0) break;

      const hasAttempt = await ChallengeAttempt.findOne({
        userId: compProfile.userId,
        challengeId: { $in: challenges.map(c => c._id) },
        completedAt: { $ne: null },
      });

      if (!hasAttempt) break;
      streak++;
      checkDate = new Date(checkDate.getTime() - 24 * 60 * 60 * 1000);
    }

    compProfile.currentChallengeStreak = streak;
    if (streak > compProfile.longestChallengeStreak) {
      compProfile.longestChallengeStreak = streak;
    }
  }

  // --- Helpers ---

  _todayIST() {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);
    return new Date(Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate()));
  }

  _currentWeekStartIST() {
    const today = this._todayIST();
    const day = today.getUTCDay();
    const diff = day === 0 ? 6 : day - 1; // Monday = 0
    return new Date(today.getTime() - diff * 24 * 60 * 60 * 1000);
  }
}

module.exports = new CompetitionService();
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/competitionService.js
git commit -m "feat(competition): add competition service with scoring, randomization, leaderboards"
```

---

### Task 3: Backend — Challenge Generation Service

**Files:**
- Create: `src/services/challengeGenerationService.js`

- [ ] **Step 1: Create challenge generation service**

```javascript
// src/services/challengeGenerationService.js
const openai = require('../config/openai');
const ChallengeCandidateBank = require('../models/ChallengeCandidateBank');
const DailyChallenge = require('../models/DailyChallenge');
const LiveEvent = require('../models/LiveEvent');
const KnowledgeProfile = require('../models/KnowledgeProfile');

const CHALLENGE_GENERATION_PROMPT = `You are an expert educational assessment creator specializing in standardized competitive quizzes.

Generate questions for a daily learning challenge. These questions will be the SAME for all participants regardless of their skill level, so they must be:
1. Unambiguous — exactly one clearly correct answer
2. Self-contained — no external context needed
3. Fair — testable through reasoning, not obscure memorization
4. Varied — mix of recall, application, and conceptual questions
5. Exactly 4 options (A, B, C, D)

Difficulty distribution: 30% easy, 40% medium, 30% hard.
CRITICAL: Generate EXACTLY the number of questions specified. Not fewer, not more.

Return valid JSON with a "questions" array where each question has:
- questionText, questionType (recall | application | conceptual | critical_thinking),
  options (array of {label, text}), correctAnswer (A/B/C/D),
  explanation, difficulty (easy | medium | hard), concept`;

class ChallengeGenerationService {

  async generateWeeklyCandidates() {
    // Find active topics (topics with at least 1 user having mastery data)
    const profiles = await KnowledgeProfile.find({ 'topicMastery.0': { $exists: true } });
    const activeTopics = [...new Set(profiles.flatMap(p => p.topicMastery.map(t => t.topic)))];

    console.log(`[ChallengeGen] Generating candidates for ${activeTopics.length} topics`);

    const weekOf = this._nextMondayIST();
    const results = [];

    for (const topic of activeTopics) {
      try {
        const candidates = await this._generateForTopic(topic, 130);
        const bank = await ChallengeCandidateBank.create({
          topic, weekOf, candidates, status: 'pending_review',
        });
        results.push({ topic, count: candidates.length, bankId: bank._id });
        console.log(`[ChallengeGen] Generated ${candidates.length} candidates for "${topic}"`);
      } catch (err) {
        console.error(`[ChallengeGen] Failed for "${topic}":`, err.message);
        results.push({ topic, error: err.message });
      }
    }

    return results;
  }

  async _generateForTopic(topic, totalCount) {
    const batchSize = 20;
    const batches = Math.ceil(totalCount / batchSize);
    let allQuestions = [];

    for (let i = 0; i < batches; i++) {
      const remaining = totalCount - allQuestions.length;
      const count = Math.min(batchSize, remaining);

      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        messages: [
          { role: 'system', content: CHALLENGE_GENERATION_PROMPT },
          { role: 'user', content: JSON.stringify({ topic, questionCount: count }) },
        ],
        response_format: { type: 'json_object' },
        temperature: 0.7,
        max_tokens: count * 500,
      });

      const parsed = JSON.parse(response.choices[0].message.content);
      if (parsed.questions && Array.isArray(parsed.questions)) {
        allQuestions.push(...parsed.questions);
      }
    }

    return allQuestions;
  }

  async autoAssignQuestions(bankId) {
    const bank = await ChallengeCandidateBank.findById(bankId);
    if (!bank) throw new Error('Candidate bank not found');

    const unassigned = bank.candidates.filter(c => !c.assignedTo);
    const weekOf = bank.weekOf;

    // Assign 10 per day for 7 daily challenges
    for (let day = 0; day < 7; day++) {
      const date = new Date(weekOf.getTime() + day * 24 * 60 * 60 * 1000);
      const selected = this._selectBalanced(unassigned.filter(c => !c.assignedTo), 10);
      selected.forEach(q => { q.assignedTo = 'daily'; q.assignedDate = date; });
    }

    // Assign 10 per live event for 3 events (Mon/Wed/Fri)
    const liveEventDays = [0, 2, 4]; // Mon, Wed, Fri offsets
    for (const dayOffset of liveEventDays) {
      const date = new Date(weekOf.getTime() + dayOffset * 24 * 60 * 60 * 1000);
      const selected = this._selectBalanced(unassigned.filter(c => !c.assignedTo), 10);
      selected.forEach(q => { q.assignedTo = 'live'; q.assignedDate = date; });
    }

    bank.status = 'curated';
    bank.curatedAt = new Date();
    await bank.save();
    return bank;
  }

  _selectBalanced(pool, count) {
    // Select 3 easy, 4 medium, 3 hard (or closest possible)
    const byDifficulty = { easy: [], medium: [], hard: [] };
    pool.forEach(q => {
      if (byDifficulty[q.difficulty]) byDifficulty[q.difficulty].push(q);
    });

    const selected = [];
    const targets = { easy: 3, medium: 4, hard: 3 };
    for (const [diff, target] of Object.entries(targets)) {
      const available = byDifficulty[diff].filter(q => !selected.includes(q));
      selected.push(...available.slice(0, target));
    }

    // Fill remaining from any difficulty if needed
    while (selected.length < count) {
      const remaining = pool.find(q => !selected.includes(q));
      if (!remaining) break;
      selected.push(remaining);
    }

    return selected.slice(0, count);
  }

  async activateDailyChallenge(date) {
    const dateObj = date || this._todayIST();
    const banks = await ChallengeCandidateBank.find({
      weekOf: { $lte: dateObj },
      status: { $in: ['curated', 'used'] },
    });

    const results = [];
    for (const bank of banks) {
      const dailyQuestions = bank.candidates.filter(c =>
        c.assignedTo === 'daily' &&
        c.assignedDate &&
        c.assignedDate.toDateString() === dateObj.toDateString()
      );

      if (dailyQuestions.length < 10) continue;

      const istMidnight = new Date(dateObj);
      const istEndOfDay = new Date(dateObj.getTime() + 24 * 60 * 60 * 1000 - 1);

      const challenge = await DailyChallenge.create({
        topic: bank.topic,
        date: dateObj,
        questions: dailyQuestions.slice(0, 10),
        status: 'active',
        createdFrom: bank._id,
        activatesAt: istMidnight,
        closesAt: istEndOfDay,
      });

      results.push({ topic: bank.topic, challengeId: challenge._id });
    }

    // Close yesterday's challenges
    const yesterday = new Date(dateObj.getTime() - 24 * 60 * 60 * 1000);
    await DailyChallenge.updateMany(
      { date: yesterday, status: 'active' },
      { status: 'closed' }
    );

    return results;
  }

  _todayIST() {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);
    return new Date(Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate()));
  }

  _nextMondayIST() {
    const today = this._todayIST();
    const day = today.getUTCDay();
    const daysUntilMonday = day === 0 ? 1 : 8 - day;
    return new Date(today.getTime() + daysUntilMonday * 24 * 60 * 60 * 1000);
  }
}

module.exports = new ChallengeGenerationService();
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/challengeGenerationService.js
git commit -m "feat(competition): add challenge generation service with AI pipeline and auto-assign"
```

---

### Task 4: Backend — Live Event Service

**Files:**
- Create: `src/services/liveEventService.js`

- [ ] **Step 1: Create live event service**

```javascript
// src/services/liveEventService.js
const LiveEvent = require('../models/LiveEvent');
const LiveEventAttempt = require('../models/LiveEventAttempt');
const KnowledgeProfile = require('../models/KnowledgeProfile');
const CompetitionProfile = require('../models/CompetitionProfile');
const ChallengeCandidateBank = require('../models/ChallengeCandidateBank');
const crypto = require('crypto');

const DIFFICULTY_WEIGHTS = { easy: 0.8, medium: 1.0, hard: 1.3 };
const LEVEL_BONUS = { beginner: 1.20, intermediate: 1.10, advanced: 1.00, expert: 0.95 };
const TIERED_TIME_LIMITS = { easy: 20, medium: 35, hard: 45 };

class LiveEventService {

  async getUpcomingEvents() {
    return LiveEvent.find({
      scheduledAt: { $gte: new Date() },
      status: { $in: ['scheduled', 'lobby'] },
    }).sort({ scheduledAt: 1 }).select('-questions.correctAnswer -questions.explanation');
  }

  async getEventById(eventId) {
    return LiveEvent.findById(eventId);
  }

  async joinLobby(userId, eventId) {
    const event = await LiveEvent.findById(eventId);
    if (!event) throw new Error('Event not found');
    if (event.status !== 'lobby') throw new Error('Lobby is not open');

    const existing = await LiveEventAttempt.findOne({ userId, eventId });
    if (existing) return { alreadyJoined: true, participantCount: event.participantCount };

    const questionOrder = this._generateQuestionOrder(userId, eventId, event.questions.length);
    const optionOrders = this._generateOptionOrders(userId, eventId, event.questions);

    await LiveEventAttempt.create({ userId, eventId, questionOrder, optionOrders, answers: [] });
    await LiveEvent.findByIdAndUpdate(eventId, { $inc: { participantCount: 1 } });

    const updated = await LiveEvent.findById(eventId);
    return { alreadyJoined: false, participantCount: updated.participantCount };
  }

  async getLobbyState(eventId) {
    const event = await LiveEvent.findById(eventId).select('status participantCount scheduledAt topic');
    return event;
  }

  async getCurrentQuestion(userId, eventId) {
    const event = await LiveEvent.findById(eventId);
    if (!event || event.status !== 'live') throw new Error('Event is not live');

    const attempt = await LiveEventAttempt.findOne({ userId, eventId });
    if (!attempt) throw new Error('Not joined');

    const now = new Date();
    const elapsed = (now - event.startedAt) / 1000;

    // Calculate which question is active based on elapsed time and tiered timers
    let cumulative = 0;
    let currentIdx = -1;
    const questionTimings = event.questions.map((q, idx) => {
      const origIdx = attempt.questionOrder[idx];
      const timeLimit = TIERED_TIME_LIMITS[event.questions[origIdx].difficulty] || 35;
      const start = cumulative;
      cumulative += timeLimit + 3; // 3s results overlay between questions
      return { idx, start, end: cumulative, timeLimit };
    });

    const activeTiming = questionTimings.find(t => elapsed >= t.start && elapsed < t.end);
    if (!activeTiming) {
      return { eventComplete: true };
    }

    currentIdx = activeTiming.idx;
    const origIdx = attempt.questionOrder[currentIdx];
    const q = event.questions[origIdx];
    const optOrder = attempt.optionOrders[currentIdx];
    const shuffledOptions = optOrder.map(label => q.options.find(o => o.label === label));

    const timeRemaining = activeTiming.end - elapsed - 3; // subtract results overlay

    return {
      questionIndex: currentIdx,
      questionText: q.questionText,
      questionType: q.questionType,
      difficulty: q.difficulty,
      options: shuffledOptions.map((opt, i) => ({ label: ['A', 'B', 'C', 'D'][i], text: opt.text })),
      timeLimit: activeTiming.timeLimit,
      timeRemaining: Math.max(0, timeRemaining),
      totalQuestions: event.questions.length,
      eventComplete: false,
    };
  }

  async submitLiveAnswer(userId, eventId, questionIndex, selectedAnswer, timeSpent) {
    const attempt = await LiveEventAttempt.findOne({ userId, eventId });
    if (!attempt) throw new Error('Not joined');

    attempt.answers.push({ questionIndex, selectedAnswer, timeSpent, answeredAt: new Date() });
    await attempt.save();
    return { answersSubmitted: attempt.answers.length };
  }

  async getQuestionResults(eventId, questionIndex) {
    const event = await LiveEvent.findById(eventId);
    const attempts = await LiveEventAttempt.find({ eventId, 'answers.questionIndex': questionIndex });

    let correctCount = 0;
    for (const attempt of attempts) {
      const answer = attempt.answers.find(a => a.questionIndex === questionIndex);
      if (!answer) continue;
      const origIdx = attempt.questionOrder[questionIndex];
      const question = event.questions[origIdx];
      const optOrder = attempt.optionOrders[questionIndex];
      const answerIdx = ['A', 'B', 'C', 'D'].indexOf(answer.selectedAnswer);
      const originalLabel = optOrder[answerIdx];
      if (originalLabel === question.correctAnswer) correctCount++;
    }

    const total = attempts.length || 1;
    return { correctPercentage: Math.round((correctCount / total) * 100), totalAnswered: total };
  }

  async completeLiveEvent(eventId) {
    const event = await LiveEvent.findById(eventId);
    if (!event) throw new Error('Event not found');

    const attempts = await LiveEventAttempt.find({ eventId });
    const leaderboard = [];

    for (const attempt of attempts) {
      if (attempt.answers.length === 0) continue;

      const profile = await KnowledgeProfile.findOne({ userId: attempt.userId });
      const topicMastery = profile?.topicMastery?.find(t => t.topic === event.topic);
      const userLevel = topicMastery?.level || 'beginner';

      let correct = 0;
      for (const answer of attempt.answers) {
        const origIdx = attempt.questionOrder[answer.questionIndex];
        const question = event.questions[origIdx];
        const optOrder = attempt.optionOrders[answer.questionIndex];
        const answerIdx = ['A', 'B', 'C', 'D'].indexOf(answer.selectedAnswer);
        const originalLabel = optOrder[answerIdx];
        if (originalLabel === question.correctAnswer) correct++;
      }

      const rawScore = (correct / event.questions.length) * 100;
      const avgDifficulty = event.questions.reduce((s, q) => s + (DIFFICULTY_WEIGHTS[q.difficulty] || 1), 0) / event.questions.length;
      const handicappedScore = rawScore * avgDifficulty * (LEVEL_BONUS[userLevel] || 1.0);
      const timeTaken = attempt.answers.reduce((s, a) => s + (a.timeSpent || 0), 0);

      attempt.rawScore = rawScore;
      attempt.handicappedScore = handicappedScore;
      attempt.timeTaken = timeTaken;
      attempt.completedAt = new Date();
      await attempt.save();

      leaderboard.push({
        userId: attempt.userId, handicappedScore, rawScore, timeTaken, completedAt: attempt.completedAt,
      });
    }

    // Sort and assign ranks
    leaderboard.sort((a, b) => b.handicappedScore - a.handicappedScore || a.timeTaken - b.timeTaken);
    leaderboard.forEach((entry, idx) => { entry.rank = idx + 1; });

    // Update attempts with ranks
    for (const entry of leaderboard) {
      await LiveEventAttempt.findOneAndUpdate(
        { userId: entry.userId, eventId },
        { rank: entry.rank }
      );
    }

    event.leaderboard = leaderboard;
    event.status = 'completed';
    event.completedAt = new Date();
    event.duration = (event.completedAt - event.startedAt) / 1000;
    await event.save();

    return event;
  }

  async getEventResults(userId, eventId) {
    const event = await LiveEvent.findById(eventId)
      .populate('leaderboard.userId', 'firstName lastName username profilePicture');
    const attempt = await LiveEventAttempt.findOne({ userId, eventId });
    return { event, attempt };
  }

  // --- Randomization helpers (same as CompetitionService) ---

  _generateQuestionOrder(userId, eventId, count) {
    const seed = crypto.createHash('sha256').update(`${userId}${eventId}`).digest('hex');
    const indices = Array.from({ length: count }, (_, i) => i);
    let seedNum = parseInt(seed.substring(0, 8), 16);
    for (let i = indices.length - 1; i > 0; i--) {
      seedNum = (seedNum * 1103515245 + 12345) & 0x7fffffff;
      const j = seedNum % (i + 1);
      [indices[i], indices[j]] = [indices[j], indices[i]];
    }
    return indices;
  }

  _generateOptionOrders(userId, eventId, questions) {
    const baseSeed = crypto.createHash('sha256').update(`${userId}${eventId}opts`).digest('hex');
    return questions.map((_, qIdx) => {
      const labels = ['A', 'B', 'C', 'D'];
      let seedNum = parseInt(baseSeed.substring(qIdx * 2, qIdx * 2 + 8), 16);
      for (let i = labels.length - 1; i > 0; i--) {
        seedNum = (seedNum * 1103515245 + 12345) & 0x7fffffff;
        const j = seedNum % (i + 1);
        [labels[i], labels[j]] = [labels[j], labels[i]];
      }
      return labels;
    });
  }
}

module.exports = new LiveEventService();
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/services/liveEventService.js
git commit -m "feat(competition): add live event service with lobby, sync questions, scoring"
```

---

### Task 5: Backend — Controller & Routes

**Files:**
- Create: `src/controllers/competitionController.js`
- Create: `src/routes/competition.js`
- Modify: `src/app.js`

- [ ] **Step 1: Create competition controller**

```javascript
// src/controllers/competitionController.js
const competitionService = require('../services/competitionService');
const liveEventService = require('../services/liveEventService');
const challengeGenerationService = require('../services/challengeGenerationService');
const apiResponse = require('../utils/apiResponse');

// --- Daily Challenges ---

const getTodayChallenges = async (req, res, next) => {
  try {
    const challenges = await competitionService.getTodayChallenges();
    res.json(apiResponse.success(challenges));
  } catch (err) { next(err); }
};

const getChallengeById = async (req, res, next) => {
  try {
    const challenge = await competitionService.getChallengeById(req.params.id);
    if (!challenge) return res.status(404).json(apiResponse.error('Challenge not found'));
    res.json(apiResponse.success(challenge));
  } catch (err) { next(err); }
};

const startChallenge = async (req, res, next) => {
  try {
    const result = await competitionService.startChallenge(req.user.userId, req.params.id);
    res.json(apiResponse.success(result));
  } catch (err) { next(err); }
};

const submitChallengeAnswer = async (req, res, next) => {
  try {
    const { questionIndex, selectedAnswer, timeSpent } = req.body;
    const result = await competitionService.submitAnswer(req.user.userId, req.params.id, questionIndex, selectedAnswer, timeSpent);
    res.json(apiResponse.success(result));
  } catch (err) { next(err); }
};

const completeChallenge = async (req, res, next) => {
  try {
    const result = await competitionService.completeChallenge(req.user.userId, req.params.id);
    res.json(apiResponse.success(result));
  } catch (err) { next(err); }
};

const getChallengeResults = async (req, res, next) => {
  try {
    const result = await competitionService.getChallengeResults(req.user.userId, req.params.id);
    res.json(apiResponse.success(result));
  } catch (err) { next(err); }
};

// --- Leaderboard ---

const getWeeklyLeaderboard = async (req, res, next) => {
  try {
    const { topic, weekStart } = req.query;
    const board = await competitionService.getWeeklyLeaderboard(topic || 'global', weekStart ? new Date(weekStart) : null);
    res.json(apiResponse.success(board));
  } catch (err) { next(err); }
};

const getAllTimeLeaderboard = async (req, res, next) => {
  try {
    const { topic } = req.query;
    const board = await competitionService.getAllTimeLeaderboard(topic);
    res.json(apiResponse.success(board));
  } catch (err) { next(err); }
};

// --- Profile & Stats ---

const getCompetitionProfile = async (req, res, next) => {
  try {
    const profile = await competitionService.getCompetitionProfile(req.user.userId);
    res.json(apiResponse.success(profile));
  } catch (err) { next(err); }
};

const getCompetitionStats = async (req, res, next) => {
  try {
    const stats = await competitionService.getCompetitionStats(req.user.userId);
    res.json(apiResponse.success(stats));
  } catch (err) { next(err); }
};

// --- Live Events ---

const getUpcomingEvents = async (req, res, next) => {
  try {
    const events = await liveEventService.getUpcomingEvents();
    res.json(apiResponse.success(events));
  } catch (err) { next(err); }
};

const getEventById = async (req, res, next) => {
  try {
    const event = await liveEventService.getEventById(req.params.id);
    if (!event) return res.status(404).json(apiResponse.error('Event not found'));
    res.json(apiResponse.success(event));
  } catch (err) { next(err); }
};

const joinLobby = async (req, res, next) => {
  try {
    const result = await liveEventService.joinLobby(req.user.userId, req.params.id);
    res.json(apiResponse.success(result));
  } catch (err) { next(err); }
};

const getLobbyState = async (req, res, next) => {
  try {
    const state = await liveEventService.getLobbyState(req.params.id);
    res.json(apiResponse.success(state));
  } catch (err) { next(err); }
};

const getCurrentQuestion = async (req, res, next) => {
  try {
    const question = await liveEventService.getCurrentQuestion(req.user.userId, req.params.id);
    res.json(apiResponse.success(question));
  } catch (err) { next(err); }
};

const submitLiveAnswer = async (req, res, next) => {
  try {
    const { questionIndex, selectedAnswer, timeSpent } = req.body;
    const result = await liveEventService.submitLiveAnswer(req.user.userId, req.params.id, questionIndex, selectedAnswer, timeSpent);
    res.json(apiResponse.success(result));
  } catch (err) { next(err); }
};

const getQuestionResults = async (req, res, next) => {
  try {
    const { questionIndex } = req.query;
    const results = await liveEventService.getQuestionResults(req.params.id, parseInt(questionIndex));
    res.json(apiResponse.success(results));
  } catch (err) { next(err); }
};

const getEventResults = async (req, res, next) => {
  try {
    const results = await liveEventService.getEventResults(req.user.userId, req.params.id);
    res.json(apiResponse.success(results));
  } catch (err) { next(err); }
};

// --- Admin ---

const getChallengeCandidates = async (req, res, next) => {
  try {
    const { week } = req.query;
    const filter = week ? { weekOf: new Date(week) } : {};
    const banks = await require('../models/ChallengeCandidateBank').find(filter).sort({ createdAt: -1 });
    res.json(apiResponse.success(banks));
  } catch (err) { next(err); }
};

const approveCandidates = async (req, res, next) => {
  try {
    const bank = await challengeGenerationService.autoAssignQuestions(req.params.id);
    res.json(apiResponse.success(bank, 'Questions assigned'));
  } catch (err) { next(err); }
};

const triggerGeneration = async (req, res, next) => {
  try {
    const results = await challengeGenerationService.generateWeeklyCandidates();
    res.json(apiResponse.success(results, 'Generation complete'));
  } catch (err) { next(err); }
};

module.exports = {
  getTodayChallenges, getChallengeById, startChallenge, submitChallengeAnswer,
  completeChallenge, getChallengeResults,
  getWeeklyLeaderboard, getAllTimeLeaderboard,
  getCompetitionProfile, getCompetitionStats,
  getUpcomingEvents, getEventById, joinLobby, getLobbyState,
  getCurrentQuestion, submitLiveAnswer, getQuestionResults, getEventResults,
  getChallengeCandidates, approveCandidates, triggerGeneration,
};
```

- [ ] **Step 2: Create competition routes**

```javascript
// src/routes/competition.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const c = require('../controllers/competitionController');

// Daily Challenges
router.get('/challenges/today', auth, c.getTodayChallenges);
router.get('/challenges/:id', auth, c.getChallengeById);
router.post('/challenges/:id/start', auth, c.startChallenge);
router.put('/challenges/:id/answer', auth, c.submitChallengeAnswer);
router.post('/challenges/:id/complete', auth, c.completeChallenge);
router.get('/challenges/:id/results', auth, c.getChallengeResults);

// Leaderboard
router.get('/leaderboard/weekly', auth, c.getWeeklyLeaderboard);
router.get('/leaderboard/alltime', auth, c.getAllTimeLeaderboard);

// Profile & Stats
router.get('/profile', auth, c.getCompetitionProfile);
router.get('/stats', auth, c.getCompetitionStats);

// Live Events
router.get('/live-events/upcoming', auth, c.getUpcomingEvents);
router.get('/live-events/:id', auth, c.getEventById);
router.post('/live-events/:id/join', auth, c.joinLobby);
router.get('/live-events/:id/lobby', auth, c.getLobbyState);
router.get('/live-events/:id/question', auth, c.getCurrentQuestion);
router.put('/live-events/:id/answer', auth, c.submitLiveAnswer);
router.get('/live-events/:id/question-results', auth, c.getQuestionResults);
router.get('/live-events/:id/results', auth, c.getEventResults);

// Admin
router.get('/admin/challenge-candidates', auth, rbac('admin'), c.getChallengeCandidates);
router.put('/admin/challenge-candidates/:id', auth, rbac('admin'), c.approveCandidates);
router.post('/admin/challenges/generate', auth, rbac('admin'), c.triggerGeneration);

module.exports = router;
```

- [ ] **Step 3: Mount route in app.js**

Add to `src/app.js` where other routes are mounted:

```javascript
const competitionRoutes = require('./routes/competition');
// ... after other route mounts:
app.use('/api/v1/competition', competitionRoutes);
```

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/controllers/competitionController.js src/routes/competition.js src/app.js
git commit -m "feat(competition): add controller and routes for challenges, leaderboards, live events"
```

---

### Task 6: Backend — Queue, Worker & Cron Jobs

**Files:**
- Modify: `src/config/queue.js`
- Create: `src/workers/competitionWorker.js`
- Modify: `src/workers/cronJobs.js`
- Modify: `src/workers/index.js`

- [ ] **Step 1: Add competition queue to config/queue.js**

Add to the existing queue definitions:

```javascript
const competitionQueue = new Queue('competition', { connection });
```

Add to `module.exports`:

```javascript
competitionQueue,
```

- [ ] **Step 2: Create competition worker**

```javascript
// src/workers/competitionWorker.js
const { Worker } = require('bullmq');
const Redis = require('ioredis');
const challengeGenerationService = require('../services/challengeGenerationService');
const competitionService = require('../services/competitionService');
const liveEventService = require('../services/liveEventService');
const LiveEvent = require('../models/LiveEvent');
const ChallengeAttempt = require('../models/ChallengeAttempt');
const DailyChallenge = require('../models/DailyChallenge');
const WeeklyLeaderboard = require('../models/WeeklyLeaderboard');
const CompetitionProfile = require('../models/CompetitionProfile');
const { notificationQueue } = require('../config/queue');

const connection = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: null });

const competitionWorker = new Worker('competition', async (job) => {
  console.log(`[CompetitionWorker] Processing job: ${job.name}`);

  switch (job.name) {
    case 'generateWeeklyCandidates':
      return await challengeGenerationService.generateWeeklyCandidates();

    case 'activateDailyChallenge':
      const activated = await challengeGenerationService.activateDailyChallenge();
      // Send push notifications for each activated challenge
      for (const { topic, challengeId } of activated) {
        // Get all users with this topic in their knowledge profile
        const KnowledgeProfile = require('../models/KnowledgeProfile');
        const profiles = await KnowledgeProfile.find({ 'topicMastery.topic': topic });
        for (const profile of profiles) {
          await notificationQueue.add('send', {
            userId: profile.userId,
            title: "Today's Challenge is Live! ⚡",
            body: `Test your ${topic} skills — compete with other learners!`,
            data: { type: 'challenge_live', challengeId: challengeId.toString() },
          });
        }
      }
      return activated;

    case 'finalizeDailyRankings': {
      // Calculate speed bonuses for yesterday's challenges
      const yesterday = new Date(competitionService._todayIST().getTime() - 24 * 60 * 60 * 1000);
      const challenges = await DailyChallenge.find({ date: yesterday, status: 'closed' });

      for (const challenge of challenges) {
        const attempts = await ChallengeAttempt.find({ challengeId: challenge._id, completedAt: { $ne: null } });
        if (attempts.length < 3) continue; // Min 3 for speed bonus

        const avgTimes = attempts.map(a => {
          const totalTime = a.answers.reduce((s, ans) => s + (ans.timeSpent || 0), 0);
          return totalTime / a.answers.length;
        });
        const sorted = [...avgTimes].sort((a, b) => a - b);
        const median = sorted[Math.floor(sorted.length / 2)];

        for (let i = 0; i < attempts.length; i++) {
          const speedBonus = competitionService.calculateSpeedBonus(avgTimes[i], median);
          if (speedBonus > 0) {
            attempts[i].handicappedScore += speedBonus * 10;
            await attempts[i].save();
          }
        }
      }
      return { processed: challenges.length };
    }

    case 'finalizeWeeklyLeaderboard': {
      const prevWeekStart = new Date(competitionService._currentWeekStartIST().getTime() - 7 * 24 * 60 * 60 * 1000);
      const boards = await WeeklyLeaderboard.find({ weekStart: prevWeekStart, finalized: false });

      for (const board of boards) {
        board.entries.sort((a, b) => b.totalHandicappedScore - a.totalHandicappedScore);
        board.entries.forEach((entry, idx) => {
          entry.rank = idx + 1;
          entry.percentile = Math.round(((board.entries.length - idx) / board.entries.length) * 100);
        });
        board.finalized = true;
        await board.save();

        // Award title to #1
        if (board.entries.length > 0 && board.topic !== 'global') {
          const winner = board.entries[0];
          await CompetitionProfile.findOneAndUpdate(
            { userId: winner.userId },
            { $push: { titlesEarned: { title: `${board.topic} Weekly Champion`, earnedAt: new Date(), topic: board.topic } } },
            { upsert: true }
          );
        }

        // Notify participants
        for (const entry of board.entries.slice(0, 3)) {
          await notificationQueue.add('send', {
            userId: entry.userId,
            title: `You finished #${entry.rank} this week! 🏆`,
            body: `Top ${entry.percentile}% in ${board.topic} — ${entry.challengesCompleted}/7 challenges`,
            data: { type: 'weekly_results', topic: board.topic },
          });
        }
      }
      return { finalized: boards.length };
    }

    case 'streakReminderNotification': {
      // Find users with active streaks who haven't done today's challenge
      const today = competitionService._todayIST();
      const challenges = await DailyChallenge.find({ date: today, status: 'active' });
      const challengeIds = challenges.map(c => c._id);

      const profiles = await CompetitionProfile.find({ currentChallengeStreak: { $gte: 1 } });
      for (const profile of profiles) {
        const todayAttempt = await ChallengeAttempt.findOne({
          userId: profile.userId,
          challengeId: { $in: challengeIds },
          completedAt: { $ne: null },
        });
        if (!todayAttempt) {
          await notificationQueue.add('send', {
            userId: profile.userId,
            title: "Don't lose your streak! 🔥",
            body: `${profile.currentChallengeStreak} days straight — today's challenge is waiting`,
            data: { type: 'streak_reminder' },
          });
        }
      }
      return { checked: profiles.length };
    }

    case 'openLiveEventLobby': {
      const now = new Date();
      const fiveMinFromNow = new Date(now.getTime() + 5 * 60 * 1000);
      const events = await LiveEvent.find({
        scheduledAt: { $lte: fiveMinFromNow, $gte: now },
        status: 'scheduled',
      });
      for (const event of events) {
        event.status = 'lobby';
        await event.save();
      }
      return { opened: events.length };
    }

    case 'startLiveEvent': {
      const events = await LiveEvent.find({ status: 'lobby' });
      for (const event of events) {
        if (new Date() >= event.scheduledAt) {
          event.status = 'live';
          event.startedAt = new Date();
          await event.save();

          // Schedule completion as a delayed BullMQ job (survives worker restart)
          const totalTime = event.questions.reduce((s, q) => {
            const limit = { easy: 20, medium: 35, hard: 45 }[q.difficulty] || 35;
            return s + limit + 3; // +3s results overlay
          }, 0);

          const { competitionQueue } = require('../config/queue');
          await competitionQueue.add('completeLiveEvent', { eventId: event._id.toString() }, {
            delay: totalTime * 1000,
            removeOnComplete: true,
          });
        }
      }
      return { started: events.length };
    }

    case 'completeLiveEvent': {
      const event = await liveEventService.completeLiveEvent(job.data.eventId);
      // Notify participants
      for (const entry of event.leaderboard.slice(0, 3)) {
        await notificationQueue.add('send', {
          userId: entry.userId,
          title: `Live Event Results! 🏆`,
          body: `You finished #${entry.rank} out of ${event.leaderboard.length} in ${event.topic}`,
          data: { type: 'live_event_results', eventId: event._id.toString() },
        });
      }
      return { completed: event._id };
    }

    case 'liveEventReminder': {
      const events = await LiveEvent.find({
        status: 'scheduled',
        scheduledAt: {
          $gte: new Date(),
          $lte: new Date(Date.now() + 35 * 60 * 1000), // within 35 min
        },
      });
      for (const event of events) {
        // Notify all users (or users interested in this topic)
        const KnowledgeProfile = require('../models/KnowledgeProfile');
        const profiles = await KnowledgeProfile.find({ 'topicMastery.topic': event.topic });
        for (const profile of profiles) {
          await notificationQueue.add('send', {
            userId: profile.userId,
            title: 'Live Event Tonight! 🎯',
            body: `${event.topic} starts at 8 PM — don't miss it!`,
            data: { type: 'live_event_reminder', eventId: event._id.toString() },
          });
        }
      }
      return { reminded: events.length };
    }

    default:
      console.warn(`[CompetitionWorker] Unknown job: ${job.name}`);
  }
}, { connection, concurrency: 3 });

competitionWorker.on('failed', (job, err) => {
  console.error(`[CompetitionWorker] Job ${job.name} failed:`, err.message);
});

module.exports = competitionWorker;
```

- [ ] **Step 3: Add cron schedules to cronJobs.js**

Add these cron job registrations to `src/workers/cronJobs.js` using the existing pattern:

```javascript
const { competitionQueue } = require('../config/queue');

// Competition: Generate weekly candidates — Sunday 23:00 IST (17:30 UTC)
competitionQueue.add('generateWeeklyCandidates', {}, {
  repeat: { pattern: '30 17 * * 0' },
  removeOnComplete: true,
});

// Competition: Activate daily challenge — Daily 00:00 IST (18:30 UTC prev day)
competitionQueue.add('activateDailyChallenge', {}, {
  repeat: { pattern: '30 18 * * *' },
  removeOnComplete: true,
});

// Competition: Finalize daily rankings — Daily 00:30 IST (19:00 UTC prev day)
competitionQueue.add('finalizeDailyRankings', {}, {
  repeat: { pattern: '0 19 * * *' },
  removeOnComplete: true,
});

// Competition: Finalize weekly leaderboard — Monday 00:30 IST (Sun 19:00 UTC)
competitionQueue.add('finalizeWeeklyLeaderboard', {}, {
  repeat: { pattern: '0 19 * * 0' },
  removeOnComplete: true,
});

// Competition: Streak reminder — Daily 21:00 IST (15:30 UTC)
competitionQueue.add('streakReminderNotification', {}, {
  repeat: { pattern: '30 15 * * *' },
  removeOnComplete: true,
});

// Competition: Live event reminder — Mon/Wed/Fri 19:30 IST (14:00 UTC)
competitionQueue.add('liveEventReminder', {}, {
  repeat: { pattern: '0 14 * * 1,3,5' },
  removeOnComplete: true,
});

// Competition: Open live event lobby — Mon/Wed/Fri 19:55 IST (14:25 UTC)
competitionQueue.add('openLiveEventLobby', {}, {
  repeat: { pattern: '25 14 * * 1,3,5' },
  removeOnComplete: true,
});

// Competition: Start live event — Mon/Wed/Fri 20:00 IST (14:30 UTC)
competitionQueue.add('startLiveEvent', {}, {
  repeat: { pattern: '30 14 * * 1,3,5' },
  removeOnComplete: true,
});
```

- [ ] **Step 4: Register worker in workers/index.js**

Add to `src/workers/index.js`:

```javascript
require('./competitionWorker');
```

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git add src/config/queue.js src/workers/competitionWorker.js src/workers/cronJobs.js src/workers/index.js
git commit -m "feat(competition): add queue, worker, and cron jobs for challenge lifecycle"
```

---

### Task 7: iOS — Competition Models

**Files:**
- Create: `ScaleUp/Models/Competition.swift`

- [ ] **Step 1: Create competition models**

```swift
// ScaleUp/Models/Competition.swift
import Foundation

// MARK: - Daily Challenge

struct DailyChallenge: Codable, Identifiable, Hashable {
    let id: String
    let topic: String
    let date: String
    let status: String
    let participantCount: Int
    let activatesAt: String?
    let closesAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, date, status, participantCount, activatesAt, closesAt
    }
}

// MARK: - Challenge Start Response

struct ChallengeStartResponse: Codable {
    let attemptId: String
    let questions: [ChallengeQuestion]
}

struct ChallengeQuestion: Codable, Identifiable {
    let questionIndex: Int
    let questionText: String
    let questionType: String
    let difficulty: String
    let concept: String?
    let options: [ChallengeOption]
    let timeLimit: Int

    var id: Int { questionIndex }
}

struct ChallengeOption: Codable, Hashable {
    let label: String
    let text: String
}

// MARK: - Challenge Results

struct ChallengeResult: Codable {
    let rawScore: Double
    let handicappedScore: Double
    let timeTaken: Double
    let isPersonalBest: Bool
    let correct: Int
    let total: Int
    let previousBest: Double
}

// MARK: - Weekly Leaderboard

struct WeeklyLeaderboard: Codable {
    let id: String?
    let topic: String
    let weekStart: String
    let weekEnd: String
    let entries: [LeaderboardEntry]
    let finalized: Bool
    let participantCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, weekStart, weekEnd, entries, finalized, participantCount
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    let userId: LeaderboardUser
    let totalHandicappedScore: Double
    let challengesCompleted: Int
    let bestDayScore: Double
    let rank: Int?
    let percentile: Double?

    var id: String { userId.id }
}

struct LeaderboardUser: Codable, Identifiable {
    let id: String
    let firstName: String?
    let lastName: String?
    let username: String?
    let profilePicture: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture
    }

    var displayName: String {
        if let first = firstName, let last = lastName { return "\(first) \(last)" }
        return username ?? "Player"
    }
}

// MARK: - Competition Profile

struct CompetitionProfile: Codable {
    let userId: String?
    let personalBests: [String: PersonalBest]?
    let totalChallengesCompleted: Int
    let currentChallengeStreak: Int
    let longestChallengeStreak: Int
    let titlesEarned: [CompetitionTitle]?
}

struct PersonalBest: Codable {
    let bestDailyScore: Double?
    let bestDailyDate: String?
    let bestWeeklyScore: Double?
    let bestWeeklyWeekStart: String?
}

struct CompetitionTitle: Codable {
    let title: String
    let earnedAt: String
    let topic: String
}

// MARK: - Competition Stats

struct CompetitionStats: Codable {
    let challengeStreak: Int
    let percentile: Double?
    let challengesThisWeek: Int
    let personalBests: [String: PersonalBest]?
    let todayCompleted: Int
    let todayTotal: Int
}

// MARK: - Live Event

struct LiveEvent: Codable, Identifiable, Hashable {
    let id: String
    let topic: String
    let scheduledAt: String
    let status: String
    let participantCount: Int
    let startedAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, scheduledAt, status, participantCount, startedAt, completedAt
    }

    static func == (lhs: LiveEvent, rhs: LiveEvent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct LobbyJoinResponse: Codable {
    let alreadyJoined: Bool
    let participantCount: Int
}

struct LobbyState: Codable {
    let status: String
    let participantCount: Int
    let scheduledAt: String
    let topic: String
}

struct LiveQuestionResponse: Codable {
    let questionIndex: Int?
    let questionText: String?
    let questionType: String?
    let difficulty: String?
    let options: [ChallengeOption]?
    let timeLimit: Int?
    let timeRemaining: Double?
    let totalQuestions: Int?
    let eventComplete: Bool
}

struct LiveQuestionResults: Codable {
    let correctPercentage: Int
    let totalAnswered: Int
}

struct LiveEventResults: Codable {
    let event: LiveEventWithLeaderboard
    let attempt: LiveEventAttemptResult?
}

struct LiveEventWithLeaderboard: Codable {
    let id: String
    let topic: String
    let leaderboard: [LiveLeaderboardEntry]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, leaderboard
    }
}

struct LiveLeaderboardEntry: Codable, Identifiable {
    let userId: LeaderboardUser
    let handicappedScore: Double
    let rawScore: Double
    let rank: Int

    var id: String { userId.id }
}

struct LiveEventAttemptResult: Codable {
    let rawScore: Double?
    let handicappedScore: Double?
    let timeTaken: Double?
    let rank: Int?
}
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Models/Competition.swift
git commit -m "feat(competition): add iOS models for challenges, leaderboards, live events"
```

---

### Task 8: iOS — Competition Service

**Files:**
- Create: `ScaleUp/Features/Competition/Services/CompetitionService.swift`

- [ ] **Step 1: Create competition service with endpoints**

```swift
// ScaleUp/Features/Competition/Services/CompetitionService.swift
import Foundation

// MARK: - Competition Endpoints

enum CompetitionEndpoints: Endpoint {
    case todayChallenges
    case challengeDetail(id: String)
    case startChallenge(id: String)
    case submitAnswer(id: String)
    case completeChallenge(id: String)
    case challengeResults(id: String)
    case weeklyLeaderboard
    case allTimeLeaderboard
    case competitionProfile
    case competitionStats
    case upcomingEvents
    case eventDetail(id: String)
    case joinLobby(id: String)
    case lobbyState(id: String)
    case currentQuestion(id: String)
    case submitLiveAnswer(id: String)
    case questionResults(id: String, questionIndex: Int)
    case eventResults(id: String)

    var path: String {
        switch self {
        case .todayChallenges: return "/competition/challenges/today"
        case .challengeDetail(let id): return "/competition/challenges/\(id)"
        case .startChallenge(let id): return "/competition/challenges/\(id)/start"
        case .submitAnswer(let id): return "/competition/challenges/\(id)/answer"
        case .completeChallenge(let id): return "/competition/challenges/\(id)/complete"
        case .challengeResults(let id): return "/competition/challenges/\(id)/results"
        case .weeklyLeaderboard: return "/competition/leaderboard/weekly"
        case .allTimeLeaderboard: return "/competition/leaderboard/alltime"
        case .competitionProfile: return "/competition/profile"
        case .competitionStats: return "/competition/stats"
        case .upcomingEvents: return "/competition/live-events/upcoming"
        case .eventDetail(let id): return "/competition/live-events/\(id)"
        case .joinLobby(let id): return "/competition/live-events/\(id)/join"
        case .lobbyState(let id): return "/competition/live-events/\(id)/lobby"
        case .currentQuestion(let id): return "/competition/live-events/\(id)/question"
        case .submitLiveAnswer(let id): return "/competition/live-events/\(id)/answer"
        case .questionResults(let id, let qi): return "/competition/live-events/\(id)/question-results"
        case .eventResults(let id): return "/competition/live-events/\(id)/results"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .startChallenge, .completeChallenge, .joinLobby:
            return .post
        case .submitAnswer, .submitLiveAnswer:
            return .put
        default:
            return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .questionResults(_, let qi):
            return [URLQueryItem(name: "questionIndex", value: "\(qi)")]
        default:
            return nil
        }
    }
}

// MARK: - Request Bodies

struct ChallengeAnswerBody: Encodable {
    let questionIndex: Int
    let selectedAnswer: String
    let timeSpent: Double
}

// MARK: - Competition Service

actor CompetitionService {
    private let api = APIClient.shared

    // Daily Challenges
    func fetchTodayChallenges() async throws -> [DailyChallenge] {
        try await api.request(CompetitionEndpoints.todayChallenges)
    }

    func startChallenge(id: String) async throws -> ChallengeStartResponse {
        try await api.request(CompetitionEndpoints.startChallenge(id: id))
    }

    func submitAnswer(challengeId: String, questionIndex: Int, selectedAnswer: String, timeSpent: Double) async throws -> [String: Int] {
        let body = ChallengeAnswerBody(questionIndex: questionIndex, selectedAnswer: selectedAnswer, timeSpent: timeSpent)
        return try await api.request(CompetitionEndpoints.submitAnswer(id: challengeId), body: body)
    }

    func completeChallenge(id: String) async throws -> ChallengeResult {
        try await api.request(CompetitionEndpoints.completeChallenge(id: id))
    }

    // Leaderboard
    func fetchWeeklyLeaderboard(topic: String? = nil) async throws -> WeeklyLeaderboard {
        try await api.request(CompetitionEndpoints.weeklyLeaderboard)
    }

    // Profile & Stats
    func fetchCompetitionProfile() async throws -> CompetitionProfile {
        try await api.request(CompetitionEndpoints.competitionProfile)
    }

    func fetchCompetitionStats() async throws -> CompetitionStats {
        try await api.request(CompetitionEndpoints.competitionStats)
    }

    // Live Events
    func fetchUpcomingEvents() async throws -> [LiveEvent] {
        try await api.request(CompetitionEndpoints.upcomingEvents)
    }

    func joinLobby(eventId: String) async throws -> LobbyJoinResponse {
        try await api.request(CompetitionEndpoints.joinLobby(id: eventId))
    }

    func fetchLobbyState(eventId: String) async throws -> LobbyState {
        try await api.request(CompetitionEndpoints.lobbyState(id: eventId))
    }

    func fetchCurrentQuestion(eventId: String) async throws -> LiveQuestionResponse {
        try await api.request(CompetitionEndpoints.currentQuestion(id: eventId))
    }

    func submitLiveAnswer(eventId: String, questionIndex: Int, selectedAnswer: String, timeSpent: Double) async throws -> [String: Int] {
        let body = ChallengeAnswerBody(questionIndex: questionIndex, selectedAnswer: selectedAnswer, timeSpent: timeSpent)
        return try await api.request(CompetitionEndpoints.submitLiveAnswer(id: eventId), body: body)
    }

    func fetchQuestionResults(eventId: String, questionIndex: Int) async throws -> LiveQuestionResults {
        try await api.request(CompetitionEndpoints.questionResults(id: eventId, questionIndex: questionIndex))
    }

    func fetchEventResults(eventId: String) async throws -> LiveEventResults {
        try await api.request(CompetitionEndpoints.eventResults(id: eventId))
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Competition/Services/CompetitionService.swift
git commit -m "feat(competition): add iOS competition service with all endpoints"
```

---

### Task 9: iOS — Challenge ViewModels

**Files:**
- Create: `ScaleUp/Features/Competition/ViewModels/ChallengeViewModel.swift`
- Create: `ScaleUp/Features/Competition/ViewModels/LeaderboardViewModel.swift`
- Create: `ScaleUp/Features/Competition/ViewModels/LiveEventViewModel.swift`

- [ ] **Step 1: Create ChallengeViewModel**

This manages the daily challenge session — fetching questions, tracking answers, submitting, handling background detection and tiered timers.

Key properties: `questions`, `currentQuestionIndex`, `timeRemaining`, `answers`, `isComplete`, `result`. Key methods: `startChallenge()`, `submitAnswer()`, `completeChallenge()`, `handleBackgroundDetection()`.

Follow the pattern from `QuizSessionViewModel.swift` — `@Observable @MainActor`, timer via `Task.sleep`, background detection via `NotificationCenter` for `UIApplication.didEnterBackgroundNotification`.

- [ ] **Step 2: Create LeaderboardViewModel**

Manages leaderboard data, stats strip, weekly board. Properties: `stats`, `weeklyBoard`, `isLoading`. Methods: `loadStats()`, `loadLeaderboard()`.

- [ ] **Step 3: Create LiveEventViewModel**

Manages live event lifecycle — lobby polling, question sync, results. Properties: `event`, `lobbyState`, `currentQuestion`, `isInLobby`, `isLive`, `participantCount`. Methods: `joinLobby()`, `pollLobbyState()`, `pollCurrentQuestion()`, `submitAnswer()`.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Competition/ViewModels/
git commit -m "feat(competition): add challenge, leaderboard, and live event view models"
```

---

### Task 10: iOS — Daily Challenge Carousel & Home Integration

**Files:**
- Create: `ScaleUp/Features/Competition/Views/DailyChallengeCarousel.swift`
- Modify: `ScaleUp/Features/Home/Views/HomeView.swift`
- Modify: `ScaleUp/Features/Home/ViewModels/HomeViewModel.swift`

- [ ] **Step 1: Create DailyChallengeCarousel view**

Swipeable horizontal carousel using `TabView` with `.tabViewStyle(.page)`. Each card shows: LIVE badge (gold pill), trophy emoji, topic name, "10 Qs · {count} playing · Ends midnight", gold gradient CTA button. Completed cards: green border, score/percentile/accuracy stats bar, Share/View Board CTAs. Live event cards: purple border, "LIVE EVENT" badge, countdown timer, "Join →" CTA.

Objective topics appear first in the carousel with a "Your Goal" micro-badge.

- [ ] **Step 2: Add challenge data to HomeViewModel**

Add to `HomeViewModel`:
- `todayChallenges: [DailyChallenge] = []`
- `upcomingEvents: [LiveEvent] = []`
- `competitionStats: CompetitionStats?`
- `private let competitionService = CompetitionService()`
- Load in `loadDashboard()` alongside existing calls

- [ ] **Step 3: Integrate carousel into HomeView**

Insert `DailyChallengeCarousel` between the header and the content feed in `mainContent`. Add navigation destinations for `ChallengeSessionView` and `LiveEventLobbyView`.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Competition/Views/DailyChallengeCarousel.swift ScaleUp/Features/Home/Views/HomeView.swift ScaleUp/Features/Home/ViewModels/HomeViewModel.swift
git commit -m "feat(competition): add daily challenge carousel to Home tab"
```

---

### Task 11: iOS — Challenge Session & Results Views

**Files:**
- Create: `ScaleUp/Features/Competition/Views/ChallengeSessionView.swift`
- Create: `ScaleUp/Features/Competition/Views/ChallengeResultsView.swift`
- Create: `ScaleUp/Features/Competition/Views/ShareScoreCardView.swift`

- [ ] **Step 1: Create ChallengeSessionView**

Reuses layout patterns from `QuizSessionView`. Key differences: no skip button, tiered timer bar with gold accent, no back button, background detection auto-submits, question counter "Q 4/10".

- [ ] **Step 2: Create ChallengeResultsView**

Animated handicapped score reveal, personal best comparison, live rank/percentile, question review (expandable), three CTAs: Share Score / View Leaderboard / Done.

- [ ] **Step 3: Create ShareScoreCardView**

SwiftUI view for share card image generation. Dark gradient background, ScaleUp wordmark, date + topic, gold-bordered circle with score, percentile + accuracy, "Can you beat my score?" CTA. Uses `ImageRenderer` to produce `UIImage` for sharing via `UIActivityViewController`.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Competition/Views/ChallengeSessionView.swift ScaleUp/Features/Competition/Views/ChallengeResultsView.swift ScaleUp/Features/Competition/Views/ShareScoreCardView.swift
git commit -m "feat(competition): add challenge session, results, and share card views"
```

---

### Task 12: iOS — Leaderboard & Progress Integration

**Files:**
- Create: `ScaleUp/Features/Competition/Views/LeaderboardView.swift`
- Create: `ScaleUp/Features/Competition/Views/CompetitionStatsSection.swift`
- Modify: `ScaleUp/Features/Progress/ProgressTabView.swift`
- Modify: `ScaleUp/Features/Progress/ViewModels/ProgressViewModel.swift`

- [ ] **Step 1: Create LeaderboardView**

Full leaderboard pushed from "See Full Board". Segmented control: Global / per-topic. Tab bar: This Week / Last Week / All Time. Your row pinned at top with "You" label. Each row: rank, avatar, name, handicapped score, challenges completed, trend arrow. Pull to refresh.

- [ ] **Step 2: Create CompetitionStatsSection**

Stats strip (horizontal scroll chips) + weekly leaderboard preview card. Matches existing Progress tab styling.

- [ ] **Step 3: Integrate into ProgressTabView**

Add `CompetitionStatsSection` at the top of the Progress tab, above topic mastery. Add `competitionStats` and `weeklyBoard` to `ProgressViewModel`.

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Competition/Views/LeaderboardView.swift ScaleUp/Features/Competition/Views/CompetitionStatsSection.swift ScaleUp/Features/Progress/ProgressTabView.swift ScaleUp/Features/Progress/ViewModels/ProgressViewModel.swift
git commit -m "feat(competition): add leaderboard view and competition stats to Progress tab"
```

---

### Task 13: iOS — Live Event Views

**Files:**
- Create: `ScaleUp/Features/Competition/Views/LiveEventLobbyView.swift`
- Create: `ScaleUp/Features/Competition/Views/LiveEventSessionView.swift`
- Create: `ScaleUp/Features/Competition/Views/LiveEventResultsView.swift`

- [ ] **Step 1: Create LiveEventLobbyView**

Topic name, participant count (poll every 3s), countdown timer, participant avatars, rules reminder, "Leave Lobby" option. Purple gradient theme.

- [ ] **Step 2: Create LiveEventSessionView**

Synchronized quiz view. "LIVE" indicator with pulse animation, participant count, tiered timers, after each question: brief results overlay (2-3s) showing correct %, your rank so far. Poll `/question` every 2s for current question.

- [ ] **Step 3: Create LiveEventResultsView**

Full leaderboard (all participants), your highlighted row, question-by-question review, "Share Live Results" with purple-themed share card, "Next Live Event: Wednesday 8 PM — Finance".

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Competition/Views/LiveEventLobbyView.swift ScaleUp/Features/Competition/Views/LiveEventSessionView.swift ScaleUp/Features/Competition/Views/LiveEventResultsView.swift
git commit -m "feat(competition): add live event lobby, session, and results views"
```

---

### Task 14: iOS — Navigation & Deep Links

**Files:**
- Modify: `ScaleUp/App/MainTabView.swift`
- Modify: `ScaleUp/Core/PushNotificationManager.swift`

- [ ] **Step 1: Add navigation destinations to MainTabView**

Add `.navigationDestination` for competition-related hashable types: `DailyChallenge`, `LiveEvent`, `LeaderboardDestination`.

- [ ] **Step 2: Handle competition deep links in PushNotificationManager**

In `handleNotification()`, parse competition-specific deep link types: `challenge_live`, `weekly_results`, `live_event_reminder`, `streak_reminder`. Return appropriate deep link strings that the app can route.

- [ ] **Step 3: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/App/MainTabView.swift ScaleUp/Core/PushNotificationManager.swift
git commit -m "feat(competition): add navigation destinations and deep link handling"
```

---

### Task 15: Backend — Deploy & Verify

- [ ] **Step 1: Verify all backend files are committed**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend"
git status
git log --oneline -10
```

- [ ] **Step 2: Push to GitHub to trigger deploy**

```bash
git push origin master
```

- [ ] **Step 3: Verify deployment succeeded**

Check GitHub Actions for successful deploy. Test key endpoints:

```bash
curl -s http://15.207.72.150:5000/api/v1/competition/challenges/today -H "Authorization: Bearer <token>" | head -c 200
```

- [ ] **Step 4: Test admin generation endpoint**

```bash
curl -s -X POST http://15.207.72.150:5000/api/v1/competition/admin/challenges/generate -H "Authorization: Bearer <admin_token>" | head -c 200
```

---

### Task 16: iOS — Build & Verify

- [ ] **Step 1: Verify project structure**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
ls -la ScaleUp/Features/Competition/
ls -la ScaleUp/Features/Competition/Views/
ls -la ScaleUp/Features/Competition/ViewModels/
ls -la ScaleUp/Features/Competition/Services/
```

- [ ] **Step 2: Add files to Xcode project**

If using XcodeGen:
```bash
xcodegen generate
```

Otherwise, ensure all new files are added to the Xcode project target.

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme ScaleUp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Fix any build errors.

- [ ] **Step 4: Commit any fixes**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add -A
git commit -m "fix(competition): resolve build errors"
```
