# Autonomous Mistake Response Policy

**Version:** 1.0  
**Date:** 2026-06-24

---

## Purpose

Defines what the owner and system must do when an autonomous response is identified as bad. A "mistake" is any autonomous output that falls below the quality, safety, or accuracy standards of the supervised path.

---

## Mistake Categories

| Category | Definition | Severity |
|----------|------------|----------|
| Quality mistake | Response was grammatically poor, unhelpful, or off-topic | LOW |
| Tone mistake | Response was too aggressive, too passive, or inappropriate for prospect | LOW-MEDIUM |
| Content mistake | Response contained incorrect information from the approved knowledge base | MEDIUM |
| CTA mistake | Response included wrong call-to-action (wrong link, wrong next step) | MEDIUM |
| Classification mistake | System sent for an intent type it should have escalated | HIGH |
| Eligibility mistake | System sent when gates should have blocked it | HIGH |
| Safety violation | System sent for a permanently blocked intent type | CRITICAL |
| Legal/compliance mistake | Any response touching unsubscribe, legal, GDPR, SOC2, pricing | CRITICAL |

---

## Response by Severity

### LOW — Quality or Tone Mistake

1. Note in post-action review (rating: `bad_response` or `wrong_tone`)
2. Write a better_response_text
3. Create learning event
4. Review if active rules need updating
5. **No kill switch required unless pattern emerges**

### MEDIUM — Content or CTA Mistake

1. Note in post-action review with specific wrong content identified
2. If prospect was misled: send human correction reply
3. Create learning event and rule candidate
4. Review knowledge base for gap
5. Review active rules for gap
6. **No kill switch required unless the same mistake recurs**

### HIGH — Classification or Eligibility Mistake

1. Activate kill switch immediately if send already occurred
2. Assess whether any other prospects were affected (review daily digest)
3. Create learning event and rule candidate
4. Review eligibility engine for the gate that should have blocked this
5. Fix the gate, test in acceptance harness
6. Owner sign-off before re-enabling autonomous mode

### CRITICAL — Safety Violation or Legal/Compliance

1. Activate kill switch immediately
2. Contact affected prospect with apology (manual human send)
3. Document in incident log
4. Create learning event with severity=CRITICAL
5. Notify any relevant parties (if legal, may need legal review)
6. Root cause analysis
7. Fix eligibility engine (the specific case type must be hardcoded as blocked)
8. Full acceptance harness re-run
9. Owner sign-off before re-enabling autonomous mode
10. Reduce daily cap to 1 for first week after re-enabling

---

## Repeated Mistakes Policy

| Scenario | Required Action |
|----------|----------------|
| 2 bad responses in same category | Review eligibility for that category; increase confidence threshold |
| 3 bad responses in same category | Remove category from autonomous eligibility |
| Any legal/compliance mistake | Remove category from autonomous eligibility permanently |
| Kill switch triggered once | Reduce daily cap to 1 after re-enabling |
| Kill switch triggered twice | Pause autonomous mode for 7+ days; full review before re-enabling |
| Kill switch triggered 3 times | Disable autonomous mode indefinitely; redesign eligibility engine |

---

## Mistake Log Requirements

Every mistake must be logged in the audit trail with:
- Severity
- Category
- Case ID
- What went wrong
- What correct output would have been
- What gate failed (if eligibility mistake)
- What action was taken
- Whether prospect was affected and how

---

## What "No Autonomous Sends" Mode Means

If mistakes are severe enough to require temporary disabling:
- `autonomous_enabled = false`
- `emergency_disabled = true`
- All future candidates route to supervised HumanApproval path
- Owner reviews all shadow log entries from the preceding period
- Fixes are applied and tested
- New owner approval (Gate 2 or Gate 3) required before re-enabling

---

## Related Documents

- `docs/AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md` — review form
- `docs/AUTONOMOUS_HUMAN_CORRECTION_TO_RULE_FLOW.md` — correction flow
- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — kill switch
- `docs/AUTONOMOUS_INCIDENT_RESPONSE_RUNBOOK.md` — full incident response
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — failure modes
