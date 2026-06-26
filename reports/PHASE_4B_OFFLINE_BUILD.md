# Phase 4B Offline Build Report

Scope: offline-only file generation and local deterministic testing for two
new n8n workflows - `HMZ - Reply SLA Watchdog - Validation` and
`HMZ - Reply Full Test Harness - Validation` - plus a Phase 4B extension of
the existing `hmz-send-state` sidecar. No n8n connection, no MCP, no
Instantly access, and no API key were used or requested. Phase 5 was not
started.

## Files created / modified

Infrastructure (sidecar extension, reused from Phase 4A):
- `infrastructure/send-state/state-store.mjs` (modified) - added
  `listUnfinishedSends`, `listUnresolvedErrors`, `resolveErrorRecord`,
  `recordAlertOnce` (atomic `open('wx')` alert dedupe), `writePhase4bResult`,
  `readPhase4bResult`.
- `infrastructure/send-state/server.mjs` (modified) - added routes
  `GET /v1/unfinished`, `POST /v1/alert/dedupe`,
  `POST /v1/error/:errorId/resolve`, `POST /v1/phase4b/result`,
  `GET /v1/phase4b/result/:resultId`. No host port published; existing
  Phase 4A routes/behaviour unchanged.

Workflow generation (verification):
- `verification/phase4b/watchdog-core.mjs` (new) - pure SLA Watchdog logic:
  send/error record classification into 7 watchdog categories, 180s/300s
  age thresholds, Processing vs. Transmission SLO separation, sanitised
  alert-record/alert-key construction, dedupe-result merge, and the final
  sanitised `watchdog_result`.
- `verification/phase4b/harness-core.mjs` (new) - the deterministic
  `classifyIntakeEvent()` intake/policy contract (T1-T16 prefilter taxonomy)
  plus the `CHECKS` registry, `getPath`/`compareExpected`, `runFixture`, and
  `runFixtureMatrix` used by the Full Test Harness.
- `verification/phase4b/build-workflows.mjs` (new) - deterministically
  generates both workflow JSON files from compact node definitions plus
  Code-node source embedded (via `.toString()`/custom RegExp-safe constant
  serialization) from `sender-core.mjs`, `error-core.mjs`, `watchdog-core.mjs`,
  `harness-core.mjs`, and the full fixture matrix.
- `verification/phase4b/run-offline-tests.mjs` (new) - offline test suite
  (25 tests).
- `verification/phase4b/offline-test-results.json` (generated) - latest run
  results.
- `verification/phase4b/import-phase4b.ps1` (new) - **not executed**, see
  below.

Generated workflows:
- `workflows/05_reply_sla_watchdog_validation.json` (new, generated, 14 nodes)
- `workflows/06_reply_full_test_harness_validation.json` (new, generated, 7 nodes)

Fixtures (60 total, `fixtures/phase_4/`):
- `intake_fixtures.json` (23, group `intake`, pre-existing)
- `sender_fixtures.json` (10, group `sender`, new)
- `failure_fixtures.json` (19, group `failure`, new)
- `monitoring_fixtures.json` (8, group `monitoring`, new)

Reports/docs:
- `docs/TEST_PLAN.md` (new)
- `reports/PHASE_4B_OFFLINE_BUILD.md` (this file, new)

## Architecture

`HMZ - Reply SLA Watchdog - Validation` is triggered by a Schedule Trigger
(eventual, 5-minute interval) or an Execute Workflow Trigger (synthetic test
entry); both feed a single "A. Capture Trigger Input" Code node so the rest
of the chain is trigger-agnostic. It reads `GET /v1/unfinished` from
`http://hmz-send-state:5681`, classifies every unfinished send/error record
into one of `AI_CLASSIFICATION_WAIT`, `API_RETRY`, `HUMAN_REVIEW`,
`SEND_FAILURE`, `SEND_UNCERTAIN`, `SUPPRESSION_FAILURE`, `UNKNOWN_STATE`,
compares age against 180s (`WARNING`) / 300s (`BREACH`), and splits totals
into a Processing SLO and a Transmission SLO (only `SEND_UNCERTAIN` belongs
to Transmission - every draft/queue/approval/human-review item is Processing,
never "transmitted"). Warning/breach records become sanitised alert
candidates (category + SLO type + kind + identifier + status; identifiers
are already sha256 hashes, no message bodies, no raw addresses), deduplicated
atomically via `POST /v1/alert/dedupe`, then routed only to a
`PLACEHOLDER_NOT_CONFIGURED` notification object (`delivered: false`) - no
real notification call. The final `watchdog_result`
(`validation_mode: true`) is persisted via `POST /v1/phase4b/result`.
The workflow remains `active: false`.

`HMZ - Reply Full Test Harness - Validation` is triggered by a Manual Trigger
or an Execute Workflow Trigger (synthetic test entry). A single Code node
embeds the 60-fixture matrix plus the sender-core/error-core/watchdog-core/
harness-core modules, runs `runFixtureMatrix()`, and returns a sanitised
`harness_result` (`schema_version`, `synthetic: true`, `validation_mode:
true`, `total`, `passed`, `failed`, `overall_result`, per-fixture results),
which is persisted via `POST /v1/phase4b/result`. The workflow remains
`active: false`.

## Tests run

`node verification/phase4b/run-offline-tests.mjs` - run twice: once
producing 23/25 passing (2 failed tests: the 60-fixture matrix run with 3
failing fixtures, and the harness workflow runtime smoke test with 20 failing
fixtures), and once (final) after one repair pass, producing
**25/25 passing**.

Coverage includes: the 60-fixture matrix run directly against the real core
modules; workflow JSON validity, exact names, `active: false`, no
`credentials` objects, no secret-like literal values, every `httpRequest`
node targeting only `http://hmz-send-state:5681` (no `instantly.ai`), no real
notification service references with `PLACEHOLDER_NOT_CONFIGURED`/
`delivered: false` hardcoded, hardcoded `validation_mode: true`, every Code
node compiling standalone; end-to-end runtime smoke tests of both generated
Code-node chains; watchdog category/threshold/SLO-separation/alert-key unit
tests; `hmz-send-state` Phase 4A regression (acquire/lock, forward-only state
machine) plus Phase 4B additions (unfinished listing excludes terminal
states, resolved-error exclusion, atomic alert dedupe, `phase4b/result`
round-trip); an end-to-end HTTP test against an ephemeral local instance of
the server covering `/health`, `/v1/send/acquire`, `/v1/unfinished`,
`/v1/error` (+resolve), `/v1/alert/dedupe`, and `/v1/phase4b/result`; and a
`docker compose config` regression confirming `hmz-send-state` publishes no
host port.

## One repair pass (proven defects)

Four defects were proven by the initial run and fixed in a single repair
pass:

1. `watchdog-core.mjs`'s internal `SEND_FAILURE_STATES` constant (used by
   `classifyErrorRecord`) was not exported, so the embedded Full Test Harness
   Code node threw `SEND_FAILURE_STATES is not defined` for the
   `monitoring-processing-transmission-slos-distinct` fixture. Fixed by
   exporting it and adding it to the watchdog preamble's constant list.
2. `build-workflows.mjs`'s `serializeEmbeddedConstant()` used
   `JSON.stringify()`, which turns any `RegExp` (e.g. the `re` fields inside
   harness-core's `RULES_*` arrays) into `{}`, causing every intake fixture
   to fail in the embedded harness Code node with `rule.re.test is not a
   function`. Fixed with a recursive serializer that preserves `RegExp`
   literals (`.toString()`) at any depth inside arrays/objects.
3. `fixtures/phase_4/sender_fixtures.json`'s `sender-unresolved-template-
   variable` fixture expected `terminal.details` in the order
   `["unresolved_template_variables", "live_campaigns_empty_live_send_blocked"]`,
   but `sender-core.mjs`'s `runSendGates()` pushes
   `live_campaigns_empty_live_send_blocked` before
   `unresolved_template_variables`. Fixed the fixture's expected order to
   match the real (unmodified) implementation.
4. `fixtures/phase_4/monitoring_fixtures.json`'s `monitoring-error-record-
   sanitised` and `monitoring-uncertain-send-never-retryable` fixtures used
   `expected` paths prefixed with `error_record.`, but their `CHECKS` entries
   (`error_record_sanitised`, `send_uncertain_not_retryable`) already return
   the unwrapped `error_record` object. Fixed both fixtures' expected paths
   to drop the `error_record.` prefix.

Workflows were regenerated and the full 25-test suite was re-run (final run:
25/25 passed).

## Sidecar extension safety result

PASS. `hmz-send-state`'s Phase 4B additions:
- `GET /v1/unfinished` and `GET /v1/phase4b/result/:resultId` are read-only.
- `recordAlertOnce()` records a given `alertKey` at most once via an atomic
  `open('wx')` lock; a repeated `alertKey` is reported as `deduped: true`
  with the original `firstSeenAt`.
- `writePhase4bResult()`/`readPhase4bResult()` round-trip a sanitised result
  with a 16-hex `resultId`.
- `resolveErrorRecord()` excludes a resolved record from
  `listUnresolvedErrors()`.
- No host port is published for `hmz-send-state` (`docker compose config`
  confirms this); existing Phase 4A endpoints/behaviour are unchanged and
  still pass their original regression tests.
- No credentials, API keys, `Authorization` headers, message bodies, or raw
  payloads are stored by any new endpoint.

## Workflow static safety result

PASS. Both `workflows/05_reply_sla_watchdog_validation.json` and
`workflows/06_reply_full_test_harness_validation.json`:
- Parse as valid JSON, `active: false`, no node has a `credentials` object,
  no secret-like literal values.
- Every `httpRequest` node targets only `http://hmz-send-state:5681/...`; no
  node references `instantly.ai`.
- No node references Slack/SendGrid/SMTP/Sheets/Mailgun/Twilio; the only
  notification object is `{ surface: 'PLACEHOLDER_NOT_CONFIGURED', delivered:
  false }`.
- `validation_mode: true` and `synthetic: true` are hardcoded constants in
  the generated Code nodes, not read from input.
- Every Code node's `jsCode` compiles standalone as n8n JavaScript.

## Known limitations

- The generated workflows have not been imported into or executed inside
  n8n; correctness is verified only against the embedded pure-function logic,
  an in-process ephemeral-port HTTP test of the sidecar, and static JSON
  structure.
- `hmz-send-state` has not been built or started as a Docker container in
  this session; only `docker compose config` (syntax/structure) was run.
- Where a fixture would require executing the real sub-workflows 01-06 via
  Execute Workflow Trigger by ID, it instead exercises the equivalent
  deterministic local contract (`classifyIntakeEvent()`); full sub-workflow
  integration testing after import is recorded as a Phase 5 task (see
  `docs/TEST_PLAN.md`).

## Exact import command (NOT run in this session)

```powershell
# In a PowerShell 7 session, after the local n8n + hmz-send-state stack is
# running (docker compose -f infrastructure/local-n8n/docker-compose.yml up -d)
# and HMZ_N8N_API_KEY is set for that shell only:
pwsh -File verification/phase4b/import-phase4b.ps1
```

## Verdict

**PHASE_4B_OFFLINE_READY**
