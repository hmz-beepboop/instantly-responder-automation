# SL-PHASE-5Q14D Invalid Diagnostic Link and Context Missing

**Date:** 2026-06-29  
**Agent:** Codex  
**Verdict:** COMPLETE for diagnostic-link repair and context-missing root cause; live self-improvement proof still pending  
**Status percentage:** 94%

## Scope

This session traced `case-3df4e733`, repaired diagnostic review-link rendering, and fixed the narrow Decision path that produced an empty draft for `INFORMATION_REQUEST / BOOKING_REQUEST`.

No Sender, autonomous, Gate 2, or live-send path was changed.

## Case Trace

- Case: `case-3df4e733`
- Intake: `00MQYOYTHS3KBL8U23HW3RAKX4`
- HumanApproval create execution: `3270`
- Review-link GET executions: `3271`, `3272`
- Intake execution: `3268`
- Decision execution: `3269`
- Status: `CONTEXT_MISSING_BLOCKED`
- Diagnostic status shown in Chat: `INTAKE_CONTEXT_MISSING / diagnostic only`
- Missing fields: `draft_text`
- Token: present, expires `2026-06-29T05:02:16.884Z`; GET attempts at `2026-06-29T04:02:36Z` and `2026-06-29T04:03:29Z` were before expiry
- Diagnostic-only marker: present in `sanitized_context.context_missing.blocked=true`
- Link failure: HumanApproval GET gate excluded `CONTEXT_MISSING_BLOCKED` from renderable states and returned `ALREADY_DECIDED`, sending the owner to the token error page
- Sender: not triggered for this case
- Instantly POST: none caused by this case or this apply

## Intake and Context Diagnosis

The live test was not missing core Intake thread context:

- Campaign ID was present: `531e64ed-c225-4baf-97a9-4ec90dc34eb0`
- Lead email was present: `hamzahzahid0@gmail.com`
- Sender/eaccount was present: `zahid@gethmzautomation.com`
- Subject was present after hydration: `Re: Capacity Question`
- Thread ID was present after hydration
- Reply body was present: `Is there a calendar link I can use to pick a slot?`
- Intake validation was `valid=true`

Root cause for `draft_text` missing was in Decision, not Intake. The classifier emitted `INFORMATION_REQUEST / BOOKING_REQUEST`, but `draftPolicyFor()` did not define `BOOKING_REQUEST`, so it defaulted to `HUMAN_ONLY`. Decision D also only had a template for `MEETING_TIME_REQUEST`, not the `BOOKING_REQUEST` micro-intent alias.

This invalid case cannot prove self-improvement.

## Root Cause Categories

- `A`: diagnostic-only states were excluded from renderable review-link states.
- `B`: the GET token gate treated `CONTEXT_MISSING_BLOCKED` as terminal/already decided.
- `F`: Decision selected `HUMAN_ONLY` because the `BOOKING_REQUEST` micro-intent had no sendable draft-policy mapping.
- `G`: `case-3df4e733` is invalid and cannot prove live learning.
- `H`: Decision also needed a narrow template alias so `INFORMATION_REQUEST / BOOKING_REQUEST` uses the existing booking template path and the active booking-rule crosswalk.

Owner setup was not the evidence-backed root cause for this case; the campaign/thread/lead/reply fields were present.

## Repair

HumanApproval:

- Added `CONTEXT_MISSING_BLOCKED` to GET/POST renderable states.
- Added it to POST handoff-optional reopen states so diagnostic POST attempts are handled by the existing non-send missing-context branch instead of token unavailability.
- Expanded the diagnostic page to show case ID, status, missing fields, from, sender, broad category, micro intent, draft policy/source, subject, reply excerpt, exact correction instructions, safe next action, `No reply was sent.`, and `This diagnostic case cannot be approved or sent.`
- Diagnostic page renders disabled action buttons only.
- Preserved 5Q11 same-link accessibility states.

Decision:

- Added `BOOKING_REQUEST: 'FIXED_TEMPLATE'` in `draftPolicyFor()`.
- Added a narrow template alias: micro-intent `BOOKING_REQUEST` uses the existing `MEETING_TIME_REQUEST` booking template.
- Extended the 5Q14B active-rule crosswalk to cover both `BOOKING_REQUEST / MEETING_TIME_REQUEST` and `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Did not hardcode the learned booking guidance into baseline policy or templates.

## Harness Results

Pre-apply:

- 5Q14D Python: `21/21 PASS`
- 5Q14D PowerShell: `21/21 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`

Post-sync:

- 5Q14D Python: `21/21 PASS`
- 5Q11 Python: `24/24 PASS`
- 5Q14B Python: `20/20 PASS`
- 5Q12 Python: `29/29 PASS`

## Production Apply

Production guard passed before n8n writes.

Backup:

- `backups/sl-phase-5q14d-invalid-diagnostic-link-20260629T202122Z`

Version/state:

- HumanApproval `f1138daa-8d38-4acf-b0c9-a6a2bef626fe` -> `00eb6dbc-c1a7-42ce-97ef-24653d06784d`; active preserved `true`
- Decision `c7299598-71e2-4f0f-b493-184cb7b793f7` -> `302e34bc-8b81-4c2f-97fa-832246153646`; active preserved `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow Evaluator unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Latest Sender execution remained `3193`, started before this session; no Sender execution contained `case-3df4e733`

## Next Owner Action

Create one fresh owned/test booking-link reply after:

- HumanApproval version `00eb6dbc-c1a7-42ce-97ef-24653d06784d`
- Decision version `302e34bc-8b81-4c2f-97fa-832246153646`

Use an owned/test prospect already seeded in the active Instantly campaign. Reply from the prospect inbox in the existing campaign thread, not by forwarding or composing a standalone email. Before retrying, confirm Instantly shows the campaign, lead email, subject, thread, and reply body.

Suggested reply:

`Is there a calendar link I can use to pick a slot?`

Inspect the review draft only. Do not approve, send, or click learning-only.

## 5Q14F Render Crash Follow-up

**Date:** 2026-06-29  
**Verdict:** COMPLETE for render-crash repair; live learning proof still pending  
**Status percentage:** remains 94%

Fresh case `case-9747ff6f` was valid/non-diagnostic and had draft text, but the review link returned a blank page. HumanApproval execution `3493` failed at node `J. Render Review Form HTML` with `SyntaxError: Unexpected identifier 'background'`.

Root cause:

- 5Q14D diagnostic HTML added unescaped attributes inside JavaScript strings in Node J, including `style="background...` and `type="button"`.
- Because this was a compile error, it affected valid AI-supervised pages before branch logic could render.

Repair:

- HumanApproval version `de84f8f3-d4c4-4565-88ab-c40449e727ca` escapes the diagnostic HTML attributes and adds safe optional-metadata rendering for malformed `risk_flags` / `detected_intents`.
- Decision version `e64cded8-e4a9-46f8-b541-23512e9f4dce` adds narrow classifier coverage for `grab a time`, `grab a slot`, and `time on your calendar`.
- `case-9747ff6f` was classified as `INFORMATION_REQUEST / OFFER_EXPLANATION`; Q12 found rule `c9860e74-ff23-477e-87f1-812bec8023e5`, but Decision D did not consume it because the micro-intent was ineligible.
- The AI draft mentioning a calendar link is therefore not live form-learning proof.

Harness:

- 5Q14F Python/PowerShell: `22/22 PASS`
- 5Q14D Python/PowerShell: `21/21 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`

Next owner action now supersedes the earlier action: immediately reopen the existing `case-9747ff6f` review link before `2026-06-29T23:07:37Z` and inspect the draft only. Do not approve, send, save, or click learning-only.
