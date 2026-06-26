# Live Review Draft Reason UI Repair — SL-PHASE-5M

**Date applied:** 2026-06-26  
**Script:** `scripts/SL-PHASE-5M-live-review-draft-reason-ui-repair.ps1`  
**HumanApproval versionId before:** `e0a45327-7745-457f-bc7a-881ff03ef1ef` (SL-PHASE-5L)  
**HumanApproval versionId after:** `8a148c91-ea1c-405c-9074-6b9a573370dc` (SL-PHASE-5M)

---

## Root Cause

SL-PHASE-5L added draft revision reason fields to the review form (J node), but the section div used `style="display:none"` with JavaScript change-detection to show the fields only when the reviewer **edited** the draft text.

When the owner opened case-ddb1f011, they had not yet edited the draft. The JS condition (`ta.value !== orig.value`) was false, so the section remained hidden. No "Draft improvement learning" section was visible at all.

The 22/22 verification in SL-PHASE-5L checked that the HTML **code contained** the field elements — it did not verify that the fields were **visible on page load**. This was a false-positive verification.

---

## Fix Applied

**Node changed:** J. Render Review Form HTML (HumanApproval `9aPrt92jFhoYFxbs`)

| Change | Before | After |
|--------|--------|-------|
| Section visibility | `display:none` — hidden until draft edited | Always visible (no display:none) |
| Section heading | "You changed the draft — please explain..." | "Draft improvement learning (optional — does not block approval):" |
| Field 1 help text | None | "Explain what the system should learn for future similar replies." |
| Field 2 label | "Type of edit:" | "What type of draft improvement was this?" |
| JavaScript | Show/hide entire section based on draft change | Warning-only: shows `hmzEditWarn` paragraph if draft was edited but reason is blank |

**No other nodes changed.** L node, SL-P1A, SL-P2A, Decision, Sender, Proxy, Intake, ErrorHandler, SLAWatchdog all unchanged.

---

## Verification Results

**WhatIf:** 13/13 PASS — root cause confirmed, patch simulated cleanly  
**Apply:** versionId changed `e0a45327 → 8a148c91`  
**VerifyRenderedReviewHtml:** 11/11 PASS — live J node code confirmed  
**VerifySubmitCapture:** 9/9 PASS — L/P1A/P2A capture paths confirmed  

**Total: 33/33 checks PASS**

---

## How the Form Now Behaves

1. Review form loads — "Draft improvement learning" section is **immediately visible** below the reply textarea.
2. Reviewer can enter a reason, select a type, and add desired future behaviour **before or after editing the draft**.
3. If the reviewer edits the draft but leaves the reason blank, a non-blocking warning appears: "Draft edited — consider explaining why above."
4. Approval still works if all reason fields are blank.
5. Classification correction fields (below the form, in a `<details>`) are unchanged.

---

## What Still Needs to Happen

**Test A (capture proof):** Open a real review case, edit the draft, enter a reason in "Why did you change the draft reply?", approve. Then verify the rule candidate in the DataTable/Proxy has the human reason (not the generic fallback string).

**Test B (behavioural proof):** After a rule candidate is approved and injected via RC process, verify a similar future prospect email gets an improved AI draft.

Full protocol: `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md`

---

## Lessons Learned

- Verification scripts must check **rendered visibility**, not just code presence.
- Hidden-by-default UI elements require a separate "visible on page load" assertion.
- Future J node patches must include a `-VerifyRenderedVisibility` assertion that confirms `display:none` is absent from any section that should be visible by default.
