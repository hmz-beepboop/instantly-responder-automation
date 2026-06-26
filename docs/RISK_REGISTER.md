# Risk Register — Phase 2 (reconciled)

Date: 2026-06-10. Each risk has a deterministic mitigation encoded in the design; residual risk is what remains after that mitigation.

> **Reconciliation notes (correction pass).** (1) "Actions" are now structured **action-plan** fields, not the `AUTO_SEND`/`SUPPRESS`/`ESCALATE`/`NOOP` enum; read those terms as the corresponding action-plan outcome. (2) The auto-send threshold is `0.90` and is **necessary, never sufficient** — every pre-send gate must pass (`HMZ_APPROVED_REPLY_RULES.md` §9.1); the old `0.85` is removed. (3) In `OPERATING_MODE=VALIDATION` (default) no substantive reply auto-sends, which lowers the likelihood of several send-path risks below. (4) Webhook protection, storage, heartbeat, and quiet-hours items are reconciled per the Validation MVP / Production split.

Severity is `S` × `L` where S = business impact (1–5) and L = likelihood given the current design (1–5).

| ID | Risk | S | L | Mitigation (already in design) | Residual | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | Duplicate reply to the same prospect from webhook redelivery | 5 | 4 | `events.dedupe_key` unique + partial unique index on active `sends` (`STATE_AND_IDEMPOTENCY.md` §2–3); 300s time bucket | Low | system |
| R2 | Auto-reply to an unsubscribe / opt-out request | 5 | 3 | Deterministic `det-unsub-001` runs before AI; AI cannot assign T7; templates have an unsubscribe footer; status change to `unsubscribed` before any other action | Low | system |
| R3 | Auto-reply to a legal or privacy demand | 5 | 2 | `det-legal-00*` deterministic match → `ESCALATE` with `legal=true`; AI cannot assign T12 directly; urgent severity | Low | system |
| R4 | Auto-reply mentioning price or making a commercial commitment | 5 | 3 | `det-price-001` deterministic; T11 escalates; templates contain no price language; "never auto-reply" denylist | Low | system + user (review templates) |
| R5 | Reply sent in the wrong language to the lead | 3 | 3 | Auto-send guardrail #4 in `REPLY_POLICY.md` §5: language must match template's supported list, else escalate | Low | system |
| R6 | Reply attempts to address an attachment-dependent ask | 4 | 3 | Deterministic `det-attach-001`; T14 escalates; conservative regex catches "see attached" multilingual variants | Low–Med (false negatives possible) | system |
| R7 | PII or production prospect data leaks into source control via test fixtures | 5 | 3 | Test fixtures live in `.tmp/` (in `.gitignore`); `synthetic=true` events are stamped; review checklist before committing any fixture; the `nes` JSONB redacts message bodies in checked-in samples | Medium | user (review on PR) |
| R8 | Sending in dry-run mode by accident, OR sending live when expected to dry-run | 5 | 2 | DRY_RUN default true + `LIVE_CAMPAIGNS` allowlist required AND `synthetic=true` hard-locks DRY_RUN on. Tested in Test Harness. | Low | system |
| R9 | Webhook payload missing `reply_to_uuid` source → can't reply | 4 | 4 | LOOKUP fallback in NES; until verified, send path remains in DRY_RUN; escalate otherwise (`ASSUMPTIONS_AND_UNKNOWNS.md` B3) | Med (operational, not safety) | system |
| R10 | Webhook spoofing — attacker posts fake `reply_received` to our endpoint | 4 | 3 | Configurable protection strategy **pending verification** (`ARCHITECTURE.md` §4): native signed/secret verification if supported, else compensating controls (secret URL path, secret query param, source allowlist, strict payload validation, API-side event verification, rate limiting). We do **not** assume Instantly can send a custom `X-Webhook-Secret` header. Auth/validate happens **before** acceptance; never 200-then-401. | Med | system + user (select + verify method) |
| R11 | Classifier silently regresses across model updates | 3 | 4 | Pinned `prompt_version`; nightly Test Harness pass with assertions on category/action; alerts on per-category accuracy drop | Low | system |
| R12 | Race condition: two Reply Sender executions on the same event | 5 | 3 | Partial unique index on `sends.dedupe_key`; advisory lock keyed on `eaccount`; transaction around `INSERT … RETURNING` | Low | system |
| R13 | Uncertain send outcomes retried, causing duplicates | 5 | 3 | `UNCERTAIN` is a terminal-pending state until reconciler resolves (`STATE_AND_IDEMPOTENCY.md` §4); no inline retries; until B9 endpoints are confirmed, `UNCERTAIN` escalates without retry | Low | system |
| R14 | Suppression action partially succeeds (status changed, blocklist failed) | 4 | 3 | Per-call result columns in `suppressions`; Watchdog flags rows with mixed outcomes; human follows up | Low–Med | system |
| R15 | Quiet hours / off-hours send | 2 | 2 | **Not applicable to the Validation MVP** — no auto-send of substantive replies in VALIDATION mode, and no quiet-hours hold (events are processed and the operator notified immediately; `ARCHITECTURE.md` §7). Becomes relevant only if unattended auto-send is later enabled in the Production profile, where the quiet-hours design re-applies. | Low (MVP) | user (Production) |
| R16 | n8n workflow disabled / instance down — events lost | 4 | 2 | Instantly is the source of truth; events do not vanish if we ack only accepted requests. If we are down, Instantly never reaches us. **MVP:** failures are surfaced to the human-review destination. **External heartbeat monitoring (e.g. UptimeRobot) is a Production-profile option**, not an MVP requirement (`ARCHITECTURE.md` §3). | Med | user (Production monitor) |
| R17 | API key leaked via logs, exports, or error excerpts | 5 | 2 | Rule #5 + redacted excerpts ≤ 280 chars + key only in n8n credentials; n8n log redaction patterns include `Bearer`, `Authorization`, `INSTANTLY_API_KEY` | Low | system + user |
| R18 | Reply breaks email thread (clients see two threads) | 3 | 4 | Carry `thread_id` from Instantly's response; request includes `reply_to_uuid`. Until `In-Reply-To`/`References` preservation confirmed (B10), every live test inspects the destination inbox before scaling. | Med | system + user |
| R19 | Decision Engine treats first reply differently than follow-up replies, causing confusing behaviour | 3 | 3 | Auto-send guardrail #2 prevents repeat sends within a bucket; guardrail #3 distrusts different sender addresses | Low | system |
| R20 | Cost runaway from classifier loops | 2 | 2 | Sender concurrency cap; per-`eaccount` advisory lock; per-event idempotency means re-deliveries never re-classify; `replay=true` is explicit | Low | system |
| R21 | Policy/template change applied without coverage check | 3 | 3 | Test Harness asserts at least one fixture per category per active `policy_version`; CI blocks merge on missing coverage | Low | system + user (review PR) |
| R22 | Misclassification: T1 / T11 confusion ("interested, but what's the price?") | 4 | 4 | T11 deterministic prefilter runs before AI; AI confidence band downgrades borderline T1 to escalate | Med | system |
| R23 | Misclassification: T8 OOO mistaken for T1 positive | 3 | 3 | OOO deterministic regex runs before AI; multilingual coverage limited initially | Low–Med | system |
| R24 | Sender hits Instantly 429 storm | 3 | 2 | Single-call-per-event design; concurrency cap; respect `Retry-After`; Watchdog alerts before storm escalates | Low | system |
| R25 | State-store outage | 4 | 2 | Reply Intake fails closed — does not accept (no success ack) if it can't write the event. Instantly retries per its policy. Storage engine is the deferred choice (`ARCHITECTURE.md` §6), not mandated Supabase. | Med | user (monitor store) |
| R26 | Vendor API change (Instantly renames or removes fields) | 4 | 3 | NES isolates downstream from vendor schema; `nes_version` and `policy_version` bumps; deterministic rules + AI classifier are decoupled from raw payload fields | Low–Med | system |
| R27 | AI classifier hallucinates a slot value (e.g. fake meeting time) | 3 | 3 | Slots are advisory; templates do not interpolate raw slot text into substantive promises; T3 sends a booking link, not a committed time | Low | system |
| R28 | Operator confusion: which campaign is live? | 3 | 4 | `LIVE_CAMPAIGNS` is the single authoritative list; Sender logs the allowlist version on every send; Watchdog dashboard surfaces it | Low | user (treat list as change-controlled) |
| R29 | Synthetic fixtures drift from real payload shape | 3 | 4 | Capture one real `reply_received` payload in early Phase 3 (sacrificial campaign) → hash check fixtures against the captured shape | Low | system |
| R30 | Wrong-person re-route results in unsolicited outreach to a new contact | 4 | 3 | T5 / T10 never auto-email a new address. Re-routing is a human action with an explicit confirmation step. | Low | system + user |
| R31 | Media/journalist enquiry mis-handled as hostile (T13) and suppressed/ignored | 4 | 3 | `det-media-001` routes media to a **human-review risk flag (P3M media track)**, never auto-class as hostile; only an authorised spokesperson responds (`HMZ_APPROVED_REPLY_RULES.md` §8). | Low | system + user |
| R32 | Inbound `List-Unsubscribe` header wrongly treated as a prospect opt-out | 3 | 3 | T7 fires only on **prospect-stated** opt-out language; a `List-Unsubscribe` header alone never triggers T7 (`HMZ_APPROVED_REPLY_RULES.md` §5.1). | Low | system |
| R33 | Ordinary automated sender mis-classified as a bounce, dropping a real lead | 3 | 3 | T9 requires **delivery-status evidence** (DSN/status code), not just a daemon-style address; uncertain → human review (`REPLY_POLICY.md` §2.2). | Low | system |
| R34 | A high confidence score authorises a prohibited or ungated send | 5 | 3 | Confidence is necessary, never sufficient; the full pre-send gate must pass and VALIDATION mode requires human approval (`HMZ_APPROVED_REPLY_RULES.md` §9.1). | Low | system |

## Tripwires

A tripwire automatically pauses the relevant workflow when it fires. They are independent of Watchdog alerts.

| Tripwire | Condition | Action |
| --- | --- | --- |
| `tw-error-spike` | > 10 errors in 5 minutes | Disable Reply Sender automatically; alert. |
| `tw-suppression-flood` | > 5 hard-suppressions in 10 minutes from one campaign | Disable that campaign in `LIVE_CAMPAIGNS`; alert. |
| `tw-classifier-divergence` | Nightly Test Harness pass rate < 95% | Block any push of new templates / prompts; alert. |
| `tw-uncertain-overflow` | > 3 `UNCERTAIN` sends unreconciled for > 10 minutes | Disable Reply Sender; alert. |
| `tw-heartbeat-missing` | No SLA Watchdog heartbeat for 5 minutes | Out-of-band alert (UptimeRobot or similar). **Production-profile tripwire** — the watchdog + external heartbeat belong to Production, not the Validation MVP. |

## Self-anneal targets

These are the failure modes most likely to be caught by Rule #2's self-anneal loop:
- R9 (missing identifier) — first real payload tells us whether the LOOKUP fallback is needed.
- R18 (threading) — first reply tells us whether `In-Reply-To`/`References` survive.
- R22 (T1/T11 confusion) — accumulated fixtures will tighten the deterministic prefilter and classifier prompt.
- R23 (OOO misclassification) — new patterns get added to `det-ooo-001`.
