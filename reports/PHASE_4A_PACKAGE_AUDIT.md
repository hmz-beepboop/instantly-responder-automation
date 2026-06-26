# Phase 4A Package Audit

**Audit date:** 2026-06-14  
**Input:** `Instantly_Responder_Automation_2.3.zip`  
**Audited scope:** Phase 4A offline package only

## Original package verdict

`PHASE_4A_OFFLINE_FAILED_RUNTIME_AUDIT`

The original 38/38 result was not sufficient because the tests exercised the source modules directly but did not execute the JavaScript embedded in the generated n8n Code nodes.

## Defects found

### 1. Generated Error Handler Code nodes would fail at runtime

The generated Error Handler embedded helper functions but omitted module-level constants used by those functions:

- `REDACT_KEY_PATTERN`
- `MAX_STRING_LENGTH`
- `RETRYABLE_HTTP_STATUSES`
- `OPERATOR_ACTION_BY_CLASS`

The first generated Error Handler Code node failed with:

`ReferenceError: OPERATOR_ACTION_BY_CLASS is not defined`

After initially embedding the constants, the regular expression was serialised as `{}` by `JSON.stringify`, causing:

`TypeError: REDACT_KEY_PATTERN.test is not a function`

### 2. Sidecar state stored raw identity values

The original sidecar persisted the raw inbound Email ID, sender email, recipient email and policy/template ID inside the durable state record. This conflicted with the intended minimal/sanitised state design.

### 3. Import script was not rerun-safe

The original import script did not check for existing exact-name workflows before creating new ones. A rerun or partial-recovery attempt could therefore create duplicate Sender or Error Handler workflows.

It also did not clearly surface partial import state or clear in-process key-bearing variables.

## Repairs applied

- Exported the Error Handler constants required by generated Code nodes.
- Added those constants to the generated Error Handler preamble.
- Added RegExp-aware constant serialisation.
- Added generated-workflow Code-node compilation tests.
- Added a generated Error Handler runtime smoke test.
- Added a generated Sender DRY_RUN runtime smoke test.
- Replaced raw sidecar identity values with SHA-256 hashes in durable-state details.
- Added a test proving raw sender/recipient/inbound/template values are absent from stored state.
- Replaced the import script with an exact-name duplicate preflight, pagination support, partial-import warning, stricter offline-evidence gate and in-process key cleanup.

## Final offline test result

- Total: 42
- Passed: 42
- Failed: 0

New critical coverage includes:

- Every generated Code node compiles.
- The generated Error Handler completes a synthetic `SEND_UNCERTAIN` pipeline.
- The generated Sender completes the validation `DRY_RUN` path.
- Durable state stores hashes rather than raw email identifiers.

## Remaining limitations

- The corrected PowerShell import script must still be syntax-checked by PowerShell 7 on Windows.
- The workflows have not yet been imported into n8n.
- The sidecar container has not yet been built and health-checked in the user's Docker environment.
- n8n-native workflow validation has not yet been run.
- No Phase 4A workflow has been activated or used to contact Instantly.

## Corrected package verdict

`PHASE_4A_OFFLINE_READY_FOR_LOCAL_IMPORT`
