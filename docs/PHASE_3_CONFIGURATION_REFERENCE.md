# Phase 3 Configuration Reference

Date: 2026-06-11, updated 2026-06-12 (Phase 3.1A surgical repairs). Purpose: a single place to find the IDs, names, paths, and constants needed to continue working on the two Phase 3 workflows without re-deriving them from the JSON exports. This file is descriptive (records what was built), not a new design document — for schema/policy detail see `docs/NORMALIZED_EVENT_SCHEMA.md`, `docs/STATE_AND_IDEMPOTENCY.md`, `docs/REPLY_POLICY.md`, `docs/HMZ_APPROVED_REPLY_RULES.md`, `docs/VALIDATION_CAMPAIGN_CONFIG.md`. Phase 3.1A added four nodes to Workflow 1 (`B1`, `B2`, `E4`, `E5`) and revised Workflow 1 Section E1 and Workflow 2 Section E — see `docs/PHASE_3_SURGICAL_REPAIR_CHANGELOG.md` for the full repair-by-repair record.

Both workflows are **inactive** (`active: false`, `activeVersionId: null`) and contain **no credentials**. Nothing in this file is a secret.

---

## 1. Local n8n instance

- URL: `http://127.0.0.1:5678` (project-scoped `.mcp.json`, `N8N_API_URL`).
- Container: `hmz-n8n-local-dev`, n8n version `2.25.7` (pinned), bound to `127.0.0.1:5678` only.
- `n8n-mcp` `WEBHOOK_SECURITY_MODE=moderate`.

---

## 2. Workflow 1 — `HMZ - Instantly Reply Intake - Validation`

- **Workflow ID**: `cCcpFfi6iovWS94T`
- **Export**: `workflows/01_reply_intake_validation.json`
- State as of this session: `active: false`, `activeVersionId: null`, `versionCounter: 7`, `versionId: "c885c7c9-11d5-48b2-a5fd-56c353642401"`, `updatedAt: "2026-06-12T02:19:40.611Z"`, `createdAt: "2026-06-11T08:10:46.083Z"`.
- 22 nodes total (14 logical nodes + 8 sticky notes). Chain with two IF-routed branches (Phase 3.1A Repairs 1 and 4 added B1/B2 and E4/E5):

| Step | Node name | Type |
| --- | --- | --- |
| Trigger | `Webhook - Synthetic Reply Intake (DEV ONLY)` | `n8n-nodes-base.webhook` |
| A | `A. Webhook Intake Normalization` | `n8n-nodes-base.code` |
| B | `B. Configuration Gate` | `n8n-nodes-base.code` |
| B1 | `B1. Configuration Gate Router` | `n8n-nodes-base.if` |
| C | `C. Payload Validation` (B1 `true`) | `n8n-nodes-base.code` |
| B2 | `B2. Configuration Gate Rejection (Terminal)` (B1 `false`) | `n8n-nodes-base.code` |
| D | `D. Normalization to NES` | `n8n-nodes-base.code` |
| E1 | `E1. Compute Idempotency Key` | `n8n-nodes-base.code` |
| E2 | `E2. Idempotency Data Table Upsert` | `n8n-nodes-base.dataTable` |
| E3 | `E3. Recombine Idempotency Result` | `n8n-nodes-base.code` |
| E4 | `E4. Duplicate Event Router` | `n8n-nodes-base.if` |
| F | `F. Deterministic Prefilter` (E4 `true`) | `n8n-nodes-base.code` |
| E5 | `E5. Duplicate Event Terminal` (E4 `false`) | `n8n-nodes-base.code` |
| G | `G. Decision Engine Handoff` | `n8n-nodes-base.executeWorkflow` |

Connections: `Webhook -> A -> B -> B1 -> {C (true) / B2 (false)}`; `C -> D -> E1 -> E2 -> E3 -> E4 -> {F (true) / E5 (false)}`; `F -> G`. `B2` and `E5` are terminal Code nodes (no further downstream connections).

### 2.1 Webhook (trigger)

```json
{ "httpMethod": "POST", "path": "hmz-validation-reply-intake-dev", "responseMode": "onReceived", "options": {} }
```
Dev-only path; not exposed publicly (local instance binds to `127.0.0.1:5678` only). Full URL when the instance is running: `http://127.0.0.1:5678/webhook/hmz-validation-reply-intake-dev` (test: `/webhook-test/...`).

### 2.2 Section B — `CONFIG` constant

```js
const CONFIG = {
  operating_mode: 'VALIDATION',
  dry_run: true,
  live_campaigns: [],
  geo_code: 'US_B2B_CORE_12',
  validation_cells: [
    'CELL_1_SAAS_SALES_HIRING',
    'CELL_2_SAAS_EXISTING_OUTBOUND',
    'CELL_3_SPECIALISED_B2B_AGENCY'
  ],
  allowed_country: 'US',
  region_priority: ['EASTERN', 'CENTRAL'],
  transmission_disabled: true,
  external_actions_mocked: true
};
```
Hardcoded for Phase 3 (not environment-variable-backed yet — see `docs/ASSUMPTIONS_AND_UNKNOWNS.md` section D). `config_gate.passed=false` is now routed to a terminal `REJECTED` state by B1/B2 below (Phase 3.1A Repair 1, resolves `reports/UNRESOLVED_ITEMS.md` U2).

### 2.2a Section B1 — `B1. Configuration Gate Router` (IF, Phase 3.1A Repair 1)

`n8n-nodes-base.if` v2.3, id `f2e8963d-8580-4b2d-ad9a-6b6b02645483`, position `[820,-120]`. Single condition: `leftValue: "={{ $json.config_gate.passed }}"`, `operator: {type:"boolean", operation:"true", singleValue:true}`. `true` output (`main[0]`, `config_gate.passed === true`) -> `C. Payload Validation`. `false` output (`main[1]`, `config_gate.passed === false`) -> `B2. Configuration Gate Rejection (Terminal)`. See `reports/UNRESOLVED_ITEMS.md` U6 for the non-blocking "missing onError" validator warning on this node.

### 2.2b Section B2 — `B2. Configuration Gate Rejection (Terminal)` (Code, Phase 3.1A Repair 1)

`n8n-nodes-base.code`, id `c5f65583-97d5-4377-8d21-ace27779d296`, position `[820,160]`, `onError:"continueRegularOutput"`. Terminal node — no downstream connections. Builds `reasonText` from `config_gate.reasons` (joined with `'; '`, prefixed `"Configuration gate failed: "`, or `"Configuration gate failed (no reasons recorded)"` if empty) and returns `{...input, terminal_status:'REJECTED', processing_halted:true, external_action_status:'NOOP', reason: reasonText}`.

### 2.3 Section E2 — Data Table upsert

```json
{
  "resource": "row",
  "operation": "upsert",
  "dataTableId": { "mode": "id", "value": "xUlD0Zhoek6mU5I2" },
  "filters": { "conditions": [
    { "keyName": "idempotency_key", "condition": "eq", "keyValue": "={{ $json.idempotency.idempotency_key }}" }
  ]},
  "columns": { "mappingMode": "defineBelow", "value": {
    "idempotency_key": "={{ $json.idempotency.idempotency_key }}",
    "dedupe_key": "={{ $json.nes.dedupe_key }}",
    "intake_id": "={{ $json.intake_id }}",
    "state": "={{ $json.idempotency.proposed_state }}",
    "event_type": "={{ $json.nes.event_type }}",
    "lead_email": "={{ $json.nes.lead_email }}",
    "campaign_id": "={{ $json.nes.campaign_id }}"
  }}
}
```

Data Table: **`hmz_validation_reply_intake_idempotency`**, ID **`xUlD0Zhoek6mU5I2`**. Columns written: `idempotency_key`, `dedupe_key`, `intake_id`, `state`, `event_type`, `lead_email`, `campaign_id`, plus n8n's own `id`/`createdAt`/`updatedAt`.

### 2.4 Section E1 — idempotency key (Phase 3.1A Repair 2)

E1 computes `key_components = {event_id, email_id, campaign_id, email_account, lead_email}` from `validated.*` (and `nes.lead_email`, treating `null`/`'UNKNOWN'` as absent), then picks one of two `idempotency.key_scheme` values:

- **`full_identity`** — all five components present and valid: `idempotency_key = [event_id, email_id, campaign_id, email_account, lead_email].join(':')` (e.g. `evt-...:email-...:campaign-...:outbound1@...:lead@...`).
- **`identifier_poor_hash`** — one or more components missing/invalid (`isIdentifierPoor=true`, true for every `payload_status=MALFORMED` item since Section C sets all 11 `validated.*` fields to `null`): `idempotency_key = ['identifier_poor', 'instantly', ...presentParts, \`payload_hash=${canonicalPayloadHash(raw_payload)}\`].join(':')`, where `presentParts` is the non-null `key=value` components (often empty for malformed payloads) and `canonicalPayloadHash` is a recursive key-sorted-JSON djb2 hash (8 hex chars) of `raw_payload`. For a fully malformed payload this is `identifier_poor:instantly:payload_hash=<hash>` — a hash of the exact payload, not a fixed placeholder. Resolves `reports/UNRESOLVED_ITEMS.md` U3 (different malformed payloads now get different keys; cross-checked by fixtures 11/13 in `run_synthetic_tests.js`).

`idempotency.state_enum` lists all 9 states from `docs/STATE_AND_IDEMPOTENCY.md`. `idempotency.storage_adapter = 'n8n_data_table'`.

### 2.5 Section E3 — duplicate-detection fields (output)

```
idempotency.is_duplicate                 (boolean)
idempotency.table_row_id                 (Data Table row id, or null)
idempotency.created_at / updated_at      (from the upserted row)
idempotency.duplicate_detection_method   = 'created_at_vs_updated_at_after_upsert'
idempotency.duplicate_detection_status   = 'PROVISIONAL'   <- see UNRESOLVED_ITEMS U1
```

### 2.5a Sections E4/E5 — duplicate-event routing (Phase 3.1A Repair 4)

`E4. Duplicate Event Router` (`n8n-nodes-base.if` v2.3, id `4c6090f6-93a2-4047-a386-4f90c8d66540`, position `[2420,-120]`): single condition `leftValue: "={{ $json.idempotency.is_duplicate }}"`, `operator: {type:"boolean", operation:"false", singleValue:true}`. `true` output (`main[0]`, `idempotency.is_duplicate === false`, i.e. NOT a duplicate) -> `F. Deterministic Prefilter` (continues to Workflow 2 as before). `false` output (`main[1]`, `idempotency.is_duplicate === true`) -> `E5. Duplicate Event Terminal`. See `reports/UNRESOLVED_ITEMS.md` U6 for the non-blocking "missing onError" validator warning on this node.

`E5. Duplicate Event Terminal` (`n8n-nodes-base.code`, id `5a923a2f-368b-4787-9225-102641956ed4`, position `[2420,160]`, `onError:"continueRegularOutput"`). Terminal node — no downstream connections; Workflow 2 (Sections A-E) never runs for a duplicate event. Reads `idempotency.idempotency_key` (default `'UNKNOWN'`) and returns `{...input, terminal_status:'COMPLETED_NO_SEND', processing_halted:true, external_action_status:'NOOP', stop_active_sequence:false, reason: \`Duplicate event detected for idempotency key "${key}" (idempotency.is_duplicate=true); no further processing or send required.\`}`.

### 2.6 Section F — deterministic prefilter flags

`prefilter.is_unsupported_event_type`, `is_empty_reply`, `is_malformed_payload`, `is_duplicate_event` (mirrors `idempotency.is_duplicate`), `is_self_sent`, `is_automated_response`, `is_out_of_office`, `is_bounce_or_delivery_notice`, `is_unsubscribe`, `is_campaign_cell_mismatch`, `has_attachment`. `SUPPORTED_EVENT_TYPES` includes `reply_received` and `auto_reply_received`. `OOO_PATTERN` (fixed this session — see `reports/UNRESOLVED_ITEMS.md` U4): `/\b(out of (the )?office|ooo|on leave|on vacation|away from (the )?office|annual leave)\b/i`.

### 2.7 Section G — decision-engine handoff

```json
{
  "source": "database",
  "workflowId": { "mode": "list", "value": "NJcnNQoJ5nSIWYte", "cachedResultName": "HMZ - Reply Decision Engine - Validation" },
  "workflowInputs": { "mappingMode": "defineBelow", "value": {} },
  "mode": "each",
  "options": {}
}
```
`n8n-nodes-base.executeWorkflow`, `source=database` (by workflow ID), synchronous (`waitForSubWorkflow` default `true`).

---

## 3. Workflow 2 — `HMZ - Reply Decision Engine - Validation`

- **Workflow ID**: `NJcnNQoJ5nSIWYte`
- **Export**: `workflows/02_reply_decision_engine_validation.json`
- State as of this session: `active: false`, `activeVersionId: null`, `versionCounter: 8`, `versionId: "758b9928-2c10-48de-a7e7-2c34a8ef6fc9"`, `updatedAt: "2026-06-12T02:24:05.404Z"`, `createdAt: "2026-06-11T07:12:24.379Z"`. Edited this build for Phase 3.1A Repair 3 (Section B reads the renamed `nes.validation_learning_seed`; Section E now validates and exposes the authoritative `validation_learning`).
- 12 nodes total (5 logical nodes + trigger + 6 sticky notes). Linear chain:

| Step | Node name | Type |
| --- | --- | --- |
| Trigger | `When Called by Reply Intake` | `n8n-nodes-base.executeWorkflowTrigger` (`inputSource: "passthrough"`) |
| A | `A. Deterministic Policy Stage` | `n8n-nodes-base.code` |
| B | `B. Mock Semantic Classifier` | `n8n-nodes-base.code` |
| C | `C. Decision Policy` | `n8n-nodes-base.code` |
| D | `D. Mock Draft Preparation` | `n8n-nodes-base.code` |
| E | `E. Output Validation` | `n8n-nodes-base.code` |

### 3.1 Section A — deterministic rule IDs (checked in order, override the classifier)

`det-unsub-001`, `det-legal-001`, `det-legal-002`, `det-regulator-001`, `det-hostile-001`, `det-hostile-002`, `det-complaint-001`, `det-bounce-001`, `det-bounce-002`, `det-ooo-001`, `det-price-001`, `det-attach-001`, `det-booking-001`, `det-referral-001`, `det-wrong-001`, plus operational/non-classifier rules `op-duplicate`, `op-self-sent`, `op-malformed`, `op-unsupported-event`, `op-empty-reply`.

`det-ooo-001` (priority 13) is checked before `det-referral-001` (priority 16) so an out-of-office reply that also says "contact my colleague" is never misread as a referral (fixture 5).

### 3.2 Section D — `TEMPLATE_REGISTRY` keys

`T1_SCENARIO_A_OPEN_TO_CALL`, `T1_SCENARIO_C_UNCLEAR_INTEREST`, `T4_SCENARIO_B_VAGUE`, `T5_REFERRAL_ACK`, `T6_NOT_INTERESTED_ACK`, `T7_UNSUBSCRIBE_CONFIRMATION`, `T10_WRONG_PERSON_ACK`.

`T2_KB_INFORMATION_REQUEST` (used for `INFORMATION_REQUEST`) and `T3` (booking-request) reply template IDs are referenced in decisions but have **no entry** in `TEMPLATE_REGISTRY` — `draft.draft_text` is `null` with an explanatory note for these (intentional: T2/T3 drafts must be composed from `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` per policy-HMZ-1.2 Section 8, not a fixed template; see fixture 02's notes).

---

## 4. `validation_learning` — three locations, do not confuse them (Phase 3.1A Repair 3)

- **`nes.validation_learning_seed`** (Workflow 1 Section D, via `emptyValidationLearning()`; renamed this build from `nes.validation_learning`): a **static** snapshot of all 11 fields at their defaults (`'unknown'` for the 9 tri-state fields, `null` for `validation_signal_strength` and `voice_of_customer_excerpt`). Never enriched, never read by Workflow 2 Section E. Non-authoritative — present only as the seed that Section B enriches from.
- **`classifier.validation_learning`** (computed by Workflow 2 Section B, via `emptyValidationLearning(nes)` reading the renamed `nes.validation_learning_seed`, plus enrichment): the **per-execution, enriched** object. Enrichment applied:
  - `voice_of_customer_excerpt` — populated from `reply_text` (or `reply_subject` if `reply_text` is empty) when non-empty.
  - `pricing_interest` — set to `true` if `category === 'PRICING_OR_COMMERCIAL_NEGOTIATION'` and was `'unknown'`.
  - All other fields remain at their `'unknown'`/`null` defaults.
- **`validation_learning`** (new top-level field, set by Workflow 2 Section E `E. Output Validation`): the **single authoritative, canonical** object for this execution. Section E reads `validationLearning = (input.classifier && input.classifier.validation_learning) || {}`, runs the per-field `isTriState` check (`true`/`false`/`'unknown'`) over the 9 tri-state fields, and returns `{...input, decision: finalDecision, validation:{valid, errors, checked_at}, validation_learning: validationLearning}`. If any field fails `isTriState`, `decision` is overridden to `review_hold:true, human_review_required:true, reply_permitted:false, external_action_status:'NOT_PERFORMED', terminal_status:'REVIEW_HOLD'` — but `validation_learning` itself still carries the (invalid) value through unchanged for human review (see fixture 15).

When writing fixtures or tests, **`expected.validation_learning` should be checked against the top-level `validation_learning`** (= `classifier.validation_learning`, post-validation). `fixtures/phase_3/run_synthetic_tests.js` does this directly — `known = {...result}` naturally exposes `result.validation_learning`; no special-case mapping is needed.

---

## 5. Local synthetic test harness

- `fixtures/phase_3/run_synthetic_tests.js` — pure Node.js, no n8n/Instantly/AI calls, no activation required. Run with `node run_synthetic_tests.js` from `fixtures/phase_3/`.
- Loads each Code section's `jsCode` directly out of the two workflow JSON exports via `new Function('$input', '$', jsCode)` and chains them in the same order n8n would execute them, following the Phase 3.1A branching: Workflow 1 `A -> B -> B1 -> {C (true) / B2 (false, terminal)}`, then for the `true` branch `C -> D -> E1 -> [simulated E2] -> E3 -> E4 -> {F (true) / E5 (false, terminal)}`, then for E4's `true` branch, Workflow 2 `A -> B -> C -> D -> E`. B1 and E4 are native IF nodes with no `jsCode`; their boolean conditions (`configGatePassed` / `eventIsNotDuplicate`) are reproduced directly in the harness from the exact `leftValue`/`operator` pairs in `workflows/01_reply_intake_validation.json`.
- The Data Table (E2) is simulated in-memory with a monotonic fake clock so a second upsert to the same `idempotency_key` returns `createdAt !== updatedAt` — this is the PROVISIONAL assumption from `reports/UNRESOLVED_ITEMS.md` U1.
- A fixture may declare a top-level `"inject": {"path": "dot.path", "value": ...}` object, applied via `setPath()` to the item after Workflow 2 Section B runs and before Section C — used by fixture 15 to push an invalid (non-tri-state) value into `classifier.validation_learning.pricing_interest` and confirm Section E's validation catches it.
- `checkPartial` supports `must_be_absent` (top-level fields that must be `undefined` on a terminal short-circuit, e.g. fixture 14/B2 and fixture 10 second-submission/E5) and a generic `{"starts_with": "..."}` expectation (used for the `identifier_poor_hash` idempotency-key prefix in fixtures 11/13).
- The main loop also runs a dedicated cross-check that fixtures 11 and 13 (two different malformed payloads) produce two distinct `idempotency_key` values — resolves `reports/UNRESOLVED_ITEMS.md` U3.
- Current result: **16/16 checks PASS** (15 fixtures + 1 cross-check).
- Re-run this script after any future edit to either workflow's Code-node `jsCode` to catch regressions before touching the live n8n instance.

---

## 6. What is NOT yet built (deferred, per the Phase 3 spec)

- Sender workflow (any real Instantly call, even mocked-as-real).
- SLA watchdog workflow.
- Error-handling workflow.
- Complete Phase 4 test harness (the 16 Phase 3 fixtures/checks + `run_synthetic_tests.js` are a "safe local synthetic tests where possible" step only, per Phase 3 validation requirement 10 — not the full harness).
- Any credential, environment variable file (`.env`), or external-service configuration (Instantly, AI provider, email, Slack, Google Sheets, Supabase).

Phase 4 must not begin without explicit user authorisation, per `CLAUDE.md` and `docs/IMPLEMENTATION_PLAN.md` §1.
