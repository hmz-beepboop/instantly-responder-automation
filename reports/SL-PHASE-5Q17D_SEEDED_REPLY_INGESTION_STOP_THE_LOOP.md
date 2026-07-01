# SL-PHASE-5Q17D Seeded Reply Ingestion Stop The Loop

Date: 2026-07-01

## Verdict

COMPLETE. `case-2c7e1ff0` was a post-5Q17C production failure, not a pre-repair artifact and not proven owner setup error.

The owner was again correct that seeded context reached Intake. The new failure was the same `missing /` symptom, but 5Q17D found the exact underlying cause: Decision node D contained a malformed regular expression literal inside `_5qNormalizeDraftForLearningDelta(...)`. That is a parse-time JavaScript syntax error, so the 5Q17C runtime fallback could not catch it. n8n converted the failed node item into error-only `{ error: "missing /" }`, and HumanApproval generated a diagnostic from that invalid upstream payload.

## Timing And Version Gate

`case-2c7e1ff0` was created after 5Q17C production apply.

- Intake execution: `3814`, started `2026-06-30T21:37:10.851Z`
- Decision execution: `3815`, started `2026-06-30T21:37:11.505Z`
- HumanApproval execution: `3816`, started `2026-06-30T21:37:11.807Z`
- diagnostic expiry: `2026-06-30T22:37:11.859Z`
- failing Decision production version before 5Q17D: `3b949639-3cf8-4e0e-ab1a-cee3bcb669ef`
- failing HumanApproval production version before 5Q17D: `a069be1a-cfc5-4c5e-be9a-e300600aa58f`

Note: the prompt's `90bcfe07-6a61-4e90-aa0f-a8eb8bd388f2` Decision reference was stale. That was the 5Q17B version. 5Q17C had already advanced production Decision to `3b949639-3cf8-4e0e-ab1a-cee3bcb669ef`.

## Seeded Reply Path Trace

Raw webhook and Intake:

- raw payload present
- top-level keys included `timestamp`, `event_type`, `workspace`, `campaign_id`, `unibox_url`, `campaign_name`, `email_account`, `reply_text_snippet`, `lead_email`, `email`, `Website`, `First_name`, `Company_name`, `step`, `variant`, `email_id`, `reply_subject`, `reply_text`, and `reply_html`
- event type `reply_received`
- campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0`
- lead email present
- sender email present
- subject `Re: Capacity Question`
- reply text present
- email ID `00MR163AORTSYC1H11R9E3P123`

Instantly hydration:

- attempted
- HTTP status `200`
- alternate thread source `instantly_email`
- hydrated thread ID `53-RKIOlX32DrLO3dLAoGwdkoG`
- hydrated message ID present
- merged reply text length `50`

Decision:

- input contained valid Intake context: intake ID, reply_from_email, sender_email, subject, thread_id, and reply_text
- classifier produced `INFORMATION_REQUEST`
- micro-intent was `OFFER_EXPLANATION`
- node D output was error-only `{ error: "missing /" }`

HumanApproval:

- received error-only Decision output
- created diagnostic `case-2c7e1ff0`
- status `CONTEXT_MISSING_BLOCKED`
- rendered Google Chat status as generic `INTAKE_CONTEXT_MISSING`, which was misleading because Intake had context
- approve/send disabled
- latest Sender execution did not change

## Root Cause

Category: Decision parse-time workflow bug plus HumanApproval diagnostic-layer ambiguity.

Exact broken Decision D source shape:

```javascript
function _5qNormalizeDraftForLearningDelta(value) {
  return String(value || '').replace(/<literal newline>/g, '').replace(/[ \t]+/g, ' ').replace(/<literal newline>{3,}/g, '<literal newline><literal newline>').trim();
}
```

Corrected code:

```javascript
function _5qNormalizeDraftForLearningDelta(value) {
  return String(value || '').replace(/\r/g, '').replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
}
```

Because the malformed regex prevented node D from parsing, the 5Q17C runtime fallback could not execute. HumanApproval then had no valid Decision object, so it built a diagnostic. HumanApproval's prior diagnostic contract collapsed all downstream missing fields into `INTAKE_CONTEXT_MISSING`, hiding that Intake was valid and Decision dropped context.

## Repair

Patched only:

- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`

Decision repair:

- fixed `_5qNormalizeDraftForLearningDelta(...)` regex escaping so node D parses
- preserved the 5Q17C whole-item fallback and `DRAFT_PREP_NODE_EXCEPTION_FALLBACK` guard
- did not change Sender, autonomous mode, Gate 2, or learning rules

HumanApproval repair:

- added layer-specific diagnostic status:
  - `RAW_WEBHOOK_CONTEXT_MISSING`
  - `INTAKE_MAPPING_CONTEXT_MISSING`
  - `INSTANTLY_HYDRATION_FAILED`
  - `DECISION_CONTEXT_DROPPED`
  - `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`
  - `UNKNOWN`
- preserves upstream evidence in diagnostic context:
  - campaign ID
  - lead email presence
  - sender email presence
  - reply_from_email presence
  - subject presence
  - thread ID presence
  - reply text presence
  - hydration attempted/status
  - upstream error
- Google Chat and the review page now display the diagnostic layer and upstream evidence
- when Intake context exists and Decision emits error-only output, the correction text says this is a workflow defect, not an owner mailbox/thread setup correction

## Production Apply

Guard passed with:

```text
pwsh -File ./scripts/assert-hmz-production-target.ps1
```

Backup:

- `backups/SL-PHASE-5Q17D_20260701_002622/Decision-tgYmY97CG4Bm8snI-before.json`
- `backups/SL-PHASE-5Q17D_20260701_002622/HumanApproval-9aPrt92jFhoYFxbs-before.json`

Version IDs:

- Decision `3b949639-3cf8-4e0e-ab1a-cee3bcb669ef` -> `333e6d60-53e3-4e3b-ad69-5c799c4992bd`, active remained `true`
- HumanApproval `a069be1a-cfc5-4c5e-be9a-e300600aa58f` -> `0fa9d0ce-585e-495e-8af6-dbdb4957ab78`, active remained `true`
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow inactive `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`; no Sender execution or Instantly POST was triggered by apply.

## Harness Results

Post-apply:

- 5Q17D Python: `28/28 PASS`
- 5Q17D PowerShell: `28/28 PASS`
- 5Q17C Python: `24/24 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q11 Python: `24/24 PASS`

Full suite was not run.

## Next Live Action

Owner should create one fresh seeded prospect reply inside the active Instantly campaign-started thread after this 5Q17D apply. Inspect the Google Chat card/review page only.

Do not approve, send, save, click learning-only, or continue self-improvement proof from any diagnostic case. Report the new case ID. Status remains `94` until valid self-improvement override proof succeeds.
