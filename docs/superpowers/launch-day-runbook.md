# Launch Day Runbook — Day-1 Diagnostic V2

Hour-by-hour playbook for the launch of `FEATURE_DAY1_DIAGNOSTIC_V2`. Keep this document open during the launch window.

---

## T-24h — Staging Dry-Run

- [ ] Full end-to-end diagnostic on staging: onboarding → voice recording → topic selection → finish → results screen → plan tab populates
- [ ] Confirm all 7 objective types produce valid `superpower` taxonomy matches (no `taxonomy_miss` fallback)
- [ ] `pm2 list` on EC2 — backend + worker both `online`, zero restarts
- [ ] MongoDB pre-launch backup taken and labelled (e.g. `pre-launch-v2-2026-05-07`)
- [ ] Notify support team (or self-note) of the launch window: date, time, and that new diagnostic UX is going live
- [ ] Confirm iOS TestFlight build is installed on a real device and tested today
- [ ] Confirm Android internal test APK installed and tested today
- [ ] Read through `docs/superpowers/rollback-plan.md` — know the 5-minute backend rollback by heart

---

## T-1h — Pre-Launch Final Checks

- [ ] Pre-launch checklist (`docs/superpowers/launch-checklist.md`) — all boxes ticked
- [ ] Mixpanel Live View open in browser — ready to watch events
- [ ] EC2 CloudWatch or `pm2 logs` tail open in a terminal
- [ ] App Store Connect → confirm iOS build is set to phased release (not 100%)
- [ ] Play Console → confirm Android rollout percentage is 10% or less
- [ ] No active incidents on [OpenAI status](https://status.openai.com), AWS EC2, or S3
- [ ] Slack / comms channel with the Wave 1 cohort ready — draft welcome message loaded

---

## T=Launch — Flag Flip

```bash
# On EC2:
# 1. Edit .env — set FEATURE_DAY1_DIAGNOSTIC_V2=true
nano /home/ubuntu/scaleup-backend/.env

# 2. Reload
pm2 reload all

# 3. Verify worker alive
pm2 list | grep worker
```

- [ ] Flag flipped + `pm2 reload all` completed
- [ ] First user journey: complete a fresh diagnostic as a Wave 1 test user — confirm results screen shows real LLM insights (not the deterministic template fallback)
- [ ] Plan tab: verify "Plan brewing..." pill appears within 5 seconds of finishing, and plan populates within 60 seconds
- [ ] Push notification received on test device: "Your Superpower Plan is ready"
- [ ] Mixpanel Live View: `diagnostic_started` and `diagnostic_completed` events appear within 2 minutes
- [ ] Send Wave 1 cohort welcome message

---

## T+15m — First Signal Check

- [ ] `pm2 logs` — no uncaught exceptions, no `ECONNRESET` spikes
- [ ] CloudWatch (or EC2 `top`) — CPU within normal bounds; no memory leak
- [ ] Mixpanel: `diagnostic_completed` event count matches expected early adopters
- [ ] Check insights fallback rate: `db.diagnosticattempts.countDocuments({ insightsSource: 'template' })` vs. total — should be < 10%
- [ ] Check plan fallback rate: `db.diagnosticattempts.countDocuments({ planStatus: 'fallback' })` vs. total — should be < 5%
- [ ] If any alert threshold is breached: consult "Common Issues" section below before rolling back

---

## T+1h — Stability Check

- [ ] Error rate on `/diagnostic/finish` endpoint stable (< 1% 5xx)
- [ ] Median `insightsLatencyMs` in MongoDB < 15 000ms (15s) for V2 attempts
- [ ] Plan worker queue depth: `db.planqueue.countDocuments({ status: 'pending' })` — should be draining, not growing
- [ ] At least 3 Wave 1 users have completed the full flow (start → plan ready)
- [ ] No support messages from Wave 1 cohort indicating broken UX
- [ ] Review Mixpanel funnel: `diagnostic_started` → `diagnostic_completed` → `insights_viewed` → `plan_viewed` — drop-off at any step > 40% warrants investigation (not necessarily rollback)

---

## T+4h — Afternoon Review

- [ ] Total diagnostic completions vs. starts — completion rate > 60% expected (new UX is longer; some drop-off is normal)
- [ ] Insights fallback rate still < 10%
- [ ] Plan generation success rate > 95%
- [ ] Voice transcription: check S3 upload success rate — `POST /diagnostic/voice/upload` should have < 2% 4xx/5xx
- [ ] Push notifications delivered rate — check APNs/FCM delivery logs or Mixpanel push events
- [ ] Spot-check 3 completed attempts in MongoDB: `insightsStatus: 'ready'`, `planStatus: 'ready'`, `calibrationClass` set per result
- [ ] Write a brief internal status note (Slack / Notion): completions, fallback rates, any incidents, current stability assessment

---

## T+24h — Daily Digest Review

- [ ] Mixpanel dashboard: activation funnel numbers (Wave 1 started / completed / viewed plan)
- [ ] Top-3 taxonomy misses: run `db.diagnosticattempts.aggregate([{ $unwind: '$results' }, { $match: { 'results.taxonomyMiss': true } }, { $group: { _id: '$results.objectiveType', count: { $sum: 1 } } }, { $sort: { count: -1 } }, { $limit: 3 }])` — feed findings into taxonomy improvement backlog
- [ ] Wave 2 cron job verification: confirm the Wave 2 batch cron is registered and scheduled (`pm2 list` or cron log)
- [ ] Any crash reports from App Store Connect or Play Console — triage and prioritise
- [ ] Support messages from Wave 1 cohort — respond within 24h; common issues handled below
- [ ] Confirm App Store phased release is progressing on schedule (or paused if warranted)
- [ ] Confirm Android rollout percentage increase is appropriate (e.g. 10% → 25% if T+24h is clean)

---

## Common Issues + Responses

### Insights fallback rate > 10%

**Likely cause:** OpenAI GPT-4o is degraded or rate-limited.

**Response:**
1. Check [OpenAI status page](https://status.openai.com).
2. If degraded: no action required — the deterministic template fallback is designed for this. Users still see insights, just not LLM-generated. Do not roll back.
3. If rate-limited (429s in logs): check OpenAI usage dashboard. If approaching tier limits, contact OpenAI support or reduce concurrency in the insights service.
4. Once OpenAI recovers, new attempts will automatically use LLM again. Existing template-fallback attempts are not retroactively upgraded (by design).

### Diagnostic completion rate < 60%

**Likely cause:** Drop-off during voice recording, topic selection, or the results screen.

**Response:**
1. Check Mixpanel step-by-step funnel — identify the exact step where drop-off spikes.
2. If drop-off is at voice recording: check `POST /diagnostic/voice/upload` error rate. If > 5% errors, investigate S3 upload or file size limits.
3. If drop-off is at topic selection: likely a UX friction issue, not a bug. Note for Wave 2 iteration.
4. If drop-off is at results screen: check iOS/Android crash reports. If crash rate > 1%, pause the App Store / Play Console rollout.
5. Do not roll back based on drop-off rate alone unless it indicates a blocking bug (completion rate = 0%).

### Taxonomy miss spikes

**Likely cause:** LLM returning objective types not in the taxonomy, or taxonomy seed data incomplete.

**Response:**
1. Run the taxonomy miss query (see T+24h section above) to identify which objective types are missing.
2. Check the realtime LLM generation path: if `FEATURE_DAY1_DIAGNOSTIC_V2=true` and the taxonomy miss is consistent, inspect `diagnosticEngine.js` — the taxonomy lookup fallback should have prevented a hard error.
3. If the miss is producing bad results (corrupt insights), set `FEATURE_DAY1_DIAGNOSTIC_V2=false` temporarily, patch the taxonomy seed, re-run the seed script, then re-enable.
4. If the miss is benign (fallback triggered, user experience intact), log the missing entries and add them to the taxonomy in the next patch.

### Plan generation fallback > 5%

**Likely cause:** Schema validation failure in the plan generation worker, or OpenAI returning a response that fails `json_schema` strict parsing.

**Response:**
1. Check the plan worker logs: `pm2 logs worker | grep fallback`
2. Inspect the raw LLM response for the failing attempts in MongoDB (`planRawResponse` field if present).
3. If the schema mismatch is consistent: the plan prompt may need updating. Set `FEATURE_DAY1_DIAGNOSTIC_V2=false`, patch the prompt/schema, merge, redeploy, re-enable.
4. If sporadic (< 10% of fallbacks): acceptable in V2 launch. The fallback plan is still a usable experience. Log and fix in patch.

### Voice transcription failures

**Likely cause:** S3 upload failure, Whisper API degraded, or file format mismatch.

**Response:**
1. Check `POST /diagnostic/voice/upload` 4xx/5xx rate in CloudWatch or `pm2 logs`.
2. If S3 errors: check AWS S3 console — bucket permissions, region availability.
3. If Whisper API errors: check OpenAI status. If Whisper is down, voice-based objective type questions will fail — users should be prompted to retry or answer via text fallback (if implemented).
4. If file format errors: check the iOS/Android audio encoding — expected format is `m4a` / `webm`. A mismatch here is a client-side bug requiring a hotfix build.

---

## On-Call Coverage

| Period | Coverage | Action |
|--------|----------|--------|
| T=Launch → T+24h | Nirpeksh — dedicated, phone on | Respond to any alert within 15 minutes |
| T+24h → T+7d | Nirpeksh — daily digest review | Check Mixpanel + MongoDB once per day; respond to crash reports within 24h |
| T+14d | Wave 2 Batch 1 verification | Confirm Wave 2 cron ran correctly; review Wave 2 cohort completion rate |

---

_Last updated: 2026-05-07. Plan 5 Task 21._
