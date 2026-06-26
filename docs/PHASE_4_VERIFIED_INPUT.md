# Phase 4 Verified Input

**Date:** 2026-06-14  
**Purpose:** Compact technical source of truth for Phase 4 implementation.  
**Scope:** HMZ's own validation-stage Instantly responder only.  
**Mode:** `OPERATING_MODE=VALIDATION`, `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`.

This file supersedes older technical-status statements in:

- `docs/ARCHITECTURE.md` technical verification status only
- `docs/STATE_AND_IDEMPOTENCY.md` §4 reconciliation/retry behaviour only
- `docs/REPLY_POLICY.md` technical mechanism status only
- `docs/HMZ_APPROVED_REPLY_RULES.md` technical mechanism status labels only; approved policy semantics and templates remain authoritative
- `docs/CURRENT_BUILD_STATE.md`
- `docs/ASSUMPTIONS_AND_UNKNOWNS.md`
- `docs/ENVIRONMENT_AUDIT.md`
- `docs/INSTANTLY_FIELD_MAP.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `reports/PHASE_3_VALIDATION.md`
- `reports/UNRESOLVED_ITEMS.md`

It does **not** supersede approved business policy semantics, approved templates, knowledge-base content, safety rules, or Phase 3 runtime evidence. Where an older approved-policy document labels an Instantly mechanism `BLOCKED` or `PROVISIONAL`, this file supersedes only that technical-status label, not the policy decision.

## 1. Environment

- Windows 11
- PowerShell 7.6.2 available
- Node.js `v24.15.0`
- Docker Desktop with WSL2
- Isolated local n8n
- n8n `2.25.7`
- n8n MCP `2.57.3`
- Project-scoped MCP configuration
- n8n URL: `http://127.0.0.1:5678`
- `WEBHOOK_SECURITY_MODE=moderate`
- No production workflows
- No secrets may enter project files, workflow exports, reports, logs, or chat

## 2. Existing workflows

### Reply Intake

- Name: `HMZ - Instantly Reply Intake - Validation`
- ID: `cCcpFfi6iovWS94T`
- Inactive
- Phase 3 runtime acceptance: VERIFIED

### Decision Engine

- Name: `HMZ - Reply Decision Engine - Validation`
- ID: `NJcnNQoJ5nSIWYte`
- Inactive
- Phase 3 runtime acceptance: VERIFIED

Verified Phase 3 behaviours include configuration-gate rejection, persistent Data Table idempotency, duplicate termination, real sub-workflow handoff, unsubscribe action-plan fields, positive-interest versus booking classification, malformed-payload handling, no external sends, and restoration to inactive state.

## 3. Instantly verification status

### V1 — VERIFIED

- API V2 access
- Webhook event-types access
- `reply_received` availability
- Account listing
- Email listing
- Dedicated sender connected, setup complete, warm-up active, warm-up score 100, daily limit 40

### V2 — VERIFIED

A genuine `reply_received` webhook proved:

- Webhook `email_id` is the canonical inbound Instantly Email object ID
- That ID is the correct `reply_to_uuid`
- `thread_id` and `message_id` are present
- Inbound and original outbound messages share the same `thread_id`
- `lead_id` may be null on the inbound Email object
- `is_auto_reply=0` for the controlled genuine reply

### V3 — VERIFIED

`POST /api/v2/emails/reply` with:

- `eaccount`
- `reply_to_uuid`
- `subject`
- `body.text` and/or `body.html`

proved:

- HTTP 200
- Exactly one sent Email object
- Correct sender
- Correct recipient
- Same Instantly thread
- Same Gmail conversation
- No unexpected CC/BCC
- No duplicate
- `body.text` may be empty on the retrieved successful sent object

### V4 — VERIFIED

- Ordinary reply selectively prevents future follow-ups in the source campaign
- `POST /api/v2/leads/update-interest-status` returns 202 and the changed state must be retrieved
- `POST /api/v2/leads/subsequence/remove` clears the subsequence after retrieval verification
- Exact email-level block-list insertion prevents sending workspace-wide and can be retrieved/deleted
- Genuine unsubscribe sets source-campaign lead status `-2` and stops source-campaign follow-up
- Genuine unsubscribe does **not** automatically create an exact workspace block-list entry
- V4E4 proved ordinary unsubscribe is campaign-local under the tested workspace configuration: the previously unsubscribed controlled address and a matched control each received exactly one email in a fresh campaign
- Therefore workspace-wide unsubscribe protection requires a separate exact email-level block-list action

### V5 Layer 1 — VERIFIED

The deterministic local policy harness passed all 18 required scenarios:

- Permanent 400: no retry
- 401/402/403: stop and alert
- 404 invalid reply target: stop and investigate
- 429 with and without `Retry-After`: bounded retry
- 500/502/503/504: bounded retry
- Proven pre-submission failures: bounded retry allowed
- Connection reset where submission cannot be ruled out: `SEND_UNCERTAIN`
- Timeout after submission: `SEND_UNCERTAIN`
- Malformed 2xx: `SEND_UNCERTAIN`
- Maximum three attempts for retryable outcomes
- No `SEND_UNCERTAIN` scenario issued a second POST
- No duplicate-risking retry occurred

### V5 Layer 2 — VERIFIED

One controlled live test proved:

- Local proxy forwarded exactly one reply POST
- Instantly returned upstream HTTP 200
- Proxy deliberately dropped the response
- Sender recorded the uncertain outcome
- No second reply POST was attempted
- Read-only reconciliation found exactly one matching sent Email object on two checks
- Final state: `SENT_RECONCILED`
- Exactly one email arrived from the dedicated sender in the original thread
- No duplicate arrived

## 4. Required Phase 4 workflows

Build exactly:

1. `HMZ - Instantly Reply Sender - Validation`
2. `HMZ - Reply Error Handler - Validation`
3. `HMZ - Reply SLA Watchdog - Validation`
4. `HMZ - Reply Full Test Harness - Validation`

Keep all workflows inactive after every test.

## 5. Sender requirements

The Sender must:

- Accept only the structured Decision Engine output
- Re-validate every send and suppression gate
- Use a stable send key independent of random markers
- Acquire a durable atomic send lock before any external POST
- Block concurrent and later reruns for the same send key
- Persist forward-only send state
- Keep `DRY_RUN=true` and `LIVE_CAMPAIGNS=[]`
- Make no live Instantly call during Phase 4 testing
- Use a mock transport for synthetic tests
- Contain the verified live adapter contract, but keep it unreachable until later explicit approval and credential configuration
- Reply only using canonical inbound Email ID as `reply_to_uuid`
- Derive `eaccount` from the inbound Email object and cross-check it
- Preserve the thread and subject
- Never send unresolved variables, placeholders, test content, invented claims, or unapproved pricing
- Classify 400, 401/402/403, 404, 429, 5xx, pre-submission network failures, and uncertain outcomes according to V5
- Honour valid `Retry-After`
- Use bounded exponential backoff with jitter
- Never blindly retry `SEND_UNCERTAIN`
- Reconcile using thread, sender, recipient, exact subject, narrow timestamp, and stable unique marker/fingerprint
- Require exactly one matching sent Email object on repeated checks before `SENT_RECONCILED`
- Route zero or multiple matches to human review without a second POST

## 6. Suppression requirements

For unsubscribe and durable do-not-contact handling:

- Source-campaign stop/unsubscribe is not sufficient for workspace protection
- Perform or record the source-campaign action
- Create an exact email-level workspace block-list entry
- Verify the block-list result
- Treat the two actions as independently idempotent
- Do not send an unsubscribe confirmation until required suppression actions are verified
- Any partial or uncertain suppression result must escalate

Use the verified interest-status and subsequence-removal contracts only where the approved action plan requires them.

## 7. Error Handler requirements

- Begin with an n8n Error Trigger
- Capture workflow, execution, failed node, intake ID, send key, state, HTTP status, error class, attempt, retryability, and operator action
- Persist a sanitised error record
- Route to one configurable placeholder notification surface
- Never silently swallow serious errors
- Never convert an uncertain send into an automatic retry

## 8. SLA Watchdog requirements

- Detect unfinished cases and sends
- Warning threshold: 180 seconds
- Breach threshold: 300 seconds
- Distinguish AI wait, API retry, human review, send failure, uncertain send, suppression failure, and unknown state
- Measure processing SLO separately from transmission SLO
- A draft, notification, queue item, or approval request is not a transmission
- Support synthetic execution without sending

## 9. Full Test Harness requirements

Use mocks only. Never send a real email.

Cover at minimum:

- Positive interest
- Information request
- Booking request
- Timing objection
- Referral
- Not interested
- Unsubscribe
- Out of office
- Bounce
- Wrong person
- Pricing
- Legal/privacy/complaint
- Hostile/reputational
- Attachment-dependent
- Ambiguous
- Other
- Duplicate webhook
- Repeated sender execution
- Self-sent event
- Unsupported event
- Empty reply
- Malformed payload
- Campaign/cell mismatch
- API 400
- API 401/402/403
- API 404
- API 429 with/without `Retry-After`
- API 500/502/503/504
- Pre-submission network failure
- Timeout after submission
- Malformed 2xx
- Zero-match reconciliation
- Multiple-match reconciliation
- Atomic concurrent lock
- Durable sequential-rerun lock
- SLA warning
- SLA breach
- Error-handler routing
- `DRY_RUN` send prevention
- Unsubscribe source action plus exact workspace block-list action
- Partial suppression failure

## 10. Phase 4 deliverables

- Four inactive n8n workflows
- Versioned JSON exports under `workflows/`
- Phase 4 fixtures under `fixtures/phase_4/`
- `docs/TEST_PLAN.md`
- `reports/PHASE_4_VALIDATION.md`
- Minimal technical-status corrections to:
  - `docs/ARCHITECTURE.md` technical verification status only
- `docs/STATE_AND_IDEMPOTENCY.md` §4 reconciliation/retry behaviour only
- `docs/REPLY_POLICY.md` technical mechanism status only
- `docs/HMZ_APPROVED_REPLY_RULES.md` technical mechanism status labels only; approved policy semantics and templates remain authoritative
- `docs/CURRENT_BUILD_STATE.md`
  - `docs/ASSUMPTIONS_AND_UNKNOWNS.md`
  - `docs/INSTANTLY_FIELD_MAP.md`
  - `reports/INSTANTLY_VERIFICATION_EVIDENCE.md`
  - `reports/UNRESOLVED_ITEMS.md`

Do not rewrite unrelated documentation.

## 11. Hard safety boundaries

- No secrets in files, workflow exports, logs, reports, or chat
- No credential creation or binding during Phase 4
- No live Instantly call during Phase 4
- No production actions
- No activation left on after testing
- No deletion of existing workflows or data
- No speculative refactoring of Phase 3 workflows
- No new business claims
- No client-facing or reusable-product expansion
- No Skill creation
