# Next Phase Roadmap: Self-Improving and Autonomous Responder

**Last updated:** 2026-06-22
**Prerequisite:** Final acceptance test must pass (see `docs/FINAL_ACCEPTANCE_CHECKLIST.md`) before any implementation begins.
**Phase start:** Documentation and architecture design only. No production implementation until explicitly approved.

---

## Feature 1: Self-Improving Supervised Drafting

**Goal:** Human-edited drafts become structured reusable rules, not uncontrolled model self-training.

### How It Works

1. When a human edits a draft before approving, capture both the original AI draft and the final human-edited version.
2. Diff the two versions to extract what changed (tone, CTA, objection handling, safety edits).
3. Store the diff as a structured rule or example (not raw text fed back to the model).
4. Rules are human-reviewable, human-editable, and reversible at any time.
5. Future AI drafts are prompted with the active approved rule set.

### Safety Constraints

- Rules only become active after human review and explicit approval.
- No rule can override deterministic safety gates or suppression logic.
- Rules must reference the source edit that created them (traceable).
- Rule set must be versionable with rollback capability.

### Architecture Notes (to design, not build yet)

- Storage: structured JSON or lightweight DB table, not a vector store initially.
- Rule types: style rules, objection-handling examples, CTA preferences, forbidden phrase list.
- Prompt injection: rules injected as structured context block before AI drafting.

---

## Feature 2: Human-Editable Classification

**Goal:** Reviewers can correct category and micro-intent; corrections become training signals for future classification.

### How It Works

1. Review form exposes current classification (category + micro-intent) as editable fields.
2. Reviewer can override classification before approving.
3. Corrections are stored with the original AI classification for comparison.
4. When a correction accumulates enough agreement (threshold TBD), it becomes a new approved classification rule.
5. New or amended classification rules require human approval before going live.

### Safety Constraints

- Classification corrections never auto-update the live classifier without approval.
- Deterministic safety classifications (opt-out, complaint, legal) cannot be overridden by reviewers.
- All correction history is retained and auditable.

### Architecture Notes (to design, not build yet)

- Review form update: add classification override fields to HumanApproval workflow card.
- Storage: correction log with timestamp, reviewer identity, original vs. corrected values.
- Classification rule store: separate from draft rules, versioned.

---

## Feature 3: Autonomous Out-of-Hours Reply Mode

**Goal:** System can send low-risk replies autonomously during configurable human-offline hours, with post-send review.

### Strict Conditions for Enablement

- Not the default. Must be explicitly enabled by owner.
- Only active during configurable human-offline hours (e.g. 11pm–7am local).
- Shadow mode first (drafts generated, not sent) → limited pilot → controlled enablement.
- Owner must approve each phase transition.

### Post-Send Behaviour

- Every autonomous send triggers a post-send review notification (Google Chat + email).
- Notification shows: what was sent, to whom, classification, draft used, rule applied.
- Human can send a follow-up reply after reviewing.
- Follow-up replies are stored as learning signals for Feature 1 and Feature 2.

### Strict Safety Exclusions (Never Auto-Send)

Autonomous mode must never send for:

- Angry or hostile replies
- Legal, privacy, or compliance mentions
- Complaints or negative sentiment
- Unsubscribe or opt-out requests
- Billing or pricing negotiation
- Ambiguous intent (confidence below threshold TBD)
- High-value or custom-deal scenarios
- Any escalation-worthy case
- Any case where a deterministic gate would normally suppress

### Architecture Notes (to design, not build yet)

- Hours config: owner-set schedule in `config/business-ready.config.json`
- Mode flag: `autonomous_mode_enabled=false` default, `shadow_mode=true` during pilot
- Post-send notification: extend existing Google Chat webhook card format
- Exclusion evaluation: runs before autonomous send gate, same deterministic pipeline as supervised mode
- Rollback: disabling autonomous mode reverts immediately to full supervised VALIDATION mode

---

## Phase Sequence

| Phase | Action | Gate |
|-------|--------|------|
| 0 | Final acceptance test passes | Owner confirms |
| 1 | Feature 1 architecture design doc | Owner reviews |
| 2 | Feature 2 architecture design doc | Owner reviews |
| 3 | Feature 3 architecture design doc + shadow mode spec | Owner reviews |
| 4 | Feature 1 implementation + offline tests | Owner approves |
| 5 | Feature 2 implementation + offline tests | Owner approves |
| 6 | Feature 3 shadow mode implementation + pilot | Owner approves each step |

No phase may begin without the previous phase gate passing.
