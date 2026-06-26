# Claude Usage Guardrails

**Last updated:** 2026-06-22
**Purpose:** Rules every Claude session must follow before touching this project.

## 1. Production Target — Always

- All n8n operations target `https://n8n.hmzaiautomation.com/api/v1`
- Run `scripts/assert-hmz-production-target.ps1` before any n8n operation
- See `docs/HMZ_PRODUCTION_TARGET_GUARD.md` for full guard policy

## 2. Banned Unless User Explicitly Says "local dev"

- `localhost` or `127.0.0.1` as n8n target
- Docker Desktop, docker-compose, any docker command
- Container name `hmz-n8n-local-dev`
- Path `infrastructure/local-n8n`
- Scripts `run-local-*`, `run-n8n-runtime-tests.ps1`, any script setting `$N8nUrl = "http://127.0.0.1:5678"`

## 3. n8n-MCP Restrictions

**Do not use n8n-mcp for:**
- Retrieving full workflow JSON (use local exports or REST API)
- Simple REST read-only tasks (health check, list workflows, get execution)
- Any operation performable via `Invoke-RestMethod` against the production API

**Allowed n8n-mcp uses (narrow):**
- Schema validation questions that cannot be answered from local files
- Node configuration lookups not covered by local docs
- Targeted execution inspection when REST response is insufficient

**Why:** MCP calls for read-only tasks bloat context unnecessarily and slow sessions.

## 4. No Production Changes Without Approval

- Never patch, activate, deactivate, or modify production workflows without explicit user instruction
- WhatIf before Apply for all production workflow changes, except explicitly approved mechanical applies
- FullTestHarness (`RLUcJHQJPvLhw4mG`) must remain INACTIVE unless explicitly testing
- Autonomous sending must not be enabled without explicit human approval

## 5. No Sends, Deletions, or Secrets

- No real Instantly send/reply API calls
- No Sender workflow triggers
- No deletion of workflows, credentials, backups, or exports
- No secrets in files, exports, logs, or chat

## 6. Scope Discipline

- Do not touch `archive/` unless explicitly instructed
- Do not run full-repository scans unless explicitly authorised
- One narrow objective per session
- Hard cap MCP tool calls when MCP is used

## 7. Source of Truth Hierarchy

1. `docs/SOURCE_PRIORITY.md` — business facts and strategy
2. `docs/HMZ_APPROVED_REPLY_RULES.md` — approved reply policy
3. `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` — approved runtime facts (absent = UNKNOWN → escalate)
4. Local workflow JSON exports — architecture and implementation

Never invent business claims, API fields, pricing, proof, results, or case studies.
