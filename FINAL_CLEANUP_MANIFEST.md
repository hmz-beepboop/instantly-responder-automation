# Final Cleanup Manifest — Instantly Responder Automation 2.7

**Purpose:** Remove redundant build artefacts, canonicalise scripts, update the
authoritative project state after the successful integration-closure runtime
test, and leave a compact active repository without changing workflow logic.

## Verified current state

- Phase 4A offline suite: 42/42 passed
- Phase 4B offline suite: 31/31 passed
- Integration-closure offline suite: 16/16 passed
- Integration-closure n8n runtime: PASS
- Real Reply Sender sub-workflow reached `DRY_RUN_OK`
- Real Error Handler synthetic entry persisted a sanitised non-retryable
  `SEND_UNCERTAIN` record
- Full Test Harness integration result: PASS
- All workflows were returned to inactive
- System readiness remains `READY_FOR_DRY_RUN`
- Controlled live and production readiness are not achieved

## Delete from the active project

These files are redundant, superseded, duplicated, or contain an unnecessary
pre-apply copy of controlled real-email data.

### Root artefacts

- `Check-Phase4B-RemotePatch.ps1`
- `INTEGRATION_CLOSURE_AUDITED_SCRIPTS.zip`
- `Instantly_Responder_Automation_INTEGRATION_CLOSURE_OFFLINE.zip`
- `PHASE_4A_AUDITED_PATCH.zip`
- `PHASE_4A_PACKAGE_AUDIT.md`
- `PHASE_4B_AUDITED_PATCH.zip`
- `PHASE_4B_VALIDATOR_FIX_PATCH.zip`
- `PHASE_5_DOCUMENTATION_CORRECTION_PATCH.zip`
- `Run-Phase5-MechanicalAudit.ps1`
- `Run-Phase5-MechanicalAudit-v2.ps1`
- `Run-Phase5-MechanicalAudit-v3.ps1`
- `Run-Phase5-RuntimeCorrection.ps1`
- `run-n8n-runtime-tests_AUDITED_v2.ps1`
- `run-n8n-runtime-tests_AUDITED_v3.ps1`

### Duplicate or superseded directories/files

- `V5_LAYER2_PRELIVE_FIXED/`
- `.claude/settings.local.json`
- `verification/phase4a/import-phase4a_FIXED.ps1`
- `verification/integration-closure/runtime-results-readable.json`
- `verification/integration-closure/preapply-backup/`
- `verification/integration-closure/run-n8n-runtime-tests_AUDITED.ps1`
- `verification/integration-closure/run-n8n-runtime-tests_AUDITED_v2.ps1`

The pre-apply backup must not remain in the active repository because it
contains a controlled real recipient address. The user's external 2.7 ZIP is
the rollback snapshot.

## Canonicalise

1. Copy the contents of:
   - `verification/integration-closure/apply-integration-closure_AUDITED.ps1`
   to:
   - `verification/integration-closure/apply-integration-closure.ps1`
   Then delete the `_AUDITED` copy.

2. Copy the contents of:
   - `verification/integration-closure/run-n8n-runtime-tests_AUDITED_v3.ps1`
   to:
   - `verification/integration-closure/run-n8n-runtime-tests.ps1`
   Fix its final terminal display so it reads the saved
   `runtime-results.json` as a `PSCustomObject` before printing nested
   `.passed` values. Do not alter test logic.
   Then delete the `_AUDITED_v3` copy.

3. Move:
   - `Run-Phase5-MechanicalAudit-v4.ps1`
   to:
   - `verification/phase5/Run-Phase5-MechanicalAudit.ps1`

4. Move:
   - `verification/phase4b/update-phase4b-validator-fix.ps1`
   to:
   - `archive/scripts-history/update-phase4b-validator-fix.ps1`

## Reorganise without deleting history

- Move `prompts/` to `archive/prompts-history/`
- Move `brainstorms/` to `archive/brainstorms/`
- Move `archive/SESSION_HANDOFF_PHASE_2_SUPERSEDED.md` to
  `archive/handoffs/SESSION_HANDOFF_PHASE_2_SUPERSEDED.md`
- Create `archive/INDEX.md` explaining that archived content is historical and
  must not be loaded unless explicitly needed.

Do not move historical evidence from `docs/` or `reports/` in this pass,
because current files still cite those paths.

## Update authoritative documentation

Update only these existing files:

- `README.md`
- `CLAUDE.md`
- `.gitignore`
- `docs/ARCHITECTURE.md`
- `docs/CURRENT_BUILD_STATE.md`
- `docs/ASSUMPTIONS_AND_UNKNOWNS.md`
- `docs/INSTANTLY_FIELD_MAP.md`
- `docs/SETUP_GUIDE.md`
- `docs/INSTANTLY_CONFIGURATION.md`
- `docs/N8N_CONFIGURATION.md`
- `docs/DEPLOYMENT_CHECKLIST.md`
- `docs/TROUBLESHOOTING.md`
- `reports/VALIDATION_REPORT.md`
- `reports/UNRESOLVED_ITEMS.md`
- `reports/SKILL_READINESS_ASSESSMENT.md`

Create:

- `PROJECT_MANIFEST.md`
- `docs/NEXT_STEPS.md`
- `reports/FINAL_CLEANUP_REPORT.md`
- `archive/INDEX.md`

## Facts the updated documents must state

- The six workflows are built and integrated.
- Current local workflow IDs are environment-specific, not portable.
- Local exports retain placeholder sub-workflow/error-workflow IDs and the
  apply script remaps them to actual IDs.
- Intake reaches Decision Engine then Sender only on the accepted,
  non-duplicate path.
- The normal Intake path terminates
  `BLOCKED_PENDING_DURABLE_APPROVAL`.
- A separately approved synthetic Sender input reached `DRY_RUN_OK` in actual
  n8n runtime with `sent=false` and `transport=NONE`.
- The Error Handler synthetic entry ran in actual n8n runtime and persisted a
  sanitised, non-retryable `SEND_UNCERTAIN` record.
- Automatic `settings.errorWorkflow` routing from a genuinely failed parent
  execution remains unexercised.
- Instantly API base host is verified as `https://api.instantly.ai`.
- Controlled live API replies occurred during V3 and V5 Layer 2.
- No live reply has been sent through the n8n Reply Sender workflow.
- State name is `SENT_RECONCILED`, never `RECONCILED_SENT`.
- Environment variable required by project scripts is
  `HMZ_N8N_API_KEY`.
- `.env.example` and `config/config.example.json` are reference templates;
  editing them does not change hardcoded workflow constants.
- Readiness remains `READY_FOR_DRY_RUN`.
- Skill verdict remains `READY_TO_DESIGN_SKILL`.
- Do not claim controlled-live or production readiness.

## CLAUDE.md correction

Replace the permanent `n8n MCP first` rule with:

> Use the lightest reliable interface. Inspect and edit local workflow JSON
> first. Prefer deterministic local tests and the n8n CLI/API for bounded
> import, retrieval and runtime checks. Use n8n MCP only for narrowly targeted
> schema questions, validation or execution inspection that cannot be done
> reliably from local files or the CLI. Never retrieve full workflows or full
> node schemas through MCP when a local export already exists.

Add:

- Do not read `archive/` unless explicitly instructed.
- One narrow objective per Claude session.
- No full-repository scan unless explicitly authorised.
- Hard cap tool calls when MCP is used.

## .gitignore additions

Ensure it includes:

- `.env`
- `.env.*`
- `!.env.example`
- `.claude/settings.local.json`
- `node_modules/`
- `tmp/`
- `*.log`
- `verification/**/preapply-backup/`
- root-level `*.zip`

Keep `.mcp.json` ignored if already present.

## Final active project layout

The active root should contain only:

- `.env.example`
- `.gitignore`
- `.mcp.json`
- `CLAUDE.md`
- `PROJECT_MANIFEST.md`
- `README.md`
- `archive/`
- `config/`
- `docs/`
- `fixtures/`
- `infrastructure/`
- `reports/`
- `sources/`
- `verification/`
- `workflows/`

No ZIP or loose temporary PowerShell file should remain in the project root.

## Verification after cleanup

Run:

1. `node verification/phase4a/run-offline-tests.mjs`
   - expected 42/42
2. `node verification/phase4b/run-offline-tests.mjs`
   - expected 31/31
3. `node verification/integration-closure/run-offline-tests.mjs`
   - expected 16/16
4. Parse every retained `.ps1` file with the PowerShell parser.
5. Parse every JSON file outside `archive/`.
6. Confirm all six workflow exports:
   - parse,
   - remain `active=false`,
   - contain no credentials,
   - contain no reachable external HTTP Request target.
7. Confirm no real email address exists outside:
   - original source DOCX files, or
   - explicitly synthetic `.test` / example fixtures.
8. Confirm no ZIP remains in the project root.
9. Confirm the project root matches the final active layout.
10. Confirm no stale phrase remains in authoritative files:
    - `RECONCILED_SENT`
    - `Instantly API base host is unconfirmed`
    - `Sender/Error Handler have no actual n8n-runtime evidence`
    - `No live Instantly send has ever occurred`

## Final report

`reports/FINAL_CLEANUP_REPORT.md` must include:

- deleted files
- moved files
- canonical scripts
- documentation corrected
- test results
- privacy/secret scan
- final root tree
- readiness verdict
- exact remaining blockers
- one exact next implementation objective
