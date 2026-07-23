# OPERATION_HANDOFF.md

Timestamped log of agent sessions. Most-recent entry first. This file is the authoritative execution state for this repo and takes precedence over Obsidian notes for current project status.

---

## Checkpoint — 2026-07-23 00:45 UTC — ✅ r13 PATCH PASS: AUTOMATIC/OOO REPLIES USE THE ORDINARY SUPERVISED PATH

**Trigger:** owner scope correction (2026-07-23) superseding the reply-eligibility parts of the r12
prompt. r12 had already deployed, so it was preserved and this correction shipped as the next sequential
release r13. **SYSTEM COMPLETION PASS is authoritative again now that this functional correction
passes.** The permanent stop-work rule is restored.

**Owner requirement.** Automatic and out-of-office Instantly inbound emails must support the same
supervised Google Chat reply workflow as ordinary inbound emails — notification thread → reply →
mention @Instantly → Review card → review recipient/mailbox/thread/body → one Send click. **Nothing
auto-sends.** Classification must select the visible label only; it must not by itself make a record
non-replyable.

**Exact root cause of "No pending prospect reply is linked to this thread."** One expression, one
consequence chain — proven by code trace plus production readback:

1. `inbound-contract.mjs` computed
   `sendAllowed = authoritativeRoutingComplete && ![AUTOMATIC, OOO, UNSUBSCRIBE, BOUNCE, SYSTEM,
   MALFORMED, UNKNOWN].includes(classification)` → automatic/OOO were `sendAllowed = false`.
2. `inbound-service.mjs enrichAndCreateLegacyContext` returns early on `!record.sendAllowed`
   **before `createContext`** → no durable reply context, and `inbound_records.legacy_context_id`
   stayed `NULL`.
3. `inbound-service.mjs drainOutbox` attaches the Chat acknowledgement only under
   `if (transport.acknowledged && item.record.legacyContextId)` → with a null context id,
   **`attachChatPost` was skipped**, so the Google Chat *thread resource name*
   (`spaces/…/threads/…`) was never written to `/data/thread-index`.
4. The @Instantly mention handler calls `GET /v1/context/by-thread?threadKey=<chat thread resource>`
   → `resolveByThreadKey` found nothing → HTTP 404 `NO_CONTEXT_FOR_THREAD`, which the interaction
   workflow renders as "No pending prospect reply is linked to this thread (it may have expired or
   already been answered)."

So the failure was at **reply-context creation**, and it propagated into Chat-thread linking. It was
never a card-copy problem — the footer was a faithful symptom. The Chat notification itself was always
correct: automatic/OOO records were durably registered, posted and acknowledged normally.

**Classification policy narrowed (the only policy change).** `REPLY_INELIGIBLE_CLASSIFICATIONS` is now
`[UNSUBSCRIBE, BOUNCE, SYSTEM, MALFORMED, UNKNOWN]` — `AUTOMATIC` and `OOO` removed. Classification
detection and precedence are untouched; an unsubscribe containing auto-reply wording still classifies
as unsubscribe and stays non-replyable (tested).

**Ordinary vs automatic/OOO paths are now identical.** One shared mechanism throughout: same
`registerInbound`, same `createContext`, same `attachChatPost` thread association, same
`resolveByThreadKey` lookup, same `createDraft`/`validateReview`/`acquireSend`/`performSend`. No
parallel automatic-reply workflow was created. `store.mjs` and `inbound-store.mjs` were not modified.

**Files changed (6).**
| File | SHA-256 |
|---|---|
| `inbound-contract.mjs` (reply-eligibility list; `(null)` mailbox fix) | `909257737115d7ca2b1a55255b2e0c7e919d104a678e5846a98870bfa6b7d826` |
| `inbound-service.mjs` (link stored Chat ack to a newly created context) | `ee91583bc3c7055da1cb8f02ae78ce8dad77711d703639f08298945644356aed` |
| `package.json` (test wiring) | `057ab5c2f62904f939665fcc9cf42436d7eaa3774f5a89b32e4b190a4eb3a8db` |
| `test-auto-ooo-replyable.mjs` (**new**, 15 tests) | `a48869f2eb5b270f51457d7b1c4e1a1b7b13fab369d93e5964fe28135d4223cb` |
| `test-card-presentation.mjs` (r13 eligibility + `(null)` regression) | `2fa2d2a83b2d896c76e4ca7018971b9dddc9f59271e03da59ffa4254bb85c591` |
| `test-inbound-v2.mjs` (26-category matrix: automatic/OOO now reply-eligible) | `a03a304bb0af5c28831cadbcad561fd0beaab34ae09513706f54ac4e4d40eea3` |

**Unchanged, byte-identical in the running r13 container:** `store.mjs`
`c55490cb5a7a7d3f72504602f0d70b9e57555a306221a53a2a2307e8d88c571b`, `inbound-store.mjs`
`82ba0caed9fbe90d477213a5a7e73812c23dfd756a8cfcf9dc34235ef54b2868`, `enrich.mjs`
`001b425ca220b5d05cf72d8c3fc97fab371c0eac912f62883f8e371476c98fb7` (r12).

**Existing cards heal without being reposted.** When a context is created for a record that was already
acknowledged, the stored `ack_message_name`/`ack_thread_name` are linked through the same
`attachChatPost` path. No Chat message is rewritten, reposted or mutated; the old card keeps its
original footer, but its thread now resolves for @Instantly.

**Additional fix found while generating the required routing-incomplete preview:** the r10 sender line
rendered `Sender mailbox: Hamza Moheen (null)` when `eaccount` was missing. It now renders
`Sender mailbox: unavailable`, with the routing warning naming the missing field. Same function, same
release, regression-tested.

**Tests.** New focused suite **15/15** (ordinary regression; automatic; OOO; recovered; pre-policy card
healed without repost; no-pending-context; exact authoritative routing; routing incomplete; optional
enrichment; historical guard ×2; unsubscribe/bounce/system regression; unsubscribe precedence;
token/stale/duplicate; Chat-parameter override attempt). Full suite inside the exact r13 image
**222/222**. `npm audit` 0 vulnerabilities; `node --check` clean; JSON clean; `git diff --check` clean;
secret scan clean (only a synthetic `key=k&token=t` placeholder in the new test). 100k workload not
rerun — the normaliser, outbox, cursor and acknowledgement architecture are unchanged.

**Deployment.** Rollback backup `/root/backups/pre-r13-20260723T003935Z`, validated (`quick_check ok`,
0 FK violations, 997 inbound, 305 holds; `inbound-v2.sqlite`
`c2c8c37ff40a48a5d4fe6833a06e795a65d72dce2a8481b8fa133e6493ba0afc`), plus `go-live.json`,
`owner-binding.json`, compose and the r12 image id. Image
**`hmz-reply-console:r13-autoooo-replyable-20260723`**, id
`sha256:b2c022bf2a901b5e4d02c824e3bd98d65fba1202f45995f78d71ac1e265660cf`. Exactly one compose line
changed; only `hmz-reply-console` recreated (`--no-deps --no-build --wait`); volume and configuration
preserved; healthy.

**Global-send record: byte-identical before and after** —
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`, `enabled: true`, unarmed. The patch
required no gate change.

**Production verification after deploy.** Health `ok`; `quick_check ok`; FK violations 0; missing/orphan
outbox 0; alerts 0; queued/posting/retrying/ambiguous **0/0/0/0**; 997 inbound / 997 outbox / 692
`CHAT_NOTIFIED`; **305 `HISTORICAL_OWNER_HOLD` unchanged**; `historical_backfill_released` 0 (no drain);
poll heartbeat fresh; auditors fresh; workflows and subscriptions untouched. **Zero prospect reply
POSTs. Zero Google Chat posts caused by this patch.**

**Live read-only verification (no draft, no send).** 16 post-epoch automatic/OOO records, all with
complete authoritative routing. 3 have already been re-observed since deployment and healed: for every
one of them the Chat thread index resolves to its context, and the context's `instantlyEmailId`,
`replyToUuid`, `authoritativeThreadId`, `prospectEmail`, `eaccount` and `campaignId` match the durable
inbound record exactly, with `chatMessageName`/`chatThreadName` linked, state `PENDING`, **0 drafts and
0 send attempts**. The remaining 13 heal automatically the next time a poll or auditor window covers
them (the daily auditor spans 7 days); none is at risk, and no card is reposted.

**Remaining owner action:** optional — reply in a *new* automatic/OOO notification thread mentioning
@Instantly to see the Review card. No controlled live send is required for this patch. GitHub/Obsidian
commits deliberately not made; they belong to the separate audited checkpoint.

---

## Checkpoint — 2026-07-23 00:12 UTC — ✅ r12 PATCH PASS: NOTIFICATION-CARD PRESENTATION REPAIR

**Trigger:** explicit owner-approved business requirement (a narrow, authorised exception to the
permanent stop-work rule). **SYSTEM COMPLETION PASS remains authoritative** — this was a surgical
UI/enrichment patch, not a completeness, routing or send change. The stop-work rule is restored.

**Owner-reported presentation defects (all four fixed):** automatic cards showed no prospect name;
automatic titles carried a visible `(recovered)` suffix; cards showed the campaign UUID instead of the
display name; cards carried a "Campaign details unavailable (campaign context not registered: <UUID>).
Reply routing is unaffected." paragraph.

**Root causes (confirmed against production data, read-only).**
1. **Prospect name.** `enrichAndCreateLegacyContext` returned early on `!record.sendAllowed`, so the
   authoritative prospect-name lookup never ran for automatic/OOO/unsubscribe records. Their cards fell
   back to `record.prospectName`, which is `null` for anything not discovered by the webhook.
2. **`(recovered)`.** `notificationTitle` appended `' (recovered)'` whenever `outbox.recovered=1`. The
   poll and both auditors register with `recovered: true`, so every automatic/OOO card carried it.
3. **Campaign UUID.** `campaignName` was only ever populated from a raw `campaign_name` payload field.
   **No campaign resolver existed anywhere.** The `GET /emails` readback used by the poll/auditors does
   not return `campaign_name`, so those records had only the UUID.
4. **Warning paragraph.** `buildNotificationText` emitted it whenever routing was complete but
   `campaignName` was falsy — i.e. on every poll/audit-discovered card.

**Why ordinary and automatic differed.** Instantly's `reply_received` webhook fires for genuine human
replies but not for auto-responders; automatic/OOO replies only reach the console via the recovery poll
or the completeness auditors. Production readback proved it: post-epoch `CHAT_NOTIFIED` ordinary records
with `first_discovery_source=DISCOVERED_WEBHOOK` carry both `campaign_name` and `prospect_name`, while
**every** automatic/OOO record (`NORMAL_POLL` / `COMPLETENESS_AUDIT` / `DISCOVERED_READBACK`) has
neither. Same campaign `35c31fe3…`: named on webhook rows, `NULL` on readback rows.

**Files changed (6; core store/send/routing modules byte-identical to r11).**
| File | SHA-256 |
|---|---|
| `infrastructure/reply-console/enrich.mjs` (+durable campaign cache) | `001b425ca220b5d05cf72d8c3fc97fab371c0eac912f62883f8e371476c98fb7` |
| `infrastructure/reply-console/inbound-contract.mjs` (title/campaign line/warning) | `b32880a90b36e5cd2fad89ef6778ca684d57c509e35b5468b6fcb2f57a258811` |
| `infrastructure/reply-console/inbound-service.mjs` (enrichment ordering + cached campaign name) | `e1cd162614baaa6227882e606e3078b578960c8bc6017c09122fa4ae2da393e9` |
| `infrastructure/reply-console/package.json` (test wiring) | `dac140690a36281776afbc94a55c3e5b7c74e373f87d349d8c43f61f4c0ff484` |
| `infrastructure/reply-console/test-card-presentation.mjs` (**new**, 20 tests) | `61fff04b93c7c02be0d936dc1e60afd7ba986dcc173dd9cb5dc54bb79a584492` |
| `infrastructure/reply-console/test-card-state.mjs` (one r11 assertion → r12 contract) | `cfe9d08e56b79a25558e5d70bba55b2a3b4be083e35875dff741786fe7098eda` |

**Unchanged, verified byte-identical to r11 inside the running r12 container** (send, persistence and
routing cores were not touched):

| Module | SHA-256 (r11 = r12) |
|---|---|
| `store.mjs` | `c55490cb5a7a7d3f72504602f0d70b9e57555a306221a53a2a2307e8d88c571b` |
| `inbound-store.mjs` | `82ba0caed9fbe90d477213a5a7e73812c23dfd756a8cfcf9dc34235ef54b2868` |
| `server.mjs` | `e69debfd12cc0522c71a3be81d95272719baf229463afeca1b12bad021cc557c` |
| `recovery.mjs` | `2f8e18066dff17c813dfe3243e237f14097f37b30581e81ad4df04a5a8cd416a` |

**Behaviour now.** Prospect: `<name> (<full email>)` when an authoritative name exists, otherwise
`<full email>` — never invented, resolved through the existing `resolveProspectNameByLookup`
(exact-email lead lookup, refuses ambiguous matches) and persisted via the existing
`updateInboundEnrichment`. Campaign: authoritative display name for ordinary, automatic and OOO cards,
resolved once per campaign per 24h into a new durable `/data/campaign-directory` cache that mirrors the
existing account-directory cache (negative results cached too, so an unresolvable campaign cannot storm
the API); the Chat drain reads the cache and never performs network I/O. Fallback is the concise
`Campaign: Unknown` or `Campaign: <UUID>` — no separate paragraph. Titles are `🤖 Automatic Reply` /
`🤖 Out-of-Office Reply` with no `(recovered)`; discovery/recovery source stays in
`first/last_discovery_source`, `discovery_sources_json` and telemetry. Genuine safety signals kept:
routing-incomplete title + warning, and the probable-duplicate prefix.

**Presentation enrichment now runs for every registered record, including non-sendable ones — it grants
no capability.** The `!record.sendAllowed` gate is unchanged and still refuses to create a reply
context; `enrichment_state` still records `BLOCKED_ROUTING`.

**Tests.** New focused suite **20/20**. Full reply-console suite inside the exact r12 image
**206/206** (store 49, historical-guard 13, ooo-and-card 7, card-state 8, **card-presentation 20**,
enrich 15, formatting 13, dialog-contract 4, acceptance-F 7, backfill 5, recovery 8, inbound-structural
13, inbound-v2 23, historical-backfill 1, http 20). `npm audit` 0 vulnerabilities; `node --check` clean
on all modules; JSON parse clean; `git diff --check` clean on the changed paths; targeted secret scan
clean. The 100k workload was deliberately not rerun — no completeness or send logic changed.

**Deployment.** Fresh rollback backup `/root/backups/pre-r12-20260723T000153Z` (consistency-safe
`VACUUM INTO`; validated: `quick_check ok`, 0 FK violations, 995 inbound / 995 outbox / 305 holds;
`inbound-v2.sqlite` `621269b775e34d90aa2bf68b47c60fceaeb1acf526c0a0aec382158370a6e4a9`; plus
`go-live.json`, `owner-binding.json`, compose and the r11 image id). Image
**`hmz-reply-console:r12-cardpresentation-20260723`**, id
`sha256:b5281c6f91ed27fc4ae3634614aa693426c9cd83f2a25ae388c451cc805d0fa8`. **Exactly one compose line
changed** (the image reference); recreated only `hmz-reply-console` with `--no-deps --no-build --wait`;
durable volume and configuration preserved; container healthy.

**Global-send record: byte-identical before and after** —
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`, `enabled: true`, unarmed. Never
toggled or rewritten.

**Production verification after deploy.** Health `status: ok`, `inboundStoreIntegrity: true`;
`quick_check ok`; foreign-key violations 0; missing/orphan outbox 0; alerts 0; queued/posting/retrying/
ambiguous **0/0/0/0**; 995 inbound / 995 outbox; 690 `CHAT_NOTIFIED`; **305 `HISTORICAL_OWNER_HOLD`
unchanged**; `historical_backfill_released` 0 and `historical_backfill_notified` 0 (no drain); poll
heartbeat fresh (00:11:35Z); auditors fresh. **Zero prospect reply POSTs. Zero Google Chat posts. Zero
notification attempts and zero new reply contexts since deployment.** No campaign, lead, account,
mailbox, workflow, subscription, Shadow, Gate 2 or autonomous change.

**One count movement investigated and cleared.** `ooo` moved 28 → 27 (`ordinary` 901 → 902) across the
restart. Cause: the **pre-existing startup legacy-acknowledgement import** ("legacy ack imported 49")
re-observes stored legacy contexts as `DISCOVERED_READBACK`; `registerOneInTransaction` recomputes
`classification` from the re-observed payload, and one record's legacy preview text no longer matched
the OOO pattern. This lives in `inbound-store.mjs`, which is **byte-identical to r11**, and the r11→r12
diff proves `classifyInboundLabel` and `normalizeInstantlyReceived` were not touched — the patch only
changed `notificationTitle` and `buildNotificationText`. It would occur on any restart of r11. Impact
is nil: that record has been `CHAT_NOTIFIED` since 2026-07-20, its context predates this work
(created 2026-07-20T13:07:35Z), and 0 contexts, 0 outbox writes and 0 notification attempts occurred
after deployment. **Logged as a pre-existing LOW observation, not repaired** (out of scope): a record's
classification and `send_allowed` can be recomputed on re-observation when a readback payload's preview
differs from the original. Related pre-existing LOW observation: the re-observation UPDATE does not
refresh `updated_at` (only `last_seen_at`/`observed_at`), so `updated_at` understates recency.

**Card previews (sanitised, generated read-only; no real card was reposted).**
Ordinary and automatic/OOO now render identically apart from the classification label and the
Send affordance, e.g.
`🤖 Automatic Reply` / `Prospect: Noah Cole (noah@example.com)` /
`Sender mailbox: Hamza Moheen (hamzah@hmzautomation.com)` /
`Campaign: Test Batch Run - Cold Email Outbound` — no `(recovered)`, no unavailable paragraph.

**Note on the campaign cache.** `/data/campaign-directory` is created on the first registration after
deployment. Enrichment always precedes the outbox drain in every ingestion path (webhook, poll,
auditor), so the cache is warm before the first card is posted.

**Remaining owner action:** none for this patch. GitHub/Obsidian commits are deliberately **not** made
here — they belong to a separate audited checkpoint after PATCH PASS.

---

## Checkpoint — 2026-07-22 — REMOTE BACKUP VERIFIED; PROJECT CLOSED AT SUPERVISED GOOGLE CHAT BASELINE

**Closure decision:** the owner elected to close this project at the supervised Google Chat
reply-console baseline. **SYSTEM COMPLETION PASS** remains authoritative. The accepted system is
human-written, human-approved and supervised; autonomous sending is neither claimed nor authorised.

**Project checkpoint:** GitHub repository `hmz-beepboop/instantly-responder-automation`, branch
`checkpoint/instantly-r11-system-complete-20260722`; implementation commit
`0c9320dad153503de06af2c69edcd4782c57d4c1`, documentation commit
`bd837e6baf71bebcf20d726e698d0d1e9b7954bc`, and prior checkpoint handoff commit
`910837f62b48de8d4a6a3475082c6c1ec6b9b691`. Remote-match verification passed for that checkpoint
branch, `safety/instantly-responder-supervised-complete-r11-20260722`, and annotated tag
`instantly-responder-supervised-complete-r11-20260722`, all resolving/peeling to `910837f62b48de8d4a6a3475082c6c1ec6b9b691`.
Final closure references created at this closure commit are branch
`checkpoint/instantly-responder-project-closed-r11-20260722`, safety branch
`safety/instantly-responder-project-closed-r11-20260722`, and annotated tag
`instantly-responder-project-closed-r11-20260722`.

**Obsidian:** canonical note `02_PROJECTS/INSTANTLY_RESPONDER.md` in `hmz-business-brain` contains
"Google Chat Supervised Reply Console — Final Closure" at commit
`07420773b0f3ce7779bf3987adbadd65f8c66dc5`; `origin/main` was fetched and verified at that exact
commit before final project closure.

**Scope and safety:** Draft Memory V2, Draft Learning experiments/candidates, blocked RFC work, B6
proxy/historical repair packages, SL-PHASE-5Q backups, historical exports, rollback payloads,
live-incident evidence, temporary files and all unrelated dirty-tree work were intentionally excluded.
The broad primary dirty tree remains untouched; only this handoff file was staged in an isolated clean
worktree. Targeted secret/PII checks found no committed secret. No production, n8n, Instantly, VPS,
Gmail, Google Chat, credential, workflow, campaign, lead, database, send, deployment or other outbound
action occurred during closure. No force push occurred.

**Permanent stop-work rule:** supervised production may continue to run and be monitored, but future
engineering requires a reproduced production defect, failed monitored invariant, security finding or
explicit new business requirement. Project closure means no further engineering; it does not disable
the accepted running supervised service.

**Regression Safety Check:** latest baseline `910837f62b48de8d4a6a3475082c6c1ec6b9b691`; latest
pre-existing handoff entry "GITHUB + OBSIDIAN FINAL CHECKPOINT COMPLETE" (2026-07-22 02:05 UTC).
Checked the two accepted commit file lists and `ed94d57..bd837e6` diff, r11 runtime hashes, all six
console workflows, 186/186 isolated tests, accepted/final Git refs, this staged handoff diff and the
canonical Obsidian note delta. No broad rewrite or deletion, excluded work staging, stale-template
overwrite, r7/r8 regression, historical release/drain reactivation, autonomous path, global-send
mutation or risk of reverting current production was introduced; the primary dirty tree was preserved.

---

## Checkpoint — 2026-07-22 02:05 UTC — GITHUB + OBSIDIAN FINAL CHECKPOINT COMPLETE

**Project state:** SYSTEM COMPLETION PASS remains authoritative. No production, workflow, campaign,
account, lead, database, global-send or outbound action occurred during this checkpoint (read-only
local hash verification only; local r11 source matched recorded evidence exactly — inbound-contract
`a1561d00`, inbound-service `e3f7d88e`, store `c55490cb`, inbound-store `82ba0cae`).

**GitHub:** final accepted console state audited for regression and secrets, committed on checkpoint
branch `checkpoint/instantly-r11-system-complete-20260722` (from baseline `ed94d57`). Build/documentation
commits: `0c9320dad153503de06af2c69edcd4782c57d4c1` (feat: reply-console runtime + 6 console workflows +
tests + deploy compose + scan script) and `bd837e6baf71bebcf20d726e698d0d1e9b7954bc` (docs: closure
reports + runbooks + evidence). No force push. Explicit path-based staging only; the whole worktree was
never staged.

**Obsidian:** canonical note `02_PROJECTS/INSTANTLY_RESPONDER.md` in `hmz-business-brain` updated with a
"Google Chat Supervised Reply Console — Final Closure" section, committed at
`07420773b0f3ce7779bf3987adbadd65f8c66dc5`. Business-brain had no unrelated pending changes.

**Safety references (created at the final checkpoint commit):** annotated tag
`instantly-responder-supervised-complete-r11-20260722` and safety branch
`safety/instantly-responder-supervised-complete-r11-20260722`.

**Regression audit:** r11 runtime hashes, durable inbound/outbox completeness architecture,
server-authoritative outbound routing, r9 historical send-guard, global-send record and the permanent
stop-work rule all preserved. No r7/r8 logic reintroduced; degradedMetadata card overload removed by
r11; no auto/OOO/bounce/malformed exclusion; no historical release/drain reactivated. Secret + PII scan
clean on all committed files. One live-incident evidence file bearing a real production identifier and
all unrelated prior-subsystem work (Draft Memory V2 / Draft Learning / B6 proxy / SL-PHASE-5Q backups)
were intentionally left unstaged.

**Push status:** `git push` from this agent session was blocked by the local command-safety classifier;
the commits, branch, tag and Obsidian commit exist locally and must be pushed by the owner (commands
provided). No force push in any command.

**Operating instruction:** continue supervised production and monitor. Reopen engineering only for a
reproduced defect, failed invariant, security finding or explicit new business requirement.

---

## Checkpoint — 2026-07-22 01:47 UTC — ✅ SYSTEM COMPLETION PASS (FINAL CLOSURE)

**Verdict: SYSTEM COMPLETION PASS.** Read-only production closure completed; no production state
changed. Final image **r11 `codex-cardstate-20260722-r11`** healthy; deployed hashes match recorded
evidence (contract `a1561d00`, service `e3f7d88e`, store `c55490cb` guard, inbound-store `82ba0cae`).
Global-send record byte-for-byte unchanged, canonical
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`, `armedContextId:null`.

**Production epoch `2026-07-18T18:33:00Z`.** Post-epoch reconciliation (read-only): Instantly received
51 observed, **missing inbound 0 / missing outbox 0**; durable post-epoch inbound 54 / outbox 54 /
CHAT_NOTIFIED 54; queued/posting/retrying/ambiguous 0; duplicate logical 0 → every post-epoch
Instantly identity is `CHAT_NOTIFIED`. Global durable: 987/987, 682 notified, 305 held.

**Outbound consolidated:** Send A (F1) → `alinazahidkhan890@gmail.com` via `hamzah@hmzautomation.com`,
thread `86-1-WxpS…`, rev1 hash `18735e40…`, 1 POST, `SENT_API_CONFIRMED`, stale→0; owner inbox
confirmed. Send B (F2) → `humzaabbas1357@gmail.com` via `hamzah@gethmzautomation.com`, thread
`86--eKoz…`, rev2 (edited) hash `c816afc4…`, 1 POST, `SENT_API_CONFIRMED`, dup/stale→0; owner inbox
confirmed. Total POSTs 2, extra 0, distinct recipient/account/thread.

**Ops health:** quick_check ok, FK 0, watchdog 0, poll+short/deep/daily auditors fresh; reply_received
(Notification v2 Durable) + email_sent Reconciliation workflows ACTIVE; no historical release/drain
process; no historical backlog competing with live. **Historical:** 305 held (`PRE_EPOCH_HISTORICAL_HOLD`),
non-actionable (quarantine + r9 guard), never posted; 628 incident-artifact acks preserved & excluded
from live stats. **F3/F4/F5 waived** by owner. **Known defects:** no HIGH/MEDIUM; one LOW (auto/OOO
classification precision — completeness/safety unaffected). **External:** Google Chat/Instantly are
external providers; future provider failure cannot be precluded (durable retry + watchdog mitigate).

**PERMANENT STOP-WORK RULE (in effect):** no further engineering, fixture testing, or deployment
without a reproduced production defect, a failed monitored invariant, a security finding, or a new
explicit business requirement. Remaining owner action: **NONE — continue supervised production and
monitor.** Reports updated: FINAL_GOOGLE_CHAT_INSTANTLY_SYSTEM_COMPLETION(.md/.json),
FINAL_CONTROLLED_OUTBOUND_RECIPIENT_ACCEPTANCE.md, (reframed) production-epoch reconciliation,
operator runbook.

---

## Checkpoint — 2026-07-22 01:30 UTC — r11 DEPLOYED: CARD-STATE SEMANTICS REPAIR (routing vs enrichment separation)

Owner-flagged correctness defect fixed. **r11 = `codex-cardstate-20260722-r11`** (`inbound-contract.mjs`
`a1561d00`); diff vs r10 = inbound-contract.mjs + test files ONLY; **store.mjs `c55490cb` (guard) and
inbound-service.mjs `e3f7d88e` (sender-name) byte-identical**. Single compose flip; healthy; gate
`611f5d6e…4522` unchanged; integrity ok, FK 0, watchdog 0, no drain (hold 305).

**Root cause:** one overloaded `degradedMetadata` boolean (`= metadataIssues.length>0`, i.e. ANY
missing field incl. optional `lead_id`/`message_id`/`thread_id`) drove BOTH the "Metadata Incomplete"
header and the "Reply sending is blocked until authoritative routing is recovered" footer. F1/F2 were
routing-complete (eaccount+prospect+instantly id present; sends succeeded) yet showed both warnings.
**Proven:** `store.mjs` send path (performSend/acquireSend/createDraft/validateReview) has ZERO
`degraded` references — degradedMetadata was presentation/telemetry only, never a send gate; the real
`sendAllowed` derives from routing+classification, not campaign enrichment.

**Fix:** explicit independent dimensions — `isAuthoritativeRoutingComplete(record)` (identityKind
INSTANTLY && eaccount && prospectEmail && (threadId||instantlyEmailId)); `missingRoutingFields()`;
`optionalEnrichmentComplete`. Card header/footer now key on ROUTING completeness only. Routing
complete + optional gap → normal card (+ narrow "Campaign details unavailable" note only when campaign
missing); routing incomplete → "⚠️ Routing Incomplete", lists missing fields, no Send, "unavailable
until authoritative routing is recovered". `degradedMetadata` retained for telemetry (100k scale
counts unaffected). No send/routing/token/revision/dup gate weakened; recipient/eaccount/reply_to_uuid
/thread derivation, historical guard, gate, campaigns/leads/accounts untouched.

**Tests:** new `test-card-state.mjs` **8/8** (cases A–F: campaign-unknown→Send ok; missing
prospect/eaccount/id→routing warning+no Send; name/mailbox fallbacks). Updated `test-inbound-v2` +
`test-recovery` "Metadata"→"Routing" (both genuinely routing-incomplete). Full r11 image suite
**186/186**. Deployed F1/F2 card preview: header "🔔 New Instantly Inbound Email" (no Metadata
Incomplete), Prospect full email, Sender mailbox display name+address, @Instantly footer (no false
block). Guard fail-closed re-confirmed (`/send`→409 NOT_FOUND). Backup `pre-r11-deploy-20260722T012742Z`;
r10 image + `…yml.pre-r11.bak` retained. **F3/F5/F4 may now proceed.**

---

## Checkpoint — 2026-07-22 01:12 UTC — r10 DEPLOYED: OOO CLASSIFIER + NOTIFICATION-CARD FIXES (owner-requested)

Two owner-approved fixes, deployed as **r10 = `codex-card-ooo-20260722-r10`** (`7b78e9ef`). Diff vs r9
= only `inbound-contract.mjs` + `inbound-service.mjs` (+ new `test-ooo-and-card.mjs`); store.mjs guard
byte-identical (`c55490cb`). Single compose tag flip; healthy; gate `611f5d6e…4522` unchanged;
integrity ok, FK 0, watchdog 0, no drain (hold 305).

**Fix 1 — OOO classifier (root cause found during F3 live test):** two genuine Gmail
vacation-responder auto-replies were classified `ordinary` because (a) Instantly did not set
`is_auto_reply`, and (b) the OOO regex `out[ -]?of[ -]?office` did not match **"out of THE office"**.
Broadened to `out[ -]?of[ -]?(?:the[ -]?)?office`. (Every such reply was still notified — completeness
held; only the label was wrong.)

**Fix 2 — notification card missing prospect email + mailbox name:** `sanitizeChatText` strips
`<…>`, so the template `Name <email>` rendered as name-only (email deleted); and the sender display
name wasn't resolved at notification time (only at draft). Now: prospect line shows `Name (email)`
(sanitizer-safe), and the live path resolves the sending-mailbox display name from the durable
account cache (`getCachedAccount`+`normalizeName`) → `Sender mailbox: Hamza Moheen (hamzah@…)`.
Historical redacted cards unchanged. Reconstructed live cards confirm both fields now present.

Tests: `test-ooo-and-card.mjs` **7/7** + full r10 image suite **178/178**. Backup
`pre-r10-deploy-20260722T010856Z`; r9 image + `…yml.pre-r10.bak` retained.

**Observation (not yet fixed, unrequested):** for records with `degradedMetadata=true` (unregistered
campaign `860453af` → campaign_context UNKNOWN), the card footer says "Reply sending is blocked until
authoritative routing is recovered", yet sending actually worked (Send A/B). The degraded flag
conflates campaign-context-unknown with routing-incomplete. Flagged for owner; left unchanged.

**Still pending for SYSTEM COMPLETION PASS:** owner re-trigger F3 (genuine "out of the office" →
now labels OOO), F5 (empty/attachment-only), F4 (unsubscribe, LAST); then from-epoch reconciliation
+ verdict.

---

## Checkpoint — 2026-07-22 00:35 UTC — LIVE ACCEPTANCE: F1/F2 NOTIFIED; SEND A + SEND B FULLY PASSED; F3–F5 PENDING

Crash-recovery readback confirmed clean (F1/F2 CHAT_NOTIFIED+PENDING, 0 drafts/tokens/attempts,
incident contained, gate `611f5d6e…4522`, watchdog 0). Real Google Chat workflow used
(@Instantly mention → Review card → Send; **no Draft button**).

**Send A (F1, unedited) — PASS.** ctx `4765a1b3…`, recipient `alinazahidkhan890@gmail.com`, eaccount
`hamzah@hmzautomation.com`, thread `86-1-WxpS69xd1JM68kPWij0FP`, reply_to_uuid `019f86f7-bf57…`,
rev1 body hash `18735e40…76c18c` (independently re-verified). Terminal `SENT_API_CONFIRMED`,
**sendAttemptCount=1** (HTTP 200). Owner-confirmed: exactly one reply in `alinazahidkhan890`, correct
From/subject/thread/body; `humzaabbas1357` did NOT receive it. Stale re-click → `NO_ACTIVE_DRAFT`,
**0** extra POST; no new revision/token.

**Send B (F2, edited) — PASS.** ctx `06b6c39b…`, recipient `humzaabbas1357@gmail.com`, eaccount
`hamzah@gethmzautomation.com`, thread `86--eKozl7_zFmnRANH1W_NNdN`, reply_to_uuid `019f86f8-18ed…`.
Rev1 `eaf05fa2…` (edited via Edit → rev2, rev1 stale, never sent); rev2 body hash `c816afc4…abeb6772`
sent. Terminal `SENT_API_CONFIRMED`, **sendAttemptCount=1** (rev2, HTTP 200). Owner-confirmed edited
body in `humzaabbas1357` only; `alina` did NOT receive it. Duplicate click (card converted in place to
rev2) → `NO_ACTIVE_DRAFT`; server replay probes (stale rev1 + empty) → HTTP 409 `NO_ACTIVE_DRAFT`,
**0** extra POST. Gate unchanged throughout.

**Outbound acceptance COMPLETE:** server-authoritative routing, 1 POST each, exact bodies, correct
recipient/mailbox/thread, zero wrong-inbox, duplicate/stale → 0 extra POST.

**Pending for SYSTEM COMPLETION PASS:** mixed-category inbound fixtures F3 (auto/OOO — genuine
provider auto-reply required, else NOT SAFELY MANUFACTURABLE LIVE), F5 (empty/attachment-only,
classification reported honestly), F4 (unsubscribe, run LAST) on campaign `531e64ed` `53-…` threads;
then final from-epoch reconciliation + verdict. Packet:
`reports/FINAL_LIVE_ACCEPTANCE_PACKET_2026-07-21.md`.

---

## Checkpoint — 2026-07-21 17:35 UTC — SCOPE CORRECTED TO LIVE-EPOCH CONTRACT; r9 HISTORICAL GUARD DEPLOYED; LIVE HEALTH GATE PASSED

**Owner scope correction:** "every Instantly email" = every NEW inbound **from the formal
operational epoch onward**, NOT all-time. Consequences applied:
- **Formal production notification epoch = `2026-07-21T16:55:20.330Z`** (r8 restart/containment
  StartedAt, from `docker inspect` production evidence). Live completeness contract runs from here.
- The **305** held (267 failed-run + 38 original) are **permanent PRE_EPOCH_HISTORICAL_HOLD** — do
  NOT release/register/notify. `historical-release.mjs` and all backfill/drain stay disabled.
- The **628** posted historical notifications are **accepted incident artifacts**: acks preserved,
  not deleted, not reposted, permanently non-actionable, **excluded from live reliability stats**.
- Pre-epoch records are outside the live contract (not failures/successes/denominator).

**Live contract (from epoch):** every Instantly-received email → durable inbound → outbox →
definite Chat ack → CHAT_NOTIFIED. Verified: Instantly received since console go-live
(2026-07-18T18:33) reconciled 0 missing; **all post-epoch durable items CHAT_NOTIFIED**; the
downtime/live replies (13:11Z + later) recovered correctly. Live inbound grew normally to 977+.

**Defence-in-depth guard shipped (r9 = `codex-historical-guard-20260721-r9`, `ed5d416a`):** single
surgical `store.mjs` change — `isHistoricalActor()` (EXPLICIT_BACKFILL or receivedAt < notification
epoch) now hard-denies createContext / createDraft / validateReview / performSend / arm with
`HISTORICAL_NON_ACTIONABLE`. Diff vs r8 = store.mjs only (+ new `test-historical-guard.mjs`).
Targeted tests: guard **13/13**, store 49/49, inbound-v2 23/23, historical-backfill 1/1, recovery
8/8 (100k scale suite NOT rerun — core inbound/outbox logic unchanged). Deployed via single compose
tag flip; healthy; prod fail-closed re-confirmed (`/draft`→400, `/send`→409 NOT_FOUND).

**Live health gate PASSED:** deep auditor fired 17:20:35Z (fresh), `audit_deep:HEARTBEAT_STALE`
**cleared automatically**, watchdog `alertCount 0`, quick_check ok, FK 0, gate
`611f5d6e…4522` unchanged. Counts: `CHAT_NOTIFIED 672`, `HISTORICAL_OWNER_HOLD 305`,
queued/posting/retrying/ambiguous 0.

**Next:** prepare the final live-acceptance packet (mixed inbound fixtures + 2 controlled sends,
owner-controlled addresses). **Do NOT trigger any fixture/send** until the owner provides
`APPROVE FINAL CLOSURE: MIXED INBOUND FIXTURES AND TWO CONTROLLED GOOGLE CHAT SENDS`. Packet:
`reports/FINAL_LIVE_ACCEPTANCE_PACKET_2026-07-21.md`. Backup: `pre-r9-deploy-…T172901Z`;
r8 image + `…yml.pre-r9.bak` retained for rollback.

---

## Checkpoint — 2026-07-21 17:00 UTC — r8 DEPLOYED; BACKFILL MIS-POST INCIDENT → CONTAINED, QUARANTINED, LIVE SERVICE RESTORED; 305 HELD FOR REPAIRED COORDINATOR

**r8 deployed correctly** (Phase 0/1 fully verified: image `ac06508f…` source byte-identical to
repo; global-send hash `611f5d6e…4522` unchanged; 2 genuine polls observed; internal 5s drain +
30s sweep confirmed; full exact-image suite reproduced, sole non-pass a stale VPS-copy Dockerfile
that does not affect the built image). Compose flipped r7→r8 (single image-tag line; backup
`…hostinger-traefik.yml.pre-r8.bak`).

**INCIDENT during registration.** `backfill.mjs --apply` was used to register the 895. It builds
its own inbound-service WITHOUT `notificationEpoch`, so `queuePolicyFor` never set
`HISTORICAL_OWNER_HOLD`; all 895 pre-epoch records registered as `NOTIFICATION_QUEUED` and the drain
posted them to the Google Chat webhook (no banner, no rate limit). Chat 429-throttling limited it to
**628 posted** before halt. **No prospect email** (notification path has no sender); global-send
record **byte-identical throughout**.

**Contained** (container stopped 07:41:13Z; all fixes via throwaway containers on the frozen volume):
forensic snapshot taken; failed run isolated with certainty via
`first_discovery_source='EXPLICIT_BACKFILL'` + incident-window `first_seen_at` (895, all pre-epoch,
in manifest range); **267 not-yet-posted → HOLD**; **628 posted are UNDELETABLE via API** (incoming
webhook, no delete-capable credential) — enumerated with resource names in
`forensic-incident-20260721T0730Z/exports/delete-set.json`. Legit **40 notified + 38 holds
untouched** (verified before & after). Final state: inbound 973 / outbox 973, `CHAT_NOTIFIED 668`
(40 legit + 628 mis-posted), `HISTORICAL_OWNER_HOLD 305` (38 + 267), 0 queued/posting/retrying;
`quick_check ok`, FK 0. Container **left stopped**; backfill/coordinator **NOT running**.

**Owner-directed resolution EXECUTED (Option 2 + accept-628):** Safety sweep found **0 tokens,
0 drafts, 0 revisions, 0 armed** across all 895/817 (all `PENDING`; `armedContextId=null`).
**Quarantine:** deleted 817 failed-run context files (backed up), nulled 817 `legacy_context_id`,
set 817 `send_allowed=0` — isolated to `EXPLICIT_BACKFILL` incident set; outbox acks untouched.
**Fail-closed proven** (deleted historical ids): `/draft`→400, `/send`→409, `/validate`→409, all
`NOT_FOUND`. **628 accepted** as historical (no deletion — webhook can't delete; acks preserved);
one explanatory Chat notice posted. **Restarted exact r8**, healthy, **no historical drain**; 2
genuine polls; **live continuity proven** (3 downtime replies recovered); watchdog has 1 transient
`audit_deep:HEARTBEAT_STALE` (downtime artifact, self-clears). Global-send `611f5d6e…4522`
unchanged throughout; no prospect email sent.

**Final live state:** inbound/outbox **976** (973 + 3 new live), `CHAT_NOTIFIED` **671**, HOLD
**305**, 0 queued/posting/retrying/ambiguous; `quick_check ok`, FK 0.

**Remaining (owner):** the **305 held** (267 failed-run + 38 original) await release ONLY after
`historical-release.mjs`/registration is repaired to be epoch/HOLD-correct, independently tested,
dry-run reconciled, and **separately approved** (≤5/min, live priority). Recommended: add an explicit
server-side code guard denying send/edit/token/arm for historical items. Full report:
`reports/INCIDENT_HISTORICAL_BACKFILL_MISPOST_CONTAINMENT_2026-07-21.md`; memory:
`backfill-mjs-bypasses-notification-epoch`. Backups: `pre-r8-deploy-…T071409Z`,
`pre-registration-895-…T072155Z`, `forensic-incident-20260721T0730Z`, `post-containment-…T0748Z`,
`quarantine-20260721T0800Z`, `post-quarantine-…T0801Z`; r7 image `94dd2dcb…` retained.

---

## Checkpoint — 2026-07-21 06:37 UTC (07:37 BST) — 973-ID BACKFILL AUTHORISED; r8 VERIFIED; DEPLOYMENT BLOCKED BY EXECUTION ALLOWANCE

The owner explicitly authorised the exact signed all-time set:
`AUTHORIZE ALL-TIME HISTORICAL BACKFILL FOR MANIFEST
38d9530da608f7d51cdf5bb3eca6d66fdb3f3564e2b0c49b1b36e5a111cf536a:
REGISTER AND NOTIFY THE 895 MISSING IDENTITIES AND RELEASE THE 38 VERIFIED
HOLDS`. This supersedes the owner-decision blocker in the 05:20 checkpoint,
but does not change the manifest, its fixed end
`2026-07-21T05:20:00.000Z`, or its 973-ID / 895+38 bounds.

Prepared the bounded r8 release implementation locally. It adds an internal,
restart-safe historical-plan ledger, snapshots exactly the signed range, allows
at most one unacknowledged historical item at a time, enforces a durable
minimum 12.5-second interval (no more than five logical releases/minute), and
requires definite Chat acknowledgement before releasing the next item. The
range is pinned so a newer live inbound cannot invalidate or enter the signed
manifest. Historical cards have the required pre-console banner and no Send
control/body preview. The coordinator has no Instantly API, Chat URL, or
prospect-send adapter; the existing durable outbox worker remains the sole Chat
transport.

Proof completed before any deployment: local permanent suite **158/158**;
exact built-image suite **158/158**; npm audit **0 vulnerabilities**; source and
workflow-fixture secret scans clean. Source archive
`/root/codex-final-historical-backfill-r8.tar.gz` SHA-256
`9cdd4fa09e8e838b30dd1cda64084b85a9552ff033cfe764a9506873b14c2c53`.
Built but **not deployed** image
`hmz-reply-console:codex-final-historical-backfill-20260721-r8`, image ID
`sha256:ac06508f489b6759582e6898e064aa3fd5b9c6303d41f570f95348a315f5aaaa`.
The completed 100,000-event evidence was correctly not rerun because this
change does not alter normalization, inbound/outbox persistence, cursoring,
retry, or acknowledgement semantics.

Fresh immediately pre-change rollback backup passed at
`/root/backups/pre-r8-historical-backfill-20260721T063300Z`: SQLite backup API,
quick check `ok`, zero FK violations, 78 inbound / 78 outbox, readable durable
archive, stable before/after legacy manifests, seven unchanged workflow
exports, sanitized subscriptions/config/image metadata, and secret scan zero
findings. `SHA256SUMS` SHA-256:
`cd7750fcb84d99ed36a9455eb3824d2f096a2e9dedac0d5aae0b2cecf756208b`.
The earlier `...T063000Z` directory is marked `INCOMPLETE_DO_NOT_USE` after a
tar-pattern failure and is not a rollback artifact.

The production command channel then refused further privileged operations
because the Codex execution allowance was exhausted (reported reset: 2026-07-25
04:42). This occurred before the compose/image deployment. Do not bypass this
control. Last production readback remains healthy r7
`sha256:94dd2dcb55fc4472ed5cc7ef361159a6f0a010119e0926ab8241aebfbd24ea43`
with exact enabled global-send SHA-256
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`.
No production source/workflow/subscription/gate/context/token was changed; no
historical Chat post and no prospect email POST occurred. Production therefore
still has 78 inbound / 78 outbox / 40 `CHAT_NOTIFIED` / 38 holds, with the 895
signed identities still unregistered.

**Resume surgically:** do not repeat the all-time scan, 100k suite, local suite,
or image build unless hashes contradict this checkpoint. Re-read gate/health,
verify the r8 image/archive and pre-r8 backup hashes, change only the compose
reply-console image tag to r8, recreate only that service with its existing
volume, and read the gate back. Then take a fresh pre-registration SQLite
backup, revalidate the fixed signed set, register exactly 895 as holds, produce
the sanitized 933-row manifest, start the internal release coordinator with
`--range-end 2026-07-21T05:20:00.000Z --expected-total 973
--expected-backfill 933 --min-interval-ms 12500`, and monitor until 933/933
definite acknowledgements. Only after that proceed to the focused outbound
check and the separate exact live-acceptance approval phrase.

**Current verdict remains NO-GO** solely because the authorized 933 posts have
not yet executed and the final live/outbound acceptance remains pending.

---

## Checkpoint — 2026-07-21 05:20 UTC (06:20 BST) — FINAL SYSTEM CLOSURE STOPPED: ALL-TIME INBOUND NO-GO

The final closure stopped at its mandatory Phase 1 mismatch gate. A direct
authenticated, read-only Instantly query from `2000-01-01` through
`2026-07-21T05:20:00Z` fetched all 11 pages: **973 items / 973 unique received
identities**, first `2026-01-15T14:45:41Z`, last
`2026-07-20T22:15:37Z`, identity-set SHA-256 `38d9530d…cf536a`.
Production has 78 inbound / 78 outbox / 40 definite Chat acknowledgements / 38
`HISTORICAL_OWNER_HOLD`; **895 additional Instantly identities have neither an
inbound row nor outbox nor Chat acknowledgement**, spanning 15 January–5 July.
Missing classification counts: ordinary 817, automatic 28, OOO 26,
unsubscribe 24. Missing monthly counts: Jan 32, Feb 141, Mar 552, Apr 1,
Jun 121, Jul 48.

The exact 38 set itself passed its prechecks: all are in Instantly, zero have a
Chat resource/ack timestamp, zero have attempt rows, and there are zero logical
or Instantly-ID duplicates. It was **not released** because the owner's
instruction explicitly required a stop if any non-held record was
unacknowledged and explicitly denied authorization for any other historical
range. No rows were registered, no Chat post was made, no prospect reply was
sent, and no live fixture/outbound acceptance was attempted.

Phase 0 otherwise passed without drift: healthy r7 image
`94dd2d…ea43`; seven workflow versions/semantic hashes exact and active;
subscriptions exact; schema v2/SQLite/FK integrity clean; no SENDING or
RECONCILING console context. Fresh valid backup:
`/root/backups/final-system-closure-20260721T051500Z`, manifest SHA-256
`4c6546a1…b74645f`, readable SQLite/archive/seven workflow exports, secret scan
21 files / zero findings. The earlier `...T051300Z` directory is explicitly
marked incomplete after an export-serialization failure and is not a rollback
artifact.

Global send remained enabled and byte-identical; file SHA-256
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`.
The all-time scan briefly exhausted the shared Instantly read quota: one normal
poll recorded 429, followed by a successful scheduled poll. Genuine watchdog
cycle `2026-07-21T05:20:56.179Z` cleared the alert; queue and active-alert
counts returned to zero.

**Verdict:** **NO-GO** for the all-time contract. Exact owner decision needed:
explicitly authorize the additional 895-identity historical registration and
rate-limited individual Chat backfill (plus the verified 38), or provide
authoritative evidence that the 895 are outside the covered workspace. The
general no-date-exception objective does not override the prompt's narrower
Phase 2 mutation authorization.

Evidence: `reports/FINAL_ALL_TIME_INBOUND_NOTIFICATION_RECONCILIATION.md`,
`reports/FINAL_GOOGLE_CHAT_INSTANTLY_SYSTEM_COMPLETION.md`, and
`reports/final-google-chat-instantly-system-completion-evidence.json`.

---

## Checkpoint — 2026-07-21 04:31 UTC (05:31 BST) — CODEX INBOUND COMPLETENESS / 100K SCALE CLOSURE: CONDITIONAL PASS

Fresh independent code + production audit completed. **Single verdict:
CONDITIONAL PASS.** The internal Instantly-visible contract, transactional
outbox, retry-until-definite-ack behavior, independent auditor, cursor safety,
explicit 100,000-record workload, outage drain and current production mirror
pass. `SCALE CLOSURE PASS` is withheld because no sender/MX/mailbox trace can
identify the allegedly absent fifteenth outbound attempt and no new controlled
live mixed-category fixture burst was owner-authorised.

**Global supervised-send record remained exact and enabled throughout:**
`enabled:true`, note `GLOBAL supervised sending — owner re-enabled 2026-07-20
during edit-flow repair`, original `at:2026-07-20T02:39:57.377Z`, null armed /
fault fields; canonical SHA-256
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`
before/after every deployment, actual rollback, historical registration and
final readback. No prospect reply was sent. Sender, Shadow, Gate 2, autonomous,
campaigns, leads, accounts, drafts, approvals and tokens were not changed.

**Production r7:** sidecar image
`sha256:94dd2dcb55fc4472ed5cc7ef361159a6f0a010119e0926ab8241aebfbd24ea43`
(`hmz-reply-console:codex-inbound-closure-20260721-r7`), source archive
`1d11b54…9470`, healthy, inbound schema v2/integrity true. All seven relevant
n8n workflows are active at recorded versions, including durable notification
`x6vPPurIk8MBBcA8` and auditor `gN9rgLJw9xC4ZnxT`. `reply_received`
subscription `019f75ce-…9baf` is active at the v2 webhook; `email_sent`
`019f7b2f-…a499` remains active/unchanged. Final watchdog: 0 alerts, SQLite
quick check `ok`, 0 FK violations, 0 missing/orphan outbox, queue 0. Final
operations: 78 inbound / 78 outbox / 40 definite Chat ack / 38 explicit
pre-console owner holds / 0 queued-posting-retrying-ambiguous; seven rollout
probable duplicates durably counted.

Repository workflow JSONs remain deploy-safe payloads (live IDs/version
timestamps omitted; new templates `active:false`), not byte-for-byte live
exports. Production is active as above and executable-graph semantics match;
this is expected packaging metadata drift, not unexplained logic drift.

**Repairs:** one canonical received normalizer/classifier for webhook, poll,
backfill and auditor; bounce/system and malformed records can no longer be
excluded; safe surrogate identities; atomic SQLite inbound+outbox uniqueness;
append-only attempts; expiring worker leases; no finite retry cap; bounded
backoff; definite Chat resource-name acknowledgement; streaming 8 MiB Instantly
page cap; timestamp+ID cursor with overlap/full pagination/fail-closed commit;
independent 5m/2h, hourly/24h and daily/7d auditor; direct reconciliation
telemetry; expanded watchdog; synthetic self-test quarantined recoverably;
historical 38 registered without Chat attempts as `HISTORICAL_OWNER_HOLD`.

**Rollout defects disclosed and closed:** r5 safely rejected a real
132,987-byte Instantly page and did not advance its cursor; an actual old-image
rollback restored health/gate and proves rollback. r6 then exposed a legacy
migration bug: seven contexts had valid Chat resource names but no newer
`notificationState`, so seven duplicate Chat notifications were posted. r7
treats those resource names as definite acknowledgements at startup and late
discovery, includes permanent tests, and persists counter
`verified_legacy_ack_duplicate_chat_posts=7`. No email send occurred.

**Proof:** exact r7 image suite 156/156; npm audit 0. Full scale harness 45/45:
100,000 unique + 100,000 duplicate + 100,000 three-path races (300,000
deliveries), 1,000 concurrent, 10k auto/OOO, 10k bounce/system, 15k degraded,
5k attachment/empty, 102 pages/101 transitions. Final 100k inbound/outbox/ack,
zero missing/nonterminal/duplicate logical/prospect POST. Sustained 100k Chat
outage produced 99k retry + 1k ambiguity, zero false ack; full drain after
restore at 1,638.92/s, queue 0. Result hash `ada09575…3238`.

**Live reconciliation at 04:26 UTC:** burst 15/15/15/15; campaign-resumption
7/7; incident inventory 21/21; since repair 15/15; post-console 37/37; last 24h
22/22; last 7d 48/48 represented, 40 ack + 8 historical hold. Every active
missing/outbox-missing/queued/retrying/ambiguous/duplicate-logical count is 0.
The owner-observed 14/14 subset is verified; current burst state is 15 distinct
IDs → 15 inbound → 15 outbox → 15 distinct definite Chat acknowledgements,
2.303–13.924s, no retry/ambiguity/duplicate.

**Schedules observed genuinely (`mode=trigger`):** post-r7 polls include IDs
12588/12589/12590/12592/12595; short audits 12593/12602; deep 12616 (22
observed, 0 missing/backlog); daily 12624 (48 observed, 0 missing/backlog).
Watchdog cycles clean. Manual bootstrap is not used as schedule proof.

**Upstream fifteenth:** `INSUFFICIENT_PROVIDER_EVIDENCE`. Current Instantly
has 15, but no preserved earlier authenticated 14-record snapshot or exact
sender/MX/Microsoft-GoDaddy mailbox correlation identifies the alleged missing
attempt. Do not infer delivery failure, quarantine or delayed ingestion. The
owner-gated read-only comparator design is documented; none was deployed.

**Security/backups:** fresh hash-verified/readable backups at baseline and
before each write; actual rollback plus prepared r7/subscription rollback.
Repository secret scan 1,320 files/110,460,915 bytes clean; workflow scan clean;
VPS exact-path scan 969 files/8,748,530 bytes clean excluding designated
credential snapshots; 14 credential-bearing env files are mode 0600. No secret
value entered repo evidence.

**Exact remaining owner decisions:** (1) authorise a live mixed-category
inbound fixture burst if desired; (2) provide narrow read-only provider trace
access if exact fifteenth-attempt attribution/comparator is desired; (3) decide
whether the 38 pre-console notifications should ever be posted—default remains
do not post. Full report/evidence:
`reports/CODEX_INBOUND_COMPLETENESS_SCALE_CLOSURE.md`,
`reports/codex-inbound-completeness-scale-evidence.json`,
`reports/CODEX_INBOUND_100K_SCALE_RESULTS.md`, and
`reports/FIFTEENTH_EMAIL_UPSTREAM_INVESTIGATION.md`.

---

## Checkpoint — 2026-07-20 18:30 UTC (19:30 BST) — LIVE missed-auto-reply-notification incident: INCIDENT PATCH PASS (revokes the same-day INDEPENDENT PASS below)

**A real production incident occurred after the audit below closed:** the owner resumed a real campaign; Instantly registered two genuine inbound emails; only one produced a Google Chat notification. The **INDEPENDENT PASS** verdict immediately below is **revoked** — see the revocation notice added to `reports/FABLE_GOOGLE_CHAT_REPLY_CONSOLE_INDEPENDENT_AUDIT.md`. Its F1/F2/F3 findings remain individually valid; only the overall completeness verdict is revoked.

**Root cause (proven, not assumed):** the missed email (`019f7fbe-0e6c-7d88-a0b3-8b646c691921`, received 2026-07-20T13:36:30Z) was a genuine automatic/out-of-office reply (Instantly's own `is_auto_reply:1` flag set). `recovery.mjs`'s `isAutoReply()` classifier conflated true bounces (mailer-daemon — correctly excluded) with genuine automatic/OOO prospect replies (which the business requirement explicitly says must still be notified, just labelled) and silently discarded both identically — zero telemetry, zero context, zero notification. This is a distinct code path from the prior audit's F1 finding (missing *fields*, not content-based classification), so F1's fix and tests never covered it. The recovery poll itself had zero gaps all day (384 consecutive 1-minute executions, confirmed from n8n's own execution log) — this was a pure classification defect, not an infrastructure failure. The webhook fast path also did not fire for this specific event (Instantly-side delivery gap, outside this codebase, already mitigated by the poll's existence).

**Global supervised-send state — confirmed unchanged throughout:** `enabled:true`, identical note and `at:2026-07-20T02:39:57.377Z` at every readback (pre-backup, pre-deploy, post-deploy, post-recovery). Never touched.

**Repair (smallest surgical change):** split `isAutoReply()` into `isBounce()` (still excluded) and `isAutoOfficeReply()` (now recovered + Chat-notified with a distinct `🤖 Automatic/Out-of-Office Reply` label) in both `recovery.mjs` and `backfill.mjs`. Added a `retryStuckNotifications()` sweep (runs every recovery-poll cycle, no attempt cap, backs off after 10 fast attempts up to 30 min) closing a second, previously-latent gap: the notification workflow's `Post to Google Chat` node uses `onError:continueErrorOutput` with no automatic retry of its own, so a genuine Chat-POST failure could previously strand a context forever. Also fixed a latent bug in `backfill.mjs --apply` found while testing: it posted the Chat notification but never called `attachChatPost`, so recovered items never actually reached `CHAT_NOTIFIED`. Added `backfill.mjs` to the sidecar `Dockerfile`'s `COPY` list (closes outstanding owner-decision #3 from the prior audit, done opportunistically since a rebuild was already required). No workflow, credential, campaign, lead, or send-configuration change. Sender/Gate 2/Shadow/autonomous untouched.

**Tests:** local suite 129/129 (was 124/124 — +4 recovery, +1 backfill), re-run inside the actual built Docker image (not just pre-build source) before touching production. New 5-category adversarial/scale harness (2,000-email identical-timestamp burst mixed with 200 auto-replies + 50 malformed items; cross-page duplicates; simulated poll-crash-and-resume; 8-way concurrent poll race; prolonged Chat outage + full backlog drain) — 5/5 pass, ~2,950 simulated events (scaled down from the literal 100,000 ask, documented honestly).

**Deployment:** fresh backups taken and secret-scan clean before any change (pre-fix source, full `/data` tarball, 4 workflow exports, compose+env snapshot). Image rebuilt; deployed hashes verified to match the fixed source exactly (`store.mjs`/`recovery.mjs`/`server.mjs`/`backfill.mjs` changed as expected, `verify.mjs`/`enrich.mjs`/`telemetry.mjs` byte-identical). Container recreated; durable volume and go-live gate confirmed unchanged. **8 genuine scheduled recovery-poll cycles** ran cleanly against the new code post-deploy (required minimum: 2).

**Recovery:** bounded dry-run backfill audit (2026-07-18T18:33Z, when the console's context-creation capability first existed, through now — deliberately excluding the prior audit's separate 38 pre-instrumentation historical items) found exactly 22 applicable emails, 21 already notified, **1 missing — the known incident email, nothing else**. `--apply` recovered it; `GET /v1/inbound-by-email/{id}` confirms **`state: CHAT_NOTIFIED`**. A second dry-run over the identical window then returned `missing: 0` (22/22). The one remaining watchdog alert is the same previously-identified self-test debris (`SUPPRESS-SELFTEST-*`/`@example.com`) from the prior audit, deliberately excluded from the new retry sweep by a reserved-domain guard — not a genuine gap.

**Verdict: INCIDENT PATCH PASS.** No unrelated responder regression. No prospect email sent. Files: `reports/LIVE_MISSED_NOTIFICATION_INCIDENT_2026-07-20.md`, `reports/live-missed-notification-incident-evidence.json`, `reports/INBOUND_NOTIFICATION_COMPLETENESS_SCALE_RESULTS.md`, `docs/INBOUND_NOTIFICATION_COMPLETENESS_RUNBOOK.md`; updated `reports/FABLE_GOOGLE_CHAT_REPLY_CONSOLE_INDEPENDENT_AUDIT.md` (revocation notice), `reports/fable-google-chat-reply-console-audit-evidence.json` (revocation pointer), `reports/reliability-report-snapshot-2026-07-20.json` (fresh snapshot + note).

**Residual limitations:** the Instantly-side webhook delivery gap for this specific event was not independently root-caused (outside this codebase); the new retry sweep is proven by reproduction and a clean live no-op, not yet by a genuine live Chat-outage occurrence; live sample sizes (N=17 inbound this window) remain far below the 10,000-event statistical-demonstration threshold.

**Rollback:** restore `/root/backups/incident-2026-07-20-missed-notification/deploy-source-prefix/*.mjs` over the VPS deployment directory, rebuild, recreate the container. Durable `/data` was not modified beyond the one recovered context; both pre- and post-fix full-volume tarballs are preserved in the same backup directory.

**Secret scan:** clean, before and after.

---

## Checkpoint — 2026-07-20 08:08 UTC (09:08 BST) — FABLE 5 independent large-scale hardening audit: INDEPENDENT PASS *(REVOKED — see entry above)*

Fresh independent Fable 5 audit/repair/scale-hardening run against the Google Chat supervised Instantly reply console. Baseline HEAD `ed94d57` (unchanged; no commit made). **Global supervised-send gate confirmed unchanged throughout** — `enabled:true`, identical note and `at:2026-07-20T02:39:57.377Z` at every readback (post-backup, post-fix-deploy, post-DR-drill, final); never disabled, paused, or toggled.

**Baseline/drift:** zero drift — all 5 console workflow structural hashes and all 6 shared sidecar source files matched exactly between repo and production before any change. Fresh sanitised backups taken and hash-verified (workflow exports, full durable-data tarball, compose/env snapshot, pre-fix source copies), all secret-scan clean, all VPS artifacts locked to root-only 600/700.

**One HIGH finding, fixed and deployed (F1):** `recovery.mjs`'s scheduled poll silently and *permanently* dropped any Instantly received-email item missing a required routing field (`eaccount`/prospect email/id) — zero telemetry, zero notification, and the high-water mark advanced past it, excluding it from all future recovery. Reproduced directly, then repaired: telemetry trace (`inbound_readback_invalid_skipped`) + best-effort raw Chat notification + new watchdog alert (`readback_invalid_items`). Two regression tests added; 124/124 local suite passes. Deployed via Docker image rebuild + container recreate (durable volume/gate/binding/key-fingerprint all preserved and verified unchanged); the next genuinely *scheduled* poll ran clean against the new code within 2 minutes.

**One MEDIUM gap closed (F2):** no bounded/dry-run backfill tool existed (Phase 4 requirement). Built `backfill.mjs` (explicit date range, dry-run default, provably no send-path code, dedupes against webhook/poll), 7/7 tests. Ran a real read-only dry-run against production: 38 historical missing ledger entries, **all** dated before the console's context-creation capability existed (2026-07-18T18:33Z) — zero missing since. Did **not** run `--apply` (posting up to 38 backfilled Chat notifications for weeks-old replies is an owner decision, not an audit action).

**One LOW/informational (F3):** the one watchdog-flagged unresolved notification is confirmed prior-session self-test debris (`SUPPRESS-SELFTEST-17`), not a real prospect reply. Not auto-cleaned.

**Test totals:** local repo suite 124/124; independent adversarial harnesses 71/71 (concurrency 21, Chat authz+Edit-flow 30, DR restoration drill 9/9 against the *real* production backup, scale/soak 11/11 categories ~19,550 simulated events — 3 of which initially failed due to bugs in the audit's own mock harness, found and fixed, documented for transparency). 3 live 401 auth probes against the real endpoint. Edit flow independently reproduced with the required exact multiline body; 25/25 dialog-open iterations valid, zero mutation, zero POSTs. Security pass clean (no command exec/eval-on-input/SSRF/path-traversal; secret scan clean).

**SLO honesty preserved:** both reliability targets (99.99% inbound-notified, ≥99.99% outbound-clear) remain targets, not statistically demonstrated — live samples are inbound N=10, outbound N=3.

**Verdict: INDEPENDENT PASS.** No unresolved HIGH/MEDIUM finding. No unrelated responder regression (Intake/Decision/HumanApproval/Sender/SLAWatchdog/ErrorHandler unchanged/active; Shadow inactive; Gate 2/autonomous untouched). Files: `reports/FABLE_GOOGLE_CHAT_REPLY_CONSOLE_INDEPENDENT_AUDIT.md`, `reports/fable-google-chat-reply-console-audit-evidence.json`, `reports/FABLE_GOOGLE_CHAT_REPLY_CONSOLE_SCALE_RESULTS.md`, `docs/GOOGLE_CHAT_REPLY_CONSOLE_OPERATOR_RUNBOOK.md`, `docs/GOOGLE_CHAT_REPLY_CONSOLE_FAILURE_MODEL.md`.

**Outstanding owner decisions:** (1) run `backfill.mjs --apply` for the 38 historical items or leave them; (2) delete or ignore the one self-test-debris context; (3) add `backfill.mjs` to the sidecar Dockerfile's `COPY` list so it survives the next image rebuild. No emergency action required; no immediate production risk found.

---

## 2026-07-18 — Draft Memory V2 Session F G1-R Intake reconciliation PASS; baseline adoption pending (READ-ONLY PRODUCTION)

Owner approved exactly `APPROVE G1-R: NARROW INTAKE DRIFT RECONCILIATION — READ-ONLY PRODUCTION AND LOCAL ANALYSIS ONLY`. Guard PASS; two independent Intake-only GETs returned HTTP 200 and reproduced `5af1e935…`; the pre-change source reproduced `5962b0a6…` twice under the same `{name,nodes,connections,settings}` hash algorithm. Deterministic diff: only `D. Normalization to NES.parameters.jsCode` changed (`8a1bb1c2…`→`de495486…`); F1 `bd2c25a3…`, nodes/IDs/types, connections, settings, credential references, Decision/HumanApproval routing and safety boundaries are unchanged. Current production exactly equals the preserved mapping payload. Direct 2026-07-16 governance/write/rollback evidence proves the permanent Cell 4 mapping was owner-approved and intentionally retained when temporary F1 isolation was removed; checkpoint/master-plan evidence corroborates normal F1 + permanent Cell 4 as the must-preserve state. Targeted results: expected pre-change 14 PASS + 1 expected mapping gap + 0 FAIL; actual production 15/15 PASS; containment 5/5 PASS. Classification `OWNER_APPROVED_FUNCTIONAL_DRIFT`; recommendation `ADOPT_CURRENT_PRODUCTION_AS_NEW_BASELINE`; no candidate needed. Official state stays `BLOCKED`, substate `INTAKE_BASELINE_ADOPTION_READY`, G2 prohibited. Exact next gate: `APPROVE INTAKE BASELINE ADOPTION: 5af1e93540b70c9170900bccc2f00db972dee965aa8ed1b9712728176f3efe5f — LOCAL BASELINE FILES ONLY; NO PRODUCTION WRITES`. Production/workflow/activation/data/outbound/Git-history/Obsidian/credential exposure: none.

SESSION F INTAKE RECONCILIATION PASS — WAITING FOR OWNER BASELINE-ADOPTION DECISION

---

## 2026-07-18 — Draft Memory V2 Session F G1 production readback NO-GO; Intake semantic drift (READ-ONLY ONLY)

Owner approved exactly `APPROVE G1: AUTHENTICATED PRODUCTION READ-ONLY ACCESS`. The production-target guard passed for `https://n8n.hmzaiautomation.com/api/v1`; all five authorised workflow GETs and running/waiting execution GETs returned sanitized HTTP 200 through the secure runtime credential reference. Decision semantic/Node D, HumanApproval semantic, Sender semantic/Q, Shadow inactive, Gate 2/autonomy disabled, and zero running/waiting executions matched. Intake `VtDQqw02Ux1TgjIH` did not: expected semantic `5962b0a6…`, actual `5af1e935…`; classified `BLOCKING_DRIFT`. Persisted state is `BLOCKED`; G2 is not permitted. Recorded rollback sources remain locally available by path; no fresh backup or production write occurred. Smallest owner action: clarify whether the current Intake hash is an approved change and separately authorise narrow reconciliation if desired—do not approve G2 yet. Production writes/activation changes/data writes/outbound/Git-history/Obsidian/credential exposure: none.

SESSION F PRODUCTION NO-GO — LEFT IN VERIFIED SAFE MODE

---

## 2026-07-18 — Draft Memory V2 Session F local production preflight PASS; waiting for G1 (NO PRODUCTION ACCESS)

PF-1 passed on branch `codex/5q-context-token-forensic-20260705` at HEAD `ed94d57c647cd33f346277c6b331b8002d0f90fe`, with staging empty and the production-target guard confirming only `https://n8n.hmzaiautomation.com/api/v1` without a network call. The production manifest is valid (SHA-256 `4d94403b…`), contains G1–G9, rollback, exact reviewed hashes, per-class/no-aggregate thresholds, mandatory HumanApproval, OFF-first mode and no autonomous send. Recomputed evidence: 27/27 reviewed V2 artifacts, 2/2 sidecar files, 8/8 Session A inventory sources, Decision source/Node D, Sender semantic/Q and HumanApproval semantic all exact; Session E report/manifest/persistent 31-probe artifact exist. The 421-line pre-status (`bd9dc981…`) reconciles to Session D's 418-line baseline plus Session E's three created artifacts; no protected mismatch exists. Persistent state: `reports/DRAFT_MEMORY_V2_PRODUCTION_CLOSURE_AND_LIVE_ACCEPTANCE.md` and `reports/draft-memory-v2-production-evidence.json`.

Next: owner gate G1 only. Required exact response: `APPROVE G1: AUTHENTICATED PRODUCTION READ-ONLY ACCESS`. After approval, rerun the guard and execute PF-2 authenticated read-only reconciliation only. No production/n8n/Instantly/network/credential/read/write/deploy/Shadow/send/Git-history/GitHub/Obsidian/CRR action occurred.

SESSION F LOCAL PREFLIGHT PASS — WAITING FOR PRODUCTION READ APPROVAL

---

## 2026-07-18 — Draft Memory V2 Session E targeted independent re-review: PASS, acceptance manifest created (NO PRODUCTION ACCESS)

Fresh Fable review-only session. Baseline exact (branch/HEAD, staging empty, 90-line dirty tree preserved). All nine Session C findings independently verified as genuinely repaired through reachable governed paths: F1 typed contradiction control (mandated pair + two independent formulations REJECT_CONFLICT; ambiguous→clarification; explicit owner replacement→ledgered SUPERSEDE; superseded cannot reactivate; replay deterministic), F2 reviewer scope narrowing preserved end-to-end with fail-closed malformed/unknown/contradictory scope and absolute workspace isolation, F6 typed sync/async adapter-fault containment with SHADOW byte-for-byte legacy preservation under throw/rejection/hostile-Proxy/kernel-breaking input, plus all six mediums (identity collision quarantine, strict conjoinable MERGE, shared expiry gate exact at boundary, governed persisted-proof-only reviewer override, timing de-widening, fully ledgered rebuildable lifecycle). Historical Session C probe run unmodified: F1/F2 labels confirmed STALE_ASSERTION (literal descriptive-string comparison against safe concrete values `REJECT_CONFLICT`/`micro_intent`); all other lines print repaired.

Independent evidence: 31/31 new adversarial probes (`tests/draft-memory-v2/review/session-e/session-e-adversarial.probe.mjs`) with three documented safe-direction LOW observations (paraphrase contradictions merge visibly instead of lexical detection; positive-phrased reversals follow the ledgered refinement path; unlisted compound targets are inert). Reproduction: V2 253/253 (24 files incl. repair 10/10), coverage 9×21+15 PASS, RFC 298/298, legacy 772/772, integration 94/94, secret scan clean, schema 34 $defs additive, all protected hashes exact (8 inventory sources, Node D `a4696732…`, Sender `9910bfb6…`/Q `695bd3db…`, HumanApproval `cc6821a9…`, sidecar `957654e9…`/`87d8b3ae…`). Report: `reports/DRAFT_MEMORY_V2_FABLE_TARGETED_RE_REVIEW.md`. PASS-only artifact created: `reports/DRAFT_MEMORY_V2_SHADOW_LIVE_ACCEPTANCE_MANIFEST.json` (9 owner gates, drift-reconciling preflight, OFF-first deployment sequence, per-class Shadow thresholds with zero-tolerance list, per-class controlled-live and continuous-learning acceptance, rollback table, closure actions; no credentials).

Next: ChatGPT controller audits the manifest and this report, then writes the controlled production-closure Codex prompt. No production/n8n/Instantly/VPS/Gmail/GitHub/Obsidian/network/deploy/approval/send action; no Git-history action; staging empty; no implementation, Session D test, Session C probe, ADR, or schema file modified.

SESSION E TARGETED INDEPENDENT PASS — READY FOR CHATGPT AUDIT AND CONTROLLED PRODUCTION CLOSURE PROMPT

---

## 2026-07-18 — Draft Memory V2 Session D consolidated repair and local revalidation PASS (LOCAL ONLY)

Codex repaired all nine Session C findings without architecture redesign: reachable typed contradiction/polarity and explicit-replacement handling (F1); governed scope/target preservation through trace and retrieval (F2); typed sync/async adapter-fault containment with SHADOW byte equality (F6); canonical event collision quarantine; strict conjoinable MERGE; shared classification/draft lifecycle gate; governed reviewer-override attribution; removal of the two timing widenings; and automatically ledgered, hash-linked lifecycle snapshots with deterministic rebuild. The strict schema received the smallest additive extension (29→34 definitions); both independently accepted accommodations remain intact.

Local revalidation: repair 10/10; V2 24/24 files / 253 logical cases; mandatory 189/189; cross-class 15/15; RFC 298/298; legacy 772/772; Decision integration 94/94; coverage/syntax/JSON/secret scans PASS. All 8 Session A source hashes, Node D `a4696732…`, Sender `9910bfb6…`, Q `695bd3db…`, HumanApproval `cc6821a9…`, and sidecar `957654e9…`/`87d8b3ae…` match. Staging empty; broad dirty tree preserved. Historical Session C probe unchanged: six lines say repaired; F1/F2 retain misleading literal-comparison labels despite safe actual values (`REJECT_CONFLICT`, `micro_intent`), covered by new assertions. Full evidence: `reports/DRAFT_MEMORY_V2_CODEX_REPAIR_AND_REVALIDATION.md`.

Next: fresh Fable/Claude Code targeted re-review only, no silent fixes, focused on the nine Session C findings and adjacent regression surface. No production/network/n8n/Instantly/VPS/Gmail/GitHub/credential/deploy/send action; no Git-history action; no Obsidian action.

SESSION D REPAIR PASS — READY FOR FRESH FABLE TARGETED RE-REVIEW

---

## 2026-07-18 — Draft Memory V2 Session C independent review: NO-GO, Codex repair required (NO PRODUCTION ACCESS)

Fresh Fable review-only session. Baseline verified (branch/HEAD exact, staging empty, all 8 Session A source hashes and local Node D `a4696732…` recompute exactly). Session B counts reproduce: V2 243/243, coverage 9×21+15 PASS, legacy 772/772, integration 94/94, secret scan clean. Both schema accommodations reviewed and ACCEPTABLE_WITH_DOCUMENTED_CONSTRAINT. Injection/poisoning/isolation/attribution guards all held under 20 independent probe groups: no false `actually_applied`, no guidance bypass, no cross-workspace application, OFF inert, SUPERVISED keeps approval and no Sender path.

Three HIGH defects force NO-GO: **F1** contradiction through the real extraction path silently SUPERSEDEs the active memory (extraction never emits `negative_constraints`; the passing Session B contradiction test hand-crafts a shape the pipeline cannot produce — ADR D6 stability-wins unreachable); **F2** reviewer-declared scope narrowing (`draft_improvement_scope`/target classifications) is discarded, so edits become workspace-wide `classification_scope:'all'` memories; **F6** a throwing or missing adapter crashes `applyMemories` (schema TypeError on null `stage_results.evidence`) and in SHADOW the crash destroys the legacy draft path — the P3-T1 throw acceptance criterion was never actually tested with a throw. Mediums: event_id uniqueness unenforced (F3), MERGE lacks conjoinability (F4), expired classification memories still apply (F5), reviewer_override attribution unreachable (F7), timing gate widened vs legacy (F8), lifecycle transitions not ledgered so rebuild can't reproduce them (F12); lows F9–F11. All reproduced, none repaired.

Evidence: `reports/DRAFT_MEMORY_V2_FABLE_INDEPENDENT_REVIEW.md`; persistent reproduction `tests/draft-memory-v2/review/session-c-findings.probe.mjs` (standalone, prints DEFECT PRESENT per finding; suite stays 243/243 green). Shadow/live acceptance manifest intentionally NOT created (PASS-only artifact). Next: fresh Codex local repair (F1/F2/F6 mandatory, F3–F8/F12 unless owner defers), convert probes to asserting tests, full local re-acceptance; then fresh Fable Session C re-review which on PASS writes `reports/DRAFT_MEMORY_V2_SHADOW_LIVE_ACCEPTANCE_MANIFEST.json`. No production/n8n/Instantly/VPS/Gmail/GitHub/Obsidian/network/deploy/approval/send action; no Git-history action; staging empty; protected baselines untouched.

SESSION C INDEPENDENT NO-GO — CODEX REPAIR REQUIRED

---

## 2026-07-18 — Draft Memory V2 Session B local implementation and deterministic acceptance PASS (LOCAL ONLY)

Codex completed all 14 approved implementation-manifest tasks across four local phases. Added the dependency-free typed schema validator, immutable/idempotent event ledger, extraction, six-operation consolidation/lifecycle/rebuild, trace metrics, universal evidence-only policy kernel, independent raw/persisted compliance and attribution, nine adapters, deterministic migration/quarantine, OFF/SHADOW/SUPERVISED_APPLY guards, and a local-only integration shim. Default remains `OFF`; no workflow export or protected runtime was modified. Legacy reason-for-contact rule `182ad47b…` is quarantined at memory level while the class keeps a proven positive path.

Local acceptance: Draft Memory V2 full collection 22/22 test files PASS; coverage validator PASS (9 classes × 21 concrete mandatory cases = 189/189, 15/15 manifest cross-class contracts); RFC adapter unchanged corpus 106/106 positive + 181/181 negative and 11/11 RFC v4 hard-FP probes PASS; continuous classification/draft/style/safety/no-change/rejection/repeat-correction loops PASS; isolation/lifecycle/conflict/injection/poisoning/unsupported-fact cases PASS. Existing protected suites remain 772/772 module and 94/94 Decision integration PASS. Node D hash remains `a4696732…`; Sender semantic/Q and HumanApproval semantic recompute exactly to their protected values. Syntax/JSON/targeted and workflow secret scans PASS; staging empty at validation.

Full evidence and exact files: `reports/DRAFT_MEMORY_V2_CODEX_IMPLEMENTATION_AND_LOCAL_ACCEPTANCE.md`. Independent review should challenge the two documented schema accommodations (inert unclassified quarantine envelope; strict canonical classification-target encoding) and the ADR-required truthful `UNVERIFIABLE` result for non-checkable classes. No silent fixes: next agent is fresh Fable/Claude Code review-only. No production/n8n/Instantly/VPS/Gmail/GitHub/Obsidian/network/deploy/approval/send action; no Git-history action.

SESSION B LOCAL PASS — READY FOR FRESH FABLE INDEPENDENT REVIEW

---

## 2026-07-18 — Draft Memory V2 Session A complete: inventory, baseline, ADR, schemas, coverage contract, Codex manifest (LOCAL ONLY)

Fable 5 architecture/inventory session. First applied the owner-authorised correction: restored the missing
strategic checkpoint entry into this file from the checksum-verified bundle patch (`a91ea49b…`,
`git apply --include=OPERATION_HANDOFF.md`); history preserved, RFC v4 remains blocked.

Delivered (all additive; no runtime, workflow, test or fixture modified): deterministic inventory generator
`scripts/DRAFT-MEMORY-V2-inventory.mjs` + authoritative baseline `reports/draft-memory-v2-inventory-baseline.json`
(16 categories, 22 micro-intents, 9 explicit classes + `unclassified` quarantine sink, 5 stores, 37 central paths,
5 bypass paths — key finding: the production Decision export does NOT contain the v3 compliance chain; per-class
28-dimension baseline totals PASS 9 / PARTIAL 111 / NOT_IMPLEMENTED 61 / UNPROVEN 52 / UNKNOWN 8 / N-A 6 / FAIL 5,
all FAILs on reason_for_contact per the recorded RFC v4 NO-GO); implementation-ready ADR
`docs/DRAFT_MEMORY_V2_ADR.md` (D1–D23: immutable event ledger, two channels, typed memories, six-op consolidation,
lifecycle, one non-bypassable kernel, evidence-only adapters, workspace-first scoping, truthful UNVERIFIABLE
compliance, migration+quarantine incl. rule 182ad47b… at memory level, OFF/SHADOW/SUPERVISED_APPLY, no new deps);
strict schema bundle `schemas/draft-memory-v2.schema.json` (29 $defs); balanced coverage contract
`tests/draft-memory-v2/coverage-manifest.json` (21 mandatory cases × 9 classes, 15 cross-class contracts, 15% rule)
with validator `scripts/DRAFT-MEMORY-V2-validate-coverage.mjs` (PASS); Codex task graph
`reports/DRAFT_MEMORY_V2_IMPLEMENTATION_MANIFEST.json` (4 phases, 14 tasks). Full report:
`reports/DRAFT_MEMORY_V2_SESSION_A_REPORT.md`. The prose Codex prompt was intentionally not written (ChatGPT will).

Validation: node --check PASS; all JSON parses; coverage validator PASS; existing suites unchanged and passing once
(module 772/772, integration 94/94); targeted secret scan clean. No production/n8n/Instantly/VPS/Gmail/GitHub/
Obsidian access; no stage/commit/push; staging empty; broad dirty tree preserved; protected baselines untouched
(Decision 9ab7cefe…/a4696732…, Sender/Q/HumanApproval/sidecar, Shadow inactive, Gate 2/autonomy disabled).

Regression Safety Check: **PASS** — additive-only; legacy suites at recorded totals with zero legacy-file changes.

Next: ChatGPT controller audits Session A artifacts and writes the Codex Session B implementation prompt from
`reports/DRAFT_MEMORY_V2_IMPLEMENTATION_MANIFEST.json`.

SESSION A COMPLETE — READY FOR CHATGPT AUDIT AND CODEX IMPLEMENTATION PROMPT

---

## 2026-07-17 — ChatGPT controller checkpoint: Cross-Class Draft Memory V2 programme adopted (NO PRODUCTION OR GIT WRITE)

The owner rejected the previously proposed human-only disablement of `reason_for_contact` and required automatic draft self-learning to work consistently across every supported message class. This strategic instruction supersedes the RFC v4 review's **recommended next action only**; the RFC v4 NO-GO findings remain preserved as valid failure evidence and the candidate remains forbidden for production.

The recent reason-for-contact-only repair loop is closed. No RFC v4.1/v5 lexical patch is authorised. The new programme is **Cross-Class Draft Memory V2**: authoritative inventory of every category/micro-intent/behaviour/rule path; governed review-event ledger; separate classification and drafting learning channels; typed extraction and consolidation/lifecycle; one central applicability/conflict/compliance pipeline; balanced per-class and cross-class acceptance; shadow acceptance; controlled live learning acceptance; full regression; CRR; freeze; pilot.

No entire message class may be disabled. Ambiguous individual messages may fail closed to human review, but every supported class must retain a proven automatic positive path. Known current draft classes are `reason_for_contact`, `timing`, `pricing`, `trust`, `objection`, `meeting`, `tone`, `brevity`, and `cta`; the authoritative inventory must discover any others.

Master plan: `docs/INSTANTLY_RESPONDER_MASTER_COMPLETION_PLAN_DRAFT_MEMORY_V2.md`. Checkpoint audit: `reports/CHECKPOINT_2026-07-17_CROSS_CLASS_DRAFT_MEMORY_V2.md`. Fresh-chat controller prompt: `reports/CONTINUE_NEW_CHAT_INSTANTLY_RESPONDER_DRAFT_MEMORY_V2.md`.

Formal progress remains **7/14 (50%)**. Honest planning estimates: draft self-learning **35–40%**; overall engineering maturity **82–86%**; scale/sell readiness **55–60%**. These estimates do not override hard gates.

Latest recorded production safety state remains unchanged: Decision protected baseline semantic `9ab7cefef85035bd59b12428fea6527ee8f24a24e8eade12ad3d2f2594b87172`, Node D `a46967329bc24fd58e2226bbbd24b1f3f2de700961036424a4f97702144206e3`; Intake normal F1 with permanent Cell 4 mapping; Sender/Q/HumanApproval/sidecar protected; Shadow inactive; Gate 2/autonomy disabled. The RFC v4 candidate and all earlier reason-for-contact candidates must not be deployed.

Checkpoint evidence from the uploaded snapshot: branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57c647cd33f346277c6b331b8002d0f90fe`, staging empty, broad dirty tree preserved. A complete local snapshot checkpoint was created; broad GitHub commit/push is not authorised without a dedicated surgical audit. No production/n8n/Instantly/VPS/Gmail call, workflow execution, approval, send, credential operation, Git history mutation, push, or Obsidian edit occurred during this controller checkpoint.

**Next tool/session:** fresh ChatGPT controller → fresh Claude Code/Fable 5 high-effort local-only architecture/inventory session. It must produce the authoritative inventory, per-class baseline, ADR/schemas, balanced harness design and a fresh Codex implementation prompt. Do not reuse previous high-context Fable/Codex sessions.

Regression Safety Check: **PASS for strategic checkpoint containment** — prior audit history preserved; blocked candidate remains blocked; protected production state unchanged; broad dirty worktree and staging state preserved; no stale template used to overwrite current work; no production, send, GitHub or Obsidian action.

CROSS-CLASS DRAFT MEMORY V2 PLANNING CHECKPOINT — READY FOR FRESH CHATGPT CONTROLLER

---

## 2026-07-17 — Independent Fable RFC v4 review: NO-GO, human-only fallback required (NO PRODUCTION ACCESS)

Independent review-only session (Claude Fable 5) of the Codex RFC v4 whole-target parser. Verdict:
**INDEPENDENT FABLE RFC V4 NO-GO — HUMAN-ONLY FALLBACK REQUIRED**. The RFC v4 candidate must not be
deployed, and per the final-cycle rule no further automatic-detector repair (no RFC v4.1) is proposed.

Independently VERIFIED first: branch/HEAD `ed94d57`; staging empty; all four hashes recomputed and equal
(candidate file `f76f089d…`, semantic `3b38051b…`, Node D `8db62399…`, protected baseline Node D
`a4696732…`); 33 nodes both workflows; corpus 287 (106+181) and matrices 128/130; patcher 16-anchor +
baseline-pin + fail-closed structure (static). `_5qRfcClassifyTarget` itself is a true complete-span
contract: 145 prefix/possessive/multiword/trailer-concealment probes all fail closed, all v3.1–v3.3
defect families remain repaired, all 30 canonical first-party positives accept, safe-trailer set closed.

New blocking finding (224 temporary non-repo probes, 125 with novel tails; 11 hard false positives,
0 hard false negatives): two event paths bypass the whole-target contract. (1) The sender-owned-noun
path's receiver look-behind recognises only past-tense `received|got|saw`, so bare-infinitive receipt
verbs hide a third-party receiver and the target defaults to first-party `me` — "Why did my accountant
get your email?", "Why did my assistant receive your call?", "Why did my colleague see your message?"
all accept. (2) The `how/where did you get/find my|our` shorthand accepts a first-party PREFIX without
classifying the complete span — "How did you find my colleague's email?", "How did you get my
assistant's number?" accept: the literal v3.3 prefix defect surviving in the deictic branch. Six
representatives proven through the real `_5qSelectDraftRuleWinners` with production-shape rule
`182ad47b…` and resolved context: winner selected, `evidence_present=true`. Corpus and matrices are
structurally blind to both families (only past-tense receiver rows; no third-party-possessive
provenance rows). NOT RUN (fail-fast): module 772, integration 94, behavioural 483×2, byte-identity,
patcher refusal execution, secret scans.

Required next step (owner authorization required, NOT implemented here): human-only fallback —
automatic reason-for-contact rule application disabled; reason-for-contact cases remain
supervised/human-drafted; all other responder functionality unchanged. Evidence:
`reports/FINAL_INDEPENDENT_REASON_FOR_CONTACT_RFC_V4_FABLE_REVIEW.md`. No production-closure prompt
was created. No n8n/Instantly/VPS/Gmail/GitHub/Obsidian access, no deploy, no execution, no email, no
stage/commit/tag/branch/push; only this review report and this handoff entry were written. Production
remains safely rolled back (Decision baseline `9ab7cefe…`/Node D `a4696732…`, Shadow inactive,
Gate 2/autonomy disabled).

Regression Safety Check: **PASS for fail-stop containment** — review-only; blocking candidate not
deployed; protected workflows and staging untouched; zero outbound; temp harnesses outside the repo.

INDEPENDENT FABLE RFC V4 NO-GO — HUMAN-ONLY FALLBACK REQUIRED

---

## 2026-07-17 — Reason-for-contact RFC v4 whole-target repair complete (LOCAL ONLY)

Completed the final permitted automated-detector repair cycle after the independent v3.3 NO-GO. Root cause:
`_5qRfcClassifyTarget` accepted a first-party prefix without validating the rest of the action target noun
phrase. The frozen v3.3 module reproduced 28/28 false positives directly and through real
`_5qSelectDraftRuleWinners`; each selected `182ad47b…` with evidence=true.

RFC v4 implements one complete target-span contract with `first_party_complete`, `third_party`, `sender`,
`unknown` and `conflicting` outcomes. Empty spans, a small closed safe-trailer set and all-first-party
conjunctions are accepted; possessive, nominal, mixed, attached and ambiguous continuations fail closed.
Active, passive, sender-owned-noun, reason, prompted-message, selection/fit/about, objectless and supported
cross-sentence paths use or are subordinated to this contract. A focused legacy fit/about overreach found
during stabilization was repaired compositionally and five cases were permanently added.

Final local proof: original corpus 234/234 retained; expanded corpus 287/287; original semantic matrix
128/128; new whole-target matrix 130/130; temporary adversarial 150/150 with 70 novel non-repo tails and
zero hard false positives/negatives; module 772/772 (previous 528 retained); Decision integration 94/94
(previous 82 retained); behavioural baseline/candidate 483/483 each. Six classification functions are
byte-identical. All patcher guards, async JS/JSON, block equality, Node-D-only containment, 33-node and
settings/connections/credential-ref invariants, and scoped/repository secret scans pass.

Final candidate generated only from protected baseline Node D `a4696732…`: file
`f76f089d35b77e3ece48d4a66a1a43bce5a6a0ea7114c8e910466f6c6c9677c4`, semantic
`3b38051b258b9d1ac0d724916ec6f1622297ac61926d393d1b400606491a9f11`, Node D
`8db6239931ce043bfdbb43cf6f59ed520bea53b82b32b015f4b87a79166bc570`; none equals invalid v3.3.
Production block delta +32/-15 lines; pre-report test/evidence additions 204 lines.

No n8n/Instantly/VPS/Gmail/GitHub/Obsidian/network access, deployment, execution, send, approval or Git-history
action occurred. Production remains safely rolled back. Evidence:
`reports/REASON_FOR_CONTACT_RFC_V4_WHOLE_TARGET_PARSER_REPAIR_AND_PROOF.md`. Next fresh independent review:
`reports/NEXT_FABLE_PROMPT_REASON_FOR_CONTACT_RFC_V4_INDEPENDENT_REVIEW.md`.

Regression Safety Check: **PASS** — local Node-D-only candidate; protected workflows/staging/dirty paths
preserved; zero production action and zero outbound.

GO FOR FRESH FABLE RFC V4 INDEPENDENT REVIEW — LOCAL ONLY

---

## 2026-07-17 — Independent Fable v3.3 review: NO-GO, local repair required (NO PRODUCTION ACCESS)

Independent review-only session (Claude Fable 5) of the v3.3 reason-for-contact explicit-target repair.
Verdict: **INDEPENDENT FABLE V3.3 NO-GO — LOCAL REPAIR REQUIRED**. The v3.3 candidate must not be deployed.

Evidence discrepancy (§3 of the review mandate) **RESOLVED**: the v3.2 Fable review and the v3.3 Codex
pre-fix reproduction tested different sentences for the intern/secretary family (loose-branch forms vs
direct-object forms); neither report is inaccurate — the 6/6 premise came from the repair prompt's
paraphrase. All 14 wordings from both sessions were re-executed against v3.3: all negative. Both v3.2
defect families are genuinely repaired.

New blocking finding (96 temporary non-repo probes, 12 hard false positives, 0 hard false negatives):
`_5qRfcClassifyTarget` anchors only a PREFIX of the target noun phrase, so any third-party phrase beginning
with a first-party organisational noun is blessed as first-party across all event paths — `Why did you
email our office manager?`, `What made you contact our team lead?`, `Why did you call my business
partner?`, `Why did you email my company's competitor?`, `What prompted your email to our company
accountant?`, passive `Why was our team lead contacted?` all return true. Four representatives proven
through the real `_5qSelectDraftRuleWinners` with production-shape rule `182ad47b…`: winner selected,
`evidence_present=true` — the v3.1/v3.2 defect class one composition layer deeper. Corpus (234/234-green)
and semantic matrix are structurally blind to the family: every third-party row starts outside the FP_ORG
noun list ("our finance director" rejected only because "finance" is not in the list; "our team lead"
accepted because "team" is).

Independently VERIFIED before fail-fast: candidate file `b47c8052…`, semantic `dc82b412…`, Node D
`98260f49…`, baseline Node D `a4696732…`, injected block byte-equal module↔candidate (42,560 bytes),
Node-D-only diff, 33 nodes, connections/settings/credential refs equal, corpus counts 94+140, all 20
novel non-prefixed third parties + all 15 reverse-direction + mixed/generic/stop probes correct, all 12
canonical first-party positives correct. NOT RUN (fail-fast): module 528, integration 82, behavioural
483×2, classification byte-identity, patcher refusal modes, secret scans. Required v3.4 repair:
whole-phrase target classification (empty/safe-trailer/first-party-conjunction remainder only; bare-noun
and possessive continuations fail closed) + permanent corpus/matrix rows for the family — see
`reports/FINAL_INDEPENDENT_REASON_FOR_CONTACT_V33_FABLE_REVIEW.md`. No production-closure prompt created.

No n8n/Instantly/VPS/Gmail/GitHub/Obsidian access, no deploy, no execution, no email, no stage/commit/tag/
branch/push. No implementation, test, corpus, patcher, candidate or prompt file changed. Production remains
safely rolled back (Decision baseline `9ab7cefe…`/Node D `a4696732…`, normal Intake F1 with permanent
Cell 4 mapping, Shadow inactive, Gate 2/autonomy disabled).

Regression Safety Check: **PASS for fail-stop containment** — review-only; blocking candidate not deployed;
protected workflows and staging untouched; zero outbound; temp harness outside the repository.

INDEPENDENT FABLE V3.3 NO-GO — LOCAL REPAIR REQUIRED

---

## 2026-07-17 — Reason-for-contact v3.3 explicit-target repair complete (LOCAL ONLY)

Recovered the interrupted Fable run as `PARTIAL_IMPLEMENTATION`: the injected detector remained byte-equal to
invalid v3.2 and only a 23-line v3.3 design comment had been added. Codex completed the bounded local repair with
a structured deterministic event evaluator that validates sender actor, actual first-party action target,
voice, causal link, reverse direction and conflicts; unknown noun phrases no longer depend on a role blacklist.

Pre-fix execution of the six owner-listed probes produced 4 actual v3.2 false positives/selections; the intern
and secretary direct-object cases already failed closed. Final proof: targeted 14/14; semantic matrix 128/128;
expanded corpus 94/94 + 140/140 with all prior 90/115 retained; temporary adversarial 60/60; module 528/528;
Decision integration 82/82 with all prior 74 retained; behavioural baseline and candidate 483/483 each. Six
classification functions are byte-identical. Patcher pin/anchors and all four refusal guards pass with no partial
output. Candidate syntax/JSON, Node-D-only containment, 33 nodes, equal settings/connections/credential refs and
scoped/repository secret scans pass.

Candidate (local only): file `b47c8052d2ceb7fb7fc132c5b56444a8c0c0c394159c5947c6aee20aba2ed8e9`,
semantic `dc82b4123018e1b78390dee7e89b18742ece28d8100ccf66e5e1cd4524e82220`, Node D
`98260f496251e05eb612a0dd69cfc756cd14fe299bb2b2627c64123bee8adc78`, generated only from protected baseline
Node D `a46967329bc24fd58e2226bbbd24b1f3f2de700961036424a4f97702144206e3`.

No production/network/workflow/send/approval/deploy or Git-history action occurred. Production remains safely
rolled back. Evidence: `reports/REASON_FOR_CONTACT_V33_EXPLICIT_TARGET_CONTRACT_REPAIR_AND_PROOF.md`. Next fresh
review: `reports/NEXT_FABLE_PROMPT_REASON_FOR_CONTACT_V33_INDEPENDENT_REVIEW.md`.

Regression Safety Check: **PASS** — local Node-D-scoped work; zero outbound; dirty/untracked paths preserved.

GO FOR FRESH FABLE V3.3 INDEPENDENT REVIEW — LOCAL ONLY

---

## 2026-07-17 — Independent Fable v3.2 review: NO-GO, local repair required (NO PRODUCTION ACCESS)

Independent review-only session (Claude Fable 5) of the v3.2 reason-for-contact target/direction repair.
Verdict: **INDEPENDENT FABLE NO-GO — LOCAL REPAIR REQUIRED**. The v3.2 candidate must not be deployed.

Adversarial execution of the shipped detector (66 probes, temporary non-repo harness) proved **8 hard false
positives in two structural families**: (1) third-party outreach targets outside the finite role lexicon are
accepted because `aboutFirstParty`, `nounReason` and `promptedMessage` never validate the outreach action's
object — `What about my company made you email its former owner?` (a mandated probe), `…my intern`,
`…my secretary`, `…my receptionist` all return true; (2) reverse-direction "worth + gerund" forms bypass the
direction gate — `What makes you worth contacting?` (a mandated probe) and `Why are you worth emailing?`
return true. All three tested false positives propagate through `_5qSelectDraftRuleWinners`: rule
`182ad47b…` is selected with `evidence_present=true`, so guidance would be injected on third-party/reverse
messages — the v3.1 defect class one lexicon layer deeper.

Independently VERIFIED: corpus 90/90 + 115/115 (green — structurally blind to both families); baseline Node D
`a4696732…`; candidate Node D `7412d66e…`, semantic `3330e8b9…`, file `6d8ebca5…`; fresh patcher regeneration
reproduces the exact candidate hash; six classification functions byte-identical; Node-D-only diff, 33 nodes,
settings/connections equal; all four patcher refusal modes fail closed with no output; candidate syntax
(async context) + scoped secret scan clean; live wording still detects and selects `182ad47b…`; three v3.1
failures remain false; unresolved context excludes fail-closed. NOT RUN (fail-fast after critical finding):
module 367, integration 74, behavioural 483×2, repo secret scan. Closure prompt audited: procedurally sound,
not edited, but must not be executed until a v3.3 repair passes a fresh independent review (its `7412d66e…`
hash expectation is now invalid). Required v3.3 repair: first-party-object validation in the three loose
branches, worth/deserve-gerund exclusion, `us` in reverseActor, permanent corpus rows for both families —
see `reports/FINAL_INDEPENDENT_REASON_FOR_CONTACT_V32_FABLE_REVIEW.md`.

No n8n/Instantly/VPS/Gmail/GitHub/Obsidian access, no deploy, no execution, no email, no stage/commit/tag/
branch/push. No implementation, test, corpus, patcher, candidate or prompt file changed. Production remains
safely rolled back with normal Intake F1 and permanent Cell 4 mapping.

Regression Safety Check: **PASS for fail-stop containment** — review-only; blocking candidate not deployed;
protected workflows and staging untouched; zero outbound.

INDEPENDENT FABLE NO-GO — LOCAL REPAIR REQUIRED

---

## 2026-07-17 — Reason-for-contact v3.2 target/direction repair complete (LOCAL ONLY)

Codex completed the owner-authorized bounded local repair for the v3.1 independent NO-GO. Production actions:
**none**. The five pre-fix detector false positives reproduced 5/5; the v3.1 candidate then failed all eight new
Decision assertions (66/74), proving third-party/generic selection and the missed cross-sentence first-party case.

v3.2 replaces unsafe R4/R6/R6b/R8-style broad matching with compositional causal-intent, action,
first-party-target and sender-direction predicates. Central fail-closed gates reject third parties, opt-out/high-risk
language, reverse direction and ambiguous compounds. Passive/cross-sentence forms require a first-party target;
fit/relevance requires explicit semantics; question-free reason statements no longer qualify. Post-green
adversarial review found and repaired six more boundaries, all permanently added to the existing corpus.

Final local proof: corpus **90/90 positive + 115/115 negative**; module **367/367**; Decision integration
**74/74**; behavioural baseline **483/483** and candidate **483/483**; six classification functions byte-identical;
patcher pinned success plus wrong-SHA/missing/duplicate/already-patched refusal with no partial output; syntax,
JSON, Node-D-only containment and secret scans PASS. Candidate regenerated only from baseline Node D
`a46967329bc24fd58e2226bbbd24b1f3f2de700961036424a4f97702144206e3`: local semantic
`3330e8b9549d8502989de8352799a5c9b48ee0a2f3f4f22f05516219bcf0082f`, Node D
`7412d66e1cf35d6c17101944a544da3a063fb1735f32bba642c0959c3d8f04d7`. Only Decision Node D differs;
33 nodes and ID/name/settings/connections/credential references remain equal.

No n8n/Instantly/VPS/Gmail/GitHub/Obsidian access, deployment, workflow execution, email, stage, commit, tag,
branch or push occurred. Production remains safely rolled back with normal Intake F1 and permanent Cell 4 mapping.
Detailed evidence: `reports/REASON_FOR_CONTACT_V32_TARGET_DIRECTION_REPAIR_AND_PROOF.md`. Next fresh review:
`reports/NEXT_CODEX_PROMPT_REASON_FOR_CONTACT_V32_REVIEW_AND_CLOSURE.md`.

Regression Safety Check: **PASS** — local-only scoped delta; protected workflows and production untouched; zero
outbound; staging remains empty.

GO FOR FRESH CODEX V3.2 INDEPENDENT REVIEW — LOCAL ONLY

---

## 2026-07-16 — Codex independent v3.1 review found blocking detector false positives (NO PRODUCTION ACCESS)

The owner-authorized closure chain stopped during the local independent-review phase at the first mandatory
critical/high defect. Direct adversarial execution of the current v3.1 detector proved family-level false
positives that the shipped corpus misses: `What's the reason you're emailing my boss?` and `What was the
rationale behind your call to my colleague?` both return `true`, violating the required third-party/directionality
gate. Generic no-outreach wording (`What about my company do you think?`) also returns `true`, showing that R4's
bare `think` alternative does not enforce the documented outreach/selection/fit conjunction. Related
sender-facing fit/relevance probes also qualify.

The structural bypasses are in R6/R6b (no recipient-object or third-party validation), R4 (bare `think` accepted),
and R8 (sender-facing fit/relevance can qualify). This is not an exact-sentence special case. The current local
candidate must not be deployed. Required next work is a bounded local repair, negative-corpus expansion using
these probes and variants, candidate regeneration from the protected baseline, and a fresh independent review.

No remaining focused suite was run after the fail-fast finding. No production-target guard, credential use,
n8n/Instantly API call, production read/write, backup mutation, Intake F1 isolation, Decision deployment,
validation event, approval, send, regression, CRR edit, Git history operation, GitHub action or Obsidian access
occurred. Branch/HEAD remained `codex/5q-context-token-forensic-20260705` / `ed94d57`; staging was empty; all
395 pre-existing dirty/untracked paths were preserved. Production therefore remains safely rolled back exactly
as the preceding authoritative entry records.

Detailed evidence: `reports/FINAL_INDEPENDENT_REASON_FOR_CONTACT_V31_REVIEW_NO_GO.md`.

Regression Safety Check: **PASS for fail-stop containment** — zero production contact or mutation, zero outbound,
protected workflows untouched, and the blocking candidate was not deployed.

PRODUCTION CLOSURE NO-GO

---

## 2026-07-16 — Reason-for-contact evidence detector repaired locally (v3.1); GO for fresh Codex review (LOCAL ONLY)

Single local session completing the authorized Step 8 repair for the case-80337eae blocking defect.
**Production actions: none.** No n8n/Instantly/SSH/Gmail/GitHub/Obsidian access; no deploy; no send; no
workflow invocation; nothing staged, committed, tagged, or pushed. Production remains safely rolled back
exactly as the previous entry records (Decision `2bb92b36` / `9ab7cefe` / Node D `a4696732`; Intake
`808a79f2` / `5af1e935` with permanent Cell 4 mapping and no temporary F1 isolation; protected workflows
unchanged; Gate 2/autonomy disabled).

**Pre-fix reproduction (recorded before editing):** against the unmodified module and the byte-identical
repository copy of the deployed candidate (Node D `b33732cc…`), the live wording "What specifically about
my company made you think this was relevant enough to contact me?" with the exact resolved Cell 4 context
produced 7/9 failing assertions reproducing execution 8856 exactly: `evidence_present=false`,
`excluded_reason=NO_PROSPECT_CONTEXT_EVIDENCE_FOR_REASON_FOR_CONTACT`, `draft_guidance_injected=false`,
`draft_actually_applied=false`, first failure `NO_ACTIVE_DRAFT_RULES`, while classification correction and
timing exclusion passed — isolating the failure to the evidence gate.

**Root cause:** the `reason_for_contact` prospect-evidence gate in
`infrastructure/draft-learning/decision-draft-compliance.js` was structurally under-generalised (literal
`why`-anchored patterns only; no "what made/prompted/led/caused", no "what about my company", no
selection/fit language, no passive or outreach-first order, no apostrophe/Unicode normalisation) and
simultaneously direction-blind (its broadest pattern matched "Why should I contact you?").

**Repair (v3.1):** new deterministic detector `_5qProspectAsksReasonForContact` (+
`_5qNormalizeProspectText`) requiring causal/query signal × outreach/selection/fit signal × correct
sender→recipient direction, with explicit protections for reverse direction, third-party objects,
negated-"why" suggestion/hostile forms, unsubscribe, pricing, booking, timing-only and sender-facing
relevance wording. The evidence-gate case now delegates to it; nothing else in the v3 chain changed.
Patcher gained one post-condition line requiring the new function. Named reviewable corpus:
`tests/fixtures/draft-learning/reason_for_contact_evidence_corpus.json` — **56 positives / 48 negatives**.
Exact-failure fixture snapshotted: `decision_candidate_prev_v3_reason_evidence_b33732cc.json`
(file sha `8f8bc4ec…`, byte-identical to the reviewed/deployed v3 candidate).

**Proof (all local, deterministic):** module suite **261/261** (142 legacy retained); integration
**66/66** (53 legacy retained; V1–V3 exact-8856 replay on the fixture; W1–W10 repair proofs incl.
eleven-stage clean chain, unresolved-context fail-closed, reverse-direction/unsubscribe negatives, and
six classification functions byte-identical); behavioural harness **483/483 baseline root AND 483/483
temp candidate root**; candidate Node D syntax PASS; JSON PASS; patcher wrong-SHA/already-patched/
missing-anchor/duplicate-anchor all refuse with no output; scoped + repo secret scans CLEAN. Sender/B5/B6
suites not rerun — no Sender/Q/sidecar/HumanApproval/Shadow/Intake/B5/B6 file is in the delta.

**Candidate of record (LOCAL ONLY, never deploy the file):** regenerated from the pinned local baseline
(input Node D `a4696732…`, 16 edits, Node-D-only diff): output Node D
`0f57b4d4fab9c75e4febef0542d5eea98dbb41fed7f6fa4d09987e532128ce22`, semantic
`13ebe1db40970e36d97b0253106cfce71c0b3a1bbed029e6f28d64f81247b5cd`. Production must regenerate from a
fresh authenticated export and expect exactly this Node D output hash.

Files changed: module, patcher (1 line), both draft-learning suites, new corpus + new fixture, regenerated
candidate, `reports/REASON_FOR_CONTACT_EVIDENCE_DETECTOR_REPAIR_AND_PROOF.md`,
`reports/NEXT_CODEX_PROMPT_REASON_FOR_CONTACT_REPAIR_REVIEW_AND_CLOSURE.md`, this entry. Detailed
evidence: `reports/REASON_FOR_CONTACT_EVIDENCE_DETECTOR_REPAIR_AND_PROOF.md`.

**Next agent:** fresh Codex, using
`reports/NEXT_CODEX_PROMPT_REASON_FOR_CONTACT_REPAIR_REVIEW_AND_CLOSURE.md` — independent local review
first; production closure only on its own PASS, with fresh production readback and explicit owner
approval both mandatory. Do not reuse case-80337eae as acceptance evidence; do not approve or send it;
the positive acceptance needs a new owner-sent wording. Remaining risks are fail-closed only (novel
phrasings outside the signal families yield truthful `evidence_present=false` with safe baseline
behaviour; corpus is English-only; local/production baseline semantic drift is non-Node-D metadata).

Regression Safety Check: **PASS** — scoped delta only; protected baseline export untouched;
classification-learning semantics byte-identical; zero production access; zero outbound; no secrets;
Git history and Obsidian untouched.

GO FOR FRESH CODEX INDEPENDENT REVIEW — LOCAL ONLY

---

## 2026-07-16 — Positive Decision v3 acceptance failed; safety rollback complete (PRODUCTION CLOSURE NO-GO)

The owner sent the new controlled reason-for-contact reply from `junaidk7531@gmail.com` on the exact isolated
campaign/sender/thread tuple. Exactly one new integrated chain completed: Intake `8855`, Decision `8856`,
HumanApproval create `8857`, and review render `8858`; case `case-80337eae` was created once and remains `NEW`,
with `approved_at=null` and no approver. Decision execution `8856` proves deployed workflow version
`2403cd06-1dce-4ed4-8a50-024efd83e1a7` and executed Node D
`b33732ccba364076eb3e446d77be5eedda397ad51321a11e5b2e35ddca65690b`.

The governed Cell 4 campaign context was complete and correct. Active rule
`182ad47b-9b53-4957-8841-b51700fa3543` was retrieved, but v3 incorrectly recorded
`evidence_present=false` and excluded it as `NO_PROSPECT_CONTEXT_EVIDENCE_FOR_REASON_FOR_CONTACT` for the
unseen wording “What specifically about my company made you think this was relevant enough to contact me?”.
Consequently `active_form_draft_rule_count=0`, `draft_guidance_injected=false`,
`learning_applied_to_draft=false`, `draft_actually_applied=false`, and first failure was
`NO_ACTIVE_DRAFT_RULES`. The persisted draft was the unrelated timing-close template rather than a grounded
direct reason for contact. Classification rule `71dde429-7278-44bb-8957-eb3eb7263bf6` remained present and
operational; unrelated timing rules were excluded, but the required draft-learning behaviour did not apply.
This is a blocking positive-acceptance defect.

The Decision draft and persisted case draft were byte-equal (SHA-256
`410692777fe8645527b0a5c9e9fb35f046fae3331faa60fdc72b9074a0d71536`), and the review textarea displayed
that persisted draft exactly after HTML escaping. This persistence/render equality does not cure the behavioural
failure. No approval occurred. Sender remained at historical execution `8070`; no Sender execution, Instantly
reply POST, or outbound responder email occurred.

Per the owner-approved critical/high failure rule, the verified Decision rollback and Intake isolation-only
rollback were applied immediately. Current production Decision is version
`2bb92b36-46ad-45d7-83ae-3697e2013437`, semantic
`9ab7cefef85035bd59b12428fea6527ee8f24a24e8eade12ad3d2f2594b87172`, Node D
`a46967329bc24fd58e2226bbbd24b1f3f2de700961036424a4f97702144206e3`. Current Intake is version
`808a79f2-3d77-40ba-aafa-d7545165bbb1`, semantic
`5af1e93540b70c9170900bccc2f00db972dee965aa8ed1b9712728176f3efe5f`: permanent Cell 4 Node D mapping
`de495486f0758febb3aebb2ec11950fca734c2a30543411ce217108e69cbe290` is retained and temporary F1 isolation
is removed (`bd2c25a3ce9852e9c9bd00daf413dbd82fb7c6c329a682a14059316de415142f`). HumanApproval, Sender/Q, inactive
Shadow and sidecar remained protected; Gate 2/autonomy remain disabled; all five workflows are 0 running /
0 waiting. No negative control was requested or sent, and final regression/CRR closure did not begin.

Detailed evidence: `reports/FINAL_DECISION_V3_POSITIVE_ACCEPTANCE_FAILURE_AND_ROLLBACK.md`.

### Continuation contract

- `contract_version`: `4`
- `status`: `BLOCKED_CRITICAL_POSITIVE_ACCEPTANCE_FAILURE_ROLLED_BACK`
- `completed_phase`: `POSITIVE_ACCEPTANCE_FAILURE_FORENSICS_AND_SAFETY_ROLLBACK`
- `current_production_state`: `Decision baseline 2bb92b36 / 9ab7cefe / a4696732; Intake normal governed routing 808a79f2 / 5af1e935 with permanent Cell 4 mapping and no temporary F1 isolation; protected workflows unchanged; all 0/0`
- `authorized_next_phase`: `LOCAL_REASON_FOR_CONTACT_EVIDENCE_DETECTOR_REPAIR_AND_FRESH_INDEPENDENT_REVIEW_ONLY`
- `required_owner_action`: `none until a repaired candidate has new local proof and independent review; do not send a negative control or approve/send case-80337eae`
- `safety_gates_waived`: `false`
- `rollback_state`: `Decision rollback applied and verified; temporary Intake isolation removed while permanent mapping retained`
- `exact_next_session_terminal_marker`: `PRODUCTION CLOSURE NO-GO`

Regression Safety Check: **PASS for failure containment** — the defective v3 candidate is no longer exposed,
normal governed Intake routing is restored, protected components are unchanged, and zero outbound activity
occurred.

PRODUCTION CLOSURE NO-GO

---

## 2026-07-16 — Decision v3 deployed from fresh production baseline (PASS; VALIDATION READY)

Owner-authorized Decision v3 deployment completed against production
`https://n8n.hmzaiautomation.com/api/v1`. The corrected handoff-order gate passed against SHA-256
`3290e0d1cc9d275d84d5032b8ac97a318d3172811e373f8ac4c35b483e1061e5`; branch/HEAD remained
`codex/5q-context-token-forensic-20260705` / `ed94d57`, staging was empty, and all 391 broad dirty/untracked
paths were preserved. The production-target guard and authenticated entry readback passed.

Fresh pre-write production state matched the isolated Intake tuple exactly: active version
`a96d5a4f-f400-4f7c-a0fd-a94b1826775e`, semantic `51d6cb2324559577de5cb819f4dade9c09b31b89987f07e9494d013229574514`,
permanent Node D `de495486f0758febb3aebb2ec11950fca734c2a30543411ce217108e69cbe290`, temporary F1
`23e7c02692943ca8f9d16a7213b0bff8a64a4e3e380c7176c9a77263d49d319c`. Decision matched protected baseline
version `1a2cf9ff-286b-4bf7-84f2-ceb9b6f5625d`, semantic `9ab7cefef85035bd59b12428fea6527ee8f24a24e8eade12ad3d2f2594b87172`,
Node D `a46967329bc24fd58e2226bbbd24b1f3f2de700961036424a4f97702144206e3`.

The existing `verification/production-closure/20260716T031958Z/decision-v3` manifest passed in full; rollback
nodes/connections/name and the n8n-supported filtered settings matched the protected baseline, command syntax
and JSON passed, and no secret was stored. Current reviewed module/patcher hashes still matched the accepted v3
proof. The patcher was applied in memory to a fresh authenticated Decision export: all 16 anchors passed and
produced exact candidate semantic `6004e37dabebd749f2ab148ea8d4adc54a5e17745faf36a73a59b432863e63ec`, Node D
`b33732ccba364076eb3e446d77be5eedda397ad51321a11e5b2e35ddca65690b`; only Decision Node D changed, node count
remained 33, and settings/connections/credential references/classification-learning semantics remained equal.
Reviewed v3 invariants, async-wrapped JavaScript syntax, JSON and scoped secret gates passed.

The bounded PUT produced Decision version `2403cd06-1dce-4ed4-8a50-024efd83e1a7`, active, with exact candidate
semantic and Node D hashes. Immediate authenticated readback proved intended equality. Intake, HumanApproval
`cc6821a94f634bf114f326d63b07752367b536a9ae91084158deda6a6e60e147`, Sender
`9910bfb644f1b67ec18d2d16f1fa52290ca2d9d1168e69f1ab80a921f7d0ad04`, Sender Q
`695bd3db0c193649b0280b74a35818c5f9deeaa0a5b27e103289cab2328df651`, inactive Shadow
`4b2ffe90160bedbc66204e707ad7567b8d03aa9a09f4d0a47402909d52141b05`, and sidecar source hashes
`957654e9…` / `87d8b3ae…` remained protected. Gate 2/autonomy remained disabled. All five workflows were 0 running /
0 waiting; latest execution IDs stayed Intake `8673`, Decision `8354`, HumanApproval `8363`, Sender `8070`,
Shadow none. Deployment launched no workflow execution, approval, Sender execution, Instantly reply POST, or
outbound responder email. Rollback remains immediately available and verified.

Detailed evidence: `reports/FINAL_DECISION_V3_PRODUCTION_DEPLOYMENT_EVIDENCE.md`.

### Continuation contract

- `contract_version`: `3`
- `status`: `AWAITING_OWNER_POSITIVE_CONTROLLED_INBOUND`
- `completed_phase`: `DECISION_V3_PRODUCTION_DEPLOYMENT_AND_READBACK`
- `current_production_state`: `Intake isolated a96d5a4f; Decision v3 2403cd06 / 6004e37d / b33732cc; protected workflows unchanged; all 0/0`
- `authorized_next_phase`: `POSITIVE_SELF_LEARNING_ACCEPTANCE_READ_ONLY_EVIDENCE`
- `required_owner_action`: `send the supplied new reason-for-contact wording from junaidk7531@gmail.com as a reply on the exact approved isolated campaign/sender/thread tuple; do not approve or send the generated draft`
- `safety_gates_waived`: `false`
- `rollback_state`: `verified Decision rollback immediately available; Intake isolation-only rollback preserved`
- `exact_next_session_terminal_marker`: `VALIDATION READY`

Regression Safety Check: **PASS for bounded Decision deployment** — Node-D-only containment and exact production
readback passed; no event, approval, send, checkpoint, Git history mutation, push, Obsidian action, or commercial
traffic occurred.

VALIDATION READY

---

## 2026-07-16 — Owner-authorized provenance correction and Decision v3 continuation gate (PASS; NO PRODUCTION WRITE)

The owner explicitly authorizes this provenance-backed continuation correction after the immediately following
no-write session stopped only because the preceding safe-boundary entry lacked an exact terminal declaration.
This correction supersedes that administrative `PRODUCTION CLOSURE NO-GO` only as a continuation-routing result;
it does not overwrite, weaken, or reinterpret any production evidence, regression gate, approval boundary, hash,
rollback requirement, or protected-component constraint.

The authoritative completed boundary remains the later entry titled
`Intake mapping and temporary isolation deployed (PASS; DECISION APPROVAL REQUIRED)`. Its recorded evidence
remains intact: independent v3 review PASS; focused proof 142/142, 53/53, and 483/483 for both baseline and
candidate; permanent Intake Node D mapping deployed; temporary exact-tuple F1 isolation deployed and proven
10/10; rollback sets verified; Decision still at the protected pre-v3 baseline; protected workflows unchanged;
Shadow inactive; Gate 2/autonomy disabled; no validation, Sender action, outbound email, Git checkpoint, push,
or Obsidian update.

The immediately following no-write stop entry remains preserved verbatim as audit history. It made no production
read or write and therefore does not supersede the last authenticated production evidence. A successor must still
perform the complete fresh entry readback before any Decision write and must stop on any unexplained drift.

### Continuation contract

- `contract_version`: `1`
- `status`: `READY`
- `authorized_next_phase`: `DECISION_V3_DEPLOYMENT_AND_CONTROLLED_ACCEPTANCE`
- `owner_authorization`: `PROVENANCE_BACKED_CORRECTION_APPROVED`
- `administrative_no_go_superseded`: `true`
- `safety_gates_waived`: `false`
- `fresh_production_readback_required`: `true`
- `temporary_f1_isolation_expected`: `true`
- `decision_expected_at_pre_v3_baseline`: `true`
- `repeat_credential_or_governance_investigation`: `false_unless_direct_drift`
- `repeat_independent_v3_review_or_focused_suites`: `false_unless_source_or_checksum_drift`
- `next_required_action`: `re-run full fresh entry gate, then continue Decision backup revalidation, fresh-baseline patch, deployment, positive acceptance, negative control, F1 restoration, final regression, CRR, and checkpoint gates`

This entry is the newest authoritative continuation state. Future sessions must evaluate this continuation
contract together with fresh production invariants; they must not require the preserved historical predecessor
entry itself to end with the terminal declaration below.

Regression Safety Check: **PASS for this provenance-only correction** — this entry changes continuation metadata
only. All pre-existing handoff content is preserved byte-for-byte after the insertion; no workflow, credential,
execution, send, Git history, Obsidian record, or production state is changed by this file correction.

FRESH SESSION REQUIRED — DECISION V3 DEPLOYMENT READY

---

## 2026-07-16 — Corrective continuation entry found out of authoritative order (ENTRY BLOCKED; NO PRODUCTION CALL)

The owner instructed the operator to resume from a newly added top provenance-correction entry. Fresh disk
inspection found that correction text intact at lines 211–255, including its Decision-ready terminal marker,
but it is below the newer administrative no-write entry and the Intake PASS entry. The file declares newest
entries first, so the correction is not the newest authoritative entry as represented. This direct repository-
order drift was not silently repaired, reordered, duplicated, or treated as production authorization.

Local entry facts verified before stopping: branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57`,
Git staging empty, and 391 dirty/untracked paths preserved. No production-target guard, n8n/Instantly API call,
production read or write, workflow execution, validation event, send, test collection, Git history operation,
Obsidian action, or commercial traffic occurred in this continuation attempt.

### Continuation contract

- `contract_version`: `2`
- `status`: `BLOCKED_REPOSITORY_ORDER_DRIFT`
- `completed_phase`: `LOCAL_ENTRY_PREFLIGHT_ONLY`
- `current_production_state`: `NOT_FRESHLY_READ_IN_THIS_ATTEMPT`
- `authorized_next_phase`: `CORRECT_HANDOFF_ORDER_THEN_RERUN_FULL_ENTRY_GATE`
- `required_owner_action`: `place or add the owner-authorized provenance correction as the actual newest top entry without removing preserved audit history`
- `safety_gates_waived`: `false`
- `rollback_state`: `previously recorded artifacts exist; not freshly revalidated in this attempt`
- `exact_next_session_terminal_marker`: `FRESH SESSION REQUIRED — DECISION V3 DEPLOYMENT READY`
- `this_entry_terminal_marker`: `PRODUCTION CLOSURE NO-GO`

Regression Safety Check: **PASS for the no-contact stop boundary** — the protected dirty worktree remains
preserved, staging is empty, and production was neither contacted nor changed.

PRODUCTION CLOSURE NO-GO

---

## 2026-07-16 — Decision v3 closure stopped at literal entry gate (NO PRODUCTION CALL OR WRITE)

The owner authorised the bounded Decision v3 production-closure chain, but the session did not proceed because
the newest preceding handoff entry does not conclude with the exact required Decision-ready terminal declaration.
It ends with the safe-boundary Regression Safety Check instead. This is a hard owner-defined precondition and was
not repaired or treated as a semantic-equivalence check by the current operator.

Local checks completed before stopping: branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57`, Git
staging empty, and 391 broad pre-existing dirty/untracked paths preserved. No checkout, reset, restore, stash,
clean, pull, n8n/Instantly API call, production read, production write, workflow execution, validation event,
send, test collection, stage, commit, tag, branch creation, push, Obsidian access, or commercial traffic occurred.
Temporary Intake F1 isolation therefore remains in the previously recorded state; no fresh production assertion
was made in this blocked session.

Required owner action: explicitly direct a fresh session to waive the literal predecessor-handoff requirement or
authorise a provenance-backed correction by the operator/session that produced that readiness boundary. After
that, restart from the full entry gate; do not infer that protected production hashes remain current from this
blocked session.

Regression Safety Check: **PASS for the no-write stop boundary** — only this handoff entry was added; the dirty
worktree was preserved, staging remains empty, and production was not contacted or changed.

PRODUCTION CLOSURE NO-GO

---

## 2026-07-16 — Intake mapping and temporary isolation deployed (PASS; DECISION APPROVAL REQUIRED)

Owner approved only the grouped Intake production-write phase. Permanent Node D mapping deployed from
baseline version `abc83e43-9b97-4ca1-ae32-c42599255328` as version
`a489fd70-8c89-4134-817e-9f1ef39535f5`, semantic `5af1e93540b70c9170900bccc2f00db972dee965aa8ed1b9712728176f3efe5f`,
Node D `de495486f0758febb3aebb2ec11950fca734c2a30543411ce217108e69cbe290`; only Node D changed. Temporary
F1 isolation then deployed as final version `a96d5a4f-f400-4f7c-a0fd-a94b1826775e`, semantic
`51d6cb2324559577de5cb819f4dade9c09b31b89987f07e9494d013229574514`, Node D retained, F1
`23e7c02692943ca8f9d16a7213b0bff8a64a4e3e380c7176c9a77263d49d319c`; only F1 changed versus the mapped
version. Exact candidate equality, settings/connections/credential equality and active state passed after
each write.

Production-readback isolation proof passed 10/10: exact tuple passes; each single-field mismatch fails with
all other fields correct; unrelated recipients/campaigns fail; synthetic/dev routing is baseline-equivalent.
Protected Decision `9ab7cefe…`, HumanApproval `cc6821a9…`, Sender `9910bfb6…`, Q `695bd3db…`, inactive
Shadow `4b2ffe90…`, and sidecar hashes remained unchanged. All five workflows ended 0 running / 0 waiting;
latest execution IDs remained historical (Intake 8673, Decision 8354, HumanApproval 8363, Sender 8070,
Shadow none). Secret scans passed; no workflow execution, send or outbound email occurred.

Backups/rollback: `verification/production-closure/20260716T031958Z/intake-governance-isolation/`; isolation-
only rollback retains the mapping, full rollback restores pre-write Intake. Detailed evidence:
`reports/FINAL_INTAKE_MAPPING_AND_ISOLATION_PRODUCTION_EVIDENCE.md`. Decision remains baseline and must not be
deployed without separate explicit approval. No validation event, full regression, stage, commit, tag, branch,
push or Obsidian action occurred.

### Safe phase boundary — fresh Decision session required

1. Entry gate: **PASS**.
2. Independent v3 review: **INDEPENDENT PASS FOR V3 PRODUCTION CLOSURE**.
3. Focused proof: module **142/142**; integration **53/53**; behavioural baseline **483/483**; behavioural
   candidate **483/483**.
4. Intake versions: baseline `abc83e43-9b97-4ca1-ae32-c42599255328`; permanent mapping
   `a489fd70-8c89-4134-817e-9f1ef39535f5`; final isolated `a96d5a4f-f400-4f7c-a0fd-a94b1826775e`.
5. Final Intake semantic: `51d6cb2324559577de5cb819f4dade9c09b31b89987f07e9494d013229574514`.
6. Permanent Node D: `de495486f0758febb3aebb2ec11950fca734c2a30543411ce217108e69cbe290`.
7. Temporary F1: `23e7c02692943ca8f9d16a7213b0bff8a64a4e3e380c7176c9a77263d49d319c`.
8. Production-readback isolation proof: **10/10 PASS**.
9. Baseline-to-final containment: only Intake Node D and F1 changed.
10. Mapping-to-final containment: only Intake F1 changed.
11. Settings, connections and credential references: unchanged.
12. Protected hashes unchanged: Decision
    `9ab7cefef85035bd59b12428fea6527ee8f24a24e8eade12ad3d2f2594b87172`; HumanApproval
    `cc6821a94f634bf114f326d63b07752367b536a9ae91084158deda6a6e60e147`; Sender
    `9910bfb644f1b67ec18d2d16f1fa52290ca2d9d1168e69f1ab80a921f7d0ad04`; Sender Q
    `695bd3db0c193649b0280b74a35818c5f9deeaa0a5b27e103289cab2328df651`; inactive Shadow
    `4b2ffe90160bedbc66204e707ad7567b8d03aa9a09f4d0a47402909d52141b05`; sidecar
    `957654e988320725514d43ef09a3d0aa033c8c36f8e159943be270393f874550` /
    `87d8b3aeb521474097aafedc0ab0fa483fa869c97736a9670a0c4059221c68e5`.
13. Fresh boundary readback: Intake, Decision, HumanApproval, Sender and Shadow each **0 running / 0 waiting**.
14. No validation event, Sender execution or outbound responder email occurred; latest execution IDs remain
    Intake `8673`, Decision `8354`, HumanApproval `8363`, Sender `8070`, Shadow none.
15. Scoped workflow/repository/backup secret scans: **PASS**.
16. Git staging area: empty; no commit, tag, branch, push or Obsidian action.
17. Backup root: `verification/production-closure/20260716T031958Z/intake-governance-isolation`.
18. Isolation-only rollback: `verification/production-closure/20260716T031958Z/intake-governance-isolation/intake-isolation-only-rollback-payload.json`.
19. Full Intake rollback: `verification/production-closure/20260716T031958Z/intake-governance-isolation/intake-full-rollback-payload.json`.
20. Evidence report: `reports/FINAL_INTAKE_MAPPING_AND_ISOLATION_PRODUCTION_EVIDENCE.md`.

**Temporary F1 isolation is intentionally preserved** for the immediate fresh Decision v3 deployment and
controlled validation session. Decision remains at protected pre-v3 version
`1a2cf9ff-286b-4bf7-84f2-ceb9b6f5625d`, semantic `9ab7cefe…`, Node D `a4696732…`. Shadow remains inactive;
Gate 2 and autonomy remain disabled. The successor must not repeat credential investigation, governance
investigation, independent v3 review, focused test collections or Intake deployment unless a direct fresh
readback detects drift. Resume with fresh Decision baseline verification, checksum-backed candidate equality,
separate Decision deployment approval, deployment/readback, then the controlled validation gate.

Regression Safety Check: **PASS for the safe phase boundary** — read-only production verification confirmed
the preserved isolated state and protected hashes; only this handoff entry was updated. No production write,
workflow execution, test rerun, Decision deployment, validation event, stage, commit, push or Obsidian access
occurred at the boundary.

---

## 2026-07-16 — Steps 8–12 closure paused at Intake write approval (REVIEW/BACKUP PASS; NO PRODUCTION WRITE)

Entry gate passed after the exact required terminal verdict was added to the preceding handoff entry; all
credential/governance prerequisites remained PASS and the CRR remained unsigned. Branch/HEAD is still
`codex/5q-context-token-forensic-20260705` / `ed94d57`; staging is empty and all 397 pre-existing dirty/
untracked paths are preserved.

Fresh authenticated protected readback matched Intake `5962b0a6…` / D `8a1bb1c2…` / F1 `bd2c25a3…`,
Decision `9ab7cefe…` / D `a4696732…`, HumanApproval `cc6821a9…`, Sender `9910bfb6…` / Q `695bd3db…`, and
inactive Shadow `4b2ffe90…`; all five were 0/0 running/waiting and Gate 2/autonomy remained disabled.
Independent review verdict: **INDEPENDENT PASS FOR V3 PRODUCTION CLOSURE**. Focused proof passed 142/142,
53/53, behavioural baseline/candidate 483/483 each, syntax/JSON/config/secret and patcher fail-closed guards.
Fresh Decision candidate is `6004e37d…` / Node D `b33732cc…`, Node-D-only.

Checksum-verified secret-free backups are under
`verification/production-closure/20260716T031958Z/{intake-governance-isolation,decision-v3}/`; every manifest
entry and rollback/deploy command syntax passed. Local Intake candidate proof passed 24/24. Approved Cell 4
and campaign row were added locally to `docs/VALIDATION_CAMPAIGN_CONFIG.md`. No production workflow write,
execution, send, stage, commit, Git ref, push, Obsidian action or commercial traffic occurred.

Resume only after explicit approval for grouped Intake production writes: deploy permanent Node D mapping,
read back and verify, then deploy temporary F1 isolation and read back/verify. Decision v3 deployment requires
its later separate approval.

---

## 2026-07-16 — Pre-production credential and governance gates cleared (LOCAL EVIDENCE UPDATE ONLY)

**Branch/HEAD baseline:** `codex/5q-context-token-forensic-20260705` / `ed94d57`.  
**Gate verdict:** credential **PASS (4/4)**; governance **PASS (2/2)**. Steps 8–12 were not begun.

Credential evidence is closed without storing values. Replacement Instantly API access returned HTTP `200`
for the exact campaign read; the superseded key returned HTTP `401` on the same request. Replacement webhook
authentication is proven by safe B2 terminal execution `8652` and the approved 11-second A–B–A differential:
A1 execution `8672` HTTP `200`, middle superseded-token request HTTP `403` with no execution, then A2
execution `8673` HTTP `200`. A1/A2 each contained its unique proof ID, finished successfully at
`B2. Configuration Gate Rejection (Terminal)` because `campaign_id is missing`, and had zero Decision,
HumanApproval, Sender or Data Table correlation. The middle proof had zero Intake, Decision, HumanApproval,
Sender or Data Table correlation. No outbound responder email occurred.

Governance proposal `CGP-531e64ed-v1-20260715`, canonical SHA-256
`2f9a6af856bea4aa5713b5801606e0119b3b3cfa2d856e4f125cbecc2e8562ec`, and proposed cell
`CELL_4_RESPONDER_ACCEPTANCE_CAPACITY_ALIGNED` are approved exactly as recorded. Humza separately attested
at `2026-07-16T02:00:00Z` as co-business partner and owner approver; Abs separately attested at
`2026-07-16T02:01:00Z` as co-business partner and business-partner approver. Both have equal authority to
approve email replies. Both attestations originated from shared account `humza@hmzaiautomation.com`; this is
not independent account or identity authentication.

### Protected production baselines at gate entry

- Intake `VtDQqw02Ux1TgjIH`: active version `abc83e43-9b97-4ca1-ae32-c42599255328`, semantic
  `5962b0a66d3be99dedaca4b8d25d9a23f6d9efb49bfe6c32830de0eda4980791`, Node D
  `8a1bb1c265ded9b06540c14b2c66801426c670282eb14d348425927fde29a6c4`, F1
  `bd2c25a3ce9852e9c9bd00daf413dbd82fb7c6c329a682a14059316de415142f`.
- Decision `tgYmY97CG4Bm8snI`: active version `1a2cf9ff-286b-4bf7-84f2-ceb9b6f5625d`, semantic
  `9ab7cefef85035bd59b12428fea6527ee8f24a24e8eade12ad3d2f2594b87172`, Node D
  `a46967329bc24fd58e2226bbbd24b1f3f2de700961036424a4f97702144206e3`.
- HumanApproval semantic `cc6821a94f634bf114f326d63b07752367b536a9ae91084158deda6a6e60e147`;
  Sender semantic `9910bfb644f1b67ec18d2d16f1fa52290ca2d9d1168e69f1ab80a921f7d0ad04`; Sender Node Q
  `695bd3db0c193649b0280b74a35818c5f9deeaa0a5b27e103289cab2328df651`; inactive Shadow semantic
  `4b2ffe90160bedbc66204e707ad7567b8d03aa9a09f4d0a47402909d52141b05`.
- Shadow inactive; Gate 2 and autonomous operation disabled. No production workflow or credential mutation,
  deployment, valid responder event, approval, Sender action or outbound email occurred during gate closure.

### Exact entry conditions for a fresh Steps 8–12 closure session

1. Treat the credential and governance gates above as complete; do not repeat their historical investigation.
2. Reconfirm branch/HEAD, preserve the broad dirty worktree, require an empty staging area, run the production
   target guard, and read back current Intake/Decision versions plus every protected hash before any write.
   Stop on unexplained drift. Require relevant workflows `0 running / 0 waiting`, Shadow inactive, and Gate
   2/autonomy disabled.
3. Independently review draft-learning v3 from the authoritative local proof and fresh-baseline patcher. Run
   the focused pre-deployment collections once. Proceed only on `INDEPENDENT PASS FOR V3 PRODUCTION CLOSURE`.
4. Create separate checksum-verified Intake/isolation and Decision/rollback backups. Implement only proposal
   `CGP-531e64ed-v1-20260715`: Intake Node D plus `docs/VALIDATION_CAMPAIGN_CONFIG.md`, then temporary F1
   isolation for campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, recipient `junaidk7531@gmail.com`, and
   the exact approved sender/thread tuple. Prove each mismatch fails closed and keep rollback ready.
5. Fetch the fresh production Decision, apply the reviewed patcher to that export, and deploy only the Node D
   semantic change after candidate equality, protected-state and secret checks pass. Never deploy an old local
   candidate directly.
6. Request one genuinely new owner-controlled inbound asking why contact was made; do not approve or send its
   draft. Prove the full eleven-stage chain and zero Sender/outbound. Then request one unrelated benign negative
   control and prove truthful `actually_applied=false` with zero outbound.
7. Restore only temporary F1 isolation, retaining the approved permanent mapping. Run the mandatory full
   regression collection once, update the still-unsigned CRR, and stop at the explicit owner-signature gate.
   Do not checkpoint, push, update Obsidian or begin commercial rollout without the later approvals.

Authoritative files for that fresh session, in order: `OPERATION_HANDOFF.md`,
`reports/FINAL_PRODUCTION_CLOSURE_CREDENTIAL_GATE.md`,
`reports/CAMPAIGN_VALIDATION_CELL_OWNER_DECISION.md`, `reports/DRAFT_LEARNING_V3_LOCAL_PROOF.md`,
`reports/NEXT_CODEX_PROMPT_DRAFT_LEARNING_V3_FINAL_CLOSURE.md`,
`reports/DRAFT_LEARNING_PRODUCTION_CLOSURE_REPORT.md`,
`docs/DRAFT_LEARNING_PRODUCTION_DEPLOYMENT_AND_ACCEPTANCE_RUNBOOK.md`,
`docs/campaign-readiness/CRR-531e64ed.md`, and `reports/FINAL_CHECKPOINT_AND_FREEZE_MANIFEST.md`.

Regression Safety Check: **PASS for credential/governance gate closure** — evidence-only edits were limited
to the four owner-approved files; production workflows, credentials and protected state were untouched; no
deployment, valid responder event, draft-learning test, Sender action, Git operation or Obsidian access
occurred. A non-disclosing scan of exactly those four files found zero high-confidence credential-literal
pattern classes, confirming no credential value was persisted. Final post-acceptance regression remains
mandatory.

PRE-PRODUCTION GATES CLEARED FOR FRESH CODEX CLOSURE

---


## 2026-07-15 — Credential Rotation Verification (PARTIAL PASS; AUTH PROOF BLOCKED; NO PRODUCTION WRITE)

Owner reported both scoped replacements entered and both superseded credentials removed/revoked at
`2026-07-15T22:30:00Z`, with no value supplied in chat. Read-only n8n evidence confirms credential-record
updates: `hmzInstantlyApi` (`jWeA…l7yK`) updated `22:21:07.878Z`; `hmzInstantlyWebhookToken`
(`gUUV…HOCM`) updated `22:25:49.980Z`. Names, types, references, workflow versions, nodes, connections,
settings, and protected semantics remain unchanged. Intake/Decision/HumanApproval/Sender/Shadow are each
0/0 running/waiting. No execution occurred after owner completion; Decision latest remains `8354`, Sender
latest remains historical `8070`; no responder outbound occurred. Shadow is inactive; Gate 2/autonomous
remain disabled. Workflow export secret scan passed; repository/report high-confidence scan covered 1,114
text files with zero findings.

Mandatory auth proof is still blocked: public n8n API exposes only sanitized credential metadata, not the
stored values or a generic-header credential test; no secret-bearing environment variable exists. Therefore
Codex cannot independently issue the new/old Instantly requests or new/old webhook requests without the owner
locally using those values. Metadata update/revocation attestation is not treated as authentication proof.
Gate remains closed pending four sanitized owner-executed results (new Instantly campaign GET succeeds; old
key fails; new malformed webhook authenticates and yields one Intake-only execution; old token rejects with
no Intake execution). No focused test run, workflow/campaign/credential write, validation event, send, stage,
commit, tag, branch, push, or Obsidian change occurred. Detailed evidence:
`reports/FINAL_PRODUCTION_CLOSURE_CREDENTIAL_GATE.md`.

---

## 2026-07-15 — Final Production Closure (CREDENTIAL GATE; NO PRODUCTION WRITE)

**Branch/HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57`; all 387 pre-existing dirty/untracked
paths preserved; staging empty. Production-target guard and authenticated read-only n8n preflight passed.
Intake remains version `abc83e43…`, semantic `5962b0a6…`, Node D `8a1bb1c2…`, F1 `bd2c25a3…`.
Decision remains protected baseline version `1a2cf9ff…`, semantic `9ab7cefe…`, Node D `a4696732…`.
HumanApproval `cc6821a9…`, Sender `9910bfb6…`, Node Q `695bd3db…`, and inactive Shadow `4b2ffe90…`
match protected state. Intake/Decision/HumanApproval/Sender/Shadow are each 0/0 running/waiting; Gate 2 and
autonomous operation remain disabled. Same-day authenticated Instantly evidence remains 17 owner-controlled
recipients; only `junaidk7531@gmail.com` is authorised for closure events.

The exposed pair is recorded without values as the Instantly API header credential `jWeA…l7yK`
(`hmzInstantlyApi`) and inbound webhook header/token credential `gUUV…HOCM`
(`hmzInstantlyWebhookToken`). Both require owner-side replacement entry and provider-side revocation; new-auth
success, old-auth failure, controlled inbound no-send authentication, and unchanged protected state must then
be proven. No focused v3 test run was consumed because deployment remains blocked. The separate Humza and Abs
governance attestations are also still absent. No backup, workflow/credential/campaign write, event, send,
stage, commit, tag, branch, push, or Obsidian change occurred.

Detailed evidence and exact safe operator actions:
`reports/FINAL_PRODUCTION_CLOSURE_CREDENTIAL_GATE.md`. Resume at credential verification, then validate both
attestations before independent review. Do not repeat completed preflight investigation unless state changed.

---

## 2026-07-15 — Codex Governance and Final Closure (GOVERNANCE GATE; NO PRODUCTION WRITE)

**Branch/HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57`; broad dirty worktree preserved;
nothing staged. Production-target guard and authenticated read-only n8n access passed. Decision remains
baseline version `1a2cf9ff…`, semantic `9ab7cefe…`, Node D `a4696732…`, active/33; Intake remains
`abc83e43…`, semantic `5962b0a6…`, Node D `8a1bb1c2…`. Sender `9910bfb6…`, Q `695bd3db…`,
HumanApproval `cc6821a9…`, and inactive Shadow `4b2ffe90…` are unchanged; Gate 2/autonomous disabled;
Intake/Decision/HumanApproval/Sender/Shadow each 0/0 running/waiting.

Authenticated Instantly extraction resolved the exact Step 1 / Variant 1 subject/body/config and the current
17-recipient scope. Owner confirms every recipient is controlled acceptance and no real prospect is present;
only `junaidk7531@gmail.com` is approved for this closure. The exact message is generic US B2B
capacity-aligned outbound and matches none of Cells 1–3. Proposal `CGP-531e64ed-v1-20260715`, SHA-256
`2f9a6af8…`, creates one acceptance-specific Cell 4, one exact campaign registry row, one Node-D campaign-ID
lookup, and one temporary F1 campaign/recipient/sender/thread guard. Full evidence and exact Humza/Abs
attestations: `reports/CAMPAIGN_VALIDATION_CELL_OWNER_DECISION.md` §9.

Gate: wait for two separate named/timestamped attestations, both disclosing origin through shared account
`humza@hmzaiautomation.com`; shared account is not independent authentication. No production write,
backup, deploy, event, send, stage, commit, tag, branch, push, or Obsidian change occurred. Credential hygiene
stop: two live values were inadvertently surfaced only in ephemeral tool output (not repository-persisted);
separate rotation authority/completion is required before any production write.

---

## 2026-07-15 — Codex Draft-Learning v3 Production Closure (DEPLOYED; OWNER CONTEXT DECISION REQUIRED)

**Branch/HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57`; broad dirty worktree preserved.
**Independent verdict:** `INDEPENDENT PASS FOR FABLE PRODUCTION CLOSURE` recorded in
`reports/DRAFT_LEARNING_V3_INDEPENDENT_REVIEW.md` after local 142/142 + 53/53, exact failed-case replay,
patcher/secret/syntax guards, 6/6 classification-function identity, and Node-D-only containment.

Fresh production baseline Decision `cad701a5…` matched semantic `9ab7cefe…`, Node D `a4696732…`, active/33,
0/0. Fresh patch produced Node D `b33732cc…`, semantic `6004e37d…`; focused candidate proof 142/142 + 53/53
+ 483/483. Checksum-verified backup:
`/var/backups/hmz-instantly-responder/draft-learning-v3/20260714T231401Z/` (13/13 content checksums PASS
locally and remotely; rollback payload/commands present).

Decision-only deployment PASS: current version `ec18cda2-aa9c-4672-adf3-2bfba7fffd22`, semantic exactly
`6004e37d…`, Node D `b33732cc…`, active/33, only Node D changed, 0/0. HumanApproval `cc6821a9…`, Sender
`9910bfb6…`, Q `695bd3db…`, Shadow `4b2ffe90…` inactive unchanged; Gate 2/autonomous disabled; no standalone
execution or send.

Integrated smoke PASS: Intake `8353` → Decision `8354` → HumanApproval create `8355`, one case row 173 /
`case-0cf8de28`; Q12 36 live rows; deployed Node D ran; read-only form render `8356` showed the same persisted
draft; Sender latest remains historical `8070`, no Instantly POST/email. Campaign context is confirmed
unresolved: production Intake mapping has no `531e64ed…`; smoke carried all-`UNKNOWN`. Preserved teaching is
validly reused only as teaching: case `case-d38b78cc`, event `f808eaf8…`, active rule row 114 / `182ad47b…`,
known scope, v3 class `reason_for_contact`; never repaired-generation evidence.

**Owner chose path (a), but the mandatory pre-write uniqueness gate failed:** production Intake
`VtDQqw02Ux1TgjIH` Node C only accepts an inbound `validation_cell`; Node D (`8a1bb1c2…`) expands one of three
governed cells but has no campaign-ID registry lookup. `docs/VALIDATION_CAMPAIGN_CONFIG.md` explicitly has no
configured campaign rows, the live n8n Data Table catalogue has no campaign-context registry, and the Instantly
campaign record name `HMZ Responder Behaviour Acceptance - Round 1` does not identify Cell 1/2/3. Any selection
would invent `pain_trigger`/`offer_angle`; therefore no Intake backup/write/rollback artifact was created and
no mapping changed.

**Subsequent owner-requested safety gate:** Intake is active, the campaign and 24 sender eaccounts are
allowlisted, and no recipient/test-inbox allowlist exists, so isolation to `junaidk7531@gmail.com` could not be
proven. With Decision 0/0, Sender still historical `8070`, Shadow inactive, and protected state intact, the
checksum-verified rollback payload was applied. **Current Decision:** version
`1a2cf9ff-286b-4bf7-84f2-ceb9b6f5625d`, active/33, baseline semantic `9ab7cefe…`, Node D `a4696732…`, 0/0.
HumanApproval `cc6821a9…`, Sender `9910bfb6…`, Q `695bd3db…`, Shadow `4b2ffe90…` inactive unchanged;
Gate 2/autonomous disabled. No candidate is exposed.

Read-only owner decision packet: `reports/CAMPAIGN_VALIDATION_CELL_OWNER_DECISION.md`. Verdict:
`INSUFFICIENT EVIDENCE` for Cells 1/2/3. Actual record provides campaign ID/name, workspace, controlled inbox,
sender, subject, step=1, variant=1, and owner-confirmed CTA, but not the full initial body, campaign-specific
purpose, governed message-variant ID, segment/subsegment, pain trigger, offer angle, or cell. No cell selected;
no registry/config/workflow/table change. Unblock requires owner + named business-partner supplied authoritative
values using the packet's approval statement. Fail-closed path (b) is explicitly not selected.

No staging/commit/branch/tag/push/Obsidian action. Detailed evidence:
`reports/DRAFT_LEARNING_V3_PRODUCTION_CLOSURE_REPORT.md`.

---

## 2026-07-14 — Claude Fable 5 Draft-Learning v3 Repair (Codex NO-GO findings resolved; LOCAL PASS; GO FOR FRESH CODEX V3 FINAL CLOSURE)

**Agent/model:** Claude Fable 5, bounded v3 repair architect. **Branch/HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57` (verified; broad dirty worktree preserved).
**Newest previous handoff:** 2026-07-14 Claude Fable 5 v2 Repair (GO FOR CODEX FINAL ACCEPTANCE) — superseded by the Codex v2 review verdict.
**Production actions: NONE** (no API call, no SSH, no deploy, no send, no workflow invocation; nothing staged/committed/branched/tagged/pushed; Obsidian untouched).

**Trigger:** `reports/DRAFT_LEARNING_V2_INDEPENDENT_REVIEW.md` — **INDEPENDENT NO-GO**, severity HIGH:
(1) patcher K1 substituted unresolved `pain_trigger`/`offer_angle`/`validation_cell` with factual-looking
defaults in the provider prompt; (2) evidence chain never validated original campaign context —
K1 substitutes + a compliant-looking model reply could certify `actually_applied=true`; (3) sentinel
detection case-sensitive, missing `unspecified` and equivalents; (4) no regression covering unresolved
source + compliant-looking output. A prior Fable session correctly refused the deployment authorization
because the review did not conclude PASS.

**v3 repair (LOCAL ONLY, Decision Node D scope, NOT deployed):**
- Module v3 `infrastructure/draft-learning/decision-draft-compliance.js`: NFKC/whitespace-normalized,
  case-insensitive, word-bounded sentinel detection (adds `unspecified`, `not specified`, `not provided`,
  `unavailable`, `tbc`, `${...}` templates; prompt scan exempts only `<<firstName>>/<<senderName>>/<<bookingLink>>`);
  per-class original source requirements (`_5Q_CLASS_REQUIRED_SOURCE_FIELDS`: `reason_for_contact`→`pain_trigger`;
  unknown classes fail closed); `_5qEvaluateSourceContext()` explicit evidence (classes, required/present/
  unresolved/safely-omitted fields, `source_context_resolved`, sanitized reason); winner selection excludes
  `REQUIRED_SOURCE_CONTEXT_UNRESOLVED_FAIL_CLOSED` rules BEFORE injection (safe baseline preserved);
  `_5qDetectSubstituteGrounding()` rejects the legacy invented phrases; evidence v3 adds mandatory
  `source_context_resolved`, gates `context_resolved` on it + no substitute grounding + no sentinel in
  source/prompt/guidance/persisted, forces `persisted_compliant=false` on unresolved source; strict
  11-stage `actually_applied` conjunction; no later stage overrides an earlier one.
- Patcher v3 `scripts/DRAFT-LEARNING-apply-compliance-evidence-fix.py`: 16 anchored fail-closed edits
  (A,B,C,J,K1,K1b,K2,M1,M2,L,D,E,F,G,H,I). K1/K1b now OMIT unresolved fields (no substitutes; explicit
  "CAMPAIGN CONTEXT: none provided — do not invent" line); M1/M2 capture the exact provider prompt for the
  evidence chain; post-conditions REFUSE substitute-context fallbacks and require the v3 elements; keeps
  `--expect-node-sha` pin (production Node D `a4696732…`), Node-D-only semantic diff, secret guard.
- Regenerated local candidate `workflows/decision_candidate_draft_learning_compliance_fix.json`:
  Node D `b33732cc…`, semantic `5b9d95b0…`, 33 nodes, Node-D-only diff. NEVER deploy directly —
  production regenerates from a fresh authenticated export.

**Proof (zero network):** module **142/142**; integration **53/53** (PREV fixture exact-8230 R1–R6;
v3 fail-closed F1–F10; resolved-source noncompliant-model G1–G4; **new key regression KR1–KR5**
[unresolved source + compliant-looking output + clean persisted ⇒ all grounding stages FALSE]; clean chain
P1–P8; negative/hygiene/classification N1–N8/K1–K2); harness **483/483 baseline root AND 483/483 candidate
root** (temp-root helper-script artifact identified and resolved — not a code defect); Sender gates
**77/77**; item-18 **60/60** (truthful pin `a2cd9419…`); B6 **31/31 + 8/8 + 19/19**; negative invariants
**6/6**; legacy 21/21 evidence stands (sidecar byte-equal `957654e9…`/`87d8b3ae…`); Node D `node --check`,
JSON, secret scan PASS. Patcher guards proven (drift refusal, already-patched refusal, substitute-fallback
refusal). Protected: Sender `9910bfb6…` ✓, Q `695bd3db…` ✓, HumanApproval `cc6821a9…` ✓, Decision baseline
untouched (`4c9e806a…`/Node D `a4696732…`), Shadow `active=false` byte-unchanged, Gate 2/autonomous disabled.

**NEW operational prerequisite:** clean-chain `actually_applied=true` acceptance now requires the
production Intake to resolve `nes.campaign_context.pain_trigger` for campaign `531e64ed…` (exec 8230
carried `UNKNOWN` — the campaign is likely unmapped to a validation cell). v3 truthfully fails closed
otherwise. Runbook v3 step 8a records the owner decision path (approve minimal intake mapping fix, or
accept fail-closed proof). Never fabricate context.

**Files changed (v3 session):** module, patcher, regenerated candidate, 2 test suites,
`reports/DRAFT_LEARNING_V3_LOCAL_PROOF.md` (new), forensic + closure report v3 addenda, runbook v3,
checkpoint-manifest v3 refresh (still blocked), CRR v3 status (unsigned),
`reports/NEXT_CODEX_PROMPT_DRAFT_LEARNING_V3_FINAL_CLOSURE.md` (new), this handoff. Codex v2 review
preserved verbatim. Transient `.tmp-v3/` removed.

**Next session:** FRESH Codex session with
`reports/NEXT_CODEX_PROMPT_DRAFT_LEARNING_V3_FINAL_CLOSURE.md` — one dependency chain: bounded
independent v3 review (STOP on NO-GO) → fresh authenticated Decision retrieval → fresh-baseline patcher →
focused proof → verified backup → Decision-only deploy → smoke → campaign-context check (step 8a) →
teaching (valid reuse of case-d38b78cc or one replacement) → genuinely fresh unseen validation → negative
control → classification control → final regression once → CRR signature gate → checkpoint/freeze gate →
rollout preparation only. Never reuse `case-623134e7` as fresh validation; never use a real prospect;
nothing staged/pushed before owner approval.

**Regression Safety Check:** handoff + review read first; branch/HEAD verified; dirty worktree preserved
(no checkout/clean/restore/stash); only scoped draft-learning files + listed docs changed; no production
access or mutation; no send; no secrets printed or persisted; Sender/Q/sidecar/HumanApproval/Shadow
untouched; Shadow inactive; Gate 2/autonomous disabled; nothing staged or committed.

---

## 2026-07-14 — Claude Fable 5 Draft-Learning v2 Conflict/Sentinel/Grounding Repair (LOCAL PASS; GO FOR CODEX FINAL ACCEPTANCE)

**Agent/model:** Claude Fable 5, bounded repair architect. **Branch/HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57`.
**Newest previous handoff:** 2026-07-14 Codex Draft-Learning Integrated Acceptance (VALIDATION NO-GO; SAFE ROLLBACK COMPLETE).
**Production actions: NONE** (no API call, no SSH, no deploy, no send; nothing staged/committed/branched/tagged/pushed).

**Failed validation addressed:** exec `8230` / `case-623134e7` on deployed candidate `6077adbc…` (since rolled
back to protected `9ab7cefe…`, version `cad701a5…`). **Causal defects (proven, forensic addendum):** (1)
draft eligibility keyed on micro-intent label only → classification `OFFER_EXPLANATION→NON_PRIORITY` leaked
`AMBIGUOUS/NON_PRIORITY` timing rules into scope; (2) no behaviour classes/evidence gates/conflict grouping →
five conflicting rules injected; (3) sentinel `pain_trigger='UNKNOWN'` truthy → entered prompt + persisted
reason line; (4) `NON_PRIORITY` prompt instruction asserted an unstated timing objection → model invented
timing; (5) v1 `actually_applied` let a post-processor delta override `model_complied=false`/`post_processing_preserved=false`.

**Exact repair (v2, Decision Node D only, NOT deployed):** module v2 `infrastructure/draft-learning/decision-draft-compliance.js`
(sentinel rejection; behaviour classes w/ deterministic safe migration, fail-closed `unclassified`;
prospect-evidence gates; broad-category leakage guard; one-winner-per-class deterministic conflict selection
with fail-closed equal-priority ties; cross-class compatibility; strict all-mandatory-stage `actually_applied`
— post-processor repair ≠ application); patcher v2 (12 fail-closed anchored edits incl. winner-selection
wiring, sentinel-safe prompt context, timing-evidence-gated NON_PRIORITY/NOT_NOW instruction, final
sentinel persistence gate; `--expect-node-sha` pins fresh production Node D `a4696732…`; Node-D-only
semantic-diff guard). Exact-8230 deterministically reproduced against the deployed-candidate fixture
(`tests/fixtures/draft-learning/decision_candidate_prev_compliance_fix_972bc711.json`) and fixed A/B.

**Files changed (17):** module, patcher, regenerated local candidate (Node D `18185a11…`), 2 test suites,
1 new fixture, forensic/repair/closure report addenda, runbook v2 (23-step), new
`reports/NEXT_CODEX_PROMPT_DRAFT_LEARNING_FINAL_ACCEPTANCE.md`, CRR update (unsigned), checkpoint manifest
refresh (blocked), runtime checklist D7–D12, scale gates note, fault ledger DL-2, this handoff.

**Test counts:** draft-learning module **103/103**; Decision integration **40/40** (exact-8230 repro R1–R6,
repaired F1–F10, clean chain P1–P6, negative/hygiene N1–N8, classification K1–K2); harness **483/483**
baseline root AND **483/483** candidate root; Sender body gates **77/77**; item-18 B5/B6 contract **60/60**
(truthful pin `HMZ_EXPECTED_SENDER_VERSION=a2cd9419…`, semantic `9910bfb6…`; default `00b52f03` pin is the
stale pre-item18 version tag); B6 adversarial **31/31**, corrective **8/8**, rehearsal **19/19**; item-18
negative invariants **6/6**; legacy 21/21 evidence stands (sidecar byte-equal `957654e9…`/`87d8b3ae…`;
volume fixture not local; SSH prohibited). Node D syntax/JSON/secret scans PASS. Protected: Sender
`9910bfb6…` ✓, Q `695bd3db…` ✓, HumanApproval `cc6821a9…` ✓, Shadow export unmodified + `active=false`,
Decision baseline untouched. Classification learning byte-unchanged (K1/K2 + 483/483).

**Readiness:** supervised scale/sell ~93%, still BLOCKED on live acceptance. Steps 8/10/11/12 partial → local
portions complete; Step 9 pending. **Next Codex session:** resume `019f60b4-7d5f-7f91-9e9f-3afe7df2962f` with
`reports/NEXT_CODEX_PROMPT_DRAFT_LEARNING_FINAL_ACCEPTANCE.md` (14% weekly allowance discipline; stop before
checkpoint below 5%). Never reuse `case-623134e7` as fresh validation; never use a real prospect.

**Regression Safety Check:** baseline/handoff read first; no production access or mutation; no stale export
deployed; pre-existing dirty worktree preserved (no checkout/clean/restore/stash); only draft-learning files
+ listed docs changed; no secret printed or persisted; Sender/Q/sidecar/HumanApproval/Shadow untouched;
Shadow inactive; Gate 2/autonomous disabled; nothing staged or committed.

---

## 2026-07-14 — Codex Draft-Learning Integrated Acceptance (VALIDATION NO-GO; SAFE ROLLBACK COMPLETE)

**Agent/model:** Codex (GPT-5), bounded production-closure operator. **Branch/HEAD:**
`codex/5q-context-token-forensic-20260705` / `ed94d57`. **Scope:** Decision `tgYmY97CG4Bm8snI`, campaign
`531e64ed-c225-4baf-97a9-4ec90dc34eb0`, explicitly owner-controlled inbox `junaidk7531@gmail.com`. No B5/B6.

**Authorized continuation:** Minimal revalidation required restored Decision semantic `9ab7cefe…`, 33 nodes,
active, 0/0 running/waiting; unchanged reviewed candidate `6077adbc…`; 13/13 backup checksums valid at
`/var/backups/hmz-instantly-responder/draft-learning/20260714T130807Z/`. Protected HumanApproval
`cc6821a9…`, Sender `9910bfb6…`, Sender Q `695bd3db…`, Shadow `4b2ffe90…` inactive, and sidecar image/health
all matched. Gate 2 and autonomous mode remained disabled.

**Production write and integrated smoke:** Exact reviewed Decision candidate redeployed as version
`219a1cfb-5292-418d-8529-40575acc86ec`, semantic `6077adbc…`, active/33 nodes, exact candidate equality;
only Node D differs from restored baseline. Owner sent one authorized benign inbound. Intake `8222`, Decision
`8223`, and HumanApproval `8224` all succeeded. Q12 returned 35 live Data Table rows and repaired Node D ran
once on the deployed version. Existing classification rule `635870a5…` applied pre-draft; this event truthfully
resolved `HUMAN_ONLY / NO_DRAFT_HUMAN_ONLY`, with injection false, persisted compliance false, and
`draft_actually_applied=false`. Exactly one case was created: row 171 / `case-9b5c2366`, NEW, HUMAN_ONLY.
Sender had zero executions since deployment (latest remains historical `8070`); no Instantly POST/email/send,
duplicate case, or duplicate integrated chain occurred.

**Teaching result:** `case-d38b78cc` was used once as **SAFE NO-SEND TEACHING ONLY**; it predates repaired
Decision and remains excluded from repaired-generation/validation evidence. HumanApproval execution `8227`
captured exactly one feedback event `f808eaf8…`, changed the case to `LEARNING_REVISION_APPROVED`, recorded
classification audit `no_change`, and created exactly one active draft rule: row 114 / `182ad47b…`,
`INFORMATION_REQUEST / NON_PRIORITY`, `current_micro_intent_only`, target `micro_intent:NON_PRIORITY`, with
the exact authorized direct-reason instruction. Campaign, sender, and test-inbox context were captured in the
feedback event. No final reply was persisted; non-send terminal path only. Sender remains untouched.

**Fresh validation NO-GO:** Owner sent the authorized unseen wording `Why did you decide to contact me?`.
Intake `8229`, Decision `8230`, HumanApproval create `8231`, and read-only form render `8232` succeeded on
candidate version `219a1cfb…`; case row 172 / `case-623134e7` was created once. New rule `182ad47b…` was
retrieved/eligible, but the existing classification rule changed `OFFER_EXPLANATION` to `NON_PRIORITY`, after
which Node D injected five draft rules, including unrelated timing-objection rules. Raw output invented that
the note suggested timing was not right; `draft_model_complied=false` and
`draft_post_processing_preserved=false`. Post-processing produced `persisted_compliant=true` /
`actually_applied=true`, but its persisted first sentence contained literal unresolved campaign sentinel
`UNKNOWN`. The review form exactly displayed that persisted draft. This is a high-severity conflict/grounding
failure; no second validation or negative event was requested. No approval, Sender execution, Instantly POST,
or outbound email occurred.

**Immediate rollback:** With Decision 0/0 running/waiting and still exactly equal to the candidate, the
checksum-verified rollback payload was applied. Current Decision is version
`cad701a5-a9fa-4c42-8e62-1d63b413f622`, active/33 nodes, exact protected baseline semantic `9ab7cefe…`, Node D
`a4696732…`, 0/0 running/waiting. HumanApproval/Sender/Shadow exactly equal protected backups; Shadow inactive;
Node Q/sidecar unchanged; Gate 2/autonomous disabled. New rule and controlled cases remain preserved; no
historical cleanup or deletion.

**Status/safety:** Step 8 integrated runtime smoke PASS before rollback; Step 9 teaching PASS but unseen
validation FAIL, so Step 9 overall NO-GO. Negative control, final regression, and CRR were not entered. CRR
remains unsigned; no checkpoint, stage, commit, branch, tag, push, Obsidian operation, or commercial traffic.
Detailed evidence: `reports/DRAFT_LEARNING_PRODUCTION_CLOSURE_REPORT.md`. Next engineering session must fix
sentinel rejection and deterministic conflict selection, rebuild from a fresh authenticated baseline, and
obtain a new owner live-event gate. Do not repeat B5/B6.

---

## 2026-07-14 — Codex Draft-Learning Fresh-Baseline Deployment Attempt (NO-GO; SAFE ROLLBACK COMPLETE)

**Agent/model:** Codex (GPT-5), independent review + bounded production closure. **Branch/HEAD:**
`codex/5q-context-token-forensic-20260705` / `ed94d57`. **Scope:** Decision `tgYmY97CG4Bm8snI`, campaign
`531e64ed-c225-4baf-97a9-4ec90dc34eb0`, owner inbox `kinghamzah111@gmail.com`. No B5/B6 repetition.

**Independent review:** authenticated fresh production Decision was version `2a8db02a…`, 33 nodes, semantic
`9ab7cefe…`, Node D `a4696732…`; running/waiting 0/0. The stale local candidate was excluded. Review found
two mandatory evidence defects in the reported local repair: `post_processing_preserved` was absent, and a
checkable-class `draftLearningDelta.changed` could force persisted compliance/application true without the
persisted verifier passing. The module/patch/tests were tightened to eight stages, separate capture/retrieval/
eligibility counts, fail-closed checkable compliance, explicit preservation evidence, and same-sentence
recipient-grounded reason verification. Classification code remained byte-identical.

**Fresh candidate:** nine-anchor patch reapplied cleanly to the authenticated baseline. Only Decision Node D
changed; settings/connections/node count/all other nodes/credentials unchanged. Candidate semantic
`6077adbc60ec7ee8edc4e0be16f190d84d14d12a6053f1f223c0a76d2cb07b02`; Node D `26e58a8d…`;
classification section `8af1425b…` unchanged. Missing/duplicate-anchor fixtures failed closed with no output.
Tests: module **70/70**, fresh Node integration **17/17**, candidate-root behavioural/classification **483/483**,
Node D syntax/JSON/secret scan PASS. The only required rerun was after a temporary harness root initially
omitted the unchanged Sender helper symlink (482/483 environment failure, then 483/483 PASS).

**Backup:** strict SSH identity verified using the already-known key for production IP `31.97.56.217` (the
resolved n8n host). Sidecar `hmz-send-state-business-live` healthy. Checksum-verified 13-artifact backup at
`/var/backups/hmz-instantly-responder/draft-learning/20260714T130807Z/` contains Decision, settings/connections,
HumanApproval, Shadow, classification configuration, 113 learning rows, Sender, protected hashes, candidate,
deployment/rollback payloads, sidecar status, rollback commands, and SHA manifest.

**Production writes and rollback:** first Decision PUT returned HTTP 400 before mutation because `binaryMode`
is read-only in public-API settings. Filtered payload then deployed exactly as version `6d8324f7…`, semantic
`6077adbc…`; HumanApproval `cc6821a9…`, Sender `9910bfb6…`, Q `695bd3db…`, Shadow `4b2ffe90…` inactive,
and sidecar remained unchanged. The API-only credential cannot run an `executeWorkflowTrigger` workflow. A
bounded standalone CLI smoke created execution `8209`, which failed at Q12 because standalone CLI disables
the Data Table module; Node D was not reached. No Sender/HumanApproval execution, Instantly POST, or email
occurred. Because mandatory production runtime smoke remained unproven and the shared Decision launch could
not be bounded to the owner inbox through that route, Decision was immediately rolled back. **Current
production Decision:** version `b0a20e73-05c3-4361-a34c-74473b21fa68`, active, semantic exactly baseline
`9ab7cefe…`, running/waiting 0/0. Failed execution `8209` preserved; no historical cleanup.

**Status:** Step 8 remains partial/NO-GO; Steps 9-13 not entered. No teaching case or learning-row write; no
fresh validation, negative or classification control; no CRR change/signature; no checkpoint, stage, commit,
branch, tag, push, Obsidian read/write, or rollout packet. Detailed evidence:
`reports/DRAFT_LEARNING_PRODUCTION_CLOSURE_REPORT.md`. Next session must obtain an owner-authorized normal
integrated launch path bounded to the owner inbox/campaign, then repeat only Step 8 deploy/smoke from the
reviewed candidate. Do not repeat Step 7 or B5/B6.

**Regression Safety Check:** baseline/handoff read; exact production writes were one successful Decision
candidate PUT and one successful Decision rollback PUT (plus one rejected no-mutation PUT and failed CLI
execution `8209`). No stale export deployed, no broad rewrite/deletion, no real prospect, no send, no secret
exposure. Sender/Q/sidecar/HumanApproval/Shadow unchanged; Shadow inactive; Gate 2/autonomous disabled;
classification learning preserved. Nothing staged or committed.

---

## 2026-07-14 — Claude Opus 4.8 Draft-Learning Compliance Repair (LOCAL PASS; CONDITIONAL GO)

**Agent/model:** Claude Opus 4.8 (independent draft-improvement learning forensic engineer).
**Branch/HEAD:** `codex/5q-context-token-forensic-20260705` / `ed94d57`. **Newest previous handoff:** 2026-07-14
Codex B6 Corrective Retry (LIVE PASS; RESTORED). **Production actions: none** (read-only; production GET 401).

**Root cause (PROVEN):** Decision Node D conflated AI-prompt *injection* with draft *application* —
`learning_applied_to_draft` / `active_learning_rules_applied` were set true whenever guidance was injected
into the AI prompt (`aiDraftUsedGuidance`/`aiPromptInjectionSingleRule`), with **no** verification that the
persisted draft complied and **no** `actually_applied` field. Contributing: no deterministic post-processor
for the reason-for-contact ("why are you emailing me?") class. This is why `case-9d8fdc47`/`f7cb7c56`/
`efc205a5` showed "applied" evidence while the persisted draft never answered the question. Full chain:
`reports/DRAFT_LEARNING_FORENSIC_REPORT.md`.

**Repair (Decision Node D only):** `_5qApplyReasonForContact` (campaign-context-grounded, validation-stage
honest, no invented pricing/proof/results) wired into the post-processor; persisted-draft compliance verifier
`_5qDraftAnswersReasonForContact`; compliance-verified `_5qDraftApplicationEvidence` emitting seven distinct
stages (captured/eligible/retrieved/injected/model_complied/persisted_compliant/actually_applied) with
`actually_applied` gated on the persisted draft. Single source
`infrastructure/draft-learning/decision-draft-compliance.js`; fail-closed anchor patcher
`scripts/DRAFT-LEARNING-apply-compliance-evidence-fix.py` (9 edits); local-proof candidate
`workflows/decision_candidate_draft_learning_compliance_fix.json` (canonical semantic
`972bc71135ff07e1a4b495cb9d085b3b3a8bdabcb8481e2728cee1d2b92dd0c4`). Production exports NOT modified.

**Changed files (this session):** NEW — `infrastructure/draft-learning/decision-draft-compliance.js`,
`scripts/DRAFT-LEARNING-apply-compliance-evidence-fix.py`,
`workflows/decision_candidate_draft_learning_compliance_fix.json`,
`tests/draft-learning/run-draft-learning-proof.mjs`, `tests/draft-learning/run-decision-node-integration.mjs`,
`reports/DRAFT_LEARNING_FORENSIC_REPORT.md`, `reports/DRAFT_LEARNING_LOCAL_REPAIR_AND_PROOF.md`,
`reports/FINAL_CHECKPOINT_AND_FREEZE_MANIFEST.md`,
`docs/DRAFT_LEARNING_PRODUCTION_DEPLOYMENT_AND_ACCEPTANCE_RUNBOOK.md`. UPDATED (additive) —
this file, `docs/RUNTIME_PROOF_CHECKLIST.md`, `docs/SCALE_READY_ACCEPTANCE_GATES.md`,
`docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`, `docs/campaign-readiness/CRR-531e64ed.md`.

**Test counts:** draft-learning module 64/64; node integration 16/16; behavioural harness 483/483 (unchanged);
B6 adversarial 31/31, corrective 8/8, rehearsal 19/19; item18 negative-invariants 6/6; sender contract 60/60
(own version pin; the 59/60 with the hardcoded `00b52f03` baseline tag is pre-existing Sender-dirty state, not
this change); JSON validity 31/31; Node D `node --check` OK; secret scan clean.

**Local regression status:** GREEN for everything the Decision-only change can affect. Sender semantic
`9910bfb6…`, Q `695bd3db…`, HumanApproval `cc6821a9…` **unchanged**; production Decision export untouched;
Shadow inactive; Gate 2/autonomous unchanged.

**Readiness:** supervised operation 100%; supervised scale/sell 95% blocked; classification learning 98%;
draft-improvement learning **90% (local); production-unproven** (was 70%); autonomous out of scope.

**CONDITIONAL GO FOR CODEX PRODUCTION DRAFT-LEARNING ACCEPTANCE.** Two blockers gate a full GO: (1) **Decision
baseline drift** — the local export (`4c9e806a`/`84b941a4`) does not match production Decision
(`9ab7cefe`/`2a8db02a`); production 401 this session prevented refresh, so the patch must be re-applied and
re-proven against a freshly-exported authenticated production Decision before deploy; (2) **live acceptance** —
truthful `actually_applied` must be proven on an owner teaching→fresh-case cycle in production.

**Exact next agent:** Codex — execute `docs/DRAFT_LEARNING_PRODUCTION_DEPLOYMENT_AND_ACCEPTANCE_RUNBOOK.md`
(mandatory precondition first: refresh + re-patch the authenticated production Decision). Do not repeat B5/B6.
Do not sign the CRR. Do not `git add .`.

**Regression Safety Check:** latest baseline/handoff read (B6 2026-07-14); reviewed exact current Node D +
HumanApproval Node J source; compared local exports to newest handoff (found + recorded the Decision drift);
no broad rewrites/deletions (9 anchored Node-D edits in a candidate only); no stale export overwrite (production
exports untouched); production not modified; no send; Sender/Node Q/sidecar unchanged; B5/B6 not repeated;
classification learning preserved (483/483); Decision/HumanApproval/Shadow protected (production exports
untouched, Shadow inactive); Gate 2/autonomous unchanged; no secret written to any repo file; no stage, commit,
tag, branch or push.

---

## 2026-07-14 — Codex B6 Corrective Retry (LIVE PASS; RESTORED)

**Verdict:** B6 is **LIVE-PROVEN** for the one owner-authorised replacement case
`case-6563db8b`, campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, prospect recipient
`junaidk7531@gmail.com`. The superseded link `case-9d5ee570` remained unapproved/expired and was not
reused. Owner approved exactly once only after the permit, identity, timing and authenticated-read gates
passed. HumanApproval execution `8069` and Sender execution `8070` each ran once.

**Corrections:** the B6 permit now defaults to 600 seconds, reports expiry/remaining time, refuses the
owner-action instruction below 300 seconds, permits disarm/re-arm only before any reservation/attempt,
and fails closed across expiry/restart. Reservation, upstream-attempt start and upstream response are
durably distinct. A zero-attempt failure is `PRE_FORWARD_REJECTED`, is never valid SEND_UNCERTAIN
evidence, and cannot start reconciliation. Reconciliation 401 root cause was Sender node V omitting the
same `genericCredentialType`/`httpHeaderAuth` selectors used by working node Q; the stored credential is
an n8n `=Bearer …` expression and the earlier raw 401 probes had sent the unevaluated expression. A
secret-free in-memory evaluated read returned HTTP 200 before deployment; the temporary V correction was
limited to those two selectors.

**Live proof:** permit `53c7ebef7c6f858e` was armed at `2026-07-14T01:47:51.018Z`, expired at
`01:57:51.015Z`, max-use one, `destroy-downstream`. Exact send key
`3a1fd665e3624b347a5d536579407e5a6b04fc3eca0442c0053439e3f4448d25`; payload SHA-256
`5de3891f1d2f7e402a6812cda245e70b97befe25db87c9fef743d116f98aa153`. The proxy atomically reserved
once, started exactly one upstream Instantly POST, observed HTTP 200 at `01:49:11.271Z`, journalled it,
then destroyed the downstream response. Sender persisted `SEND_UNCERTAIN`; no retry or second Q ran.
Two authenticated read-only polls each found exactly one matching email id
`019f5e50-4af8-72e7-9f6b-f946552408f3`; consecutive count 1 then 2 transitioned the durable record to
terminal `SENT_RECONCILED`. Exact-identity replay returned 409 `DURABLE_STATE_EXISTS`; total upstream
POST count remained one and duplicate count remained zero.

**Restoration/equality:** proxy disarmed, sanitised journal archived, and temporary container/image/
volume/source removed. Sender is active at restoration version `ebebd966-f67e-4847-8ca3-ea11b8aebed5`,
45 nodes, direct Instantly Q URL, semantic SHA-256
`9910bfb644f1b67ec18d2d16f1fa52290ca2d9d1168e69f1ab80a921f7d0ad04`, Q SHA-256
`695bd3db0c193649b0280b74a35818c5f9deeaa0a5b27e103289cab2328df651`. Decision/HumanApproval/
Shadow remain `9ab7cefe…` / `cc6821a9…` / `4b2ffe90…`; Shadow inactive. Sidecar image/modules remain
`eb59e30c…` / `957654e9…` / `87d8b3ae…`, healthy; current unfinished 0, n8n running/waiting 0/0.

**Evidence/tests:** backup root
`/var/backups/hmz-instantly-responder/b6-proxy-retry/20260714T012857Z/`; all 14 artifacts verify and
`SHA256SUMS` hashes to `f127d14d11f69a734836478fc355ab131ecd9805e91b91353efcd47c39bba9ca`.
Corrected adversarial 31/31, corrective 8/8, integrated rehearsal 19/19, focused item-18 60/60,
syntax/JSON/secret scan PASS. The 483/483 and 77/77 suites were not rerun because shared Sender and
sidecar business logic did not change. Step 6/B6 is complete. The CRR remains unsigned and the separate
draft-learning acceptance remains open. Optional Phase 10 was not entered because the required 45%
remaining-context gate could not be established after the live production closure. No Shadow, Gate 2,
autonomous, learning, historical cleanup, stage, commit or push occurred.

---

## 2026-07-14 — Codex B6 Corrective Engineering (LOCAL PASS; PAUSED BEFORE DEPLOYMENT)

**Authorization/scope:** owner authorised one surgical controlled retry for `case-9d5ee570`, campaign
`531e64ed-c225-4baf-97a9-4ec90dc34eb0`, owned recipient `kinghamzah111@gmail.com`. The case remains
open and unapproved. No approval, Sender execution, Instantly POST, deployment, activation, workflow
write, SSH mutation, backup, commit, or push occurred in this session segment.

**Baseline:** branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57`; newest prior handoff was
the 2026-07-13 safe-failed B6 attempt. The broad pre-existing dirty/CRLF worktree was preserved. Sender
source remains semantic `9910bfb644f1b67ec18d2d16f1fa52290ca2d9d1168e69f1ab80a921f7d0ad04`,
node Q `695bd3db0c193649b0280b74a35818c5f9deeaa0a5b27e103289cab2328df651`; sidecar remains
`957654e988320725514d43ef09a3d0aa033c8c36f8e159943be270393f874550` / `87d8b3aeb521474097aafedc0ab0fa483fa869c97736a9670a0c4059221c68e5`.

**Three corrective controls:** permit default is now 600 seconds with explicit expiry/remaining time and
a hard owner-instruction refusal below 300 seconds; unattempted permits may be safely replaced, but any
reservation/upstream-attempt/result permanently forbids re-arm; production-process restart invalidates
an unconsumed armed permit. The proxy now journals reservation separately from upstream-attempt start and
labels zero-attempt failures `PRE_FORWARD_REJECTED`, with reconciliation forbidden and immediate
disarm/fail/restore action. Only exactly one journalled upstream attempt with an observed 2xx response and
downstream loss is reconciliation-eligible. Replays after a reservation cannot be mislabeled zero-attempt.

**Reconciliation root cause/candidate:** the current Sender source's node V has the same
`hmzInstantlyApi` credential reference as working node Q but omits node Q's required
`authentication=genericCredentialType` and `genericAuthType=httpHeaderAuth`. The temporary B6 workflow
builder adds exactly those two V fields plus the reviewed temporary Q URL; it does not modify the protected
Sender source. Official Instantly V2 documentation independently confirms `GET /api/v2/emails` requires a
Bearer Authorization header. A live authenticated read remains mandatory before any send.

**Local proof:** corrected adversarial **31/31**, corrective controls **8/8**, integrated rehearsal
**19/19** (`upstreamPostsTotal=1`), focused item-18 **60/60**, syntax checks PASS, JSON/config **3/3**,
targeted secret scan clean except the existing explicitly synthetic `Bearer SECRET-KEY-do-not-log` test
fixture; zero external test calls. Corrected proxy hashes: `permit-store.mjs` `a8013b26…`, `proxy.mjs`
`c80eda03…`, `b6-control.mjs` `6bf6d59a…`.

**Production revalidation update:** the replacement Windows user-level `HMZ_N8N_API_KEY` is current and
authenticated Sender GETs now succeed. Live Sender remains active at version `ace01a15…`, 45 nodes,
semantic `9910bfb6…`, Q `695bd3db…`; Q has the working `hmzInstantlyApi` header-auth configuration while
V has the same credential reference but still omits both auth-selector fields, conclusively proving the
prior reconciliation 401 root cause. Decision/HumanApproval/Shadow hashes remain `9ab7cefe…` /
`cc6821a9…` / `4b2ffe90…`, Shadow is inactive, the sidecar is healthy, SSH identity/host and disk capacity
passed, and the exact review row remains `NEW` and unapproved.

**Owner scope update / current verdict:** the owner subsequently confirmed that `junaidk7531@gmail.com` is
a prospect in the exact allowlisted campaign and explicitly authorised continuing B6 with that recipient;
this supersedes only the earlier owner-inbox restriction for this one case. Reconciliation authentication
is now independently proven: the stored credential is an n8n `=Bearer …` expression, and a secret-free
in-memory evaluation of `GET /api/v2/emails` returned HTTP 200 with the expected `items` shape. The initial
raw 401 probes sent the unevaluated expression literally and made no write/send; Intake execution `8040`
independently recorded HTTP 200 for the exact governed email read. Running/waiting and sidecar unfinished
are 0/0; Sender is the sole reply-POST egress; protected hashes and sidecar hashes/image match. Verified
backup root `/var/backups/hmz-instantly-responder/b6-proxy-retry/20260714T012857Z/` contains Sender, Q, V,
Decision, HumanApproval, Shadow, proxy/routing source, sanitized topology, rollback plan and baseline summary;
all ten artifacts pass `SHA256SUMS`.

**CONDITIONAL PASS; DO NOT DEPLOY OR APPROVE YET.** The exact review row remains `NEW`, unapproved,
`draft_status=NO_DRAFT_HUMAN_ONLY`, `reply_mode=HUMAN_ONLY`, with a zero-length draft. Exact B6 binding
requires the final non-empty body to compute the send identity and canonical payload digest before route
change/arming. Owner action: provide the exact intended reply text while keeping the form unapproved. No
workflow write, route change, proxy deployment, permit, approval, Sender execution or upstream POST has
occurred.

---

## 2026-07-13 — Codex Independent B6 Proxy Review + Controlled Attempt (SAFE FAIL; RESTORED)

**Baseline:** branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57`; newest prior handoff
was the Claude Code local-only B6 proxy package. Owner authorised one exact drill for
`case-2d555dab`, campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, owned recipient
`kinghamzah111@gmail.com`.

**Independent review:** **CONDITIONAL PASS FOR TEMPORARY DEPLOYMENT.** Reproduced proxy rehearsal
**18/18**, adversarial **25/25**, focused item-18 **60/60**, JavaScript **7/7**, secret scan clean,
zero external test calls. Selected `destroy-downstream` because B6 requires genuine response loss.
Mandatory live binding included send key, sender, thread, subject, recipient and canonical payload
digest; case/campaign were separately verified. Proxy source hashes: `permit-store.mjs`
`f74a9287e8e44b5a791ed6d37b2272e2c463720c1efdef8490750aa8fbf9e8f9`, `proxy.mjs`
`2b68557e28c6c5b191476e53d1a582c141d5078bb08e4798523222d0c19e8cd0`, Dockerfile
`7a0623afd3b78a9594614fc5d51e0575b49c784815af1eddc5b0544380daccbe`.

**Backup/deployment:** verified backup root
`/var/backups/hmz-instantly-responder/b6-proxy/20260713T145802Z/`. Sender was drained; temporary
proxy image `sha256:91f03e12ae6122e3947726b6f63d2275bad11a5ee36713f08b631397bf578a86`
ran disarmed on the governed network. Only node-Q `parameters.url` changed: temporary Sender
version `59be0de7-5224-4dfc-a7ca-d2718d37241e`, semantic `07e39b93…`, Q `32120d53…`.
Permit `08352f269e40761d` was armed at `15:02:54Z`, expiry `15:17:54.439Z`, attempt count zero.

**Live result — SAFE FAIL / B6 NOT LIVE-PROVEN:** owner approved exactly once. HumanApproval `7913`
approved at `2026-07-13T15:20:13.599Z`; Sender `7914` reached Q once. The permit had expired before
the request (`REQUEST_REJECTED/PERMIT_EXPIRED` at `15:20:14.484Z`), so proxy upstream Instantly POST
count was **0**, no response-loss fault occurred and no email was sent. Q returned 409; Sender safely
performed no retry/second Q, persisted `SEND_UNCERTAIN`, then two reconciliation GETs returned 401 and
the exact controlled state terminated `HUMAN_REVIEW_ZERO_MATCHES`. This is not B6 acceptance.

**Restoration/final state:** proxy disarmed, journal archived, container/image/volume/source directory
removed, proxy DNS route absent. Original Q route restored exactly; Sender active at restoration
version `ace01a15-18bf-46ae-9e2f-c76ff467f46c`, 45 nodes, semantic `9910bfb6…`, Q `695bd3db…`.
Decision `9ab7cefe…`, HumanApproval `cc6821a9…`, Shadow inactive `4b2ffe90…`, sidecar hashes
`957654e9…`/`87d8b3ae…`; running/waiting and unfinished/SUBMITTING all zero. All 51 pre-attempt state
files remain, one new controlled terminal record exists, 49 locks and 35 errors are unchanged.

**Next:** do not reuse/reapprove this consumed case. Independently review two blockers before a new
case/drill: arm immediately before the human pause with an expiry window that remains valid through
approval, and diagnose why reconciliation `GET /api/v2/emails` returned 401. Do not repeat B5 or item-18
deployment. Draft-improvement learning and unsigned CRR remain separate blockers. No stage/commit/push.

---

## 2026-07-13 — Claude Code B6 Lost-Response Proxy Package (LOCAL-ONLY; GO FOR CODEX REVIEW)

**Agent/model:** Claude Code (Opus 4.8, `claude-opus-4-8`), independent implementation engineer.
**Objective:** build the smallest safe, review-ready, production-integrable exact-request forward-once
lost-response proxy needed to later run one owner-controlled B6 drill. **Local-only.** No production, SSH,
n8n API, Instantly credential, deploy, send, active-workflow change, stage, commit, or push.

**Baseline:** branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57`.
**Newest previous handoff:** 2026-07-13 Codex Item-18 Paired Deployment + B5 Live Closure (B6 BLOCKED).

**Architecture:** standalone one-shot proxy (`infrastructure/b6-lost-response-proxy/`) + a temporary,
narrowly-scoped node-Q `url` routing patch (proxy on the Docker network; https client to Instantly). Node Q
is the sole reply-POST egress, so repointing its URL removes any direct path by construction. Disarmed by
default; one permit; atomic `open('wx')` forward reservation *before* the single upstream POST; observe
upstream response, then destroy the downstream response; permit permanently consumed; crash/restart
fail-closed (no second POST). Permit binds sendKey (marker) + eaccount + thread (mandatory) and optional
subject/recipient/payload-digest; campaign is audit-only (not in the reply body — enforced out-of-band).

**Changed files (all additive except this handoff):**
`infrastructure/b6-lost-response-proxy/{permit-store.mjs, proxy.mjs, Dockerfile, README.md}`,
`scripts/B6-proxy-{arm,disarm,status,local-rehearsal}.mjs`, `tests/b6-proxy/proxy-adversarial.test.mjs`,
`reports/B6_PROXY_DESIGN_AND_LOCAL_PROOF.md`, `docs/B6_PROXY_DEPLOYMENT_AND_LIVE_DRILL_RUNBOOK.md`,
`docs/patches/B6_NODE_Q_ROUTING_PATCH.md`, and this `OPERATION_HANDOFF.md` entry.

**Test counts:** local rehearsal **18/18** (`upstreamPostsTotal=1`); adversarial **25/25**; item-18 B6
harness **60/60** (B6 17/17, semantic `9910bfb6…`, Q `695bd3db…`, external calls 0); `node --check` 7/7;
secret scan clean (only synthetic `Bearer …-do-not-log` fixtures). Rehearsal bridge: destroyed-socket loss
→ real node R `SEND_UNCERTAIN` (control kept-200 → `SENT`); real sidecar `SUBMITTING → SEND_UNCERTAIN →`
two matching polls `→ SENT_RECONCILED`; later acquire blocked.

**Skipped broad suites + justification:** 483 behavioural, 77 body gates, 21 legacy rehearsal **not** rerun
— no shared Sender/sidecar/contract code changed (sidecar `957654e9…`/`87d8b3ae…`, Sender semantic
`9910bfb6…`, node Q `695bd3db…` all byte-identical to the deployed baseline). Latest passing evidence:
2026-07-13 post-deploy record in `reports/ITEM18_DEPLOYMENT_AND_LIVE_EVIDENCE.md` (483/483, 77/77, 21/21).

**Production actions:** none. **Verdict:** GO FOR CODEX INDEPENDENT REVIEW OF B6 PROXY PACKAGE.
**Remaining blockers:** owner-approved supervised B6 drill per the runbook (deploy proxy, apply node-Q patch,
one permitted request, observe SEND_UNCERTAIN→SENT_RECONCILED, disarm, restore); then draft-improvement
learning clean test and the unsigned CRR before scale/sell.

**Readiness:** B6 proxy local design/proof 100%; B6 live-proven 0% (drill pending); item-18 deployed 100%;
B5 live 100%; normal supervised 95%; supervised scale/sell 92% **BLOCKED** (B6 drill, draft-improvement
learning, CRR); classification learning 98%; draft-improvement learning 70%; autonomous 17%.

**Next agent/session:** Codex independent review of this package, then a separately owner-approved
production maintenance + B6 drill session. Do not repeat item-18 deployment or B5.

**Regression Safety Check:** latest baseline `ed94d57`; newest handoff 2026-07-13 Codex Item-18. Current
files compared with latest versions — sidecar/Sender/node-Q byte-identical to deployed baseline; no broad
rewrites or deletions; no risk of reverting current state (no checkout/restore/clean/stash/stage/commit/
push); no stale export overwrote current work (additive files only); production not accessed; current
Sender, node Q, and sidecar unchanged; Decision, HumanApproval, Shadow, and learning untouched; no send,
deployment, Shadow, Gate 2, or autonomous change.

---

## 2026-07-13 — Codex Item-18 Paired Deployment + B5 Live Closure (B5 PASS; B6 BLOCKED BEFORE SEND)

**Baseline:** `codex/5q-context-token-forensic-20260705` / `ed94d57`. Owner authorised the paired
production deployment and controlled B5/B6 programme. Exact SSH identity fingerprint
`SHA256:FhBEVuiRN2oSV+XrhTp9kUwYs2JFVzeB2aYN+f9X79M` was verified with strict
`IdentitiesOnly=yes`; target `root@srv1763256`.

**Deployment:** complete. Backup root
`/var/backups/hmz-instantly-responder/item18/20260713T003742Z/` has verified workflow/source/image/
volume archives and checksums. Sidecar candidate hashes `957654e9…` / `87d8b3ae…`, image
`sha256:eb59e30…`, healthy. Sender `ePS5uBBxKxhFCYgU` is active at version
`a2cd9419-f9b2-40b2-a3aa-a5a4f55b779c`, 45 nodes, semantic `9910bfb6…`, Q `695bd3db…`.
Post-deploy proof: 60/60 + 6/6 + 21/21 + 483/483 + 77/77, syntax/JSON/secret scans PASS.

**B5 LIVE-PROVEN:** owner case `case-eda8ba50`, authorised owned recipient
`kinghamzah111@gmail.com`, HumanApproval exec `7741`, Sender exec `7742`. One Q and one Instantly
reply POST returned 200; durable `SUBMITTING -> SENT`. Exact-key evidence ref `b31e6c3e1935cbe5`.
Direct replay through the reviewed production `/v1/send/acquire` barrier returned 409
`DURABLE_STATE_EXISTS`, prior terminal `SENT`; replay Sender/Q/POST/email deltas were zero and the
original state-file SHA/timestamps were unchanged. The earlier recipient stop was an authorization-
record mismatch caused by the Ops Console single-inbox limitation, not Sender misrouting.

**B6 BLOCKED / NOT ATTEMPTED:** no production-integrated exact-request forward-once proxy exists.
Production Compose has only `hmz-send-state,n8n`; the historical V5 localhost runner is a separate
sender and cannot substitute for the packet-required scoped route. No B6 case, proxy arm, approval,
or POST occurred.

**Final safety:** Decision `9ab7cefe…`, HumanApproval `cc6821a9…`, Shadow inactive `4b2ffe90…`;
Sender running/waiting 0/0; sidecar healthy. All 50 pre-existing state files, 49 locks, and 35 errors
are byte-identical to the stopped-volume backup. Current extra record is the controlled B5 `SENT`.
Shadow/Gate 2/autonomous unchanged; learning untouched. Detailed evidence:
`reports/ITEM18_DEPLOYMENT_AND_LIVE_EVIDENCE.md`. No stage, commit, or push.

**Readiness:** item-18 deployed implementation 100%; B5 live 100%; B6 live 0%; normal supervised
95%; supervised scale/sell 92% **BLOCKED** by B6, draft-improvement learning, and unsigned CRR;
classification learning 98%; draft-improvement learning 70%; autonomous 17%.

**Next agent/tool:** one narrow independent design/review session to create a production-integrated,
exact-request B6 proxy with forward-once permit, observable counter, blocked direct egress and
immediate disablement. Do not repeat deployment or B5.

---

## 2026-07-12 22:40 BST — Claude Code Item-18 Legacy-Lock Deployment-Compatibility Review (GO — PRESERVE LEGACY LOCKS; NOT DEPLOYED)

**Agent/tool and model:** Claude Code (Opus 4.8, `claude-opus-4-8`), independent deployment-compatibility reviewer. Read-only production inspection (VPS SSH read-only + attempted n8n GETs), local isolated exact-volume-copy rehearsal, deployment-policy review. **No production mutation, deployment, send, Instantly POST, DataTable write, stale-lock change, Gate 2, autonomous change, stage, commit, or push.**

**Objective:** determine whether the 49 historical LOCKED records genuinely require disposition before the reviewed item-18 sidecar + 45-node Sender candidate can be safely deployed as a pair while preserving all 49 locks, 35 errors, and the volume unchanged.

**Latest baseline:** branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57`. **Newest pre-existing handoff:** 2026-07-12 21:50 BST (Codex stale-lock forensic package), which handed off to this reviewer.

**Production snapshot (read-only):** n8n API **BLOCKED** — `HMZ_N8N_API_KEY` present but rotated (HTTP 401), so live workflow metadata was not re-authenticated this session; prior read-only baselines (same HEAD, no change since) relied upon; deploy-time re-auth mandatory. VPS SSH read-only available. Live volume inventory: 50 state (49 LOCKED + 1 DRY_RUN_OK), 49 locks, 0 `.tmp`, 35 unresolved errors, 6,786 files/122,822,145 B; +11 files vs the forensic snapshot, entirely `alerts/`+`phase4b-results/` — **stale-lock set unchanged, no drift**.

**Zero-lock policy review:** the zero-LOCKED requirement is documentation-only (deployment-packet prerequisite + stop condition + forensic recommendation); **not enforced by any code path**. Candidate sidecar has no startup migration/scan/TTL; `acquireSend` reads durable state before locking and blocks any prior record by exact key (`DURABLE_STATE_EXISTS`); non-terminal LOCKED keeps its lock and can never reach SUBMITTING via acquire; per-key SHA isolation lets unrelated new keys acquire; `/v1/unfinished` is read-only. Preserving the 49 LOCKED is **safe** and **not** a prerequisite.

**Volume-copy method:** read-only SSH `tar -czf -` of the full volume → `/tmp/hmz-item18-legacy-volume-rehearsal/<UTC>/{immutable-original,working-copy,evidence}` (outside repo, sanitized, uncommitted). Archive `870fd791…`, 6,790 entries. **Fidelity: 134/134 compatibility-critical files (50 state + 49 lock + 35 error) byte-identical production↔local.**

**Copied-volume counts:** 6,786 files; 49 LOCKED + 1 DRY_RUN_OK + 49 locks + 35 unresolved errors; every LOCKED key maps to a manifest category B/D/F record.

**Candidate startup result:** unmodified candidate sidecar (`state-store 957654e9…`, `server 87d8b3ae…`) on `127.0.0.1` against the working copy — health ok; all 50 records readable; startup + restart deterministic and mutate nothing (6,786 unchanged). **Legacy-volume rehearsal 21/21 PASS**, 0 external calls.

**Legacy-key blocking result:** existing LOCKED blocks re-acquire (`DURABLE_STATE_EXISTS`, priorState LOCKED, priorTerminal false), record+lock byte-identical; terminal SENT blocks (priorTerminal true); no blocked acquire overwrites/removes/retryables anything.

**New-key isolation result:** synthetic unique key acquired (200, LOCKED); only +1 added; all 49 historical records byte-identical.

**Watchdog/operator result:** `/v1/unfinished` truthfully reports 49 LOCKED + 35 errors; identical `listUnfinishedSends` already runs in production, so deployment creates **no new alert surface** (dedup via `recordAlertOnce`); visibility unchanged-to-improved. Watchdog/Error Handler not modified.

**Rollback result:** deliberate mutation → restore from immutable snapshot returned exact 6,786 files + 134-file byte-identity, deterministic ×2; immutable original unchanged.

**Exact test counts:** item-18 FINAL-CLOSURE **60/60**; negative invariants **6/6**; behavioural closure **483/483**; body gates **77/77**; legacy-volume rehearsal **21/21**; rollback **PASS ×2**; secret scan **clean**; `node --check` 5/5; JSON parse 2/2; Q `695bd3db…`; candidate file `be7a9964…`; semantic `9910bfb6…` (45 nodes); Decision/HumanApproval/Shadow git-clean vs HEAD (HumanApproval export semantic-matches prod baseline; Decision export is versionId `84b941a4` vs prod `2a8db02a` — pre-existing staleness, not changed here).

**Deployment verdict:** **A — GO FOR OWNER-APPROVED PAIRED DEPLOYMENT WHILE PRESERVING LEGACY LOCKS.** The zero-LOCKED prerequisite is lifted and replaced by the evidence-backed condition (preserve 49 locks + 1 DRY_RUN_OK + 35 errors; no new/recent LOCKED/SUBMITTING; post-deploy count/hash reconciliation). Cleanup of the 15 category-B records remains a separate non-blocking task. Remaining (non-stale-lock) conditions unchanged: owner approval, deploy-time live-API re-auth, post-deploy semantic/Q equality + reruns, B5/B6 not-live-proven.

**Files changed:** `reports/ITEM18_LEGACY_LOCK_DEPLOYMENT_COMPATIBILITY_REVIEW.md` (new); `scripts/ITEM18-legacy-volume-rehearsal.mjs` (new); `docs/ITEM18_SENDER_SIDECAR_DEPLOYMENT_ROLLBACK_PACKET.md` (prerequisite/preflight/stop-conditions updated); this handoff. No production, sidecar/Sender candidate, Decision/HumanApproval/Shadow, learning, manifest classification, or apply tooling changed.

**Production actions:** read-only only (SSH volume inventory + full tar stream; n8n GETs 401). **Remaining blockers:** live-API re-auth (fresh key), B5/B6 live proof, owner-approved paired-deploy window, unsigned CRR.

**Readiness:** legacy-lock deployment compatibility **100%**; stale-lock disposition required for deployment **0%** (lifted); local candidate implementation **98%** / production-integrated **0%**; B5/B6 live-proven **0%**; normal supervised **90%**; supervised scale/sell **88% BLOCKED**; classification learning **98%**; draft-improvement learning **70%**; autonomous **17%**.

**Recommended next agent/tool:** Codex or Claude Code in a separately owner-approved paired sidecar-first deployment maintenance session with a fresh `HMZ_N8N_API_KEY` and host access; honor the packet §17 legacy-lock condition; then hand back for bounded B5/B6 drills. Do not touch Decision, HumanApproval, Shadow, learning, Gate 2, or autonomous mode.

**Regression Safety Check:** baseline `ed94d57`; newest pre-existing handoff 2026-07-12 21:50 BST. Compared candidate + rollback Sender, candidate sidecar store/server, deployment packet, forensic report, stale-lock manifest, sanitized fixture, independent safety review, item-18/negative harnesses, local Decision/HumanApproval/Shadow exports, and a byte-exact production volume copy. Production accessed read-only only; no write/service/workflow/state mutation. No broad rewrite/deletion; no checkout/pull/clean/restore/stash/stage/commit/push. Immutable local snapshot unchanged (`870fd791…`). Sidecar/Sender candidates unmodified; Decision/HumanApproval/Shadow/learning untouched. No deployment, send, Instantly POST, DataTable write, Gate 2, or autonomous change.

---

## 2026-07-12 21:50 BST — Codex Item-18 Stale-Lock Forensic/Disposition Review Package (GO FOR INDEPENDENT REVIEW — NO PRODUCTION CHANGE)

**Agent/tool and model:** Codex (GPT-5), forensic safety engineer; authenticated n8n GETs, read-only SSH, local deterministic tooling/tests. **Objective:** refresh production, classify all 49 stale LOCKED records, prove persistence causes, build a sanitized review-only manifest/planner, correct the Hostinger packet, and issue a disposition-review verdict. No cleanup, deploy, send, POST, service/workflow/state mutation, stage, commit, or push.

**Latest baseline:** branch codex/5q-context-token-forensic-20260705, HEAD ed94d57. **Latest pre-existing handoff:** 2026-07-12 16:40 BST — Claude Code Independent Safety Review of Item-18 Sender/sidecar Repair (CONDITIONAL GO — NOT DEPLOYED). Its candidate implementation/review files and the broad CRLF dirty tree were preserved.

**Production snapshots:** workflows 2026-07-12T20:32:20.791Z; state/lock evidence 2026-07-12T20:41:12Z; no-drift checks 2026-07-12T20:47:17.862Z / 20:47:29Z. Decision 33 nodes, active, 2a8db02a…, semantic 9ab7cefe…; HumanApproval 55, active, 99b4c092…, semantic cc6821a9…; Sender remains the 38-node active rollback 00b52f03…, semantic 5d84b40b…, Q 695bd3db…; Shadow 5, inactive, ae13bf4e…, semantic 4b2ffe90…. One active Sender; running/waiting 0/0.

**Verified topology:** srv1763256.hstgr.cloud / 31.97.56.217, Ubuntu 24.04; Compose project hmz-instantly-responder; workdir /root/Instantly_Responder_Automation/infrastructure/business-live; docker-compose.hostinger-traefik.yml SHA c33205ca…; service/container hmz-send-state / hmz-send-state-business-live; image hmz-instantly-responder-hmz-send-state:latest, image ID sha256:c30ffa8a…; build context ../send-state; no host port; healthy; unless-stopped; volume hmz_send_state_business_live_data at /data and /var/lib/docker/volumes/hmz_send_state_business_live_data/_data. Host tree is not Git; running state-store/server hashes 02c97677… / 4ae6f02a… match clean ed94d57.

**Inventory/classification:** 49 LOCKED + 49 locks; one DRY_RUN_OK; 35 unresolved errors; zero malformed state/error records; zero correlated error records. Categories: A 0, B 15, C 0, D 1, E 0, F 33, G 0. Conclusive 15; ambiguous 34; malformed/unknown 0; potentially post-submission 16. Age was never used. High-risk SL-026 / execution 4834 is D: Q reached, serverReceived true, no response identifier, nonterminal reconciliation, canceled after seven days. D/F remain non-eligible.

**Root causes:** the 38-node X transition sent state:SENT instead of required toState; all 15 retained confirmed sends received X HTTP 409, but continueRegularOutput allowed X2 to report SENT while state stayed LOCKED. The historical Sender lacked P3 SUBMITTING, U4 SEND_UNCERTAIN, and U2F failure persistence. Old reconciliation did not persist history and one execution was canceled. The sidecar correctly retains nonterminal LOCKED files and has no age TTL. Thirty-three outcomes are outside n8n retention; the 35 HumanApproval/SLA errors are unrelated. This is code defect + expected retention + operational cleanup/evidence-retention gap, not proof that old locks are safe to delete.

**Files added/updated:** reports/ITEM18_STALE_LOCK_FORENSIC_REPORT.md; reports/item18-stale-lock-disposition-manifest.json; scripts/ITEM18-stale-lock-forensic.mjs; scripts/ITEM18-stale-lock-disposition-plan.mjs; tests/fixtures/item18-stale-lock/sanitized-snapshot.json; docs/ITEM18_SENDER_SIDECAR_DEPLOYMENT_ROLLBACK_PACKET.md; this handoff. No workflow, sidecar, Decision, HumanApproval, Shadow, or learning file changed.

**Tests:** new fixture suite 23/23 PASS; node --check new scripts 2/2 PASS; item-18 harness 60/60 PASS (zero external calls); independent negative invariants 6/6 PASS; main behavioural closure 483/483 PASS; Sender body gates 77/77 PASS; workflow secret scan PASS. The planner is dry-run only, has no apply/network/SSH mode, refuses traversal and production paths, preserves inputs/errors, produces deterministic simulations/checksums, and refuses D/F/G.

**Disposition verdict:** **GO FOR INDEPENDENT REVIEW OF DISPOSITION PACKAGE; NO-GO for production cleanup or deployment.** Only 15 B records are review-eligible for a future archive-and-terminal-reconstruction design. The D record and 33 F records remain untouched. Evidence limits: historical versionId unavailable; only 16 locked keys retain execution detail; no direct Instantly outcome evidence for D/F; state records contain no execution/case/history.

**Production actions:** none. Read-only access only. **Remaining owner actions:** commission an independent local review of every B row, tool fail-closed behavior, archive/reconstruction mechanics, counts and rollback; then separately approve a maintenance operation if review passes. Cleanup, paired deployment, B5/B6 drills, and reactivation approvals must remain separate.

**Readiness:** forensic inventory 100%; conclusively dispositionable 31% (15/49, not an authorization); disposition package 95% pending independent review; production cleanup 0%; local item-18 candidate implementation 98% / production-integrated 0%; B5/B6 live-proven 0%; normal supervised 90%; supervised scale/sell 80% BLOCKED; classification learning 98%; draft-improvement learning 70%; autonomous 17%.

**Exact next agent/tool:** Claude Code Opus 4.8 as an independent local-only safety reviewer of the manifest, both scripts, fixture suite, forensic report, and corrected packet. No production mutation or deployment.

**Regression Safety Check:** baseline ed94d57; newest pre-existing handoff 2026-07-12 16:40 BST. Compared current/rollback Sender, production workflow metadata/hashes, clean running sidecar source, state/idempotency code/docs, item-18 harness/review tests, real topology, 49 sanitized state/lock rows, and 19 retained Sender executions. Production records were read-only and never copied raw into Git. No broad rewrite/deletion, checkout, pull, clean, restore, stash, stage, commit, or push; no stale export overwrote current work. Decision/HumanApproval/Sender/Shadow/learning code remained untouched. No state/lock/error/service/workflow modification; no deployment, email, Instantly POST, DataTable write, Gate 2, Shadow, or autonomous change.

---


## 2026-07-12 16:40 BST — Claude Code Independent Safety Review of Item-18 Sender/sidecar Repair (CONDITIONAL GO — NOT DEPLOYED)

**Agent/tool and model:** Claude Code (Opus 4.8, `claude-opus-4-8`), independent safety reviewer — review-only, local deterministic re-verification. **Objective:** independently establish the baseline, review the Codex item-18 Sender/sidecar B5/B6 repair surgically, rerun and challenge the deterministic evidence, add high-value negative tests, verify normal-path (B1-B4) non-regression and the deployment/rollback packet, and issue a deploy verdict. No deploy, Sender trigger, send, production write, Instantly POST, or protected-workflow edit.

**Latest baseline (independently confirmed):** branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57`, nothing staged/committed. Sender base versionId `00b52f03-1ae7-4252-a164-ce08f0c7a77e` (workflow ID `ePS5uBBxKxhFCYgU`). Candidate **semantic SHA-256 `9910bfb644f1b67ec18d2d16f1fa52290ca2d9d1168e69f1ab80a921f7d0ad04` reproduced exactly**; Q node `695bd3db…` byte-identical to backup; sidecar `state-store 957654e9…` / `server 87d8b3ae…` match the packet. **Dirty-tree reconciliation:** the prior handoff's 342/353-entry count vs this Windows checkout's **24** entries is a CRLF artifact (`core.autocrlf=true` here vs autocrlf-off WSL); all three implementation files hash-match the recorded candidate, so content is identical — not a safety concern.

**Latest pre-existing handoff:** `2026-07-12 13:10 BST — Codex Item-18 Sender/sidecar Safety Repair (PASS DETERMINISTICALLY — NOT DEPLOYED)` (its own predecessor: `2026-07-11 17:19 BST`).

**Files reviewed:** `infrastructure/send-state/{state-store.mjs,server.mjs}`; `workflows/production_sender_current.json`; exact backup `workflows/sender_backup_00b52f03_pre_item18_b5_b6_contract_repair.json`; `scripts/{ITEM18-patch-current-sender.mjs,FINAL-CLOSURE-current-sender-b5-b6-test.mjs,FABLE-RUN4-sender-body-gate-node-test.js}`; real current Sender node bodies (E,E2,F2,O,P,P3,P4,Q,R,S,T,U,U2,U4,U2F,V,W,W1,W2,W4,W5,W6,X) and connection topology; `docs/ITEM18_SENDER_SIDECAR_DEPLOYMENT_ROLLBACK_PACKET.md`; `docs/{STATE_AND_IDEMPOTENCY,RUNTIME_PROOF_CHECKLIST,SCALE_READY_ACCEPTANCE_GATES}.md`; `infrastructure/business-live/docker-compose.yml`; AGENTS.md; both newest handoff entries. Decision/HumanApproval/Shadow exports checked read-only (git-unchanged vs HEAD).

**Tests rerun (exact counts, all independent):** FINAL-CLOSURE B5/B6 harness **60/60 PASS** (META 4, CONTRACT 11, B5 12, B6 17, COMPAT 15, COUNTERS 1; 0 external calls); behavioural closure **483/483 PASS**; body-gate (extracted B+O) **77/77 PASS**; secret scan **PASS**; `node --check` 4 changed JS modules **PASS** + 7 extracted Code nodes **7/7 PASS**; JSON parse current+backup **2/2**; Q hash `695bd3db…` and semantic `9910bfb6…` **match**; Decision `84b941a4`/HumanApproval `99b4c092`/Shadow `active=false` byte-identical to HEAD. **Harness limitation:** it does not evaluate the 7 new nodes' n8n `={{…}}` expressions inside real n8n — that layer is unproven until deployment.

**Newly added review tests:** `scripts/ITEM18-REVIEW-negative-invariants.mjs` — **6/6 PASS**, loopback-only: NEG-1 non-terminal 409 not misread as terminal/sent; NEG-2 different single match IDs across two persisted polls → `HUMAN_REVIEW_MULTIPLE_MATCHES`, never `SENT_RECONCILED`; NEG-3 tampered `recommendedState` recomputed away; NEG-4 (observation) sidecar `/transition` trusts caller `toState` (authority in W4/W5); NEG-5 malformed poll history fails safe.

**Sidecar verdict:** **PASS.** Correct terminal set; durable-before-lock TOCTOU-safe acquire; no record overwrite/deletion; fail-closed on malformed/unknown; canonical `toState`-only `/transition` with explicit 400/404/409; persistent reconciliation history requiring two consecutive same-identity matches; `writeState` not exposed over HTTP. One LOW design observation: reconciliation-terminal authority is split (sidecar enforces state-machine legality only; Sender W4/W5 supply the recomputed `rec.state`); internal-only sidecar + sole Sender caller → low risk, cannot cause a send.

**Sender verdict:** **PASS.** E surfaces 409 (fail-closed on connection error); E2 never treats an arbitrary 409 as acquired; any blocked acquire → F2 no-send; node O `TERMINAL_SEND_STATES` includes SENT+SENT_RECONCILED and the 15th blank-body gate; **Q's only inbound edges are P4 and T**; SEND_UNCERTAIN/reconciliation graphs cannot reach Q; P3 persists SUBMITTING before Q; P4 restores the exact Q context; X/U4/U2F/W1/W5 use `toState`; V is GET-only; W filters thread/sender/recipient/subject/timestamp/marker; retry (pre-submission only, ≤3) is cleanly separated from post-submission uncertainty; **Q byte-identical**.

**Normal-path (B1-B4) regression verdict:** **ACCEPTABLE with one understood behavioral change.** Q unchanged; blank-body dual gate intact; retry classifier (R) untouched; P4 returns Q's exact shape; SENT path only renames `state`→`toState`. New: **P3 makes sidecar health a fail-closed precondition for all normal sends** (unhealthy sidecar → sends stop, not blind-send) — safer, but a new availability coupling on a live-capable (`DRY_RUN=false`) Sender, proven only deterministically.

**Deployment packet verdict:** **COMPLETE (16/16)** and rollback **SAFE** — paired sidecar-first order, drain via `/v1/unfinished`, production guard, semantic-SHA + Q-hash equality (not versionId), full deterministic rerun, separated deployment vs drill approval, volume/record preservation, exhaustive stop conditions. Candidate topology (`hmz-send-state-business-live` / `hmz_send_state_business_live_data`) corroborated by the business-live compose but **host-unverified**.

**Verdict:** **CONDITIONAL GO FOR OWNER-APPROVED PAIRED DEPLOYMENT.** No critical/high defect; deterministic evidence fully reproduced; packet complete; production topology discovery required before change. Conditions C1-C6: (C1) confirm real production sidecar topology/host access, STOP on mismatch; (C2) paired sidecar-first deploy with Sender deactivated+drained, no LOCKED/SUBMITTING; (C3) verify by semantic SHA `9910bfb6…`+Q `695bd3db…` (candidate and live share versionId `00b52f03` but differ 45 vs 38 nodes), rerun 60/60+483/483+77/77+secret scan; (C4) B5/B6 remain **NOT-LIVE-PROVEN** until separately-approved bounded drills pass on the deployed version; (C5) confirm both n8n API creds and host shell access; (C6) accept the fail-closed sidecar-health coupling.

**Remaining owner actions:** (1) authorise a bounded paired-deployment maintenance session honoring the packet + C1-C6; (2) separately authorise the owned-lead B5 replay + B6 one-shot-proxy drills only after semantic-equal deploy and post-deploy reruns pass; (3) do not sign the CRR or claim scale/sell readiness until B5/B6 are live-proven and all gates pass.

**Readiness percentages:** implementation completeness (local candidate) **98%** / production-integrated **0%**; B5/B6 live-proven **0%** (B1-B4 live-proven); normal supervised operating **90%**; supervised scale/sell **88% — BLOCKED**; classification self-learning **98%** (untouched); draft-improvement self-learning **70%** (separate, untouched); autonomous **17%**. No hard gate overridden; no 100% claim.

**Recommended next tool/agent:** Codex or Claude Code in a separately owner-approved production maintenance session with confirmed host + API access; then hand back for the bounded B5/B6 drills. Do not touch Decision, HumanApproval, Shadow, learning, Gate 2, or autonomous mode.

**Regression Safety Check:** latest baseline `ed94d57`; latest pre-existing handoff `2026-07-12 13:10 BST`. Compared current Sender + exact backup, sidecar store/server, real node bodies, Decision/HumanApproval/Shadow, item-18 packet, state/runtime/scale docs, business-live compose. No archive/vault/full-repo scan. No broad rewrite/deletion; no checkout/restore/clean/stash; the uncommitted item-18 implementation and closure docs are preserved unchanged; implementation-file hashes match the recorded candidate (state-store `957654e9…`, server `87d8b3ae…`, sender `be7a9964…`, Q `695bd3db…`). Decision/HumanApproval/Shadow/learning untouched (byte-identical to HEAD; Shadow inactive). Review added only `scripts/ITEM18-REVIEW-negative-invariants.mjs`, `reports/ITEM18_INDEPENDENT_SAFETY_REVIEW.md`, and this entry. All tests loopback-only, zero external network calls. No deployment, production write, Sender trigger, review approval, Instantly POST, DataTable write, Shadow activation, Gate 2 approval, or autonomous enablement. Stopped without staging/committing.

---

## 2026-07-12 13:10 BST — Codex Item-18 Sender/sidecar Safety Repair (PASS DETERMINISTICALLY — NOT DEPLOYED)

**Agent/tool and model:** Codex (GPT-5), local surgical implementation + deterministic Node.js/Python verification. **Objective:** repair only the proven Sender/sidecar B5/B6 durable-state, prior-SENT, reconciliation-history and transition-contract defects; prepare deployment/rollback evidence; do not deploy or trigger production.

**Latest baseline:** branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57` (`proof: record final supervised live gates`), current production-tagged Sender base `00b52f03-1ae7-4252-a164-ce08f0c7a77e`. Initial worktree: 342 dirty entries (340 tracked, 2 untracked). The two untracked files were the owner `.docx` and the previous audit's B5/B6 harness. The prior audit's seven governing-document updates and harness were preserved and extended, not regenerated from an older export. No checkout/pull/clean/restore/stash/stage/commit/push.

**Latest valid pre-existing handoff:** `2026-07-11 17:19 BST — Codex Final Supervised Scale-Readiness Closure (PARTIAL — B5/B6 current Sender defect)`, whose own pre-existing reference was the `2026-07-08 01:55 BST` closure attempt.

**Defects reproduced before editing:** exact baseline harness **27/37 PASS, 10 FAIL** (META 2/2, B5 12/17, B6 13/18). `SENT` had an outgoing transition and was nonterminal, so its lock remained; acquire checked the lock before durable state and returned `LOCK_ALREADY_HELD` without `priorState=SENT`; W re-read R on every loop and reset poll history; no Sender transition persisted `SUBMITTING`, `SEND_UNCERTAIN`, failure or reconciliation outcomes; W4 mislabeled zero/multiple as `SEND_UNCERTAIN`; X sent `state` while the route required `toState`. Additional real-runtime trace: E did not set `neverError`, so an actual replay 409 could stop before E2 surfaced the body. Historical V5 Layer 2 remained a separate-runner result, not current Sender proof.

**Root causes:** sidecar terminality was inferred from an incorrect transition graph; acquire ordered lock before durable lookup; reconciliation state lived only in an n8n item that the GET loop discarded; current workflow wiring omitted the documented forward transitions; request/response field names were not canonical end-to-end; and the older P22 topology assertion assumed P connected directly to Q.

**Files changed in this repair:** `infrastructure/send-state/{state-store.mjs,server.mjs,README.md}`; `workflows/production_sender_current.json`; new exact backup `workflows/sender_backup_00b52f03_pre_item18_b5_b6_contract_repair.json`; new patch utility `scripts/ITEM18-patch-current-sender.mjs`; extended `scripts/FINAL-CLOSURE-current-sender-b5-b6-test.mjs`; Sender-only P22 topology update in `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`; `docs/{STATE_AND_IDEMPOTENCY.md,INSTANTLY_CONFIGURATION.md,ASSUMPTIONS_AND_UNKNOWNS.md,RUNTIME_PROOF_CHECKLIST.md,SCALE_READY_ACCEPTANCE_GATES.md,INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md}`; `docs/campaign-readiness/{CRR-531e64ed.md,README.md}`; new `docs/ITEM18_SENDER_SIDECAR_DEPLOYMENT_ROLLBACK_PACKET.md`; `reports/INSTANTLY_VERIFICATION_EVIDENCE.md`; this handoff. The previous audit's `docs/S2_ROLLBACK_LIVE_DRILL.md` changes remain untouched.

**Exact contract changes:** `SENT`, `SENT_RECONCILED`, human-review outcomes and permanent/auth/invalid/exhausted outcomes are terminal; `SEND_UNCERTAIN` is nonterminal only for reconciliation and can never resubmit. Acquire validates identity, reads durable state before/after atomic locking, returns canonical `priorState`, cleans only stale locks backed by known terminal records, and fails closed on malformed/unknown records. `/transition` accepts only `toState`, returns `state`, and emits explicit 400/404/409 errors. New explicit `/v1/send/reconciliation` durably records filtered match IDs/consecutive history without performing a state transition. Sender E surfaces 409 bodies; P3/P4 persist `SUBMITTING` and restore identical Q context; X uses `toState`; U4/U2F persist uncertain/failure states; V stays GET-only and reads stable R context; W filters thread/sender/recipient/subject/timestamp/exact marker; W1 persists each poll; W5/W6 persist/finalise reconciled/zero/multiple states. Node Q itself is byte-identical to the pre-repair backup (SHA-256 `695bd3db…`).

**Tests and exact counts:** baseline negative 27/37 as above. Repaired current-node + real loopback-sidecar HTTP harness **60/60 PASS**: META 4, contract 11, B5 12, B6 17, compatibility/failure 15, counters 1; external network calls 0. Main behavioural harness **483/483 PASS**. Extracted-current-node body gate **77/77 PASS**. Secret scan PASS/no credential-shaped workflow values. `node --check`: four changed JS modules/scripts PASS plus seven extracted changed Sender Code nodes **7/7 PASS**; literal-newline guard PASS. JSON parse **2/2 PASS** (candidate + backup). Semantic comparison: only nine intended original Sender nodes and ten intended connection sources changed; seven nodes added; Q/B/D/R, launch profile, workflow ID/settings/active flag unchanged. Decision/HumanApproval/Shadow file hashes remained exactly `4037b704…` / `3fa056d6…` / `3e790b8b…`; Shadow export remains inactive.

**B5 deterministic verdict:** **PASS — LOCAL CANDIDATE ONLY, NOT LIVE-PROVEN.** Initial acquire → SUBMITTING → terminal SENT; GET returns terminal SENT; exact replay returns 409/DURABLE_STATE_EXISTS/prior SENT; real E2/F2/O block before Q; replay reply-POST counter 0; record/file unchanged; reconciled SENT and both human-review terminals equally protected; unrelated key allowed; duplicate race, old stale SENT lock and altered nonidentity payload covered.

**B6 deterministic verdict:** **PASS — LOCAL CANDIDATE ONLY, NOT LIVE-PROVEN.** Exactly one simulated reply POST; malformed success enters durable SEND_UNCERTAIN with retry disabled; first exact match persists count 1; separate second poll after sidecar restart persists count 2; separate child-process restart also preserves history; canonical transition reaches SENT_RECONCILED; total reply POST remains one and replay blocks. Zero and multiple become durable human-review terminals with zero extra POST; sender/recipient/subject/thread/marker mismatches do not count; illegal/malformed transitions fail; no uncertain/human graph reaches Q.

**Production deployment status:** **NOT DEPLOYED.** No production guard/API call was needed because no n8n operation occurred. No production sidecar read/restart/change, workflow PUT, activation/deactivation, Sender execution, approval, DataTable write, Instantly POST or email occurred. The local export deliberately retains the base production versionId until an approved PUT returns a real new versionId; candidate semantic SHA-256 is `9910bfb644f1b67ec18d2d16f1fa52290ca2d9d1168e69f1ab80a921f7d0ad04`.

**Regression risks:** the real production sidecar orchestration/container/volume has not been authenticated and the repo business-live README contains stale deployment wording; P3 makes sidecar health a deliberate fail-closed precondition before normal Q; n8n runtime must confirm the new node references/expressions; Sender and sidecar must never be active with only one half updated; a workflow PUT creates a new versionId; existing uncertain/human records must survive. Draft-improvement learning's separately reopened defect remains pending and was not inspected.

**Rollback readiness:** PREPARED. Exact pre-repair Sender export/hash exists; clean sidecar source is recoverable from `ed94d57`; durable volume must be preserved; paired deactivate/drain/restore/rebuild/health/reactivate order, forward deployment, version/semantic equality, B5 replay, forward-once B6 proxy, stop conditions and volume-preserving rollback are in `docs/ITEM18_SENDER_SIDECAR_DEPLOYMENT_ROLLBACK_PACKET.md`.

**Exact next recommended tool/agent:** Codex or Claude Code in a separately owner-approved production maintenance session. Run `scripts/assert-hmz-production-target.ps1`, authenticate/read production Sender and actual sidecar topology, deactivate/drain Sender, back up state, deploy sidecar then Sender as a pair, refresh the export, rerun with `HMZ_EXPECTED_SENDER_VERSION=<new>`, and restore active state only after equality/health. Obtain separate owner approval for bounded B5/B6 drills. Do not touch Decision, HumanApproval, Shadow, learning logic, Gate 2 or autonomous mode.

**Readiness percentages:** implementation completeness **98%** (local candidate complete; not production-integrated); normal supervised operating readiness **90%** (current B1-B4 constrained path only); supervised scale/sell readiness **88%** (blocked by deployment/version equality, owner B5/B6, draft-improvement clean test and unsigned CRR); classification self-learning **98%** (live-proven within approved scope, untouched); draft-improvement self-learning **70%** (separate reopened defect pending); autonomous readiness **17%** (Shadow inactive, Gate 2 unapproved, autonomous disabled). No percentage overrides a hard gate; no 100% claim.

**Regression Safety Check:** latest baseline `ed94d57`; latest pre-existing handoff `2026-07-11 17:19 BST`. Compared current Sender + exact backup, sidecar store/server, real current node bodies, Decision, HumanApproval, Shadow, state/idempotency/config/runtime/scale/fault/CRR docs, V5 Layer 1/2 evidence and only relevant fixtures. No archive/vault/full-repo scan. No broad workflow replacement or accidental deletion; Q and normal mapping/retry/body/allowlist profile are unchanged; no stale template or old export overwrote current work. Decision, HumanApproval, Shadow, classification/draft-learning logic were untouched. No production write, Sender trigger, review approval, Instantly POST, email, Shadow activation, Gate 2 approval or autonomous enablement. Stop without committing.

---

## 2026-07-11 17:19 BST — Codex Final Supervised Scale-Readiness Closure (PARTIAL — B5/B6 current Sender defect)

**Agent/tool:** Codex (GPT-5), local read-only workflow inspection + deterministic Node.js tests. **Objective:** reconcile the new owner-live evidence, close safe documentation gates, and prove current-Sender B5/B6 without any production write or live send.

**Baseline:** branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57` (`proof: record final supervised live gates`). Latest valid pre-existing handoff was `2026-07-08 01:55 BST — Codex Final Proof-Gate Closure Attempt`. Initial dirty tree was exactly the known broad baseline: 333 modified entries plus untracked `HMZ Instantly Responder Ops Console Build Plan.docx`; targeted governing docs were clean, while current workflow exports already had pre-existing line-ending churn. No checkout/pull/clean/restore/stage/commit/push.

**Files changed:** `scripts/FINAL-CLOSURE-current-sender-b5-b6-test.mjs`; `docs/RUNTIME_PROOF_CHECKLIST.md`; `docs/SCALE_READY_ACCEPTANCE_GATES.md`; `docs/S2_ROLLBACK_LIVE_DRILL.md`; `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`; `docs/campaign-readiness/CRR-531e64ed.md`; `docs/campaign-readiness/README.md`; this handoff. No workflow export or unrelated file edited.

**Owner evidence recorded:** `case-30157120` / HumanApproval `7231` review + Chat PASS (`INFORMATION_REQUEST / OFFER_EXPLANATION`, no correction, `AI_DRAFT_APPROVAL`, validated non-empty `ai_supervised_with_form_learning` draft); Sender `7232` normal-send B1-B4 PASS (Q 200, X2 SENT, correct inbound eaccount, lead recipient, same thread, non-empty body, marker, exactly one Gmail reply); HumanApproval `7239` repeat-send reason gate PASS (`repeat_send_reason_required`, same editable review, no Sender/POST/email) and explicitly not B5. S2.6 owner-live PASS: rule-off `case-4b8bbac0`, restored rule-on `case-a7d83472`, exact target row 82/rule `6e50fd54…`; temporary second style-rule deactivation `cdada69d…` recorded; owner confirms both active. Ops Console Stage 1 walkthrough PASS/100%, still local-only/no production read or control. CRR owner confirmations recorded: current `531e64ed…`, retired `bcda01f7…`, 24 senders, subject/thread, CTA/no-link scope clarification, reviewer, enrolled owned lead, intended future signatory Humza Z.

**Production metadata checked:** production target guard PASS. No n8n API credential variables were present in Bash or PowerShell, so no authenticated production GET was possible and no API request was attempted. Local exports: Decision `84b941a4…` active, HumanApproval `99b4c092…` active, Sender `00b52f03…` active; owner execution identified expected Sender `00b52f03…`; disabled Shadow export remains `active=false`. Current Sender node O exactly matches the owner workspace, current campaign, reviewer, and all 24 sender eaccounts (24/24, no missing/extra). Rule restored states are owner-live verified only, not independently API-rechecked.

**Tests/checks:** `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` = **483/483 PASS**; extracted-current-node body gate with required args = **77/77 PASS**; secret scan = PASS/no credential-shaped values; new script syntax = PASS; new current-Sender B5/B6 harness = **27/37 PASS, 10 FAIL** (META 2/2, B5 12/17, B6 13/18), exit 1 as required by failed acceptance. No test made a network call.

**B1-B6 verdicts:** B1-B4 **LIVE-PROVEN from owner evidence** against current Sender normal send. B5 **CURRENT-VERSION DETERMINISTIC ACCEPTANCE FAILED / PENDING REPAIR**: real sidecar + real D/E2/F2/O code produces replay POST count 0, but sidecar treats `SENT` as nonterminal, retains the lock, returns `LOCK_ALREADY_HELD` without prior `SENT`, and cannot satisfy `no_prior_terminal_send_state`. B6 **CURRENT-VERSION DETERMINISTIC ACCEPTANCE FAILED / PENDING REPAIR**: real R makes ambiguous 200 `SEND_UNCERTAIN`, disables retry, V is GET-only, and uncertain/human-review paths cannot reach Q; however W resets poll history from R, no uncertain/reconciliation state is persisted, zero/multiple W4 terminals use `SEND_UNCERTAIN`, and X sends `state` while the sidecar requires `toState`. The affected nodes are byte-identical to pre-Run-4 `dfb310f4`; this is not a blank-body regression. Historical V5 Layer 2 proved a separate runner and does not close current n8n wiring.

**Defect:** fault-ledger item 18, severity **HIGH / supervised scale blocker**. Do not repair without owner approval; do not run B5/B6 live/proxy drill until all 37 deterministic assertions pass on the repaired deployed version. Exact bounded post-repair runbook with hard POST cap, rollback, evidence, and stop conditions is in `docs/RUNTIME_PROOF_CHECKLIST.md`.

**Gate verdicts:** S2.6 PASS (owner-live; restored states not API-rechecked); Ops Console Stage 1 PASS/100%; CRR business fields complete but **UNSIGNED / NOT READY FOR SIGNATURE** because B5/B6 fail. Shadow inactive, Gate 2 unapproved, autonomous disabled.

**Remaining human actions:** (1) explicitly authorise a narrow Sender+sidecar repair session for item 18; (2) after deterministic 37/37 and production/local version match, explicitly authorise the bounded owned-lead B5 replay + B6 one-shot proxy drill; (3) sign/date the CRR as Humza Z only after B5/B6 and all mandatory gates pass. No scale increase before these steps.

**Recommended next agent/tool:** Claude Code / Fable or Codex, one narrow owner-approved item-18 repair session. Reproduce first, align sidecar transitions and W history carriage, add integration tests, deploy under the production guard only after owner approval, refresh export, then hand back for controlled owner proof. Do not touch Decision, HumanApproval, Shadow, Gate 2, or autonomous mode.

**Gate-based readiness:** implementation completeness **92%** (22/24 mandatory behaviours); supervised operating readiness **90%** (21.5/24 evidence points, normal supervised validation only); supervised scale/sell readiness **84%** (23.5/28, **BLOCKED** by item 18/B5/B6/unsigned CRR); autonomous readiness **17%** (2/12 S3+S4 criteria). Percentages do not override failed hard gates.

**Regression Safety Check:** latest baseline `ed94d57`; latest pre-existing handoff `2026-07-08 01:55 BST`; current Decision/HumanApproval/Sender/Shadow exports, sidecar store/server, V5 Layer 1/2 evidence and only relevant scripts were checked. No broad rewrites/deletions, no archive/full-vault scan, no stale template/README state used, and no risk-bearing workflow edit. No production write, Sender trigger, review submit/approval, Instantly POST, DataTable change, Shadow activation, Gate 2 approval, or autonomous enablement occurred.

---

## 2026-07-08 01:55 BST — Codex Final Proof-Gate Closure Attempt (BLOCKED — owner-live evidence pending)

**Agent:** Codex
**Objective:** Final owner-guided live-proof evidence collection for CRR / supervised scale gates. Scope was evidence collection only: no workflow deploys, no workflow edits, no Sender trigger, no review approval, no Instantly POST, no Shadow activation, no Gate 2 approval, no autonomous enablement.

**Baseline used:** branch `codex/5q-context-token-forensic-20260705`; latest commits `cd5d15f` (`review: final verify Fable Run 4`) and `dadf534` (`final: prepare shadow readiness and local ops console`). Initial worktree was already very dirty with many pre-existing modified files; this session treated them as owner/generated state and changed only this handoff file. Environment variables were presence-checked only; no secret values printed.

**Local checks:** `node --version` -> `v22.22.1`. The exact requested no-arg command `node scripts/FABLE-RUN4-sender-body-gate-node-test.js` failed because the script requires `<extracted_b.js> <extracted_o.js>` arguments. To collect the intended proof without editing the repo, Sender nodes B and O were extracted from `workflows/production_sender_current.json` into `/tmp`, then `node scripts/FABLE-RUN4-sender-body-gate-node-test.js /tmp/hmz_sender_node_b.js /tmp/hmz_sender_node_o.js` returned **77 PASS / 0 FAIL**. `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` returned **483/483 PASS**. `python3 scripts/scan-workflow-exports-for-secrets.py` returned `RESULT: no credential-shaped values found in workflow exports.`

**Production read-only metadata:** production target guard passed (`https://n8n.hmzaiautomation.com/api/v1`). The first metadata GET failed under sandbox DNS; rerun with approved network escalation was read-only only. Production workflow metadata matched required versions: Decision `tgYmY97CG4Bm8snI` versionId `84b941a4-bc6d-4f48-be27-36dad1510c8d` active=true; HumanApproval `9aPrt92jFhoYFxbs` versionId `99b4c092-d78e-4580-a3c8-46dc65ab00cf` active=true; Sender `ePS5uBBxKxhFCYgU` versionId `00b52f03-1ae7-4252-a164-ce08f0c7a77e` active=true; Shadow `aHzLtQiv6G8h1bqD` versionId `ae13bf4e-ee04-438f-9657-3c57183b90a2` active=false. No production writes were made.

**UI / live review confirmation:** BLOCKED / pending owner evidence. No fresh live review case ID, incoming reply text, Google Chat screenshot/confirmation, or review-form confirmation was supplied in this session. Required fields remain: effective classification; original vs effective if corrected; reply mode; AI draft status; draft source; non-empty draft where expected.

**Runtime proof B1-B5 against Sender `00b52f03`:** BLOCKED / pending owner-approved send. No owner approval/send evidence was supplied in this session. B1 Sender node Q `statusCode=200`, B2 terminal `SENT`, B3 correct sender/eaccount, B4 correct recipient/thread/body/marker, and B5 no duplicate/idempotency proof remain unproven live for the current Sender.

**Duplicate replay drill:** LIVE DRILL PENDING. Local/code evidence remains positive: Sender has prior-terminal-state blocking and `no_prior_terminal_send_state` gate before node Q, and duplicate terminal nodes exist. No safe replay case/send key was provided, so no second-attempt proof was collected and no claim of live B5 PASS is made.

**SEND_UNCERTAIN reconciliation:** CODE-PROVEN ONLY / live drill pending. Local Sender export still contains terminal `SEND_UNCERTAIN`, reconciliation poll nodes V/W/W4, and code paths for consecutive single-match vs zero/multiple human review. No safe simulated/live SEND_UNCERTAIN event was available; no duplicate POST was attempted; no live B6 PASS is claimed.

**S2.6 rollback live drill:** PENDING OWNER ACTION. Runbook `docs/S2_ROLLBACK_LIVE_DRILL.md` identifies candidate rule `6e50fd54-ff2a-4d5a-b220-c0c7374edea4` with stop conditions, but no owner confirmation of the exact row capture/deactivate/probe/restore/verify sequence was supplied. No DataTable row was modified by Codex.

**CRR `docs/campaign-readiness/CRR-531e64ed.md`:** BLOCKED / incomplete. Campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0` is the current documented Sender allowlist campaign, but owner confirmations remain pending for approved sender(s), subject/thread pattern, CTA, test lead enrollment, and campaign-ID reconciliation. Rows 10-14 remain pending current-Sender live proof. Owner signature/date is still absent. Launch remains blocked; scale-ready is not claimed.

**Ops Console Stage 1 checklist:** PARTIAL PASS from static/local inspection. `ops/responder-ops-console.html` is a local single HTML file with eight modules, Blob downloads, readiness statuses, diagnosis module, runtime proof module, and no `fetch(` / `XMLHttpRequest` / `WebSocket` / `EventSource` / `sendBeacon` / `api-key` / `apikey` matches. No standalone `READY FOR AUTONOMOUS SENDING` status exists; the permanent banner is `NOT APPROVED FOR AUTONOMOUS SENDING`. A real browser double-click/open and owner walkthrough were not confirmed in this session, so opened-locally/navigation/download UX remains owner-confirm pending.

**Autonomous status:** Shadow inactive; Gate 2 not approved; autonomous disabled; 14-day shadow review not started. High-risk categories remain no-autonomous-send: unsubscribe/suppression/legal/compliance/hostile/no-reply/pricing/booking/proof/trust/ambiguous remain human review, draft-only, or no-send according to policy and future owner allowlists.

**Final readiness percentages:** supervised responder 98%; self-improvement 98%; sender / scale safety 92%; autonomous shadow readiness 70%; ops console stage 1 90% (static/local verified, owner browser walkthrough pending); full scale-ready system 80%. System is **not** supervised scale-ready because current-Sender live send proof, duplicate replay proof, S2.6 live rollback, and signed CRR remain missing. No consolidated repair run is needed from this evidence; the blocker is owner-live proof/action, plus one minor test-run usability defect: the body-gate script's no-arg command fails despite docs/owner instructions expecting standalone execution.

**Regression Safety Check:** no Sender trigger by Codex; no Instantly POST by Codex; no production write; no workflow deploy; no Shadow/Gate2/autonomous change; no stale README evidence used; no unrelated files staged.

---

## 2026-07-08 01:08 BST — Codex Final Review: Fable Run 4 (PASS)

**Agent:** Codex
**Objective:** Final skeptical review of Fable Run 4 before owner-live proof actions. Review-only: no workflow deploy, no production writes, no live email tests, no Sender trigger, no Shadow activation, no Gate 2 approval, no autonomous enablement, no Ops Console edits.

**Baseline used:** branch `codex/5q-context-token-forensic-20260705`; latest Run 4 commit `dadf534` (`final: prepare shadow readiness and local ops console`). Worktree remained very dirty with many pre-existing modified backup/output/workflow files; nothing was staged before this handoff update. Required process check found only the current `pwsh` shell, no orphaned Fable Run 4 node/python test process. Environment variables were presence-checked only; no secret values printed.

**Checks run:** required git pre-flight; required file reads only; production target guard passed; read-only production metadata GETs for Decision/HumanApproval/Sender/Shadow; `node scripts/FABLE-RUN4-sender-body-gate-node-test.js` attempted but `node` is unavailable in this shell; `python` shim unavailable, so the same scripts were run with `python3`; `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` -> **483/483 PASS** with P22 static fallback for node absence; `python3 scripts/scan-workflow-exports-for-secrets.py` -> no credential-shaped values; Ops Console network/API grep via PowerShell -> no matches; scoped JSON comparison of Sender current vs backup.

**Protected workflow verdict:** Decision unchanged locally and in production at `84b941a4-bc6d-4f48-be27-36dad1510c8d`; HumanApproval unchanged locally and in production at `99b4c092-d78e-4580-a3c8-46dc65ab00cf`; Sender changed from backup `dfb310f4-901a-4d76-81dc-8f5d4ad13552` to local/production `00b52f03-1ae7-4252-a164-ce08f0c7a77e`; Shadow production active=false (`ae13bf4e-ee04-438f-9657-3c57183b90a2`). No production writes were made.

**Sender body-gate verdict:** PASS. Structured diff showed only Sender nodes `B. Re-run Send & Suppression Gates`, `O. Live Send Gate Evaluation (14 Gates)`, and two sticky notes changed; workflow connections/settings/active state unchanged. Node B blocks blank body before ownership acquisition via C false -> C2. Node O adds the 15th `draft_body_non_empty` gate immediately before P/Q; P false -> P2, so POST and SENT terminal are unreachable on body failure. Node Q POST body expression, send ownership, SENT terminal, retry classification, and reconciliation nodes were byte-for-byte unchanged from backup. Body normalization covers comments/marker, HTML tags, nbsp, zero-width chars, and whitespace. HumanApproval R0 still treats recoverable Sender blocks as same-review-link retryable. Limitation: the 77/77 standalone Node.js behavioural test could not be re-run here because `node` is not installed; Fable's reported 77/77 result is supported by the real-node test script, P22 static checks, and direct export inspection.

**Ops Console verdict:** PASS. `ops/responder-ops-console.html` is a single local HTML file with 8 modules, no backend, no fetch/XHR/WebSocket/EventSource/sendBeacon/API references, no secret inputs, no workflow activation/case approval/sending/autonomous controls, and no `READY FOR AUTONOMOUS SENDING` status. It includes New Campaign Setup with approved sender list, Product/Offer setup, Draft Style tuning, start/stop guidance-only modules, Diagnose Issue with 11 issue types, Runtime Proof, SOP reference, readiness statuses `BLOCKED` / `READY FOR CONTROLLED TEST` / `READY FOR SUPERVISED USE` plus permanent `NOT APPROVED FOR AUTONOMOUS SENDING`, and all 7 Blob-download outputs.

**Autonomous-shadow verdict:** PASS for disabled readiness only. `docs/AUTONOMOUS_SHADOW_READINESS.md` states default disabled, Shadow not activated, Gate 2 NOT APPROVED/unsigned, 14-day plan with thresholds, disallowed categories, escalation rules, rollback/kill switch, owner signoff, and no executable autonomous activation without explicit owner approval.

**Campaign/S2 proof verdict:** PASS for documentation, owner-live pending. `docs/S2_ROLLBACK_LIVE_DRILL.md` is an owner runbook and does not claim completion. CRR docs mark unknowns pending, document the `bcda01f7` vs `531e64ed` campaign-ID conflict, keep launch blockers explicit, and leave the `531e64ed` record incomplete/unsigned.

**Remaining owner-live actions:** next approved send runtime proof B1-B5 against Sender `00b52f03`; duplicate replay and SEND_UNCERTAIN drills before volume increase; S2.6 rollback live drill; complete/sign `docs/campaign-readiness/CRR-531e64ed.md` including campaign-ID confirmation; confirm Run 3 UI/chat fields on the next live case; owner walk-through of `ops/README.md`.

**Final readiness percentages:** supervised responder 98%; self-improvement 98%; sender / scale safety 92%; autonomous shadow readiness 70%; ops console stage 1 100%; full scale-ready system 80%.

**Regression Safety Check:** no Sender trigger, no Instantly POST from this review, no workflow deploy, no production write, no Shadow activation, no Gate 2 approval, no autonomous enablement, no Ops Console edit, no broad repo/archive scan, no secrets printed.

---

## 2026-07-07 — Fable Run 4: Sender Blank-Body Defense-in-Depth + Shadow Readiness (disabled) + Ops Console Stage 1 (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Absorb the Codex Run 3 PASS review; close the commissioned Sender blank-body gap; backfill the Campaign Readiness Record; write the S2 live-drill runbook; consolidate autonomous shadow readiness (disabled only); build Ops Console Stage 1; update all governing docs. Owner explicitly approved this run, including the Sender defense-in-depth patch. No autonomous activation, no Gate 2 approval, no Shadow activation, no live sends.

**Baseline used:** review commit `0dd459c`, implementation commit `c558263`, branch `codex/5q-context-token-forensic-20260705`, clean worktree. Production versionIds verified matching local exports BEFORE any change (guard passed): Decision `84b941a4`, HumanApproval `99b4c092`, Sender `dfb310f4`, Shadow `aHzLtQiv6G8h1bqD` active=false.

**Sender blank-body defense-in-depth (SS.4 — DEPLOYED):** Gap proven by read-only audit: node A never checks body; node B's variable gate passes when `draft_text === null`; node O's 14 gates have no body check; node Q's POST body coalesces to `''` (`draft.draft_text || body.edited_reply_text || ''`) — a blank POST was structurally possible, prevented only upstream (HumanApproval Node N `draft_text_required`). Also verified Sender is invoked ONLY from HumanApproval "Q. Reply Sender Handoff (Approved)" — no suppression-only path enters Sender, so the block cannot break a legitimate no-send flow. **Patch (nodes B + O only, marker `FABLE-RUN4-SENDER-BODY-GATE`):** shared `hmzSenderVisibleBodyText` normalization (strips HTML comments incl. the hmz-send-key marker, tags, nbsp entities/chars, zero-width chars, collapses whitespace); node B gate `draft_body_gate_passed` blocks BEFORE lock acquisition (C false → C2; reason `draft_body_missing_or_blank` + explicit fix instruction; HumanApproval R0 classifies it form-retryable → same review link, fix-and-reapprove works, no lock consumed); node O 15th gate `draft_body_non_empty` blocks immediately BEFORE the POST (P false → P2, reason `DRAFT_BODY_MISSING_OR_BLANK`). Both mirror node Q's exact effective-body precedence. Idempotency, retry, reconciliation, sender-mapping all untouched (P22.14-15). A second narrow deploy replaced the dangerously stale Sender sticky notes (claimed DRY_RUN=true/inactive/no-HTTP) with truthful live-capable text — the Codex-flagged truthfulness risk.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Sender | `ePS5uBBxKxhFCYgU` | `dfb310f4` | `aad8301e` → `00b52f03` | Run 4 blank-body gates (nodes B+O), then truthful sticky notes |

Backup: `workflows/sender_backup_dfb310f4_pre_run4_blank_body_gate.json`. Local export refreshed from production after each deploy (versionId verified); active=true preserved; Shadow re-confirmed inactive post-deploy. Patch script: `scripts/FABLE-RUN4-apply-sender-blank-body-gate.py`. Behavioural proof: `scripts/FABLE-RUN4-sender-body-gate-node-test.js` runs the REAL patched node code in Node.js — **77/77 PASS** (missing/empty/whitespace/marker-only/html-empty/nbsp/zero-width all BLOCK at both nodes with reasons; valid text, text+marker, and edited_reply_text fallback all pass; unresolved-variable gate unaffected; 15 gates total). No Sender trigger, no Instantly POST at any point.

**Harness:** **483/483 PASS** (was 463/463; P22 added 20 checks: markers, gate fields, passed-expression wiring, 15-gate count, node --check both nodes, the 77/77 behavioural run, block-point connection topology (pre-lock + pre-POST), node Q unchanged, idempotency nodes untouched, launch profile unchanged, C2/R0 retryability reasoning, upstream Node N retained, no-POST envelope). Re-run green against the production-refreshed export after BOTH deploys. Secrets scan PASS after final export refresh.

**Campaign readiness (Objective C):** `docs/campaign-readiness/README.md` documents the campaign-ID reconciliation with evidence: `bcda01f7-21c9-4e12-9849-0a375b548467` is STALE/SUPERSEDED (old BUSINESS_READY inputs/config; named `$STALE_CID` by `Apply-SupervisedLivePatch.ps1`); `531e64ed-c225-4baf-97a9-4ec90dc34eb0` is the CURRENT campaign (only entry in the live Sender allowlist; live exec 5263). The 2026-06-23 send evidence may predate the ID switch — owner confirmation required. `docs/campaign-readiness/CRR-531e64ed.md` is a backfilled but **INCOMPLETE, UNSIGNED** record: rows 1/2/7/15/16 evidence-backed; rows 3/4/6/8/17 PENDING_OWNER_CONFIRMATION; rows 10-14 require fresh live proof against Sender `00b52f03`. **Launch blocked until complete + signed. Nothing was invented.**

**S2 rollback drill (Objective D):** `docs/S2_ROLLBACK_LIVE_DRILL.md` — owner runbook (capture row → deactivate `6e50fd54` in Q12 `sl_rule_candidates` DataTable `CSdiTjXfi0tl0oZF` → probe → restore → verify probe → log), with stop conditions incl. "do not proceed if the rule row is unclear". **No production rule was modified this session; live drill remains owner-action; S2.6 stays PARTIAL.**

**Autonomous shadow readiness (Objective E — disabled only):** `docs/AUTONOMOUS_SHADOW_READINESS.md` consolidates the SR1-SR9 readiness checklist, 14-day review plan (+ restart rules), metrics/thresholds (≥98% agreement, 0 critical mismatches final 7 days, 0 false-safe on disallowed categories), safe vs disallowed categories, escalation rules, rollback + one-step kill switch, evidence + weekly templates, and the Gate 2 checklist **explicitly NOT APPROVED (G2.1-G2.7 all NOT MET/UNSIGNED)**. Nothing activated; Shadow remains inactive (API-confirmed); no config flag was flipped.

**Ops Console Stage 1 (Objective F):** `ops/responder-ops-console.html` (single self-contained file, double-click to open) + `ops/README.md`. All 8 modules built: New Campaign Setup (full field set, 24-eaccount approved-sender dropdown + blocking "Other", hard blocks, readiness scoring), Product/Offer Setup (16 fields, DRAFT-only output), Draft Style Tuning, Start/Stop guidance, Diagnose Issue (11 symptoms × 6 sections each), Runtime Proof Check (11 items), SOP Quick Reference. 7 Blob downloads (CRR JSON/MD, offer profile MD, Decision Engine update prompt MD, controlled test MD, runtime proof MD, diagnosis MD). Statuses: BLOCKED / READY FOR CONTROLLED TEST / READY FOR SUPERVISED USE + permanent NOT APPROVED FOR AUTONOMOUS SENDING banner. Verified: no fetch/XHR/WebSocket/external resources/API-key inputs; "READY FOR AUTONOMOUS SENDING" absent; console JS `node --check` clean. **It is an operator aid only — it reads nothing from and controls nothing in production. Stage 2/3 NOT built.**

**Docs updated:** `docs/SCALE_READY_ACCEPTANCE_GATES.md` (SS.4 closed dual-layer; S5.7 backfilled-incomplete; honest position rewritten for Run 4), `docs/RUNTIME_PROOF_CHECKLIST.md` (Sender-version invalidation note; new B8), `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md` (reference state; item 11 gap closed; item 15 Stage 1 built; **new item 17: stale embedded workflow documentation fault class**), `docs/CAMPAIGN_READINESS_RECORD.md` (points to per-campaign records).

**Remaining owner-only proof (unchanged in nature, updated in target):** (1) next approved send runtime proof B1-B5 **against Sender `00b52f03`**; (2) S2.6 live rollback drill per the new runbook; (3) duplicate replay + SEND_UNCERTAIN drills (B5/B6) before any volume increase; (4) complete + sign `CRR-531e64ed.md` incl. campaign-ID confirmation; (5) confirm Run 3 UI fields on the next live case (S1.7/A5/A9); (6) walk the Ops Console verification checklist in `ops/README.md`.

**Safety envelope:** production guard before every API call; only Sender nodes B/O + sticky notes changed; Decision/HumanApproval untouched; Sender never triggered; no Instantly POST; no live email tests; Shadow inactive (API-confirmed post-deploy); Gate 2 unapproved; autonomous disabled; no secrets in any file/log; no archive scan.

### Run 4 additions to the PERMANENT ANTI-REGRESSION LEDGER (items 1-12 in the Run 3 entry below remain in force, unchanged)

13. **Embedded workflow notes must be truthful:** any deploy changing a workflow's operating posture (DRY_RUN, allowlists, active state, gate count) must update that workflow's sticky notes in the same deploy. Never trust a sticky note over the executable config; never leave one contradicting it (fault ledger item 17).
14. **Sender blank-body gates are load-bearing:** node B `draft_body_gate_passed` (pre-lock) and node O `draft_body_non_empty` (pre-POST, 15th gate) must never be removed or weakened; they mirror node Q's effective-body precedence — if Q's body expression ever changes, both gates change with it (harness P22 enforces).
15. **Ops Console stays powerless:** Stage 1 is local/no-API/no-controls; no session may add network calls, credential inputs, workflow controls, case approval, sending, or any autonomous-ready status to it without explicit owner commissioning of Stage 2 with its own safety review.
16. **CRR discipline:** per-campaign records live in `docs/campaign-readiness/`; an incomplete or unsigned record blocks launch; `bcda01f7-...` is a stale campaign ID — never allowlist it without a new CRR; send-path evidence never carries across Sender versionId changes.

---

## 2026-07-07 07:27 BST — Codex Review: Fable Run 3 Scale Hardening (PASS)

**Agent:** Codex
**Objective:** Review Fable Run 3 cheaply before any Fable Run 4 work. Review-only: no workflow deploy, no production writes, no live email tests, no Sender trigger, no autonomous/Gate 2/Shadow/Ops Console work.

**Baseline used:** branch `codex/5q-context-token-forensic-20260705`; latest Run 3 commit `c558263` (`hardening: close Run 3 scale safety gates`). `git show --stat --oneline c558263` matched the reported Run 3 surface: docs/reports/scripts, HumanApproval export/backup, fresh Sender export; no Decision export change. Initial worktree was already very dirty with many unrelated modified backup/output/archive-style files; nothing was staged. Review treated those as pre-existing and ignored them.

**Checks run:** required git pre-flight; env-var presence check without values; required file reads; `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` -> `463/463 PASS`; `python3 scripts/scan-workflow-exports-for-secrets.py` -> no credential-shaped values found; local workflow metadata parsed from exports; production guard passed; read-only production workflow metadata checked; read-only Review Cases rows checked for `case-e97b60ea` and `case-ea98043d`. No production writes.

**Changed files reviewed:** `OPERATION_HANDOFF.md`; `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`; `docs/SCALE_READY_ACCEPTANCE_GATES.md`; `docs/RUNTIME_PROOF_CHECKLIST.md`; `docs/CAMPAIGN_READINESS_RECORD.md`; the three listed reports; `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`; `scripts/SL-PHASE-5Q-RUN3-apply-ui-visibility-fix.py`; `scripts/scan-workflow-exports-for-secrets.py`; `workflows/production_humanapproval_current.json`; `workflows/production_sender_current.json`; `workflows/production_decision_current.json`. Protected workflow result: Decision unchanged (`84b941a4`), Sender unchanged logically (`dfb310f4`, new export only), Shadow inactive, no autonomous/Gate 2/Ops Console changes found.

**Production read-only verification:** Decision `84b941a4-bc6d-4f48-be27-36dad1510c8d` active and matches local; HumanApproval `99b4c092-d78e-4580-a3c8-46dc65ab00cf` active and matches local; Sender `dfb310f4-901a-4d76-81dc-8f5d4ad13552` active and matches local; Shadow `aHzLtQiv6G8h1bqD` active=false. Production target guard passed before the API reads.

**UI confirmation cases:** owner-confirmed UI evidence was independently row-checked read-only. `case-e97b60ea`: token/review path derivable, non-empty draft, baseline/effective `INFORMATION_REQUEST/PROOF_REQUEST`, `reply_mode=AI_DRAFT_APPROVAL`, `draft_source_raw=ai_supervised`, `ai_attempt.ok=true`, rule `ea15095a`, no fallback mislabel. `case-ea98043d`: token/review path derivable, non-empty draft, baseline `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` -> effective `AMBIGUOUS/NON_PRIORITY`, `reply_mode=AI_DRAFT_APPROVAL`, `draft_source_raw=ai_supervised`, `ai_attempt.ok=true`, rule `6e50fd54`, no fallback mislabel. This closes the Run 3 pending UI confirmation item for Original-vs-Effective / reply mode / AI status visibility.

**Sender/send-path review:** Sender is live-capable for the allowlisted campaign (`DRY_RUN=false`, live campaign allowlist present), unchanged by Run 3, and has pre/post sender/recipient/thread checks, `hmz-send-key`, sidecar acquire/terminal-state idempotency, SEND_UNCERTAIN reconciliation without blind second POST, retry handling for 429/5xx, and terminal handling for 400/401/402/403/404. Known gap is accurately documented: Sender's own live gates do not independently reject blank `draft.draft_text`; blank-body prevention is upstream in HumanApproval Node N (`draft_text_required`). This is acceptable for remaining owner-only controlled live proof, but blocks scale until runtime checklist B1-B5 and duplicate/reconciliation proof are completed or a targeted Sender defense-in-depth patch is explicitly commissioned.

**Risks / uncertainties:** large pre-existing dirty worktree remains; Sender export contains a stale sticky note saying DRY_RUN-only/inactive while executable config is live-capable; live Sender evidence from 2026-06-23 is stale; duplicate replay and SEND_UNCERTAIN reconciliation are code-proven but not live-drilled; S2 rollback drill remains owner-live pending; CRR template has no completed signed campaign record.

**Required owner actions:** complete/backfill Campaign Readiness Record for campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`; perform owner-approved runtime proof on next send using `docs/RUNTIME_PROOF_CHECKLIST.md` B1-B5; run S2 live rollback/deactivation drill; keep Shadow/Gate 2/autonomous/Ops Console untouched until explicitly commissioned.

**Next recommended step:** Human/Fable owner-only live proof actions first. After those are recorded, Fable Run 4 may proceed with autonomous shadow readiness + Stage 1 Ops Console scaffold, still with no Gate 2 approval or autonomous activation unless owner explicitly approves.

**Regression Safety Check:** no Sender trigger, no Instantly POST from this review, no workflow deploy, no production write, no Shadow activation, no Gate 2 approval, no autonomous work, no Ops Console build, no broad archive scan.

---

## 2026-07-07 — Fable Run 3: UI/Reporting Visibility Fix + S1/S-SEND/S5 Scale Gates + Sender Audit (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Absorb the Codex live-row evidence (five cases), fix the proven UI/reporting mismatch, audit S1 supervised gate + Sender/send-path/idempotency (read-only), scaffold S5 multi-campaign gates, and write the permanent anti-regression ledger below.

**Live row confirmation (read-only REST, table `WMTmI6UNjZZgSU3h`, guard passed):** all five rows re-verified. `case-58e6b3b0` (trust → PROOF_REQUEST AI draft, rule ea15095a injected, non-empty summary) PASS. `case-5e2fbcbe` (setup → OFFER_EXPLANATION AI draft, no PROOF hijack) PASS. The three "not-now failures" (`4a5596a0`/`07bd8bb5`/`659d1e01`) are **backend successes**: baseline `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` → effective `AMBIGUOUS/NON_PRIORITY` via rule `6e50fd54`, `reply_mode=AI_DRAFT_APPROVAL`, `ai_attempt.ok=true`, drafts present, `ai_upgrade_eligible=true`. **No classifier/upgrade/style patch was made for these rows — none was needed.** Session 16 S2 work is live-proven.

**Proven UI/reporting defect (fixed — SL-PHASE-5Q-RUN3-UIVIS, HumanApproval nodes J + chat D only):** (a) Google Chat printed "Micro intent: N/A" (fallback chain missed `recommended_action_plan.micro_intent`); (b) review form had no Original-vs-Effective classification display, so top-level baseline `AMBIGUOUS` read as final; (c) correction section labelled the EFFECTIVE micro intent "Original micro intent" (untruthful); (d) no explicit reply-mode / AI-draft-status line. New form/chat content: "Classification corrected by approved learning" block (Original (detected) vs Effective (used for drafting) + applied correction rule ID + warning that top-level category may show baseline), "Reply mode: ... | AI draft status: ..." line (status derived from `draft_source_raw` + `ai_attempt.ok` — fallback can never display as AI success), truthful "Current effective ..." labels, chat "Micro intent (effective)" + correction line + reply mode + "(AI draft passed validation)". Offline proof: patched Node J executed against the REAL case-4a5596a0 row — 11/11 assertions PASS; chat node 6/6.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `0054f20b` | `99b4c092` | Run 3 UI/reporting visibility fix (nodes J + chat D) |

Decision unchanged (`84b941a4`). Backup: `workflows/humanapproval_backup_0054f20b_pre_run3_ui_visibility.json`. Local export refreshed from production post-deploy (versionId verified). Patch script: `scripts/SL-PHASE-5Q-RUN3-apply-ui-visibility-fix.py`.

**Sender read-only audit (S-SEND gate, NOT modified, NOT triggered):** fresh production export captured to `workflows/production_sender_current.json` (Sender `ePS5uBBxKxhFCYgU`, versionId `dfb310f4`, active; the old `03_reply_sender_validation.json` is stale — do not use it as Sender truth). Findings: correct-sender/recipient/thread enforced pre-send (14 gates: workspace/campaign/sender/reviewer allowlists, DRY_RUN flag, lock, suppression, no-prior-terminal-state) AND post-send (`isValidSentEmailObject` verifies eaccount/recipient/subject, rejects unexpected cc/bcc → SEND_UNCERTAIN); `hmz-send-key` marker embedded; duplicates blocked by atomic hmz-send-state acquire + prior-terminal-state gate; SEND_UNCERTAIN terminal (never blindly retried) with reconciliation needing 2 consecutive single matches (zero/multiple → human review); 400/401/402/403/404 terminal, 429/5xx retry max 3 with retry-after cap 5s. **No critical defect → no Sender patch.** Accepted gap (ledger item 11): Sender gates don't re-check non-empty body (enforced upstream in HumanApproval Node N `draft_text_required`).

**Harness:** 463/463 PASS (was 425/425; P21 added 38 tests: the three exact live not-now phrases → NON_PRIORITY + upgrade preconditions; UI-visibility markers + truthful labels; node --check on both patched nodes; Decision invariants unchanged; negative controls booking/pricing/proof/unsubscribe/legal/hostile; never-upgrade protections; no-Instantly-POST). Re-run green against production-refreshed exports.

**New docs/scripts:** `docs/RUNTIME_PROOF_CHECKLIST.md` (runtime source of truth, S1/S-SEND/S2 proof matrix), `docs/CAMPAIGN_READINESS_RECORD.md` (S5 per-campaign launch blocker template), `scripts/scan-workflow-exports-for-secrets.py` (credential-leak scan — PASS 2026-07-07). `docs/SCALE_READY_ACCEPTANCE_GATES.md` updated (S1.4 now PASS on live evidence; new S1.7, S-SEND, S5.7-S5.9). Fault ledger updated (item 11 audit evidence, new item 16).

**Safety envelope:** production guard passed before every API call; Sender untouched/not triggered; no Instantly POST; no live email tests; Shadow `aHzLtQiv6G8h1bqD` inactive (API-confirmed post-deploy); Gate 2 unapproved; autonomous disabled; Ops Console not built.

**Owner actions:** (1) open the next review case + Google Chat message and confirm the new Original-vs-Effective / Reply mode / AI draft status fields render; (2) live rollback drill (S2.6): flip one Q12 rule to `deactivated`, send a probe, restore; (3) on the next approved send, re-prove RUNTIME_PROOF_CHECKLIST B1-B4.

### PERMANENT ANTI-REGRESSION LEDGER (do not regress — details in `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`)

1. **Stale sources:** Never execute from README, old dry-run docs, old prompt packs, old fix packages, archived notes, or stale local exports. `OPERATION_HANDOFF.md` + production-refreshed exports are truth. `03_reply_sender_validation.json` is stale; Sender truth is `production_sender_current.json`. Refresh + commit exports after every deploy (ledger 3).
2. **Wrong target:** Production is `https://n8n.hmzaiautomation.com/api/v1` only. Run `scripts/assert-hmz-production-target.ps1` first. No localhost/Docker unless owner says "local dev" (CLAUDE.md hard rule).
3. **Credentials:** No secrets in files/exports/logs/chat. Run `scripts/scan-workflow-exports-for-secrets.py` in any session touching exports (PASS 2026-07-07). Missing `OPENAI_API_KEY` must stay a truthful `AI_PROVIDER_CONFIG_MISSING` fallback (ledger 2).
4. **Code-node string patches:** Node J syntax crash (session 7) and Node D join literal-newline crash (case-68110963) both shipped from string patching. `node --check` + literal-newline guard are mandatory before any Code-node deploy (ledger 4, 13; P11/P17/P19/P21).
5. **Review render/link invariants:** newest review link only; stale link after SENT blocked (already-sent banner); blocked submits keep the same link + exact reason; valid HUMAN_ONLY/`ai_failed_fallback` cases are REAL reviews, never diagnostic fallback (P13/P14); diagnostic fallback only for genuinely missing context; Google Chat payload must remain well-formed text (ledger 7).
6. **Classification protections:** trust/proof variants (trust/trustworthy/credible/believe/evidence) stay PROOF_REQUEST; NON_PRIORITY promotion blocked on proof/trust replies; PROOF_REQUEST promotion requires trust/proof signal (no hijack of setup questions); booking stays deterministic (no hyper-literal instruction pasting — GAP-1); pricing stays PRICING_REQUEST/HUMAN_ONLY with guidance consumed (GAP-2); not-now dense coverage per P7/P18/P20/P21 (ledger 5, 6).
7. **Upgrade rules:** deterministic/human→AI upgrades ONLY from allowlist {PROOF_REQUEST, NON_PRIORITY, NOT_NOW}, ONLY with ≥1 active form-created style rule for the EFFECTIVE classification; classification correction alone never upgrades; unsubscribe/legal/hostile/suppress/no-reply/pricing/booking never upgrade; NOT_NOW/PROOF fallbacks are non-null (textarea never empty) (ledger 8; P20/P21).
8. **Truthful metadata:** `reply_mode`/`reply_draft_status` must match the real draft; fallback drafts are never labelled AI; "passed validation" requires `ai_attempt.ok===true`; multi-rule injection never claims per-rule impact (attribution stays conservative); active-learning counters must not over- or under-credit (ledger 9, 16).
9. **UI truthfulness (Run 3):** baseline row category must never present as the effective classification; Original-vs-Effective + applied rule + reply mode + AI draft status must stay visible (P21.10-19). The not-now "failure" report was a visibility artifact — check reporting before patching classifiers.
10. **Validator honesty:** style-only rejections (dense paragraph) are reflowed whitespace-only and re-validated, never presented as safety failures; banner names exact failed checks; FORBIDDEN_AI negation-window gaps (10c) stay UNPATCHED until a live case exists (ledger 10).
11. **Send safety:** same sender as inbound, original lead recipient, same thread, non-empty body (enforced at approval), `hmz-send-key` marker, duplicate prevention via send-state lock + terminal-state gate, SEND_UNCERTAIN never blindly retried, reopened-case repeat sends stay manual (S-SEND gate; ledger 11, 12).
12. **Process:** rollback = flip Q12 rule `status` (documented + offline-drilled; live drill pending); old acceptance harness is never sole runtime evidence — `docs/RUNTIME_PROOF_CHECKLIST.md` is; Shadow stays inactive, Gate 2 stays unapproved, autonomous stays disabled without explicit owner sign-off; Ops Console, when commissioned, starts as a local no-API wizard.

---

## 2026-07-07 - Codex Evidence Pass: Live Row Collection Before Fable Run 3 (COMPLETE)

**Agent:** Codex
**Objective:** Read-only live Review Case row evidence collection before Fable Run 3. No patch, deploy, live email test, Sender touch, autonomous work, Gate 2 approval, or Ops Console work.

**Baseline used:** Latest handoff entry `2026-07-07 - Codex Review/Triage: Fable Run 2 S2 Live Retest`; branch `codex/5q-context-token-forensic-20260705`; latest commit before this evidence update `5d3dde6`; latest Fable implementation commit `9ed8aa4`; Decision local export versionId `84b941a4-bc6d-4f48-be27-36dad1510c8d`; HumanApproval local export versionId `0054f20b-2090-41e4-be76-95e8b71921de`; prior harness baseline `425/425 PASS`.

**Env/API checks:** Required git pre-flight run. Production guard passed via `pwsh -File ./scripts/assert-hmz-production-target.ps1` and confirmed `https://n8n.hmzaiautomation.com/api/v1`. Env vars checked without printing values: `HMZ_N8N_API_KEY`, `N8N_API_KEY`, `N8N_API_URL`, and `N8N_BASE_URL` all SET. First sandboxed REST read failed with `Permission denied`; the same read-only production DataTables requests succeeded with approved escalation. Review Cases table `WMTmI6UNjZZgSU3h` was read via n8n REST only. No production writes.

**Files checked:** `OPERATION_HANDOFF.md`, `AGENTS.md`, `workflows/production_decision_current.json`, `workflows/production_humanapproval_current.json`. Workflow metadata matched the baseline versionIds above. No full repo scan.

**Row findings:**
- `case-58e6b3b0`: incoming reply `Anything to establish trust between us and your company?`; original/effective `INFORMATION_REQUEST / PROOF_REQUEST`; draft policy/source `AI_SUPERVISED_OR_TEMPLATE_WITH_FORM_LEARNING` / `ai_supervised_with_form_learning`; reply mode `AI_DRAFT_APPROVAL`; draft present; AI attempted `ok=true`, model `gpt-5.4-mini`, no validation errors, no fallback; active learning found 29, eligible/applied style rule `ea15095a-26f3-4a12-ad2d-ff0fe2d759cc`; no classification correction; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.
- `case-5e2fbcbe`: incoming reply `Mind breaking down what the setup actually is?`; original/effective `INFORMATION_REQUEST / OFFER_EXPLANATION`; draft policy/source `AI_SUPERVISED_OR_TEMPLATE_WITH_FORM_LEARNING` / `ai_supervised_with_form_learning`; reply mode `AI_DRAFT_APPROVAL`; draft present; AI attempted `ok=true`, model `gpt-5.4-mini`, no validation errors, no fallback; active learning found 29, eligible style rules `41a9c35b-f2ad-40a5-ae85-01514f0b869a` and `48e10cac-69a0-4ec7-9c35-42d3675812e6`; no classification correction; `ai_upgrade_eligible=false`, reason `DRAFT_POLICY_ALREADY_AI`.
- `case-4a5596a0`: incoming reply `Not now. Maybe later`; top-level row category remains `AMBIGUOUS`, but original classification `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` was corrected to effective `AMBIGUOUS / NON_PRIORITY`; draft policy/source `AI_SUPERVISED_OR_TEMPLATE_WITH_FORM_LEARNING` / `ai_supervised_with_form_learning`; reply mode `AI_DRAFT_APPROVAL`; draft present; AI attempted `ok=true`, no validation errors, no fallback; active learning found 29; eligible rules `6e50fd54-ff2a-4d5a-b220-c0c7374edea4`, `877c3d75-ad83-4929-a9ae-b910030836e0`, `cdada69d-63a0-471d-801b-3cf3d7ddd1bd`; applied classification rule `6e50fd54-ff2a-4d5a-b220-c0c7374edea4`; style rules eligible/injected but per-rule draft impact attribution remains multi-rule unproven; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.
- `case-07bd8bb5`: incoming reply `I can't right now.`; top-level row category remains `AMBIGUOUS`, but original `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` became effective `AMBIGUOUS / NON_PRIORITY`; same NON_PRIORITY rule path as `case-4a5596a0`; draft present; AI attempted `ok=true`, no validation errors, no fallback; reply mode `AI_DRAFT_APPROVAL`; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.
- `case-659d1e01`: incoming reply `I don't have time right now. Maybe later`; top-level row category remains `AMBIGUOUS`, but original `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` became effective `AMBIGUOUS / NON_PRIORITY`; same NON_PRIORITY rule path as `case-4a5596a0`; draft present; AI attempted `ok=true`, no validation errors, no fallback; reply mode `AI_DRAFT_APPROVAL`; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.

**Exact root-cause hypothesis:** The three alleged not-now failures are not live AI-draft failures and not upgrade failures. They are most likely a reporting/UI expectation mismatch: the row-level `category` remains baseline `AMBIGUOUS`, while the persisted effective classification and review decision path use `AMBIGUOUS / NON_PRIORITY`, apply rule `6e50fd54`, inject NON_PRIORITY draft guidance, and produce successful AI drafts. Root cause bucket: reporting/UI issue. Not supported by live evidence: classifier phrase coverage gap, classification-rule eligibility/scope gap, effective-classification timing issue, upgrade allowlist issue, style-rule absence, or legitimate human-only/block case.

**Exact Fable Run 3 requirements:** Do not spend Fable time patching classifier/upgrade/style coverage for these five rows unless new contrary evidence appears. Fix target should be HumanApproval/reporting visibility if the owner expects the displayed classification to show the effective classification/micro intent and AI attempt status. Harness additions: exact phrases from the three not-now rows must assert effective `AMBIGUOUS / NON_PRIORITY`, `AI_DRAFT_APPROVAL`, `ai_attempt.ok=true`, no fallback, draft present, rule `6e50fd54` applied, and NON_PRIORITY style rules eligible/injected. Add UI/reporting assertions that baseline row category cannot be mistaken for final effective classification. Negative controls: booking/setup, pricing, proof/trust, unsubscribe/legal/hostile/no-reply, and human-only blocked classes must not be swept into NON_PRIORITY or upgraded. Live retests: the three exact not-now phrases above, one known good trust/proof case, one setup/OFFER_EXPLANATION case, one pricing exclusion, and one high-risk/human-only protection case; verify both row metadata and review UI labels.

**Regression safety check:** Sender untouched and not triggered; no Instantly POST; Shadow status not changed from inactive baseline; Gate 2 unapproved; autonomous disabled; no broad rewrites/deletions; no stale README/local dry-run assumptions used. Existing dirty worktree contains many unrelated modified files; this session should commit only `OPERATION_HANDOFF.md`.

---

## 2026-07-07 — Codex Review/Triage: Fable Run 2 S2 Live Retest (PARTIAL — live rows not API-rechecked)

**Agent:** Codex
**Objective:** Review Fable Run 2 / Session 16 cheaply and triage the owner's new live retest results without patching, deploying, touching Sender/autonomous/Gate 2, or running live email tests.

**Baseline used:** Latest valid handoff entry remains Session 16. Branch `codex/5q-context-token-forensic-20260705`; latest commit before this handoff update was `9ed8aa4` (`SL-PHASE-5Q session 16: S2 upgrade engine + PROOF promotion gate + truthful metadata`). Local exports report Decision `84b941a4-bc6d-4f48-be27-36dad1510c8d` and HumanApproval `0054f20b-2090-41e4-be76-95e8b71921de`. `git diff --ignore-space-at-eol` showed no semantic local diff for the current Decision/HumanApproval exports despite line-ending noise on `workflows/production_decision_current.json`. HumanApproval was not changed by commit `9ed8aa4`; Sender was not in the Session 16 changed-file set.

**Checks run:** Required git pre-flight run (`git status --short`, branch, log, `git show --stat --oneline 9ed8aa4`, remote). Read required source files only. Production target guard passed via `pwsh -File ./scripts/assert-hmz-production-target.ps1`. Local harness run with `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` returned `425/425 PASS`; JS syntax checks used the harness static fallback because `node` is unavailable in this shell. No n8n REST row/metadata checks were possible because no n8n/HMZ environment variable names were present; live Review Case rows for the five new case IDs were therefore **not rechecked** from DataTables in this Codex pass.

**Fable Run 2 review verdict:** Session 16 S2 code-level work is locally coherent and harness-green. Decision Node D contains the S2 upgrade allowlist `{PROOF_REQUEST, NON_PRIORITY, NOT_NOW}`, requires at least one active form-created draft/style rule for the effective classification, keeps classification correction alone from upgrading, records `ai_upgrade_eligible` / reason / blocked reason / `effective_classification_used_for_draft_policy`, preserves the PROOF_REQUEST content gate, maps fallback drafts away from AI-labelled success, and emits truthful `decision.reply_mode`. The protected high-risk/no-reply/suppress/pricing/booking branches are covered by P20 and were not broadened in this review. No critical safety defect was found.

**Owner live PASS evidence triage:** Owner reported `case-58e6b3b0` and `case-5e2fbcbe` were correctly classified and received AI drafts. Because DataTable rows were not API-rechecked here, incoming reply text, exact original/effective classification, draft source, AI attempt status, rule IDs, and attribution remain unverified by Codex. At high level, the observation is consistent with Session 16 claims that AI draft paths still work and reply-mode/status truthfulness should now be recorded, but Fable Run 3 should fetch the rows before treating these as closed evidence.

**Owner live FAIL not-now evidence triage:** Owner reported `case-4a5596a0`, `case-07bd8bb5`, and `case-659d1e01` are genuine not-now cases, were not classified as `NOT_NOW` / `NON_PRIORITY`, and did not receive AI drafts. Without row access, the exact incoming text and row metadata are not verified by Codex. Local code strongly suggests the likely failure is upstream classification/eligibility, not the Session 16 upgrade engine: Section B timing coverage includes `not the right time`, `maybe next/in a few`, `circle/check back`, `follow up in/next`, `touch base in/next`, `revisit`, `down the road/line`, and `next quarter/month/year`, but does **not** visibly cover common timing phrases such as `not until ...`, `later in the quarter`, `after ...`, month/quarter names, or `Q1/Q2/Q3/Q4`. Node D's NON_PRIORITY promotion guard only blocks proof/trust hijacks; it does not positively rescue every timing phrase across mismatched source scopes. If these live rows landed in a baseline class other than the existing `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` correction scope, the known rule `6e50fd54` would not apply; no effective `NON_PRIORITY` / `NOT_NOW` means no style-rule match, no S2 AI upgrade eligibility, and therefore no AI draft.

**Exact Fable Run 3 requirements:** Fetch and trace the five new Review Case rows first, especially reply text, baseline classification, effective classification, `learning_attribution`, `ai_attempt`, `reply_mode`, `draft_source`, and `applied_learning_rule_ids`. For the three failing not-now rows, add S2 retest fixes only after row proof: likely patch Decision Section B timing phrase coverage and/or Node D classification-rule eligibility for genuine timing/later language. Add harness tests for each exact live phrase; include negative controls proving booking/setup, pricing/commitment, proof/trust, unsubscribe/legal/hostile/no-reply, and human-only blocked classes do not get swept into NOT_NOW or upgraded. Required live retest after Fable Run 3: the three exact failing not-now phrases plus a known good not-now, setup/booking question, pricing question, proof/trust question, and one high-risk/human-only protection case. Sender must remain untouched unless Fable Run 3 is explicitly auditing Sender safety.

**Regression safety check:** Used Session 16 handoff as latest baseline; did not rely on README/local dry-run assumptions or old templates. No broad repo/archive scan. No production writes, no workflow deploy, no live email tests, no Sender/autonomous/Gate 2/Ops Console work. Existing dirty worktree contains many unrelated pre-existing modified backup/report/output files; this session should commit only this handoff entry.

---

## 2026-07-07 — SL-PHASE-5Q Session 16: S2 Closure — Upgrade Engine + PROOF Promotion Gate + Truthful Metadata (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Close Gate S2. Trace owner-reported live cases `case-64589b37` / `case-269eed7f` / `case-5afa61d3` ("forms remain deterministic/human drafts despite applied learning"), prove exact root causes, patch only what is proven.

**Live trace (production Review Cases DataTable `WMTmI6UNjZZgSU3h`, via REST `/data-tables`; production versionIds verified matching local exports before any change):**
- **case-64589b37** (not-now): learning WORKED — classification rule `6e50fd54` + style rules `877c3d75`/`cdada69d` consumed via `post_processor_delta` with visible draft effect ("When would be a good time to check back in?"). Stayed deterministic because NON_PRIORITY→FIXED_TEMPLATE and the upgrade guard was PROOF_REQUEST-only. Exact blocking predicate: `microIntent === 'PROOF_REQUEST' && draftPolicy === 'HUMAN_ONLY'` + `canTryAI` requiring `AI_SUPERVISED_OR_TEMPLATE`.
- **case-269eed7f** (trust): SUCCESS — real AI-supervised draft (`ai_attempt.ok=true`, zero validation errors) with style rule `ea15095a` injected (applied=1, `ai_prompt_injection`). Defects: empty `learning_impact_summary` for the injection path; row `reply_mode=HUMAN_ONLY`.
- **case-5afa61d3** (setup question): CLASSIFICATION FALSE POSITIVE — active OFFER_EXPLANATION→PROOF_REQUEST correction rules `d82e94d7`/`1dba7933` fired on a reply with zero trust/proof signal (`_5qClassificationRuleAllowedForReply` gated booking and NON_PRIORITY promotions but not PROOF_REQUEST). Trust guidance leaked into a setup answer; stale `reply_draft_status=NO_DRAFT_HUMAN_ONLY` sat next to a real AI draft.
- **All rows** stored `reply_mode=HUMAN_ONLY` because Decision never emitted `reply_mode` (HumanApproval Node A default).

**Fixes deployed (Decision Node D ONLY; HumanApproval untouched):**
1. `SL-PHASE-5Q-S2-PROOF-GATE` — rules promoting to PROOF_REQUEST require a trust/proof signal in the reply. Genuine trust variants still pass.
2. `SL-PHASE-5Q-S2-UPGRADE` — generalized safe deterministic/human→AI upgrade engine. Allowlist: PROOF_REQUEST (from HUMAN_ONLY), NON_PRIORITY and NOT_NOW (from FIXED_TEMPLATE/HUMAN_ONLY). Requires ≥1 active form-created style rule for the EFFECTIVE classification; classification correction alone never upgrades. Unsubscribe/legal/hostile/suppress/no-reply/pricing/booking classes never upgrade (booking deterministic by design). Auditable per case: `ai_upgrade_eligible`, `ai_upgrade_reason`, `ai_upgrade_blocked_reason`, `effective_classification_used_for_draft_policy` in `learning_attribution` (considered/consumed reuse `active_learning_rules_found`/`applied_learning_rule_ids`).
3. New `intInstr` NON_PRIORITY/NOT_NOW AI instructions (acknowledge timing, ONE check-back question, no pitch). AI failure falls back to the non-null NOT_NOW template + post-processing (textarea never empty).
4. `SL-PHASE-5Q-S2-STATUS-SYNC` — `reply_draft_status` flipped only when contradicted by the real draft; NOT_APPLICABLE never rewritten.
5. `SL-PHASE-5Q-S2-REPLY-MODE` — Decision emits `decision.reply_mode` (AI_DRAFT_APPROVAL / FIXED_TEMPLATE_APPROVAL / HUMAN_ONLY / NO_REPLY); case rows now truthful; fallback drafts are never labelled AI.
6. `SL-PHASE-5Q-S2-SUMMARY` — single-rule AI injection now writes a truthful non-empty impact summary; multi-rule stays attribution-uncertain.

**Harness:** 425/425 PASS (was 375/375; P20 added 50 tests: reproductions of all three live cases, upgrade allowlist + every blocked-reason branch, high-risk/unsubscribe/no-reply never-upgrade protections, pricing exclusion, status-sync/reply-mode truthfulness, injection-summary truthfulness, rollback/deactivation offline drill P20.38-40, newer-overrides-older, scope containment, JS `node --check`, no-Instantly-POST). Re-run green against the production-refreshed export. P12.11 updated to recognise the S2 form of the rule-gate (same invariant).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `4474c96a` | `84b941a4` | S2 upgrade engine + PROOF promotion gate + reply_mode/status/summary truthfulness |

**Backup:** `workflows/decision_backup_4474c96a_pre_s2_upgrade_engine.json`. Local export refreshed from production post-deploy (versionId verified matching). HumanApproval unchanged (`0054f20b`). Production guard passed before every API call. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) confirmed inactive via API post-deploy. Gate 2 unapproved. Autonomous disabled. No live email tests run. New reusable script: `scripts/SL-PHASE-5Q-S2-inject-node-code.py`.

**Rollback/deactivation procedure (S2.6):** documented in `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — operator sets a Q12 rule's `status` to `deactivated`/`rejected`/`superseded` (n8n Data Table UI or REST); Decision ignores it on the next case; newer same-scope rules already override older ones. Offline drill proven (P20.38-40); live drill pending.

**Owner action required (manual live test matrix, ~3 emails):**
1. Not-now reply ("This could be useful but not until later in the quarter.") → expect an AI-supervised draft (blue "AI-generated draft" banner) acknowledging timing + ONE check-back question; metadata `ai_upgrade_eligible=true`. If AI fails, the NOT_NOW template with the check-back question must appear (never empty).
2. Setup question ("Before I book, can you give me a quick breakdown of what you set up?") → expect `INFORMATION_REQUEST / OFFER_EXPLANATION` (NOT PROOF_REQUEST) and a setup-steps draft.
3. Trust reply ("I don't know if you are trustworthy.") → expect PROOF_REQUEST AI draft as before, now with a non-empty learning impact summary.
4. Optional S2.6 live drill: set one Q12 rule to `deactivated`, send a matching probe, confirm the rule no longer applies, then restore.

**Do-not-regress rules unchanged:** Do not touch Sender. Do not activate Shadow. Do not approve Gate 2. Do not enable autonomous. Do not start SL-PHASE-5R before the live retest matrix above is complete.

---

## 2026-07-06 — SL-PHASE-5Q Session 15: Dense-Paragraph Fallback Fix + Fault Ledger + Scale Gates (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Trace and repair the remaining blocker (`AI_OUTPUT_VALIDATION_FAILED` / safe-fallback banner too frequent on proof/trust cases); create the complete fault ledger and scale-readiness gates; preserve checkpoint state.

**Checkpoint status resolved:** The 2026-07-05 handoff entry said the push was blocked; verified via `git ls-remote` that branch `codex/5q-context-token-forensic-20260705` and tag `sl-phase-5q-largely-working-20260705` ARE on origin. The uncommitted working-tree changes from sessions 13-14 (afe08974 export, 349-test harness, reports, backups) were committed (`dec5c2f`) and pushed before any new work.

**Blocker root cause (live-proven, exec 5329):** AI provider returned a fully safe, honest, correctly-negated PROOF_REQUEST draft; the ONLY validation error was `active policy violation: dense paragraph` — a style predicate, not a safety predicate. Cause chain: globally-scoped owner style policy `27293ea8` ("short paragraphs", scope `all_ai_drafts`) arms the dense-paragraph check (>360 chars/paragraph) for every AI draft, while `intInstr.PROOF_REQUEST` demanded "One concise paragraph" — the prompt invited exactly the shape the validator rejects. Boundary confirmed: exec 5286 (~336 chars) passed, exec 5329 (~386 chars) failed. The older proof-mention false positive (execs 4976/4980) was confirmed already fixed by session 12 (`asksProof` guard) — current executions 5286/5296 pass it.

**Fixes deployed:**
- Decision Node D `buildAIPrompt`: PROOF_REQUEST instruction now asks for 2-3 short paragraphs (each <300 chars), CTA in its own final paragraph.
- Decision Node D: new `_5qReflowDenseParagraphs` — when validation errors are EXCLUSIVELY dense-paragraph, the draft is reflowed at sentence boundaries (whitespace-only; wording never altered) and the FULL validator re-runs. Any safety error still falls back unchanged. Smoke-tested in Node.js against the exact exec-5329 draft: rejected before, passes after, wording preserved, invented-proof drafts still fail.
- Decision Node D: `ai_attempt` now records `style_reflow_applied` and `raw_draft_text_before_reflow` (truthful metadata).
- HumanApproval Node J: ai_failed_fallback banner now names the exact failed check(s) and states when the rejection was a formatting/style check only, not a content-safety check. Safety wording ("Do not invent proof...") retained.
- Proof safety NOT weakened: invented proof/case studies/testimonials/results/guarantees/pricing still hard-fail (harness P19.11-P19.16).

**Harness:** 375/375 PASS (was 349/349; P19 added 26 tests: exec-5329 regression reproduction, reflow fix proof, wording preservation, safety-not-weakened, banner accuracy, JS literal-newline guards on both patched nodes, no-Instantly-POST check). Re-run green against production-refreshed exports.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `afe08974` | `4474c96a` | PROOF_REQUEST prompt paragraphs + dense-reflow rescue + truthful reflow metadata |
| HumanApproval | `9aPrt92jFhoYFxbs` | `7aac637e` | `0054f20b` | Fallback banner names failed checks; style-only vs safety distinction |

**Backups:** `workflows/decision_backup_afe08974_pre_dense_reflow_fix.json`, `workflows/humanapproval_backup_7aac637e_pre_fallback_banner_detail.json`. Local exports refreshed from production post-deploy (versionIds verified matching). Both workflows remain active. Production guard passed before every API call. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) confirmed inactive via API post-deploy. Gate 2 unapproved. Autonomous disabled. No live email tests run.

**New governance docs:**
- `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md` — 15 fault classes, honest statuses, evidence, false-positive risks, ranked open faults. Notable open item 10(c): FORBIDDEN_AI negation-window gaps (`can't/cannot/won't` missing; post-keyword negation not exempted) — deliberately NOT patched (no live occurrence; do not patch without a live case).
- `docs/SCALE_READY_ACCEPTANCE_GATES.md` — gates S1 (supervised live) through S5 (multi-campaign). S1 effectively open pending fresh trust retest; S3-S5 not met by design; autonomous remains NOT APPROVED.
- New scripts: `scripts/SL-PHASE-5Q-apply-dense-reflow-fix.py`, `scripts/SL-PHASE-5Q-apply-fallback-banner-detail.py`, `scripts/SL-PHASE-5Q-deploy-workflow-update.py` (reusable PUT deploy helper).

**Owner action required (manual live test matrix):**
1. Send a fresh trust/proof reply (e.g. `Ah, I don't know if you are trustworthy.`). Expect: `INFORMATION_REQUEST / PROOF_REQUEST`; an AI-supervised draft in 2-3 short paragraphs (possibly `style_reflow_applied=true` in metadata); NOT an empty textarea; NOT a diagnostic page.
2. If a fallback still occurs, the yellow banner must name the exact failed check(s) — report the named check.
3. Regression: send one OFFER_EXPLANATION setup question — expect short-paragraph/list draft as before.
4. Regression: send one not-now reply — expect NON_PRIORITY NOT_NOW template with check-back question.

**Do-not-regress rules unchanged:** Do not touch Sender. Do not activate Shadow. Do not approve Gate 2. Do not enable autonomous. Do not start SL-PHASE-5R before the SL-PHASE-5Q live retest matrix above is complete.

---

## 2026-07-05 00:00 BST — GitHub Checkpoint / Build Preservation (PARTIAL: LOCAL COMMIT/TAG CREATED, PUSH BLOCKED)

**Agent:** Codex
**Objective:** Documentation and Git/GitHub checkpoint only. Preserve the current largely working SL-PHASE-5Q responder build before any further repair work.

**Current known production version IDs (from handoff/reports, not freshly queried via n8n API):**

| Workflow | ID | Current known versionId | Status |
|----------|----|-------------------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `afe08974-b635-4a56-be42-d005ba7f3520` / short `afe08974` | Latest known trust/proof variant repair deployed |
| HumanApproval | `9aPrt92jFhoYFxbs` | `7aac637e-e57a-44b3-91c4-96b9e4f0d064` / short `7aac637e` | Latest known modern review/scope/default repair deployed |

**Current known status:** Largely working, approximately 97% ready, and should be preserved before more changes. Latest harness reported `349/349 PASS`. Exact proof/trust classification path is mostly working after the trust/proof variant repair. `trust`, `trustworthy`, `credible`, `believe`, and proof/evidence variants were patched into the Decision classifier priority and NON_PRIORITY leakage guard. Sender remains untouched. Shadow Evaluator remains inactive. Gate 2 remains unapproved. Autonomous remains disabled.

**What is working:** Decision and HumanApproval current known versions reflect SL-PHASE-5Q fixes through the trust/proof variant repair. PROOF_REQUEST classification learning and style-rule eligibility are materially improved. Context/token regression was repaired. Review form modern path and fallback taxonomy are documented as repaired in the current handoff/reports. No Sender trigger, no Instantly POST, no autonomous activation, and no Gate 2 approval are recorded for these latest repairs.

**Not yet fully verified:** A fresh live owner retest is still required after the trust/proof variant repair. Production version metadata was not re-queried in this checkpoint session; `scripts/assert-hmz-production-target.ps1` passed, but no n8n API metadata call was made. SL-PHASE-5Q live verification and anti-false-positive audit remain the gating evidence before any autonomous or 5R work.

**Current blocker / next task:** Remaining known issue is `AI_OUTPUT_VALIDATION_FAILED` / safe fallback banner appearing too often on proof/trust cases. Next repair task is to reduce fallback frequency on proof/trust cases without inventing proof, results, guarantees, customer examples, or credibility claims.

**Do-not-regress rules:** Do not regress to older `README.md` or local dry-run project state. Do not touch Sender. Do not activate Shadow Evaluator. Do not approve Gate 2. Do not enable autonomous. Do not start SL-PHASE-5R before SL-PHASE-5Q live verification and anti-false-positive audit are complete. Keep `OPERATION_HANDOFF.md` as the source of truth when it conflicts with README or older docs.

**Files changed in checkpoint session:** `OPERATION_HANDOFF.md`, `README.md`, `CLAUDE.md`, `AGENTS.md`. No application code or workflow logic intentionally changed.

**Git branch:** `codex/5q-context-token-forensic-20260705` before checkpoint; preferred checkpoint branch is `checkpoint/sl-phase-5q-largely-working-20260705`, but branch switch may be skipped because the worktree is already dirty with many pre-existing non-documentation changes.

**Commit / push / tag result:** Documentation checkpoint commit `23b2d48` created with message `checkpoint: preserve largely working SL-PHASE-5Q responder state`. GitHub branch push attempted to `origin codex/5q-context-token-forensic-20260705` and failed because GitHub credentials were unavailable in the agent shell: `fatal: could not read Username for 'https://github.com': No such device or address`. Local annotated tag `sl-phase-5q-largely-working-20260705` created. Tag push skipped because branch push did not succeed.

**Exact next recommended owner/action:** Preserve this checkpoint, then run a fresh live proof/trust retest (`Ah, I don't know if you are trustworthy.`). If classification is `INFORMATION_REQUEST / PROOF_REQUEST` but the safe fallback banner appears too often, start a narrow Decision-only repair session for AI validation/fallback-frequency on proof/trust cases. Do not start autonomous or SL-PHASE-5R first.

---

## 2026-07-05 — SL-PHASE-5Q Trust/Proof Variant Classification-Learning Repair (DEPLOYED)

**Agent:** Codex
**Objective:** Prove and repair why `Ah, I don't know if you are trustworthy.` remained `AMBIGUOUS / NON_PRIORITY` after the owner corrected `case-e6e99b67` to `INFORMATION_REQUEST / PROOF_REQUEST`.

**Root cause (live-proven):** The correction was submitted and stored, but not consumable for the follow-up baseline. `case-e6e99b67` produced correction event row `66` (`approval_decision=approve`, `status=captured_only`, old `AMBIGUOUS/NON_PRIORITY`, corrected `INFORMATION_REQUEST/PROOF_REQUEST`) and active Q12 rows: classification rule `b90ff779-5593-4b02-9a98-6aebd40ef7e8` scoped from `AMBIGUOUS/NON_PRIORITY`, plus PROOF_REQUEST style rule `9f7c332d-651d-4931-bae3-a17ed2caa131`. Follow-up `case-3a05c80c` started as `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY`, so `b90ff779` was not eligible. Older rule `6e50fd54` promoted it to `NON_PRIORITY`, then NON_PRIORITY draft rules `877c3d75` and `cdada69d` generated the wrong check-back draft.

**Fix:** Decision only. Section B now gives trust/proof variants (`trust`, `trustworthy`, `credible`, `believe`, proof/evidence wording) deterministic priority as `INFORMATION_REQUEST / PROOF_REQUEST`. Node D now blocks NON_PRIORITY classification-rule promotion when the reply has trust/proof intent. No proof claims or reply text were hardcoded.

**Harness:** 349/349 PASS (was 326/326; P18 added 23 trust/proof variant, NON_PRIORITY leakage, source-case rule eligibility, attribution, and safety tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `f6d5b731` | `afe08974` | Trust/proof classifier priority + NON_PRIORITY classification guard |

**HumanApproval unchanged** (`7aac637e`). Backup created: `workflows/decision_backup_f6d5b731_pre_trust_variant_fix.json`. Local Decision export refreshed from production. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) confirmed inactive. Gate 2 remains unapproved.

**Owner action required:** Send a fresh `Ah, I don't know if you are trustworthy.` reply. Expected: `INFORMATION_REQUEST / PROOF_REQUEST`; PROOF_REQUEST style learning eligible; no NON_PRIORITY check-back draft.

---

## 2026-07-05 — SL-PHASE-5Q Context/Token Upstream Regression Repair (DEPLOYED)

**Agent:** Codex
**Objective:** Prove why `case-68110963` rendered as `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK` with `Invalid or unexpected token` and all upstream context missing.

**Root cause (live-proven):** Not review-link token validation, case lookup, Google Chat URL corruption, Intake payload loss, or owner/test misuse. Production execution `5263` showed Decision received valid upstream context before Node D (`campaign_id=531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email present, sender `hamzah@teamhmzautomations.com`, subject/reply text present, classifier `INFORMATION_REQUEST / OFFER_EXPLANATION`). Decision Node D then failed before its in-node catch could preserve context and emitted only `{ error: "Invalid or unexpected token " }`. HumanApproval execution `5264` created `case-68110963` from that error-only item, generated a diagnostic fallback identity (`DIAGNOSTIC_MISSING_INTAKE_...`), and stored `context_missing.blocked=true`, `status=HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`, all required fields missing, and `upstream_error="Invalid or unexpected token "`. Review execution `5265` proved `token_valid=true`, `token_invalid_reason=OK`; the token was not the cause.

**Exact code bug:** Decision Node D PROOF_REQUEST fallback branch contained a JavaScript syntax error:
`return _prParts.join('` followed by a literal newline and then `');`. n8n could not compile the Code node, so the workflow-level error output dropped valid Decision/Intake context before HumanApproval.

**Fix:** Decision Node D only — changed the PROOF_REQUEST fallback join to escaped newline source: `return _prParts.join('\\n\\n');`.

**Harness:** 326/326 PASS (was 318/318; P17 added 8 context/token/upstream regression tests, plus Node J syntax check now has a static fallback when `node` is unavailable in the agent shell).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `9198554c` | `f6d5b731` | Node D syntax repair in PROOF_REQUEST fallback join |

**HumanApproval unchanged** (`7aac637e`). Backup created: `workflows/decision_backup_9198554c_pre_context_token_fix.json`. Local Decision export refreshed from production. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) remains inactive. Gate 2 remains unapproved.

**Owner action required:** Send a fresh seeded reply in the existing Instantly campaign thread. Verify Instantly shows campaign ID, lead email, sender email, subject/thread, and reply body before sending. The next review case should no longer be an error-only diagnostic from Node D; it should preserve upstream context and render a normal review form or a legitimate context diagnostic if Instantly truly omits required fields.

---

## 2026-07-05 — SL-PHASE-5Q PROOF_REQUEST AI-Fallback Non-Null Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix the empty textarea for PROOF_REQUEST cases when AI fails after the session 11 eligibility fix.

**Root cause (proven from code):** Session 11 fixed eligibility correctly — the upgrade guard fires and `draftPolicy` upgrades to `AI_SUPERVISED_OR_TEMPLATE` when the style rule from case-a92bb763 is active. AI is called. But when AI output fails validation OR the API call fails, `draftText = fallbackText`. `buildPolicyAwareFallback` had no PROOF_REQUEST branch — it fell through to `return deterministicText` which is `null` (no PROOF_REQUEST entry in `MI_TEMPLATES`). Result: `draftText = null` → empty textarea, `draftSource = ai_failed_fallback`, `aiDraftUsedGuidance = false` (because `draftSource !== 'ai_supervised'`) → draft style rule not counted as applied in `activeLearningRulesApplied` → only classification rule 1dba7933 shown as applied. Evidence: case-9996084f (`AI_SUPERVISED_OR_TEMPLATE / ai_failed_fallback`, found=19, eligible=2, applied=1, empty textarea).

**Fix 1 (Decision Node D — `validateAI`):**
- `asksProof = microIntent === 'PROOF_REQUEST' || /.../.test(prospect)` — ensures `asksProof = true` for PROOF_REQUEST micro_intent.
- Prevents false-positive validation rejection if any active guidance rule contains "do not mention validation unless the prospect asks" (the prospect's "How can I trust you?" doesn't contain the trigger words, so `asksProof` would be `false` without this fix).

**Fix 2 (Decision Node D — `buildPolicyAwareFallback`):**
- Added PROOF_REQUEST branch before the HOW_IT_WORKS/AMBIGUOUS fallback.
- Returns a safe, non-null deterministic fallback: honest proof-gap acknowledgment ("We don't have public customer examples or case studies to point to yet. We're at an early validation stage...") + diagnostic question ("Would that be worth the time?").
- No invented proof, results, guarantees, case studies, or customer examples.
- Human review still required before send.

**Harness:** 318/318 PASS (was 292/292; P16 added: 26 new PROOF_REQUEST AI-fallback, validateAI guard, and safety tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `0e1e1193` | `9198554c` | Node D `validateAI` asksProof guard + `buildPolicyAwareFallback` PROOF_REQUEST branch |

**HumanApproval unchanged** (`7aac637e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. The review form should now show a non-empty draft in the textarea — a safe proof-gap acknowledgment with a diagnostic question. Edit as needed and approve/send or approve for learning. If the textarea is still empty, check the n8n execution log for the specific AI failure reason in `aiAttempt.fallback_reason`.

---

## 2026-07-05 — SL-PHASE-5Q PROOF_REQUEST Draft-Learning Activation Bridge Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix the missing bridge between teaching case (case-532bae78) manual reply + draft_learning_instruction and future PROOF_REQUEST AI-supervised draft generation.

**Root cause:** Style rule from case-532bae78 was written to Q12 (rule count 17→18 confirmed) but was NEVER eligible in `_5qPolicyApplies`. The owner submitted the form without selecting a scope checkbox. Node N fell back to `draft_improvement_scope = "unsure_review_needed"` (default). SL-P2A mapped this to `proposed_rule_scope = "requires_human_scope_decision"` (the else branch). In Decision Node D, `_5qPolicyApplies` returned `false` for this scope → rule not eligible → `activeFormDraftRuleMatches = []` → upgrade guard never fired → PROOF_REQUEST remained HUMAN_ONLY.

**Fix 1 (Decision Node D — `_5qPolicyApplies`):**
- Added fallback for `scope === 'requires_human_scope_decision' || scope === 'unsure_review_needed'`.
- Falls back to `_5qPolicyMicroMatches(policy.micro_intent_scope, cat, mi)` if `micro_intent_scope` is set, else `classification_scope` category match.
- Fixes the existing rule already in Q12 from case-532bae78 (will now be eligible for PROOF_REQUEST cases).

**Fix 2 (HumanApproval Node J — form scope default):**
- Changed `_5qDraftScopes` default for new cases from `["unsure_review_needed"]` to `["current_micro_intent_only"]`.
- The "current_micro_intent_only" scope checkbox is now pre-checked for new cases.
- Future rules get `proposed_rule_scope = "micro_intent"` directly via SL-P2A → no fallback needed.
- Previously reviewed cases with saved scopes are preserved (not overridden).

**Harness:** 292/292 PASS (was 266/266; P15 added: 26 new PROOF_REQUEST draft-learning bridge tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `84e6638e` | `0e1e1193` | Node D `_5qPolicyApplies` unresolvable-scope fallback |
| HumanApproval | `9aPrt92jFhoYFxbs` | `c20af72e` | `7aac637e` | Node J form scope default → current_micro_intent_only |

**No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.**

**Owner action required:** Send another "How can I trust you?" reply to generate a fresh PROOF_REQUEST case. The review form should now show: (1) scope checkbox pre-checked at "current_micro_intent_only"; (2) on subsequent cases, if the existing case-532bae78 style rule is eligible, the upgrade guard should fire and produce an AI-supervised draft using the proof-safety prompt. Human approval still required before send.

---

## 2026-07-05 — SL-PHASE-5Q Valid-Fallback Submit/Reopen Repair (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix `CONTEXT_MISSING_BLOCKED` on submit + diagnostic fallback on reopen for valid `ai_failed_fallback` cases (case-13c3dad3 class).

**Root causes:**
- Node N `rowLooksMissing`: no `isIntentionallyNoDraft` exemption → empty `draft_text` on `ai_failed_fallback` cases triggered `contextMissingBlocked=true` → blocked submit despite valid upstream context.
- Node J `_5q3MissingContext`: included `rc.status === "CONTEXT_MISSING_BLOCKED"` as standalone trigger → after blocked submit set status, reopening showed diagnostic fallback even though `sanitized_context` was intact.
- SL-P2A had same `rowLooksMissing` bug → learning capture skipped for `ai_failed_fallback` cases on valid submits.

**Fix (HumanApproval — Node N + Node J + SL-P2A only):**
- Node N: added `_nIsIntentionallyNoDraft` (mirrors Node A/J) before `rowLooksMissing`; removed `rc.status === "CONTEXT_MISSING_BLOCKED"` from `contextMissingBlocked` (relies on `reply_mode` + `rowLooksMissing`).
- Node J: removed `(rc.status === "CONTEXT_MISSING_BLOCKED")` from `_5q3MissingContext`; `_5q3RowLooksMissing` still catches all genuinely missing context.
- SL-P2A: added `_p2aIsIntentionallyNoDraft` exemption; removed `rc.status` check from context-skip condition.
- Genuine diagnostic invariants preserved: `reply_mode=DIAGNOSTIC_CONTEXT_MISSING`, `ctx.context_missing.blocked=true`, and missing required context fields still always diagnostic.

**Harness:** 266/266 PASS (was 240/240; P14 added: 26 new submit/reopen taxonomy tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `ee2f160e` | `c20af72e` | Node N + Node J + SL-P2A submit/reopen fix |

**Decision unchanged** (`84e6638e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Reopen case-13c3dad3 from the review link. The form should now render normally — yellow AI-failed-fallback banner, empty editable textarea, classification/learning metadata, all modern buttons enabled. Submit a learning-only or save action. Confirm CONTEXT_MISSING_BLOCKED is gone and the case can be re-reviewed. Then send another "How can I trust you?" reply to generate a fresh case and confirm the full render → save → approve cycle works end-to-end.

---

## 2026-07-04 — SL-PHASE-5Q ai_failed_fallback Valid-Review Taxonomy Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix recurring valid-context diagnostic fallback when AI draft validation fails (case-b0cfd04c class: PROOF_REQUEST + AI_SUPERVISED_OR_TEMPLATE + ai_failed_fallback + missing draft_text + valid upstream context).

**Root cause:** Both Node A (`_aIsIntentionallyNoDraft`) and Node J (`_5q3IsIntentionallyNoDraft`) only exempted `HUMAN_ONLY`/`NO_DRAFT`/`human_only`/`none` from the missing-draft check. `ai_failed_fallback` was missing → cases where AI ran but output failed validation (draft_source=ai_failed_fallback, draft_text empty) were flagged as diagnostic fallback despite fully valid upstream context. The `ai_failed_fallback` banner at Node J ~18100 already existed but was never reached.

**Fix (HumanApproval Node A + Node J only):**
- Node A: `_aIsIntentionallyNoDraft` — added `|| _aDraftSourceRaw === "ai_failed_fallback"`.
- Node J: `_5q3IsIntentionallyNoDraft` — added `|| rc.draft_source === "ai_failed_fallback"` and `|| ctx.draft_source === "ai_failed_fallback"` in ctx branch.
- Genuine missing context (campaign, lead_email, sender_email, thread_id, reply_text, UNKNOWN category, missing micro_intent) still triggers diagnostic fallback.

**Review-state taxonomy established:**
- Diagnostic: missing reply_from_email, sender_email, thread_id, reply_text, UNKNOWN category, missing micro_intent — always diagnostic regardless of draft_source.
- Valid human-only: draft_policy=HUMAN_ONLY, draft_source=human_only → exempt.
- Valid ai_failed_fallback: draft_source=ai_failed_fallback → exempt. Existing ai_failed_fallback banner renders (yellow warning, safety constraints, empty editable textarea).
- Valid no-draft: draft_policy=NO_DRAFT, draft_source=none → exempt.

**Harness:** 240/240 PASS (was 216/216; P13 added: 24 new ai_failed_fallback taxonomy tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `c51ac1f3` | `ee2f160e` | Node A + Node J ai_failed_fallback exempt |

**Decision unchanged** (`84e6638e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. The review page must now render normally — yellow AI-failed-fallback banner, empty editable textarea, classification/learning metadata, all modern buttons. If still diagnostic, check n8n execution log for any remaining error in Node A or Node J.

---

## 2026-07-04 — SL-PHASE-5Q PROOF_REQUEST Learned-Draft Pathway (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Allow future PROOF_REQUEST draft-learning rules to generate AI-supervised drafts; keep current HUMAN_ONLY behaviour while only classification correction exists.

**Root cause:** `_5qDraftPolicyFor` (and `draftPolicyFor` in Section B) mapped `PROOF_OR_CASE_STUDY_REQUEST → AI_SUPERVISED_OR_TEMPLATE` but had no `PROOF_REQUEST` entry — default fell through to `HUMAN_ONLY`. After classification correction set `micro_intent=PROOF_REQUEST`, no draft-policy recalculation occurred.

**Fix (Decision Node D only):**
- `const draftPolicy` → `let draftPolicy` (allows in-place upgrade).
- Upgrade guard: if `microIntent === 'PROOF_REQUEST'` AND `draftPolicy === 'HUMAN_ONLY'` AND `activeFormDraftRuleMatches.length > 0`, upgrade to `AI_SUPERVISED_OR_TEMPLATE`.
- `activeFormDraftRuleMatches` includes only `rule_type=style` rules (via `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`). Classification correction rules (`rule_type=classification_correction`) are excluded — classification learning alone does NOT trigger the upgrade.
- Added `PROOF_REQUEST` entry to `buildAIPrompt` `intInstr` map with safety-first instruction (no invented proof/results/customer claims).

**Current state:** Case case-5de97d7a has rule `1dba7933` (classification correction only) → upgrade condition is `false` → PROOF_REQUEST correctly remains HUMAN_ONLY. Upgrade path is ready for future owner-created style rules for PROOF_REQUEST.

**Harness:** 216/216 PASS (was 190/190; P12 section added: 26 new PROOF_REQUEST learned-draft pathway tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `4cb34768` | `84e6638e` | Node D PROOF_REQUEST draft-learning upgrade guard + intInstr |

**HumanApproval unchanged** (`c51ac1f3`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** To enable AI drafts for future PROOF_REQUEST cases, use the review form to create a draft-learning rule with `rule_type=style` and `micro_intent_scope=PROOF_REQUEST`. Once that rule is active in Q12, the upgrade guard will fire and AI-supervised drafts will be generated — human approval still required before send.

---

## 2026-07-04 — SL-PHASE-5Q Node J Syntax Crash Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix live render crash (UNKNOWN at node J) for valid PROOF_REQUEST/HUMAN_ONLY cases after session 6 deploy.

**Root cause:** Session 6 introduced a JavaScript `SyntaxError` in Node J. The comment placement was wrong: `const // SL-PHASE-5Q-PROOF-FIX: ...` (line 59) left an orphaned `const` keyword with no variable declaration — only a comment followed on the same line. Line 61 then declared `_5q3RowLooksMissing = ...` without `const`/`let`/`var`. These two errors together caused n8n to report `UNKNOWN at node J. Render Review Form HTML` for every case, including valid PROOF_REQUEST cases. The session 6 harness (168/168 Python simulation) missed this because it simulates logic in Python and never runs the actual JavaScript.

**Fix (HumanApproval Node J only):**
- Line 59: `const // SL-PHASE-5Q-PROOF-FIX: ...` → `// SL-PHASE-5Q-PROOF-FIX: ...` (removed orphaned `const`)
- Line 61: `_5q3RowLooksMissing = ...` → `const _5q3RowLooksMissing = ...` (added `const` declaration)
- Verified with `node --check`: SYNTAX OK.

**Harness:** 190/190 PASS (was 168/168; P11 section added: 22 new tests including `node --check` JS syntax validation to prevent recurrence).

**Classification learning confirmed (live):** Cases case-d24661f0 and case-3838bcee both showed active learning applied, rule `1dba7933-c38c-4bc1-a7d2-3723af0b2711`, source case-bd8e453e, marker `humanapproval_form_created_learning`, effective classification `INFORMATION_REQUEST / PROOF_REQUEST`. Classification learning is materially evidenced.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `e0e89e0e` | `c51ac1f3` | Node J syntax crash fix (two-line const error) |

**Decision unchanged** (`4cb34768`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. Review page must now render fully — HUMAN_ONLY banner, empty editable textarea, classification/learning metadata, all modern buttons. If blank page persists, check n8n execution log for any remaining error.

---

## 2026-07-04 — SL-PHASE-5Q PROOF_REQUEST / HUMAN_ONLY Review-Path Repair (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix valid PROOF_REQUEST/HUMAN_ONLY cases incorrectly becoming `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`.

**Root cause:** Both Node A (Build Review Case Record) and Node J (Render Review Form HTML) in HumanApproval treated missing `draft_text` as a missing-context indicator. For `HUMAN_ONLY` and `NO_DRAFT` policies, `draft_text` is intentionally absent — no AI draft is generated. This caused valid PROOF_REQUEST cases with complete upstream context (campaign, lead_email, sender_email, thread_id, reply_text all present) to be flagged as diagnostic fallback.

**Patches applied (HumanApproval):**
- Node A: `_aIsIntentionallyNoDraft` guard — skips `draft_text` from `missingContextFields` when `draft_policy ∈ {HUMAN_ONLY, NO_DRAFT}` or `draft_source ∈ {human_only, none}`.
- Node J: `_5q3IsIntentionallyNoDraft` guard — same condition exempts `draft_text` from `_5q3RowLooksMissing`.
- Existing HUMAN_ONLY banner at ~line 17090 in Node J was already correct — it was never reached due to the diagnostic intercept.
- Genuine missing context (campaign, lead_email, sender_email, thread_id, reply_text absent) still triggers diagnostic fallback correctly.

**Harness:** 168/168 PASS (was 148/148; P10 section added: 20 new PROOF_REQUEST/HUMAN_ONLY tests).

**Classification-learning verdict (case-bd8e453e):** PARTIAL. The owner corrected `OFFER_EXPLANATION` → `PROOF_REQUEST` on case-bd8e453e, and follow-up cases ea4350f5/cd2c2eb6 showed `PROOF_REQUEST` classification. This is plausible classification learning but cannot be fully proven without a live rule trace from the DataTable (no rule ID confirmed).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `849c2c64` | `e0e89e0e` | Node A + Node J HUMAN_ONLY draft_text exempt |

**Decision unchanged** (`4cb34768`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. Review page should now show the HUMAN_ONLY banner ("No AI draft was generated because this reply requires human-only handling.") with a text area to write a manual reply — not the diagnostic fallback red error page.

---

## 2026-07-04 — SL-PHASE-5Q Attribution False-Positive Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Audit local attribution patch; fix multi-rule over-credit risk; deploy.

**Root cause fixed:** Local patch credited ALL eligible draft rules when `learningAppliedToDraft=true` via AI prompt injection. If 2 rules were eligible (as in the two-email test), both were counted even if only one could provably influence AI output.

**Fix applied (Node D):**
- Added `aiPromptInjectionSingleRule` / `aiPromptInjectionMultiRule` flags.
- Single-rule AI injection → 1 rule credited, `via: 'ai_prompt_injection'`.
- Multi-rule AI injection → 0 rules credited individually; `learning_attribution_uncertain: true`; `via: 'ai_prompt_injection_multi_rule_unproven'`; reason: `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN`.
- Post-processor delta → all eligible rules credited (observable proof).
- Added `learning_guidance_injected` and `learning_attribution_uncertain` to attribution object.

**Harness:** 148/148 PASS (was 119/119; P9 section added: 29 new attribution false-positive tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `937488a9` | `4cb34768` | Attribution false-positive fix |

**HumanApproval unchanged** (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Run a fresh two-email self-learning test (same OFFER_EXPLANATION path). Expect: if 1 eligible rule → `applied count = 1`, `via = 'ai_prompt_injection'`. If 2 eligible → `applied count = 0`, `attribution_uncertain = true`, reason = `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN`.

---

## 2026-07-04 — SL-PHASE-5Q Learning Attribution False-Positive Check (PATCH READY, PENDING DEPLOY)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Diagnose two-email self-improvement test: applied count = 0 despite apparent second-draft improvement.

**Root cause confirmed:** Attribution bug. `draftTextBeforeActiveLearning` is captured AFTER AI generation (index 62,295) but the learning rule is injected into `buildAIPrompt` BEFORE AI generation (index 57,461). For OFFER_EXPLANATION (AI prompt injection path), the post-processor makes no change → delta = 0 → applied count = 0. The learning IS consumed but is invisible to the delta check.

**Verdict:** Second draft improvement is likely REAL learning. Applied count = 0 is a counter bug, not a false positive.

**Patch written to local file — NOT YET DEPLOYED:**
- `workflows/production_decision_current.json` — Node D: added `aiDraftUsedGuidance` flag; extended `learningAppliedToDraft` to include AI prompt injection path; added `learning_applied_via` field (`'ai_prompt_injection'` vs `'post_processor_delta'`)
- Owner must approve and deploy this patch before it takes effect.

**Files changed (local only):**
- `workflows/production_decision_current.json` — patch written
- `reports/SL-PHASE-5Q_LEARNING_ATTRIBUTION_FALSE_POSITIVE_CHECK.md` — created
- `OPERATION_HANDOFF.md` — this entry

**No production changes applied.** Decision versionId still `937488a9`. HumanApproval unchanged (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator untouched. Gate 2 unapproved.

**Owner action required:** Review patch in `workflows/production_decision_current.json` Node D, then deploy via `PUT /workflows/tgYmY97CG4Bm8snI` or run harness after confirming patch is correct.

---

## 2026-07-04 — SL-PHASE-5Q Decision Classification + GAP-3b Repair (PARTIAL → pending Variant C)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** FIX-1 booking/pricing classification correction; FIX-3 NOT_NOW style rule consumption (GAP-3b).

**Files changed:**
- `workflows/production_decision_current.json` — updated from production (versionId `937488a9`)
- `workflows/nodeD_backup_a3916c2e_pre_5q_session4.json` — backup before patch
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 89/89 → 119/119 (+30 new P7+P8 tests)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — session 4 patches documented
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — session 4 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — session 4 verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `a3916c2e` | `937488a9` | FIX-1 booking regex, FIX-2 pricing regex, FIX-3 GAP-3b NOT_NOW consumer |

**HumanApproval unchanged** (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Root causes fixed:**
- FIX-1: Section B `detectMicroIntent` BOOKING_REQUEST regex didn't match `walkthrough`/`demo`/`tour`/`meeting`. Extended: `book (?:a (?:quick |brief )?)?(time|slot|call|walkthrough|demo|tour|meeting)`. Same fix applied to `_5qReplyHasBookingIntent` in Section D.
- FIX-2: Section B `detectMicroIntent` PRICING_REQUEST regex didn't match `commitment`/`retainer`. Extended with those terms.
- FIX-3 (GAP-3b): `_5qApplyActiveFormRuleInstructionToDraft` had no NON_PRIORITY/NOT_NOW handler. Added: when cdada69d guidance active + "check back/when would be/better time" signal present, replaces "I'll close the loop" with "When would be a good time to check back in?"

**Harness:** 119/119 PASS (was 89/89). P7 (booking/pricing classification 12 tests) + P8 (NOT_NOW style 18 tests) added.

**Remaining:** Owner Variant C live retests required — booking, pricing/commitment, not-now, setup/process regression.

---

## 2026-07-04 — SL-PHASE-5Q Live Regression Repair (PARTIAL)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Repair Node J review form regression; triage Variant B live results; update harness.

**Files changed:**
- `workflows/production_humanapproval_current.json` — Node J restored from 0fa9d0ce lineage; pushed to production
- `workflows/nodeJ_backup_pre_live_regression_repair.json` — backup of 54b7a8e4 Node J before repair
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 66/66 → 89/89 (P5 + P6 sections added)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — created (Variant B execution trace + root causes)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — updated to PARTIAL + session 3 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — updated with session 3 Variant B verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `54b7a8e4` | `849c2c64` | Node J regression repair (modern UI restored) |

**Decision unchanged.** No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Node J regression root cause confirmed:**
Previous session patched Node J using stale `9c71882f` as base instead of modern `0fa9d0ce` lineage. Old `draft_revision_type`, `desired_future_behavior`, and `What should the system do next time?` fields reintroduced. `draft_learning_instruction` field and `Save draft and learning` button lost.

**Node J repair:** Surgically replaced from `agent/codex/sl-phase-5q-checkpoint-20260701` (0fa9d0ce). Modern UI confirmed: `draft_learning_instruction`, `Why did you make this change, and what should the system do next time?`, `Save draft and learning`, `Approved for learning only`. Old fields removed. Other nodes (H, L, N, Q2, SL-P2A) preserved.

**Harness: 89/89 PASS** (was 66/66; added P5 Node J regression + P6 Variant B structural sections).

**Variant B live triage (all cases confirmed against a3916c2e):**

| Case | Exec | Classification | Rule applied | Verdict | Root cause |
|------|------|---------------|-------------|---------|-----------|
| Booking | 4846 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 97eb3b0a | FAIL | AI misclassification |
| Setup/process | 4855 | OFFER_EXPLANATION (correct) | 48e10cac | PASS | — |
| Not-now | 4859 | AMBIGUOUS→NON_PRIORITY (correct) | cdada69d eligible but not consumed | FAIL | GAP-3b: NOT_NOW post-processor gap |
| Pricing | 4865 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 493884ad | FAIL | AI misclassification |

**Remaining gaps requiring next session:**

1. **GAP-3b:** cdada69d post-processing not implemented for NOT_NOW/FIXED_TEMPLATE path. Draft says "close the loop" — needs "when to check back" question. Requires narrow Decision patch to NOT_NOW style rule consumer.

2. **Classification correction for booking/pricing:** Booking walkthrough requests and minimum-commitment questions misclassified as OFFER_EXPLANATION. Recommended fix: add classification correction rules (similar to 6e50fd54 pattern) for BOOKING_REQUEST and PRICING_REQUEST signals within OFFER_EXPLANATION context.

**Recommended next actions (owner):**
1. Verify review form renders modern UI (no `draft_revision_type` dropdown, yes `Save draft and learning` button).
2. Next Claude Code session: patch GAP-3b (NOT_NOW post-processor for cdada69d style guidance).
3. Decide booking/pricing classification fix approach (correction rules recommended).
4. Fresh live retest after Decision patch.

---

## 2026-07-04 — SL-PHASE-5Q Self-Improvement Behavioural Closure (COMPLETE)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Root-cause all self-learning behavioural failures; create harness; patch all 4 gaps.

**Files changed:**
- `reports/SL-PHASE-5Q_BASELINE_EVIDENCE_RECONCILIATION.md` — created (session 1), unchanged (session 2)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — created (session 1); updated to COMPLETE + patch status (session 2)
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — created (session 1); updated post-patch verdicts (session 2)
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — created 44/44 (session 1); updated to 66/66 with P1-P4 post-patch tests (session 2)
- `workflows/nodeD_backup_889e1d45.js` — backup of Decision Node D before patch
- `workflows/nodeD_patched.js` — patched Decision Node D (all 4 gaps, pushed to production)
- `workflows/production_decision_current.json` — updated from production (versionId `a3916c2e`)
- `workflows/production_humanapproval_current.json` — updated from production (versionId `54b7a8e4`)
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `889e1d45` | `a3916c2e` | GAP-1, GAP-2, GAP-3 |
| HumanApproval | `9aPrt92jFhoYFxbs` | `0fa9d0ce` | `54b7a8e4` | GAP-4 |

**No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.**

**Patches applied (Decision Node D, versionId a3916c2e):**

- **GAP-1 (booking post-processor):** `_5qApplyActiveFormRuleInstructionToDraft` now detects `instructionUrl`. If URL present → email-content mode (extract booking link). If no URL and instruction matches constraint pattern (`replace the previous|do not ask|do not say|do not use`) → policy-constraint mode: renders template without pasting instruction meta-phrases as email lines. Eliminates hyper-literal booking draft from 97eb3b0a.

- **GAP-2 (pricing constraints):** New function `_5qApplyPricingConstraints` added to post-processing chain. When `behaviouralGuidance` from rule 493884ad is present (marker check + `do not dodge pricing` signal), replaces the hardcoded evasive pricing paragraph with a per-shown-call / setup-fee pricing line. No invented prices. Pilot line added when guidance mentions "small pilot".

- **GAP-3 (NON_PRIORITY template):** `NON_PRIORITY` added to `_5qDraftPolicyFor` → `"FIXED_TEMPLATE"`. `templateMicroIntent` maps `NON_PRIORITY` → `NOT_NOW`. NON_PRIORITY cases now produce a NOT_NOW template draft (not null), enabling cdada69d style rule post-processing.

**Patch applied (HumanApproval Node J, versionId 54b7a8e4):**

- **GAP-4 (revision reason prefill):** `_5pSavedRevisionReason` variable added. For sent-case reopens (`RESPONSE_APPROVED`/`LEARNING_REVISION_APPROVED`), reads `decision_payload.draft_revision_reason` and prefills the `draft_revision_reason` textarea. New cases and old cases without saved reason start blank.

**Harness: 66/66 PASS** (was 44/44 pre-patch; P1-P4 post-patch sections added).

**Key finding — local Decision file is STALE:**
Local `production_decision_current.json` versionId `e1b84f34` ≠ production `889e1d45`.
Production Decision has 1253-line Node D with full 5Q learning infrastructure (Q12 DataTable lookup, policy matching, classification correction, AI prompt injection). Local file has 393-line stale version.
**Action required: update local workflow export after any future Decision patch.**

**Root causes confirmed:**

1. **Booking hyper-literal (case-7c87d21a):** `_5qApplyActiveFormRuleInstructionToDraft` extracts sentences from `97eb3b0a`'s behavioral specification and pastes them as email content. The instruction contains no URL → booking link is null → draft becomes garbled instruction fragments.

2. **Old booking rule (c9860e74) suppression:** WORKING CORRECTLY via scope deduplication. `97eb3b0a` wins (newer timestamp). Not a bug — the literal application (root cause #1) is the only booking failure.

3. **Pricing no delta (case-d555bcfd):** Rule `493884ad` eligible, guidance built, but `AI_COMMERCIAL_SUPERVISED` branch uses a hardcoded deterministic template that never reads `behaviouralGuidance`. Pipeline gap — guidance built but has no consumer.

4. **Setup/process rule (case-083fe26e):** Rule `48e10cac` eligible, guidance IS injected into AI prompt for OFFER_EXPLANATION (AI_SUPERVISED_OR_TEMPLATE). If "no output delta" was observed, it may be an AI compliance issue (AI ignoring guidance) or a measurement artifact. Not a code injection failure.

5. **Not-now/later → HUMAN_ONLY (case-5fa982f4):** Classification rule `6e50fd54` correctly changes AMBIGUOUS/AMBIGUOUS_SHORT_REPLY → NON_PRIORITY. But `NON_PRIORITY` is not in the draft policy map → defaults to HUMAN_ONLY → `draft_text=null`. Style rule `cdada69d` is eligible but has no pathway to reach the draft.

6. **Reopened form reasons:** Node J doesn't prefill `draft_revision_reason` textarea from case history on reopen. Reply text IS prefilled; reasons are not.

**Harness results:** 44/44 PASS (all rules, leakage tests, safety checks, attribution tests).

**Patches applied:** All 4 gaps patched. See patch detail block above.

**Old/new versionIDs:** Decision `889e1d45` → `a3916c2e`. HumanApproval `0fa9d0ce` → `54b7a8e4`.

**Recommended next actions (owner):**
1. Live test GAP-1: BOOKING_REQUEST case — verify draft has no policy meta-phrases ("Replace the previous", "Do not ask them").
2. Live test GAP-2: PRICING_REQUEST case with rule 493884ad active — verify commercial draft shows setup-fee / per-shown-call wording.
3. Live test GAP-3: AMBIGUOUS/AMBIGUOUS_SHORT_REPLY case with rule 6e50fd54 active — verify NON_PRIORITY classification produces NOT_NOW template draft.
4. Live test GAP-4: Reopen a previously approved case — verify `draft_revision_reason` textarea is prefilled.
5. If all 4 live tests pass → SL-PHASE-5Q VERIFIED COMPLETE. Start SL-PHASE-5R if further self-improvement scope identified.

---

## 2026-07-02 03:13 BST — Codex Strategic Repo Audit

**Agent:** Codex
**Objective:** Read-only strategic audit of current repo status and next highest-leverage task.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this concise audit entry only

**Current status observed:**
- Repo docs are inconsistent by age: `README.md` still describes the older six-workflow dry-run state, while newer docs/reports show a seven-workflow supervised responder, production workflow IDs, self-improvement patches, and autonomous shadow-review preparation.
- Latest repo evidence points to: core supervised responder operating in validation/supervised mode; self-improvement infrastructure installed with remaining behavioural proof for draft-improvement learning; autonomous Gate 2 not approved and blocked by the 14-day shadow review plus owner signoffs/allowlists.
- Worktree has many pre-existing modified files; future sessions should use narrow file scopes and avoid assuming a clean baseline.

**Recommended next task:**
Run the docs-guided, owner-supervised draft-improvement learning behavioural proof from `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md` before further autonomous Gate 2 work. This should be a Claude Code/manual-production-validation session, not a Codex implementation session.

---

## 2026-07-02 02:48 BST — Codex Business Brain Pilot

**Agent:** Codex
**Objective:** Verify that this repo is correctly connected to the HMZ Business Brain and that future Codex sessions can use the correct context without reading the full Obsidian vault.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this timestamped pilot entry

**Files read:**
- `OPERATION_HANDOFF.md`
- `AGENTS.md`
- `README.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_BUSINESS_BRIEF.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_PROJECT_INDEX.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_SOURCE_PRIORITY.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_AGENT_RULES.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\02_PROJECTS\INSTANTLY_RESPONDER.md`

**What was verified:**
- `AGENTS.md` is accurate, concise, and safe for future Codex sessions.
- `AGENTS.md` points to the Business Brain root at `C:\Users\Hamzah Zahid\Projects\hmz-business-brain`.
- `AGENTS.md` explicitly says not to read the full vault by default.
- `AGENTS.md` explicitly says this repo's `OPERATION_HANDOFF.md` takes precedence over Obsidian notes for current execution state.
- The named Business Brain files were read selectively; the full vault was not scanned or edited.

**Current status:** COMPLETE — documentation/control-file review only; no application code, scripts, workflows, configs, credentials, package files, tests, lockfiles, deployment files, or vault files were modified.

**Risks / unknowns:**
- `AI_CONTEXT/AI_AGENT_RULES.md` mentions `AI_CONTEXT/AI_CURRENT_PRIORITIES.md` in its general vault checklist, but this repo's `AGENTS.md` deliberately lists a narrower project-specific allowed set. Future sessions should follow repo instructions and current user instructions first.
- `02_PROJECTS/INSTANTLY_RESPONDER.md` still contains placeholder repo-reference fields and explicitly says not to rely on it for current state. This is low risk because both the repo and `AI_SOURCE_PRIORITY.md` direct agents back to `OPERATION_HANDOFF.md`.

**Recommended next step:**
Proceed with future Codex sessions using `OPERATION_HANDOFF.md`, `AGENTS.md`, and `README.md` first; read only the named Business Brain context files when the task needs business context.

---

## 2026-07-01 — Business Brain Connection

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Connect this repo to the HMZ Business Brain so Claude Code and Codex can access business-wide context safely.

**Files changed:**
- `CLAUDE.md` — added "Business Brain Context" section at end of file
- `AGENTS.md` — created; contains production target rules, safety defaults, source-of-truth table, and Business Brain Context section
- `OPERATION_HANDOFF.md` — created (this file)

**What was done:**
Documentation/control-file update only. No application code, scripts, workflows, configs, tests, package files, or credentials were modified. No vault files were read or edited. No secrets were stored.

**Current status:** COMPLETE — documentation update only; no production changes.

**Risks / unknowns:**
- The vault path `C:\Users\Hamzah Zahid\Projects\hmz-business-brain` has not been verified to exist in this session (per the hard rule against reading the vault without need). An agent reading `AI_CONTEXT/` files for the first time should confirm the path exists before acting on anything found there.
- `AI_CONTEXT/AI_SOURCE_PRIORITY.md` has not been read. Until it is, conflict-resolution between vault and repo files should default to favouring repo files (this file, `docs/SOURCE_PRIORITY.md`).
- `AGENTS.md` is new — Codex or other agents that auto-load it will pick up the vault-path pointer. Verify those agents respect the "read only when needed" rule before running them in this repo.

**Recommended next step:**
If the owner wants to use business-brain context in an upcoming session, open `AI_CONTEXT/AI_BUSINESS_BRIEF.md` and `AI_CONTEXT/AI_SOURCE_PRIORITY.md` at the start of that session to confirm the vault is current, then proceed with the specific task (e.g., campaign copy, offer positioning, or scope decisions).

**Recommended next agent:** Human review first. Then Codex should perform a documentation-only onboarding pass to verify `AGENTS.md` before any implementation task.

---

## Checkpoint — 2026-07-18 16:21 BST — Isolated integration: Instantly Reply → Google Chat Notification (notification-only)

**Scope:** Standalone, notification-only path. Not part of the responder chain. No drafting/approval/classification/sending. VERDICT: **PASS**.

**Created (production):**
- n8n workflow `HMZ — Instantly Reply → Google Chat Notification` — ID `JojqjTVw3KQRtYEN`, **active**, path `hmz-instantly-reply-google-chat-v1`, URL `https://n8n.hmzaiautomation.com/webhook/hmz-instantly-reply-google-chat-v1`.
- n8n credential `HMZ Instantly GChat Inbound Secret` (`Pd9mWMv29ZhLJZdE`, httpHeaderAuth) — header `X-HMZ-Webhook-Secret`; secret only in encrypted credential.
- Instantly V2 webhook `HMZ Google Chat — Prospect Replies` (`019f75ce-f9d4-7a85-9bd9-14059c8c9baf`) — `reply_received`, all campaigns, active, target = the n8n URL above, header `X-HMZ-Webhook-Secret`.
- VPS env var `HMZ_GCHAT_REPLY_NOTIFY_URL` (new, separate from the responder's existing `GOOGLE_CHAT_WEBHOOK_URL`, whose value differs) added to `infrastructure/business-live/.env` + one passthrough line in `docker-compose.hostinger-traefik.yml`; both backed up (`*.before-gchat-notify-*`); `docker compose config` validated; **only** the n8n service recreated; n8n healthy; `hmz-send-state`/`lk2-sidecar`/Traefik unaffected.

**Design:** Webhook(headerAuth) → Validate/sanitise → Dedup(static workflow data, 7d TTL / 5000 cap) → IF → Post to Google Chat → Respond. Link uses the event's exact `unibox_url` (https-validated, never constructed). Prospect text sanitised (HTML stripped, `<`/`>` neutralised to block `<url|text>`/`<users/all>`, ~700 char cap). Task runner blocks `require('crypto')` and `new URL()` — replaced with pure-JS hash + regex URL check.

**Tests (all synthetic, no email sent):** T1 missing auth→403; T2 wrong auth→403; T3 wrong event→200 ignored; T4 missing unibox_url→400; T5 valid→200 notified + exactly one `[TEST]` Google Chat post with `Review reply in Instantly` link (Google returned message resource); T6 replay→200 duplicate_suppressed, no 2nd post. Instantly official `/webhooks/{id}/test`→200 (does not deliver to target; synthetic T5 is authoritative).

**Non-regression:** No pre-existing n8n workflow or Instantly webhook changed/removed; responder Intake intact. `kWZpb8Qt7EqkxIgT` "My workflow" is owner-created (confirmed) — untouched.

**Secrets:** None persisted to repo/Git. Files added: `workflows/HMZ_Instantly_Reply_Google_Chat_Notification.json`, `reports/INSTANTLY_GOOGLE_CHAT_NOTIFICATION_IMPLEMENTATION.md`, `reports/instantly-google-chat-notification-evidence.json`, this checkpoint.

**Owner note:** Live end-to-end from a real Instantly reply was not exercised (would require a real prospect reply). Config is active and correct; the next genuine `reply_received` will post to the dedicated Google Chat space.

---

## Checkpoint — 2026-07-18 19:33 BST — Google Chat Supervised Reply Console (interactive upgrade)

**Scope:** Upgrade of the notification-only path so the owner can write + explicitly approve an Instantly reply from inside a Google Chat thread. Human-written, human-approved sending only. VERDICT: **PARTIAL** (built + deployed + synthetically verified; sending held behind a default-OFF go-live gate; awaiting the manual Google Chat app-config gate and an optional owner-approved controlled live send).

**Backups (passed before any live change):** repo export `backups/n8n/instantly-google-chat-notification-pre-interactive-2026-07-18.json` (SHA-256 `bb3175c7…4a47d`); inactive n8n duplicate `xxOjHdtQFgEcXHMI` (structural hash `013024ca…5382` matches original). Live workflow untouched until verified.

**Created (production):**
- Sidecar `hmz-reply-console-business-live` (image built on VPS) — internal-only (5691), own volume `hmz_reply_console_business_live_data`, on `hmz-instantly-responder_default`. Google OIDC verify (`google-auth-library`, aud=`$GOOGLE_CHAT_INTERACTION_URL`, iss accounts.google.com, identity `chat@system.gserviceaccount.com`) + durable context/draft/one-use-token/atomic-send-state store + **default-OFF go-live gate**. No plaintext API keys. Added `hmz-reply-console` service to `docker-compose.hostinger-traefik.yml` + `HMZ_CHAT_INTERACTION_AUDIENCE` to `.env` (both backed up `*.before-reply-console-20260718T163257Z`); only the new service built/started — n8n and send-state NOT recreated.
- Interaction workflow `HMZ — Google Chat Supervised Reply Console` — ID `G7GIQGt9JOXxITH4`, **active**, route `hmz-google-chat-reply-console-v1`, endpoint == `$GOOGLE_CHAT_INTERACTION_URL`.

**Modified (production):** Notification workflow `JojqjTVw3KQRtYEN` (versionId `8528824e…`→`bef39526…`, still active) — added deterministic thread key + `Create Console Context` + threaded `Post to Google Chat` (`messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD`) + `Attach Chat Post` + reply-instruction line. All prior behaviour (auth, event gate, unibox validation, sanitisation, dedup, error handling) preserved. Instantly webhook `019f75ce…` **unchanged** (all fields identical before/after).

**Tests:** store 23/23; full-server HTTP integration 20/20; live endpoint 401 on missing/malformed bearer; notification Validate dry-run correct; non-regression clean (6 responder workflows active, Shadow disabled, containers not recreated); Instantly POST count 0; secret scan CLEAN.

**Field contract (VERIFIED repo evidence):** `email_id`→`reply_to_uuid`, `email_account`→`eaccount`, `POST /api/v2/emails/reply`.

**Remaining owner actions:** (1) configure the internal Google Chat app (name `HMZ Instantly Reply Console`, HTTP endpoint + audience = `$GOOGLE_CHAT_INTERACTION_URL`, owner-only visibility, add to the existing space; no SA key); (2) confirm visible user/space/thread identifiers to bind; (3) optionally identify an owner-controlled test conversation + type the explicit approval phrase to enable one controlled live send. Reports: `reports/GOOGLE_CHAT_SUPERVISED_REPLY_CONSOLE_IMPLEMENTATION.md`, `reports/google-chat-supervised-reply-console-evidence.json`. Not pushed to GitHub.

### Update — 2026-07-19 ~00:2x BST — V2 delivery diagnosis + owner-authz fix + binding

- **V1 Google project didn't dispatch:** genuine mentions logged Google errors (code 13/3) but multi-layer proof (proven `tcpdump` on :443, n8n executions, sidecar logs) showed the request never reached the VPS; endpoint healthy. Root cause was Google-side app/deployment config. Owner rebuilt a clean **standalone V2 Chat app** (project `hmz-instantly-reply-console`/`547955906917`, HTTP endpoint URL audience) which now reaches the endpoint.
- **Authz bug found + fixed:** the V2 event verified fine (mode `endpoint_url`, `chat@system…`, aud=exact URL) and carried HUMAN `user.email=humza@…`, but the console replied "restricted." Cause: the **n8n container had no `GOOGLE_CHAT_ALLOWED_EMAIL`** so `$env` was empty and the owner-email check failed. Fix: owner authorisation moved into the **isolated sidecar** (durable binding + bootstrap capture; `OWNER_ALLOWED_EMAIL` wired into the sidecar only — no n8n recreate). Interaction workflow now forwards sanitised event identity to the sidecar and uses its binding/bootstrap decision.
- **Owner bound (after explicit confirmation):** stable `user.name users/1138***`, email `hum***@hmzaiautomation.com`, space `spaces/AAQ***` (group; DM `spaces/_5***` ignored). Bound-owner→authorised; impostor(same email, diff user.name)→denied; bootstrap auto-disabled. Store tests 27/27; live endpoint still 401 on missing/malformed tokens. **Send gate still OFF; 0 Instantly POSTs; backups/webhook/responder workflows unchanged.**
- **Verifier** is dual-mode strict (endpoint-URL ID token used by V2; project-number Chat-SA JWT also supported strictly). Sidecar backups on VPS: compose/.env `*.before-owner-authz-<ts>`, `*.before-reply-console-<ts>`, `*.before-verify-dualmode-<ts>`.
- **Next:** exercise the actual reply flow (owner mention in a prospect notification thread → review card → Edit/Cancel), then optionally one owner-approved controlled live send.

---

## Checkpoint — 2026-07-19 ~03:1x BST — Controlled multiline send PASS; 401 + whitespace defects fixed

**Verdict:** CONTROLLED TEST PASS. System remains **PARTIAL / NOT PRODUCTION-ACCEPTED** — global send gate is **OFF**; supervised production sending needs a **separate explicit owner approval**.

**Two acceptance defects found and fixed:**
1. **HTTP 401 on send.** Root cause: the Authorization header was never a valid Bearer — first `$env.INSTANTLY_API_KEY` was missing in the n8n container, then an n8n-API-imported httpHeaderAuth credential didn't execute. Key scope was never the issue (all 3 workspace keys are `all:all`). Fix: **moved the Instantly send into the isolated sidecar** (`performSend`), which forms `Authorization: Bearer <key>` itself from a root-owned `INSTANTLY_API_KEY` env (fingerprint `eb31b16145df`, len 68; never in repo). Verified by a live read-only auth probe → **HTTP 200**.
2. **Whitespace collapse.** Extraction used `.replace(/\s+/g,' ')` → one-line body. Fix: CRLF/CR→LF only, strip mention token only, trim OUTER boundary only; card renders `\n`→`<br>`; email sends exact `body.text` + `body.html`. Proven by 13/13 formatting tests.

**Send architecture (new):** single atomic sidecar `POST /v1/context/:id/send` → side-effect-free validate → scoped go-live gate (arm exactly one context+revision) → atomic APPROVED→SENDING lock → **one** Instantly POST → classify SENT / **FAILED_AUTH_401** / FAILED_SAFE / SEND_UNCERTAIN → finalize. Failed attempts recorded immutably in `context.sendAttempts[]`; a 4xx failure → **RETRYABLE** (needs a fresh draft + fresh token); never silently reset to PENDING. SEND_UNCERTAIN holds the lock (no auto-retry).

**Controlled send evidence:** context `07b1ec10***` (fresh; the earlier 401 attempts stayed on a different context, never reused). Sent `zah***@hmzautomations.com` → `hum***@gmail.com`, existing thread `53-DdSVxV0***`, Instantly email id `019f7821***`, `ue_type=3`. **Exactly 1 Instantly POST**; duplicate Send → `ALREADY_SENT` (0 extra POSTs). Multiline preserved. Gate returned to **OFF + unarmed**.

**Tests:** store 34/34, HTTP 20/20, formatting 13/13, auth regression (missing/malformed/wrong-aud/forged/expired→401; V1 project number 562370690438 now rejected), credential fingerprint match + live 200 probe. Secret scan CLEAN (key value absent from repo). Responder workflows (Intake/Decision/HumanApproval/Sender/SLAWatchdog/ErrorHandler) all active; Shadow still disabled; Instantly webhook `019f75ce…` unchanged; backups preserved.

**Owner decision required before production:** explicitly approve enabling supervised production sending (global gate ON). Until then the console is fully built and controlled-test-verified but sending stays OFF.

---

## Checkpoint — 2026-07-19 ~03:2x BST — Supervised production sending ENABLED (owner-approved)

**State change:** The owner gave explicit approval to enable supervised production sending for real prospects across **all** Instantly campaigns. The console's global send gate is now **ON** (enabled, unarmed) — `note: "supervised production sending — explicit owner approval 2026-07-19, all campaigns"`.

**What this means / does NOT mean:**
- **Supervised, not autonomous.** Every send still requires the owner to: receive a prospect-reply notification, mention @Instantly with the reply text, review the exact outgoing body in the private card, and click **Send**. No reply is auto-generated or auto-sent.
- **Owner-only.** Only the bound owner (`users/1138***`) in the bound space (`spaces/AAQ***`) can operate the console; Google token verification + owner/space authorisation unchanged.
- **All-campaign coverage** is automatic — the existing all-campaign Instantly `reply_received` webhook feeds every campaign's notifications.
- Per-send safety intact: atomic one-POST send, one-use tokens, duplicate-click block, FAILED_AUTH_401/FAILED_SAFE→RETRYABLE, SEND_UNCERTAIN never auto-retried.
- **Unchanged:** the autonomous responder pipeline (Decision/Human Approval/Sender/Q/Shadow/Gate 2) remains exactly as before — this approval applies ONLY to the isolated Google Chat manual console, not to any autonomous sending.

**To pause sending later:** set the console go-live gate back to disabled (`POST /v1/go-live {enabled:false}` on the sidecar) — ordinary notifications continue; only the Send action is blocked.

---

## Checkpoint — 2026-07-19 — Send gate OFF; automatic post-send reconciliation built (false SEND_UNCERTAIN fixed)

**Trigger:** a controlled send showed "Send uncertain (http ?)" but the email WAS delivered. Root cause: `performSend` used a 15s `AbortSignal.timeout`; Instantly's response exceeded it, the client aborted (TimeoutError) AFTER Instantly accepted+sent, the response was lost → generic `http_0` → immediate false SEND_UNCERTAIN. Readback proved delivery (thread `53-DdSVxV0***`, sent email `019f782d***`; exactly one POST). Incident preserved immutably in `reports/false-uncertain-incident-2026-07-19.json` (not reset).

**Phase 0 (done):** global console send gate set **OFF + unarmed**; ambiguous attempt preserved; delivered email preserved; backups/webhook/binding/responder workflows unchanged.

**Reconciliation system (built + deployed):**
- New state machine: `SENDING → {SENT_API_CONFIRMED | FAILED_DEFINITIVE(→RETRYABLE) | RECONCILING}`; `RECONCILING → {SENT_RECONCILED_WEBHOOK | SENT_RECONCILED_READBACK | MANUAL_RECONCILIATION_REQUIRED}`. RECONCILING holds the send-lock and NEVER issues a second POST. Attempt record opened atomically BEFORE the POST; survives restart.
- Authoritative thread stored on context; reconciliation requires `thread_id == stored authoritative thread`; card params never trusted for routing.
- Readback reconciliation: sidecar `GET /emails` (thread+account+sent+timestamp filter); candidate requires thread+sent-type+account+recipient+normalised-subject+timestamp-window+**exact canonical body hash** (text OR html-derived). one→SENT_RECONCILED_READBACK; multiple→MANUAL; none→stay RECONCILING.
- email_sent reconciliation (Phase 4): **new isolated** Instantly `email_sent` subscription `019f7b2f***` (active; reuses existing shared secret; **reply_received UNCHANGED**) → n8n workflow `HMZ — Instantly email_sent Reconciliation` (`0QqQh78lrgOmvByZ`, no send, no Chat notify) → sidecar `/v1/email-sent`; matches only open RECONCILING attempts; duplicate/unrelated/wrong-thread ignored.
- Shared 20/min token-bucket limiter; bounded synchronous readback in the Chat window + durable 30s background sweep (survives restart) escalating to MANUAL after a 6-min window.
- UX: `✅ Sent.` / `✅ Sent — confirmed in Instantly.` / `🟡 Confirming delivery…` with a **Check status** button (no 2nd Send) / `⚠️ Delivery could not be confirmed automatically… Do not resend.`

**Tests:** store+fault-injection **45/45** (incl. response-drop, timeout-after-accept, empty/429 readback, candidate thread/body/account rejection, multiple candidates, HTML-derived match, rate limiter, concurrent-one-POST, window expiry, email_sent match/duplicate/unrelated); HTTP 20/20; formatting 13/13. Every ambiguous case proves **exactly one Instantly POST**.

**State:** send gate **OFF**; key fingerprint `eb31b16145df`; owner bound; three console workflows active; responder workflows unchanged; Shadow disabled; reply_received subscription unchanged.

**Remaining (Phase 10-11):** controlled **forced-response-loss** live test (owner-approved) must reach SENT_RECONCILED with one POST and no manual check; then a **separate** explicit owner production-enable decision. Until then: PARTIAL / NOT PRODUCTION-ACCEPTED.

---

## Checkpoint — 2026-07-19 — Reconciliation CONTROLLED ACCEPTANCE PASS; gate remains OFF

**Two fixes since the false-uncertain build:**
1. **Body matching** — Instantly wraps sent html in a full document (`<!DOCTYPE html>…<title>…</title>…<body>…</body>`, no `text` field), so exact body-hash never matched → stuck RECONCILING → MANUAL (false). Fixed with **structural equivalence**: `htmlToText` strips head/title/style/script/tags; `normalizeForMatch` collapses whitespace; a match requires the reviewed body text to be present in the sent body, plus thread+account+recipient+subject+timestamp (exact-hash fast path retained). Proven against the real stuck send (`019f7b47`) and re-test (`019f7b94`); wrapped-html unit test passes.
2. **Auto-notify** — the sidecar now posts a threaded `✅ Sent — confirmed in Instantly.` (or the MANUAL warning) via the one-way incoming webhook (no app auth), from the **async** paths only (email_sent webhook + 30s background sweep); the synchronous Send/Check-status card shows the result itself. A one-off double-post (sync card + sync-reconcile notify) was fixed by removing notify from the synchronous reconcile paths.

**Phase 10B forced-response-loss live test — PASS:** fresh context `6112f6fb***`, recipient `jun***@gmail.com` (owner-confirmed), sending account `ham***@onehmzautomations.com`, thread `53-2n2k64r***`. Injected `drop_response` (genuine POST completes, response discarded) → attempts `RECONCILING(RESPONSE_PARSE_FAILURE)` → `SENT_RECONCILED_READBACK(019f7b94)`. **Exactly one POST**; **auto-confirmed** (no manual check); duplicate Send blocked (0 extra POSTs); gate returned **OFF**.

**Tests:** store+fault-injection **46/46**, HTTP 20/20, formatting 13/13. State survives restart (durable files + background sweep). Responder workflows unchanged; reply_received subscription unchanged; email_sent subscription `019f7b2f***` + workflow `0QqQh78lrgOmvByZ` active (isolated, no send/notify of its own beyond confirmation).

**Verdict:** CONTROLLED ACCEPTANCE PASS. **PARTIAL / NOT PRODUCTION-ACCEPTED** — global send gate **OFF**; enabling supervised production sending requires a **separate explicit owner decision**.

---

## Checkpoint — 2026-07-20 — Reliability & observability programme (Phases 0-10); send gate OFF

**Phase 0 (safe state):** send gate set OFF (unarmed); reply notifications kept active; fresh sanitised backups of all 3 workflows (`backups/n8n/*-pre-reliability-2026-07-20.json`, hashed) + sidecar config snapshot + VPS compose/.env; inactive n8n duplicates created + **verified** (notification `qWgBDwfjtfvSRcdM`, supervised-reply `lxsVZHNNQCYUvj6N`, email-sent `AcZzig5JJkKcIVEt`, all inactive, structural hashes matched); `reply_received` subscription unchanged.

**Reliability contract (two SLOs):** (A) Inbound — 99.99% of applicable prospect replies reach CHAT_NOTIFIED, no reply silently disappears. (B) Supervised send — >=99.99% of POST attempts reach a clear success/definitive-failure without manual investigation, MANUAL <=0.01%, no auto second POST. Honest scope: proves Instantly acceptance + thread presence, NOT external inbox delivery.

**Built + deployed (all tested):**
- **Dual-path inbound (Phase 2):** `HMZ — Inbound Recovery Poll` (`7LNeDYVaEbuZ4fpO`, active, 1-min) → sidecar `/v1/poll-recover`: lists recent Instantly *received* emails with a rolling high-water-mark + overlap, dedups by Instantly email id, recovers+notifies any missing genuine reply (DISCOVERED_READBACK); auto-replies/bounces skipped. First live run: scanned 1, recovered 0, alreadyPresent 1 — correct dedup, **no flood**.
- **Notification state machine (Phase 3):** DISCOVERED_* → CHAT_NOTIFIED | CHAT_POST_AMBIGUOUS | CHAT_POST_FAILED_DEFINITIVE; 2xx+message-name ⇒ notified; ambiguous never silently marked notified. Documented limitation: incoming-webhook can't read Chat history, so a post-accept response loss is a rare unavoidable ambiguity.
- **Watchdog (Phase 4):** `HMZ — Reliability Watchdog` (`5nSbIHky9dQaJvd9`, active, 5-min) → sidecar `/v1/watchdog` (unresolved notifications, poll heartbeat freshness, Instantly API 401/429/5xx). Sanitised alert (no bodies/credentials/raw IDs) to an ops thread via the incoming webhook AND persisted at `/v1/watchdog`. Never sends prospect emails.
- **Name enrichment (Phases 5-7):** prospect names from reply_received `First_name`/`Last_name` (WEBHOOK) or exact lead lookup (ambiguous⇒no pick); sender names from the Instantly Account for the exact eaccount (durable 6h cache, fails-closed for send eligibility, never suppresses inbound). Never inferred from local part/display/company/body/signature. Shown in notification, review card, edit review, and named success receipt (Prospect/Sender/Subject/Confirmation/Time London+UTC).
- **Telemetry (Phase 9):** append-only JSONL (no bodies/names/emails/creds); `/v1/report` gives numerator/denominator/% + latency p50/p95/p99/max. **Truthful**: never claims "99.99% achieved" below 10,000 events; reports "0 unresolved out of N" at low volume.

**Tests:** 101 total — store/fault-injection 46, HTTP 20, formatting 13, enrichment 15, recovery 7. Covers webhook-missing→readback recovery, webhook/poll race dedup, duplicate webhook, auto-reply skip, name first-only/last-only/none/ambiguous, account both/absent/missing/inactive, and all send-fault cases (one POST max).

**State:** send gate **OFF**; responder workflows (Intake/Decision/HumanApproval/Sender/SLAWatchdog/ErrorHandler) unchanged/active; Shadow disabled; secret scan CLEAN; Instantly key never in repo.

**Verdict:** RELIABILITY PROGRAMME BUILT. **PARTIAL / NOT PRODUCTION-ACCEPTED** — 99.99% is a TARGET (sample < 10,000, not statistically demonstrated). Remaining: live controlled acceptance (webhook-path + poll-recovery + name correctness on owner fixtures), then a **separate explicit owner production-enable decision**.

---

## Checkpoint — 2026-07-20 — GLOBAL supervised sending ENABLED (owner-approved, mid-acceptance)

**State change:** During Phase 11 controlled acceptance, the owner explicitly instructed "open the system for global use." Global supervised send gate set **ON** (enabled, unarmed, no fault-inject). Owner bound `users/1138***`; Instantly key fingerprint `eb31b16145df`; health ok. Supervised (per-send human review + Send click), all campaigns.

**Acceptance status at enable time:**
- **A (webhook fast-path): PASS** — real jun reply → one context, CHAT_NOTIFIED, source WEBHOOK, latency 1186ms, names correct (Noah Cole / Hamza Moheen), owner visually confirmed.
- **B (missed-webhook recovery): PASS** — webhook suppressed (exec 10032, no Post), poll recovered via readback (source DISCOVERED_READBACK), one recovery notification, correct names, thread resolved, latency 44.3s, hwm advanced, delayed-webhook dedup, owner visually confirmed.
- **C (Chat response-loss): PASS** — CHAT_POST_AMBIGUOUS (not false CHAT_NOTIFIED), watchdog detects, telemetry records, no storm, honest exact-once limitation documented, no send.
- **F (definitive failure + exhaustion): PASS 7/7** — mocks, no send, POST≤1, named exceptional message with prospect/sender + "no second email" + link, no "http ?" jargon.
- **D (normal send): interrupted by a Google Chat MOBILE dialog limitation** — the Edit dialog ("Could not load dialog. Invalid response returned by app") does not render on the Chat mobile app; each Edit created a new revision, invalidating prior Send tokens ("superseded by an edit" — correct safety behaviour, no email sent, 0 attempts). Body reached the intended value (revision 4). The owner then chose to enable global sending to proceed. **Send/Cancel (plain buttons) work on mobile; only dialogs (Edit) do not.** Mobile-edit workaround: reply @Instantly again in the thread with corrected text (creates a fresh revision, no dialog).
- **E (forced response-loss send): the underlying capability already PASSED earlier this session** (context 6112f6fb → SENT_RECONCILED_READBACK, one POST, auto-confirm) and is covered by 46 store fault-injection tests; not re-run in the scripted D/E sequence.

**Known limitation flagged:** Google Chat mobile app does not reliably render interactive dialogs → Edit is unreliable on mobile (desktop web/app fine). Documented; reply-again workaround available. Not a send-safety issue.

**Reconciliation/thread fix:** webhook `reply_received` payloads omit `thread_id`; added `ensureThreadId` (resolves + persists thread from `reply_to_uuid` at send time) so webhook-originated sends can auto-reconcile. Recovery path already gets thread_id from readback.

**Tests:** 108 total (store 46, http 20, formatting 13, enrich 15, recovery 7, acceptance-F 7). Responder workflows unchanged/active; Shadow disabled; secret scan clean; Instantly key not in repo.

**To pause sending:** `POST /v1/go-live {enabled:false}` on the sidecar (notifications continue; only Send blocked).
