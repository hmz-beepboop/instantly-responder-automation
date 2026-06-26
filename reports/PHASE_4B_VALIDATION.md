# Phase 4B Validation

**Date:** 2026-06-14

## Workflows

1. `HMZ - Reply SLA Watchdog - Validation`
   - ID: `37p0OPzfDxlPvYQo`
   - Active: `false`

2. `HMZ - Reply Full Test Harness - Validation`
   - ID: `gu9Ede8IM5cHGtKK`
   - Active: `false`

## Runtime and package evidence

- Phase 4A regression suite: `42/42 passed`
- Phase 4B audited suite: `31/31 passed`
- Synthetic fixture matrix: 60 fixtures
- Every embedded Code-node program compiled
- Complete synthetic Watchdog path executed successfully
- Complete synthetic Test Harness path executed successfully
- Alert deduplication passed
- Sidecar regression passed
- No credentials are bound
- No reachable Instantly request exists
- All HTTP Request nodes target only `http://hmz-send-state:5681`
- Both workflows remain inactive

## Remote deployment check

A read-only comparison of local exports and the workflows stored in n8n confirmed:

- Identical Code-node counts
- Identical Code-node source hashes
- No bare `return { ... }` helper patterns remained
- Patched local exports and remote n8n workflows matched exactly
- Both remote workflows remained inactive

## n8n-MCP validator result

The n8n-MCP validator continued to report:

### SLA Watchdog

- `valid: false`
- 4 errors
- 20 warnings

### Full Test Harness

- `valid: false`
- 1 error
- 8 warnings

All five errors were:

`Array items must be objects with json property`

These errors persisted after the remote workflows were proven identical to the patched local exports and after all embedded Code-node programs passed direct compile and runtime tests.

## Validator exception

The n8n-MCP Code-node validator is known to use scope-unaware regular-expression checks that can misclassify valid helper-function returns as the Code node's top-level output. This is a known open validator defect.

The remaining errors are therefore recorded as a tool limitation rather than evidence of a demonstrated workflow runtime defect.

No further code changes will be made solely to satisfy this validator because doing so would introduce unnecessary implementation risk after successful runtime testing.

## Safety boundary

This exception does not grant production readiness.

Phase 5 must still:

- Execute the synthetic workflows in the actual local n8n runtime
- Audit all six workflow connections and expressions
- Verify duplicate, suppression, retry, reconciliation, error, and SLA behaviour
- Confirm all workflows remain inactive
- Confirm no credentials, secrets, or uncontrolled real prospect data exist

## Verdict

`PHASE_4B_RUNTIME_VERIFIED_WITH_KNOWN_MCP_VALIDATOR_EXCEPTION`

## Phase 5 entry status

`PHASE_5_ALLOWED`

The n8n-MCP validator errors must remain documented as a known limitation and must not be represented as resolved or as `valid=true`.
