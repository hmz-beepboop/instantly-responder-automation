# Project Manifest — Instantly Responder Automation

**System verdict: `READY_FOR_DRY_RUN`.** Controlled-live and production
readiness are **not** approved. `OPERATING_MODE=VALIDATION`, `DRY_RUN=true`,
`LIVE_CAMPAIGNS=[]`, all six workflows `active: false`.

This file is the map of the active repository after the final cleanup pass
(`reports/FINAL_CLEANUP_REPORT.md`). For agent rules, see `CLAUDE.md`. For
the system overview, see `README.md`. For the exact next implementation
objective, see `docs/NEXT_STEPS.md`.

## Root layout

- `.env.example` — environment variable placeholders (reference template;
  editing it does not change hardcoded workflow constants).
- `.gitignore`
- `.mcp.json` — n8n MCP configuration (kept ignored).
- `CLAUDE.md` — agent workflow rules.
- `PROJECT_MANIFEST.md` — this file.
- `README.md` — system overview, six-workflow inventory, validation evidence.
- `archive/` — historical material only; see `archive/INDEX.md`. Do not load
  unless explicitly instructed.
- `config/` — `config.example.json` (reference template, validation
  defaults).
- `docs/` — architecture, policy, configuration, setup, troubleshooting,
  and `NEXT_STEPS.md`.
- `fixtures/` — synthetic fixture matrices (phase_3, phase_4,
  integration_closure).
- `infrastructure/` — `local-n8n/docker-compose.yml` (n8n + hmz-send-state)
  and the `hmz-send-state` sidecar source.
- `reports/` — validation/audit/security/failure-mode/closure reports
  (historical evidence; not reorganised by this pass).
- `sources/` — original business source documents (`*.docx`, unchanged).
- `verification/` — Phase 4A/4B/5/Integration-Closure offline test suites,
  audit JSON, and the canonical apply/runtime scripts.
- `workflows/` — six n8n workflow JSON exports (all `active: false`).

## Canonical scripts (verification/integration-closure/)

- `apply-integration-closure.ps1` — discovers the six workflows by canonical
  name on an n8n instance, creates any missing ones in dependency order,
  patches the three workflow-ID placeholders to real IDs, and PUTs the
  patched bodies back. Requires `HMZ_N8N_API_KEY`. Not executed by routine
  setup.
- `run-n8n-runtime-tests.ps1` — runs the Integration Closure runtime test
  (temporarily activates only the Reply Sender and Error Handler, executes
  the Full Test Harness, restores inactive state, writes
  `runtime-results.json` and `reports/INTEGRATION_CLOSURE_RUNTIME.md`).
  Requires `HMZ_N8N_API_KEY`. Not re-run by routine setup — see
  `docs/NEXT_STEPS.md`.
- `build-integration.mjs` / `run-offline-tests.mjs` — offline build and the
  16-test Integration Closure offline suite (no network, no n8n).

## Six workflows

See `README.md` "Six-workflow inventory" and `docs/N8N_CONFIGURATION.md`.
Current local workflow IDs are environment-specific, not portable. Local
exports retain placeholder sub-workflow/error-workflow IDs; a fresh import is
remapped by `apply-integration-closure.ps1`.

## Latest verified state

- Phase 4A offline suite: 42/42 passed.
- Phase 4B offline suite: 31/31 passed.
- Integration-closure offline suite: 16/16 passed.
- Integration-closure n8n runtime: PASS
  (`reports/INTEGRATION_CLOSURE_RUNTIME.md`,
  `verification/integration-closure/runtime-results.json`).
- Real Reply Sender sub-workflow reached `DRY_RUN_OK` (`sent=false`,
  `transport=NONE`) for an approved synthetic item.
- Real Error Handler synthetic entry persisted a sanitised, non-retryable
  `SEND_UNCERTAIN` record.
- The normal Intake → Decision Engine → Sender path terminates
  `BLOCKED_PENDING_DURABLE_APPROVAL`.
- Automatic `settings.errorWorkflow` routing from a genuinely failed parent
  execution remains unexercised.
- Instantly API base host verified as `https://api.instantly.ai`.
- Controlled live API replies occurred during V3 and V5 Layer 2. No live
  reply has been sent through the n8n Reply Sender workflow.
- All workflows were returned to inactive.
- Skill verdict: `READY_TO_DESIGN_SKILL` (`reports/SKILL_READINESS_ASSESSMENT.md`).
  No Skill has been created.

## Exact next implementation objective

See `docs/NEXT_STEPS.md`: design and implement a durable human-approval
mechanism for the Reply Sender's approval gate.
