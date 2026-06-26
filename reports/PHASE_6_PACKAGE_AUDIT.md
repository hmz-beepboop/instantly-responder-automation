# Phase 6 Package Audit

**Date:** 2026-06-14  
**Package reviewed:** `Instantly_Responder_Automation_2.6.zip`

## Executive verdict

`PHASE_6_DOCUMENTS_CREATED_BUT_SYSTEM_CLOSURE_FAILED`

The 11 requested Phase 6 operator files exist, the configuration JSON parses,
the Phase 4A suite still passes 42/42, and the Phase 4B suite still passes
31/31.

However, the repository is not a completed end-to-end dry-run responder.
The current `READY_FOR_DRY_RUN` verdict is defensible only for isolated
components, not for the six-workflow system as a whole.

**System-level readiness should remain `NOT_READY` until the integration
closure items below are implemented and runtime-tested.**

## What passed

- All 11 Phase 6 files exist.
- `config/config.example.json` is valid JSON.
- No real email address, token, API key, or Bearer value was found in the
  Phase 6 output files.
- Phase 4A: 42/42 tests passed.
- Phase 4B: 31/31 tests passed.
- Phase 6 consistently warns that the system is not production-ready and
  must not send live replies.
- `READY_TO_DESIGN_SKILL` is acceptable as a design-only verdict; the Skill
  must not be built yet.

## Critical implementation gaps

### 1. No Decision Engine to Sender orchestration

The only Execute Sub-workflow call in Reply Intake targets the Decision Engine.

There is no Execute Sub-workflow call from:

- Reply Intake to Reply Sender, or
- Reply Decision Engine to Reply Sender.

Therefore, an accepted inbound event finishes after the Decision Engine and
never reaches the Sender, even in DRY_RUN mode.

### 2. Error Handler is not attached to the other workflows

None of the applicable workflow `settings` objects identifies
`HMZ - Reply Error Handler - Validation` as the error workflow.

The Error Handler exists as a standalone workflow, but workflow failures are
not automatically routed to it.

### 3. Full Test Harness does not exercise the real Sender or Error Handler

The Full Test Harness runs the embedded deterministic fixture/core matrix. It
does not contain Execute Sub-workflow nodes targeting:

- Reply Sender
- Reply Error Handler

Phase 5 therefore proved the harness workflow itself can run, but not that the
real Sender and Error Handler execute correctly inside n8n.

### 4. Fresh-import instructions can break the existing sub-workflow link

The Intake export contains the current-instance Decision Engine ID:

`NJcnNQoJ5nSIWYte`

Execute Sub-workflow references target a workflow ID. A fresh import may
create different IDs. The operator documentation:

- lists current-instance IDs as though they are portable,
- imports Intake before Decision Engine, despite Intake depending on it,
- does not require remapping and validating the Execute Sub-workflow target.

A fresh installation can therefore import successfully but have a broken
handoff.

### 5. Environment-variable names do not match the implemented tools

The current tools and project MCP configuration use:

- `HMZ_N8N_API_KEY`
- `N8N_API_URL` inside `.mcp.json`

The new `.env.example` and Setup Guide instead document:

- `N8N_API_KEY`
- `N8N_BASE_URL`

Using the new documentation literally will not satisfy the import, update,
mechanical-audit, or MCP configuration scripts.

### 6. `.env` and `config.example.json` are not runtime configuration sources

The workflows currently hardcode:

- `OPERATING_MODE=VALIDATION`
- `DRY_RUN=true`
- `LIVE_CAMPAIGNS=[]`
- `LIVE_CREDENTIAL_READY=false`

The Docker Compose file does not consume the Phase 6 `.env` values for these
workflow constants, and the workflow Code nodes do not read
`config/config.example.json`.

The files are reference templates only. The Setup Guide currently implies
that copying/editing them configures the workflows.

### 7. Instantly API host status is stale

The repository's live V3 and V5 tests and the Sender adapter contract used:

`https://api.instantly.ai`

Official Instantly API documentation also uses that host.

The following Phase 6 statements are stale:

- `INSTANTLY_API_BASE=<...unconfirmed>`
- "Confirm the Instantly API base host"
- Skill assessment claims the base host is unconfirmed

### 8. Skill assessment incorrectly says no live Instantly send occurred

Controlled live API replies occurred during:

- V3 thread-preserving reply verification
- V5 Layer 2 lost-response/reconciliation verification

What remains untested is a live send **through the n8n Reply Sender
workflow**, not every live Instantly send.

### 9. Authoritative project documents remain stale

Examples:

- `docs/ARCHITECTURE.md` still says workflows were not built, storage is
  deferred, and no Instantly call occurred.
- `docs/CURRENT_BUILD_STATE.md` begins with Phase 5 status but later says the
  watchdog/error/test workflows are not built and the next task is Phase 4.
- `docs/ASSUMPTIONS_AND_UNKNOWNS.md` still calls the API host provisional,
  uses the obsolete `RECONCILED_SENT` state, and says storage is not chosen.
- `docs/INSTANTLY_FIELD_MAP.md` still labels the API host unknown.

These files can mislead future Claude sessions and operators despite the new
README being more accurate.

## Readiness correction

### Component-level

The individual deterministic cores, sidecar, Watchdog and Test Harness have
strong validation evidence.

### System-level

Until orchestration and error routing are implemented and exercised:

`NOT_READY`

The next milestone is not a controlled live test. It is a complete
end-to-end synthetic n8n dry-run:

```text
Synthetic Intake
→ Decision Engine
→ Reply Sender
→ DRY_RUN_OK
```

plus a forced synthetic failure routed automatically to the Error Handler.

## Smallest safe closure path

1. Build one offline integration patch with no MCP:
   - connect Decision Engine output to Sender,
   - attach Error Handler to applicable workflows,
   - add an actual Sender/Error Handler integration test path,
   - create ID-safe install/update scripts,
   - correct the documentation defects above.

2. Audit the patch locally.

3. Update the six inactive workflows.

4. Execute one actual n8n synthetic end-to-end dry-run and one forced-error
   run.

5. Rerun the Phase 5 mechanical/security audit.

6. Regenerate only the affected final reports and operator documents.

No Instantly credential or live call is required for this closure.
