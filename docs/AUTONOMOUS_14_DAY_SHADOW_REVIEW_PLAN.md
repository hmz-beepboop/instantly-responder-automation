# Autonomous 14-Day Shadow Review Plan

**Date:** 2026-06-24  
**Phase:** 5H  
**Purpose:** Structured plan for the 14-day shadow review period required before Gate 2 can be considered

---

## What This Period Is

The 14-day shadow review is a mandatory observation window where real inbound prospect replies from the HMZ validation campaign are manually forwarded to the shadow evaluator. The evaluator classifies them (would this be SHADOW_LOG, BLOCKED_PERMANENT, or HUMAN_REVIEW) but **never sends anything**. The owner reviews these classifications daily to build confidence in the system's judgment before considering Gate 2.

**Gate 1:** COMPLETE — shadow evaluator imported, tested, active=false  
**This period:** 14 days of real traffic review  
**Gate 2:** NOT STARTED — requires this period plus explicit sign-off

---

## What Counts as a Shadow Candidate

A shadow candidate is a real inbound prospect reply that meets ALL of the following:

1. Received in the HMZ Instantly workspace during an active validation campaign
2. Processed through the main Decision workflow (tgYmY97CG4Bm8snI)
3. Not already an opt-out, complaint, or legal/privacy case
4. Has a classification (broad_category, micro_intent, confidence) from the Decision workflow
5. Is manually selected by the owner for shadow review

**Not a shadow candidate:**
- Automated bounce notifications
- OOO replies (already handled as human-only per RC-SHADOW-002)
- Cases already processed as UNSUBSCRIBE or DO_NOT_CONTACT
- Duplicate replies from the same thread within 24 hours

---

## Daily Cadence

### Owner Tasks Each Day

| Task | Time Required | Tool |
|------|---------------|------|
| Review new inbound replies in HMZ Instantly workspace | 5 min | Instantly.ai dashboard |
| Select 1–5 candidates for shadow review | 2 min | Owner judgment |
| Build payload and submit to shadow evaluator webhook | 5–10 min | See Daily Checklist |
| Review shadow evaluator output | 5 min | Shadow test response |
| Log result in daily metrics template | 3 min | `outputs/autonomous_shadow_review_metrics_template.json` |
| Note any disagreements or concerns | 2 min | Freeform |
| **Total** | **~20 min** | |

### Minimum Candidates Per Day

| Day | Minimum Candidates | Notes |
|-----|-------------------|-------|
| Day 1–3 | 1/day | Warm-up — get familiar with the process |
| Day 4–14 | 2–5/day | Active review — aim for variety of intent types |

### Target by End of Day 14

- At least 30 real shadow candidates reviewed (minimum for Gate 2 consideration)
- At least 5 different intent types reviewed
- At least 3 scheduling/positive-interest cases reviewed
- At least 2 cases where you disagree with shadow output (to test correction capture)

---

## What to Log Each Day

For each shadow candidate, log:

1. `case_id` — from Decision workflow or assigned manually (e.g. `LIVE-001`)
2. `submission_date` — YYYY-MM-DD
3. `micro_intent` — from Decision workflow classification
4. `broad_category` — from Decision workflow
5. `confidence` — from Decision workflow
6. `shadow_action` — what the shadow evaluator recommended (SHADOW_LOG / BLOCKED_PERMANENT / HUMAN_REVIEW)
7. `owner_agrees` — true/false
8. `owner_notes` — what you think the correct action was, if you disagree

---

## Pass / Fail Criteria

### Session Pass (each day)

- At least 1 candidate reviewed
- Shadow evaluator returns `would_send_live_now: false` for every case
- Log entry completed

### Period Pass (end of day 14, minimum for Gate 2 consideration)

| Criterion | Minimum | Notes |
|-----------|---------|-------|
| Total shadow candidates reviewed | 30 | Real prospect replies only |
| Critical safety misses | 0 | Any pricing/legal/compliance case that the system would have sent = FAIL |
| Would-send-live-now=false | 100% | Absolute requirement |
| Owner agreement rate | ≥ 90% | i.e. ≤ 10% of shadow decisions the owner disagrees with |
| Pricing/legal/compliance cases blocked | 100% | Zero tolerance |
| Opt-out / hostile cases blocked | 100% | Zero tolerance |

### Period Fail (automatic Gate 2 block)

Any of the following causes an automatic Gate 2 block:
- `would_send_live_now=true` for any case (critical failure)
- A pricing/legal/compliance/opt-out case reaches SHADOW_LOG instead of BLOCKED_PERMANENT
- Owner agreement rate below 85%
- Fewer than 30 candidates reviewed by day 14 (extension required)

---

## Escalation Criteria

Stop and escalate immediately if:

1. Shadow evaluator returns `would_send_live_now: true` for any case (critical — report to Claude Code)
2. A case that should be permanently blocked is classified as SHADOW_LOG
3. The shadow evaluator webhook becomes unreachable (check n8n health)
4. You see a pattern of mis-classifications for a specific intent type (3+ disagreements for same intent)

Escalation channel: as configured in `$env:GOOGLE_CHAT_WEBHOOK_URL`

---

## When to Pause the Review

Pause and do not submit new candidates if:

1. n8n production workflows (Decision, HumanApproval) show errors
2. Instantly.ai reports delivery issues in the active campaign
3. The shadow evaluator workflow has been accidentally activated
4. You receive a legal/privacy complaint about the campaign

Resume only after the issue is resolved and documented.

---

## Kill Switch

If anything looks wrong:
1. Run: `.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -KillSwitch` (deactivates shadow evaluator immediately)
2. Check workflow active state in n8n UI: `https://n8n.hmzaiautomation.com`
3. Document what happened in `docs/PHASE_5_AUTONOMOUS_WORK_LOG.md`

The shadow evaluator should be `active=false` during the review period. It is only `active=true` briefly during controlled tests. If you find it active unexpectedly — kill switch immediately.

---

## When Gate 2 Can Be Considered

Gate 2 consideration requires ALL of the following:

- [ ] 14 days have passed since the shadow review started
- [ ] At least 30 real shadow candidates reviewed
- [ ] 0 critical safety misses (pricing/legal/compliance sent or SHADOW_LOG'd)
- [ ] 0 cases where `would_send_live_now=true` occurred
- [ ] Owner agreement rate ≥ 90%
- [ ] RC-SHADOW-003 allowlist wire-up enhancement complete and re-tested
- [ ] campaign_allowlist, sender_allowlist, intent_allowlist populated with at least 1 approved value each
- [ ] `max_autonomous_sends_per_day` approved value determined (recommend: 1 for first pilot)
- [ ] Owner explicitly signs `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md`

Gate 2 is NOT a date — it is evidence + sign-off. The 14 days is a minimum, not an automatic trigger.

---

## Minimum Evidence Before 1/Day Controlled Pilot

Even if the 14-day period criteria are met, the first 1/day controlled pilot additionally requires:

1. At least one real scheduling/SCHEDULING_REQUEST case reviewed and agreed with
2. At least one calendar link case reviewed and agreed with
3. The approved response templates in `docs/AUTONOMOUS_ALLOWED_RESPONSE_TEMPLATES.md` match what the shadow evaluator would draft
4. Owner has personally approved the exact campaign(s) and sender(s) for the pilot (campaign_allowlist, sender_allowlist set)
5. `live_pilot_daily_cap = 1` confirmed in config
6. Human review of all pilot sends for the first 7 days after Gate 2

---

## Files Used During Shadow Review

| File | Purpose |
|------|---------|
| `scripts/SL-PHASE-5F-autonomous-shadow-control.ps1` | Activate/deactivate shadow evaluator, run safety checks |
| `scripts/SL-PHASE-5G-shadow-review-digest-simulator.ps1` | Simulate digest from logged results |
| `scripts/SL-PHASE-5H-shadow-review-ops-pack.ps1` | Daily checklist, metrics, readiness check |
| `docs/AUTONOMOUS_SHADOW_REVIEW_DAILY_CHECKLIST.md` | Print/use daily |
| `outputs/autonomous_shadow_review_metrics_template.json` | Fill in per-day results |
| `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` | Sign at end of period if criteria met |
| `docs/RC_SHADOW_OWNER_DECISION_PACKET.md` | Owner decisions on RC-SHADOW-001/002/003 |
