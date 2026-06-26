# HMZ Production Target Guard

## Active production target

| Field | Value |
|-------|-------|
| Environment | PRODUCTION_CLOUD_N8N |
| n8n API base URL | `https://n8n.hmzaiautomation.com/api/v1` |
| n8n UI | `https://n8n.hmzaiautomation.com` |
| Hosting | VPS / cloud (not Docker Desktop, not localhost) |

This is the **only** n8n target for all production responder work. Established: 2026-06-21.

---

## What is forbidden without explicit "local dev" instruction

| Forbidden term | Reason |
|----------------|--------|
| `localhost` / `127.0.0.1` | Local Docker port — not the production VPS |
| `hmz-n8n-local-dev` | Local Docker container name |
| `infrastructure/local-n8n` | Local Docker Compose setup |
| Docker Desktop / `docker-compose` | Local environment only |
| Any script setting `$N8nUrl = "http://127.0.0.1:5678"` | Targets local n8n, not VPS |

---

## Scripts marked LOCAL DEV ONLY

The following scripts target the local Docker n8n instance and **must not** be used for production VPS responder checks:

| Script | Reason |
|--------|--------|
| `verification/integration-closure/run-n8n-runtime-tests.ps1` | Sets `$N8nUrl = "http://127.0.0.1:5678"` and uses `infrastructure/local-n8n/docker-compose.yml` |
| `verification/business-ready/run-local-runtime-acceptance.ps1` | Verifies against a local n8n instance |
| `verification/v5/layer2/Run-V5Layer2.ps1` | Layer 2 tests designed for local environment |

---

## How to assert the correct target

Run before any n8n operation:

```powershell
.\scripts\assert-hmz-production-target.ps1
```

---

## Trigger conditions for this guard

A Claude Code session must consult this file **before** any of the following:

1. Calling the n8n MCP tool
2. Making an n8n API call
3. Running a verification or acceptance script
4. Importing or updating a workflow
5. Any health check, execution inspection, or credential retrieval

---

## When local dev IS allowed

Only when the user explicitly uses the phrase **"local dev"** or **"local Docker test"** in their message. Even then, confirm the scope before proceeding.
