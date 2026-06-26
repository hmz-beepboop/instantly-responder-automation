# Business-Ready Hosting (Supervised VALIDATION Profile)

Status: **offline-built, not deployed**. This stack exists so the owner can
host the 7 `... - Validation` workflows behind a public HTTPS endpoint
*after* completing `BUSINESS_READY_OWNER_INPUTS.md` and running
`verification/business-ready/apply-business-ready.ps1`. Building this
infrastructure does not deploy it, bind credentials, change `DRY_RUN`,
populate `LIVE_CAMPAIGNS`, or activate any workflow.

This file contains no secrets and is safe to commit.

---

## 0. What this is for

The Instantly reply webhook and the Human Approval review links
(`config.review.review_base_url`) need a public HTTPS URL. This stack
provides that by putting a reverse proxy (Caddy, automatic Let's Encrypt
TLS) in front of the same n8n + `hmz-send-state` pairing already verified
locally in `infrastructure/local-n8n/`.

It is a **separate** compose project from `infrastructure/local-n8n/` -
different container names, different volumes, different (production-style)
n8n configuration (`N8N_HOST`, `WEBHOOK_URL`, `N8N_ENCRYPTION_KEY`). Do not
run both stacks against the same n8n data volume.

## 1. Components

| Service | Image | Public? | Purpose |
| --- | --- | --- | --- |
| `n8n` | `docker.n8n.io/n8nio/n8n:2.25.7` (pinned, same as local) | No (127.0.0.1:5678 only) | Runs the 7 Validation workflows |
| `hmz-send-state` | built from `infrastructure/send-state` | No (no published port) | Durable send-lock + sanitised error records |
| `reverse-proxy` | `caddy:2-alpine` | Yes (80/443) | TLS termination, forwards to `n8n:5678` |

All three have `restart: unless-stopped` and health checks. `n8n` and
`reverse-proxy` wait on their dependency's health check before starting.

## 2. Prerequisites

- Docker + Docker Compose (same as `infrastructure/local-n8n/`).
- A host with a public IP and ports 80/443 reachable from the internet.
- A DNS A/AAAA record for the hostname you will put in `N8N_HOST`, pointing
  at that host's public IP, **before** starting `reverse-proxy` (Caddy needs
  this to obtain its Let's Encrypt certificate).
- `BUSINESS_READY_OWNER_INPUTS.md` §10 (hosting target/domain/TLS strategy)
  completed.

## 3. Deploy

1. Copy `.env.example` to `.env` in this directory and fill in `N8N_HOST`,
   `ACME_EMAIL`, and a freshly generated `N8N_ENCRYPTION_KEY`
   (`openssl rand -hex 24`). Keep `.env` out of version control.
2. From the project root:
   ```bash
   docker compose -f infrastructure/business-live/docker-compose.yml up -d
   ```
3. Confirm health:
   ```bash
   docker compose -f infrastructure/business-live/docker-compose.yml ps
   ```
   All three services should show `healthy` within ~60 seconds. `n8n`
   becomes reachable at `https://<N8N_HOST>/` once Caddy has issued its
   certificate (check `docker logs hmz-reverse-proxy-business-live`).
4. Create the n8n owner account in the browser (same manual step as
   `infrastructure/local-n8n/README.md` §3) and generate an API key for
   `$env:HMZ_N8N_API_KEY` (used by the apply/acceptance/rollback scripts,
   which target `http://127.0.0.1:5678` and work unchanged against this
   stack).

## 4. Activation order (after `apply-business-ready.ps1` succeeds)

This stack only hosts the workflows; it does not decide whether they run.
Activation remains a separate, deliberate step outside this compose file,
following the existing gates:

1. `apply-business-ready.ps1` (patches placeholders, leaves all 7 inactive).
2. `run-local-runtime-acceptance.ps1` (runtime checks against this n8n).
3. `run-controlled-live-acceptance.ps1` (read-only Instantly pre-flight).
4. Owner reviews `BUSINESS_READY_OWNER_INPUTS.md` is fully completed,
   `config.live_credential_readiness.ready_for_controlled_live_test=true`,
   and binds real credentials (`hmzInstantlyApi`, `hmzGoogleChatWebhook`,
   `hmzN8nApi`) via the n8n UI only - never via any script or file here.
5. Owner manually activates the workflows in the n8n UI, in the order
   documented in `docs/DEPLOYMENT_CHECKLIST.md` /
   `docs/ROLLBACK_GUIDE.md`, starting with `DRY_RUN=true` still set.
6. Owner performs the single controlled-live send (manual, out of band -
   see "Next step if READY" in
   `reports/BUSINESS_READY_CONTROLLED_LIVE_ACCEPTANCE.md`).
7. Only after a reviewed, successful controlled-live result does the owner
   decide whether to flip `DRY_RUN=false` for the designated campaign(s) -
   this remains a manual decision with no script support.

## 5. Monitoring

- `docker compose -f infrastructure/business-live/docker-compose.yml ps`
  - shows health status for all three services.
- `docker logs hmz-n8n-business-live --tail 100`
- `docker logs hmz-send-state-business-live --tail 100`
- `docker logs hmz-reverse-proxy-business-live --tail 100`
  (certificate issuance/renewal and proxy errors)
- n8n's built-in execution list (UI) is the primary source of truth for
  per-item processing outcomes; Google Chat notifications (once configured)
  surface SLA breaches (workflow 05) and error records (workflow 04).
- `hmz-send-state`'s `/health` endpoint is internal-only; check it via
  `docker exec hmz-send-state-business-live wget -qO- http://127.0.0.1:5681/health`.

## 6. Backup / retention

- `backup-business-live.ps1` archives the two named volumes
  (`hmz_n8n_business_live_data`, `hmz_send_state_business_live_data`) to
  `infrastructure/business-live/backups/<timestamp>/`. For a guaranteed-
  consistent backup, `docker compose ... stop` first (see script header for
  the read-while-running caveat).
- `restore-business-live.ps1 -BackupTimestamp <ts> -Confirm` restores both
  volumes from a backup directory. Destructive - requires the stack to be
  stopped and `-Confirm`.
- Data retention (review cases, send-state, error records) is governed by
  `config.business-ready.config.json` `retention.*` (currently
  placeholders pending owner input - see `BUSINESS_READY_OWNER_INPUTS.md`
  §8); no automated purge job exists yet. Retention enforcement is a future
  scheduled task, not part of this build.
- `hmz_caddy_data` / `hmz_caddy_config` hold the Let's Encrypt account and
  certificates; back these up too if you want to avoid re-issuance after a
  host rebuild (not certificate-rate-limit-critical, but convenient).

## 7. Rollback

- **Workflow content rollback**: use
  `verification/business-ready/rollback-business-ready.ps1` (restores the
  7 workflows' `{name, nodes, connections, settings}` from
  `verification/business-ready/preapply-backup/<timestamp>/` and ensures
  they remain inactive). Works against this stack's n8n the same as against
  `infrastructure/local-n8n`.
- **Hosting rollback**: `docker compose -f infrastructure/business-live/docker-compose.yml down`
  stops all three containers without deleting volumes. Add `-v` only if you
  intentionally want to discard all data (irreversible) - prefer
  `restore-business-live.ps1` from a known-good backup instead.
- **Full step-by-step rollback procedure** (including the n8n workflow
  layer): `docs/ROLLBACK_GUIDE.md`.

## 8. PROVEN mode / unattended auto-send

Not implemented anywhere in this repository, including this hosting layer.
This stack only provides a reachable HTTPS endpoint and persistent storage;
it has no scheduler, queue, or auto-promotion logic that could move a reply
from `DRY_RUN` to live without the manual steps in §4. Any future PROVEN
mode would require its own explicit, separately-reviewed design and is out
of scope for this build.

## 9. Isolation reminders

- `N8N_ENCRYPTION_KEY` and `.env` in this directory are secrets - never
  commit them, paste them into chat, or place them in workflow JSON,
  `config/business-ready.config.json`, or any report.
- `hmz-send-state` has no published port in this compose file either - do
  not add one.
- `DRY_RUN=true` and `LIVE_CAMPAIGNS=[]` remain the defaults regardless of
  this stack's deployment state, until the steps in §4 are deliberately
  completed by the owner.
