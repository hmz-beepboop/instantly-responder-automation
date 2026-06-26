# Autonomous Prompting and Rule Usage Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Overview

The autonomous draft path uses the same AI draft infrastructure as the supervised path. Active rules from Decision node D's ACTIVE_RULE_GUIDANCE block apply identically to both paths. This document specifies how prompting and rules work in the autonomous context.

---

## Draft Generation in Autonomous Path

### Step 1 — Classification (Decision Workflow)

The existing Decision workflow runs first:
- Classifies the prospect reply (broad category + micro intent + additional intents)
- Applies active rules from ACTIVE_RULE_GUIDANCE block
- Outputs the classification + draft_policy + draft guidance

### Step 2 — Eligibility Engine

The eligibility engine evaluates the Decision output:
- Checks all gates (identity, allowlist, intent, hours, confidence, etc.)
- If all gates pass AND system is in controlled pilot: proceeds to draft

### Step 3 — Draft Preparation

The AI draft uses:
- Same OpenAI Responses API (via SL-PATCH-3.0)
- Same knowledge base: `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`
- Same reply policy: `docs/HMZ_APPROVED_REPLY_RULES.md`
- Same active rules from Decision node D (ACTIVE_RULE_GUIDANCE block)
- Same forbidden terms and safety wording

The autonomous draft is NOT a different or weaker draft. It uses all the same constraints as the supervised path.

---

## Active Rules in Autonomous Context

Active rules (RC-001, RC-005, etc.) apply to the draft regardless of whether the case is supervised or autonomous. The rule injection point is in Decision node D — all cases pass through Decision, so all cases receive rule guidance.

**No autonomous-specific rules exist or are needed.** The same rules that improve supervised drafts also improve autonomous drafts.

---

## Prompting Constraints That Always Apply (Autonomous Path)

The following constraints are inherited from the supervised path and CANNOT be overridden by the autonomous layer:

1. **No invented prices.** The AI must never state a specific price.
2. **No invented case studies.** The AI must not fabricate customer examples.
3. **No invented results.** The AI must not claim specific ROI, conversion rates, or outcomes.
4. **No "proven/established/mature" language.** HMZ is in validation stage.
5. **Booking link must appear exactly once.**
6. **No duplicate signoff.**
7. **No pricing content in any draft** (even if the case somehow reached the draft stage — defence in depth).
8. **Honest validation-stage language when proofing/evidence is requested.**

These are enforced in the AI prompt (Decision node D), not in the autonomous layer. The autonomous layer inherits them automatically.

---

## Autonomous Draft Scope

Autonomous drafts are only permitted for the lowest-risk intent types:

| Intent type | Allowed in autonomous | Notes |
|-------------|----------------------|-------|
| INFORMATION_REQUEST | YES (Phase B only) | Generic info about the service |
| SCHEDULING_REQUEST | YES (Phase B, after Phase B success) | Calendar link + brief message |
| PROOF_OR_CASE_STUDY_REQUEST | NO — requires RC-001 guidance | Route to supervised |
| PRICING_REQUEST | NEVER | Permanently blocked |
| All commercial/legal/compliance intents | NEVER | Permanently blocked |

---

## Template vs AI Draft in Autonomous Context

The existing supervised path has both template paths and AI draft paths. In autonomous mode:
- **Templates** (T-category): deterministic, pre-approved text — safer for autonomous
- **AI drafts** (AI_SUPERVISED, AI_COMMERCIAL_SUPERVISED): generated — requires higher confidence threshold

Initial autonomous eligibility should prefer template-eligible cases over AI draft cases for additional safety. Consider adding a gate: `draft_policy in ['ai_supervised'] AND confidence >= 0.90` as the autonomous-specific threshold (higher than supervised).

---

## Related Documents

- `docs/AUTONOMOUS_ALLOWED_RESPONSE_TEMPLATES.md` — approved templates
- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — scope
- `docs/SELF_IMPROVEMENT_OPERATIONAL_RUNBOOK.md` — active rule context
- `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` — knowledge base (source of truth)
