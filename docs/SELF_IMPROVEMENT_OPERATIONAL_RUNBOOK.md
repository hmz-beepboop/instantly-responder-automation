# Self-Improvement Operational Runbook

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** OPERATIONAL

---

## Overview

This runbook explains how the self-improving layer operates in production. It covers how human edits become rule candidates, how candidates are reviewed and activated, and how the system produces better outputs over time.

---

## How Human Edits Produce Rule Candidates

Every time a reviewer edits a draft or corrects a classification in the HumanApproval review form, the system captures a structured learning signal.

### Step 1 — Reviewer submits the review form

The reviewer may:
- Edit the draft text before approving
- Change the micro_intent classification
- Add or remove additional intents
- Write a correction reason in one of the three reason fields

### Step 2 — System captures a correction event

If the reviewer changed anything significant, Node J creates an `sl_p2_correction_event` in the approval payload. This event contains:
- `old_micro_intent` — the original classification
- `corrected_micro_intent` — the reviewer's correction (if changed)
- `correction_reason_micro_intent` — why the reviewer changed the classification
- `correction_reason_draft` — why the draft was edited
- `correction_reason_additional_intents` — why intents were changed
- `human_revision_draft` — the revised draft text (if edited)
- `submit_additional_intents_shadow` — intents the reviewer added

### Step 3 — Proxy writes the learning event to DataTable

Node P2A/Proxy writes the correction event to the `hmz-learning-events` DataTable. Each row represents one learning event from one review case.

### Step 4 — Rule candidate shadow is created

If the correction meets the threshold criteria, a `proposed_shadow` rule candidate is written to the `hmz-rule-candidates` DataTable. This candidate is NOT active — it is waiting for human review.

### Step 5 — Owner reviews the rule candidate

Run the review console script:
```powershell
$env:HMZ_N8N_API_KEY = "<from secure store>"
$env:HMZ_PHASE3_PROXY_WEBHOOK_URL = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-read"
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -ListCandidates
```

Review each candidate. For each one, decide: approve, reject, or amend.

### Step 6 — Owner approves a rule candidate

To approve and inject a rule:
```powershell
.\scripts\SL-PHASE-4D-supervised-active-rule-injection.ps1 -Apply -RuleId RC-XXX
```

This injects the rule into Decision node D's ACTIVE_RULE_GUIDANCE block. From that point forward, every eligible case will receive the rule's guidance before drafting.

### Step 7 — Improved outputs begin immediately

The injected rule provides structured guidance to the AI draft node. The AI must follow the rule's guidance when it applies. The result is demonstrably different (and better) output for matching cases.

---

## How to Review and Act on Rule Candidates

### List all pending candidates
```powershell
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -ListCandidates
```

### Inspect a specific candidate
```powershell
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -InspectCandidate RC-XXX
```

### Approve a candidate
```powershell
.\scripts\SL-PHASE-4D-supervised-active-rule-injection.ps1 -Apply -RuleId RC-XXX
```

### Reject a candidate
Use the Proxy write endpoint to set status to `rejected`:
```powershell
$env:HMZ_PHASE3_PROXY_WRITE_URL = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-write"
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -RejectCandidate RC-XXX -Reason "Not generalisable enough"
```

### Amend a candidate before approving
Edit the `proposed_rule_text` field in the DataTable directly via n8n UI, then approve.

### Deprecate an active rule
```powershell
.\scripts\SL-PHASE-4D-supervised-active-rule-injection.ps1 -Deprecate -RuleId RC-XXX
```

This removes the rule from the ACTIVE_RULE_GUIDANCE block. Existing cases are not affected.

### Roll back an active rule
```powershell
.\scripts\SL-PHASE-4I-phase3-proxy-write-repair.ps1 -RollBack -RuleId RC-XXX
```

---

## Monitoring the Self-Improvement System

### Signs the system is working

- New rows appearing in `hmz-learning-events` DataTable after review sessions
- New `proposed_shadow` candidates appearing in `hmz-rule-candidates` after corrections
- Active rule count in Decision node D increasing after approvals
- Draft quality improving for case types covered by active rules

### Signs the system is not working

- No new learning events after multiple review sessions → check Node J correction event logic
- Proposed_shadow candidates not appearing → check Proxy write endpoint
- Active rules not appearing in Decision node D → check Phase 4D injection logic
- Draft quality not improving despite active rules → check ACTIVE_RULE_GUIDANCE block in node D prompt

### Verification commands

Check active rules in Decision node D:
```powershell
$env:HMZ_N8N_API_KEY = "<from secure store>"
.\scripts\SL-PHASE-4J-self-improvement-verification-suite.ps1 -RunS7
```

Check safety gates:
```powershell
.\scripts\SL-PHASE-4J-self-improvement-verification-suite.ps1 -RunS9
```

---

## What Happens When a Rule Fails

If an active rule produces a bad draft:

1. The reviewer edits the draft and writes a correction reason in the draft correction field
2. This creates a new learning event and proposed_shadow
3. The owner reviews the new candidate — it may propose tightening or removing the existing rule
4. The owner deprecates the bad rule and approves the correction

No rule should remain active if it consistently produces bad outputs. The system provides the signals; the owner makes the final decision.

---

## Safety Invariants — Never Violate

- No rule candidate becomes active without explicit owner approval
- No rule overrides the HUMAN_ONLY gate
- No rule overrides the UNSUBSCRIBE gate
- No rule causes an autonomous send
- ACTIVE_RULE_GUIDANCE only applies to ai_supervised and AI_COMMERCIAL_SUPERVISED paths
- Pricing, legal, compliance, GDPR, SOC2, custom proposal cases always require human review regardless of any rule

---

## Related Documents

- `docs/ACTIVE_RULE_GOVERNANCE_RUNBOOK.md` — detailed governance process
- `docs/SELF_IMPROVEMENT_RULE_REVIEW_CADENCE.md` — when to review candidates
- `docs/SELF_IMPROVEMENT_FINAL_SIGNOFF.md` — system signoff record
- `docs/RULE_CANDIDATE_REVIEW_RUNBOOK.md` — step-by-step review process
