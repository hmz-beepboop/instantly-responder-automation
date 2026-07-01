# SL-PHASE-5Q14B Deterministic Template Learning Bypass

**Date:** 2026-06-29  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Verdict:** PARTIAL / deterministic-template bypass fixed and harness-proven; fresh live post-repair proof still required  
**Status percentage:** 94%

## Scope

5Q14B audited `case-7f53d7bb`, where the owner observed a deterministic template draft after the 5Q13 classifier repair. The goal was to avoid a false positive: a review draft can mention booking without proving that the active HumanApproval form-created rule was consumed.

No Sender, Intake, HumanApproval, autonomous, Gate 2, VPS, or live-send path was changed.

## Live Trace

Source rule:

- Rule ID: `c9860e74-ff23-477e-87f1-812bec8023e5`
- Source case: `case-5cf1aa57`
- Source marker: `humanapproval_form_created_learning`
- Status/effect: active/effective immediately
- Original classification: `INFORMATION_REQUEST / OFFER_EXPLANATION`
- Corrected/effective classification: `INFORMATION_REQUEST / BOOKING_REQUEST`
- Target classification used: `INFORMATION_REQUEST / BOOKING_REQUEST`

Fresh case:

- Case: `case-7f53d7bb`
- Intake: `00MQYNWXX305FU23S7A2RHHMXH`
- Inbound: asked for the link to book a time
- Broad category: `BOOKING_REQUEST`
- Micro intent: `MEETING_TIME_REQUEST`
- Draft policy: `FIXED_TEMPLATE`
- Draft source: `deterministic_template`
- Decision execution: `3257`
- Q12 lookup: executed and fetched active rule metadata, including rule `c9860e74-ff23-477e-87f1-812bec8023e5` and source case `case-5cf1aa57`
- Decision D output did not contain the active rule metadata or instruction terms
- Sender executions checked: latest Sender execution remained unchanged during production apply; no Sender trigger or Instantly POST was caused by this session

## Root Cause

Root causes:

- `A`: deterministic/fixed template path bypassed active form-created learning.
- `B`: Q12 lookup ran, but deterministic template output ignored rule context.
- `D/F`: classification schema mismatch prevented eligibility. The source rule target was `INFORMATION_REQUEST / BOOKING_REQUEST`, while the fresh case was classified as `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- `G`: the fixed template was static and could not adapt to active learning before this patch.

This was not safe to mark complete from live evidence. Q12 finding the rule was not enough; the active rule had to be eligible and change the draft through dynamic rule context.

## Repair

Patched Decision node `D. Draft Preparation (Templates / Human Draft)` only.

Changes:

- Added a narrow booking taxonomy crosswalk in active-policy eligibility:
  - form-created policy micro-intent `BOOKING_REQUEST`
  - can match current `BOOKING_REQUEST / MEETING_TIME_REQUEST`
  - only for booking category/micro-intent; it does not broaden pricing or unrelated scopes
- Preserved source metadata in behavioural guidance:
  - `source_case_id`
  - `source_marker`
  - activation/source fields
- Added active-rule postprocessing for all draft paths:
  - AI supervised
  - commercial supervised
  - safe fallback
  - deterministic/fixed template
- Added a bounded booking-link postprocessor that activates only when matching active form-created rule context is present.

Anti-false-positive constraints:

- The learned booking instruction was not hardcoded into the classifier.
- The learned booking instruction was not hardcoded into deterministic templates.
- Codex baseline policies remain separate from `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`.
- The deterministic template changes only when matching active HumanApproval form-created rule context is present.

## Harness Results

New targeted harness:

- `scripts/SL-PHASE-5Q14B-deterministic-template-learning-bypass.py`: `20/20 PASS`
- `scripts/SL-PHASE-5Q14B-deterministic-template-learning-bypass.ps1`: `20/20 PASS`

Regression:

- `scripts/SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.py`: `29/29 PASS`
- `scripts/SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.ps1`: `29/29 PASS`

5Q11 and 5Q10 were not run because HumanApproval target storage and review-form paths were not changed.

## Production Apply

Production guard passed before API operations.

Backup:

- `backups/sl-phase-5q14b-deterministic-template-learning-bypass-20260629T035240Z`

Version/state:

- Decision `f50e70f3-56bb-494e-8dfb-c3108d84e784` -> `c7299598-71e2-4f0f-b493-184cb7b793f7`
- Decision active preserved: `true`
- HumanApproval unchanged: `f1138daa-8d38-4acf-b0c9-a6a2bef626fe`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow Evaluator unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Sender latest execution remained `3193` before and after apply

## Next Owner Action

Create one fresh owned/test booking-link reply after Decision version `c7299598-71e2-4f0f-b493-184cb7b793f7`, using:

`Can you send over the link to book a time that works for me?`

Inspect the review draft only. Do not approve, send, or click learning-only.

## 5Q14D Invalid Diagnostic Link and Context-Missing Repair

**Date:** 2026-06-29  
**Verdict:** COMPLETE for diagnostic-link repair; live learning proof still pending  
**Status percentage:** remains 94%

Fresh attempted post-5Q14B case `case-3df4e733` is not valid self-improvement proof. It became `INTAKE_CONTEXT_MISSING / diagnostic only` with missing field `draft_text`.

Trace summary:

- Intake execution `3268` had campaign ID, lead email, sender/eaccount, subject, thread ID, and reply body after hydration.
- Decision execution `3269` classified as `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Decision selected `HUMAN_ONLY / human_only` because `BOOKING_REQUEST` as a micro-intent had no sendable draft-policy mapping, so no `draft_text` was produced.
- HumanApproval create execution `3270` correctly created a diagnostic row with `CONTEXT_MISSING_BLOCKED`.
- Review-link GET executions `3271` and `3272` happened before token expiry, but HumanApproval token gate excluded `CONTEXT_MISSING_BLOCKED` from renderable statuses and returned `ALREADY_DECIDED`.

Repair:

- HumanApproval version `00eb6dbc-c1a7-42ce-97ef-24653d06784d` now renders diagnostic links until expiry and shows diagnostic details/correction instructions while disabling all actions.
- Decision version `302e34bc-8b81-4c2f-97fa-832246153646` maps `INFORMATION_REQUEST / BOOKING_REQUEST` to the existing fixed booking-template path and extends active booking-rule matching to both `INFORMATION_REQUEST / BOOKING_REQUEST` and `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- The learned booking guidance was not hardcoded into baseline policy or templates.

Harness:

- 5Q14D Python/PowerShell: `21/21 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`

Next owner action now supersedes the earlier version target: create a fresh owned/test booking-link reply after Decision version `302e34bc-8b81-4c2f-97fa-832246153646` and HumanApproval version `00eb6dbc-c1a7-42ce-97ef-24653d06784d`. Inspect the review draft only; do not approve, send, or click learning-only.

## 5Q14F HumanApproval Render Crash and Live Booking Case

**Date:** 2026-06-29  
**Verdict:** COMPLETE for render crash and classifier eligibility repair; live learning proof still pending  
**Status percentage:** remains 94%

Fresh case `case-9747ff6f` was valid/non-diagnostic and had an AI-supervised draft, but the review link failed before render:

- HumanApproval execution `3493` failed at node `J. Render Review Form HTML`.
- Error: `SyntaxError: Unexpected identifier 'background'`.
- Cause: 5Q14D diagnostic HTML strings had unescaped `style="..."` and `type="button"` attributes, creating a Node J compile error.

Learning audit:

- Inbound: `Where can I grab a time on your calendar?`
- Decision execution `3491` classified it as `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Q12 found active rule `c9860e74-ff23-477e-87f1-812bec8023e5` with source case `case-5cf1aa57`.
- Rule was not eligible/consumed because the current micro-intent stayed `OFFER_EXPLANATION`.
- Draft calendar wording is not proof of form-created learning.

Repair:

- HumanApproval version `de84f8f3-d4c4-4565-88ab-c40449e727ca` fixes Node J render syntax and adds safe optional metadata fallback.
- Decision version `e64cded8-e4a9-46f8-b541-23512e9f4dce` adds narrow booking/calendar classifier handling for `grab a time`, `grab a slot`, and `time on your calendar`.
- Learned booking guidance remains not hardcoded into baseline policy, classifier, or deterministic templates.

Harness:

- 5Q14F Python/PowerShell: `22/22 PASS`
- 5Q14D Python/PowerShell: `21/21 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`

Next owner action now supersedes prior action: immediately reopen existing `case-9747ff6f` review link before `2026-06-29T23:07:37Z` and inspect the draft only. Do not approve, send, save, or click learning-only.

## 5Q15 Dynamic Classification Source-of-Truth Follow-up

**Date:** 2026-06-29  
**Verdict:** PARTIAL / local repair harness-proven; production apply and fresh live proof pending.

5Q14B proved deterministic/fixed-template draft paths could consume active form-created draft guidance once the classification was already eligible. 5Q15 found the remaining architecture gap: HumanApproval form-created classification corrections were not active/effective source-of-truth rules, and Decision did not consume them before effective draft policy/template selection.

Local 5Q15 repair:

- HumanApproval now emits active/effective form-created classification correction rows with original classification, corrected/effective classification, target classification, source case ID, source marker, and human instruction.
- Decision D now applies the newest matching active form-created classification rule before draft policy/template selection.
- Decision then consumes active form-created draft rules using the learned effective classification.

Harness:

- 5Q15 Python/PowerShell: `35/35 PASS`
- 5Q14B Python/PowerShell regression: `20/20 PASS`

Production was not applied in 5Q15 because production API access was rejected by policy.
