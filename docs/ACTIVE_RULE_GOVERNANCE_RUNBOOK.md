# Active Rule Governance Runbook

**Status:** SCAFFOLD ONLY — No active rules exist. Phase 4D required for injection.  
**Last updated:** 2026-06-23 (SL-PHASE-4C batch)  
**Script:** `scripts/SL-PHASE-4C-active-rule-governance-scaffold.ps1`

---

## What "Approved for Activation" Means (and Doesn't Mean)

`approved_for_activation` is a **review status** in `sl_rule_candidates`. It means a human reviewer has marked a rule candidate as eligible for future activation.

**It does NOT:**
- Inject anything into the Decision workflow
- Alter AI behaviour, classification logic, or routing
- Enable autonomous sending
- Change operating mode or any safety gate

**Active injection requires Phase 4D**, which is a separate implementation phase requiring explicit owner approval. No active rules exist today.

---

## Governance Requirements (Must Be Met Before Any Activation)

1. **Human-approved only.** Only candidates with `status = approved_for_activation` (set by a named human reviewer) may become active rules. The system must never auto-promote candidates.

2. **Versioned and reversible.** Every active rule must carry a version ID, activation timestamp, and reviewer name. Rollback must restore previous behaviour without a full workflow redeploy.

3. **Conflict detection must pass.** Before activating any rule, run `-DetectRuleConflicts`. All BLOCK-severity conflicts must be resolved. WARNING-severity conflicts must be reviewed.

4. **No weakening of safety gates.** Active rules must not:
   - Lower confidence thresholds for sending
   - Bypass DRY_RUN, LIVE_CAMPAIGNS, or duplicate-check gates
   - Reduce suppression coverage (unsubscribe, hostile, legal, compliance)
   - Enable sending without human approval in VALIDATION mode

5. **Supervised drafts only, first.** The first active rules may only add context to the AI prompt for supervised drafting. They must not change routing, classification, or suppression.

6. **No autonomous sending.** Active rules in Phase 4D/4E do not enable autonomous sending. Autonomous mode requires Phase 5/6 (separate, explicit owner approval, clean shadow run, compliance review).

---

## Script Usage

### Prerequisites

```powershell
# Proxy must be running (set up via Phase 3 console):
$env:HMZ_N8N_API_KEY = "<your key>"
$env:HMZ_PHASE3_PROXY_WEBHOOK_URL = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-read"

Set-Location "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
```

### Safety check (always run first)

```powershell
.\scripts\SL-PHASE-4C-active-rule-governance-scaffold.ps1 -WhatIf
```

### List candidates with approved_for_activation status

```powershell
.\scripts\SL-PHASE-4C-active-rule-governance-scaffold.ps1 -ListApprovedForActivation
```

### Preview what active rules would look like (read-only)

```powershell
.\scripts\SL-PHASE-4C-active-rule-governance-scaffold.ps1 -PreviewActiveRules
```

### Detect conflicts before any activation

```powershell
.\scripts\SL-PHASE-4C-active-rule-governance-scaffold.ps1 -DetectRuleConflicts
```

Conflicts are categorised as:
- **BLOCK**: Must be resolved before any activation. Examples: unsafe wording (autonomous, guarantee, bypass approval), pricing figures.
- **WARNING**: Must be reviewed before activation. Example: multiple rules for same scope.

### Export proposed active rules to local file (no production write)

```powershell
.\scripts\SL-PHASE-4C-active-rule-governance-scaffold.ps1 -ExportProposedActiveRulesJson
# Output: outputs/proposed_active_rules_preview.json
```

The export file is a local preview only. It is NOT loaded into production and has no effect on AI behaviour.

---

## Before Any Owner Approves a Candidate

Use the Phase 3 console:

```powershell
# List all candidates (read-only):
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -ListCandidates

# Show detail for a specific candidate:
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -ShowCandidate <rule_id>

# Approve (sets status to approved_for_activation only — not injected):
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 `
    -ApproveCandidate <rule_id> -Reviewer "you@example.com" -WhatIf
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 `
    -ApproveCandidate <rule_id> -Reviewer "you@example.com"
```

After approving, run conflict detection:

```powershell
.\scripts\SL-PHASE-4C-active-rule-governance-scaffold.ps1 -DetectRuleConflicts
```

---

## Activation Phases (Future)

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 3** | Review candidates, set approved_for_activation | READY (proxy set up 2026-06-23) |
| **Phase 4C** | Governance scaffold, conflict detection, export preview | DONE (2026-06-23) |
| **Phase 4D** | Supervised prompt injection from approved rules | NOT IMPLEMENTED |
| **Phase 4E** | Monitored retest (offline harness + controlled live test) | NOT IMPLEMENTED |
| **Phase 5** | Autonomous shadow simulation (log only, never transmit) | NOT IMPLEMENTED |
| **Phase 6** | Limited out-of-hours autonomous pilot (explicit owner approval required) | NOT IMPLEMENTED |

**Autonomous mode remains OFF.** Do not skip phases.

---

## What the Governance Scaffold Does Not Do

- Does not inject rules into Decision.
- Does not modify any production n8n workflow.
- Does not change AI prompts.
- Does not change routing or suppression logic.
- Does not enable autonomous sending.
- Does not modify rule candidates (read-only).
- Only writes one local file (`outputs/proposed_active_rules_preview.json`) when `-ExportProposedActiveRulesJson` is used.

---

## Key Files

| File | Purpose |
|------|---------|
| `scripts/SL-PHASE-3-rule-candidate-review-console.ps1` | Review and approve/reject candidates |
| `scripts/SL-PHASE-4C-active-rule-governance-scaffold.ps1` | Conflict detection + preview export |
| `docs/ACTIVE_RULE_INJECTION_PLAN.md` | Full phase roadmap and governance rules |
| `outputs/proposed_active_rules_preview.json` | Local preview export (not production) |
