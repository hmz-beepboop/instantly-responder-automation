# Phase 5 Verified Input

**Date:** 2026-06-14  
**Purpose:** Compact source of truth for the final independent audit.

This file supersedes older technical status statements that conflict with the evidence below. It does not supersede approved business policy or knowledge-base content.

## System objective

Safely process HMZ-owned Instantly prospect replies in validation mode, normally within two minutes and within a five-minute Processing SLO, while preserving threads, preventing duplicate sends, applying verified suppression, escalating risk and never blindly retrying uncertain sends.

## Fixed safety mode

- `OPERATING_MODE=VALIDATION`
- `DRY_RUN=true`
- `LIVE_CAMPAIGNS=[]`
- No live credential is bound
- All six workflows must remain inactive during Phase 5
- No live Instantly call is permitted
- No production action is permitted

## Workflow inventory

1. Reply Intake
   - ID: `cCcpFfi6iovWS94T`
2. Decision Engine
   - ID: `NJcnNQoJ5nSIWYte`
3. Reply Sender
   - ID: `OzYLWuCF6DoU7Iw9`
4. Error Handler
   - ID: `koyKIaY2ExF3yhx7`
5. SLA Watchdog
   - ID: `37p0OPzfDxlPvYQo`
6. Full Test Harness
   - ID: `gu9Ede8IM5cHGtKK`

## Evidence already verified

### Phase 3

- Intake and Decision Engine runtime acceptance passed
- Real webhook path tested
- Persistent Data Table idempotency tested
- Duplicate termination tested
- Real sub-workflow handoff tested
- Malformed payload handling tested
- Both workflows restored inactive

### Instantly V1-V5

- API access and dedicated sender verified
- Genuine reply webhook and canonical inbound Email ID verified
- Correct sender and thread-preserving API reply verified
- Ordinary reply stops the source campaign sequence
- Interest-status update verified after retrieval
- Subsequence removal verified
- Exact email block-list enforcement verified workspace-wide
- Genuine unsubscribe verified source-campaign-local under tested conditions
- V5 Layer 1 retry/error policy verified
- V5 Layer 2 lost-response reconciliation verified
- One upstream POST, dropped response, `SEND_UNCERTAIN`, one reconciled Email object, no second POST, no duplicate

### Phase 4A

- 42/42 tests passed
- Sender and Error Handler are inactive and n8n-valid
- Concurrent and sequential duplicate protection passed
- No live call or credential

### Phase 4B

- 31/31 tests passed
- 60-fixture matrix passed
- Embedded Code-node compile/runtime tests passed
- Watchdog and Test Harness runtime-smoke tests passed
- Alert dedupe and sidecar regression passed
- Remote and local Code-node sources match
- Known n8n-MCP static-validator false positives remain documented

## Known documentation defects to correct in Phase 5

The following files contain stale technical status and must be minimally corrected:

- `docs/CURRENT_BUILD_STATE.md`
- `docs/ASSUMPTIONS_AND_UNKNOWNS.md`
- `docs/INSTANTLY_FIELD_MAP.md`
- `docs/STATE_AND_IDEMPOTENCY.md`
- `docs/REPLY_POLICY.md`
- `reports/INSTANTLY_VERIFICATION_EVIDENCE.md`
- `reports/UNRESOLVED_ITEMS.md`

Required corrections:

- Phase 4 is built
- V1-V5 are verified
- Ordinary unsubscribe is campaign-local under tested conditions
- Exact email-level block-list action is required for workspace-wide suppression
- Zero or multiple reconciliation matches require human review and no second POST
- Phase 4B has a documented MCP validator exception, not a resolved valid=true result
- Phase 5 runtime audit status and final readiness verdict

## Known privacy cleanup

A historical environment-audit report contains one real local n8n owner email address in project metadata. Replace it with `<LOCAL_N8N_OWNER_EMAIL>`. Do not preserve or repeat the address.

## Phase 5 mechanical entry gate

The deterministic mechanical audit must prove:

- Phase 4A suite passes
- Phase 4B suite passes
- Sidecar health passes
- All six remote workflows exist and are inactive
- Remote workflow Code-node sources match local exports
- No bound credentials
- No reachable non-local HTTP Request target
- Actual n8n execution of the Full Test Harness succeeds
- Actual n8n execution of the SLA Watchdog succeeds or produces a precisely documented trigger limitation
- n8n security audit runs
- Project secret/PII scan is recorded
- No live Instantly call occurs

## Readiness verdicts

Use only:

- `NOT_READY`
- `READY_FOR_DRY_RUN`
- `READY_FOR_CONTROLLED_LIVE_TEST`

Do not claim production readiness.

`READY_FOR_CONTROLLED_LIVE_TEST` requires actual n8n runtime evidence for every critical integration path. Otherwise, use `READY_FOR_DRY_RUN` even when all deterministic contracts pass.
