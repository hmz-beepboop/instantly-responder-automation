# Autonomous First Pilot Recommendation

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED — Requires owner approval before any implementation

---

## Recommended Pilot Sequence

### Phase A — Shadow Mode (Minimum 14 days)

**Goal:** Calibrate the eligibility engine with real production data before any live sends.

**Config:**
```json
{
  "autonomous_enabled": false,
  "shadow_only": true,
  "dry_run": true,
  "emergency_disabled": false,
  "intent_allowlist": ["INFORMATION_REQUEST", "SCHEDULING_REQUEST"],
  "confidence_threshold": 0.85,
  "max_autonomous_sends_per_day": 0
}
```

**Owner actions during shadow period:**
1. Review daily digest each morning (5 minutes)
2. Assess shadow-eligible draft quality
3. Note any shadow decisions you disagree with
4. Note intent types where drafts consistently look good
5. After 14 days: decide whether to proceed to Phase B

**Success criteria for Phase A:**
- At least 50 shadow candidates evaluated
- 90%+ of shadow-eligible cases you agree should be shadow-eligible
- Draft quality for INFORMATION_REQUEST and SCHEDULING_REQUEST is acceptable
- Zero unexpected blocks or unexpected allowances

---

### Phase B — Controlled Pilot: 1/day (Minimum 7 days)

**Goal:** Test real sends at minimum volume with mandatory review.

**Config changes from Phase A:**
```json
{
  "autonomous_enabled": true,
  "shadow_only": false,
  "dry_run": false,
  "emergency_disabled": false,
  "campaign_allowlist": ["<your-primary-campaign-id>"],
  "sender_allowlist": ["<your-primary-sender-email>"],
  "intent_allowlist": ["INFORMATION_REQUEST"],
  "max_autonomous_sends_per_day": 1,
  "live_pilot_daily_cap": 1,
  "live_pilot_requires_owner_toggle": true
}
```

**Why INFORMATION_REQUEST only first:**
- Lowest risk intent type
- Prospect just wants to know more about the service
- No pricing, no scheduling confirmation, no legal/compliance
- Draft quality has been validated in shadow mode
- Easy for owner to verify correctness

**Owner actions during Phase B:**
1. Each morning: check if 1 autonomous send occurred
2. Review the draft that was sent (post-action review form)
3. Rate the response quality
4. If prospect replied: assess reaction
5. After 7 days: decide whether to continue or expand

**Success criteria for Phase B:**
- All 7 sends (at most 1/day) reviewed
- 6/7+ rated `good_response` or `acceptable_but_edit_next_time`
- Zero kills switch events
- No prospect complaints

---

### Phase C — Controlled Pilot Expansion

**Only after Phase B success criteria met.**

Expand in this order:
1. Add SCHEDULING_REQUEST to intent_allowlist (still 1/day cap)
2. If successful for 7 days: increase cap to 2/day
3. If successful for 14 days: increase cap to 5/day
4. Each expansion requires owner approval

---

## What is Never in the Autonomous Pilot

Regardless of pilot phase, these are NEVER autonomous:
- PRICING_REQUEST
- CONTRACT_TERMS
- GDPR_REQUEST / SOC2_REQUEST / DATA_SECURITY_REQUEST
- LEGAL_COMPLAINT
- UNSUBSCRIBE / DNC / OPT_OUT
- ANGRY_REPLY / HOSTILE_REPLY
- BILLING_DISPUTE / REFUND_REQUEST
- CUSTOM_PROPOSAL_REQUEST
- ENTERPRISE_REQUEST
- Any case with unknown sender/campaign/thread
- Any correction/learning case
- Any multi-intent case with a blocked additional intent

---

## First Pilot Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Wrong draft content | 14-day shadow calibration + active rules from supervised path |
| Low-quality tone | Same AI draft infrastructure as supervised (already validated) |
| Wrong recipient | Thread identity gate (required) |
| Duplicate send | Idempotency check in existing Sender workflow |
| Out-of-hours send | Working-hours gate |
| Too many sends | Daily cap of 1 |
| Owner misses review | Digest + escalation channels |
| Negative prospect reaction | Post-action review → learning → eligibility tightening |

---

## Related Documents

- `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` — formal approval gates
- `docs/AUTONOMOUS_GO_NO_GO_CHECKLIST.md` — go/no-go per mode
- `docs/AUTONOMOUS_METRICS_TO_TRACK.md` — what to measure
- `docs/AUTONOMOUS_METRICS_TO_TRACK.md` — success metrics
