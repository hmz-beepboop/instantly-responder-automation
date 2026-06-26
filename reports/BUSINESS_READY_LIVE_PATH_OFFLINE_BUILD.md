# Business-Ready Live Path - Offline Build

**Generated:** 2026-06-15
**Scope:** Offline build only. No n8n/Docker/Instantly/MCP/credential access,
no workflow activation, no sends. `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`
throughout.

## Verdict

BUSINESS_READY_LIVE_PATH_OFFLINE_READY

## Files changed

- `verification/business-ready/build-live-path.mjs` (new, idempotent build script, executed once)
- `workflows/01_reply_intake_validation.json` - real production webhook (`instantly-reply`, header-auth) + security/allowlist gate (A0/A0/F1/F2/F3)
- `workflows/02_reply_decision_engine_validation.json` - gated suppression adapters (G/G2-G6)
- `workflows/03_reply_sender_validation.json` - 17 new nodes (O-X2): 14-gate live-send evaluation, gated reply adapter, retry/classification, reconciliation
- `workflows/07_reply_human_approval_validation.json` - M1 reviewer-identity allowlist check (advisory)
- `config/business-ready.config.json` - `launch_profile`, `allowlists`, `reviewer_allowlist`, `live_credential_readiness.instantly`, `webhook_protection.production_path="instantly-reply"`, rate-limit endpoint
- `.env.example` - explanatory comments for `hmzInstantlyApi`/`hmzInstantlyWebhookToken` and the production webhook path
- `verification/business-ready/run-live-path-offline-tests.mjs` (new, 41/41 PASS) and `live-path-offline-results.json` (new, `overall_result: PASS`)
- `verification/business-ready/apply-business-ready.ps1` - allows `https://api.instantly.ai` for gated adapters, resolves `credentialPlaceholder` -> real credentials only when `live_credential_readiness.instantly=true`, requires the live-path offline gate
- `verification/business-ready/run-controlled-live-acceptance.ps1` - replaced with `-PreflightOnly` (default, read-only) and `-AllowOneControlledReply -ConfirmationPhrase "RUN-ONE-CONTROLLED-REPLY"` (one gated, non-retried reply)
- `verification/business-ready/rollback-business-ready.ps1` - restores `config.dry_run=true`/`live_campaigns=[]` plus the 7 workflows
- `fixtures/business_ready_live_path/` (new: `error_routing_acceptance.json`, `sla_watchdog_acceptance.json`)
- `reports/BUSINESS_READY_GAP_MATRIX.md`, `docs/NEXT_STEPS.md` updated

**Deviation:** `run-offline-tests.mjs`, `verification/phase4a/run-offline-tests.mjs`,
and `verification/integration-closure/run-offline-tests.mjs` were updated to
recognise the new gated `https://api.instantly.ai/*` adapter nodes
(`credentialPlaceholder: "hmzInstantlyApi"`, `onError:
"continueRegularOutput"`) as expected, since these were intentionally added
real adapters (previously string-only contracts). All three regressions
remain at original totals (42/42, 31/31, 16/16).

## Live reply / suppression / webhook / approval / notification paths

- **Reply:** N -> O (14 gates) -> P -> Q (`POST /api/v2/emails/reply`, gated) -> R (classify) -> S/T (bounded retry, max 3) -> U -> X/X2 (SENT) or U2/U3 (failure) or V/W/W2/W3/W4 (reconciliation, max 2 polls).
- **Suppression:** F -> G (router) -> G2-G4 (STOP/UPDATE/BLOCKLIST, gated) -> G5 (verify) -> G6 (idempotent result), only if any `suppression_action_enablement.*` is true (all false by default).
- **Webhook:** new `instantly-reply` production webhook -> A0 (tag) -> A -> ... -> F -> F1 (security/allowlist gate, fails closed on empty allowlists) -> F2 -> G/F3.
- **Approval:** unchanged decision logic; M1 adds advisory reviewer-identity-allowlist metadata only.
- **Notification:** unchanged gated Google Chat wiring, now also covers the new adapter URLs via the updated `gated_google_chat_notifications` test.

## Safety defaults (unchanged/verified)

`DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, all 7 workflows `active:false`, no
`credentials` field anywhere (7 new `credentialPlaceholder` nodes only),
all 14 gates fail by default, suppression/security gates fail closed, no
PROVEN mode, no unattended auto-send.

## Tests

`run-live-path-offline-tests.mjs`: 41/41 PASS (one initial run found 5
failures - two incorrect test assertions, two PS1 scripts, fixtures
directory - all fixed; final run 41/41). `run-offline-tests.mjs` regression:
23/23 PASS.

## Remaining owner inputs / exact next action

Per `docs/NEXT_STEPS.md`: fill `config.allowlists`/`reviewer_allowlist`,
bind `hmzInstantlyApi`/`hmzInstantlyWebhookToken`, then run
`apply-business-ready.ps1` -> `run-local-runtime-acceptance.ps1` ->
`run-controlled-live-acceptance.ps1 -PreflightOnly` -> (owner-supervised)
`-AllowOneControlledReply`. No further action in this offline session.
