# SL-PHASE-5Q7 AI Source Label and Validation

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q6-thread-and-ai-fallback-repair/20260628-050358`  
**Verdict:** PARTIAL - root cause fixed and production-applied; fresh post-fix live recheck pending  
**Status percentage:** 90%

## 2026-06-28 SL-PHASE-5Q8 Addendum

Fresh post-5Q7 live case `case-c3341a17` proved the accepted AI path worked (`draft_source=ai_supervised`, OpenAI `ok=true`, non-empty draft, Google Chat banner correct), but HumanApproval render failed at node `J. Render Review Form HTML` with `Unexpected identifier 'background'`. Root cause was a 5Q7 renderer escaping defect in the new source/banner block: unescaped `style="..."` and textarea attributes inside JavaScript strings. SL-PHASE-5Q8 patched only HumanApproval node `J`, production-applied HumanApproval `34531128-5ff6-4538-8846-bbbc5888a7a9`, and added 5Q8 harness coverage (`22/22` Python/PowerShell). Owner-authenticated live reopen of `case-c3341a17` remains pending because Codex's render-only GET returned HTTP 401 before workflow execution.

## 2026-06-28 SL-PHASE-5Q9 Addendum

`case-9b9197a4` exposed a blocked-send same-link defect unrelated to AI source labelling: missing `repeat_send_reason_required` was detected internally but hidden in the owner page, and status `BLOCKED_MISSING_VARIABLES` made the same link validate as `ALREADY_DECIDED`. HumanApproval `68f4b543-0004-4677-a95c-ba6768a8523c` now preserves the same token/link, keeps the case editable, shows the exact missing variable and correction steps, and avoids new retry links. 5Q7 labels still pass `17/17` after the 5Q9 production export sync.

## Summary

New post-5Q6 live case `case-f67601bc` proved thread hydration and fallback quality were fixed, but exposed two follow-up defects:

1. Decision rejected a safe numbered-list AI draft as `active policy violation: dense paragraph`.
2. HumanApproval review form displayed the fallback as a normal `AI-assisted draft for human review`, even though the source was `ai_failed_fallback`.

Both defects were traced, patched, harness-proven, and production-applied. No learning-only action, approve/send action, Sender trigger, autonomous activation, Gate 2 work, or VPS access was performed.

## Case Trace

| Workflow | Execution | Started | Evidence |
|---|---:|---|---|
| Intake | `2882` | `2026-06-28T04:25:14.910Z` | Hydrated normally; Instantly email hydration returned HTTP 200 with canonical thread id and RFC message id. |
| HumanApproval create | `2884` | `2026-06-28T04:25:18.869Z` | Created `case-f67601bc`, `INFORMATION_REQUEST / OFFER_EXPLANATION`, `draft_source=ai_failed_fallback`, non-empty policy-aware fallback draft. |
| HumanApproval render | `2886` | `2026-06-28T04:25:42.678Z` | Review form rendered normally, but banner said `AI-assisted draft for human review` despite fallback source. |
| HumanApproval save | `2887` | `2026-06-28T04:27:00.447Z` | Owner used Save only; no send path. |
| HumanApproval reopen | `2888` | `2026-06-28T04:27:05.374Z` | Reopened normally; same misleading banner remained before the 5Q7 patch. |
| Sender | none | n/a | No Sender execution contained `case-f67601bc`; recent Sender executions remained older pre-existing runs. |

Thread hydration:

- Source/from: `hamzahzahid3@gmail.com`
- Sender: `hamzah@onehmzautomation.com`
- Campaign: `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, `HMZ Responder Behaviour Acceptance - Round 1`
- Thread source: canonical Instantly email hydration
- Thread id: present
- Subject: `Re: Capacity Question`
- Reply: setup-process question

## AI Source / Validation

Decision evidence from Intake execution `2882`:

- Provider call attempted: YES
- Provider: `openai`
- Model: `gpt-5.4-mini`
- Provider status: `ok=true`, no provider error
- AI output: present and usable in substance
- Final source: `ai_failed_fallback`
- Fallback reason: `AI_OUTPUT_VALIDATION_FAILED`
- Validation error: `active policy violation: dense paragraph`

Assessment:

The rejection was over-strict. The AI draft answered the setup question first, used a numbered list, avoided validation/proof/case-study/results/pricing/guarantee claims, and placed CTA at the end. Decision D split dense paragraphs only on blank lines, so a numbered-list draft with single newlines could be treated as one dense paragraph.

## Fix Summary

Decision:

- Patched `D. Draft Preparation (Templates / Human Draft)`.
- Dense-paragraph validation now detects list structure and checks max line length separately.
- Safe numbered/bulleted answer-before-CTA drafts are no longer rejected merely because list lines are in one visual block.
- Unsafe proof/pricing/guarantee/customer-results checks are preserved.

HumanApproval:

- Patched `D. Build Google Chat Notification Payload`.
- Patched `J. Render Review Form HTML`.
- Google Chat now distinguishes:
  - `ai_supervised`: AI-generated draft for human review
  - `ai_failed_fallback`: safe fallback draft for human review plus safe reason category
- Review form now distinguishes:
  - normal AI-generated draft;
  - safe fallback draft because AI draft was rejected by validation;
  - provider/config fallback via safe `fallback_reason`.
- Review form now displays draft source and fallback reason without secrets.

## Harness Results

Post-production-sync local harness results:

- 5Q7 Python: `17/17 PASS`
- 5Q7 PowerShell: `17/17 PASS`
- 5Q6 Python: `24/24 PASS`
- 5Q5 Python: `34/34 PASS`
- 5Q4 Python: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`

PowerShell parity was also run pre-apply for 5Q6, 5Q5, 5Q4, 5Q3, 5Q2, and 5R-prep; all passed.

## Production Apply

Production target guard passed before API writes.

Backup directory:

- `backups/sl-phase-5q7-ai-source-label-validation-20260628T043853Z`

| Workflow | Old versionId | New versionId | Active after | Changed nodes |
|---|---|---|---:|---|
| Decision | `676c83ad-ebbd-4dd6-a204-b48245e061bc` | `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` | `true` | `D. Draft Preparation (Templates / Human Draft)` |
| HumanApproval | `4caf621f-cda5-4aca-84a7-e1b521e99c7c` | `4b18ec1b-a821-42a0-bc46-06e7ebe81599` | `true` | `D. Build Google Chat Notification Payload`, `J. Render Review Form HTML` |
| Intake | `abc83e43-9b97-4ca1-ae32-c42599255328` | unchanged | `true` | none |
| Sender | `dfb310f4-901a-4d76-81dc-8f5d4ad13552` | unchanged | `true` | none |
| Proxy | `d61050e6-dbc6-4fec-b404-3aad20a80e84` | unchanged | `true` | none |
| Shadow Evaluator | `ae13bf4e-ee04-438f-9657-3c57183b90a2` | unchanged | `false` | none |

Unexpected drift: NONE.

## Safety Confirmation

- Sender/live send was not triggered.
- Latest Sender executions remained older pre-existing runs: `2762`, `2760`, `2740`, `2233`, `1526`.
- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Live autonomous sending remains disabled.
- Sender still contains `DRY_RUN`; `LIVE_CREDENTIAL_READY=true` was not present.
- `approve_and_send_followup` auto-send remains disabled/not implemented.
- VPS/SSH was not used.

## Remaining Proof

Because Decision validation was patched, use a fresh varied setup reply before learning-only proof:

```text
Could you explain what the setup process would look like before we decide whether a call makes sense?
```

Stop after inspecting the Google Chat card/review form. Do not click `Approved for learning only` or `Approve and send`.
