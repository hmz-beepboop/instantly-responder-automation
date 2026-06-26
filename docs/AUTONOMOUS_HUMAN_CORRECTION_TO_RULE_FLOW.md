# Autonomous Human Correction to Rule Flow

**Version:** 1.0  
**Date:** 2026-06-24

---

## Overview

This document describes how corrections from autonomous post-action reviews flow back into the self-improving rule system. The flow is identical to the supervised correction flow (Phase 1C-2B → Phase 3 → Phase 4D).

---

## Correction Sources

1. **Owner post-action review** — owner rates an autonomous response as bad and writes a correction
2. **Prospect negative follow-up** — prospect's negative reply creates an immediate human case; reviewer writes correction
3. **Pattern from daily digest** — owner notices repeated pattern and manually creates a correction entry

---

## Step-by-Step Flow

### Step 1 — Correction Created

Owner completes the post-action review form. Fields that trigger a correction:
- Rating: `bad_response`, `should_have_escalated`, `wrong_classification`, `wrong_tone`, `wrong_content`, `wrong_cta`
- `better_response_text` filled in
- `create_learning_event = true`

### Step 2 — Learning Event Written

System creates an `sl_p2_correction_event` (same structure as supervised path) with additional autonomous-specific fields:
- `source: autonomous_post_action_review`
- `autonomous_case: true`
- `was_sent: true`
- `post_action_review_rating: <rating>`

Learning event is written to `hmz-learning-events` DataTable.

### Step 3 — Proposed Shadow Rule Candidate Created

If correction meets criteria (rating is bad, better_response_text provided, or pattern is clear):
- A `proposed_shadow` entry is created in `hmz-rule-candidates`
- `trigger_condition` is derived from the case's classification
- `proposed_rule_text` is derived from the correction reason and better_response_text
- Status: `proposed_shadow` (same as supervised path)

### Step 4 — Owner Reviews Rule Candidate

Via the Phase 3 review console:
```powershell
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -ListCandidates
```

Owner sees all pending candidates including those from autonomous corrections. Reviews and decides: approve / reject / amend.

### Step 5 — Rule Injected (if Approved)

Via Phase 4D injection:
```powershell
.\scripts\SL-PHASE-4D-supervised-active-rule-injection.ps1 -Apply -RuleId RC-XXX
```

From this point, both supervised AND autonomous paths benefit from the corrected rule.

### Step 6 — Eligibility Tightening (if Applicable)

If the correction reveals a gap in the eligibility gates (wrong intent type was allowed through):
1. Owner removes the intent from `intent_allowlist` in the config
2. Or owner reduces the `confidence_threshold`
3. Or owner adds the intent to `additional_intent_blocklist`
4. Config change is documented with reason
5. Acceptance harness re-run to verify

---

## Difference From Supervised Flow

| Aspect | Supervised Flow | Autonomous Flow |
|--------|----------------|-----------------|
| Correction source | Human reviewer in HumanApproval form | Owner in post-action review form |
| Timing | Immediate (reviewer sees draft before send) | Next morning (owner reviews after send) |
| Damage potential | None — reviewer can change draft before send | Send has already occurred; damage is done |
| Learning speed | Immediate | 12-24 hour delay |
| Additional gate | None | Eligibility tightening recommendation |

Because autonomous corrections are post-send, they require more careful handling. A single autonomous bad response is serious; two in the same category warrants eligibility review; three warrants removing the category from autonomous eligibility.

---

## Accumulation Thresholds

| Bad Response Count | Recommended Action |
|--------------------|-------------------|
| 1 in any category | Log correction; propose rule candidate |
| 2 in same category | Review eligibility for that category; increase confidence threshold |
| 3 in same category | Remove that intent type from autonomous eligibility |
| 1 with legal/compliance element | Immediately remove category; may tighten eligibility further |

---

## Related Documents

- `docs/AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md` — review form
- `docs/AUTONOMOUS_FOLLOWUP_LEARNING_SPEC.md` — overall learning flow
- `docs/AUTONOMOUS_MISTAKE_RESPONSE_POLICY.md` — mistake escalation
- `docs/SELF_IMPROVEMENT_OPERATIONAL_RUNBOOK.md` — rule injection reused
