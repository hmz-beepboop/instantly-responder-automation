# Autonomous Owner Approval Checklist

**Version:** 1.1  
**Date:** 2026-06-24  
**Status:** GATE 1 APPROVED — Shadow mode active. Gate 2 requires 14 days shadow review.

---

## Overview

This checklist defines the explicit approvals required from the owner before any advancement in autonomous operating mode. Each gate must be signed off separately.

No Claude session may advance the autonomous mode without matching owner approval recorded here or in a session handoff document.

---

## Gate 1 — Shadow Mode Activation

**Prerequisite:** Phases 5B–5E complete (config, eligibility engine, acceptance harness all pass).

Owner must confirm:

- [x] I have read and understood `docs/AUTONOMOUS_PHASE_5_ARCHITECTURE.md`
- [x] I have read and understood `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md`
- [x] I have read and understood `docs/AUTONOMOUS_SAFETY_MODEL.md`
- [x] I have reviewed the eligibility engine scenarios (`outputs/autonomous_eligibility_decision_matrix.json`)
- [x] I have confirmed `would_send_live_now = false` for all 75 scenarios in the eligibility engine
- [x] I have reviewed the disabled shadow evaluator workflow spec
- [x] I accept that shadow mode logs decisions but sends nothing
- [x] I understand that I must review the daily digest after each shadow run
- [x] I confirm the escalation channels in the config are correct (GOOGLE_CHAT_WEBHOOK_URL — Europe/London working hours)
- [x] I authorise enabling shadow mode (Mode 1)

**Owner sign-off date:** 2026-06-24  
**Method of sign-off:** Explicit session instruction to Claude Code  
**Shadow evaluator workflow ID:** aHzLtQiv6G8h1bqD  
**Shadow evaluator versionId:** 7fcf032c-03d3-4da4-b1a5-f473fde4d144  
**Config changes applied:** reviewer_timezone=Europe/London, escalation_channels=[GOOGLE_CHAT_WEBHOOK_URL]

---

## Gate 2 — Controlled Pilot Activation (Mode 2)

**Prerequisite:** At least 14 days of shadow mode operation. Owner has reviewed shadow logs.

Owner must confirm:

- [ ] I have reviewed the shadow logs for at least 14 days
- [ ] I am satisfied with the eligibility engine's shadow decisions
- [ ] I understand that Mode 2 will result in at most `live_pilot_daily_cap` (default: 1) real autonomous sends per day
- [ ] I have set `live_pilot_requires_owner_toggle = true` in the config
- [ ] I have confirmed `campaign_allowlist` contains only the correct campaign IDs
- [ ] I have confirmed `sender_allowlist` contains only the correct sender emails
- [ ] I have confirmed `intent_allowlist` contains only the correct intent types (recommended: INFORMATION_REQUEST and SCHEDULING_REQUEST only initially)
- [ ] I have confirmed `confidence_threshold` is set at or above 0.85
- [ ] I have confirmed `max_autonomous_sends_per_day = 1`
- [ ] I have confirmed `require_post_action_review = true`
- [ ] I commit to reviewing every autonomous send the next morning before any new sends are allowed
- [ ] I understand the kill switch procedure
- [ ] I authorise enabling controlled pilot (Mode 2) with daily cap of 1

**Owner sign-off date:** ___________  
**Method of sign-off:** ___________

---

## Gate 3 — Controlled Pilot Expansion

**Prerequisite:** At least 7 days of controlled pilot at 1/day. Owner has reviewed all sends.

Owner must confirm:

- [ ] I have reviewed all autonomous sends from the first pilot week
- [ ] All pilot sends received acceptable prospect responses (or no negative responses)
- [ ] No kill switch events occurred
- [ ] Post-action reviews completed for all pilot sends
- [ ] No correction events were created from pilot sends that indicate systemic problems
- [ ] I authorise increasing `live_pilot_daily_cap` to _____ (owner fills in)
- [ ] I authorise expanding `intent_allowlist` to include _____ (owner fills in, if any)

**Owner sign-off date:** ___________  
**Method of sign-off:** ___________

---

## What Requires Owner Approval at Any Time (Not Just Mode Changes)

| Action | Approval required |
|--------|------------------|
| Changing `autonomous_enabled` from false to true | YES — Gate 2 |
| Changing `shadow_only` from true to false | YES — Gate 2 |
| Changing `dry_run` from true to false | YES — Gate 2 |
| Adding a campaign to `campaign_allowlist` | YES — document reason |
| Adding a sender to `sender_allowlist` | YES — document reason |
| Adding an intent to `intent_allowlist` | YES — document reason |
| Increasing `live_pilot_daily_cap` | YES — Gate 3 |
| Activating any disabled autonomous workflow in n8n | YES |
| Injecting a new active rule into Decision node D | YES |
| Rolling back an active rule | Owner should be notified; may be done immediately in emergency |
| Activating kill switch | May be done immediately; notify owner ASAP |
| Removing an item from any blocklist | YES — requires documented justification |

---

## What Does NOT Require Owner Approval

| Action | Notes |
|--------|-------|
| Reading production workflow metadata | Read-only |
| Running eligibility engine offline scenarios | No production writes |
| Running acceptance harness | No production writes |
| Updating handoff and memory docs | Documentation only |
| Creating or updating shadow log entries | Shadow mode only |
| Generating daily digest | Read-only summarisation |
| Activating kill switch | Emergency action; notify owner after |

---

## Related Documents

- `docs/AUTONOMOUS_GO_NO_GO_CHECKLIST.md` — go/no-go decision per mode
- `docs/AUTONOMOUS_PHASE_5_ARCHITECTURE.md` — architecture overview
- `docs/AUTONOMOUS_SAFETY_MODEL.md` — gate layers
- `docs/AUTONOMOUS_FIRST_PILOT_RECOMMENDATION.md` — recommended pilot configuration
