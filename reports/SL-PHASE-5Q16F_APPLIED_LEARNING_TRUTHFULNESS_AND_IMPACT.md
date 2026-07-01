# SL-PHASE-5Q16F Applied Learning Truthfulness and Impact

Date: 2026-06-30

## Verdict

`case-acf4513f` is not accepted as complete live self-improvement proof.

The case is valid and post-5Q16D. It shows the active HumanApproval form-created rule was found, eligible, and consumed. The final draft did change because of that rule: the deterministic baseline was replaced by rule-derived booking-link/availability wording.

However, 5Q16D still allowed a false-positive gap: `learning_applied_to_draft` could be true whenever an eligible rule and a draft existed, rather than only when the final draft differed from the pre-learning draft. 5Q16F repaired that truthfulness gap.

The poor sentence in the live draft came from the stored HumanApproval rule instruction itself, not from the static deterministic template:

`At the end you can mention thaqt they can ask any question if they have any.`

Codex did not silently rewrite that source rule. A future human review should improve or supersede the rule if the desired wording is different.

Status remains `94` pending one fresh post-5Q16F live proof.

## Live Case Trace

- Case: `case-acf4513f`
- HumanApproval create execution: `3584`, started `2026-06-30T04:06:12.389Z`
- HumanApproval render execution: `3585`, started `2026-06-30T04:06:25.801Z`
- Decision execution: `3583`, started `2026-06-30T04:06:11.914Z`
- Valid/non-diagnostic: yes
- Created after Decision `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa`: yes
- Created after HumanApproval `05244014-0ba9-4b6e-b82c-867a31be61c6`: yes
- Inbound reply: `Can you send across the booking link so I can choose a time?`
- Effective classification: `INFORMATION_REQUEST / BOOKING_REQUEST`
- Draft policy/source: `FIXED_TEMPLATE_WITH_FORM_LEARNING` / `deterministic_template_with_form_learning`
- Active learning rules found: yes
- Active learning rules eligible: yes
- Active learning rules applied: yes, but pre-5Q16F this was not delta-gated
- Applied rule ID: `c9860e74-ff23-477e-87f1-812bec8023e5`
- Source case ID: `case-5cf1aa57`
- Source marker: `humanapproval_form_created_learning`
- Sender triggered: no
- Instantly POST/live send: no evidence; latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`

## Source Rule Payload

- Rule ID: `c9860e74-ff23-477e-87f1-812bec8023e5`
- Source case: `case-5cf1aa57`
- Source marker: `humanapproval_form_created_learning`
- Target scope: `INFORMATION_REQUEST / BOOKING_REQUEST`
- Original classification: `INFORMATION_REQUEST / OFFER_EXPLANATION`
- Corrected/effective classification: `INFORMATION_REQUEST / BOOKING_REQUEST`
- Active/effective: yes

Exact stored instruction:

```text
Just share the booking link and offer that I can book them in if they share their availability.

Booking link: https://calendar.app.google/yUyUxcuBdsFgtjnk7

Do NOT talk about the offer, just answer their question. At the end you can mention thaqt they can ask any question if they have any.
```

Instruction strength:

- Strong enough to require booking-link wording and availability handling.
- Weak/low-quality for the final question sentence because it contains a typo and awkward phrasing.
- It does not by itself define a polished final wording standard.

## Draft Impact Audit

The live draft was:

```text
Booking link: https://calendar.app.google/yUyUxcuBdsFgtjnk7

I can book you in if you share your availability.

you can ask any question if they have any.

Zahid
```

Attribution:

- `Booking link: ...` came from the active HumanApproval form-created rule instruction.
- `I can book you in if you share your availability.` came from the active rule instruction after runtime pronoun normalization.
- `you can ask any question if they have any.` came from the active rule instruction, including its weak wording.
- `Zahid` came from sender/signature context.
- The static deterministic baseline did not contain the learned booking instruction or the bad sentence.

Therefore the draft did change because of the rule, but the source rule needs quality improvement.

## Repair

Decision now separates rule states as follows:

- `active_learning_rules_found`: rule was present in active form-learning data.
- `active_learning_rules_eligible`: rule matched effective classification/scope.
- `active_learning_rules_applied`: rule actually changed classification or final draft output.
- `learning_applied_to_draft`: true only when normalized final draft text differs from the pre-learning draft.
- `learning_applied_to_classification`: true only when effective classification differs from baseline because of a rule.
- `learning_not_applied_reason`: uses `RULE_FOUND_BUT_NO_OUTPUT_DELTA` when a rule was found/eligible but did not change output.
- `learning_impact_summary`: explains the actual output effect when learning is applied.

HumanApproval now displays:

- active learning rules found count
- active learning rules eligible count
- active learning rules actually applied count
- learning impact summary
- applied rule ID/source case/source marker
- non-application reason when relevant

## Production Apply

- Guard: passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`
- Backup path: `backups/SL-PHASE-5Q16F_20260630T041500Z`
- Decision version: `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa` -> `52753ab6-62f5-4334-9111-6f3f838cd698`
- HumanApproval version: `05244014-0ba9-4b6e-b82c-867a31be61c6` -> `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200`
- Active states: preserved
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`
- No Sender execution, Instantly POST, or live email send was triggered by this apply

## Harness Results

- 5Q16F Python: `22/22 PASS`
- 5Q16F PowerShell: `22/22 PASS`
- 5Q16D Python: `32/32 PASS`
- 5Q16D PowerShell: `32/32 PASS`
- 5Q16B Python: `30/30 PASS`
- 5Q16B PowerShell: `30/30 PASS`
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q12 Python: `29/29 PASS`
- 5Q12 PowerShell: `29/29 PASS`

## Next Live Proof

Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with:

`Can you send across the booking link so I can choose a time?`

Then inspect the Google Chat card and review page only.

Do not approve, send, save, or click learning-only.
