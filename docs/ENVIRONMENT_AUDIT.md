# Environment Audit — Phase 1 (reaffirmed)

Date: 2026-06-10 (reaffirmed in the Phase 2 correction pass)
Working directory: `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation`

> The three build blockers below remain **unresolved**: n8n MCP is not connected, the non-production n8n instance is not confirmed, and the Instantly API key / plan tier is not provisioned or confirmed. No workflow may be built until they are resolved (`docs/ASSUMPTIONS_AND_UNKNOWNS.md` A1-A3, `docs/IMPLEMENTATION_PLAN.md` §1).

---

## Phase 2.6 Gate 2-3 (2026-06-11, current status, supersedes the Gate 1-2 section below)

Full detail: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` ("Phase 2.6 Gate 2-3" section). Resumed for **Gate 2 and Gate 3 only**, per explicit instruction — no previous environment, Docker, MCP setup, business-policy, architecture, or source-review work was repeated; Prompt 3 was not started; `claude mcp get`/`claude mcp list`/anything revealing `HMZ_N8N_API_KEY` were not run.

- The owner independently verified from PowerShell that `http://localhost:5678/healthz`, `http://127.0.0.1:5678/healthz`, `http://127.0.0.1:5678/healthz/readiness`, and authenticated `GET /api/v1/workflows?limit=1` on both hosts all succeed (HTTP 200 / empty workflow collection). `.mcp.json` now uses `N8N_API_URL=http://127.0.0.1:5678` (was `http://localhost:5678`).
- **Gate 2 (API connection): PASS — `NO_RESPONSE` blocker resolved.** `n8n_health_check(mode="diagnostic")` now returns `connected: true, error: null, config.baseUrl: "http://127.0.0.1:5678"`. `n8n_list_workflows()` → 0 workflows; `n8n_executions(action="list")` → 0 executions. `version: "unknown"` is an n8n API response-shape limitation (instance remains pinned to `2.25.7` per Phase C, not re-checked this session).
- **Gate 3 (disposable workflow lifecycle): PASS.** With owner approval, created `DELETE_ME_ROUTE_A_VERIFICATION` (Manual Trigger + Sticky Note, typeVersion 1 each, `connections: {}`, no credentials, created inactive). Retrieved (`active: false`, no credential references confirmed), validated (`valid: false` — one expected/known artifact: "Multi-node workflow has no connections", caused by the validator counting the Sticky Note, not a security/credential/activation issue), deleted (`deleted: true`), and re-listed (0 workflows — confirmed gone). Never executed.
- Secrets check: `.env*` glob — no files (`DRY_RUN=true` default unchanged). Repo-wide grep for `N8N_API_KEY|eyJhbGci` — same 7 known placeholder/documentation files as before, no new exposure. `claude mcp get`/`claude mcp list` not run.
- `DRY_RUN=true` confirmed (default, no `.env*`). `LIVE_CAMPAIGNS=empty` carried forward, not re-verified this session (file not in this session's read-only list).
- **Verdict: `ROUTE A READY FOR PROMPT 3`.** Route A's MCP-verified-build gates are now met. **Prompt 3 was not started** — requires explicit user authorisation in a future session.

---

## Phase 2.6 Gate 1-2 (project-scoped `.mcp.json`) — 2026-06-11 (historical — superseded by the Gate 2-3 section above; instance/tool-surface findings remain valid)

Full detail: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` ("Phase 2.6 Gate 1-2" section). Resumed for **Phase 2.6 verification only** (a fixed Gate 1-4 script) — MCP configuration, Docker provisioning, WSL setup, n8n installation, business-policy review, and architecture work were not repeated; Prompt 3 was not started; `claude mcp get`/`claude mcp list`/anything revealing `HMZ_N8N_API_KEY` were not run.

- The owner replaced the user-scoped `n8n-mcp` MCP config with a project-scoped `.mcp.json` (`N8N_API_URL=http://localhost:5678`, `N8N_API_KEY=${HMZ_N8N_API_KEY}`, `WEBHOOK_SECURITY_MODE=moderate`).
- **Gate 1 (tool surface): PASS.** All 24 tools present and schema-loaded — 7 documentation/node tools + 17 `n8n_*` instance-management tools (full list in the audit report). **This resolves the Phase D retry's "0/17 tools present" regression.**
- **Gate 2 (API connection): FAIL — new blocker, SSRF blocker resolved.** `n8n_health_check(mode="diagnostic")` now returns `connected: false, error: "No response from n8n server"` — a **different** error from the prior session's `"SSRF protection: Localhost access is blocked in strict mode"`. `WEBHOOK_SECURITY_MODE=moderate` is confirmed working. `n8n_list_workflows()` and `n8n_executions(action="list")` both fail with `{"success": false, "error": "Unable to connect to n8n...", "code": "NO_RESPONSE"}`.
- **Read-only diagnostics (status checks, not provisioning):** `docker ps` shows `hmz-n8n-local-dev` running (`Up 3 hours`, image `docker.n8n.io/n8nio/n8n:2.25.7`, port `127.0.0.1:5678->5678/tcp`); `Get-NetTCPConnection -LocalPort 5678` shows `Listen` on `127.0.0.1:5678`, no `0.0.0.0`/`::` listener. The container is up and the port is locally reachable at TCP level, yet `n8n-mcp` gets no HTTP response — root cause not diagnosed (see audit report for an unverified IPv4/IPv6 `localhost`-resolution hypothesis).
- Gate 3 (disposable workflow lifecycle) and the API-dependent Gate 4 items were **not attempted** (gated on Gate 2). Local-only Gate 4 items (URL, Docker binding, version pins, SSRF mode, no tunnel, no API key in repo, `DRY_RUN=true`) all **confirmed** — see audit report.
- `DRY_RUN=true` and `LIVE_CAMPAIGNS=empty` unchanged. No business-policy file touched. No Instantly call made.
- **Verdict: `ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`** (new cause — `NO_RESPONSE`, SSRF resolved). Still **NOT READY FOR PROMPT 3.**

---

## Phase 2.6 Phase D retry — 2026-06-11 (historical — superseded by the Gate 1-2 section above; instance-level findings remain valid)

Full detail: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` ("Phase D retry" section). Resumed **from the failed health-check gate only**, per explicit instruction — WSL/Docker/provisioning/version-pinning/business-policy/architecture work and Prompt 3 were not repeated/started; Instantly was not configured or called; `claude mcp get`/`claude mcp list` were **not** run (standing prohibition, since the owner reported a key rotation + reconfiguration this session).

- Owner reported: revoked the previously-exposed local n8n API key, created a replacement key, reconfigured `n8n-mcp` (user scope) with the new key, added `WEBHOOK_SECURITY_MODE=moderate`, retained `N8N_API_URL=http://localhost:5678`, and restarted Claude Code.
- **New finding — regression: none of the 17 `n8n_*` instance-management tools (including `n8n_health_check`, `n8n_list_workflows`, `n8n_executions`) are present in this session's tool surface.** Three independent ToolSearch queries plus an exact-name `select:` lookup for `n8n_health_check`, `n8n_list_workflows`, `n8n_executions`, `n8n_create_workflow`, and `n8n_manage_credentials` all returned "No matching deferred tools found". Only the same 7 documentation/node tools as the pre-Phase-D (Phase 2.5/Phase C) state are available: `tools_documentation`, `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`.
- `tools_documentation()` (one of the always-available 7 tools, read-only, no `claude mcp get`) confirms the `n8n-mcp` server process itself is connected and responding. Its text states the 15 `n8n_*` API tools "require N8N_API_URL configuration" — but this is static reference text, not a live-config report.
- `ListMcpResourcesTool(server="n8n-mcp")` returns only two generic UI resources (`Operation Result`, `Validation Summary`) — no instance-config information available this way.
- Because `n8n_health_check` is not present, **it cannot be invoked at all** — Phase D's connectivity steps (health check, `n8n_list_workflows`, `n8n_executions`) could not be attempted. This is an earlier-stage failure than the prior session's `connected: false` (SSRF) result, where the tool was at least present and callable.
- Per the explicit prohibition on `claude mcp get`/`claude mcp list`, the live `n8n-mcp` configuration cannot be inspected from this session. The symptom is consistent with: (a) the owner's `claude mcp add` reconfiguration not completing successfully, (b) Claude Code not having been **fully** restarted (all processes) after the reconfiguration, or (c) this session not reflecting a post-restart state. None of these can be distinguished without the prohibited commands.
- **Secrets-handling check (read-only, safe):** repo-wide grep for the previously-exposed key's JWT prefix (`eyJhbGci`) returns exactly one match, in `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` — verified to be that report's own prose *describing* the earlier grep, not a reproduced key. A separate grep for `N8N_API_KEY`/`N8N_API_URL`/`WEBHOOK_SECURITY_MODE` finds only documentation/config-instruction references with placeholders (`<key>`, `<new-key>`, `<your-local-dev-api-key-here>`). No real secret values found anywhere in the repository.
- `.env*` glob (project root): no files found. `DRY_RUN=true` remains the documented default (`CLAUDE.md` rule #5); `LIVE_CAMPAIGNS` registry untouched (`docs/VALIDATION_CAMPAIGN_CONFIG.md` §3 not read/edited this session).
- Phase E (disposable workflow lifecycle) and Phase F (final isolation verification) were **not attempted** — both gated on Phase D's health check, which could not run.
- **Verdict: `ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`** (same verdict string as the prior session, but the underlying cause has regressed: previously the tool ran and reported `connected: false` due to SSRF; now the tool is absent entirely and cannot run at all). Still **NOT READY FOR PROMPT 3.**

---

## Phase 2.6 Phase D update — 2026-06-11 (historical — superseded by the Phase D retry section above; instance-level findings below remain valid)

Full detail: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` (Phase D section). Resumed from Phase D only — Phase A-C, version pinning, and business-policy work were not repeated; Prompt 3 was not started; Instantly was not configured or called.

- **`n8n-mcp` is connected** with `N8N_API_URL=http://localhost:5678` and `N8N_API_KEY` configured (`claude mcp get n8n-mcp` → `✔ Connected`).
- **Incident:** that same `claude mcp get` command displayed the full API key value in this session's transcript (its normal behaviour — it dumps the full configured environment). No value was repeated, copied, or written anywhere (repo-wide grep for the key's JWT prefix returned zero matches). Owner decision: continue using only `n8n-mcp` tool calls (which redact the key as `"***configured***"`), and **rotate the key afterward** (n8n Settings → API → regenerate, update `n8n-mcp` config outside Claude Code, restart Claude Code).
- **All 17 `n8n_*` workflow-management tools are now present and callable** (previously 0/15) — the prior `MCP WORKFLOW TOOLS UNAVAILABLE` blocker is **resolved**.
- **New blocker:** `n8n_health_check`, `n8n_list_workflows`, and `n8n_executions` all fail with `"SSRF protection: Localhost access is blocked in strict mode"`. Root cause: `n8n-mcp`'s `WEBHOOK_SECURITY_MODE` env var defaults to `strict`, which blocks its own HTTP client from reaching `localhost`/RFC1918 addresses — including its configured `N8N_API_URL=http://localhost:5678`. **Verified fix** (per `n8n-mcp`'s own published security advisory, [GHSA-cmrh-wvq6-wm9r](https://github.com/czlonkowski/n8n-mcp/security/advisories/GHSA-cmrh-wvq6-wm9r)): set `WEBHOOK_SECURITY_MODE=moderate` (allows localhost, still blocks RFC1918/cloud-metadata) and restart Claude Code.
- Phase E (disposable workflow lifecycle) and the remaining Phase F items (credentials-category check, fresh workflow/active counts via MCP) are blocked pending this fix — not attempted, since they would reproduce the identical SSRF error.
- Phase F items not requiring live API calls (URL, Docker binding, version pin, tunnels, `DRY_RUN`/`LIVE_CAMPAIGNS`) are carried forward unchanged from Phase C and were not re-verified this session (no Docker commands run, per scope).
- **Verdict: `ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`** (narrowed from "MCP WORKFLOW TOOLS UNAVAILABLE"). Still **NOT READY FOR PROMPT 3**.

---

## Phase 2.6 Phase C update — 2026-06-11 (historical — superseded by Phase D above for connectivity/tool-availability status; instance-level findings below remain valid)

Full detail: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` (Phase C-F section). The owner has manually installed WSL2 + Docker Desktop, started the prepared Compose environment, created the n8n owner account, and created a local development API key. Phase C (read-only verification) ran and **all claims checked out true**.

- **WSL2: installed and working.** Default distro `Ubuntu` (version 2); `docker-desktop` WSL distro running.
- **Docker: installed and working.** `docker --version` → 29.5.3 (build `d1c06ef`); `docker compose version` → v5.1.4. `docker info` succeeds — Server Version 29.5.3, OSType `linux` (WSL2-backed Docker Desktop), 1 container running.
- **Container `hmz-n8n-local-dev`: running**, `RestartCount=0`, image `docker.n8n.io/n8nio/n8n:2.25.7` (pinned this session — was `:latest`; image ID `761374d4eb84` unchanged, re-tagged locally, no pull/upgrade occurred).
- **Port binding: `127.0.0.1:5678` only** — confirmed via `docker inspect` `PortBindings` (`{"5678/tcp":[{"HostIp":"127.0.0.1","HostPort":"5678"}]}`) and `Get-NetTCPConnection -LocalPort 5678` (LocalAddress `127.0.0.1` only, no `0.0.0.0`/`::` listeners).
- **`http://localhost:5678` responds HTTP 200** (verified before and after the version-pin recreation).
- **Volume `hmz_n8n_local_dev_data`: present**, driver `local`, created `2026-06-11T00:59:00Z`, mounted read-write at `/home/node/.n8n`; timestamp unchanged across the pin-recreation — data preserved.
- **Workflows: 0** — `docker exec hmz-n8n-local-dev n8n list:workflow` (CLI, no API key required) returns empty; container logs confirm "Processed 0 draft workflows, 0 published workflows" on every startup.
- **Tunnels: none** — no `ngrok`/`cloudflared`/`localtunnel` process running on the host.
- Container logs show benign n8n-internal startup messages ("Last session crashed", "Database connection timed out → recovered", a 6s timeout fetching n8n's external MCP-registry at `api.n8n.io`) — none fatal; "n8n ready ... port 5678" and HTTP 200 confirm the instance is healthy.
- **`n8n-mcp` MCP config: still missing `N8N_API_URL`/`N8N_API_KEY`** — `claude mcp get n8n-mcp` shows only `MCP_MODE=stdio`, `LOG_LEVEL=error`, `DISABLE_CONSOLE_OUTPUT=true`. Owner must run the corrected command in `infrastructure/local-n8n/README.md` §5 (in a terminal outside this repo/chat) and restart Claude Code for the new env vars to take effect. **This is now the sole remaining step** before Phase D-F (MCP reconnect, tool inventory, disposable workflow lifecycle) can run.
- `DRY_RUN=true` and `LIVE_CAMPAIGNS=empty` unchanged. No Instantly call made. No business-policy file touched. No secret was written to any project file.

---

## Phase 2.6 update — 2026-06-10 (historical — Phase A was blocked at this point; superseded by Phase C above)

Full detail: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md`. Scope: provision and verify a completely local, non-production n8n dev instance to resolve A2. **Result: blocked at the prerequisite check (Phase A) — no provisioning was performed.**

- **Docker Desktop / Docker CLI: not installed.** `docker --version` → command not found. No `C:\Program Files\Docker`. No Docker service or process.
- **WSL2: not installed** (`wsl --status` → "The Windows Subsystem for Linux is not installed"). Required as the Docker Desktop backend on this OS (Windows 11 **Home** — Hyper-V backend is unavailable, so WSL2 is mandatory, not optional).
- **Port `5678`: free** (no listener; consistent with the Phase 2.5 finding that no local n8n is running).
- **No existing `hmz-n8n-local-dev` container or `hmz_n8n_local_dev_data` volume** (none possible — Docker is not installed) and **no other local n8n instance** found.
- A dev-only, secret-free Compose file and setup guide were prepared for when Docker is installed: `infrastructure/local-n8n/docker-compose.yml`, `infrastructure/local-n8n/README.md`. Nothing was started, created, or modified on the host beyond these two new files.
- **A2 remains BLOCKED** — now specifically on owner-side WSL2 + Docker Desktop installation (exact steps in `infrastructure/local-n8n/README.md` §1). Once Docker is installed and running, Phases B-F of `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` can proceed using the prepared Compose file.
- `DRY_RUN=true` and `LIVE_CAMPAIGNS=empty` unchanged. No n8n workflow created/imported/activated. No Instantly call made.

---

## Phase 2.5 update — 2026-06-10 (current status, supersedes the n8n-MCP rows below)

Full detail: `reports/PHASE_2_5_MCP_AND_ENVIRONMENT_AUDIT.md`.

- **n8n MCP is now connected**: `n8n-mcp` (`github.com/czlonkowski/n8n-mcp`, user-scope config, `npx n8n-mcp`, stdio). Health check ✔ Connected. The 7 non-instance tools (`tools_documentation`, `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`) were each tested read-only and work.
- **No n8n instance is connected**: the server's configured env has no `N8N_API_URL`/`N8N_API_KEY`, so the 15 `n8n_*` workflow-management/API tools (list/get/create/update/validate-by-ID/executions/health-check, etc.) are unavailable. No local n8n was found either (no `localhost:5678`, no `n8n` CLI, no `~/.n8n`).
- **A2 (non-production instance) remains unmet** — not because production was found, but because no instance is connected at all. There is nothing to classify as production or non-production yet.
- **A3 (Instantly API key/plan tier)** unchanged — still BLOCKED for live actions, but confirmed **not** to block the Prompt-3 mocked-build scope (`IMPLEMENTATION_PLAN.md` §2 items 1-11).
- The Phase 1 "n8n MCP tools ... Missing" row below is now **historical** (true at the time it was written, no longer the current state for tool availability — though the live-instance gap it predicted is still open via A2).

## Repository state

```
CLAUDE.md
docs/   (created in Phase 1)
infrastructure/local-n8n/   (created in Phase 2.6 — docker-compose.yml + README.md, no secrets)
```

- No `directives/`, `execution/`, `.tmp/`, `.env`, `credentials.json`, or `token.json` present.
- No prior n8n workflow exports in the working tree.
- Not a git repository.

## Connected tooling — actual

| Capability | Available? | Notes |
| --- | --- | --- |
| `WebFetch`, `WebSearch` | yes | Used for Instantly doc research. |
| Local shell (PowerShell / Bash) | yes | Used to create `docs/`. |
| File editing | yes | |

## Connected tooling — expected by CLAUDE.md but **NOT** present

| Capability | Status | Impact |
| --- | --- | --- |
| **n8n MCP tools** (workflow inspection, node schemas, validation, execution history) | **Historical (Phase 1) — superseded.** At the time of writing, tool searches for `n8n` and `mcp workflow node` returned zero matches. As of the Phase 2.5 update above, `n8n-mcp` is connected and 7 node/template/validation tools work; the 15 workflow-inspection/execution-history tools still require `N8N_API_URL` (no instance connected — A2). | Project Rule #4 mandates using n8n MCP "to inspect current nodes, schemas, workflows, validation results, and executions before guessing configuration." Node/schema/template inspection (Phase 1 Tasks 1, 3, 5) is now possible; workflow/execution inspection (Task 2, and live-instance parts of 1/5) remains blocked by A2. |
| n8n credentials / instance URL | Not provided. | We cannot verify environment type, list existing workflows, or pull node-version-specific schemas. |
| Instantly API key | Not provided (would live in `.env` per CLAUDE.md). | Expected — we are not authorised to make live API calls in Phase 1. |
| Google OAuth (`credentials.json`, `token.json`) | Not present. | Not required for Phase 1; relevant later for deliverables. |

## Tasks affected by missing n8n MCP

| Phase 1 task | Status | Reason |
| --- | --- | --- |
| 1. Confirm which n8n MCP tools are available | **Blocked** | None registered in this environment. |
| 2. Confirm n8n instance is non-production | **Blocked / unknown** | No instance URL or credentials provided. Cannot inspect. |
| 3. Search relevant existing n8n templates (via MCP) | **Blocked** | No MCP template-search tool. Can fall back to manually browsing `n8n.io/workflows` later if approved. |
| 4. Identify likely nodes required | **Done** (general n8n knowledge — see `INSTANTLY_FIELD_MAP.md` → "Likely n8n nodes"). |
| 5. Inspect current node schemas via n8n MCP | **Blocked** | Schemas vary by n8n version; cannot retrieve without MCP or a live instance. |
| 6. Research current official Instantly documentation | **Done** — see `INSTANTLY_FIELD_MAP.md`. |
| 7. Do not guess unsupported fields | **Adhered to.** Fields are marked **VERIFIED**, **INFERRED**, or **UNKNOWN**. |
| 8. Create the four docs | **Done.** |

## Recommended actions (before Phase 2)

1. ~~Install or surface the n8n MCP server in this environment so Project Rule #4 can be satisfied.~~ **Done as of Phase 2.5**: `n8n-mcp` is connected; node/template/validation tools work (`reports/PHASE_2_5_MCP_AND_ENVIRONMENT_AUDIT.md`). Remaining gap is instance-level (#2 below), which also gates the 15 `n8n_*` workflow/execution tools.
2. Provide the target n8n instance URL and confirm in writing that it is **non-production** (separate workspace / isolated workflows copy per Rule #1), then configure `N8N_API_URL`/`N8N_API_KEY` on the `n8n-mcp` server (outside this repo).
3. Provide an Instantly **V2** API key with the scopes listed in `INSTANTLY_FIELD_MAP.md` § "Scopes required" — but keep it out of chat; reference its env var only.
4. Confirm the Instantly workspace plan tier in writing. Documentation indicates webhooks need a higher tier (referenced as "Hyper Growth or above"), but **our account's tier is unconfirmed** — do not assume it (`ASSUMPTIONS_AND_UNKNOWNS.md` A3).

Until #2 lands, Route A (`docs/IMPLEMENTATION_PLAN.md` §1) remains blocked on non-production isolation (A2). #3/#4 are confirmed not to block the Prompt-3 mocked-build scope (Phase E, `reports/PHASE_2_5_MCP_AND_ENVIRONMENT_AUDIT.md`).
