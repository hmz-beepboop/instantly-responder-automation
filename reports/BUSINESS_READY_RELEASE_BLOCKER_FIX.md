# Business-Ready Release-Blocker Correction (Offline)

**Verdict: `BUSINESS_READY_RELEASE_BLOCKERS_CLEARED`**

This pass corrects the eight release-blocking contract/acceptance defects
(A-H) identified by an independent audit, offline only. No workflow was
activated, no credentials were bound, no request left the filesystem, and
`config.dry_run=true` / `config.live_campaigns=[]` / all 7 workflows
`active: false` are unchanged.

## Corrections by blocker

- **A - Reply-success classification (workflow 03).** `R. Classify Send
  Attempt` now treats an HTTP 2xx from `Q. POST Reply to Instantly (Gated)`
  as terminal `SENT` only when the response body is a valid Email object
  (`id`, `message_id`, `thread_id` all non-empty strings); any other 2xx is
  `SEND_UNCERTAIN` (`ambiguous_side_effect=true`, `retryable=false`). `X2`
  carries `email_id`/`message_id`/`thread_id` into `terminal`.
- **B - Reconciliation (workflow 03).** `V. Reconciliation Poll
  (list_emails, Gated)` issues `GET /api/v2/emails` with
  `search/eaccount/lead/email_type=sent/min_timestamp_created/
  max_timestamp_created/preview_only=false/limit`. `W` filters locally:
  zero matches -> `HUMAN_REVIEW_ZERO_MATCHES`, multiple matches ->
  `HUMAN_REVIEW_MULTIPLE_MATCHES`, two consecutive single-match polls of the
  same id -> `SENT_RECONCILED` with `matchId`.
- **C - Suppression plan/execution (workflow 02).** `F. Safety Action Plan`
  emits schema_version 1.1 with 4 per-action contracts
  (`SOURCE_CAMPAIGN_STOP`, `UPDATE_INTEREST_STATUS`, `SUBSEQUENCE_REMOVAL`,
  `EXACT_EMAIL_BLOCKLIST`). The G0-G6 chain (canonical-lead retrieval,
  per-action gate/executor/record for each action, blocklist-verification
  G5, final G6) is now **fully connected** end to end - a genuine
  connectivity bug (G0r-G4r "Record" nodes had no outgoing edges, leaving
  G1g-G5g unreachable) was found and fixed directly in
  `workflows/02_reply_decision_engine_validation.json`, and
  `build-release-blocker-fixes.mjs` was updated to reproduce the same
  connections on regeneration. With the shipped
  `suppression_action_enablement.*` all `false`, every action remains
  `enabled=false` / `verification_status=SUPPRESSION_ACTION_DISABLED_BY_CONFIG`,
  and G6 reports `EXECUTION_AND_VERIFICATION_GATED_OFFLINE`.
- **D - Apply script as config source of truth.**
  `apply-business-ready.ps1` fails closed via `Assert-OwnerInputsComplete`
  (refuses unless `owner_inputs_status === 'COMPLETE'` and no `<REQUIRED_*>`
  placeholders remain), then re-embeds `config.launch_profile` /
  `config.allowlists` / `config.reviewer_allowlist` /
  `config.suppression_action_enablement` into the `HMZ_INJECT`-marked
  constants (`LAUNCH_PROFILE`, `ALLOWLISTS`, `REVIEWER_ALLOWLIST`,
  `SUPPRESSION_ACTION_ENABLEMENT`) and re-verifies them. A second genuine
  defect was found and fixed here: `Test-AllowedHttpUrl` previously rejected
  the G1h-G4h per-action executors' expression-based URLs
  (`={{ ... request_contract.url ... }}`), which would have made
  `Assert-WorkflowBodySafe` throw on workflow 02. A new check now recognises
  these as gated `hmzInstantlyApi` adapters (same `credentialPlaceholder` +
  `onError: continueRegularOutput` contract) and allows them. Verified via
  `pwsh -Command [Parser]::ParseFile` and a functional run of
  `Test-AllowedHttpUrl`/`Assert-WorkflowBodySafe` against the real workflow
  02 JSON.
- **E - Controlled-live acceptance via n8n.**
  `run-controlled-live-acceptance.ps1 -AllowOneControlledReply` posts the
  synthetic NES to the Intake workflow's dev webhook
  (`hmz-validation-reply-intake-dev`), temporarily activates only Intake,
  polls n8n's executions API for the Sender's run, and reads
  `terminal.send_state` / `email_id` / `message_id` / `thread_id`. It never
  calls `POST /api/v2/emails/reply` directly, and restores Intake's prior
  activation state plus `dry_run=true` / `live_campaigns=[]` in `finally`.
- **F - Production security gate fail-closed (workflow 01).** `F1` is a
  passthrough for non-`PRODUCTION_WEBHOOK` entries; for
  `PRODUCTION_WEBHOOK` entries, campaign and sender-eaccount allowlisting
  are conditional on `workspace_id` first being allowlisted, so an empty
  `ALLOWLISTS` (the shipped `HMZ_INJECT_BEGIN:ALLOWLISTS` default) fails all
  three checks (`WORKSPACE_NOT_ALLOWLISTED`,
  `CAMPAIGN_NOT_ALLOWLISTED_OR_WORKSPACE_NOT_ALLOWLISTED`,
  `SENDER_EACCOUNT_NOT_ALLOWLISTED_OR_WORKSPACE_NOT_ALLOWLISTED`). F2/F3
  produce `terminal.result=REJECTED`, `reason=PRODUCTION_SECURITY_GATE_FAILED`.
- **G - Reviewer auth and allowlist fail-closed (workflow 07).** The
  production review-form/submit webhooks require Basic Auth
  (`hmzReviewBasicAuth`; dev webhooks remain unauthenticated). `M1` is
  fail-closed: with the shipped empty `REVIEWER_ALLOWLIST`,
  `configured=false` and `allowlisted=false` (never `null`). `M2` routes
  `allowlisted=true` -> `N` (unchanged decision logic) and
  `allowlisted=false` -> `M2b` -> `N2`, with
  `token_invalid_reason=REVIEWER_NOT_ALLOWLISTED`.
- **H - Error/Schedule trigger acceptance.**
  `run-local-runtime-acceptance.ps1` temporarily activates the Reply Sender,
  Error Handler, Human Approval, and SLA Watchdog workflows in an isolated
  window, runs the Full Test Harness, then runs standalone `n8n execute`
  against the Error Handler's real Error Trigger and the SLA Watchdog's real
  Schedule Trigger, checking `persisted_error.errorId` and
  `watchdog_result.schema_version`/`phase4b_result_id`. The `finally` block
  restores all four workflows to `active: false`
  (`allWorkflowsInactiveAfter=true`).

## Test evidence

- New suite `verification/business-ready/run-release-blocker-tests.mjs`:
  **34/34 PASS** (`release-blocker-results.json`, `overall_result: "PASS"`),
  covering workflow parsing, all 8 blockers (A-H, 4+3+4+4+3+3+4+3=28 tests),
  plus 5 embedded regression re-runs.
- Regression chain, all re-checked with corrected (non-stale) assertions:
  Phase 4A **42/42**, Phase 4B **31/31**, integration-closure **16/16**,
  business-ready **23/23**, prior live-path **41/41**.
- New fixtures: `fixtures/business_ready_release/release_blocker_acceptance.json`
  (one synthetic acceptance record per blocker A-H).

## Scope notes

Two corrections went beyond test-assertion repair because they are genuine
implementation defects directly tied to named blockers, and both touched
files already in the hard write scope:

1. `workflows/02_reply_decision_engine_validation.json` - added the 5 missing
   `Record -> next Gate` connections completing the G0-G6 chain (Blocker C).
2. `verification/business-ready/apply-business-ready.ps1` - extended
   `Test-AllowedHttpUrl` to recognise the G1h-G4h expression-based per-action
   executor URLs as gated Instantly adapters (Blocker D).

No new features, no architecture changes, no credentials, no network access,
no activation. `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, all 7 workflows
`active: false` remain unchanged.

## Verdict

**`BUSINESS_READY_RELEASE_BLOCKERS_CLEARED`**
