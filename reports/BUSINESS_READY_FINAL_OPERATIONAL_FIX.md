# Business-Ready Final Controlled-Live Orchestration Fix

**Generated:** 2026-06-15T17:03:27.827Z (offline build session)
**Verdict:** `FINAL_OPERATIONAL_FIX_READY`

This was the final offline-only code pass on the business-ready package. No
redesign, no reply-policy/classifier/send-state changes, no workflow JSON
edits (all 7 exports remain `active: false`, unchanged). No n8n/Docker/
Instantly/MCP/network access was used; nothing was activated.

## Corrections made (1-6)

1. **Live gates** - `New-ControlledLiveConfig` in
   `run-controlled-live-acceptance.ps1` builds an in-memory clone of
   `config/business-ready.config.json` with `operating_mode=SUPERVISED_VALIDATION`,
   `dry_run=false`, `live_campaigns=[the one designated campaign]`,
   `allowlists.campaign_ids=[same]`, `launch_profile.required_operating_mode=
   SUPERVISED_VALIDATION`, and the three `live_credential_readiness` flags set
   true, leaving every owner-supplied allowlist/reviewer/sender value
   untouched. `Restore-SafeState` restores the pre-run backup or, failing
   that, re-asserts `operating_mode=VALIDATION`/`dry_run=true`/
   `live_campaigns=[]`/`allowlists.campaign_ids=[]`/all three readiness flags
   `false`.
2. **Real human-approval path** - `-AllowOneControlledReply
   -ConfirmationPhrase "RUN-ONE-CONTROLLED-REPLY"` replaces the prior
   synthetic dev-webhook send. It backs up config + all 7 remote workflow
   bodies, applies the temporary config, activates the 6 runtime workflows
   (Full Test Harness excluded and explicitly verified inactive), prints a
   unique marker and the exact owned campaign/workspace/sender/lead/subject,
   and blocks on operator confirmation after a real reply is sent and
   approved via the production Human Approval review page. It never POSTs to
   the Instantly reply-send endpoint; it polls n8n executions for the Reply
   Sender's `terminal.*` and independently confirms via `GET /api/v2/emails`
   (one Email object, correct thread/subject/marker, empty CC/BCC, no
   duplicate after 60s). `SEND_UNCERTAIN` triggers reconciliation reads only,
   never a second send. `finally` always deactivates, restores, reruns
   `apply-business-ready.ps1`, and clears all secret/controlled-live env vars.
3. **Credential binding by type** (carried over from this task's prior pass,
   re-verified) - `apply-business-ready.ps1` resolves `hmzInstantlyApi` /
   `hmzInstantlyWebhookToken` as `httpHeaderAuth` and `hmzReviewBasicAuth` as
   `httpBasicAuth`, each requiring its own `HMZ_*_CREDENTIAL_ID`; the review
   credential is never routed through the Instantly credential map.
4. **Google Chat env contract** - no workflow JSON change.
   `infrastructure/business-live/docker-compose.yml` now passes
   `GOOGLE_CHAT_WEBHOOK_URL` into the n8n container; `.env.example` documents
   it as a deployment-only secret with no separate `hmzGoogleChatWebhook`
   credential required.
5. **Fail-closed workspace preflight** - `Invoke-Preflight` now requires the
   designated campaign's `workspace_id` to be non-empty, in
   `config.workspace_allowlist`, AND exactly equal to
   `config.allowlists.workspace_id`; a blank/missing workspace_id alone
   blocks.
6. **Owner inputs/config consistency** - `BUSINESS_READY_OWNER_INPUTS.md`
   gained rows for the review Basic Auth and webhook-token credentials, the
   public n8n/review/production-webhook URLs, the exact controlled-live
   campaign/workspace/sender/recipient/subject fields, and an explicit owner
   acknowledgement of the temporary live-mode rewrite/restore cycle. No
   secret values were added. `rollback-business-ready.ps1` accepts
   `hmzReviewBasicAuth` in credential backups and re-asserts all safe
   defaults (including `live_credential_readiness.review_basic_auth=false`)
   on rollback.

## Targeted offline test suite

`verification/business-ready/run-final-operational-tests.mjs`: **17/17
passed** (see `final-operational-results.json`), covering the 15+ required
checks: safe stored config; temp SUPERVISED_VALIDATION/dry_run=false/one
campaign construction; absence of the synthetic dev-webhook POST; absence of
any `POST /api/v2/emails/reply`; real production reply + human-approval gate;
correct 6-workflow runtime activation set (Full Test Harness excluded);
`finally`-block restoration; fail-closed blank-workspace preflight (4
sub-cases exercised via pwsh); `hmzReviewBasicAuth`->`httpBasicAuth`;
Instantly creds->`httpHeaderAuth`; Google Chat env wiring; no embedded
secrets; PowerShell parse checks for all 3 retained scripts; all 7 workflow
exports unchanged/inactive; rollback safe-default re-assertion; and owner
inputs completeness.

## One repair made

The targeted run first found 1 proven failure: the pre-existing
`run-release-blocker-tests.mjs` regression (33/34) - its
`blocker_d_test_allowed_http_url_covers_per_action_executors` test slices
`apply-business-ready.ps1` at a fixed line 588, which this task's earlier
credential-type-binding edit had shifted to land mid-body of
`Assert-PatchedRemoteReferences`, breaking the slice's parse. Fixed by adding
a short doc comment ahead of that function in `apply-business-ready.ps1`,
shifting its start past line 588 with no other behavioral change. After this
one repair, both suites were re-run: `run-final-operational-tests.mjs`
17/17 and `run-release-blocker-tests.mjs` 34/34 (which itself re-runs Phase
4A 42/42, Phase 4B 31/31, integration-closure 16/16, business-ready 23/23,
live-path 41/41).

## Status (unchanged)

`operating_mode=VALIDATION`, `dry_run=true`, `live_campaigns=[]`, all 7
workflows `active: false`, no credentials bound, nothing applied/imported/
activated. See `docs/NEXT_STEPS.md` for the unchanged owner-led next steps.
