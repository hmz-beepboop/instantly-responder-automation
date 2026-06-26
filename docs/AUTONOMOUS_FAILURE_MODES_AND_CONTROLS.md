# Autonomous Failure Modes and Controls

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Failure Mode 1 — Wrong Recipient

**Scenario:** Autonomous send goes to the wrong prospect (thread identity mismatch).

**Likelihood:** Low — thread identity gate is a prerequisite.

**Detection:** Prospect replies with "I didn't send you anything", or post-action review notices mismatch.

**Controls:**
- Thread identity confidence gate (`thread_identity_confident = true` required)
- Sender identity confidence gate (`sender_identity_confident = true` required)
- Campaign identity confidence gate (`campaign_identity_confident = true` required)
- Audit trail captures thread_id, campaign_id, sender_email, recipient_email

**Response:**
1. Activate kill switch
2. Contact recipient to apologise (manual send)
3. Document in incident log
4. Tighten thread identity confidence checks

---

## Failure Mode 2 — Invented Business Claim

**Scenario:** Autonomous draft contains an invented price, fake case study, false result, or guarantee.

**Likelihood:** Very low — same AI draft infrastructure and knowledge base constraints apply; active rules cannot override safety wording.

**Detection:** Owner post-action review; prospect calls out false claim.

**Controls:**
- Same AI draft infrastructure as supervised path — knowledge base constraints apply
- Active rules cannot instruct AI to invent claims (hardcoded in rule governance)
- No pricing in autonomous eligible intents (PRICING_REQUEST is permanently blocked)
- Post-action review detects invented claims next morning

**Response:**
1. Activate kill switch
2. Send correction to prospect if possible (manual)
3. Document claim in incident log
4. Review AI prompt for gap that allowed the invention
5. Update knowledge base or add active rule to explicitly prohibit the specific claim type
6. Run verification before re-enabling

---

## Failure Mode 3 — Duplicate Send

**Scenario:** Autonomous path sends the same reply twice to the same prospect.

**Likelihood:** Low — existing Sender workflow has idempotency check; autonomous path must not bypass it.

**Detection:** Prospect complains of duplicate; or idempotency state shows two sends for same thread.

**Controls:**
- `duplicate_risk` gate (`duplicate_risk = true` blocks the case)
- Sender workflow idempotency check (independent of autonomous path)
- Audit trail captures every send with thread_id
- Daily cap prevents runaway sending

**Response:**
1. Activate kill switch if systemic
2. Apologise to affected prospects (manual send)
3. Document in incident log
4. Identify which idempotency layer failed
5. Fix the failing layer before re-enabling

---

## Failure Mode 4 — Out-of-Hours Send

**Scenario:** Autonomous send occurs outside the configured working-hours window.

**Likelihood:** Very low — working-hours gate is a prerequisite.

**Controls:**
- Working-hours gate (`in_human_working_hours = true` required)
- Timezone specified explicitly in config
- Blackout dates listed in config

**Response:**
1. Verify the working-hours gate was correctly evaluated (timezone offset, DST?)
2. Document the gap
3. Add blackout dates if holiday was missed
4. If prospect reacts negatively, handle as supervised case

---

## Failure Mode 5 — Blocked Intent Type Processed

**Scenario:** A case with PRICING_REQUEST, UNSUBSCRIBE, LEGAL_COMPLAINT, or other permanently blocked intent type is processed autonomously.

**Likelihood:** Very low — permanent block list is hardcoded, not configurable.

**Controls:**
- Permanent block list in eligibility engine (hardcoded)
- Intent blocklist gate
- Multi-intent block (any blocked additional intent blocks the whole case)

**Response:**
1. Activate kill switch immediately
2. Identify which gate failed to block the case
3. Review eligibility engine code for the gap
4. Fix the gap, run acceptance harness, confirm the specific case would now be blocked
5. Owner sign-off before re-enabling

---

## Failure Mode 6 — Daily Cap Exceeded

**Scenario:** More than `max_autonomous_sends_per_day` autonomous sends occur in one day.

**Likelihood:** Very low — daily cap is a gate.

**Controls:**
- Daily cap gate (per-day, per-campaign, per-sender)
- Audit trail captures every send with timestamp

**Response:**
1. Identify why the cap was bypassed (counter state, concurrent execution?)
2. Fix the counter mechanism
3. Document and report all excess sends
4. Notify prospects if excess sends were inappropriate

---

## Failure Mode 7 — Eligibility Engine Exception

**Scenario:** The eligibility engine throws an exception or returns an unexpected result.

**Likelihood:** Moderate risk in early deployment — code bugs possible.

**Controls:**
- Default-blocked posture: exceptions block the case (not allow it)
- Audit trail captures exception details
- Daily digest alerts on exception rate

**Response:**
1. No send occurs (exception = blocked)
2. Case routes to supervised path
3. Fix exception in next deployment
4. Test fix in acceptance harness before re-deploying

---

## Failure Mode 8 — Learning System Creates a Bad Active Rule

**Scenario:** A correction event generates a proposed_shadow rule that, if approved, would produce bad outputs.

**Likelihood:** Low — proposed_shadow rules require explicit owner approval.

**Controls:**
- No rule becomes active without owner approval
- Rule candidate review process includes assessment of proposed_rule_text
- Owner can amend the text before approving
- Active rules can be rolled back immediately

**Response:**
1. If rule is proposed_shadow: reject it; document why
2. If rule was wrongly activated: roll back using Phase 4I-B rollback command
3. Update rule review criteria to catch similar proposals in future

---

## Failure Mode 9 — Kill Switch Not Stopping Autonomous Actions

**Scenario:** `emergency_disabled = true` is set but autonomous sends continue.

**Likelihood:** Very low if config is loaded correctly.

**Controls:**
- Config reload triggers immediate stop
- n8n workflow deactivation as fallback
- Escalation channel as second fallback

**Response:**
1. Deactivate the autonomous workflow in n8n UI immediately
2. Identify why the config reload did not propagate
3. Fix config loading mechanism before re-enabling

---

## Failure Mode 10 — Post-Action Review Skipped

**Scenario:** Autonomous sends occur but the daily digest is not reviewed by the owner.

**Likelihood:** Moderate — human behaviour risk.

**Controls:**
- `require_post_action_review = true` enforces review queuing
- Digest sent to `escalation_channels`
- Autonomous sends blocked for the next day if previous day's review not acknowledged (future enforcement mechanism)

**Response:**
1. Review outstanding sends as soon as review resumes
2. Increase digest visibility (additional notification channel)
3. If pattern of skipped reviews: reduce daily cap or pause autonomous mode

---

## Risk Summary Table

| Failure Mode | Likelihood | Severity | Key Control |
|-------------|-----------|----------|-------------|
| Wrong recipient | Low | High | Thread identity gate |
| Invented claim | Very Low | High | Knowledge base constraints + intent block |
| Duplicate send | Low | Medium | Idempotency + duplicate_risk gate |
| Out-of-hours send | Very Low | Low | Working-hours gate |
| Blocked intent processed | Very Low | High | Hardcoded permanent block list |
| Daily cap exceeded | Very Low | Medium | Daily cap gate |
| Eligibility engine exception | Moderate | Low | Default-blocked posture |
| Bad active rule approved | Low | Medium | Owner review gate |
| Kill switch failure | Very Low | High | n8n workflow deactivation fallback |
| Post-action review skipped | Moderate | Medium | Digest + escalation channels |

---

## Related Documents

- `docs/AUTONOMOUS_SAFETY_MODEL.md` — gate layers in detail
- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — emergency controls
- `docs/AUTONOMOUS_INCIDENT_RESPONSE_RUNBOOK.md` — incident response
- `docs/AUTONOMOUS_ROLLBACK_DRILL.md` — rollback practice
