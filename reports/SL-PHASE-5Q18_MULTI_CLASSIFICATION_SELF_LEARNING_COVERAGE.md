# SL-PHASE-5Q18 Multi-Classification Self-Learning Coverage

Date: 2026-07-01

## Verdict

COMPLETE with a targeted repair. The four fresh seeded campaign-thread review cases were valid, non-diagnostic review cases. No `INTAKE_CONTEXT_MISSING` recurrence occurred, Intake hydration remained stable, Decision output was valid, HumanApproval created valid review cases, Sender was not triggered, and no Instantly reply POST occurred.

One real learning-leakage defect was found and repaired: setup/process case `case-58710f80` was baseline `INFORMATION_REQUEST / OFFER_EXPLANATION`, but the old booking classification rule promoted it to `INFORMATION_REQUEST / BOOKING_REQUEST` even though the inbound text did not ask for a booking/calendar link. Decision now requires booking/calendar intent in the actual reply text before any HumanApproval form-created classification rule may promote a reply into `BOOKING_REQUEST`.

Status remains `95`.

## Live Cases

All cases had raw webhook payloads with campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead context, sender account, subject, reply text, email ID, Instantly-hydrated `thread_id` `53-RKIOlX32DrLO3dLAoGwdkoG`, valid Intake output, valid Decision output, and valid HumanApproval review creation.

| Case | Meaning | Classification / Micro | Draft policy/source | Learning result |
|---|---|---|---|---|
| `case-c525ea1e` | calendar/booking request | `INFORMATION_REQUEST / BOOKING_REQUEST` | `FIXED_TEMPLATE_WITH_FORM_LEARNING` / `deterministic_template_with_form_learning` | booking draft rule applied correctly |
| `case-6396244e` | pricing/minimum commitment | `PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST` | `AI_COMMERCIAL_SUPERVISED` / `ai_commercial_supervised` | booking rule found but not eligible; no leak |
| `case-58710f80` | setup/process explanation | live pre-patch output became `INFORMATION_REQUEST / BOOKING_REQUEST` | `FIXED_TEMPLATE_WITH_FORM_LEARNING` / `deterministic_template_with_form_learning` | defect: booking classification+draft learning leaked; repaired for future cases |
| `case-119e086c` | not-now/later in year | `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` | `AI_SUPERVISED_OR_TEMPLATE` / `ai_supervised` | booking rule found but not eligible; no learning leak |

`case-ef1010f7` was also audited as the prior booking proof case. It was valid, non-diagnostic, and showed the same booking rule applied with both classification and draft effects.

## Learning Attribution

Known active booking rule:

- rule ID: `c9860e74-ff23-477e-87f1-812bec8023e5`
- source case: `case-5cf1aa57`
- marker: `humanapproval_form_created_learning`
- target: `INFORMATION_REQUEST / BOOKING_REQUEST`

Findings:

- Booking rule applied correctly to `case-c525ea1e`.
- Booking rule did not apply to pricing case `case-6396244e`.
- Booking rule did not apply to not-now case `case-119e086c`.
- Before the patch, booking classification learning leaked to setup/process case `case-58710f80`.
- Non-application reason was visible on unrelated cases: `ACTIVE_RULES_FOUND_BUT_NONE_ELIGIBLE_FOR_EFFECTIVE_CLASSIFICATION`.
- Found/eligible/applied attribution remained truthful: found rules can exist without eligibility or application.

## Duplicate Rule Audit

`case-ef1010f7` and pre-patch `case-58710f80` showed the same rule ID/source case twice in applied metadata because the same HumanApproval-created learning event had two effects:

- classification effect: `OFFER_EXPLANATION` -> `BOOKING_REQUEST`
- draft effect: final draft changed after active rule postprocessing

This did not double-apply draft output. The duplicated rule ID in arrays is owner-facing noisy but explainable because the two effects remain separately auditable. No display patch was applied in 5Q18; `learning_impact_summary` distinguishes classification and draft effects.

## Draft Quality / Override Readiness

The old weak booking rule remains active. Its draft wording still contains the weak/awkward sentence inherited from source case `case-5cf1aa57`. No newer same-scope override rule was found in the audited outputs.

Decision still supports newest same-scope precedence. The correct owner action is to create a better same-scope HumanApproval form-learning override from a future booking review case. Codex did not rewrite the old human-created rule and did not hardcode improved booking wording.

## Repair

Patched only:

- `workflows/production_decision_current.json`

Decision now includes:

- `_5qReplyHasBookingIntent(text)`
- `_5qClassificationRuleAllowedForReply(rule, replyText)`
- booking classification-learning promotion blocked unless reply text contains booking/calendar intent

No changes were made to Intake, HumanApproval, Sender, Proxy, Shadow, Gate 2, autonomous mode, or learning-rule rows.

## Production Apply

Guard passed with:

```text
pwsh -File ./scripts/assert-hmz-production-target.ps1
```

Backup:

- `backups/SL-PHASE-5Q18_20260701_010330/Decision-tgYmY97CG4Bm8snI-before.json`

Version IDs:

- Decision `333e6d60-53e3-4e3b-ad69-5c799c4992bd` -> `889e1d45-7103-4b0a-a85d-685d19a2cadd`, active remained `true`
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`
- HumanApproval unchanged `0fa9d0ce-585e-495e-8af6-dbdb4957ab78`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow unchanged/inactive `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`; no Sender execution or Instantly POST was triggered by trace or apply.

## Harness Results

Post-apply:

- 5Q18 Python: `20/20 PASS`
- 5Q18 PowerShell: `20/20 PASS`
- 5Q17D Python: `28/28 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q16D Python: `32/32 PASS`

Full suite was not run.

## Residual Risks

- Existing pre-patch `case-58710f80` remains a leaked review case; the patch is forward-looking.
- Existing not-now case `case-119e086c` was valid and no learning applied, but baseline classification/draft quality is weak: it classified as `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` and the AI draft still included a calendar CTA. This is not booking-rule leakage, so it was not patched in 5Q18.
- The old weak booking rule remains active until the owner creates a better same-scope override.

## Next Action

Owner should create one improved booking review case and save a better same-scope form-learning instruction for `INFORMATION_REQUEST / BOOKING_REQUEST`, then retest one booking request and one setup/process explanation. Do not approve/send during that proof.
