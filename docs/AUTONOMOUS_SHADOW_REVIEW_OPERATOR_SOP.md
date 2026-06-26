# Autonomous Shadow Review — Operator SOP

**Version:** 1.0  
**Date:** 2026-06-24  
**Audience:** Owner / operator running the 14-day manual shadow review  
**Time per session:** 15–30 minutes per day  
**Required tools:** PowerShell 7+, n8n access, Instantly.ai access

---

## What Is the Shadow Review?

The shadow review is a 14-day period where you manually check whether the autonomous system would make good decisions on real prospect replies — WITHOUT it ever sending anything.

You are doing a test drive with the engine running but the car in neutral.

**Outcome:** After 14 days, you will have evidence to decide whether the system is ready for Gate 2 (1 autonomous send per day, strictly monitored).

---

## Quick Start (Run This Every Day)

```powershell
# Step 1 — Create today's review sheet (replace N with day number)
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -CreateDailyReviewSheet -Day N

# Step 2 — Get a payload template for each reply you want to review
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -GeneratePayloadTemplate

# Step 3 — Fill in the template with the real reply details (text editor)
# Save as: outputs/shadow_review_payloads/day_N_case_1.json

# Step 4 — Validate the payload before submitting
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ValidateManualPayload -PayloadFile outputs\shadow_review_payloads\day_N_case_1.json

# Step 5 — Append result to the day sheet
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -AppendShadowReviewResult -PayloadFile outputs\shadow_review_payloads\day_N_case_1.json

# Step 6 — Export daily summary at the end
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ExportDailySummary -Day N
```

---

## Detailed Step-by-Step

### Before You Start Each Day

1. Confirm the shadow evaluator is `active=false` in n8n:
   - Open `https://n8n.hmzaiautomation.com`
   - Find workflow `aHzLtQiv6G8h1bqD`
   - Confirm the Active toggle is grey/off
   - If it is green/on: do NOT proceed. Contact Claude Code immediately.

2. Check the main Decision workflow is running:
   - In n8n, find workflow `tgYmY97CG4Bm8snI`
   - Confirm it is Active
   - Check for any error notifications in the execution log

3. Open `docs/AUTONOMOUS_SHADOW_REVIEW_DAILY_CHECKLIST.md` — print a copy or keep it open

### Selecting Candidates

1. Log in to Instantly.ai
2. Go to your active campaign inbox
3. Look at today's inbound replies
4. Select 1–5 replies for review (start with 1–2 in the first week)

**Skip immediately without review:**
- Any reply that contains an unsubscribe request, opt-out, or "remove me"
- Any reply that contains threatening or abusive language
- Any reply that is clearly automated spam or a bounce

These skip cases are NOT errors — route them to human review normally using the main responder.

### Filling In a Payload Template

Open the generated template and fill in these fields from the real reply:

| Field | Where to Find It | Example |
|-------|-----------------|---------|
| `prospect_email` | Reply sender address (mask it: use first 3 chars + @domain) | `joh@example.com` |
| `campaign_id` | Instantly.ai campaign URL | `abc123xyz` |
| `sender_email` | Your sending account used | `you@yourcompany.com` |
| `reply_text` | Paste the actual reply text | `"Sounds interesting, when can we chat?"` |
| `your_intent_assessment` | What YOU think the intent is | `SCHEDULING_REQUEST` |
| `your_block_assessment` | Should it block? YES/NO | `NO` |
| `your_notes` | Anything unusual | `"Reply is very short but clear"` |

**Do not include:**
- Full prospect names (use masked email only)
- Phone numbers
- Company addresses
- Any sensitive personal information

### What the System Returns

After validation, the helper returns the autonomous system's assessment:

| Field | Meaning |
|-------|---------|
| `shadow_action` | What the system decided: SHADOW_LOG, HUMAN_REVIEW, PERMANENT_BLOCK, or BLOCKED_NOT_ELIGIBLE |
| `block_reason` | If blocked, why |
| `confidence` | 0.0–1.0 — how confident the system is |
| `would_send_live_now` | Always false — confirms no live send |
| `micro_intent` | The system's intent classification |

### Evaluating the Result

After seeing the system's decision, record YOUR assessment:

- **AGREE** — the system made the right call
- **DISAGREE — system too permissive** — system would have sent when you would not (false positive)
- **DISAGREE — system too restrictive** — system blocked when you think it should have been eligible (false negative)
- **UNCERTAIN** — you are not sure yourself

**False positives (system too permissive) are the most important to catch.** If the system would send when it should not, that is a safety concern. Log these with full notes.

### End of Day

1. Export the daily summary:
   ```powershell
   .\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ExportDailySummary -Day N
   ```

2. Review the summary metrics:
   - If `false_positive_count > 0` → do NOT advance toward Gate 2 without resolving
   - If `false_negative_count > 3 in a day` → note for review — system may be too conservative

3. Save the day sheet to `outputs/shadow_review_days/`

---

## Weekly Review (End of Week 1 and Week 2)

At the end of each week, review all 7 daily summaries together:

1. Count total cases reviewed
2. Count total false positives (aim: 0)
3. Count total false negatives (aim: below 20%)
4. Note any patterns in disagreements
5. Check if the intent types being classified match what you expected

If week 1 shows systemic false positives: **stop and contact Claude Code before continuing.**

---

## Pass Criteria for Gate 2 Readiness

| Metric | Required |
|--------|----------|
| Days reviewed | 14 minimum |
| Total cases reviewed | 30 minimum |
| False positive rate | 0% (zero false positives) |
| Unresolved disagreements | 0 |
| Weekly summaries filed | 2 |
| Owner satisfaction rating | "Satisfied" or above |

---

## Files Produced During Shadow Review

| File | Purpose |
|------|---------|
| `outputs/shadow_review_days/shadow_review_day_N_YYYY-MM-DD.json` | Daily log |
| `outputs/shadow_review_payloads/day_N_case_K.json` | Individual payload records |
| `outputs/shadow_review_summary_week_1.json` | Week 1 summary |
| `outputs/shadow_review_summary_week_2.json` | Week 2 summary |

Keep all these files. They are your evidence for Gate 2 approval.

---

## Escalation

If at any point you are unsure whether a case is safe to continue reviewing, stop and start a new Claude Code session with:

> "I am running the 14-day shadow review and have a case I am unsure about. The system decided [X] but I expected [Y]. Here is the payload: [paste payload]."

Do not try to debug the autonomous system yourself during the shadow review. That is Claude Code's job.
