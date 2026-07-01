# SL-PHASE-5Q17B Seeded Prospect Context-Missing

Date: 2026-06-30

## Verdict

`case-ed174cd6` was a fresh seeded-prospect campaign-thread event, not only the old diagnostic case.

## 5Q17C Supersession Note

SL-PHASE-5Q17C found that `case-ed174cd6` recurred after this repair because it is the deterministic fallback hash for `UNKNOWN_INTAKE|policy-HMZ-1.2`. 5Q17B correctly identified the first Decision D context drop, but its catch only covered the AI provider/runtime call path. A later node-D exception could still emit n8n's error-only `{ error: "missing / " }`, and HumanApproval then reused the same fallback diagnostic case ID.

5Q17C production-applied a broader Decision D per-item exception fallback and a HumanApproval diagnostic identity repair. Use `reports/SL-PHASE-5Q17C_REPEATED_SEEDED_THREAD_CONTEXT_LOSS.md` as the current source for this incident class.

The fresh execution chain was:

- Intake execution `3726`, started `2026-06-30T15:20:03Z`
- Decision execution `3727`, started `2026-06-30T15:20:04Z`
- HumanApproval execution `3728`, started `2026-06-30T15:20:04Z`

Intake successfully preserved and hydrated the seeded campaign context:

- campaign ID: present, `531e64ed-c225-4baf-97a9-4ec90dc34eb0`
- lead email: present
- sender account: present
- subject: present
- reply text: present
- thread ID: hydrated from Instantly email response
- hydration: attempted, HTTP `200`

Decision received valid context and classified the reply before node `D. Draft Preparation (Templates / Human Draft)` returned only:

```text
error: missing /
```

HumanApproval then correctly created a diagnostic-only context-missing case because Decision returned an error-only payload with no reply context, classification, micro-intent, or draft.

Status remains `94`. This case is not self-improvement proof.

## Root Cause

Category: `G` / Decision dropped valid Intake context.

The owner setup was valid for the fresh event. Intake was not the failing boundary.

The failing boundary was Decision D. A runtime/provider error in the AI-supervised draft-prep path could be surfaced by n8n as a success item containing only `{ error: "missing / " }`, discarding the valid input context. For `AI_SUPERVISED_OR_TEMPLATE` paths such as `OFFER_EXPLANATION`, the deterministic fallback could also be null because no fixed template existed for that micro-intent.

## Repair

Patched only Decision node `D. Draft Preparation (Templates / Human Draft)`:

- Catches AI provider/runtime exceptions around `callAI(...)`.
- Converts those failures into fallback draft attempts instead of error-only output.
- Adds `DRAFT_PREP_EXCEPTION_FALLBACK` / `AI_PROVIDER_RUNTIME_EXCEPTION` attribution.
- Adds a non-null `OFFER_EXPLANATION` fallback draft so valid seeded context can produce a valid review case even when AI drafting fails.

No Intake, HumanApproval, Sender, autonomous, or Gate 2 changes were made.

## Production Apply

- Guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q17B_20260630T154021Z/Decision-before.json`
- Decision versionId: `52753ab6-62f5-4334-9111-6f3f838cd698` -> `90bcfe07-6a61-4e90-aa0f-a8eb8bd388f2`
- Decision active: preserved `true`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- HumanApproval unchanged: `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow Evaluator unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`; no `case-ed174cd6` Sender execution.

## Harness Results

- 5Q17B Python: `23/23 PASS`
- 5Q17B PowerShell: `23/23 PASS`
- 5Q14D Python: `21/21 PASS`
- 5Q14D PowerShell: `21/21 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q16F PowerShell: `22/22 PASS`

PowerShell harnesses were run outside the sandbox because sandboxed `pwsh` is blocked by local snap confinement.

## Next Live Action

Use a seeded prospect already in the active Instantly campaign. Open the prospect inbox and reply inside the existing campaign thread only with:

```text
Could you send me the link to pick a meeting time?
```

Inspect the Google Chat card and review form only. Do not approve, send, save, or click learning-only. Report the new valid case ID.
