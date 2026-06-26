# Autonomous Kill Switch and Rollback

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Kill Switch

### What the kill switch does

Setting `emergency_disabled = true` in the autonomous config immediately halts all autonomous processing. The system will:
- Evaluate no new candidates autonomously
- Send no autonomous replies
- Continue logging all inbound events (supervised path is not affected)
- Surface all pending candidates in the next human review queue
- Continue writing to the daily digest (with a KILL_SWITCH_ACTIVE flag)

The kill switch does NOT affect the supervised path. Reviewers can continue reviewing and approving cases manually through the HumanApproval workflow.

### How to activate the kill switch

**Option 1 — Config file update (if running from config)**
```json
{
  "emergency_disabled": true
}
```
Reload the config. All new evaluations will be blocked.

**Option 2 — n8n workflow disable (if autonomous workflow is active)**
In the n8n UI: Open the autonomous shadow evaluator workflow → Toggle to Inactive.

**Option 3 — Escalation path (if owner is not available)**
The escalation_channels listed in config receive an alert. They can deactivate the workflow in n8n UI without needing API access.

### When to activate the kill switch

Activate immediately if:
- Any autonomous send was sent to the wrong recipient
- Any autonomous send contained invented pricing, false claims, or invented results
- Any autonomous send triggered an unsubscribe, complaint, or hostile reply
- Any autonomous send went to a DNC/unsubscribe contact
- A pattern of bad outputs is detected in the daily digest
- An external actor has flagged an autonomous reply as inappropriate
- The daily cap was exceeded unexpectedly
- The idempotency check failed to prevent a duplicate send

---

## Rollback Procedures

### Rollback 1 — Active rule rollback

If an active rule in Decision node D produced bad outputs:

```powershell
$env:HMZ_N8N_API_KEY = "<from secure store>"
$env:HMZ_PHASE3_PROXY_WRITE_URL = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-write"
.\scripts\SL-PHASE-4I-phase3-proxy-write-repair.ps1 -RollBack -RuleId RC-XXX
```

Verify removal:
```powershell
.\scripts\SL-PHASE-4J-self-improvement-verification-suite.ps1 -RunS7
```

### Rollback 2 — Config rollback

If the autonomous config was changed to enable live sends and must be reverted:

Restore the sample config defaults:
```powershell
.\scripts\SL-PHASE-5B-autonomous-config-and-hours.ps1 -ExportSampleConfig
```

The sample config has `autonomous_enabled = false`, `shadow_only = true`, `dry_run = true`, `emergency_disabled = true`.

### Rollback 3 — Workflow deactivation

If the autonomous shadow evaluator workflow was imported and activated and must be stopped:

In n8n UI: Open workflow → Toggle to Inactive.

The workflow is currently in disabled state (JSON only, not imported to production). If it has been imported and activated, deactivation is immediate and reversible.

### Rollback 4 — Idempotency repair

If a duplicate send occurred despite the idempotency check:
1. Activate kill switch immediately
2. Identify the duplicate case ID in the audit trail
3. Confirm the recipient received two replies by checking Instantly UI
4. If confirmed: draft a short human apology reply and send manually
5. Document in audit trail with `duplicate_send_confirmed = true`
6. Create a rule candidate that tightens the idempotency check for that case type

---

## Post-Incident Procedure

After any autonomous incident requiring the kill switch:

1. **Activate kill switch** — `emergency_disabled = true`
2. **Document the incident** — write to `docs/AUTONOMOUS_INCIDENT_LOG.md` (create if not exists)
3. **Review the audit trail** — identify root cause
4. **Review daily digest** — identify scope of impact
5. **Assess damage** — how many recipients affected? What content?
6. **Create correction events** — for each bad case, create a learning event
7. **Review eligibility engine** — was the gate that should have blocked this case missing?
8. **Update the eligibility engine or config** — tighten the gate
9. **Run acceptance harness** — confirm the fix prevents recurrence
10. **Owner signs off** — before re-enabling autonomous mode
11. **Increase review frequency** — return to higher review cadence after re-enabling

---

## Recovery Criteria

Before re-enabling autonomous mode after a kill switch event:

- [ ] Root cause identified and documented
- [ ] Gate fix applied and tested in eligibility engine
- [ ] Acceptance harness passes all checks
- [ ] Owner reviews fix and signs off
- [ ] Daily cap reduced for initial re-entry (e.g. from 5/day to 1/day)
- [ ] Post-action review frequency increased (every case reviewed, not sample)
- [ ] Kill switch remains readily accessible

---

## Related Documents

- `docs/AUTONOMOUS_SAFETY_MODEL.md` — gate layers
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — specific failure scenarios
- `docs/AUTONOMOUS_INCIDENT_RESPONSE_RUNBOOK.md` — full incident response process
- `docs/AUTONOMOUS_ROLLBACK_DRILL.md` — practice rollback procedure
