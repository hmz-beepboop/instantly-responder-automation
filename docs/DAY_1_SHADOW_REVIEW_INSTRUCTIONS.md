# Day 1 Shadow Review — Step-by-Step Instructions

**Version:** 1.0  
**Date:** 2026-06-24  
**Phase:** 5K — Gate 2 Evidence Start  
**Purpose:** Exact instructions for running Day 1 of the 14-day manual shadow review

---

## Before You Start

Confirm all of these are true before touching anything:

- [ ] You are in: `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation`
- [ ] You have at least 1 real inbound reply waiting in Instantly.ai
- [ ] The Decision workflow in n8n has processed that reply (you can see it in execution history)
- [ ] You have your n8n execution history open at `https://n8n.hmzaiautomation.com`

---

## Step 1 — Confirm Shadow Evaluator is OFF

Go to `https://n8n.hmzaiautomation.com` → open workflow `aHzLtQiv6G8h1bqD`.

Confirm the Active toggle is **OFF** (grey, not green).

Do not turn it on. It must stay off throughout the entire 14-day review period.

---

## Step 2 — Create Today's Review Sheet

Open a PowerShell terminal in the project folder and run:

```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -CreateDailyReviewSheet -Day 1
```

This creates: `outputs\shadow_review_days\shadow_review_day_1_YYYY-MM-DD.json`

Open this file. You will fill it in as you work through real replies.

Also open: `outputs\shadow_review_days\day_1_owner_working_file.json` — this is your scratch pad.

---

## Step 3 — For Each Real Reply You Review

### 3a. Open the reply in Instantly.ai

Find a real inbound reply from a prospect. Read it carefully.

### 3b. Find the Decision workflow output in n8n

- Go to `https://n8n.hmzaiautomation.com`
- Open the Decision workflow: `tgYmY97CG4Bm8snI`
- Find the execution that processed this reply (match by thread ID or prospect name)
- Note down these values from the Decision output:
  - `broad_category` (e.g. `SCHEDULING_POSITIVE`)
  - `micro_intent` (e.g. `SCHEDULING_REQUEST`)
  - `confidence` (e.g. `0.91`)
  - Any `risk_flags`

### 3c. Generate a payload for this reply

```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -GeneratePayloadTemplate
```

This creates: `outputs\autonomous_manual_shadow_payload_template.json`

Open the file and fill in the fields:
- `case_id` — use format `case_YYYYMMDD_001` (real date, increment for each case)
- `thread_id` — from Instantly.ai (or use a descriptive label)
- `campaign_id` — from Instantly.ai campaign
- `sender_email` — the sender address that received the reply
- `incoming_text` — the reply text (remove any PII except first name)
- `broad_category` — from Decision output
- `micro_intent` — from Decision output
- `confidence` — from Decision output
- `additional_intents` — from Decision output (if any)
- `risk_flags` — from Decision output (if any)
- `in_human_working_hours` — was it during business hours?

### 3d. Validate the payload

```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ValidateManualPayload -PayloadFile "outputs\autonomous_manual_shadow_payload_template.json"
```

If validation FAILS, fix the errors shown and re-run until it passes.

### 3e. Decide what the shadow evaluator WOULD decide

Look at the payload values and the blocked intent list in `docs/GATE_2_ALLOWLIST_DRAFT_FOR_OWNER_REVIEW.md`.

Ask yourself: **If the allowlists were populated with this campaign, sender, and intent — what would the shadow evaluator do?**

- If `micro_intent` is on the blocked-forever list → **BLOCKED**
- If campaign or sender not in allowlist → **BLOCKED_ALLOWLIST**
- If `confidence` below 0.85 → **BLOCKED_CONFIDENCE**
- If `in_human_working_hours = false` → **BLOCKED_OUT_OF_HOURS**
- If multiple intents, any blocked → **MULTI_INTENT_BLOCK**
- Otherwise → **SHADOW_ELIGIBLE** (would be flagged for autonomous action if autonomy were live)

Record this as the `expected_autonomous_decision` in the day sheet.

### 3f. Record your own assessment

Ask yourself: **Is that decision correct? Would I have made the same call?**

- If you agree → mark `was_correct: true`
- If you disagree → mark `was_correct: false` and write a `learning_signal` explaining why
- If you are uncertain → mark `was_correct: null` and write a note

---

## Step 4 — After Each Reply, Add It to the Day Sheet

Open: `outputs\shadow_review_days\shadow_review_day_1_YYYY-MM-DD.json`

Add an entry to the `cases` array:

```json
{
  "case_id": "case_20260624_001",
  "micro_intent": "SCHEDULING_REQUEST",
  "confidence": 0.91,
  "expected_autonomous_decision": "SHADOW_ELIGIBLE",
  "owner_assessment": "AGREE",
  "was_correct": true,
  "learning_signal": ""
}
```

---

## Step 5 — After Reviewing All Replies for the Day

Export the daily summary:

```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ExportDailySummary -Day 1
```

This creates: `outputs\autonomous_shadow_review_day_1_summary.json`

---

## Stop Conditions — Pause if Any of These Occur

- You find a case where the system would have sent a reply to an opt-out or hostile message
- You find a case where a pricing or legal reply would have been flagged as eligible
- You find 3+ false positives in a single day (cases that would incorrectly be sent)
- You are uncertain about 50% or more of cases in a single day
- Something about the system output looks wrong or unexpected

If you stop: do not panic. Set `stop_flag: true` in the day sheet, write `stop_reason`, and ask Claude Code in your next session.

---

## What Counts as a Good Day 1

- 1–3 real prospect replies reviewed
- Each reply has a complete payload (all fields filled)
- Each payload validated cleanly by the helper
- Each case has your honest assessment recorded
- Summary exported at the end

You do **not** need to review many replies on Day 1. Quality matters more than quantity. Varied reply types matter more than volume.

---

## Files You Will Touch Today

| File | When |
|------|------|
| `outputs\shadow_review_days\shadow_review_day_1_*.json` | Created by helper, filled in by you |
| `outputs\shadow_review_days\day_1_owner_working_file.json` | Scratch pad — optional |
| `outputs\autonomous_manual_shadow_payload_template.json` | Re-generated for each new reply |
| `outputs\autonomous_shadow_review_day_1_summary.json` | Created by ExportDailySummary at end |

---

## Files You Must NOT Touch Today

- Any n8n workflow (Decision, HumanApproval, Proxy, Shadow Evaluator)
- Any file in `docs/` (read-only for reference)
- Any `.env` or credentials file
- `outputs/autonomous_shadow_review_log.json` (written by helper only)

