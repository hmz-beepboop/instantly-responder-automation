# Autonomous Daily Digest Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Purpose

The daily digest is a structured summary of all autonomous layer activity in the past 24 hours. It is the primary tool for the owner to maintain oversight of the autonomous layer without needing to review every log entry individually.

---

## Digest Content

### Section 1 — Overall Activity Summary

| Field | Description |
|-------|-------------|
| `digest_period_start` | Start timestamp of digest period |
| `digest_period_end` | End timestamp |
| `digest_generated_at` | When this digest was created |
| `autonomous_mode_state` | Current mode (SHADOW_ONLY / CONTROLLED_PILOT / etc.) |
| `kill_switch_active` | Whether kill switch was active at any point |
| `total_candidates_evaluated` | Total cases evaluated by eligibility engine |
| `shadow_eligible_count` | Cases that would be shadow-eligible |
| `blocked_count` | Cases that were blocked |
| `autonomous_sends_attempted` | Sends attempted (if mode enabled) |
| `autonomous_sends_completed` | Sends completed successfully |
| `autonomous_sends_failed` | Sends that failed or were held |

### Section 2 — Blocked Reason Breakdown

Top blocked reasons with counts:
- `intent_allowlist_empty` — N
- `campaign_not_allowlisted` — N
- `out_of_working_hours` — N
- `intent_permanently_blocked: PRICING_REQUEST` — N
- etc.

### Section 3 — High-Risk Escalations

List of any cases that triggered:
- UNSUBSCRIBE / DNC / OPT_OUT
- LEGAL_COMPLAINT
- HOSTILE_REPLY / ANGRY_REPLY
- BILLING_DISPUTE / REFUND_REQUEST
- KILL_SWITCH_TRIGGERED

Each escalation includes case_id, thread_id, micro_intent, blocked_reason.

### Section 4 — Autonomous Sends (if applicable)

For each autonomous send:
- `case_id`
- `thread_id`
- `recipient_email`
- `micro_intent`
- `draft_excerpt` (first 200 chars)
- `active_rules_applied`
- `confidence`
- `post_action_review_pending`

### Section 5 — Drafts Needing Review

Cases where a draft was prepared but not sent (shadow mode), requiring owner assessment of draft quality:
- `case_id`
- `micro_intent`
- `draft_excerpt`
- `blocked_reason` (why it wasn't sent)

### Section 6 — Follow-Ups Needed

Cases where a follow-up check is scheduled:
- `case_id`
- `follow_up_reason`
- `follow_up_due`

### Section 7 — Learning Events Generated

| Field | Value |
|-------|-------|
| `total_learning_events` | N |
| `classification_corrections` | N |
| `draft_revisions` | N |
| `intent_edits` | N |
| `proposed_shadow_created` | N |
| `rules_pending_review` | N (total pending in DataTable) |

### Section 8 — Recommended Owner Actions

Prioritised list of actions for the owner:
1. HIGH: Review N autonomous sends (post-action review forms)
2. HIGH: Review N escalations
3. MEDIUM: Review N high-risk blocks
4. LOW: Review N rule candidates
5. LOW: Review N out-of-hours candidates for pattern

---

## Digest Delivery

The digest is generated at the frequency specified in `digest_frequency` config (default: daily, at the end of working hours or at a fixed time).

Delivery channels: `escalation_channels` in config (email, Slack webhook, etc.).

Until delivery is implemented, the digest is written to a local output file and the owner checks it manually.

---

## Digest Schema (Machine-Readable)

See `outputs/autonomous_daily_digest_sample.json` for an example.

---

## Related Documents

- `outputs/autonomous_daily_digest_sample.json` — sample digest
- `docs/AUTONOMOUS_SHADOW_CANDIDATE_LOGGING_SPEC.md` — source data
- `docs/AUTONOMOUS_REVIEW_QUEUE_SPEC.md` — review queue that digest summarises
- `docs/AUTONOMOUS_AUDIT_TRAIL_SPEC.md` — full audit trail
