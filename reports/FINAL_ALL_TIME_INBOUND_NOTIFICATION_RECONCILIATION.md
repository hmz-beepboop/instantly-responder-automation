# Production-Epoch Inbound Notification Reconciliation

*(Renamed from "Final All-Time Inbound Notification Reconciliation" for honesty: the operative
contract is the production epoch, not all-time history.)*

**Final result (2026-07-22): PASS.**

## Production-epoch contract
- **Production notification epoch: `2026-07-18T18:33:00Z`** (established console go-live epoch).
- The live notification guarantee applies to every Instantly-visible inbound email received from
  this epoch onward: one durable inbound identity, one outbox identity, one definite Google Chat
  acknowledgement, final state `CHAT_NOTIFIED`.
- Records predating the epoch are **archival**, remain held (`HISTORICAL_OWNER_HOLD`), and are
  **outside** the live contract by explicit owner decision. They are never posted to Google Chat.

## Production-epoch reconciliation (read-only, 2026-07-22T01:46:55Z)
| Measure | Value |
|---|---:|
| Instantly received observed [epoch → readback] | 51 |
| Missing durable inbound | 0 |
| Missing durable outbox | 0 |
| Durable inbound (post-epoch) | 54 |
| Durable outbox (post-epoch) | 54 |
| `CHAT_NOTIFIED` (post-epoch) | 54 |
| queued / posting / retrying / ambiguous | 0 / 0 / 0 / 0 |
| duplicate logical identities | 0 |

Durable is a superset of the instantaneous Instantly scan; **every Instantly-visible post-epoch
identity is `CHAT_NOTIFIED`** with zero gaps. Global durable state: 987 inbound / 987 outbox;
682 `CHAT_NOTIFIED`; 305 `HISTORICAL_OWNER_HOLD`; 0 mature queued/posting/retrying/ambiguous.

## Why historical records remain held
Per owner decision (2026-07-21/22), "every Instantly email" means new inbound from the production
epoch onward — not all-time. The 305 pre-epoch records (267 from the 2026-07-21 mis-post incident +
38 original owner holds) stay `PRE_EPOCH_HISTORICAL_HOLD` permanently: never released, never posted,
non-actionable (data quarantine + r9 server-side historical guard). The 628 notifications that were
mis-posted during the incident are accepted as incident artifacts (acknowledgements preserved,
non-actionable, excluded from live reliability statistics). No historical release/drain process is
active.

---

## Historical record retained below (all-time scan, 2026-07-21) — no longer the contract

The original all-time 973/895/38 analysis is preserved for provenance only.

## Authorized continuation status — 2026-07-21 06:37 UTC

The owner explicitly authorized this exact manifest and all 895+38 historical
notifications. The release implementation and exact r8 image passed 158/158,
and a fresh verified rollback backup was created. Production execution was
then blocked by the Codex allowance before deployment. Consequently, the table
below remains the current production truth: 895 are still unregistered, all 38
holds remain held, and no historical Chat post has yet occurred. This section
supersedes the owner-decision wording at the end of this report; it does not
supersede the counts or the NO-GO verdict.

## Authoritative readback

The production sidecar queried Instantly directly with `email_type=received`,
ascending full pagination, page size 100, and the explicit range
`2000-01-01T00:00:00.000Z` through `2026-07-21T05:20:00.000Z`. This was a
read-only dry run. It returned 973 items on 11 pages and 973 unique normalized
Instantly identities. The authoritative identity-set SHA-256 is
`38d9530da608f7d51cdf5bb3eca6d66fdb3f3564e2b0c49b1b36e5a111cf536a`.

| Measure | Count |
|---|---:|
| Instantly received identities | 973 |
| Durable inbound identities | 78 |
| Logical outbox identities | 78 |
| Definite `CHAT_NOTIFIED` acknowledgements | 40 |
| `HISTORICAL_OWNER_HOLD` | 38 |
| Missing durable inbound and outbox identities | 895 |
| Extra durable identities absent from Instantly inventory | 0 |
| Queued / posting / retrying / ambiguous | 0 / 0 / 0 / 0 |
| Duplicate logical identities / duplicate Instantly IDs | 0 / 0 |

The 895 missing records span `2026-01-15T14:45:41.000Z` through
`2026-07-05T06:20:05.000Z`. The 78 represented records are the later bounded
inventory previously reconciled. Therefore the earlier 78-record conclusion
was valid for its queried period but was not an all-time reconciliation.

## Missing inventory distribution

| Month | Missing |
|---|---:|
| 2026-01 | 32 |
| 2026-02 | 141 |
| 2026-03 | 552 |
| 2026-04 | 1 |
| 2026-06 | 121 |
| 2026-07 through 5 July | 48 |
| **Total** | **895** |

| Classification | Missing |
|---|---:|
| ordinary | 817 |
| automatic | 28 |
| out-of-office | 26 |
| unsubscribe | 24 |
| **Total** | **895** |

These counts are presentation classifications only. Every one of the 895 is
an authoritative Instantly received identity under the final contract.

## Exact historical-38 precondition

The previously identified set remains internally consistent:

- exactly 38 rows are in `HISTORICAL_OWNER_HOLD`;
- all 38 are present in the authoritative Instantly inventory;
- none has a Chat acknowledgement or acknowledgement timestamp;
- none has a notification-attempt row;
- no duplicate logical identity exists.

The release precondition nevertheless fails because 895 additional
authoritative records outside that set are unacknowledged. The owner explicitly
limited Phase 2 authorization to exactly the 38 and required a stop if any
record outside them was unacknowledged. Accordingly, zero holds were released,
zero new inbound/outbox rows were created, and zero Chat posts were made.

## Safety state

The global-send file remained byte-for-byte unchanged at SHA-256
`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`.
The sidecar remained on r7 and healthy. No prospect reply POST, campaign,
lead, account, workflow activation, draft, token, Shadow, Gate 2 or autonomous
change occurred.

The all-time scan briefly consumed the shared Instantly read quota. One normal
poll received HTTP 429 and the next scheduled poll succeeded. A genuine
watchdog cycle at `2026-07-21T05:20:56.179Z` then cleared the transient alert;
the queue remained zero and active-alert count returned to zero.

## Required owner decision

The run cannot safely continue under the existing authorization. The owner
must explicitly authorize durable registration and rate-limited individual
historical notification of the additional 895 identities, in addition to the
verified 38 holds, or provide contradictory authoritative evidence that those
895 IDs are outside the covered workspace. A date-based exception would not
satisfy Final Contract A.
