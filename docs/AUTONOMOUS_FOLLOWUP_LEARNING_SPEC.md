# Autonomous Follow-Up Learning Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Purpose

Defines how autonomous sends generate learning signals — through both owner post-action reviews and prospect follow-up replies — feeding back into the same self-improving rule system used by supervised cases.

---

## Learning Signal Sources

### Source 1 — Owner Post-Action Review

When the owner completes a post-action review form for an autonomous case:
- A learning event is created in `hmz-learning-events` DataTable
- If the owner indicates a correction: a proposed_shadow rule candidate is created
- If the owner marks `tighten_eligibility`: an eligibility tightening recommendation is logged
- The same correction capture infrastructure from Phase 1C-2B is reused

### Source 2 — Prospect Negative Follow-Up

If a prospect replies negatively to an autonomous send (e.g. "this was the wrong response", "I never asked for this", "unsubscribe"):
1. The system creates an immediate human case in the HumanApproval queue
2. The case is flagged with `autonomous_sent = true` and `negative_followup = true`
3. The reviewer handles the case and writes a correction reason
4. The correction creates a proposed_shadow rule candidate
5. The eligibility engine is reviewed for the gap that allowed this case

### Source 3 — Daily Pattern Analysis

If the daily digest shows repeated negative patterns (e.g. 3+ cases of the same intent type rated `bad_response`), the digest recommends:
- Removing that intent from the eligibility allowlist
- Creating a tightening rule candidate
- Reviewing the draft prompt for that intent type

---

## Learning Event Fields for Autonomous Cases

All learning events from autonomous cases include additional fields:

| Field | Description |
|-------|-------------|
| `autonomous_case` | Always `true` for autonomous-path cases |
| `was_sent` | Whether an autonomous send occurred |
| `prospect_reaction` | POSITIVE / NEUTRAL / NEGATIVE / UNSUBSCRIBE |
| `post_action_review_rating` | Owner's rating from post-action review form |
| `draft_quality_issue` | Specific quality issue if rating was bad |
| `eligibility_gate_gap` | Which gate should have blocked this case (if applicable) |

---

## Correction-to-Rule Flow for Autonomous Cases

This is the same flow as supervised cases (Phase 4D rule injection):

1. Owner submits post-action review with correction
2. Learning event created → proposed_shadow rule candidate created
3. Owner reviews rule candidate via SL-PHASE-3 console
4. Owner approves → rule injected into Decision node D via SL-PHASE-4D
5. From that point: all cases (supervised AND autonomous) benefit from the rule

No new infrastructure is needed for autonomous follow-up learning. It reuses Phase 1C-2B capture infrastructure and Phase 3-4D rule lifecycle.

---

## Eligibility Tightening Flow

If an autonomous case reveals a gap in the eligibility gates:

1. Post-action review flags `tighten_eligibility = true` with reason
2. System logs an eligibility tightening recommendation to audit trail
3. Owner reviews recommendation in next digest
4. Owner decides: remove intent type from allowlist / reduce confidence threshold / add additional block
5. Config is updated (requires owner approval — Gate 2 level change)
6. Acceptance harness re-run to verify tightening

---

## Learning Accumulation Over Time

As the autonomous layer operates in shadow mode:
- Every shadow evaluation contributes signal about which case types cluster as good/bad candidates
- Shadow digest reviews help calibrate thresholds before any live sends
- By the time controlled pilot is enabled, the owner has reviewed dozens of shadow-eligible cases and knows which ones are truly safe

This is the same accumulation approach as the supervised path: operate conservatively, collect evidence, tighten or loosen based on evidence.

---

## Related Documents

- `docs/AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md` — review form
- `docs/AUTONOMOUS_HUMAN_CORRECTION_TO_RULE_FLOW.md` — correction to rule pipeline
- `docs/AUTONOMOUS_MISTAKE_RESPONSE_POLICY.md` — mistake response
- `docs/SELF_IMPROVEMENT_OPERATIONAL_RUNBOOK.md` — rule lifecycle (reused)
