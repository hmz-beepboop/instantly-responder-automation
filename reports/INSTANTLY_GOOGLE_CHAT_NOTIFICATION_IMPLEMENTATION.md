# Instantly Reply → Google Chat Notification — Implementation Evidence

**Verdict: PASS**

Notification-only integration. It does not draft, approve, classify, modify, or send any email, and it is fully isolated from the responder chain (Decision / Human Approval / Sender / Shadow / Gate 2).

- **UTC:** 2026-07-18T15:21:42Z · **Europe/London:** 2026-07-18T16:21:42+0100
- **Branch:** `codex/5q-context-token-forensic-20260705` · **HEAD:** `ed94d57c647cd33f346277c6b331b8002d0f90fe`
- **n8n:** 2.25.7 (Docker Compose, project `hmz-instantly-responder`, service `n8n`, behind Traefik)

## Flow

```
Instantly reply_received
  → n8n Webhook (header auth: X-HMZ-Webhook-Secret)
  → Validate & Build Message (deterministic gate + sanitised Chat text)
  → Dedup Guard (workflow static data)
  → Notify? (IF)
        true  → Post to Google Chat → Respond 200 Notified   (or → Respond 502 on delivery failure)
        false → Respond No-Notify   (ignored 200 / invalid 400 / duplicate 200)
```

## Resources created

| Resource | Name | ID | State |
|---|---|---|---|
| n8n workflow | HMZ — Instantly Reply → Google Chat Notification | `JojqjTVw3KQRtYEN` | **active** |
| n8n credential (header auth) | HMZ Instantly GChat Inbound Secret | `Pd9mWMv29ZhLJZdE` | httpHeaderAuth (encrypted) |
| Instantly webhook | HMZ Google Chat — Prospect Replies | `019f75ce-f9d4-7a85-9bd9-14059c8c9baf` | **active**, all campaigns, `reply_received` |
| VPS env var | `HMZ_GCHAT_REPLY_NOTIFY_URL` | — | in n8n container (protected) |

- **Webhook path:** `hmz-instantly-reply-google-chat-v1`
- **Production URL:** `https://n8n.hmzaiautomation.com/webhook/hmz-instantly-reply-google-chat-v1`

## Secret handling

- **Inbound auth secret** (`X-HMZ-Webhook-Secret`) → encrypted n8n `httpHeaderAuth` credential; the Webhook node returns **403** on missing/incorrect header before any workflow logic runs. Never embedded in workflow JSON.
- **Google Chat webhook URL** → the container already had a `GOOGLE_CHAT_WEBHOOK_URL` for the existing responder review chat, and its value **differs** from the supplied dedicated space (verified by hash, values never printed). To avoid disturbing the responder, a **new** protected env var `HMZ_GCHAT_REPLY_NOTIFY_URL` was provisioned and referenced as `{{ $env.HMZ_GCHAT_REPLY_NOTIFY_URL }}`. The full URL is not in workflow JSON, Git, Markdown, or evidence.
- Compose change was minimal: `.env` + one env passthrough line on the n8n service; both files backed up first; `docker compose config` validated; only the n8n service was recreated; health re-verified.

## Message format

```
[TEST] 🔔 *New Instantly Prospect Reply*

*Prospect:* prospect@example.com
*Campaign:* HMZ US B2B Validation Q3
*Received by:* hamzah@hmzaiautomation.com
*Subject:* Re: quick question about your outreach

*Reply preview:*
<sanitised preview, snippet-first, ~700 char cap>

<https://app.instantly.ai/app/unibox?...|Review reply in Instantly>
```

- Preview uses `reply_text_snippet` first, then `reply_text`, then `No text preview supplied`.
- Prospect text is sanitised: HTML stripped, angle brackets neutralised (blocks `<url|text>` and `<users/all>` injection), control/zero-width removed, whitespace collapsed, ~700 char cap.
- The review link uses the event's **exact** `unibox_url`, validated as a clean `https://` URL. No URL is constructed or guessed.
- `[TEST]` prefix appears only when the payload carries the synthetic marker; real events are unmarked.

## Deduplication

Native n8n **workflow static data** (durable per-workflow store). Key = strongest available identifier (`id`/`message_id`/`reply_id`/`event_id`/`email_id`), else a hash of `workspace | campaign_id | lead_email | reply_subject | timestamp | reply_text`. First valid event notifies and records the key; identical replays return 200 with no second post. Records expire after 7 days and are hard-capped at 5000 keys (oldest-first eviction), so the store cannot grow without bound. (A pure-JS FNV-1a+djb2 hash is used because the n8n task runner blocks `require('crypto')`.)

## Test matrix

| # | Test | Expected | Result | Status |
|---|---|---|---|---|
| 1 | Missing auth header | reject, no Chat | HTTP 403, no Chat | **PASS** |
| 2 | Incorrect auth header | reject, no Chat | HTTP 403, no Chat | **PASS** |
| 3 | Wrong event type (`auto_reply_received`) | ignored, no Chat | HTTP 200 `ignored_event_type`, no Chat | **PASS** |
| 4 | Missing `unibox_url` | controlled 4xx, no Chat | HTTP 400 `invalid_missing_fields`, no Chat | **PASS** |
| 5 | Valid `reply_received` | exactly one Chat with labelled link | HTTP 200 `notified`; Google Chat accepted (message resource returned); prospect/campaign/preview + exact https unibox link present; sanitised; `[TEST]` marked | **PASS** |
| 6 | Exact replay of #5 | duplicate, no second Chat | HTTP 200 `duplicate_suppressed`; post node did not run | **PASS** |

All tests were synthetic (no real prospect, no email sent). Test alerts are clearly marked `[TEST]`.

## Google Chat delivery

Delivered. The n8n HTTP node succeeded (2xx) and routed to *Respond 200 Notified*; a non-2xx would have routed to *Respond 502 Delivery Failed*. The Google Chat API response contained the created message resource (`name`, `thread`, `space`). The workflow never reports success on a failed delivery.

## Provider (Instantly) test

`POST /webhooks/019f75ce-.../test` returned **HTTP 200** (accepted). Instantly's test endpoint does not deliver a payload to the target URL, so the controlled synthetic test (#5) is the authoritative link-rendering + delivery proof — as the task anticipated.

## Non-regression

- No pre-existing n8n workflow changed active state; none removed. The responder Intake subscription (`instantly-reply`) and all other Instantly webhooks are intact.
- `kWZpb8Qt7EqkxIgT` "My workflow" (inactive) is **owner-created** (confirmed by the owner); it was not created or modified by this task and uses a different webhook path (no collision).
- Post-restart: n8n healthy; `hmz-send-state`, `lk2-sidecar`, Traefik, and the other containers unaffected.

## Health

`healthz` 200 · n8n API read 200 · Instantly API read 200.

## Files changed

- `workflows/HMZ_Instantly_Reply_Google_Chat_Notification.json` (new, sanitised — no secrets)
- `reports/INSTANTLY_GOOGLE_CHAT_NOTIFICATION_IMPLEMENTATION.md` (this file)
- `reports/instantly-google-chat-notification-evidence.json` (new)
- `OPERATION_HANDOFF.md` (append-only checkpoint)
- VPS (not in Git): `infrastructure/business-live/.env` (+1 var) and `docker-compose.hostinger-traefik.yml` (+1 env passthrough), each with a timestamped backup.

## Secrets

No secrets persisted in the repository or Git: no Google Chat URL, shared secret, or API key in any file. The inbound secret lives only in the encrypted n8n credential; the Google Chat URL lives only in the protected VPS env var. Focused secret scan: clean.
