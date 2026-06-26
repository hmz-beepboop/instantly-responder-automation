## Phase 5 Final Status (2026-06-14)

Phase 5 final independent audit complete. See `reports/VALIDATION_REPORT.md`, `reports/SECURITY_AUDIT.md`, and `reports/FAILURE_MODE_AUDIT.md`.

- All six workflows remained inactive; remote logic matches local exports; no bound credentials; no external HTTP targets.
- Actual n8n runtime execution of the Full Test Harness and SLA Watchdog both completed successfully (PASS/success markers observed).
- Phase 4B n8n-MCP static-validator exception (5 Code-node return-shape false positives) remains documented and unresolved by design.
- Project secret/PII scan: 0 real-email hits, 0 unexpected secret-pattern hits; 2 known synthetic secret-pattern hits in offline test fixtures (expected).
- Remaining open items as of Phase 5 (did not block `READY_FOR_DRY_RUN`):
  - Sender/Error Handler runtime evidence in Phase 4/5 was limited to the validator and offline/compile suites, with no actual n8n-runtime execution yet.
  - No live Instantly call/Sender execution has occurred (prohibited by scope).
  - Zero/multiple-match reconciliation outcomes are policy-verified (human review, no second POST) but not exercised against a live Instantly response.
  - SLA Watchdog's actual n8n execution used a manual/CLI-triggered run of the Schedule Trigger node (workflow remains inactive); an actual scheduled firing while active was not exercised.
- Final readiness verdict: `READY_FOR_DRY_RUN`.

## Phase 6 update (2026-06-15) — Integration Closure

- **RESOLVED:** the Sender/Error Handler n8n-runtime-evidence item above is
  closed. The Integration Closure runtime test
  (`reports/INTEGRATION_CLOSURE_RUNTIME.md`,
  `verification/integration-closure/runtime-results.json`) executed the real
  Reply Sender (approved synthetic item → `DRY_RUN_OK`, `sent=false`,
  `transport=NONE`) and the real Error Handler (forced synthetic item →
  sanitised, non-retryable `SEND_UNCERTAIN` record) in actual n8n runtime.
  All six workflows were returned to `active: false` afterward.
- **STILL OPEN:** no live reply has been sent through the n8n Reply Sender
  workflow; zero/multiple-match reconciliation remains policy-verified only;
  the SLA Watchdog's actual scheduled (cron) firing while active remains
  unexercised; automatic `settings.errorWorkflow` routing from a genuinely
  failed parent execution remains unexercised (only the synthetic Execute
  Workflow Trigger path was run).
- **NEW:** the normal Intake → Decision Engine → Sender path terminates
  `BLOCKED_PENDING_DURABLE_APPROVAL` because no durable human-approval
  mechanism exists yet for the Sender's approval gate — see
  `docs/NEXT_STEPS.md` for the next implementation objective.
- Readiness verdict remains `READY_FOR_DRY_RUN`. Controlled-live and
  production readiness remain unapproved. A controlled live dry-run/test
  campaign may be planned only with `DRY_RUN=true` retained, an explicit
  owner-approved scoped Instantly key, and a durable approval mechanism for
  the Sender's gate, before any `LIVE_CAMPAIGNS` entry or `DRY_RUN=false`
  change is considered.

---

# Phase 3 — Unresolved Items

Date: 2026-06-11, updated 2026-06-12 (Phase 3.1A surgical repairs; Phase 3.1B/3.1C runtime verification). Scope: items identified while building and synthetically testing the two Phase 3 workflows (`HMZ - Instantly Reply Intake - Validation`, `HMZ - Reply Decision Engine - Validation`) and the 16 fixtures/checks under `fixtures/phase_3/`. This file records what is still open, what was found and fixed during this build (including Phase 3.1A), what was confirmed against the real local n8n instance (Phase 3.1B/3.1C), and what is a confirmed non-blocking warning. It does not change `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, or `OPERATING_MODE=VALIDATION`, and does not authorise Phase 4.

Status meanings (same taxonomy as `docs/ASSUMPTIONS_AND_UNKNOWNS.md`):
- **VERIFIED** — confirmed against the live n8n instance or a captured payload.
- **PROVISIONAL** — implemented and logically sound (confirmed by local synthetic simulation), but not yet confirmed against the real n8n component it stands in for.
- **RESOLVED** — a confirmed defect found during this build, fixed, and re-validated.
- **KNOWN LIMITATION** — an intentional, documented gap that does not block Phase 3 given the current hardcoded configuration.
- **NON-BLOCKING WARNING** — a validator finding investigated and confirmed not to be a defect.

---

## U1. Idempotency duplicate detection — **VERIFIED this session (Phase 3.1B1 Data Table experiment + Phase 3.1C2 runtime test)**

- **Where**: Workflow 1 (`cCcpFfi6iovWS94T`), Section E1 (`E1. Compute Idempotency Key`) computes `idempotency.idempotency_key`; Section E2 (`E2. Idempotency Data Table Upsert`, `n8n-nodes-base.dataTable`, `resource=row`, `operation=upsert`, table ID `xUlD0Zhoek6mU5I2`, table name `hmz_validation_reply_intake_idempotency`) upserts a row keyed on `idempotency_key`; Section E3 (`E3. Recombine Idempotency Result`) reads the upserted row's `createdAt`/`updatedAt` and sets:
  ```
  idempotency.is_duplicate = !!(createdAt && updatedAt && createdAt !== updatedAt)
  idempotency.duplicate_detection_method = 'created_at_vs_updated_at_after_upsert'
  idempotency.duplicate_detection_status = 'VERIFIED_N8N_2_25_7'
  ```
- **Why it matters**: CLAUDE.md rule 10 requires persistent idempotency + send-state checks so no duplicate event produces a duplicate downstream action. This is the entire mechanism for fixture 10 (duplicate event) and for the malformed-payload collision in U3.
- **Resolved by (Phase 3.1B1)**: `reports/PHASE_3_DATATABLE_BEHAVIOUR_EXPERIMENT.md` exercised the real local Data Table (`xUlD0Zhoek6mU5I2`) directly via `mcp__n8n-mcp__n8n_manage_datatable` (`upsertRows`/`getRows`/`deleteRows`, no workflow execution). Confirmed: `upsert` returns `id`/`createdAt`/`updatedAt` (camelCase, ISO 8601 with milliseconds); a first upsert sets `createdAt === updatedAt`; a second upsert to the same `idempotency_key` preserves `createdAt` and advances `updatedAt` (`createdAt !== updatedAt`); omitted fields on the second upsert are preserved unchanged. E3's existing comparison is correct as written — no code change required. Test rows cleaned up (`getRows` -> `count: 0`).
- **Resolved by (Phase 3.1C2)**: `reports/PHASE_3_RUNTIME_ACCEPTANCE_LOG.md` then confirmed the same behaviour end-to-end inside the live, activated Intake workflow (real `n8n-nodes-base.dataTable` E2 node, real webhook trigger, not the MCP datatable tool directly): the same `intake_id` (fixture `phase3_01_positive_interest_no_scheduling`) was POSTed twice. 1st submission: `idempotency.is_duplicate=false`, full processing through to Decision Engine, `terminal_status=REVIEW_HOLD`. 2nd submission (identical payload): `idempotency.is_duplicate=true`, routed `E4(false) -> E5. Duplicate Event Terminal`, Decision Engine skipped, `terminal_status=COMPLETED_NO_SEND`, `external_action_status=NOOP`, `stop_active_sequence=false`. Both workflows deactivated and the Data Table row deleted afterward.
- **Status**: VERIFIED. Both the real n8n Data Table `upsert` row shape/behaviour and the live `E4`/`E5` duplicate-routing path are confirmed end-to-end against n8n `2.25.7`.
- **Blocks Phase 4?** No.

---

## U2. `config_gate.passed=false` is computed but not branched on — **RESOLVED this session (Phase 3.1A Repair 1)**

- **Where**: Workflow 1, Section B (`B. Configuration Gate`) computes `config_gate.{passed, dry_run_ok, live_campaign_claim_detected, reasons[]}` for every item. A new node, **`B1. Configuration Gate Router`** (`n8n-nodes-base.if` v2.3, id `f2e8963d-8580-4b2d-ad9a-6b6b02645483`, position `[820,-120]`), was inserted immediately after Section B with condition `leftValue: "={{ $json.config_gate.passed }}"`, `operator: {type:"boolean", operation:"true", singleValue:true}`.
- **New branching**: B1's `true` output (`main[0]`, `config_gate.passed === true`) connects to `C. Payload Validation` exactly as before. B1's `false` output (`main[1]`, `config_gate.passed === false`) connects to a new terminal node, **`B2. Configuration Gate Rejection (Terminal)`** (`n8n-nodes-base.code`, id `c5f65583-97d5-4377-8d21-ace27779d296`, position `[820,160]`, `onError:"continueRegularOutput"`), which builds a `reasonText` from `config_gate.reasons` (joined with `'; '`) and returns `{...input, terminal_status:'REJECTED', processing_halted:true, external_action_status:'NOOP', reason: reasonText}`. Sections C-G and the entire Decision Engine (Workflow 2) never run for a `config_gate.passed=false` item.
- **Tested by**: `fixtures/phase_3/14_live_campaign_claim_config_gate_rejection.json` — `raw_payload.live_campaign=true` (a synthetic-only claim) sets `config_gate.live_campaign_claim_detected=true` and `config_gate.passed=false` even though `CONFIG.dry_run=true`. The fixture asserts `terminal_status=REJECTED`, `processing_halted=true`, `external_action_status=NOOP`, a `reason` containing `"raw_payload.live_campaign is explicitly true"`, and `must_be_absent` for every field Sections C-G / Workflow 2 would otherwise produce (`validated`, `validation_errors`, `payload_status`, `nes`, `idempotency`, `prefilter`, `deterministic`, `classifier`, `decision`, `draft`, `validation`, `validation_learning`). PASS.
- **Validated**: `mcp__n8n-mcp__n8n_validate_workflow(cCcpFfi6iovWS94T)` -> `valid: true, errorCount: 0` (14 nodes, 13 valid connections, 0 invalid connections). Retrieved via `mcp__n8n-mcp__n8n_get_workflow(mode=minimal)` -> `active: false, isArchived: false, activeVersionId: null`. Re-exported to `workflows/01_reply_intake_validation.json` (`updatedAt: "2026-06-12T02:19:40.611Z"`, `versionId: "c885c7c9-11d5-48b2-a5fd-56c353642401"`, `versionCounter: 7`).
- **Status**: RESOLVED. `CONFIG.dry_run: true` and `CONFIG.live_campaigns: []` remain hardcoded (`docs/ASSUMPTIONS_AND_UNKNOWNS.md` section D, unchanged) — migrating `CONFIG` to environment-variable-backed values is still future work, but is now fully independent of this routing fix.
- **Blocks Phase 4?** No.

---

## U3. Malformed-payload idempotency-key collision — **RESOLVED this session (Phase 3.1A Repair 2)**

- **Where**: Workflow 1, Section E1 (`E1. Compute Idempotency Key`). Previously, when `validated.event_id`, `validated.email_id`, `validated.campaign_id`, `validated.email_account`, and `nes.lead_email` were all absent/invalid (true for every malformed payload, since Section C sets all 11 `validated.*` fields to `null`), E1 fell back to the fixed placeholders `NOEVENTID`, `NOEMAILID`, `NOCAMPAIGN`, `NOEACCOUNT`, `NOLEADEMAIL`, producing the **same** `idempotency_key` (`NOEVENTID:NOEMAILID:NOCAMPAIGN:NOEACCOUNT:NOLEADEMAIL`) for every malformed payload regardless of content.
- **Fix applied**: E1 now classifies each item by `key_scheme`. If all five key components (`event_id`, `email_id`, `campaign_id`, `email_account`, `lead_email`) are present and valid, `key_scheme='full_identity'` and `idempotency_key = [event_id,email_id,campaign_id,email_account,lead_email].join(':')` (unchanged from before). Otherwise (`isIdentifierPoor=true`, i.e. one or more components are `null`), `key_scheme='identifier_poor_hash'` and `idempotency_key = ['identifier_poor','instantly', ...presentParts, \`payload_hash=${canonicalPayloadHash(raw_payload)}\`].join(':')`, where `presentParts` lists only the non-null `key=value` components and `canonicalPayloadHash` is a recursive key-sorted-JSON djb2 hash (8 hex chars) of `raw_payload` itself. For a fully malformed payload (all 5 components null), this reduces to `identifier_poor:instantly:payload_hash=<hash>` — a hash of the exact payload, not a fixed placeholder.
- **Tested by**:
  - `fixtures/phase_3/11_malformed_payload.json` (`event_type` missing) and `fixtures/phase_3/13_distinct_malformed_payload.json` (different `intake_id`/`lead_email`/`reply_text`, explicit empty-string `event_type`) both assert `idempotency.key_scheme='identifier_poor_hash'` and `idempotency.idempotency_key` starting with `"identifier_poor:instantly:payload_hash="`.
  - `run_synthetic_tests.js`'s main loop performs a dedicated cross-check: `idempotency_key` for fixtures 11 and 13 must be distinct strings. Observed: fixture 11 = `identifier_poor:instantly:payload_hash=32192ae0`, fixture 13 = `identifier_poor:instantly:payload_hash=4983379e` — distinct, as expected (different `raw_payload` -> different hash).
  - Both fixtures independently reach `rule_id='op-malformed'` / `terminal_status='REJECTED'` / `human_review_required=true` — neither is misread as a duplicate of the other.
- **Validated**: covered by the same `n8n_validate_workflow(cCcpFfi6iovWS94T)` -> `valid: true, errorCount: 0` run as U2 (same workflow, same export).
- **Status**: RESOLVED. The well-formed (`full_identity`) path is unchanged and still covered by fixtures 1-10, 12, 14, 15.
- **Blocks Phase 4?** No.

---

## U4. `OOO_PATTERN` regex gap in Workflow 1 Section F — **RESOLVED this session**

- **Found during**: Task #8 (local synthetic testing). `fixtures/phase_3/05_out_of_office.json` (reply text "I am currently out of the office and will return on Monday...") failed: `expected.prefilter.is_out_of_office=true`, actual `false`.
- **Root cause**: Workflow 1 Section F (`F. Deterministic Prefilter`)'s `OOO_PATTERN` was:
  ```
  /\b(out of office|ooo|on leave|on vacation|away from (the )?office|annual leave)\b/i
  ```
  This does not match the extremely common phrasing "out of **the** office" (missing the optional "the" before "office" in the first alternative — note the second-to-last alternative, "away from (the )?office", already had the optional group, but "out of office" did not).
- **Scope check**: Workflow 2 Section A's own `det-ooo-001` regex (`/(out of (the )?office|on vacation|on holiday|on leave|on sabbatical|automatic reply|auto[- ]?reply|away from (the )?office|currently away)/`) already correctly handled "out of (the )?office" — so the deterministic-match, classifier, decision, and draft results for fixture 5 were all correct **even before this fix**. Only Workflow 1 Section F's diagnostic flag `prefilter.is_out_of_office` was wrong.
- **Fix applied**:
  ```
  /\b(out of (the )?office|ooo|on leave|on vacation|away from (the )?office|annual leave)\b/i
  ```
  Applied via `mcp__n8n-mcp__n8n_update_partial_workflow` (`patchNodeField` on node "F. Deterministic Prefilter", `parameters.jsCode`, single find/replace). Validated via `mcp__n8n-mcp__n8n_validate_workflow` (`valid=true, errorCount=0`). Retrieved via `mcp__n8n-mcp__n8n_get_workflow` (`mode=full`) and confirmed: `active=false`, `activeVersionId=null`, `versionCounter=3`, `versionId="657a83c9-6072-40df-afde-550047f12dec"`. Re-exported to `workflows/01_reply_intake_validation.json` (3 surgical edits: the regex string, `versionId`, `versionCounter`, `updatedAt`).
- **Result**: `node fixtures/phase_3/run_synthetic_tests.js` -> all 12 fixtures PASS, 0 failed.
- **Status**: RESOLVED. No further action needed. This is the synthetic-test process working as intended — a real (if minor) gap in an inactive Code node was found and fixed before any live use.

---

## U5. "Invalid $ usage detected" warning on Workflow 1 Section D — **NON-BLOCKING WARNING, assessed this session**

- **Where**: `mcp__n8n-mcp__n8n_validate_workflow` on `cCcpFfi6iovWS94T` returns `valid=true, errorCount=0, warningCount=10`. Nine of the ten warnings are the generic, expected per-Code-node "Code nodes can throw errors — consider error handling" suggestion (one per Code node, plus one workflow-level suggestion). The tenth and only Code-node-specific finding is **"Invalid $ usage detected"** on node "D. Normalization to NES".
- **Investigation**: Section D's `jsCode` contains exactly one `$`-prefixed token outside of the standard `$input.all()` accessor on line 1 — a literal JavaScript string constant (used when populating `nes.campaign_context.subsegment` for the validation cells, sourced from `docs/VALIDATION_CAMPAIGN_CONFIG.md`):
  ```js
  subsegment: '$5k+ monthly retainer services',
  ```
- **Assessment**: the validator's static check for malformed n8n expressions (`$json`, `$node`, `$(...)`, etc.) appears to pattern-match on any `$` character in the code body, including inside string literals — this is a **false positive**. The string is syntactically valid JavaScript, is not an n8n expression, and executes correctly: all 12 fixtures pass, including fixtures 1, 10, and 12 which exercise CELL_1/CELL_2/CELL_3 campaign-context normalization through this exact code path.
- **Decision**: no code change made. Per CLAUDE.md "Surgical Changes", rewording or escaping an approved campaign-context literal from `docs/VALIDATION_CAMPAIGN_CONFIG.md` purely to silence a validator false positive is out of scope and would not change behaviour.
- **Blocks Phase 4?** No.

---

## U6. "Missing onError: 'continueErrorOutput'" warning on B1 and E4 (IF nodes) — **NON-BLOCKING WARNING, assessed this session (Phase 3.1A)**

- **Where**: `mcp__n8n-mcp__n8n_validate_workflow(cCcpFfi6iovWS94T)` -> `valid: true, errorCount: 0, warningCount: 14` (up from 10 before Repairs 1/4: +1 generic "Code nodes can throw errors" suggestion each for the two new terminal Code nodes `B2. Configuration Gate Rejection (Terminal)` and `E5. Duplicate Event Terminal`, +1 "Webhooks should always send a response, even on error" finding on the trigger not previously itemised, and +2 of the finding below). The two new node-specific findings are both:
  > "Node has error output connections in main\[1\] but missing onError: 'continueErrorOutput'. Add this property to properly handle errors."

  on **`B1. Configuration Gate Router`** and **`E4. Duplicate Event Router`** — the two IF nodes added by Repairs 1 and 4.
- **Investigation**:
  - **Node schema** (`mcp__n8n-mcp__get_node('nodes-base.if', detail=full, includeTypeInfo=true)`, IF node v2.3): the node type's `outputs` are intrinsically `[{index:0, name:"true"}, {index:1, name:"false"}]` (`outputNames: ["true","false"]`) — both ordinary `main`-type data outputs defined by the node itself, each with its own `connectionGuidance`. The IF node schema has no separate "error output" port at all. `onError: 'continueErrorOutput'` is a mechanism for *other* node types that have a single main output plus an optional error-routing output; it is not a meaningful configuration for a node whose normal two-output operation is already its complete behaviour.
  - **Workflow connections** (`mcp__n8n-mcp__n8n_get_workflow(cCcpFfi6iovWS94T, mode=structure)`, current export): `"B1. Configuration Gate Router": {"main": [[{"node":"C. Payload Validation","type":"main","index":0}], [{"node":"B2. Configuration Gate Rejection (Terminal)","type":"main","index":0}]]}` and `"E4. Duplicate Event Router": {"main": [[{"node":"F. Deterministic Prefilter","type":"main","index":0}], [{"node":"E5. Duplicate Event Terminal","type":"main","index":0}]]}`. Both `main[1]` connections are `type:"main"` (ordinary data-flow), not `type:"error"`.
  - **Runtime confirmation**: both `false` branches are exercised end-to-end by the synthetic harness — fixture 14 (`config_gate.passed=false` -> B1 false -> B2 -> `terminal_status=REJECTED`) and fixture 10's `second_submission` (`idempotency.is_duplicate=true` -> E4 false -> E5 -> `terminal_status=COMPLETED_NO_SEND`) both PASS.
- **Assessment**: **false positive**. The validator's heuristic for "error output connections" appears to assume that any connection present at output index `main[1]` is an error-routing connection requiring `onError: 'continueErrorOutput'`. For an IF node, `main[1]` is the node's own intrinsic, schema-defined "false" branch — an ordinary second output, not an error output. Setting `onError: 'continueErrorOutput'` on `B1`/`E4` would not be semantically applicable (there is no separate error output to redirect into) and would not change behaviour.
- **Decision**: no code change made. Per CLAUDE.md "Surgical Changes", adding a node property purely to silence a validator false positive — with no behavioural effect and no applicable target for that property — is out of scope.
- **Blocks Phase 4?** No.

---

## Summary

| ID | Item | Status | Blocks Phase 4? |
| --- | --- | --- | --- |
| U1 | Idempotency duplicate detection (createdAt vs updatedAt after Data Table upsert) | VERIFIED (Phase 3.1B1 + 3.1C2) | No |
| U2 | `config_gate.passed=false` computed but not branched on | RESOLVED (Phase 3.1A Repair 1; runtime-verified 3.1C1) | N/A |
| U3 | Malformed payloads share one idempotency key | RESOLVED (Phase 3.1A Repair 2; runtime-verified 3.1C5) | N/A |
| U4 | `OOO_PATTERN` missing "out of THE office" (Workflow 1 Section F) | RESOLVED | N/A |
| U5 | "Invalid $ usage detected" on Workflow 1 Section D | NON-BLOCKING WARNING | No |
| U6 | "Missing onError: 'continueErrorOutput'" on B1/E4 (IF nodes) | NON-BLOCKING WARNING | No |

All Phase 3 runtime assumptions (U1-U4) are now RESOLVED/VERIFIED against the real local
n8n instance (`2.25.7`); U5/U6 remain non-blocking validator-warning false positives.
None of U1-U6 require `DRY_RUN=false`, a `LIVE_CAMPAIGNS` entry, or any
Instantly/AI/email/Slack/Sheets/Supabase call. Genuine Phase 4 dependencies (untested
deterministic rules, untested `TEMPLATE_REGISTRY` entries, campaign/cell-mismatch path,
and the unresolved Instantly-integration items in `docs/ASSUMPTIONS_AND_UNKNOWNS.md`)
are unaffected by this file and remain open — see `reports/PHASE_3_VALIDATION.md` §5 and
`docs/ASSUMPTIONS_AND_UNKNOWNS.md` section D.
