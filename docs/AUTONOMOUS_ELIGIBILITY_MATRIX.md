# Autonomous Eligibility Matrix

**Status:** DESIGN ONLY — Autonomous mode is 0% live  
**Generated:** 2026-06-23 (Phase 5A shadow scaffold)

See `AUTONOMOUS_SHADOW_MODE_DESIGN.md` for full context.

---

## Eligible (Out-of-hours shadow candidates only)

| Category | Micro-intent | Shadow action |
|---|---|---|
| POSITIVE_INTEREST | DISCOVERY_CALL_REQUEST | SHADOW_ELIGIBLE_OUT_OF_HOURS |
| POSITIVE_INTEREST | GENERAL_INTEREST | SHADOW_ELIGIBLE_OUT_OF_HOURS |
| INFORMATION_REQUEST | HOW_IT_WORKS_REQUEST | SHADOW_ELIGIBLE_OUT_OF_HOURS |
| INFORMATION_REQUEST | OFFER_EXPLANATION | SHADOW_ELIGIBLE_OUT_OF_HOURS |
| SCHEDULING | AVAILABILITY_REQUEST | SHADOW_ELIGIBLE_OUT_OF_HOURS |

During human working hours: `DEFER_TO_HUMAN_IN_HOURS` (even if category is eligible).

---

## Always Blocked

| Category | Micro-intent | Block reason |
|---|---|---|
| UNSUBSCRIBE_REQUEST | * | Hard suppress — human must verify and action |
| LEGAL_OR_COMPLIANCE | * | Never autonomous |
| COMPLAINT_OR_HOSTILE | * | Never autonomous |
| PRICING_OR_COMMERCIAL_NEGOTIATION | * | Pricing/negotiation — human only |
| DATA_SECURITY_OR_COMPLIANCE_COMMITMENT | * | Compliance commitment — human only |
| INFORMATION_REQUEST | PROOF_OR_CASE_STUDY_REQUEST | Human judgment on evidence |
| INFORMATION_REQUEST | CONTRACT_TERMS_REQUEST | Legal terms — human only |
| INFORMATION_REQUEST | DATA_SECURITY_REQUEST | Data commitment — human only |
| AMBIGUOUS_OR_SHORT | * | Unclear intent — human only |
| HIGH_VALUE_CUSTOM | * | Bespoke request — human only |
| BILLING_DISPUTE | * | Human only |
| *(any other)* | * | Default DENY |

`*` = any micro-intent within that category

---

## Simulation Results (Phase 5A)

12/12 scenarios PASS. `would_send_autonomously = false` for all scenarios.  
See `outputs/autonomous_shadow_decision_matrix.json`.
