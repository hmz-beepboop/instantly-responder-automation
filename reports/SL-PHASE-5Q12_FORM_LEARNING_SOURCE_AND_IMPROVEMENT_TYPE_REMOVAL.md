# SL-PHASE-5Q12 Form Learning Source and Improvement-Type Removal

**Date:** 2026-06-29  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Verdict:** PARTIAL after live later-similar checks; live source registration and leakage control are verified, and deterministic-template bypass is harness-fixed, but fresh live post-repair proof is still required  
**Status percentage:** 94%

## Summary

5Q12 removes the redundant `What type of improvement is this?` review-form section and makes the combined human explanation/instruction field the primary learning signal.

It also closes the prior source-of-truth gap: HumanApproval-created draft-learning rows no longer remain inert `proposed_shadow` candidates. For supervised drafting, form-created style rules are written as active/effective immediately, with source metadata and auditability, and Decision dynamically reads active form-created rules before drafting.

No Sender, Intake, Proxy, autonomous, or Gate 2 logic was changed.

## UI Simplification

- Removed visible `What type of improvement is this?` checkbox section.
- Removed hidden/submit dependency on `draft_revision_types`.
- Save, learning-only, and approve/send paths no longer require improvement type selections.
- Existing old rows with improvement-type fields remain readable as historical/audit data only.
- Scope selection remains visible and functional.
- Target classification selection remains visible and functional.

## Learning Source-of-Truth

| Learning path | Evidence |
|---|---|
| Visible field | `Why did you make this change, and what should the system do next time?` |
| Submitted variable | `draft_learning_instruction` -> `submit_draft_learning_instruction` |
| Persisted candidate fields | `source_case_id`, `human_instruction`, `behavioural_instruction`, `draft_learning_instruction`, `draft_improvement_scope`, target classifications, original classification, corrected/effective classification |
| Status/effect | style candidates from form learning now write `status: active`, `effective_at`, `activated_at`, `immediate_supervised_effect: true`, `requires_human_activation: false` |
| Source marker | `activation_source: humanapproval_form`, `source_marker: humanapproval_form_created_learning` |
| Decision consumption | new Decision node `Q12. Lookup Active Form Learning Rules` reads active `sl_rule_candidates` rows and merges them as `DYNAMIC_FORM_BEHAVIOURAL_POLICIES` |
| Draft effect | active form-created guidance is included in AI prompts and a generic exact-start postprocessor applies matching active rules to both AI and safe fallback drafts |
| Baseline separation | embedded Codex/owner baseline remains `ACTIVE_BEHAVIOURAL_POLICIES`; dynamic form rules are separate `DYNAMIC_FORM_BEHAVIOURAL_POLICIES` and carry HumanApproval source markers |

## Corrected Classification Target

5Q11 corrected-classification logic is preserved:

- original classification is stored separately;
- corrected/effective classification is stored separately;
- when the owner selects “this classification,” target classifications are rewritten to the corrected/effective classification;
- if there is no correction, original detected classification remains the effective target.

## Dynamic Proof

The 5Q12 harness uses a synthetic instruction that is not present in the workflows:

`For this synthetic setup-test classification, start the draft with exactly: "Thanks — I can outline the setup clearly."`

Harness proof:

- before adding the synthetic form-created rule, the workflows do not contain that instruction or exact prefix;
- the synthetic form-created candidate stores the instruction with a source case and HumanApproval source marker;
- once active/effective, Decision guidance includes the instruction only for matching classification/scope;
- a later similar normal draft changes to start with the exact prefix;
- a safe fallback draft also changes to start with the exact prefix;
- unrelated classification does not inherit the instruction;
- a newer same-scope human rule overrides an older one;
- the effect is tied to the form-created rule metadata, not a Codex baseline patch.

## Harness Results

- 5Q12 Python: `29/29 PASS`
- 5Q12 PowerShell: `29/29 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`
- 5R-prep idempotency/token: not run; send/idempotency path was not changed.

Post-production-export sync:

- 5Q12 Python: `29/29 PASS`
- 5Q11 Python: `24/24 PASS`

## Production Apply

Production guard passed before API writes.

Data table schema:

- Table: `sl_rule_candidates`
- Backup: `backups/sl-phase-5q12-rule-candidate-table-schema-20260629T003608Z`
- Added metadata columns required for source-of-truth storage, including `human_instruction`, `behavioural_instruction`, `original_classification`, `corrected_effective_classification`, `target_classification_used`, `activation_source`, `source_marker`, `effective_at`, and `immediate_supervised_effect`.

Workflow backup/apply:

- Backup: `backups/sl-phase-5q12-form-learning-source-20260629T003636Z`
- HumanApproval `d3449764-b059-48be-b73a-8a9beae443ea` -> `f1138daa-8d38-4acf-b0c9-a6a2bef626fe`
- Decision `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` -> `009daf13-58f7-442c-b74b-c43f352620fe`
- Active states preserved: both remained `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged and inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Latest Sender execution observed after apply was `3193`, started before the 5Q12 apply; no Sender execution or Instantly POST was caused by this patch.

## Next Owner Action

Use one owned/test review case. Enter a unique instruction in the combined learning box, choose the intended scope/target classification, click `Approved for learning only`, then send/open a later similar owned/test inbound case and report whether the new draft follows that exact instruction.

## 5Q13 Live Source Registration Check

**Date:** 2026-06-29  
**Source case:** `case-5cf1aa57`  
**Verdict:** FAILED / no source learning registration observed  
**Status percentage:** remains 92%

Read-only production evidence after the production-target guard:

- Review case table contains `case-5cf1aa57`, but it remains `status=NEW`.
- The case has no `approved_at`, no `approver_identity`, no `final_reply_text`, and no `decision_payload`.
- Rule-candidate table has no row with `source_case_id=case-5cf1aa57`.
- Recent HumanApproval executions checked: 100; only execution containing the case was create-review-case execution `3210`.
- Execution `3210` ran only create/notification nodes and did not run submit, reviewer-decision, learning-capture, rule-candidate, or Sender-handoff nodes.
- Recent Sender executions checked: 51; none contained `case-5cf1aa57`.

Root-cause boundary: the live learning-only submit was not observed by n8n for this case. There is no evidence of a HumanApproval form-origin learning rule, and no patch is justified from this evidence because the workflow learning path did not execute.

Decision readiness remains structurally present from 5Q12: Decision version `009daf13-58f7-442c-b74b-c43f352620fe` includes `Q12. Lookup Active Form Learning Rules`, normal AI draft consumption, and fallback draft consumption. It cannot consume a rule for `case-5cf1aa57` because no active rule row exists.

## 5Q13 Retry Live Source Registration Check

**Date:** 2026-06-29  
**Source case:** `case-5cf1aa57`  
**Verdict:** PARTIAL / live form-origin active rule registration verified; originally intended setup/process instruction was not the stored instruction  
**Status percentage:** 93%

Read-only production evidence after the production-target guard:

- Review case table now shows `case-5cf1aa57` as `LEARNING_REVISION_APPROVED`.
- HumanApproval execution `3216` received `submit_action=approve_learning_only` and `final_action=approve_learning_only`.
- Execution `3216` ran the submit, reviewer-decision, draft-revision capture, classification-correction capture, rule-candidate emit/write, and non-send terminal result nodes.
- Execution `3216` did not run Sender handoff node `Q. Reply Sender Handoff (Approved)`.
- Recent Sender executions checked: 51; none contained `case-5cf1aa57`.
- Rule-candidate table has two rows for `source_case_id=case-5cf1aa57`: one classification candidate in `proposed_shadow`, and one style rule active immediately.
- Active style rule ID: `c9860e74-ff23-477e-87f1-812bec8023e5`.
- Active style rule metadata: `status=active`, `activation_source=humanapproval_form`, `source_marker=humanapproval_form_created_learning`, `immediate_supervised_effect=true`, `effective_at=2026-06-29T01:12:38.202Z`, `activated_at=2026-06-29T01:12:38.202Z`.
- Source metadata is stored: `source_case_id=case-5cf1aa57`, `source_original_case_id=case-5cf1aa57`.
- Original classification is preserved as `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Corrected/effective classification is stored as `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Target classification used is stored as `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Scope is stored as `current_micro_intent_only`, with policy precedence key `INFORMATION_REQUEST|BOOKING_REQUEST|current_micro_intent_only`.

Important mismatch:

- The active rule did not store the originally intended setup/process instruction from the handoff.
- The stored active instruction is booking-link guidance for `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Therefore the requested later-similar setup/process wording should not be used as proof for this source rule; it would not be a matching classification/scope test.

Decision readiness:

- Decision remains version `009daf13-58f7-442c-b74b-c43f352620fe`.
- `Q12. Lookup Active Form Learning Rules` reads active rows from `sl_rule_candidates`.
- `D. Draft Preparation (Templates / Human Draft)` still separates Codex baseline `ACTIVE_BEHAVIOURAL_POLICIES` from dynamic `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`.
- Normal AI and fallback draft paths remain structurally ready to consume the active form-created rule for matching `INFORMATION_REQUEST / BOOKING_REQUEST` cases.

No patch was made and no harness was run.

## 5Q13 Live Later-Similar / Leakage / Corrected-Classification Check

**Date:** 2026-06-29  
**Verdict:** PARTIAL / leakage control and corrected-classification source proof passed; later-similar booking proof failed pre-repair due classification mismatch  
**Status percentage:** 94%

Live case identification:

- `case-0c0f1ee1`: booking-link request. Stored inbound asks for the booking link so the prospect can choose a time. Review case draft source `ai_supervised`.
- `case-89673efb`: pricing/commitment request. Stored inbound asks about cost and minimum contract. Review case draft source `ai_commercial_supervised`.

Later-similar booking proof:

- Case: `case-0c0f1ee1`.
- Decision execution: `3225`, after 5Q12.
- `Q12. Lookup Active Form Learning Rules` executed and fetched active rule metadata including rule `c9860e74-ff23-477e-87f1-812bec8023e5` and source case `case-5cf1aa57`.
- The draft shared a booking link, but the case was classified as `INFORMATION_REQUEST / OFFER_EXPLANATION`, not `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Because the source rule scope is `current_micro_intent_only` with policy precedence `INFORMATION_REQUEST|BOOKING_REQUEST|current_micro_intent_only`, the active booking rule was fetched but not eligible for the current case micro-intent.
- Root cause: Decision micro-intent detection lacked booking-link/time-selection phrase handling under `INFORMATION_REQUEST`.

Leakage control:

- Case: `case-89673efb`.
- Decision execution: `3222`, after 5Q12.
- `Q12. Lookup Active Form Learning Rules` executed and fetched active rules, but the pricing draft stayed scoped to pricing/commitment.
- No booking-rule wording leaked into the pricing draft.
- The draft did not invent a price, guarantee, result, or contract term; it stayed human-reviewable.
- Sender was not triggered for either live test case. Recent Sender executions checked: none contained either case.

Corrected-classification proof:

- Source rule `c9860e74-ff23-477e-87f1-812bec8023e5` preserves original classification as `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Corrected/effective classification is stored as `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Target classification used is stored as `INFORMATION_REQUEST / BOOKING_REQUEST`.
- The first later-similar case did not prove consumption because it repeated the original-target micro-intent mismatch; this confirmed the corrected target is not silently broadened to the original `OFFER_EXPLANATION` target.

Minimal repair:

- Patched Decision node `B. Deterministic Reply Classifier` only.
- Added booking-link/time-selection phrase handling so `booking link`, `calendar link`, `choose a time`, `pick a time`, `send/share booking link`, `availability`, and `time options` map to micro-intent `BOOKING_REQUEST` under `INFORMATION_REQUEST`.
- Production guard passed before apply.
- Decision versionId changed from `009daf13-58f7-442c-b74b-c43f352620fe` to `f50e70f3-56bb-494e-8dfb-c3108d84e784`; active remained `true`.
- Backup: `backups/sl-phase-5q13-booking-classifier-20260629T025310Z`.
- Post-apply 5Q12 targeted harness: `29/29 PASS`.
- Post-apply local phrase checks passed: booking-link phrase matches booking regex; pricing phrase remains pricing and does not match booking.

Next owner action:

- Create one fresh owned/test booking-link reply after Decision version `f50e70f3-56bb-494e-8dfb-c3108d84e784`, using wording like: `Could you send me the booking link so I can choose a time?`
- Inspect the review draft only. Do not approve, send, or click learning-only.

## 5Q14B Deterministic Template Learning Bypass

**Date:** 2026-06-29  
**Verdict:** PARTIAL / deterministic-template bypass fixed and harness-proven; fresh live proof still required  
**Status percentage:** 94%

Live trace:

- Fresh case `case-7f53d7bb` was created after Decision version `f50e70f3-56bb-494e-8dfb-c3108d84e784`.
- Inbound asked for the link to book a time.
- Decision execution `3257` classified it as `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- Draft policy was `FIXED_TEMPLATE`; draft source was `deterministic_template`.
- Q12 active form-learning lookup executed and fetched rule `c9860e74-ff23-477e-87f1-812bec8023e5` with source case `case-5cf1aa57`.
- Decision D did not include or apply the active rule instruction in the deterministic template output.

Root cause:

- Q12 lookup ran, but deterministic/fixed template output bypassed active form-created learning.
- The source rule target was `INFORMATION_REQUEST / BOOKING_REQUEST`, while the current taxonomy classified booking-link asks as `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- The active rule was present but not eligible/consumed by the deterministic template path.

Repair:

- Patched Decision node `D. Draft Preparation (Templates / Human Draft)` only.
- Added a narrow booking taxonomy crosswalk so corrected/effective form rule micro-intent `BOOKING_REQUEST` can match current `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- Added active-rule postprocessing for deterministic/fixed template drafts, while preserving AI supervised, commercial supervised, and safe fallback active-rule consumption.
- Preserved source metadata in active behavioural guidance (`source_case_id`, `source_marker`).
- Did not hardcode the learned booking guidance into the classifier or deterministic templates.

Production:

- Production guard passed.
- Backup: `backups/sl-phase-5q14b-deterministic-template-learning-bypass-20260629T035240Z`.
- Decision `f50e70f3-56bb-494e-8dfb-c3108d84e784` -> `c7299598-71e2-4f0f-b493-184cb7b793f7`; active remained `true`.
- HumanApproval unchanged `f1138daa-8d38-4acf-b0c9-a6a2bef626fe`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`; latest Sender execution remained `3193`.
- Shadow Evaluator remained inactive.

Harness:

- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`
- 5Q11/5Q10 not run because HumanApproval target storage and review-form paths were not changed.

Next owner action:

- Create one fresh owned/test booking-link reply after Decision version `c7299598-71e2-4f0f-b493-184cb7b793f7`, using: `Can you send over the link to book a time that works for me?`

## 5Q15 Dynamic Classification Source-of-Truth Follow-up

**Date:** 2026-06-29  
**Verdict:** PARTIAL / local source-of-truth repair harness-proven; production apply and fresh live proof pending.

5Q12 made form-created draft/style rules active/effective and source-marked. 5Q15 found that classification corrections still were not dynamically active before Decision draft policy/template selection.

Local 5Q15 repair:

- HumanApproval now emits active/effective classification correction rows from form-created corrections.
- The classification row preserves source case ID, original classification, corrected/effective classification, target classification, source marker, human instruction, active/effective timestamps, and immediate supervised effect.
- Decision D now reads active HumanApproval form-created classification rows and applies the newest same-scope correction before draft policy/template selection.
- Decision continues to consume active form-created draft rules after effective classification is set.

Harness:

- 5Q15 Python/PowerShell: `35/35 PASS`
- 5Q12 Python/PowerShell regression: `29/29 PASS`

Production was not applied in 5Q15 because production API access was rejected by policy.
- Inspect the review draft only. Do not approve, send, or click learning-only.
