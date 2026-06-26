# Phase 3.1B1 — Data Table Behaviour Experiment (Idempotency)

Date: 2026-06-12. Scope: evidence-only experiment against the real local n8n Data Table
`hmz_validation_reply_intake_idempotency` (`xUlD0Zhoek6mU5I2`), to resolve
`reports/UNRESOLVED_ITEMS.md` U1's open question about `createdAt`/`updatedAt`
field names and behaviour on repeated `upsert`. **No workflow was read, edited, or
validated.** No external services were called. 5 MCP calls used (limit: 8).

---

## 1. Exact MCP operations used

All via `mcp__n8n-mcp__n8n_manage_datatable`, `tableId: "xUlD0Zhoek6mU5I2"`
(table `hmz_validation_reply_intake_idempotency`), mirroring E2's configured
`resource: "row"`, `operation: "upsert"`, filter on `idempotency_key` (eq).

1. **`upsertRows`** — filter `idempotency_key = "phase3b1-test-key-a"`, `data` = full
   record (`idempotency_key`, `dedupe_key`, `intake_id`, `state`, `event_type`,
   `lead_email`, `campaign_id`), `returnData: true`. (First write for key-a; combines
   experiment steps 1+2.)
2. **`upsertRows`** — same filter (`idempotency_key = "phase3b1-test-key-a"`), `data` =
   `{ idempotency_key: "phase3b1-test-key-a", state: "COMPLETED_NO_SEND" }` only —
   the other 5 non-key columns deliberately omitted, `returnData: true`. (Second write
   for the same key; combines steps 3+4.)
3. **`upsertRows`** — filter `idempotency_key = "phase3b1-test-key-b"`, `data` = full
   record, `returnData: true`. (Distinct key; combines steps 5+6.)
4. **`deleteRows`** — filter `type: "or"`, matching `idempotency_key` in
   `{"phase3b1-test-key-a", "phase3b1-test-key-b"}`, `returnData: true`. (Cleanup.)
5. **`getRows`** — same `or` filter as step 4, no `returnData` needed. (Cleanup proof.)

---

## 2. Observed output shape

`upsertRows` / `deleteRows` (with `returnData: true`) return:

```json
{
  "success": true,
  "data": [ { <all defined columns>, "id": <integer>, "createdAt": "<ISO 8601 UTC>", "updatedAt": "<ISO 8601 UTC>" } ],
  "message": "Row upserted successfully" | "Rows deleted successfully"
}
```

`getRows` returns:

```json
{ "success": true, "data": { "rows": [...], "count": <integer> } }
```

Key observations on field names/casing:

- The row-identity field is **`id`** (camelCase, integer — `1`, `2`), not `row_id` or `_id`.
- The timestamp fields are **`createdAt`** and **`updatedAt`** (camelCase), as ISO 8601
  UTC strings with millisecond precision (e.g. `"2026-06-12T03:31:18.185Z"`). No
  `created_at`/`updated_at` snake_case fields were present anywhere.
- There is **no separate insert/update indicator field** on the row (no `wasInserted`,
  `operation`, `matched`, etc.). The only signal distinguishing insert from update is
  the top-level `message` string (`"Row upserted successfully"` — identical for both
  the first and second write) combined with the `createdAt` vs `updatedAt` values.
- All 7 defined columns (`idempotency_key`, `dedupe_key`, `intake_id`, `state`,
  `event_type`, `lead_email`, `campaign_id`) are returned alongside `id`/`createdAt`/`updatedAt`.

### Raw evidence

**Call 1** (first upsert, key-a, full record):
```json
{
  "idempotency_key": "phase3b1-test-key-a", "dedupe_key": "test-dedupe-a",
  "intake_id": "test-intake-a", "state": "READY_FOR_DECISION",
  "event_type": "reply_received", "lead_email": "test-a@example.com",
  "campaign_id": "test-campaign-a",
  "id": 1,
  "createdAt": "2026-06-12T03:31:18.185Z",
  "updatedAt": "2026-06-12T03:31:18.185Z"
}
```

**Call 2** (second upsert, key-a, only `state` supplied):
```json
{
  "idempotency_key": "phase3b1-test-key-a", "dedupe_key": "test-dedupe-a",
  "intake_id": "test-intake-a", "state": "COMPLETED_NO_SEND",
  "event_type": "reply_received", "lead_email": "test-a@example.com",
  "campaign_id": "test-campaign-a",
  "id": 1,
  "createdAt": "2026-06-12T03:31:18.185Z",
  "updatedAt": "2026-06-12T03:31:26.378Z"
}
```

**Call 3** (first upsert, key-b, full record):
```json
{
  "idempotency_key": "phase3b1-test-key-b", "dedupe_key": "test-dedupe-b",
  "intake_id": "test-intake-b", "state": "READY_FOR_DECISION",
  "event_type": "reply_received", "lead_email": "test-b@example.com",
  "campaign_id": "test-campaign-b",
  "id": 2,
  "createdAt": "2026-06-12T03:31:47.214Z",
  "updatedAt": "2026-06-12T03:31:47.214Z"
}
```

---

## 3. Findings for the seven questions

1. **Does the first write return a row?**
   Yes. Call 1 returned `data: [{...}]` — a single row object including `id`, `createdAt`, `updatedAt`, and all 7 supplied columns. (Confirmed again independently by Call 3 for key-b.)

2. **Does a repeated write preserve the original creation timestamp?**
   Yes. Call 2 (same `idempotency_key`, same `id: 1`) returned `createdAt: "2026-06-12T03:31:18.185Z"` — byte-identical to Call 1's `createdAt`.

3. **Does the repeated write advance the update timestamp?**
   Yes. Call 2 returned `updatedAt: "2026-06-12T03:31:26.378Z"`, later than and different from both Call 1's `updatedAt` and the row's own `createdAt`.

4. **Does the operation explicitly identify insert versus update?**
   No. Both Call 1 (insert case) and Call 2 (update case) returned the identical top-level message `"Row upserted successfully"`, and no row-level field flags which case occurred. The only available signal is the `createdAt`/`updatedAt` comparison itself.

5. **Does upsert overwrite fields that are omitted or only fields supplied?**
   Only the fields supplied are overwritten; omitted fields are preserved unchanged. Call 2 supplied only `idempotency_key` (match key) and `state`. The returned row still carried `dedupe_key="test-dedupe-a"`, `intake_id="test-intake-a"`, `event_type="reply_received"`, `lead_email="test-a@example.com"`, `campaign_id="test-campaign-a"` — all unchanged from Call 1 — while `state` changed from `"READY_FOR_DECISION"` to `"COMPLETED_NO_SEND"`. Omitted columns were **not** nulled or cleared.

6. **Is `createdAt !== updatedAt` a reliable duplicate indicator in this n8n version?**
   Yes, for the case tested. First write: `createdAt === updatedAt` (`is_duplicate` would compute `false`). Second write to the same key: `createdAt !== updatedAt` (`is_duplicate` would compute `true`). Both fields are present, non-null, well-formed ISO strings on every response (insert and update), so E3's guard `!!(createdAt && updatedAt && createdAt !== updatedAt)` evaluates correctly in both cases using `row.createdAt`/`row.updatedAt` directly — the `|| row.created_at` / `|| row.updated_at` snake_case fallbacks in E3 are never reached in this n8n version (camelCase is always present), but are harmless dead branches.

7. **What is the smallest reliable native duplicate-detection pattern for Phase 3.1B2?**
   E3's existing comparison — `is_duplicate = !!(row.createdAt && row.updatedAt && row.createdAt !== row.updatedAt)` read directly from the E2 upsert output — is already the smallest reliable pattern and requires **no code change**. See recommendation below.

---

## 4. Cleanup result

`deleteRows` (Call 4) returned `"message": "Rows deleted successfully"` with `data`
containing both rows (`id: 1` for `phase3b1-test-key-a`, `id: 2` for
`phase3b1-test-key-b`) as the affected/deleted rows.

`getRows` (Call 5) with the same `idempotency_key` filter (`or`, both test keys)
returned `{"rows": [], "count": 0}` — **both temporary rows are confirmed gone**.
The table itself (`hmz_validation_reply_intake_idempotency`, `xUlD0Zhoek6mU5I2`) was
not modified structurally and was not deleted.

---

## 5. Recommended duplicate-detection method

**Keep E3's current method unchanged**: `idempotency.is_duplicate =
!!(row.createdAt && row.updatedAt && row.createdAt !== row.updatedAt)`, evaluated on
the row returned by E2's `upsert`. This experiment confirms, against the live local
Data Table:
- the upserted row is returned with `id`, `createdAt`, `updatedAt` (all camelCase),
- `createdAt` is preserved and `updatedAt` advances on a second upsert to the same
  `idempotency_key`,
- E2's "define all 7 columns every time" mapping mode means every E2 upsert supplies
  the full column set, so the "omitted fields preserved" behaviour observed in Call 2
  (with a deliberately partial `data`) is not even exercised in the real E2 config —
  E2 always rewrites all 7 non-key columns, which is fine since they're recomputed
  from the current item each run anyway.

The only change this evidence supports (out of scope for this experiment, a Phase
3.1B2 item) is updating `idempotency.duplicate_detection_status` from `'PROVISIONAL'`
to `'VERIFIED'` once this evidence is reviewed — no change to the comparison
expression itself, and no new node or pattern is needed.

---

## 6. Uncertainties

- This experiment used `mcp__n8n-mcp__n8n_manage_datatable` (`upsertRows` /
  `deleteRows` / `getRows`) rather than executing the actual
  `n8n-nodes-base.dataTable` node (E2) inside a live workflow run. Both should read
  and write the same underlying Data Table storage/API and the field names observed
  (`id`, `createdAt`, `updatedAt`, camelCase) match exactly what E3 checks first
  (`row.createdAt`, `row.id`), but the precise item-wrapping a real node execution
  hands to a downstream Code node (E3's `item.json`) was not directly observed in
  this experiment.
- Only one repeat-write cycle was tested, ~8 seconds apart on the local instance's
  clock (`2026-06-12T03:31:18.185Z` -> `2026-06-12T03:31:26.378Z`). Behaviour for two
  writes within the same millisecond (where `createdAt === updatedAt` might
  coincidentally hold even on a genuine update) was not tested, but is very unlikely
  given E1 -> E2 always involves multiple sequential node executions.
- The absence of an explicit insert/update indicator (Q4) was checked only at the
  fields surfaced by this MCP tool (`success`, `data[]`, `message`); it is possible —
  though not evidenced — that the raw Data Table API exposes additional metadata not
  passed through by this wrapper.

---

## Final verdict

**DATATABLE BEHAVIOUR VERIFIED**
