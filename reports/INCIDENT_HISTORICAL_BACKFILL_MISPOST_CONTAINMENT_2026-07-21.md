# Incident — Historical-Backfill Mis-Post & Containment (2026-07-21)

**Severity:** HIGH (owner-Chat notification flood; no prospect contact; no send-gate change)
**Status:** CONTAINED + QUARANTINED + LIVE SERVICE RESTORED. 628 accepted as historical; 305 held for a repaired coordinator (separately approved) before release.
**Cause owner:** this Claude Code session (registration-tool error). Owned and reported.

## 1. What happened

While executing the authorised 895+38 historical backfill, registration was performed with
`backfill.mjs --apply` over the manifest range. `runBackfill()` builds its own inbound-service via
`createInboundService({...})` **without passing `notificationEpoch`** (`inbound-service.mjs`).
With `notificationEpoch = null`, `queuePolicyFor()` (`inbound-service.mjs:175-176`) can never return
`HISTORICAL_OWNER_HOLD`, so all 895 pre-epoch records were registered as `NOTIFICATION_QUEUED`
(normal), enriched (legacy contexts created), and then posted to the Google Chat **incoming webhook**
by the trailing `drainOutbox` plus the server's internal 5-second drain — **without** the historical
banner and **without** the 5/min rate limit. The epoch is only applied by the long-running
`server.mjs` service (which injects `INBOUND_NOTIFICATION_EPOCH`), never by a standalone
`backfill.mjs` invocation. Choosing `backfill.mjs` as the "register-as-holds" tool was the error;
the handoff prescribed "register exactly 895 as holds" without naming that tool.

**Exact root cause:** epoch/hold policy is not inherited by `backfill.mjs`; it registered historical
records as live-queued and the drain posted them.

## 2. Timeline (UTC)

- 07:17:37 — r8 deployed healthy (correct, verified).
- 07:21:55 — pre-registration consistency backup taken (`pre-registration-895-...T072155Z`).
- ~07:25:17–07:27:28 — `backfill.mjs --apply` registered 895 as QUEUED (first_seen window).
- 07:25:19–07:40:54 — drain posted 628 of them to Chat (throttled by Chat 429s).
- 07:41:13 — **container stopped** (halt); posting frozen.
- 07:42–07:53 — forensic snapshot, isolation analysis, 267→HOLD, post-containment snapshot.

## 3. Isolation (three-signal, certain)

Failed-run set is exactly the 895 rows with `first_discovery_source='EXPLICIT_BACKFILL'` AND
`first_seen_at` in the incident window (07:25–07:27), all `received_at` pre-epoch (2026-01-15 →
2026-07-05), all within the manifest range. Disjoint from the pre-existing 78 (sources
`COMPLETENESS_AUDIT` 48 / `DISCOVERED_WEBHOOK` 27 / `DISCOVERED_READBACK` 3).

| Set | Count | Disposition |
|---|---:|---|
| Failed-run posted (CHAT_NOTIFIED, all have resource names) | 628 | **Undeletable via API** (webhook) — left posted |
| Failed-run not-yet-posted (was POSTING 20 + RETRYING 247) | 267 | **Moved to HISTORICAL_OWNER_HOLD** |
| Legit pre-existing notified (all post-epoch) | 40 | Untouched (verified 40 before & after) |
| Pre-existing holds | 38 | Untouched (now part of 305 held) |
| Genuine live during incident | 0 | n/a |

Evidence: `/root/forensic-incident-20260721T0730Z/` (raw frozen DB+WAL, logs, meta) and
`.../exports/` (`delete-set.json` = 628 with Chat resource names; `hold-set.json`;
`ambiguous-notified.json` = 0; `failed-run-manifest.json` = 895).

## 4. Deletion feasibility — NOT POSSIBLE programmatically

The console posts via a Google Chat **incoming webhook**
(`https://chat.googleapis.com/v1/spaces/AAQAid4Jl_E/messages?key=…&token=…`) with **no
`Authorization` header** and **no service-account / OAuth Chat-app credential** on the host.
Incoming webhooks cannot delete messages, and `spaces.messages.delete` requires app- or user-auth
that does not exist here. The 628 posted messages therefore **cannot be deleted by this system**.

## 5. Post-containment state (verified)

- inbound 973 / outbox 973; `CHAT_NOTIFIED 668` (40 legit + 628 mis-posted), `HISTORICAL_OWNER_HOLD 305` (38 + 267).
- **Zero** in QUEUED/POSTING/RETRYING → nothing re-posts on restart.
- `quick_check ok`, `foreign_key_violations 0`.
- Global-send record byte-identical throughout: `611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`.
- Container `hmz-reply-console-business-live` **stopped** (backfill/coordinator NOT running).
- No prospect email sent (the notification path has no sender); no campaign/lead/account/workflow/subscription change; r7→r8 image change stands.

## 6. Remaining (owner decisions + fix before any resume)

1. **628 undeletable Chat messages** — manually delete in the Chat UI (space AAQAid4Jl_E; posted
   07:25:19–07:40:54Z; enumerated in `delete-set.json`), or provide a Chat-app/OAuth credential with
   `chat.messages.delete` scope for automated deletion, or accept them.
2. **Restart live service?** Safe now (nothing re-posts; missed live items recover via poll). Held
   pending your call per your "do not restart until verified" instruction.
3. **Fix the registration path** (epoch-aware / true HOLD path) + independent re-verification
   (dry-run manifest, corrected rate-limited coordinator, rollback plan) BEFORE any re-attempt.
   The 305 held items remain correctly held for a proper future release.
4. **Assess failed-run contexts/tokens** — ~895 legacy contexts were created (contexts dir ≈1720);
   confirm no approval tokens were minted and whether the 628 posted cards expose Send/Edit controls.
5. **Re-notify the 628 with banner?** Only after their old posts are deleted (else duplicates).

## 7. Backups / rollback

- Pre-deploy: `/root/backups/pre-r8-deploy-20260721T071409Z`
- Pre-registration (pre-incident DB): `/root/backups/pre-registration-895-20260721T072155Z`
- Forensic (frozen DB+exports): `/root/forensic-incident-20260721T0730Z`
- Post-containment: `/root/backups/post-containment-20260721T0748Z`
- r7 image `94dd2dcb…` and r7 compose backup `…hostinger-traefik.yml.pre-r8.bak` remain for full rollback if desired.
- Quarantine (deleted contexts backup): `/root/quarantine-20260721T0800Z/deleted-contexts` (817 files)
- Post-quarantine: `/root/backups/post-quarantine-20260721T0801Z`

## 8. Owner decision executed (2026-07-21) — accept 628, quarantine, restart

Per owner instruction: **628 accepted** as historical notifications (no deletion attempted, acks
preserved); one explanatory Chat notice posted (`spaces/AAQAid4Jl_E/messages/EfYAA0cJHJs…`).

**Read-only safety sweep (895 records / 817 contexts):** activeReviewToken **0**, drafts **0**,
draft revisions **0**, armed contexts **0** (`go-live.armedContextId=null`), all context state
`PENDING`. Zero historical cards had an actionable draft/token.

**Quarantine (isolated to EXPLICIT_BACKFILL incident set):** deleted **817** context files
(backed up first), nulled **817** `legacy_context_id`, set **817** `send_allowed=0`. Result:
0 failed-run contexts remain, 0 send_allowed. Outbox acks untouched (628 + 267 + 40 + 38).

**Fail-closed proof (post-restart, on deleted historical context ids):** `/draft`→400 `NOT_FOUND`,
`/send`→409 `NOT_FOUND`, `/validate`→409 `NOT_FOUND`. No draft/token/arm/Instantly-POST can
originate from a historical notification.

**Restart:** exact verified r8 image `codex-final-historical-backfill-20260721-r8` (`ac06508f…`),
healthy; NO historical drain (0 queued/posting/retrying). 2 genuine recovery polls observed; live
continuity proven (3 downtime replies recovered & notified). Watchdog: 1 transient
`audit_deep:HEARTBEAT_STALE` alert from the ~9.6h authorized downtime (self-clears at next deep
audit; normal-poll reconciliation shows 0 missing). Global-send `611f5d6e…4522` unchanged.

**Final counts:** inbound/outbox **976** (973 manifest + 3 new live), `CHAT_NOTIFIED` **671**
(40 legit + 628 historical + 3 live), `HISTORICAL_OWNER_HOLD` **305** (267 + 38), 0
queued/posting/retrying/ambiguous. `quick_check ok`, FK 0.

**Next safe step for the 305:** repair `historical-release.mjs`/registration to be epoch-/HOLD-correct,
independently test + dry-run reconcile, obtain separate execution approval, then release ≤5/min with
live-notification priority. Recommended additionally: an explicit server-side code guard rejecting
send/edit/token/arm for `EXPLICIT_BACKFILL`/historical items (defense-in-depth beyond the data
quarantine) — to be added with the coordinator fix.
