# SL-PHASE-5P — Review Reopen, Learning Amendments, Google Chat Expiry

**Date applied:** 2026-06-26
**HumanApproval versionId before:** 23ffc9f2-a869-4313-a1cb-e032bd35e526
**HumanApproval versionId after:** 9c71882f-a096-48a9-861a-37e5424035ae
**Script:** `scripts/SL-PHASE-5P-review-reopen-learning-amendments-consolidated.ps1`

---

## What Was Added

### Node H — Allow form access for approved/sent cases

Previously, `H. Validate Review Token (GET)` rejected cases with status `RESPONSE_APPROVED` or `LEARNING_REVISION_APPROVED` with `ALREADY_DECIDED`. After this patch, these statuses allow form access so reviewers can reopen and submit learning amendments.

- Expiry check is **skipped** for `RESPONSE_APPROVED` and `LEARNING_REVISION_APPROVED` (case already decided; reopen is for learning only).
- Token is still required (provides auth).

### Node J — Already-sent banner, revision counter, prefill, new action buttons

The review form now detects whether a case was already approved and sent.

**For approved/sent cases (`RESPONSE_APPROVED`, `LEARNING_REVISION_APPROVED`):**
- Green banner: "This review was already approved and an email was already sent."
- Info block: "The fields below are prefilled with the last human-approved content, not the original AI draft."
- Revision counter: "Approved improvement revisions for this case: N"
- Reply textarea prefilled from `decision_payload.latest_approved_reply_text` (not original draft)
- Hidden original-draft field also uses latest approved reply (for change-detection)
- Corrected broad category prefilled from `decision_payload.latest_corrections.corrected_category`
- Corrected micro intent prefilled from `decision_payload.latest_corrections.corrected_micro_intent`
- Two new action buttons:
  - **Approve future learning changes only — do not send email** (`approve_learning_only`)
  - **Send another human-approved reply** (`approve_and_send_followup`)
- Repeat send reason input shown when follow-up button clicked (JavaScript)

**For pending cases (NEW, IN_REVIEW, RETRY_NEEDED):** unchanged — original approve/deny buttons shown.

### Node L — Allow submit for reopened cases

`L. Validate & Consume Review Token (POST)` now allows submissions for `RESPONSE_APPROVED` and `LEARNING_REVISION_APPROVED` cases. Expiry check is also skipped for these statuses on submit.

New field captured: `submit_repeat_send_reason` (from `body.repeat_send_reason`).

### Node N — Handle new actions, store revision metadata

**`approve_learning_only` action:**
- Sets status to `LEARNING_REVISION_APPROVED`
- Increments `decision_payload.revision_count` (+1 from prior)
- Stores `decision_payload.latest_approved_reply_text` (from submitted edited text)
- Stores `decision_payload.latest_corrections` (corrected classifications + reasons)
- Builds `decision_payload.revision_history` array with full per-revision record
- Does NOT call Sender. Does NOT send email.

**`approve_and_send_followup` action:**
- Requires `repeat_send_reason` — blocked if empty
- Sets status to `FOLLOWUP_SEND_PENDING_MANUAL`
- Stores `decision_payload.controlled_send_key = case_id + "|f" + revisionNumber`
- Sets `decision_payload.sender_audit_required = true`
- Does NOT automatically call Sender (requires SL-PHASE-5Q Sender idempotency audit)

**`approve` action (existing, updated):**
- Now stores `decision_payload.revision_count = 1` on first approval
- Now stores `decision_payload.latest_approved_reply_text`
- Now stores `decision_payload.latest_corrections` (from submitted correction fields)

### Node D — Google Chat expiry text

Google Chat notification now includes:
```
Review link expires: <ISO timestamp> (N min remaining)
```
Or if no expiry is set:
```
Review link expiry: no fixed expiry currently configured
```

Current TTL is 60 minutes (from `CONFIG.review.review_token_ttl_minutes`).

### Node Q2 — Result pages for new statuses

New result pages added (shown after submit when no email is sent):

**`LEARNING_REVISION_APPROVED`:**
> Learning revision approved — no email sent
> Draft improvement learning captured.
> Approved improvement revisions for this case: N

**`FOLLOWUP_SEND_PENDING_MANUAL`:**
> Follow-up send captured — manual send required
> The email was NOT automatically sent.
> Controlled repeat send requires Sender idempotency audit (SL-PHASE-5Q).
> Controlled send key: case-xxx|f2 (revision 2)

---

## What Was NOT Changed

| Item | Status |
|------|--------|
| Sender workflow | UNCHANGED |
| Decision workflow | UNCHANGED |
| Proxy workflow | UNCHANGED |
| Shadow Evaluator | UNCHANGED, active=false |
| `dry_run` | UNCHANGED (false, controlled by CONFIG) |
| `autonomous_enabled` | UNCHANGED (false) |
| Duplicate-send protection | PRESERVED — no accidental retry path created |

---

## Known Limitations

| # | Limitation |
|---|------------|
| 1 | `approve_and_send_followup` does NOT automatically send — requires SL-PHASE-5Q (Sender idempotency audit) |
| 2 | Revision history is stored in `decision_payload` JSON — no dedicated DataTable column |
| 3 | Classification correction prefill works only if `latest_corrections` was stored in prior approval (requires at least one prior `approve` or `approve_learning_only` via this patched version) |
| 4 | `desired_future_behavior` and `draft_revision_type` are NOT prefilled in reopened forms (not stored in `latest_corrections`; would require adding those fields to `N` in a future patch) |

---

## Verification

**108/108 code-level checks PASS** (106 in main run + 2 in verify pass after API fix).

Manual verification still required:
1. Open an existing `RESPONSE_APPROVED` case — confirm already-sent banner shows
2. Submit `approve_learning_only` — confirm no email sent, revision counter increments
3. Open same case again — confirm revision counter shows N+1

See `docs/NEXT_MANUAL_TEST_PACKET_REVIEW_REOPEN_REPEAT_SEND.md` for test protocol.
