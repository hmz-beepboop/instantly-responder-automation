# Manual Test Packet — Draft Improvement Learning (Behavioural Proof)

**Phase:** SL-PHASE-5O (target classification selector) / SL-PHASE-5N (scope field) / SL-PHASE-5M (UI repair) / SL-PHASE-5L (original capture patch)  
**Date updated:** 2026-06-26  
**Purpose:** Prove the full draft-improvement learning loop end-to-end, including scope/generalisation control and per-email classification targeting.  
**Prerequisite:** SL-PHASE-5O patch applied (HumanApproval versionId: `23ffc9f2-a869-4313-a1cb-e032bd35e526`).

---

## MANDATORY PRE-CHECK BEFORE STARTING TEST A

**Do not start Test A until this is confirmed:**

Open the review form for any pending case (e.g. case-ddb1f011 if still valid and not yet approved).

Without editing the draft, verify that a section titled **"Draft improvement learning"** is visible below the reply textarea. It should show ALL of:

- **"Which detected classification(s) should this draft improvement apply to?"** — checkbox group listing each detected classification separately (NEW, SL-PHASE-5O)
  - Broad category: [value] — one checkbox
  - Micro intent: [value] — one checkbox
  - Additional detected intent: [value] — one checkbox per additional intent (NOT grouped)
  - If no additional intents: "Additional detected intents: N/A" note
- "Should this draft improvement apply only to this classification, or generally to all drafts?" dropdown (scope field, SL-PHASE-5N)
- "Why did you change the draft reply?" textarea (SL-PHASE-5L)
- "What type of draft improvement was this?" dropdown  
- "What should the system do next time?" field

If the target classification selector is NOT visible, or if additional intents are grouped into one option, report the issue — do not proceed.

**SL-PHASE-5L failure note:** The original 5L patch hid this section behind a JavaScript edit event. The 5M repair made it always visible. The 22/22 verification in 5L was a false positive (code-anchor only, not rendered visibility).

---

## What This Proves

The patch (SL-PHASE-5L) added the `draft_revision_reason` field. But field capture alone is not behavioural proof. To prove the loop works:

1. Reviewer edits a draft and enters a reason → reason is captured in `sl_draft_revision_events`
2. A proposed_shadow rule candidate is created (visible via Proxy or n8n DataTable)
3. Owner reviews and approves the candidate (following the classification rule review process)
4. Approved rule is injected into Decision node's ACTIVE_RULE_GUIDANCE block
5. A similar future prospect email arrives → the AI draft reflects the improvement
6. Owner approves and email sends → VERIFY the improvement appears in the draft

Only when Step 6 is confirmed is draft-level self-improvement VERIFIED.

---

## Test A — Capture the Edit Reason

### Prospect email to use (real or simulated in review form)

> "This sounds interesting, but can you explain what the setup actually includes before I book anything?"

### Expected initial AI draft (typical AI behaviour without rule)

Something like:
> "Great to hear you're interested! I'd love to schedule a quick intro call to walk you through everything. Here's my calendar link: [link]"

(The AI rushes to CTA without answering the setup question.)

### Reviewer action in the form

1. Open the review form for this case
2. Edit the draft to directly answer what the setup includes before asking for a call. Example:

> "Happy to clarify — the setup includes a 2-week onboarding period, connection to your current outreach tool, and weekly performance check-ins. Once that makes sense, happy to jump on a quick call: [link]"

3. The "Draft improvement learning" section should already be visible (always shown after SL-PHASE-5M/5N). If not, stop and re-verify the patch.
4. **Select target classifications** ("Which detected classification(s) should this draft improvement apply to?"):
   - Check the boxes for the classifications this improvement applies to
   - For this test case: check **"Broad category: INFORMATION_REQUEST"** and **"Micro intent: OFFER_EXPLANATION"** (or whatever micro_intent is shown for the case)
   - Do NOT check classifications unrelated to the setup-question improvement
   - Leaving all unchecked is valid — the rule candidate will still be created, just without target classification scope

5. **Select the scope dropdown** ("Should this draft improvement apply only to this classification, or generally to all drafts?"):
   - For this test case (setup question / INFORMATION_REQUEST): select **"This broad category/classification"** (applies to POSITIVE_INTEREST INFORMATION_REQUEST type drafts — appropriate because answering setup questions before CTA is good practice for this category, not just one micro-intent)
   - Default is "Unsure — reviewer/rule approver should decide" — leaving it at default is also valid for Test A

6. Enter in **"Why did you change the draft reply?"**:

> "The prospect asked what the setup includes, so future replies should answer the setup question directly before asking for a call."

7. Select **Type of edit**: `missing_answer`
8. Enter in **"What should the system do next time?"** (optional):

> "When prospect asks what the setup includes, answer that directly before CTA"

9. Click **Approve and send**

### Expected results after Test A

- [ ] Email sends successfully
- [ ] `draft_revision_reason` appears in the case's learning event in `sl_draft_revision_events`
- [ ] `draft_changed = true` in the event
- [ ] `edit_detected = true` in the P1A event
- [ ] `draft_improvement_scope` captured (e.g. `current_broad_category` or `unsure_review_needed`)
- [ ] `draft_improvement_target_classifications` captured as array of objects: `[{type:"broad_category",value:"INFORMATION_REQUEST"},{type:"micro_intent",value:"OFFER_EXPLANATION"}]`
- [ ] A new proposed_shadow rule candidate appears with:
  - `rule_type: "style"`
  - `classification_scope` matching the prospect's category
  - `reason` = the human-entered reason (not the generic fallback)
  - `draft_revision_type: "missing_answer"`
  - `draft_improvement_scope` = the scope option selected by reviewer
  - `proposed_rule_scope` = derived value (e.g. `"broad_category"` or `"requires_human_scope_decision"`)
  - `draft_improvement_target_classifications` = the checked classifications as separate objects (NOT grouped)
  - `status: "proposed_shadow"` (NOT active)
- [ ] No second email sent
- [ ] Autonomous mode still disabled

### PASS criteria for Test A

ALL of the above checked. Particularly:
- reason in the rule candidate is the human-entered text, not `"Reviewer edited draft before approval"`.
- scope is captured even if left at default `unsure_review_needed`.
- proposed_rule_scope reflects the human's scope selection.
- `draft_improvement_target_classifications` is an array — NOT a grouped string.
- each additional detected intent appears as its own `{type:"additional_intent",value:"..."}` object.
- If no checkboxes were selected, `draft_improvement_target_classifications` is `[]` — approval still worked.

---

## Interlude — Owner approves the rule candidate

After Test A:

1. View the proposed_shadow rule candidate (via Rule Candidate review console or Proxy DataTable)
2. Review it for safety:
   - Does it teach the system to answer setup questions before CTA? YES — safe
   - Does it invent any business facts? NO
   - Does it override safety gates? NO
   - Is it scoped to a specific category/micro_intent? YES
3. If approved: follow the same rule injection process used for RC-001 and RC-005 (Phase 4D)
4. Rule must go into Decision node ACTIVE_RULE_GUIDANCE block with status "active"
5. Record the rule ID

**Do not auto-activate. Do not skip human review.**

---

## Test B — Verify Behavioural Improvement

### Prospect email to use (similar but NOT identical to Test A)

> "Before booking, can you give me a quick breakdown of what the system actually covers?"

This asks the same kind of question (explain setup/coverage) in different words.

### Expected AI draft AFTER rule is injected

With the rule active, the AI draft should:
- Directly explain what the system covers (onboarding, connection, reporting, etc.)
- NOT rush immediately to calendar CTA
- Ask for a call only AFTER explaining the setup
- NOT invent results, case studies, or guarantees
- Remain honest about validation stage

### Reviewer action in Test B

Review the draft. If the draft reflects the improvement (answers the setup question before CTA):
- Note that the improvement is present
- Approve and send

### PASS criteria for Test B

| Criterion | Required |
|-----------|---------|
| Draft directly answers "what the system covers" before asking for a call | YES |
| Draft does not rush to CTA without answering | YES |
| Draft does not invent results or proof | YES |
| Draft keeps validation-stage honesty | YES |
| Send requires human approval (not autonomous) | YES |
| Classification self-improvement still working | YES (spot-check) |
| Scope preserved: if scope was micro_intent_only, unrelated classifications NOT affected | YES |
| Scope preserved: if scope was all_ai_drafts, improvement applies regardless of classification | YES |

### FAIL criteria for Test B

- Draft behaves identically to pre-rule draft (CTA first, no setup explanation)
- Only the first edit was captured but future drafts did not improve
- Rule was not active in Decision node at time of Test B
- Scope leaked: a micro_intent_only rule affected an unrelated classification
- Scope under-applied: a broad scope rule only appeared in one micro_intent
- Target classification leaked: rule for `OFFER_EXPLANATION` also changed drafts for unrelated micro-intents (e.g. `PRICING_REQUEST`)
- Multiple additional intents were treated as one grouped target when they should be separate

---

## Comparison Matrix

| Step | Test A (capture) | Test B (behaviour) |
|------|-----------------|-------------------|
| Email | Setup question variant 1 | Setup question variant 2 |
| Draft before rule | CTA first, no setup explanation | (same as before, without rule) |
| Draft after rule | N/A — rule not yet active | CTA after setup explanation |
| Human action | Edit + enter reason + approve | Review improved draft + approve |
| Learning event | Reason captured → proposed_shadow | N/A (rule already active) |
| Proof claimed | Capture proven | Behaviour improvement proven |

---

## Status Tracking

| Step | Status | Date | Notes |
|------|--------|------|-------|
| SL-PHASE-5L patch applied | DONE | 2026-06-25 | versionId e0a45327 |
| SL-PHASE-5M UI repair applied | DONE | 2026-06-26 | versionId 8a148c91 — always visible |
| SL-PHASE-5N scope field applied | DONE | 2026-06-26 | versionId 9e9da4f1 — 63/63 PASS |
| SL-PHASE-5O target classification selector | DONE | 2026-06-26 | versionId 23ffc9f2 — 4 nodes patched, 49/52 checks PASS (3 false-negatives explained) |
| Test A — reason + scope + target_classifications captured | NOT YET | — | |
| Proposed_shadow candidate created | NOT YET | — | |
| Owner reviews candidate | NOT YET | — | |
| Rule injected into Decision | NOT YET | — | |
| Test B — draft improved | NOT YET | — | |
| Draft improvement VERIFIED | NOT YET | — | |

---

## What Counts as VERIFIED

Draft-level self-improvement is VERIFIED when:
- Test A PASS (reason captured in rule candidate)
- Rule approved by owner and injected into Decision
- Test B PASS (future similar email draft shows the improvement)

Until then: **INSTALLED** with reason capture. Not VERIFIED.

---

## Related Files

- `docs/DRAFT_REVISION_REASON_LEARNING_PROOF.md` — patch proof record
- `scripts/SL-PHASE-5L-draft-revision-reason-learning-proof.ps1` — patch + verify script
- `docs/SELF_IMPROVEMENT_SCORECARD.md` — overall scorecard
- `docs/SELF_IMPROVEMENT_OPERATIONAL_RUNBOOK.md` — how to inject approved rules
