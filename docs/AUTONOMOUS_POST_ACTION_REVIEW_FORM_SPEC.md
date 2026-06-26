# Autonomous Post-Action Review Form Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Purpose

Every case processed by the autonomous layer (whether or not a send occurred) must be reviewed by the owner the following morning. This spec defines the review form structure.

---

## When Is a Post-Action Review Required

- Any case where `was_autonomous_send = true` — mandatory
- Any case in the HIGH priority review queue — mandatory
- A sample of shadow-eligible cases (at least 5/day during shadow mode) — recommended
- Any case where `learning_signal_created = true` — recommended

---

## Form Fields

### Section 1 — Case Reference

| Field | Type | Required |
|-------|------|----------|
| `queue_id` | string | YES — from review queue |
| `case_id` | string | YES |
| `thread_id` | string | YES |
| `campaign_id` | string | YES |
| `review_date` | date | YES |
| `reviewer` | string | YES |

### Section 2 — Response Quality Assessment

The reviewer evaluates the autonomous response (or the draft that would have been sent):

| Rating | Meaning |
|--------|---------|
| `good_response` | Response was correct, appropriate, and effective |
| `acceptable_but_edit_next_time` | Response was passable but could be improved |
| `bad_response` | Response was inappropriate, incorrect, or harmful |
| `should_have_escalated` | Case should have been sent for human review instead |
| `wrong_classification` | The classification was incorrect |
| `wrong_eligibility` | The eligibility decision was incorrect |
| `wrong_tone` | The tone was inappropriate for the prospect |
| `wrong_content` | The content was incorrect or misleading |
| `wrong_cta` | The call-to-action was wrong |

### Section 3 — What Was Wrong (if applicable)

If rating is anything other than `good_response`:

| Field | Type | Description |
|-------|------|-------------|
| `wrong_aspect` | string | What was wrong (free text) |
| `correct_classification` | string | What the classification should have been |
| `correct_eligibility_decision` | string | SEND / HOLD / ESCALATE |
| `better_response_text` | string | What a better response would look like |
| `rule_to_create` | string | If a rule should be created to prevent this, describe it |

### Section 4 — Follow-Up Learning

| Field | Type | Description |
|-------|------|-------------|
| `create_learning_event` | boolean | True if this case should generate a learning event |
| `learning_event_reason` | string | Why this generates a learning signal |
| `recommend_rule_candidate` | boolean | True if a rule candidate should be proposed |
| `rule_candidate_description` | string | Description of the proposed rule |
| `tighten_eligibility` | boolean | True if this case type should be removed from eligibility |
| `tighten_eligibility_reason` | string | Why this category should be tightened |

### Section 5 — Prospect Follow-Up

| Field | Type | Description |
|-------|------|-------------|
| `prospect_reply_received` | boolean | Did the prospect reply to the autonomous send? |
| `prospect_reaction` | string | POSITIVE / NEUTRAL / NEGATIVE / UNSUBSCRIBE |
| `follow_up_action` | string | NONE / HUMAN_REPLY_NEEDED / ESCALATE / DNC |
| `notes` | string | Any other relevant notes |

---

## Routing of Review Outcomes

| Outcome | What happens |
|---------|-------------|
| `good_response` | Logged; positive signal; no learning event needed |
| `acceptable_but_edit_next_time` | Logged; optional learning event |
| `bad_response` | Learning event created; rule candidate proposed; consider tightening eligibility |
| `should_have_escalated` | Learning event; eligibility gate review; consider removing this intent type from autonomous |
| `wrong_classification` | Correction event created; proposed_shadow rule candidate |
| `wrong_eligibility` | Eligibility engine logic reviewed |
| `wrong_tone/content/cta` | Draft prompt reviewed; learning event |

Three consecutive `bad_response` or `should_have_escalated` ratings for the same intent type trigger a recommendation to remove that intent type from the autonomous eligibility list.

---

## Related Documents

- `docs/AUTONOMOUS_FOLLOWUP_LEARNING_SPEC.md` — how follow-up learning works
- `docs/AUTONOMOUS_HUMAN_CORRECTION_TO_RULE_FLOW.md` — how corrections become rules
- `docs/AUTONOMOUS_MISTAKE_RESPONSE_POLICY.md` — what happens after a bad response
- `docs/AUTONOMOUS_REVIEW_QUEUE_SPEC.md` — where review items come from
