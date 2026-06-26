# Autonomous Shadow Mode Design

**Version:** scaffold-1.0 (Phase 5A)  
**Status:** DESIGN ONLY — Autonomous mode is 0% live. No autonomous sends active.  
**Last updated:** 2026-06-23

---

## Purpose

This document describes the intended design for an out-of-hours autonomous reply layer. Nothing in this document is active in production. The supervised responder remains the only active system.

Autonomous mode will not be enabled until all of the following are separately approved:
- Controlled shadow simulation passes offline ✓ (AS-1 through AS-12, Phase 5A)
- Minimum 30 live manual test cases confirmed without errors in supervised mode
- Working hours config validated in production environment
- Human post-review requirement confirmed technically enforced
- System owner explicit sign-off

---

## Design Principles

1. **Out-of-hours only**: Autonomous action is only considered outside human working hours. During working hours, all replies go to human review regardless of category.

2. **Strict category allowlist**: Only a small set of clearly safe categories are eligible. Default is DENY for any category not on the explicit eligible list.

3. **Always proposed_shadow**: Autonomous draft decisions are stored as `proposed_shadow` status. No rule candidate is promoted to `active` automatically.

4. **Human post-review required**: Every autonomous action must be reviewed by a human after the fact. The system logs all decisions and drafts for review.

5. **Blocked categories are never autonomous**: Unsubscribe, legal, complaint, billing, pricing/negotiation, data/security commitments, contract terms, ambiguous intent — all permanently blocked regardless of context.

6. **No autonomous send**: This scaffold creates the design and offline simulation only. `would_send_autonomously` is always false until explicit activation.

---

## Working Hours Configuration

- **Default (sample):** Mon–Fri, 09:00–18:00 UTC (Europe/London approximate)
- **Out-of-hours window:** Outside the above, including weekends
- **Timezone:** Must be configured per sender before go-live

---

## Eligible Categories (Shadow Simulation)

| Category | Micro-intent | Rationale |
|---|---|---|
| POSITIVE_INTEREST | DISCOVERY_CALL_REQUEST | Simple scheduling — no pricing or commitment |
| POSITIVE_INTEREST | GENERAL_INTEREST | Safe positive acknowledgement |
| INFORMATION_REQUEST | HOW_IT_WORKS_REQUEST | Simple KB-grounded answer |
| INFORMATION_REQUEST | OFFER_EXPLANATION | Simple offer explanation from approved KB |
| SCHEDULING | AVAILABILITY_REQUEST | Propose booking link only |

---

## Always-Blocked Categories

| Category | Notes |
|---|---|
| UNSUBSCRIBE_REQUEST | Hard suppress — human must verify |
| LEGAL_OR_COMPLIANCE | Never autonomous |
| COMPLAINT_OR_HOSTILE | Never autonomous |
| PRICING_OR_COMMERCIAL_NEGOTIATION | Pricing/negotiation — human only |
| DATA_SECURITY_OR_COMPLIANCE_COMMITMENT | Compliance commitment — human only |
| INFORMATION_REQUEST / PROOF_OR_CASE_STUDY_REQUEST | Human judgment on evidence |
| INFORMATION_REQUEST / CONTRACT_TERMS_REQUEST | Legal terms — human only |
| INFORMATION_REQUEST / DATA_SECURITY_REQUEST | Data commitment — human only |
| AMBIGUOUS_OR_SHORT | Unclear intent — human only |
| HIGH_VALUE_CUSTOM | Bespoke request — human only |
| BILLING_DISPUTE | Human only |

Any category not on the eligible list defaults to DENY.

---

## Proposed State Machine (Future)

```
Webhook received
  → Classification
  → Is out-of-hours? NO → human review queue (current system)
  → Is out-of-hours? YES
    → Category eligible? NO → human review queue
    → Category eligible? YES
      → Generate shadow draft (KB-grounded, no invented claims)
      → Store as proposed_shadow
      → Queue for human post-review
      → [FUTURE ONLY: if autonomous mode enabled] → send + log + human post-review required
```

---

## Files

| File | Purpose |
|---|---|
| `scripts/SL-PHASE-5A-autonomous-shadow-simulation-scaffold.ps1` | Offline simulation + eligibility matrix |
| `outputs/autonomous_shadow_decision_matrix.json` | Exported eligibility matrix |
| `docs/AUTONOMOUS_ELIGIBILITY_MATRIX.md` | Human-readable eligibility reference |

---

## Activation Checklist (Future — not started)

- [ ] 30+ live manual test cases confirmed passing in supervised mode
- [ ] Working hours config validated in production
- [ ] Sender config includes timezone for each eaccount
- [ ] Post-review notification mechanism implemented
- [ ] Human post-review queue built and tested
- [ ] System owner explicit sign-off on each eligible category
- [ ] Controlled A/B test design approved (shadow vs human comparison)
- [ ] No-send fallback confirmed working (autonomous draft stored, not sent, if any gate fails)
