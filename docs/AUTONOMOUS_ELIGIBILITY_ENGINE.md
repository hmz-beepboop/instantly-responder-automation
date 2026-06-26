# Autonomous Eligibility Engine

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — OFFLINE ONLY — NOT ENABLED

---

## Purpose

The eligibility engine evaluates every inbound candidate against all autonomous safety gates and returns a structured eligibility decision object. It does NOT send anything. It produces a decision that the autonomous dispatch layer would act upon (if and when that layer is enabled).

---

## Decision Output Fields

Every evaluated scenario produces a decision object with these fields:

| Field | Type | Description |
|-------|------|-------------|
| `scenario_id` | string | Unique scenario identifier |
| `incoming_text` | string | Excerpt of the prospect's reply text |
| `broad_category` | string | Broad category (e.g. POSITIVE_INTEREST, UNSUBSCRIBE) |
| `micro_intent` | string | Micro intent (e.g. SCHEDULING_REQUEST, PROOF_OR_CASE_STUDY_REQUEST) |
| `additional_intents` | array | Additional detected intents |
| `in_human_working_hours` | boolean | True if evaluated time is within working-hours window |
| `out_of_hours` | boolean | Inverse of in_human_working_hours |
| `campaign_allowlisted` | boolean | True if campaign is in campaign_allowlist |
| `sender_allowlisted` | boolean | True if sender is in sender_allowlist |
| `intent_allowlisted` | boolean | True if primary intent is in intent_allowlist |
| `risk_flags` | array | Any risk flags detected |
| `confidence` | number | Classification confidence (0.0–1.0) |
| `active_rule_conflict` | boolean | True if two active rules conflict |
| `duplicate_risk` | boolean | True if idempotency check indicates possible duplicate |
| `thread_identity_confident` | boolean | True if thread identity is confirmed |
| `sender_identity_confident` | boolean | True if sender identity is confirmed |
| `campaign_identity_confident` | boolean | True if campaign identity is confirmed |
| `would_be_shadow_eligible` | boolean | True if this case would be logged in shadow mode |
| `would_send_live_now` | boolean | True ONLY if all gates pass AND live mode is enabled |
| `blocked_reason` | string | Primary reason for blocking (if blocked) |
| `recommended_action` | string | SHADOW_LOG / HUMAN_REVIEW / AUTONOMOUS_ELIGIBLE / BLOCKED |
| `post_action_review_required` | boolean | Always true for any non-trivial case |

**HARD RULE: `would_send_live_now` must be false in all scenarios when sample config is used (autonomous_enabled=false, shadow_only=true, dry_run=true).**

---

## Gate Evaluation Order

1. System state gates (autonomous_enabled, dry_run, shadow_only, emergency_disabled)
2. Identity gates (thread, sender, campaign)
3. Allowlist gates (campaign, sender, intent)
4. Permanent intent block check
5. Working-hours gate
6. Confidence gate
7. Duplicate risk gate
8. Daily cap gate
9. Active rule conflict check

Failure at any gate sets `would_send_live_now = false` and populates `blocked_reason`.

---

## Shadow Eligibility vs Live Eligibility

`would_be_shadow_eligible = true` means: if the system were in shadow mode, this case would be evaluated and logged. It does NOT mean the case would be sent.

`would_send_live_now = true` means: if autonomous_enabled=true, dry_run=false, shadow_only=false, AND all gates pass, this case would be sent autonomously. With the sample config, this is ALWAYS false.

---

## Scenario Categories

The 75 offline scenarios cover:

- **Positive eligible cases:** positive interest, scheduling, info requests (in and out of hours)
- **Commercial blocked cases:** pricing, contract, pilot requests
- **Legal/compliance blocked cases:** GDPR, SOC2, data security, privacy
- **Safety blocked cases:** unsubscribe, DNC, legal complaint, angry, hostile
- **Financial blocked cases:** billing, refund
- **Ambiguous cases:** ambiguous language, vague positive signals
- **Identity gate failures:** sender not allowlisted, campaign not allowlisted
- **Multi-intent cases:** one blocked intent blocks the entire case
- **Quality gate failures:** low confidence, active rule conflict, duplicate risk
- **Special reply types:** out-of-office, autoresponder, bounce, spam-like
- **Common prospect queries:** asks who this is, asks what HMZ does, requests demo/brochure/call

---

## Script Reference

```powershell
.\scripts\SL-PHASE-5C-autonomous-eligibility-engine.ps1 -UseSampleConfig -RunOfflineScenarios -ExportDecisionMatrix -ExportSummary
```

Outputs:
- `outputs/autonomous_eligibility_decision_matrix.json` — per-scenario decisions
- `outputs/autonomous_eligibility_summary.json` — aggregate stats and blocked reason breakdown

---

## Related Documents

- `docs/AUTONOMOUS_SAFETY_MODEL.md` — gate layers
- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — permanent block list
- `docs/AUTONOMOUS_WORKING_HOURS_CONFIG.md` — working hours configuration
- `outputs/autonomous_eligibility_decision_matrix.json` — scenario results
- `outputs/autonomous_eligibility_summary.json` — summary
