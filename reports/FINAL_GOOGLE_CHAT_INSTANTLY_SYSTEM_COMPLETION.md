# Final Google Chat ↔ Instantly System Completion

**Run date:** 2026-07-22
**Verdict:** **SYSTEM COMPLETION PASS**

## Production epoch
Formal console production notification epoch: **`2026-07-18T18:33:00Z`**
(`INBOUND_NOTIFICATION_EPOCH`). The live notification guarantee applies to every
Instantly-visible inbound email received from this epoch onward. Records predating
it are archival, remain held (`HISTORICAL_OWNER_HOLD`), and are outside the live
contract by owner decision.

## Final production image
`hmz-reply-console:codex-cardstate-20260722-r11`, healthy. Deployed source hashes
(read back from the running container):
- `inbound-contract.mjs` `a1561d00cdf507da8e2cee5a7a864bfb4b2656e51dc2e31eea6ebd22e7059ad8`
- `inbound-service.mjs`  `e3f7d88e49878f7508089d517bdde10bf8e1c5ede44e9b19cd704d8f0f15d770`
- `store.mjs`            `c55490cb5a7a7d3f72504602f0d70b9e57555a306221a53a2a2307e8d88c571b` (historical guard)
- `inbound-store.mjs`    `82ba0caed9fbe90d477213a5a7e73812c23dfd756a8cfcf9dc34235ef54b2868`

## Global supervised-send record — unchanged
`enabled:true`, note unchanged, `at:2026-07-20T02:39:57.377Z`, `armedContextId:null`,
`armedRevision:null`, `faultInject:null`. Canonical SHA-256
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522` — byte-for-byte
identical before and after every action in this closure.

## Inbound — production-epoch reconciliation (read-only)
Instantly received `2026-07-18T18:33:00Z` → readback `2026-07-22T01:46:55Z`:
- Instantly received observed: 51 (2 pages), **missing inbound: 0**, **missing outbox: 0**.
- Durable post-epoch: **inbound 54 / outbox 54 / CHAT_NOTIFIED 54** (durable is a superset
  of the instantaneous scan; zero records lack a durable notification).
- queued 0 / posting 0 / retrying 0 / ambiguous 0 / duplicate logical identities 0.
- **Every mature Instantly-visible identity in the production epoch is `CHAT_NOTIFIED`.**

Global durable state at closure: 987 inbound / 987 outbox; 682 `CHAT_NOTIFIED`
(40 legit pre-incident + 628 accepted incident-artifact historical + 14 later live);
305 `HISTORICAL_OWNER_HOLD`; 0 queued/posting/retrying/ambiguous.

## Outbound — controlled sends (consolidated)
Both approved Google Chat sends used server-authoritative routing (recipient, eaccount,
Instantly thread/`reply_to_uuid`, latest revision/body from durable state; Chat action
supplies only `{reviewToken, bodyHash}`), each with exactly one Instantly POST.

**Send A (F1, unedited):** recipient `alinazahidkhan890@gmail.com`; eaccount
`hamzah@hmzautomation.com`; thread `86-1-WxpS69xd1JM68kPWij0FP`; `reply_to_uuid`
`019f86f7-bf57-7e73-b248-9822c12d9e77`; revision 1; body hash
`18735e408c85da06182520541d19c96c49aa90cde98a9fa90e16e1d88576c18c`; POST count 1;
terminal `SENT_API_CONFIRMED`; stale re-click → `NO_ACTIVE_DRAFT`, 0 extra POST.
Owner inbox confirmation PROVIDED: exactly one reply in `alinazahidkhan890@gmail.com`,
correct From/subject/thread/body; `humzaabbas1357@gmail.com` did not receive it.

**Send B (F2, edited):** recipient `humzaabbas1357@gmail.com`; eaccount
`hamzah@gethmzautomation.com`; thread `86--eKozl7_zFmnRANH1W_NNdN`; `reply_to_uuid`
`019f86f8-18ed-7b91-b27e-4a5b7b20149f`; revision 2 (edited; rev 1 stale, never sent);
body hash `c816afc4e619e29bb682688d9a406b3b703bc9af75f2920f9775f450abeb6772`; POST count 1;
terminal `SENT_API_CONFIRMED`; duplicate click + server replay → `NO_ACTIVE_DRAFT`/409,
0 extra POST. Owner inbox confirmation PROVIDED: edited body in `humzaabbas1357@gmail.com`
only; `alinazahidkhan890@gmail.com` did not receive it.

Distinct recipients, distinct eaccounts, distinct threads. Total Instantly POSTs across
both approved sends: **2** (one each). Duplicate/stale actions: **0** additional POSTs.

## Accepted scale/burst evidence (not repeated)
- Production burst: 15 distinct identities → 15 inbound / 15 outbox / 15 definite acks.
- Exact-image 100,000-record workload: 100k unique + 100k duplicates + 100k races;
  10k auto/OOO; 10k bounce/system; 15k malformed/degraded; 5k empty/attachment-only;
  0 missing inbound / 0 missing outbox / 0 permanently unnotified; full outage-backlog recovery.

## Operations health
Sidecar healthy; SQLite quick_check ok; 0 FK violations; watchdog `alertCount 0`;
recovery poll fresh; short/deep/daily auditors fresh; reply_received (Notification v2
Durable) and email_sent Reconciliation workflows ACTIVE; no active historical
release/drain process; no historical backlog competing with live traffic.

## Fixture waiver
F3 (auto/OOO), F4 (unsubscribe), F5 (empty/attachment-only) were **cancelled and waived
by the owner** as redundant/unnecessarily production-mutating. Their behaviour is covered
by the deployed implementation and permanent tests (`test-ooo-and-card.mjs`,
`test-card-state.mjs`, `test-inbound-v2.mjs`, exact-image scale suite).

## Known internal limitations (non-blocking)
- **Auto/OOO classification precision (LOW):** labelling depends on Instantly's
  `is_auto_reply` flag or a phrase set (broadened in r10 to include "out of the office").
  A genuine auto-reply with other wording and no `is_auto_reply` may label `ordinary`.
  Completeness is unaffected (still notified); safety is unaffected (nothing auto-sends).
  No open HIGH or MEDIUM defect.

## External limitations
Google Chat and Instantly are external providers; future provider outages or API changes
cannot be statistically precluded. The durable outbox retries with bounded backoff and the
watchdog surfaces stranded items; this is the strongest defensible internal guarantee.

## Rollback
Verified backups: `pre-r11-deploy-20260722T012742Z` (and pre-r8/r9/r10). Prior images
r7/r8/r9/r10 retained; compose backups `…yml.pre-r{8..11}.bak`. r7
(`94dd2dcb…`) remains a full rollback target.

## Remaining owner action
**NONE — continue supervised production operation and monitor.**
