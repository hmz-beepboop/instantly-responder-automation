# SL-PHASE-5Q Self-Improvement Behavioural Closure

**Date:** 2026-06-27  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q/20260627-025313`  
**Verdict:** SUPERSEDED / PARTIAL - guarded SL-PHASE-5Q production apply succeeded, but live behavioural effect was insufficient, duplicate retry/token handling was unsafe, and the first 5Q2 retest exposed blank/UNKNOWN case hydration from a Decision D malformed-regex regression. See `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md` and `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`.  
**Status percentage:** 80% after SL-PHASE-5Q3 production fix; corrected post-fix live retest still pending

## 2026-06-28 SL-PHASE-5Q6 Follow-up

SL-PHASE-5Q6 traced and repaired the post-5Q5 blockers:

- `case-f54aff79` missed `thread_id` because Instantly email hydration returned `404`, while the alternate Unibox query `thread_search=thread:<id>` was not mapped.
- Hydrated cases using `ai_failed_fallback` were not provider outages: OpenAI returned an AI draft, but Decision D post-validation rejected it and fell back to deterministic text.
- Fallback text is now policy-aware and improvement-aware for setup questions, with safe fallback reason metadata.

Production apply succeeded for Intake `abc83e43-9b97-4ca1-ae32-c42599255328` and Decision `676c83ad-ebbd-4dd6-a204-b48245e061bc`. HumanApproval, Sender, Proxy, and Shadow Evaluator were unchanged. Overall verdict remains PARTIAL because the new post-5Q6 live review-only proof is still pending.

2026-06-28 SL-PHASE-5Q7 follow-up: `case-f67601bc` proved hydration and policy-aware fallback quality, but exposed over-strict AI draft validation and misleading fallback labelling. Decision now accepts safe structured list drafts and HumanApproval distinguishes AI-generated drafts from validation/provider fallback drafts. Production is Decision `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` and HumanApproval `4b18ec1b-a821-42a0-bc46-06e7ebe81599`. Fresh post-5Q7 live review-only proof remains pending.

2026-06-28 SL-PHASE-5Q8 follow-up: Fresh post-5Q7 live case `case-c3341a17` proved the accepted AI-generated draft path (`ai_supervised`) but review rendering failed at HumanApproval node `J` because the 5Q7 banner/source HTML inserted unescaped JavaScript string quotes. 5Q8 patched only node `J`, production-applied HumanApproval `34531128-5ff6-4538-8846-bbbc5888a7a9`, and added 5Q8 render regression harness coverage (`22/22` Python/PowerShell). Owner-authenticated live reopen remains pending, so the overall verdict remains PARTIAL.

## 2026-06-28 SL-PHASE-5Q3 Follow-up

Post-5Q2 live retest created invalid `case-ed174cd6` with blank/UNKNOWN sender, subject, reply, classification, and draft context. n8n trace showed the original Intake payload was valid and hydrated, but Decision execution `2821` failed in node D with `error: missing /` before HumanApproval built a blank fallback review case.

SL-PHASE-5Q3 production fix:

- Decision `a7d7c4cf-bc33-460e-95a4-63070490a9cf` -> `a4dab823-a540-48e8-8df6-514eca5d060a`
- HumanApproval `0ee1b410-94e1-4ffc-bcfe-c722af783839` -> `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow Evaluator unchanged `active=false`

The corrected live proof must restart with a newly hydrated review case. Do not use `case-ed174cd6` as self-improvement evidence.

2026-06-28 corrected retest Stage 1 was completed by Codex on branch `agent/codex/phase-5q3-corrected-live-retest/20260628-032641`: production guard passed, workflow versionIds matched the expected post-5Q3 state, Shadow Evaluator remained `active=false`, Sender remained `DRY_RUN=true` with no live campaigns and `LIVE_CREDENTIAL_READY=false`, and the 5Q3 plus 5Q2 Python/PowerShell harnesses passed. No corrected hydrated live source case has been created yet, so the verdict remains PARTIAL at 80%.

2026-06-28 SL-PHASE-5Q4 follow-up: corrected hydrated case `case-535d430a` proved the Intake/Decision/HumanApproval create path could build a hydrated Google Chat card and persisted fallback draft, but review rendering failed in HumanApproval node `J. Render Review Form HTML` with `Unexpected identifier 'background'`. The issue was a malformed escaped quote in the 5Q3 diagnostic HTML string, not missing context or `ai_failed_fallback`. HumanApproval was patched and production-applied to versionId `542f4159-fb6b-4dc4-9dda-f97657fbf7ac`; live reopen verification is pending, so status is 82% PARTIAL.

2026-06-28 SL-PHASE-5Q5 follow-up: after render was fixed, Save/reopen failed for `case-535d430a`. n8n execution evidence showed Save received the edited draft and learning fields and persisted them in `final_reply_text` / `decision_payload`, but node J reloaded original `draft_text` for unsent cases. HumanApproval was patched and production-applied to versionId `4caf621f-cda5-4aca-84a7-e1b521e99c7c`; live save/reopen recheck remains pending, so status is 84% PARTIAL.

## 2026-06-27 SL-PHASE-5Q2 Follow-up

SL-PHASE-5Q live proof is marked failed/insufficient for behavioural effect. The later similar case `case-a3e7b1d2` proved active policy availability but not material draft improvement. A separate duplicate submit also exposed unsafe HumanApproval retry-token mutation after a successful send.

Follow-up fix report:

- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`

SL-PHASE-5Q2 patched Decision behavioural enforcement, review-form save/multi-select UX, and HumanApproval duplicate/retry/token safety. Production apply succeeded with HumanApproval versionId `0ee1b410-94e1-4ffc-bcfe-c722af783839` and Decision versionId `a7d7c4cf-bc33-460e-95a4-63070490a9cf`. Post-fix live retest is still pending, so the overall verdict remains PARTIAL, not COMPLETE.

---

## 2026-06-27 Live Owner Proof - Global Candidate Activation

**Result:** Owner approved activation of the live source-case behavioural candidate.

Source case and candidate:

- Source case: `case-66062eda`
- HumanApproval submit execution: `2739`
- Sender execution from owner `approve`: `2740`
- Candidate/rule ID: `27293ea8-bc4c-444b-be08-3623c9bb942b`
- Candidate source event: `7c96a99f-4c06-47f3-990e-20b1d9855159`
- Candidate status before activation: `proposed_shadow`
- Candidate activation scope: `global_draft_policy` / `all_ai_drafts`

Captured learning:

- Start setup-question drafts with a natural acknowledgement.
- Answer the setup question in short paragraphs before any CTA.
- Do not mention validation unless the prospect asks for proof, case studies, or maturity.

Activation apply:

| Workflow | ID | Active before | Active after | Old versionId | New versionId |
|---|---|---:|---:|---|---|
| HMZ - Reply Decision Engine - Validation | `tgYmY97CG4Bm8snI` | `true` | `true` | `646fe558-01b1-4e4b-8b84-bb4866bcbb91` | `d1bc10e9-1a41-4cae-89cf-9ea38cdce2b0` |
| HMZ Autonomous Shadow Evaluator [DISABLED] | `aHzLtQiv6G8h1bqD` | `false` | `false` | `ae13bf4e-ee04-438f-9657-3c57183b90a2` | `ae13bf4e-ee04-438f-9657-3c57183b90a2` |

Safety checks:

- Exact production guard passed before API operations.
- Backups/payloads: `backups/sl-phase-5q-live-activate-global-20260627T212709Z`
- Decision node D only was changed.
- Existing Decision active rule IDs remained present exactly once.
- No old Decision active-rule set was re-applied.
- Shadow Evaluator remains `active=false`.
- Python harness after activation: `41/41 PASS, 0 FAIL`
- JSON parse after activation: PASS

Remaining proof:

- Send a later similar setup-question case and verify the active global candidate affects the draft.
- Run unrelated leakage checks, especially pricing, not-now, unsubscribe, and ambiguous/detail cases.

---

## 2026-06-27 Live Owner Proof - Later Similar Setup Case

**Result:** PARTIAL / FAIL for behavioural effect.

Later similar reply:

- Sent by owner around 2026-06-27 22:41 BST.
- Decision execution: `2750`
- HumanApproval execution: `2751`
- New review case: `case-a3e7b1d2`
- Classification: `INFORMATION_REQUEST` / `OFFER_EXPLANATION`
- Draft source/status: `ai_supervised` / `DRAFT_PENDING_REVIEW`
- Sender execution: none
- Shadow Evaluator execution: none

Decision active-policy evidence:

- Decision execution `2750` ran after Decision versionId `d1bc10e9-1a41-4cae-89cf-9ea38cdce2b0` was applied.
- Execution workflow data contained active behavioural candidate `27293ea8-bc4c-444b-be08-3623c9bb942b`.
- Execution workflow data contained the behavioural guidance block and instruction text:
  - start with a natural acknowledgement;
  - answer in short paragraphs before CTA;
  - do not mention validation unless proof/case studies/maturity is asked.
- Direct AI prompt body is not exposed in n8n execution data, so prompt-string consumption cannot be proven directly from logs; it is inferred from Decision D running with the active policy code present.

Observed draft:

```text
Absolutely, . Our setup is a short capacity-aligned outbound workflow: we map your target accounts, define the message and routing, then run a controlled outreach sequence so the team only handles conversations that fit your capacity. We are still validating this approach and do not yet have public customer examples, but I can walk you through the setup on a 10-minute call here: [booking link].

Hamza
```

Behavioural assessment:

- Natural acknowledgement: PARTIAL yes (`Absolutely, .` but malformed punctuation/name handling).
- Short paragraphs before CTA: FAIL / weak, still one dense main paragraph.
- Avoid validation mention unless asked for proof/case studies/maturity: FAIL, draft still says validation/public examples.
- Later similar behavioural effect: PARTIAL at best, not a pass.

Conclusion:

- Source learning capture and active policy availability are proven.
- Later similar draft effect is insufficient. The policy either was not strongly consumed by the model or the model ignored material parts of the guidance.
- Continue with no-send review/edit evidence collection; do not mark SL-PHASE-5Q complete.

---

## 2026-06-27 Live Owner Proof - Edited Approval Duplicate/Retry Block

**Result:** Owner-approved edited reply appears to have sent successfully, but a second duplicate submit immediately afterward produced a misleading blocked/retry page.

Owner action:

- Owner clicked `Approved and send` for `case-a3e7b1d2` around 2026-06-27 23:07 BST.
- Owner reported the UI said the send was blocked and claimed a new link was sent, but no usable new link appeared.

n8n evidence:

- Exact production guard passed before read-only n8n API checks.
- HumanApproval execution `2759`: success, started `2026-06-27T22:07:31.878Z`.
- Sender execution `2760`: success, started `2026-06-27T22:07:32.099Z`.
- Sender node `Q. POST Reply to Instantly (Gated)` returned HTTP `200`.
- Sender node `X2. Build SENT Terminal Result` produced a sent terminal path.
- Sender node `X. Persist SENT Result (hmz-send-state)` hit `409 UNKNOWN_STATE`, matching the earlier source-case post-send persistence issue.
- HumanApproval execution `2761`: success, started `2026-06-27T22:07:35.098Z`, a second submit for the same case.
- Sender execution `2762`: success, started `2026-06-27T22:07:35.291Z`, blocked as duplicate/rerun with `SEND_OWNERSHIP_NOT_ACQUIRED`; it did not POST to Instantly.
- HumanApproval marked the duplicate block as recoverable and set case status to `RETRY_NEEDED`.
- Retry Chat webhook node `R4. POST Retry Chat Webhook` did not error and received a Google Chat message object back.
- Retry notification text incorrectly stated that the prospect did not receive a reply, even though the preceding Sender execution received HTTP `200`.
- Retry notification generated a relative review path rather than a full production review URL.
- HumanApproval render execution `2763` returned a token error for `case-a3e7b1d2` with `WRONG_TOKEN` / HTTP `410`.
- Follow-up diagnosis: the successful approval path used the original review token, then the duplicate retry path updated the case to `RETRY_NEEDED` with a different token. Reopening the original/same review form therefore failed token validation as `WRONG_TOKEN`.

Assessment:

- This is not evidence that the first owner-approved edited reply failed to send.
- It is evidence that the duplicate/rerun handling and retry notification path is misleading after an already-successful send.
- This belongs in SL-PHASE-5R Sender idempotency/retry handling, not in the 5Q behavioural-learning patch.

Immediate safety instruction:

- Do not click approve/send again for `case-a3e7b1d2`.
- Do not use the generated retry path for this case.
- Do not expect the original review form link for this case to work after the duplicate retry mutation.
- Confirm in Instantly or the recipient mailbox whether the edited reply sent at approximately `2026-06-27T22:07:34Z`.
- Pause further live send clicks until the owner explicitly accepts this risk or SL-PHASE-5R is completed.

---

## 2026-06-27 Guarded Production Apply / Verification

**Result:** PARTIAL. Production HumanApproval and Decision were exported, backed up, compared, patched with only SL-PHASE-5Q deltas, re-exported, and verified. Live owner proof was not executed.

Local proof before production:

- Python harness: `41/41 PASS, 0 FAIL`
- PowerShell harness: `41/41 PASS, 0 FAIL`
- JSON parse: PASS for HumanApproval, Decision, and disabled Shadow Evaluator

Tooling/env:

- `pwsh`, `python3`, `bash`, and `curl` available
- `node` and `jq` unavailable
- `N8N_BASE_URL` and `N8N_API_KEY` present; values not printed
- `N8N_BASE_URL` was the production UI base, so the documented production API path `/api/v1` was derived from that env value after the exact guard passed

Production guard:

```bash
pwsh -File ./scripts/assert-hmz-production-target.ps1
```

Result: PASS. Production target confirmed.

Production backup/export:

- Backup directory: `backups/sl-phase-5q-production-apply-20260627T044425Z`
- HumanApproval exported/backed up: YES
- Decision exported/backed up: YES
- Shadow Evaluator metadata/status exported: YES

Production workflow apply:

| Workflow | ID | Active before | Active after | Old versionId | New versionId |
|---|---|---:|---:|---|---|
| HMZ - Reply Human Approval - Validation | `9aPrt92jFhoYFxbs` | `true` | `true` | `9c71882f-a096-48a9-861a-37e5424035ae` | `07895ef4-f177-41a0-954b-dcb67690a8ee` |
| HMZ - Reply Decision Engine - Validation | `tgYmY97CG4Bm8snI` | `true` | `true` | `85f51eb4-bf8f-4d17-9883-52d7c2f11225` | `646fe558-01b1-4e4b-8b84-bb4866bcbb91` |
| HMZ Autonomous Shadow Evaluator [DISABLED] | `aHzLtQiv6G8h1bqD` | `false` | `false` | `ae13bf4e-ee04-438f-9657-3c57183b90a2` | `ae13bf4e-ee04-438f-9657-3c57183b90a2` |

Comparison and safety result:

- Production workflow identities matched expected HumanApproval and Decision IDs/names.
- Local Decision export was **not safe to apply as-is**: it included unrelated Decision B/C drift and would have removed existing `ACTIVE_RULE_GUIDANCE` plus the `AI_COMMERCIAL_SUPERVISED` path.
- Applied payloads were generated from current production exports, not by uploading the unsafe local Decision file wholesale.
- HumanApproval payload changed only:
  - `J. Render Review Form HTML`
  - `L. Validate & Consume Review Token (POST)`
  - `N. Process Reviewer Decision`
  - `SL-P2A. Prepare Phase 1C+2 Capture Data`
- Decision payload changed only:
  - `D. Draft Preparation (Templates / Human Draft)`
- Decision B and C were verified unchanged post-apply.
- Existing active rule IDs remained present exactly once; no duplicate active rules were introduced.
- `ACTIVE_BEHAVIOURAL_POLICIES` remains empty by default.
- Decision now consumes active/effective behavioural guidance when such owner-approved policies exist.
- Existing active rule guidance remains appended to the AI prompt.
- `AI_COMMERCIAL_SUPERVISED` remains preserved.
- `approve_and_send_followup` remains `FOLLOWUP_SEND_PENDING_MANUAL` with `sender_audit_required`.

Post-apply export checks:

- Export-based assertions: `22/22 PASS, 0 FAIL`
- Local Python harness against post-apply exports: `41/41 PASS, 0 FAIL`
- Local PowerShell harness against post-apply exports: `41/41 PASS, 0 FAIL`
- JSON parse against post-apply exports: PASS for HumanApproval, Decision, and Shadow Evaluator

Autonomous/Sender safety:

- Shadow Evaluator active: `false`
- Gate 2 approved/enabled: NO
- Live autonomous sending enabled: NO
- Sender workflow touched: NO
- Sender triggered: NO
- Instantly API used: NO
- Google Chat webhook used: NO
- VPS SSH used: NO
- Live email sent: NO

Live proof:

- Varied proof packet remains available: `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- Live owner tests executed: NO
- case-759e58d7 -> case-d099e6f3 is explained by the missing production bridge and is now production-patched, but live behavioural proof remains pending.

---

## 2026-06-27 Re-Verification / Production Apply Attempt

**Result:** BLOCKED before production n8n operations.

What was proved in this run:

- Current branch: `agent/codex/phase-5q/20260627-025313`
- Tool availability: `python3`, `bash`, and `curl` present; `pwsh`, `node`, and `jq` missing.
- `N8N_BASE_URL` and `N8N_API_KEY` are present in the environment, but values were not printed.
- Local Python SL-PHASE-5Q harness re-passed: `41/41 PASS, 0 FAIL`.
- JSON parse passed for:
  - `workflows/production_humanapproval_current.json`
  - `workflows/production_decision_current.json`
  - `workflows/disabled_autonomous_shadow_evaluator.json`
- Exact guard command was attempted:

```bash
pwsh -File ./scripts/assert-hmz-production-target.ps1
```

Guard result:

```text
/bin/bash: line 1: pwsh: command not found
```

Per the production guard rule, Codex stopped before any n8n API operation.

Production actions not performed:

- Production HumanApproval export/back up: NO
- Production Decision export/back up: NO
- Shadow Evaluator production status read: NO
- Production comparison against local 5Q patch: NO
- Production workflow update/import: NO
- New production versionId confirmation: NO
- Post-apply export checks: NO

New owner packet created:

- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`

Autonomous/Sender safety in this run:

- n8n API used: NO
- n8n MCP used: NO
- Instantly API used: NO
- Google Chat webhook used: NO
- Sender triggered/touched: NO
- VPS touched: NO
- Gate 2 approved/enabled: NO
- Live autonomous sending enabled: NO

---

## Root Cause

Draft behavioural self-improvement failed because the local Decision export did not consume active/effective draft behavioural policy guidance. Node D had no `ACTIVE_RULE_GUIDANCE` or active behavioural policy block and called `buildAIPrompt(...)` without appended owner-approved behavioural guidance.

Review reopen preservation was also incomplete. HumanApproval captured draft-learning fields, but reopened forms did not prefill/store a durable `latest_draft_learning` object, so blank reopened submissions could drop the human-entered reason, type, scope, and target classifications.

The live failure pair is explained by this missing bridge:

- Source: `case-759e58d7`
- Comparison: `case-d099e6f3`
- Human edit was captured by UI fields, but no active/effective behavioural instruction was available to and consumed by Decision node D for the later similar draft.

---

## Files Inspected

- `OPERATION_HANDOFF.md`
- `CLAUDE.md`
- `AGENTS.md`
- `README.md`
- `docs/HMZ_PRODUCTION_TARGET_GUARD.md`
- `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md`
- `docs/SELF_IMPROVEMENT_OPERATIONAL_RUNBOOK.md`
- `docs/REVIEW_REOPEN_LEARNING_AMENDMENTS_CONSOLIDATED_PATCH.md`
- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `workflows/disabled_autonomous_shadow_evaluator.json`

Requested doc mismatch:

- Missing: `docs/NEXT_MANUAL_TEST_PACKET_SELF_IMPROVEMENT_BEHAVIOURAL_PROOF.md`
- Closest equivalent used: `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md`

---

## Files Changed

- `workflows/production_humanapproval_current.json`
  - Reopened forms now prefill draft-learning reason, type, desired future behaviour, scope, and target classifications from `decision_payload.latest_draft_learning` or latest `revision_history`.
  - Submit validation preserves prior draft-learning fields on blank reopened submissions.
  - First approval and `approve_learning_only` now store `decision_payload.latest_draft_learning`.
  - Draft-style rule candidates now include `behavioural_instruction`, `source_original_case_id`, and `requires_human_activation: true`.

- `workflows/production_decision_current.json`
  - Added empty `ACTIVE_BEHAVIOURAL_POLICIES` block.
  - Added active/effective policy filtering, scope/target matching, and duplicate suppression.
  - Appends matched behavioural guidance to the supervised AI draft prompt.
  - Default policy list remains empty, so no rule is activated by this patch.

- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.ps1`
  - Local-only PowerShell wrapper for owner execution.

- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`
  - Dependency-free fallback harness used in WSL.

- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
  - This report.

- `OPERATION_HANDOFF.md`
  - Updated: yes. Current state, active tasks, and newest session log now mark SL-PHASE-5Q as PARTIAL/local-proven with production and live owner proof pending.

---

## Harness Results

Command run:

```bash
python3 ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py
```

Result:

```text
SUMMARY: 41/41 PASS, 0 FAIL
```

Re-run on 2026-06-27:

```text
SUMMARY: 41/41 PASS, 0 FAIL
```

JSON parse re-run on 2026-06-27:

```text
production_humanapproval_current.json: JSON PASS
production_decision_current.json: JSON PASS
disabled_autonomous_shadow_evaluator.json: JSON PASS
```

`pwsh` was unavailable in WSL, so this command was not run:

```bash
pwsh -File ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.ps1
```

No successful production n8n guard run exists because `pwsh` is unavailable. The exact guard command fails with `pwsh: command not found`. Therefore no production n8n operation was attempted.

---

## Evidence for Bridge Repair

Local/synthetic harness verified:

- Human edit is captured.
- `draft_revision_reason` is preserved.
- `draft_revision_type` is preserved.
- `draft_improvement_scope` is preserved.
- `draft_improvement_target_classifications` are preserved.
- Proposed draft-style candidate is created as `proposed_shadow`.
- Candidate preserves source/original case ID.
- Candidate preserves behavioural instruction.
- Candidate requires human activation.
- Active/effective behavioural policy is available after synthetic owner activation.
- Decision consumes only active/effective draft behavioural policies.
- Future similar draft guidance is affected by learned behaviour.
- Unrelated pricing, objection, unsubscribe, and different-micro-intent scenarios are not affected.
- Global/cross-classification policy applies only when explicitly scoped.
- Duplicate active rules are de-duped.
- `proposed_shadow` policies are not consumed.
- Unsafe policies are not consumed.

Varied synthetic scenarios used:

1. Positive/meeting-interest reply
2. Pricing/cost question
3. Objection/not-now reply
4. Unsubscribe/not-interested reply
5. Ambiguous/question reply

---

## Reopened-Form Reason Preservation

Local harness verified:

- Reopened form has a `latest_draft_learning` prefill path.
- Blank reopened submit preserves previous human-entered draft reason.
- Blank reopened submit preserves type, scope, desired future behaviour, and target classifications.

Manual owner proof is still pending. Production is now patched, but the owner has not yet run a live reopened-review proof.

---

## Classification-Amendment Learning Status

Existing same-bridge classification amendment path was inspected and verified locally:

- Human classification amendment capture path exists in `SL-P2A`.
- Corrected classification candidate is created as `proposed_shadow`.
- Corrected-classification reason is preserved.
- Decision-side classification self-improvement was already marked verified in handoff and was not changed in this 5Q patch.

No parallel classification learning system was created.

---

## Autonomous Safety Confirmation

- Shadow Evaluator local export remains `active=false`.
- Shadow config still contains `autonomous_enabled: false`, `shadow_only: true`, `dry_run: true`, and `would_send_live_now: false`.
- Gate 2 remains not approved per handoff/docs.
- No autonomous mode was activated.
- No Sender workflow was changed.
- No live send path was enabled.
- `approve_and_send_followup` remains `FOLLOWUP_SEND_PENDING_MANUAL` with `sender_audit_required: true`.

---

## Production / n8n / Sender Operations

- Production n8n touched: YES, after the exact PowerShell guard passed.
- n8n API called: YES, only scoped GET/PUT for HumanApproval and Decision plus GET status for Shadow Evaluator.
- n8n MCP called: NO
- Instantly API called: NO
- Google Chat webhook called: NO
- Sender workflow touched: NO
- Sender triggered: NO
- Live email sent: NO
- Autonomous sending enabled: NO
- VPS SSH used: NO

---

## Remaining Manual Owner Tests

Manual owner proof remains required before SL-PHASE-5Q can be marked COMPLETE in production:

1. Run varied live owner tests using `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`:
   - Positive/setup explanation reply similar to `case-759e58d7`
   - Pricing/cost question, verifying no behavioural leakage
   - Not-now/timing objection, verifying no behavioural leakage
   - Unsubscribe/not-interested reply, verifying no behavioural leakage
   - Ambiguous/question reply, verifying only explicitly scoped global rules apply
2. Confirm a later similar case produces a draft influenced by the approved behavioural policy.
3. Confirm reopened review forms preserve the latest human-entered draft-learning reason/type/scope/targets in live UI.

---

## Status

**PARTIAL.** Local bridge repair, exact production guard, production export/backup/compare/apply, new `versionId` confirmation, active-state preservation, Shadow Evaluator inactive status, post-export assertions, and Python/PowerShell harnesses all passed. Live owner behavioural proof remains pending, so SL-PHASE-5Q is not complete.
