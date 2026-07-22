# Inbound Completeness Operator Runbook v2

Production target: `https://n8n.hmzaiautomation.com/api/v1` only. Run `scripts/assert-hmz-production-target.ps1` before an n8n API call. Never print API keys, Chat URLs, webhook secrets, bodies or the protected production environment.

This runbook covers inbound notification visibility. Do not toggle `/data/go-live.json`, Sender, Shadow, Gate 2, autonomous mode, campaigns, leads or accounts while using it.

## Expected production components

- sidecar: `hmz-reply-console-business-live`, healthy, internal port 5691;
- authenticated Instantly `reply_received` subscription;
- authenticated Instantly `email_sent` subscription (unchanged, send reconciliation only);
- recovery poll: one-minute schedule;
- completeness auditor: five-minute/two-hour, hourly/24-hour and daily/seven-day schedules;
- reliability watchdog;
- SQLite store: `/data/inbound-v2.sqlite` on the preserved reply-console volume.

Safe internal endpoints expose counts and sanitized error kinds only:

- `GET /health`
- `GET /v2/operations`
- `GET /v2/watchdog`
- `POST /v2/poll`
- `POST /v2/audit/short`
- `POST /v2/audit/deep`
- `POST /v2/audit/daily`
- `POST /v2/outbox/drain`

The POST endpoints are private-network operations, not public controls. They cannot select a Chat URL, arbitrary date range or prospect-send action.

## Normal health check

1. Confirm the container is healthy and its image ID matches the release evidence.
2. Read `/health`; require store integrity `true`.
3. Read `/v2/operations`; require:
   - `outbox_missing=0`;
   - `queued=posting=retrying=ambiguous=0` for mature records;
   - `queueDepth=0` after the retry grace period;
   - fresh `recovery_poll`, `audit_short`, `audit_deep`, `audit_daily`, and `watchdog` successful heartbeats;
   - no unexplained active alert.
4. Read the exact global-send record and compare its value, note, timestamp and hash with the handoff. Do not rewrite it to “confirm” it.
5. Check recent scheduled n8n executions. A manual endpoint call is diagnostic evidence, not proof that a schedule is firing.

The primary completeness statement must come from a direct Instantly reconciliation: “X of Y Instantly-visible inbound records in this window have definite Google Chat acknowledgement.” Historical event counters are secondary and must not be used as the denominator.

For an all-time claim, a seven-day or console-epoch window is insufficient.
Query from a safely early timestamp through a fixed current boundary with full
pagination, then report the earliest returned timestamp. On 2026-07-21 the
first genuine all-time query returned 973 identities from 15 January onward;
895 pre-6-July identities were outside the then-current store. Never reuse the
earlier 78-row bounded result as an all-time denominator.

## Direct bounded reconciliation

Run the shared sidecar service internally with an explicit `since` and `until`. Report only IDs, timestamps, classifications, states and counts; never raw bodies. Required operational windows are the burst/test window, campaign-resumption window, incident-repair window, last 24 hours and last seven days.

For each window capture:

- Instantly received observed;
- durable inbound present/missing;
- outbox present/missing;
- `CHAT_NOTIFIED`, queued, retrying and ambiguous;
- historical owner hold;
- degraded, bounce/system and surrogate counts;
- duplicate logical identities and probable duplicate posts.

Use `repair=false` first. If a post-epoch gap is real, back up the store, then run the same bounded range with `repair=true`; the service creates the inbound/outbox, requeues it and never sends a prospect reply. Re-run read-only reconciliation after the queue drains.

## Alert response

`INSTANTLY_401`: verify the protected API key mapping; do not rotate or print it during diagnosis. The poll/auditor cursor must remain unchanged.

`INSTANTLY_429`: allow bounded backoff. Do not increase schedule frequency. Confirm deep/daily ranges remain covered.

`INSTANTLY_5XX` or network error: retain the old cursor and observe retries. A provider outage is not a reason to mark records complete.

`INSTANTLY_INVALID_JSON`, `INSTANTLY_INVALID_SCHEMA`, or `INSTANTLY_RESPONSE_TOO_LARGE`: record status, byte size and top-level keys only. Do not log the body. The cursor must not advance.

`RETRY_BACKLOG` or Chat 4xx/5xx: individual outbox rows remain retryable without an attempt cap. Confirm deterministic thread keys and do not mass-mark acknowledgements.

`AMBIGUOUS_CHAT_RESPONSE`: the transport may have accepted the post. Do not mark notified without a message resource name. The retry will be labelled as a probable duplicate recovery.

`STUCK_POSTING_LEASE`: after lease expiry, the worker records the open attempt as ambiguous and reclaims it. Do not clear leases by hand.

`SURROGATE_IDENTITY_UNRECONCILED`: inspect only safe identity fields. Never force a merge across contradictory mailboxes, senders or threads.

`MALFORMED_RECORD_UNACKNOWLEDGED`: routing defects may block Send but never notification. Confirm the degraded item remains queued/retrying.

`HISTORICAL_OWNER_HOLD` is not a retry failure and must not raise `MALFORMED_RECORD_UNACKNOWLEDGED`. It remains visible in reconciliation. If a legacy context has a valid stored Google Chat message resource but no `notificationState` field, treat the resource as the definite legacy acknowledgement; do not re-post it.

## Backups

Before a production change:

1. ensure no relevant running n8n execution or migration;
2. capture the exact gate file and SHA-256;
3. export every relevant workflow and active/version state;
4. create two durable-volume file manifests around a sorted archive without pausing the sidecar; require the manifests to match;
5. copy source, Dockerfile, Compose and protected environment into a root-only backup;
6. verify every hash and extract/read the data archive;
7. scan repository and release artifacts for secrets.

If the two data manifests differ, discard that candidate backup and retry; do not treat it as consistency-safe.

## Rollback

Rollback never changes the global-send record.

1. Point the Instantly subscription back to the still-active previous notification webhook if it was switched.
2. Restore the pre-change Compose file.
3. Recreate only `hmz-reply-console` with `--no-deps --no-build`; the previous image remains locally addressable by its recorded digest.
4. Preserve the volume. Do not restore data unless integrity is bad and the owner approves data restoration.
5. Verify health, exact gate hash, active old notification/poll/watchdog workflows, and a successful genuine poll cycle.
6. Deactivate only a newly introduced auditor workflow if its endpoint does not exist after rollback; never deactivate the established recovery poll or watchdog.

If data restoration is explicitly approved, stop only the sidecar, archive the failed volume first, extract the verified data backup, restore ownership, restart, and compare exact counts/hashes. Do not use `git reset`, delete contexts, or clear send locks.

## Historical owner decision

Pre-epoch rows in `HISTORICAL_OWNER_HOLD` are expected and must be reported separately. Do not requeue or post them without an explicit owner decision. They must not dilute post-deployment completeness percentages.

The 2026-07-21 final-closure authorization covered exactly 38 verified hold
rows. It did not cover 895 additional all-time identities discovered in Phase
1. Do not infer range expansion from the general completeness objective: obtain
an explicit owner decision, refresh the exact manifest, back up the store and
rate-limit individual historical posts to at most five per minute.
