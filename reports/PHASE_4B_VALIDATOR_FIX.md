# Phase 4B Validator Compatibility Fix

**Date:** 2026-06-14

## Cause

n8n's static Code-node validator interpreted helper-function statements of the form `return { ... }` as if they were the Code node's top-level output. This produced the error `Array items must be objects with json property` even though the generated runtime smoke tests completed successfully and each Code node's actual top-level return used n8n item objects.

## Fix

The deterministic workflow generator now rewrites helper object returns from:

```js
return { ... };
```

into the runtime-equivalent form:

```js
return Object.assign({}, { ... });
```

The top-level n8n output remains unchanged.

## Verification

- Phase 4A regression: `42/42 passed`
- Phase 4B audited suite: `31/31 passed`
- Every generated Code node compiles
- Complete Watchdog synthetic path passes
- Complete 60-fixture Harness path passes
- No generated Code node contains `return {` or `return
{`
- Both workflow exports remain inactive
- No credentials are present
- No reachable Instantly request exists
- HTTP Request nodes target only `http://hmz-send-state:5681`

## Update target

- SLA Watchdog: `37p0OPzfDxlPvYQo`
- Full Test Harness: `gu9Ede8IM5cHGtKK`

The update script refuses to modify either workflow if it is active, has the wrong name, contains credentials, contains a non-sidecar HTTP request, or still contains a validator-ambiguous return pattern.

## Status

`PHASE_4B_VALIDATOR_FIX_READY`
