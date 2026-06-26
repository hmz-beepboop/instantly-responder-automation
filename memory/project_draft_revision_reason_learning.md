---
name: project_draft_revision_reason_learning
description: SL-PHASE-5L draft revision reason learning patch — new fields added to HumanApproval review form; capture and rule candidate verified; behavioural proof pending Test A+B
metadata:
  type: project
---

SL-PHASE-5L applied 2026-06-25. Patched HumanApproval workflow to capture why the reviewer changed a draft.

**Why:** The draft rule candidate previously used a hardcoded generic reason ("Reviewer edited draft before approval"). Without a human-entered reason, the system could not learn the *principle* behind a draft edit — only that an edit occurred. This blocked meaningful draft-level self-improvement.

**How to apply:** HumanApproval versionId is now `e0a45327-7745-457f-bc7a-881ff03ef1ef`. When the next real review happens and reviewer edits a draft, expect the `draft_revision_reason` section to appear automatically in the form. The rule candidate written to `sl_draft_revision_events` will include the human reason.

## What was patched

Nodes changed (HumanApproval `9aPrt92jFhoYFxbs` only):

| Node | Change |
|------|--------|
| J. Render Review Form HTML | draft_revision_reason textarea + draft_revision_type select + desired_future_behavior input. Shown only when draft is edited (JS detection). Does not block approval. |
| L. Validate & Consume Review Token (POST) | Parses submit_draft_revision_reason, submit_draft_revision_type, submit_desired_future_behavior from form POST. |
| SL-P1A. Build Draft Revision Event | Adds draft_revision_reason, draft_revision_type, desired_future_behavior to sl_draft_revision_events event. |
| SL-P2A. Prepare Phase 1C+2 Capture Data | Draft rule candidate now uses human reason (not hardcoded string). Also includes draft_revision_type and desired_future_behavior. Status: proposed_shadow (never auto-activated). |

## Verification

- Offline: 5/5 fixture scenarios PASS — all produce reason-enriched proposed_shadow candidates
- Live: 22/22 checks PASS — all 4 nodes verified in production (versionId e0a45327)
- No routing changes, no live rules, no autonomous mode

## What still needs to happen

Behavioural proof (draft-level) requires two manual tests:

**Test A:** Review a real case → edit the draft → enter draft_revision_reason → approve → verify reason captured in rule candidate (proposed_shadow).

**Test B (after rule approved and injected):** Similar prospect email → verify new AI draft reflects the improvement without reinventing it.

See `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md` for full protocol.

## Status as of 2026-06-25

- draft_revision_reason field: INSTALLED + VERIFIED (22/22 live)
- draft-level self-improvement loop: INSTALLED but NOT BEHAVIOURALLY VERIFIED
- Classification self-improvement: remains VERIFIED (unchanged)
- Self-improvement overall confidence: 98% (unchanged — draft behaviour proof is the remaining gap)
