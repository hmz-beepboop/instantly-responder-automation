# Instantly Responder Automation (Validation Stage)

## Purpose

This project implements an n8n-based automated responder for inbound Instantly
prospect replies, for HMZ's own initial US B2B validation campaign only. It
classifies replies, applies a deterministic safety prefilter and mock
semantic classifier, produces a structured action plan, manages send
ownership/idempotency through an internal sidecar, and (in later phases,
once approved) sends approved replies via the Instantly API.

## Current readiness

**System verdict: `READY_FOR_DRY_RUN`**

- This system is **not production-ready**.
- It is **not ready for unrestricted or controlled live sending yet**.
- `OPERATING_MODE=VALIDATION`
- `DRY_RUN=true`
- `LIVE_CAMPAIGNS=[]`
- No live Instantly credential is bound to any workflow.
- All six workflows below remain **inactive**.

## Six-workflow inventory

| # | Workflow | n8n Workflow ID | Nodes |
|---|---|---|---|
| 1 | HMZ - Instantly Reply Intake - Validation | `cCcpFfi6iovWS94T` | 22 |
| 2 | HMZ - Reply Decision Engine - Validation | `NJcnNQoJ5nSIWYte` | 12 |
| 3 | HMZ - Instantly Reply Sender - Validation | `OzYLWuCF6DoU7Iw9` | 21 |
| 4 | HMZ - Reply Error Handler - Validation | `koyKIaY2ExF3yhx7` | 9 |
| 5 | HMZ - Reply SLA Watchdog - Validation | `37p0OPzfDxlPvYQo` | 14 |
| 6 | HMZ - Reply Full Test Harness - Validation | `gu9Ede8IM5cHGtKK` | 7 |

These IDs belong to the current local n8n instance and are
**environment-specific, not portable** to a fresh instance. Local exports
under `workflows/` retain placeholder sub-workflow/error-workflow IDs;
`verification/integration-closure/apply-integration-closure.ps1` discovers
each workflow by canonical name on a fresh instance and remaps the
placeholders to the real IDs. Local exports of all six live under
`workflows/`.

## Architecture overview

```
Instantly reply webhook
       │
       ▼
1. Reply Intake  ──normalized event (NES)──▶ 2. Reply Decision Engine
   (auth/compensate,                            (deterministic prefilter →
    schema validate,                             mock classifier →
    idempotency via                              structured action plan)
    n8n Data Table)
       │                                              │
       ▼                                              ▼
                                          3. Reply Sender ──▶ hmz-send-state
                                             (DRY_RUN gate,    sidecar
                                              send-key, lock,  (ownership,
                                              reconciliation)   durable state,
                                                                error records,
4. Reply Error Handler ◀── sanitised errors ──        alert dedupe)
       │
       ▼
5. SLA Watchdog ──reads /v1/unfinished──▶ alerts (placeholder surface)

6. Full Test Harness ── runs the 60-fixture matrix against sender-core,
                         error-core, watchdog-core, harness-core
```

Send ownership and error persistence use the internal `hmz-send-state`
sidecar (exclusive lock-file creation + durable state files + sanitised
`/v1/error` records) — **not** a relational `sends` or `errors` table. The
implemented reconciled state is `SENT_RECONCILED`.

## Project directory map

```
workflows/                 Six n8n workflow JSON exports (inactive)
docs/                       Architecture, policy, field-map, setup docs
reports/                    Validation/audit/security/failure-mode reports
verification/               Phase 4A/4B/5 offline test suites and audit JSON
fixtures/                   Synthetic fixture matrices (phase_3, phase_4)
infrastructure/local-n8n/   docker-compose.yml (n8n + hmz-send-state)
infrastructure/send-state/  hmz-send-state sidecar source
config/                      config.example.json (validation defaults)
.env.example                 Environment variable placeholders
```

## Fastest safe installation path

1. Read `docs/SETUP_GUIDE.md` end to end first.
2. Copy `.env.example` to `.env` and `config/config.example.json` to your
   local config; keep all validation defaults (`DRY_RUN=true`,
   `LIVE_CAMPAIGNS=[]`).
3. `docker compose -f infrastructure/local-n8n/docker-compose.yml up -d`.
4. Confirm the `hmz-send-state` sidecar health endpoint responds.
5. Import the six workflows from `workflows/` in the documented order,
   leaving every one **inactive**.
6. Run the Phase 4A/4B offline test suites and the Phase 5 mechanical audit
   to reproduce the validation evidence.
7. Read `reports/VALIDATION_REPORT.md` for the final verdict before any
   further step.

## Validation evidence summary

- All six workflows: inactive, credential-free, zero external HTTP targets
  (sidecar only), remote logic matches local exports.
- Phase 4A: 42/42 offline tests passed. Phase 4B: 31/31 offline tests +
  60-fixture matrix passed. Integration Closure offline suite: 16/16 passed.
- Actual n8n runtime execution succeeded for the **Full Test Harness** and
  **SLA Watchdog** (exit 0, success markers observed).
- **Integration Closure runtime test (Phase 6) PASSED**
  (`reports/INTEGRATION_CLOSURE_RUNTIME.md`,
  `verification/integration-closure/runtime-results.json`): Intake now hands
  off to the Decision Engine and then to the Reply Sender on the accepted,
  non-duplicate path only. The normal path terminates
  `BLOCKED_PENDING_DURABLE_APPROVAL`. A separately approved synthetic Sender
  input reached `DRY_RUN_OK` (`sent=false`, `transport=NONE`), and a forced
  synthetic Error Handler entry persisted a sanitised, non-retryable
  `SEND_UNCERTAIN` record. All six workflows were returned to `active: false`
  afterward.
- Project secret/PII scan: 0 real-email hits, 0 unexpected secret-pattern
  hits.
- Instantly V1-V5 live-evidence items verified: genuine `reply_received`
  webhook, `email_id`→`reply_to_uuid` mapping, thread/subject preservation,
  `update-interest-status`, `subsequence/remove`, exact email-level
  Blocklist (workspace-wide), campaign-local ordinary unsubscribe, and one
  lost-response reconciliation (`SEND_UNCERTAIN` → `SENT_RECONCILED`).
  Controlled live API replies occurred during V3 and V5 Layer 2. The
  Instantly API base host is verified as `https://api.instantly.ai`.

## Limitations

- No durable human-approval mechanism exists yet for the Reply Sender's
  approval gate, so the normal Intake → Decision Engine → Sender path
  terminates `BLOCKED_PENDING_DURABLE_APPROVAL`.
- Automatic `settings.errorWorkflow` routing from a genuinely failed parent
  execution remains unexercised (only the synthetic Execute Workflow Trigger
  path was run).
- Zero-match and multiple-match reconciliation outcomes are policy-verified
  only, not exercised against a live Instantly response.
- The SLA Watchdog's actual n8n execution was a manual/CLI-triggered run of
  the Schedule Trigger node, not an active cron firing.
- No live reply has been sent through the n8n Reply Sender workflow.
- The Phase 4B n8n-MCP static validator reports five Code-node return-shape
  false positives on the Phase 4B workflows; documented and unresolved by
  design (remote/local source comparison and compile/runtime tests pass).

## Exact next milestone

See `docs/NEXT_STEPS.md`. In summary: design and implement a durable
human-approval mechanism for the Reply Sender's approval gate so an accepted,
non-duplicate reply can progress past `BLOCKED_PENDING_DURABLE_APPROVAL`,
while keeping `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, and all six workflows
inactive. This is required before `READY_FOR_CONTROLLED_LIVE_TEST` can be
considered.

## Not production-ready

**This system is not production-ready and is not authorised for any live or
controlled-live Instantly send.** All activation, credential-binding, and
`LIVE_CAMPAIGNS`/`DRY_RUN=false` decisions require explicit owner approval
and additional runtime evidence beyond what exists today.
