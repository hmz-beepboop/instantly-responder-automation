# Instantly Configuration — Verified Contracts and Future Steps

This document distinguishes **empirically verified live evidence** (captured
in `reports/INSTANTLY_VERIFICATION_EVIDENCE.md`, summarised in
`docs/PHASE_5_VERIFIED_INPUT.md` and `docs/INSTANTLY_FIELD_MAP.md`) from
**future configuration steps** required before any controlled live send.
`DRY_RUN=true` and `LIVE_CAMPAIGNS=[]` remain in force; no live Instantly
credential is bound to any of the six workflows.

## Verified live evidence

### Genuine `reply_received` event

A real `reply_received` webhook event was captured and used as the basis for
Reply Intake's normalization (Normalized Event Schema). The documented
payload fields (`timestamp`, `event_type`, `workspace`, `campaign_id`,
`campaign_name`, `lead_email`, `email_account`, `unibox_url`, `step`,
`variant`, `is_first`, `reply_text_snippet`, `reply_subject`, `reply_text`,
`reply_html`) are treated as verified for this event type.

### Canonical webhook `email_id` as `reply_to_uuid`

**Verified.** The webhook's `email_id` matched the retrievable inbound Email
object ID and was confirmed as the correct `reply_to_uuid` target for
`POST /api/v2/emails/reply`.

### Connected `eaccount`

`POST /api/v2/emails/reply` requires `eaccount` (the sending account used for
the reply). The Sender derives this from the connected sender account
associated with the inbound thread. Verified as part of the reply-mapping
evidence above; a controlled live send would still require an explicit
sender-account approval per `docs/HMZ_APPROVED_REPLY_RULES.md` §9.1.

### Thread and subject preservation

**Verified.** The inbound and original outbound Email objects shared the
same `thread_id`; `message_id` was also present on both. Reply construction
preserves the thread.

### Update-interest-status result verification

**Verified (V4B).** `POST /api/v2/leads/update-interest-status` returned HTTP
`202`; a subsequent retrieval confirmed the interest status and its
timestamp had changed as expected.

### Subsequence removal result verification

**Verified (V4C).** A controlled lead was moved into a subsequence, removed
via `POST /api/v2/leads/subsequence/remove`, and retrieval confirmed the lead
was outside the paused subsequence afterward.

### Source-campaign unsubscribe behaviour

**Verified (V4E4): campaign-local, not workspace-wide**, under the tested
workspace configuration (`CAMPAIGN_LOCAL_UNSUBSCRIBE_VERIFIED`). An ordinary
unsubscribe/interest-status change stops the source campaign sequence for
that lead but does **not** by itself prevent other campaigns from contacting
the same address.

### Exact email-level blocklist for workspace-wide suppression

**Verified (V4D).** Adding an exact email address to the workspace Blocklist
(Settings → Blocklist) is a workspace-wide kill switch: a blocked address
received no further campaign email, while a matched unblocked control
address did. This is the mechanism required, **in addition to** the
source-campaign action, for true workspace-wide suppression (T7 / T12 /
T13), per `docs/REPLY_POLICY.md` §6 and `docs/INSTANTLY_FIELD_MAP.md` §5.3.

### Rate-limit and failure policy

Documented rate limits: no more than 100 requests/second, no more than 6,000
requests/minute; over-limit returns HTTP `429`. The implemented retry policy
(`docs/STATE_AND_IDEMPOTENCY.md` §6, V5 Layer 1 fault-injection-verified):

- `400` → `PERMANENT_FAILURE`, no retry.
- `401`/`402`/`403` → `AUTH_OR_PLAN_FAILURE`, no retry.
- `404` invalid reply target → `INVALID_REPLY_TARGET`, no retry.
- `429` → bounded retry, honouring a valid `Retry-After` header.
- `500`/`502`/`503`/`504` → bounded retry (maximum 3 total attempts).
- Proven pre-submission network failure → bounded retry allowed.
- Submission-uncertain failure, post-submission timeout, or malformed
  successful response → `SEND_UNCERTAIN`, never blindly retried.

### Reconciliation rules

Reconciliation is read-only and searches verified Instantly Email fields,
locally filtered by thread, sender, recipient, exact subject, a narrow
timestamp window, and a unique marker/fingerprint.

- Exactly one matching Email object on repeated checks → `SENT_RECONCILED`.
- Zero matches by the deadline → `HUMAN_REVIEW_ZERO_MATCHES`.
- More than one match → `HUMAN_REVIEW_MULTIPLE_MATCHES`.
- Zero/multiple matches never trigger a second `POST` and always require
  human review.

**V5 Layer 2 live-tested only the exactly-one-match path** (one upstream
`POST`, response deliberately lost, state `SEND_UNCERTAIN`, exactly one
matching Email object found on reconciliation, `SENT_RECONCILED`, no
duplicate send). The zero-match and multiple-match paths are
deterministic-policy and local-harness verified only — **not** exercised
against a live Instantly response.

## Future configuration steps (not yet performed)

These are required before any controlled live test and are **not** part of
the current validation environment:

- Provision a narrowly scoped Instantly API v2 key (`emails:create` /
  `emails:all` / `all:create` / `all:all` plus the minimum lead-management
  scope needed for `update-interest-status` and `subsequence/remove`).
- Bind that key as an n8n credential (never in workflow JSON), only after a
  durable human-approval mechanism exists for the Sender's approval gate
  (see `docs/NEXT_STEPS.md`). Sender/Error Handler n8n-runtime evidence
  itself now exists (`reports/INTEGRATION_CLOSURE_RUNTIME.md`).
- The Instantly API base host is verified as `https://api.instantly.ai`
  (`docs/INSTANTLY_FIELD_MAP.md` §1, `docs/ASSUMPTIONS_AND_UNKNOWNS.md` B1).
- Configure a per-campaign or workspace webhook for `reply_received` (and
  `lead_unsubscribed` for suppression-path testing) with a chosen
  authentication/compensating-control strategy (`docs/ARCHITECTURE.md` §4).
- Add the exact, owner-approved campaign ID to `LIVE_CAMPAIGNS` only after
  the full pre-send gate (`docs/HMZ_APPROVED_REPLY_RULES.md` §9.1) is met.
- Confirm the workspace's webhook plan-tier gating (referenced as "Hyper
  Growth or above" in vendor docs, account tier not confirmed).
