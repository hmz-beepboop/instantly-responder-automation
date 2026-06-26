# Phase 4 Test Plan

Scope: the complete synthetic fixture matrix and offline test strategy for
Phase 4A (`HMZ - Instantly Reply Sender - Validation`,
`HMZ - Reply Error Handler - Validation`) and Phase 4B
(`HMZ - Reply SLA Watchdog - Validation`,
`HMZ - Reply Full Test Harness - Validation`). All fixtures are synthetic
(`synthetic: true`), exercise only deterministic local "core" modules, and
never call Instantly or use credentials.

## Fixture matrix (60 fixtures, `fixtures/phase_4/`)

| File | Group | Count | Exercises |
| --- | --- | --- | --- |
| `intake_fixtures.json` | `intake` | 23 | `classifyIntakeEvent()` (harness-core) - the deterministic intake/policy reimplementation of `docs/HMZ_APPROVED_REPLY_RULES.md` sections 3 and 5: malformed payload, unsupported event type, self-sent/auto-reply, duplicate detection, unknown campaign, empty reply, the full T1-T16 prefilter taxonomy (hard-safety, bounce/OOO, pricing/attachment, strong-signal, and free-text positive/timing/info/not-interested rules), and the AI-classifier fallback. |
| `sender_fixtures.json` | `sender` | 10 | sender-core gates, send-key derivation, acquisition/locking, suppression verification and escalation, and the `DRY_RUN_OK` terminal contract. |
| `failure_fixtures.json` | `failure` | 19 | error-core HTTP status classification (400/401/402/403/404/429 with and without `Retry-After`/500/502/503/504), pre-submission vs. ambiguous (connection-reset/timeout/malformed-2xx) failures, reconciliation (zero/multiple/repeated-single match), and the "no second POST after `SEND_UNCERTAIN`" attempt-planning rule. |
| `monitoring_fixtures.json` | `monitoring` | 8 | watchdog-core SLA evaluation (180s warning / 300s breach boundaries), Processing vs. Transmission SLO separation, sanitised alert records, placeholder-only notification routing, error-record sanitisation/truncation, and `SEND_UNCERTAIN` never being marked retryable. Two fixtures (`sidecar_resolved_exclusion`, `sidecar_alert_dedupe`) are proven against `infrastructure/send-state/state-store.mjs` directly by `run-offline-tests.mjs`, since they need the filesystem-backed sidecar store and report `skipped: true` inside the embedded (sandboxed) Code node. |

Each fixture declares a `check` (one of the `CHECKS` registry entries in
`verification/phase4b/harness-core.mjs`) and an `expected` object compared by
dot-path (`getPath`/`compareExpected`) against the actual result of running
that check against the real Phase 4A/4B core modules (`sender-core.mjs`,
`error-core.mjs`, `watchdog-core.mjs`).

## Offline test suites

- `verification/phase4a/run-offline-tests.mjs` - 38 tests covering the
  Phase 4A Sender/Error-Handler workflows and the `hmz-send-state` sidecar's
  Phase 4A endpoints.
- `verification/phase4b/run-offline-tests.mjs` - 25 tests covering:
  - the full 60-fixture matrix run directly against the core modules
    (`harness-core-fixture-matrix-all-pass`);
  - generated-workflow structural checks (valid JSON, exact names,
    `active: false`, no credentials, no secret-like literals, every
    `httpRequest` node targets only `http://hmz-send-state:5681`, no real
    notification service, hardcoded `validation_mode: true`, every Code node
    compiles standalone);
  - end-to-end runtime smoke tests of the generated SLA Watchdog and Full
    Test Harness Code-node chains;
  - watchdog classification/threshold/SLO-separation/alert-key unit tests;
  - `hmz-send-state` sidecar regression (Phase 4A acquire/lock, unfinished
    listing, resolved-error exclusion, atomic alert dedupe, Phase 4B result
    round-trip) and an end-to-end HTTP test against an ephemeral local
    instance of the server;
  - `docker compose config` host-port regression for `hmz-send-state`.

## How the two Phase 4B workflows use the matrix

- `HMZ - Reply SLA Watchdog - Validation` (workflow 05) does **not** run the
  fixture matrix; it reads live unfinished records from
  `GET http://hmz-send-state:5681/v1/unfinished`, classifies/ages them,
  builds sanitised alert candidates, deduplicates via
  `POST /v1/alert/dedupe`, and persists a sanitised `watchdog_result` via
  `POST /v1/phase4b/result`. It is triggered either by a Schedule Trigger
  (eventual, inactive) or an Execute Workflow Trigger (synthetic test entry).
- `HMZ - Reply Full Test Harness - Validation` (workflow 06) embeds the full
  60-fixture matrix as a JSON literal alongside the sender-core, error-core,
  watchdog-core, and harness-core modules, runs `runFixtureMatrix()` in a
  single Code node, and persists the sanitised `harness_result`
  (`schema_version`, `synthetic`, `total`, `passed`, `failed`,
  `overall_result`, per-fixture results) via
  `POST /v1/phase4b/result`.

## Known scope limit (recorded as a Phase 5 task)

Where a fixture would require executing the real sub-workflows 01-06 via
Execute Workflow Trigger by ID, the fixture instead exercises the equivalent
deterministic local contract (`classifyIntakeEvent()` in harness-core.mjs).
Full sub-workflow integration testing (Execute Workflow calls into
workflows 01-06 by their assigned n8n workflow IDs, after import) is
out of scope for this offline build and is recorded as a Phase 5 task.
