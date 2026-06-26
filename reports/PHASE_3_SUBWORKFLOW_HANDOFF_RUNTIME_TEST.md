# Phase 3.1B3C — Sub-Workflow Handoff Runtime Test (Verified)

Date: 2026-06-12. Resolves 3.1B3B by activating Decision Engine
(`NJcnNQoJ5nSIWYte`) before Intake (`cCcpFfi6iovWS94T`). Fixture
`phase3_01_positive_interest_no_scheduling`. 6 MCP calls used (limit 8).

## Result
- Pre-check: both workflows `active: false`.
- Activated Decision Engine, then Intake (both `active: true`).
- POST to `http://127.0.0.1:5678/webhook/hmz-validation-reply-intake-dev`
  -> `{"message":"Workflow was started"}`.
- Intake execution `1`: status `success`, finished `true`, mode
  `webhook`, lastNodeExecuted `"G. Decision Engine Handoff"`.
- Decision Engine invoked: YES (subExecution id `2`, workflowId
  `NJcnNQoJ5nSIWYte`, executionStatus `success`).
- Intake received returned result: YES — node output carries
  `decision`, `draft`, `validation`, `validation_learning` from DE; this
  node has no outgoing connections, so it is Intake's terminal output.
- Final category: `POSITIVE_INTEREST` (matches expected).
- Final terminal_status: `REVIEW_HOLD`.
- Credentials/external calls: none (mock classifier, n8n_data_table
  only; `external_actions_mocked: true`).
- Cleanup: deactivated Intake -> `active: false`, then Decision Engine
  -> `active: false`. Both confirmed inactive via deactivation responses.

## Verdict
**SUB-WORKFLOW HANDOFF VERIFIED**
