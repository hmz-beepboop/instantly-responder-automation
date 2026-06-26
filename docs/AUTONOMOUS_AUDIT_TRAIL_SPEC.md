# Autonomous Audit Trail Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Purpose

The audit trail is a tamper-evident, comprehensive log of every action taken by the autonomous layer. It is the ultimate source of truth for compliance, incident investigation, and rollback decisions.

---

## Audit Trail Entry Types

| Event Type | When Created | Description |
|------------|-------------|-------------|
| `ELIGIBILITY_EVALUATED` | Every candidate evaluation | Full decision object |
| `SHADOW_LOG_CREATED` | Every shadow candidate | Shadow log entry |
| `DRAFT_PREPARED` | When a draft is produced | Draft content and active rules |
| `AUTONOMOUS_SEND_ATTEMPTED` | Before any send | Attempt record |
| `AUTONOMOUS_SEND_COMPLETED` | After successful send | Completion confirmation |
| `AUTONOMOUS_SEND_FAILED` | After failed send | Error details |
| `DAILY_CAP_HIT` | When daily cap is reached | Cap state |
| `KILL_SWITCH_ACTIVATED` | When emergency_disabled set to true | Who/when/why |
| `KILL_SWITCH_DEACTIVATED` | When emergency_disabled set to false | Who/when/why |
| `CONFIG_CHANGED` | When autonomous config is modified | Before/after diff |
| `POST_ACTION_REVIEW_SUBMITTED` | When owner completes review | Review outcome |
| `LEARNING_EVENT_CREATED` | When a learning event is written | Learning event ID |
| `ESCALATION_TRIGGERED` | When a case requires immediate attention | Escalation reason |
| `DUPLICATE_PREVENTED` | When idempotency check prevents a duplicate | Case ID |

---

## Required Fields for All Audit Entries

| Field | Type | Description |
|-------|------|-------------|
| `audit_id` | string | Globally unique audit entry ID |
| `event_type` | string | One of the event types above |
| `case_id` | string | Linked case ID (if applicable) |
| `correlation_id` | string | Linked correlation ID |
| `timestamp` | string | ISO 8601 UTC |
| `autonomous_mode_state` | string | Mode at time of event |
| `dry_run_state` | boolean | dry_run value at time of event |
| `shadow_only_state` | boolean | shadow_only value at time of event |
| `emergency_disabled_state` | boolean | emergency_disabled value at time of event |
| `actor` | string | "AUTONOMOUS_ENGINE" / "OWNER" / "SYSTEM" |
| `details` | object | Event-specific details |

---

## Retention Policy

| Entry Type | Minimum Retention |
|------------|------------------|
| ELIGIBILITY_EVALUATED | 90 days |
| SHADOW_LOG_CREATED | 90 days |
| DRAFT_PREPARED | 1 year |
| AUTONOMOUS_SEND_* | 2 years |
| KILL_SWITCH_* | 2 years |
| CONFIG_CHANGED | 2 years |
| POST_ACTION_REVIEW_SUBMITTED | 2 years |
| ESCALATION_TRIGGERED | 2 years |

---

## What Must NOT Appear in the Audit Trail

- API keys, secrets, or credentials
- Full prospect email bodies (use excerpt only)
- n8n webhook secrets
- Internal system prompts in full (use hash/reference)

---

## Audit Trail Integrity

The audit trail must be append-only — existing entries must not be modified or deleted within the retention period. If an entry was created in error, create a new `CORRECTION` entry referencing the original.

---

## Related Documents

- `docs/AUTONOMOUS_SHADOW_CANDIDATE_LOGGING_SPEC.md` — shadow log (subset of audit trail)
- `docs/AUTONOMOUS_INCIDENT_RESPONSE_RUNBOOK.md` — using the audit trail for incident investigation
- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — audit trail during rollback
