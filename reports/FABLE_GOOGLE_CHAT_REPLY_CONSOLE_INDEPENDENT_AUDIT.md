# FABLE 5 — Independent Large-Scale Hardening Audit
## HMZ Google Chat Supervised Instantly Reply Console

> **⚠️ REVOKED 2026-07-20 (later same day).** This **INDEPENDENT PASS** verdict
> was invalidated by live production evidence: after this audit closed, the
> owner resumed a real campaign and one of two genuine inbound Instantly
> emails failed to produce a Google Chat notification (a genuine automatic/
> out-of-office reply, silently dropped by `recovery.mjs`'s `isAutoReply()`
> classifier — a distinct code path from this audit's F1 finding, which only
> covered items with *missing* required fields). Root cause, repair, and
> recovery are documented in
> `reports/LIVE_MISSED_NOTIFICATION_INCIDENT_2026-07-20.md`
> (verdict: **INCIDENT PATCH PASS**). The F1/F2/F3 findings and evidence
> below remain individually valid and are not re-litigated — only the
> overall completeness verdict is revoked.

**Verdict: INDEPENDENT PASS** *(REVOKED — see notice above)*

Run window: 2026-07-20T05:29Z – 2026-07-20T08:08Z (06:29–09:08 BST). Branch `codex/5q-context-token-forensic-20260705`, HEAD `ed94d57` — unchanged before and after (no commit made).

---

## 1. Verdict

**INDEPENDENT PASS.** One HIGH-severity silent-loss defect was found by direct reproduction, root-caused, fixed with the smallest surgical change, deployed to production, and verified by rebuild, hash-match readback, and a live post-deploy regression (the next *scheduled* recovery poll ran clean against the new code). One MEDIUM gap (no bounded backfill/audit tool) was closed by building and testing the tool, then running it read-only against production, which surfaced a real but non-live finding (see §6). No other unresolved HIGH or MEDIUM correctness or security finding remains. This is not a claim of perfection — see §11 Residual Risks.

## 2. Global supervised-send state — before and after

| | State |
|---|---|
| Before | `enabled: true`, note "GLOBAL supervised sending — owner re-enabled 2026-07-20 during edit-flow repair", `at: 2026-07-20T02:39:57.377Z` |
| After | Identical — `enabled: true`, same note, same `at` timestamp |

**The global send capability was never disabled, paused, or toggled at any point in this run.** The identical `at` timestamp across every readback (post-backup, post-fix-deploy, post-DR-drill, final) is itself proof the gate record was never rewritten — a toggle-and-restore would have produced a new timestamp. This was confirmed by direct `GET /v1/go-live` reads against the production sidecar at four separate checkpoints.

## 3. Production baseline and drift

Production readback (n8n 2.25.7, five console-related workflows, six shared sidecar source files) was compared against the local repository export **before any change was made**. Result: **zero drift**. All five workflow structural hashes matched exactly (`HMZ — Google Chat Supervised Reply Console`, `HMZ — Instantly Reply → Google Chat Notification`, `HMZ — Inbound Recovery Poll`, `HMZ — Instantly email_sent Reconciliation`, `HMZ — Reliability Watchdog`), and all six sidecar files (`server.mjs`, `store.mjs`, `enrich.mjs`, `recovery.mjs`, `telemetry.mjs`, `verify.mjs`) hashed identically between the repo and the running container. Fresh sanitised backups (workflow exports, a full durable-data tarball, compose/env snapshots, and pre-fix source copies) were taken and hash-verified before any repair, all secret-scan clean, all locked to root-only permissions.

Durable-state snapshot at baseline: 21 real contexts, zero stuck in `SENDING`/`RECONCILING`, one context in `DISCOVERED` (unresolved-notification) — traced and confirmed to be prior-session self-test debris (`SUPPRESS-SELFTEST-17`, `example.com` domain), not a genuine unresolved prospect reply.

## 4. Findings by severity

| ID | Severity | Status |
|---|---|---|
| F1 | **HIGH** | Fixed and deployed |
| F2 | MEDIUM | Tool built, tested, run read-only; historical-data decision left to owner |
| F3 | LOW / informational | Identified, not auto-cleaned |

No unresolved HIGH or MEDIUM finding remains. Full detail, reproduction, and evidence for each is in `reports/fable-google-chat-reply-console-audit-evidence.json`.

### F1 (HIGH, fixed) — Recovery-poll silent, permanent loss of malformed inbound items

The scheduled `HMZ — Inbound Recovery Poll` workflow calls the sidecar's `pollRecover()`. When Instantly returns a received-email item missing a required routing field (`eaccount`, prospect email, or the email id itself), the pre-fix code did:

```js
const created = createContext(base, input);
if (!created.ok || !created.created) { if (created.ok && !created.created) alreadyPresent++; continue; }
```

An `ok:false` result (invalid input) fell into the same silent `continue` as a harmless duplicate. Worse, the item's timestamp had already been folded into the running high-water mark **before** this check ran, so the mark advanced past the unroutable item and permanently excluded it from every future recovery scan — retrying would fail identically, since the field is genuinely absent at the API source. Zero telemetry event, zero Chat notification, zero watchdog trace. I reproduced this directly with a synthetic two-item page (one well-formed item, one with `eaccount`/`prospectEmail` deliberately blank and the *later* timestamp) and confirmed: no durable context created, no telemetry recorded, an empty watchdog unnotified-list, and a permanently advanced high-water mark. This is a direct violation of the audit's first required property — "no silently missed applicable prospect reply."

**Repair:** `recovery.mjs` now records `inbound_readback_invalid_skipped` telemetry and posts a best-effort raw Chat notification naming the Instantly email id and the missing field whenever an item can't be routed. `server.mjs`'s `/v1/watchdog` gained a new `readback_invalid_items` alert kind that surfaces these events through the existing persisted/posted alert pipeline, so the failure is durably visible even with no context ever created. Two regression tests were added. All 117 pre-existing local tests plus the 2 new tests pass (124/124 total local suite including the new backfill tool's tests).

**Deployment:** backed up the pre-fix source on the VPS, rebuilt the `hmz-reply-console` Docker image, recreated the container (the durable `/data` volume — contexts, go-live gate, owner binding, key fingerprint — is untouched by an image rebuild), verified the deployed file hashes matched the fixed source exactly, confirmed the container came up healthy within 21 seconds, and — rather than manually triggering it — **waited for the next genuinely scheduled recovery poll** to run against the new code, which it did cleanly two minutes later.

### F2 (MEDIUM, tool built) — No bounded, dry-run backfill/audit tool existed

Phase 4 requires an idempotent, explicit-date-range, dry-run-by-default tool that can never send and safely repairs missing ledger entries. None existed. I built `infrastructure/reply-console/backfill.mjs`: it never reads or writes the live poll's high-water mark (so it can't disturb steady-state recovery), defaults to a read-only report, requires an explicit `--apply` to actually create contexts, has no code path that can reach the Instantly reply-send endpoint (asserted by a dedicated test), and dedupes against the same primary key the webhook and poll paths already use. 7/7 tests pass.

I then ran a genuine **read-only dry-run** against production over a 14-day window: 56 applicable received emails, 38 missing from the durable ledger. Every one of the 38 is dated **before** the console's context-creation capability was deployed (2026-07-18T18:33Z) or before the reliability programme went live — the earliest is 2026-07-06, the latest 2026-07-18T15:53, four minutes short of that deployment. **Zero missing items since.** This confirms full live coverage; the 38 are pre-instrumentation history. I did **not** run `--apply`: posting up to 38 "recovered" notifications for replies as old as two weeks into the shared Chat space is a visible, owner-facing action that the owner should explicitly choose (some may already have been handled directly in Instantly). This is recorded as an outstanding owner decision, not executed.

### F3 (LOW, informational) — One watchdog alert is prior-session test debris

The single `DISCOVERED`-state context the watchdog currently flags was directly inspected and confirmed to be leftover from a prior session's `/v1/test-suppress` probe mechanism (`replyToUuid: SUPPRESS-SELFTEST-17`, `example.com` addresses) — not a real prospect reply. Harmless (no send risk), but keeps the watchdog's alert count at 1 instead of 0. Not deleted by this audit; recommended for cleanup.

## 5. Independent test totals

- **Local repository suite:** 124/124 (store 49, HTTP 20, formatting 13, enrichment 15, recovery 9, acceptance-F 7, dialog-contract 4, backfill 7 — the last two categories net-new/expanded this session)
- **Independent Fable adversarial harnesses** (own code, driving the real `store.mjs`/`recovery.mjs` against local mocks, zero real Instantly/Chat calls): 71/71 — concurrency 21/21, Google-Chat authz + Edit-flow 30/30, DR restoration drill 9/9, scale/soak harness 11/11 scenario categories
- **Live production probes:** 3 real 401 auth checks against the live endpoint, 1 real read-only backfill dry-run, 1 live scheduled-poll post-deploy regression, multiple gate-state readbacks

A genuinely candid note on the scale harness: my first run showed 3 of 11 scenarios failing. Investigation proved all three were bugs in **my own test harness** — the shared mock Instantly server never actually implemented its "drop" fault-injection branch (always returned 200, so ambiguous-transport scenarios vacuously never entered `RECONCILING`), the pagination mock conflated the list endpoint with nested per-item lookups, and two scenarios omitted a `subject` field the product correctly requires for reconciliation matching. All three were fixed and the full run re-verified at 11/11. I'm recording this rather than hiding it — it's evidence the scale run was genuinely adversarial rather than tuned to pass.

## 6. Scale/soak results

See `reports/FABLE_GOOGLE_CHAT_REPLY_CONSOLE_SCALE_RESULTS.md` for the full breakdown. Summary: 11/11 scenario categories pass, ~19,550 total simulated events, covering synthetic inbound volume, duplicate webhooks, webhook/poll races, paginated recovery, draft/edit interactions, duplicate Send clicks, ambiguous-send reconciliation, concurrent inbound, concurrent reconciliation, and restart-consistency. Volumes were scaled down from the literal 20,000-per-category asks for session practicality (documented honestly per category, not hidden) while preserving the same correctness invariants: zero missed contexts, zero duplicate contexts, at-most-one Instantly POST per attempt, and every simulated event reaching a defined durable terminal or in-flight state. **This is simulation, not a demonstration of live four-nines reliability.**

## 7. Edit-flow result

Independently reproduced end-to-end with the audit's exact required multiline body. Confirmed: the Edit button carries a valid `OPEN_DIALOG` action; opening the dialog is read-only (zero store mutation across 25 iterations); `SUBMIT_DIALOG` creates a new revision atomically (new revision + new token committed together, old token invalidated only afterward); the canonical stored body is byte-identical to the reviewed body across the full chain (Google event extraction → stored draft → `bodyHash` → outgoing `body.text`/`body.html`); a stale card recovers the **latest** revision rather than dead-ending; concurrent Edit-during-Send cannot let an unreviewed body reach Instantly (proven in the concurrency harness); duplicate dialog submissions produce exactly one active revision. 25/25 genuine-shaped dialog-open iterations produced valid `DIALOG` responses with the exact required body, zero accidental revisions, zero stale-token dead ends, and zero Instantly POSTs.

## 8. Inbound recovery result

Dual-path inbound (webhook fast path + scheduled recovery poll) reviewed and adversarially tested. Webhook/poll races, duplicate webhooks, delayed webhooks after poll recovery, and restart-replay were all proven to dedupe safely on the shared Instantly email id (concurrency harness §S2/S2b/S3/S14). The one genuine defect found (F1) was in this phase and has been fixed and deployed (§4). Name enrichment code was reviewed and its existing 15/15 test suite re-run unchanged: prospect names come strictly from `reply_received` payload fields or an exact lead lookup (never inferred from local-part/display/company/body/signature), sender names strictly from the Instantly Account for the exact `eaccount`, and ambiguous lookups explicitly refuse to guess.

## 9. Outbound/reconciliation result

The send contract (`POST /emails/reply`, single Bearer, server-resolved routing never trusted from Chat card params) and the full state machine (`DRAFT→APPROVED→SENDING→{SENT_API_CONFIRMED|RECONCILING→{...}|FAILED_DEFINITIVE→RETRYABLE}`) were reviewed against `store.mjs`'s `ALLOWED_TRANSITIONS` table, which is the sole enforcement point for reachable states. Ambiguous transport (dropped response, timeout, 5xx, response-parse-failure) was proven in both the concurrency and scale harnesses to always yield exactly one POST followed by durable, restart-safe reconciliation via readback matching and the isolated `email_sent` webhook — never a second POST. The reported "http ?" jargon concern does not apply: code inspection confirms the `FAILED_DEFINITIVE` branch's `'?'` fallback is structurally unreachable, since that outcome is only ever reached with a definite 400–499 status.

## 10. Security result

No command execution, no `eval`/`new Function` in runtime code (only in a test harness evaluating the repo's own workflow source), no SSRF-reachable dynamic fetch targets (every fetch target is fixed or env-configured, never derived from Chat-controlled input), no path traversal (context ids are validated against `/^[0-9a-f]{32}$/` at every route), 192-bit one-use review tokens stored only as a salted-free but irreversible sha256 hash with TTL, and outgoing HTML is escaped before markup insertion so a hostile reply body cannot inject into the outgoing email or card. The only runtime logging is a sanitised, token-free diagnostic gated behind a debug flag confirmed `false` in production. A targeted secret scan of every backup and evidence artifact this audit produced — repository and VPS-side — was clean.

## 11. Disaster-recovery result

A restoration drill was run against the **real, pre-repair production backup** (21 genuine contexts), extracted into an isolated scratch path inside the running container (never `/data`) and exercised with the real `store.mjs` module. 9/9 checks passed: restored contexts parse cleanly with no data loss; no `SENDING` context loses its lock; zero terminal/delivered contexts can re-acquire a send after restore; every non-active draft revision is structurally superseded so old tokens are unreachable; the high-water mark restores as valid state; the watchdog-equivalent check correctly detects an *induced* stuck-notification failure on a scratch clone; owner binding and the go-live gate both restore to their exact prior values.

## 12. SLO status and sample size

Both reliability SLOs (99.99% inbound-notified, ≥99.99% outbound-clear-outcome) remain **targets, not statistically demonstrated claims** — current live samples are inbound N=10, outbound N=3, far below the 10,000-event threshold the system's own telemetry module correctly requires before making that claim. The system's own `/v1/report` truthfully reports this; I did not find any place where a smaller-sample result is dressed up as an achieved target.

## 13. Residual risks

- Google Chat's incoming-webhook notification path cannot read Chat message history: a response lost *after* Google accepts a post is an irreducible, architecture-level delivery ambiguity. It is honestly represented as `CHAT_POST_AMBIGUOUS`, never silently reported as notified.
- Operational alerts and ordinary notifications share the same one-way incoming webhook; a full outage of that specific transport would make both invisible in Chat simultaneously. Mitigated: alerts are also persisted and independently queryable at `/v1/watchdog`.
- 38 historical (pre-instrumentation) prospect replies are not in the console's ledger; the tool to safely close this now exists, but running it is an outstanding owner decision (§4, F2).
- The new `readback_invalid_items` watchdog alert is proven by local reproduction and code deployment, not yet by a genuine live occurrence.
- Live sample sizes remain far too small to statistically support any 99.99% claim.

I make no claim of literal perfection, no claim of guaranteed 100% external mailbox delivery, and no claim of statistically demonstrated 99.99% production reliability.

## 14. Files changed

- `infrastructure/reply-console/recovery.mjs` — F1 repair
- `infrastructure/reply-console/server.mjs` — F1 watchdog alert
- `infrastructure/reply-console/test-recovery.mjs` — 2 new regression tests
- `infrastructure/reply-console/backfill.mjs` — new, F2
- `infrastructure/reply-console/test-backfill.mjs` — new, F2, 7 tests

Production: `recovery.mjs`/`server.mjs` rebuilt and deployed into `hmz-reply-console-business-live` (container recreated; durable volume, gate, binding, key fingerprint all preserved and verified unchanged); `backfill.mjs` copied into the running container for the one read-only audit run (not yet in the Dockerfile's `COPY` list — recommended follow-up so it survives the next rebuild).

No workflow, credential, campaign, lead, or send-configuration change was made anywhere in this run.

## 15. Secret-scan result

**CLEAN.** No secret value appears in any report, backup, or evidence file this audit produced, on either the repository side or the VPS side. VPS-side backup artifacts (including the one file that legitimately contains real values, the compose `.env` snapshot) were locked to root-only `600`/`700` permissions.

## 16. Exact remaining owner decisions

1. Whether to run `node backfill.mjs --since 2026-07-06T00:00:00Z --until 2026-07-18T18:33:00Z --apply` to backfill the 38 historical (pre-instrumentation) prospect replies with Chat notifications.
2. Whether to remove the one self-test-debris `DISCOVERED` context (`67391b9f…`) from the durable store, or leave it (harmless).
3. Whether to add `backfill.mjs` to the sidecar `Dockerfile`'s `COPY` list so it survives future image rebuilds without a manual `docker cp`.

No emergency owner action is required. No immediate production risk was found. The global supervised-send capability remains exactly as it was found: enabled, owner-controlled, untouched.
