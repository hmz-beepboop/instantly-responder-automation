# Rule Candidate Review Runbook

**Phase 3 — Rule Candidate Review (Human-gated, read/write only)**
DataTable: `sl_rule_candidates` (ID: `CSdiTjXfi0tl0oZF`)
Script: `scripts/SL-PHASE-3-rule-candidate-review-console.ps1`

---

## What this phase is and is not

**Is:** A structured human review loop to inspect, approve, reject, deprecate, or rollback rule candidates that were shadow-captured from reviewer behaviour. Status changes are DataTable writes only.

**Is not:** Active rule injection. `approved_for_activation` is a staging status. It does NOT inject the rule into Decision, alter AI classification, alter draft logic, or enable autonomous sending. Active injection is a future phase requiring explicit owner approval.

---

## Allowed status values

| Status | Meaning |
|--------|---------|
| `proposed_shadow` | Captured from reviewer behaviour, awaiting review |
| `approved_for_activation` | Reviewed and staged for future injection — inactive |
| `rejected` | Reviewed and rejected, will not be injected |
| `deprecated` | Previously approved but superseded or withdrawn |
| `rolled_back` | Was activated (in a future phase) and rolled back |

---

## Rule types

| type | Source |
|------|--------|
| `style` | Reviewer edited the draft before approving |
| `classification` | Reviewer changed broad category or micro intent |
| `multi_intent_shadow` | Reviewer noted additional intents in the email |

---

## Phase 4I: Proxy write bug fix (SL-PHASE-4I-B)

The "Validate Write" code node now correctly handles all three body formats:
- `Content-Type: application/json` → object body (was broken before Phase 4I)
- `Content-Type: text/plain` → string body (workaround, still works)
- Stringified JSON → string body (parsed correctly)

The `-ApproveCandidate` / `-RejectCandidate` / etc. script commands now work without the `Content-Type: text/plain` workaround. The default `ConvertTo-Json` body format (application/json) works correctly.

---

## One-time setup (required before reads/writes)

The n8n REST API does not expose a DataTable rows endpoint. Reads and writes go through a dedicated proxy workflow with webhook endpoints. Run `-Setup` once to create it:

```powershell
# One-time: create and activate the Phase 3 proxy workflow
# Requires owner confirmation (type YES at prompt)
.\SL-PHASE-3-rule-candidate-review-console.ps1 -Setup

# After setup, store the webhook URLs as env vars (printed by -Setup)
$env:HMZ_PHASE3_PROXY_WEBHOOK_URL = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-read"
$env:HMZ_PHASE3_PROXY_WRITE_URL   = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-write"

# Verify setup
.\SL-PHASE-3-rule-candidate-review-console.ps1 -CheckSetup
```

---

## Commands

```powershell
# List all candidates
.\SL-PHASE-3-rule-candidate-review-console.ps1 -ListCandidates

# Inspect a specific candidate
.\SL-PHASE-3-rule-candidate-review-console.ps1 -ShowCandidate <rule_id>

# Approve (stage for future injection — does NOT activate)
.\SL-PHASE-3-rule-candidate-review-console.ps1 -ApproveCandidate <rule_id> -Reviewer you@example.com -WhatIf
.\SL-PHASE-3-rule-candidate-review-console.ps1 -ApproveCandidate <rule_id> -Reviewer you@example.com

# Reject
.\SL-PHASE-3-rule-candidate-review-console.ps1 -RejectCandidate <rule_id> -Reviewer you@example.com -Reason "Not representative"

# Deprecate (superseded)
.\SL-PHASE-3-rule-candidate-review-console.ps1 -DeprecateCandidate <rule_id> -Reviewer you@example.com -Reason "Superseded by newer rule"

# Rollback (for a future phase where rules were activated)
.\SL-PHASE-3-rule-candidate-review-console.ps1 -RollbackCandidate <rule_id> -Reviewer you@example.com -Reason "Caused misclassification"
```

Always run `-WhatIf` first for any mutating action.

---

## Reviewer discipline

1. Read the full candidate with `-ShowCandidate` before any mutation.
2. Check `proposed_rule_text`, `example_before`, `example_after`, and `reason`.
3. For `multi_intent_shadow`: check that the additional intents are real, distinct, and worth capturing — not noise.
4. For `classification`: confirm the corrected category/micro_intent is correct and not a reviewer error.
5. For `style`: confirm the edited draft represents a genuine improvement in tone, accuracy, or CTA — not just a one-off preference.
6. Only approve candidates that are representative, safe, and clearly correct.
7. If unsure, leave as `proposed_shadow` or reject.
8. Record your reasoning: the `-Reason` field is stored for audit.

---

## Multi-intent shadow candidates

These candidates have `rule_type: multi_intent_shadow`. They record that a prospect asked more than one thing. Review them as follows:

- Check `micro_intent_scope` — the format is `primary_intent | additional_intents`.
- Confirm the additional intents are real (e.g., prospect actually asked about scope AND pricing).
- Approve if the multi-intent pattern is real and worth learning from.
- Reject if additional_intents_shadow was a reviewer entry error.
- These candidates do not affect routing or drafting today even if approved.

---

## Safety rules

- Never skip `-WhatIf` for bulk operations.
- Never approve candidates you have not read.
- `approved_for_activation` is a staging status only — confirm with the team before running any active rule injection phase.
- Active rule injection requires a separate script, separate review, and explicit owner sign-off.
- Autonomous sending is NOT enabled by any action in this script.
- The production n8n target is `https://n8n.hmzaiautomation.com/api/v1`. Never run against localhost.

---

## Rollback procedure

If a candidate was incorrectly approved:

1. `.\SL-PHASE-3-rule-candidate-review-console.ps1 -RollbackCandidate <rule_id> -Reviewer you@example.com -Reason "<why>"`

If active injection was already performed (future phase), additional steps will be defined in that phase's runbook. Rollback here only changes the DataTable status.

---

## When to review

Review the candidate list after each batch of human approvals (e.g., weekly or after 5+ approvals). Look for:

- Patterns across multiple cases that suggest a reliable rule.
- Candidates with `confidence: low` that do not yet meet the bar for approval.
- `multi_intent_shadow` candidates from the same prospect category that together suggest a common multi-intent pattern.

---

## Active rule injection (not yet enabled)

When the team decides to inject approved rules into the Decision workflow:

1. A separate injection script will be created and reviewed.
2. The script will require: a list of `approved_for_activation` rule IDs, explicit owner approval, a controlled test run, and a rollback plan.
3. No injection script exists in Phase 3. Do not attempt manual injection.
