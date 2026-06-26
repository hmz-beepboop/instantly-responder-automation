# Instantly Responder Build Status

**Audit date:** 2026-06-15  
**Target:** supervised HMZ business use with mandatory human approval  
**Current release status:** `RELEASE_BLOCKED_OFFLINE_CONTRACT_FIX_REQUIRED`

## Overall completion

`████████████████░░░░ 80%`

This percentage tracks the supervised-business-use target, not unattended
production auto-send.

## Fixed milestones

| Milestone | Weight | Status |
|---|---:|---|
| API and webhook verification | 10% | COMPLETE |
| Intake, policy and duplicate protection | 10% | COMPLETE |
| Atomic send state and uncertain-send reconciliation | 15% | COMPLETE |
| Error Handler, Watchdog and Test Harness | 10% | COMPLETE |
| Durable human approval mechanism | 10% | COMPLETE |
| Integrated synthetic n8n dry run | 10% | COMPLETE |
| Hosting, apply, rollback and acceptance assets | 5% | OFFLINE BUILT |
| Correct real Instantly reply/reconciliation contracts | 8% | BLOCKED |
| Correct real suppression execution and verification | 7% | BLOCKED |
| Runtime config injection and secure review surface | 5% | BLOCKED |
| Owner configuration, deployment and credential binding | 5% | NOT STARTED |
| Controlled n8n live acceptance | 3% | NOT STARTED |
| Supervised launch and monitoring | 2% | NOT STARTED |

## Release blockers found in 2.9

1. Reply success handling expects `{status:'sent', messageId}` instead of the
   Instantly Email object response containing `id`, `message_id`,
   `thread_id`, `eaccount`, and related fields.
2. Reconciliation calls obsolete `POST /api/v2/emails/list`; the current
   endpoint is `GET /api/v2/emails` with query filters.
3. Suppression request contracts use incorrect endpoint/body shapes.
4. One suppression router can execute all three HTTP nodes when only one
   action is enabled.
5. Suppression verification does not actually verify the changed lead,
   subsequence or block-list state.
6. The apply script does not inject the approved non-secret config into the
   hardcoded workflow constants and review paths.
7. The controlled-live script sends directly through PowerShell rather than
   exercising the final n8n Reply Sender workflow.
8. Controlled-live preflight treats a missing campaign workspace ID as
   allowlisted.
9. The production review form lacks an authenticated reviewer boundary and
   the reviewer allowlist is advisory rather than fail-closed.
10. Automatic Error Trigger routing and a real scheduled Watchdog firing
    remain unproved.

## Finish line

The responder is **fully built for supervised use** only when all are true:

- release-blocker patch passes independent audit;
- owner inputs are complete;
- review Data Table and named credentials exist;
- workflows apply successfully and remain safe by default;
- local acceptance proves real workflow paths;
- HTTPS deployment and protected production webhooks work;
- one owned-recipient n8n Sender reply succeeds once, in-thread, without a
  duplicate;
- one controlled suppression test verifies workspace-wide protection;
- automatic error routing and scheduled Watchdog firing are proven;
- workflows are activated only in supervised mode;
- rollback and backup are confirmed.

## Remaining execution stages

1. Final release-blocker offline correction.
2. Owner setup and local apply/acceptance.
3. HTTPS deployment and webhook registration.
4. One controlled live acceptance.
5. Supervised launch.

No further architecture or feature-building phase is allowed unless a
specific acceptance test proves a defect.
