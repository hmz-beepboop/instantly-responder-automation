# SL-PHASE-5Q2 Behavioural Effectiveness, Review UX, and Idempotency Fix

**Date:** 2026-06-27  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q2-idempotency-behavioural-fix-20260627-224147`  
**Verdict:** SUPERSEDED / PARTIAL - production patch applied and locally/post-export harness-proven, but post-fix live retest exposed a Decision D malformed-regex regression that created blank/UNKNOWN `case-ed174cd6`. See `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`.  
**Status percentage:** 80% after SL-PHASE-5Q3 production fix; corrected live retest still pending

## 2026-06-28 SL-PHASE-5Q6 Addendum

Decision D now has policy-aware fallback behaviour for `ai_failed_fallback`: active behavioural guidance is used for fallback text as well as normal AI drafts, setup questions answer before CTA, validation/proof language is avoided unless asked, and safe `fallback_reason` metadata is emitted. Decision is now `676c83ad-ebbd-4dd6-a204-b48245e061bc`; Sender/idempotency paths were not changed.

2026-06-28 SL-PHASE-5Q7 addendum: Decision dense-paragraph validation was too strict for safe numbered-list AI drafts. It now treats list-structured drafts by max line length instead of rejecting the whole list as one dense paragraph. Unsafe proof/pricing/guarantee/customer-results rejection remains preserved. Decision is now `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`.

2026-06-28 SL-PHASE-5Q8 addendum: The first accepted AI live retest after 5Q7 (`case-c3341a17`) generated the expected supervised draft and Chat labels, then exposed a HumanApproval render escaping regression in node `J`. 5Q8 patched only HumanApproval node `J`; review UX, Save, learning-only, duplicate/token safety, and Sender idempotency harnesses all still pass. HumanApproval is now `34531128-5ff6-4538-8846-bbbc5888a7a9`.

2026-06-28 SL-PHASE-5Q9 addendum: `case-9b9197a4` exposed a second blocked-submit UX defect. Missing `repeat_send_reason_required` was stored internally but omitted from the blocked page, and `BLOCKED_MISSING_VARIABLES` locked the same review link as `ALREADY_DECIDED` despite token stability. HumanApproval now preserves same-link retry, keeps blocked cases editable, states that no reply was sent, and names exact correction steps. HumanApproval is now `68f4b543-0004-4677-a95c-ba6768a8523c`; 5R-prep token/idempotency harness was updated to the safer same-link invariant and passes `17/17`.

## 2026-06-28 SL-PHASE-5Q3 Follow-up

The first post-fix live retest produced invalid `case-ed174cd6`: Google Chat and review form showed `UNKNOWN`/blank sender, classification, incoming reply, and draft fields. Read-only n8n trace proved the incoming Instantly payload was hydrated, but Decision execution `2821` failed at `D. Draft Preparation (Templates / Human Draft)` with `error: missing /`.

SL-PHASE-5Q3 fixed Decision D malformed JavaScript regex/string literals and added a HumanApproval missing-context diagnostic guard so blank/UNKNOWN rows cannot proceed to normal approve/send or learning-candidate creation. Production now has Decision `a4dab823-a540-48e8-8df6-514eca5d060a` and HumanApproval `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609`. Corrected live self-improvement proof remains pending.

## Live Proof Failure Summary

- SL-PHASE-5Q production apply and candidate activation worked.
- Active behavioural candidate `27293ea8-bc4c-444b-be08-3623c9bb942b` from `case-66062eda` was available in later Decision execution `2750`.
- Later case `case-a3e7b1d2` was correctly classified as `INFORMATION_REQUEST / OFFER_EXPLANATION`, but the draft still had a malformed opener (`Absolutely, .`), one dense paragraph, and validation/public-example language when the prospect only asked about setup.
- Owner-approved edited send succeeded: HumanApproval `2759`, Sender `2760`, Instantly POST HTTP 200, owner confirmed edited email present.
- Duplicate submit then ran HumanApproval `2761` and Sender `2762`; Sender correctly blocked as `SEND_OWNERSHIP_NOT_ACQUIRED` with no second Instantly POST, but HumanApproval incorrectly treated that as recoverable, set `RETRY_NEEDED`, issued a new token, sent a false retry message, and made the original review link fail as `WRONG_TOKEN / HTTP 410`.

## Root Causes

**Behavioural effect failure**
- Active policy text was available to Decision, but it was advisory rather than mandatory.
- The built-in `OFFER_EXPLANATION` instruction contradicted the learned rule by telling the model to state validation stage.
- The final direct AI prompt lacked a hard active-policy self-check.
- Post-validation did not reject obvious active-policy violations: malformed acknowledgement, dense paragraph, or validation/proof language when the prospect had not asked for proof.

**Review UX / preservation**
- Improvement scope and type were single-select controls.
- `Style` was not available as an explicit improvement type.
- Separate reason/future-behaviour fields duplicated intent and made reviewer input harder to preserve.
- There was no save-only action for draft and learning inputs before approval.
- `approve_learning_only` was only exposed on already-sent reopened cases, not normal unsent cases.

**Duplicate / retry / token defect**
- Sender idempotency lock worked: duplicate submit did not create a second Instantly POST.
- HumanApproval `R0` only checked `terminal.details` for nonrecoverable causes and ignored `terminal.reason`, `prior_state`, and failed send-state gates.
- `SEND_OWNERSHIP_NOT_ACQUIRED` therefore went down the recoverable retry-token path.
- Retry-token generation defaulted to an empty base URL when runtime config was absent, allowing relative retry links.
- Retry messaging falsely stated the prospect did not receive a reply, even when a prior Sender execution had returned HTTP 200.

## Files Inspected

- `OPERATION_HANDOFF.md`
- `CLAUDE.md`
- `AGENTS.md`
- `README.md`
- `docs/HMZ_PRODUCTION_TARGET_GUARD.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `workflows/03_reply_sender_validation.json`
- Production read-only exports for HumanApproval, Decision, Sender, Proxy, and Shadow Evaluator

## Files Changed

- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `workflows/disabled_autonomous_shadow_evaluator.json` (synced post-export only; active remains false)
- `scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.py`
- `scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.ps1`
- `scripts/SL-PHASE-5R-prep-send-idempotency-token-safety.py`
- `scripts/SL-PHASE-5R-prep-send-idempotency-token-safety.ps1`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

## Implementation Summary

- Decision active/effective behavioural policies are now injected as **mandatory active drafting constraints** in the final direct AI prompt.
- Newer active policies override older contradictory policies within the same scope key.
- `OFFER_EXPLANATION` no longer tells the model to mention validation stage by default.
- The prompt now includes a final self-check for active policy compliance, malformed openers, proof/validation mentions, setup-answer formatting, and CTA placement.
- AI post-validation now rejects active-policy violations for validation/proof mention without proof request, dense paragraph, and malformed acknowledgements like `Absolutely, .`.
- Review form now has a combined learning field: `Why did you make this change, and what should the system do next time?`
- Scope and improvement type are multi-select checkbox controls; `Style` is included.
- Save action persists draft and learning inputs without sending and without creating a candidate.
- Approval and blocked-approval paths preserve latest draft-learning fields before any send handoff.
- `Approved for learning only` is available on the unsent review form and remains no-send.
- Duplicate ownership / prior terminal send states are nonrecoverable and do not issue retry tokens.
- Genuine retry-token generation now has a full production URL fallback.
- Retry/block messaging no longer claims the prospect did not receive a reply when that is not proven.

## Harness Results

Pre-apply and post-export results:

- Existing 5Q Python harness: `41/41 PASS, 0 FAIL`
- Existing 5Q PowerShell harness: `41/41 PASS, 0 FAIL`
- New 5Q2 Python harness: `27/27 PASS, 0 FAIL`
- New 5Q2 PowerShell harness: `27/27 PASS, 0 FAIL`
- New 5R-prep Python harness: `17/17 PASS, 0 FAIL`
- New 5R-prep PowerShell harness: `17/17 PASS, 0 FAIL`

## Production Apply Status

- Guard passed: YES
- n8n API used: YES, scoped GET/PUT workflow operations only
- Live prospect/send tests run: NO
- Sender triggered by this run: NO
- Instantly API called by this run: NO
- Google Chat webhook called by this run: NO
- VPS SSH used: NO
- Backup directory: `backups/sl-phase-5q2-production-apply-20260627T225600Z`

| Workflow | ID | Old versionId | New versionId | Active after |
|---|---|---|---:|
| HumanApproval | `9aPrt92jFhoYFxbs` | `07895ef4-f177-41a0-954b-dcb67690a8ee` | `0ee1b410-94e1-4ffc-bcfe-c722af783839` | `true` |
| Decision | `tgYmY97CG4Bm8snI` | `d1bc10e9-1a41-4cae-89cf-9ea38cdce2b0` | `a7d7c4cf-bc33-460e-95a4-63070490a9cf` | `true` |
| Sender | `ePS5uBBxKxhFCYgU` | `dfb310f4-901a-4d76-81dc-8f5d4ad13552` | unchanged | `true` |
| Proxy | `seB6ZmlyomhC4QWU` | `d61050e6-dbc6-4fec-b404-3aad20a80e84` | unchanged | `true` |
| Shadow Evaluator | `aHzLtQiv6G8h1bqD` | `ae13bf4e-ee04-438f-9657-3c57183b90a2` | unchanged | `false` |

Unexpected drift: NONE. The apply payload changed only:

- HumanApproval: `J`, `L`, `N`, `SL-P2A`, `R0`, `R-GenToken`, `R3`, `R5`, `R5b`
- Decision: `D`

## Remaining Manual Tests

- 2026-06-28 SL-PHASE-5Q5 fixed Save/reopen persistence for unsent `IN_REVIEW` cases. Save submission for `case-535d430a` received edited draft and learning fields, persisted them in `final_reply_text` and `decision_payload`, but render preferred original `draft_text`. HumanApproval is now `4caf621f-cda5-4aca-84a7-e1b521e99c7c`; 5Q5 Python/PowerShell `34/34 PASS`.
- 2026-06-28 SL-PHASE-5Q4 fixed the HumanApproval node J render syntax defect exposed by hydrated `case-535d430a`. HumanApproval is now `542f4159-fb6b-4dc4-9dda-f97657fbf7ac`; 5Q4 Python/PowerShell `26/26 PASS`; 5Q3 `30/30 PASS`; 5Q2 `27/27 PASS`; 5R-prep `17/17 PASS`. Owner must reopen the current review link before save/reopen proof resumes.
- 2026-06-28 corrected retest Stage 1: production guard and read-only workflow metadata verification passed. HumanApproval is `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609`; Decision is `a4dab823-a540-48e8-8df6-514eca5d060a`; Sender is `dfb310f4-901a-4d76-81dc-8f5d4ad13552`; Proxy is `d61050e6-dbc6-4fec-b404-3aad20a80e84`; Shadow Evaluator is `ae13bf4e-ee04-438f-9657-3c57183b90a2` and `active=false`.
- 2026-06-28 corrected retest harnesses: 5Q3 Python/PowerShell `30/30 PASS`; 5Q2 Python/PowerShell `27/27 PASS`. 5R-prep was not rerun because optional send/idempotency proof was not selected.
- Open the next review form and stop before sending.
- Confirm the combined field, multi-select scope/type, `Style`, Save, and `Approved for learning only` buttons are visible.
- Use Save, reopen the same review URL, and confirm edited draft plus learning inputs persist.
- Generate one later similar setup-question case and verify draft behaviour at review stage only.
- Do not click approve/send for live retest until the owner explicitly accepts that production idempotency patch is installed and wants a send test.

## Safety Confirmation

- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Live autonomous sending remains disabled.
- `approve_and_send_followup` auto-send remains disabled/pending manual.
- Sender duplicate lock was not weakened.
- No live Sender execution was triggered by this run.
- No old Decision active rule set was re-applied.
