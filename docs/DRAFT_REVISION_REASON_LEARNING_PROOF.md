# Draft Revision Reason Learning Proof

**Phase:** SL-PHASE-5L  
**Date:** 2026-06-25  
**Status:** PATCHED — VERIFY PENDING MANUAL TEST  
**HumanApproval versionId after patch:** `e0a45327-7745-457f-bc7a-881ff03ef1ef`

---

## What Was Patched

The review form previously captured that a draft was edited (`edit_detected = true`) but never captured **why** the reviewer changed it. Without a reason, draft-level rule candidates contained only the generic string `"Reviewer edited draft before approval"` — not useful for learning.

This patch fills that gap.

### Nodes Changed (HumanApproval `9aPrt92jFhoYFxbs` only)

| Node | Change |
|------|--------|
| J. Render Review Form HTML | Added `draft_revision_reason` textarea, `draft_revision_type` select, `desired_future_behavior` input. Section appears only when reviewer edits the draft text (JS change detection). Does not block approval if blank. |
| L. Validate & Consume Review Token (POST) | Added parsing of 3 new POST body fields: `submit_draft_revision_reason`, `submit_draft_revision_type`, `submit_desired_future_behavior`. |
| SL-P1A. Build Draft Revision Event | Added `draft_revision_reason`, `draft_revision_type`, `desired_future_behavior` to the draft revision event written to `sl_draft_revision_events`. |
| SL-P2A. Prepare Phase 1C+2 Capture Data | Draft rule candidates now use the human-entered reason (with fallback to generic string). Also include `draft_revision_type` and `desired_future_behavior` in the rule candidate object. |

**No other nodes changed. Decision, Sender, Intake, ErrorHandler, SLAWatchdog unchanged.**

---

## New Fields

### Form Fields (J node)

| Field name | Type | Required | Purpose |
|------------|------|----------|---------|
| `draft_revision_reason` | textarea | No (soft — section shown only on edit) | Human explains the principle behind the edit |
| `draft_revision_type` | select dropdown | No | Type: missing_answer / tone / clarity / too_pushy / unsafe_claim / wrong_cta / too_long / too_short / other |
| `desired_future_behavior` | text input | No | What the system should do next time for similar emails |

The section is hidden by default. JavaScript detects when the textarea content differs from the original draft and reveals the section. The reviewer is not blocked from approving if they leave it blank — it is guidance only.

### Parsed Fields (L node)

- `submit_draft_revision_reason`
- `submit_draft_revision_type`
- `submit_desired_future_behavior`

### Event Fields (SL-P1A → sl_draft_revision_events)

- `draft_revision_reason`
- `draft_revision_type`
- `desired_future_behavior`

### Rule Candidate Fields (SL-P2A → proposed_shadow)

The `draftChanged` rule candidate now includes:
- `reason`: human-entered reason (falls back to `"Reviewer edited draft before approval"` if blank)
- `draft_revision_type`: the selected type
- `desired_future_behavior`: the stated future behavior
- `status`: always `"proposed_shadow"` — never auto-activated

---

## Verification Results

### Offline (5 fixtures, -VerifyRuleCandidate)

| Scenario | draft_changed | Reason-enriched candidate |
|----------|--------------|--------------------------|
| Setup question not answered | true | PASS |
| Overclaimed proof | true | PASS |
| Pricing — exact numbers given | true | PASS |
| Simple scheduling over-explained | true | PASS |
| Vague prospect — ask clarifying question | true | PASS |

Result: **5/5 PASS**

### Live (22 checks, -VerifyReviewFormField -VerifyLearningCapture)

All 22 checks PASS:
- J node: all 3 fields + JS detection + backward-compat preserved
- L node: all 3 submit fields + additional_intents preserved
- P1A event: all 3 new event fields + edit_detected preserved
- P2A rule candidate: human reason + type + behavior + proposed_shadow status confirmed

---

## What This Does NOT Do

- Does not block approval if reason is blank
- Does not auto-activate any rule — all remain `proposed_shadow`
- Does not change routing, classification, or draft generation
- Does not enable autonomous mode
- Does not change Sender, Decision, Intake, ErrorHandler, SLAWatchdog

---

## What Remains Unproven

Full draft-level behavioural proof requires the two-test chain:

**Test A:** Reviewer edits a draft and enters a reason → reason is captured → proposed_shadow rule candidate created.

**Test B:** Owner reviews candidate → approves → rule injected into Decision → similar future prospect email produces an improved draft that reflects the reason.

See `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md` for the full protocol.

Draft-level self-improvement is **INSTALLED** with reason capture now. It is not **VERIFIED** until Test A and Test B are run.

---

## Safety Record

| Safety constraint | Status |
|-------------------|--------|
| No autonomous sending enabled | CONFIRMED |
| No live rules auto-created | CONFIRMED |
| Sender unchanged | CONFIRMED |
| Decision unchanged | CONFIRMED |
| Routing unchanged | CONFIRMED |
| dry_run still true | CONFIRMED |
| shadow_only still true | CONFIRMED |
| autonomous_enabled still false | CONFIRMED |
