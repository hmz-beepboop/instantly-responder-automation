# Autonomous Shadow Review — Daily Checklist

**Use one copy per day. Fill in and keep as log.**  
Print or copy this section each morning.

---

## Daily Review — Day _____ / Date: _______________

### Pre-Review Safety Check (2 min)

- [ ] Shadow evaluator is `active=false` in n8n UI (`https://n8n.hmzaiautomation.com`)
- [ ] Main Decision workflow (tgYmY97CG4Bm8snI) is running normally
- [ ] No errors in n8n execution log for Decision/HumanApproval/Proxy
- [ ] No outstanding opt-outs or complaints from yesterday that need attention

**If any pre-check fails → STOP. Do not submit shadow candidates until resolved.**

---

### Candidate Selection (5 min)

Look at today's inbound replies in Instantly.ai. Select 1–5 candidates for shadow review.

**Candidates today:**

| # | Campaign | Prospect Email (masked) | Reply Summary | Intent (your guess) |
|---|----------|------------------------|---------------|---------------------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

**Skip if:**
- The reply is an opt-out, DO_NOT_CONTACT, or complaint → route to human immediately, do not shadow review
- The reply is an automated OOO → log as OOO, human-only per RC-SHADOW-002 policy

---

### Payload Submission (5–10 min per candidate)

For each candidate, submit a payload to the shadow evaluator webhook. Use the Decision workflow's classification output.

**Webhook endpoint:** `https://n8n.hmzaiautomation.com/webhook/autonomous-shadow-eval-test`  
**Workflow must be active=true before submitting.** Activate with:
```
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -Activate
```
**Deactivate immediately after all submissions:**
```
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -Deactivate
```

**Sample payload structure:**
```json
{
  "case_id": "LIVE-XXX",
  "incoming_text": "<prospect reply text>",
  "broad_category": "<from Decision output>",
  "micro_intent": "<from Decision output>",
  "confidence": 0.XX,
  "campaign_id": "<campaign ID>",
  "sender_email": "<sender email>",
  "thread_id": "<thread ID>",
  "additional_intents": [],
  "risk_flags": []
}
```

---

### Results Review (5 min per candidate)

For each submission, record:

| Case ID | micro_intent | confidence | shadow_action | would_send_live_now | owner_agrees | notes |
|---------|-------------|------------|---------------|---------------------|--------------|-------|
| | | | | false ✓ | | |
| | | | | false ✓ | | |

**CRITICAL CHECK:** `would_send_live_now` must be `false` for every single case. If it is ever `true` → **KILL SWITCH IMMEDIATELY** and report.

---

### Post-Review (3 min)

- [ ] Deactivate shadow evaluator: `.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -Deactivate`
- [ ] Confirm shadow evaluator is `active=false` in n8n UI
- [ ] Add today's results to `outputs/autonomous_shadow_review_metrics_template.json`
- [ ] Note any disagreements or concerns below

**Disagreements / Concerns:**
```
(free text)
```

---

### Day Summary

| Item | Value |
|------|-------|
| Candidates reviewed today | |
| Total candidates reviewed to date | |
| Any would_send_live_now=true? | NO / YES (if YES — emergency) |
| Any safety misses (pricing/legal/opt-out routed wrong)? | NO / YES |
| Owner agreement rate today | /100% |
| Shadow evaluator deactivated? | YES / NO |

---

### Running Totals (update each day)

| Metric | Target | Current |
|--------|--------|---------|
| Days elapsed | 14 | |
| Total candidates | ≥ 30 | |
| Critical misses | 0 | |
| would_send_live_now=true incidents | 0 | |
| Owner agreement rate | ≥ 90% | |
| RC-SHADOW-003 complete | Yes | |

---

## Kill Switch Reference

```powershell
# Emergency deactivate
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -KillSwitch

# Check status
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -Status

# Safety check only (no activation)
.\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -SafetyCheck
```
