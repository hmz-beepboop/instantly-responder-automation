# Phase 4B Package Audit

**Date:** 2026-06-14

## Verdict before repair

`NO_GO`

The original Phase 4B offline package passed its own 25 tests, but the audit found three safety/correctness defects that were not covered:

1. **Silent workflow failure handling**
   - Generated Code and HTTP Request nodes used `onError: continueRegularOutput`.
   - A sidecar outage or Code-node exception could therefore continue into later nodes and produce a successful-looking empty or partial watchdog/harness result.

2. **SLA age reset on every state transition**
   - Durable send state stored only `updatedAt`.
   - Every transition replaced that timestamp, so an old case could appear new and avoid the 180-second warning or 300-second breach.
   - The watchdog also calculated age only from `updatedAt`.

3. **Incomplete sidecar content sanitisation**
   - Arbitrary transition/error details could still persist raw email-like strings or short message/subject/body fields even though acquisition identifiers were hashed.

## Repairs applied

### Workflow failure safety

- Removed continue-on-error behaviour from all generated Phase 4B Code and HTTP Request nodes.
- Malformed `/v1/unfinished`, `/v1/alert/dedupe`, and `/v1/phase4b/result` responses now throw explicit errors.
- Sidecar failures can no longer be silently converted into successful-looking zero-alert or persisted results.

### Durable SLA timing

- Send records now preserve a stable `createdAt` value across all transitions.
- Existing safe details are merged forward rather than discarded.
- `/v1/unfinished` now returns both `createdAt` and `updatedAt`.
- Processing SLO age uses `createdAt` with backward-compatible fallback to `updatedAt`.
- Transmission timing can use `transmissionStartedAt` or `submissionStartedAt` where supplied.

### Sanitisation

- Raw email-like string values are replaced with hashes.
- Common identity fields are stored only as hashes.
- Body, HTML, payload, raw, reply-text, message, content, and subject fields are replaced with `<REDACTED_CONTENT>`.
- Credential-like fields remain redacted.

## Verification

### Phase 4A regression

- `42/42 passed`
- Atomic send lock and durable rerun protection remain intact.

### Phase 4B audited suite

- `30/30 passed`
- Added tests prove:
  - Code/HTTP nodes do not continue after failure.
  - malformed sidecar responses are rejected.
  - processing SLA age does not reset after a transition.
  - `createdAt` persists and prior safe details merge.
  - raw emails and content fields do not survive sidecar sanitisation.

### Existing safety checks retained

- 60 synthetic fixtures remain present.
- Generated Watchdog and Harness Code nodes compile and run.
- Both workflows remain inactive.
- No credentials are bound.
- No reachable Instantly call exists.
- All HTTP requests target only `http://hmz-send-state:5681`.
- Alert deduplication remains atomic.
- Phase 4A state-machine regression passes.

## Docker note

The uploaded package had already passed `docker compose config` on the user's Windows/Docker environment. Docker was not available in the audit sandbox, so that command was not rerun here. The Compose file itself was not changed by this repair.

## Final verdict

`PHASE_4B_AUDITED_READY_FOR_LOCAL_TEST_AND_IMPORT`
