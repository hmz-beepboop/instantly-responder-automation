# Autonomous Safety Model

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Safety Principles

1. **Deterministic safety always overrides AI.** Every safety gate is a hard check, not a probabilistic assessment. No confidence score can override a blocked intent type.

2. **Default is blocked.** Every case starts as blocked. It must affirmatively pass every gate to become eligible for autonomous action.

3. **No single point of failure.** Safety is enforced at config, eligibility engine, intent blocklist, daily cap, Sender workflow, and audit trail levels independently.

4. **Human oversight preserved.** The autonomous layer produces daily digests and post-action reviews. A human always has visibility into what the system did.

5. **Kill switch always available.** The owner can set `emergency_disabled = true` to halt all autonomous processing immediately without modifying any workflow.

6. **Learning from mistakes.** Every bad autonomous outcome creates a correction event that tightens future eligibility.

---

## Gate Layers

Gates are evaluated in order. Failure at any gate blocks the case.

### Gate 1 — System State Gates

| Check | Pass condition |
|-------|---------------|
| `autonomous_enabled` | Must be `true` |
| `dry_run` | Must be `false` |
| `shadow_only` | Must be `false` |
| `emergency_disabled` | Must be `false` |

These are config values. If any is in the wrong state, no case can proceed.

### Gate 2 — Identity Gates

| Check | Pass condition |
|-------|---------------|
| `thread_identity_confident` | Must be `true` |
| `sender_identity_confident` | Must be `true` |
| `campaign_identity_confident` | Must be `true` |

If the system cannot confidently identify the thread, sender, or campaign context, no autonomous action is permitted.

### Gate 3 — Allowlist Gates

| Check | Pass condition |
|-------|---------------|
| Campaign in `campaign_allowlist` | Must be present |
| Sender in `sender_allowlist` | Must be present |
| Intent in `intent_allowlist` | Primary intent must be present |
| Micro intent in `micro_intent_allowlist` | Must be present (if configured) |
| No additional intent in `additional_intent_blocklist` | No blocked additional intents |
| No risk flag in `risk_blocklist` | No risk flags triggered |

### Gate 4 — Intent Safety Gates

| Check | Pass condition |
|-------|---------------|
| Primary intent not in permanent block list | Must not be a blocked intent (see AUTONOMOUS_SYSTEM_BOUNDARIES.md) |
| No additional intent in permanent block list | None of the additional_intents may be blocked |
| `active_rule_conflict` | Must be `false` |

This gate is hardcoded — it cannot be overridden by config.

### Gate 5 — Working-Hours Gate

| Check | Pass condition |
|-------|---------------|
| Current time in reviewer_timezone | Must be within `working_hours_start` to `working_hours_end` |
| Current day | Must be in `working_days` |
| Current date | Must not be in `blackout_dates` |
| `prospect_timezone_strategy` | Applied as configured |

### Gate 6 — Quality Gates

| Check | Pass condition |
|-------|---------------|
| `confidence` | Must be >= `confidence_threshold` |
| `duplicate_risk` | Must be `false` |
| `correction_pending` | Must be `false` |

### Gate 7 — Daily Cap Gate

| Check | Pass condition |
|-------|---------------|
| Sends today (total) | Must be < `max_autonomous_sends_per_day` |
| Sends today (this campaign) | Must be < `max_autonomous_sends_per_campaign_per_day` |
| Sends today (this sender) | Must be < `max_autonomous_sends_per_sender_per_day` |

### Gate 8 — Post-Action Review Gate

| Check | Pass condition |
|-------|---------------|
| `require_post_action_review` | If `true`, case is queued for next-morning review regardless of outcome |

This gate does not block the send — it ensures accountability after the send.

---

## Safety Invariants (Never Violated)

These invariants are absolute. No config change, rule injection, or operator action can override them.

1. **Sender workflow is never bypassed.** The autonomous path must use the same Sender workflow as the supervised path. It cannot call Instantly API directly.

2. **Idempotency is never bypassed.** The autonomous path must check and set send-state before any send. If idempotency state is uncertain, the case escalates to human review.

3. **Unsubscribe/DNC/opt-out always suppress immediately.** These intent types are hardcoded as blocked regardless of all other gates.

4. **Legal and compliance cases always escalate.** Any case touching legal, GDPR, SOC2, data security, or compliance is hardcoded as human-only.

5. **Pricing is always human-only.** Any case with a PRICING_REQUEST or PRICING_NEGOTIATION intent (primary or additional) is blocked.

6. **Post-action review is never skipped.** Every case processed by the autonomous path (whether it resulted in a send or not) is logged and surfaced in the daily digest.

7. **No invented business claims.** The autonomous path uses the same AI draft infrastructure and the same knowledge base as the supervised path. Active rules cannot instruct the AI to invent prices, results, case studies, or guarantees.

---

## Safety in Shadow Mode

In shadow mode (current state), all gates are evaluated but outcomes are never acted upon. The purpose is to:

- Calibrate gate thresholds before enabling any live sends
- Identify cases the eligibility engine would approve that the owner would disagree with
- Build confidence in the system before enabling pilots
- Catch configuration errors before they cause real sends

The shadow log records `would_be_shadow_eligible` and `would_send_live_now` for every evaluated case. The owner reviews these to validate the engine's judgment.

---

## Safety Under Failure

If the eligibility engine fails (exception, timeout, unexpected output):
- Default action: human review required
- The supervised path is not affected
- The failure is logged to the audit trail
- A digest alert is produced

If the daily cap counter is unavailable:
- Default action: no autonomous sends until counter is restored
- Log the unavailability

If the Sender workflow is unavailable:
- Default action: queue for next window; escalate if delayed beyond SLA
- Do not retry autonomously without confirming idempotency

---

## Related Documents

- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — what is permanently blocked
- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — emergency disable and rollback
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — specific failure scenarios
- `docs/AUTONOMOUS_PHASE_5_ARCHITECTURE.md` — overall architecture
