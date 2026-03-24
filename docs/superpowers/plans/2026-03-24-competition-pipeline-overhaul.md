# Competition Pipeline Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the manual, cost-explosive competition pipeline with a fully automated daily generation system scoped to user objectives.

**Architecture:** Rewrite `challengeGenerationService.js` to generate 15 questions per objective daily via a single GPT-4o call (scoped by `UserObjective` + sub-topic union from `KnowledgeProfile`). Merge all competition cron jobs into a single `generateAndActivateDaily` job. Simplify scoring to remove difficulty weights. Update iOS to show objective-scoped leaderboards with "This Week" / "All Time" tabs.

**Tech Stack:** Node.js/Express, MongoDB/Mongoose, BullMQ/Redis, OpenAI GPT-4o, SwiftUI (iOS)

**Spec:** `docs/superpowers/specs/2026-03-24-competition-pipeline-overhaul-design.md`

---

## File Structure

### Backend (modify)
- `src/services/challengeGenerationService.js` — **Rewrite**: new `generateAndActivateDaily()` replacing `generateWeeklyCandidates()`, `autoAssignQuestions()`, `activateDailyChallenge()`
- `src/services/competitionService.js` — **Modify**: simplify scoring (remove difficulty weights), fix `getAllTimeLeaderboard()` to include current week, update `completeChallenge()` scoring
- `src/workers/competitionWorker.js` — **Modify**: replace `generateWeeklyCandidates` + `activateDailyChallenge` cases with single `generateAndActivateDaily`, add `completeLiveEventSafety`
- `src/workers/cronJobs.js` — **Modify**: replace competition crons (lines 60-106) with new schedule
- `src/models/DailyChallenge.js` — **Modify**: change question count validator from 10 to 15, add `timeLimitSeconds`, remove `difficulty` from question schema, remove `createdFrom`
- `src/controllers/competitionController.js` — **Modify**: update `startChallenge` response to remove per-question time limits

### Backend (create)
- `src/utils/normalizeTopic.js` — **Create**: shared topic normalization utility
- `scripts/normalize-topics.js` — **Create**: one-time migration script

### iOS (modify)
- `ScaleUp/Models/Competition.swift` — **Modify**: add `timeLimitSeconds` to `DailyChallenge`, remove `difficulty`/`timeLimit` from `ChallengeQuestion`
- `ScaleUp/Features/Competition/Views/LeaderboardView.swift` — **Modify**: replace Global/ByTopic filter with objective-scoped default, connect scope picker to API
- `ScaleUp/Features/Competition/ViewModels/LeaderboardViewModel.swift` — **Modify**: add `loadAllTimeLeaderboard()`, load user's objective topic
- `ScaleUp/Features/Competition/Services/CompetitionService.swift` — **Modify**: pass `topic` query param to leaderboard endpoints, add `fetchAllTimeLeaderboard()`

---

## Task 1: Create topic normalization utility

**Files:**
- Create: `src/utils/normalizeTopic.js`

- [ ] **Step 1: Create the utility**

```javascript
// src/utils/normalizeTopic.js
function normalizeTopic(topic) {
  if (!topic || typeof topic !== 'string') return '';
  return topic.trim().toLowerCase();
}

module.exports = normalizeTopic;
```

- [ ] **Step 2: Commit**

```bash
git add src/utils/normalizeTopic.js
git commit -m "feat(competition): add normalizeTopic utility"
```

---

## Task 2: Create topic normalization migration script

**Files:**
- Create: `scripts/normalize-topics.js`

- [ ] **Step 1: Write the migration script**

```javascript
// scripts/normalize-topics.js
require('dotenv').config();
const mongoose = require('mongoose');

async function migrate() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to MongoDB');

  const db = mongoose.connection.db;

  // Simple field normalization for these collections
  const simpleCollections = [
    { name: 'dailychallenges', field: 'topic' },
    { name: 'weeklyleaderboards', field: 'topic' },
    { name: 'liveevents', field: 'topic' },
    { name: 'challengecandidatebanks', field: 'topic' },
  ];

  for (const { name, field } of simpleCollections) {
    const result = await db.collection(name).updateMany(
      {},
      [{ $set: { [field]: { $toLower: { $trim: { input: `$${field}` } } } } }]
    );
    console.log(`${name}.${field}: ${result.modifiedCount} normalized`);
  }

  // KnowledgeProfile.topicMastery — array of objects with .topic field
  const profiles = await db.collection('knowledgeprofiles').find({}).toArray();
  let kpCount = 0;
  for (const profile of profiles) {
    if (!profile.topicMastery || !Array.isArray(profile.topicMastery)) continue;
    let changed = false;
    for (const entry of profile.topicMastery) {
      if (entry.topic && entry.topic !== entry.topic.trim().toLowerCase()) {
        entry.topic = entry.topic.trim().toLowerCase();
        changed = true;
      }
    }
    if (changed) {
      await db.collection('knowledgeprofiles').updateOne(
        { _id: profile._id },
        { $set: { topicMastery: profile.topicMastery } }
      );
      kpCount++;
    }
  }
  console.log(`knowledgeprofiles.topicMastery: ${kpCount} normalized`);

  // UserObjective.topicsOfInterest — already has lowercase:true in schema but normalize existing data
  const objectives = await db.collection('userobjectives').find({}).toArray();
  let uoCount = 0;
  for (const obj of objectives) {
    if (!obj.topicsOfInterest || !Array.isArray(obj.topicsOfInterest)) continue;
    const normalized = obj.topicsOfInterest.map(t => t.trim().toLowerCase());
    const changed = obj.topicsOfInterest.some((t, i) => t !== normalized[i]);
    if (changed) {
      await db.collection('userobjectives').updateOne(
        { _id: obj._id },
        { $set: { topicsOfInterest: normalized } }
      );
      uoCount++;
    }
  }
  console.log(`userobjectives.topicsOfInterest: ${uoCount} normalized`);

  console.log('Migration complete');
  await mongoose.disconnect();
}

migrate().catch(err => { console.error(err); process.exit(1); });
```

- [ ] **Step 2: Commit**

```bash
git add scripts/normalize-topics.js
git commit -m "feat(competition): add topic normalization migration script"
```

---

## Task 3: Update DailyChallenge model

**Files:**
- Modify: `src/models/DailyChallenge.js`

- [ ] **Step 1: Update the schema**

Changes:
1. Remove `difficulty` from `challengeQuestionSchema` (line 16)
2. Change question count validator from `arr.length === 10` to `arr.length === 15` (line 23)
3. Add `timeLimitSeconds` field with default 720
4. Remove `createdFrom` field (line 26)

The updated file:

```javascript
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
  concept: { type: String },
}, { _id: true });

const dailyChallengeSchema = new mongoose.Schema({
  topic: { type: String, required: true, index: true },
  date: { type: Date, required: true, index: true },
  questions: { type: [challengeQuestionSchema], validate: [arr => arr.length === 15, 'Must have exactly 15 questions'] },
  status: { type: String, enum: ['active', 'closed'], default: 'active' },
  participantCount: { type: Number, default: 0 },
  timeLimitSeconds: { type: Number, default: 720 },
  activatesAt: { type: Date },
  closesAt: { type: Date },
}, { timestamps: true });

dailyChallengeSchema.index({ topic: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('DailyChallenge', dailyChallengeSchema);
```

- [ ] **Step 2: Commit**

```bash
git add src/models/DailyChallenge.js
git commit -m "feat(competition): update DailyChallenge for 15 questions, remove difficulty"
```

---

## Task 4: Rewrite challengeGenerationService.js

This is the core change. Replace the entire file with the new on-demand daily generation pipeline.

**Files:**
- Modify: `src/services/challengeGenerationService.js`

- [ ] **Step 1: Rewrite the service**

```javascript
// src/services/challengeGenerationService.js
const openai = require('../config/openai');
const DailyChallenge = require('../models/DailyChallenge');
const LiveEvent = require('../models/LiveEvent');
const UserObjective = require('../models/UserObjective');
const KnowledgeProfile = require('../models/KnowledgeProfile');
const normalizeTopic = require('../utils/normalizeTopic');

const GENERATION_PROMPT = `You are an expert educational assessment creator for competitive daily quizzes.

Generate questions for a daily learning challenge. These questions will be the SAME for all participants, so they must be:
1. Unambiguous — exactly one clearly correct answer
2. Self-contained — no external context needed
3. Fair — testable through reasoning, not obscure memorization
4. Varied — mix of recall, application, and analytical questions
5. Exactly 4 options (A, B, C, D)
6. Conceptual only — no code snippets or programming output questions
7. Naturally varied in complexity — some straightforward, some requiring deeper thinking

CRITICAL: Generate EXACTLY the number of questions specified. Not fewer, not more.

Return valid JSON with a "questions" array where each question has:
- questionText, questionType (recall | application | conceptual | critical_thinking),
  options (array of {label, text}), correctAnswer (A/B/C/D),
  explanation, concept`;

const MAX_SUBTOPICS = 20;
const MAX_RETRIES = 2;

class ChallengeGenerationService {

  /**
   * Main daily pipeline — called by the single midnight cron job.
   * Generates and activates daily challenges for all active objectives.
   * On Sun/Tue/Thu, also creates live events for the next day.
   */
  async generateAndActivateDaily() {
    const results = { daily: [], liveEvents: [], errors: [] };

    // 1. Get distinct active objectives
    const objectives = await this._getActiveObjectives();
    console.log(`[ChallengeGen] ${objectives.length} active objectives found`);

    // 2. Close yesterday's challenges
    const yesterday = this._dateOffset(-1);
    await DailyChallenge.updateMany(
      { date: yesterday, status: 'active' },
      { status: 'closed' }
    );

    const today = this._todayIST();

    // 3. Generate and activate daily challenge for each objective
    for (const objective of objectives) {
      try {
        const subTopics = await this._getSubTopicsForObjective(objective);
        const exclusions = await this._getLast7DaysQuestions(objective);
        const questions = await this._generateQuestions(objective, subTopics, exclusions, 15);

        const challenge = await DailyChallenge.create({
          topic: objective,
          date: today,
          questions,
          status: 'active',
          timeLimitSeconds: 720,
          activatesAt: today,
          closesAt: new Date(today.getTime() + 24 * 60 * 60 * 1000 - 1),
        });

        results.daily.push({ topic: objective, challengeId: challenge._id });
        console.log(`[ChallengeGen] Daily challenge created for "${objective}"`);
      } catch (err) {
        console.error(`[ChallengeGen] Daily failed for "${objective}":`, err.message);
        results.errors.push({ topic: objective, type: 'daily', error: err.message });
      }
    }

    // 4. If eve of live event day (Sun/Tue/Thu), create live events for tomorrow
    const dayOfWeek = this._getDayOfWeekIST(); // 0=Sun, 1=Mon, ...
    const isLiveEventEve = [0, 2, 4].includes(dayOfWeek); // Sun, Tue, Thu

    if (isLiveEventEve) {
      const tomorrow = this._dateOffset(1);
      const tomorrowAt8PM = new Date(tomorrow);
      tomorrowAt8PM.setUTCHours(14, 30, 0, 0); // 8 PM IST = 14:30 UTC

      for (const objective of objectives) {
        try {
          const subTopics = await this._getSubTopicsForObjective(objective);
          // Include today's daily questions in exclusions too
          const todayChallenge = await DailyChallenge.findOne({ topic: objective, date: today });
          const exclusions = await this._getLast7DaysQuestions(objective);
          if (todayChallenge) {
            exclusions.push(...todayChallenge.questions.map(q => q.questionText));
          }

          const questions = await this._generateQuestions(objective, subTopics, exclusions, 15);

          const event = await LiveEvent.create({
            topic: objective,
            scheduledAt: tomorrowAt8PM,
            questions,
            status: 'scheduled',
          });

          results.liveEvents.push({ topic: objective, eventId: event._id });
          console.log(`[ChallengeGen] Live event created for "${objective}" at ${tomorrowAt8PM.toISOString()}`);
        } catch (err) {
          console.error(`[ChallengeGen] Live event failed for "${objective}":`, err.message);
          results.errors.push({ topic: objective, type: 'liveEvent', error: err.message });
        }
      }
    }

    return results;
  }

  // --- Private helpers ---

  async _getActiveObjectives() {
    const raw = await UserObjective.distinct('topicsOfInterest', { status: 'active' });
    // topicsOfInterest is an array field, distinct flattens it
    const normalized = [...new Set(raw.map(normalizeTopic).filter(Boolean))];
    return normalized;
  }

  async _getSubTopicsForObjective(objective) {
    // Find all users who have this objective topic
    const userObjectives = await UserObjective.find(
      { topicsOfInterest: objective, status: 'active' },
      { userId: 1 }
    ).lean();
    const userIds = userObjectives.map(o => o.userId);

    if (userIds.length === 0) return [objective];

    // Get union of all sub-topics from KnowledgeProfiles
    const profiles = await KnowledgeProfile.find(
      { userId: { $in: userIds } },
      { 'topicMastery.topic': 1 }
    ).lean();

    const topicCounts = {};
    for (const profile of profiles) {
      if (!profile.topicMastery) continue;
      for (const entry of profile.topicMastery) {
        const t = normalizeTopic(entry.topic);
        if (t) topicCounts[t] = (topicCounts[t] || 0) + 1;
      }
    }

    // Sort by frequency, cap at MAX_SUBTOPICS
    const sorted = Object.entries(topicCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, MAX_SUBTOPICS)
      .map(([topic]) => topic);

    return sorted.length > 0 ? sorted : [objective];
  }

  async _getLast7DaysQuestions(objective) {
    const sevenDaysAgo = this._dateOffset(-7);
    const challenges = await DailyChallenge.find({
      topic: objective,
      date: { $gte: sevenDaysAgo },
    }).lean();

    return challenges.flatMap(c => c.questions.map(q => q.questionText));
  }

  async _generateQuestions(objective, subTopics, exclusions, count) {
    const subTopicStr = subTopics.join(', ');
    const exclusionStr = exclusions.length > 0
      ? `\n\nDo NOT repeat any of these previously used questions:\n${exclusions.map((q, i) => `${i + 1}. ${q}`).join('\n')}`
      : '';

    const userMessage = JSON.stringify({
      topic: objective,
      subTopics: subTopicStr,
      questionCount: count,
    }) + exclusionStr;

    let lastError = null;

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        if (attempt > 0) {
          const delay = attempt === 1 ? 1000 : 3000;
          await new Promise(r => setTimeout(r, delay));
          console.log(`[ChallengeGen] Retry ${attempt} for "${objective}"`);
        }

        const response = await openai.chat.completions.create({
          model: 'gpt-4o',
          messages: [
            { role: 'system', content: GENERATION_PROMPT },
            { role: 'user', content: userMessage },
          ],
          response_format: { type: 'json_object' },
          temperature: 0.7,
          max_tokens: count * 500,
        });

        const parsed = JSON.parse(response.choices[0].message.content);
        if (!parsed.questions || !Array.isArray(parsed.questions) || parsed.questions.length < count) {
          throw new Error(`Expected ${count} questions, got ${parsed.questions?.length || 0}`);
        }

        return parsed.questions.slice(0, count);
      } catch (err) {
        lastError = err;
        console.error(`[ChallengeGen] Attempt ${attempt + 1} failed for "${objective}":`, err.message);
      }
    }

    throw new Error(`All ${MAX_RETRIES + 1} generation attempts failed for "${objective}": ${lastError?.message}`);
  }

  // --- Date helpers ---

  _todayIST() {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);
    return new Date(Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate()));
  }

  _dateOffset(days) {
    const today = this._todayIST();
    return new Date(today.getTime() + days * 24 * 60 * 60 * 1000);
  }

  _getDayOfWeekIST() {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);
    return istNow.getUTCDay();
  }
}

module.exports = new ChallengeGenerationService();
```

- [ ] **Step 2: Commit**

```bash
git add src/services/challengeGenerationService.js
git commit -m "feat(competition): rewrite generation service for daily on-demand pipeline"
```

---

## Task 5: Simplify scoring in competitionService.js

**Files:**
- Modify: `src/services/competitionService.js`

- [ ] **Step 1: Update scoring constants and methods**

Remove `DIFFICULTY_WEIGHTS` and `TIERED_TIME_LIMITS` constants (lines 10, 12). Keep `LEVEL_BONUS`.

Replace `calculateHandicappedScore` (line 46-50) with simplified scoring:

```javascript
// Old (line 46-50):
calculateHandicappedScore(rawScore, questions, userLevel) {
  const avgDifficulty = questions.reduce((sum, q) => sum + (DIFFICULTY_WEIGHTS[q.difficulty] || 1.0), 0) / questions.length;
  const levelBonus = LEVEL_BONUS[userLevel] || 1.0;
  return rawScore * avgDifficulty * levelBonus;
}

// New:
calculateScore(correctAnswers, userLevel) {
  const levelBonus = LEVEL_BONUS[userLevel] || 1.0;
  return correctAnswers * levelBonus;
}
```

- [ ] **Step 2: Update completeChallenge method (lines 118-176)**

Key changes:
- Use raw correct count instead of percentage-based rawScore
- Call new `calculateScore()` instead of `calculateHandicappedScore()`
- Get userLevel from `CompetitionProfile` (fallback to KnowledgeProfile, then 'beginner')

Replace lines 128-139 with:

```javascript
    let correct = 0;
    for (const answer of attempt.answers) {
      const origQuestionIdx = attempt.questionOrder[answer.questionIndex];
      const question = challenge.questions[origQuestionIdx];
      const optOrder = attempt.optionOrders[answer.questionIndex];
      const answerIdx = ['A', 'B', 'C', 'D'].indexOf(answer.selectedAnswer);
      const originalLabel = optOrder[answerIdx];
      if (originalLabel === question.correctAnswer) correct++;
    }

    // Simplified scoring: correctAnswers × levelBonus
    const topicMastery = profile?.topicMastery?.find(t => t.topic === challenge.topic);
    const userLevel = topicMastery?.level || 'beginner';
    const baseScore = this.calculateScore(correct, userLevel);
    const timeTaken = attempt.answers.reduce((sum, a) => sum + (a.timeSpent || 0), 0);
```

Update the attempt save and leaderboard update to use `baseScore` instead of `handicappedScore`.

- [ ] **Step 3: Update getAllTimeLeaderboard to include current week (lines 282-311)**

Replace the query at line 283-286 with:

```javascript
  async getAllTimeLeaderboard(topic) {
    const currentWeekStart = this._currentWeekStartIST();
    const boards = await WeeklyLeaderboard.find({
      topic: topic || 'global',
      $or: [
        { finalized: true },
        { weekStart: currentWeekStart },
      ],
    });
    // ... rest of aggregation stays the same
```

- [ ] **Step 4: Update startChallenge response (lines 90-105)**

Remove `difficulty` and per-question `timeLimit` from the response. The response now returns `timeLimitSeconds` from the challenge instead:

Replace line 98-102 (the randomizedQuestions mapping) to remove difficulty/timeLimit:

```javascript
    const randomizedQuestions = questionOrder.map((origIdx, newIdx) => {
      const q = challenge.questions[origIdx];
      const optOrder = optionOrders[newIdx];
      const shuffledOptions = optOrder.map(label => q.options.find(o => o.label === label));
      return {
        questionIndex: newIdx,
        questionText: q.questionText,
        questionType: q.questionType,
        concept: q.concept,
        options: shuffledOptions.map((opt, i) => ({ label: ['A', 'B', 'C', 'D'][i], text: opt.text })),
      };
    });

    return { attemptId: attempt._id, questions: randomizedQuestions, timeLimitSeconds: challenge.timeLimitSeconds || 720 };
```

- [ ] **Step 5: Remove unused constants**

Delete lines 10 and 12:
```javascript
// DELETE: const DIFFICULTY_WEIGHTS = { easy: 0.8, medium: 1.0, hard: 1.3 };
// DELETE: const TIERED_TIME_LIMITS = { easy: 20, medium: 35, hard: 45 };
```

- [ ] **Step 6: Commit**

```bash
git add src/services/competitionService.js
git commit -m "feat(competition): simplify scoring, include current week in all-time leaderboard"
```

---

## Task 6: Update competitionWorker.js

**Files:**
- Modify: `src/workers/competitionWorker.js`

- [ ] **Step 1: Replace job cases**

Replace `generateWeeklyCandidates` case (lines 20-21) and `activateDailyChallenge` case (lines 23-37) with single `generateAndActivateDaily`:

```javascript
    case 'generateAndActivateDaily': {
      const result = await challengeGenerationService.generateAndActivateDaily();

      // Send notifications for activated daily challenges
      const UserObjective = require('../models/UserObjective');
      for (const { topic, challengeId } of result.daily) {
        const objectives = await UserObjective.find({ topicsOfInterest: topic, status: 'active' }, { userId: 1 }).lean();
        for (const obj of objectives) {
          await notificationQueue.add('send', {
            userId: obj.userId.toString(),
            title: "Today's Challenge is Live! ⚡",
            body: `Test your ${topic} skills — compete with other learners!`,
            data: { type: 'challenge_live', challengeId: challengeId.toString() },
          });
        }
      }

      if (result.errors.length > 0) {
        console.error('[CompetitionWorker] Generation errors:', JSON.stringify(result.errors));
        // Log is sufficient for now — Slack alerting deferred to future iteration
      }

      return result;
    }
```

- [ ] **Step 2: Update finalizeDailyRankings to use new scoring**

Replace the speed bonus calculation in `finalizeDailyRankings` (lines 39-63) to use the new proportional formula:

```javascript
    case 'finalizeDailyRankings': {
      const yesterday = new Date(competitionService._todayIST().getTime() - 24 * 60 * 60 * 1000);
      const challenges = await DailyChallenge.find({ date: yesterday, status: 'closed' });

      for (const challenge of challenges) {
        const attempts = await ChallengeAttempt.find({ challengeId: challenge._id, completedAt: { $ne: null } });
        if (attempts.length < 3) continue;

        const times = attempts.map(a => a.timeTaken || 0).filter(t => t > 0);
        if (times.length === 0) continue;
        const sorted = [...times].sort((a, b) => a - b);
        const medianTime = sorted[Math.floor(sorted.length / 2)];

        for (const attempt of attempts) {
          const userTime = attempt.timeTaken || 0;
          if (userTime <= 0 || userTime >= medianTime) continue;

          const speedFactor = Math.max(0, (medianTime - userTime) / medianTime);
          const baseScore = attempt.handicappedScore; // This is now baseScore (correctAnswers × levelBonus)
          const speedBonus = baseScore * 0.10 * speedFactor;

          attempt.handicappedScore += speedBonus;
          await attempt.save();

          // Update weekly leaderboard with adjusted score
          await competitionService._updateWeeklyLeaderboard(
            attempt.userId, challenge.topic, speedBonus
          );
        }
      }
      return { processed: challenges.length };
    }
```

- [ ] **Step 3: Update startLiveEvent to use fixed 20-min timer**

Replace the duration calculation in `startLiveEvent` (lines 145-148) — the old code calculated duration based on per-question difficulty time limits, which no longer exist:

```javascript
    case 'startLiveEvent': {
      const events = await LiveEvent.find({ status: 'lobby' });
      for (const event of events) {
        if (new Date() >= event.scheduledAt) {
          event.status = 'live';
          event.startedAt = new Date();
          await event.save();

          // Fixed 20-minute duration for all live events
          const { competitionQueue } = require('../config/queue');
          await competitionQueue.add('completeLiveEvent', { eventId: event._id.toString() }, {
            delay: 20 * 60 * 1000,
            removeOnComplete: true,
          });
        }
      }
      return { started: events.length };
    }
```

- [ ] **Step 4: Add completeLiveEventSafety case**

Add after the existing `completeLiveEvent` case:

```javascript
    case 'completeLiveEventSafety': {
      // Safety net: complete any events stuck in 'live' status
      const stuckEvents = await LiveEvent.find({ status: 'live' });
      let completed = 0;
      for (const event of stuckEvents) {
        try {
          await liveEventService.completeLiveEvent(event._id.toString());
          for (const entry of event.leaderboard?.slice(0, 3) || []) {
            await notificationQueue.add('send', {
              userId: entry.userId,
              title: 'Live Event Results! 🏆',
              body: `You finished #${entry.rank} out of ${event.leaderboard.length} in ${event.topic}`,
              data: { type: 'live_event_results', eventId: event._id.toString() },
            });
          }
          completed++;
        } catch (err) {
          console.error(`[CompetitionWorker] Safety complete failed for ${event._id}:`, err.message);
        }
      }
      return { completed };
    }
```

- [ ] **Step 5: Update liveEventReminder to use UserObjective instead of KnowledgeProfile**

Replace lines 182-183:

```javascript
    case 'liveEventReminder': {
      const events = await LiveEvent.find({
        status: 'scheduled',
        scheduledAt: {
          $gte: new Date(),
          $lte: new Date(Date.now() + 35 * 60 * 1000),
        },
      });
      for (const event of events) {
        const UserObjective = require('../models/UserObjective');
        const objectives = await UserObjective.find(
          { topicsOfInterest: event.topic, status: 'active' },
          { userId: 1 }
        ).lean();
        for (const obj of objectives) {
          await notificationQueue.add('send', {
            userId: obj.userId.toString(),
            title: 'Live Event Tonight! 🎯',
            body: `${event.topic} starts at 8 PM — don't miss it!`,
            data: { type: 'live_event_reminder', eventId: event._id.toString() },
          });
        }
      }
      return { reminded: events.length };
    }
```

- [ ] **Step 6: Commit**

```bash
git add src/workers/competitionWorker.js
git commit -m "feat(competition): update worker for daily pipeline, new scoring, safety cron"
```

---

## Task 7: Update cronJobs.js

**Files:**
- Modify: `src/workers/cronJobs.js` (lines 60-106)

- [ ] **Step 1: Replace competition cron entries**

Replace lines 60-106 with the new cron schedule:

```javascript
  // Competition: Generate + activate daily challenges (and live events on eve days)
  // Daily midnight IST = 18:30 UTC previous day
  competitionQueue.add('generateAndActivateDaily', {}, {
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

  // Competition: Safety net — complete stuck live events — Mon/Wed/Fri 20:20 IST (14:50 UTC)
  competitionQueue.add('completeLiveEventSafety', {}, {
    repeat: { pattern: '50 14 * * 1,3,5' },
    removeOnComplete: true,
  });
```

- [ ] **Step 2: Commit**

```bash
git add src/workers/cronJobs.js
git commit -m "feat(competition): replace cron schedule with new daily pipeline"
```

---

## Task 8: Update iOS Competition model

**Files:**
- Modify: `ScaleUp/Models/Competition.swift`

- [ ] **Step 1: Add timeLimitSeconds to DailyChallenge**

Add `timeLimitSeconds` to the `DailyChallenge` struct (after line 10):

```swift
struct DailyChallenge: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let topic: String
    let date: String
    let status: String
    let participantCount: Int
    let timeLimitSeconds: Int?
    let activatesAt: String?
    let closesAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, date, status, participantCount, timeLimitSeconds, activatesAt, closesAt
    }
}
```

- [ ] **Step 2: Update ChallengeStartResponse to include timeLimitSeconds**

```swift
struct ChallengeStartResponse: Codable, Sendable {
    let attemptId: String
    let questions: [ChallengeQuestion]
    let timeLimitSeconds: Int?
}
```

- [ ] **Step 3: Remove difficulty and timeLimit from ChallengeQuestion**

```swift
struct ChallengeQuestion: Codable, Sendable, Identifiable {
    let questionIndex: Int
    let questionText: String
    let questionType: String
    let concept: String?
    let options: [ChallengeOption]

    var id: Int { questionIndex }
}
```

- [ ] **Step 4: Commit**

```bash
git add ScaleUp/Models/Competition.swift
git commit -m "feat(competition): update iOS models for 15-question format"
```

---

## Task 9: Update iOS LeaderboardViewModel

**Files:**
- Modify: `ScaleUp/Features/Competition/ViewModels/LeaderboardViewModel.swift`

- [ ] **Step 1: Add objective-scoped loading and all-time support**

```swift
import SwiftUI

@Observable
@MainActor
final class LeaderboardViewModel {

    // MARK: - State

    var stats: CompetitionStats? = nil
    var weeklyBoard: WeeklyLeaderboard? = nil
    var allTimeEntries: [AllTimeEntry]? = nil
    var userObjectiveTopic: String? = nil
    var isLoading = false
    var error: String? = nil

    private let service = CompetitionService()

    // MARK: - Load All (default: user's objective topic)

    func loadAll() async {
        isLoading = true
        error = nil

        // Load user's primary objective topic first
        if userObjectiveTopic == nil {
            userObjectiveTopic = try? await service.fetchPrimaryObjectiveTopic()
        }

        let topic = userObjectiveTopic

        async let statsTask: CompetitionStats? = {
            try? await self.service.fetchCompetitionStats()
        }()
        async let boardTask: WeeklyLeaderboard? = {
            try? await self.service.fetchWeeklyLeaderboard(topic: topic)
        }()

        let (fetchedStats, fetchedBoard) = await (statsTask, boardTask)
        stats = fetchedStats
        weeklyBoard = fetchedBoard

        isLoading = false
    }

    // MARK: - Load Weekly

    func loadWeekly() async {
        isLoading = true
        do {
            weeklyBoard = try await service.fetchWeeklyLeaderboard(topic: userObjectiveTopic)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load All Time

    func loadAllTime() async {
        isLoading = true
        do {
            let result = try await service.fetchAllTimeLeaderboard(topic: userObjectiveTopic)
            allTimeEntries = result.entries
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ScaleUp/Features/Competition/ViewModels/LeaderboardViewModel.swift
git commit -m "feat(competition): update LeaderboardViewModel for objective-scoped loading"
```

---

## Task 10: Update iOS CompetitionService.swift

**Files:**
- Modify: `ScaleUp/Features/Competition/Services/CompetitionService.swift`

- [ ] **Step 1: Add topic query param to leaderboard endpoints and add alltime/objective endpoints**

Add new endpoint cases and update existing ones:

```swift
// Add to CompetitionEndpoints enum:
    case weeklyLeaderboardForTopic(topic: String?)
    case allTimeLeaderboardForTopic(topic: String?)
    case primaryObjectiveTopic

// Add path cases:
    case .weeklyLeaderboardForTopic: return "/competition/leaderboard/weekly"
    case .allTimeLeaderboardForTopic: return "/competition/leaderboard/alltime"
    case .primaryObjectiveTopic: return "/competition/objective-topic"

// Add queryItems:
    case .weeklyLeaderboardForTopic(let topic):
        if let t = topic { return [URLQueryItem(name: "topic", value: t)] }
        return nil
    case .allTimeLeaderboardForTopic(let topic):
        if let t = topic { return [URLQueryItem(name: "topic", value: t)] }
        return nil
```

Update CompetitionService actor methods:

```swift
    func fetchWeeklyLeaderboard(topic: String? = nil) async throws -> WeeklyLeaderboard {
        try await api.request(CompetitionEndpoints.weeklyLeaderboardForTopic(topic: topic))
    }

    func fetchAllTimeLeaderboard(topic: String? = nil) async throws -> AllTimeLeaderboardResponse {
        try await api.request(CompetitionEndpoints.allTimeLeaderboardForTopic(topic: topic))
    }

    func fetchPrimaryObjectiveTopic() async throws -> String? {
        struct ObjectiveResponse: Codable { let topic: String? }
        let result: ObjectiveResponse = try await api.request(CompetitionEndpoints.primaryObjectiveTopic)
        return result.topic
    }
```

Add the response model in Competition.swift:

```swift
struct AllTimeEntry: Codable, Sendable, Identifiable {
    let userId: LeaderboardUser
    let totalScore: Double
    let totalChallenges: Int
    let rank: Int

    var id: String { userId.id }
}

struct AllTimeLeaderboardResponse: Codable, Sendable {
    let entries: [AllTimeEntry]
    let topic: String
}
```

- [ ] **Step 2: Commit**

```bash
git add ScaleUp/Features/Competition/Services/CompetitionService.swift ScaleUp/Models/Competition.swift
git commit -m "feat(competition): add objective-scoped leaderboard endpoints to iOS service"
```

---

## Task 11: Update iOS LeaderboardView

**Files:**
- Modify: `ScaleUp/Features/Competition/Views/LeaderboardView.swift`

- [ ] **Step 1: Replace filter controls with scope-only picker**

Remove the `LeaderboardFilter` enum and the Global/ByTopic segmented control. Keep only `LeaderboardScope` (This Week / All Time). The leaderboard automatically shows the user's objective topic.

Replace `filterControls` (lines 69-90) with:

```swift
    private var filterControls: some View {
        VStack(spacing: Spacing.sm) {
            // Show which objective this leaderboard is for
            if let topic = viewModel.userObjectiveTopic {
                Text(topic.capitalized)
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(ColorTokens.gold)
            }

            // This Week / All Time
            Picker("Scope", selection: $selectedScope) {
                ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.lg)
            .onChange(of: selectedScope) { _, newScope in
                Task {
                    if newScope == .thisWeek {
                        await viewModel.loadWeekly()
                    } else {
                        await viewModel.loadAllTime()
                    }
                }
            }
        }
        .padding(.bottom, Spacing.md)
    }
```

- [ ] **Step 2: Update leaderboardContent to switch between weekly and all-time**

Replace `leaderboardContent` (lines 94-106) to handle both scopes:

```swift
    private var leaderboardContent: some View {
        Group {
            if viewModel.isLoading && viewModel.weeklyBoard == nil && viewModel.allTimeEntries == nil {
                loadingState
            } else if selectedScope == .thisWeek, let board = viewModel.weeklyBoard {
                leaderboardList(board)
            } else if selectedScope == .allTime, let entries = viewModel.allTimeEntries {
                allTimeList(entries)
            } else if let error = viewModel.error {
                errorState(error)
            } else {
                emptyState
            }
        }
    }
```

- [ ] **Step 3: Add allTimeList view**

Add a new computed property for rendering all-time entries (similar to weekly but using `AllTimeEntry`):

```swift
    private func allTimeList(_ entries: [AllTimeEntry]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack(spacing: Spacing.sm) {
                        rankBadge(entry.rank)
                        avatarView(user: entry.userId, size: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.userId.id == appState.currentUser?.id ? "You" : entry.userId.displayName)
                                .font(Typography.bodySmallBold)
                                .foregroundStyle(entry.userId.id == appState.currentUser?.id ? ColorTokens.gold : .white)
                                .lineLimit(1)
                            Text("\(entry.totalChallenges) challenges")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }

                        Spacer()

                        Text("\(Int(entry.totalScore))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.rank <= 3 ? ColorTokens.gold : .white)
                    }
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(entry.userId.id == appState.currentUser?.id ? ColorTokens.gold.opacity(0.06) : Color.clear)
                    )
                    .padding(.horizontal, Spacing.lg)
                }
            }
            .padding(.bottom, Spacing.xxxl)
        }
    }
```

- [ ] **Step 4: Remove unused `selectedFilter` state and `LeaderboardFilter` enum**

Delete lines 6 and 15-18.

- [ ] **Step 5: Commit**

```bash
git add ScaleUp/Features/Competition/Views/LeaderboardView.swift
git commit -m "feat(competition): redesign LeaderboardView for objective-scoped display"
```

---

## Task 12: Add backend endpoint for user's primary objective topic

**Files:**
- Modify: `src/controllers/competitionController.js`
- Modify: `src/routes/competition.js`

- [ ] **Step 1: Add controller method**

Add to `competitionController.js`:

```javascript
  async getObjectiveTopic(req, res, next) {
    try {
      const UserObjective = require('../models/UserObjective');
      const objective = await UserObjective.findOne(
        { userId: req.user.id, status: 'active', isPrimary: true },
        { topicsOfInterest: 1 }
      ).lean();

      const topic = objective?.topicsOfInterest?.[0] || null;
      res.json({ topic });
    } catch (err) {
      next(err);
    }
  }
```

- [ ] **Step 2: Add route**

Add to `src/routes/competition.js`:

```javascript
router.get('/objective-topic', auth, competitionController.getObjectiveTopic);
```

- [ ] **Step 3: Commit**

```bash
git add src/controllers/competitionController.js src/routes/competition.js
git commit -m "feat(competition): add objective-topic endpoint for iOS leaderboard"
```

---

## Task 13: Bump build number and final verification

**Files:**
- Modify: `project.yml` (line 15)

- [ ] **Step 1: Bump CURRENT_PROJECT_VERSION from 31 to 32**

- [ ] **Step 2: Regenerate Xcode project**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcodegen generate
```

- [ ] **Step 3: Verify iOS build**

```bash
xcodebuild -scheme ScaleUp -sdk iphonesimulator build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add project.yml ScaleUp.xcodeproj
git commit -m "Build 32: Competition pipeline overhaul — daily generation, simplified scoring, objective-scoped leaderboards"
```

---

## Deployment Order

1. **Run migration script** on production MongoDB: `node scripts/normalize-topics.js`
2. **Deploy backend** to EC2 (PM2 restart)
3. **Verify**: Check midnight IST cron fires and generates daily challenges
4. **Submit iOS build** to TestFlight
