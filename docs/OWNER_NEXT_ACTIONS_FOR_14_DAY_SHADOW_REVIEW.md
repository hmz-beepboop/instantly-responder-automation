# Owner Next Actions: 14-Day Shadow Review

**Version:** 1.0  
**Date:** 2026-06-24  
**Phase:** 5K — Gate 2 Evidence Start  
**Purpose:** Complete operational guide for the owner to run the 14-day shadow review from start to finish

---

## Overview

The 14-day shadow review is a manual evidence-gathering process. You are checking whether the system's classifications and decisions match your own judgment on real prospect replies. Nothing runs automatically during this period. The autonomous layer stays off.

**Why 14 days?** Real prospect replies have variation — scheduling requests on Mondays, out-of-office replies mid-week, pricing questions on Fridays. 14 days gives you a representative sample across different prospect types, reply tones, and situations. Reviewing only one type of reply is not enough.

---

## 1. How to Collect a Real Inbound Reply

1. Log into Instantly.ai and open your inbox
2. Find an inbound reply from a prospect (not an auto-reply from your own campaign)
3. Read it carefully and decide what type of reply it is from your own judgment
4. Note the campaign it came from and the sender address it was sent to

**Good candidates for Day 1:**
- Simple scheduling requests ("Let's jump on a call")
- Simple information requests ("Tell me more")
- Pricing questions ("How much does this cost?")
- Out-of-office replies

**Avoid for first 3 days:**
- Highly ambiguous replies that even you are unsure about
- Angry or hostile replies
- Replies with legal or compliance language

---

## 2. How to Convert a Reply into a Manual Shadow Payload

1. Open the Decision workflow execution that processed this reply in n8n (`https://n8n.hmzaiautomation.com`)
2. Find the `broad_category`, `micro_intent`, `confidence`, and `risk_flags` from the output
3. Run the helper to create a blank payload:
   ```powershell
   .\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -GeneratePayloadTemplate
   ```
4. Fill in all fields in `outputs\autonomous_manual_shadow_payload_template.json`:
   - Use the Decision output values for classification fields
   - Paste the reply text (remove PII beyond first name)
   - Set `in_human_working_hours` based on when the reply arrived
5. Save the file

See `docs/DAY_1_SHADOW_REVIEW_INSTRUCTIONS.md` for step-by-step detail.

---

## 3. How to Run the Helper

All helper commands are safe — no production writes, no activation, no live sends.

```powershell
# Create a fresh day sheet for Day N
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -CreateDailyReviewSheet -Day N

# Generate a blank payload template for a new reply
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -GeneratePayloadTemplate

# Validate a filled-in payload before recording it
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ValidateManualPayload -PayloadFile "outputs\autonomous_manual_shadow_payload_template.json"

# Export the day's summary at end of session
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ExportDailySummary -Day N
```

Replace `N` with the current day number (1–14).

---

## 4. How to Record Whether the System Was Correct

After filling in and validating a payload, decide what the shadow evaluator would have done:

| Situation | Expected Decision |
|-----------|------------------|
| `micro_intent` is on the blocked-forever list | `BLOCKED_INTENT` |
| Campaign or sender not in allowlist | `BLOCKED_ALLOWLIST` |
| `confidence` below 0.85 | `BLOCKED_CONFIDENCE` |
| Reply arrived outside business hours | `BLOCKED_OUT_OF_HOURS` |
| Multi-intent with any blocked component | `MULTI_INTENT_BLOCK` |
| All gates pass | `SHADOW_ELIGIBLE` |

Then record your own assessment:
- Do you agree with this decision?
- Would you have made the same call?
- Record `was_correct: true` or `false` in the day sheet

---

## 5. How to Label Mistakes

If you find a case where the system made the wrong call, label it using the mistake labels in `docs/AUTONOMOUS_SHADOW_REVIEW_MISTAKE_LABELS.md`.

The most important labels to watch for:

| Label | Meaning | Severity |
|-------|---------|---------|
| `FP_SEND_UNSAFE` | System would have sent to an opt-out or hostile reply | **CRITICAL — STOP** |
| `ALLOWLIST_BYPASS` | System would have acted on a campaign/sender not on the list | **CRITICAL — STOP** |
| `LIVE_SEND_FLAG` | Any indication of a real send path being triggered | **CRITICAL — STOP** |
| `FP_WRONG_PROSPECT` | System would have sent to the wrong person | HIGH |
| `FN_CONSERVATIVE` | System blocked something that was clearly fine | Low (conservative is safe) |
| `CT_TOO_LOW` | Confidence threshold let through a borderline case | Medium |
| `POLICY_PROOF` | Proof request handled incorrectly | Medium |
| `POLICY_OOO` | OOO reply handled incorrectly | Medium |

Write the label and a brief explanation in the `learning_signal` field of that case.

---

## 6. How to Record Follow-Up Learning Signal

If you find something that should change the system's behaviour in the future, record it as a learning signal:

```json
"learning_signal": "SCHEDULING_REQUEST with very short text (one word) got confidence 0.87 — borderline. Consider raising threshold for short replies."
```

Learning signals are NOT immediate changes. They are evidence for future sessions. Do not ask Claude Code to make changes based on a single learning signal during the review period.

---

## 7. When to Pause

Pause the review and do not continue to the next day if:

- You find a case where an opt-out or hostile reply would be acted on
- You find any case where a real email would have been sent without your approval
- You find 3+ false positives in a single day (cases that should be blocked but weren't)
- You are uncertain about more than half of the cases in a day
- Something in the system output looks different from what you expected

To pause: set `stop_flag: true` in the day sheet, write `stop_reason`, and leave the day sheet saved.

---

## 8. When to Kill-Switch

Use the kill switch immediately if:

- You see any real email sent to a prospect without your approval
- The shadow evaluator workflow becomes active without you turning it on
- You see any indication of live autonomous behaviour

**Kill switch steps:**
1. Go to `https://n8n.hmzaiautomation.com`
2. Open workflow `aHzLtQiv6G8h1bqD`
3. Click the Active toggle to OFF
4. Note the date and time
5. Start a Claude Code session and explain what you saw

The kill switch takes effect in under 15 seconds. You do not need technical help.

---

## 9. What NOT to Do

| Action | Why |
|--------|-----|
| Turn on the Shadow Evaluator workflow | It must stay off (active=false) throughout all 14 days |
| Make changes to any n8n workflow | The review period is observation only — no changes |
| Approve Gate 2 before Day 14 | 14 days minimum is a hard floor |
| Keep testing the same type of reply | Variety is the point — test different intent types |
| Skip the validation step | Unvalidated payloads produce unreliable data |
| Record assessments without reading the Decision output | Your assessment must be grounded in what the system actually decided |
| Ask Claude Code to populate allowlists during the review | Allowlists are populated only in the Gate 2 activation session |

**Important:** Use varied real client replies. Do not keep testing the same type of reply. The evidence only counts if you have seen different intent types across different days.

---

## 10. What Evidence Is Needed Before Gate 2

You need all of the following before asking Claude Code to run Gate 2:

### Mandatory Evidence

| Evidence | Minimum | Status |
|----------|---------|--------|
| Days of shadow review complete | 14 | 0 of 14 |
| Cases reviewed total | 30 | 0 of 30 |
| Unresolved CRITICAL false positives | 0 | N/A |
| RC-SHADOW-001 signed | Yes | Pending |
| RC-SHADOW-002 signed | Yes | Pending |
| Allowlist values ready | Yes (all 3 lists) | Not started |
| Gate 2 checklist signed | Yes | Not started |

### What "Satisfied" Means for the Shadow Review

You are satisfied when:
- You have reviewed at least 30 cases across 14 days
- The cases covered at least 4–5 different intent types (not all scheduling)
- You found zero CRITICAL false positives (FP_SEND_UNSAFE, ALLOWLIST_BYPASS, LIVE_SEND_FLAG)
- You found fewer than 3 HIGH false positives total
- You understand and agree with how the system handles your most common reply types

### How to Tell Claude Code You Are Ready

In a new Claude Code session, after completing all 14 days:

> "14-day shadow review is complete. I reviewed N cases across 14 days. Summary files are in outputs/shadow_review_days/. I have signed RC-SHADOW-001 and RC-SHADOW-002. My allowlist values are: campaign_allowlist: [X], sender_allowlist: [Y], intent_allowlist: [SCHEDULING_REQUEST, INFORMATION_REQUEST]. I am ready for Gate 2 activation."

Do not provide allowlist values until you are ready for that session. Gate 2 activation is a dedicated, separate Claude Code session.

---

## Quick Reference Card

| Day | Action |
|-----|--------|
| 1 | Read these instructions. Run Day 1 sheet. Review 1–3 replies. Export summary. |
| 2–6 | Daily: create sheet, review 2–3 replies, export summary. Mix intent types. |
| 7 | Mid-review check: are you satisfied? Any patterns? Any concerns? |
| 8–13 | Daily: continue review. Start thinking about allowlist values. Sign RC-SHADOW-001/002. |
| 14 | Final review day. Complete Gate 2 readiness checklist. Plan Gate 2 activation session. |

---

## Files Reference

| File | Purpose |
|------|---------|
| `docs/DAY_1_SHADOW_REVIEW_INSTRUCTIONS.md` | Detailed Day 1 step-by-step |
| `docs/AUTONOMOUS_SHADOW_REVIEW_OPERATOR_SOP.md` | Full daily SOP for all 14 days |
| `docs/AUTONOMOUS_SHADOW_REVIEW_MISTAKE_LABELS.md` | All 17 mistake labels with definitions |
| `docs/AUTONOMOUS_SHADOW_REVIEW_FAQ.md` | Answers to common questions |
| `docs/GATE_2_ALLOWLIST_DRAFT_FOR_OWNER_REVIEW.md` | Allowlist planning worksheet |
| `docs/RC_SHADOW_001_OWNER_DECISION_FORM.md` | Proof request policy decision |
| `docs/RC_SHADOW_002_OWNER_DECISION_FORM.md` | Out-of-office policy decision |
| `docs/GATE_2_SIGNOFF_BLOCKERS.md` | Gate 2 blocker checklist |
| `outputs\shadow_review_days\` | Your daily review sheets |
| `outputs\autonomous_shadow_payload_library.json` | 40 example payloads for practice |

