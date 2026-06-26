# Phase 2.6 — Local n8n Provisioning Audit

Date: 2026-06-10. Scope: provision and verify a completely local, **non-production** n8n development environment (`HMZ_N8N_LOCAL_DEVELOPMENT_ONLY`) to resolve A2 and unblock Route A for Prompt 3. **Do not begin Prompt 3** remained in force throughout. No Instantly responder workflow was built, no Instantly configuration/calls were made, no production or customer data was used.

This report supersedes the A2 framing in `reports/PHASE_2_5_MCP_AND_ENVIRONMENT_AUDIT.md` and `docs/ASSUMPTIONS_AND_UNKNOWNS.md`. It does not change `DRY_RUN=true` or `LIVE_CAMPAIGNS=empty`, and does not authorise Prompt 3.

---

## 2026-06-11 update — resumed at Phase C only (supersedes the Phase A blocker below for current status)

The owner manually installed WSL2 + Docker Desktop, started the prepared Compose environment, created the n8n owner account, and created a local development API key. This session resumed **from Phase C only** — Phase A/B and the business-policy audits were not repeated, Prompt 3 was not started, and Instantly was not configured or called.

**Phase C (read-only verification): all 10 checks PASS** (see "Phase C — read-only verification (2026-06-11)" below). The n8n version was then pinned from `:latest` to the verified running version `2.25.7` with no pull/upgrade. **Phase D (MCP reconnect) is blocked on one remaining owner action**: add `N8N_API_URL`/`N8N_API_KEY` to the `n8n-mcp` user-scope config (`infrastructure/local-n8n/README.md` §5, corrected this session) and restart Claude Code. Phases D-F have not yet run.

**Updated verdict: `ROUTE A BLOCKED — MCP WORKFLOW TOOLS UNAVAILABLE`** (see "Final verdict (2026-06-11)" at the end of this report, which supersedes the 2026-06-10 verdict below).

---

## Summary (2026-06-10, historical — Phase A was blocked at this point)

**Phase A (prerequisite check) failed: Docker is not installed, and its mandatory backend on this machine (WSL2) is also not installed.** Per the task's own instruction — "If Docker is not installed or running, stop and give exact owner instructions. Do not silently switch to npm." — provisioning stopped at Phase A. Phases B-F (container/volume creation, owner account, MCP reconnection, disposable workflow lifecycle, isolation evidence) were **not attempted**. Nothing was started, created, modified, or removed on the host, except two new reference files (no secrets, no execution): `infrastructure/local-n8n/docker-compose.yml` and `infrastructure/local-n8n/README.md`.

---

## Phase A — prerequisite checks

| # | Check | Result |
| --- | --- | --- |
| 1 | Operating system | Microsoft Windows **11 Home**, version `10.0.26200`, 64-bit. |
| 2 | Docker Desktop availability | **Not installed.** No `Docker Desktop.exe` at `C:\Program Files\Docker\Docker\`; no `C:\Program Files\Docker` directory at all. |
| 3 | Docker CLI availability | **Not available.** `docker --version` → "The term 'docker' is not recognized as the name of a cmdlet, function, script file, or operable program." No `docker` command found on PATH. |
| 4 | Docker engine running | **N/A — not installed.** No Docker Windows service, no Docker process running. |
| 5 | Port `5678` availability | **Free.** `Test-NetConnection -ComputerName localhost -Port 5678` → `TcpTestSucceeded: False`; `Get-NetTCPConnection -LocalPort 5678` → no listener. |
| 6 | Existing `hmz-n8n-local-dev` container / `hmz_n8n_local_dev_data` volume | **None — cannot exist.** Docker is not installed, so no containers or volumes of any name exist. |
| 7 | Other local n8n instance running | **None.** Port `5678` free (above); consistent with the Phase 2.5 finding (no `localhost:5678`, no `~/.n8n`, no `n8n` CLI). |

**Additional finding (relevant to remediation):** WSL2 is also **not installed** (`wsl --status` → "The Windows Subsystem for Linux is not installed. You can install by running 'wsl.exe --install'."). This matters because Windows 11 **Home** cannot use Docker Desktop's Hyper-V backend (Home edition does not support Hyper-V) — **WSL2 is the only available backend** and is therefore a hard prerequisite for Docker Desktop on this machine, not an optional extra.

No removal, overwrite, install, or modification of any existing container, volume, or system component was performed. Nothing was found to remove or overwrite.

---

## Phase B — installation pattern (researched, not executed)

Docker could not be installed or invoked, so no container/volume was created. To avoid a second round trip once Docker is available, the official current installation pattern was researched (`docs.n8n.io` Docker docs, current as of 2026-06-10) and a ready-to-use, **secret-free, dev-only** Compose file + setup guide were prepared:

- `infrastructure/local-n8n/docker-compose.yml`
  - Image: `docker.n8n.io/n8nio/n8n:latest` (current official stable image, not a beta/`next` tag).
  - Container name: `hmz-n8n-local-dev`.
  - Volume: `hmz_n8n_local_dev_data` (persistent, mounted at `/home/node/.n8n`).
  - Port binding: `127.0.0.1:5678:5678` (localhost-only — not reachable from the network).
  - `GENERIC_TIMEZONE=Europe/London`, `TZ=Europe/London`.
  - `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true`, `N8N_RUNNERS_ENABLED=true` (current official defaults).
  - No secrets, no tunnel, no production configuration. Header comment marks it `HMZ_N8N_LOCAL_DEVELOPMENT_ONLY`.
- `infrastructure/local-n8n/README.md`
  - §1: exact WSL2 + Docker Desktop installation steps for Windows 11 Home (owner action required).
  - §2: how to start the prepared Compose file.
  - §3: manual owner-account creation (no password requested/stored).
  - §4: how to create a development API key in n8n Settings → API.
  - §5: how to configure the existing `n8n-mcp` MCP server with `N8N_API_URL`/`N8N_API_KEY` outside this repo.
  - §6: stop/teardown commands.
  - §7: isolation reminders (no business workflows, no Instantly/AI/email credentials, no tunnel, `DRY_RUN=true`/`LIVE_CAMPAIGNS=empty` unchanged, activation prohibited).

These names do not collide with any existing environment — none exists (Phase A, check 6).

---

## Phase C — read-only verification (2026-06-11)

The owner reported having: installed WSL2 + Docker Desktop, started the prepared Compose environment, created the n8n owner account, and created a local development API key. Per the task's "stop if any claim is false" instruction, all 10 read-only checks were run before any action was taken. **All 10 checks passed:**

| # | Check | Result |
| --- | --- | --- |
| 1 | `wsl --status` | Default Distribution: `Ubuntu`, Default Version: `2`. |
| 2 | `wsl -l -v` | `Ubuntu` (Stopped, v2) — default; `docker-desktop` (Running, v2). |
| 3 | `docker --version` | `Docker version 29.5.3, build d1c06ef`. |
| 4 | `docker compose version` | `Docker Compose version v5.1.4`. |
| 5 | `docker info` | Succeeds. Server Version `29.5.3`, OSType `linux` (WSL2-backed Docker Desktop), Containers: 1 (1 running), Kernel `6.18.33.1-microsoft-standard-WSL2`. |
| 6 | `docker ps --filter "name=hmz-n8n-local-dev"` | Container `hmz-n8n-local-dev` running, image `docker.n8n.io/n8nio/n8n:latest` (at time of check), `127.0.0.1:5678->5678/tcp`, created 29 min ago, up 4 min. |
| 7 | Last 50 container log lines | `n8n ready on ::, port 5678`, `Version: 2.25.7`, "Processed 0 draft workflows, 0 published workflows". Benign warnings: "Last session crashed" (n8n-internal startup message, not a Docker restart — `RestartCount=0`), repeated "Database connection timed out → recovered" (SQLite startup quirk under Docker Desktop's constrained VM, non-fatal), and a 6s timeout fetching n8n's own external MCP-server registry at `api.n8n.io` (unrelated to our `n8n-mcp`, non-fatal). |
| 8 | `http://localhost:5678` | HTTP `200`. |
| 9 | `docker compose -f infrastructure/local-n8n/docker-compose.yml config` | Effective config confirms: container `hmz-n8n-local-dev`, image (then) `:latest`, port `127.0.0.1:5678→5678` (ingress), volume `hmz_n8n_local_dev_data` → `/home/node/.n8n`, env `GENERIC_TIMEZONE`/`TZ=Europe/London`, `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true`, `restart: unless-stopped`. |
| 10 | Port binding | `docker inspect` `PortBindings`: `{"5678/tcp":[{"HostIp":"127.0.0.1","HostPort":"5678"}]}`. `Get-NetTCPConnection -LocalPort 5678`: all entries `LocalAddress=127.0.0.1` (Listen + FinWait2/TimeWait from the HTTP check), no `0.0.0.0`/`::` listener. |

Additional read-only evidence gathered: volume `hmz_n8n_local_dev_data` exists (driver `local`, created `2026-06-11T00:59:00Z`); `docker exec hmz-n8n-local-dev n8n --version` → `2.25.7`; `docker exec hmz-n8n-local-dev n8n list:workflow` → empty (0 workflows); no `ngrok`/`cloudflared`/`localtunnel` process running on the host.

---

## Version pinning (2026-06-11)

The Compose file pinned `image: docker.n8n.io/n8nio/n8n:latest`. Per official n8n guidance ([n8n Docker docs](https://docs.n8n.io/hosting/installation/docker/), [Docker Hub tags](https://hub.docker.com/r/n8nio/n8n/tags)) — "Pinning the version is the single most important habit; unpinned images get silently upgraded and break workflows in unpredictable ways" — the image was pinned to the **exact version already running**, `2.25.7`, with no upgrade:

1. `docker tag docker.n8n.io/n8nio/n8n:latest docker.n8n.io/n8nio/n8n:2.25.7` — creates a local tag alias; both tags point to the same image ID `761374d4eb84` (no pull).
2. `infrastructure/local-n8n/docker-compose.yml` `image:` updated to `docker.n8n.io/n8nio/n8n:2.25.7`, with a comment recording the pin date and a no-silent-bump note.
3. `docker compose -f infrastructure/local-n8n/docker-compose.yml up -d` — Compose detected the image-tag change and recreated the container. Default `pull_policy: missing` meant no network pull occurred (the `2.25.7` tag was already present locally from step 1).
4. Post-recreation verification: `docker ps` shows `hmz-n8n-local-dev` on `docker.n8n.io/n8nio/n8n:2.25.7`, `RestartCount=0`, `Status=running`; `docker exec ... n8n --version` → `2.25.7`; volume `hmz_n8n_local_dev_data` mount and creation timestamp (`2026-06-11T00:59:00Z`) unchanged — data preserved; `http://localhost:5678` → HTTP `200`; logs again show `Version: 2.25.7` and "Processed 0 draft workflows, 0 published workflows".

---

## Phase D — MCP reconnection (blocked, 2026-06-11)

`claude mcp get n8n-mcp` confirms the server is connected (`Type: stdio`, `Command: npx n8n-mcp`) with environment `MCP_MODE=stdio`, `LOG_LEVEL=error`, `DISABLE_CONSOLE_OUTPUT=true` — **no `N8N_API_URL`/`N8N_API_KEY`**. This is unchanged from Phase 2.5/2.6.

`infrastructure/local-n8n/README.md` §5 was corrected this session: the previous example placed `--env KEY=VALUE` *after* the `--` separator, which `claude mcp add --help` (run this session) shows is incorrect — those flags would be passed to `npx n8n-mcp` as CLI args, not consumed by Claude Code. The corrected form places `-e KEY=VALUE` flags *before* `--`, preserving the three existing env vars and adding the two new ones:

```powershell
claude mcp remove n8n-mcp -s user
claude mcp add n8n-mcp -s user -e MCP_MODE=stdio -e LOG_LEVEL=error -e DISABLE_CONSOLE_OUTPUT=true -e N8N_API_URL=http://localhost:5678 -e N8N_API_KEY=<your-local-dev-api-key-here> -- npx n8n-mcp
```

The owner must run this in a terminal **outside** Claude Code (not via the `!` prefix, which would echo into this transcript), substituting their real local development API key (created in README §4) for the placeholder, then **restart Claude Code** (stdio MCP servers are spawned at session start). No secret was requested, displayed, or written anywhere in this session.

A read-only check (`claude mcp get n8n-mcp`) confirms the tool/connection state is unchanged from Phase 2.5/2.6: 7/21 tools available; the 15 `n8n_*` workflow-management tools remain absent pending the step above.

---

## Phase E — disposable workflow lifecycle — not attempted (deferred)

Depends on Phase D (the 15 `n8n_*` tools, including `n8n_create_workflow`/`n8n_delete_workflow`, are not yet available). Not attempted this session; no owner approval was sought since the precondition is not met. Deferred to the next session, after Phase D completes.

---

## Phase F — isolation evidence (partial, 2026-06-11)

Most isolation items can now be stated about the *real, running* environment:

- n8n URL: `http://localhost:5678` — confirmed (HTTP 200, Phase C check 8).
- Docker binds only to `127.0.0.1` — confirmed (Phase C checks 9-10).
- Container name: `hmz-n8n-local-dev` — confirmed running.
- Volume name: `hmz_n8n_local_dev_data` — confirmed present, intact across the version-pin recreation.
- n8n version pinned: `2.25.7` (was `:latest`) — confirmed.
- No tunnel or public route exists — confirmed (no `ngrok`/`cloudflared`/`localtunnel` process; port bound to `127.0.0.1` only).
- No business workflows exist — confirmed (`n8n list:workflow` empty; logs confirm 0 workflows on every startup).
- No active workflows exist — confirmed (0 workflows total ⇒ 0 active).
- The disposable `DELETE_ME_ROUTE_A_VERIFICATION` workflow lifecycle (Phase E) — **not yet attempted**, deferred pending Phase D.
- The API key was not written into the repository — confirmed; no key value was requested, displayed, or stored anywhere in this session.
- `DRY_RUN=true` — unchanged (no `.env` exists yet; documented as the project default in `CLAUDE.md` rule #5 and referenced across `docs/*.md`).
- `LIVE_CAMPAIGNS` remains empty — unchanged (`docs/VALIDATION_CAMPAIGN_CONFIG.md` §3 has zero rows).
- **Not yet verified**: "no Instantly, AI-provider, email, or production credentials exist" inside the n8n instance. `n8n list:credentials` is not a CLI subcommand (only `import:credentials`/`export:credentials` exist — checked via `n8n --help`), so this requires either MCP-based credential listing (Phase D) or a separately-approved `export:credentials` run. The volume was created `2026-06-11T00:59:00Z` (today) and 0 workflows exist, so the likelihood of any credential being present is low, but this is **not yet confirmed** — deferred to Phase D/F completion.

---

## Route A verification gates (2026-06-10, historical — see updated table at end of file)

| Gate | Status |
| --- | --- |
| n8n local instance starts successfully | **Not reached** — Docker/WSL2 not installed. |
| Owner login works | Not reached. |
| Local API key authentication works | Not reached. |
| n8n MCP exposes workflow-management tools | **No** — same as Phase 2.5: 7/21 tools available (no `N8N_API_URL`). Confirmed unchanged this session (read-only `tools_documentation()` call). |
| MCP health check succeeds | Not reached (`n8n_health_check` requires `N8N_API_URL`, not configured). |
| Workflow listing succeeds | Not reached. |
| Disposable workflow create/get/validate/delete lifecycle succeeds | Not reached — and not attempted (no instance, no owner approval requested). |
| Disposable workflow no longer present | N/A — never created. |
| No workflow is active | True (vacuously — no workflows exist anywhere in this environment). |
| No secret was written into the project | **True.** Only two new files created, both secret-free (`infrastructure/local-n8n/docker-compose.yml`, `infrastructure/local-n8n/README.md`). |
| No Instantly or external API call occurred | **True.** No Instantly config exists; only read-only local checks (Docker/WSL/port/MCP tool list) and one official-docs lookup for the Compose pattern were performed. |
| Non-production isolation documented | Documented as **not yet provisioned** (this report + `docs/ENVIRONMENT_AUDIT.md` Phase 2.6 update). |
| `DRY_RUN=true` | Unchanged — true. |
| `LIVE_CAMPAIGNS` remains empty | Unchanged — empty. |

---

## Final verdict (2026-06-10, historical — see updated verdict at end of file)

**`ROUTE A BLOCKED — DOCKER OWNER SETUP REQUIRED`**

1. **Docker status:** Not installed. Docker Desktop absent (`C:\Program Files\Docker` does not exist); `docker` CLI not on PATH; no Docker service/process. WSL2 (the mandatory backend on Windows 11 Home — Hyper-V is unavailable on Home) is also not installed.
2. **Container and volume names:** None exist. Proposed names `hmz-n8n-local-dev` / `hmz_n8n_local_dev_data` are reserved in the prepared Compose file (`infrastructure/local-n8n/docker-compose.yml`) and do not collide with anything (nothing exists).
3. **Local n8n URL:** None yet. Planned: `http://localhost:5678` (already reserved as free — Phase A check 5).
4. **n8n version:** N/A — no instance exists. The prepared Compose file pins the official stable channel (`docker.n8n.io/n8nio/n8n:latest`, not a beta/`next` tag); the actual version will be reported once the container starts (Phase B, future session).
5. **API authentication result:** Not attempted — no instance, no key.
6. **Actual MCP tools available:** Unchanged from Phase 2.5 — **7 of 21**: `tools_documentation`, `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`. The 15 `n8n_*` workflow-management/API tools (`n8n_create_workflow`, `n8n_get_workflow`, `n8n_update_full_workflow`, `n8n_update_partial_workflow`, `n8n_delete_workflow`, `n8n_list_workflows`, `n8n_validate_workflow`, `n8n_autofix_workflow`, `n8n_test_workflow`, `n8n_executions`, `n8n_health_check`, `n8n_workflow_versions`, `n8n_deploy_template`, `n8n_manage_datatable`, `n8n_generate_workflow`) remain absent — confirmed via a fresh read-only `tools_documentation()` call this session, no reconnection performed (nothing changed to reconnect to).
7. **Disposable workflow lifecycle result:** Not attempted. Precondition (a reachable local n8n instance) not met; no owner approval was sought for this step since it could not have proceeded regardless.
8. **Evidence of non-production isolation:** No environment exists to be production or non-production. Nothing was created, so nothing needs isolating yet. The prepared Compose file binds to `127.0.0.1` only, uses a uniquely-named container/volume, sets no production config, and contains no secrets — ready for isolation verification once an instance actually runs.
9. **Secrets-handling result:** Clean. No `.env`, credential, or key file was created or modified. No secret values exist anywhere in this environment for n8n or Instantly. Only env-var/file/process *existence* was checked (PowerShell `Get-Command`, `Get-CimInstance`, `Test-NetConnection`, `Get-NetTCPConnection`) — no values were displayed or stored.
10. **Files changed:**
    - Created: `infrastructure/local-n8n/docker-compose.yml` (no secrets, dev-only, localhost-bound).
    - Created: `infrastructure/local-n8n/README.md` (no secrets; WSL2/Docker install steps + setup guide).
    - Updated: `docs/ENVIRONMENT_AUDIT.md` (new "Phase 2.6 update" section + repository-state listing).
    - Updated: `docs/ASSUMPTIONS_AND_UNKNOWNS.md` (A2 entry updated with Phase 2.6 findings and revised verification path).
    - Updated: `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` (new "Phase 2.6 addendum" section, "Pick up here" item 0, updated open-question bullet).
    - Created: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` (this file).
    - No business-policy file (`docs/HMZ_APPROVED_REPLY_RULES.md`, `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`, `docs/VALIDATION_CAMPAIGN_CONFIG.md`, etc.) was touched.
11. **Unresolved blockers:**
    - **A2 (non-production n8n instance)** — still BLOCKED. Specific cause has narrowed from "nothing connected" (Phase 2.5) to "Docker/WSL2 not installed" (this phase). Owner action required: install WSL2 + Docker Desktop (`infrastructure/local-n8n/README.md` §1).
    - **A3 (Instantly API key/plan tier)** — unchanged, still BLOCKED for live actions, still confirmed not to block Prompt 3's mocked-build scope.
12. **Exact next action:** Owner installs WSL2 + Docker Desktop per `infrastructure/local-n8n/README.md` §1 (run `wsl --install` as Administrator, restart, install Docker Desktop, restart, verify `docker info` succeeds). Once that succeeds, resume this audit at **Phase B** using `infrastructure/local-n8n/docker-compose.yml` (`docker compose -f infrastructure/local-n8n/docker-compose.yml up -d`), then proceed through Phases C-F as originally scoped. Until then, the verdict remains **`ROUTE A BLOCKED — DOCKER OWNER SETUP REQUIRED`** and **Prompt 3 must not begin**.

---

## Route A verification gates (2026-06-11 update — supersedes the table above)

| Gate | Status |
| --- | --- |
| n8n local instance starts successfully | **Yes** — `hmz-n8n-local-dev` running, n8n `2.25.7` (pinned), HTTP 200, `RestartCount=0`. |
| Owner login works | Reported by owner; consistent with the running instance and an existing API key (no password seen or required). |
| Local API key authentication works | **Not yet tested** — requires `N8N_API_URL`/`N8N_API_KEY` on `n8n-mcp` (Phase D, owner action pending). |
| n8n MCP exposes workflow-management tools | **No** — still 7/21 tools (no `N8N_API_URL`/`N8N_API_KEY`). Confirmed unchanged this session via `claude mcp get n8n-mcp`. |
| MCP health check succeeds | Not reached — same dependency as above. |
| Workflow listing succeeds (via MCP) | Not reached — same dependency. Non-MCP evidence (`n8n list:workflow`) shows 0 workflows. |
| Disposable workflow create/get/validate/delete lifecycle succeeds | Not reached — depends on Phase D tools; not attempted, no owner approval sought (precondition unmet). |
| Disposable workflow no longer present | N/A — never created. |
| No workflow is active | **True** — `n8n list:workflow` empty; logs confirm 0 workflows on every startup (before and after the version-pin recreation). |
| No secret was written into the project | **True.** Only `infrastructure/local-n8n/docker-compose.yml` (image tag + comment) and `infrastructure/local-n8n/README.md` (status + corrected §5 syntax) were edited; both secret-free. |
| No Instantly or external API call occurred | **True.** Only local Docker/WSL/n8n-CLI checks and one official n8n-docs web search were performed. |
| Non-production isolation documented | **Mostly** — instance-level isolation confirmed (localhost-only, dedicated container/volume, 0 workflows, no tunnels); credentials count not yet confirmed. |
| `DRY_RUN=true` | Unchanged — true (no `.env` exists; documented default). |
| `LIVE_CAMPAIGNS` remains empty | Unchanged — empty (`docs/VALIDATION_CAMPAIGN_CONFIG.md` §3 has zero rows). |
| n8n version pinned | **True** — `2.25.7`, `infrastructure/local-n8n/docker-compose.yml`. |

---

## Final verdict (2026-06-11)

**`ROUTE A BLOCKED — MCP WORKFLOW TOOLS UNAVAILABLE`**

1. **WSL2 result:** Installed and working. `wsl --status` → Default Distribution `Ubuntu`, Default Version `2`. `wsl -l -v` → `Ubuntu` (Stopped, v2, default), `docker-desktop` (Running, v2).
2. **Docker result:** Installed and working. `docker --version` → `29.5.3` (build `d1c06ef`); `docker compose version` → `v5.1.4`; `docker info` succeeds (Server Version `29.5.3`, OSType `linux`, WSL2-backed Docker Desktop, Kernel `6.18.33.1-microsoft-standard-WSL2`).
3. **Container and volume status:** `hmz-n8n-local-dev` running (`RestartCount=0`, `Status=running`), bound to `127.0.0.1:5678` only. `hmz_n8n_local_dev_data` present, driver `local`, created `2026-06-11T00:59:00Z`, mounted RW at `/home/node/.n8n`, intact across the version-pin recreation.
4. **Exact pinned n8n version:** `2.25.7` (`docker exec hmz-n8n-local-dev n8n --version`; `infrastructure/local-n8n/docker-compose.yml` now pins `docker.n8n.io/n8nio/n8n:2.25.7`, was `:latest`; same image ID `761374d4eb84` — no pull/upgrade occurred).
5. **localhost binding result:** `127.0.0.1:5678` only — confirmed via `docker inspect` `PortBindings` and `Get-NetTCPConnection -LocalPort 5678` (no `0.0.0.0`/`::` listener). `http://localhost:5678` → HTTP `200`.
6. **API authentication result:** Not attempted — `n8n-mcp` has no `N8N_API_URL`/`N8N_API_KEY` configured yet (owner action pending, see item 13).
7. **Complete MCP tool inventory:** Unchanged from Phase 2.5/2.6 — 7/21 tools available: `tools_documentation`, `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`. The 15 `n8n_*` workflow-management/API tools remain absent.
8. **MCP health-check result:** Not reached (`n8n_health_check` requires `N8N_API_URL`, not configured).
9. **Disposable workflow lifecycle result:** Not attempted — depends on the 15 `n8n_*` tools (Phase D), which are not yet available. No owner approval was sought since the precondition is unmet.
10. **Proof that no workflow remains active:** `docker exec hmz-n8n-local-dev n8n list:workflow` returns empty; container logs confirm "Processed 0 draft workflows, 0 published workflows" on every startup (both before and after the version-pin recreation).
11. **Secrets-handling result:** Clean. No API key, password, or other secret was requested, displayed, pasted, or written to any file in this session. `claude mcp get n8n-mcp` (read-only) shows only the three pre-existing non-secret env vars.
12. **Files changed:**
    - Modified: `infrastructure/local-n8n/docker-compose.yml` (image pinned `:latest` → `:2.25.7`, explanatory comment added — no secrets).
    - Modified: `infrastructure/local-n8n/README.md` (§0 status updated; §5 `claude mcp add` syntax corrected to use `-e KEY=VALUE` before `--`, per `claude mcp add --help` — no secrets).
    - Modified: `docs/ENVIRONMENT_AUDIT.md` (new "Phase 2.6 Phase C update — 2026-06-11" section).
    - Modified: `docs/ASSUMPTIONS_AND_UNKNOWNS.md` (A2 status updated to "PARTIALLY RESOLVED").
    - Modified: `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` (new "Phase 2.6 Phase C addendum" section; "Pick up here" item 0 and the Route A open-question bullet updated).
    - Modified: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` (this file — Phase C-F results, updated gates table and verdict added; 2026-06-10 content retained as historical record).
    - No business-policy file (`docs/HMZ_APPROVED_REPLY_RULES.md`, `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`, `docs/VALIDATION_CAMPAIGN_CONFIG.md`, etc.) was touched. No `.env`, credential, or key file was created.
13. **Unresolved blockers:**
    - **A2 (non-production n8n instance) — PARTIALLY RESOLVED.** Instance-level isolation is confirmed (local-only, dedicated container/volume, pinned version, 0 workflows, no tunnels). The remaining gap is MCP-level: the owner must run the corrected `infrastructure/local-n8n/README.md` §5 command — `claude mcp remove n8n-mcp -s user` then `claude mcp add n8n-mcp -s user -e MCP_MODE=stdio -e LOG_LEVEL=error -e DISABLE_CONSOLE_OUTPUT=true -e N8N_API_URL=http://localhost:5678 -e N8N_API_KEY=<key> -- npx n8n-mcp` — in a terminal **outside** Claude Code, then **restart Claude Code**.
    - **A3 (Instantly API key/plan tier)** — unchanged, still BLOCKED for live actions, still confirmed not to block Prompt 3's mocked-build scope.
    - **Credentials count inside the n8n instance** — not yet confirmed (no `n8n list:credentials` CLI command; deferred to Phase D's MCP-based credential listing).
14. **Exact next action:** Owner runs the §5 command above (placeholder key replaced with their real local development API key, in a terminal outside this repo/chat) and restarts Claude Code. Next session resumes at **Phase D**: reconnect `n8n-mcp`, run `tools_documentation()` to confirm all 15 `n8n_*` tools are present, run `n8n_health_check` and `n8n_list_workflows`/`n8n_executions`, then (Phase E, with owner approval) the disposable `DELETE_ME_ROUTE_A_VERIFICATION` workflow lifecycle, then Phase F's remaining credentials check. Until Phase D-F complete, the verdict remains **`ROUTE A BLOCKED — MCP WORKFLOW TOOLS UNAVAILABLE`** and **Prompt 3 must not begin**.

---

## Phase D — MCP reconnection verification (2026-06-11, continued — supersedes the verdict above)

A further session resumed **from Phase D only** per explicit instruction — Phase A-C, version pinning, and business-policy work were **not** repeated; Prompt 3 was **not** started; Instantly was **not** configured or called.

### Credential-exposure incident (resolved with owner decision)

The owner had configured `n8n-mcp` (user-scope) with `N8N_API_URL=http://localhost:5678` and a local development `N8N_API_KEY`, entered outside Claude Code as instructed. The first verification step, `claude mcp get n8n-mcp`, **printed the full `N8N_API_KEY` value in plaintext into this session's tool output** — this is `claude mcp get`'s normal behaviour (it dumps the full configured environment) and was not anticipated. This conflicts with the standing instruction that the key "must never be displayed, copied, logged, or written into this repository," because the value is now part of this session's local transcript.

- **No value was repeated, copied, or written anywhere by the agent.** Verified by a repository-wide grep for the key's JWT header prefix (`eyJhbGci`) — **zero matches** anywhere in the project.
- The owner was stopped and asked how to proceed. **Decision: continue now using only `n8n-mcp` tool calls (which redact the key, e.g. `"N8N_API_KEY": "***configured***"`), and rotate the key afterward** (regenerate in n8n Settings → API, update the `n8n-mcp` config outside Claude Code, restart Claude Code).
- **Recommendation for future sessions:** do not run `claude mcp get`/`claude mcp list` for `n8n-mcp` once an API key is configured — use `mcp__n8n-mcp__n8n_health_check(mode="diagnostic")` instead, which reports `N8N_API_KEY: "***configured***"` without revealing the value.
- This incident is **local to this machine's session transcript only** — no Instantly, production, or shared system was involved, and the key only authorises calls to the owner's own `127.0.0.1:5678` n8n instance.

### Phase D checks

1. **`n8n-mcp` connected:** `claude mcp get n8n-mcp` → `✔ Connected`. `N8N_API_URL=http://localhost:5678` and `N8N_API_KEY=***` (configured) confirmed present (value not reproduced — see incident above).
2. **Tool inventory (enumerated via tool search, all schemas loaded/callable):**
   - 7 documentation/node tools: `tools_documentation`, `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`.
   - 17 instance-management `n8n_*` tools, **all now present** (previously 0/15 were available): `n8n_create_workflow`, `n8n_get_workflow`, `n8n_update_full_workflow`, `n8n_update_partial_workflow`, `n8n_delete_workflow`, `n8n_list_workflows`, `n8n_validate_workflow`, `n8n_autofix_workflow`, `n8n_test_workflow`, `n8n_executions`, `n8n_health_check`, `n8n_workflow_versions`, `n8n_deploy_template`, `n8n_manage_datatable`, `n8n_generate_workflow`, `n8n_audit_instance`, `n8n_manage_credentials`.
   - **Total: 24 tools confirmed present.** Note: `n8n_health_check`'s own diagnostic output self-reports `"managementTools": {"count": 14}` and `"totalAvailable": 21` — this appears to be a **stale hardcoded count inside that diagnostic's code** (it predates `n8n_audit_instance`, `n8n_manage_credentials`, and possibly others), since the tool search and the actual tool invocations below prove more tools are loaded and functional. This is a documentation/self-report discrepancy in `n8n-mcp` itself, not a connectivity problem.
3. **Workflow-management tools present:** **YES** — confirmed via (2) above. **This resolves the prior `ROUTE A BLOCKED — MCP WORKFLOW TOOLS UNAVAILABLE` verdict.**
4. **`n8n_health_check(mode="diagnostic")` result:**
   - `apiConfiguration.configured: true`, `config.baseUrl: "http://localhost:5678"` (matches the Phase C-verified dev container; this is a non-secret config value).
   - `apiConfiguration.status.connected: false`, **`error: "SSRF protection: Localhost access is blocked in strict mode"`**.
   - `versionInfo.current: "2.57.3"` — this is the **`n8n-mcp` package's own npm version** (it checked itself against npm and reports up-to-date), **not** the n8n instance version. The n8n instance remains `2.25.7` per Phase C (not re-checked this session, per the "do not repeat Docker/provisioning" scope restriction).
   - **Result: FAILED** (health check ran, but reports not connected).
5. **`n8n_list_workflows()` result:** `{"success": false, "error": "SSRF protection: Localhost access is blocked in strict mode", "code": "REQUEST_ERROR"}`. **FAILED — same cause as #4.**
6. **`n8n_executions(action="list", limit=1)` result:** `{"success": false, "error": "SSRF protection: Localhost access is blocked in strict mode", "code": "REQUEST_ERROR"}`. **FAILED — same cause.**
7. **Connected instance identity:** `N8N_API_URL=http://localhost:5678` is configured (matches the Phase C dev container's port binding `127.0.0.1:5678`), but **n8n-mcp cannot complete a live API call to confirm reachability/identity** — every API call is rejected by n8n-mcp's own SSRF guard before it reaches n8n. **Not provable via MCP this session.**
8. **No business workflows / no active workflows:** **Not re-confirmed via MCP this session** (blocked by #5/#6). Phase C's non-MCP evidence (`docker exec hmz-n8n-local-dev n8n list:workflow` → empty, 0 workflows) stands but was not refreshed — per scope, Docker commands were not re-run this session.
9. **No secret values inspected/revealed by Phase D MCP calls themselves:** confirmed — `n8n_health_check` redacts the key as `"***configured***"`. The only exposure this session was the separate `claude mcp get` incident documented above.

### Root cause and verified fix for the SSRF blocker

`n8n-mcp` (≥ v2.16.3) ships SSRF protection on its own outbound HTTP client (used for all `n8n_*` API calls), controlled by the `WEBHOOK_SECURITY_MODE` environment variable:

| Mode | Behaviour |
| --- | --- |
| `strict` (default — current config) | Blocks RFC1918 private-network addresses **and localhost** |
| `moderate` | Allows localhost; still blocks RFC1918 and cloud metadata endpoints |
| `permissive` | Allows RFC1918 too (private networks only) |

Because `N8N_API_URL=http://localhost:5678`, the default `strict` mode blocks every `n8n_*` API call — exactly the `"SSRF protection: Localhost access is blocked in strict mode"` error seen in #4-#6. **Verified fix** (per the project's own published security advisory, read-only research, no Instantly/business content involved): set `WEBHOOK_SECURITY_MODE=moderate` on the `n8n-mcp` server config. This is the minimal setting that allows `localhost:5678` while still blocking RFC1918/cloud-metadata ranges (`permissive` is not needed and would be broader than necessary).

Source: [Authenticated SSRF in n8n-mcp webhook and API client paths · Advisory · czlonkowski/n8n-mcp · GHSA-cmrh-wvq6-wm9r](https://github.com/czlonkowski/n8n-mcp/security/advisories/GHSA-cmrh-wvq6-wm9r)

### Phase E — disposable workflow lifecycle: NOT attempted

Gated on Phase D's health check succeeding (it did not — #4). `n8n_create_workflow`/`n8n_get_workflow`/`n8n_validate_workflow`/`n8n_delete_workflow` would hit the **identical SSRF block** (same HTTP client, same `N8N_API_URL`). No owner approval was sought for Phase E since the precondition is unmet, and attempting it would only reproduce the same error with no useful new information.

### Phase F — final isolation checks (2026-06-11, Phase D)

| Check | Result |
| --- | --- |
| URL is `http://localhost:5678` | **Confirmed** — `n8n_health_check` diagnostic `config.baseUrl` (non-secret). |
| Docker binding remains `127.0.0.1:5678` | Carried forward from Phase C (unchanged) — **not re-verified this session** (no Docker commands run, per scope). |
| n8n version remains pinned to `2.25.7` | Carried forward from Phase C (unchanged) — `infrastructure/local-n8n/docker-compose.yml` not edited this session. |
| No tunnel or public route exists | Carried forward from Phase C (unchanged) — not re-checked this session. |
| No Instantly credential exists | **Blocked** — `n8n_manage_credentials` would hit the same SSRF error as #5/#6; not attempted. |
| No AI-provider credential exists | **Blocked** — same reason. |
| No email credential exists | **Blocked** — same reason. |
| No business workflow exists | Carried forward from Phase C (`n8n list:workflow` empty); **not refreshed via MCP this session** (blocked). |
| No active workflow exists | Carried forward from Phase C (0 workflows ⇒ 0 active); **not refreshed via MCP this session** (blocked). |
| Disposable workflow has been deleted | N/A — never created (Phase E not attempted). |
| No API key or secret appears anywhere in the repository | **True** — repo-wide grep for the exposed key's JWT prefix (`eyJhbGci`) returned zero matches. The four files matching `N8N_API_KEY=` all contain only the pre-existing `<key>`/`<your-local-dev-api-key-here>` placeholders. |
| `DRY_RUN=true` | Unchanged — no `.env` exists; documented default. |
| `LIVE_CAMPAIGNS` remains empty | Unchanged — `docs/VALIDATION_CAMPAIGN_CONFIG.md` §3 not touched this session. |

### Route A verification gates (2026-06-11, Phase D update — supersedes the 2026-06-11 table above)

| Gate | Status |
| --- | --- |
| n8n local instance starts successfully | Yes (carried forward from Phase C). |
| Owner login works | Yes (carried forward). |
| Local API key authentication works | **Not provable** — n8n-mcp is configured with the key, but its own SSRF guard rejects every request before n8n's auth layer is reached. |
| n8n MCP exposes workflow-management tools | **YES (NEW)** — all 17 `n8n_*` tools confirmed present and callable. Resolves the prior blocker. |
| MCP health check succeeds | **No** — `connected: false`, `"SSRF protection: Localhost access is blocked in strict mode"`. |
| Workflow listing succeeds (via MCP) | **No** — same SSRF error. |
| Execution listing succeeds (via MCP) | **No** — same SSRF error. |
| Disposable workflow create/get/validate/delete lifecycle succeeds | Not attempted — gated on health check; would hit the same SSRF block. |
| Disposable workflow no longer present | N/A — never created. |
| No workflow is active | Carried forward from Phase C (0 workflows); not refreshed via MCP. |
| No secret was written into the project | **True** — verified by repo-wide grep (see above). |
| No Instantly or external API call occurred | **True** — only one read-only fetch of `n8n-mcp`'s own public GitHub security advisory + one web search, both about MCP server configuration. |
| Non-production isolation documented | Mostly — instance-level isolation carried forward from Phase C; credentials-count check still blocked. |
| `DRY_RUN=true` | Unchanged — true. |
| `LIVE_CAMPAIGNS` remains empty | Unchanged — empty. |
| n8n version pinned | Carried forward (`2.25.7`) — not re-verified this session. |
| **NEW** — n8n-mcp API-key display incident | Occurred via `claude mcp get n8n-mcp`; key value not repeated/written anywhere (grep-verified); owner to rotate. |
| **NEW** — n8n-mcp SSRF protection blocks localhost | `WEBHOOK_SECURITY_MODE` defaults to `strict`; verified fix is `moderate` (see above). |

### Final verdict (2026-06-11, Phase D)

**`ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`**

1. **MCP connection result:** `✔ Connected`. `N8N_API_URL`/`N8N_API_KEY` now configured (Phase D's sole prior blocker is resolved). **Incident:** `claude mcp get n8n-mcp` displayed the full API key value in this session's transcript — see "Credential-exposure incident" above. No value was repeated/written anywhere (grep-verified); owner to rotate the key.
2. **Complete tool inventory:** 24 tools confirmed present and callable — 7 documentation/node tools + 17 `n8n_*` instance-management tools (full list above). `n8n_health_check`'s self-reported "21 total / 14 management" appears to be a stale internal count in `n8n-mcp` itself.
3. **Workflow-management tools present:** **YES** — resolves the prior `MCP WORKFLOW TOOLS UNAVAILABLE` verdict.
4. **MCP health-check result:** Ran successfully as a tool call, but reports `connected: false`, `error: "SSRF protection: Localhost access is blocked in strict mode"`. `n8n-mcp` package version `2.57.3` (the MCP tool's own version, not the n8n instance's `2.25.7`).
5. **Connected instance identity:** `N8N_API_URL=http://localhost:5678` configured (matches Phase C's dev container), but live confirmation is blocked by the SSRF guard.
6. **Initial workflow and execution counts:** Not obtainable via MCP this session (`n8n_list_workflows`/`n8n_executions` both fail with the SSRF error). Phase C's non-MCP count (0 workflows) stands but was not refreshed.
7. **Disposable workflow create/get/validate/delete result:** Not attempted — gated on #4; would reproduce the identical SSRF error.
8. **Final workflow and active-workflow counts:** N/A — Phase E not attempted, nothing created.
9. **Credential-category check without values:** Not performed — `n8n_manage_credentials` would hit the same SSRF block as #5/#6; not attempted.
10. **Secrets-handling result:** Phase D's own MCP tool calls redact the key (`"***configured***"`). The separate `claude mcp get` incident is documented above with its mitigation. Repo-wide grep confirms **zero** secret values written to any file.
11. **Files changed:**
    - Modified: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` (this file — new "Phase D" section, updated gates table and verdict).
    - Modified: `docs/ENVIRONMENT_AUDIT.md` (new Phase D update section).
    - Modified: `docs/ASSUMPTIONS_AND_UNKNOWNS.md` (A1/A2 updated with Phase D findings and the new SSRF sub-blocker).
    - Modified: `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` (new Phase D addendum; "Pick up here" item 0 updated).
    - No business-policy file touched. No `.env`, credential, or key file created or modified. `infrastructure/local-n8n/README.md` and `docker-compose.yml` **not** modified this session (README §5 should be updated next session to add `WEBHOOK_SECURITY_MODE=moderate` and the key-rotation step — out of scope for "update only" the four files above).
12. **Unresolved blockers:**
    - **New: n8n-mcp `WEBHOOK_SECURITY_MODE=strict` blocks all `n8n_*` API calls to `http://localhost:5678`.** Verified fix: `WEBHOOK_SECURITY_MODE=moderate`.
    - **New (incident, low severity): local dev API key was displayed in this session's transcript.** Owner to rotate (regenerate in n8n Settings → API).
    - **A3 (Instantly API key/plan tier)** — unchanged, still BLOCKED for live actions, still confirmed not to block Prompt 3's mocked-build scope.
    - Phase E (disposable lifecycle) and the remaining Phase F items (credentials-category check, fresh workflow/active counts) remain blocked pending the SSRF fix.
13. **Exact next action:** In **one** terminal session outside Claude Code, the owner: (a) regenerates the local development API key in n8n (Settings → API → revoke old, create new), then (b) runs `claude mcp remove n8n-mcp -s user` followed by `claude mcp add n8n-mcp -s user -e MCP_MODE=stdio -e LOG_LEVEL=error -e DISABLE_CONSOLE_OUTPUT=true -e N8N_API_URL=http://localhost:5678 -e N8N_API_KEY=<new-key> -e WEBHOOK_SECURITY_MODE=moderate -- npx n8n-mcp` (adding the new key and the new `WEBHOOK_SECURITY_MODE=moderate` variable in the same step), then (c) restarts Claude Code. The next session resumes Phase D by re-running `n8n_health_check(mode="diagnostic")`, `n8n_list_workflows()`, and `n8n_executions(action="list")`; if `connected: true` and 0 workflows are confirmed, proceed to Phase E (disposable `DELETE_ME_ROUTE_A_VERIFICATION` lifecycle, with owner approval) and the remaining Phase F items (`n8n_manage_credentials` category check). Until then, the verdict remains **`ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`** and **Prompt 3 must not begin**.

---

## Phase D retry — tool inventory regressed, health check cannot be invoked (2026-06-11, continued — supersedes the Phase D verdict above)

A further session resumed **from the failed health-check gate only**, per explicit instruction. Not repeated: WSL, Docker, container provisioning, n8n version pinning, business-policy review, source reconciliation, architecture design, Prompt 3. Not run: `claude mcp get n8n-mcp` or `claude mcp list` (standing prohibition — the owner reported a key rotation + reconfiguration this session, and these commands would re-expose the new key exactly as `claude mcp get` did the old one). Instantly was not configured or called.

### Owner-reported state at start of this session

The owner reported having: revoked the previously-exposed local n8n API key; created a replacement local-development API key; reconfigured `n8n-mcp` (user scope) with the new key; added `WEBHOOK_SECURITY_MODE=moderate`; retained `N8N_API_URL=http://localhost:5678`; restarted Claude Code.

### Phase D retry checks

1. **Tool inventory (ToolSearch, four independent queries):**
   - "n8n_health_check n8n_list_workflows n8n_executions workflow management" → only `validate_workflow`, `get_template`, `search_templates`, plus unrelated harness tools (`EnterPlanMode`, `EnterWorktree`, `TaskUpdate`). No `n8n_*` instance tools.
   - `select:mcp__n8n-mcp__n8n_health_check,mcp__n8n-mcp__n8n_list_workflows,mcp__n8n-mcp__n8n_executions,mcp__n8n-mcp__n8n_create_workflow,mcp__n8n-mcp__n8n_manage_credentials` → **"No matching deferred tools found"**.
   - "n8n instance API workflow create delete validate audit credentials manage" → only the 7 documentation/node tools + unrelated harness tools; no `n8n_*` instance tools.
   - `select:mcp__n8n-mcp__n8n_health_check` (bare) and "audit_instance manage_credentials workflow_versions deploy_template generate_workflow" → **"No matching deferred tools found"**.
   - **Conclusion: zero of the 17 `n8n_*` instance-management tools are present in this session's tool surface.** This matches the Phase 2.5/Phase C state (before Phase D's reconnection ever ran), not the prior Phase D session's reported 24-tool inventory.
2. **`tools_documentation()` (read-only, no `claude mcp get`):** returns the standard static reference. Confirms the `n8n-mcp` server process is connected and responding (the call succeeded). States the 15 `n8n_*` API tools "require N8N_API_URL configuration" — this is hardcoded reference text, not a live-config report, and does not by itself confirm whether `N8N_API_URL` is currently set.
3. **`ListMcpResourcesTool(server="n8n-mcp")`:** returns exactly two generic UI resources (`ui://n8n-mcp/operation-result`, `ui://n8n-mcp/validation-summary`) — both static MCP "resources" (UI templates) unrelated to instance configuration. No config/connection info obtainable this way.
4. **`n8n_health_check(mode="diagnostic")`:** **could not be run — the tool is not present in this session** (confirmed by step 1's exact-name lookup). This is the retry's primary blocked check.
5. **`n8n_list_workflows()`:** **could not be run** — same reason.
6. **`n8n_executions(action="list")`:** **could not be run** — same reason.
7. **Workflow/active-workflow counts:** **not obtainable via MCP this session** (no tool available). Phase C's non-MCP count (0 workflows, via `docker exec ... n8n list:workflow`) was not refreshed — Docker commands were out of scope for this retry.

### Secrets-handling checks (read-only, safe alternatives to `claude mcp get`/`claude mcp list`)

- Repo-wide grep for the previously-exposed key's JWT header prefix (`eyJhbGci`): **1 match**, in this file (`reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md`). Inspected: the match is this report's own Phase D prose *describing* that earlier grep ("...repository-wide grep for the key's JWT header prefix (`eyJhbGci`) — **zero matches**...") — i.e. the search pattern itself appears as documentation text, not a reproduced key. **No new exposure.**
- Grep for `N8N_API_KEY|N8N_API_URL|WEBHOOK_SECURITY_MODE` across the repository: all matches are in documentation/config-instruction files (`docs/ENVIRONMENT_AUDIT.md`, `docs/ASSUMPTIONS_AND_UNKNOWNS.md`, `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md`, `reports/PHASE_2_5_*`, `reports/PHASE_2_6_*`, `infrastructure/local-n8n/README.md`), and every instance is either a placeholder (`<key>`, `<new-key>`, `<your-local-dev-api-key-here>`) or a description of the variable name — no real key value, and the only URL value is the already-documented non-secret `http://localhost:5678`.
- `.env*` glob (project root): **no files found**. `DRY_RUN=true` remains the documented default (`CLAUDE.md` rule #5, no `.env` override exists). `LIVE_CAMPAIGNS` registry not touched this session (`docs/VALIDATION_CAMPAIGN_CONFIG.md` §3 not read/edited).

### Why the connectivity check could not proceed

The retry instructions required confirming `n8n-mcp` is connected and that workflow-management tools remain available **without using `claude mcp get`**. The only available read-only signals (ToolSearch, `tools_documentation()`, `ListMcpResourcesTool`) show the `n8n-mcp` server process itself is reachable, but its `n8n_*` tool surface — which the documentation says is gated on `N8N_API_URL` configuration — is identical to the **pre-Phase-D** state (7 tools only). This is the same observable symptom as "no `N8N_API_URL`/`N8N_API_KEY` configured for this session's `n8n-mcp` connection", but the cause cannot be confirmed without `claude mcp get` (prohibited) or `claude mcp list` (same risk, not attempted). Plausible causes, in no particular order:

- The owner's `claude mcp remove`/`claude mcp add` reconfiguration command did not complete successfully (e.g. a typo, wrong scope, or an error that was not visible).
- Claude Code was not **fully** restarted (all windows/processes closed and reopened) after the reconfiguration — stdio MCP servers are spawned once at process start, so a session whose underlying Claude Code process predates the config change would still see the old (no-`N8N_API_URL`) config.
- This conversation/session is a continuation that predates the restart, even though a `/mcp` command was run during it.

None of these can be distinguished from inside this session without the prohibited commands.

### Phase E and Phase F — not attempted

Both are gated on Phase D's health check succeeding (it could not even be invoked). Per the retry instructions ("Stop immediately with the appropriate blocked verdict if the health check or API calls fail"), Phase E's disposable-workflow lifecycle and Phase F's final isolation verification were **not attempted**. No owner approval was sought for Phase E since its precondition is unmet.

### Route A verification gates (2026-06-11, Phase D retry — supersedes the Phase D table above for connectivity status)

| Gate | Status |
| --- | --- |
| n8n-mcp server process connected | **Yes** — `tools_documentation()` succeeded. |
| n8n MCP exposes workflow-management tools | **No (regressed)** — 0 of 17 `n8n_*` tools found via ToolSearch (4 query variants, including exact-name lookups), vs. 17/17 in the prior Phase D session. |
| MCP health check succeeds | **No — could not be invoked** (`n8n_health_check` not present in this session's tool surface). |
| Workflow listing succeeds (via MCP) | **No — could not be invoked** (`n8n_list_workflows` not present). |
| Execution listing succeeds (via MCP) | **No — could not be invoked** (`n8n_executions` not present). |
| Disposable workflow create/get/validate/delete lifecycle succeeds | Not attempted — gated on health check; precondition unmet. |
| Disposable workflow no longer present | N/A — never created. |
| No workflow is active | Not refreshed via MCP this session (no tool available). Phase C's non-MCP count (0) carried forward, not re-verified. |
| No secret was written into the project | **True** — repo-wide grep for the prior key's JWT prefix returns only the report's own descriptive text (verified); placeholder-only matches for `N8N_API_KEY`/`N8N_API_URL`/`WEBHOOK_SECURITY_MODE`. |
| No Instantly or external API call occurred | **True** — only ToolSearch, `tools_documentation()`, `ListMcpResourcesTool`, and local read-only file/grep/glob operations were performed. |
| `claude mcp get`/`claude mcp list` not run | **True** — neither was run, per the standing prohibition. |
| Non-production isolation documented | Carried forward from Phase C/D (instance-level isolation), not re-verified — Docker/credentials checks remain blocked. |
| `DRY_RUN=true` | Unchanged — true (no `.env` exists). |
| `LIVE_CAMPAIGNS` remains empty | Unchanged — not touched this session. |

### Final verdict (2026-06-11, Phase D retry)

**`ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`**

1. **MCP connection result:** The `n8n-mcp` server process is connected and responding (`tools_documentation()` succeeded). `claude mcp get`/`claude mcp list` were **not** run, per the standing prohibition — live env configuration cannot be inspected from this session.
2. **Health-check result:** **`n8n_health_check` is not present in this session's tool surface** — it cannot be invoked at all. This is a regression from the prior Phase D session, where the tool was present and returned `connected: false` (SSRF). The health check therefore fails at an earlier stage than before.
3. **Workflow-management tool availability:** **0 of 17 `n8n_*` tools** found (four ToolSearch query variants, including exact-name `select:` lookups for `n8n_health_check`, `n8n_list_workflows`, `n8n_executions`, `n8n_create_workflow`, `n8n_manage_credentials` — all returned "No matching deferred tools found"). Only the same 7 documentation/node tools as the pre-Phase-D state are available.
4. **Initial workflow and execution counts:** Not obtainable via MCP this session (no tool available). Phase C's non-MCP count (0 workflows) carried forward, not refreshed.
5. **Disposable workflow create/get/validate/delete result:** Not attempted — gated on #2; precondition unmet, no owner approval sought.
6. **Final workflow and active-workflow counts:** N/A — Phase E not attempted.
7. **SSRF mode used:** Cannot be confirmed this session — `n8n_health_check`'s diagnostic output (which previously reported the SSRF/connection status) is unavailable. The owner reports `WEBHOOK_SECURITY_MODE=moderate` was added; not independently verifiable without the prohibited commands.
8. **Credential-category check without values:** Not performed — `n8n_manage_credentials` is not present in this session's tool surface.
9. **Confirmation old key revoked:** Owner-reported, not independently verifiable from within this session (no API access to n8n's credential/API-key management, and `claude mcp get`/`list` prohibited).
10. **Secrets-handling result:** Clean. Repo-wide grep for the prior key's JWT prefix (`eyJhbGci`) returns one match — confirmed to be this report's own descriptive prose, not a reproduced key. Grep for `N8N_API_KEY`/`N8N_API_URL`/`WEBHOOK_SECURITY_MODE` finds only documentation/placeholders. `.env*` — no files. No secret was requested, displayed, or written this session. `claude mcp get`/`claude mcp list` were not run.
11. **Files changed:**
    - Modified: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` (this file — new "Phase D retry" section, updated gates table and verdict).
    - Modified: `docs/ENVIRONMENT_AUDIT.md` (new "Phase 2.6 Phase D retry" section).
    - Modified: `docs/ASSUMPTIONS_AND_UNKNOWNS.md` (A1/A2 updated to reflect the regressed/unconfirmed tool availability).
    - Modified: `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` (new "Phase D retry" addendum; "Pick up here" item 0 and the Route A open-question bullet updated).
    - No business-policy file touched. No `.env`, credential, or key file created or modified. `infrastructure/local-n8n/docker-compose.yml` and `infrastructure/local-n8n/README.md` not modified this session (no Docker/provisioning work, per scope).
12. **Unresolved blockers:**
    - **New: the `n8n_*` workflow-management tool surface (17 tools) is absent in this session, where the immediately-prior session reported all 17 present.** Cause not confirmed (cannot use `claude mcp get`/`claude mcp list`). Most likely an incomplete reconfiguration or a Claude Code restart that this session does not reflect.
    - A2's SSRF sub-blocker (`WEBHOOK_SECURITY_MODE=moderate` fix) **cannot be verified** this session — the tools needed to test it are absent.
    - A3 (Instantly API key/plan tier) — unchanged, still BLOCKED for live actions, still confirmed not to block Prompt 3's mocked-build scope.
    - Phase E and the remaining Phase F items remain blocked, now pending **both** the original SSRF fix verification **and** restoration of the `n8n_*` tool surface.
13. **Exact next action:** Outside Claude Code, the owner re-confirms (without displaying values) that the `n8n-mcp` user-scope MCP server config includes `N8N_API_URL=http://localhost:5678`, the new `N8N_API_KEY`, and `WEBHOOK_SECURITY_MODE=moderate` — by re-running the idempotent `claude mcp remove n8n-mcp -s user` then `claude mcp add n8n-mcp -s user -e MCP_MODE=stdio -e LOG_LEVEL=error -e DISABLE_CONSOLE_OUTPUT=true -e N8N_API_URL=http://localhost:5678 -e N8N_API_KEY=<rotated-key> -e WEBHOOK_SECURITY_MODE=moderate -- npx n8n-mcp` command (safe to re-run). Then **fully quit all Claude Code windows/processes** (not just this session) and start a brand-new session in this project directory. In that new session, before doing anything else, re-run this Phase D retry's tool-inventory check (ToolSearch / exact-name lookup for `mcp__n8n-mcp__n8n_health_check`); if the 17 `n8n_*` tools are now present, proceed with `n8n_health_check(mode="diagnostic")`, `n8n_list_workflows()`, `n8n_executions(action="list")`, and — only if those succeed with `connected: true` and 0 workflows — Phase E (disposable `DELETE_ME_ROUTE_A_VERIFICATION` lifecycle, with owner approval) and the remaining Phase F items. If the tools are still absent after a full restart, the owner should additionally check the in-app `/mcp` dialog (Claude Code's built-in MCP status UI, which shows connection status without dumping env vars to the transcript) for `n8n-mcp`'s reported state. Until then, the verdict remains **`ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`** and **Prompt 3 must not begin**.

---

## Phase 2.6 Gate 1-2 — project-scoped `.mcp.json`, SSRF blocker resolved, new `NO_RESPONSE` blocker (2026-06-11, continued — supersedes the Phase D retry verdict above)

A further session ran **Phase 2.6 verification only** (a fixed Gate 1-4 script), per explicit instruction. Not repeated: MCP configuration, Docker provisioning, WSL setup, n8n installation, business-policy review, architecture work; Prompt 3 not started. Not run: `claude mcp get`/`claude mcp list`, any command printing MCP environment variables, or anything revealing `HMZ_N8N_API_KEY`.

### Owner-side change since the Phase D retry

The owner replaced the user-scoped `n8n-mcp` MCP configuration with a project-scoped `.mcp.json` (read this session, contains only `${HMZ_N8N_API_KEY}` as an unresolved placeholder reference — see "Secrets-handling" below). It sets `N8N_API_URL=http://localhost:5678`, `N8N_API_KEY=${HMZ_N8N_API_KEY}`, `WEBHOOK_SECURITY_MODE=moderate`.

### Gate 1 — Tool surface: PASS

Two ToolSearch queries (an exact-name `select:` lookup for the six gate-required tools, plus a broad keyword search) both returned full, callable schemas. **24 tools total — matches the inventory the prior (non-retry) Phase D session reported but the retry could not reproduce. This resolves that regression.**

- 17 `n8n_*` instance-management tools, all present and schema-loaded: `n8n_health_check`, `n8n_list_workflows`, `n8n_get_workflow`, `n8n_create_workflow`, `n8n_delete_workflow`, `n8n_executions`, `n8n_audit_instance`, `n8n_validate_workflow`, `n8n_manage_credentials`, `n8n_workflow_versions`, `n8n_autofix_workflow`, `n8n_test_workflow`, `n8n_update_full_workflow`, `n8n_update_partial_workflow`, `n8n_deploy_template`, `n8n_generate_workflow`, `n8n_manage_datatable`.
- Plus the 7 always-available documentation/node tools (`tools_documentation`, `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`) — `search_nodes`, `validate_node`, `validate_workflow`, `search_templates`, `get_template` were directly returned by the broad query this session; `tools_documentation`/`get_node` carried forward as previously verified present.

### Gate 2 — API connection: FAIL (new error; SSRF blocker resolved)

1. `n8n_health_check(mode="diagnostic")`:
   - `apiConfiguration.configured: true`, `config.baseUrl: "http://localhost:5678"` (non-secret, matches the Phase C dev container).
   - `apiConfiguration.status.connected: false`, **`error: "No response from n8n server"`**, `version: null`.
   - `environment.N8N_API_KEY: "***configured***"` (redacted as expected — no value displayed).
   - `versionInfo.current/latest: "2.57.3"` — `n8n-mcp`'s own npm self-check, not the n8n instance version.
   - `toolsAvailability`: `documentationTools.count: 7`, `managementTools.count: 14`, `totalAvailable: 21` — same stale internal self-report noted previously; the actual surface has 17 management + 7 doc = 24 (Gate 1).
   - **Result: FAILED**, but the error has changed from the prior session's `"SSRF protection: Localhost access is blocked in strict mode"` to **`"No response from n8n server"`**. **The SSRF blocker is resolved** — `WEBHOOK_SECURITY_MODE=moderate` is verified working; a different, later-stage connectivity failure now blocks the same call.
2. `n8n_list_workflows()`: `{"success": false, "error": "Unable to connect to n8n. Please check the server URL and ensure n8n is running.", "code": "NO_RESPONSE"}`. **FAILED — same cause as #1.**
3. `n8n_executions(action="list", limit=1)`: identical error and code. **FAILED — same cause.**

Per the gate's "stop and report the exact redacted error" instruction, **Gate 3 (disposable lifecycle) and the API-dependent parts of Gate 4 were not attempted.**

### Read-only diagnostic context (status checks only — not Docker provisioning)

- `docker ps -a --filter "name=hmz-n8n-local-dev"`: container **running**, `Up 3 hours`, image `docker.n8n.io/n8nio/n8n:2.25.7` (matches the pinned Compose file), port `127.0.0.1:5678->5678/tcp`.
- `Get-NetTCPConnection -LocalPort 5678`: `Listen` on `127.0.0.1:5678` (plus `TimeWait`/`FinWait2`/`Established` entries, all `127.0.0.1` — no `0.0.0.0`/`::` listener).

The container is up, pinned to the expected version, and the port is listening/locally reachable at the TCP level — yet `n8n-mcp`'s HTTP client gets no response. **Root cause not diagnosed further this session** (would require either an MCP-configuration change or deeper network investigation, both out of scope). One **unverified** hypothesis for the owner to consider: Node (`v24.15.0`, Windows) may resolve `localhost` to IPv6 `::1` ahead of IPv4, but Docker Desktop published the port on `127.0.0.1` (IPv4) only — if `n8n-mcp`'s HTTP client tries `::1:5678` with no fallback, every request would fail with no response despite `127.0.0.1:5678` being reachable. Other possibilities (e.g. an n8n-side issue, or an API-key/permissions problem manifesting as a dropped connection rather than a 401) are equally plausible and were not distinguished. **No configuration change was attempted.**

### Gate 4 — partial (file/local checks only; API-dependent items blocked by Gate 2)

| Check | Result |
| --- | --- |
| n8n URL remains localhost | **Confirmed** — `config.baseUrl: "http://localhost:5678"` (health-check diagnostic, non-secret) and Docker port binding. |
| Docker remains bound to `127.0.0.1:5678` | **Confirmed** — `docker ps` + `Get-NetTCPConnection` (all entries `127.0.0.1`, no `0.0.0.0`/`::`). |
| n8n remains pinned to `2.25.7` | **Confirmed** — `docker ps` image tag; `infrastructure/local-n8n/docker-compose.yml` unchanged. |
| n8n-mcp remains pinned to `2.57.3` | **Confirmed** — `.mcp.json` (`n8n-mcp@2.57.3`); health-check `versionInfo.current: "2.57.3"`. |
| SSRF mode is `moderate`, not disabled | **Confirmed** — `.mcp.json` sets `WEBHOOK_SECURITY_MODE=moderate`; behaviourally consistent (the prior SSRF-specific error no longer occurs — see Gate 2). |
| No public tunnel exists | **Confirmed** — no `ngrok`/`cloudflared`/`localtunnel` process found. |
| No Instantly, AI, email, or production credentials exist in n8n | **Not verified** — `n8n_manage_credentials` would hit the same `NO_RESPONSE` error; not attempted. |
| No business workflow exists | **Not re-verified via MCP** — Phase C's non-MCP count (0 workflows) carried forward, not refreshed this session. |
| No active workflow exists | **Not re-verified via MCP** — same as above. |
| Disposable workflow was deleted | **N/A** — never created (Gate 3 not attempted, gated on Gate 2). |
| No API key exists in the repository | **Confirmed** — `.mcp.json` contains only `${HMZ_N8N_API_KEY}` (read this session); repo-wide grep for `N8N_API_KEY`/`eyJhbGci` matches only 7 known documentation/config files, all placeholder/variable-name references (no values displayed). |
| `.mcp.json` contains only `${HMZ_N8N_API_KEY}` | **Confirmed** — read this session (`"N8N_API_KEY": "${HMZ_N8N_API_KEY}"`). |
| `DRY_RUN=true` | **Confirmed (default)** — no `.env*` file exists (glob, project root); `CLAUDE.md` rule #5 documents this as the default. |
| `LIVE_CAMPAIGNS` remains empty | **Carried forward, not re-verified** — `docs/VALIDATION_CAMPAIGN_CONFIG.md` not read/touched this session (business-policy file, out of scope). |

### Route A verification gates (2026-06-11, Gate 1-2 update — supersedes the Phase D retry table above for tool-availability and connectivity status)

| Gate | Status |
| --- | --- |
| n8n-mcp connected via project-scoped `.mcp.json` | **Yes (NEW)** — both ToolSearch queries returned live schemas. |
| n8n MCP exposes workflow-management tools | **YES (regression resolved)** — 17/17 `n8n_*` tools + 7 doc tools = 24 total, confirmed present. |
| MCP health check succeeds | **No** — `connected: false`, `error: "No response from n8n server"` (NEW error — SSRF blocker resolved). |
| SSRF mode permits localhost | **Yes (NEW)** — `WEBHOOK_SECURITY_MODE=moderate` confirmed in `.mcp.json`; the SSRF-specific error no longer occurs. |
| Workflow listing succeeds (via MCP) | **No** — `NO_RESPONSE`. |
| Execution listing succeeds (via MCP) | **No** — `NO_RESPONSE`, same cause. |
| Local n8n container running, pinned, localhost-only | **Yes** — `docker ps`/`Get-NetTCPConnection` (read-only checks, this session). |
| Disposable workflow create/get/validate/delete lifecycle succeeds | Not attempted — gated on Gate 2; precondition unmet. |
| Disposable workflow no longer present | N/A — never created. |
| No secret was written into the project | **True** — `.mcp.json` placeholder-only; repo-wide grep clean. |
| No Instantly or external API call occurred | **True** — only `n8n-mcp` tool calls (to `localhost:5678`) and local read-only Docker/file checks. |
| `claude mcp get`/`claude mcp list` not run | **True** — neither was run, per the standing instruction. |
| `DRY_RUN=true` | Unchanged — true (no `.env*` exists). |
| `LIVE_CAMPAIGNS` remains empty | Carried forward, not re-verified this session. |

### Final verdict (2026-06-11, Gate 1-2)

**`ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`**

1. **MCP tool count and tool names:** 24 tools — 7 documentation/node tools + 17 `n8n_*` instance-management tools (full list above). **Gate 1 PASSES** — resolves the Phase D retry's regression.
2. **Health-check result:** `n8n_health_check(mode="diagnostic")` ran successfully as a tool call; `apiConfiguration.status.connected: false`, `error: "No response from n8n server"`. A **new, different** error from the prior session's SSRF block — the SSRF fix (`WEBHOOK_SECURITY_MODE=moderate`) is verified working.
3. **Initial workflow and execution counts:** Not obtainable via MCP — `n8n_list_workflows`/`n8n_executions` both return `{"success": false, "error": "Unable to connect to n8n...", "code": "NO_RESPONSE"}`. Phase C's non-MCP count (0 workflows) carried forward, not refreshed via Docker exec this session (only `docker ps`/netstat status checks were run).
4. **Disposable workflow lifecycle result:** Not attempted — gated on Gate 2; precondition unmet; no owner approval sought.
5. **Final workflow and active-workflow counts:** N/A — Gate 3 not attempted.
6. **SSRF mode:** `moderate` (per `.mcp.json`) — confirmed effective (the SSRF-specific error no longer occurs).
7. **n8n and n8n-mcp pinned versions:** n8n `2.25.7` (`docker ps`, unchanged from Phase C); n8n-mcp `2.57.3` (`.mcp.json` and health-check `versionInfo.current`).
8. **Secret-reference verification:** `.mcp.json` contains only `${HMZ_N8N_API_KEY}` (read this session) — not a literal value. Repo-wide grep for `N8N_API_KEY`/`eyJhbGci` returns only the 7 already-known documentation/config files, all placeholder/variable-name references; no value displayed or written. `claude mcp get`/`claude mcp list` were **not** run.
9. **Files changed:** this report + `docs/ENVIRONMENT_AUDIT.md`, `docs/ASSUMPTIONS_AND_UNKNOWNS.md`, `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md`. No business-policy file touched. No `.env`, credential, or key file created/modified. `infrastructure/local-n8n/docker-compose.yml`/`README.md` not modified this session.
10. **Unresolved blockers:**
    - **New: `n8n-mcp` cannot get a response from the n8n API at `http://localhost:5678` (`NO_RESPONSE`), even though the container is running, pinned to `2.25.7`, and the port is listening on `127.0.0.1:5678`.** The prior SSRF blocker is resolved. Root cause not diagnosed (IPv6/IPv4 `localhost`-resolution mismatch is one unverified hypothesis among several).
    - A3 (Instantly API key/plan tier) — unchanged, still BLOCKED for live actions, still confirmed not to block Prompt 3's mocked-build scope.
    - Gate 3 (disposable lifecycle) and the API-dependent Gate 4 items remain blocked pending a Gate-2 fix.
11. **Exact next action:** Outside this session, the owner investigates why `n8n-mcp` (Node `v24.15.0`, Windows, `N8N_API_URL=http://localhost:5678`) gets no HTTP response from a container confirmed running and listening on `127.0.0.1:5678`. As a **diagnostic only** (not performed this session): browse to `http://localhost:5678/healthz` from the same Windows machine to confirm the API responds outside `n8n-mcp`. If that works, the owner may consider whether `N8N_API_URL=http://127.0.0.1:5678` (explicit IPv4) in `.mcp.json` resolves an IPv6/IPv4 `localhost`-resolution mismatch — this is an MCP-configuration change and is **deferred to a future session**, not performed now. Once `n8n_health_check` reports `connected: true` with a non-null `version`, re-run Gate 2 (`n8n_list_workflows`, `n8n_executions`) — expect 0 workflows — then proceed to Gate 3 (disposable `DELETE_ME_ROUTE_A_VERIFICATION` lifecycle, with owner approval) and the remaining Gate 4 items. Until then, the verdict remains **`ROUTE A BLOCKED — MCP HEALTH CHECK FAILED`** and **Prompt 3 must not begin**.

---

## Phase 2.6 Gate 2-3 — API connection succeeds, disposable lifecycle complete (2026-06-11, continued — supersedes the Gate 1-2 verdict above)

A further session ran **Gate 2 and Gate 3 only**, per explicit instruction. Not repeated: any previous environment, Docker, MCP setup, business-policy, architecture, or source-review work; Prompt 3 was not started. Not run: `claude mcp get`/`claude mcp list`, any command printing environment variables, or anything that could expose `HMZ_N8N_API_KEY`.

### Owner-side change since the Gate 1-2 session

The owner independently verified from PowerShell that `http://localhost:5678/healthz`, `http://127.0.0.1:5678/healthz`, and `http://127.0.0.1:5678/healthz/readiness` all return HTTP 200, and that authenticated requests to both `http://localhost:5678/api/v1/workflows?limit=1` and `http://127.0.0.1:5678/api/v1/workflows?limit=1` succeed with an empty workflow collection. The project `.mcp.json` was updated to `N8N_API_URL=http://127.0.0.1:5678` (read this session — confirmed; was `http://localhost:5678` in the Gate 1-2 session).

### Gate 2 — API connection: PASS (resolves the `NO_RESPONSE` blocker)

1. **Tool surface (re-confirmed):** Two ToolSearch queries — an exact-name `select:` lookup for the 9 most relevant `n8n_*` tools, plus a broad keyword search — both returned full, callable schemas. All 24 tools (7 documentation/node + 17 `n8n_*` instance-management) confirmed present and loadable.
2. **`n8n_health_check(mode="diagnostic")`:**
   - `apiConfiguration.configured: true`, `apiConfiguration.status.connected: true`, `error: null`.
   - `config.baseUrl: "http://127.0.0.1:5678"` (matches the updated `.mcp.json`, non-secret).
   - `environment.N8N_API_URL: "http://127.0.0.1:5678"`, `environment.N8N_API_KEY: "***configured***"` (redacted, no value displayed).
   - `apiConfiguration.status.version: "unknown"` — n8n's `/api/v1` health response does not expose a version field; the instance remains pinned to `2.25.7` per Phase C's Docker-based verification (not re-checked this session, out of scope).
   - `versionInfo.current/latest: "2.57.3"` — `n8n-mcp`'s own npm self-check (matches `.mcp.json`'s pin).
   - `toolsAvailability`: still self-reports the stale `documentationTools.count: 7, managementTools.count: 14, totalAvailable: 21` — same known internal-count discrepancy noted in the Gate 1-2 session; the actual loadable surface is 24 (confirmed in #1).
   - **Result: PASS.** This is a **new, successful** result — the prior `"No response from n8n server"` / `code: "NO_RESPONSE"` error no longer occurs. Switching `N8N_API_URL` from `http://localhost:5678` to `http://127.0.0.1:5678` is the change that coincides with this fix (consistent with the IPv4/IPv6 `localhost`-resolution hypothesis recorded in the Gate 1-2 session, though no isolated A/B test of that specific variable was performed this session).
3. **`n8n_list_workflows(limit=10)`:** `{"workflows": [], "returned": 0, "nextCursor": null, "hasMore": false}`. **PASS — 0 workflows.**
4. **`n8n_executions(action="list", limit=1)`:** `{"executions": [], "returned": 0, "nextCursor": null, "hasMore": false}`. **PASS — 0 executions.**
5. **API connection confirmed:** `connected: true` (item 2). **Gate 2 PASSES.**
6. **Zero business workflows / zero active workflows:** `n8n_list_workflows()` returns 0 workflows total ⇒ 0 active. **Confirmed.**

### Gate 3 — disposable workflow lifecycle: PASS

Owner approval was requested and granted (via `AskUserQuestion`) before any workflow was created, per the gate's instruction.

1. **Node-type verification (per `CLAUDE.md` rule #1 — n8n MCP first):** `get_node(nodes-base.manualTrigger, mode="info")` → `n8n-nodes-base.manualTrigger`, `typeVersion: 1`, `hasCredentials: true` (capability flag only — no credential was attached). `get_node(nodes-base.stickyNote, mode="info")` → `n8n-nodes-base.stickyNote`, `typeVersion: 1`, required props `height`/`width`/`color`/`content` (all defaulted/filled).
2. **`n8n_create_workflow`:** created `DELETE_ME_ROUTE_A_VERIFICATION` (id `LOCDmrLsxfmlHDnY`) with exactly two nodes — one `n8n-nodes-base.manualTrigger` (typeVersion 1, no parameters, no credentials) and one `n8n-nodes-base.stickyNote` (typeVersion 1, content identifying it as disposable Route A verification, no credentials) — and `connections: {}`. Result: `{"success": true, "active": false, "nodeCount": 2}`. No HTTP Request, Code, Webhook, or email node; no credentials; not activated.
3. **`n8n_get_workflow(id, mode="full")`:** retrieved successfully. `"active": false` (**confirmed inactive**). Neither node nor the workflow object contains a `credentials` field (**confirmed no credential references**). `connections: {}`, `tags: []`, owned by the personal project of `<LOCAL_N8N_OWNER_EMAIL>` (project metadata only — no secret).
4. **`n8n_validate_workflow(id)`:** ran successfully. `valid: false`, one error: `"Multi-node workflow has no connections. Nodes must be connected to create a workflow."` — this is the validator counting the Sticky Note as a node requiring a `main` connection from/to the Manual Trigger; it is a **known artifact** for trigger + sticky-note-only workflows (sticky notes are visual annotations, never wired into `connections` in real n8n usage) and is **not** a credential, security, or activation issue. Reported verbatim per the gate's "validate it" step; not worked around (would have required adding a third node, which the gate explicitly disallows).
5. **`n8n_delete_workflow(id)`:** `{"success": true, "deleted": true}`.
6. **`n8n_list_workflows(limit=10)` (re-run):** `{"workflows": [], "returned": 0, "hasMore": false}` — **disposable workflow confirmed no longer present.**
7. **Not executed** — `n8n_test_workflow` / manual-trigger execution was never invoked, per the gate's "Do not execute it" instruction.

### Secrets-handling check (this session)

- `.env*` glob (project root): **no files found** — `DRY_RUN=true` remains the documented default (`CLAUDE.md` rule #5).
- Repo-wide grep for `N8N_API_KEY|eyJhbGci`: **7 files matched** — `.mcp.json` (placeholder `${HMZ_N8N_API_KEY}` only, read this session) plus the same 6 documentation/report files identified in prior sessions (`docs/SESSION_HANDOFF_PHASE_2_CURRENT.md`, `docs/ASSUMPTIONS_AND_UNKNOWNS.md`, `docs/ENVIRONMENT_AUDIT.md`, this report, `infrastructure/local-n8n/README.md`, `reports/PHASE_2_5_MCP_AND_ENVIRONMENT_AUDIT.md`), all previously confirmed placeholder/descriptive-text only. No new file matched. `claude mcp get`/`claude mcp list` were **not** run this session.

### Route A verification gates (2026-06-11, Gate 2-3 update — supersedes the Gate 1-2 table above)

| Gate | Status |
| --- | --- |
| n8n-mcp connected, 24 tools present | **Yes** — confirmed via ToolSearch, this session. |
| MCP API connection (`N8N_API_URL=http://127.0.0.1:5678`) | **YES (NEW)** — `connected: true`, `error: null`. The `NO_RESPONSE` blocker is resolved. |
| Workflow listing succeeds (via MCP) | **Yes** — 0 workflows. |
| Execution listing succeeds (via MCP) | **Yes** — 0 executions. |
| Disposable workflow create/get/validate/delete lifecycle succeeds | **YES (NEW)** — all steps completed; validation returned one expected sticky-note-connection finding (non-blocking, documented). |
| Disposable workflow no longer present | **Yes** — `n8n_list_workflows()` empty after deletion. |
| No workflow is active | **Yes** — 0 workflows ⇒ 0 active. |
| No secret was written into the project | **True** — `.mcp.json` placeholder-only; repo-wide grep clean (7 known files, no new exposure). |
| No Instantly or external API call occurred | **True** — only `n8n-mcp` tool calls to `127.0.0.1:5678` (the owner's own local dev instance) and local read-only file/grep/glob checks. |
| `claude mcp get`/`claude mcp list` not run | **True**. |
| n8n local container running, pinned, localhost-only | Carried forward from Phase C / Gate 1-2 (`2.25.7`, `127.0.0.1:5678` only) — **not re-verified via Docker this session** (out of scope); the owner's independently-reported `/healthz`/`/healthz/readiness`/`/api/v1/workflows` checks on both `localhost` and `127.0.0.1` this session are consistent with this and with no regression. |
| SSRF mode `moderate` | Carried forward (`.mcp.json`, unchanged) — behaviourally consistent (no SSRF error). |
| `DRY_RUN=true` | **Confirmed (default)** — no `.env*` file exists (glob, this session). |
| `LIVE_CAMPAIGNS` remains empty | Carried forward, not re-verified this session (`docs/VALIDATION_CAMPAIGN_CONFIG.md` not in this session's read-only file list). |

### Final verdict (2026-06-11, Gate 2-3)

**`ROUTE A READY FOR PROMPT 3`**

1. **MCP connection result:** `connected: true`, `error: null`, `config.baseUrl: "http://127.0.0.1:5678"`. Resolves the prior `NO_RESPONSE` blocker.
2. **Complete tool inventory:** 24 tools confirmed present and callable (7 doc + 17 `n8n_*`).
3. **Health-check result:** PASS (`connected: true`). `version: "unknown"` is an n8n API response-shape limitation, not a connectivity problem; the instance's actual version (`2.25.7`) was independently pinned and verified in Phase C and is unchanged (Compose file not modified).
4. **Initial workflow and execution counts:** 0 workflows, 0 executions (both via MCP, this session).
5. **Disposable workflow create/get/validate/delete result:** All steps PASS. Created inactive, no credentials, retrieved and confirmed inactive with no credential references, validated (one expected non-blocking sticky-note-connection finding, documented above), deleted, and confirmed no longer present. Never executed.
6. **Final workflow and active-workflow counts:** 0 workflows, 0 active (after deletion).
7. **SSRF mode:** `moderate` (per `.mcp.json`, unchanged) — behaviourally consistent (no SSRF error).
8. **`N8N_API_URL` change:** `.mcp.json` now uses `http://127.0.0.1:5678` (was `http://localhost:5678`). This change, made by the owner outside this session, coincides with the resolution of the `NO_RESPONSE` blocker.
9. **Secrets-handling result:** Clean. `.mcp.json` contains only `${HMZ_N8N_API_KEY}` (placeholder, read this session). Repo-wide grep for `N8N_API_KEY`/`eyJhbGci` returns only the 7 already-known documentation/config files, all placeholder/descriptive references. `.env*` — no files. `claude mcp get`/`claude mcp list` were **not** run.
10. **Files changed:**
    - Modified: `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` (this file — new "Phase 2.6 Gate 2-3" section, updated gates table and verdict).
    - Modified: `docs/ENVIRONMENT_AUDIT.md` (new "Phase 2.6 Gate 2-3" current-status section; prior Gate 1-2 section marked historical).
    - Modified: `docs/ASSUMPTIONS_AND_UNKNOWNS.md` (A1 and A2 updated to reflect resolved tool-surface and API-connectivity blockers).
    - Modified: `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` (new "Phase 2.6 Gate 2-3" current-status addendum; "Pick up here" item 0 updated; prior Gate 1-2 addendum marked historical).
    - No business-policy file touched. No `.env`, credential, or key file created or modified. `infrastructure/local-n8n/docker-compose.yml`/`README.md` and `.mcp.json` not modified this session (`.mcp.json` was read-only; its `N8N_API_URL` change was made by the owner before this session started).
11. **Unresolved blockers:**
    - **A3 (Instantly API key/plan tier)** — unchanged, still BLOCKED for live actions, still confirmed not to block Prompt 3's mocked-build scope.
    - The disposable-workflow validation finding ("Multi-node workflow has no connections" for the Manual Trigger + Sticky Note pair) is a **known n8n-mcp validator artifact for sticky-note-only auxiliary nodes**, not a project blocker — flagged here for awareness if it recurs in real workflow builds (a sticky note alongside connected functional nodes will not trigger this, since the *other* nodes will have connections; only an all-isolated-nodes workflow does).
    - `LIVE_CAMPAIGNS` (`docs/VALIDATION_CAMPAIGN_CONFIG.md` §3) and Docker-level isolation (binding/version pin/no-tunnel) were **not independently re-verified by this session's tool calls** — both carried forward from Phase C / Gate 1-2 with no contradicting evidence, and the latter is consistent with the owner's independently-reported PowerShell checks this session.
12. **Exact next action:** Route A's MCP-verified-build gates (n8n MCP connected with full tool surface, non-production local instance reachable, disposable create/get/validate/delete lifecycle proven, 0 business/active workflows, `DRY_RUN=true`, `LIVE_CAMPAIGNS=empty`, no secrets in repo) are now met. **Prompt 3 was not started this session** (explicitly out of scope) — the next session may proceed to Prompt 3 only with the user's explicit authorisation, per `CLAUDE.md` and `docs/IMPLEMENTATION_PLAN.md` §1.

