# SL-PHASE-5Q5 Save/Reopen Persistence

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q3-corrected-live-retest/20260628-032641`  
**Verdict:** PARTIAL - root cause fixed and production-applied; owner live recheck pending  
**Status percentage:** 84%

## 2026-06-28 SL-PHASE-5Q6 Addendum

Save/reopen evidence is now n8n-proven for the requested fields on `case-535d430a`: HumanApproval execution `2862` reopened the case as `IN_REVIEW` with `decision_payload.latest_saved_reply_text`, combined learning instruction, revision types, improvement scopes, and target classifications persisted. No Sender execution contained `case-535d430a`, and no learning-only/approval action was performed by Codex.

SL-PHASE-5Q6 also fixed two later blockers and production-applied Intake `abc83e43-9b97-4ca1-ae32-c42599255328` plus Decision `676c83ad-ebbd-4dd6-a204-b48245e061bc`; see `reports/SL-PHASE-5Q6_THREAD_AND_AI_FALLBACK_REPAIR.md`.

2026-06-28 SL-PHASE-5Q7 addendum: `case-f67601bc` Save-only execution `2887` and reopen `2888` remained no-send; HumanApproval source/banners were patched afterward. Save/reopen protections and non-send routing remain harness-proven.

2026-06-28 SL-PHASE-5Q8 addendum: `case-c3341a17` render failed before the form could display because 5Q7 node `J` banner HTML had unescaped JavaScript string quotes. 5Q8 patched only `J. Render Review Form HTML`; Save/reopen persistence code and learning-field prefill remain harness-proven. Owner-authenticated live reopen is still required before resuming Save or learning-only proof.

2026-06-28 SL-PHASE-5Q9 addendum: `case-9b9197a4` proved Save/reopen persisted edited draft and learning fields before a later blocked `approve_and_send_followup`. 5Q9 keeps blocked missing-variable submits editable as `IN_REVIEW`, preserves the same token, and shows exact correction steps. 5Q5 save/reopen still passes `34/34` after the 5Q9 production export sync.

## Live Failure Summary

Case `case-535d430a` rendered normally after the 5Q4 renderer fix. The owner edited the draft and learning fields, clicked `Save draft and learning` only, and saw:

```text
Recorded
No reply will be sent for case case-535d430a. Status: IN_REVIEW
```

On reopening the same review link, the form displayed the original fallback draft and did not prefill the saved learning fields.

The owner did not click `Approved for learning only`, `Approve and send`, or deny/no reply.

## Execution Trace

| Workflow | Execution | Started | Evidence |
|---|---:|---|---|
| HumanApproval GET/render | `2850` | `2026-06-28T03:18:44.203Z` | Rendered `case-535d430a` with original `draft_text`, status `NEW`. |
| HumanApproval POST/save | `2853` | `2026-06-28T03:29:20.165Z` | Submit body had `action=save`, `edited_reply_text`, `draft_learning_instruction`, multi-select `draft_revision_types`, multi-select `draft_improvement_scopes`, target classifications `broad_category:INFORMATION_REQUEST` and `micro_intent:OFFER_EXPLANATION`, and approver identity. |
| HumanApproval GET/reopen | `2854`, `2855` | `2026-06-28T03:29:27Z` / `03:29:36Z` | Reopened row status `IN_REVIEW`, but node J displayed original `draft_text`. |
| HumanApproval POST/save | `2857` | `2026-06-28T03:33:15.773Z` | Second save also received edited draft and learning fields. |
| HumanApproval GET/reopen | `2858` | `2026-06-28T03:35:15.864Z` | Row contained `final_reply_text` and `decision_payload.latest_saved_reply_text` with edited draft plus `decision_payload.latest_draft_learning`, but render still preferred original `draft_text`. |
| Sender | none linked | n/a | Latest Sender executions did not contain `case-535d430a`. |

## Root Cause Classification

**D. Render reloads original state**, with one supporting Save persistence gap.

Save received the edited draft and learning values and persisted them in `final_reply_text` and `decision_payload.latest_saved_reply_text` / `decision_payload.latest_draft_learning`. The render node `J. Render Review Form HTML` used `rc.draft_text` for unsent cases, so reopened `IN_REVIEW` cases displayed the original creation draft instead of saved state.

The save branch also did not set `rc.approver_identity` for `action=save`, so approver identity was not persisted even when submitted.

## Files Changed

- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q5-save-reopen-persistence.py`
- `scripts/SL-PHASE-5Q5-save-reopen-persistence.ps1`
- `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`
- `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

## Fix Summary

- `N. Process Reviewer Decision`
  - Save now persists `rc.approver_identity`.
  - Save records `saved_by` in `decision_payload`.
- `J. Render Review Form HTML`
  - Unsent/saved cases now prefill draft from `decision_payload.latest_saved_reply_text || rc.final_reply_text || rc.draft_text`.
  - Unsent/saved cases now preload `decision_payload.latest_draft_learning`.
  - Approver identity field now preloads saved approver identity.

## Harness Results

- 5Q5 Python: `34/34 PASS`
- 5Q5 PowerShell: `34/34 PASS`
- 5Q4 Python: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`
- 5R-prep PowerShell: `17/17 PASS`

## Production Apply Status

- Guard passed before production API write.
- Backup directory: `backups/sl-phase-5q5-save-reopen-persistence-20260628T034300Z`
- HumanApproval changed only:
  - `J. Render Review Form HTML`
  - `N. Process Reviewer Decision`
- HumanApproval versionId: `542f4159-fb6b-4dc4-9dda-f97657fbf7ac` -> `4caf621f-cda5-4aca-84a7-e1b521e99c7c`
- HumanApproval active state preserved: `true`
- Decision unchanged: `a4dab823-a540-48e8-8df6-514eca5d060a`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Unexpected drift: NONE.

## Remaining Proof

Owner must repeat the save/reopen action on `case-535d430a`:

1. Reopen the same review link.
2. Edit the draft and learning fields again.
3. Click `Save draft and learning` only.
4. Reopen the same link.
5. Report whether edited draft, combined reason/instruction, improvement types, scope/target classifications, and approver identity persisted.

Do not click `Approved for learning only` until this passes.

## Safety Confirmation

- Save does not send.
- Save does not activate a final learning rule.
- Save does not create a draft candidate while `final_action === "save"`.
- Sender was not triggered.
- Token was not mutated.
- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Live autonomous sending remains disabled.
- `approve_and_send_followup` auto-send remains disabled.
