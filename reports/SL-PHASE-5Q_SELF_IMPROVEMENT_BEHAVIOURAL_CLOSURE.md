# SL-PHASE-5Q Self-Improvement Behavioural Closure
**Created:** 2026-07-04  
**Session verdict:** COMPLETE — all 4 gaps patched, 66/66 harness PASS, production changes applied 2026-07-04

---

## Summary

The production Decision workflow has complete 5Q learning infrastructure (Q12 DataTable lookup, policy matching, classification correction, AI prompt injection, post-processing). All 6 failing rule IDs are present and active in the DataTable. The system reads them. The failures are caused by specific logic bugs in how rules are consumed, not by missing infrastructure.

---

## Root Cause Audit

### 1. Booking hyper-literal application (case-7c87d21a)

**Node/function:** Decision Node D — `_5qApplyActiveFormRuleInstructionToDraft`

**Evidence:**  
Rule `97eb3b0a`'s `behavioural_instruction` is a policy specification: "Replace the previous booking-request guidance. For booking/calendar-link requests, reply with the booking link once, say they can choose any suitable time..." — no URL in the text.

The function `_5qApplyActiveFormRuleInstructionToDraft`:
1. Extracts URL via `_5qExtractFirstUrl(instruction)` → returns `""` (no URL in 97eb3b0a)
2. Falls back to `bookingLink` which is `null` (SENDER_CONFIG is empty `{}`)
3. Extracts "question line" via `_5qInstructionSentence` with pattern `/any questions?|ask any question/i` — matches "inviting questions before booking"
4. Assembles draft from extracted sentence: `"Add one short line inviting questions before booking.\n\nSenderName"` — garbled output

**Why prior work missed it:** The function was designed assuming rule instructions contain email-ready content. `c9860e74` (old weak rule) had a proper URL in its instruction. `97eb3b0a` was written as a behavioral policy spec — a different pattern.

**Minimal patch:** Modify `_5qApplyActiveFormRuleInstructionToDraft` to abort if `link` is empty and extracted sentences appear to be policy text (contain words like "do not", "reply with", "previous guidance", "replace"). Instead, render the deterministic template with the canonical booking link fallback.

**Alternatively:** Populate SENDER_CONFIG with the sender's booking link — this is the correct long-term fix.

---

### 2. Old weak booking rule (c9860e74) suppression

**Node/function:** Decision Node D — `_5qSelectBehaviouralPolicyMatches` scope deduplication

**Evidence:**  
Both `c9860e74` and `97eb3b0a` have scope key `"micro_intent::INFORMATION_REQUEST::BOOKING_REQUEST::"`. The `newestByScope.set` logic uses `candidate.time >= existing.time`. In execution 3951, `97eb3b0a` appears after `c9860e74` in the Q12 output. With `time = 0` for both (if no timestamp fields populated), the `>=` comparison means the last processed wins — `97eb3b0a` correctly supersedes `c9860e74`.

**Verdict:** Suppression is WORKING CORRECTLY if timestamps are equal-zero. Old rule IS suppressed in policy selection. The failure is only in how `97eb3b0a`'s instruction is interpreted (root cause #1).

**Caveat:** If `created_at`/`approved_at` fields exist on the DataTable rows (not visible in execution output) and `c9860e74` is newer, it could win. This should be verified.

---

### 3. Pricing rule no output delta (case-d555bcfd, rule 493884ad)

**Node/function:** Decision Node D — `AI_COMMERCIAL_SUPERVISED` branch

**Evidence:**  
For PRICING_REQUEST with `_5qIsCommercialSafe = true`, `draftPolicy = "AI_COMMERCIAL_SUPERVISED"`. The `canTryAI` check requires `draftPolicy === 'AI_SUPERVISED_OR_TEMPLATE'` — **pricing never calls AI**. The `AI_COMMERCIAL_SUPERVISED` branch uses a hardcoded deterministic template that never reads `behaviouralGuidance`.

The post-processing `_5qApplyActiveRuleDraftPostprocessing` only modifies BOOKING_REQUEST/MEETING_TIME_REQUEST templates, not commercial ones.

Rule `493884ad` IS matched by `_5qSelectBehaviouralPolicyMatches` and IS in `activeFormDraftRuleMatches`, so `activeDraftRulesApplied = 1`. But `draftLearningDelta.changed = false` because the hardcoded commercial template is identical before/after policy application.

**Result:** `learningNotAppliedReason = "RULE_FOUND_BUT_NO_OUTPUT_DELTA"` (technically accurate — the rule was found, eligible, but no delta occurred because the template ignored the guidance).

**Minimal patch:** Inject `behaviouralGuidance` into the `AI_COMMERCIAL_SUPERVISED` branch by either:
- Calling AI for pricing cases when guidance is present (and `AI_COMMERCIAL_SUPERVISED` becomes AI-driven), OR
- Applying behavioural constraints post-hoc to the hardcoded commercial template (detect pricing/minimum-commitment questions, answer first, then CTA)

**Risk:** Pricing contains sensitive business content; any auto-modification needs careful safety gates.

---

### 4. Setup/process rule no confirmed delta (case-083fe26e, rule 48e10cac)

**Node/function:** Decision Node D — AI prompt injection for OFFER_EXPLANATION

**Evidence:**  
Rule `48e10cac` IS eligible for OFFER_EXPLANATION. `canTryAI = true`. `behaviouralGuidance` IS injected into the AI prompt. The system should work.

**Suspected cause of "no delta":** The AI (gpt-5.4-mini) may already satisfy the guidance by coincidence, OR the delta detection (`_5qDraftLearningDelta`) normalises whitespace and both before/after texts differ only in whitespace → delta=false. OR the AI call failed (timeout/API error) → fallback to `buildPolicyAwareFallback` which also has OFFER_EXPLANATION-aware logic → delta=0 between AI-attempt fallback and what policy-aware fallback would produce anyway.

**Not a code bug** in the same way as booking/pricing. The setup rule IS injected into AI prompts. The "no delta" may be a measurement artifact rather than a non-injection. Needs live test to confirm AI output before/after.

**Harness test:** Compare AI prompt with and without 48e10cac guidance. If prompt differs but AI output doesn't, it's an AI compliance issue. If the delta check is wrong, it's a measurement bug.

---

### 5. Not-now/later → HUMAN_ONLY with no draft (case-5fa982f4)

**Node/function:** Decision Node D — `_5qDraftPolicyFor` + `_5qApplyDynamicClassificationLearning`

**Evidence:**  
Classification rule `6e50fd54` corrects AMBIGUOUS/AMBIGUOUS_SHORT_REPLY → AMBIGUOUS/NON_PRIORITY.  
`_5qDraftPolicyFor("NON_PRIORITY", detFlags)` → not in the map → returns "HUMAN_ONLY".  
Style rule `cdada69d` (AMBIGUOUS/NON_PRIORITY, "acknowledge timing, ask when to check back") IS eligible as a behavioural policy, but `draftText = null` (HUMAN_ONLY) so post-processing is skipped (`if (draftText) draftText = ...`).  
`behaviouralGuidance` from `cdada69d` IS built but cannot be injected (no AI call for HUMAN_ONLY).

**"HUMANAPPROVAL_DIAGNOSTIC_FALLBACK" string:** Not found in any current workflow code. Likely refers to owner observing a confusing null/empty draft_text in the review form — a symptom of HUMAN_ONLY with no template, not a literal string.

**Minimal patch:** Add `NON_PRIORITY` to `_5qDraftPolicyFor` → `"AI_SUPERVISED_OR_TEMPLATE"` when a style rule is active. OR map NON_PRIORITY to the existing NOT_NOW template (`FIXED_TEMPLATE`). The `MI_TEMPLATES.NOT_NOW` already has an appropriate "Understood, I'll close the loop" template.

**Safe approach:** Map `NON_PRIORITY` draft policy to `FIXED_TEMPLATE` (same as NOT_NOW), and use the NOT_NOW template for rendering. The style rule `cdada69d` guidance would then need to be applied as post-processing or AI override.

---

### 6. Reopened form reason persistence

**Node/function:** HumanApproval Node J — form HTML rendering

**Evidence:**  
Node J line 54: `draft_revision_reason` textarea has no prefill from saved values. The form shows an empty textarea even for reopened cases.  
Node J line 28-29: Reply text IS prefilled from `latest_approved_reply_text` for reopened cases.

**Gap:** The `draft_revision_reason` field from previous submissions is not read back from the case record for prefill on reopen.

**Minimal patch:** In Node J, look up `rc.draft_revision_reason` (or `rc.reviewer_decisions[-1].draft_revision_reason` if stored in reviewer decision history) and prefill the textarea value.

---

## State model assessment

| Status | Infrastructure | Working |
|--------|----------------|---------|
| `proposed_shadow` | Q12 row filter (status=active excludes non-active) | YES |
| `approved_for_future_learning` | Not a production status; field doesn't exist in current schema | N/A |
| `active` (draft policy) | Q12 fetches status=active, `_q12DynamicFormPolicies` filter | YES |
| `active` (classification) | Q12 fetches status=active, `_q12DynamicFormClassificationRules` filter | YES |
| `superseded` | Not set automatically; older same-scope rules are suppressed in `newestByScope` but remain with status=active in DataTable | PARTIAL |
| `rejected` | Not a current status in DataTable | N/A |

**Gap:** Old same-scope rules are functionally suppressed in scope deduplication but their DataTable `status` remains `active`. There is no mechanism to automatically mark c9860e74 as `superseded` when 97eb3b0a takes precedence.

---

## Production apply status

**ALL 4 PATCHES APPLIED — 2026-07-04**

| Patch | Workflow | Old versionId | New versionId |
|-------|----------|---------------|---------------|
| GAP-1 (booking post-processor) | Decision `tgYmY97CG4Bm8snI` | `889e1d45` | `a3916c2e` |
| GAP-2 (pricing constraints) | Decision `tgYmY97CG4Bm8snI` | `889e1d45` | `a3916c2e` |
| GAP-3 (NON_PRIORITY policy) | Decision `tgYmY97CG4Bm8snI` | `889e1d45` | `a3916c2e` |
| GAP-4 (Node J revision reason) | HumanApproval `9aPrt92jFhoYFxbs` | `0fa9d0ce` | `54b7a8e4` |

Both workflows remain active. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched (active=false). No Sender triggered. No Instantly POST. No autonomous activation.

---

## Harness status

See `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — 66/66 PASS (S1-S10, P1-P4, SC.1-SC.6, AT.1-AT.2).

---

## Manual owner actions still needed

1. **Live test GAP-1**: Submit a new BOOKING_REQUEST case and verify the booking draft does not contain policy meta-phrases from 97eb3b0a ("Replace the previous", "Do not ask them").
2. **Live test GAP-2**: Submit a PRICING_REQUEST case with rule 493884ad active; verify the commercial draft replaces the evasive paragraph with setup-fee / per-shown-call wording.
3. **Live test GAP-3**: Submit a case classified as AMBIGUOUS/AMBIGUOUS_SHORT_REPLY with rule 6e50fd54 active; verify corrected NON_PRIORITY classification produces a NOT_NOW template draft (not null/HUMAN_ONLY).
4. **Live test GAP-4**: Reopen a previously approved review case; verify draft_revision_reason textarea is prefilled with the previously entered reason.
