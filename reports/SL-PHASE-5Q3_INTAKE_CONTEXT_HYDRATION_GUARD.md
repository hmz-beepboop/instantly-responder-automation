# SL-PHASE-5Q3 Intake Context Hydration Guard

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q2-postfix-live-retest/20260628-002222`  
**Verdict:** PARTIAL - root cause fixed and production-applied; corrected live retest still pending  
**Status percentage:** 80%

## 2026-06-28 SL-PHASE-5Q6 Addendum

SL-PHASE-5Q6 found a new Intake context edge case: `case-f54aff79` had no top-level `thread_id`, and Instantly email hydration returned `404 Email not found`, but `unibox_url` contained `thread_search=thread:<id>`. Intake now maps that alternate stable thread identifier in `C2. Merge Reply Hydration`; genuinely missing thread context remains diagnostic-only. Intake is now `abc83e43-9b97-4ca1-ae32-c42599255328`.

2026-06-28 SL-PHASE-5Q7 addendum: `case-f67601bc` confirmed Intake hydration is correct post-5Q6. Instantly email hydration returned HTTP 200 and canonical thread/message IDs; no Intake patch was needed.

2026-06-28 SL-PHASE-5Q8 addendum: `case-c3341a17` confirmed the Intake/Decision path remained hydrated and accepted AI output, but HumanApproval node `J` failed to compile due to unescaped 5Q7 banner HTML attributes. HumanApproval-only production patch `34531128-5ff6-4538-8846-bbbc5888a7a9` fixed the renderer; owner-authenticated live reopen remains pending.

## Bad Case Summary

`case-ed174cd6` is not a valid self-improvement proof case.

Observed owner-facing failure:

- Google Chat showed `From: UNKNOWN`, `Sender: ? <?>`, `Broad category: UNKNOWN`, `Micro intent: N/A`, blank excerpt, and no draft policy/source.
- Review form showed blank subject, incoming reply, and reply text with `UNKNOWN` / `not set` classification state.
- Draft-improvement controls were visible, but there was no valid draft/context to review.

## Execution Trace

Read-only n8n API trace after production guard:

| Workflow | Execution | Started | Evidence |
|---|---:|---|---|
| Intake | `2820` | `2026-06-28T01:44:14.290Z` | Webhook payload contained campaign ID/name, reply subject, reply body, lead email, email ID, hydrated Instantly email, sender/from email, and thread ID. |
| Decision | `2821` | `2026-06-28T01:44:14.608Z` | A-C received usable context and classified as `INFORMATION_REQUEST`; D returned only `error: missing /`; E output validation failed with 26 missing decision/draft fields. |
| HumanApproval | `2822` | `2026-06-28T01:44:14.845Z` | Built `case-ed174cd6` from the broken Decision fallback: `UNKNOWN_INTAKE`, `UNKNOWN` category, blank draft, blank reply fields. |
| HumanApproval form GET | `2823` | `2026-06-28T01:44:28.993Z` | Rendered blank/UNKNOWN review form for `case-ed174cd6`. |
| Sender | none | n/a | No Sender execution was linked to this case. |

## Root Cause

**Workflow defect**, not test setup.

The original incoming payload was usable. The first missing-context point was Decision node `D. Draft Preparation (Templates / Human Draft)`. The SL-PHASE-5Q2 active-policy validation code had malformed JavaScript literals:

- word-boundary regexes had been serialized as backspace characters;
- the paragraph split regex had a real newline inside the regex literal;
- the active-guidance string block had real line breaks inside single-quoted JavaScript strings.

That caused Decision D to emit `error: missing /`, after which output validation correctly failed closed. HumanApproval then incorrectly turned that failed output into a normal-looking blank review case instead of a diagnostic blocked case.

## Files Inspected

- `OPERATION_HANDOFF.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `docs/HMZ_PRODUCTION_TARGET_GUARD.md`
- `AGENTS.md`
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- n8n executions `2820`, `2821`, `2822`, `2823`

## Files Changed

- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `workflows/disabled_autonomous_shadow_evaluator.json` (post-export sync only; `active=false`)
- `scripts/SL-PHASE-5Q3-intake-context-hydration-guard.py`
- `scripts/SL-PHASE-5Q3-intake-context-hydration-guard.ps1`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

## Fix Summary

- Fixed Decision D active-policy regex/string serialization so draft preparation no longer throws `missing /`.
- Added HumanApproval missing-context diagnostic guard:
  - missing sender/from, sender account, subject, thread, reply body, draft, classification, or micro-intent marks a diagnostic case;
  - diagnostic cases use `CONTEXT_MISSING_BLOCKED` / `DIAGNOSTIC_CONTEXT_MISSING`;
  - Google Chat says invalid/missing context and lists missing fields;
  - review form renders diagnostic-only instructions and returns before normal approve/save/learning buttons;
  - submit processing blocks diagnostic and persisted blank/UNKNOWN rows;
  - SL-P2A emits no rule candidates for diagnostic blank/UNKNOWN rows;
  - Sender remains reachable only from `final_action === 'approve'`.

## Harness Results

Post-apply, synced production exports:

- 5Q3 Python: `30/30 PASS, 0 FAIL`
- 5Q3 PowerShell: `30/30 PASS, 0 FAIL`
- 5Q2 Python: `27/27 PASS, 0 FAIL`
- 5Q2 PowerShell: `27/27 PASS, 0 FAIL`
- 5R-prep Python: `17/17 PASS, 0 FAIL`
- 5R-prep PowerShell: `17/17 PASS, 0 FAIL`
- Legacy 5Q Python: `41/41 PASS, 0 FAIL`
- Legacy 5Q PowerShell: `41/41 PASS, 0 FAIL`

## Production Apply Status

- Guard passed: YES
- n8n API used: YES, scoped GET/PUT workflow operations only
- Backup directories:
  - `backups/sl-phase-5q3-context-guard-apply-20260628T021021Z`
  - `backups/sl-phase-5q3-persisted-row-guard-apply-20260628T021242Z`
- Decision changed only: `D. Draft Preparation (Templates / Human Draft)`
- HumanApproval changed only: `A. Build Review Case Record`, `D. Build Google Chat Notification Payload`, `J. Render Review Form HTML`, `N. Process Reviewer Decision`, `SL-P2A. Prepare Phase 1C+2 Capture Data`

| Workflow | Old versionId | New versionId | Active after |
|---|---|---:|---:|
| Decision | `a7d7c4cf-bc33-460e-95a4-63070490a9cf` | `a4dab823-a540-48e8-8df6-514eca5d060a` | `true` |
| HumanApproval | `0ee1b410-94e1-4ffc-bcfe-c722af783839` | `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609` | `true` |
| Sender | `dfb310f4-901a-4d76-81dc-8f5d4ad13552` | unchanged | `true` |
| Proxy | `d61050e6-dbc6-4fec-b404-3aad20a80e84` | unchanged | `true` |
| Shadow Evaluator | `ae13bf4e-ee04-438f-9657-3c57183b90a2` | unchanged | `false` |

Unexpected drift: NONE.

## Corrected Human Test Instructions

Ignore `case-ed174cd6`; it was created by a workflow defect and is not valid self-improvement evidence.

Next Human Action 1:

1. Use the same seeded owned/test prospect already present in the active Instantly campaign thread.
2. Reply in the existing Instantly campaign email thread, not as a new standalone email and not by forwarding.
3. Send exactly:

```text
Before we book anything, can you explain what your setup actually includes?
```

4. Wait for the Google Chat review card.
5. Confirm the card is hydrated before opening the form:
   - From is not `UNKNOWN`;
   - Sender is not `? <?>`;
   - Broad category is not `UNKNOWN`;
   - Micro intent is set;
   - Reply excerpt is nonblank.
6. Open the review form and stop before approving/sending.

If any of those hydration checks fail, stop and report the case ID only.

## Remaining Risks

- 2026-06-28 SL-PHASE-5Q4 follow-up: corrected hydrated Human Action 1 produced `case-535d430a` with hydrated Google Chat card and non-empty `ai_failed_fallback` draft, but HumanApproval review rendering failed at node `J. Render Review Form HTML` because of a malformed diagnostic HTML string (`Unexpected identifier 'background'`). This was fixed and production-applied in HumanApproval versionId `542f4159-fb6b-4dc4-9dda-f97657fbf7ac`; see `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`.
- 2026-06-28 SL-PHASE-5Q5 follow-up: Save/reopen persistence failed for `case-535d430a`; render was loading original state over saved state. This was fixed and production-applied in HumanApproval versionId `4caf621f-cda5-4aca-84a7-e1b521e99c7c`; see `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`.
- 2026-06-28 corrected retest Stage 1 passed: production guard passed; HumanApproval, Decision, Sender, Proxy, and Shadow versionIds match the expected post-5Q3 state; Shadow remains `active=false`; Sender remains `DRY_RUN=true` with no live campaigns and `LIVE_CREDENTIAL_READY=false`; 5Q3 Python/PowerShell harnesses both returned `30/30 PASS`; 5Q2 Python/PowerShell harnesses both returned `27/27 PASS`.
- Corrected hydrated owner action produced `case-535d430a`, but review-form rendering failed before save/reopen proof. Save/reopen proof, learning-only proof, later similar draft proof, and leakage control evidence remain pending.
- Corrected live retest is still pending. Save/reopen, learning-only/candidate activation, later similar draft effect, and leakage control are not yet live-proven after this fix.
- Optional live idempotency/send proof remains pending and should not be attempted until the review-form/draft-behaviour checks pass.
- `case-ed174cd6` should not be used for self-improvement proof.

## Safety Confirmation

- Sender was not triggered by this run.
- Instantly API was not called by this run.
- Google Chat webhook was not called directly by this run.
- VPS/SSH not used.
- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Live autonomous sending remains disabled.
- `approve_and_send_followup` auto-send remains disabled/pending full Sender audit.
