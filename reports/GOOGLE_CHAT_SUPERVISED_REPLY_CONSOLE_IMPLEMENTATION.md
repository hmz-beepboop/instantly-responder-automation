# HMZ — Google Chat Supervised Reply Console — Implementation Report

**Verdict (latest):** CONTROLLED TEST PASS — one controlled multiline reply was delivered to an owner-controlled test inbox (HTTP 200, exactly 1 POST, duplicate blocked, correct thread/account, multiline preserved). System remains **PARTIAL / NOT PRODUCTION-ACCEPTED**: the global send gate is **OFF** and supervised production sending requires a **separate explicit owner approval**. No genuine prospect was used.

> **2026-07-19 update — send path reworked.** The Instantly send now runs entirely inside the isolated sidecar (`performSend`): it forms `Authorization: Bearer <key>` from a root-owned env key (fingerprint `eb31b16145df`, never in repo), makes at most one POST, and classifies SENT / **FAILED_AUTH_401** / FAILED_SAFE / SEND_UNCERTAIN with an immutable `sendAttempts[]` audit (a 4xx failure → RETRYABLE, needs a fresh draft; never silently reset). Two acceptance defects were fixed: an HTTP‑401 caused by the Authorization header never being a valid Bearer under n8n (env var missing / imported credential not executing), and a whitespace‑collapse bug that flattened multiline replies. Tests: store 34/34, HTTP 20/20, formatting 13/13. See the OPERATION_HANDOFF checkpoint and evidence JSON for full detail.

---

**Verdict (original build):** PARTIAL — full implementation built, deployed and synthetically verified; sending held behind a default-OFF go-live gate.

**Timestamps:** 2026-07-18T18:33Z (19:33 BST)
**Branch / HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57`

This upgrade lets the authorised owner write and explicitly approve an Instantly reply from inside a Google Chat thread. It never generates or auto-sends a prospect reply — every send is human-written and human-approved.

---

## 1. Architecture

```
Instantly reply_received ──▶ Notification workflow (JojqjTVw3KQRtYEN, active)
  webhook(headerAuth) → validate/sanitise → dedup → Create Console Context ─┐
                                             → Post to Google Chat (threaded) │  (reply-console sidecar,
                                             → Attach Chat Post ──────────────┘   internal-only, holds context)

Owner replies in the thread + @mentions the app
  Google Chat ──(bearer JWT)──▶ Interaction workflow (G7GIQGt9JOXxITH4, active)
     Verify Google Token (sidecar /v1/verify, google-auth-library)
     Parse & Authorise (owner email/domain/human/space/thread)
     MESSAGE → Create Draft → private Review card (From/To/Subject/EXACT body + Send/Edit/Cancel)
     CARD_CLICKED → Send / Edit / Cancel
        Send → acquireSend (atomic APPROVED→SENDING, one-use token, go-live gate)
             → POST /api/v2/emails/reply → classify → SENT / FAILED_SAFE / SEND_UNCERTAIN
```

The existing Google Chat **incoming webhook** still authors the notification (one-way, no buttons). Interactivity is a **separate** Google Chat app HTTP endpoint. No service-account JSON key was introduced; the incoming webhook was not replaced.

## 2. Isolated console sidecar (`hmz-reply-console-business-live`)

Modelled on the proven `hmz-send-state` sidecar. Internal only (port 5691, no host publish, not via Traefik), on the `hmz-instantly-responder_default` network, own volume `hmz_reply_console_business_live_data`.

- **Google request verification** — `google-auth-library` `OAuth2Client.verifyIdToken({ idToken, audience })`; audience fixed to `$GOOGLE_CHAT_INTERACTION_URL`; asserts issuer ∈ {accounts.google.com, https://accounts.google.com}, Chat service identity `chat@system.gserviceaccount.com` + `email_verified`. Google's tokeninfo endpoint is **not** used. Bearer tokens are never logged. Failure → 401, no state change. (Method confirmed from Google's official "Verify requests from Chat" doc.)
- **Durable store** — atomic `open('wx')` lock + write-tmp-then-rename (no plaintext API keys). Server-side context per reply (opaque notification id, deterministic context key, `reply_to_uuid`, `eaccount`, prospect, subject, campaign, exact `unibox_url`, thread key + captured Chat message/thread resource names, status, expiry, source payload hash). Immutable draft revisions with one-use review tokens. Forward-only send state `PENDING→APPROVED→SENDING→{SENT|FAILED_SAFE|SEND_UNCERTAIN}`.
- **Go-live gate (default OFF)** — `acquireSend` refuses every real send with `SEND_DISABLED_NOT_GO_LIVE` (no token consumed, no state change) until the owner explicitly authorises go-live in-session. This is the deliberately blocked send adapter; Review/Edit/Cancel work throughout.

Card/dialog actions carry **only** an opaque context id + one-use token — all sensitive routing (`eaccount`, `reply_to_uuid`, subject, body) is resolved server-side.

## 3. Instantly reply contract (from VERIFIED repo evidence)

`email_id` → `reply_to_uuid`; `email_account` → `eaccount`; `POST /api/v2/emails/reply` with `{ eaccount, reply_to_uuid, subject, body }` (key scope sufficient — prior controlled V3 returned 200). The console never switches accounts and never starts a new thread.

## 4. Backups (mandatory first action — PASSED before any live change)

- **A (repo export):** `backups/n8n/instantly-google-chat-notification-pre-interactive-2026-07-18.json`, JSON-valid, SHA-256 `bb3175c7…4a47d`, no secrets (Google Chat URL is `$env`, auth is a credential reference).
- **B (inactive n8n duplicate):** `xxOjHdtQFgEcXHMI`, inactive, structural hash `013024ca…5382` **matches** the original; intentional diffs = new id, inert webhook path, backup-labelled sticky note, regenerated webhookId, new timestamps.
- Live workflow versionId/updatedAt confirmed unchanged until both backups verified.

## 5. Tests

- Store unit tests: **23/23**. Full-server HTTP integration tests: **20/20** (verify guards, context create/dedup/resolve-by-resource-name/unknown/malformed, draft empty/valid/tamper, go-live default-OFF blocks acquire without consuming token, authoritative routing, duplicate acquire blocked, finalize SENT, no-send-after-SENT, SEND_UNCERTAIN keeps lock/no auto-retry).
- Live endpoint auth: missing bearer → **401**, malformed bearer → **401** (through Traefik→n8n→sidecar). Endpoint exactly equals `$GOOGLE_CHAT_INTERACTION_URL`.
- Notification upgrade: Validate dry-run emits `console_capable`, deterministic `thread_key`, complete `context_input`, the reply-instruction line, and preserves preview sanitisation.
- Instantly subscription: all fields **unchanged** before/after (`019f75ce…`, `reply_received`, active, org-wide, same target + auth header).
- Non-regression: Intake/Decision/HumanApproval/Sender/SLAWatchdog/ErrorHandler all still active; Shadow Evaluator still disabled; n8n and send-state containers **not recreated**.
- Instantly POST count: **0**. Secret scan: **CLEAN**.

## 6. Remaining owner actions

1. **Manual gate** — configure the internal Google Chat app (see the session message): app name `HMZ Instantly Reply Console`, Chat API + interactive features, HTTP endpoint = `$GOOGLE_CHAT_INTERACTION_URL`, auth audience = same URL, visibility limited to the owner, add the app to the same space as the incoming webhook. No service-account key.
2. Confirm the visible user/space/thread identifiers so they can be bound.
3. (Optional, same session) identify an owner-controlled test conversation and type the explicit approval phrase to enable one controlled live send; otherwise this remains **PARTIAL**.

## 7. Rollback

- Notification: PUT the backup export back to `JojqjTVw3KQRtYEN` (or activate duplicate `xxOjHdtQFgEcXHMI`).
- Interaction: deactivate + delete `G7GIQGt9JOXxITH4`.
- Sidecar: `docker compose -f docker-compose.hostinger-traefik.yml stop hmz-reply-console`; restore compose/.env from `*.before-reply-console-20260718T163257Z`. Ordinary notifications continue regardless.
- Instantly webhook: no change made.
