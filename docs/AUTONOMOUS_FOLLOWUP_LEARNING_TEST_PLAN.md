# Autonomous Follow-Up Learning Test Plan

**Version:** 1.0  
**Date:** 2026-06-24  
**Purpose:** Test plan for learning signal → rule candidate → decision injection cycle

---

## Overview

This plan defines what to test once live shadow traffic provides learning signals. It supplements the offline acceptance harness.

---

## Stage 1 — Shadow Decision Quality Tests

After 14 days of shadow traffic:

| Test | Check | Pass Criteria |
|------|-------|--------------|
| SL-FU-01 | SCHEDULING_REQUEST shadow decisions | All shadow-eligible, none blocked unless risk flag |
| SL-FU-02 | INFORMATION_REQUEST shadow decisions | All shadow-eligible above 0.85 confidence |
| SL-FU-03 | PRICING_REQUEST always blocked | Zero shadow-eligible pricing requests |
| SL-FU-04 | UNSUBSCRIBE always blocked | Zero shadow-eligible unsubscribes |
| SL-FU-05 | AMBIGUOUS_INTENT always blocked | Zero shadow-eligible ambiguous intents |
| SL-FU-06 | OUT_OF_OFFICE handling | No reply drafted — NOOP or suppression only |
| SL-FU-07 | Multi-intent with blocked secondary | Always blocked at top level |

---

## Stage 2 — Rule Candidate Validation

For each proposed rule candidate (RC-SHADOW-001 through RC-SHADOW-003):

| Test | Check |
|------|-------|
| SL-FU-08 | RC-SHADOW-001: Proof requests shadow-log correctly |
| SL-FU-09 | RC-SHADOW-002: OOO handling matches suppression policy |
| SL-FU-10 | RC-SHADOW-003: Allowlist wire-up works for real campaign/sender IDs |

---

## Stage 3 — Gate 2 Pre-Flight

Before owner approves Gate 2:

| Test | Check | Pass Criteria |
|------|-------|--------------|
| SL-FU-11 | Acceptance harness 45/45 PASS | No regressions |
| SL-FU-12 | Shadow evaluator confirms active=false | Not accidentally left active |
| SL-FU-13 | Sample config autonomous_enabled=false | Not changed without approval |
| SL-FU-14 | Campaign allowlist has at least one entry | Required before Gate 2 |
| SL-FU-15 | Sender allowlist has at least one entry | Required before Gate 2 |
| SL-FU-16 | Intent allowlist contains only SCHEDULING_REQUEST + INFORMATION_REQUEST | Initial pilot scope only |

---

## Owner Sign-Off Required Before Any Stage 3 Item

Gate 2 checklist: `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md`

---

## Related Documents

- `docs/AUTONOMOUS_ACCEPTANCE_TEST_PLAN.md` — offline acceptance harness
- `docs/AUTONOMOUS_SHADOW_CANDIDATE_LOGGING_SPEC.md` — logging spec
- `docs/AUTONOMOUS_FOLLOWUP_LEARNING_SPEC.md` — learning loop
- `outputs/autonomous_shadow_learning_signal_preview.json` — current learning signals
