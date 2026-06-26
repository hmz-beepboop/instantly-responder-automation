# Autonomous Incident Response Runbook

**Version:** 1.0  
**Date:** 2026-06-24

---

## Incident Classification

| Level | Definition | Response Time |
|-------|------------|--------------|
| P0 — CRITICAL | Autonomous send to wrong recipient, blocked intent processed, duplicate send, legal/compliance violation | Immediate (< 5 minutes) |
| P1 — HIGH | Bad quality autonomous send, prospect negative reply, unexpected eligibility allowance | Within 1 hour |
| P2 — MEDIUM | Out-of-hours send (if gate fails), post-action review overdue, config change without notification | Within 4 hours |
| P3 — LOW | Repeated low-confidence blocks, out-of-hours candidate volume, digest generation failure | Daily digest review |

---

## P0 Response Procedure

### Immediate (0–5 minutes)

1. **Activate kill switch**
   - Set `emergency_disabled = true` in config
   - If workflow is active: deactivate in n8n UI
   - Confirm kill switch active in config validation

2. **Assess scope**
   - How many sends occurred?
   - Which recipients were affected?
   - What was the content?

3. **Contact affected recipients (if needed)**
   - If wrong recipient: send human apology reply
   - If false business claim: send correction reply
   - If unsubscribe/DNC reached: confirm DNC suppression

4. **Notify escalation channels**
   - Alert escalation_channels with incident summary
   - Include: what happened, what was sent, to whom, when

### Investigation (5–60 minutes)

5. **Audit trail review**
   - Retrieve all audit entries for the incident period
   - Identify the case ID(s) and correlation IDs
   - Trace through all gate evaluations

6. **Root cause identification**
   - Which gate should have blocked the case?
   - Why did the gate fail?
   - Was this a code bug, config error, or edge case?

7. **Scope confirmation**
   - Are any other cases at risk?
   - Scan shadow log for similar cases that may have been allowed

### Resolution (1–24 hours)

8. **Implement fix**
   - Fix the eligibility engine gate that failed
   - Update config if needed (e.g. tighten threshold)
   - Test offline with the specific case type

9. **Acceptance harness**
   ```powershell
   .\scripts\SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1 -RunAll -ExportReport
   ```
   Expected: 45/45 PASS

10. **Create rule candidate**
    - Document the learnt lesson as a rule candidate
    - This prevents the same pattern from being misclassified

11. **Owner sign-off**
    - Owner reviews fix
    - Owner approves re-enable (with reduced cap)

12. **Document in incident log**
    - Full post-incident report in `docs/AUTONOMOUS_INCIDENT_LOG.md`

---

## P1 Response Procedure

1. Complete post-action review form for the affected case
2. Create learning event and rule candidate
3. Review eligibility for the affected intent type
4. Consider reducing confidence threshold or removing intent from allowlist
5. No kill switch required unless pattern is systemic

---

## P2 Response Procedure

1. Investigate the specific condition
2. Document in the daily digest review notes
3. Update config or process to prevent recurrence
4. No kill switch required

---

## Incident Log Format

Create `docs/AUTONOMOUS_INCIDENT_LOG.md` (or append to it):

```markdown
## Incident [ID] — [Date]

**Severity:** P0/P1/P2/P3
**Date/Time:** [UTC]
**Detected by:** [digest/alert/owner/prospect]
**Cases affected:** [case IDs]
**Content sent (if applicable):** [excerpt]
**Recipients affected:** [count, no PII]

### Root Cause
[Description]

### Gate That Failed
[Gate name and why it failed]

### Fix Applied
[Description of fix]

### Acceptance Harness Result After Fix
[X/45 PASS]

### Prevention
[What prevents this recurring]

### Resolution Status
[ ] Kill switch activated
[ ] Affected recipients contacted
[ ] Root cause identified
[ ] Fix applied
[ ] Acceptance harness PASS
[ ] Owner sign-off
[ ] Cap reduced for re-entry
[ ] Incident log updated
```

---

## Related Documents

- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — kill switch
- `docs/AUTONOMOUS_ROLLBACK_DRILL.md` — practice drill
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — failure scenarios
- `docs/AUTONOMOUS_MISTAKE_RESPONSE_POLICY.md` — mistake categorisation
