# SL-PHASE-5Q16D Learning Attribution and Template Proof Gate

Date: 2026-06-30

## Verdict

`case-f1135dcd` is not accepted as complete live self-improvement proof.

The case was valid, post-5Q16B, and Decision consumed the active HumanApproval form-created draft rule at runtime. However, the owner-facing output still showed plain `FIXED_TEMPLATE` / `deterministic_template`, and the Google Chat card/review page did not expose the applied rule metadata clearly enough to distinguish dynamic learning from a deterministic template.

5Q16D repaired attribution and display. Status remains `94` until one fresh post-5Q16D live case proves the visible attribution in production.

## Live Case Trace

- Case: `case-f1135dcd`
- Decision execution: `3570`, started `2026-06-30T03:37:01.725Z`
- HumanApproval create execution: `3571`, started `2026-06-30T03:37:02.177Z`
- HumanApproval render execution: `3572`, started `2026-06-30T03:37:43.235Z`
- Valid/non-diagnostic: yes
- `INTAKE_CONTEXT_MISSING`: no
- `draft_text` present: yes
- Inbound reply: `Would you be able to send me the calendar link so I can book a slot ?`
- Broad/micro baseline: `INFORMATION_REQUEST / BOOKING_REQUEST`
- Broad/micro effective: `INFORMATION_REQUEST / BOOKING_REQUEST`
- Draft policy/source before 5Q16D repair: `FIXED_TEMPLATE` / `deterministic_template`
- Q12 active form-learning lookup: executed
- Active form draft rule count: `1`
- Rule consumed for draft: yes
- Applied rule ID: `c9860e74-ff23-477e-87f1-812bec8023e5`
- Source case ID: `case-5cf1aa57`
- Source marker: `humanapproval_form_created_learning`
- Classification learning applied: no, because the baseline classification already matched the corrected target
- Sender triggered: no
- Instantly POST/live send: no evidence; Sender did not execute

## Root Cause

The failure was attribution and proof instrumentation, not rule lookup.

Categories:

- D: active rule consumed but output metadata did not expose all required proof fields.
- E: deterministic path consumed learning but still labelled itself as plain deterministic template.
- F: Google Chat card hid applied-learning metadata.
- G: review page hid applied-learning metadata.
- I: no remaining 5Q16B source-gated hardcoded learned phrase was found in production Decision, but proof instrumentation was insufficient.

## Repair

Decision `D. Draft Preparation (Templates / Human Draft)` now emits structured learning attribution on every output:

- `baseline_broad_category`
- `baseline_micro_intent`
- `effective_broad_category`
- `effective_micro_intent`
- `active_learning_rules_found`
- `active_learning_rules_eligible`
- `active_learning_rules_applied`
- `applied_learning_rule_ids`
- `applied_learning_source_case_ids`
- `applied_learning_source_markers`
- `applied_learning_scopes`
- `learning_applied_to_classification`
- `learning_applied_to_draft`
- `learning_not_applied_reason`
- `draft_policy_raw`
- `draft_source_raw`
- `draft_policy_effective`
- `draft_source_effective`
- `learning_attribution`

When active HumanApproval form-created draft learning affects a deterministic/fixed-template draft, the owner-facing labels now become:

- Draft policy: `FIXED_TEMPLATE_WITH_FORM_LEARNING`
- Draft source: `deterministic_template_with_form_learning`

Plain `FIXED_TEMPLATE` / `deterministic_template` remains possible only when no active form-created draft rule is applied.

HumanApproval now carries Decision attribution into the review case, Google Chat card, and review form. Both surfaces can show:

- active learning applied: yes/no
- applied rule ID(s)
- source case ID(s)
- source marker(s)
- effective classification
- non-application reason when no learning was applied

## Anti-False-Positive Result

The 5Q16D repair does not add booking guidance to baseline classifier logic, deterministic templates, fallback templates, or a learned-wording postprocessor.

The remaining booking phrase logic is eligibility/scope classification logic. Draft wording changes must come from active HumanApproval form-created rule context.

Codex baseline and HumanApproval form-created learning remain distinguishable through source metadata and the `humanapproval_form_created_learning` marker.

## Production Apply

- Guard: passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`
- Backup path: `backups/SL-PHASE-5Q16D_20260630T035530Z`
- Decision version: `e283c3f7-6677-402a-8052-71ecf86c3a51` -> `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa`
- HumanApproval version: `16ad1875-ea16-46a3-b934-ac710002a2e9` -> `05244014-0ba9-4b6e-b82c-867a31be61c6`
- Active states: preserved
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`
- No Sender execution, Instantly POST, or live email send was triggered by this apply

Production patch verification:

- Decision attribution block: present
- Learned deterministic labels: present
- HumanApproval Google Chat learning display: present
- HumanApproval review-form learning display: present
- Old hardcoded learned booking phrase count in Decision D: `0`

## Harness Results

- 5Q16D Python: `32/32 PASS`
- 5Q16D PowerShell: `32/32 PASS`
- 5Q16B Python: `30/30 PASS`
- 5Q16B PowerShell: `30/30 PASS`
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q14B Python: `20/20 PASS`
- 5Q14B PowerShell: `20/20 PASS`
- 5Q11 Python: `24/24 PASS`
- 5Q11 PowerShell: `24/24 PASS`

5Q12 was not rerun because HumanApproval source-rule storage was not changed in 5Q16D.

## Next Live Proof

Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with:

`Would you be able to send me the calendar link so I can book a slot?`

Then inspect the Google Chat card and review page only.

Do not approve, send, save, or click learning-only.

## 5Q16F Addendum - Applied Learning Truthfulness

On 2026-06-30, fresh post-5Q16D case `case-acf4513f` showed visible attribution:

- draft policy/source: `FIXED_TEMPLATE_WITH_FORM_LEARNING` / `deterministic_template_with_form_learning`
- active learning applied: yes
- rule ID: `c9860e74-ff23-477e-87f1-812bec8023e5`
- source case: `case-5cf1aa57`
- source marker: `humanapproval_form_created_learning`

The case is not accepted as final proof because 5Q16D still marked draft learning as applied whenever an eligible rule and draft existed, not only when the final output changed. 5Q16F repaired this by gating `learning_applied_to_draft` and `active_learning_rules_applied` on normalized output delta.

5Q16F also added owner-visible found/eligible/applied counts and a `learning_impact_summary`.

Production state after 5Q16F:

- Decision `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa` -> `52753ab6-62f5-4334-9111-6f3f838cd698`; active preserved `true`
- HumanApproval `05244014-0ba9-4b6e-b82c-867a31be61c6` -> `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200`; active preserved `true`
- Backup: `backups/SL-PHASE-5Q16F_20260630T041500Z`

5Q16F harness:

- 5Q16F Python/PowerShell: `22/22 PASS`
- 5Q16D Python/PowerShell: `32/32 PASS`

Status remains `94` until one fresh post-5Q16F live case proves truthful impact attribution.
