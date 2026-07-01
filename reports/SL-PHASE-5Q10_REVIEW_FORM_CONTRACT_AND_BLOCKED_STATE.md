# SL-PHASE-5Q10 Review Form Contract and Blocked State

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Verdict:** PARTIAL - HumanApproval contract defect fixed, harness-proven, and production-applied; one owner live confirmation remains pending  
**Status percentage:** 86%

## Summary

Latest owner evidence showed a HumanApproval UI/backend contract mismatch: a sent-style reopened case blocked a blank reply box with `repeat_send_reason_required`, even though the owner had not been shown a usable repeat-send reason field and the blank field was the reply textarea. Returning to the review form after the blocked submit also removed the already-approved/sent banner.

Codex inspected only HumanApproval and the 5Q9 harness files. The defect was isolated to HumanApproval:

- `repeat_send_reason` existed in the HTML but was inside a `display:none` container with no script to reveal it.
- `approve_and_send_followup` validated missing repeat-send reason before clearly mapping blank reply text to a draft-specific missing variable.
- normal approve/send blank draft reused stale `rc.blocked_variables`, so it could omit `draft_text_required`.
- sent-style blocked submits changed status to `IN_REVIEW`, so the already-approved/sent banner disappeared on reopen.
- learning-only allowed both blank reply text and blank learning instruction.

## UI/Backend Contract

| Visible label | HTML input name | Backend variable | Action(s) | Required | Owner-facing error if missing |
|---|---|---|---|---|---|
| Reply text (editable) | `edited_reply_text` | `submit_edited_text` | approve/send, send another reply, learning-only | Required for approve/send and send another reply; optional for learning-only if learning instruction exists | `draft_text_required` / “Enter reply text in the draft box” |
| Why did you make this change, and what should the system do next time? | `draft_learning_instruction` | `submit_draft_learning_instruction` | save, learning-only, approve/send, follow-up metadata | Required for learning-only only when reply text is blank | `learning_instruction_required` |
| Where this draft improvement should apply | `draft_improvement_scopes` | `submit_draft_improvement_scopes` | learning capture | Optional, defaults/falls back | none |
| What type of improvement is this? | `draft_revision_types` | `submit_draft_revision_types` | learning capture | Optional | none |
| Which detected classification(s) should this draft improvement apply to? | `draft_improvement_target_classifications` | `submit_draft_improvement_target_classifications` | learning capture | Optional | none |
| Corrected broad category | `corrected_category` | `submit_corrected_category` | classification shadow learning | Optional | none |
| Corrected micro intent | `corrected_micro_intent` | `submit_corrected_micro_intent` | classification shadow learning | Optional | none |
| Reason for sending another reply | `repeat_send_reason` | `submit_repeat_send_reason` | send another human-approved reply | Required only for `approve_and_send_followup` | `repeat_send_reason_required` |
| Approver name/email | `approver_identity` | `submit_approver_identity` | approve/send, learning-only, send another reply | Required for approval actions | `approver_identity_required` |

No backend-required repeat-send field remains hidden without a visible label.

## Root Cause Classification

- **A. hidden required field:** confirmed. `repeat_send_reason` was hidden by `display:none`.
- **B. wrong missing-variable mapping:** confirmed. normal approve blank draft could reuse stale blocked variables instead of `draft_text_required`.
- **C. blank draft incorrectly mapped to repeat_send_reason:** confirmed for the owner path because follow-up validation did not independently name blank reply text.
- **D. sent-style form missing visible repeat-send reason field:** confirmed. Field existed but was not visible/usable.
- **E. blocked send hides approved/sent banner:** confirmed. blocked submit changed sent-style status to `IN_REVIEW`.
- **F. learning-only allows invalid blank learning state:** confirmed. both blank reply and blank learning instruction were accepted before this patch.

## Fix Summary

Patched HumanApproval only:

- `J. Render Review Form HTML`
  - shows `Reason for sending another reply` as a visible field when `Send another human-approved reply` is available.
  - renders a blocked-attempt banner without replacing the already-approved/sent banner.
  - preserves the sent-style banner after a blocked submit using `previous_status`.
  - keeps reply textarea escaping intact for normal and blocked retry states.
- `N. Process Reviewer Decision`
  - maps blank normal approve/send reply text to `draft_text_required`.
  - maps blank follow-up reply text to `draft_text_required` and blank repeat reason to `repeat_send_reason_required`.
  - keeps sent-style status on blocked follow-up/learning-only submits so the approved/sent banner persists.
  - blocks learning-only only when both reply text and learning instruction are blank, with `learning_instruction_required`.
  - preserves no-send, same-link retry, token stability, editable state, and no duplicate Sender/Instantly path.

## Harness Results

- 5Q10 Python: `22/22 PASS`
- 5Q10 PowerShell: `22/22 PASS`
- 5Q9 Python: `21/21 PASS`
- 5Q9 PowerShell: `21/21 PASS`
- 5Q8 render Python: `22/22 PASS`
- 5Q8 render PowerShell: `22/22 PASS`
- 5R-prep idempotency/token: not run; Sender/idempotency path was not changed.

## Production Apply

- Production guard passed before API write.
- Backup directory: `backups/sl-phase-5q10-review-form-contract-20260628T172409Z`
- HumanApproval `91060513-b41f-4b9d-9c25-f94935ae8bc7` -> `50d77bbb-546f-4a85-8902-4ead1c3776b4`
- Active state preserved: `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Decision unchanged: `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged and inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Post-apply Sender check:

- No Sender execution started during or after this apply.
- Latest Sender execution remained `3066`, started `2026-06-28T16:40:37.296Z`, before this patch.
- No Instantly POST was caused by this patch.

## Next Owner Action

Use one owned/test sent-style case that already shows the approved/sent banner. Reopen the review link, clear the reply textarea, leave `Reason for sending another reply` blank, click `Send another human-approved reply` once, screenshot the blocked page, reopen the same link, and confirm both the blocked-attempt banner and already-approved/sent banner are visible. Stop there.

## 2026-06-28 5Q11 Follow-Up

Owner evidence on `case-6ebd0e3a` showed the 5Q10 blocked validation improved, but the later captured follow-up state `FOLLOWUP_SEND_PENDING_MANUAL` was not reopenable and returned an already-decided style page. 5Q11 patched HumanApproval token/render eligibility for follow-up/manual-send states and added corrected-classification learning-target metadata.

Production:

- HumanApproval `50d77bbb-546f-4a85-8902-4ead1c3776b4` -> `d3449764-b059-48be-b73a-8a9beae443ea`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q9 Python/PowerShell: `21/21 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`
- 5R-prep Python/PowerShell: `17/17 PASS`
- Intake, Decision, Sender, Proxy, and Shadow Evaluator unchanged; Shadow remains inactive.

## 2026-06-29 5Q12 Follow-Up

5Q12 intentionally changes the 5Q10 UI contract by removing the `What type of improvement is this?` checkbox section. The combined explanation/instruction field is now the primary learning signal; scope and target classification controls remain.

Harnesses after the change:

- 5Q12 Python/PowerShell: `29/29 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS` with the updated contract that improvement-type selections are absent
- 5Q8 render Python/PowerShell: `22/22 PASS`
