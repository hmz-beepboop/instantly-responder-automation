# Phase 4 Validation

**Date:** 2026-06-14

## Scope

Phase 4 implemented and tested:

1. `HMZ - Instantly Reply Sender - Validation`
   - ID: `OzYLWuCF6DoU7Iw9`
2. `HMZ - Reply Error Handler - Validation`
   - ID: `koyKIaY2ExF3yhx7`
3. `HMZ - Reply SLA Watchdog - Validation`
   - ID: `37p0OPzfDxlPvYQo`
4. `HMZ - Reply Full Test Harness - Validation`
   - ID: `gu9Ede8IM5cHGtKK`

All four workflows are inactive.

## Phase 4A evidence

- Offline and package-audited suite: `42/42 passed`
- Sender and Error Handler imported successfully
- n8n validator:
  - Sender: `valid=true`, 0 errors, 19 warnings
  - Error Handler: `valid=true`, 0 errors, 6 warnings
- No credentials bound
- No reachable Instantly request
- `DRY_RUN=true`
- `LIVE_CAMPAIGNS=[]`
- Atomic concurrent lock verified
- Durable sequential-rerun block verified
- `SEND_UNCERTAIN` never blindly retries
- Unsubscribe requires both source-campaign action and exact workspace email suppression

## Phase 4B evidence

- Phase 4A regression: `42/42 passed`
- Phase 4B audited suite: `31/31 passed`
- Synthetic fixture matrix: 60 fixtures
- All embedded Code-node programs compiled and executed
- Complete Watchdog runtime-smoke path passed
- Complete Test Harness runtime-smoke path passed
- Sidecar regression passed
- Alert deduplication passed
- Durable `createdAt` survives state transitions
- Processing and Transmission SLO timing remain separate
- No credentials bound
- No reachable Instantly request

## n8n-MCP validator exception

The n8n-MCP validator reports five Code-node return-shape errors on the Phase 4B workflows. A read-only comparison proved the patched local exports and remote n8n workflow Code-node sources match exactly. Direct compile and runtime tests pass.

The remaining errors are documented as a known n8n-MCP static-validator limitation. They must not be represented as resolved or as `valid=true`.

## Security boundary

- No live Instantly call occurred during Phase 4
- No workflow was left active
- All HTTP Request nodes in Phase 4 target only `http://hmz-send-state:5681`
- The live Instantly adapter exists only as an unreachable validation contract
- No credentials are embedded in workflow exports
- The sidecar has no published host port

## Known Phase 5 work

Phase 5 must still:

- Execute the Full Test Harness in the actual local n8n runtime
- Execute the SLA Watchdog in the actual local n8n runtime
- Compare remote workflows with local exports
- Audit all six workflow connections, expressions, credentials, URLs and inactive states
- Run a project-level secret and uncontrolled-data scan
- Preserve the Phase 4B validator exception
- Update stale status documents
- Assign a readiness verdict

## Verdict

`PHASE_4_VERIFIED_COMPLETE_WITH_KNOWN_MCP_VALIDATOR_EXCEPTION`

## Phase 5 entry

`PHASE_5_ALLOWED`
