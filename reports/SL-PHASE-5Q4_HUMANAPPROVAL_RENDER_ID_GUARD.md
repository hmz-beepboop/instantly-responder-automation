# SL-PHASE-5Q4 HumanApproval Render ID Guard

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q3-corrected-live-retest/20260628-032641`  
**Verdict:** PARTIAL - root cause fixed and production-applied; owner re-open proof pending  
**Status percentage:** 82%

## 2026-06-28 SL-PHASE-5Q6 Addendum

The post-render/live sequence exposed two separate blockers after this report: `case-f54aff79` was diagnostic-only because Intake missed an alternate Unibox thread identifier, and hydrated cases used `ai_failed_fallback` because Decision post-validation rejected AI drafts and fell back to weak deterministic setup text. Both were traced, harness-proven, and production-applied in SL-PHASE-5Q6. HumanApproval remained unchanged at `4caf621f-cda5-4aca-84a7-e1b521e99c7c`.

2026-06-28 SL-PHASE-5Q7 addendum: HumanApproval review-form banner/source wording was misleading for `ai_failed_fallback`. Node `J. Render Review Form HTML` now shows a safe fallback banner and reason category for validation/provider fallback; HumanApproval is now `4b18ec1b-a821-42a0-bc46-06e7ebe81599`.

2026-06-28 SL-PHASE-5Q8 addendum: A second node `J` syntax regression appeared after 5Q7, this time in the accepted AI source/banner block (`Unexpected identifier 'background'` on `case-c3341a17`). 5Q8 escaped the 5Q7 banner and textarea attributes, added render regression harness coverage, and production-applied HumanApproval `34531128-5ff6-4538-8846-bbbc5888a7a9`. The original diagnostic banner guard remains preserved.

## Live Failure Summary

Corrected hydrated Human Action 1 produced `case-535d430a`.

Google Chat card evidence:

- From: `alinazahidkhan890@gmail.com`
- Sender: `Hamza <hamzah@teamhmzautomations.com>`
- Broad category: `INFORMATION_REQUEST`
- Micro intent: `OFFER_EXPLANATION`
- Urgency: `routine`
- Draft policy: `AI_SUPERVISED_OR_TEMPLATE`
- Draft source: `ai_failed_fallback`
- Reply excerpt: `Before we book anything, can you explain what your setup actually includes?`
- Review link present

The card was hydrated, so this was not the prior blank/UNKNOWN hydration defect. The subsequent Google Chat error records reported `UNKNOWN_ID`, but n8n execution evidence showed the first failing node was actually `J. Render Review Form HTML` with JavaScript syntax error `Unexpected identifier 'background'`.

## Execution Trace

| Workflow | Execution | Started | Evidence |
|---|---:|---|---|
| Intake | `2835` | `2026-06-28T02:40:05.073Z` | Human Approval handoff emitted `case-535d430a`, status `NEW`. |
| Decision | `2836` | `2026-06-28T02:40:05.657Z` | Completed successfully in the same chain. |
| HumanApproval create | `2837` | `2026-06-28T02:40:09.053Z` | Built review case `case-535d430a`, status `NEW`, micro intent `OFFER_EXPLANATION`, draft source `ai_failed_fallback`, draft policy `AI_SUPERVISED_OR_TEMPLATE`, non-empty fallback draft. Data Table row id `67` persisted with token. |
| HumanApproval GET/render | `2839`, `2840` | `2026-06-28T02:40:51Z` | Render executions failed at node `J. Render Review Form HTML` with `Unexpected identifier 'background'`. Stored query evidence in those two executions showed old links for `case-66062eda` and `case-ed174cd6`; the same node-level syntax defect would block `case-535d430a` too because node J could not compile. |
| Error Handler | `2841`, `2842` | `2026-06-28T02:40:51Z` | Two separate render failures generated two separate error-handler executions. |
| Sender | none linked | n/a | Recent Sender executions did not contain `case-535d430a`; render path did not trigger Sender. |

## Root Cause Classification

**H. Other - HumanApproval renderer JavaScript syntax defect.**

The first failing node was `J. Render Review Form HTML`. The 5Q3 diagnostic block contained a malformed JavaScript string:

```text
html += "<div style="background:#f8d7da;...
```

The inner `style="..."` quote was not escaped, so node J failed to compile before it could render any review form. That made hydrated cases non-renderable even when case creation and persistence were valid.

`case-535d430a` itself was hydrated and renderable in data terms: it had case ID, token, from/sender context, classification, micro intent, fallback draft text, and review row state. The blocker was renderer syntax, not missing context, token mismatch, or `ai_failed_fallback`.

## Files Changed

- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q4-humanapproval-render-id-guard.py`
- `scripts/SL-PHASE-5Q4-humanapproval-render-id-guard.ps1`
- `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

## Fix Summary

- Escaped the diagnostic banner style quote in HumanApproval node `J. Render Review Form HTML`.
- Added 5Q4 local harness coverage for:
  - render syntax regression;
  - case/token lookup and validation;
  - wrong-token and unknown-case safety;
  - `ai_failed_fallback` editable draft rendering;
  - learning UI, Save, and learning-only controls;
  - diagnostic early return before normal buttons;
  - no Sender or candidate creation from render path;
  - node J not self-posting duplicate error records.

## Harness Results

- 5Q4 Python: `26/26 PASS`
- 5Q4 PowerShell: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`
- 5Q3 PowerShell: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5Q2 PowerShell: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`
- 5R-prep PowerShell: `17/17 PASS`

## Production Apply Status

- Guard passed before production API operations.
- Backup directory: `backups/sl-phase-5q4-humanapproval-render-id-guard-20260628T025225Z`
- HumanApproval changed only: `J. Render Review Form HTML`
- HumanApproval versionId: `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609` -> `542f4159-fb6b-4dc4-9dda-f97657fbf7ac`
- HumanApproval active state preserved: `true`
- Decision unchanged: `a4dab823-a540-48e8-8df6-514eca5d060a`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Unexpected drift: NONE.

## Remaining Proof

2026-06-28 SL-PHASE-5Q5 follow-up: `case-535d430a` rendered after the 5Q4 fix, but Save/reopen did not prefill saved draft/learning values because node J preferred original `draft_text` for unsent `IN_REVIEW` cases. This was fixed and production-applied in HumanApproval versionId `4caf621f-cda5-4aca-84a7-e1b521e99c7c`; see `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`.

Owner must reopen the current `case-535d430a` review link once. If it renders normally, resume the save/reopen proof from the 5Q3 packet. Do not approve/send.

If the same link no longer works because the token expired or the wrong link was opened, create a new seeded owned/test prospect reply with:

```text
Before we go any further, can you explain what the setup would actually involve for our team?
```

## Safety Confirmation

- Sender was not triggered by this repair.
- Instantly API was not called.
- Google Chat webhook was not called directly by Codex.
- VPS/SSH not used.
- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Live autonomous sending remains disabled.
- `approve_and_send_followup` auto-send remains disabled.
