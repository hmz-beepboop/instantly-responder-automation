# Integration Closure Runtime Audit

**Generated:** 2026-06-14T23:14:00.1813460+00:00

## Verdict

INTEGRATION_CLOSURE_RUNTIME_PASSED

## Safety boundary

- All six workflows were inactive before testing.
- Only Reply Sender and Error Handler were temporarily activated because n8n 2.x requires active database-backed sub-workflows.
- Both temporary activations were reversed and all six workflows were confirmed inactive after testing.
- No credential was added or read by a workflow.
- No Instantly endpoint was reachable.
- Only the internal hmz-send-state sidecar was called.
- The main n8n service was restarted after the one-off execution.

## Verified

- Remote Intake maps to the actual Decision Engine and Reply Sender IDs.
- Five workflows map to the actual Error Handler ID.
- The Full Test Harness maps to the actual Reply Sender and Error Handler IDs.
- An approved synthetic Sender item executed inside n8n and reached DRY_RUN_OK.
- Sender returned sent=false and transport=NONE.
- The Error Handler executed inside n8n for a forced sanitised SEND_UNCERTAIN item.
- The Error Handler marked the item non-retryable and persisted a sanitised error record.
- The combined Full Test Harness result remained PASS.

## Important limitation

The normal Intake to Decision Engine to Sender path is expected to terminate at
the Sender's approval gate because VALIDATION mode requires a durable human
approval record before transmission. This runtime test proves the real Sender
sub-workflow with an explicitly approved synthetic item; it does not implement
or prove a durable approval user interface.

The settings.errorWorkflow mappings are verified, but this run invokes the
Error Handler through its synthetic Execute Workflow Trigger. Automatic
Error Trigger routing from a genuinely failed parent execution remains
unexercised.

## Files

- Detailed JSON: verification/integration-closure/runtime-results.json
