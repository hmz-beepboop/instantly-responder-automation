# Google Chat ↔ Instantly Final Operator Runbook

> ## FINAL STATUS — 2026-07-23: SYSTEM COMPLETION PASS
> Production image **r13 = `hmz-reply-console:r13-autoooo-replyable-20260723`** (healthy). Production
> notification epoch **`2026-07-18T18:33:00Z`**. Every post-epoch Instantly-visible identity is
> `CHAT_NOTIFIED` (0 missing). Two controlled outbound sends passed (one POST each, distinct
> recipient/eaccount/thread, 0 duplicate). Global-send record unchanged
> (`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`). 305 pre-epoch records remain
> permanently held. Remaining owner action: **NONE — continue supervised production operation and
> monitor.**
>
> ### Release history after r11
> - **r12 (`r12-cardpresentation-20260723`)** — notification-card presentation: prospect name + full
>   email on automatic/OOO cards; `(recovered)` removed from titles; authoritative Instantly campaign
>   display name resolved through a durable per-campaign cache; obsolete "Campaign details
>   unavailable…" paragraph removed (concise `Campaign: Unknown` / UUID fallback instead).
> - **r13 (`r13-autoooo-replyable-20260723`)** — automatic and out-of-office replies use the ORDINARY
>   supervised reply path. Classification now selects the card label only; it no longer blocks reply
>   eligibility. Their Chat threads map to durable reply contexts, so @Instantly drafting works.
>   Unsubscribe, bounce, mail-system, malformed, routing-incomplete and historical records keep every
>   existing restriction, and nothing auto-sends.
>
> ### Operator workflow to reply from Google Chat (there is NO "Draft" button)
> Open the notification thread → reply in that thread and **mention @Instantly** with your draft text
> → review the private Review card (recipient, sender mailbox, Instantly thread, revision, exact body)
> → click **Send**. To edit: click **Edit** on the Review card, save a new revision (the old one goes
> stale), then Send from the newest card only. This works for ordinary, automatic and out-of-office
> notifications alike.
>
> **Automatic/OOO cards posted before r13** keep their original footer text ("Reply through this Chat
> notification is unavailable for this record type") because old Chat messages are never rewritten or
> reposted. Their threads still become replyable once a poll or auditor pass re-observes the record.
>
> ### PERMANENT STOP-WORK RULE
> **No additional engineering, fixture testing or deployment is authorised without either a reproduced
> production defect, a failed monitored invariant, a security finding, or a new explicit business
> requirement.** Do not restart the historical backfill, post held historical records, run further
> live category fixtures, or build a new image absent one of those triggers.


Production target is `https://n8n.hmzaiautomation.com/api/v1`. Run the
production-target assertion before any n8n operation. Never toggle or rewrite
`/data/go-live.json`.

> **2026-07-21 CORRECTED SCOPE (authoritative).** The live completeness contract covers **new inbound
> from the formal production notification epoch `2026-07-21T16:55:20.330Z` onward**, not all-time.
> The **305** pre-epoch records are **permanent `PRE_EPOCH_HISTORICAL_HOLD`** — never release,
> register, or notify them; keep `historical-release.mjs` and all backfill/drain **disabled**. The
> **628** bulk-mis-posted historical notifications are accepted incident artifacts (acks preserved,
> non-actionable via r9 guard, excluded from live reliability stats). Live server image is
> `codex-historical-guard-20260721-r9`. **Do NOT run `backfill.mjs` to register holds** — it bypasses
> the epoch and posts immediately (root cause of the 2026-07-21 incident). See
> `reports/INCIDENT_HISTORICAL_BACKFILL_MISPOST_CONTAINMENT_2026-07-21.md` and
> `reports/FINAL_LIVE_ACCEPTANCE_PACKET_2026-07-21.md`.

## Mandatory resume gate

1. Read the newest `OPERATION_HANDOFF.md` checkpoint.
2. Re-read the exact global-send file and require SHA-256
   `611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`.
3. Require healthy r7 or its explicitly documented successor, SQLite quick
   check `ok`, zero foreign-key violations, and no `SENDING` or `RECONCILING`
   console context.
4. Observe a genuine successful poll and watchdog after the all-time scan's
   transient 429; require the alert to be resolved.
5. Run exactly one all-time read-only Instantly reconciliation. Respect API
   rate limits and do not overlap it with another deep scan.
6. Compare the current authoritative identity-set manifest with the recorded
   973-identity snapshot. Do not assume the missing count is still 895.

## Historical release authorization

The existing authorization covers only the verified 38
`HISTORICAL_OWNER_HOLD` rows. It does not cover the additional 895 records.
Without explicit expanded authorization, stop before registration or Chat
posting.

After authorization:

1. create a new consistency-safe SQLite and outbound-state backup;
2. generate a sanitized immutable manifest of every authorized identity;
3. refuse if an identity already has a valid Chat resource name;
4. register missing identities and outboxes without creating Send controls;
5. use the durable outbox and require a valid returned Chat message resource;
6. label every pre-console post as historical backfill;
7. release no more than five logical notifications per minute;
8. wait for each acknowledgement before releasing the next item;
9. resume safely after restart from durable state;
10. reconcile the complete Instantly inventory again and require all identities
    `CHAT_NOTIFIED` before proceeding to live inbound/outbound acceptance.

At 933 currently unacknowledged historical identities, five per minute implies
a theoretical minimum posting duration of about 187 minutes. Do not bypass the
rate limit to shorten the run.

## Live acceptance gate

Only after all-time inbound reconciliation passes should the operator prepare
the single mixed-inbound and two-controlled-send approval packet. The exact
approval phrase in the owner's final-closure instruction remains mandatory.
No real prospect may be contacted.

