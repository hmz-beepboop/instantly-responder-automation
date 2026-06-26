# Autonomous Acceptance Test Plan

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** TESTS DEFINED — OFFLINE HARNESS READY

---

## Purpose

Defines the acceptance tests that must pass before any advancement to shadow mode activation or controlled pilot. All tests run offline with no production writes.

---

## Test Categories

### Category A — Config Safety Tests

| Test ID | Test | Expected Result |
|---------|------|----------------|
| A01 | Sample config has autonomous_enabled=false | PASS |
| A02 | Sample config has shadow_only=true | PASS |
| A03 | Sample config has dry_run=true | PASS |
| A04 | Sample config has emergency_disabled=true | PASS |
| A05 | Sample config has campaign_allowlist empty | PASS |
| A06 | Sample config has sender_allowlist empty | PASS |
| A07 | Sample config has intent_allowlist empty | PASS |
| A08 | Sample config has max_autonomous_sends_per_day=0 | PASS |
| A09 | Sample config validates against schema | PASS |
| A10 | Unsafe config (autonomous_enabled=true without required fields) fails validation | PASS |

### Category B — Eligibility Engine Tests

| Test ID | Test | Expected Result |
|---------|------|----------------|
| B01 | All 75 offline scenarios: would_send_live_now=false | PASS |
| B02 | UNSUBSCRIBE intent is permanently blocked | PASS |
| B03 | PRICING_REQUEST intent is permanently blocked | PASS |
| B04 | LEGAL_COMPLAINT intent is permanently blocked | PASS |
| B05 | GDPR_REQUEST intent is permanently blocked | PASS |
| B06 | Multi-intent with one blocked intent blocks whole case | PASS |
| B07 | Low confidence blocks the case | PASS |
| B08 | Out-of-hours candidate is blocked | PASS |
| B09 | Sender not in allowlist blocks the case | PASS |
| B10 | Campaign not in allowlist blocks the case | PASS |
| B11 | INFORMATION_REQUEST with all gates met is SHADOW_LOG eligible | PASS |
| B12 | SCHEDULING_REQUEST with all gates met is SHADOW_LOG eligible | PASS |

### Category C — Workflow Safety Tests

| Test ID | Test | Expected Result |
|---------|------|----------------|
| C01 | Disabled shadow evaluator workflow has active=false | PASS |
| C02 | Disabled workflow has no Sender node | PASS |
| C03 | Disabled workflow has no Instantly API node | PASS |
| C04 | Disabled workflow name contains DISABLED marker | PASS |
| C05 | Disabled workflow has would_send_live_now hardcoded false | PASS |
| C06 | Disabled workflow has shadow_evaluator_mode marker | PASS |

### Category D — Document Completeness Tests

| Test ID | Test | Expected Result |
|---------|------|----------------|
| D01 | Kill switch documented | PASS |
| D02 | Owner approval checklist exists | PASS |
| D03 | Failure modes documented | PASS |
| D04 | Post-action review spec complete | PASS |
| D05 | Follow-up learning spec complete | PASS |
| D06 | Daily digest spec complete | PASS |
| D07 | Audit trail spec complete | PASS |
| D08 | Shadow candidate logging spec complete | PASS |
| D09 | Go/no-go checklist exists | PASS |

### Category E — Schema Validity Tests

| Test ID | Test | Expected Result |
|---------|------|----------------|
| E01 | Config schema is valid JSON | PASS |
| E02 | Sample config is valid JSON | PASS |
| E03 | Shadow log schema is valid JSON | PASS |
| E04 | Daily digest sample is valid JSON | PASS |
| E05 | Review queue sample is valid JSON | PASS |
| E06 | Eligibility decision matrix is valid JSON | PASS |
| E07 | Eligibility summary is valid JSON | PASS |

---

## Overall Acceptance Criteria

Before any mode advancement:
- All Category A tests: 10/10 PASS
- All Category B tests: 12/12 PASS
- All Category C tests: 6/6 PASS
- All Category D tests: 9/9 PASS
- All Category E tests: 7/7 PASS
- Total: 44/44 PASS

**If any test fails, the gap must be remediated before advancing.**

---

## Running the Acceptance Harness

```powershell
.\scripts\SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1 -RunAll -ExportReport
```

See `outputs/autonomous_readiness_acceptance_report.json` for results.

---

## Related Documents

- `scripts/SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1` — the harness
- `outputs/autonomous_readiness_acceptance_report.json` — most recent results
- `docs/AUTONOMOUS_GO_NO_GO_CHECKLIST.md` — go/no-go before each mode
