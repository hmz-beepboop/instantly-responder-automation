# Autonomous Shadow Review Digest Runbook

**Version:** 1.0  
**Date:** 2026-06-24  
**Purpose:** How to generate and review the daily shadow digest

---

## Overview

The daily digest summarises shadow evaluator decisions across real (or test) traffic. It is the primary review artifact during the 14-day shadow review period before Gate 2.

---

## How to Generate the Digest

### From controlled test results (after SL-PHASE-5F):

```powershell
cd "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
.\scripts\SL-PHASE-5G-shadow-review-digest-simulator.ps1 `
    -RunDigestSimulation `
    -UseShadowTestResults `
    -ExportDigest `
    -ExportLearningSignals
```

**Output files:**
- `outputs/autonomous_shadow_daily_digest_from_tests.json`
- `outputs/autonomous_shadow_learning_signal_preview.json`

---

## What to Review in the Digest

| Field | What to Check |
|-------|--------------|
| `total_test_payloads` | Volume of events seen |
| `shadow_eligible_count` | Cases the system would shadow-log |
| `blocked_count` | Cases correctly blocked |
| `would_send_live_now_ever_true` | Must always be `false` |
| `top_blocked_reasons` | Are the right reasons blocking? |
| `escalations` | Were any escalations generated? |
| `follow_ups_needed` | Any errors or anomalies? |
| `proposed_shadow_rule_candidates` | Any rule candidates to review? |
| `owner_actions` | List of actions for owner |

---

## Daily Review Cadence (14-Day Shadow Period)

1. Each day: run digest simulator or collect live shadow logs
2. Review digest: are blocked decisions correct?
3. Review shadow-eligible decisions: would these be appropriate to reply to?
4. Note any anomalies in `docs/AUTONOMOUS_SHADOW_REVIEW_LOG.md` (create if not exists)
5. After 14 days: review accumulated data and decide on Gate 2

---

## Learning Signal Review

Each learning signal in `outputs/autonomous_shadow_learning_signal_preview.json` represents an observation from shadow traffic that may suggest a rule candidate.

**For each signal:**
1. Read the `observation` — does it match what you saw?
2. Read the `learning` — is the interpretation correct?
3. Check the `action` — what should be done?
4. If a rule candidate emerges: add to `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` before injecting

---

## Related Documents

- `docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md` — digest schema specification
- `docs/AUTONOMOUS_FOLLOWUP_LEARNING_SPEC.md` — learning loop specification
- `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` — Gate 2 checklist
- `outputs/autonomous_shadow_test_results.json` — raw test results
