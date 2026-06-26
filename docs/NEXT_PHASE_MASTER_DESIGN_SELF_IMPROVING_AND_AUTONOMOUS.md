# Next Phase Master Design: Self-Improving and Autonomous Responder

**Last updated:** 2026-06-22
**Status:** DESIGN ONLY — no implementation until Phase 0 architecture review is approved
**Prerequisite:** Final acceptance test must pass (see `docs/FINAL_ACCEPTANCE_CHECKLIST.md`)

---

## 1. Executive Summary

The core supervised responder is 99.99% complete. This document designs the next phase: a system where human reviewer behaviour (edits, classification corrections, follow-ups) generates structured, human-approved rules that improve future AI drafts and classification — without uncontrolled fine-tuning or hidden model training. A future autonomous out-of-hours mode is designed here but must not be built until Phases 1–3 are complete and explicitly approved.

The design is conservative: human approval gates every rule transition, every exclusion is hard-coded and deterministic, and autonomous mode starts in shadow simulation only.

---

## 2. Current Production State — Must Not Regress

- Production: `https://n8n.hmzaiautomation.com/api/v1`
- Workflow IDs locked (see `docs/DO_NOT_REGRESS.md`)
- `DRY_RUN=true`, `OPERATING_MODE=VALIDATION`
- All T2 drafts require human approval — never auto-sent
- Deterministic safety gates run before AI and cannot be bypassed
- `this.helpers.httpRequest` for OpenAI calls
- Booking link `https://calendar.app.google/bNXWJkS3xz3yqdW36` injected once
- Exactly one sender signoff per review card
- FullTestHarness (`RLUcJHQJPvLhw4mG`) stays INACTIVE unless explicitly testing

---

## 3. Proposed Data Model

### `draft_revision_event`
```json
{
  "event_id": "string (uuid)",
  "reply_id": "string",
  "timestamp_utc": "ISO8601",
  "original_ai_draft": "string",
  "human_edited_draft": "string",
  "category": "string",
  "micro_intent": "string",
  "reviewer_id": "string",
  "diff_summary": "string"
}
```

### `classification_correction_event`
```json
{
  "event_id": "string (uuid)",
  "reply_id": "string",
  "timestamp_utc": "ISO8601",
  "original_category": "string",
  "corrected_category": "string",
  "original_micro_intent": "string",
  "corrected_micro_intent": "string",
  "reviewer_id": "string",
  "reviewer_note": "string"
}
```

### `rule_candidate`
```json
{
  "candidate_id": "string (uuid)",
  "rule_type": "style | classification | micro_intent | cta | forbidden_wording | escalation | example_memory",
  "status": "proposed | approved | active | deprecated | rolled_back",
  "source_event_ids": ["string"],
  "proposed_rule_text": "string",
  "proposed_by": "system",
  "created_at": "ISO8601",
  "approved_by": "string | null",
  "approved_at": "ISO8601 | null",
  "activated_at": "ISO8601 | null",
  "deprecated_at": "ISO8601 | null"
}
```

### `active_rule`
```json
{
  "rule_id": "string (uuid)",
  "rule_type": "string",
  "rule_text": "string",
  "applies_to_categories": ["string"],
  "applies_to_micro_intents": ["string"],
  "version": "integer",
  "activated_at": "ISO8601",
  "source_candidate_id": "string"
}
```

### `autonomous_send_event`
```json
{
  "event_id": "string (uuid)",
  "reply_id": "string",
  "timestamp_utc": "ISO8601",
  "category": "string",
  "micro_intent": "string",
  "draft_used": "string",
  "rules_applied": ["string"],
  "safety_gates_passed": ["string"],
  "send_mode": "shadow | live",
  "sent": "boolean"
}
```

### `post_send_review_event`
```json
{
  "event_id": "string (uuid)",
  "autonomous_send_event_id": "string",
  "reviewer_id": "string",
  "timestamp_utc": "ISO8601",
  "reviewer_verdict": "approved | would_have_changed | escalation_missed",
  "reviewer_note": "string"
}
```

### `human_followup_learning_event`
```json
{
  "event_id": "string (uuid)",
  "autonomous_send_event_id": "string",
  "followup_reply_text": "string",
  "timestamp_utc": "ISO8601",
  "inferred_signal": "positive | neutral | negative | unsubscribe | objection",
  "reviewer_confirmed_signal": "string | null"
}
```

---

## 4. Learning Mechanism

### Style Rules
Derived from `draft_revision_event` diffs. Captures: tone shifts, sentence length preferences, formality level, opener/closer patterns. Stored as plain-text instructions injected into AI system prompt context block.

### Classification Rules
Derived from `classification_correction_event`. Captures: which surface patterns map to which category. New rules are `proposed` until approved. Deterministic safety classifications (opt-out, complaint, legal) are immutable and cannot be overridden.

### Micro-Intent Rules
Derived from classification corrections and reviewer notes. Captures: sub-patterns within a category (e.g. "proof-request vs ROI-question within T2"). Stored as keyword/pattern → micro_intent mappings plus example phrases.

### CTA Rules
Derived from draft revision diffs on CTA sentences only. Captures: preferred booking link placement, preferred CTA wording, length preference. Example: "always place calendar link in its own sentence, last paragraph."

### Forbidden Wording Rules
Derived from draft revisions where AI used a phrase the human removed. Captures: exact phrases or patterns to exclude from future drafts. Human must approve each addition to the forbidden list.

### Escalation Rules
Derived from `post_send_review_event` where verdict is `escalation_missed`. Captures: patterns that should trigger human review instead of autonomous send. Human must approve before activating.

### Example Memories
Selected `(original AI draft, human-edited draft, category, micro_intent)` tuples stored as few-shot examples. Injected into AI prompt as "Here are approved examples for this type of reply." Human curates which examples are active.

---

## 5. Rule Lifecycle

```
proposed → approved → active → deprecated
                              ↘ rolled_back
```

| State | Meaning |
|-------|---------|
| `proposed` | System generated from event data; not yet reviewed |
| `approved` | Human reviewed and approved; not yet injected into live prompt |
| `active` | Injected into live AI prompt context; in effect |
| `deprecated` | Superseded by newer rule; no longer injected |
| `rolled_back` | Manually reverted by owner; treated as never active |

**Transitions require explicit human action at every step.** No automatic promotion from `proposed` to `approved` or `approved` to `active`.

---

## 6. Reviewer UI Changes Needed

### Current review card (HumanApproval workflow)
- Draft text
- Approve / Reject buttons
- Sender signoff (×1)
- Calendar link (×1)

### Required additions (Phase 3)
- **Classification display:** show current `category` and `micro_intent` as read-only labels
- **Classification override fields:** editable dropdowns for `category` and `micro_intent`
- **Reviewer note field:** free text, optional, stored with correction event
- **Draft diff view (Phase 1 capture only):** show side-by-side original AI draft vs. human-edited version after edit (for capture purposes, not blocking)

### Required additions (Phase 5+, autonomous post-send)
- **Post-send review card:** separate from approval card; shows what was sent autonomously
- **Verdict field:** approved / would_have_changed / escalation_missed
- **Follow-up trigger:** button to send a human follow-up reply

---

## 7. Human-Editable Classification Design

### Capture Flow
1. Reviewer sees current category + micro_intent on review card.
2. Reviewer can override before approving.
3. On submit, system writes a `classification_correction_event`.
4. System checks if ≥3 corrections agree on the same correction for similar inputs.
5. If threshold met, system generates a `rule_candidate` (status: `proposed`).
6. Owner reviews proposed rule in a separate admin view.
7. Owner approves → `approved`. Owner activates → `active`.

### Constraints
- Deterministic safety classifications (opt-out, complaint, legal, hostile) are immutable — no reviewer override allowed for these.
- A proposed rule that contradicts a safety classification is rejected at generation time.
- Classification correction log is permanent and auditable.

---

## 8. Autonomous Out-of-Hours Design

### Mode Flag
`autonomous_mode_enabled: false` (default, in `config/business-ready.config.json`)
`autonomous_hours: { start: "23:00", end: "07:00", timezone: "America/New_York" }` (owner-set)
`autonomous_shadow_mode: true` (default during pilot — generates drafts, does not send)

### Decision Gate (before any autonomous send)
1. Current time is within `autonomous_hours` → else abort, route to supervised queue
2. `autonomous_mode_enabled = true` → else abort
3. Category is NOT in excluded categories list → else abort, route to supervised queue
4. All existing deterministic safety gates pass → else abort
5. Active rule set covers this category + micro_intent → else abort, route to supervised queue
6. Confidence threshold met (TBD, owner-set) → else abort
7. `autonomous_shadow_mode = false` → else log as shadow send, do not transmit

### Post-Send
- Immediately write `autonomous_send_event`
- Immediately send post-send review notification (Google Chat + email)
- Notification includes: what was sent, to whom, category, micro_intent, rules applied, safety gates passed
- Reviewer submits `post_send_review_event` within 24h (non-blocking; system continues)
- If reviewer sends a follow-up reply → write `human_followup_learning_event`

---

## 9. Safety Gates and Excluded Categories

### Permanently Excluded from Autonomous Mode (hard-coded, not configurable)

| Category | Reason |
|----------|--------|
| Complaint / negative sentiment | Reputational risk |
| Legal / privacy / compliance mention | Liability |
| Opt-out / unsubscribe request | Legal |
| Hostile or angry reply | Reputational risk |
| Billing / pricing negotiation | Revenue-sensitive |
| Ambiguous intent (below threshold) | Correctness |
| High-value / custom-deal scenario | Revenue-sensitive |
| Data-sensitive mention | Privacy |
| Escalation-worthy (any flag) | Human judgment required |
| Non-English reply | Policy HMZ-1.2 §15 |

### Additional Gate: Duplicate Prevention
Idempotency check runs before every autonomous send attempt — same as supervised mode.

### Rollback
`autonomous_mode_enabled` can be set to `false` at any time. Takes effect on next event. Does not affect already-sent messages.

---

## 10. Implementation Sequence

| Phase | Scope | Gate to proceed |
|-------|-------|-----------------|
| 0 | Architecture review only — this document | Owner approves design |
| 1 | Capture `draft_revision_event` and `classification_correction_event` in HumanApproval workflow; no rule generation yet | Offline tests pass; owner approves |
| 2 | Rule candidate generation (shadow only) — system proposes `rule_candidate` records; no AI prompt injection yet | Owner reviews sample candidates; approves format |
| 3 | Human-editable classification UI in review card; `classification_correction_event` write confirmed | Controlled test with 3 real corrections; owner approves |
| 4 | Active rule injection into AI draft prompt (supervised mode only); example memories; forbidden wording | Offline prompt tests pass; 5 supervised live tests; owner approves |
| 5 | Autonomous mode shadow simulation — full autonomous decision gate runs but `autonomous_shadow_mode=true`; post-send review card | 10 shadow events reviewed by owner; owner approves pilot |
| 6 | Limited out-of-hours pilot — `autonomous_shadow_mode=false` for narrow approved category only (e.g. T2 booking requests only) | Owner approves category scope; explicit go/no-go |

**No phase begins without the previous gate passing and owner written approval.**

---

## 11. Risks and Mitigations

| # | Risk | Mitigation |
|---|------|------------|
| 1 | Rule drift — active rules accumulate and contradict each other | Rule versioning + deprecation; max active rules per type (TBD) |
| 2 | Bad rule approved by mistake | Instant `rolled_back` state; re-prompt without that rule on next event |
| 3 | Autonomous mode sends to excluded category due to misclassification | Excluded categories are deterministic hard-codes, not AI outputs |
| 4 | Duplicate autonomous send | Idempotency check before every send attempt, same as supervised |
| 5 | Post-send review fatigue — reviewer stops reviewing | Review notifications expire after 24h with non-blocking reminder; not a blocker |
| 6 | Forbidden wording list grows too large and breaks AI drafts | Forbidden list is injected as structured block; length-capped; human curates |
| 7 | Classification threshold (3 corrections) triggers bad rule | Owner must still explicitly approve before rule is active |
| 8 | Autonomous mode enabled in supervised hours by misconfiguration | Hours gate is first check; any mismatch aborts |
| 9 | Human follow-up learning signals are noisy or contradictory | Follow-up signals are labelled, not auto-applied; owner reviews before influencing rules |
| 10 | Phase 6 pilot scope creeps beyond approved category | Category allowlist for autonomous mode is explicit in config, not inferred |

---

## 12. Exact Next Implementation Prompt (Phase 1 Only)

Use this prompt to start Phase 1 in a future Claude session after owner approves this design:

```
Phase 1 only: Capture learning events in HumanApproval workflow.

Active project: C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation
Production target: https://n8n.hmzaiautomation.com/api/v1
HumanApproval workflow ID: 9aPrt92jFhoYFxbs

Task:
1. Read docs/NEXT_PHASE_MASTER_DESIGN_SELF_IMPROVING_AND_AUTONOMOUS.md Section 3
   for the exact schemas of draft_revision_event and classification_correction_event.
2. Design (do not implement yet) exactly which node in HumanApproval workflow
   captures the original AI draft and the human-edited draft after submission.
3. Design where these events are stored (n8n data table or external?).
   Propose the lightest reliable option.
4. Write the design decision to docs/PHASE_1_CAPTURE_DESIGN.md only.
5. Do not modify any workflow JSON. Do not call production API.
   Do not use n8n-mcp. Do not use subagents.
6. Output: design doc path, storage recommendation, any blockers.
```
