---
name: project-sl-phase4g
description: SL-PHASE-4G — blocked-send validation override, blocked result page, additional intents UI, micro_intent path fix; APPLIED 2026-06-23; verified 95%
metadata:
  type: project
---

SL-PHASE-4G applied 2026-06-23 to HumanApproval workflow 9aPrt92jFhoYFxbs only.

**versionId after apply:** 7f23d288-c27e-4e88-ba5d-5afd96514c9b (was 5937dbfe-82a0-48f7-85b5-9807eeb3c107)

**Root cause of case-db631034 blocked send:** `validation.valid=false` (AI draft contained "proof"/"examples" keywords) was passed from HumanApproval Node Q to Sender unchanged. Sender's validateSenderInput check `validation.valid !== true` set `sender_validation.valid=false`. Gate rejected with `sender_validation_failed`. Reviewer tried to retry via old URL → token consumed → K5 token error.

**Part A — Node Q validation override:**
Changed `validation` mapping from `{{ $json.case_input.validation }}` to `{{ Object.assign({}, $json.case_input.validation || {}, { valid: true, human_approved: true }) }}`. Human approval is the final authority; content validation is a pre-review pre-filter only. Sender's other gates (campaign, sender, approval, draft variable) remain active.

**Part B — Node R result page:**
Now shows SEND_BLOCKED_RETRYABLE vs approved state with human-readable explanation. Detects `terminal.result === 'BLOCKED'` and `isSenderValidationFailed`. Blocked cases explain that the prospect did NOT receive a reply and instruct the reviewer to contact the system owner.

**Part C — Node J additional classification section:**
`additional_intents_shadow` field moved from standalone main-form area into `<details>Optional: Correct classification...</details>` section. Section defaults to `open` when additional intents exist. Field always rendered (blank when no intents). Help text: "Add, remove, or replace additional classifications here. This creates shadow learning feedback only and does not affect routing, drafting, or sending."

**Part D — SL-P2A origMicroIntent path:**
Fixed line: `const origMicroIntent = String(rap.micro_intent || ctx.micro_intent || rc.micro_intent || (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent) || "")`. Was missing `ctx.sender_handoff.draft.micro_intent` path. This caused `old_micro_intent=""` in correction events (e.g. case-8a8a5d4f had PRICING_REQUEST as primary but `old_micro_intent` was empty).

**Harness:** 65/65 PASS (55 existing + 10 new RG-1 to RG-10)

**Workflows NOT modified:** Decision, Sender, Intake, ErrorHandler, SLAWatchdog, FullTestHarness.

**Why:** Sender validation blocked ai_failed_fallback drafts that contained the word "proof" (a false positive for fallback templates like "Do you have any proof you can share?"). Human review is the correct final gate; the pre-review content flag should not block after human approval.

**How to apply:** See scripts/SL-PHASE-4G-review-retry-and-classification-edit-repair.ps1

**Known remaining issues:**
- No new live manual test (MT) yet for Phase 4G features (validation override, result page, Node J UI, SL-P2A path)
- True token-refresh retry (for non-recoverable blocks other than validation) deferred to Phase 4H
- `SENDER_CONFIG` still has `bookingLink: null` but CONFIG.sender_mapping has real links — booking links resolve via CONFIG.sender_mapping now

See [[project-sl-phase4f]] for Phase 4F context.
