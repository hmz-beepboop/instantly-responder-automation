# SL-PHASE-5Q11 Review Link Accessibility and Corrected Classification

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Verdict:** PARTIAL - root cause fixed, harness-proven, and production-applied; owner same-link reopen confirmation remains pending  
**Status percentage:** 89%

## Case Trace

Target case: `case-6ebd0e3a`.

Targeted production evidence:

- Current case status: `FOLLOWUP_SEND_PENDING_MANUAL`
- Decision action: `approve_and_send_followup`
- Previous status: `RESPONSE_APPROVED`
- Controlled send key: `case-6ebd0e3a|f2`
- Revision count: `2`
- Repeat send reason recorded: `Prospect requested the email to be sent again.`
- Sender audit/manual-send flag: present
- Token present and unchanged in the case row; token value was not printed.
- Human correction evidence in row: original broad category remained `INFORMATION_REQUEST`; corrected/effective micro intent stored as `BOOKING_REQUEST`.

Recent execution payloads were not available through the API runData response, but workflow metadata and the case row matched the owner-observed terminal page. Latest Sender execution after investigation remained `3141` at `2026-06-28T21:27:20.357Z`, before this production apply; no Sender execution was caused by the patch.

## Root Cause

- **A. sent/follow-up captured state is treated as non-renderable terminal state:** confirmed.
- **B. already-decided guard too broad:** confirmed.
- **C. manual-send-required state not included in renderable states:** confirmed.
- **F. corrected classification not used as effective learning target:** confirmed for checked draft-improvement target classifications.

HumanApproval token validators `H` and `L` allowed `RESPONSE_APPROVED`, `LEARNING_REVISION_APPROVED`, and `BLOCKED_MISSING_VARIABLES`, but not `FOLLOWUP_SEND_PENDING_MANUAL`, `FOLLOWUP_SEND_CAPTURED`, `MANUAL_SEND_REQUIRED`, or `RESPONSE_SENT`. After the follow-up capture, `case-6ebd0e3a` was therefore treated as `ALREADY_DECIDED`.

HumanApproval learning capture already used corrected `effectCat/effectMi` for rule scopes, but preserved submitted draft-improvement target checkboxes from the original rendered classification. If the owner corrected the classification and selected “this classification,” the target list could still point at the original AI classification.

## Fix Summary

Patched HumanApproval only:

- `H. Validate Review Token (GET)`
  - added renderable states: `SAVED`, `RESPONSE_SENT`, `FOLLOWUP_SEND_PENDING_MANUAL`, `FOLLOWUP_SEND_CAPTURED`, `MANUAL_SEND_REQUIRED`.
  - same link renders until token expiry instead of blocking as `ALREADY_DECIDED`.
- `L. Validate & Consume Review Token (POST)`
  - same renderable-state contract as GET.
  - decided/manual states no longer require Sender handoff to reopen/post safe review actions.
- `J. Render Review Form HTML`
  - treats follow-up/manual-send states as sent-style.
  - preserves approved/sent banner.
  - adds manual-send-required banner with repeat-send reason and controlled send key.
  - disables duplicate follow-up capture button after manual-send-required state.
- `N. Process Reviewer Decision`
  - follow-up capture now stores previous status, latest learning fields, latest corrections, `manual_send_required`, and `same_review_link_retry`.
- `SL-P2A. Prepare Phase 1C+2 Capture Data`
  - stores original classification separately.
  - stores corrected/effective classification separately.
  - rewrites “this classification” draft-improvement targets to corrected/effective classification.
  - candidate metadata now includes original classification, corrected/effective classification, target classification used, improvement types, scope, timestamp, status, and precedence metadata.

## Harness Results

- 5Q11 Python: `24/24 PASS`
- 5Q11 PowerShell: `24/24 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q9 Python/PowerShell: `21/21 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`
- 5R-prep idempotency/token Python/PowerShell: `17/17 PASS`

## Production Apply

- Guard passed before API write.
- Backup directory: `backups/sl-phase-5q11-review-link-accessibility-20260628T215136Z`
- HumanApproval `50d77bbb-546f-4a85-8902-4ead1c3776b4` -> `d3449764-b059-48be-b73a-8a9beae443ea`
- Active state preserved: `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Decision unchanged: `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged and inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- No Sender execution or Instantly POST was caused by the apply.

## Next Owner Action

Reopen the same `case-6ebd0e3a` review link once. Confirm the review form renders, the approved/sent banner remains visible, and the manual-send-required banner shows the controlled send key. Stop before clicking any submit button.

## 2026-06-29 5Q12 Follow-Up

Owner reported fresh review accessibility on `case-389ef118` is working perfectly. 5Q12 then removed the redundant improvement-type checkbox section and promoted HumanApproval form-created draft learning to active/effective supervised-drafting rules with source metadata.

Production:

- HumanApproval `d3449764-b059-48be-b73a-8a9beae443ea` -> `f1138daa-8d38-4acf-b0c9-a6a2bef626fe`
- Decision `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` -> `009daf13-58f7-442c-b74b-c43f352620fe`
- Added required metadata columns to `sl_rule_candidates` after schema backup.
- 5Q12 Python/PowerShell: `29/29 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`
- No Sender execution or Instantly POST was caused by the patch.
