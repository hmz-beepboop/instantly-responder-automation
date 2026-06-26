# State and Idempotency — Implemented Validation Architecture

**Date:** 2026-06-14  
**Status:** Implemented source of truth for the current validation system.

This document supersedes the earlier Phase 2 storage proposal wherever that proposal refers to a relational `sends` table, partial unique indexes, or automatic retries after zero-match reconciliation.

## 1. Storage boundaries

The current validation system uses two persistence mechanisms:

1. **n8n Data Tables**
   - Used by the Phase 3 Reply Intake path for persistent inbound-event idempotency and related validation records.
   - Phase 3 runtime acceptance verified duplicate-event termination and persistence across executions.

2. **`hmz-send-state` internal sidecar**
   - Used for atomic send ownership, durable send state, sanitised error records, unfinished-record queries, alert deduplication, and Phase 4B result persistence.
   - Runs on the internal Docker Compose network.
   - Reachable by n8n at `http://hmz-send-state:5681`.
   - Has no published host port.
   - Persists data in a named Docker volume.
   - Stores no API keys, Authorization headers, full message bodies, full webhook payloads, or raw API responses.

The current implementation does **not** use a relational `sends` table or a partial unique database index.

## 2. Inbound-event idempotency

Reply Intake derives and persists an inbound-event idempotency key before invoking downstream logic.

Verified behaviour:

- The first eligible event creates the persistent record.
- A repeated event updates/retrieves the existing record and terminates as a duplicate.
- Duplicate events do not invoke the Decision Engine.
- Malformed events use a content-derived fallback key rather than collapsing into one shared empty-identifier key.
- Duplicate terminal outcome is `COMPLETED_NO_SEND` / `NOOP`.

The exact Phase 3 implementation and runtime evidence remain in the Phase 3 validation reports.

## 3. Stable send key

The Sender derives a stable SHA-256 send key from:

- canonical inbound Instantly Email object ID
- connected sender account
- controlled recipient
- policy/template identity

A random body marker is deliberately excluded.

Consequences:

- Concurrent executions derive the same key.
- A later rerun derives the same key.
- A new random marker cannot bypass duplicate protection.

## 4. Atomic send ownership

The sidecar acquires ownership using exclusive file creation:

```text
open(lockPath, "wx")
```

Two protections apply:

1. **Concurrent protection**
   - The first execution creates the lock.
   - A simultaneous second execution receives `LOCK_ALREADY_HELD`.
   - The losing path must stop before any reply POST.

2. **Sequential-rerun protection**
   - Send state is written durably with a temporary-file write followed by atomic rename.
   - A later execution for the same stable send key receives `DURABLE_STATE_EXISTS`.
   - Releasing the temporary lock does not permit a later duplicate send because the durable state remains.

This behaviour was verified by Phase 4A tests and the V5 Layer 2 harness.

## 5. Send states

Implemented send states:

- `READY`
- `LOCKED`
- `DRY_RUN_OK`
- `SUBMITTING`
- `SENT`
- `SEND_UNCERTAIN`
- `SENT_RECONCILED`
- `HUMAN_REVIEW_ZERO_MATCHES`
- `HUMAN_REVIEW_MULTIPLE_MATCHES`
- `PERMANENT_FAILURE`
- `AUTH_OR_PLAN_FAILURE`
- `INVALID_REPLY_TARGET`
- `RETRY_EXHAUSTED`
- `BLOCKED`

Transitions are forward-only.

Important rules:

- `DRY_RUN_OK` is terminal.
- `SEND_UNCERTAIN` may transition only to:
  - `SENT_RECONCILED`
  - `HUMAN_REVIEW_ZERO_MATCHES`
  - `HUMAN_REVIEW_MULTIPLE_MATCHES`
- Zero or multiple reconciliation matches never transition back to submission.
- No uncertain or human-review state may issue a second reply POST.
- Terminal durable state blocks later reruns.

The implemented state name is `SENT_RECONCILED`, not `RECONCILED_SENT`.

## 6. Retry policy

Maximum total attempts for retryable pre-confirmation outcomes: three, including the first attempt.

Policy:

- 400: `PERMANENT_FAILURE`, no retry
- 401, 402, 403: `AUTH_OR_PLAN_FAILURE`, no retry
- 404 invalid reply target: `INVALID_REPLY_TARGET`, no retry
- 429: bounded retry; honour valid `Retry-After`
- 500, 502, 503, 504: bounded retry
- Proven pre-submission network failure: bounded retry allowed
- Failure where submission cannot be ruled out: `SEND_UNCERTAIN`
- Post-submission timeout: `SEND_UNCERTAIN`
- Malformed successful response: `SEND_UNCERTAIN`

`SEND_UNCERTAIN` is never blindly retried.

## 7. Reconciliation

Reconciliation is read-only.

It searches using the verified Instantly Email fields and locally filters by:

- thread
- sender
- recipient
- exact subject
- narrow timestamp window
- unique marker/fingerprint

Outcomes:

- The same single matching Email object on repeated checks:
  `SENT_RECONCILED`
- Zero matches by the deadline:
  `HUMAN_REVIEW_ZERO_MATCHES`
- More than one match:
  `HUMAN_REVIEW_MULTIPLE_MATCHES`

Zero or multiple matches require human review and never trigger a second POST.

V5 Layer 2 live-tested the exactly-one-match path after deliberately losing the upstream response. Zero and multiple paths are deterministic-policy and local-harness verified, not live Instantly exercised.

## 8. Error persistence

The Error Handler writes sanitised records through:

```text
POST /v1/error
```

The sidecar stores records atomically under its durable volume.

Records may include sanitised:

- source workflow
- execution reference
- failed node
- intake identifier/hash
- send key
- send state
- HTTP status
- error class
- attempt
- retryability
- operator action

Credential-like fields are redacted. Message/body/payload content is replaced with redacted placeholders. Email-like identifiers are hashed.

There is no implemented relational `errors` table in the validation architecture.

## 9. Watchdog and alert state

The sidecar provides:

- `GET /v1/unfinished`
- `POST /v1/error/:errorId/resolve`
- `POST /v1/alert/dedupe`
- `POST /v1/phase4b/result`
- `GET /v1/phase4b/result/:resultId`

Alert deduplication uses exclusive file creation so the same stable alert key is recorded once.

## 10. SLA timestamps

Each send record preserves:

- stable `createdAt`
- changing `updatedAt`

`createdAt` survives transitions so Processing SLO age cannot reset when state changes.

Where available, Transmission SLO timing may use:

- `transmissionStartedAt`
- `submissionStartedAt`

Processing and Transmission SLOs are separate. A draft, notification, queue item, approval request, or human-review record is never treated as a transmission.

Thresholds:

- warning: 180 seconds
- breach: 300 seconds

## 11. Suppression idempotency

For genuine unsubscribe or durable do-not-contact handling:

1. Perform or record the source-campaign stop/unsubscribe action.
2. Create an exact email-level workspace block-list entry.
3. Verify each result independently.
4. Escalate partial or uncertain completion.

Ordinary unsubscribe was verified campaign-local under the tested workspace configuration. It must not be treated as workspace-wide suppression.

## 12. Current limitations

Before any controlled live Sender path:

- Execute the Reply Sender and Error Handler in the actual n8n runtime with synthetic inputs.
- Preserve `DRY_RUN=true` and `LIVE_CAMPAIGNS=[]`.
- Keep the live Instantly adapter unreachable until explicitly approved and credentialed.
- Retention and cleanup policy for the named sidecar volume must be documented before production use.
- The sidecar is a validation-MVP mechanism, not a production-scale database claim.
