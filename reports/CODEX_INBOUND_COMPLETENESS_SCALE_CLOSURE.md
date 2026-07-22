# Codex Inbound Completeness and Scale Closure

**Run date:** 2026-07-21 UTC / Europe-London  
**Repository:** `Instantly_Responder_Automation`  
**Branch / HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57c647cd33f346277c6b331b8002d0f90fe`  
**Production n8n:** `https://n8n.hmzaiautomation.com/api/v1`, version `2.25.7`  
**Final verdict:** **CONDITIONAL PASS**

> **Superseding all-time checkpoint — 2026-07-21 05:20 UTC:** the later final
> closure queried the complete safely queryable Instantly history rather than
> the bounded July windows used below. It found 973 unique received identities,
> of which 895 (15 January–5 July 2026) are absent from the durable mirror and
> outbox. The architecture/100k and bounded-window results in this report remain
> valid, but they do **not** establish all-time completeness. For the newer
> all-time contract the current verdict is **NO-GO**. No backfill was applied;
> see `reports/FINAL_ALL_TIME_INBOUND_NOTIFICATION_RECONCILIATION.md`.

The repaired internal Instantly-visible-email contract, durable outbox, independent auditor, cursor handling, outage recovery and explicit 100,000-record workload pass. Production reconciliation has no unexplained post-repair Instantly-to-ledger-to-Chat gap. This is not a `SCALE CLOSURE PASS` because the alleged fifteenth outbound test attempt cannot be attributed through sender, MX and mailbox without provider trace access, and the owner has not authorised a new live mixed-category fixture burst. The current production inventory nevertheless proves fifteen distinct Instantly-visible records and fifteen distinct definite Chat acknowledgements in the burst window.

This report does not claim literal perfection, external-provider availability, visual exactly-once Chat delivery, or a statistically established 100% long-run reliability rate.

## 1. Safety boundary and global send state

The exact global supervised-send record was read before the run, after every deployment, after rollback, after historical registration and at final readback:

```json
{
  "enabled": true,
  "note": "GLOBAL supervised sending — owner re-enabled 2026-07-20 during edit-flow repair",
  "at": "2026-07-20T02:39:57.377Z",
  "armedContextId": null,
  "armedRevision": null,
  "faultInject": null
}
```

Canonical SHA-256: `611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522` before and after. The value, note and original timestamp did not change. No prospect reply was sent. Sender, Shadow, Gate 2, autonomous mode, campaigns, leads, sending accounts, approvals and tokens were not changed.

## 2. Baseline, drift and backups

The worktree was already broadly dirty and staging was empty. It was not reset, cleaned, stashed, replaced, committed or pushed. The five pre-existing relevant production workflows matched the reviewed repository workflow graphs semantically, and the pre-change sidecar matched repository source; no unexplained protected-logic drift was found. Repository workflow files are deploy-safe payloads rather than byte-for-byte live exports: they intentionally omit live IDs/version timestamps and new templates retain `active:false`, while authenticated production readback proves their deployed counterparts active. That packaging/activation metadata difference is expected and explicitly recorded. The deficiencies below existed in the shared design, not only in repository prose. Expected production changes were limited to the inbound-v2 sidecar, two additive workflows, the `reply_received` subscription target, and protected export readback.

Fresh consistency-safe backups were taken before every production write. They include workflow exports, source, image/compose metadata, a root-only environment snapshot, protected subscription records and consistency-checked durable data. Before/after data manifests matched and every final SQLite copy passed readability/quick-check validation.

| Checkpoint | Backup | Manifest SHA-256 |
|---|---|---|
| baseline | `/root/backups/codex-inbound-closure-20260721T005100Z` | `3876af…` |
| immediately pre-r5 | `/root/backups/codex-inbound-r5-predeploy-20260721T030537Z` | `4280be6c…113a` |
| immediately pre-r6 | `/root/backups/codex-inbound-r6-predeploy-20260721T033000Z` | `f8cb9df9…c548` |
| pre-n8n additive workflows | `/root/backups/codex-inbound-r6-pre-n8n-20260721T033600Z` | `faf7c289…39977` |
| pre-subscription switch | `/root/backups/codex-inbound-r6-pre-subscription-20260721T033800Z` | `3590f415…8f0cb` |
| immediately pre-r7 | `/root/backups/codex-inbound-r7-predeploy-20260721T040100Z` | `a5acbb8c…8a26a` |
| pre-historical mirror | `/root/backups/codex-inbound-r7-pre-historical-mirror-20260721T040700Z` | `d7885da8…131c9` |

Protected environment copies remain mode `0600`; their contents are excluded from repository evidence. No unexplained notification worker or migration was running at baseline.

## 3. Findings by severity

### High — repaired

1. **Category exclusion before durable notification.** Recovery/backfill policy could suppress mail-system/bounce records, while older malformed handling could move past records without an individual notification. Automatic/OOO had already caused the July 20 incident. Repaired with one canonical received contract and presentation-only classification.
2. **No transactional notification outbox or independent denominator.** The legacy context plus notification-state files did not establish atomic inbound/outbox persistence, expiring claims, append-only attempt evidence or direct Instantly reconciliation. Repaired with SQLite schema v2 and the independent auditor.
3. **Production Instantly page-size rejection.** The first candidate retained a generic 100 KiB response cap; a real 132,987-byte / 22-record Instantly page failed safely and did not advance the cursor. The old image was immediately restored, proving rollback. r6/r7 use an 8 MiB streamed Instantly page limit while preserving the 100 KiB Chat-response limit.
4. **Legacy acknowledgement migration re-posted seven messages in r6.** Seven early contexts had valid `spaces/.../messages/...` Chat resource names but predated `notificationState`. r6 treated them as unacknowledged and posted seven duplicates. r7 now treats the resource name as definite acknowledgement both at startup and late discovery, has permanent tests, and records `verified_legacy_ack_duplicate_chat_posts=7`. No prospect email was sent.

### Medium — repaired

1. Auditor requeue could have competed with an active posting claim; active leases are now non-stealable and expire into an explicit ambiguous state.
2. Surrogate merge could over-trust a reused RFC Message-ID and could lose attempt evidence; authoritative-field contradictions now prevent merge and both histories are preserved/renumbered.
3. Completeness telemetry used internal applicability rather than a direct external inventory; the current denominator is now Instantly received IDs.
4. Historical owner holds could falsely trigger malformed/unacknowledged watchdog alerts; the explicit hold state is now reported separately and excluded only from active-delivery alarms.
5. The synthetic `SUPPRESS-SELFTEST` record distorted watchdog state. It was proven synthetic, backed up and recoverably quarantined without touching any production context/token/send attempt.
6. Dependency audit required an update; `google-auth-library` is now `10.9.0`, and the exact image reports zero npm audit vulnerabilities.

### Low / external

1. Incoming-webhook response loss cannot establish visual exactly-once Chat delivery. The system chooses at-least-once visibility, deterministic thread keys, explicit probable-duplicate labels and durable counting.
2. No provider-authorised sender/MX/mailbox trace identifies the alleged fifteenth outbound attempt. Classification is `INSUFFICIENT_PROVIDER_EVIDENCE`.
3. A five-minute soak is bounded evidence, not proof against every long-horizon leak.

All evidenced in-scope High and Medium findings were repaired and re-tested.

## 4. Repairs and deployed architecture

- `inbound-contract.mjs` is the only eligibility/normalisation and labelling contract used by webhook, poll, auditor and backfill.
- Every authenticated Instantly inventory record is authoritative received input; bounce/system/malformed/unknown classification cannot make `notificationRequired` false.
- `inbound-v2.sqlite` atomically persists `inbound_records` plus `notification_outbox` before Chat. Unique constraints enforce one logical row each.
- `notification_attempts` is append-only; leases expire; failed or ambiguous responses have no finite retry cap and use bounded backoff.
- A valid 2xx Chat response must include a message resource name before `CHAT_NOTIFIED` is committed.
- Missing Instantly IDs use deterministic `SURROGATE_UNVERIFIED` identities, are notified with Send blocked, and can alias/merge later without discarding prior acknowledgement evidence.
- Recovery poll has overlap, ID deduplication, full pagination, a timestamp-plus-ID cursor, atomic lease and fail-closed cursor commit.
- The independent auditor has its own cursor-free windows and heartbeats: 5-minute/2-hour, hourly/24-hour and daily/7-day.
- Operations and watchdog endpoints expose no raw body or credential and reconcile current state separately from historical counters.
- Pre-epoch records are registered as `HISTORICAL_OWNER_HOLD`; this preserves the separate decision not to flood Chat.

Final sidecar image: `sha256:94dd2dcb55fc4472ed5cc7ef361159a6f0a010119e0926ab8241aebfbd24ea43` (`hmz-reply-console:codex-inbound-closure-20260721-r7`). Source archive SHA-256: `1d11b548fc0676c9cca0fab4494cfaab59a070350098e46ace850d57bd099470`.

## 5. Received-category, bounce and malformed results

The permanent matrix covers ordinary positive/negative/neutral/question, unsubscribe, automatic, OOO, bounce, mailer-daemon, postmaster, delivery status, empty, attachment-only, missing name/address/mailbox/campaign/lead/thread/message/Instantly ID, invalid timestamp, unexpected fields, malformed Unicode, oversized values and unknown type.

For every authoritative received fixture: notification required is true; one durable inbound and outbox identity exists; eventual state is `CHAT_NOTIFIED`; and Send is absent where routing is not authoritative. Bounce/system cards use the mail-system label. Missing-ID fixtures use a surrogate and later alias without duplicate logical identity. Structural tests reject classifier-controlled eligibility, bounce skips, malformed skips and per-path rule duplication.

The exact r7 image suite passed **156/156**: 49 store, 15 enrichment, 13 formatting, 4 dialog, 7 acceptance-F, 5 backfill, 8 recovery, 12 structural, 23 inbound-v2 and 20 HTTP tests. Test-log SHA-256: `f99dcf…d7f`.

## 6. Durable outbox and transport result

The implementation meets the required transactional-outbox invariants: atomic inbound/outbox registration, database-enforced uniqueness, expiring leases, durable attempts, bounded retry scheduling with no terminal exhaustion, definite acknowledgement metadata, crash recovery, independent requeue and no cursor commit over an unrepresented record. A malformed row cannot stop later rows because batch registration and transport claims are independently idempotent.

The transport remains at-least-once under response ambiguity. It does not falsely mark an ambiguous response successful. Definite acknowledgements retain Google Chat resource names. The incoming webhook does not provide a supported lookup that would prove whether an ambiguous post is visually present; exact visual once is therefore not claimed.

## 7. Auditor, cursor and watchdog result

Production workflow `gN9rgLJw9xC4ZnxT` is active with short/deep/daily schedules. It queries Instantly independently of the webhook, normal poll and poll cursor; creates missing inbound/outbox records; requeues unacknowledged notifications; and records discrepancy, snapshot and heartbeat evidence. Recovery source is `COMPLETENESS_AUDIT`.

Deterministic tests passed equal timestamps, inclusive overlap, duplicates across boundaries, page mutation/insertion, partial/final-page failure, 401, 429, 5xx, database interruption, process restart, concurrent workers, stale leases and cursor restoration. API/durable failure prevents cursor advancement. The direct auditor never reads or writes the normal poll cursor.

The watchdog detects missing inbound/outbox, unacknowledged/stuck/ambiguous work, stale poll/auditor heartbeats, cursor lag, enrichment/surrogate/malformed problems, provider failures, Chat failures, store failures and queue/age thresholds. Alerts are durable outside Chat and never substitute for the individual notification.

## 8. Verified burst reconciliation

Direct Instantly inventory for `2026-07-20T22:10:00Z`–`22:20:00Z` yields:

> **15 of 15 Instantly-visible inbound records in this window have definite Google Chat acknowledgement.**

There are 15 unique Instantly IDs, 15 inbound identities, 15 logical notification IDs and 15 distinct hashed Chat resource names. All states are `CHAT_NOTIFIED`; retrying, ambiguous and probable duplicate counts are zero. Latency was 2,303–13,924 ms. The owner's observed 14/14 subset is therefore independently verified; current authoritative state additionally contains a fifteenth one-to-one record. The sanitized item-level ledger is embedded in the machine-readable evidence file.

## 9. Fifteenth-email upstream boundary

Classification: **`INSUFFICIENT_PROVIDER_EVIDENCE`**.

The trailing current Instantly record was created and webhook-notified promptly, but no preserved authenticated snapshot proves which outbound attempt was absent from the owner's earlier visual count. No sender acceptance log, MX receipt, Microsoft/GoDaddy mailbox, junk/quarantine, rule, or tenant message trace was available. Calling it a delivery failure, quarantine event or delayed Instantly ingestion would be guessing. See `reports/FIFTEENTH_EMAIL_UPSTREAM_INVESTIGATION.md` and `docs/MAILBOX_INSTANTLY_GAP_DETECTION_PLAN.md`.

## 10. Full 100,000+ scale and outage result

The exact r7 image ran the full requested workload, not the earlier reduced substitute. It passed **45/45** scale assertions in 615.080 seconds:

| Workload/result | Value |
|---|---:|
| unique / duplicate / logical three-path races | 100,000 / 100,000 / 100,000 |
| race deliveries | 300,000 |
| simultaneous discoveries | 1,000 |
| auto+OOO / bounce-system / degraded / attachment-empty | 10,000 / 10,000 / 15,000 / 5,000 |
| pages / transitions | 102 / 101 |
| final inbound / outbox / `CHAT_NOTIFIED` | 100,000 / 100,000 / 100,000 |
| missing / nonterminal / duplicate logical / prospect POST | 0 / 0 / 0 / 0 |

A sustained mock Chat outage accumulated the full 100,000 backlog: 99,000 explicit failures plus 1,000 response-loss ambiguities, zero false acknowledgements. After restore, four workers drained all 100,000 at 1,638.92/s in 61.016 seconds; final queue/retry/ambiguous/open-attempt counts were zero. The 1,000 possible duplicate posts are the bounded 1% ambiguity deliberately injected into this synthetic workload and are labelled/counted.

Unique registration was 6,229.31/s; duplicate delivery 14,633.99/s; race delivery 8,210.87/s. Maximum RSS/heap was 496,271,360/198,511,200 bytes; final RSS 160,288,768; average CPU 67.72%; database 229,695,488 bytes; checkpointed WAL zero; descriptors 22 before/after; restart recovery 0.552 s. Result-log SHA-256: `ada09575138402a7e27d834543a3e2ed2adad79af3cd8ed0f5d8373a15ae3238`. Full detail: `reports/CODEX_INBOUND_100K_SCALE_RESULTS.md`.

## 11. Production reconciliation

Post-r7 operational state after explicit historical registration is 78 inbound rows, 78 outbox rows, 40 definite Chat acknowledgements and 38 explicit historical owner holds. There are zero queued, posting, retrying or ambiguous rows; zero missing/orphan outbox rows; queue depth zero; SQLite quick check `ok`; foreign-key violations zero; watchdog alerts zero. The 38 holds are all pre-console and are not counted as post-repair mature misses.

| Window | Instantly received | Inbound | Outbox | Chat acknowledged | Owner hold | Active missing/nonterminal |
|---|---:|---:|---:|---:|---:|---:|
| burst, 22:10–22:20 UTC | 15 | 15 | 15 | 15 | 0 | 0 |
| campaign resumption, 12:00–18:30 UTC | 7 | 7 | 7 | 7 | 0 | 0 |
| incident inventory, Jul 19 00:00–Jul 20 18:30 UTC | 21 | 21 | 21 | 21 | 0 | 0 |
| since incident repair, Jul 20 18:30 UTC | 15 | 15 | 15 | 15 | 0 | 0 |
| post-console epoch, Jul 18 18:33 UTC | 37 | 37 | 37 | 37 | 0 | 0 |
| last 24 hours at 04:26 UTC | 22 | 22 | 22 | 22 | 0 | 0 |
| last 7 days at 04:26 UTC | 48 | 48 | 48 | 40 | 8 | 0 active |
| pre-console owner-decision window | 41 | 41 | 41 | 3 | 38 | 0 active |

The seven r6 duplicate-recovery posts are recorded separately and do not change logical identity counts. The pre-console 38 were registered without a Chat attempt; attempt count stayed unchanged and queue depth stayed zero.

## 12. Deployment and genuine scheduled observation

The final workflows are active:

| Function | Workflow ID | Version | Active |
|---|---|---|---|
| legacy notification safety net | `JojqjTVw3KQRtYEN` | `079fa1d2-c7e2-419f-8435-1a273bc2d76f` | true |
| Chat interaction | `G7GIQGt9JOXxITH4` | `127be2da-c0d1-4535-a01c-1e4e22fdd574` | true |
| email-sent reconciliation | `0QqQh78lrgOmvByZ` | `df51ed2a-4a72-45fd-9227-4a4383bb6f15` | true |
| recovery poll | `7LNeDYVaEbuZ4fpO` | `93125fc5-a0d0-45f1-ba03-cab8be296b51` | true |
| watchdog | `5nSbIHky9dQaJvd9` | `08abfa95-d23b-423d-9b03-4f4634bc7293` | true |
| durable notification v2 | `x6vPPurIk8MBBcA8` | `13b1984b-741c-432b-8dd0-8016b226224b` | true |
| completeness auditor | `gN9rgLJw9xC4ZnxT` | `1b2556a0-d430-435c-aa5a-96b21031e1a0` | true |

Post-r7, genuine n8n `mode=trigger` execution evidence includes recovery polls `12588`, `12589`, `12590`, `12592` and `12595` (with further clean cycles continuing), short audits `12593` and `12602`, deep audit `12616`, and daily seven-day audit `12624`. Deep observed 22 records and daily observed 48; both reported zero missing, zero recovered and zero backlog. These are scheduler-created executions, not manual endpoint calls. Exact timestamps are preserved in `reports/codex-inbound-completeness-scale-evidence.json`.

The `reply_received` subscription `019f75ce-f9d4-7a85-9bd9-14059c8c9baf` is active and targets the durable v2 webhook. The `email_sent` subscription `019f7b2f-a48a-705f-b4b1-120d6808a499` remains active and unchanged. The v1 workflow remains active as a safe overlap; disabling notification/poll/watchdog/reconciliation was not used as a deployment technique.

## 13. Synthetic artifact and historical state

The `SUPPRESS-SELFTEST` / `@example.com` record was proven synthetic: absent from Instantly production inventory and unreferenced by real contexts, active tokens, send attempts or reconciliation dependencies. A database backup preceded its recoverable quarantine. Final manifest: `/root/backups/codex-selftest-quarantine-20260721T031800Z.FINAL-MANIFEST.sha256`, SHA-256 `2666638…3270`; the three exact live artifact paths are absent.

The 38 pre-console notifications remain an explicit owner decision. They are now durably mirrored/outboxed as `HISTORICAL_OWNER_HOLD` but were not posted and do not distort post-deployment completeness.

## 14. Security result

The reviewed paths cap request/page/text sizes, normalize invalid Unicode, strip Chat/HTML/control markup, hash bodies instead of logging them, enforce safe state paths, use parameterized SQLite, constrain Chat posting to the fixed Google Chat destination, reject redirects/arbitrary destinations, and expose no public date-range/backfill/message-injection control. Operational endpoints are private-network only. Test controls are disabled. The inbound-v2 modules have no prospect-reply POST adapter.

The exact-image npm audit found zero vulnerabilities. The final repository scan covered 1,320 files / 110,460,915 bytes with zero findings; the independent workflow-export scan found zero credential-shaped values. The network-isolated VPS exact-path scan covered 969 non-protected files / 8,748,530 bytes across release, backups and sanitized evidence with zero findings. Fourteen credential-bearing live/backup environment files are mode `0600`; six `0644` environment-named files are non-secret examples, Compose history or variable-name-only inventories. Protected values were never emitted or copied into repository evidence.

## 15. Rollback result

Rollback was not merely documented: the r5 page-cap failure triggered an actual image rollback. The old container returned healthy, the durable volume was preserved, and the global-send record hash remained exact. r7 rollback sources, image and commands are stored in the pre-r7 backup. The command recreates only `hmz-reply-console` with `--no-deps --no-build`; it does not touch `go-live.json`. Subscription rollback is separately protected in the pre-subscription backup. Durable-data restore remains owner-authorised only because restoring it can discard later evidence.

## 16. Verdict rationale and remaining owner decisions

**CONDITIONAL PASS** is the single verdict. Internal architecture, scale, outage recovery, production mirror and scheduled operation pass. The conditions preventing `SCALE CLOSURE PASS` are external/live-evidence conditions, not an unexplained current Instantly-visible omission:

1. Authorise a controlled live mixed-category inbound fixture run (ordinary, auto/OOO, bounce/DSN, empty/attachment-only, malformed and one intentionally missed webhook) if live category-level acceptance is required. It must never send a prospect reply.
2. Provide narrowly scoped read-only sender and Microsoft/GoDaddy message-trace/mailbox access if exact attribution of the alleged fifteenth outbound attempt or deployment of the isolated mailbox comparator is desired.
3. Decide whether the 38 pre-console historical notifications should ever be posted. Default and current state remain **do not post**.

No mailbox-provider ingestion architecture was deployed, no Instantly thread was fabricated, and no alert is counted as the individual email notification.
