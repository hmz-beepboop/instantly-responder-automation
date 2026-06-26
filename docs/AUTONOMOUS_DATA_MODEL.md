# Autonomous Data Model

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Overview

The autonomous layer requires three new DataTables in n8n (or equivalent persistent storage). This document defines the data model for each.

---

## DataTable 1 — hmz-autonomous-shadow-log

**Purpose:** Records every candidate evaluated by the eligibility engine.

**Primary key:** `correlation_id` (unique per evaluation)

**Key columns:**

| Column | Type | Description |
|--------|------|-------------|
| correlation_id | string | Primary key |
| case_id | string | Linked case from Decision workflow |
| thread_id | string | Prospect thread |
| campaign_id | string | Campaign context |
| sender_email | string | Sending account |
| recipient_email | string | Prospect email |
| incoming_text_excerpt | string | First 200 chars |
| detected_micro_intent | string | Classification |
| additional_intents | JSON array | Additional intents |
| confidence | decimal | 0.0–1.0 |
| would_be_shadow_eligible | boolean | Shadow eligibility |
| would_send_live_now | boolean | Live send gate (always false in shadow) |
| blocked_reason | string (nullable) | Block reason |
| recommended_action | string | SHADOW_LOG / HUMAN_REVIEW / BLOCKED / ELIGIBLE |
| autonomous_mode_state | string | Current mode |
| timestamp | datetime | UTC evaluation time |
| reviewer_action_needed | boolean | Needs human review |

---

## DataTable 2 — hmz-autonomous-review-queue

**Purpose:** Tracks cases requiring owner review.

**Primary key:** `queue_id`

| Column | Type | Description |
|--------|------|-------------|
| queue_id | string | Primary key |
| case_id | string | Linked case |
| correlation_id | string | Linked shadow log entry |
| queue_reason | string | Why in queue |
| priority | string | HIGH / MEDIUM / LOW |
| was_autonomous_send | boolean | Whether a send occurred |
| draft_sent | string (nullable) | Draft content if sent |
| awaiting_post_action_review | boolean | True until reviewed |
| created_at | datetime | When queued |
| reviewed_at | datetime (nullable) | When reviewed |
| review_outcome | string (nullable) | Outcome after review |

---

## DataTable 3 — hmz-autonomous-daily-digest

**Purpose:** Stores generated daily digests for audit and trend tracking.

**Primary key:** `digest_id`

| Column | Type | Description |
|--------|------|-------------|
| digest_id | string | Primary key |
| digest_period_start | datetime | Period start |
| digest_period_end | datetime | Period end |
| generated_at | datetime | When generated |
| total_candidates | integer | Total evaluated |
| shadow_eligible | integer | Shadow eligible count |
| blocked | integer | Blocked count |
| autonomous_sends | integer | Live sends (0 in shadow) |
| kill_switch_events | integer | Kill switch activations |
| digest_json | JSON | Full digest content |

---

## Existing DataTables (Phase 1C-2B) — Unchanged

- `hmz-learning-events` — learning events from supervised AND autonomous corrections
- `hmz-rule-candidates` — proposed_shadow and active rule candidates

These do not need modification. Autonomous correction events use the same sl_p2_correction_event structure.

---

## DataTable IDs (To Be Confirmed)

The new DataTables (hmz-autonomous-shadow-log, hmz-autonomous-review-queue, hmz-autonomous-daily-digest) do not exist yet. They must be created in n8n when shadow mode is activated (Phase 5F).

The existing DataTable IDs (`hmz-learning-events`, `hmz-rule-candidates`) are confirmed in production but the exact DataTable row-audit API endpoint format is still pending verification (S1/S2 gap from Phase 4J).

---

## Related Documents

- `docs/AUTONOMOUS_DATATABLE_SCHEMA_PROPOSAL.md` — DataTable creation proposal
- `outputs/autonomous_datatable_schema.json` — machine-readable schema
- `docs/AUTONOMOUS_SHADOW_CANDIDATE_LOGGING_SPEC.md` — logging spec uses this model
