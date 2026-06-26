# Business-Ready Controlled-Live Acceptance

**Generated:** 2026-06-18T23:23:07.9750831+00:00
**Mode:** RUN_CONTROLLED_LIVE_REPLY
**Marker:** HMZ-CTRL-20260618T232308-0600eb

## Verdict

CONTROLLED_LIVE_REPLY_FAILED

## What this run did

- Backup directory: C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\verification\business-ready\controlled-live-backup\20260618T232309Z
- Live send performed via the real, approved, production n8n workflow chain: False
- Result (terminal.send_state from the Reply Sender workflow): FAILED
- Email ID / Message ID / Thread ID:  /  / 
- Exactly one outbound Email object confirmed via GET /api/v2/emails: False
- No duplicate after a 60-second observation window: False
- Correct sender confirmed locally: False
- Correct recipient confirmed locally: False
- CC/BCC empty: False
- Confirmed Email ID matches Sender terminal: False
- Confirmed message ID matches Sender terminal: False

## What this script never does

- Never POSTs to the Instantly reply-send endpoint directly; the only send path is the real, approved, production n8n workflow chain.
- Never performs a second send attempt, including on SEND_UNCERTAIN (reconciliation reads only).
- Never leaves config.dry_run=false, config.operating_mode=SUPERVISED_VALIDATION, or a non-empty config.live_campaigns on disk (restored in `finally`).
- Never leaves any of the 7 business-ready workflows active, including the 6 temporarily activated for this run (restored in `finally`). The Full Test Harness is never activated.

## Restoration

- config restored to safe defaults (operating_mode=VALIDATION, dry_run=true, live_campaigns=[]): True
- All 7 workflows inactive after restore: True

## Files

- Detailed JSON: verification/business-ready/controlled-live-acceptance-results.json
