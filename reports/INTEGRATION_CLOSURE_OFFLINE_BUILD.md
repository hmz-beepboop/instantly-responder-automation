# Post-Phase-6 Integration Closure - Offline Build

**Generated:** 2026-06-14

## Safety boundary

- No live Instantly call was made; n8n was not contacted; no MCP, no credentials.
- All six workflows remain `active: false`. No credentials were added.
- All HTTP Request nodes target only `http://hmz-send-state:5681/...`.
- This build was not applied or executed against any n8n instance.

## Files changed / created

- `workflows/01_reply_intake_validation.json` (modified)
- `workflows/02_reply_decision_engine_validation.json` (modified)
- `workflows/03_reply_sender_validation.json` (modified)
- `workflows/04_reply_error_handler_validation.json` (unchanged - included in scope, no edits required)
- `workflows/05_reply_sla_watchdog_validation.json` (modified)
- `workflows/06_reply_full_test_harness_validation.json` (modified)
- `verification/integration-closure/build-integration.mjs` (new)
- `verification/integration-closure/run-offline-tests.mjs` (new)
- `verification/integration-closure/offline-test-results.json` (new, generated)
- `verification/integration-closure/apply-integration-closure.ps1` (new, **not executed**)
- `verification/integration-closure/run-n8n-runtime-tests.ps1` (new, **not executed**)
- `fixtures/integration_closure/` (created, empty - reserved, not currently needed)
- `reports/INTEGRATION_CLOSURE_OFFLINE_BUILD.md` (this report)

`build-integration.mjs` is the single source of truth: it loads each workflow
JSON, applies a fixed, idempotent set of in-memory mutations, and writes the
files back with the original 2-space/LF/trailing-newline formatting. Running
it twice produces no further changes (verified).

## Integration graph (defects closed)

### Defect #1 - Intake -> Sender handoff

`01_reply_intake_validation.json`:

```
... -> F. Deterministic Prefilter
     -> G. Decision Engine Handoff   (Execute Sub-workflow -> Decision Engine)
     -> H. Reply Sender Handoff      (Execute Sub-workflow -> Reply Sender)  [NEW]
```

`H. Reply Sender Handoff` is a new `n8n-nodes-base.executeWorkflow` node
(typeVersion 1.3, `source: database`, `mode: each`,
`workflowInputs: { mappingMode: defineBelow, value: {} }` - passthrough of
the current item, identical pattern to `G`). It is wired only from `G`'s
single output.

`G` is reachable **only** via the accepted, non-duplicate path:
`B1. Configuration Gate Router` (true) -> ... -> `E4. Duplicate Event Router`
(true) -> `F` -> `G` -> `H`. The two terminal branches -
`B2. Configuration Gate Rejection (Terminal)` and
`E5. Duplicate Event Terminal` - have **zero outgoing connections** (verified
by BFS in the offline suite), so config-rejection and duplicate events can
never reach `H`.

Because Intake never sets `approval.approved = true`, the Sender's
`approval_gate_passed` check fails, so the natural outcome of this handoff is
`C2. Gate Rejection Terminal` -> `terminal.result = 'BLOCKED'`,
`terminal.send_state = 'BLOCKED'`, `sent = false` - a safe blocked/review
state, as required. The Sender remains the authoritative pre-send gate; no
gate logic was relaxed.

### Defect #2 - Error Handler assignment

`settings.errorWorkflow` was added (placeholder, see below) to:

- `01_reply_intake_validation.json`
- `02_reply_decision_engine_validation.json`
- `03_reply_sender_validation.json`
- `05_reply_sla_watchdog_validation.json`
- `06_reply_full_test_harness_validation.json`

`04_reply_error_handler_validation.json` was left untouched - it does **not**
set `settings.errorWorkflow` on itself.

### Defect #3 - Full Test Harness real sub-workflow integration

`06_reply_full_test_harness_validation.json` gained a new serial route,
inserted between the existing `A. Run Fixture Matrix` and
`B. Persist Harness Result (hmz-send-state)`:

```
A. Run Fixture Matrix
  -> Z0a. Build Sender Integration Input (Unique Fixture)        [Code]
  -> Z1.  Integration - Real Reply Sender Call (Unique Fixture)  [Execute Sub-workflow -> Reply Sender]
  -> Z0b. Build Sender Integration Input (Stable Rerun Fixture)  [Code]
  -> Z1b. Integration - Real Reply Sender Call (Stable Rerun Fixture) [Execute Sub-workflow -> Reply Sender]
  -> Z0c. Build Error Handler Integration Input (Forced SEND_UNCERTAIN) [Code]
  -> Z3.  Integration - Real Error Handler Call (Forced Error)   [Execute Sub-workflow -> Error Handler]
  -> Z5.  Merge Integration Assertions Into Harness Result       [Code]
  -> B. Persist Harness Result (hmz-send-state)
  -> C. Attach Result ID
```

- `Z0a` builds a valid synthetic Decision Engine output with a per-execution
  unique identity (`$execution.id` + `Date.now()`), `approval.approved =
  true`, no unresolved draft tokens, and `address_suppression_intent: 'NONE'`.
  `Z1` runs the **real** Reply Sender workflow against it. `Z5` asserts
  `terminal.result === 'DRY_RUN_OK'`, `terminal.sent === false`,
  `terminal.transport === 'NONE'` (no Instantly call - DRY_RUN forces the `K`
  branch, which only calls the sidecar).
- `Z0b`/`Z1b` repeat the same call with a **stable**, fixed identity
  (`intake-integration-stable-rerun-fixture`). `Z5` records its
  `acquisition.acquired` outcome; sequential-rerun blocking
  (`acquisition.acquired === false` on a repeat run against the same sidecar
  state) is proven across repeated executions by
  `run-n8n-runtime-tests.ps1`, not within a single offline run.
- `Z0c` builds a forced `send_state: 'SEND_UNCERTAIN'` synthetic error event
  (flat shape matching the Error Handler's `Execute Workflow Trigger
  (Synthetic Test Entry)`). `Z3` runs the **real** Error Handler workflow
  against it. `Z5` asserts `error_record.send_state === 'SEND_UNCERTAIN'`,
  `error_record.error_class === 'SEND_UNCERTAIN'`,
  `error_record.retryable === false`,
  `notification.surface === 'PLACEHOLDER_NOT_CONFIGURED'`,
  `notification.delivered === false`, and that `persisted_error.errorId` was
  returned by the sidecar (a sanitised error record was created).
- `Z5` merges both assertion blocks into `integration_result` and folds it
  into `harness_result` (`{ ...harness_result, integration_result,
  overall_result }`), preserving the existing `harness_result.results` (60
  fixtures) untouched.
- `B`'s `jsonBody = {{ $json.harness_result }}` is unchanged and now persists
  the combined object. `C. Attach Result ID`'s prior-item lookup was
  repointed from `A. Run Fixture Matrix` to `Z5...` (one-line string change)
  so the final harness output also carries `integration_result`.

### Defect #4 - Safe ID remapping for a fresh import

Every Execute Sub-workflow `workflowId.value` and every new
`settings.errorWorkflow` uses one of three placeholder tokens (never a
current-instance ID):

- `__PLACEHOLDER_DECISION_ENGINE_WORKFLOW_ID__` (was the hardcoded
  `NJcnNQoJ5nSIWYte` on `G`'s `workflowId.value`; `cachedResultName` retained)
- `__PLACEHOLDER_REPLY_SENDER_WORKFLOW_ID__` (used by `H`, `Z1`, `Z1b`)
- `__PLACEHOLDER_ERROR_HANDLER_WORKFLOW_ID__` (used by all five
  `settings.errorWorkflow` and by `Z3`)

`apply-integration-closure.ps1` discovers each of the six workflows by exact
canonical name (`HMZ - <...> - Validation`), refuses to proceed if more than
one workflow shares a canonical name, creates any missing workflows in the
dependency order `Decision Engine -> Error Handler -> Reply Sender -> SLA
Watchdog -> Full Test Harness -> Reply Intake` (matches
`build-integration.mjs`'s exported `DEPENDENCY_ORDER`), updates existing
workflows in place, then performs **one global string-substitution pass**
replacing the three placeholder tokens with the real IDs captured during
create/discovery, and PUTs the patched bodies back. All workflows stay
`active: false`; no credentials are added; any non-sidecar `httpRequest`
target aborts the run before any write; nothing is ever deleted; partial
state is reported on error; `HMZ_N8N_API_KEY` is cleared in `finally`.

## Offline tests (16/16 PASS)

Run via `node verification/integration-closure/run-offline-tests.mjs`
(spawns the existing Phase 4A / 4B suites as subprocesses; no network, no
n8n):

1. `workflows_parse` - all six JSON files parse
2. `workflows_inactive` - all six `active: false`
3. `no_credentials` - no `credentials` field anywhere
4. `no_external_http_targets` - every `httpRequest` URL is `hmz-send-state`
5. `intake_single_decision_and_sender_calls` - exactly one Decision Engine
   call and one Sender call in Intake
6. `sender_follows_decision_engine` - `G -> H` edge present
7. `reject_duplicate_cannot_reach_sender` - BFS proves `B2`/`E5` are
   dead-end leaves
8. `five_workflows_identify_error_handler` - 01/02/03/05/06 set
   `settings.errorWorkflow`
9. `error_handler_not_self_referencing` - 04 sets no `errorWorkflow`
10. `full_harness_calls_sender_and_error_handler` - real `Execute Workflow`
    calls into 03 and 04 exist in 06
11. `workflow_id_references_patchable` - every Execute Sub-workflow
    target / `errorWorkflow` is one of the three placeholders
12. `fresh_install_dependency_order` - `DEPENDENCY_ORDER` matches the
    required order and is mirrored in the apply script
13. `apply_script_idempotent_by_name` - apply script exists, discovers by
    exact name, refuses duplicates, gates on offline pass, patches all
    placeholders
14. `embedded_code_nodes_compile` - every Code node `jsCode` parses
    (`vm.Script`)
15. `phase4a_regression` - 42/42
16. `phase4b_regression` - 31/31

Result: `16/16 passed, 0 failed`, `overall_result: PASS`
(`verification/integration-closure/offline-test-results.json`).

## Limitations

- No actual n8n execution occurred this session; the integration route in
  workflow 06 and the `H` handoff in workflow 01 are structurally verified
  (parse, connections, placeholders, Code-node compilation) but not
  runtime-proven.
- Sequential-rerun blocking for the stable Sender fixture (`Z1b`) can only be
  observed across **repeated** runs against a persistent sidecar; this is a
  `run-n8n-runtime-tests.ps1` responsibility, not the offline suite's.
- `run-n8n-runtime-tests.ps1` and `apply-integration-closure.ps1` were
  authored but **not executed** (per instructions: stop after the offline
  build).
- `fixtures/integration_closure/` was created but is currently empty; no
  offline test required a fixture file outside the workflow JSON itself.

## Verdict

**INTEGRATION_CLOSURE_OFFLINE_READY**
