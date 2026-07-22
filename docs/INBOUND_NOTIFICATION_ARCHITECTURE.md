# Inbound Notification Architecture

Status: production design for the HMZ single-tenant Instantly-to-Google-Chat console. This document describes notification visibility only; it does not change the separately gated supervised reply-send path.

## Contract

An object returned by Instantly's received-email inventory is notification-authoritative. For every such logical email, the system must durably hold:

1. one canonical inbound identity;
2. one logical notification outbox row; and
3. eventually, a definite Google Chat acknowledgement carrying a message resource name.

`isInstantlyReceived(record)` decides only whether an untrusted webhook event claims to be inbound. A record returned from the authenticated Instantly `email_type=received` endpoint is authoritative regardless of optional fields or `ue_type`. `classifyInboundLabel(record)` is separate and presentation-only. Ordinary, automatic, out-of-office, unsubscribe, bounce, mail-system, empty, attachment-only, malformed and unknown records all have `notificationRequired=true`.

Reply Send controls are allowed only when the Instantly email ID, receiving account, prospect address and authoritative thread/email routing are sufficient. Withholding Send never withholds the notification.

## Discovery paths

- Authenticated `reply_received` webhook: n8n header-authenticates the provider request and forwards the unfiltered payload to the private sidecar. The sidecar normalizes and transactionally registers it before attempting Chat.
- Recovery poll: every minute, queries Instantly directly with a five-minute overlap and its own timestamp-plus-email-ID cursor. It processes every page and advances only after the complete range is durable.
- Completeness auditor: independent short (five minutes / two hours), deep (hourly / 24 hours), and daily (seven days) schedules. It neither reads nor advances the normal poll cursor.
- Backfill: an internal, bounded operator command using the same service and normalizer. Dry-run is non-mutating; apply has no prospect-send adapter.

All four paths converge on `normalizeInstantlyReceived()` and `registerInbound()` in the sidecar. Database uniqueness suppresses webhook/poll/auditor races.

## Durable identity and outbox

The sidecar uses `inbound-v2.sqlite` with WAL, `synchronous=FULL`, foreign keys, strict tables and schema version 2. Relevant tables are:

- `inbound_records`: canonical identity and sanitized routing/presentation metadata;
- `notification_outbox`: exactly one logical outbox row per inbound identity;
- `notification_attempts`: append-only transport attempt history;
- `identity_aliases`: surrogate-to-Instantly identity reconciliation;
- `worker_leases` and `poll_state`: crash-safe claims and cursor state;
- `audit_runs`, `audit_discrepancies`, `heartbeats`, `operational_alerts`, `event_counters`, and `reconciliation_snapshots`: independent evidence and telemetry.

Inbound and outbox insertion occur in one `BEGIN IMMEDIATE` transaction. Unique constraints enforce one row per Instantly email ID and one outbox per inbound identity. An outbox worker atomically claims due rows with an expiring lease, records an attempt before the network call, and accepts success only for a Google 2xx response containing a message resource `name`.

There is no finite retry cap. Failed and response-ambiguous attempts receive bounded exponential backoff (maximum 30 minutes). A crashed posting lease becomes an ambiguous preserved attempt before it is reclaimed. Auditors may requeue unacknowledged rows but cannot steal an active posting lease.

Google response loss is at-least-once: the item remains retryable, reuses a deterministic thread key, and the next post is labelled as a probable duplicate recovery. The system does not claim visual exactly-once delivery where the webhook transport cannot query by message identity.

Legacy migration treats a syntactically valid `spaces/.../messages/...` resource name as the definite acknowledgement, even when an early context predates the later `notificationState` field. The same check runs when an auditor discovers an existing legacy context after startup. This preserves the original Chat acknowledgement and prevents a completeness audit from re-posting an already-visible message merely because the newer state field is absent.

## Malformed and surrogate records

A valid Instantly email ID is always the primary identity even when every optional field is missing or malformed. Registration precedes enrichment. Chat receives a metadata-incomplete card and Send is blocked only where routing cannot be proven.

If an observed record has no Instantly ID, a SHA-256 surrogate combines workspace, receiving account, RFC Message-ID, thread, received timestamp, sender, safe body hash and a hash of the complete raw object. The stored row is `SURROGATE_UNVERIFIED`, gets a notification, exposes no Send control, and is reconsidered on overlapping audits.

Merge requires non-contradictory authoritative fields plus a matching thread/content fingerprint. A reused RFC Message-ID across receiving accounts cannot merge. If both candidate identities already have attempt history, histories are preserved and renumbered. An active transport lease defers the merge. A prior Chat acknowledgement is preserved; irreducible dual acknowledgements are counted as probable duplicates.

## Cursor and pagination invariants

- Query ordering uses Instantly's strongest available ascending pagination token.
- Every page is deduplicated by canonical email identity.
- Equal timestamps are not collapsed.
- A rolling overlap handles late indexing and page mutation.
- API 401, 429, 5xx, network errors, invalid/oversized schemas, page-token loops, final-page failure and durable-store failure prevent cursor advancement.
- Partial rows already made durable remain safe and idempotent; the unchanged cursor causes the range to be retried.
- Independent deep audits limit dependence on any one cursor.

The Instantly page reader streams and bounds decompressed JSON at 8 MiB per page. Google Chat responses retain a separate 100 KiB limit.

## Historical boundary

Records before `INBOUND_NOTIFICATION_EPOCH=2026-07-18T18:33:00Z` are durably registered as `HISTORICAL_OWNER_HOLD`. They are visible in reconciliation but excluded from the active notification queue. This implements the owner's standing decision not to flood Chat with the pre-console historical set. It is not used for post-epoch records.

Historical holds are also excluded from retry-backlog and malformed-unacknowledged watchdog facts. They remain explicit in `historical_owner_hold` counts and in direct reconciliation; this exemption prevents a deliberate owner hold from masquerading as an active delivery failure.

## Security boundary

The sidecar has no published host port and accepts operational calls only on the private Compose network. The public n8n webhook uses an encrypted header-auth credential. Chat posting accepts only HTTPS `chat.googleapis.com`, rejects redirects and arbitrary destinations, caps/sanitizes metadata, strips markup/control characters, and never logs bodies or credentials. Backfill/audit ranges and Chat destinations are not user-supplied through a public endpoint.

The notification modules contain no Instantly prospect-reply POST adapter. The legacy supervised-send gate, drafts, tokens and attempts remain in their original store and are not mutated by inbound-v2 operations.

## External boundary

The internal guarantee starts at records Instantly exposes as received. An email absent from Instantly and from every accessible provider source cannot be synthesized into an authoritative Instantly thread. A mailbox-versus-Instantly comparator, if later credentialed, is additional operational visibility rather than an alternative reply-ingestion path.
