# Instantly Verification Evidence

## Purpose

Sanitised verification record for the HMZ AI Automation Instantly reply-automation project.

Status vocabulary:

- DOCUMENTED
- OBSERVED
- VERIFIED
- PARTIALLY VERIFIED
- BLOCKED
- NOT TESTED

No API keys, webhook receiver tokens, custom secret-header values, or real recipient addresses are included.

## Evidence Matrix

| Gate | Capability | Status | Evidence summary |
|---|---|---:|---|
| V1 | API V2 access | VERIFIED | Read-only access to webhook event types, accounts, and emails succeeded. |
| V1 | `reply_received` availability | VERIFIED | Workspace event-types response included `reply_received`. |
| V1 | Dedicated sender availability | VERIFIED | Controlled sender was connected, setup complete, warm-up active, score 100, daily limit 40. |
| V2 | Genuine reply webhook | VERIFIED | A genuine `reply_received` webhook was captured from an owned recipient. |
| V2 | Canonical inbound Email ID | VERIFIED | Webhook `email_id` matched the retrievable inbound Email object ID and was the correct reply target. |
| V2 | Thread identifiers | VERIFIED | Inbound and original outbound Email objects shared the same `thread_id`; `message_id` was also present. |
| V3 | API reply accepted | VERIFIED | One controlled `POST /api/v2/emails/reply` returned HTTP 200. |
| V3 | Correct sender | VERIFIED | Retrieved sent Email object used the expected connected sending account. |
| V3 | Thread continuity | VERIFIED | The reply preserved the Instantly thread and the recipient's Gmail conversation. |
| V3 | Duplicate prevention in controlled test | VERIFIED | Exactly one new sent Email object and one received reply were observed. |
| V4A | Ordinary reply stops campaign follow-up | VERIFIED | Replying controls received Step 1 and no Step 2; non-replying matched control received both steps. |
| V4B | Interest-status update | VERIFIED | HTTP 202 was followed by retrieval proving the interest status and timestamp changed. |
| V4C | Subsequence removal | VERIFIED | Controlled lead was moved into, retrieved from, removed from, and re-retrieved outside a paused subsequence. |
| V4D | Exact email block-list enforcement | VERIFIED | Blocked controlled address received no campaign email; matched unblocked control received one; block entry was later removed. |
| V4E | Genuine unsubscribe webhook | VERIFIED | Genuine `lead_unsubscribed` event was received with the expected campaign and controlled recipient. |
| V4E | Source-campaign unsubscribe state | VERIFIED | Source lead changed to status `-2`; Step 1 count was one and follow-up count remained zero. |
| V4E | Automatic exact block-list creation | NOT TESTED | No exact entry was observed, but absence alone does not prove every automatic suppression mechanism. |
| V4E4 | Cross-campaign import | VERIFIED | Previously unsubscribed controlled recipient was accepted into a fresh campaign as active. |
| V4E4 | Cross-campaign send | VERIFIED | Target and matched control each produced exactly one matching campaign Email object. |
| V4E4 | Ordinary unsubscribe scope | VERIFIED | Under the tested workspace configuration, ordinary unsubscribe was campaign-local rather than workspace-wide. |
| V5 Layer 1 | Local retry and fault policy | VERIFIED | Local deterministic fault-injection harness exercised retry classification, `Retry-After` handling, and uncertain-send no-retry against all listed fault cases. |
| V5 Layer 2 | Lost-response uncertain-send reconciliation | VERIFIED | One controlled lost-response proxy test: request reached Instantly, response was lost, state became `SEND_UNCERTAIN`, no second POST occurred, reconciliation found exactly one match, became `RECONCILED_SENT`, no duplicate. Zero/multiple-match cases are policy-verified (escalate, no second POST) but not exercised against a live Instantly response. |

## V4E4 Sanitised Result

- Test date: 2026-06-14 UTC
- Campaign status: Draft before activation; Active after activation
- Activation attempts: 1
- Activation HTTP status: 200
- Target initial status: 1
- Target final status: 3
- Control initial status: 1
- Control final status: 3
- Target matching Email objects: 1
- Control matching Email objects: 1
- Duplicate observed: no
- Primary verdict: `CAMPAIGN_LOCAL_UNSUBSCRIBE_VERIFIED`
- Verification passed: true

## Architectural Consequence

Campaign-level unsubscribe state must not be treated as workspace-wide do-not-contact protection.

The production unsubscribe path must independently enforce:

1. Source-campaign unsubscribe or stop state.
2. Exact email-level workspace suppression.
3. Idempotent handling of both operations.
4. Escalation when either operation fails or its outcome is uncertain.

## Remaining Verification Work

### V5 Layer 1

Use local fault injection for:

- 400
- 401
- 402
- 403
- 404 reply target
- 429 with and without `Retry-After`
- 500
- 502
- 503
- 504
- connection refused
- connection reset
- failure before request submission
- delayed response
- malformed response
- timeout after request submission

### V5 Layer 2

Use one controlled lost-response proxy test to prove:

- Request may reach Instantly while the client loses the response.
- Send state becomes `SEND_UNCERTAIN`.
- No second reply POST occurs before reconciliation.
- Reconciliation searches using thread, sender, recipient, subject, narrow timestamp, and unique marker.
- Exactly one match becomes sent.
- Zero or multiple matches escalate to human review.
- No duplicate email is produced.

## Readiness Boundary

V5 Layer 1 and Layer 2 are now VERIFIED. A live n8n Sender execution against real Instantly endpoints was not performed in Phase 4 or Phase 5 (prohibited by scope) and remains outside this evidence set. Per `reports/VALIDATION_REPORT.md`, the project is `READY_FOR_DRY_RUN`, not `READY_FOR_CONTROLLED_LIVE_TEST`.
