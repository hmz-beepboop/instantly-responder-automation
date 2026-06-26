# n8n Configuration

## Local n8n version

`docker.n8n.io/n8nio/n8n:2.25.7`, pinned in
`infrastructure/local-n8n/docker-compose.yml`. Do not change to `:latest` or
bump without a deliberate, documented upgrade step — all Phase 3-5 evidence
was captured against `2.25.7`.

## Docker Compose services

Defined in `infrastructure/local-n8n/docker-compose.yml`:

- **`n8n`** (`hmz-n8n-local-dev`) — bound to `127.0.0.1:5678` only (not
  reachable from the network). Volume `hmz_n8n_local_dev_data` for
  `/home/node/.n8n`. Depends on `hmz-send-state`.
- **`hmz-send-state`** — the Phase 4A internal sidecar providing durable
  atomic send-ownership and sanitised error records. No host port is
  published. Volume `hmz_send_state_data` for `/data`.

## Internal sidecar URL

`http://hmz-send-state:5681` — reachable only from other containers on the
compose network. There is no published host port for this service.
Endpoints used by the workflows and audits: `POST /v1/error`,
`POST /v1/error/:errorId/resolve`, `GET /v1/unfinished`,
`POST /v1/alert/dedupe`, `POST /v1/phase4b/result`,
`GET /v1/phase4b/result/:resultId`, plus the Phase 4A send-ownership
acquire/lock endpoints.

## Workflow import order

Import in dependency order — Reply Intake first, Full Test Harness last:

1. HMZ - Instantly Reply Intake - Validation
2. HMZ - Reply Decision Engine - Validation
3. HMZ - Instantly Reply Sender - Validation
4. HMZ - Reply Error Handler - Validation
5. HMZ - Reply SLA Watchdog - Validation
6. HMZ - Reply Full Test Harness - Validation

The IDs above (`cCcpFfi6iovWS94T`, `NJcnNQoJ5nSIWYte`, `OzYLWuCF6DoU7Iw9`,
`koyKIaY2ExF3yhx7`, `37p0OPzfDxlPvYQo`, `gu9Ede8IM5cHGtKK`) are the current
local n8n instance's workflow IDs. They are **environment-specific and not
portable** to a fresh instance. Local exports under `workflows/` retain
placeholder sub-workflow/error-workflow IDs
(`__PLACEHOLDER_DECISION_ENGINE_WORKFLOW_ID__`,
`__PLACEHOLDER_REPLY_SENDER_WORKFLOW_ID__`,
`__PLACEHOLDER_ERROR_HANDLER_WORKFLOW_ID__`); on a fresh import,
`verification/integration-closure/apply-integration-closure.ps1` discovers
each workflow by its canonical name and remaps every placeholder to the
real ID created/discovered on that instance. This script requires the
`HMZ_N8N_API_KEY` environment variable.

## No credential bindings in current exports

All six workflow exports have `credentialsBound: false`
(`verification/phase5/mechanical-audit.json`). No Instantly, Slack, email, or
other external credential is attached to any node. All HTTP Request nodes
target only `http://hmz-send-state:5681`
(`externalHttpTargets: []` for every workflow).

## Inactive-by-default requirement

All six workflows must remain `active: false`. The Phase 5 mechanical audit
recorded `active: false` for all six workflow IDs and confirmed
`localMatchesRemote: true` with `mismatches: []` for each. Activating any
workflow without re-running the relevant audit invalidates that evidence.

## Synthetic execution method

The Full Test Harness and SLA Watchdog were executed via actual n8n runtime
(CLI-driven single run against the local n8n `2.25.7` instance), not via an
active/scheduled trigger. Both produced `Execution was successful` with
exit code 0 and observed PASS/success markers
(`reports/PHASE_5_MECHANICAL_AUDIT.md`).

The Reply Sender and Error Handler have since been executed the same way as
part of the Integration Closure runtime test
(`reports/INTEGRATION_CLOSURE_RUNTIME.md`,
`verification/integration-closure/run-n8n-runtime-tests.ps1`): an approved
synthetic Sender item reached `DRY_RUN_OK` (`sent=false`,
`transport=NONE`), and a forced synthetic Error Handler item persisted a
sanitised, non-retryable `SEND_UNCERTAIN` record. Both workflows were
temporarily activated only for this run (n8n 2.x requires database-backed
sub-workflows to be active when called) and were confirmed `active: false`
again afterward. Automatic `settings.errorWorkflow` routing from a
genuinely failed parent execution remains unexercised.

## Known task-broker port conflict when invoking `n8n execute` inside a running container

n8n's Task Broker listens on `127.0.0.1:5679` inside the container. When the
main `hmz-n8n-local-dev` service is already running (and therefore already
holds the Task Broker port), invoking `n8n execute` for a CLI-driven
workflow run inside that same running container conflicts on port `5679`.

## Safe one-off-container approach used by the Phase 5 audit

The Phase 5 mechanical audit avoided this conflict by:

1. Temporarily stopping the main `hmz-n8n-local-dev` service.
2. Running the CLI-driven `n8n execute` for the target workflow (Full Test
   Harness, then SLA Watchdog) in this freed Task Broker context — observed
   output included `n8n Task Broker ready on 127.0.0.1, port 5679` and
   `Registered runner "JS Task Runner"`.
3. Restarting the main n8n service afterward and confirming it was
   API-ready again.

No workflow was activated or modified, and no live Instantly call was made
during this process.

## Phase 4B validator exception

The Phase 4B n8n-MCP static validator reports five Code-node return-shape
errors on the Phase 4B workflows (SLA Watchdog and Full Test Harness). A
read-only comparison proved the patched local exports and the remote n8n
workflow Code-node sources match exactly, and direct compile/runtime tests
pass. The Phase 4B workflows are **not** claimed `valid=true` by the n8n-MCP
validator; this is a documented static-validator limitation, and no code was
changed solely to satisfy it.
