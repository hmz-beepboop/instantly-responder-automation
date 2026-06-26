# HMZ_N8N_LOCAL_DEVELOPMENT_ONLY

A completely local, non-production n8n instance used **only** to let the
`n8n-mcp` MCP server inspect/build/validate workflows for Phase 2.6 and the
Prompt 3 Validation MVP build. It is **not** part of any production system,
contains **no** Instantly credentials, **no** AI-provider keys, **no** email
credentials, and **no** business workflows.

This file contains no secrets and is safe to commit.

---

## 0. Status (2026-06-11, Phase 2.6 Phase C)

This environment is **provisioned and running**. WSL2 + Docker Desktop are
installed, the `hmz-n8n-local-dev` container is up (image pinned to
`docker.n8n.io/n8nio/n8n:2.25.7`), bound to `127.0.0.1:5678` only, with the
owner account created and a local development API key created. The
`n8n-mcp` MCP server is connected but **not yet configured** with
`N8N_API_URL`/`N8N_API_KEY` (see §5 — pending owner action). See
`reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` for the full audit.

---

## 1. Prerequisites: install WSL2 + Docker Desktop (Windows 11 Home)

Windows 11 Home cannot use the Hyper-V backend, so Docker Desktop requires
WSL2.

1. Open **PowerShell as Administrator** and run:
   ```powershell
   wsl --install
   ```
   This installs WSL2, the Linux kernel update, and a default Ubuntu
   distribution. **Restart the computer** when prompted.
2. After restart, Ubuntu may prompt for a one-time UNIX username/password on
   first launch. This is independent of n8n and is not required for Docker
   itself, but completing it confirms WSL2 is working.
3. Download **Docker Desktop for Windows** from the official site:
   https://www.docker.com/products/docker-desktop/
   (or the install guide: https://docs.docker.com/desktop/setup/install/windows-install/)
4. Run the installer (`Docker Desktop Installer.exe`). On Windows 11 Home the
   WSL2 backend is used automatically (Hyper-V is not an option).
5. Restart again if prompted, then launch Docker Desktop and accept the
   service agreement.
6. Open a **new** PowerShell window (so PATH updates take effect) and verify:
   ```powershell
   docker --version
   docker info
   ```
   `docker info` should succeed without errors and show the WSL2 engine
   running.

---

## 2. Start the local n8n instance

From the project root:

```powershell
docker compose -f infrastructure/local-n8n/docker-compose.yml up -d
```

This creates:
- Container: `hmz-n8n-local-dev`
- Volume: `hmz_n8n_local_dev_data`
- Binding: `127.0.0.1:5678:5678` (localhost only — not reachable from other
  devices on the network)
- Timezone: `Europe/London`

Check it started:
```powershell
docker ps --filter "name=hmz-n8n-local-dev"
docker logs hmz-n8n-local-dev --tail 50
```

Open http://localhost:5678 in a browser.

---

## 3. Create the owner account (manual, in-browser)

n8n's first-run screen asks you to create the **owner account**
(email/name/password). Do this yourself in the browser.

- **Do not** share or paste this password into chat or into any file in this
  repository. Claude Code will not ask for it and does not need it.

---

## 4. Create a development API key

1. In n8n, go to **Settings → n8n API** (sometimes labelled **API**).
2. Create a new API key (any descriptive label, e.g.
   `hmz-local-dev-mcp`).
3. Copy the key value — you will paste it once into your **user-scope**
   Claude Code MCP configuration (step 5), **not** into this repository or
   chat.

This key is a secret even though the instance is local — treat it like any
other credential.

---

## 5. Configure the `n8n-mcp` MCP server

The existing user-scope `n8n-mcp` server (confirmed connected, Phase 2.6
Phase C, 2026-06-11 — current config: `MCP_MODE=stdio`, `LOG_LEVEL=error`,
`DISABLE_CONSOLE_OUTPUT=true`, no `N8N_API_URL`/`N8N_API_KEY` yet) needs two
extra environment variables added: `N8N_API_URL` and `N8N_API_KEY`.

`claude mcp add` takes `-e KEY=VALUE` flags **before** the `--` separator
(verified via `claude mcp add --help`, 2026-06-11) — flags placed after `--`
are passed to `npx n8n-mcp` itself, not to Claude Code.

Run this in a **normal terminal window outside Claude Code** (not via the
`!` prefix in a Claude Code session, and not pasted into chat), so the key
never appears in any transcript, project file, or repository:

```powershell
claude mcp remove n8n-mcp -s user
claude mcp add n8n-mcp -s user -e MCP_MODE=stdio -e LOG_LEVEL=error -e DISABLE_CONSOLE_OUTPUT=true -e N8N_API_URL=http://localhost:5678 -e N8N_API_KEY=<your-local-dev-api-key-here> -- npx n8n-mcp
```

Replace `<your-local-dev-api-key-here>` with the local development API key
created in §4. This preserves the three existing env vars
(`MCP_MODE`, `LOG_LEVEL`, `DISABLE_CONSOLE_OUTPUT`) and adds the two new ones.

Notes:
- `N8N_API_URL` must include the protocol: `http://localhost:5678`.
- Never put `N8N_API_KEY` in `.env` in this project, in Markdown, in workflow
  JSON exports, in reports, or in chat.
- After configuring, **restart Claude Code** (stdio MCP servers are spawned
  at session start, so a config change requires a new session) and re-run
  `tools_documentation()` to confirm the 15 `n8n_*` workflow-management tools
  are now available (Phase D of `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md`).

---

## 6. Stopping / removing (development only)

```powershell
# stop the container, keep data
docker compose -f infrastructure/local-n8n/docker-compose.yml down

# stop and also delete the persistent volume (irreversible — only if you
# want a clean slate)
docker compose -f infrastructure/local-n8n/docker-compose.yml down -v
```

---

## 7. Isolation reminders

- This instance is **for this project only**. Do not import business
  workflows, Instantly credentials, AI-provider keys, or email credentials
  into it.
- Do not expose it publicly and do not configure a tunnel (ngrok, Cloudflare
  Tunnel, etc.).
- `DRY_RUN=true` and `LIVE_CAMPAIGNS=empty` remain the project defaults
  regardless of this environment's state (`CLAUDE.md` rules #5, #7).
- Workflow activation remains prohibited until explicitly authorised in a
  later phase.
