# Autonomous Shadow Review Metrics Template

**Purpose:** Daily log during the 14-day shadow review period  
**Fill in one row per day. Keep this file updated throughout the review period.**

---

## Period Overview

| Field | Value |
|-------|-------|
| Review start date | _______________ |
| Review end date (target) | _______________ (14 days after start) |
| Shadow evaluator workflow ID | aHzLtQiv6G8h1bqD |
| Shadow evaluator active during review | false (activated briefly per day, then deactivated) |

---

## Daily Log

| Day | Date | Candidates Reviewed | would_send_live_now=true | Critical Misses | Owner Agreement | Shadow Evaluator Deactivated | Notes |
|-----|------|---------------------|--------------------------|-----------------|-----------------|------------------------------|-------|
| 1 | | | 0 | 0 | /% | YES | |
| 2 | | | 0 | 0 | /% | YES | |
| 3 | | | 0 | 0 | /% | YES | |
| 4 | | | 0 | 0 | /% | YES | |
| 5 | | | 0 | 0 | /% | YES | |
| 6 | | | 0 | 0 | /% | YES | |
| 7 | | | 0 | 0 | /% | YES | |
| 8 | | | 0 | 0 | /% | YES | |
| 9 | | | 0 | 0 | /% | YES | |
| 10 | | | 0 | 0 | /% | YES | |
| 11 | | | 0 | 0 | /% | YES | |
| 12 | | | 0 | 0 | /% | YES | |
| 13 | | | 0 | 0 | /% | YES | |
| 14 | | | 0 | 0 | /% | YES | |

---

## Intent Type Coverage

Track which intent types were reviewed. Aim for variety.

| Intent Type | Count Reviewed | Correct Classification | Notes |
|-------------|---------------|----------------------|-------|
| SCHEDULING_REQUEST | | | |
| INFORMATION_REQUEST | | | |
| PROOF_REQUEST | | | |
| POSITIVE_INTEREST_GENERAL | | | |
| PRICING_REQUEST | | | should always be BLOCKED_PERMANENT |
| UNSUBSCRIBE / OPT_OUT | | | should always be BLOCKED_PERMANENT |
| OUT_OF_OFFICE | | | should be HUMAN_REVIEW |
| AMBIGUOUS_INTENT | | | should be BLOCKED_PERMANENT |
| Other: ____________ | | | |

---

## Disagreement Log

| Day | Case ID | micro_intent | Shadow Action | Owner's Expected Action | Reason for Disagreement |
|-----|---------|-------------|---------------|------------------------|------------------------|
| | | | | | |
| | | | | | |

---

## Cumulative Metrics (update at end of each day)

| Metric | Target | Running Total |
|--------|--------|---------------|
| Total candidates reviewed | ≥ 30 | |
| would_send_live_now=true incidents | 0 | |
| Critical safety misses | 0 | |
| Total disagreements | ≤ 10% of reviewed | |
| BLOCKED_PERMANENT correct rate | 100% | |
| SHADOW_LOG correct rate | ≥ 90% | |

---

## Gate 2 Readiness Checklist (complete at end of day 14)

- [ ] 14+ days elapsed
- [ ] 30+ candidates reviewed
- [ ] 0 would_send_live_now=true incidents
- [ ] 0 critical safety misses (pricing/legal/compliance/opt-out wrong)
- [ ] Owner agreement rate ≥ 90%
- [ ] RC-SHADOW-003 allowlist wire-up complete and tested
- [ ] Intent types reviewed include SCHEDULING_REQUEST and INFORMATION_REQUEST
- [ ] campaign_allowlist has at least 1 approved campaign ID
- [ ] sender_allowlist has at least 1 approved sender email
- [ ] intent_allowlist has approved intents defined
- [ ] `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` signed by owner

**Gate 2 decision:** ☐ APPROVED  ☐ EXTEND REVIEW  ☐ NOT APPROVED

**Owner signature:** _______________  **Date:** _______________
