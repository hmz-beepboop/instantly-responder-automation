# Phase 3.1A Surgical Repair Changelog

Date: 2026-06-12. Scope: a focused set of surgical repairs to the two Phase 3 workflows (`HMZ - Instantly Reply Intake - Validation`, `cCcpFfi6iovWS94T`; `HMZ - Reply Decision Engine - Validation`, `NJcnNQoJ5nSIWYte`), addressing two previously-deferred KNOWN LIMITATION items (`reports/UNRESOLVED_ITEMS.md` U2 and U3), completing the duplicate-event routing path that those repairs made necessary, and consolidating `validation_learning` into a single authoritative, validated, top-level object. Phase 3.1A made **no changes** to Repairs already validated as Phase 3 (the F-section OOO regex fix, U4) and did not begin Phase 3.1B or Phase 4.

All four repairs below were applied directly to the live n8n workflows via `mcp__n8n-mcp__n8n_update_partial_workflow` / `n8n_update_full_workflow`, re-validated via `n8n_validate_workflow`, re-retrieved via `n8n_get_workflow`, and confirmed to match the local exports in `workflows/`. Both workflows remain `active: false`, `isArchived: false`, `activeVersionId: null` throughout and after all four repairs.

---

## Repair 1 — Configuration Gate Router / Rejection (`B1`/`B2`, Workflow 1)

**Resolves**: `reports/UNRESOLVED_ITEMS.md` U2 (previously KNOWN LIMITATION, now RESOLVED).

**Problem**: Workflow 1 Section B already computed `config_gate.{passed, dry_run_ok, live_campaign_claim_detected, reasons[]}` for every item, including setting `terminal_status='REJECTED'` and `processing_halted=true` on the item itself when `config_gate.passed=false`. However, nothing in the workflow *acted* on this — every item, regardless of `config_gate.passed`, continued unconditionally to `C. Payload Validation` and all the way through to the Decision Engine. A `config_gate.passed=false` item would still receive a full `classifier`/`decision`/`draft`/`validation` result, contradicting its own `terminal_status='REJECTED'`.

**Change made**: Two new nodes were inserted between `B. Configuration Gate` and `C. Payload Validation`:

- **`B1. Configuration Gate Router`** (`n8n-nodes-base.if`, typeVersion 2.3, id `f2e8963d-8580-4b2d-ad9a-6b6b02645483`, position `[820, -120]`). Single condition: `leftValue: "={{ $json.config_gate.passed }}"`, `operator: {type: "boolean", operation: "true", singleValue: true}`. Output 0 (`true`) → `C. Payload Validation`; output 1 (`false`) → `B2`.
- **`B2. Configuration Gate Rejection (Terminal)`** (`n8n-nodes-base.code`, typeVersion 2, id `c5f65583-97d5-4377-8d21-ace27779d296`, position `[820, 160]`, `onError: "continueRegularOutput"`). For each item, builds `reason = "Configuration gate failed: " + config_gate.reasons.join('; ')` (or a fallback string if `reasons` is empty), and spreads the input through with `terminal_status: 'REJECTED'`, `processing_halted: true`, `external_action_status: 'NOOP'`, `reason: reasonText`. `B2` has **no outgoing connections** — it is a terminal node. Items reaching `B2` never acquire `nes`, `idempotency`, `prefilter`, `deterministic`, `classifier`, `decision`, `draft`, or `validation`.

**Connections updated**: `B. Configuration Gate -> B1. Configuration Gate Router` (replacing the old direct `B -> C` edge); `B1.main[0] (true) -> C. Payload Validation`; `B1.main[1] (false) -> B2. Configuration Gate Rejection (Terminal)`.

**Because `CONFIG.dry_run=true` and `CONFIG.live_campaigns=[]` are hardcoded constants for Phase 3**, `config_gate.dry_run_ok` is always `true`, so `config_gate.passed=false` can currently only occur via `config_gate.live_campaign_claim_detected=true` — i.e. `raw_payload.dry_run===false`, `raw_payload.operating_mode` not `'VALIDATION'`, `raw_payload.campaign_id` in `CONFIG.live_campaigns` (currently impossible, the list is empty), or the synthetic-only `raw_payload.live_campaign===true` claim used by the new fixture.

**Sticky note updated**: `Section B - Configuration Gate (notes)` now documents the B1/B2 branch, including the exact downstream field set absent on a `B2` item and the fixture used to exercise it.

**Fixture**: `fixtures/phase_3/14_live_campaign_claim_config_gate_rejection.json` — `raw_payload.live_campaign=true` -> `config_gate={passed:false, dry_run_ok:true, live_campaign_claim_detected:true, reasons:["raw_payload.live_campaign is explicitly true"]}` -> routed to `B2` -> `terminal_status='REJECTED'`, `processing_halted=true`, `external_action_status='NOOP'`, `reason` contains `"raw_payload.live_campaign is explicitly true"`, and `must_be_absent` confirms `validated`, `validation_errors`, `payload_status`, `nes`, `idempotency`, `prefilter`, `deterministic`, `classifier`, `decision`, `draft`, `validation`, `validation_learning` are all absent.

**Note**: `raw_payload.live_campaign` is a **synthetic-only** field used solely to exercise the `B1` false branch in this isolated dev/test environment. It is not a real Instantly payload field and does not represent or enable any actual live-send capability or configuration change — `CONFIG.dry_run=true` and `CONFIG.live_campaigns=[]` remain hardcoded.

---

## Repair 2 — `identifier_poor_hash` Idempotency Key Scheme (`E1`, Workflow 1)

**Resolves**: `reports/UNRESOLVED_ITEMS.md` U3 (previously KNOWN LIMITATION / "confirmed behaviour", now RESOLVED).

**Problem**: `E1. Compute Idempotency Key` previously built `idempotency.idempotency_key` by joining `event_id`, `email_id`, `campaign_id`, `email_account`, `lead_email` with `:` regardless of whether any of those components were missing/`UNKNOWN`/`null`. For a malformed payload (where `validated.*` fields are largely `null` per Section C), every missing component collapsed to the same placeholder, so **any two structurally-different malformed payloads would produce the identical `idempotency_key`** — the second would be misread as a duplicate of the first (`is_duplicate=true`) even though they represent two distinct inbound events.

**Change made**: `E1. Compute Idempotency Key` now computes `key_components = {event_id, email_id, campaign_id, email_account, lead_email}` (each a string or `null`), and branches on whether **all five** are non-null:

- **`full_identity`** (all five present): `idempotency_key = event_id + ':' + email_id + ':' + campaign_id + ':' + email_account + ':' + lead_email`, `key_scheme = 'full_identity'`.
- **`identifier_poor_hash`** (any of the five missing): `idempotency_key = 'identifier_poor:instantly:' + <present components as "key=value", joined by ':'> + ':payload_hash=' + canonicalPayloadHash(raw_payload)`, `key_scheme = 'identifier_poor_hash'`. `canonicalPayloadHash` is a new helper: it recursively sorts all object keys (canonicalizes), `JSON.stringify`s the result, and runs the same djb2 hash algorithm already used for `nes.vendor_payload_hash`, returning an 8-hex-digit string. Because the hash is over the **entire raw payload** (key-sorted for determinism), two different malformed payloads — even ones missing the exact same set of identity fields — produce different `payload_hash` values and thus different `idempotency_key` values.

`idempotency.key_scheme` and `idempotency.key_components` are new fields on the `idempotency` object; all other `idempotency.*` fields (`proposed_state`, `state_enum`, `storage_adapter`, `storage_table_name`, and — after E3 — `is_duplicate`, `table_row_id`, `created_at`, `updated_at`, `duplicate_detection_method`, `duplicate_detection_status`) are unchanged.

**Sticky note updated**: `Section E - Idempotency Preparation & Duplicate Routing (notes)` documents both schemes, the `canonicalPayloadHash` algorithm, and the cross-fixture test.

**Fixtures**:
- `fixtures/phase_3/11_malformed_payload.json` — updated to expect `idempotency={proposed_state:'REJECTED', key_scheme:'identifier_poor_hash', idempotency_key:{starts_with:'identifier_poor:instantly:payload_hash='}}` (no identity components present at all for this fixture, so the key is just `identifier_poor:instantly:payload_hash=<hash>`).
- `fixtures/phase_3/13_distinct_malformed_payload.json` (new) — a second, structurally-distinct malformed payload (different `intake_id`/`lead_email`/`reply_text`/`event_type=""`), same expected shape.
- **Cross-check** (in `run_synthetic_tests.js`, not a standalone fixture): runs both 11 and 13 and asserts their `idempotency.idempotency_key` strings differ. Confirmed this session: fixture 11 -> `identifier_poor:instantly:payload_hash=32192ae0`, fixture 13 -> `identifier_poor:instantly:payload_hash=4983379e` — distinct.

---

## Repair 3 — Authoritative `validation_learning` (Workflow 2 Section E) + Workflow 1 Section D rename

**Problem**: Three different objects all related to "validation learning" existed with overlapping names and no single authoritative, validated result:
1. Workflow 1 Section D produced `nes.validation_learning` — a static object with all 11 fields defaulted to `'unknown'`/`null`, computed once during normalization, before any classification has happened.
2. Workflow 2 Section B produced `classifier.validation_learning` — seeded from (1), then enriched per-execution (`voice_of_customer_excerpt` filled from the reply text; `pricing_interest` set to `true` for `PRICING_OR_COMMERCIAL_NEGOTIATION`).
3. Nothing validated either object's field values, and no single top-level field told a human reviewer "here is the validation-learning result for this reply."

**Change made** (two parts):

1. **Workflow 1 Section D rename**: `nes.validation_learning` (the static, all-defaults object produced by `emptyValidationLearning()`) was renamed to **`nes.validation_learning_seed`** to make explicit that it is a non-authoritative seed, not a result. Workflow 2 Section B's `emptyValidationLearning(nes)` now reads `nes.validation_learning_seed` (with `??` fallbacks to `'unknown'`/`null` per field if absent, for robustness). The `Section D - Normalization to NES (notes)` and `Section B - Mock Semantic Classifier (notes)` sticky notes were updated to describe the rename and the seed/enriched relationship.

2. **Workflow 2 Section E (`E. Output Validation`) consolidation and validation**: Section E now reads `const validationLearning = (input.classifier && input.classifier.validation_learning) || {}` and:
   - Validates each of the 9 tri-state fields (`pain_confirmed`, `current_outbound_spend_confirmed`, `capacity_problem_confirmed`, `proof_objection`, `pricing_interest`, `alpha_interest`, `decision_maker_confirmed`, `discovery_call_booked`, `discovery_call_showed`) via a new `isTriState(value)` helper (`value === true || value === false || value === 'unknown'`). Any field present on `validationLearning` that fails `isTriState` adds an error: `` `validation_learning.${field} must be true, false, or "unknown", got ${JSON.stringify(value)}` ``. This error participates in the same overall `errors[]` array as all other Section E checks (decision-field presence/type/enum checks, prohibited-claim-pattern scan, etc.) — i.e. an invalid `validation_learning` field is sufficient on its own to make `validation.valid=false` and trigger the existing REVIEW_HOLD override (`review_hold=true`, `human_review_required=true`, `reply_permitted=false`, `external_action_status='NOT_PERFORMED'`, `terminal_status='REVIEW_HOLD'`, updated `reason`).
   - Returns a new **single top-level `validation_learning` object** = `validationLearning` (i.e. `classifier.validation_learning`), exposed unconditionally — on both pass and fail — alongside the existing `validation: {valid, errors, checked_at}` and (possibly overridden) `decision`. On failure, the invalid value is carried through **unchanged** so a human reviewer can see exactly what was produced.

   `Section E - Output Validation (notes)` was updated to describe the tri-state check, the read path (`(input.classifier && input.classifier.validation_learning) || {}`), and the single authoritative top-level `validation_learning` object.

**Result — three locations, now clearly distinguished** (see `docs/PHASE_3_CONFIGURATION_REFERENCE.md` §4 for the full reference):
- `nes.validation_learning_seed` (Workflow 1 Section D) — static defaults, non-authoritative seed.
- `classifier.validation_learning` (Workflow 2 Section B) — enriched per-execution (intermediate).
- **`validation_learning`** (top level, Workflow 2 Section E) — the single authoritative, tri-state-validated result. `known = {...result}` naturally exposes `result.validation_learning`; no special-case mapping needed by the test harness.

**Fixture**: `fixtures/phase_3/15_invalid_validation_learning_tristate.json` (new) — runs the same input as fixture 1 (`POSITIVE_INTEREST`, `interest_stage='VALIDATION_SPRINT_INTEREST'`) through Workflow 1 and Workflow 2 Section B unchanged, then the test harness **injects** `classifier.validation_learning.pricing_interest = 'MAYBE'` (an invalid, non-tri-state value) before Section C runs. Confirmed:
- `validation = {valid: false, errors: ['validation_learning.pricing_interest must be true, false, or "unknown", got "MAYBE"']}` (exactly 1 error — Section B does not enrich `pricing_interest` for `POSITIVE_INTEREST`, so absent the injection it would have remained `'unknown'` and fixture 15 would behave exactly like fixture 1).
- `decision` is overridden: `review_hold=true`, `human_review_required=true`, `reply_permitted=false`, `external_action_status='NOT_PERFORMED'`, `terminal_status='REVIEW_HOLD'` (terminal_status was already `REVIEW_HOLD` for `POSITIVE_INTEREST`, so `review_hold`/`reply_permitted` are the visible flips), `reason` contains `"Output validation failed (1 issue(s)) - routed to REVIEW_HOLD"`.
- Top-level `validation_learning = {pricing_interest: 'MAYBE', voice_of_customer_excerpt: "This sounds great, I'd like to learn more.", ...rest 'unknown'/null}` — the invalid value is carried through unchanged for human review.

This confirms Section E's per-field `isTriState` check on `classifier.validation_learning` is live and actually catches an out-of-range value, end to end.

---

## Repair 4 — Duplicate Event Router / Terminal (`E4`/`E5`, Workflow 1)

**Context**: Repair 2 made `idempotency.is_duplicate` (set by `E3. Recombine Idempotency Result`) a meaningful, scheme-aware signal for both `full_identity` and `identifier_poor_hash` keys. As with Repair 1, the underlying signal (`idempotency.is_duplicate`) already existed (from the original Phase 3 build), but nothing acted on it — every item, duplicate or not, continued unconditionally from `E3` to `F. Deterministic Prefilter` and on to the Decision Engine, even though `idempotency.proposed_state`/`state_enum` already included a `DUPLICATE` concept and CLAUDE.md rule 10 requires "one acknowledgement per inbound event" / no duplicate downstream actions.

**Change made**: Two new nodes were inserted between `E3. Recombine Idempotency Result` and `F. Deterministic Prefilter`:

- **`E4. Duplicate Event Router`** (`n8n-nodes-base.if`, typeVersion 2.3, id `4c6090f6-93a2-4047-a386-4f90c8d66540`, position `[2420, -120]`). Single condition: `leftValue: "={{ $json.idempotency.is_duplicate }}"`, `operator: {type: "boolean", operation: "false", singleValue: true}` — i.e. the condition is "`is_duplicate` is `false`". Output 0 (`true`, meaning `is_duplicate===false`, **not** a duplicate) → `F. Deterministic Prefilter`; output 1 (`false`, meaning `is_duplicate===true`, **is** a duplicate) → `E5`.
- **`E5. Duplicate Event Terminal`** (`n8n-nodes-base.code`, typeVersion 2, id `5a923a2f-368b-4787-9225-102641956ed4`, position `[2420, 160]`, `onError: "continueRegularOutput"`). For each item, reads `idempotency.idempotency_key` (or `'UNKNOWN'` if absent) and spreads the input through with `terminal_status: 'COMPLETED_NO_SEND'`, `processing_halted: true`, `external_action_status: 'NOOP'`, `stop_active_sequence: false`, and `reason: 'Duplicate event detected for idempotency key "<key>" (idempotency.is_duplicate=true); no further processing or send required.'`. `E5` has **no outgoing connections** — it is a terminal node. Items reaching `E5` retain everything through `idempotency` but never acquire `prefilter`, `deterministic`, `classifier`, `decision`, `draft`, or `validation` — Workflow 2 is never invoked for a duplicate.

**Connections updated**: `E3. Recombine Idempotency Result -> E4. Duplicate Event Router` (replacing the old direct `E3 -> F` edge); `E4.main[0] (true) -> F. Deterministic Prefilter`; `E4.main[1] (false) -> E5. Duplicate Event Terminal`.

**Side effect noted (not a defect)**: Workflow 2 Section A's `op-duplicate` rule (which reads `prefilter.is_duplicate_event`) is now unreachable in normal operation, since a duplicate item never reaches Workflow 2 (it terminates at `E5` first). It is left in place as defence-in-depth — harmless, and would only matter if Workflow 2 were ever invoked directly with a hand-built item that has `prefilter.is_duplicate_event=true` but bypassed `E4`.

**Fixture**: `fixtures/phase_3/10_duplicate_event.json`, `second_submission` — the same `intake_id` is submitted twice. First submission: `idempotency.is_duplicate=false`, `key_scheme='full_identity'`, routes `E4(true) -> F -> ... -> G -> Workflow 2`, full `classifier`/`decision`/`draft`/`validation` result (`POSITIVE_INTEREST`, `REVIEW_HOLD`, `human_review_required=true`), matching fixture 1's shape. Second submission: `idempotency.is_duplicate=true`, `idempotency_key` = the same `full_identity` key as the first submission, routes `E4(false) -> E5` (terminal): `terminal_status='COMPLETED_NO_SEND'`, `processing_halted=true`, `external_action_status='NOOP'`, `stop_active_sequence=false`, `reason` contains `'Duplicate event detected for idempotency key "evt-phase3-010:email-phase3-010:campaign-validation-001:outbound1@hmzvalidation.test:robin.shaw@prospectco.test"'`, and `prefilter`/`deterministic`/`classifier`/`decision`/`draft`/`validation`/`validation_learning` are all absent (`must_be_absent`).

---

## U6 — IF-node `onError` warnings on `B1`/`E4` (non-blocking, assessed)

Adding `B1` and `E4` (both `n8n-nodes-base.if`, typeVersion 2.3) introduced two new `n8n_validate_workflow` warnings on Workflow 1:

> Node has error output connections in main[1] but missing onError: 'continueErrorOutput'. Add this property to properly handle errors.

**Assessment (this session)**: this is a **false positive**, recorded as `reports/UNRESOLVED_ITEMS.md` U6 (NON-BLOCKING WARNING) with full evidence:
- `mcp__n8n-mcp__get_node('nodes-base.if', detail=full, includeTypeInfo=true)` confirms the IF node v2.3 schema defines exactly two **intrinsic** outputs, both `main`-type: `outputs: [{index:0, name:"true", description:"Items that match the condition"}, {index:1, name:"false", description:"Items that do not match the condition"}]`, `outputNames: ["true","false"]`. There is no separate error-output port for this node type — `main[1]` is the ordinary "false" branch, not an error output.
- `n8n_get_workflow(mode=structure)` confirms `B1.main[1] -> B2` and `E4.main[1] -> E5` are both `type: "main"` connections — ordinary conditional branches, exactly as intended by Repairs 1 and 4.
- Runtime confirmation: fixture 14 (config-gate rejection) exercises `B1`'s false branch to `B2` without error, and fixture 10's `second_submission` exercises `E4`'s false branch to `E5` without error — both produce their expected terminal outputs, not error-handler outputs.

No code change was made for U6. The validator's `onError: 'continueErrorOutput'` suggestion applies to nodes with a genuine separate error-output port (e.g. some HTTP/database nodes); applying it to an IF node's `false` output would be semantically wrong and was correctly not done.

---

## Validation, retrieval, and re-export summary

- **`n8n_validate_workflow(cCcpFfi6iovWS94T)`** (Workflow 1, post all four repairs): `valid: true, errorCount: 0, warningCount: 14, totalNodes: 14, enabledNodes: 14, triggerNodes: 1, validConnections: 13, invalidConnections: 0`.
- **`n8n_validate_workflow(NJcnNQoJ5nSIWYte)`** (Workflow 2, post Repair 3): `valid: true, errorCount: 0, warningCount: 6, totalNodes: 6, enabledNodes: 6, triggerNodes: 1, validConnections: 5, invalidConnections: 0`.
- **`n8n_get_workflow(mode=minimal)`** for both: `active: false, isArchived: false, activeVersionId: null`. Workflow 1: `updatedAt: "2026-06-12T02:19:40.611Z"`, `versionCounter: 7`, `versionId: "c885c7c9-11d5-48b2-a5fd-56c353642401"`. Workflow 2: `updatedAt: "2026-06-12T02:24:05.404Z"`, `versionCounter: 8`, `versionId: "758b9928-2c10-48de-a7e7-2c34a8ef6fc9"`.
- **Re-export**: `workflows/01_reply_intake_validation.json` (22 nodes: 14 logical + 8 sticky) and `workflows/02_reply_decision_engine_validation.json` (12 nodes: 6 logical + 6 sticky) were confirmed (via direct content comparison) to already match the live n8n `updatedAt`/`versionId`/`versionCounter` exactly — both files had already been re-exported as part of applying Repairs 1-4 and Repair 3, so no additional re-export step was needed.

## Synthetic test summary

`fixtures/phase_3/run_synthetic_tests.js` (rewritten this session to be branching-aware: `configGatePassed`/`eventIsNotDuplicate` helper functions reproduce the `B1`/`E4` IF conditions; `inject` mechanism supports fixture 15; `must_be_absent` and `{starts_with:...}` partial-match checks support fixtures 10/11/13/14) was run against all 15 fixtures plus the fixtures-11-vs-13 cross-check:

```
16 passed, 0 failed, 16 total
```

This includes the 12 original Phase 3 fixtures (unchanged behaviour, re-confirmed against the post-Phase-3.1A workflow code), the updated fixtures 10 and 11, and the three new fixtures 13, 14, and 15. Full per-fixture results are in `reports/PHASE_3_VALIDATION.md` §4.

---

## Final Phase 3.1A Verdict

**`PHASE 3.1A COMPLETE WITH NON-BLOCKING WARNINGS`**

- All four planned repairs (B1/B2 config-gate router/rejection; `identifier_poor_hash` idempotency key scheme; Workflow 2 Section E `validation_learning` consolidation + Workflow 1 Section D rename to `validation_learning_seed`; E4/E5 duplicate-event router/terminal) were implemented, applied to the live n8n workflows, and validated.
- Both `reports/UNRESOLVED_ITEMS.md` U2 and U3 (previously KNOWN LIMITATION) are now **RESOLVED**, each with a fixture (14, and 11+13+cross-check respectively) demonstrating the new behaviour.
- A new item, U6 (two `onError` warnings on the IF nodes added by Repairs 1 and 4), was investigated with concrete schema and runtime evidence and assessed as a **NON-BLOCKING WARNING / false positive** — no code change required.
- Both workflows validate with `errorCount: 0` (Workflow 1: 14 warnings, all non-blocking; Workflow 2: 6 warnings, unchanged, all non-blocking), remain confirmed `active: false` / `isArchived: false` / `activeVersionId: null`, and contain no credentials and no external-service node types.
- All 16 fixtures/checks pass (`16 passed, 0 failed, 16 total`).
- Remaining non-blocking items: U1 (PROVISIONAL Data Table duplicate-detection mechanism — logically sound and synthetically confirmed for both key schemes, but the real n8n Data Table `upsert` row-level `createdAt`/`updatedAt` behaviour is still unconfirmed), U4 (resolved in the original Phase 3 build), U5 (false-positive "Invalid $ usage" warning on Section D, unchanged). None of these block Phase 3.1A and none represent a confirmed defect.
- **Phase 3.1B and Phase 4 have not begun.** No further design or implementation beyond the four repairs above and their documentation/fixture/validation updates was performed this session.
