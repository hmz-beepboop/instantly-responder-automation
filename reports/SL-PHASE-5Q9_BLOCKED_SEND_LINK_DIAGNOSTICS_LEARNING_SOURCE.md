# SL-PHASE-5Q9 Blocked Send Link Diagnostics and Learning Source

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Verdict:** PARTIAL - root cause fixed, harness-proven, and production-applied; owner-authenticated same-link reopen still pending  
**Status percentage:** 88%

## 2026-06-28 Q2 Quote-Escape Addendum

Before asking the owner to run a fresh blocked-send live proof, Codex re-inspected only HumanApproval node `Q2. Build Non-Send Terminal Result` and the 5Q9 harness. Q2 still had raw HTML attribute quotes in the blocked-page JavaScript strings:

- blocked heading string with `style="color:#c0392b"`
- blocked correction `<div>` string with `style="background:#fff3cd..."`

This could break the blocked-result page before proving the 5Q9 behaviour. Codex patched Q2 only, escaping those attributes inside the JavaScript strings while preserving:

- exact missing variable display;
- exact correction instructions;
- same-link retry behaviour;
- editable blocked-review state;
- token stability;
- no-send/no-duplicate-post semantics.

Harness results:

- 5Q9 Python: `21/21 PASS`
- 5Q9 PowerShell: `21/21 PASS`

Production apply:

- Guard passed before API write.
- Backup directory: `backups/sl-phase-5q9-q2-quote-escape-20260628T165553Z`
- HumanApproval `68f4b543-0004-4677-a95c-ba6768a8523c` -> `91060513-b41f-4b9d-9c25-f94935ae8bc7`
- Active state preserved `true`.
- Changed node: `Q2. Build Non-Send Terminal Result` only.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Decision unchanged `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.

Post-apply Sender check:

- Q2 apply did not trigger Sender.
- Latest Sender execution observed after apply was `3066`, started `2026-06-28T16:40:37.296Z`, before this Q2 apply; it reached `Q. POST Reply to Instantly (Gated)` and `X2. Build SENT Terminal Result`. Treat it as separate owner/live activity, not caused by this patch.

## Summary

`case-9b9197a4` proved the current supervised-use blocker. The owner saved the draft/learning fields, reopened the review form, approved learning-only, reopened again, then submitted `approve_and_send_followup` without the required repeat-send reason.

HumanApproval correctly detected the internal missing variable `repeat_send_reason_required`, saved the edited draft and learning fields, and did not trigger Sender. However, it set the case status to `BLOCKED_MISSING_VARIABLES`, which the GET/POST token validators treated as terminal. The same token was still present, but subsequent same-link opens routed to the token error page as `ALREADY_DECIDED`. The owner-facing blocked page also rendered `missing required variables ()` because `Q2` read `rc.blocked_variables`, while node `N` stored the variable under `decision_payload.blocked_variables`.

`case-8cba5975` was traced through Intake, HumanApproval create, and first render only. No submit, Sender execution, blocked-send path, retry link, duplicate send, or Instantly POST was found for that case in the targeted recent execution window.

## Case Trace

| Case | Evidence |
|---|---|
| `case-9b9197a4` | Intake `2908`; HumanApproval create `2910`; render `2911`; save `2912`; render `2913`; learning-only `2914`; render `2915`; blocked `approve_and_send_followup` `2916`; same-link token-error renders `2917`, `2918`, `2924`, `2925`, `3042`. |
| `case-8cba5975` | Intake `2920`; HumanApproval create `2922`; render `2923`; status `NEW`, token valid, form rendered. No submit or Sender evidence found. |

## Root Causes

- **Blocked review link:** case status became `BLOCKED_MISSING_VARIABLES`, and validators `H`/`L` treated it as `ALREADY_DECIDED`. Token hash evidence showed the token itself was stable.
- **Missing variable message:** node `N` stored `repeat_send_reason_required` in `decision_payload.blocked_variables`, but node `Q2` displayed `rc.blocked_variables`, which was empty.
- **Learning source-of-truth:** HumanApproval creates form-derived `proposed_shadow` candidates with source case, instruction, scope, classification, improvement types, timestamp, and status. Decision consumes active behavioural policies from its embedded active-policy array; active rules are distinguishable by `source_case_id` / `activation_source`, but fresh form-created candidates do not affect Decision until activated/injected.

## Fix Summary

Patched only HumanApproval:

- `H. Validate Review Token (GET)` and `L. Validate & Consume Review Token (POST)` now allow `BLOCKED_MISSING_VARIABLES` to reopen on the same token.
- `N. Process Reviewer Decision` keeps missing-variable blocked submits editable as `IN_REVIEW`, preserves the existing token, saves edited draft and learning fields, stores exact missing variables, records `sent=false`, and records explicit correction instructions.
- `Q2. Build Non-Send Terminal Result` displays exact missing variables, states the reply was not sent, and gives correction steps.
- Recoverable Sender-block retry path preserves the same token/link instead of generating a new token/link; `R2` keeps the case editable as `IN_REVIEW`.
- Sender workflow was not changed.

## Harness Results

Post-production-export sync:

- 5Q9 Python: `21/21 PASS`
- 5Q9 PowerShell: `21/21 PASS`
- 5Q8 render Python: `22/22 PASS`
- 5Q7 labels Python: `17/17 PASS`
- 5Q5 save/reopen Python: `34/34 PASS`
- 5R-prep idempotency/token Python: `17/17 PASS`
- 5R-prep idempotency/token PowerShell: `17/17 PASS`

## Production Apply

Production guard passed before API operations.

Backup directory:

- `backups/sl-phase-5q9-blocked-send-link-diagnostics-learning-source-20260628T155013Z`

Workflow update:

| Workflow | Old versionId | New versionId | Active after | Changed nodes |
|---|---|---|---:|---|
| HumanApproval | `34531128-5ff6-4538-8846-bbbc5888a7a9` | `68f4b543-0004-4677-a95c-ba6768a8523c` | `true` | `H`, `L`, `N`, `Q2`, `R-GenToken`, `R2`, `R3`, `R5` |
| HumanApproval Q2 addendum | `68f4b543-0004-4677-a95c-ba6768a8523c` | `91060513-b41f-4b9d-9c25-f94935ae8bc7` | `true` | `Q2` only |
| Decision | `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` | unchanged | `true` | none |
| Intake | `abc83e43-9b97-4ca1-ae32-c42599255328` | unchanged | `true` | none |
| Sender | `dfb310f4-901a-4d76-81dc-8f5d4ad13552` | unchanged | `true` | none |
| Shadow Evaluator | `ae13bf4e-ee04-438f-9657-3c57183b90a2` | unchanged | `false` | none |

Latest Sender executions after apply remained old `2762`, `2760`, `2740`; no Sender/live send was triggered by the apply.

## Safety Confirmation

- Same token is preserved on blocked submit.
- Missing-variable blocked submit remains editable.
- No new/broken retry link is generated.
- No Sender workflow update.
- No Instantly POST by Codex.
- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Live autonomous sending remains disabled.
- `approve_and_send_followup` automated send remains disabled.
- VPS/SSH was not used.

## Remaining Proof

Owner-authenticated live reopen is still pending. Codex cannot open the Basic Auth protected review form with the allowed environment variables.

## Next Owner Action

Use one fresh owned/test sent-style review case. Reopen it, click `Send another human-approved reply`, leave `Reason for sending a follow-up reply` blank, submit once, screenshot/report the blocked result page, then reopen the same review link and stop before any further submit.

## 2026-06-28 5Q10 Contract Follow-Up

Latest owner evidence after the 5Q9 Q2 addendum found a separate HumanApproval UI/backend contract defect: the owner blanked the reply textarea, but the blocked message named `repeat_send_reason_required`; the visible form did not expose a usable repeat-send reason field, and the already-approved/sent banner disappeared after blocked submit.

5Q10 patched HumanApproval only:

- visible `Reason for sending another reply` field for sent-style repeat-send attempts;
- `draft_text_required` for blank reply text on normal approve/send and repeat-send paths;
- `repeat_send_reason_required` only for the visible repeat-send reason field;
- `learning_instruction_required` when learning-only has both blank reply text and blank learning instruction;
- blocked-attempt banner rendered without replacing the already-approved/sent banner;
- sent-style status/banner preserved after blocked submit.

Harnesses:

- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q9 Python/PowerShell: `21/21 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`

Production:

- Guard passed.
- Backup directory: `backups/sl-phase-5q10-review-form-contract-20260628T172409Z`
- HumanApproval `91060513-b41f-4b9d-9c25-f94935ae8bc7` -> `50d77bbb-546f-4a85-8902-4ead1c3776b4`
- Intake, Decision, Sender, Proxy, and Shadow Evaluator version IDs unchanged; Shadow remains inactive.
- No Sender execution or Instantly POST was caused by the patch.

## 2026-06-28 5Q11 Link Accessibility Follow-Up

Owner evidence on `case-6ebd0e3a` proved a new same-link accessibility gap after a follow-up/send-again capture. The case status became `FOLLOWUP_SEND_PENDING_MANUAL` with controlled send key `case-6ebd0e3a|f2`, but HumanApproval token validators did not include that status in renderable/reopenable states, so reopening returned an already-decided style page.

5Q11 patched HumanApproval only:

- GET/POST review token validation now treats `SAVED`, `RESPONSE_SENT`, `FOLLOWUP_SEND_PENDING_MANUAL`, `FOLLOWUP_SEND_CAPTURED`, and `MANUAL_SEND_REQUIRED` as renderable until token expiry.
- render preserves approved/sent and manual-send-required banners after follow-up capture.
- duplicate follow-up capture is disabled in manual-send-required state.
- draft-improvement targets now use corrected/effective classification when the owner corrects classification and selects “this classification.”

Production:

- HumanApproval `50d77bbb-546f-4a85-8902-4ead1c3776b4` -> `d3449764-b059-48be-b73a-8a9beae443ea`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q9 Python/PowerShell: `21/21 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`
- 5R-prep Python/PowerShell: `17/17 PASS`
- No Sender execution or Instantly POST was caused by the patch.
