# Autonomous System Boundaries

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Hard Boundaries — Never Autonomous

These case types are permanently blocked from autonomous send regardless of operating mode, confidence score, or active rules.

### Intent-Based Blocks (Permanent)

| Intent | Block reason |
|--------|-------------|
| UNSUBSCRIBE | Legal risk; must route to DNC handler |
| DO_NOT_CONTACT | Legal risk; must suppress immediately |
| OPT_OUT | Same as UNSUBSCRIBE |
| LEGAL_COMPLAINT | Immediate human + legal review required |
| ANGRY_REPLY | Reputational risk; tone assessment required |
| HOSTILE_REPLY | Reputational risk; may require no-reply |
| BILLING_DISPUTE | Financial; human resolution only |
| REFUND_REQUEST | Financial; human resolution only |
| PRICING_REQUEST | Commercially sensitive; pricing is human-only |
| PRICING_NEGOTIATION | Contract negotiation; human-only |
| CONTRACT_TERMS | Legal agreement; human-only |
| GDPR_REQUEST | Privacy law compliance; human + legal |
| SOC2_REQUEST | Compliance certification question; human-only |
| DATA_SECURITY_REQUEST | Security posture question; human-only |
| PRIVACY_QUESTION | Privacy law; human-only |
| COMPLIANCE_QUESTION | Any compliance query; human-only |
| SENSITIVE_PERSONAL_DATA | Data handling; human-only |
| CUSTOM_PROPOSAL_REQUEST | Complex commercial; human-only |
| ENTERPRISE_REQUEST | High-value; human judgment required |
| HIGH_VALUE_JUDGEMENT | Any high-value account signal; human-only |
| AMBIGUOUS_INTENT | Classification uncertainty; human-only |

### Multi-Intent Blocks

If any detected intent is on the blocked list above, the entire case is blocked from autonomous send, even if the primary intent would otherwise be eligible.

Example: "Yes I'm interested, what's the price?" → POSITIVE_INTEREST + PRICING_REQUEST → BLOCKED because PRICING_REQUEST is present.

### State-Based Blocks (Permanent)

| State condition | Block reason |
|-----------------|-------------|
| `thread_identity_confident = false` | Cannot confirm this is the right prospect |
| `sender_identity_confident = false` | Cannot confirm sender account is correct |
| `campaign_identity_confident = false` | Cannot confirm campaign context |
| `active_rule_conflict = true` | Contradicting rules require human resolution |
| `duplicate_risk = true` | Idempotency check failed; do not retry automatically |
| `correction_pending = true` | A human correction is in progress for this case |
| `human_correction_active = true` | Human has flagged this case for review |
| Campaign not in `campaign_allowlist` | Not explicitly approved for autonomous |
| Sender not in `sender_allowlist` | Not explicitly approved for autonomous |
| `confidence < threshold` | Below minimum confidence for autonomous action |
| Out of working-hours window | Must wait for eligible window |
| `emergency_disabled = true` | Kill switch active |
| `autonomous_enabled = false` | System not in autonomous mode |
| `dry_run = true` | Dry run mode; no real sends |

### System-Level Blocks

- Autonomous layer may never call the Instantly send/reply API directly. All sends must route through the existing Sender workflow.
- Autonomous layer may never modify Decision, HumanApproval, Proxy, Intake, Sender, ErrorHandler, SLAWatchdog, or FullTestHarness workflows.
- Autonomous layer may never read or write secrets, API keys, or credentials.
- Autonomous layer may never bypass the idempotency check.
- Autonomous layer may never send a second reply to a thread that has already received a reply from this system.
- Autonomous layer may never send outside working-hours window (configurable).

---

## What the Autonomous Layer May Do (Shadow Mode — Current)

In shadow mode (current and planned Mode 1):

- Evaluate eligibility of every supervised case in parallel
- Log the shadow decision (what it WOULD have done) to the shadow candidate log
- Produce daily digest summaries for owner review
- Contribute learning signals from autonomous-path evaluations
- Write to shadow DataTable (not yet created)

In shadow mode, the autonomous layer:
- NEVER sends any reply
- NEVER calls Instantly API
- NEVER routes through Sender
- NEVER modifies any workflow

---

## What the Autonomous Layer May Do (Controlled Pilot — Future, Requires Approval)

After owner approval of controlled pilot:

- Evaluate eligibility of candidates meeting all criteria
- For candidates meeting ALL gates including working-hours and allowlists:
  - Prepare draft using existing AI draft infrastructure
  - Apply active rules from Decision node D
  - Log candidate to shadow log with `would_send_live_now = true`
  - If `dry_run = false` AND `autonomous_enabled = true` AND daily cap not exceeded:
    - Route through existing Sender workflow (same path as supervised approvals)
    - Log the send to audit trail
    - Queue case for next-morning post-action review
- Produce daily digest including autonomous sends

Even in controlled pilot, the autonomous layer:
- NEVER sends more than `live_pilot_daily_cap` cases per day
- NEVER sends to a campaign not in `campaign_allowlist`
- NEVER sends from a sender not in `sender_allowlist`
- NEVER sends for a blocked intent type
- NEVER bypasses post-action review requirement

---

## Boundary Enforcement

All boundaries are enforced at multiple independent layers:

1. **Config layer** — `autonomous_enabled`, `dry_run`, `shadow_only` must all be set correctly
2. **Eligibility engine** — independent check of all gate conditions before any action
3. **Intent blocklist** — hardcoded in eligibility engine, cannot be overridden by config
4. **Daily cap** — atomic counter prevents exceeding the cap even under concurrent execution
5. **Sender workflow** — existing Sender workflow has its own idempotency and send-state checks
6. **Audit trail** — every evaluation and action logged regardless of outcome

No single configuration change should be sufficient to enable live autonomous sends. At minimum: `autonomous_enabled = true` AND `dry_run = false` AND `shadow_only = false` AND a valid `campaign_allowlist` entry AND a valid `sender_allowlist` entry AND working-hours window AND `emergency_disabled = false` must all be true simultaneously.

---

## Related Documents

- `docs/AUTONOMOUS_PHASE_5_ARCHITECTURE.md` — overall architecture
- `docs/AUTONOMOUS_SAFETY_MODEL.md` — safety gates in detail
- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — emergency controls
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — failure scenarios
