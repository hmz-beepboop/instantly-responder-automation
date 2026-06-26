# Manual Test Packet — Learning-Only Amendments (SL-PHASE-5P)

**Date:** 2026-06-26
**HumanApproval versionId:** 9c71882f-a096-48a9-861a-37e5424035ae

See `NEXT_MANUAL_TEST_PACKET_REVIEW_REOPEN_REPEAT_SEND.md` Test 3 for the full learning-only approval protocol.

## Quick reference

| Action | What happens |
|--------|-------------|
| `approve_learning_only` | Status → LEARNING_REVISION_APPROVED; revision_count++; no email sent |
| `approve_and_send_followup` | Status → FOLLOWUP_SEND_PENDING_MANUAL; no auto-send; metadata captured |
| Original `approve` | Unchanged; status → RESPONSE_APPROVED; revision_count=1 |

## What is stored per learning revision

When `approve_learning_only` is submitted, `decision_payload` gains:
- `revision_count`: incremented
- `latest_approved_reply_text`: latest edited reply
- `latest_corrections.corrected_category`: latest category correction
- `latest_corrections.corrected_micro_intent`: latest micro intent correction
- `latest_corrections.correction_reason_broad_category`: reason
- `latest_corrections.correction_reason_micro_intent`: reason
- `latest_corrections.correction_reason_additional_intents`: reason
- `revision_history`: array of all revisions with full per-revision data

## Superseded/deprecated candidates

When a reviewer submits `approve_learning_only` with a DIFFERENT target classification or scope than a prior revision, the system records both. The `revision_history` array shows the progression. Manual review of the revision history by the owner or Claude is needed to mark earlier candidates as superseded. There is no automatic deprecation in SL-PHASE-5P.

## What is NOT yet implemented

- Automatic Sender call for `approve_and_send_followup` (requires SL-PHASE-5Q)
- `desired_future_behavior` and `draft_revision_type` prefill on reopen (future patch)
- Explicit "supersedes revision N" flag (future patch)
