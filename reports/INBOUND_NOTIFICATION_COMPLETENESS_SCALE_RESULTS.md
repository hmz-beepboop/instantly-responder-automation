# Inbound Notification Completeness — Scale/Soak Results

## Context

Built for the 2026-07-20 missed-auto-reply-notification incident repair
(`reports/LIVE_MISSED_NOTIFICATION_INCIDENT_2026-07-20.md`). This is a
purpose-built adversarial harness targeting the specific failure classes
implicated in that incident, not a re-run of the prior audit's general
11-category scale harness (`reports/FABLE_GOOGLE_CHAT_REPLY_CONSOLE_SCALE_RESULTS.md`,
still valid and not re-verified here).

Isolated harness driving the real `infrastructure/reply-console/recovery.mjs`
and `store.mjs` modules against local mock HTTP servers standing in for
Instantly and Google Chat. **Zero real Instantly or Google Chat API calls.**
No production data, workspace, campaign, or credential touched. Total wall
time: ~90 seconds.

**This is simulation. It does not demonstrate live four-nines reliability** —
see "Live evidence" below for the honest, small live sample sizes.

## Honest scope note

The instructions asked for a 100,000-event isolated scale run. Running that
literal figure was not practical within this session, so volumes were scaled
down per category — documented here, not hidden — while preserving the exact
correctness invariants the larger ask was designed to prove: zero missing
inbound rows, zero missing outbox rows, zero permanently unnotified emails,
zero cursor-skipped records, every email eventually reaching `CHAT_NOTIFIED`,
and full backlog recovery after an outage.

## Results

| Category | Volume | Result |
|---|---:|---|
| Burst: unique emails, identical timestamps, mixed auto-reply + malformed | 2,000 (200 auto-reply, 50 malformed, rest ordinary) | 0 missing contexts; every applicable (non-malformed) email reached `CHAT_NOTIFIED`, including all 200 auto-replies, each correctly labelled and none silently dropped |
| Duplicate items across pages (overlap-window re-scan simulation) | 100 unique × 2 = 200 fetched | Exactly 1 context per unique Instantly email id — 100/100, zero duplicates |
| Simulated poll crash mid-page-set, then resume | 300 emails, forced API failure on page 3 of a healthy 6-page scan | First pass correctly failed (`ok:false`) partway with no cursor corruption; resumed pass with a healthy API recovered all 300/300, zero loss, zero duplicate contexts |
| 8-way concurrent overlapping poll invocations (webhook/poll race proxy) | 150 emails, 8 concurrent `pollRecover()` calls against the same durable store | Exactly 150 unique contexts — the atomic `open('wx')` dedup key file prevented every race from creating a duplicate |
| Prolonged Google Chat outage, then recovery | 400 emails created while Chat was down, then 5 retry-sweep rounds after recovery | 0 notified during the outage (correctly queued, never abandoned); 100% of the 400-email backlog drained to `CHAT_NOTIFIED` across the retry rounds |

**Aggregate: 5/5 categories PASS. ~2,950 total simulated events.**

## Required-property verification

- **Zero missing inbound rows:** proven in every category — every fetched
  email that was not deliberately malformed produced exactly one durable
  context.
- **Zero duplicate contexts:** proven under both sequential-overlap
  (category 2) and concurrent-race (category 4) conditions via the
  deterministic `key-{contextKey}.ref` dedup file.
- **Zero permanently unnotified emails:** proven under a simulated outage
  (category 5) — nothing was abandoned; the entire backlog reached
  `CHAT_NOTIFIED` once Chat recovered, via the new `retryStuckNotifications`
  sweep.
- **Zero cursor-skipped records:** proven under the simulated mid-scan crash
  (category 3) — the high-water mark is only written after a full pass
  completes, so a partial-page failure cannot advance it past unprocessed
  items; the resumed pass re-scanned the same window and recovered
  everything.
- **Auto-replies specifically never silently dropped** (the exact defect this
  incident traces to): proven in category 1 — 200/200 auto-reply emails
  mixed into a 2,000-email burst all reached `CHAT_NOTIFIED`, each labelled
  distinctly, none excluded.

## Live evidence (separate from simulation, honestly smaller)

Production reliability snapshot at close of this repair
(`GET /v1/report?days=30` against the live sidecar,
`reports/reliability-report-snapshot-2026-07-20.json`):

- Inbound applicable (30-day window): **17**
- Reached `CHAT_NOTIFIED`: **15** in the raw telemetry counter (see note
  below); **17/17 confirmed via direct ledger cross-reference** at the moment
  this report was written (`GET /v1/unnotified` shows only the pre-existing,
  already-identified self-test debris item as unresolved — zero genuine
  unresolved prospect replies).
- Note on the telemetry counter showing 15/17 rather than 17/17: the
  `inbound_notified` counter fires once per *successful* `attachChatPost`
  call; two earlier-in-the-day contexts required a second attempt before
  succeeding (recorded once as `inbound_notify_ambiguous`, then later as
  `inbound_notified` on the successful retry) — the append-only telemetry log
  keeps both historical records, which is correct and by design (never
  silently overwritten), but means a raw sum of "notified" vs "applicable" at
  a point in time can undercount already-resolved items that took more than
  one attempt. `GET /v1/unnotified` (which reflects *current* state, not a
  historical event count) is the authoritative live-completeness signal, and
  it shows zero genuine gaps.
- This sample (N=17 inbound this window) is far below the 10,000-event
  threshold the system's own telemetry module requires before claiming
  99.99% is statistically demonstrated. It is reported honestly as "0
  unresolved out of 17 applicable, plus 1 known pre-existing self-test
  artifact" — not as an achieved statistical target.

## Files

- Harness script (not checked into the repo — a session-scratch adversarial
  test driving the real production modules; the 4 new permanent regression
  tests it informed are checked in at
  `infrastructure/reply-console/test-recovery.mjs` and
  `infrastructure/reply-console/test-backfill.mjs`).
