# RC-SHADOW-001: Proof Request Policy — Standalone Owner Decision Form

**Version:** 1.0  
**Date:** 2026-06-24  
**Phase:** 5K — Gate 2 Evidence Start  
**Status:** PENDING OWNER SIGN-OFF

---

## Plain-English Explanation

During shadow testing, the system correctly identified replies where a prospect asked for proof — things like:

- "Can you show me a case study?"
- "Do you have any results I can see?"
- "What results have you gotten for similar companies?"

The system flagged these as `PROOF_REQUEST` and routed them to you for human review. That was the correct behaviour.

**The decision you are being asked to make:** Should the controlled pilot (Gate 2) ever be allowed to send an autonomous reply to a proof request?

---

## Context: Why This Matters

If you include `PROOF_REQUEST` in the Gate 2 intent allowlist, the autonomous system may send a reply to a prospect asking for proof — **without you reviewing it first**.

That is only safe if:
1. You have an approved template reply for proof requests that does not make claims you cannot substantiate
2. The template has been reviewed and approved in your knowledge base
3. You are comfortable with that reply going out unsupervised

**As of 2026-06-24:** No approved proof-request template exists in `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`. Proof requests currently require human review.

---

## Recommended Decision

**Defer — keep PROOF_REQUEST as human-only.** Do not include it in the Gate 2 intent allowlist.

Reason: There is no approved template yet. Sending an unsupervised proof-request reply risks making claims you cannot substantiate or sending a generic reply that damages trust with a warm prospect.

---

## Your Options

Mark exactly one:

- [ ] **DEFER** — PROOF_REQUEST stays human-only. Do not include in Gate 2 allowlist. *(recommended)*  
  Effect: Every proof request reply continues to come to you for review. No change from current behaviour.

- [ ] **PERMANENTLY BLOCK** — PROOF_REQUEST is added to the blocked-forever list.  
  Effect: Same as DEFER for now, but signals that proof requests will never be autonomous even in future gates.

- [ ] **APPROVE FOR GATE 2** — PROOF_REQUEST is included in the intent allowlist. *(not recommended without an approved template)*  
  Effect: Autonomous replies may be sent to prospects asking for proof. Only choose this if you have an approved template and accept the risk.

---

## Safety Risk

| Risk Level | Detail |
|-----------|--------|
| Low (DEFER/BLOCK) | No change. Human reviews all proof requests. |
| Medium-High (APPROVE without template) | Autonomous system may send a reply that makes unsupported claims or uses a poorly-calibrated template. |

---

## Impact on Future Autonomous Behaviour

| Your Decision | Effect |
|--------------|--------|
| DEFER | Proof requests stay human-only at Gate 2. Can be revisited at Gate 3 once a template is approved. |
| PERMANENTLY BLOCK | Proof requests are always human-only, even in future gates, until this decision is reversed. |
| APPROVE | Proof request replies eligible for autonomous sending in the controlled pilot. |

---

## WARNING

Signing this form does **not** enable live autonomy. Gate 2 has 6 other blockers that must all be resolved. This form is one input to the Gate 2 process only.

---

## Owner Signature

**Decision selected:** _____________________________

**Reason (optional):** _____________________________

**Owner signature / initials:** _____________________________

**Date signed:** _____________________________

