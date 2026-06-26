# Next Steps

**Status:** `READY_FOR_DRY_RUN`. The Business-Ready Offline Build
(`reports/BUSINESS_READY_OFFLINE_BUILD.md`) and the Business-Ready Live Path
Offline Build (`reports/BUSINESS_READY_LIVE_PATH_OFFLINE_BUILD.md`) are both
complete. Controlled-live and production readiness are **not** approved.
`DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, all 7 workflows `active: false`, no
credentials bound, no workflow applied or imported to any live n8n instance,
and the new 14-gate live-send evaluation (workflow 03 node O) and security
gate (workflow 01 node F1) both fail closed with the shipped empty
allowlists/launch profile.

## What changed in the Final Controlled-Live Orchestration Fix (this session)

`run-controlled-live-acceptance.ps1` was rewritten: `-AllowOneControlledReply`
(synthetic dev-webhook send) is replaced by `-RunControlledLiveReply`, a real,
supervised, production-path run (see step 9 below) with a fail-closed
workspace preflight (a blank/missing campaign `workspace_id` now blocks).
`apply-business-ready.ps1` now binds `hmzInstantlyApi`/
`hmzInstantlyWebhookToken` as `httpHeaderAuth` and `hmzReviewBasicAuth` as
`httpBasicAuth` (via `HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID`), independently of
the Instantly credential map. `rollback-business-ready.ps1` now also accepts
`hmzReviewBasicAuth` in backups and re-asserts
`operating_mode=VALIDATION`/`live_credential_readiness.*=false` on rollback.
`infrastructure/business-live/docker-compose.yml` and `.env.example` now pass
`GOOGLE_CHAT_WEBHOOK_URL` into the n8n container (no workflow JSON change; no
separate `hmzGoogleChatWebhook` credential required). See
`reports/BUSINESS_READY_FINAL_OPERATIONAL_FIX.md`.

## What changed in the Live Path Offline Build (this session)

Workflow 03 gained a real, gated `POST /api/v2/emails/reply` adapter with
retry/classification/reconciliation (nodes O-X2), reachable only if all 14
`LAUNCH_PROFILE`/`ALLOWLISTS` gates pass. Workflow 01 gained a real
production webhook (`instantly-reply`, header-auth) with a security/allowlist
gate (F1-F3). Workflow 02 gained real, gated suppression adapters (G-G6),
disabled by default via `config.suppression_action_enablement.*`. Workflow
07 gained an advisory reviewer-identity-allowlist check (M1).
`config/business-ready.config.json` gained `launch_profile`, `allowlists`,
`reviewer_allowlist`, and `live_credential_readiness.instantly`. All new HTTP
nodes use `credentialPlaceholder` (`hmzInstantlyApi` /
`hmzInstantlyWebhookToken`), never a real `credentials` object.
`apply-business-ready.ps1` now resolves these placeholders only if
`live_credential_readiness.instantly=true` and the owner supplies credential
IDs; `run-controlled-live-acceptance.ps1` now supports `-PreflightOnly`
(default, read-only) and `-AllowOneControlledReply` (one gated, confirmed,
non-retried real reply); `rollback-business-ready.ps1` restores config safe
defaults in addition to the 7 workflows. New fixtures live under
`fixtures/business_ready_live_path/`. Covered by
`verification/business-ready/run-live-path-offline-tests.mjs` (41/41) plus
the pre-existing 23/23 + 89/89 regressions.

## What changed in the Release-Blocker Correction pass (this session)

Eight release-blocking contract/acceptance defects (A-H) identified by an
independent audit were corrected, offline only:

- **A/B (workflow 03):** R now classifies an HTTP 2xx send as `SENT` only
  when the response body is a valid Email object (`id`, `message_id`,
  `thread_id` all non-empty); otherwise `SEND_UNCERTAIN`. X2 carries
  `email_id`/`message_id`/`thread_id` into `terminal`. V/W reconcile via a
  real `GET /api/v2/emails` poll with the documented query-param contract and
  local filtering.
- **C (workflow 02):** the suppression chain is now per-action
  (`SOURCE_CAMPAIGN_STOP`, `UPDATE_INTEREST_STATUS`, `SUBSEQUENCE_REMOVAL`,
  `EXACT_EMAIL_BLOCKLIST`), each gated individually by
  `config.suppression_action_enablement.*` (all `false` by default), with a
  canonical-lead retrieval step (G0) and a blocklist-verification step (G5)
  added.
- **D:** `apply-business-ready.ps1` re-embeds
  `config.launch_profile`/`allowlists`/`reviewer_allowlist`/`suppression_action_enablement`
  verbatim into the HMZ_INJECT-marked constants and re-verifies them after
  applying; `Test-AllowedHttpUrl` now also recognises the new per-action
  executor URLs.
- **E:** `run-controlled-live-acceptance.ps1 -AllowOneControlledReply` now
  performs the single controlled reply by invoking the real n8n Reply Sender
  workflow via the Intake workflow's dev webhook
  (`hmz-validation-reply-intake-dev`) and reading the Sender's `terminal.*`
  result - it never POSTs `/api/v2/emails/reply` directly.
- **F (workflow 01):** F1 fails closed for `PRODUCTION_WEBHOOK` entries when
  `ALLOWLISTS` is empty; campaign/sender allowlisting are now conditional on
  workspace allowlisting, so a missing `workspace_id` alone blocks all three.
- **G (workflow 07):** the production review-form/submit webhooks now
  require Basic Auth (`hmzReviewBasicAuth`); the reviewer-identity allowlist
  (M1) is fail-closed (`allowlisted=false`, never `null`, when unconfigured)
  and a new M2/M2b router hard-rejects non-allowlisted reviewers
  (`REVIEWER_NOT_ALLOWLISTED`) instead of letting them proceed.
- **H:** `run-local-runtime-acceptance.ps1` additionally activates the SLA
  Watchdog and, in the same isolated/stopped-n8n window, runs standalone
  `n8n execute` against the Error Handler's real Error Trigger and the SLA
  Watchdog's real Schedule Trigger, then restores all four temporarily-active
  workflows to inactive in `finally`.

Covered by the new `verification/business-ready/run-release-blocker-tests.mjs`
(34/34), with Phase 4A 42/42, Phase 4B 31/31, integration-closure 16/16,
business-ready 23/23, and prior live-path 41/41 all re-checked with corrected
(non-stale) assertions. See
`reports/BUSINESS_READY_RELEASE_BLOCKER_FIX.md`.

## What changed since Phase 6

The durable human-approval mechanism that Phase 6 identified as missing is
now built: `workflows/07_reply_human_approval_validation.json` (Human
Approval), wired into Intake (01) and the Reply Sender (03). The Decision
Engine (02) now uses a deterministic, honestly-named classifier with a
non-English fallback, and a Safety Action Plan node independent of the
approval gate. The Reply Sender (03) adapter now models all 6 real
Instantly V2 endpoints (still unreachable in validation). All of this is
covered by `verification/business-ready/run-offline-tests.mjs` (23/23).

## Exact next steps (owner-led, out of band)

These are **not** scripted and must be done deliberately by the project
owner, in order:

1. **Complete `BUSINESS_READY_OWNER_INPUTS.md`.** Every `<REQUIRED_*>`
   value (reviewer identity, Google Chat space + webhook, review base
   URL + token TTL, sender mapping, workspace/campaign allowlists,
   retention periods, hosting domain) must be filled in. None of these are
   guessed by this build.
2. **Fill in `config.allowlists` and `config.reviewer_allowlist`** in
   `config/business-ready.config.json` (workspace ID, the one controlled
   live campaign ID, connected sender eaccounts, reviewer identities) and
   set `config.launch_profile.required_operating_mode =
   "SUPERVISED_VALIDATION"` to match `config.operating_mode` - both are the
   first of the 14 gates evaluated by workflow 03 node O.
3. **Pre-create the "Review Cases" Data Table** in the target n8n instance
   and note its ID for `$env:HMZ_REVIEW_CASES_DATA_TABLE_ID`.
4. **Bind credentials in the n8n UI only** (never in a file, script, or
   chat): `hmzInstantlyApi`, `hmzInstantlyWebhookToken`,
   `hmzGoogleChatWebhook`, `hmzN8nApi`. Update
   `config.live_credential_readiness.*` accordingly. Only set
   `live_credential_readiness.instantly = true` once both
   `hmzInstantlyApi` and `hmzInstantlyWebhookToken` are bound and their
   credential IDs are available for
   `$env:HMZ_INSTANTLY_API_CREDENTIAL_ID` /
   `$env:HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID`.
5. **Run `verification/business-ready/apply-business-ready.ps1`** against
   the target n8n instance (local dev or `infrastructure/business-live/`).
   This patches the 7 workflows' placeholder IDs, resolves
   `credentialPlaceholder` nodes only if step 4's flag/IDs are set, leaves
   all 7 `active: false`, and backs up their pre-patch state.
6. **Run `verification/business-ready/run-local-runtime-acceptance.ps1`**
   to confirm errorWorkflow mappings, sub-workflow handoffs, and the Full
   Test Harness pass against the applied workflows.
7. **Set `config.live_credential_readiness.ready_for_controlled_live_test
   = true`** only once the owner has reviewed the above, then run
   `verification/business-ready/run-controlled-live-acceptance.ps1`
   (default `-PreflightOnly`, read-only - confirms Instantly reachability
   and the designated controlled-live campaign/workspace).
8. **Manually activate the 7 workflows** in the n8n UI, in the order in
   `docs/DEPLOYMENT_CHECKLIST.md` / `docs/ROLLBACK_GUIDE.md`, with
   `DRY_RUN=true` still set. The 14-gate evaluation in workflow 03 still
   blocks every live send while `dry_run=true` and `live_campaigns=[]`.
9. **Perform one manual, supervised, production-path controlled-live reply**
   by running `run-controlled-live-acceptance.ps1 -RunControlledLiveReply
   -ConfirmationPhrase "RUN-ONE-CONTROLLED-REPLY"` with every
   `HMZ_CONTROLLED_LIVE_*`, `HMZ_*_CREDENTIAL_ID`,
   `HMZ_REVIEW_CASES_DATA_TABLE_ID`, `HMZ_N8N_PUBLIC_URL`,
   `HMZ_REVIEW_PUBLIC_BASE_URL`, and `HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL`
   environment variable set per `BUSINESS_READY_OWNER_INPUTS.md`. This
   script: verifies the public HTTPS n8n/review/production-webhook URLs are
   reachable; backs up `config/business-ready.config.json` and all 7 remote
   workflow bodies; temporarily sets
   `operating_mode=SUPERVISED_VALIDATION`/`dry_run=false`/`live_campaigns=[the
   one designated campaign]`/the credential-readiness flags and re-runs
   `apply-business-ready.ps1` to re-embed those constants and bind
   `hmzInstantlyApi`/`hmzInstantlyWebhookToken` (httpHeaderAuth) and
   `hmzReviewBasicAuth` (httpBasicAuth); temporarily activates the 6 runtime
   workflows (Intake, Decision Engine, Reply Sender, Error Handler, Human
   Approval, SLA Watchdog - the Full Test Harness is never activated); prints
   a unique marker and the exact owned test lead/campaign and waits for the
   operator to send a real reply, open the production Human Approval review
   page, edit the draft to include the marker, and approve it exactly once;
   then polls n8n's executions API for the Reply Sender's
   `terminal.send_state`/`email_id`/`message_id`/`thread_id` and Instantly's
   `GET /api/v2/emails` to independently confirm exactly one outbound Email
   object (correct sender/recipient/thread/subject/marker, empty CC/BCC, no
   duplicate after a 60-second window). It never POSTs
   `/api/v2/emails/reply` and never performs a second send, including on
   `SEND_UNCERTAIN` (reconciliation reads only). Its `finally` block
   deactivates all 6 temporarily-activated workflows, restores
   `config/business-ready.config.json` from the pre-run backup (re-asserting
   `operating_mode=VALIDATION`/`dry_run=true`/`live_campaigns=[]` if the
   backup is unavailable), reruns `apply-business-ready.ps1` against the
   restored safe config, and clears every secret/controlled-live environment
   variable. Review the result directly in Instantly.
10. Only after a reviewed, successful result does the owner decide whether
    to flip `DRY_RUN=false` for the designated campaign(s) and/or populate
    `LIVE_CAMPAIGNS` and the 14-gate `LAUNCH_PROFILE`/`ALLOWLISTS` constants
    in workflow 03 node O / workflow 01 node F1 - a manual decision with no
    automated unattended path.

If hosting is required, deploy `infrastructure/business-live/` per its
README before step 4 (or use `infrastructure/local-n8n/` for steps 4-6 and
defer hosting until step 7).

## Out of scope (unchanged)

- Any `DRY_RUN=false` change or `LIVE_CAMPAIGNS` entry without the
  owner-led steps above.
- PROVEN mode / unattended auto-send - not implemented anywhere in this
  repository and not planned without its own separately-reviewed design.
- Automatic `settings.errorWorkflow` routing from a genuinely failed parent
  execution (only the synthetic Execute Workflow Trigger path into the
  Error Handler has been exercised).
- Zero-match / multiple-match reconciliation live exercises.
- SLA Watchdog active/scheduled (cron) firing.
- Creating an Instantly-specific Skill (`CLAUDE.md` Notes).
