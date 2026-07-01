# SL-PHASE-5Q16B Deterministic Template False-Positive Audit

Date: 2026-06-30

## Verdict

`case-dce9d552` is not accepted as complete live self-improvement proof.

The live case was valid, post-5Q15, and did execute the active HumanApproval form-learning lookup. Decision execution `3555` contained rule `c9860e74-ff23-477e-87f1-812bec8023e5`, source case `case-5cf1aa57`, and source marker `humanapproval_form_created_learning`.

However, the resulting deterministic draft matched a source-gated hardcoded booking postprocessor in Decision. That made the case a false-positive risk rather than clean proof that the deterministic path was dynamically rendering from the form-created rule.

Status remains `94` pending one fresh post-5Q16B live proof.

## 5Q16D Addendum

On 2026-06-30, fresh case `case-f1135dcd` was traced after 5Q16B. Decision execution `3570` found and consumed HumanApproval form-created draft rule `c9860e74-ff23-477e-87f1-812bec8023e5` with source case `case-5cf1aa57` and source marker `humanapproval_form_created_learning`.

The case is still not accepted as complete live proof because owner-facing output remained plain `FIXED_TEMPLATE` / `deterministic_template`, and Google Chat/review display hid the applied-rule attribution.

5Q16D production-applied a Decision + HumanApproval attribution repair:

- Decision `e283c3f7-6677-402a-8052-71ecf86c3a51` -> `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa`
- HumanApproval `16ad1875-ea16-46a3-b934-ac710002a2e9` -> `05244014-0ba9-4b6e-b82c-867a31be61c6`
- Backup: `backups/SL-PHASE-5Q16D_20260630T035530Z`
- 5Q16D Python/PowerShell: `32/32 PASS`
- 5Q16B Python/PowerShell: `30/30 PASS`

Status remains `94` until a fresh post-5Q16D case proves visible runtime learning attribution.

## Live Case Trace

- Case: `case-dce9d552`
- HumanApproval create execution: `3556`, `2026-06-30T02:48:06.154Z`
- HumanApproval render execution: `3558`, `2026-06-30T02:48:31.052Z`
- Decision execution: `3555`, `2026-06-30T02:48:05.690Z`
- Valid/non-diagnostic: yes
- `INTAKE_CONTEXT_MISSING`: no
- `draft_text` present: yes
- Broad category: `INFORMATION_REQUEST`
- Micro intent: `BOOKING_REQUEST`
- Draft policy: `FIXED_TEMPLATE`
- Draft source: `deterministic_template`
- Q12 active form-learning lookup: executed
- Rule found in Decision context: `c9860e74-ff23-477e-87f1-812bec8023e5`
- Source case in Decision context: `case-5cf1aa57`
- Source marker in Decision context: `humanapproval_form_created_learning`
- Sender triggered: no
- Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`
- Instantly POST/live send: no evidence; Sender did not execute

## False-Positive Finding

Decision D contained `_5qApplyActiveBookingRuleToDraft`, which was gated on HumanApproval rule context but still rendered hardcoded learned booking copy:

- `Here is the booking link so you can choose a time`
- `If you prefer, send over a couple of times that work and I can book it in`
- `If you have any questions, send them over`

Classification/crosswalk booking phrases remain treated as eligibility/scope logic only. They do not render learned wording.

## Repair

Decision D was patched only.

Changes:

- Removed the hardcoded booking rewrite function.
- Added block-aware parsing of active HumanApproval form-created draft-rule instructions.
- Added runtime draft-rule metadata:
  - `active_form_draft_rules_applied`
  - `active_form_draft_learning_applied`
  - `active_form_draft_learning_effect`
- Kept active draft rules consumed after effective classification is set.
- Kept dynamic classification learning before draft-policy/template selection.
- Preserved AI-supervised, commercial supervised, deterministic/fixed-template, and fallback draft-rule consumption.

The deterministic rule effect now requires active runtime rule context. Without an active HumanApproval form-created rule, the repaired postprocessor does not inject the learned booking guidance.

## Production Apply

- Guard: passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`
- Affected workflow: Decision only
- Backup path: `backups/SL-PHASE-5Q16B_20260630T031453Z`
- Decision version: `4e04ebc8-c7ef-4d45-ad75-945f5179ba2d` -> `e283c3f7-6677-402a-8052-71ecf86c3a51`
- Decision active state: preserved `true`
- HumanApproval unchanged: `16ad1875-ea16-46a3-b934-ac710002a2e9`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Production patch verification:

- `active_form_draft_rules_applied`: present
- Runtime instruction renderer: present
- Old hardcoded learned booking phrase count in production Decision D: `0`

## Harness Results

- 5Q16B Python: `30/30 PASS`
- 5Q16B PowerShell: `30/30 PASS`
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q14B Python: `20/20 PASS`
- 5Q14B PowerShell: `20/20 PASS`

5Q12 and 5Q11 were not rerun because HumanApproval source storage and review-state/accessibility paths were not changed.

## Next Live Proof

Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with:

`Can I choose a time from your calendar link?`

Then inspect the review draft only.

Do not approve, send, save, or click learning-only.
