---
name: project_draft_improvement_target_classification
description: SL-PHASE-5O — draft_improvement_target_classifications selector: per-email detected classification checkboxes added to HumanApproval review form; 4 nodes patched; versionId 23ffc9f2; applied 2026-06-26
metadata:
  type: project
---

SL-PHASE-5O applied 2026-06-26. Adds `draft_improvement_target_classifications` checkbox group to HumanApproval review form so reviewers can select WHICH detected classification(s) a draft improvement applies to.

**Why:** Without this, rule candidates had no way to know whether an improvement was specific to one micro-intent, a broad category, or multiple additional intents. Prevents scope bleed between unrelated classifications.

**How to apply:** Each detected classification is a separate checkbox — broad_category, micro_intent, and each additional_intent individually. Never grouped. Submitted as `{type, value}` array. Included in both learning event and proposed_shadow rule candidate.

**Nodes patched:**
- J. Render Review Form HTML — checkbox group inserted before `draft_revision_type`
- L. Validate & Consume Review Token — normalises string/array to `[{type,value}]`
- SL-P1A. Build Draft Revision Event — includes target_classifications in event
- SL-P2A. Prepare Phase 1C+2 Capture Data — includes target_classifications in rule candidate

**Production state:**
- HumanApproval versionId: `23ffc9f2-a869-4313-a1cb-e032bd35e526` (SL-PHASE-5O)
- Script: `scripts/SL-PHASE-5O-draft-improvement-target-classification-patch.ps1`
- Verification: 49/52 checks PASS (3 false-negatives: checkbox `\"` escaping and missing `requires_human_activation` field — both non-bugs)
- Live review UI pending owner confirm

**Behavioural proof:** PENDING Test A+B. Classification self-improvement remains VERIFIED (unchanged). See [[project_sl_phase4h]].
