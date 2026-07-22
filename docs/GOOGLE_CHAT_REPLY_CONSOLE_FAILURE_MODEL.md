# Google Chat Reply Console — Failure Model

Complete failure-mode inventory for the HMZ Google Chat supervised Instantly reply console, produced during the July 2026 independent FABLE audit. Each mode states: trigger, detection, and system behaviour (never a claim of impossibility — only what is actually enforced and where the honest limits are).

## State machine (authoritative)

```
PENDING → APPROVED → SENDING → SENT_API_CONFIRMED               (terminal, delivered)
                             → RECONCILING → SENT_RECONCILED_WEBHOOK   (terminal, delivered)
                                           → SENT_RECONCILED_READBACK  (terminal, delivered)
                                           → MANUAL_RECONCILIATION_REQUIRED (terminal, needs human check)
                             → FAILED_DEFINITIVE → RETRYABLE          (no delivery; fresh draft required)
PENDING/APPROVED/RETRYABLE → CANCELLED / EXPIRED
```

This graph is enforced by a single table (`ALLOWED_TRANSITIONS` in `store.mjs`) — no code path outside that table can move a context between states. `RECONCILING` always holds the send lock and can never re-POST.

## Inbound failure modes

| Trigger | Detection | Behaviour |
|---|---|---|
| Webhook never fires (Instantly delivery issue, network blip) | Scheduled recovery poll (every 1 min) | Poll lists recent received emails via readback and recovers any missing one, tagged `DISCOVERED_READBACK` |
| Webhook and poll both see the same reply | Dedup on Instantly email id (primary key across both paths) | Exactly one context, one notification |
| Duplicate webhook delivery | Deterministic context key + `open('wx')` atomic dedup file | Second and later deliveries return the existing context, no duplicate notification |
| Recovery-poll item missing a required field (`eaccount`/prospect email/id) | **Fixed 2026-07-20 (audit finding F1).** Telemetry event `inbound_readback_invalid_skipped` + best-effort raw Chat notification + watchdog alert `readback_invalid_items` | Never silently dropped; surfaced for manual routing even though it can't be auto-created as a context |
| Auto-reply / bounce | Subject/from-address heuristic in `isAutoReply()` | Correctly skipped, not treated as an applicable reply |
| Instantly list API returns 429/5xx/network error mid-poll | Poll returns `ok:false` and does **not** advance the high-water mark | Next scheduled run retries the same window; no item is silently excluded by a partial-page failure |
| n8n/VPS restart during a poll pass | High-water mark only advances after a full pass completes | Restart resumes from the last durably persisted mark plus its overlap window |

## Google Chat authorisation failure modes

| Trigger | Behaviour |
|---|---|
| Missing/malformed/forged/wrong-audience/wrong-issuer/expired bearer token | `401`, no state change (verified live against production) |
| Correctly signed token but the event's HUMAN identity doesn't match the bound owner (same email, different stable user resource) | Denied — authorisation is on the stable `user.name` resource, never on display name or email alone |
| Non-HUMAN (bot) event | Denied |
| Correct owner, wrong Chat space | Denied |
| No owner bound yet, gate is ON | Denied outright — bootstrap capture is only permitted while sending is globally OFF, so a mid-flight binding can never be silently established while live sends are possible |

## Edit / draft failure modes

| Trigger | Behaviour |
|---|---|
| Two edits submitted concurrently | Monotonic revisions; exactly one ends up active; the other's token is structurally unreachable (superseded) |
| Send clicked on a stale (superseded) card | `STALE_CARD` — no POST — the **latest** revision is surfaced with a fresh token instead of a dead end |
| Edit submitted while a Send is in flight | Rejected with `SEND_IN_PROGRESS`; the in-flight send always completes with the body that was actually reviewed, never a later unreviewed edit |
| Dialog fails to open (Chat mobile app limitation) | Documented, non-safety-affecting; workaround is to reply again in-thread instead of using the dialog |
| Body tampered between review and click (shouldn't be reachable via the UI, defensive check exists) | `BODY_TAMPERED`, blocked before any POST |

## Send / reconciliation failure modes

| Trigger | Behaviour |
|---|---|
| Duplicate Send click (double-tap, or old+new card race) | Exactly one acquires the lock; the other gets `LOCK_ALREADY_HELD` or a stale-token response; exactly one POST |
| Instantly returns 4xx | `FAILED_DEFINITIVE` → `RETRYABLE`; no delivery occurred; a fresh draft + fresh token is required to try again — the failed context is never silently reset to `PENDING` |
| Instantly returns 5xx, or a timeout/reset/parse-failure occurs | `RECONCILING` — the one POST that was actually sent is never resent; the sidecar performs bounded synchronous readback within the Chat response window, then a durable 30-second background sweep (survives restart) for up to 6 minutes |
| The genuine POST completes but the response is lost entirely (process/network failure between send and reply) | Same `RECONCILING` path; readback matching (thread + account + recipient + normalised subject + timestamp window + structural body match) resolves it automatically once Instantly's own record is queryable |
| `email_sent` webhook arrives for an open `RECONCILING` attempt | Matched and finalised as `SENT_RECONCILED_WEBHOOK`; duplicate or unrelated `email_sent` events are ignored (matched only against currently-open attempts on the same authoritative thread) |
| Reconciliation window (6 min) exhausted with no match, or multiple ambiguous candidates found | `MANUAL_RECONCILIATION_REQUIRED` — terminal, lock held, clearly worded exceptional message naming the prospect/sender, explicitly stating no second email was attempted |
| VPS/sidecar restart while `SENDING` or `RECONCILING` | The attempt record was written **before** the POST, so a restart never loses visibility of an in-flight send; a re-click after restart is refused (`SEND_IN_PROGRESS`), never re-POSTed |

## Notification-delivery honest limitation

The initial prospect-reply notification uses a Google Chat **incoming webhook** (one-way, no read access to Chat's own message history). This is an architecture-level constraint, not a bug:

- A 2xx response **with** a returned message name is the only case marked `CHAT_NOTIFIED`.
- A 2xx response **without** a message name, or any transport failure after Google has already accepted the post, is marked `CHAT_POST_AMBIGUOUS` — visible to the watchdog, never silently reported as delivered.
- **No applicable Instantly reply can silently vanish** from the durable ledger or the watchdog even in this case — the underlying context and telemetry record always exist; only the *notification confirmation* is honestly ambiguous, not the record of the reply itself.

## Watchdog coverage

The watchdog (`/v1/watchdog`, checked every 5 minutes) currently detects: unresolved notifications older than 5 minutes, a stalled or never-run recovery poll (>10 min), Instantly API 401/429/5xx, and (as of the July 2026 audit) unroutable readback items. Alerts are both posted to an ops Chat thread **and** persisted/queryable independently at `/v1/watchdog`, so a Chat-transport outage does not make alerts fully invisible.

## Known, accepted, non-safety limitations

- Google Chat mobile app does not reliably render the Edit dialog (`OPEN_DIALOG`/`SUBMIT_DIALOG`); Send/Cancel plain buttons work fine on mobile. Workaround: reply again in-thread instead of using Edit.
- 38 historical prospect replies (2026-07-06 through 2026-07-18, before the console's context-creation capability existed) are not in the durable ledger; a bounded, dry-run-by-default tool now exists to backfill them on explicit owner request (see the operator runbook).
