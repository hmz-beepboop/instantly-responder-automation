# Next Manual Test Packet — Autonomous Shadow Evaluation

**Phase:** 5I  
**Date:** 2026-06-24  
**RC-SHADOW-003 Status:** APPLIED — versionId `ae13bf4e-ee04-438f-9657-3c57183b90a2`  
**Shadow Evaluator Workflow ID:** `aHzLtQiv6G8h1bqD`  
**Shadow Evaluator Active:** `false` (verified)

---

## What to Do Now

The RC-SHADOW-003 allowlist wire-up is complete. The shadow evaluator now correctly:
- Blocks eligibility when any allowlist is empty (production default — safe)
- Blocks PERMANENT_BLOCK intents regardless of allowlist state
- Computes `would_be_shadow_eligible` based on all three allowlist checks + confidence
- Keeps `would_send_live_now=false` unconditionally

**The 14-day shadow review period can now begin.**

---

## Step-by-Step Owner Instructions

### Day 1 Setup (one-time)

1. Open Instantly.ai and go to your active campaign's reply inbox
2. Start the review helper: `.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -CreateDailyReviewSheet -Day 1`
3. Verify shadow evaluator is `active=false` before starting

### Each Day (Days 1–14)

For each day in the 14-day review period:

**Step 1 — Select 1–3 inbound replies from Instantly.ai**
- Pick replies that arrived today or recently
- Prefer a mix: one interested prospect, one question, one unusual reply if available
- Go to the Decision workflow execution log to get the classification output for that reply

**Step 2 — Construct a shadow payload**
```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -GeneratePayloadTemplate
```
Fill in:
- `case_id`: use the execution ID from Decision workflow
- `thread_id`: from the Instantly.ai reply
- `campaign_id`: your active campaign ID
- `sender_email`: your outreach sender
- `incoming_text`: the reply text (strip PII beyond first name)
- `broad_category`, `micro_intent`, `confidence`: copy from Decision workflow output
- `additional_intents`, `risk_flags`: copy from Decision workflow output

**Step 3 — Validate the payload**
```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ValidateManualPayload -PayloadFile outputs\my_payload.json
```

**Step 4 — Simulate the shadow evaluation**  
For each validated payload, apply the eligibility logic manually:
- Is `micro_intent` in PERMANENT_BLOCK? → BLOCKED_PERMANENT
- Is `campaign_allowlist` empty? → BLOCKED_ALLOWLIST (campaign_allowlist_empty)
- Is `sender_allowlist` empty? → BLOCKED_ALLOWLIST (sender_allowlist_empty)
- Is `intent_allowlist` empty? → BLOCKED_ALLOWLIST (intent_allowlist_empty)
- Does confidence ≥ 0.85? → if all allowlists were populated, SHADOW_LOG; else check above

During the 14-day period, all allowlists are empty by design → all cases should show `BLOCKED_ALLOWLIST`.
Record what the system would do, and whether you agree that this was the correct call.

**Step 5 — Record your assessment**

For each case, record:
- `shadow_decision`: what the system decided (blocked_reason, would_be_shadow_eligible)
- `owner_assessment`: what YOU think the correct decision was
- `was_correct`: true if system and owner agree
- `should_have_blocked`: true if the reply should never reach autonomous handling
- `learning_signal`: any observation worth capturing (free text)

**Step 6 — Log the result**
```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -AppendShadowReviewResult -PayloadFile outputs\my_result.json
```

**Step 7 — Daily summary**
```powershell
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ExportDailySummary -Day <N>
```

---

## What You Are Looking For

During 14 days of manual shadow review, you are checking:

| Observation | What It Means |
|-------------|---------------|
| All cases blocked (allowlist_empty) | Expected — allowlists are empty during review period |
| PERMANENT_BLOCK intent correctly blocked | Confirms safety logic works |
| A reply you'd want autonomous action on shows up | Candidate for intent_allowlist in Gate 2 |
| A reply the system would have gotten wrong | Learning signal — may trigger rule update |
| Any reply that feels risky or ambiguous | Should remain HUMAN_REVIEW indefinitely |

**Gate 2 readiness criteria (after 14 days):**
- ≥ 14 days of review completed
- All PERMANENT_BLOCK cases correctly identified
- Owner has a clear set of intents, campaigns, and senders to populate allowlists with
- No unexpected gaps or edge cases identified
- RC-SHADOW-001 (proof requests) and RC-SHADOW-002 (OOO policy) resolved
- Owner signs Gate 2 checklist in `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md`

---

## Files

| File | Purpose |
|------|---------|
| `scripts/SL-PHASE-5I-manual-shadow-review-helper.ps1` | Review helper script |
| `outputs/autonomous_manual_shadow_payload_template.json` | Blank payload template |
| `outputs/shadow_review_days/` | Per-day review sheets |
| `outputs/autonomous_shadow_review_log.json` | Cumulative result log |
| `outputs/autonomous_shadow_review_metrics_template.json` | Metrics tracking |
| `docs/AUTONOMOUS_SHADOW_REVIEW_DAILY_CHECKLIST.md` | Daily checklist detail |
| `docs/AUTONOMOUS_14_DAY_SHADOW_REVIEW_PLAN.md` | Full 14-day plan |

---

## Safety Reminders

- Shadow evaluator workflow `aHzLtQiv6G8h1bqD` must remain `active=false` throughout
- `would_send_live_now=false` is hardcoded — no live sends are possible
- Do not populate allowlists until Gate 2 is approved
- Do not connect the shadow evaluator to the Sender workflow
- Do not set `autonomous_enabled=true`
