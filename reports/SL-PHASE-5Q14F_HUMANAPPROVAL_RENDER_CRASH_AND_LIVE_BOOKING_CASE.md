# SL-PHASE-5Q14F HumanApproval Render Crash and Live Booking Case

**Date:** 2026-06-29  
**Agent:** Codex  
**Verdict:** COMPLETE for render crash repair and classification eligibility repair; live learning proof still pending  
**Status percentage:** 94%

## Scope

This session traced `case-9747ff6f`, fixed a HumanApproval render compile error, audited the live booking/calendar classification, and patched the smallest Decision classifier gap.

No Sender, Intake, autonomous, Gate 2, or live-send path was changed.

## Case Trace

- Case: `case-9747ff6f`
- Intake: `00MQZRQI7D9OL01YPRS7ZFUH95`
- Intake execution: `3490`
- Decision execution: `3491`
- HumanApproval create execution: `3492`
- HumanApproval render GET execution: `3493`
- Case status: `NEW`
- Valid/non-diagnostic: yes
- Token: present, expires `2026-06-29T23:07:37.041Z`
- Inbound reply: `Where can I grab a time on your calendar?`
- Campaign ID: `531e64ed-c225-4baf-97a9-4ec90dc34eb0`
- Lead email: `alinazahidkhan890@gmail.com`
- Sender/eaccount: `hamzah@teamhmzautomations.com`
- Subject: `Re: Capacity Question`
- Thread ID: present in Intake execution before Decision handoff
- Reply body: present
- Broad category: `INFORMATION_REQUEST`
- Micro intent: `OFFER_EXPLANATION`
- Draft policy: `AI_SUPERVISED_OR_TEMPLATE`
- Draft source: `ai_supervised`
- Draft text present: yes
- Sender triggered: no
- Instantly POST: none caused by this case or this apply

## Render Failure

Node J failed before rendering any page:

- Workflow: `HMZ - Reply Human Approval - Validation`
- Node: `J. Render Review Form HTML`
- Error: `SyntaxError: Unexpected identifier 'background'`
- Failing fragment: diagnostic HTML added by 5Q14D had unescaped attributes inside a JavaScript string, for example `html += "<div style="background:...`
- The same diagnostic block also had unescaped `type="button"` button attributes.

Root-cause category:

- `A`: unescaped quote/template literal in Node J.
- `B`: malformed HTML/JS created by recent 5Q14D additions.
- `C`: valid AI-supervised render path was not covered by the previous diagnostic-link harness because a compile error affects the whole node before branch logic.

## Render Repair

HumanApproval:

- Escaped the diagnostic page HTML attributes in Node J.
- Added safe optional-metadata guards for malformed `risk_flags` and `detected_intents`.
- Added a visible safe render diagnostic block when optional metadata is malformed, instead of throwing a blank page.
- Preserved state banners, learning fields, save/learning-only/approve/send controls, and diagnostic-only rendering.
- Render path still does not connect to Sender.

## Booking Classification and Learning Audit

Live `case-9747ff6f` is not valid self-improvement proof yet:

- The inbound meaning is a booking/calendar/time-slot request.
- Decision classified it as `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Q12 active form-learning lookup executed and found rule `c9860e74-ff23-477e-87f1-812bec8023e5` with source case `case-5cf1aa57` and marker `humanapproval_form_created_learning`.
- The rule was not eligible in Decision D because the current micro-intent was `OFFER_EXPLANATION`, not `BOOKING_REQUEST`.
- Decision D output did not carry the source rule ID, source case ID, or marker into the draft context.
- The AI draft did mention a calendar link, but that is not proof of form-created learning because the active rule was fetched but not consumed.

Decision repair:

- Added narrow booking/calendar phrase handling for `grab a time`, `grab a slot`, `time on your calendar`, `slot on your calendar`, and `your calendar`.
- Existing 5Q14D booking mappings remain: `BOOKING_REQUEST` maps to the fixed-template path and the active booking-rule crosswalk covers `INFORMATION_REQUEST / BOOKING_REQUEST` plus `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- No learned booking guidance was hardcoded into baseline policy, classifier, or deterministic templates.

## Harness Results

Pre-apply:

- 5Q14F Python/PowerShell: `22/22 PASS`
- 5Q14D Python/PowerShell: `21/21 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`

Post-sync:

- 5Q14F Python: `22/22 PASS`
- 5Q14D Python: `21/21 PASS`
- 5Q11 Python: `24/24 PASS`
- 5Q14B Python: `20/20 PASS`
- 5Q12 Python: `29/29 PASS`

## Production Apply

Production guard passed before n8n writes.

Backup:

- `backups/sl-phase-5q14f-render-crash-live-booking-20260629T222039Z`

Version/state:

- HumanApproval `00eb6dbc-c1a7-42ce-97ef-24653d06784d` -> `de84f8f3-d4c4-4565-88ab-c40449e727ca`; active preserved `true`
- Decision `302e34bc-8b81-4c2f-97fa-832246153646` -> `e64cded8-e4a9-46f8-b541-23512e9f4dce`; active preserved `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow Evaluator unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Latest Sender execution remained `3193`, started before this session; no Sender execution contained `case-9747ff6f`

## Next Owner Action

Immediately reopen the existing `case-9747ff6f` review link before `2026-06-29T23:07:37Z` and inspect the draft only. Do not approve, send, save, or click learning-only.

## 5Q15 Follow-up: Stale-Case Boundary

**Date:** 2026-06-29  
**Verdict:** `case-9747ff6f` is stale for dynamic-learning proof.

Owner-reported evidence confirms the review form now renders. Codex did not independently re-query n8n in 5Q15 because production API access was rejected by policy.

`case-9747ff6f` was created before Decision version `e64cded8-e4a9-46f8-b541-23512e9f4dce`; its stored review-case classification/draft remain the original Decision output unless a separate regenerate feature is added. The HumanApproval GET render path displays stored review-case data and does not call Decision to regenerate classification or draft text.

5Q15 locally repairs the source-of-truth bridge so active HumanApproval form-created classification corrections can adjust future effective classification before draft policy/template selection. Fresh post-apply live proof is still required.
