# Mailbox-to-Instantly Gap Detection Plan

Status: owner-gated design only. It is not deployed because this audit found no legitimate Microsoft 365/GoDaddy mailbox or transport-trace credential in the current production mapping. The existing Instantly and Google Chat credentials cannot establish mailbox delivery.

## Purpose and boundary

The comparator detects mail accepted by the destination mailbox provider but absent from Instantly after a bounded delay. It is additional operational visibility. It must never fabricate an Instantly email ID, campaign, lead, thread, normal reply context or Send action.

An alert would read:

> ⚠️ Email received by mailbox but missing from Instantly
>
> Reply through the Instantly console is unavailable.

Only safe sender, recipient, subject and provider-received timestamp are included. No body or attachment content is sent to Chat or logs.

## Required owner inputs

The owner must provide or approve all of the following before implementation:

1. Provider identity: Microsoft 365/Exchange Online, GoDaddy-hosted Microsoft 365, or another named service.
2. Read-only application or delegated credentials with the narrowest mailbox/message-trace scopes.
3. Exact destination mailbox allowlist and tenant/organisation mapping.
4. Confirmation that message-trace and mailbox APIs may be queried for operational monitoring.
5. A dedicated operational Google Chat destination, or approval to reuse the fixed notification destination.
6. Retention and acceptable indexing-delay thresholds.

Credentials must remain in the root-owned environment or provider secret store. They must not enter n8n workflow JSON, repository files, evidence, process arguments or logs.

## Proposed design

Use an isolated read-only sidecar module and independent SQLite tables. It has no import from the supervised-send adapter and no endpoint capable of sending email.

1. Query provider-received message metadata for allowlisted mailboxes using a rolling overlap.
2. Query Instantly `email_type=received` directly over the same bounded window and every page.
3. Normalize stable identifiers in priority order:
   - exact RFC Message-ID plus receiving mailbox;
   - provider Internet message ID plus receiving mailbox;
   - otherwise a conservative fingerprint of mailbox, sender, subject and provider timestamp bucket.
4. Allow a measured Instantly indexing grace period before declaring a discrepancy.
5. Persist one comparator observation and one operational-alert outbox transactionally.
6. Post only through the fixed Chat host, store the returned message resource name, retry without a finite cap, and use an expiring lease.
7. Resolve the alert only when the same provider message later appears in Instantly or an operator records provider evidence explaining exclusion.

The comparator database must durably deduplicate by provider message identity. A weak fingerprint is labelled `PROVIDER_SURROGATE_UNVERIFIED`; contradictory receiving mailboxes can never merge. When an Instantly ID appears later, it is linked as an alias but no normal reply context is created by the comparator.

## Safe schedules

Initial proposal, subject to measured provider limits:

- every five minutes: last two hours;
- hourly: last 24 hours;
- daily: last seven days.

Each range uses overlap, full pagination and its own cursor/lease. API failures preserve the previous successful range and heartbeat. Provider and Instantly results are stored as metadata-only hashes/counts; bodies are discarded before persistence.

## Security acceptance gates

Before deployment prove:

- provider scope is read-only and restricted to the allowlist;
- no `sendMail`, SMTP, reply, forward or draft permission/path exists;
- no arbitrary mailbox, date range, URL or Chat payload is accepted publicly;
- provider URLs and Chat host are fixed allowlists; redirects are rejected;
- logs neutralize control characters and contain no body, token or credential;
- payload/page size, concurrency, retry and retention are bounded;
- RFC Message-ID reuse across mailboxes cannot collapse records;
- a mailbox-only observation cannot activate Send or impersonate an Instantly thread;
- rollback removes only the comparator and leaves the Instantly console untouched.

## Acceptance test

Use owner-controlled messages to an allowlisted test mailbox:

1. provider and Instantly both see the message: no gap alert;
2. provider sees it and a mock Instantly adapter omits it past grace: one alert;
3. the message later appears in Instantly: discrepancy resolves without a second normal notification from the comparator;
4. duplicate provider pages/races/restarts: one logical alert;
5. Chat outage/response loss: durable retry and labelled probable duplicate;
6. provider 401/429/5xx and final-page failure: no cursor advancement or false success;
7. verify zero prospect-send calls.

## Current owner decision

Provide/approve narrow read-only mailbox or message-trace access and the exact mailbox allowlist, or accept `INSUFFICIENT_PROVIDER_EVIDENCE` for transport-layer attribution beyond the evidence already available from Instantly.
