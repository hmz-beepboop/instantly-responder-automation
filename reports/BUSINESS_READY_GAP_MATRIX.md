# Business-Ready Gap Matrix

This matrix maps each required deliverable for the supervised VALIDATION
live profile to its current status. "DONE" means the offline artifact
exists and is covered by `verification/business-ready/run-offline-tests.mjs`
(23/23 PASS). "OPEN (owner input)" means the artifact is generic and
configuration-driven, and is blocked only on a value in
`BUSINESS_READY_OWNER_INPUTS.md` that was deliberately not guessed.

## A. Workflow content

| Item | Status | Evidence |
| --- | --- | --- |
| 7 import-ready inactive workflow exports | DONE | `workflows/01..07_*.json`, all `active: false`; `workflows_parse`, `workflows_inactive`, `workflow_names_canonical` |
| No bound credentials in any export | DONE | `no_credentials` |
| Deterministic (honestly-named) classifier replacing mock | DONE | `workflows/02...json` node B "B. Deterministic Reply Classifier", `classifier_version: deterministic-heuristic-1.0`; `no_mock_classifier_remnants` |
| Non-English reply -> T15 fallback per policy-HMZ-1.2 §15 | DONE | `non_english_reply_routes_to_t15` |
| Real (gated/unreachable) Instantly V2 adapter, 6 endpoints | DONE | `workflows/03...json` node N `additional_contracts`; `live_adapter_additional_contracts` |
| Safety-action execution separated from reply-approval gates | DONE | `workflows/02...json` node F; `safety_action_plan_pre_approval_independent` |
| Durable human-approval mechanism (prior session) | DONE | `workflows/07...json`; `review_token_lifecycle`, `reviewer_decision_approve_edit_identity_deny_blocked`, `approval_gate_passes_via_human_approval_handoff` |
| Fixed-template booking-link block + HUMAN_ONLY editable draft | DONE | `fixed_template_booking_link_blocks_and_human_only_editable` |
| Idempotent review-case IDs | DONE | `review_case_id_idempotent` |
| Approval handoff field mapping / intake routing | DONE | `approval_handoff_field_mapping_and_intake_routing` |
| Gated Google Chat notifications (04/05/07) | DONE (wiring); OPEN (credential) | `gated_google_chat_notifications`; webhook credential `hmzGoogleChatWebhook` not bound - `BUSINESS_READY_OWNER_INPUTS.md` §2 |
| Layered webhook protection | DONE | `config.business-ready.config.json` `webhook_protection.*` (shared-secret header, campaign/sender allowlist, rate limit, dedupe window) |
| Data Table placeholder consistency (workflow 07) | DONE | `workflow07_data_table_placeholder_consistent` |
| All embedded Code nodes syntactically valid | DONE | `embedded_code_nodes_compile` |

## B. Configuration

| Item | Status | Evidence |
| --- | --- | --- |
| Durable non-secret config source | DONE | `config/business-ready.config.json`; `config_safe_defaults` |
| `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]` | DONE | `config_safe_defaults` |
| All suppression-action live gates `false` | DONE | `config.suppression_action_enablement.*` |
| `.env.example` corrected | DONE | `.env.example` |
| Workspace allowlist / sender mapping / live campaigns | OPEN (owner input) | `BUSINESS_READY_OWNER_INPUTS.md` §4-5 - placeholders `<REQUIRED_WORKSPACE_ID>`, `<REQUIRED_SENDER_EACCOUNT_1>`, etc. |
| Review base URL / token TTL | OPEN (owner input) | `BUSINESS_READY_OWNER_INPUTS.md` §3 |
| Retention periods | OPEN (owner input) | `BUSINESS_READY_OWNER_INPUTS.md` §8 |
| Credential binding (`hmzInstantlyApi`, `hmzGoogleChatWebhook`, `hmzN8nApi`) | OPEN (owner action, out of band) | `BUSINESS_READY_OWNER_INPUTS.md` §6; `config.live_credential_readiness.*` all `false` |

## C. Apply / acceptance / rollback automation

| Item | Status | Evidence |
| --- | --- | --- |
| Apply script (offline-gated, fail-closed) | DONE (created, not executed) | `verification/business-ready/apply-business-ready.ps1`; `powershell_scripts_present_and_fail_closed` |
| Local runtime acceptance script | DONE (created, not executed) | `verification/business-ready/run-local-runtime-acceptance.ps1` |
| Controlled-live acceptance script (read-only) | DONE (created, not executed) | `verification/business-ready/run-controlled-live-acceptance.ps1` |
| Rollback script | DONE (created, not executed) | `verification/business-ready/rollback-business-ready.ps1` |
| Review Cases Data Table pre-created by owner | OPEN (owner action, out of band) | `$env:HMZ_REVIEW_CASES_DATA_TABLE_ID` required by apply script |

## D. Offline test suite

| Item | Status | Evidence |
| --- | --- | --- |
| New business-ready offline suite | DONE - 23/23 PASS | `verification/business-ready/run-offline-tests.mjs`, `offline-test-results.json` |
| Regression: phase4a | DONE - 42/42 PASS | `regression_phase4a` |
| Regression: phase4b | DONE - 31/31 PASS | `regression_phase4b` |
| Regression: integration-closure | DONE - 16/16 PASS | `regression_integration_closure` |

## E. Hosting infrastructure

| Item | Status | Evidence |
| --- | --- | --- |
| Compose stack (n8n + sidecar + HTTPS reverse proxy) | DONE (offline-built, not deployed) | `infrastructure/business-live/docker-compose.yml`, `Caddyfile` |
| Persistent named volumes, health checks, restart policies | DONE | `infrastructure/business-live/docker-compose.yml` |
| Sample env file (placeholders only) | DONE | `infrastructure/business-live/.env.example` |
| Backup / restore scripts | DONE | `infrastructure/business-live/backup-business-live.ps1`, `restore-business-live.ps1` |
| No public sidecar port | DONE | `infrastructure/business-live/docker-compose.yml` - `hmz-send-state` has no `ports:` entry |
| Deployment / activation / rollback instructions | DONE | `infrastructure/business-live/README.md` |
| Actual deployment (DNS, host, TLS issuance) | OPEN (owner action, out of band) | `BUSINESS_READY_OWNER_INPUTS.md` §10 |

## F. PROVEN mode / unattended auto-send

| Item | Status | Evidence |
| --- | --- | --- |
| PROVEN mode / unattended auto-send | NOT IMPLEMENTED (by design, explicitly out of scope) | `run-controlled-live-acceptance.ps1` header + body; `powershell_scripts_present_and_fail_closed` |

## G. Documentation

| Item | Status | Evidence |
| --- | --- | --- |
| Owner inputs reference | DONE (prior session; still INCOMPLETE pending owner) | `BUSINESS_READY_OWNER_INPUTS.md` |
| Build/offline-build report | DONE | `reports/BUSINESS_READY_OFFLINE_BUILD.md` |
| Gap matrix (this file) | DONE | `reports/BUSINESS_READY_GAP_MATRIX.md` |
| Hosting deployment/rollback docs | DONE | `infrastructure/business-live/README.md` |
| Current build state / next steps updated | DONE | `docs/CURRENT_BUILD_STATE.md`, `docs/NEXT_STEPS.md` |

## H. Live path (this session)

| Item | Status | Evidence |
| --- | --- | --- |
| 14-gate live-send evaluation (workflow 03 node O) | DONE | `gate_evaluation_empty_input_all_blocked`, `gate_evaluation_ideal_context_still_blocked_on_launch_profile`, `p2_blocked_terminal_shape` |
| Real gated `POST /api/v2/emails/reply` adapter + retry/classify/reconcile (nodes Q-X2) | DONE | `q_node_real_gated_reply_adapter`, `r_classifies_*`, `reconciliation_*`, `retry_and_reconciliation_loops_bounded` |
| Real production webhook (`instantly-reply`, header-auth) + security/allowlist gate (F1-F3) | DONE | `production_webhook_present`, `entry_source_tagging`, `security_gate_*` |
| Real gated suppression adapters (G2-G6), disabled by default | DONE | `suppression_adapters_present_and_gated`, `suppression_router_*`, `g6_idempotency_key_deterministic` |
| Reviewer-identity allowlist check (M1, advisory) | DONE | `reviewer_allowlist_check_present_and_wired`, `reviewer_decision_logic_unchanged_by_m1` |
| `config.launch_profile`, `config.allowlists`, `config.reviewer_allowlist`, `live_credential_readiness.instantly` | DONE | `config_live_path_additions` |
| Apply script: allow `api.instantly.ai`, resolve `credentialPlaceholder` (gated) | DONE | `apply_script_allows_instantly_and_webhook_credentials` |
| Controlled-live acceptance: `-PreflightOnly` / `-AllowOneControlledReply` | DONE | `controlled_live_acceptance_two_modes` |
| Rollback restores config safe defaults (`dry_run=true`, `live_campaigns=[]`) in addition to 7 workflows | DONE | manual review; not separately unit-tested |
| Error-routing / SLA-watchdog acceptance fixtures | DONE | `fixtures/business_ready_live_path/`; `live_path_fixtures_present` |
| Live-path offline suite | DONE - 41/41 PASS | `verification/business-ready/run-live-path-offline-tests.mjs`, `live-path-offline-results.json` |
| Allowlists/launch profile values, Instantly credential binding, single controlled reply | OPEN (owner input / action, out of band) | `config.allowlists`, `config.reviewer_allowlist`, `live_credential_readiness.instantly` all placeholders/false |

**Deviation note:** `verification/business-ready/run-offline-tests.mjs`
(test `gated_google_chat_notifications`),
`verification/phase4a/run-offline-tests.mjs` (`wf-no-live-instantly-request`,
`wf-live-instantly-only-in-contract-string`), and
`verification/integration-closure/run-offline-tests.mjs`
(`no_external_http_targets`) were updated to recognise the new gated,
currently-unreachable `https://api.instantly.ai/*` adapter nodes
(`credentialPlaceholder: "hmzInstantlyApi"`, `onError:
"continueRegularOutput"`) as expected rather than disallowed HTTP targets.
This was the minimal honest fix for the intentional architectural change
from string-only contracts to real, gated HTTP adapters; all three
regression suites remain at their original totals (42/42, 31/31, 16/16).

## I. Release-blocker corrections (A-H, this session)

| Blocker | Item | Status | Evidence |
| --- | --- | --- | --- |
| A | Reply-success classification requires a valid Email object `{id, message_id, thread_id}`; non-conforming 2xx is `SEND_UNCERTAIN` | DONE | `blocker_a_*` |
| B | Reconciliation via `GET /api/v2/emails` with `search/eaccount/lead/email_type=sent/min_timestamp_created/max_timestamp_created/preview_only=false/limit` + local filtering | DONE | `blocker_b_*` |
| C | Per-action suppression plan/execution (`SOURCE_CAMPAIGN_STOP`, `UPDATE_INTEREST_STATUS`, `SUBSEQUENCE_REMOVAL`, `EXACT_EMAIL_BLOCKLIST`), each individually gated by `suppression_action_enablement.*`, G0-G6 fully connected | DONE | `blocker_c_*` |
| D | `apply-business-ready.ps1` treats `config/business-ready.config.json` as the single source of truth (HMZ_INJECT markers for LAUNCH_PROFILE/ALLOWLISTS/REVIEWER_ALLOWLIST/SUPPRESSION_ACTION_ENABLEMENT), fails closed on incomplete owner inputs, and recognises the new per-action executor URLs | DONE | `blocker_d_*` |
| E | `run-controlled-live-acceptance.ps1` invokes the real send path via n8n (Intake dev webhook -> Sender workflow terminal), never POSTs `/api/v2/emails/reply` directly | DONE | `blocker_e_*` |
| F | Production security/allowlist gate (F1) fails closed: empty `ALLOWLISTS` always rejects, and campaign/sender allowlisting depend on workspace allowlisting | DONE | `blocker_f_*` |
| G | Reviewer review-form/submit webhooks require Basic Auth (`hmzReviewBasicAuth`); reviewer-identity allowlist (M1/M2/M2b) fails closed and hard-rejects non-allowlisted reviewers | DONE | `blocker_g_*` |
| H | Local runtime acceptance exercises the real Error Trigger and Schedule Trigger entry nodes in an isolated activation window, restoring all workflows to inactive afterwards | DONE | `blocker_h_*` |

Regression chain after A-H: Phase 4A 42/42, Phase 4B 31/31,
integration-closure 16/16, business-ready 23/23, prior live-path 41/41 (all
re-checked with corrected, non-stale assertions), plus the new
release-blocker suite 34/34. See
`verification/business-ready/release-blocker-results.json` and
`reports/BUSINESS_READY_RELEASE_BLOCKER_FIX.md`.

## Summary

All offline-buildable deliverables for the supervised VALIDATION live
profile, the live-path components in section H, and the release-blocker
corrections A-H in section I are complete and pass their offline tests
(23/23 + 41/41 + 34/34, plus 89/89 across the Phase 4A/4B/integration-closure
regression suites). The remaining open items are exclusively owner-supplied
values (`BUSINESS_READY_OWNER_INPUTS.md`, `config.allowlists`,
`config.reviewer_allowlist`) and owner-performed, out-of-band actions
(credential binding via the n8n UI, Data Table creation, DNS/hosting
deployment, and the single manual controlled-live reply) - none of which
were guessed, simulated, or partially stubbed in a way that would
misrepresent readiness.

## Verdict

BUSINESS_READY_OFFLINE_READY (base) /
BUSINESS_READY_LIVE_PATH_OFFLINE_READY (live-path additions; see
`reports/BUSINESS_READY_LIVE_PATH_OFFLINE_BUILD.md`) /
BUSINESS_READY_RELEASE_BLOCKERS_CLEARED (this session's A-H corrections; see
`reports/BUSINESS_READY_RELEASE_BLOCKER_FIX.md`)
