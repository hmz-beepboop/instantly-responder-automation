# Final Live Acceptance Packet — 2026-07-21

**Status:** PREPARED. **Nothing in this packet has been triggered.** No live fixture or outbound
send will run until the owner replies with the exact phrase:

`APPROVE FINAL CLOSURE: MIXED INBOUND FIXTURES AND TWO CONTROLLED GOOGLE CHAT SENDS`

Formal production notification epoch: **`2026-07-21T16:55:20.330Z`**. Live server image:
**`hmz-reply-console:codex-historical-guard-20260721-r9`** (`ed5d416a`), healthy. Global-send gate
`611f5d6e…4522` (enabled, unchanged). Historical set (305 held + 628 accepted) is permanently
non-actionable (data quarantine + r9 code guard).

## Pre-packet outbound-safety verification (server-authoritative routing) — PASS

Confirmed by code (`store.mjs performSend` / `acquireSend`) + targeted tests (`test-store.mjs` 49/49
and `test-historical-guard.mjs` 13/13, both in the r9 image):

| Property | Evidence |
|---|---|
| recipient (`reply_to_uuid`), `eaccount`, thread, `subject`, `body` come from **durable server-side state** | POST body built from `acq.routing` (stored context + approved draft), not from the request (`store.mjs:848-861`) |
| Google Chat action params cannot override routing/body | request carries only `{reviewToken, bodyHash}`; `bodyHash` is validated against the stored draft; tamper → `BODY_TAMPERED` |
| only the latest revision can send | one-use token bound to the active draft revision; older token → `TOKEN_MISMATCH` → `STALE_CARD` |
| stale cards fail closed | `performSend` → `STALE_CARD` recovery, never sends the stale click |
| duplicate/concurrent clicks → at most one POST | `acquireSend` lock (`EEXIST`→`LOCK_ALREADY_HELD`) + `SENDING` + `SENT` terminal (never resettable) |
| cross-context token fails closed | send requires `go-live.armedContextId === thisContext`; else `SEND_DISABLED_WRONG_CONTEXT` |
| ambiguous send reconciles without re-POST | `RECONCILING` state never re-POSTs (fault-injection suite) |
| historical records can never send/draft/token/arm | r9 guard → `HISTORICAL_NON_ACTIONABLE` at every chokepoint (13/13) |

## Owner inputs required (owner-controlled only)

Provide before approval (or I will use these slots): sending mailboxes (eaccounts) in the HMZ
Instantly workspace `A_EACCOUNT`, `B_EACCOUNT`; owner-controlled recipient inboxes `RECIP_A`,
`RECIP_B`; the campaign/account used to surface inbound; and confirm you can read `RECIP_A`/`RECIP_B`.

## A. Mixed-category inbound fixtures (owner-controlled senders only)

For each, the owner sends an email that Instantly will expose as `received`; expected result =
one individual, correctly-labelled Chat notification, `CHAT_NOTIFIED`, correct Instantly link.

| # | Category | How to generate (owner-controlled) | Expected Chat label | Send control |
|---|---|---|---|---|
| F1 | Ordinary reply | reply with normal text | ordinary reply | Review/Draft enabled (live) |
| F2 | Automatic / OOO | reply with an auto-reply/OOO body | `🤖 Automatic/Out-of-Office Reply` | none (acknowledgement-only) |
| F3 | Unsubscribe | reply "unsubscribe" | unsubscribe/opt-out | none (suppress) |
| F4 | Empty / attachment-only | reply empty body or attachment only | empty/attachment-only | none |
| F5 | Bounce / system | only if safely generatable and Instantly exposes it as received | bounce/system | none |

Each fixture carries a unique subject marker `HMZ-FIXTURE-<F#>-<nonce>`. Categories that cannot be
safely manufactured live retain the exact-image synthetic + scale evidence already on file; provider
events will NOT be faked in production.

## B. Controlled Send A — unedited

- Recipient: `RECIP_A` (owner-controlled) · Sending mailbox: `A_EACCOUNT` · Instantly thread: the
  authoritative thread from A's inbound (`reply_to_uuid` from durable state).
- Body: the exact latest reviewed draft revision (server-authoritative).
- Flow: latest Review card → owner clicks Send once → **≤ 1** Instantly `POST /emails/reply`.
- Verify: exact recipient/eaccount/thread/subject/body; owner confirms receipt in `RECIP_A`; no
  decoy/wrong inbox received it; replay the old action → **0** additional POST.

## C. Controlled Send B — edited

- Recipient: `RECIP_B` (different, owner-controlled) · Sending mailbox: `B_EACCOUNT` (different) ·
  different thread where possible.
- Flow: open Edit (no mutation) → save exactly one new revision → old revision becomes stale →
  latest edited Review card → owner clicks Send once → **≤ 1** POST.
- Verify: exact edited final body/revision; owner confirms receipt in `RECIP_B`; no wrong inbox;
  invoke the stale (pre-edit) action → **0** additional POST.

## Safety invariants during acceptance
No genuine prospect contacted (owner-controlled addresses only); global-send record stays
byte-identical; historical set stays non-actionable; one POST maximum per approved send;
duplicate/stale actions create zero extra POSTs.

## STOP
Awaiting the exact owner phrase above. On approval I will execute only these owner-controlled
fixtures/sends, then return the final verdict.
