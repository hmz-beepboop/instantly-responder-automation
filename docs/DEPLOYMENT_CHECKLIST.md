# Deployment Checklist

System verdict: **`READY_FOR_DRY_RUN`**. This checklist does not authorise
any live or controlled-live Instantly send.

## A. Current dry-run readiness checklist (this stage)

- [x] `OPERATING_MODE=VALIDATION`
- [x] `DRY_RUN=true`
- [x] `LIVE_CAMPAIGNS=[]`
- [x] All six workflows imported and `active: false`
- [x] Local exports match remote workflows (`localMatchesRemote: true`,
      `mismatches: []` for all six)
- [x] No credentials bound to any workflow (`credentialsBound: false`)
- [x] Zero external HTTP targets (sidecar-only: `http://hmz-send-state:5681`)
- [x] Phase 4A offline suite passes (42/42)
- [x] Phase 4B offline suite + 60-fixture matrix passes (31/31 + matrix)
- [x] `hmz-send-state` sidecar healthy
- [x] Actual n8n runtime execution succeeds for Full Test Harness
- [x] Actual n8n runtime execution succeeds for SLA Watchdog (manual/CLI
      Schedule Trigger run, documented limitation)
- [x] n8n security audit run and reviewed (generic Code-node advisory only)
- [x] Project secret/PII scan clean (0 real-email, 0 unexpected
      secret-pattern hits)
- [x] `reports/VALIDATION_REPORT.md` verdict recorded as `READY_FOR_DRY_RUN`

## B. Future controlled-live entry checklist (not yet started)

Do not begin any item below without explicit owner approval, and do not
change `DRY_RUN` or `LIVE_CAMPAIGNS` until every item is complete:

- [x] Actual n8n-runtime execution evidence (synthetic inputs) for the Reply
      Sender workflow — an approved synthetic item reached `DRY_RUN_OK`
      (`sent=false`, `transport=NONE`) (`reports/INTEGRATION_CLOSURE_RUNTIME.md`)
- [x] Actual n8n-runtime execution evidence (synthetic inputs) for the Reply
      Error Handler workflow — a forced synthetic item persisted a
      sanitised, non-retryable `SEND_UNCERTAIN` record
      (`reports/INTEGRATION_CLOSURE_RUNTIME.md`)
- [x] Instantly API base host confirmed: `https://api.instantly.ai`
      (`docs/ASSUMPTIONS_AND_UNKNOWNS.md` B1)
- [ ] A durable human-approval mechanism for the Reply Sender's approval gate
      (the normal Intake → Decision Engine → Sender path currently
      terminates `BLOCKED_PENDING_DURABLE_APPROVAL`)
- [ ] Automatic `settings.errorWorkflow` routing exercised from a genuinely
      failed parent execution (currently only exercised via the synthetic
      Execute Workflow Trigger)
- [ ] Zero-match reconciliation path exercised against a live Instantly
      response
- [ ] Multiple-match reconciliation path exercised against a live Instantly
      response
- [ ] SLA Watchdog exercised via an actual active/scheduled cron firing (not
      only a manual/CLI Schedule Trigger run)
- [ ] Owner-approved, narrowly scoped `INSTANTLY_API_KEY` provisioned and
      bound as an n8n credential (not in workflow JSON)
- [ ] Exact, owner-approved campaign ID(s) added to `LIVE_CAMPAIGNS`
- [ ] Full pre-send gate met for each candidate campaign
      (`docs/HMZ_APPROVED_REPLY_RULES.md` §9.1)
- [ ] `DRY_RUN=false` changed only by explicit owner approval, scoped to the
      approved campaign(s)
- [ ] Re-run the Phase 5 mechanical audit (or equivalent) after any of the
      above changes

## C. Production readiness checklist — out of scope / not achieved

The following are explicitly **out of scope for this project stage** and
**not achieved**:

- [ ] Production-scale storage migration (relational `sends`/`errors`
      tables, Postgres/Supabase) — current architecture uses n8n Data Tables
      plus the `hmz-send-state` sidecar only, by design
      (`docs/STATE_AND_IDEMPOTENCY.md` §1)
- [ ] Multi-tenant / multi-workspace support
- [ ] Real semantic classifier integration (currently mocked)
- [ ] `OPERATING_MODE=PROVEN` activation
- [ ] `FIXED_TEMPLATE_AUTO` reply mode for any category
- [ ] Quiet-hours / timezone / holiday scheduling
- [ ] Multiple escalation channels / reporting warehouse / external heartbeat
      monitoring
- [ ] Retention and cleanup policy for the `hmz-send-state` named volume
- [ ] Legal/compliance review and final business-partner policy approval
      (`docs/HMZ_APPROVED_REPLY_RULES.md` §17)

**No activation instruction in this document implies current authorisation
for live sends.**
