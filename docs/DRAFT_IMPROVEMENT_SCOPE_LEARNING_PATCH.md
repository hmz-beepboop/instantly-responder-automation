# Draft Improvement Scope Learning Patch — SL-PHASE-5N

**Phase:** SL-PHASE-5N  
**Applied:** 2026-06-26  
**HumanApproval versionId:** `9e9da4f1-a405-46b6-9352-b3906075f846`  
**Prerequisite:** SL-PHASE-5M (8a148c91) — always-visible draft reason section  

---

## Problem Solved

After SL-PHASE-5L/5M added `draft_revision_reason` capture, the system could learn WHY a reviewer changed a draft, but had no mechanism to control HOW BROADLY that learning should apply. This created risk of over-generalisation (a pricing edit leaking into setup explanation drafts) or under-generalisation (a universal safety rule only being applied to one micro-intent).

---

## What Was Patched

Nodes changed in HumanApproval `9aPrt92jFhoYFxbs`:

| Node | Change |
|------|--------|
| J. Render Review Form HTML | New `draft_improvement_scope` select inserted BEFORE `draft_revision_type`. Always visible (no JS show/hide). Default: `unsure_review_needed`. |
| L. Validate & Consume Review Token | Parses `submit_draft_improvement_scope` from POST body. Defaults to `unsure_review_needed` if blank. |
| SL-P1A. Build Draft Revision Event | Adds `draft_improvement_scope` to `sl_draft_revision_events` event. |
| SL-P2A. Prepare Phase 1C+2 Capture Data | Adds `draft_improvement_scope` + derived `proposed_rule_scope` to proposed_shadow candidate. |

---

## Scope Field Options

| Value | UI Label | proposed_rule_scope | Notes |
|-------|----------|---------------------|-------|
| `unsure_review_needed` | Unsure — reviewer/rule approver should decide | `requires_human_scope_decision` | Safe default. Candidate flagged for human scope decision before activation. |
| `current_micro_intent_only` | Only this micro intent | `micro_intent` | Scoped to the specific micro_intent of this case. |
| `current_broad_category` | This broad category/classification | `broad_category` | Scoped to the broad_category (e.g. POSITIVE_INTEREST). |
| `all_ai_drafts` | All AI-generated drafts, regardless of classification | `global_draft_policy` | Broadest. Universal principles only (no invented proof, pricing, results, guarantees). |
| `campaign_specific` | Only this campaign | `campaign_scoped` | Scoped to campaign_id. Does not apply globally. |
| `sender_specific` | Only this sender | `sender_scoped` | Scoped to sender_email. Narrow scope. |

---

## Rule Candidate Fields Added

Every draft-improvement `proposed_shadow` candidate now includes:

```
draft_improvement_scope:  string (human-selected)
proposed_rule_scope:      string (derived from scope_value)
draft_revision_reason:    string (human-entered — 5L)
draft_revision_type:      string (5L)
desired_future_behavior:  string (5L)
status:                   "proposed_shadow"
requires_human_activation: true
```

---

## Safety Properties

- No scope value auto-activates a rule.
- All candidates remain `proposed_shadow` with `requires_human_activation = true`.
- Approval works if scope left at default `unsure_review_needed`.
- Classification correction fields unchanged.
- Prior reason/type/future_behavior fields unchanged.
- Decision, Sender, Intake, ErrorHandler, SLAWatchdog unchanged.
- Autonomous mode unchanged (still disabled, shadow_only=true, dry_run=true).

---

## Verification

| Check | Result |
|-------|--------|
| WhatIf (19/19 anchors) | PASS |
| Apply (4 nodes patched) | PASS |
| VerifyRenderedReviewHtml (15/15) | PASS |
| VerifySubmitCapture (14/14) | PASS |
| VerifyRuleCandidateScope (11 offline) | PASS |
| **Total** | **63/63 PASS** |

---

## Scope Guidance for Reviewers

**When to use "Only this micro intent":**
- The change addresses a very specific type of prospect message (e.g. only scheduling replies should get a shorter CTA)

**When to use "This broad category/classification":**
- The change is appropriate for all messages in this category (e.g. all POSITIVE_INTEREST drafts should answer setup questions)

**When to use "All AI-generated drafts":**
- The change is a UNIVERSAL principle: do not invent proof, do not quote exact prices, do not make guarantees, do not claim established client base
- Use sparingly — this is the broadest scope

**When to use "Only this campaign":**
- The change is specific to this campaign's audience (e.g. enterprise vs SMB tone)

**When to use "Unsure" (safe default):**
- Not sure how broadly to apply — leave for the rule approver to decide before activation

---

## Behavioural Proof Status

- Scope field: **INSTALLED** (SL-PHASE-5N, 2026-06-26)
- Scope capture: **VERIFIED** (63/63 checks)
- Scope behavioural proof: **PENDING** — Test A+B not yet run
- See: `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md`
