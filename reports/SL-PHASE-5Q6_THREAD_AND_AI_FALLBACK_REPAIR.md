# SL-PHASE-5Q6 Thread Hydration and AI Fallback Repair

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q6-thread-and-ai-fallback-repair/20260628-050358`  
**Verdict:** PARTIAL - root causes traced, patched, harness-proven, and production-applied; live recheck pending  
**Status percentage:** 88%

## 2026-06-28 SL-PHASE-5Q7 Addendum

Post-5Q6 live case `case-f67601bc` was hydrated and fallback quality was good, but Decision over-rejected a safe numbered-list AI draft as `active policy violation: dense paragraph`, and HumanApproval labelled the fallback as a normal AI-assisted draft. SL-PHASE-5Q7 patched Decision dense validation and HumanApproval source/banners. Production is now Decision `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` and HumanApproval `4b18ec1b-a821-42a0-bc46-06e7ebe81599`; see `reports/SL-PHASE-5Q7_AI_SOURCE_LABEL_AND_VALIDATION.md`.

## 2026-06-28 SL-PHASE-5Q8 Addendum

`case-c3341a17` confirmed 5Q6 alternate thread mapping still works through the accepted AI path (`thread_search=thread:<id>` source, `ai_supervised` draft). A 5Q7 HumanApproval render escaping defect then blocked node `J`; 5Q8 patched only node `J` and production-applied HumanApproval `34531128-5ff6-4538-8846-bbbc5888a7a9`. Owner-authenticated live reopen proof remains pending.

## 2026-06-28 SL-PHASE-5Q9 Addendum

5Q9 did not change Intake or Decision. It patched HumanApproval blocked-send handling for `case-9b9197a4`: exact missing variable `repeat_send_reason_required` is now surfaced, same-link retry remains usable, and blocked submits stay editable with draft/learning saved. Intake remains `abc83e43-9b97-4ca1-ae32-c42599255328`; Decision remains `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`; HumanApproval is now `68f4b543-0004-4677-a95c-ba6768a8523c`.

## Summary

SL-PHASE-5Q6 traced and repaired two live blockers:

1. `case-f54aff79` was diagnostic-only because `thread_id` was missing after Instantly email hydration returned `404 Email not found`. The webhook payload still contained a usable alternate thread identifier in `unibox_url` query `thread_search=thread:<id>`, but Intake did not map it.
2. `case-495332d8`, `case-f54aff79`, and earlier `case-535d430a` used `ai_failed_fallback` because Decision D called OpenAI successfully but post-validation rejected the AI draft under active behavioural/forbidden-claim checks. The fallback template was not policy-aware enough, so it could still be weaker than the active owner-approved guidance.

No live send, Sender trigger, learning-only approval, autonomous activation, Gate 2 work, or VPS access was performed.

## Production Trace Evidence

| Case | Intake execution | HumanApproval execution(s) | Evidence |
|---|---:|---:|---|
| `case-f54aff79` | `2864` | create `2866`, render `2867`, `2868` | Webhook had campaign, sender account, lead email, email id, subject/body, and `unibox_url`; Instantly hydration returned `404 Email not found`; alternate thread id existed in `unibox_url` `thread_search`; HumanApproval blocked as `CONTEXT_MISSING_BLOCKED` for missing `thread_id`. |
| `case-495332d8` | `2869` | create `2871`, render/save/reopen `2872`-`2875` | Hydration returned HTTP 200 with canonical `thread_id` and RFC message id; normal review case built; Save/reopen persisted saved draft and learning instruction. |
| `case-535d430a` | `2835` | create `2837`, save/reopen through `2862` | Hydration returned HTTP 200 with canonical `thread_id`; post-5Q5 reopen evidence showed saved draft and learning metadata persisted. |

## Root Causes

### `case-f54aff79` Missing `thread_id`

Root cause category: **B. Thread ID exists under alternate key but mapper missed it.**

Details:

- Raw Instantly webhook payload did not contain top-level `thread_id`.
- Intake node `C1. Hydrate Reply Email From Instantly` returned `404 Email not found` for email id `019f0c5a-164d-7b4d-9cbd-28642c6dec7b`.
- Because C1 failed, `C2. Merge Reply Hydration` did not populate `raw_payload.thread_id` or `raw_payload.message_id`.
- The payload did include an Instantly Unibox URL with query key `thread_search` whose value was `thread:<thread-id>`.
- Intake did not parse `thread_search`, so `D. Normalization to NES` emitted `nes.threading.thread_id = null`.
- HumanApproval correctly blocked under the existing strict missing-context guard, but the guard became over-strict because a stable alternate thread identifier was available upstream.

Fix:

- `workflows/production_intake_current.json`
  - Patched `C2. Merge Reply Hydration` to parse `thread_id`, `threadId`, `thread`, and `thread_search=thread:<id>` from `raw.unibox_url`.
  - Preserves canonical Instantly-hydrated `email.thread_id` first.
  - Records `_hmz_v10_hydration.alternate_thread_id_source` as `unibox_url_thread_search` when the alternate path is used.
  - Leaves genuinely missing thread context diagnostic-only.

### AI Draft / Fallback

Root cause category: **AI output validation fallback, not provider outage.**

Details:

- Decision output for `case-f54aff79`, `case-495332d8`, and `case-535d430a` showed:
  - `draft.ai_attempt.provider = openai`
  - `draft.ai_attempt.model = gpt-5.4-mini`
  - `draft.ai_attempt.ok = true`
  - `draft.ai_attempt.error = null`
  - `draft.ai_attempt.raw_draft_text` present
- The final `draft_source` was still `ai_failed_fallback` because Decision D post-validation rejected the AI text, then fell back to deterministic text.
- The old deterministic `OFFER_EXPLANATION` fallback mentioned validation stage and used a weaker dense setup explanation, conflicting with active owner-approved behavioural guidance for setup questions.

Fix:

- `workflows/production_decision_current.json`
  - Added `buildPolicyAwareFallback(...)`.
  - Fallback for `INFORMATION_REQUEST / OFFER_EXPLANATION` now answers setup first, uses short paragraphs and a numbered list, places CTA after the useful answer, and avoids validation/proof/case-study/result language unless asked.
  - Fallback generation consumes the same `behaviouralGuidance` produced by active/effective owner-approved policies.
  - AI provider/config failures now use explicit safe `fallback_reason` values:
    - `AI_PROVIDER_CONFIG_MISSING`
    - `AI_PROVIDER_OR_RESPONSE_FAILED`
    - `AI_OUTPUT_VALIDATION_FAILED`
    - `FINAL_DRAFT_TOKEN_VALIDATION_FAILED`
  - `draft.ai_attempt.fallback_reason` and `draft.notes` expose a safe internal category without secrets.
  - Normal AI success path still uses active behavioural policy guidance and newer same-scope override logic.

## Save/Reopen Evidence

`case-535d430a` post-5Q5 reopen execution `2862` showed:

- row status remained `IN_REVIEW`;
- saved draft persisted in `decision_payload.latest_saved_reply_text`;
- combined learning instruction persisted;
- revision types persisted: style, formatting, grammar, clarity, wrong CTA;
- scopes persisted: current micro-intent, current broad category, all AI drafts;
- target classifications persisted: `INFORMATION_REQUEST` and `OFFER_EXPLANATION`;
- same case/token render path remained stable;
- no Sender execution contained `case-535d430a`;
- no learning-only or approval action was performed by Codex.

## Harness Results

Post-production-sync local harness results:

- 5Q6 Python: `24/24 PASS`
- 5Q6 PowerShell: `24/24 PASS`
- 5Q5 Python: `34/34 PASS`
- 5Q5 PowerShell: `34/34 PASS`
- 5Q4 Python: `26/26 PASS`
- 5Q4 PowerShell: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`
- 5Q3 PowerShell: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5Q2 PowerShell: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`
- 5R-prep PowerShell: `17/17 PASS`

## Production Apply

Production target guard passed before API operations.

Backup directory:

- `backups/sl-phase-5q6-thread-ai-fallback-20260628T041346Z`

Workflow changes:

| Workflow | Old versionId | New versionId | Active after | Changed nodes |
|---|---|---|---:|---|
| Intake | `bcfadfeb-e1a2-4924-b429-c522863c6708` | `abc83e43-9b97-4ca1-ae32-c42599255328` | `true` | `C2. Merge Reply Hydration` |
| Decision | `a4dab823-a540-48e8-8df6-514eca5d060a` | `676c83ad-ebbd-4dd6-a204-b48245e061bc` | `true` | `D. Draft Preparation (Templates / Human Draft)` |
| HumanApproval | `4caf621f-cda5-4aca-84a7-e1b521e99c7c` | unchanged | `true` | none |
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
- Sender still contains the `DRY_RUN` marker and `LIVE_CREDENTIAL_READY=true` was not present.
- `approve_and_send_followup` auto-send remains disabled/not implemented.
- VPS/SSH was not used.

## Remaining Proof

Live recheck is still required. Next owner action should be one review-only test with a new seeded active campaign-thread reply:

```text
Before we go any further, can you explain what the setup would actually involve for our team?
```

Stop after inspecting the Google Chat card/review form. Do not click `Approved for learning only` or `Approve and send` until thread hydration and draft/fallback behaviour are observed on the new post-5Q6 case.
