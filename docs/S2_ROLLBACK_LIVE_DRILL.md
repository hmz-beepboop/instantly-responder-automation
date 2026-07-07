# S2.6 Live Rollback / Deactivation Drill — Owner Runbook

**Created:** 2026-07-07 (Fable Run 4). **Status: NOT YET EXECUTED — owner-live action.**
Offline drill already PASS (harness P20.38–P20.40). This live drill is the last S2.6 step in
`docs/SCALE_READY_ACCEPTANCE_GATES.md`. Do **not** mark S2.6 complete unless a real matching probe
proved the rule no longer applied AND the restore was verified afterwards.

**What this drill proves:** an operator can neutralize a bad learning rule in production by flipping
one DataTable field, with no workflow deploy, and can restore it just as fast.

## Target store

- Q12 rule store: DataTable `sl_rule_candidates`, ID `CSdiTjXfi0tl0oZF`, production n8n
  (`https://n8n.hmzaiautomation.com` → Data Tables UI, or REST `/api/v1/data-tables`).
- Decision consumes only rows with `status` in `{active, effective}`. Any other value
  (`deactivated`, `rejected`, `superseded`) is ignored on the very next case.

## Recommended drill rule

Use classification rule **`6e50fd54-ff2a-4d5a-b220-c0c7374edea4`**
(scope `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` → effective `NON_PRIORITY`). It is the best drill target
because it is live-proven to fire on cheap, safe probe text ("Not now. Maybe later") and its
absence has an obvious, harmless effect (case stays `AMBIGUOUS_SHORT_REPLY` instead of being
promoted to `NON_PRIORITY`).

> **STOP CONDITION — do not proceed if the rule is unclear.** If you cannot positively identify the
> rule row (exact `rule_id`, current `status`, scope fields) in the Data Table UI, stop the drill.
> Do not flip any row you have not fully captured first.

## Step-by-step

### 1. Capture (backup) the exact rule row — BEFORE anything else

Open the row in the n8n Data Table UI (or GET the row via REST) and record ALL of:

- `id` (DataTable row id), `rule_id`, `status` (must currently be `active`),
- `rule_type`, `source_case_id`, `created_at` / any timestamp fields,
- scope fields (original/corrected broad category + micro intent),
- the full instruction/guidance text.

Save this capture (screenshot + paste into this file's Drill Log below). This is your restore source.

### 2. Deactivate

In the Data Table UI, edit ONLY the `status` field of that one row: `active` → `deactivated`.
Change nothing else. (REST alternative: PATCH the row on
`/api/v1/data-tables/CSdiTjXfi0tl0oZF/rows/<row-id>` with body `{"data": {"status": "deactivated"}}` —
UI is preferred; it is harder to fat-finger.)

### 3. Probe

From the owned test lead inbox (`hamzahzahid0@gmail.com`), reply to the existing campaign thread with
an exact known-matching phrase, e.g. `Not now. Maybe later`.

**Expected result (rule OFF):** the new review case shows baseline `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY`
with **no** "Classification corrected by approved learning" block, no rule `6e50fd54` in applied
rules, and NO promotion to `NON_PRIORITY`.

**If the case still shows the correction applied → the drill FAILED. Stop. Restore immediately
(step 4), then open a fault-ledger entry before retrying anything.**

### 4. Restore — immediately after the probe, same session

Edit the same row's `status`: `deactivated` → `active`. Verify in the UI that the value saved and
that every other field still matches your step-1 capture exactly.

### 5. Verify restore with a second probe

Send one more matching probe (e.g. `I can't right now.`). Expected: correction fires again —
effective `AMBIGUOUS / NON_PRIORITY`, rule `6e50fd54` listed as applied, AI draft path as before
(reply_mode `AI_DRAFT_APPROVAL`).

### 6. Record

Fill in the Drill Log below and update `docs/SCALE_READY_ACCEPTANCE_GATES.md` S2.6 and
`docs/RUNTIME_PROOF_CHECKLIST.md` C4 with the date + case IDs. Approve/deny the probe review cases
as normal (deny/learning-only is fine — no send is needed for this drill).

## Stop conditions (abort and restore immediately)

- The rule row cannot be positively identified (see above).
- More than one row shares the target `rule_id`.
- Any field other than `status` changes during the edit.
- The probe case shows ANY unexpected behaviour (wrong classification family, diagnostic fallback,
  missing context) — that is a separate fault, not part of this drill.
- Any real prospect reply arrives mid-drill: restore first, drill later.

## Safety notes

- No workflow deploy, no Sender involvement, no send required. The probe cases stay in normal human
  review; nothing in this drill authorises a send.
- Only ONE rule is flipped, and only its `status` field.
- Total deactivation window should be minutes; do not leave the rule deactivated between sessions.

## Drill Log

| Date | Operator | Rule row captured (y/n) | Probe 1 case (rule off) | Restored (y/n) | Probe 2 case (rule on) | Result |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | NOT YET RUN |
