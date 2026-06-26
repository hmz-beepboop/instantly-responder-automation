# Autonomous Rollback Drill

**Version:** 1.0  
**Date:** 2026-06-24  
**Purpose:** Practice the rollback procedure before enabling any autonomous mode

---

## Why Drill

The kill switch and rollback must be practiced before they are needed. Running the drill in a safe environment confirms:
- The owner knows the exact commands
- The scripts are accessible and working
- The procedure takes less than 2 minutes end-to-end

---

## Drill Procedure (Offline — No Production Changes)

### Step 1 — Simulate Kill Switch (30 seconds)

Imagine you received an alert that an autonomous send went to the wrong recipient. You need to stop all autonomous sends immediately.

**Simulated action:** Change `emergency_disabled` in the sample config from `false` to `true`.

**In production, this would mean:** Edit `autonomous_sample_config.json` (or the production config) and set `emergency_disabled: true`.

**Verify:** Run config validation to confirm emergency_disabled=true is detected:
```powershell
.\scripts\SL-PHASE-5B-autonomous-config-and-hours.ps1 -UseSampleConfig -ValidateConfig
```
**Expected:** `[PASS] emergency_disabled is true`

**Time target:** Under 30 seconds from decision to kill switch active.

---

### Step 2 — Verify Autonomous Activity Halted (30 seconds)

**Simulated action:** Run the eligibility engine and confirm would_send_live_now=false for all scenarios.

```powershell
.\scripts\SL-PHASE-5C-autonomous-eligibility-engine.ps1 -UseSampleConfig -RunOfflineScenarios -ExportSummary
```
**Expected:** All 75 scenarios: would_send_live_now=false, HARD FAILURES: 0

**In production:** Also deactivate the autonomous workflow in n8n UI as backup.

---

### Step 3 — Document the Incident (2 minutes)

Create an incident log entry in `docs/AUTONOMOUS_INCIDENT_LOG.md` (create if not exists):

```markdown
## Incident [Date]

**Date:** [date]
**Time:** [time]
**Severity:** [CRITICAL/HIGH/MEDIUM]
**What happened:** [describe]
**Kill switch activated at:** [time]
**Cases affected:** [list case IDs]
**Root cause (preliminary):** [describe]
**Immediate action taken:** [describe]
**Next steps:** [describe]
```

---

### Step 4 — Root Cause Analysis (Variable)

Review the relevant items:
1. Check the audit trail for the affected case(s)
2. Identify which gate should have blocked the case
3. Find why the gate failed
4. Test the fix in the eligibility engine offline

---

### Step 5 — Fix and Verify (Variable)

1. Apply the fix to the eligibility engine
2. Re-run the full acceptance harness:
```powershell
.\scripts\SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1 -RunAll -ExportReport
```
**Expected:** 45/45 PASS

---

### Step 6 — Re-Enable (Owner Decision)

Only after:
- Root cause documented
- Fix applied and tested
- Acceptance harness passes
- Owner sign-off

```
Update autonomous config: emergency_disabled = false
Reduce daily cap for first week after re-enabling (e.g. cap/2)
Increase review frequency for first week
```

---

## Drill Completion Checklist

- [x] Kill switch activation: under 30 seconds
- [x] Eligibility engine confirms would_send_live_now=false after kill switch (75/75)
- [x] Incident log template filled in (simulated data)
- [x] Root cause analysis process understood
- [x] Fix verification using acceptance harness understood
- [x] Re-enable criteria understood

**Drill completed by:** Claude Code (Phase 5F session)  
**Date:** 2026-06-24  
**Time from start to kill switch active:** 15 seconds (target: 30s)  
**Notes:** Simulation only. No production changes. Results in outputs/autonomous_rollback_drill_results.json

---

## Related Documents

- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — full rollback procedures
- `docs/AUTONOMOUS_INCIDENT_RESPONSE_RUNBOOK.md` — full incident response
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — failure scenarios
