# Autonomous Go/No-Go Checklist

**Version:** 1.1  
**Date:** 2026-06-24  
**Status:** MODE 1 (SHADOW) — GO. Mode 2 (Controlled Pilot) pending 14-day shadow review.

---

## Mode 1 — Shadow Mode Activation

### Technical Go Criteria

- [x] SL-PHASE-5B config validation: PASS (autonomous_enabled=false, shadow_only=true, dry_run=true)
- [x] SL-PHASE-5C eligibility engine: 75/75 scenarios, would_send_live_now=false for all
- [x] SL-PHASE-5D workflow validation: active=false, no Sender, no Instantly API
- [x] SL-PHASE-5E acceptance harness: all tests PASS
- [x] Shadow candidate logging spec complete
- [x] Daily digest spec complete
- [x] Audit trail spec complete

### Owner Go Criteria

- [x] Owner has read AUTONOMOUS_PHASE_5_ARCHITECTURE.md
- [x] Owner has read AUTONOMOUS_SYSTEM_BOUNDARIES.md
- [x] Owner has read AUTONOMOUS_SAFETY_MODEL.md
- [x] Owner has reviewed eligibility engine decision matrix
- [x] Owner confirms escalation_channels in config are correct (GOOGLE_CHAT_WEBHOOK_URL)
- [x] Owner confirms reviewer_timezone is correct (Europe/London)
- [x] Owner confirms working_hours are correct (09:00-18:00 Mon-Fri)

### No-Go Conditions

| Condition | Action |
|-----------|--------|
| Any acceptance test fails | Fix the gap; re-run harness |
| Owner has not reviewed architecture docs | Block until reviewed |
| Escalation channels not configured | Block until configured |
| kill switch procedure not understood | Block until owner confirms |

**GO / NO-GO Decision for Shadow Mode:**  
Date: 2026-06-24  Owner sign-off: Explicit session instruction  
**DECISION: GO — Shadow mode workflow imported as aHzLtQiv6G8h1bqD (active=false)**

---

## Mode 2 — Controlled Pilot Activation

### Shadow Mode Evidence Required

- [ ] At least 14 days of shadow mode operation
- [ ] At least 50 shadow candidates evaluated and reviewed by owner
- [ ] Owner is satisfied with shadow decision quality
- [ ] No unexpected shadow decisions found

### Technical Go Criteria

- [ ] campaign_allowlist has at least one entry (explicit campaign IDs)
- [ ] sender_allowlist has at least one entry (explicit sender emails)
- [ ] intent_allowlist has at least one safe entry (recommendation: INFORMATION_REQUEST or SCHEDULING_REQUEST)
- [ ] confidence_threshold >= 0.85
- [ ] max_autonomous_sends_per_day = 1 (start with 1)
- [ ] live_pilot_requires_owner_toggle = true
- [ ] require_post_action_review = true
- [ ] acceptance harness re-run and all tests PASS after config update

### Owner Go Criteria

- [ ] Owner has reviewed shadow logs for 14+ days
- [ ] Owner explicitly approves campaign_allowlist contents
- [ ] Owner explicitly approves sender_allowlist contents
- [ ] Owner explicitly approves intent_allowlist contents
- [ ] Owner commits to daily post-action review
- [ ] Owner understands kill switch procedure
- [ ] Owner confirms daily cap of 1 is acceptable

### No-Go Conditions

| Condition | Action |
|-----------|--------|
| Fewer than 14 days of shadow operation | Continue shadow mode |
| Owner not satisfied with shadow decisions | Tune eligibility engine; continue shadow |
| campaign_allowlist or sender_allowlist empty | Block until populated |
| max_autonomous_sends_per_day > 1 | Reduce to 1 for initial pilot |
| live_pilot_requires_owner_toggle = false | Must be true for initial pilot |
| Any kill switch event since shadow activation | Resolve incident first |

**GO / NO-GO Decision for Controlled Pilot:**  
Date: ___________  Owner sign-off: ___________

---

## Mode 3 — Controlled Pilot Expansion

### Pilot Evidence Required

- [ ] At least 7 days of controlled pilot at 1/day
- [ ] All pilot sends reviewed in post-action review
- [ ] Zero `bad_response` or `should_have_escalated` ratings
- [ ] No kill switch events
- [ ] Prospect reactions neutral or positive

### Expansion Parameters

- Daily cap increase: owner specifies _____
- Intent list expansion: owner specifies _____
- Shadow review frequency: remains daily

**GO / NO-GO Decision for Pilot Expansion:**  
Date: ___________  Owner sign-off: ___________

---

## Related Documents

- `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` — formal approval gates
- `docs/AUTONOMOUS_ACCEPTANCE_TEST_PLAN.md` — technical tests
- `docs/AUTONOMOUS_FIRST_PILOT_RECOMMENDATION.md` — recommended first pilot config
- `docs/AUTONOMOUS_METRICS_TO_TRACK.md` — what to measure during pilot
