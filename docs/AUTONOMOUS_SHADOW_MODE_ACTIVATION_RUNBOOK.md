# Autonomous Shadow Mode Activation Runbook

**Version:** 1.0  
**Date:** 2026-06-24  
**Purpose:** Step-by-step operator procedure for shadow evaluator control  
**Owner approval required:** Gate 1 (already approved 2026-06-24)

---

## Overview

The shadow evaluator (`aHzLtQiv6G8h1bqD`) receives controlled test payloads, evaluates eligibility, and returns a shadow decision. It **never sends live emails**, **never calls Sender**, and **never calls Instantly API**. `would_send_live_now` is hardcoded `false`.

---

## Pre-Requisites

| Requirement | Check |
|-------------|-------|
| `HMZ_N8N_API_KEY` env var set | `$env:HMZ_N8N_API_KEY -ne ""` |
| Workflow ID `aHzLtQiv6G8h1bqD` exists in n8n | Gate 1 confirmed |
| Gate 1 approved in `AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` | APPROVED 2026-06-24 |
| No Sender connection in workflow | Safety check SC-04/SC-05 |
| `would_send_live_now` hardcoded false | Safety check SC-06 |

---

## Step 1 — Set API Key (One Time Per Session)

```powershell
$env:HMZ_N8N_API_KEY = "<from secure store>"
```

**Never** paste or print the API key. Retrieve it from your password manager only.

---

## Step 2 — Safety Check (No API Calls)

```powershell
cd "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -SafetyCheck -WhatIf
```

**Expected output:**
- `[PASS] SC-01` through `SC-10` all green
- `[SAFE] All safety checks passed.`
- `[WHATIF] WhatIf mode — no production API calls made.`

If any SC check fails: **stop and repair before proceeding**.

---

## Step 3 — Safety Check Only (Validates Local JSON, No Activation)

```powershell
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -SafetyCheck
```

Same checks as Step 2 but without WhatIf restriction. Still no API calls — only reads the local workflow JSON.

---

## Step 4 — Full Controlled Test Run

Activate, test 20 payloads, deactivate, export report — all in one command:

```powershell
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 `
    -ActivateShadowTemporarily `
    -RunControlledWebhookTests `
    -UseSamplePayloads `
    -NoLiveSendAssertion `
    -ExportShadowTestReport `
    -DeactivateShadow
```

**What this does:**
1. Reads local workflow JSON — confirms active=false, no Sender, no Instantly send path
2. Calls n8n API to GET workflow — confirms active=false and name contains "DISABLED"
3. Calls `POST /workflows/aHzLtQiv6G8h1bqD/activate`
4. POSTs 20 sample payloads to `/webhook/autonomous-shadow-eval-test`
5. Asserts `would_send_live_now=false` in every response
6. Calls `POST /workflows/aHzLtQiv6G8h1bqD/deactivate` regardless of test outcome
7. Writes `outputs/autonomous_shadow_control_report.json`
8. Writes `outputs/autonomous_shadow_test_results.json`

**Expected:** 20/20 PASS, `final_active_state=false`, no live sends.

---

## Step 5 — Emergency Deactivation (If Needed)

If the workflow is accidentally left active, run:

```powershell
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -DeactivateShadow
```

Or manually in n8n UI:
1. Open `https://n8n.hmzaiautomation.com`
2. Find workflow `HMZ Autonomous Shadow Evaluator [DISABLED — DO NOT ACTIVATE WITHOUT OWNER APPROVAL]`
3. Toggle active → OFF

---

## Step 6 — Verify Final State

After any test run, verify active=false:

```powershell
# Check the report
Get-Content outputs/autonomous_shadow_control_report.json | ConvertFrom-Json | Select-Object final_active_state, all_safety_checks_passed, all_tests_passed
```

Expected: `final_active_state = False`, `all_safety_checks_passed = True`, `all_tests_passed = True`

---

## Safety Guarantees

| Property | Value |
|----------|-------|
| `would_send_live_now` | Always `false` — hardcoded |
| Sender called | Never |
| Instantly send/reply API called | Never |
| Production responder workflows affected | Never |
| Live emails sent | Never |
| Secrets printed | Never |
| Escalation channel | Referenced as `GOOGLE_CHAT_WEBHOOK_URL` env var only |

---

## Escalation Channel

The escalation channel is configured as the environment variable `GOOGLE_CHAT_WEBHOOK_URL`. The actual webhook URL is never printed or logged. It is stored in the n8n credentials store and referenced only by environment variable name.

**If the escalation channel is unavailable:** document as `REQUIRED_BEFORE_AUTONOMOUS_PILOT` and proceed without live escalation during shadow mode. Shadow mode decisions are still logged to the output report.

---

## Related Documents

- `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` — gate approvals
- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — kill switch procedure
- `docs/AUTONOMOUS_ROLLBACK_DRILL.md` — drill procedure
- `docs/AUTONOMOUS_INCIDENT_RESPONSE_RUNBOOK.md` — incident response
- `outputs/autonomous_shadow_control_report.json` — test results
