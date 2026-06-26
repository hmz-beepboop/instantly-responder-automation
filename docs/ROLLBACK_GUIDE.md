# Rollback Guide

This guide covers rolling back changes made during or after Phase 5/6
validation work. The current system has `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`,
no bound credentials, and all six workflows inactive — rollback should
restore exactly that state if any of it drifts.

## 1. Deactivate all workflows

If any of the six workflows (`cCcpFfi6iovWS94T`, `NJcnNQoJ5nSIWYte`,
`OzYLWuCF6DoU7Iw9`, `koyKIaY2ExF3yhx7`, `37p0OPzfDxlPvYQo`, `gu9Ede8IM5cHGtKK`)
is found `active: true`, deactivate it immediately. All Phase 5 evidence
assumes `active: false` for all six.

## 2. Restore prior workflow exports

If a workflow's remote state no longer matches its export under
`workflows/` (`localMatchesRemote: false`), re-import the last known-good
export from `workflows/` rather than hand-editing the remote workflow. Do
not overwrite an export under `workflows/` with an unreviewed remote state.

## 3. Remove live allowlist entries

If `LIVE_CAMPAIGNS` contains any entry, remove all entries and restore
`LIVE_CAMPAIGNS=[]` unless an owner-approved controlled-live test is
explicitly in progress and documented.

## 4. Restore `DRY_RUN=true`

If `DRY_RUN=false` anywhere (environment, config, or workflow Code-node
constants), restore `DRY_RUN=true` immediately unless an owner-approved
controlled-live test is explicitly in progress and documented.

## 5. Remove credential bindings

If any n8n credential (Instantly API key or otherwise) is bound to any of
the six workflows, remove the binding so `credentialsBound: false` is
restored, unless an owner-approved controlled-live test is explicitly in
progress and documented. Never delete the underlying credential object
without confirming it is not needed elsewhere.

## 6. Inspect sidecar state before deletion

Before deleting or resetting any `hmz-send-state` data:

- Query `GET /v1/unfinished` to list in-progress/uncertain send records.
- Review any `SEND_UNCERTAIN`, `HUMAN_REVIEW_ZERO_MATCHES`, or
  `HUMAN_REVIEW_MULTIPLE_MATCHES` records.
- Review any unresolved error records (via the error-listing/resolve
  endpoints).

Do not delete the `hmz_send_state_data` volume or any state file while
unresolved or uncertain records exist.

## 7. Preserve uncertain-send records

`SEND_UNCERTAIN`, `HUMAN_REVIEW_ZERO_MATCHES`, and
`HUMAN_REVIEW_MULTIPLE_MATCHES` records must be preserved during rollback.
These states are forward-only and represent the only record of an outcome
that may need human reconciliation against Instantly. Rolling back workflow
configuration must never delete these records.

## 8. Never delete evidence needed for reconciliation

Do not delete:

- `reports/` validation/audit reports
- `verification/phase5/mechanical-audit.json` and other phase audit JSON
- Sanitised error records or `harness_result`/`watchdog_result` persisted
  via `POST /v1/phase4b/result`
- Any `hmz-send-state` durable record referenced by an unresolved
  `SEND_UNCERTAIN` or `HUMAN_REVIEW_*` state

These are the evidence base for `reports/VALIDATION_REPORT.md` and for any
future reconciliation against Instantly.

## 9. Docker Compose rollback

To roll back the local environment itself:

```
docker compose -f infrastructure/local-n8n/docker-compose.yml down
```

This stops and removes the `hmz-n8n-local-dev` and `hmz-send-state`
containers but **preserves** the named volumes (`hmz_n8n_local_dev_data`,
`hmz_send_state_data`) unless `-v`/`--volumes` is also passed. Do not pass
`-v`/`--volumes` unless you have completed step 6-8 above and confirmed no
unresolved or uncertain records remain. Re-start with:

```
docker compose -f infrastructure/local-n8n/docker-compose.yml up -d
```

## 10. Verification after rollback

After any rollback:

- Confirm all six workflows are `active: false`.
- Confirm `localMatchesRemote: true` for all six against `workflows/`.
- Confirm `credentialsBound: false` and `externalHttpTargets: []` for all
  six (unless an approved controlled-live test is documented as in
  progress).
- Confirm `DRY_RUN=true` and `LIVE_CAMPAIGNS=[]`.
- Confirm `hmz-send-state` is healthy and no unresolved `SEND_UNCERTAIN` /
  `HUMAN_REVIEW_*` records were lost.
- Re-read `reports/VALIDATION_REPORT.md` to confirm the verdict
  (`READY_FOR_DRY_RUN`) still applies to the rolled-back state.
