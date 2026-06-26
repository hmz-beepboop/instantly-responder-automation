# Autonomous Shadow Candidate Logging Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Purpose

Every candidate evaluated by the autonomous eligibility engine must be logged regardless of outcome. This spec defines the schema and content of the shadow candidate log.

---

## Log Schema

Each shadow log entry contains the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `case_id` | string | YES | Unique case identifier from the Decision workflow |
| `correlation_id` | string | YES | Unique per-evaluation ID for this log entry |
| `thread_id` | string | YES | Conversation thread ID from Instantly |
| `campaign_id` | string | YES | Campaign ID from Instantly |
| `sender_email` | string | YES | Sending account email |
| `recipient_email` | string | YES | Prospect email |
| `incoming_text_excerpt` | string | YES | First 200 chars of prospect's reply text |
| `detected_broad_category` | string | YES | Broad classification category |
| `detected_micro_intent` | string | YES | Micro intent classification |
| `additional_intents` | array | YES | All additional detected intents |
| `eligibility_decision` | object | YES | Full decision object from eligibility engine |
| `would_be_shadow_eligible` | boolean | YES | True if would be logged as shadow candidate |
| `would_send_live_now` | boolean | YES | True ONLY if all gates pass AND live mode active |
| `blocked_reason` | string | NO | Primary block reason if blocked |
| `recommended_action` | string | YES | SHADOW_LOG / HUMAN_REVIEW / BLOCKED_PERMANENT / AUTONOMOUS_ELIGIBLE |
| `draft_that_would_have_been_sent` | string | NO | Draft content (if draft was prepared) |
| `active_rules_used` | array | YES | Rule IDs applied during draft preparation |
| `confidence` | number | YES | Classification confidence (0.0–1.0) |
| `risk_flags` | array | YES | Any risk flags detected |
| `reviewer_action_needed` | boolean | YES | True if human review required |
| `follow_up_needed` | boolean | NO | True if a follow-up check is scheduled |
| `learning_signal_created` | boolean | YES | True if this entry created a learning event |
| `autonomous_mode_state` | string | YES | SHADOW_ONLY / DRY_RUN / DISABLED / CONTROLLED_PILOT / LIVE |
| `dry_run_state` | boolean | YES | Current dry_run config value |
| `shadow_only_state` | boolean | YES | Current shadow_only config value |
| `timestamp` | string | YES | ISO 8601 UTC timestamp of evaluation |
| `working_hours_at_evaluation` | boolean | YES | Whether evaluation occurred in working hours |

---

## Log Retention

- Shadow logs must be retained for a minimum of 90 days
- Post-action review logs must be retained for a minimum of 1 year
- Audit trail logs must be retained for a minimum of 2 years
- Logs must not contain full prospect email content (use excerpt only)
- Logs must not contain API keys, credentials, or secrets

---

## Storage Target

Shadow logs are written to the `hmz-autonomous-shadow-log` n8n DataTable (to be created when shadow mode is activated).

Columns match the schema above. Indexed on: `case_id`, `thread_id`, `campaign_id`, `timestamp`.

---

## Log Entry Lifecycle

```
Candidate evaluated → log entry created → daily digest reads log → 
owner reviews digest → reviewer_action_needed cases queued for review →
post_action_review form completed → learning_signal_created updated
```

---

## What is NOT Logged

- Full prospect email body (only first 200 chars)
- API keys or credentials
- Internal system prompts
- n8n webhook secrets

---

## Related Documents

- `outputs/autonomous_shadow_log_schema.json` — machine-readable schema
- `docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md` — how logs are aggregated
- `docs/AUTONOMOUS_AUDIT_TRAIL_SPEC.md` — full audit trail requirements
- `docs/AUTONOMOUS_REVIEW_QUEUE_SPEC.md` — review queue for flagged cases
