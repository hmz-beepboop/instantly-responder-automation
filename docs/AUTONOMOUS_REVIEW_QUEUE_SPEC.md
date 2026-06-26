# Autonomous Review Queue Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Purpose

The review queue collects all autonomous candidates that require owner attention — whether because the action was blocked (and owner should know why), because an autonomous send occurred (and owner should verify quality), or because a follow-up is needed.

---

## Review Queue Entry Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `queue_id` | string | YES | Unique review queue entry ID |
| `case_id` | string | YES | Linked case ID from shadow log |
| `correlation_id` | string | YES | Linked correlation ID from shadow log |
| `thread_id` | string | YES | Prospect thread ID |
| `campaign_id` | string | YES | Campaign ID |
| `sender_email` | string | YES | Sender account |
| `recipient_email` | string | YES | Prospect email |
| `queue_reason` | string | YES | Why this is in the review queue (see Reason Codes) |
| `priority` | string | YES | HIGH / MEDIUM / LOW |
| `incoming_text_excerpt` | string | YES | First 200 chars of prospect's reply |
| `recommended_action` | string | YES | SHADOW_LOG / HUMAN_REVIEW / BLOCKED_PERMANENT / AUTONOMOUS_ELIGIBLE |
| `was_autonomous_send` | boolean | YES | True if an autonomous send occurred |
| `draft_sent` | string | NO | The draft that was sent (if was_autonomous_send=true) |
| `awaiting_post_action_review` | boolean | YES | True if post-action review form not yet completed |
| `post_action_review_url` | string | NO | Direct link to post-action review form (when implemented) |
| `created_at` | string | YES | ISO 8601 UTC timestamp |
| `reviewed_at` | string | NO | Timestamp when owner completed review |
| `review_outcome` | string | NO | GOOD / ACCEPTABLE / BAD / ESCALATED |

---

## Queue Reason Codes

| Code | Description | Priority |
|------|-------------|----------|
| `AUTONOMOUS_SEND_OCCURRED` | An autonomous send was made; verify quality | HIGH |
| `HIGH_RISK_BLOCKED` | Case was blocked due to a high-risk signal | MEDIUM |
| `CONFIDENCE_BELOW_THRESHOLD` | Case blocked due to low confidence | LOW |
| `OUT_OF_HOURS_CANDIDATE` | Eligible candidate arrived out of hours | LOW |
| `ESCALATION_TRIGGERED` | Any safety escalation flag | HIGH |
| `FOLLOW_UP_NEEDED` | A follow-up check is scheduled for this case | MEDIUM |
| `LEARNING_EVENT_CREATED` | A learning event was created from this case | LOW |
| `KILL_SWITCH_TRIGGERED` | Kill switch was triggered; review pending cases | HIGH |
| `DUPLICATE_RISK_DETECTED` | Idempotency check indicated possible duplicate | HIGH |
| `ACTIVE_RULE_CONFLICT` | Active rules conflict; needs human resolution | MEDIUM |

---

## Review Queue Processing

### Daily review routine

1. Open daily digest — it contains a summary of the review queue
2. Action all HIGH priority items first
3. For each `AUTONOMOUS_SEND_OCCURRED` case: open post-action review form and complete it
4. For each `HIGH_RISK_BLOCKED` case: confirm the block was correct; note any patterns
5. For each `ESCALATION_TRIGGERED` case: determine if kill switch is needed
6. Mark each item as reviewed once actioned

### After a controlled pilot send

For every case where `was_autonomous_send=true`:
1. Review the draft that was sent (`draft_sent` field)
2. Check prospect's reaction (if any reply received already)
3. Complete the post-action review form (`docs/AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md`)
4. If quality was bad: create correction event; consider tightening eligibility

---

## Related Documents

- `outputs/autonomous_review_queue_sample.json` — sample queue entries
- `docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md` — digest includes queue summary
- `docs/AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md` — review form for completed sends
- `docs/AUTONOMOUS_SHADOW_CANDIDATE_LOGGING_SPEC.md` — source log entries
