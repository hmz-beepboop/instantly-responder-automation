# Architecture — Phase 2 (reconciled)

Date: 2026-06-10. Reconciled during the Phase 2 correction pass (`docs/PHASE_2_CORRECTION_CHANGELOG.md`).

**Historical note:** "Status: design only. No workflows are built" reflects
Phase 2, before any workflow existed. All six workflows described by this
design are now built and integrated (`docs/CURRENT_BUILD_STATE.md`,
`reports/INTEGRATION_CLOSURE_RUNTIME.md`). The design rationale, profiles,
and deferred-items tables below remain the current reference for *why* the
system is shaped this way; for current build/test state use
`docs/CURRENT_BUILD_STATE.md` and `reports/`, not this file.

Two profiles are defined: a **Validation MVP** (what the next phase builds) and a **Production profile** (later options gated behind proven volume/need). Default `OPERATING_MODE=VALIDATION` (`docs/HMZ_APPROVED_REPLY_RULES.md` §2).

`DRY_RUN=true` is the default for every side-effecting action. A real prospect send additionally requires `OPERATING_MODE` + the full pre-send gate (`HMZ_APPROVED_REPLY_RULES.md` §9.1) + a `LIVE_CAMPAIGNS` allowlist match + explicit owner approval.

**Scope:** this architecture describes the system supporting **HMZ's own initial US B2B validation campaign only** (`CLAUDE.md` "Scope"). It is a single-tenant design for one Instantly workspace and the validation campaigns defined in `docs/VALIDATION_CAMPAIGN_CONFIG.md` (validation cells, `geo_code=US_B2B_CORE_12`). It is not a multi-tenant or client-facing architecture, and no part of this design should be read as describing a reusable client responder.

---

## 1. Five-minute objective — two distinct SLOs

The authoritative, staged definition is `HMZ_APPROVED_REPLY_RULES.md` §10. Summary:

- **Processing SLO (staged sub-targets):** webhook acknowledgement immediate; classification + structured action plan within 60 seconds; draft (where `draft_required=true`) + human notification within 120 seconds; processing concluded — completed, suppressed, or escalated — within 300 seconds.
- **Transmission SLO (separate; not guaranteed in `OPERATING_MODE=VALIDATION`):** where `send_allowed=true` and a human approves, the approved reply transmits within 5 minutes of approval. In `VALIDATION` mode substantive replies wait for human approval and there is no transmission guarantee.

A Slack/email notification, queue entry, case record, generated draft, approval request, or scheduled/held reply is **not** a transmitted reply. An intentional no-reply (e.g. acknowledgement-only or `NO_REPLY` outcomes) that completes within the Processing SLO is a **successful resolution**, not a failure of the objective. The two metrics are reported separately and never conflated.

---

## 2. Validation MVP

The smallest safe system for the initial ~500-email US validation sprint. It contains only:

1. **Webhook intake** — receive the Instantly reply webhook.
2. **Request validation / compensating controls** — authenticate or apply compensating controls (see §4), then minimal schema validation.
3. **Payload normalization** — to the Normalized Event Schema (`docs/NORMALIZED_EVENT_SCHEMA.md`), including a campaign-ID lookup that attaches campaign-context fields (`validation_cell`, `segment`, `subsegment`, `pain_trigger`, `offer_angle`, `geo_code`, `campaign_purpose`, `campaign_message_variant`) from `docs/VALIDATION_CAMPAIGN_CONFIG.md`. A `geo_code` mismatch is a human-review flag, not a rejection (`HMZ_APPROVED_REPLY_RULES.md` §1, §16).
4. **Deduplication** — idempotency key derived from the inbound event (`docs/STATE_AND_IDEMPOTENCY.md`).
5. **Deterministic safety prefilter** — unsubscribe, legal, hostile, media-flag, bounce-with-evidence, attachment, pricing, booking, referral, wrong-person (`HMZ_APPROVED_REPLY_RULES.md` §5).
6. **Semantic classification where required** — via a mock classifier interface until a real model integration is approved.
7. **Structured action-plan generation** (§5 below).
8. **Draft or fixed-template selection** — held for approval in VALIDATION mode.
9. **Immediate human notification** — one configurable destination.
10. **Campaign or sequence stop where verified; suppression where verified** — human task where a mechanism is unverified.
11. **Optional approved response transmission** — only where auto-send is explicitly enabled (not in VALIDATION mode by default).
12. **Basic persistent case state** — one durable case record.
13. **Basic latency logging** — lifecycle timestamps for both SLOs.
14. **Synthetic testing** and **failure visibility**.

The MVP does **not** require: new Supabase/Postgres infrastructure, three Slack channels, Google Sheets, external heartbeat monitoring, a US holiday API, a reporting warehouse, multi-client tenancy, broad observability, or production-scale retention.

### 2.1 MVP data flow

```
 Instantly        ┌────────────────────────────┐   normalized   ┌──────────────────────┐
 reply webhook ──►│ 1. Reply Intake            │──── event ────►│ 2. Reply Decision    │
 (per campaign)   │  authenticate / compensate │   (NES v1)     │    Engine            │
                  │  minimal schema validation │                │  deterministic first │
                  │  respond (200 / 4xx)       │                │  → mock classifier   │
                  │  then async dispatch       │                │  → action plan       │
                  └──────────────┬─────────────┘                └──────────┬───────────┘
                                 │ (accepted only)                          │ action plan
                                 ▼                                          ▼
                     ┌────────────────────────┐         ┌──────────────────────────────────┐
                     │  Case Store (one        │◄────────│ 3. Dispatch by action plan:        │
                     │  durable case record;   │         │  - stop/pause sequence (verified)  │
                     │  storage TBD — §6)      │         │  - suppression level (verified)    │
                     └────────────────────────┘         │  - draft/template (held)           │
                                 ▲                       │  - human notification (always)     │
                                 │                       │  - optional send (only if enabled) │
                                 │                       └──────────────────────────────────┘
                     ┌────────────────────────┐
                     │ Synthetic Test Harness  │── canned NES payloads ──► Reply Decision Engine
                     │ (DRY_RUN hard-locked)   │
                     └────────────────────────┘
```

---

## 3. Production profile (later options — not built next)

Retain only where justified by proven volume and operational need, with explicit migration triggers:

| Capability | Migration trigger |
| --- | --- |
| Postgres / Supabase as primary store | n8n-native/existing-DB storage proven inadequate at observed volume. |
| Richer observability / dashboards | Case volume exceeds what one operator can review from the MVP surface. |
| External heartbeat monitoring (e.g. UptimeRobot) | Move to unattended auto-send (PROVEN mode). |
| Multiple escalation channels (`#reply-queue`, `#reply-urgent`, `#automation-alerts`) | Case volume/urgency mix justifies separation. |
| Advanced metrics / reporting warehouse | Cross-campaign reporting needed. |
| Multi-workspace / multi-client tenancy | More than one client/workspace live. |
| Holiday / timezone scheduling (quiet hours) | Unattended auto-send enabled and prospect-experience tuning needed (see §7). |
| Production reconciliation infrastructure | Verified reconciliation endpoints exist and auto-retry is approved. |
| Expanded retention | Compliance/reporting requirement. |

---

## 4. Webhook acknowledgement and authentication

The intake sequence is, in order:

1. **Receive** the webhook.
2. **Authenticate / apply compensating controls** (strategy below — pending verification).
3. **Minimum schema validation** (required fields present and well-formed).
4. **Respond** through a Respond-to-Webhook node: `200` for an accepted, validated request; `401`/`4xx` for a rejected one.
5. **Continue/dispatch processing asynchronously** only after the request is accepted.

The system never returns `200` and then rejects the same request with `401`. The synchronous path for accepted events stays minimal and fast.

**Webhook protection is a configurable strategy, pending verification.** No option is marked verified. Candidates, with primary authentication distinguished from compensating controls:

- *Primary auth (if Instantly supports it):* native signed-webhook verification; native header/secret configuration.
- *Compensating controls:* secret URL path; secret query parameter; source IP allowlisting (only where reliable and feasible); strict payload validation; campaign and sender allowlisting; API-side event verification (re-fetch/confirm the event via the Instantly API); rate limiting.

We do **not** assume Instantly can send an `X-Webhook-Secret` custom header. The chosen method is selected and verified at build time (`docs/ASSUMPTIONS_AND_UNKNOWNS.md`).

---

## 5. Structured action plan (replaces the 4-value enum)

The Decision Engine emits an action-plan object, not a single `AUTO_SEND`/`SUPPRESS`/`ESCALATE`/`NOOP` value. Fields (full list in `HMZ_APPROVED_REPLY_RULES.md` §9.2 and schema in `STATE_AND_IDEMPOTENCY.md`): `stop_sequence`, `pause_sequence`, `suppression_level`, `interest_status_update`, `reply_mode`, `template_id`, `draft_required`, `human_review_required`, `escalation_required`, `priority`, `follow_up_date`, `send_allowed`, `blocklist_required`, `data_cleanup_required`, `legal_review_required`, `privacy_review_required`, `reputational_review_required`, `reason_codes`.

`suppression_level` includes the neutral `REVIEW_HOLD` hold state (`HMZ_APPROVED_REPLY_RULES.md` §7), distinct from the three independent review-type booleans (`legal_review_required`, `privacy_review_required`, `reputational_review_required`), which record which review(s) a `REVIEW_HOLD` case needs. Not all three booleans are set for every `REVIEW_HOLD` case (§7.1).

Each action maps to: intended business outcome → verified technical mechanism → provisional fallback → human task when no API mechanism is available. This lets T12/T13 simultaneously stop the sequence, suppress, escalate, and preserve evidence — which a single enum could not express.

---

## 6. State store — choice deferred

Storage is **not** chosen conclusively. Preference order, decided once n8n MCP and the real environment are available:

1. Suitable **n8n-native persistent storage**, if verified adequate for idempotency + case state.
2. An **already-approved existing durable database**, if one exists.
3. A **new Postgres/Supabase deployment**, only if (1) and (2) are demonstrably inadequate.

The MVP needs only: idempotency/dedupe state, one durable case record, send-state to prevent duplicates, and lifecycle timestamps. Table shapes are in `docs/STATE_AND_IDEMPOTENCY.md` and are storage-engine-agnostic until the choice is made. Whichever store is chosen must provide a durable uniqueness guarantee for the idempotency key and the send lock; if n8n-native storage cannot, that is the trigger to move down the preference order.

---

## 7. Quiet hours — deferred to Production (original preference preserved)

Quiet-hours holding is **removed from the Validation MVP**: every event is processed and the operator notified immediately, and a queued/scheduled reply is never counted as transmitted. The original owner (Grill Me) preference, retained here for later reintroduction in the Production profile:

- Automatic-send window Monday-Friday, 08:00-18:00 in the prospect's verified local timezone (configurable).
- No auto-sends on weekends or configured US federal holidays (maintained calendar/service, not hard-coded).
- Hold-and-release outside the window with re-checks before release; maximum 24-hour hold, then human escalation.
- Timezone resolution order: explicit/verified prospect timezone → verified company location → campaign timezone → validation-cell timezone; never infer from area code; `America/Chicago` conservative fallback for the ET/CT sprint.

Reintroduction requires: unattended auto-send enabled (PROVEN mode), a maintained holiday/timezone service, and prospect-timezone data quality sufficient to schedule safely.

---

## 8. Environment / config

Secrets live only in n8n credentials or env vars, never in workflow JSON or logs.

| Key | Purpose | Default | Notes |
| --- | --- | --- | --- |
| `OPERATING_MODE` | `VALIDATION` / `PROVEN`. | `VALIDATION` | PROVEN not active until its gates are met. |
| `DRY_RUN` | Global send guard. | `true` | Flip to `false` only with explicit approval + gates + allowlist. |
| `LIVE_CAMPAIGNS` | Exact campaign IDs allowed to send. | empty | Empty = nothing sends. |
| `INSTANTLY_API_KEY` | Bearer key, narrow scopes. | — | n8n credential; never echoed. PROVISIONAL until provisioned. |
| `INSTANTLY_API_BASE` | Host. | TBD | PROVISIONAL — confirm (`ASSUMPTIONS_AND_UNKNOWNS.md` B1). |
| webhook-protection config | Auth/compensating-control strategy. | — | Strategy pending verification (§4). |
| state store connection | Idempotency + case state. | — | Storage choice deferred (§6). |
| classifier creds | Semantic classification. | — | Mocked until real integration approved. |
| human-review destination | One configurable surface. | — | Owner selects (`HMZ_APPROVED_REPLY_RULES.md` §11). |
| `PROCESSING_SLO_SECONDS` / `TRANSMISSION_SLO_SECONDS` | SLO targets. | 300 / 300 | Targets; baselines measured in the real environment (no speculative p95). |

---

## 9. Latency — measure first, then target

The earlier `≤200ms`/p95 figures were speculative and are removed. The MVP records lifecycle timestamps (`HMZ_APPROVED_REPLY_RULES.md` §10) so a **baseline is measured in the actual environment first**, then realistic Processing-SLO and Transmission-SLO targets are set against that baseline. No latency threshold is asserted as a design guarantee before measurement.

---

## 10. What this design explicitly does NOT do (yet)
- Does not build any workflow in n8n (n8n MCP not connected; non-prod instance not confirmed).
- Does not call Instantly or send any email.
- Does not store prospect data outside the local design docs.
- Does not assume a verified blocklist, thread, reconciliation, interest-status, or subsequence mechanism — each is PROVISIONAL or BLOCKED (`docs/ASSUMPTIONS_AND_UNKNOWNS.md`).
- Does not auto-send substantive replies in VALIDATION mode.
- Does not provision new infrastructure before the storage choice is made.
