# hmz-send-state (Phase 4A)

A minimal internal Docker sidecar providing durable atomic send-ownership
and sanitised error records for the Phase 4A Sender and Error Handler
workflows. Reuses the verified V5 Layer 2 atomic file-lock/state logic
(`verification/v5/layer2/state-store.mjs`), packaged as a small HTTP JSON
service.

## Why this exists

n8n Data Tables have no documented transactional unique-key or
compare-and-set guarantee. A concurrent send lock therefore cannot be
implemented safely with Data Tables alone. This sidecar provides that
guarantee using an atomic `open(path, 'wx')` lock file plus
write-tmp-then-rename durable state files, exactly as verified in V5
Layer 2.

This is a Validation-MVP mechanism for Phase 4A, not a production-scale
database.

## Network isolation

- Binds to `0.0.0.0:5681` **inside** the container only.
- `infrastructure/local-n8n/docker-compose.yml` does **not** publish this
  port to the Windows host - there is no `ports:` entry for this service.
- n8n reaches it only via the Docker Compose network, as
  `http://hmz-send-state:5681`.
- State is stored in the named volume `hmz_send_state_data`, mounted at
  `/data`.

## What is stored

Only: sanitised identifiers (hashed send keys, intake IDs), forward-only
send state, timestamps, attempt counts, HTTP status class, error class,
and operator action.

**Never stored:** API keys, `Authorization` headers, full reply bodies,
full webhook payloads, or raw API responses. `state-store.mjs`'s
`sanitize()` redacts any key matching
`/authoriz|api[_-]?key|secret|token|password|cookie|bearer/i` and
truncates strings longer than 500 characters before every write.

## Send-state machine

Forward-only states (see `state-store.mjs` `ALLOWED_TRANSITIONS`):

```
READY -> LOCKED -> { DRY_RUN_OK | SUBMITTING | BLOCKED }
SUBMITTING -> { SENT | SEND_UNCERTAIN | PERMANENT_FAILURE |
                AUTH_OR_PLAN_FAILURE | INVALID_REPLY_TARGET |
                RETRY_EXHAUSTED | BLOCKED }
SENT -> SENT_RECONCILED
SEND_UNCERTAIN -> { SENT_RECONCILED | HUMAN_REVIEW_ZERO_MATCHES |
                    HUMAN_REVIEW_MULTIPLE_MATCHES }
```

All other states are terminal (no further transition permitted). Writing
a terminal state releases the send lock, so a later sequential rerun for
the same send key receives `DURABLE_STATE_EXISTS`.

## Endpoints

- `GET /health` -> `{ "status": "ok" }`
- `POST /v1/send/acquire` `{ inboundEmailId, sender, recipient, policyTemplateId }`
  -> `{ acquired, blocked, sendKey, reason?, priorState? }`
  - Stable `sendKey` = `sha256("HMZ_PHASE4A_SEND|<inboundEmailId>|<sender>|<recipient>|<policyTemplateId>")`.
    A random body marker is never part of the key.
  - Concurrent second acquisition for the same identity -> `blocked: true, reason: "LOCK_ALREADY_HELD"`.
  - A later sequential rerun -> `blocked: true, reason: "DURABLE_STATE_EXISTS"`.
- `POST /v1/send/transition` `{ sendKey, toState, details }`
  -> `{ ok, state, updatedAt }` or `{ ok: false, reason }`
  - Rejects any transition not listed in `ALLOWED_TRANSITIONS`.
- `GET /v1/send/:sendKey` -> current sanitised state record, or `404`.
- `POST /v1/error` `{ ...sanitised fields... }` -> `{ errorId }`
  - Written atomically (tmp file + rename).
- `GET /v1/error/:errorId` -> sanitised error record, or `404`.

## Build and run

This service is built and started as part of
`infrastructure/local-n8n/docker-compose.yml`:

```powershell
docker compose -f infrastructure/local-n8n/docker-compose.yml up -d hmz-send-state
```

It is not intended to be run standalone or exposed outside the compose
network.
