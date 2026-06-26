# Setup Guide — Validation Stage

This guide reproduces the current `READY_FOR_DRY_RUN` validation
environment. It does not enable any live send. Follow the steps in order.

## 1. Prerequisites

- Docker Desktop (or equivalent Docker Engine + Compose v2).
- A working directory with this repository checked out.
- No Instantly API key is required for any step in this guide.
- PowerShell or a POSIX shell for running Docker Compose commands.

## 2. Safe folder preparation

- Copy `.env.example` to `.env`. Do not put real secrets in `.env` while
  `DRY_RUN=true` and `LIVE_CAMPAIGNS=[]` — the `INSTANTLY_API_KEY` placeholder
  must remain unset/unused.
- Copy `config/config.example.json` to your local config location, keeping
  `operating_mode: VALIDATION`, `dry_run: true`, `live_campaigns: []`, and
  `live_credential_readiness.ready_for_controlled_live_test: false`.

## 3. Environment variables

Set the variables documented in `.env.example`:

- `N8N_BASE_URL` — local n8n URL (bound to `127.0.0.1:5678`).
- `N8N_API_KEY` — only needed for audit/validator tooling; leave blank
  until you generate one from the local n8n owner account.
- `OPERATING_MODE=VALIDATION`, `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]` — do not
  change these.
- `HMZ_SEND_STATE_URL=http://hmz-send-state:5681` — internal sidecar URL,
  not published to the host.

## 4. Docker Compose startup

From the repository root:

```
docker compose -f infrastructure/local-n8n/docker-compose.yml up -d
```

This starts:

- `hmz-n8n-local-dev` — n8n `2.25.7`, bound to `127.0.0.1:5678` only.
- `hmz-send-state` — the internal sidecar, reachable only on the compose
  network at `http://hmz-send-state:5681` (no published host port).

On first start, open `http://localhost:5678` and create the local n8n owner
account manually. Do not paste the owner password or any API key into chat
or into this repository.

## 5. Sidecar health check

Confirm `hmz-send-state` is healthy before importing workflows. The Phase 5
mechanical audit's sidecar-health check (`Sidecar health exit: 0`,
`Sidecar healthy: True`) is the reference result — reproduce it via the
same offline/health check used by `verification/phase4b/run-offline-tests.mjs`
rather than inventing a new check.

## 6. Workflow import order

Import the six exports from `workflows/` in this order (intake first,
dependencies before dependents):

1. `01_reply_intake_validation.json`
2. `02_reply_decision_engine_validation.json`
3. `03_reply_sender_validation.json`
4. `04_reply_error_handler_validation.json`
5. `05_reply_sla_watchdog_validation.json`
6. `06_reply_full_test_harness_validation.json`

(Use the actual filenames present under `workflows/`; the order above
matches the dependency order Intake → Decision Engine → Sender → Error
Handler → SLA Watchdog → Full Test Harness.)

## 7. Workflow IDs/names

| # | Name | ID |
|---|---|---|
| 1 | HMZ - Instantly Reply Intake - Validation | `cCcpFfi6iovWS94T` |
| 2 | HMZ - Reply Decision Engine - Validation | `NJcnNQoJ5nSIWYte` |
| 3 | HMZ - Instantly Reply Sender - Validation | `OzYLWuCF6DoU7Iw9` |
| 4 | HMZ - Reply Error Handler - Validation | `koyKIaY2ExF3yhx7` |
| 5 | HMZ - Reply SLA Watchdog - Validation | `37p0OPzfDxlPvYQo` |
| 6 | HMZ - Reply Full Test Harness - Validation | `gu9Ede8IM5cHGtKK` |

## 8. Keeping every workflow inactive

After import, verify each workflow shows `active: false`. Do not activate
any of the six workflows during validation. All Phase 5 evidence assumes
`active: false` for all six; activating any workflow invalidates that
evidence until re-audited.

## 9. Running Phase 4A/4B offline tests

```
node verification/phase4a/run-offline-tests.mjs
node verification/phase4b/run-offline-tests.mjs
```

Expected: Phase 4A 42/42 pass, Phase 4B 31/31 pass plus the embedded
60-fixture matrix (`fixtures/phase_4/`) all pass. These never call Instantly
and never require credentials.

## 10. Running the Phase 5 mechanical audit

Reproduce the checks recorded in `reports/PHASE_5_MECHANICAL_AUDIT.md`:
workflow active/inactive + local-vs-remote comparison, Phase 4A/4B suites,
sidecar health, actual n8n execution of the Full Test Harness and SLA
Watchdog, n8n security audit, and the project secret/PII scan. The main n8n
service may need to be temporarily stopped during CLI execution to avoid the
task-broker port conflict (see `docs/N8N_CONFIGURATION.md` and
`docs/TROUBLESHOOTING.md`), then restarted and confirmed API-ready
afterward.

## 11. Reading the final verdict

Read `reports/VALIDATION_REPORT.md` for the authoritative verdict
(`READY_FOR_DRY_RUN`), `reports/SECURITY_AUDIT.md` and
`reports/FAILURE_MODE_AUDIT.md` for supporting findings, and
`reports/UNRESOLVED_ITEMS.md` for open items. Do not treat any other status
string as authoritative.

## 12. Integration closure runtime evidence (Phase 6, complete)

The Reply Sender and Error Handler now have actual n8n-runtime execution
evidence with synthetic inputs, gathered via the Integration Closure runtime
test (`reports/INTEGRATION_CLOSURE_RUNTIME.md`,
`verification/integration-closure/run-n8n-runtime-tests.ps1`,
`verification/integration-closure/runtime-results.json`). This script
requires `HMZ_N8N_API_KEY` to be set in the PowerShell process and is not
re-run by routine setup — see `docs/NEXT_STEPS.md` for what comes next.

## 13. Before a controlled live test

Do not proceed past this guide toward a controlled live test until:

- A durable human-approval mechanism exists for the Reply Sender's approval
  gate (the normal Intake → Decision Engine → Sender path currently
  terminates `BLOCKED_PENDING_DURABLE_APPROVAL`; see `docs/NEXT_STEPS.md`).
- `DRY_RUN=true` and `LIVE_CAMPAIGNS=[]` remain unchanged.
- An owner-approved, narrowly scoped Instantly API key is provisioned and
  bound only after the above mechanism exists.
- The full pre-send gate (`docs/HMZ_APPROVED_REPLY_RULES.md` §9.1) is met
  for any candidate `LIVE_CAMPAIGNS` entry.
