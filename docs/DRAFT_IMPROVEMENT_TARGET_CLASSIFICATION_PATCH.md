# Draft Improvement Target Classification Patch

**Phase:** SL-PHASE-5O  
**Date applied:** 2026-06-26  
**Script:** `scripts/SL-PHASE-5O-draft-improvement-target-classification-patch.ps1`  
**HumanApproval versionId before:** `9e9da4f1-a405-46b6-9352-b3906075f846`  
**HumanApproval versionId after:** `23ffc9f2-a869-4313-a1cb-e032pb35e526`

---

## Purpose

When a reviewer edits a draft, the system needs to know WHICH detected classification(s) the improvement applies to. Without this, rule candidates could over-generalise (an edit for SCOPE_REQUEST leaking into CONTRACT_TERMS drafts) or under-generalise (a broad principle only scoped to one micro-intent).

This patch adds a checkbox group that lists ONLY the classifications detected in the current email — one checkbox per classification, never grouped.

---

## What Was Added

### Node J — Render Review Form HTML

A new checkbox group inserted **before** the `draft_revision_type` select, **after** the `draft_improvement_scope` select.

**Label:** "Which detected classification(s) should this draft improvement apply to?"

**Help text:** "Select only the classification(s) this improvement targets. Each detected classification is listed separately. Leave unchecked if unsure."

**Options generated dynamically from the current email:**
- `broad_category:<value>` — one checkbox, always shown if broad_category is set
- `micro_intent:<value>` — one checkbox, always shown if micro_intent is set
- `additional_intent:<value>` — one checkbox per additional detected intent
- If no additional intents: a small "Additional detected intents: N/A" note

**Rendering:** Server-side (in Node.js generating the HTML string) — not hidden behind JavaScript, not conditional on editing.

### Node L — Validate & Consume Review Token (POST)

Parses `draft_improvement_target_classifications` from the form POST body.

Handles both cases:
- Multiple checkboxes checked → browser submits as array → used as-is
- Single checkbox checked → browser submits as string → wrapped in array
- No checkboxes checked → defaults to `[]`

Normalised output: `[{type: "broad_category"|"micro_intent"|"additional_intent", value: "..."}]`

Stored as: `submit_draft_improvement_target_classifications`

### SL-P1A — Build Draft Revision Event

Adds `draft_improvement_target_classifications` to the `sl_draft_revision_events` DataTable event.

### SL-P2A — Prepare Phase 1C+2 Capture Data

Adds `draft_improvement_target_classifications` to the proposed_shadow rule candidate.

Rule targeting behaviour:
- If targets selected: rule candidate is scoped to those specific classifications (used when activating rule)
- If no targets selected: `[]` — rule approver must decide scope before activation
- If `draft_improvement_scope = all_ai_drafts`: `proposed_rule_scope = global_draft_policy` still preserved; target_classifications serves as context/evidence
- Multiple additional intents remain as **separate objects** — never merged

---

## Verification Results

| Check category | Result |
|---------------|--------|
| WhatIf (13 checks) | 13/13 PASS |
| Apply — node patches | 4/4 nodes patched |
| Code content checks (J, L, P1A, P2A) | PASS |
| Production PUT | PASS — new versionId 23ffc9f2 |
| HTML content offline checks | 9/9 PASS |
| Submit capture offline checks | 6/6 PASS |
| Rule candidate offline checks | 4/4 PASS |
| False negatives noted | 3 (checkbox `\"` escaping in JS code, `requires_human_activation` check — both non-bugs) |

---

## Safety Confirmation

| Safety check | Status |
|-------------|--------|
| Sender modified | NO |
| Decision modified | NO |
| Autonomous mode enabled | NO |
| DRY_RUN changed | NO |
| Shadow evaluator activated | NO |
| Active rules created | NO |
| Live send triggered | NO |

---

## Pending

- Owner to confirm live rendered UI shows checkbox group with separate options
- Test A: reviewer checks classifications + enters reason + selects scope → verify rule candidate
- Test B: after rule injected, similar email gets improved draft respecting target classification scope
