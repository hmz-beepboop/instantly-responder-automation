# Current Build State

Date: 2026-06-14 (Phase 5 final independent audit); updated 2026-06-15
(Phase 6 Integration Closure runtime test; Business-Ready Offline Build).

## Latest state (Business-Ready Offline Build, current)

**Offline build of the supervised VALIDATION live profile complete**
(`reports/BUSINESS_READY_OFFLINE_BUILD.md`,
`reports/BUSINESS_READY_GAP_MATRIX.md`,
`verification/business-ready/offline-test-results.json`,
verdict `BUSINESS_READY_OFFLINE_READY`):

- All 7 `... - Validation` workflows (01-07) are import-ready exports,
  `active: false`, no bound credentials.
- Workflow 02's mock semantic classifier was replaced by a deterministic,
  honestly-named classifier (`classifier_version:
  deterministic-heuristic-1.0`), including a `NON_ENGLISH_FALLBACK_T15`
  path for non-English replies (policy-HMZ-1.2 §15).
- Workflow 02 gained a "Safety Action Plan" node (F) that computes required
  suppression actions (stop-sequence / interest-status / blocklist)
  independently of, and prior to, the reply-approval gate, with each real
  call gated `false` by `config.suppression_action_enablement.*` and a
  documented `request_contract`.
- Workflow 03's live adapter contract (node N) now includes all 6 real
  Instantly V2 endpoints (`reply_to_email`, `update_interest_status`,
  `remove_subsequence`, `add_to_blocklist`, `get_email`, `list_emails`),
  still unreachable in validation (`LIVE_ADAPTER_UNREACHABLE_IN_VALIDATION`).
- `config/business-ready.config.json` is the single durable, non-secret
  configuration source (`DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, workspace/
  sender/retention/webhook-protection settings - several still
  `<REQUIRED_*>` placeholders pending owner input).
- New offline test suite
  (`verification/business-ready/run-offline-tests.mjs`) passes 23/23,
  plus regressions: phase4a 42/42, phase4b 31/31, integration-closure
  16/16.
- Four new PowerShell scripts exist (created, **not executed**):
  `apply-business-ready.ps1`, `run-local-runtime-acceptance.ps1`,
  `run-controlled-live-acceptance.ps1` (read-only pre-flight only), and
  `rollback-business-ready.ps1`.
- `infrastructure/business-live/` provides an offline-built (not deployed)
  Docker Compose hosting stack: n8n + `hmz-send-state` (no public port) +
  Caddy reverse proxy (the only public component, HTTPS via Let's
  Encrypt), with backup/restore scripts and a deployment/rollback README.
- `BUSINESS_READY_OWNER_INPUTS.md` remains `INCOMPLETE` by design - no
  `<REQUIRED_*>` value was guessed. PROVEN mode / unattended auto-send is
  not implemented anywhere in this repository.
- System readiness remains `READY_FOR_DRY_RUN`. Controlled-live and
  production readiness are **not** achieved - see `docs/NEXT_STEPS.md`.

## Previous state (Phase 6)

**Integration Closure runtime test PASSED**
(`reports/INTEGRATION_CLOSURE_RUNTIME.md`,
`verification/integration-closure/runtime-results.json`):

- All six workflows are built and integrated. Intake now hands off to the
  Decision Engine and then to the Reply Sender on the accepted,
  non-duplicate path only; the two rejection/duplicate terminal branches
  cannot reach the Sender.
- The normal Intake → Decision Engine → Sender path terminates
  `BLOCKED_PENDING_DURABLE_APPROVAL` (no durable human-approval mechanism
  exists yet).
- A separately approved synthetic Sender input reached `DRY_RUN_OK` in
  actual n8n runtime, with `sent=false` and `transport=NONE`.
- A synthetic Error Handler entry ran in actual n8n runtime and persisted a
  sanitised, non-retryable `SEND_UNCERTAIN` record.
- Five workflows (01, 02, 03, 05, 06) map `settings.errorWorkflow` to the
  actual Error Handler ID; workflow 04 (Error Handler) does not reference
  itself. Automatic Error Trigger routing from a genuinely failed parent
  execution remains unexercised — only the synthetic Execute Workflow
  Trigger path was run.
- All six workflows were returned to `active: false` after the test.
- Current local workflow IDs are environment-specific, not portable. Local
  exports retain placeholder sub-workflow/error-workflow IDs; a fresh import
  is remapped by `verification/integration-closure/apply-integration-closure.ps1`.
- System readiness remains `READY_FOR_DRY_RUN`. Controlled-live and
  production readiness are **not** achieved.

See `docs/NEXT_STEPS.md` for the next implementation objective.

## Phase and verdict (Phase 3-5, historical)

**Phase 3 VERIFIED COMPLETE.** Phase 3.1A surgical repairs, Phase 3.1B Data Table experiment, Phase 3.1C runtime acceptance tests, and Phase 3.1C6A technical closure are all done. See `reports/PHASE_3_FINAL_VERIFICATION.md` for the full closing summary.

**Phase 4 is built.** Four additional workflows (Reply Sender, Error Handler, SLA Watchdog, Full Test Harness) were added (`reports/PHASE_4_VALIDATION.md`). All six workflows total are inactive, contain no bound credentials, and target no external HTTP endpoint other than the local sidecar (`http://hmz-send-state:5681`).

**Instantly V1-V5 are verified** (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`), including V5 Layer 1 (local retry/error-classification fault injection) and V5 Layer 2 (lost-response/uncertain-send reconciliation).

**Phase 5 mechanical and final independent audit complete.** Final readiness verdict: `READY_FOR_DRY_RUN` (see `reports/VALIDATION_REPORT.md`). The Phase 4B n8n-MCP static-validator exception (five Code-node return-shape false positives) remains documented and unresolved by design — these workflows are not claimed `valid=true`.

## Workflows

| Workflow | ID | versionCounter | active |
| --- | --- | --- | --- |
| HMZ - Instantly Reply Intake - Validation | `cCcpFfi6iovWS94T` | 8 (`versionId c106d3b8-8738-4dd9-a6d6-1c06750847e2`) | false |
| HMZ - Reply Decision Engine - Validation | `NJcnNQoJ5nSIWYte` | 8 (`versionId 758b9928-2c10-48de-a7e7-2c34a8ef6fc9`) | false |

Both `isArchived: false`, `activeVersionId: null`, `errorCount: 0`. Exports in `workflows/01_reply_intake_validation.json` (22 nodes: 14 logical + 8 sticky) and `workflows/02_reply_decision_engine_validation.json` (12 nodes: 6 logical + 6 sticky).

## Verified runtime behaviours (Phase 3.1B/3.1C, real local n8n `2.25.7`)

- Data Table `upsert` (`hmz_validation_reply_intake_idempotency`, `xUlD0Zhoek6mU5I2`) returns `id`/`createdAt`/`updatedAt`; `createdAt` preserved and `updatedAt` advances on repeat upsert — `idempotency.is_duplicate` check confirmed correct as-is.
- Real sub-workflow handoff: Intake's `G. Decision Engine Handoff` (`executeWorkflow`) invokes the Decision Engine sub-workflow and receives `decision`/`draft`/`validation`/`validation_learning` back.
- Configuration-gate rejection: `dry_run:false` -> `config_gate.passed=false` -> `B1`(false) -> `B2` -> `terminal_status=REJECTED`, `external_action_status=NOOP`, Decision Engine never invoked.
- Duplicate termination: 2nd submission of same `intake_id` -> `is_duplicate=true` -> `E4`(false) -> `E5` -> `terminal_status=COMPLETED_NO_SEND`, `external_action_status=NOOP`, Decision Engine skipped.
- Unsubscribe / DNC: `category=UNSUBSCRIBE`, `stop_active_sequence=true`, `durable_dnc_intent=true`, `address_suppression_intent=ORGANISATION_DNC`, draft blocked, `terminal_status=REVIEW_HOLD`, `external_action_status=NOT_PERFORMED`.
- T1 vs T3 classification: POSITIVE_INTEREST -> `T1_SCENARIO_C_UNCLEAR_INTEREST`; BOOKING_REQUEST -> `T1_SCENARIO_A_OPEN_TO_CALL` (registry template-text identifier; name may read as confusing but behaviour is verified).
- Malformed payload (missing `event_type`): `payload_status=MALFORMED`, `idempotency.key_scheme=identifier_poor_hash` (hash-based, collision-resistant), `deterministic.rule_id=op-malformed`, `terminal_status=REJECTED`, `external_action_status=NOT_PERFORMED`.

## Semantics to carry forward

- Decision Engine external actions use `NOT_PERFORMED`; Intake terminal no-action branches (config-gate rejection, duplicate termination) use `NOOP`. Both mean "no external call occurred" — the literal reflects which sub-system produced the terminal item.
- Duplicate detection is verified against pinned n8n `2.25.7` only (`idempotency.duplicate_detection_status='VERIFIED_N8N_2_25_7'`).
- Intake export version metadata (`versionId`/`versionCounter`/`updatedAt`) may differ from the live instance after activation/deactivation cycles — this is expected churn, not a content change. Nodes, connections, and safety-critical logic (CONFIG, duplicate-detection status string) remain aligned.

## Mocked boundaries

- No Instantly nodes, no `httpRequest` nodes anywhere. Intake trigger is a dev-only synthetic webhook (`hmz-validation-reply-intake-dev`).
- AI / semantic classifier (Workflow 2 Section B) is a deterministic rule-based mock — no model API calls.
- Draft preparation (Workflow 2 Section D) returns placeholder `draft_text` only; nothing is transmitted.
- Persistence is n8n's built-in local Data Table (`xUlD0Zhoek6mU5I2`), non-paid, dev-safe, currently empty (`count: 0`).
- No Email / Slack / Google Sheets / Supabase nodes anywhere.
- `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, `OPERATING_MODE=VALIDATION` — all validation-safe defaults, unchanged.

## Historical: Phase 4 dependencies as of Phase 3 (resolved by Phase 4-6)

The items below were open at the end of Phase 3 and are retained for
traceability only; Phase 4-6 built and integrated all six workflows:

- Untested deterministic rules: `det-legal-002`, `det-regulator-001`, `det-hostile-001`, `det-hostile-002`, `det-media-001`, `det-attach-001`, `det-referral-001`, `det-wrong-001`, `op-self-sent`, `op-unsupported-event`, `op-empty-reply` (code-reviewed, not fixture-exercised).
- `TEMPLATE_REGISTRY` entries not selected by any fixture (e.g. most templates other than `T1_SCENARIO_A_OPEN_TO_CALL`, `T1_SCENARIO_C_UNCLEAR_INTEREST`, `T7_UNSUBSCRIBE_CONFIRMATION`).
- Campaign/validation-cell mismatch path (`prefilter.is_campaign_cell_mismatch`) — implemented, not exercised.
- Instantly-integration items in `docs/ASSUMPTIONS_AND_UNKNOWNS.md` (A3, B3, B4-B11) and the 9 owner decisions in section D — several are now `VERIFIED` (see that file); the remainder are tracked there, not here.

## Non-blocking warnings

- U5: "Invalid $ usage detected" on Workflow 1 Section D — false positive (literal `'$5k+ monthly retainer services'` string, not an n8n expression).
- U6: "Missing onError: 'continueErrorOutput'" on `B1`/`E4` (IF nodes) — false positive (IF node `main[1]` is its intrinsic "false" branch, not an error output).
- 20 total validator warnings across both workflows, all non-blocking, `errorCount: 0` on both.

## Exact next task

See `docs/NEXT_STEPS.md`. In summary: design a durable human-approval
mechanism for the Reply Sender's approval gate so the Intake → Decision
Engine → Sender path can resolve `BLOCKED_PENDING_DURABLE_APPROVAL` rather
than block at every accepted item.

## Files the next phase should read

- `reports/INTEGRATION_CLOSURE_RUNTIME.md`
- `reports/INTEGRATION_CLOSURE_OFFLINE_BUILD.md`
- `verification/integration-closure/runtime-results.json`
- `reports/UNRESOLVED_ITEMS.md`
- `docs/ASSUMPTIONS_AND_UNKNOWNS.md`
- `docs/HMZ_APPROVED_REPLY_RULES.md`
- `docs/NEXT_STEPS.md`

## Prohibited actions

- Do not set `DRY_RUN=false` or add to `LIVE_CAMPAIGNS` without explicit owner approval.
- Do not activate either workflow without a defined test plan and re-deactivation step.
- Do not add Instantly, AI-provider, email, Slack, Sheets, or Supabase nodes/credentials until the corresponding `docs/ASSUMPTIONS_AND_UNKNOWNS.md` items are resolved.
- Do not edit the `*.docx` business source documents.
- Do not claim controlled-live-test, deployment, or production readiness without new evidence.
