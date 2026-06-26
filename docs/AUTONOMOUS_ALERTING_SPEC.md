# Autonomous Alerting Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Alert Rules

### CRITICAL Alerts (Immediate — owner action required)

| Alert | Condition | Response |
|-------|-----------|----------|
| `KILL_SWITCH_ACTIVATED` | emergency_disabled set to true | Notify all escalation_channels immediately |
| `UNSUBSCRIBE_SENT` | Autonomous send to a prospect with UNSUBSCRIBE intent | CRITICAL — investigate immediately |
| `BLOCKED_INTENT_PROCESSED` | A permanently blocked intent was processed autonomously | CRITICAL — kill switch if confirmed |
| `DAILY_CAP_VIOLATED` | Sends exceeded max_autonomous_sends_per_day | CRITICAL — investigate counter failure |
| `DUPLICATE_SEND_DETECTED` | Idempotency failure — two sends to same thread | CRITICAL — apologise to prospect |

### HIGH Alerts (Within 1 hour)

| Alert | Condition | Response |
|-------|-----------|----------|
| `BAD_RESPONSE_DETECTED` | Post-action review rated `bad_response` | Review the case; consider tightening eligibility |
| `SHOULD_HAVE_ESCALATED` | Post-action review rated `should_have_escalated` | Review eligibility gate gap |
| `HIGH_RISK_ESCALATION` | Case with legal/compliance/hostile intent arrived | Confirm blocked; check routing |
| `PROSPECT_NEGATIVE_REPLY` | Prospect replied negatively to autonomous send | Create human case immediately |
| `ELIGIBILITY_ENGINE_EXCEPTION` | Exception in eligibility evaluation | Check engine; case routed to supervised path |

### MEDIUM Alerts (Within 4 hours)

| Alert | Condition | Response |
|-------|-----------|----------|
| `POST_ACTION_REVIEW_OVERDUE` | Post-action review not completed within 24h of send | Reminder to owner |
| `LEARNING_EVENT_SPIKE` | More than 5 learning events in one day | Review patterns; may indicate eligibility issue |
| `DIGEST_NOT_GENERATED` | Daily digest not generated at expected time | Check digest generation workflow |
| `CONFIG_CHANGED` | Autonomous config modified | Confirm change was authorised |

### LOW Alerts (Daily digest)

| Alert | Condition | Response |
|-------|-----------|----------|
| `SHADOW_ELIGIBLE_ZERO` | No shadow-eligible candidates in 24h | Review eligibility config if traffic exists |
| `RULE_CANDIDATES_PENDING` | Proposed_shadow candidates older than 7 days | Reminder to review |
| `OUT_OF_HOURS_CANDIDATE_VOLUME` | More than 10 out-of-hours candidates per day | Consider extending working hours |

---

## Alert Delivery

Alerts are sent to `escalation_channels` in the config. Until delivery is implemented:
- CRITICAL and HIGH alerts: appear as HIGH priority items in the daily digest
- MEDIUM alerts: appear in digest
- LOW alerts: appear in digest summary

---

## Related Documents

- `outputs/autonomous_alert_rules_sample.json` — machine-readable alert rules
- `docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md` — digest as primary alert delivery
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — alert response procedures
- `docs/AUTONOMOUS_INCIDENT_RESPONSE_RUNBOOK.md` — incident response
