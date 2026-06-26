# Phase 3.1B3A — Sub-Workflow Handoff Experiment

Date: 2026-06-12. Scope: prove one real n8n handoff from Intake
(`cCcpFfi6iovWS94T`) to Decision Engine (`NJcnNQoJ5nSIWYte`) and back, using
fixture `phase3_01_positive_interest_no_scheduling` (expected category
`POSITIVE_INTEREST`). No workflow edits made. 3 MCP calls used (limit 6).

## 1. Static read evidence (export files only, no MCP)

- Intake `G. Decision Engine Handoff` (`executeWorkflow`, source=database,
  workflowId=`NJcnNQoJ5nSIWYte`, mode=`each`, `workflowInputs.mappingMode:
  defineBelow` with empty `value: {}`) is fed by `F. Deterministic Prefilter`,
  which returns `{...input, prefilter: {...}}` — the full upstream item
  (carrying `nes`, `config`, `config_gate`, `idempotency`, and
  `nes.campaign_context` validation-cell fields) plus `prefilter`, with no
  field dropped or remapped.
- Decision Engine trigger `When Called by Reply Intake`
  (`executeWorkflowTrigger`, `inputSource: passthrough`) would receive that
  item as-is into `A. Deterministic Policy Stage`. Final node `E. Output
  Validation` returns `{...input, decision: finalDecision, validation: {...},
  validation_learning}`, where `decision` carries `category`, `confidence`,
  `terminal_status`, `external_action_status`, `reply_*`. `G` has no outgoing
  connections, so E's output would be Workflow 1's terminal output.
- Fixture `01_positive_interest_no_scheduling.json` expects
  `decision.category = "POSITIVE_INTEREST"`, `confidence 0.75`,
  `terminal_status: "REVIEW_HOLD"`, `external_action_status: "NOT_PERFORMED"`,
  `human_review_required: true`, `validation_learning.voice_of_customer_excerpt`
  populated.
- Conclusion: exported wiring is structurally consistent with the required
  handoff in both directions — but this is a static-file inference only, not
  execution evidence.

## 2. Test execution attempt

- Tool: `n8n_test_workflow`, `workflowId=cCcpFfi6iovWS94T`,
  `triggerType=webhook`, `httpMethod=POST`,
  `webhookPath=hmz-validation-reply-intake-dev`, `data=<fixture .input>`.
- **Test identifier:** none — no execution was created.
- **Result:** `success: false`, `error: "Workflow must be active to trigger
  via this method"`. n8n-mcp's only offered remedy is
  `n8n_update_partial_workflow` with `activateWorkflow` — a workflow edit,
  out of scope for this phase.
- **Input-transfer result:** NOT OBSERVED — execution never started, so
  nothing reached `G. Decision Engine Handoff` or the Decision Engine trigger.
- **Returned-output result:** NOT OBSERVED — no execution exists to inspect
  for `category`/`confidence`/`decision`/`validation_learning`/
  `terminal_status`/`external_action_status`.

## 3. Confirmations

- Credentials used: none (no execution ran).
- External calls: none (no execution ran).
- Active state post-attempt — `cCcpFfi6iovWS94T`: `active: false`;
  `NJcnNQoJ5nSIWYte`: `active: false`. Both remain inactive.

## 4. Earliest proven failure point

Intake's only trigger (`Webhook - Synthetic Reply Intake (DEV ONLY)`,
`n8n-nodes-base.webhook`, path `hmz-validation-reply-intake-dev`) cannot be
invoked by `n8n_test_workflow` while the workflow is inactive — webhook
execution requires `active: true`, and the tool has no inactive-webhook path.
No safer local mechanism exists for a webhook-triggered, inactive workflow
without activating it, which this phase forbids. Reported, not repaired.

## MCP call count

3 total: 1 `n8n_test_workflow` (failed) + 2 `n8n_get_workflow` (mode=minimal,
active-state confirmation).

## Final verdict

**SUB-WORKFLOW TEST INVOCATION BLOCKED**
