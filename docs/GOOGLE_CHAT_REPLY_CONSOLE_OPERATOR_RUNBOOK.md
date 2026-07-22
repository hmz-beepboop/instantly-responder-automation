# Google Chat Reply Console — Operator Runbook

Concise, non-technical reference for the owner operating the HMZ Google Chat supervised Instantly reply console. For architecture and failure-mode detail, see `docs/GOOGLE_CHAT_REPLY_CONSOLE_FAILURE_MODEL.md`.

## What this system does

When a prospect replies to an Instantly campaign, you get a message in the bound Google Chat space. To reply, mention the app in that thread with your text — you'll see a private card with the exact outgoing email for review, and you click **Send**, **Edit**, or **Cancel**. Nothing is ever auto-generated or auto-sent; every send is your own typed text and your own explicit click.

## Normal use

1. **New reply arrives** → a Chat message appears in the thread with Prospect, Sender, Campaign, Subject, and a preview, plus a link to open it in Instantly.
2. **To draft a reply:** reply in that same thread, mentioning the app, followed by your text. You'll get a private Review card.
3. **Review card:** shows From (sender), To (prospect), Subject, and the exact body that will be sent, plus **Send** / **Edit** / **Cancel** buttons.
4. **Edit:** opens a dialog with the current text pre-filled. Edit it and click **Save & Review** — you'll get an updated Review card. *(Known limitation: the Edit dialog does not reliably render on the Google Chat **mobile app** — desktop web/app work fine. On mobile, instead reply again in the thread with your corrected text; that creates a fresh, reviewable draft without needing the dialog.)*
5. **Send:** sends exactly that reviewed text via Instantly. You'll get a confirmation receipt with Prospect/Sender/Subject/Confirmation/Time. If Instantly's response is ambiguous (rare), you'll instead see "Confirming delivery…" with a **Check status** button — the system automatically confirms in the background; you never need to click Send again for the same draft.
6. **Cancel:** discards the draft. Nothing is sent.

## If a card looks stale or wrong

If you click Send/Edit on an old card and it was superseded by a newer edit, the system automatically shows you the **latest** saved draft instead of failing — just review and act on what it shows you.

## Pausing sending (owner-initiated, notifications continue)

You can turn off the ability to send **without** stopping notifications. On the VPS:

```
docker exec hmz-reply-console-business-live node -e "
fetch('http://127.0.0.1:5691/v1/go-live', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({enabled:false, note:'owner pause'})}).then(r=>r.json()).then(console.log)
"
```

Notifications, Review/Edit/Cancel, and reconciliation all keep working — only the Send action is blocked (`SEND_DISABLED_NOT_GO_LIVE`). To re-enable, repeat with `enabled:true`.

## Checking system health

```
docker exec hmz-reply-console-business-live node -e "
fetch('http://127.0.0.1:5691/v1/watchdog').then(r=>r.json()).then(j=>console.log(JSON.stringify(j,null,2)))
"
```

This reports: unresolved notifications, whether the scheduled recovery poll is running on time, and Instantly API health. Severity `critical`/`high` alerts warrant a look; `medium` are informational.

## Checking for missed replies (bounded, read-only audit)

If you suspect a reply is missing from the console (never notified), run a **dry-run** backfill audit for a specific date range — this never sends anything and never creates anything unless you add `--apply`:

```
docker exec hmz-reply-console-business-live node /app/backfill.mjs --since 2026-07-01T00:00:00Z --until 2026-07-20T00:00:00Z
```

It reports how many applicable replies are missing from the ledger. If you want it to actually create the missing notification contexts (and post a "(backfilled)" Chat notification for each), add `--apply`. Do this deliberately — it will post a visible Chat message per missing item, so only run `--apply` when you've reviewed the dry-run output and decided you want that.

*(Note: as of 2026-07-20, `backfill.mjs` was copied into the running container for one audit run but is not yet baked into the image's `Dockerfile`. If the container is rebuilt without adding it to the `COPY` list, re-copy it with `docker cp` before use.)*

## Rotating the Instantly API key

1. Update the key in the VPS's root-owned `.env` for the reply-console compose service.
2. `docker compose -f docker-compose.hostinger-traefik.yml up -d --no-deps hmz-reply-console` to pick up the new env var (durable data on the named volume is untouched).
3. Confirm via `GET /v1/instantly-fingerprint` that the new key's fingerprint matches what you expect (never prints the key itself).

## Stuck-state recovery

- **A context stuck in `SENDING` or `RECONCILING` for an unusually long time:** the watchdog will surface it. `RECONCILING` contexts are checked automatically every 30 seconds by the sidecar and escalate to a clear `⚠️ could not confirm` message after a 6-minute window — never automatically re-sent. If you need to look manually, `GET /v1/context/{id}` shows the full state and attempt history.
- **Database/VPS restart:** durable state lives on a named Docker volume, unaffected by a container or VPS restart. No token, lock, or delivered-state record is lost. A restore drill against a real backup was independently verified as part of the July 2026 audit (9/9 checks passed) — see the audit evidence file for detail.

## Disaster recovery — restoring from backup

Backups exist at `/root/fable-audit-backups/reply-console-data-*.tgz` (or the equivalent from your own backup schedule). To restore into an **isolated** location for inspection (never directly overwrite `/data` on a live container without first stopping it):

```
mkdir -p /root/restore-check && tar xzf /root/fable-audit-backups/reply-console-data-<timestamp>.tgz -C /root/restore-check
```

Then inspect with `store.mjs`'s functions (`readContext`, `getGoLive`, `getBinding`) exactly as the audit's DR drill did, before deciding whether/how to apply it to the live volume.

## Rollback to notification-only mode

If you want to remove Send/Edit/Cancel capability entirely and keep only the one-way notification message:

1. Set the go-live gate `enabled:false` (see "Pausing sending" above) — this alone blocks all sending while keeping full interactivity for review.
2. To remove interactivity entirely: deactivate the `HMZ — Google Chat Supervised Reply Console` workflow (`G7GIQGt9JOXxITH4`) in n8n. The original one-way `HMZ — Instantly Reply → Google Chat Notification` workflow is unaffected and keeps posting notifications.

## Who to contact / what not to do

- Do not manually edit files inside `/data` on the running container — always go through the sidecar's HTTP API or a proper restore procedure.
- Do not re-run a Send for a context showing "Confirming delivery" or "could not be confirmed" — the system's own reconciliation will resolve it, or a human should verify directly in Instantly before any manual action.
- If you ever see a genuinely wrong prospect/thread/account on a Review card, click **Cancel** and report it — do not click Send.
