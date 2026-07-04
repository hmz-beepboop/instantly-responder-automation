# SL-PHASE-5Q Live Behavioural Verification
**Created:** 2026-07-04 (session 3 — 5Q-LIVE-REGRESSION repair)  
**Decision versionId:** `a3916c2e` (confirmed in all Variant B executions)  
**HumanApproval versionId:** `849c2c64` (live regression repair applied 2026-07-04)

---

## Variant B Execution Trace Results

All 4 Variant B cases ran against Decision versionId `a3916c2e` (confirmed via n8n API).

### Case 1 — Booking request (exec 4846)
**Reply:** "Is there a link where I can book a quick walkthrough?"  
**Expected classification:** INFORMATION_REQUEST / BOOKING_REQUEST  
**Actual classification:** INFORMATION_REQUEST / OFFER_EXPLANATION  
**Booking rule 97eb3b0a applied:** NO — wrong classification scope  
**Setup rule 48e10cac applied:** YES — misclassification caused setup guidance to apply  
**Draft observed:** Booking link + 3-step setup process  

**Root cause:** AI misclassified "walkthrough" as a product explanation (OFFER_EXPLANATION) rather than a booking request (BOOKING_REQUEST). The booking post-processor (GAP-1 fix) was not triggered because the wrong micro-intent was set. Setup guidance from rule 48e10cac bled into the booking draft.

**Classification fix needed:** Not a deterministic code bug — AI classification prompt gap. Options: (a) improve AI classification prompt to distinguish walkthrough/booking from setup explanation, (b) add classification correction rule for this case, (c) accept as ambiguous and handle via review form.

**Verdict:** STALE with respect to GAP-1. GAP-1 fix is correct but was not reached due to upstream classification error. Decision patch scope: classification prompt or correction rule — NOT the post-processor.

---

### Case 2 — Setup/process breakdown (exec 4855)
**Reply:** "Before I book, can you give me a quick breakdown of what you actually set up?"  
**Actual classification:** INFORMATION_REQUEST / OFFER_EXPLANATION  
**Draft observed:** "Absolutely. Here's the setup in simple terms: 1..."  

**Root cause:** Correct classification. Setup rule 48e10cac applied. Draft shows setup steps before CTA.  
**Verdict:** PASS — broadly acceptable. No leakage of booking or pricing guidance detected.

---

### Case 3 — Not-now / later (exec 4859)
**Reply:** "This could be useful, but realistically, we would not review something like this until later in the quarter."  
**Actual classification:** AMBIGUOUS / AMBIGUOUS_SHORT_REPLY  
**After correction (rule 6e50fd54):** NON_PRIORITY → NOT_NOW template used ✓ (GAP-3 working)  
**cdada69d style rule 97eb3b0a applied:** Eligible, but post-processing did NOT modify draft  
**Draft observed:** "Understood. I'll close the loop for now. Feel free to reach out if the timing changes."  

**Root cause:** GAP-3 fix correctly routes NON_PRIORITY → NOT_NOW FIXED_TEMPLATE. cdada69d IS eligible. But the post-processor `_5qApplyActiveFormRuleInstructionToDraft` has no handler for style rules on NOT_NOW templates — it only handles BOOKING_REQUEST/MEETING_TIME_REQUEST. The guidance (ask when to check back) is built but never consumed by the NOT_NOW template path.

**Remaining gap — GAP-3b:** cdada69d post-processing is unimplemented for NOT_NOW style rules. The base NOT_NOW template produces "close the loop" but does not ask "when to check back."

**Decision patch required:** Narrow patch to NOT_NOW post-processing path to consume cdada69d style guidance (e.g. append "When would be a better time to reconnect?" or equivalent). Must not use cdada69d's instruction text verbatim in draft. Must use an approved follow-up question. Requires anti-false-positive verification.

**Verdict:** FAIL — owner live retest still required after GAP-3b patch.

---

### Case 4 — Pricing / minimum commitment (exec 4865)
**Reply:** "Before scheduling, can you tell me what the lowest commitment would be to try this?"  
**Expected classification:** PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST  
**Actual classification:** INFORMATION_REQUEST / OFFER_EXPLANATION  
**Pricing rule 493884ad applied:** NO — wrong classification scope  
**Setup rule 48e10cac applied:** YES — misclassification caused setup guidance to apply  
**Draft observed:** "The lowest commitment is a short setup phase so we can confirm fit before anything broader..." + 3-step process  

**Root cause:** AI misclassified "lowest commitment" as an offer explanation request. The pricing post-processor (GAP-2 fix, `_5qApplyPricingConstraints`) was not triggered. Setup guidance applied instead. Draft answered "lowest commitment = short setup phase" which is derived from setup guidance, not an actual pricing/commitment answer.

**Assessment:** While the draft is not fabricating invented prices (which is good), it's deflecting into setup process instead of answering the pricing/commitment question directly. The GAP-2 fix is correct but was not reached due to upstream classification error.

**Classification fix needed:** AI classification prompt or correction rule for pricing/commitment questions that get classified as OFFER_EXPLANATION. Not a post-processor bug.

**Verdict:** STALE with respect to GAP-2. Decision patch scope: classification prompt or correction rule.

---

## Summary of Variant B Live Triage

| Case | Version | Rule applied | Classification correct | Draft correct | Gap |
|------|---------|-------------|----------------------|---------------|-----|
| Booking | a3916c2e ✓ | 48e10cac (wrong) | NO — OFFER_EXPLANATION | PARTIAL | Classification bug |
| Setup/process | a3916c2e ✓ | 48e10cac (correct) | YES | YES | None |
| Not-now | a3916c2e ✓ | cdada69d (eligible, not consumed) | YES (after correction) | FAIL | GAP-3b: NOT_NOW post-processing |
| Pricing | a3916c2e ✓ | 48e10cac (wrong) | NO — OFFER_EXPLANATION | FAIL | Classification bug |

---

## Decision Patch Scope Required

### GAP-3b — PATCHED (session 4)
**Fix applied:** `_5qApplyActiveFormRuleInstructionToDraft` now has a NON_PRIORITY/NOT_NOW handler. When cdada69d guidance is active and contains "check back/when would be/better time", the "close the loop" template line is replaced with "When would be a good time to check back in?". Instruction text is NOT pasted verbatim. cdada69d instruction text does not appear in output.  
**Harness:** P8.1–P8.18 all PASS.

### Classification correction for BOOKING/PRICING confusion — PATCHED (session 4)
**Root cause confirmed:** Section B `detectMicroIntent` did not recognise `walkthrough`/`demo`/`tour`/`meeting` as booking signals, and did not recognise `commitment`/`retainer` as pricing signals.  
**Fix applied:**  
- FIX-1: `book (a )?(time|slot|call)` extended to `book (?:a (?:quick |brief )?)?(time|slot|call|walkthrough|demo|tour|meeting)`
- FIX-2: pricing regex extended with `commitment|retainer`
- FIX-1a: `_5qReplyHasBookingIntent` (Section D guard) extended consistently  
**Harness:** P7.1–P7.12 all PASS. Setup/process regression (P7.8) confirmed clean.

**Session 4 Decision versionId:** `a3916c2e` → `937488a9`. Active: true. 119/119 PASS.

---

## Review Form Regression (session 3)

**Root cause confirmed:** Previous session patched Node J using stale HumanApproval `9c71882f` as source, not the modern `0fa9d0ce` lineage. Old `draft_revision_type`, `desired_future_behavior`, and `What should the system do next time?` fields reintroduced.

**Fix applied:** Node J replaced surgically from `agent/codex/sl-phase-5q-checkpoint-20260701` (0fa9d0ce lineage). Modern `draft_learning_instruction` combined field restored. Old fields removed.

**Harness:** 89/89 PASS session 3 → 119/119 PASS session 4 (+30 new P7+P8 tests).

**Production applied:** HumanApproval `54b7a8e4` → `849c2c64`. Active state preserved. No Sender touched.

---

## Owner Action Required (session 4 — Variant C live retests)

1. **Run Variant C live retests** — send fresh emails from Instantly for all 4 cases:
   - Booking: "Is there a link where I can book a quick walkthrough?" → expect BOOKING_REQUEST, booking link draft
   - Pricing/commitment: "Before scheduling, what's the minimum commitment to try this?" → expect PRICING_REQUEST or AI_COMMERCIAL_SUPERVISED draft with commitment answer before CTA
   - Not-now: "This could be useful but not until later in the quarter." → expect "When would be a good time to check back in?" in draft (not "close the loop")
   - Setup/process: "Before I book, can you give me a quick breakdown of what you set up?" → expect OFFER_EXPLANATION, setup steps draft (regression guard)
2. **Confirm booking classification** after Variant C — if still OFFER_EXPLANATION, investigate whether `walkthrough` is in the live Section B code (check production execution trace).
3. **Paste Variant C execution IDs** into this report when available.
