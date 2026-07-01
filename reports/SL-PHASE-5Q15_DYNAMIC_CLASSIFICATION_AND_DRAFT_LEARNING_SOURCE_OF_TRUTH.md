# SL-PHASE-5Q15 Dynamic Classification and Draft Learning Source of Truth

**Date:** 2026-06-29  
**Agent:** Codex  
**Verdict:** PARTIAL / production apply complete; fresh live proof pending  
**Status percentage:** 94%

## Scope

5Q15 audited whether HumanApproval form-created learning can dynamically affect future classification and draft behaviour without Codex hardcoding the owner test phrase or booking guidance into baseline classifiers/templates.

Changed locally:

- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q15-dynamic-classification-and-draft-learning-source-of-truth.py`
- `scripts/SL-PHASE-5Q15-dynamic-classification-and-draft-learning-source-of-truth.ps1`

No Sender, Intake, Shadow Evaluator, autonomous, Gate 2, or live-send path was changed.

## Stale Case / Render Finding

`case-9747ff6f` is not valid proof that learning failed after 5Q14F:

- It was created by Decision execution `3491` before Decision version `e64cded8-e4a9-46f8-b541-23512e9f4dce`.
- Its stored classification was `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Q12 found rule `c9860e74-ff23-477e-87f1-812bec8023e5`, but the rule was not consumed because the stored micro-intent was ineligible.
- Reopening the HumanApproval review page renders stored review-case output; local workflow evidence shows the GET render path does not call Decision or regenerate draft/classification.
- Therefore old review cases are expected to remain stale unless a separate regenerate action exists.

Owner-reported live evidence says the review form now opens and renders. Codex attempted a targeted read-only n8n trace, but the approval policy rejected production API access because repository instructions forbid production API calls. No workaround was attempted.

## Root Cause

The dynamic draft learning bridge existed, but dynamic classification learning did not.

HumanApproval:

- Draft/style rules were written active/effective immediately with source metadata.
- Classification corrections were written as `proposed_shadow`, required activation, and lacked the full active/source metadata needed for immediate dynamic consumption.

Decision:

- Q12 looked up active rule-candidate rows.
- Decision D filtered active form rows into `DYNAMIC_FORM_BEHAVIOURAL_POLICIES` only when `rule_type=style`.
- Active form rows could influence draft guidance late in Draft Preparation.
- No active HumanApproval form-created classification rule altered the effective classification before draft policy/template selection.

## Local Repair

HumanApproval `SL-P2A. Prepare Phase 1C+2 Capture Data` now emits active form-created classification correction rows when the reviewer changes broad category or micro-intent.

Those rows now preserve:

- `source_case_id`
- `source_original_case_id`
- original classification
- corrected/effective classification
- target classification used
- human instruction / reason
- active/effective timestamps
- `activation_source=humanapproval_form`
- `source_marker=humanapproval_form_created_learning`
- `immediate_supervised_effect=true`
- `requires_human_activation=false`

Decision `D. Draft Preparation (Templates / Human Draft)` now:

- reads active/effective HumanApproval form-created classification rules;
- selects the newest same-scope rule for the baseline category/micro-intent;
- blocks weakening protected high-risk baselines;
- adjusts effective category/micro-intent before draft policy/template selection;
- stores baseline and effective classification metadata on `classifier`, `decision`, and `draft`;
- carries applied rule ID, source case ID, source marker, instruction, original classification, corrected/effective classification, and target classification used;
- uses the effective classification for draft policy, template/fallback selection, and active draft-rule matching.

Dynamic draft learning remains separated:

- Codex baseline policies remain `ACTIVE_BEHAVIOURAL_POLICIES`.
- HumanApproval form-created policies remain `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`.
- Draft rule source metadata is preserved in Decision output.
- AI supervised, commercial supervised, deterministic/fixed-template, and fallback paths all receive the active form-created draft guidance after effective classification is set.

## Anti-False-Positive Result

The 5Q15 harness proves the synthetic draft effect from a form-created instruction not present in workflow baseline text.

The repair does not add the synthetic instruction to:

- baseline classifier logic;
- deterministic templates;
- fallback templates;
- Codex baseline behavioural policies.

Known booking phrase classifier patches from 5Q13/5Q14F remain present as previous narrow classifier coverage. 5Q15 does not add a new phrase-specific classifier patch and does not use classifier hardcoding as learning proof.

## Harness Results

- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`

Not run:

- 5Q14F: render path was not changed in 5Q15.
- 5Q14D: diagnostic render/token path was not changed in 5Q15.
- 5Q11: review-state/token accessibility path was not changed in 5Q15.

## Production Apply

### 2026-06-29 Production Apply

Production apply was explicitly authorized by the owner and completed for the already-built local 5Q15 deltas only.

Guard:

- Production target guard passed before n8n writes.

Backup:

- `backups/sl-phase-5q15-production-apply-20260629T230705Z`

Version/state:

- Decision `e64cded8-e4a9-46f8-b541-23512e9f4dce` -> `4e04ebc8-c7ef-4d45-ad75-945f5179ba2d`; active preserved `true`
- HumanApproval `de84f8f3-d4c4-4565-88ab-c40449e727ca` -> `16ad1875-ea16-46a3-b934-ac710002a2e9`; active preserved `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Safety verification:

- Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`, before this apply window.
- No Sender execution was triggered by this apply.
- No Instantly POST or live email send was caused by this apply.
- Gate 2 remains not approved.
- Autonomous mode remains disabled.

Post-apply/post-sync harness:

- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`

Status remains `94` because fresh live dynamic classification + draft learning proof is still pending.

## Next Owner Action

Create one fresh owned/test inbound reply in the existing Instantly campaign thread, then inspect the review draft only.

Use this exact reply:

`Can I choose a time from your calendar link?`

Do not approve, send, save, or click learning-only during the proof check.

## 5Q16B Addendum - Deterministic False-Positive Repair

On 2026-06-30, `case-dce9d552` was traced as a fresh post-5Q15 production case. It was valid/non-diagnostic and Decision execution `3555` did execute Q12 with rule `c9860e74-ff23-477e-87f1-812bec8023e5`, source case `case-5cf1aa57`, and source marker `humanapproval_form_created_learning`.

The case is not accepted as complete live proof because Decision D still contained a source-gated hardcoded booking postprocessor that rendered the learned-looking deterministic wording. 5Q16B removed that false-positive path and production-applied a Decision-only repair.

Production state after 5Q16B:

- Decision `4e04ebc8-c7ef-4d45-ad75-945f5179ba2d` -> `e283c3f7-6677-402a-8052-71ecf86c3a51`; active preserved `true`
- HumanApproval unchanged: `16ad1875-ea16-46a3-b934-ac710002a2e9`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Backup: `backups/SL-PHASE-5Q16B_20260630T031453Z`

5Q16B post-apply harness:

- 5Q16B Python/PowerShell: `30/30 PASS`
- 5Q15 Python/PowerShell: `35/35 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`

Status remains `94` because one fresh post-5Q16B live proof is still pending.

## 5Q16D Addendum - Learning Attribution and Template Proof Gate

On 2026-06-30, `case-f1135dcd` was traced as a fresh post-5Q16B production case. It was valid/non-diagnostic and Decision execution `3570` consumed active HumanApproval form-created draft rule `c9860e74-ff23-477e-87f1-812bec8023e5`, source case `case-5cf1aa57`, and source marker `humanapproval_form_created_learning`.

The case is not accepted as complete live proof because the owner-facing card/review output still showed plain `FIXED_TEMPLATE` / `deterministic_template` and hid the applied-rule attribution.

5Q16D added explicit attribution and display proof gates:

- every Decision output now carries baseline/effective classification metadata, active rules found/eligible/applied, applied rule IDs, source case IDs, source markers, scopes, classification/draft learning flags, non-application reason, and effective draft policy/source;
- deterministic templates affected by active HumanApproval form-created draft rules now label as `FIXED_TEMPLATE_WITH_FORM_LEARNING` / `deterministic_template_with_form_learning`;
- HumanApproval Google Chat and review form now display active learning applied yes/no, rule IDs, source cases, source markers, effective classification, and non-application reason when relevant.

Production state after 5Q16D:

- Decision `e283c3f7-6677-402a-8052-71ecf86c3a51` -> `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa`; active preserved `true`
- HumanApproval `16ad1875-ea16-46a3-b934-ac710002a2e9` -> `05244014-0ba9-4b6e-b82c-867a31be61c6`; active preserved `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Backup: `backups/SL-PHASE-5Q16D_20260630T035530Z`

5Q16D post-apply harness:

- 5Q16D Python/PowerShell: `32/32 PASS`
- 5Q16B Python/PowerShell: `30/30 PASS`
- 5Q15 Python/PowerShell: `35/35 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`

Status remains `94` because one fresh post-5Q16D live proof with visible attribution is still pending.

## 5Q16F Addendum - Applied Learning Truthfulness

On 2026-06-30, `case-acf4513f` proved that visible attribution alone is still not enough. The live case found and consumed HumanApproval form-created rule `c9860e74-ff23-477e-87f1-812bec8023e5`, and the final draft changed from the deterministic baseline. However, 5Q16D could still mark draft learning as applied without verifying an output delta.

5Q16F repaired the truthfulness gate:

- `active_learning_rules_found` means active form-learning data contained the rule.
- `active_learning_rules_eligible` means the rule matched effective classification/scope.
- `active_learning_rules_applied` now means the rule changed final classification or draft output.
- `learning_applied_to_draft` now requires normalized final draft text to differ from the pre-learning draft.
- `learning_applied_to_classification` now requires effective classification to differ from baseline because of the rule.
- `learning_not_applied_reason` now reports `RULE_FOUND_BUT_NO_OUTPUT_DELTA` for found/eligible/no-effect cases.
- `learning_impact_summary` is emitted and displayed in Google Chat/review form.

Production state after 5Q16F:

- Decision `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa` -> `52753ab6-62f5-4334-9111-6f3f838cd698`; active preserved `true`
- HumanApproval `05244014-0ba9-4b6e-b82c-867a31be61c6` -> `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200`; active preserved `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Backup: `backups/SL-PHASE-5Q16F_20260630T041500Z`

5Q16F post-apply harness:

- 5Q16F Python/PowerShell: `22/22 PASS`
- 5Q16D Python/PowerShell: `32/32 PASS`
- 5Q16B Python/PowerShell: `30/30 PASS`
- 5Q15 Python/PowerShell: `35/35 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`

Status remains `94` pending one fresh post-5Q16F live proof.
