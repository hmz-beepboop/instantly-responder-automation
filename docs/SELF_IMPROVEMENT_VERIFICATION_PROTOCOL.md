# Self-Improvement Verification Protocol

**Version:** SL-PHASE-4J-1.0  
**Date:** 2026-06-23  
**Status:** ACTIVE — installed infrastructure, manual live proof pending

---

## Purpose

This document defines how to verify that the HMZ Instantly Responder is actually self-improving — not merely capturing data. The distinction matters: infrastructure can be 100% installed while behavioural improvement remains unproven until live before/after tests confirm that future drafts change in the intended direction.

---

## The 10-Stage Loop

A complete self-improvement cycle requires all 10 stages to fire end-to-end:

| Stage | Description | Infrastructure status |
|-------|-------------|----------------------|
| 1 | Draft revision captured | INSTALLED (SL-P2A draft_original/draft_approved fields) |
| 2 | Human edit captured | INSTALLED (SL-P2A diff capture, SL-P2B intent shadow) |
| 3 | Classification correction captured | INSTALLED (Phase 1C correction capture) |
| 4 | Additional intent edits captured | INSTALLED (Phase 4F/4G/2B additional_intents shadow) |
| 5 | Rule candidate created as proposed_shadow | VERIFIED (RC-001, RC-005, RC-002 rejected — Phase 4D) |
| 6 | Human-approved candidate becomes approved_for_activation | VERIFIED (RC-001 and RC-005 approved, others rejected) |
| 7 | Active rule injected into supervised AI (Decision node D) | VERIFIED (RC-001 + RC-005 text in node D — Phase 4D) |
| 8 | Similar future email receives improved draft/classification | STATIC_VERIFIED — **manual live test required** |
| 9 | Safety gates still override active rules | VERIFIED (deterministic gates precede AI in node D) |
| 10 | Human can reject/deprecate/rollback later | VERIFIED (proxy write accepts rolled_back/deprecated) |

---

## Pass/Fail Thresholds

### Installed Complete
All infrastructure stages (1–7, 10) are present. Does **not** require behavioural proof.
- **Current status: TRUE** (as of Phase 4J)

### Verified Complete
At least 3 live before/after behaviour proofs across different categories, AND stage 8 score ≥ 7/10.
- **Current status: FALSE** — stage 8 manual live tests not yet run
- See `docs/NEXT_MANUAL_TEST_PACKET_SELF_IMPROVEMENT_PROOF.md`

### Not Complete
If only capture exists but future drafts do not improve — this is a failure of the loop, not just an incomplete stage.

---

## Dimension Scores

| Dimension | What it measures | Pass threshold |
|-----------|-----------------|----------------|
| Capture score | Stages 1–4 average — are edits being recorded? | ≥ 7/10 |
| Candidate generation | Stage 5 — are rule candidates created? | ≥ 8/10 |
| Review/approval | Stage 6 — does the approval gate work? | ≥ 8/10 |
| Active injection | Stage 7 — do approved rules reach the AI? | ≥ 8/10 |
| Behavioural improvement | Stage 8 — do future drafts actually change? | ≥ 7/10 **MANUAL PROOF** |
| Safety preservation | Stage 9 — do deterministic gates still win? | 10/10 required |
| Rollback readiness | Stage 10 — can bad rules be removed? | ≥ 8/10 |
| Overall confidence | Weighted average | ≥ 7/10 for Verified |

---

## How to Run the Verification Suite

```powershell
cd "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"

# Preview what will be checked (no API calls)
.\scripts\SL-PHASE-4J-self-improvement-verification-suite.ps1 -WhatIf

# Full audit with known cases + export scorecard
.\scripts\SL-PHASE-4J-self-improvement-verification-suite.ps1 `
  -AuditLearningTables `
  -AuditRuleLifecycle `
  -PreviewBeforeAfterImprovement `
  -UseKnownCases `
  -ExportScorecard
```

Requires `HMZ_N8N_API_KEY` set.

---

## Evidence Base (Current)

### Stage 5–6 VERIFIED: Rule candidate lifecycle
- RC-001 `PROOF_REQUEST` guidance: proposed → approved_for_activation → active
- RC-005 `PRICING_REQUEST` suppression: proposed → approved_for_activation → active
- RC-002 / RC-003 / RC-004 / RC-006: rejected — proves selective approval works

### Stage 7 VERIFIED: Active rule injection
- Decision workflow `tgYmY97CG4Bm8snI` node D contains RC-001 and RC-005 guidance text
- Injected Phase 4D (`85f51eb4-bf8f-4d17-9883-52d7c2f11225`)
- Harness: 28/28 PASS (Phase 4D) → 40/40 (Phase 4E) → 55/55 (Phase 4F) → 65/65 (Phase 4G)

### Stage 8 STATIC_VERIFIED: Before/after improvement (pending manual proof)
- RC-001 before: no special guidance for proof requests — AI could invent examples
- RC-001 after: AI instructed to acknowledge validation stage, not invent results
- RC-005 before: PRICING_REQUEST could fire for broad capability questions
- RC-005 after: AI guided to prefer DISCOVERY_CALL/GENERAL_INTEREST for non-pricing questions

### Stage 10 VERIFIED: Rollback
- Proxy write endpoint (`seB6ZmlyomhC4QWU`, Phase 4I-B) accepts `rolled_back`, `deprecated`, `rejected`
- No rule is permanent — human can deprecate at any time

---

## Known Issues

1. **Stage 8 not live-proven** — requires manual test packet execution
2. **Stage 1–4 DataTable IDs** for `hmz-learning-events` and `hmz-rule-candidates` need confirmation in n8n before live row audit
3. **Overall confidence score limited** until stages 1–4 live audit completes

---

## What "Verified Complete" Requires

1. Run the 4 manual tests from `docs/NEXT_MANUAL_TEST_PACKET_SELF_IMPROVEMENT_PROOF.md`
2. Confirm draft wording changed for RC-001 test (proof/examples category)
3. Confirm classification changed for RC-005 test (non-pricing capability question)
4. Confirm correction feedback created a new proposed_shadow candidate
5. Re-run the suite with `-PreviewBeforeAfterImprovement -UseKnownCases -ExportScorecard`
6. Stage 8 score must reach ≥ 7/10
