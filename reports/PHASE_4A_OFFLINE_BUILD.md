# Phase 4A Offline Build Report

Scope: offline-only file generation and local deterministic testing for two
new n8n workflows - `HMZ - Instantly Reply Sender - Validation` and
`HMZ - Reply Error Handler - Validation` - plus the `hmz-send-state`
internal sidecar. No n8n connection, no MCP, no Instantly access, and no API
key were used or requested.

## Files created / modified

Infrastructure (sidecar):
- `infrastructure/send-state/state-store.mjs` (new) - atomic file-lock +
  durable-state logic adapted from `verification/v5/layer2/state-store.mjs`,
  extended with the Phase 4A forward-only send-state machine, `sanitize()`,
  and sanitised error-record storage.
- `infrastructure/send-state/server.mjs` (new) - minimal HTTP JSON server
  exposing `/health`, `/v1/send/acquire`, `/v1/send/transition`,
  `/v1/send/:sendKey`, `/v1/error`, `/v1/error/:errorId`. Node built-ins
  only.
- `infrastructure/send-state/Dockerfile` (new) - `node:24-alpine`, copies the
  two `.mjs` files, `EXPOSE 5681`.
- `infrastructure/send-state/README.md` (new) - architecture, network
  isolation, storage rules, state machine, endpoint contracts.
- `infrastructure/local-n8n/docker-compose.yml` (modified) - added the
  `hmz-send-state` service (built from `../send-state`, no `ports:` entry,
  named volume `hmz_send_state_data`) and `n8n: depends_on: hmz-send-state`.

Workflow generation (verification):
- `verification/phase4a/sender-core.mjs` (new) - pure Sender-workflow logic:
  validation, send/suppression/safety gates, send-key derivation, mock
  suppression adapter, DRY_RUN terminal, and the validation-only live
  adapter contract (classification, bounded retry, reconciliation).
- `verification/phase4a/error-core.mjs` (new) - pure Error-Handler logic:
  normalisation, classification, redaction, placeholder notification.
- `verification/phase4a/build-workflows.mjs` (new) - deterministically
  generates both workflow JSON files from compact node definitions plus
  Code-node source embedded (via `.toString()`/`JSON.stringify`) from the
  two `-core.mjs` modules.
- `verification/phase4a/run-offline-tests.mjs` (new) - offline test suite
  (38 tests).
- `verification/phase4a/offline-test-results.json` (generated) - latest run
  results.
- `verification/phase4a/import-phase4a.ps1` (new) - **not executed**, see
  below.

Generated workflows:
- `workflows/03_reply_sender_validation.json` (new, generated)
- `workflows/04_reply_error_handler_validation.json` (new, generated)

Fixtures:
- `fixtures/phase_4a/decision_engine_output_valid.json`
- `fixtures/phase_4a/decision_engine_output_unsubscribe.json`
- `fixtures/phase_4a/decision_engine_output_invalid.json`
- `fixtures/phase_4a/decision_engine_output_unresolved_template.json`
- `fixtures/phase_4a/decision_engine_output_no_approval.json`

Report:
- `reports/PHASE_4A_OFFLINE_BUILD.md` (this file, new)

## Architecture decision (as fixed by the task)

n8n Data Tables are used only for ordinary validation records. Atomic
send-ownership and forward-only send state are provided by a small internal
Docker sidecar, `hmz-send-state`, reusing the verified V5 Layer 2
file-lock/durable-state pattern (`open(path,'wx')` lock + write-tmp-then-
rename state). It is reachable only as `http://hmz-send-state:5681` on the
Docker Compose internal network - no `ports:` entry publishes it to the
host - and persists to the named volume `hmz_send_state_data`. It stores no
credentials, API keys, `Authorization` headers, full reply bodies, full
webhook payloads, or raw API responses (`sanitize()` redacts
secret-like keys and truncates strings over 500 chars).

## Tests run

`node verification/phase4a/run-offline-tests.mjs` - run twice: once
producing 35/38 passing (3 failures), and once (final) after one repair
pass, producing **38/38 passing**. All tests run entirely offline (no
external hosts contacted); `sidecar-*` tests use a temporary directory under
the OS temp folder, not the named Docker volume.

Coverage includes: workflow JSON validity, required names, `active: false`,
no `credentials` objects, no secret-like literal values, no `httpRequest`
node reaching a live Instantly endpoint (only `http://hmz-send-state:5681`),
the documented-but-unreachable V3 reply contract string, no external
notification services in the Error Handler, hardcoded
`OPERATING_MODE=VALIDATION`/`DRY_RUN=true`/`LIVE_CAMPAIGNS=[]`/
`LIVE_CREDENTIAL_READY=false`, stable send-key derivation ignoring the random
body marker, concurrent-acquisition locking, sequential-rerun blocking,
forward-only state-machine rules (no `SEND_UNCERTAIN -> SUBMITTING`), all
send/approval/campaign/template-variable/DRY_RUN gates, suppression
verification (success and partial-failure escalation), HTTP
400/401-403/404/429/5xx classification, Retry-After honouring and capping,
malformed-2xx/timeout -> `SEND_UNCERTAIN`, no further POST after
`SEND_UNCERTAIN`, reconciliation (zero/multiple/repeated-single-match),
error-record normalisation/redaction/sanitisation, `SEND_UNCERTAIN` never
retried, placeholder-only notification, error-record persistence round-trip,
and Compose host-port/volume checks.

## One repair pass (proven defect)

`error-core.mjs`'s `classifyErrorClass()` checked `http_status` before
`send_state === 'SEND_UNCERTAIN'`, so a `SEND_UNCERTAIN` record with, e.g.,
`http_status: 503` was classified `RETRYABLE` with `operator_action:
MONITOR_RETRY` - while `retryable` was still correctly forced to `false`.
This was an internal inconsistency that could mislead an operator into
expecting an automatic retry for a record marked non-retryable. Fixed by
checking `send_state === 'SEND_UNCERTAIN'` first, so `error_class`,
`retryable`, and `operator_action` are consistently `SEND_UNCERTAIN` /
`false` / `MANUAL_RECONCILIATION_REQUIRED`. Workflows were regenerated and
the full 38-test suite was re-run (final run: 38/38 passed). The other two
initial failures were test-script false positives (a sticky note containing
the word "Slack" in a "never calls Slack" note, and a raw-text search not
accounting for JSON string-escaping) and were fixed in the test script only.

## Sidecar safety result

PASS. `hmz-send-state`:
- Binds `0.0.0.0:5681` inside the container; `docker-compose.yml` has no
  `ports:` entry for this service (verified by `compose-no-host-port-for-
  sidecar` and by `docker compose config`, below).
- State persists in the named volume `hmz_send_state_data`.
- Concurrent second `acquireSend()` for the same identity ->
  `acquired:false, reason:LOCK_ALREADY_HELD`.
- After a terminal transition (e.g. `DRY_RUN_OK`), a later `acquireSend()`
  -> `acquired:false, reason:DURABLE_STATE_EXISTS, priorState:DRY_RUN_OK`.
- `SEND_UNCERTAIN -> SUBMITTING` is rejected by `canTransition()`.
- `sanitize()`/`redactValue()` strip secret-like keys and truncate long
  strings before every write.

## Workflow static safety result

PASS. Both `workflows/03_reply_sender_validation.json` and
`workflows/04_reply_error_handler_validation.json`:
- Parse as valid JSON, `active: false`, no node has a `credentials` object.
- No secret-like literal values.
- The only `httpRequest` nodes target `http://hmz-send-state:5681/...`; the
  one reference to `api.instantly.ai` is a documentation-only string literal
  inside the validation-only live-adapter-contract Code node, on a branch
  that is never reached because `DRY_RUN` is hardcoded `true`.
- `HMZ - Reply Error Handler - Validation` contains no Slack/email/Sheets/
  SMTP/Mailgun references in any executable node.
- `OPERATING_MODE=VALIDATION`, `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`,
  `LIVE_CREDENTIAL_READY=false` are hardcoded constants in the Sender
  workflow's Code nodes, not read from input.

## Known limitations

- The generated workflows have not been imported into or executed inside
  n8n; correctness is verified only against the embedded pure-function logic
  and static JSON structure (per scope, n8n/MCP/Instantly access was out of
  bounds for this task).
- The n8n-side informational `deriveSendKey()` (djb2, in `sender-core.mjs`)
  uses a different hash algorithm than the sidecar's authoritative
  `deriveSendKey()` (sha256, in `state-store.mjs`); both independently derive
  a stable key from the same identity tuple (excluding the random marker),
  so this does not affect correctness, but the two keys are not numerically
  equal.
- `hmz-send-state` has not been built or started as a Docker container in
  this session; only `docker compose config` (syntax/structure) was run.
- The live-adapter-contract branch (`N`) is unreachable by construction
  (DRY_RUN hardcoded true) and therefore has no live integration test -
  by design for Phase 4A.

## Exact import command (NOT run in this session)

```powershell
# In a PowerShell 7 session, after the local n8n + hmz-send-state stack is
# running (docker compose -f infrastructure/local-n8n/docker-compose.yml up -d)
# and HMZ_N8N_API_KEY is set for that shell only:
pwsh -File verification/phase4a/import-phase4a.ps1
```

## Verdict

**PHASE_4A_OFFLINE_READY**
