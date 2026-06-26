# Autonomous Shadow Evaluator Workflow Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — WORKFLOW IS DISABLED — NOT IN PRODUCTION

---

## Purpose

The autonomous shadow evaluator is a disabled n8n workflow that can be manually triggered with a test payload to produce an eligibility decision object. It is used for design verification and future shadow mode testing — it does not run on production traffic and does not connect to the Sender workflow.

---

## What This Workflow Does

1. Receives a manual test payload (Webhook trigger, manual only)
2. Validates the payload structure
3. Runs the eligibility engine logic against the payload
4. Produces a shadow decision object
5. Logs the result to a placeholder schema (no live DataTable)
6. Returns the decision object to the caller

## What This Workflow Does NOT Do

- Never activates on production traffic
- Never routes to the Sender workflow
- Never calls the Instantly send/reply API
- Never modifies Decision, HumanApproval, Proxy, or any production workflow
- Never reads production data automatically
- Never activates automatically (manual trigger only)

---

## Node Structure

### Node 1 — Webhook (Manual Trigger, Inactive)
- Trigger type: Webhook
- Path: `/autonomous-shadow-eval-test` (non-production path)
- Method: POST
- **Workflow is inactive** — this webhook is not accessible until the workflow is activated

### Node 2 — Validate Input
- Validates required fields: case_id, incoming_text, broad_category, micro_intent, additional_intents, confidence, campaign_id, sender_email
- Rejects any payload missing required fields

### Node 3 — Run Eligibility Gates
- Applies all eligibility gates in order (same logic as SL-PHASE-5C script)
- Uses a hardcoded shadow config (autonomous_enabled=false, dry_run=true, shadow_only=true)
- Cannot be overridden by external config

### Node 4 — Prepare Shadow Decision
- Constructs the full eligibility decision object
- Sets would_send_live_now=false (hardcoded for this disabled workflow)
- Adds shadow_evaluator_mode=true marker

### Node 5 — Log to Placeholder Schema
- Writes result to a local variable (not a live DataTable)
- Produces a JSON output matching autonomous_shadow_log_schema.json

### Node 6 — Return Decision
- Returns the complete decision object as JSON response
- Includes a WARNING header: "SHADOW_EVALUATOR_WORKFLOW — NO PRODUCTION TRAFFIC — DISABLED"

---

## Import Safety

The workflow JSON (`workflows/disabled_autonomous_shadow_evaluator.json`) is:
- Exported with `active: false`
- Has no production webhook connection
- Has no Sender connection
- Has no Instantly API connection
- Has no DataTable write node pointing to live production tables
- Must only be imported with explicit owner approval and only to the correct production workspace

Import command (requires owner approval before running):
```powershell
.\scripts\SL-PHASE-5D-create-disabled-autonomous-shadow-evaluator.ps1 -CreateDisabledWorkflow -WhatIf
```

Never import without `-WhatIf` review first.

---

## Test Payload Format

```json
{
  "case_id": "case-test-001",
  "incoming_text": "Yes I'm interested, tell me more.",
  "broad_category": "POSITIVE_INTEREST",
  "micro_intent": "INFORMATION_REQUEST",
  "additional_intents": [],
  "confidence": 0.91,
  "campaign_id": "test-campaign-001",
  "sender_email": "test@example.com",
  "thread_id": "thread-test-001",
  "duplicate_risk": false,
  "active_rule_conflict": false
}
```

---

## Related Documents

- `workflows/disabled_autonomous_shadow_evaluator.json` — the workflow JSON
- `scripts/SL-PHASE-5D-create-disabled-autonomous-shadow-evaluator.ps1` — import script
- `docs/AUTONOMOUS_PHASE_5_ARCHITECTURE.md` — architecture context
- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — what this workflow may not do
