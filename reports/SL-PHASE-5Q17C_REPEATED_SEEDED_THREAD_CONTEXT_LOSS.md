# SL-PHASE-5Q17C Repeated Seeded-Thread Context Loss

Date: 2026-06-30

## 5Q17D Supersession Note

5Q17C correctly repaired the diagnostic case-ID collision and added a node-D fallback, but `case-2c7e1ff0` later proved a post-5Q17C Decision D parse-time defect. 5Q17D fixed the malformed `_5qNormalizeDraftForLearningDelta(...)` regex that caused `missing /` before runtime fallback code could execute, and added layer-specific HumanApproval diagnostics. Current production versions after 5Q17D are Decision `333e6d60-53e3-4e3b-ad69-5c799c4992bd` and HumanApproval `0fa9d0ce-585e-495e-8af6-dbdb4957ab78`.

## Verdict

COMPLETE. The repeated diagnostic `case-ed174cd6` was a workflow bug, not an owner setup issue.

`case-ed174cd6` is exactly the deterministic fallback case ID for:

```text
case- + djb2("UNKNOWN_INTAKE|policy-HMZ-1.2")
```

That means any HumanApproval create path receiving no real `intake_id` could overwrite the same diagnostic review row. Three post-5Q17B chains showed the collision:

- `3736` -> `3737` -> `3738`, HumanApproval created `case-ed174cd6`, token expiry `2026-06-30T16:51:18.915Z`
- `3739` -> `3740` -> `3741`, HumanApproval created `case-ed174cd6`, token expiry `2026-06-30T16:53:10.997Z`
- `3742` -> `3743` -> `3744`, HumanApproval created `case-ed174cd6`, token expiry `2026-06-30T16:54:53.166Z`

Tokens existed and rotated on each overwrite, but the row identity did not. Token values were not printed.

## Latest Event Trace

Latest chain:

- Intake `3742`, started `2026-06-30T15:54:52.453Z`
- Decision `3743`, started `2026-06-30T15:54:52.798Z`
- HumanApproval `3744`, started `2026-06-30T15:54:53.116Z`

Intake had valid seeded campaign-thread context:

- raw webhook payload present
- event type `reply_received`
- campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0`
- lead email present
- sender account present
- subject `Re: Capacity Question`
- reply text present
- Instantly hydration attempted
- Instantly hydration HTTP `200`
- hydrated thread ID `53-RKIOlX32DrLO3dLAoGwdkoG`

Decision received valid context through node C:

- intake ID present
- reply_from_email present
- sender_email present
- subject present
- thread_id present
- reply_text present
- classification `INFORMATION_REQUEST`
- micro-intent `OFFER_EXPLANATION`

Decision node D still returned only:

```text
{ "error": "missing / " }
```

HumanApproval then correctly treated that error-only payload as diagnostic-only, but incorrectly reused fallback identity `UNKNOWN_INTAKE`, producing `case-ed174cd6` again.

## Root Cause

Category: Decision context drop plus HumanApproval diagnostic identity collision.

The owner's seeded campaign-thread claim is supported by production evidence. Intake preserved and hydrated the seeded campaign context. The failure boundary was Decision node D. The 5Q17B patch caught AI provider/runtime failures around `callAI(...)`, but did not guard the whole node-D item body. A later node-D exception could still be converted by n8n `onError=continueRegularOutput` into an error-only item and discard the valid Intake context.

HumanApproval had a separate collision defect: if upstream context was already lost, it used:

```text
UNKNOWN_INTAKE|policy-HMZ-1.2
```

as the case ID seed, so repeated diagnostic events overwrote the same review case.

## Repair

Patched only:

- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`

Decision D now has a per-item last-resort exception fallback. If any node-D exception escapes the normal draft path, it emits:

- original `nes` context
- preserved classification and micro-intent
- supervised fallback `draft_text`
- `DRAFT_PREP_NODE_EXCEPTION_FALLBACK` attribution
- `human_review_required=true`
- `external_action_status=NOT_PERFORMED`

HumanApproval now creates a unique diagnostic fallback intake seed only when no real Intake ID exists:

```text
DIAGNOSTIC_MISSING_INTAKE_<timestamp>_<random>
```

Valid cases with real Intake IDs keep the existing stable case-ID scheme.

## Production Apply

Guard passed with:

```text
pwsh -File ./scripts/assert-hmz-production-target.ps1
```

Backup:

- `backups/SL-PHASE-5Q17C_20260630T160715Z/Decision-before.json`
- `backups/SL-PHASE-5Q17C_20260630T160715Z/HumanApproval-before.json`

Version IDs:

- Decision `90bcfe07-6a61-4e90-aa0f-a8eb8bd388f2` -> `3b949639-3cf8-4e0e-ab1a-cee3bcb669ef`, active remained `true`
- HumanApproval `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200` -> `a069be1a-cfc5-4c5e-be9a-e300600aa58f`, active remained `true`
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow unchanged/inactive `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`; no Sender execution or Instantly POST was triggered.

## Harness Results

- 5Q17C Python: `24/24 PASS`
- 5Q17C PowerShell: `24/24 PASS`
- 5Q17B Python: `23/23 PASS`
- 5Q17B PowerShell: `23/23 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q16F PowerShell: `22/22 PASS`
- 5Q11 Python: `24/24 PASS`
- 5Q11 PowerShell: `24/24 PASS`

Full suite was not run.

## Next Live Action

Use a fresh seeded prospect already in the active Instantly campaign. Reply inside the existing campaign thread and inspect the Google Chat card/review page only.

Do not approve, send, save, or click learning-only. Report the new case ID. Status remains `94` until valid self-improvement override proof succeeds.
