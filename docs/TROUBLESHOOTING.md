# Troubleshooting

## Task broker port 5679 conflict

**Symptom:** `n8n execute <workflowId>` fails or hangs with a port-binding
error around `127.0.0.1:5679` while the main n8n service is running.

**Cause:** n8n's Task Broker already occupies port `5679` inside the running
`hmz-n8n-local-dev` container.

**Resolution:** temporarily stop the main n8n service, run the CLI-driven
execution (this frees the Task Broker port for the CLI process), then
restart the main service and confirm it is API-ready again — the approach
used by the Phase 5 mechanical audit. Do not change the published port
mapping to work around this.

## Script execution-policy block

**Symptom:** a PowerShell script fails with "running scripts is disabled on
this system" or similar.

**Resolution:** this is a local PowerShell execution-policy restriction, not
a project defect. Run the specific script with an explicit bypass for that
invocation only (e.g. `powershell -ExecutionPolicy Bypass -File <script>`)
rather than changing the system-wide policy, and confirm with the operator
before changing any persistent policy setting.

## Missing downloaded file

**Symptom:** a referenced fixture, export, or report file is missing.

**Resolution:** re-check the expected path against the directory map in
`README.md`. Do not regenerate evidence reports or workflow exports by hand
— missing files under `reports/`, `workflows/`, or `verification/` indicate
an incomplete checkout or an out-of-scope deletion and should be restored
from version control, not recreated.

## API-key environment missing

**Symptom:** a tool expects `INSTANTLY_API_KEY` or `N8N_API_KEY` and finds it
unset.

**Resolution:** expected during validation. `INSTANTLY_API_KEY` is
deliberately unused while `DRY_RUN=true` and `LIVE_CAMPAIGNS=[]`. `N8N_API_KEY`
is only needed for audit/validator tooling — generate it from the local n8n
owner account if a specific audit step requires it.

## `HMZ_N8N_API_KEY` not set

**Symptom:**
`verification/integration-closure/apply-integration-closure.ps1` or
`verification/integration-closure/run-n8n-runtime-tests.ps1` throws
"`HMZ_N8N_API_KEY` is not set in this PowerShell process."

**Resolution:** expected — both scripts require `HMZ_N8N_API_KEY` to be set
in the current PowerShell session before running, and both clear it in a
`finally` block on exit. Set it only for the duration of the run; do not
persist it in a file or profile. Neither script is part of routine setup —
see `docs/NEXT_STEPS.md` for when they apply.

## Docker service unavailable

**Symptom:** `docker compose ... up -d` fails, or `n8n`/`hmz-send-state`
containers do not start.

**Resolution:** confirm Docker Desktop/Engine is running. Check
`docker compose -f infrastructure/local-n8n/docker-compose.yml ps` and
container logs. Do not delete named volumes (`hmz_n8n_local_dev_data`,
`hmz_send_state_data`) to "fix" a startup issue — they hold the local n8n
owner account and sidecar durable state.

## Sidecar health failure

**Symptom:** the `hmz-send-state` health check does not return healthy.

**Resolution:** confirm the `hmz-send-state` container is running and on the
same compose network as `n8n`. It has no published host port — health checks
must run from inside the compose network or via the same offline test
harness used in `verification/phase4b/run-offline-tests.mjs`. Do not expose
a host port to "fix" this.

## Duplicate workflow names

**Symptom:** import fails or two workflows share a name in the n8n UI.

**Resolution:** the six canonical names are listed in
`docs/N8N_CONFIGURATION.md` and `README.md`. If a duplicate exists from a
prior import attempt, remove the duplicate (not the canonical one) before
re-importing, and re-run the local-vs-remote comparison to confirm
`localMatchesRemote: true` for the canonical workflow.

## n8n-MCP validator false positive

**Symptom:** `n8n_validate_workflow` reports Code-node return-shape errors on
the Phase 4B workflows (SLA Watchdog, Full Test Harness), or "Invalid $
usage detected" / "Missing onError: 'continueErrorOutput'" warnings on
Phase 3 workflows.

**Resolution:** these are documented, investigated false positives
(`reports/PHASE_5_MECHANICAL_AUDIT.md` known limitations;
`reports/UNRESOLVED_ITEMS.md` U5/U6). Do not modify Code-node source or IF-node
`onError` settings solely to silence these — remote/local source comparison
and compile/runtime tests already confirm correct behaviour.

## `SEND_UNCERTAIN`

**Symptom:** a send record is left in `SEND_UNCERTAIN` (e.g. after a
post-submission timeout or malformed successful response).

**Resolution:** this is expected, correct behaviour — `SEND_UNCERTAIN` is
never blindly retried. The record must be reconciled (read-only check
against Instantly Email objects). Do not manually re-trigger a send for a
`SEND_UNCERTAIN` record.

## Zero/multiple reconciliation matches

**Symptom:** reconciliation for a `SEND_UNCERTAIN` record finds zero or more
than one matching Email object.

**Resolution:** per `docs/STATE_AND_IDEMPOTENCY.md` §7, transition to
`HUMAN_REVIEW_ZERO_MATCHES` or `HUMAN_REVIEW_MULTIPLE_MATCHES` respectively.
Never issue a second `POST`. These paths are policy-verified but not yet
live-exercised against Instantly — escalate to human review per policy.

## Workflow remains inactive

**Symptom:** a workflow you expect to run does nothing because it is
inactive.

**Resolution:** this is the required state for all six workflows during
validation. Use a manual/CLI-driven execution (as done for the Full Test
Harness and SLA Watchdog) for synthetic testing — do not activate the
workflow to "make it run."

## Report or export mismatch

**Symptom:** `localMatchesRemote: false`, a node-count mismatch, or a
workflow export under `workflows/` does not match what is in the audit
reports.

**Resolution:** treat this as a blocker — do not proceed past it. Re-run the
relevant comparison from `reports/PHASE_5_MECHANICAL_AUDIT.md` and resolve
the discrepancy (re-export or re-import as appropriate) before continuing
any setup or testing step.
