# SL-PHASE-5Q8 HumanApproval Render Regression

**Date:** 2026-06-28  
**Agent:** Codex  
**Branch:** `agent/codex/phase-5q8-humanapproval-render-regression/20260628-050738`  
**Verdict:** PARTIAL - root cause fixed, harness-proven, and production-applied; owner-authenticated live reopen still pending  
**Status percentage:** 88%

## Summary

## 2026-06-28 SL-PHASE-5Q9 Addendum

Owner testing on `case-9b9197a4` exposed a post-submit blocked-send UX defect after 5Q8. `approve_and_send_followup` was submitted without `repeat_send_reason`; HumanApproval detected `repeat_send_reason_required`, saved draft/learning fields, and did not trigger Sender, but set status `BLOCKED_MISSING_VARIABLES`. The same token remained stable, yet GET validation treated that status as `ALREADY_DECIDED`, so the same review link became unavailable. `Q2` also displayed `missing required variables ()` because it read the wrong blocked-variable field. SL-PHASE-5Q9 patched HumanApproval only and production-applied versionId `68f4b543-0004-4677-a95c-ba6768a8523c`; 5Q9 `21/21`, 5Q8 `22/22`, 5Q7 `17/17`, 5Q5 `34/34`, and 5R-prep `17/17` pass post-export. Owner-authenticated same-link reopen remains pending.

Fresh post-5Q7 live case `case-c3341a17` proved the normal AI-generated draft path worked, but clicking the review link failed in HumanApproval node `J. Render Review Form HTML`.

The regression was a 5Q7 renderer JavaScript escaping defect. New source/banner HTML strings used unescaped `style="..."` and textarea attributes inside double-quoted JavaScript string literals. Node `J` therefore failed compilation with `Unexpected identifier 'background'` before it could render the form. The error handler did not receive the case id and collapsed the notification to `UNKNOWN_ID`.

No learning-only action, Save action, approve/send action, Sender trigger, autonomous activation, Gate 2 work, or VPS access was performed.

## Case Trace

| Workflow | Execution | Started | Evidence |
|---|---:|---|---|
| Intake | `2893` | `2026-06-28T04:48:04.143Z` | Hydrated `case-c3341a17`; reply text present; sender `hamzah@onehmzautomation.com`; subject `Re: Capacity Question`; alternate thread id mapped from `unibox_url_thread_search`. |
| Decision | `2894` | `2026-06-28T04:48:04.463Z` | `INFORMATION_REQUEST / OFFER_EXPLANATION`; OpenAI provider `openai`, model `gpt-5.4-mini`, `ok=true`; raw AI draft present; validation valid; final `draft_source=ai_supervised`. |
| HumanApproval create | `2895` | `2026-06-28T04:48:07.667Z` | Persisted normal `NEW` review case with non-empty draft, source `ai_supervised`, policy `AI_SUPERVISED_OR_TEMPLATE`; Google Chat card showed `AI-generated draft for human review`. |
| HumanApproval render | `2896`, `2898` | `2026-06-28T04:48:14Z`, `04:48:24Z` | Lookup and token validation passed for `case-c3341a17`; node `J` failed with `Unexpected identifier 'background'`. |
| Error Handler | `2897`, `2899` | `2026-06-28T04:48:14Z`, `04:48:24Z` | Google Chat error notification showed `HMZ error record: UNKNOWN_ID` and node `J. Render Review Form HTML`. |
| Sender | none | n/a | Latest Sender execution remained old `2762` from 2026-06-27; no Sender execution contained this case or occurred in the 5Q8 window. |

Safe case details:

- From: `hamzahzahid3@gmail.com`
- Sender: `Hamza <hamzah@onehmzautomation.com>`
- Campaign: `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, `HMZ Responder Behaviour Acceptance - Round 1`
- Thread source: alternate Unibox `thread_search` mapping from SL-PHASE-5Q6
- Reply: `Could you explain what the setup process would look like before we decide whether a call makes sense?`
- Draft text: present and AI-generated
- HumanApproval persisted state: `NEW`, non-diagnostic, no missing-context block

## Root Cause Classification

**A. JavaScript/HTML escaping defect.**

Node `J. Render Review Form HTML` contained 5Q7 source/banner logic like:

```text
html += "<p style="background:#d1ecf1;...
```

The inner `style="..."` quote ended the JavaScript string literal early, so the node could not compile. The same injected block also had unescaped textarea attributes. The accepted AI branch was not safely covered by the prior 5Q7 harness at compile-string level.

`UNKNOWN_ID` appeared because the render node failed after lookup/token validation but before normal case-aware HTML output; the error handler normalized the node failure without the case id.

## Fix Summary

Patched only `workflows/production_humanapproval_current.json`, node `J. Render Review Form HTML`:

- escaped the 5Q7 human-only, commercial AI, fallback, and accepted `ai_supervised` banner HTML attributes;
- escaped the nearby editable draft textarea attributes;
- preserved accepted AI source wording: `AI-generated draft for human review. Edit before approving.`;
- preserved fallback wording and safe fallback reason display;
- preserved 5Q5 Save/reopen loading, 5Q3 missing-context blocking, and 5Q2 learning UI.

No Decision change was needed.

## Harness Results

Post-patch local results:

- 5Q8 Python: `22/22 PASS`
- 5Q8 PowerShell: `22/22 PASS`
- 5Q7 Python/PowerShell: `17/17 PASS`
- 5Q6 Python/PowerShell: `24/24 PASS`
- 5Q5 Python/PowerShell: `34/34 PASS`
- 5Q4 Python/PowerShell: `26/26 PASS`
- 5Q3 Python/PowerShell: `30/30 PASS`
- 5Q2 Python/PowerShell: `27/27 PASS`
- 5R-prep Python/PowerShell: `17/17 PASS`

Post-production-export sync rerun:

- 5Q8 Python: `22/22 PASS`
- 5Q8 PowerShell: `22/22 PASS`
- 5Q7 Python: `17/17 PASS`
- 5Q4 Python: `26/26 PASS`

## Production Apply

Production target guard passed before API operations.

Backup directory:

- `backups/sl-phase-5q8-humanapproval-render-regression-20260628T051752Z`

Workflow update:

| Workflow | Old versionId | New versionId | Active after | Changed nodes |
|---|---|---:|---:|---|
| HumanApproval | `4b18ec1b-a821-42a0-bc46-06e7ebe81599` | `34531128-5ff6-4538-8846-bbbc5888a7a9` | `true` | `J. Render Review Form HTML` |
| Decision | `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` | unchanged | `true` | none |
| Intake | `abc83e43-9b97-4ca1-ae32-c42599255328` | unchanged | `true` | none |
| Sender | `dfb310f4-901a-4d76-81dc-8f5d4ad13552` | unchanged | `true` | none |
| Proxy | `d61050e6-dbc6-4fec-b404-3aad20a80e84` | unchanged | `true` | none |
| Shadow Evaluator | `ae13bf4e-ee04-438f-9657-3c57183b90a2` | unchanged | `false` | none |

Unexpected drift: NONE. Pre-apply production export differed from local only in `J. Render Review Form HTML`; apply payload replaced only that node code.

One PUT attempt was rejected before update because `tags` is read-only in the n8n API payload. The corrected no-tags payload succeeded.

## Live Recheck Status

Codex attempted one render-only GET for `case-c3341a17` after production apply. The request returned HTTP `401` before workflow execution because the review form requires Basic Auth credentials not available in the allowed environment variables. No review submit occurred.

Post-attempt read-only execution check:

- HumanApproval latest remained `2898`; no new render execution was created by the blocked GET.
- Sender latest remained old `2762`.
- Error Handler latest remained `2899`.

Therefore the fix is production-applied and harness-proven, but owner-authenticated live reopen proof remains pending.

## Safety Confirmation

- Sender/live send was not triggered.
- No Save, learning-only, approve, deny, or approve/send action was submitted.
- Render path remains disconnected from Sender and learning candidate creation.
- Wrong-token and unknown-case guards remain harness-proven.
- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Live autonomous sending remains disabled.
- `approve_and_send_followup` auto-send remains disabled; metadata capture still requires Sender audit.
- VPS/SSH was not used.

## Next Owner Action

Reopen the same `case-c3341a17` review link from the original Google Chat card while authenticated to the review form.

Confirm only that the form renders normally and shows:

- incoming reply;
- non-empty AI draft;
- `Draft source: ai_supervised`;
- banner: `AI-generated draft for human review. Edit before approving.`;
- learning UI, Save, Approved for learning only, and Approve/send controls.

Do not click Save, Approved for learning only, Approve/send, deny, or any follow-up action yet.

If the same link is expired, create one fresh varied setup reply:

```text
Could you walk me through what the setup would involve before we decide whether it is worth booking a call?
```

Stop after confirming the Google Chat card and review form render.
