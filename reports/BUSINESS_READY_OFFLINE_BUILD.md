# Business-Ready Offline Build Report

Scope: a single offline build session converting the validation-only
framework (7 inactive `... - Validation` workflows, durable human-approval
mechanism from the prior session) into an **import-ready supervised
VALIDATION live profile**. No n8n/MCP/Docker/Instantly connection was made,
no credential was requested, handled, or bound, no workflow was activated,
`DRY_RUN` remains `true`, and `LIVE_CAMPAIGNS` remains `[]` throughout. No
PROVEN mode / unattended auto-send exists anywhere in this repository.

## Entry gate

`BUSINESS_READY_OWNER_INPUTS.md` (created in a prior session) lists every
missing owner input as `<REQUIRED_*>`. None were guessed. All such values
remain placeholders in `config/business-ready.config.json` and
`.env.example`. The full list of outstanding owner inputs is in
`reports/BUSINESS_READY_GAP_MATRIX.md`.

## Files created or modified this session

### Workflow content (durable-approval-aware classifier, adapter, safety actions)

- `workflows/02_reply_decision_engine_validation.json`
  - Node B renamed from a mock classifier to
    **"B. Deterministic Reply Classifier"**, `classifier.model` /
    `classifier_version` = `deterministic-heuristic-1.0`,
    `decision_trace.path` distinguishes `DETERMINISTIC_RULE`,
    `OPERATIONAL_NOOP`, `NON_ENGLISH_FALLBACK_T15`, and
    `DETERMINISTIC_HEURISTIC_CLASSIFIER`. Non-English replies
    (`reply.language` not `en`/`eng`/`en-*`) are routed to
    `AMBIGUOUS`/confidence `0.3` per policy-HMZ-1.2 §15 instead of being
    fed to the English-only keyword heuristics.
  - New node **"F. Safety Action Plan (Gated Contract, Pre-Approval)"**
    computes the required suppression actions (`STOP_ACTIVE_SEQUENCE`,
    `UPDATE_INTEREST_STATUS`, `ADD_TO_BLOCKLIST`) independently of the
    reply-approval gate, with `execution_order: BEFORE_REPLY_APPROVAL_GATE`,
    each action `enabled: false` /
    `verification_status: SUPPRESSION_ACTION_DISABLED_BY_CONFIG` and a
    `request_contract` describing the real Instantly V2 call that would be
    made once `config.suppression_action_enablement.*` is separately
    enabled. This makes explicit that safety actions (T7/T12/T13) are
    decided and gated independently of whether a reply is approved.
  - Sticky note for Section B rewritten to describe the deterministic
    heuristic classifier honestly (previously described a "mock semantic
    classifier" with `model: "mock"`, which no longer matched the
    implementation after the prior session's rename).
  - All other node names/logic from the prior session unchanged.

- `workflows/03_reply_sender_validation.json`
  - Node **"N. Live Adapter Contract (Validation-Only, Unreachable)"**
    extended with `additional_contracts`: `update_interest_status`,
    `remove_subsequence`, `add_to_blocklist`, `get_email`, `list_emails` -
    the real Instantly V2 endpoints from
    `config.instantly_api.endpoints`, each with `method`/`url`/sanitised
    `body_shape`, alongside the existing `reply_to_email` contract.
    `terminal.reason` remains
    `LIVE_ADAPTER_UNREACHABLE_IN_VALIDATION` - no HTTP call is made.

(Workflows 01, 04, 05, 06, 07 were built in the prior session and are
unchanged this session except as covered by regression tests.)

### Configuration

- `config/business-ready.config.json` (prior session, validated this
  session) - single durable, non-secret configuration source:
  `dry_run: true`, `live_campaigns: []`, `classifier_version:
  deterministic-heuristic-1.0`, `suppression_action_enablement.*: false`,
  `review.google_chat_configured: false`,
  `live_credential_readiness.*: false`, `instantly_api.endpoints` (the 6
  real V2 endpoints used by node N's contracts), `webhook_protection`
  (shared-secret header, campaign/sender allowlist requirements, rate
  limit, dedupe window), `workflow_inventory` mapping each canonical
  workflow name to its export file.
- `.env.example` (prior session, validated this session) - corrected
  placeholders for `HMZ_N8N_API_KEY`, `INSTANTLY_API_KEY` (unused while
  `DRY_RUN=true`), `HMZ_SEND_STATE_URL`, `REVIEW_BASE_URL`,
  `GOOGLE_CHAT_WEBHOOK_URL`, `HMZ_INSTANTLY_WEBHOOK_TOKEN`.

### Apply / acceptance / rollback scripts (created, NOT executed)

- `verification/business-ready/apply-business-ready.ps1` - patches all 7
  exports' placeholder workflow IDs / Data Table ID / Google Chat
  expression against a live n8n instance, requires
  `$env:HMZ_N8N_API_KEY` and `$env:HMZ_REVIEW_CASES_DATA_TABLE_ID`, asserts
  an offline gate (`offline-test-results.json` PASS +
  `BUSINESS_READY_OFFLINE_READY`/`_PARTIAL` marker in this report), backs
  up the pre-patch workflow bodies, and leaves all 7 workflows `active:
  false`.
- `verification/business-ready/run-local-runtime-acceptance.ps1` -
  runtime checks against a local n8n: errorWorkflow mappings, Intake ->
  Decision Engine / Human Approval handoffs, Human Approval -> Reply
  Sender handoff, and a Full Test Harness execution reaching
  `overall_result: PASS`.
- `verification/business-ready/run-controlled-live-acceptance.ps1` -
  **read-only** pre-flight (GET-only): confirms the 7 workflows are
  present/inactive on local n8n, `GET /api/v2/campaigns` is reachable with
  the provided Instantly key, the owner-designated controlled-live
  campaign exists and its workspace is allow-listed. Never sends a reply,
  never changes `DRY_RUN`, never populates `LIVE_CAMPAIGNS`, never
  activates a workflow. Explicitly documents that PROVEN mode /
  unattended auto-send is out of scope and not implemented.
- `verification/business-ready/rollback-business-ready.ps1` - restores the
  7 workflows' `{name, nodes, connections, settings}` from the
  apply-script's pre-patch backup and ensures all 7 remain `active: false`.

### Offline test suite

- `verification/business-ready/run-offline-tests.mjs` (new, pure Node.js
  built-ins, no network, no n8n) - 23 tests covering: workflow validity/
  inactivity/naming/no-credentials; absence of mock-classifier remnants and
  presence of the deterministic heuristic classifier; non-English ->
  `AMBIGUOUS`/`NON_ENGLISH_FALLBACK_T15` routing; the safety-action plan's
  independence from the approval gate (gated, unexecuted contracts); the
  live adapter's 5 additional Instantly V2 contracts; the Reply Sender's
  approval gate blocking without a durable approval record and passing via
  the Human Approval handoff (exact Q-node field mapping, including the
  reviewer-edited draft text); the full review-token lifecycle
  (not-found/wrong-token/expired/already-decided/valid one-time token);
  reviewer approve/deny/blocked-missing-variables decisions with identity
  and edited-text persistence; fixed-template booking-link blocking vs.
  HUMAN_ONLY editable drafts; idempotent `case_id` hashing; static
  field-mapping/routing checks (Q node, Intake's Human Approval handoff);
  gated Google Chat notification wiring across workflows 04/05/07; Data
  Table placeholder consistency across workflow 07's 5 Data Table nodes;
  Code-node syntax validity across all 7 workflows; `config/business-
  ready.config.json` safe defaults; and presence/fail-closed-marker checks
  for all 4 PowerShell scripts. Also re-runs the phase4a (42/42), phase4b
  (31/31), and integration-closure (16/16) offline suites as regressions.

### Hosting infrastructure (offline-built, not deployed)

- `infrastructure/business-live/docker-compose.yml` - separate compose
  project from `infrastructure/local-n8n/`: pinned `n8n:2.25.7` (bound to
  `127.0.0.1:5678` only), `hmz-send-state` (built from
  `infrastructure/send-state`, no published port), and a `caddy:2-alpine`
  reverse proxy (the only publicly reachable component, 80/443, automatic
  Let's Encrypt TLS for `${N8N_HOST}`). Named volumes for n8n data, sidecar
  data, and Caddy's certificate store. `restart: unless-stopped` and health
  checks on all three services.
- `infrastructure/business-live/Caddyfile` - HTTPS reverse proxy to
  `n8n:5678` with HSTS/`X-Content-Type-Options`/`X-Frame-Options` headers.
- `infrastructure/business-live/.env.example` - placeholders for
  `N8N_HOST`, `ACME_EMAIL`, `N8N_ENCRYPTION_KEY`, `GENERIC_TIMEZONE`.
- `infrastructure/business-live/backup-business-live.ps1` /
  `restore-business-live.ps1` - tar-based backup/restore of the two named
  volumes via short-lived `alpine` containers; restore requires `-Confirm`
  and refuses if a volume is in use.
- `infrastructure/business-live/README.md` - deployment steps, the
  end-to-end activation order (apply -> local runtime acceptance ->
  controlled-live read-only pre-flight -> owner credential binding via n8n
  UI only -> manual activation -> manual controlled-live send -> owner
  decision on `DRY_RUN`), monitoring, backup/retention, rollback, and an
  explicit statement that PROVEN mode is not implemented at this or any
  layer.

### Project hygiene

- `.gitignore` - added `infrastructure/business-live/backups/`.

## Tests run

`node verification/business-ready/run-offline-tests.mjs`:

- **Initial run**: 22/23 passed, 1 failed -
  `no_mock_classifier_remnants` (workflow 02's Section B sticky note still
  said "Mock Semantic Classifier" / referenced `mockSemanticClassify` /
  `model: "mock"`, a documentation remnant from before the prior session's
  classifier rename; the Code node itself was already correct).
- **One repair pass**: rewrote the Section B sticky note
  (`workflows/02_reply_decision_engine_validation.json`) to describe the
  deterministic heuristic classifier (`deterministicHeuristicClassify`,
  `model: "deterministic-heuristic-1.0"`) without any mock-classifier
  naming. No code-node logic was changed.
- **Final run**: **23/23 passed, 0 failed**, including all three regression
  suites (phase4a 42/42, phase4b 31/31, integration-closure 16/16).

Results: `verification/business-ready/offline-test-results.json`
(`overall_result: "PASS"`, `total: 23`, `passed: 23`, `failed: 0`).

## What remains before any live action

See `reports/BUSINESS_READY_GAP_MATRIX.md` for the full table. In summary:
every `<REQUIRED_*>` value in `BUSINESS_READY_OWNER_INPUTS.md` is still
unfilled (reviewer identity, Google Chat space, review base URL, sender
mapping, workspace/campaign allowlists, credential binding, retention
periods, hosting domain). `config.live_credential_readiness.*` and
`config.suppression_action_enablement.*` are all `false`,
`review.google_chat_configured` is `false`, and
`owner_inputs_status` is `INCOMPLETE`. All of this is by design per the
entry gate - the offline build is generic and configuration-driven, and
none of these values were guessed.

## Verdict

BUSINESS_READY_OFFLINE_READY
