# Phase 3.1B2 — Idempotency Evidence Alignment

Date: 2026-06-12. Scope: align node E3's evidence-status label with the
Phase 3.1B1 Data Table experiment findings
(`reports/PHASE_3_DATATABLE_BEHAVIOUR_EXPERIMENT.md`). No external services
called, no execution run, no fixtures run.

## Change made

- **Workflow:** `HMZ - Instantly Reply Intake - Validation` (`cCcpFfi6iovWS94T`)
- **Node:** `E3. Recombine Idempotency Result` (`parameters.jsCode`)
- **Property changed:** `idempotency.duplicate_detection_status`
- **Previous value:** `'PROVISIONAL'`
- **New value:** `'VERIFIED_N8N_2_25_7'`

This was the only occurrence of `'PROVISIONAL'` in E3's code. No other
property, the duplicate Boolean logic, the idempotency key, routing,
connections, or node names were touched. No other node was modified.

## Method

One `n8n_update_partial_workflow` operation: `patchNodeField` on
`E3. Recombine Idempotency Result`, `fieldPath: "parameters.jsCode"`,
find/replace `duplicate_detection_status: 'PROVISIONAL'` ->
`duplicate_detection_status: 'VERIFIED_N8N_2_25_7'`.

## Verification

1. **Workflow validation (full workflow, one call):**
   `valid: true`, `errorCount: 0`, `totalNodes: 14`, `invalidConnections: 0`.
   Warnings present (14) are pre-existing (missing `onError` on Code/IF
   nodes, long linear chain) and unrelated to this change.
2. **Retrieved stored workflow (one call, mode=full):**
   - E3's `jsCode` still computes
     `isDuplicate = !!(createdAt && updatedAt && createdAt !== updatedAt)`
     unchanged.
   - `idempotency.duplicate_detection_status` is now `'VERIFIED_N8N_2_25_7'`.
   - `idempotency.duplicate_detection_method` unchanged
     (`'created_at_vs_updated_at_after_upsert'`).
   - All other E3 output fields (`is_duplicate`, `table_row_id`,
     `created_at`, `updated_at`, plus spread of `original.idempotency`)
     unchanged.
   - **Connections:** identical to the pre-change export (E2 -> E3 -> E4 ->
     {F, E5}, etc.).
   - **Active status:** `active: false` (inactive, unchanged).
   - **No credentials or external-service nodes** introduced; node count
     unchanged (14 functional + sticky notes = 22 total).

## Inactive status

Confirmed `active: false` on the retrieved stored workflow. Unchanged.

## Export alignment

`workflows/01_reply_intake_validation.json` updated: the same single
find/replace (`'PROVISIONAL'` -> `'VERIFIED_N8N_2_25_7'`) applied to E3's
`jsCode` string. E3's `jsCode` in the local export now matches the stored
workflow's E3 `jsCode` byte-for-byte. No other part of the local export was
modified.

## MCP call count

3 calls total (limit 4):
1. `n8n_update_partial_workflow` (patchNodeField on E3)
2. `n8n_validate_workflow` (full workflow)
3. `n8n_get_workflow` (mode=full, retrieve once)

No execution run. No fixtures run. No sticky notes, handoffs, architecture,
policy, or unresolved-items files were modified.

## Final verdict

**PHASE 3.1B2 COMPLETE**
