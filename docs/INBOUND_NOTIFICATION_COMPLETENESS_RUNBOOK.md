# Inbound Notification Completeness — Runbook

Reference for operating and verifying the "every inbound Instantly email gets
its own Google Chat notification" guarantee. Written after the 2026-07-20
missed-auto-reply-notification incident
(`reports/LIVE_MISSED_NOTIFICATION_INCIDENT_2026-07-20.md`). For general
day-to-day operation (Send/Edit/Cancel, pausing sending, key rotation), see
`docs/GOOGLE_CHAT_REPLY_CONSOLE_OPERATOR_RUNBOOK.md` — this doc is narrowly
about inbound completeness.

> **2026-07-21 v2 update:** production now uses the canonical SQLite
> inbound/outbox implementation and an independent scheduled auditor. For the
> current command set and rollback sequence, use
> `docs/INBOUND_COMPLETENESS_OPERATOR_RUNBOOK_V2.md`. The incident-era v1
> history below is retained, but any v1 eligibility/exclusion language is
> superseded by the contract stated here.

## The guarantee, in one line

Every email Instantly reports as inbound (`email_type=received`) — including
positive, negative, neutral, unsubscribe, out-of-office/automatic, empty,
attachment-only, malformed-metadata, bounce and mail-system records — is
durably registered and eventually reaches `CHAT_NOTIFIED`. Classification can
change the label and can suppress an unsafe Send control; it cannot suppress
the individual notification.

## How completeness is achieved (four discovery paths + durable outbox)

1. **Webhook fast path** — authenticated `reply_received` now targets the
   side-by-side durable v2 notification workflow. It forwards the payload
   without a classifier, applicability check or static-data dedup before
   persistence.
2. **Recovery poll safety net** — `HMZ — Inbound Recovery Poll`
   (`7LNeDYVaEbuZ4fpO`), every 1 minute. Lists Instantly's own
   `/emails?email_type=received` directly with overlap, complete pagination,
   timestamp-plus-ID cursor evidence and no category exclusion.
3. **Independent completeness auditor** — five-minute/two-hour,
   hourly/24-hour and daily/seven-day schedules query Instantly directly. They
   do not trust or advance the normal poll cursor and repair missing inbound
   or outbox rows idempotently.
4. **Bounded backfill** — internal operator-only tooling uses the same
   canonical service. It has no prospect-send adapter.

All paths atomically create one `inbound_records` row and one
`notification_outbox` row in `inbound-v2.sqlite` before a Chat network call.
Database uniqueness suppresses races. Expiring worker leases, immutable
attempt history and bounded backoff retry without a finite cap until a 2xx
response contains a definite Google Chat message resource name.

## Auto-reply / out-of-office handling (the 2026-07-20 fix)

Automatic and out-of-office replies from a prospect's own mailbox **are**
notified and labelled distinctly. A true bounce, postmaster or mailer-daemon
record exposed by Instantly as received is also notified, labelled
`📨 Mail-System/Bounce Notice`, with Send withheld where a prospect-thread
reply cannot be routed safely.

## Checking current completeness

**Safe current state:**

```
docker exec hmz-reply-console-business-live node -e "
fetch('http://127.0.0.1:5691/v2/operations').then(r=>r.json()).then(j=>console.log(JSON.stringify(j,null,2)))
"
```

Require `outbox_missing=0`, a drained active queue, fresh poll/auditor
heartbeats and no mature post-epoch item short of `CHAT_NOTIFIED`. A safe
operations snapshot is not by itself the denominator: run direct bounded
Instantly reconciliation as described in the v2 operator runbook.

**Bounded historical audit (dry-run, safe, never sends or notifies):**

```
docker exec hmz-reply-console-business-live sh -c 'node backfill.mjs --since <ISO> --until <ISO> --verbose'
```

Reports `missing` count and the specific Instantly email ids. Add `--apply`
(plus `--notify-url "$GCHAT_NOTIFY_URL"`, expanded from the container's own
env so the URL is never typed or logged in plaintext) only when you have
reviewed the dry-run output and want those specific items recovered — it will
post one visible, distinctly-labelled
`⏱️ [RECOVERED — GOOGLE CHAT NOTIFICATION DELAYED]` Chat message per missing
item.

**Do not mix unrelated historical windows into a live-incident recovery.**
The 38 pre-instrumentation historical items identified by the prior audit
(dated before 2026-07-18T18:33Z, when the console's context-creation
capability first existed) remain a separate, un-actioned owner decision —
always scope a recovery `--apply` run to the specific window relevant to the
current investigation.

Legacy `/v1/report` counters remain historical evidence only. Primary
completeness is always stated as: “X of Y Instantly-visible inbound records in
this window have definite Google Chat acknowledgement.”

## Watchdog alerts relevant to completeness

`GET /v2/watchdog` detects, among others: absent inbound/outbox rows,
retry/ambiguous backlogs, expired posting leases, stale poll or auditor
heartbeats, cursor lag, failed enrichment, unreconciled surrogates, malformed
active records, Instantly 401/429/5xx, Chat failures and durable-store
integrity failures. Deliberate `HISTORICAL_OWNER_HOLD` rows remain visible in
reconciliation but are not treated as active malformed/retry failures.

None of these alerts are a substitute for the notification itself — an alert
only supplements, it never counts as `CHAT_NOTIFIED`.

## What "healthy" looks like

- Instantly-visible inbound count (for a given window) equals the durable
  ledger's count for that same window.
- `/v2/operations` reports zero missing outbox rows and zero mature active
  queued/retrying/ambiguous rows.
- Recovery-poll, short-auditor, deep-auditor, daily-auditor and watchdog
  heartbeats are fresh for their schedule thresholds.
- Direct reconciliation over the incident, 24-hour and seven-day windows
  accounts explicitly for every Instantly ID; historical owner holds are
  reported separately and never mixed into post-deployment percentages.

## What to do if you find a genuine gap

1. Confirm it is not a known test artifact (see above).
2. Run the bounded dry-run backfill for a window covering it, to size the
   gap and rule out it being isolated vs. part of a wider pattern.
3. If isolated: `--apply` for that narrow window only.
4. If it looks systemic (many items, a specific field pattern, a specific
   time range coinciding with a deploy/restart): stop, do not mass-apply, and
   investigate the root cause first — mirroring the process in
   `reports/LIVE_MISSED_NOTIFICATION_INCIDENT_2026-07-20.md` §2-4. A gap
   pattern is usually a defect in a specific classification/parsing step, not
   something that self-heals with more retries.
5. Never disable, pause, or reconfigure the global send gate as a response to
   an inbound-notification gap — the two are unrelated; sending capability
   and inbound notification completeness are independent systems.
