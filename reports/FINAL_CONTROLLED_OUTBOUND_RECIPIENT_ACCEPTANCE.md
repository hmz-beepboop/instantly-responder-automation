# Final Controlled Outbound Recipient Acceptance

**Status:** **PASS** (2026-07-22)

Two owner-approved controlled Google Chat sends were executed on the real console
(r11) using the real @Instantly workflow (mention → Review card → Send). Both used
server-authoritative routing (recipient, eaccount, Instantly thread/`reply_to_uuid`,
latest revision/body loaded from durable state; the Chat action supplies only
`{reviewToken, bodyHash}` and cannot override routing/body). No genuine prospect was
contacted — both recipients are owner-controlled test inboxes.

## Send A — unedited (F1)

| Field | Value |
|---|---|
| Intended recipient | `alinazahidkhan890@gmail.com` (owner-controlled) |
| Sender mailbox (eaccount) | `hamzah@hmzautomation.com` (display: Hamza Moheen) |
| Instantly thread | `86-1-WxpS69xd1JM68kPWij0FP` |
| reply_to_uuid | `019f86f7-bf57-7e73-b248-9822c12d9e77` |
| Revision sent | 1 |
| Body SHA-256 | `18735e408c85da06182520541d19c96c49aa90cde98a9fa90e16e1d88576c18c` |
| Instantly POST count | **1** |
| Terminal state | `SENT_API_CONFIRMED` |
| Stale/duplicate replay | `NO_ACTIVE_DRAFT` → **0** extra POST |
| Owner inbox confirmation | **PROVIDED** — one reply in `alinazahidkhan890@gmail.com`, correct From/subject/thread/body; `humzaabbas1357@gmail.com` did not receive it |

## Send B — edited (F2)

| Field | Value |
|---|---|
| Intended recipient | `humzaabbas1357@gmail.com` (owner-controlled) |
| Sender mailbox (eaccount) | `hamzah@gethmzautomation.com` (display: Hamza Moheen) |
| Instantly thread | `86--eKozl7_zFmnRANH1W_NNdN` |
| reply_to_uuid | `019f86f8-18ed-7b91-b27e-4a5b7b20149f` |
| Revision initial / sent | 1 / **2** (edited; rev 1 became stale and was never sent) |
| Body SHA-256 (sent, rev 2) | `c816afc4e619e29bb682688d9a406b3b703bc9af75f2920f9775f450abeb6772` |
| Instantly POST count | **1** |
| Terminal state | `SENT_API_CONFIRMED` |
| Stale/duplicate replay | UI duplicate → `NO_ACTIVE_DRAFT`; server replay (stale rev-1 + empty) → HTTP 409 `NO_ACTIVE_DRAFT`; **0** extra POST |
| Owner inbox confirmation | **PROVIDED** — edited (rev 2) body in `humzaabbas1357@gmail.com` only; `alinazahidkhan890@gmail.com` did not receive it |

## Totals & guarantees
- Distinct recipients, distinct eaccounts, distinct Instantly threads.
- **Total Instantly reply POSTs across both approved sends: 2** (exactly one each).
- Duplicate/stale actions: **0** additional POSTs.
- No wrong-recipient / wrong-sender / wrong-thread / wrong-revision delivery observed.
- Global supervised-send record byte-for-byte unchanged
  (`611f5d6e14b5f860432ae4a4d913e680898bbfef565dcaefe051bf2582754522`).

## Server-authoritative routing verification (code + tests)
`store.mjs performSend` builds the Instantly `POST /emails/reply` body solely from
`acq.routing` (durable context + approved draft): `eaccount`, `reply_to_uuid`, subject,
body. Chat input carries only the one-use token + body hash (validated against the stored
draft; tamper → `BODY_TAMPERED`). Latest-revision-only enforced; stale cards → `STALE_CARD`;
acquire-lock permits at most one POST; cross-context requires `armedContextId` match;
ambiguous results enter `RECONCILING` and never re-POST. Covered by `test-store.mjs` (49/49)
and the fault-injection suite in the r11 image.
