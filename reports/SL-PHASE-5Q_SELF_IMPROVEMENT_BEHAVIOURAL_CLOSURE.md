# SL-PHASE-5Q Self-Improvement Behavioural Closure
**Created:** 2026-07-04  
**Session verdict:** PARTIAL — 4 gaps patched; live regression repair applied; GAP-3b + classification patches applied session 4; valid-fallback submit/reopen repair applied session 10; PROOF_REQUEST draft-learning activation bridge fixed session 11; PROOF_REQUEST AI-fallback non-null fix applied session 12; live Variant C retests still required  
**Session 12 update (2026-07-05):** PROOF_REQUEST AI-fallback non-null fix (SL-PHASE-5Q-PROOF-FALLBACK). Root cause (deeper): session 11 eligibility fix worked — upgrade guard fires, `draftPolicy=AI_SUPERVISED_OR_TEMPLATE`. But when AI output fails validation or API fails, `fallbackText=null` for PROOF_REQUEST (no branch in `buildPolicyAwareFallback`) → `draftText=null` → empty textarea. `aiDraftUsedGuidance=false` because `draftSource != 'ai_supervised'` → draft style rule not counted as applied → only classification rule in `activeLearningRulesApplied`. Live evidence: case-9996084f (draft: `AI_SUPERVISED_OR_TEMPLATE / ai_failed_fallback`, eligible=2, applied=1 classification, empty textarea). Fix 1: `validateAI` `asksProof=true` for `PROOF_REQUEST` — prevents false-positive validation rejection from guidance containing "do not mention validation" restrictions. Fix 2: `buildPolicyAwareFallback` PROOF_REQUEST branch — returns safe non-null fallback (honest proof-gap acknowledgment + diagnostic question; no invented proof/results). Decision versionId: `0e1e1193` → `9198554c`. HumanApproval unchanged (`7aac637e`). Harness 318/318 PASS (+26 P16 tests).

**Session 3 update (2026-07-04):** Node J review form regression repaired (54b7a8e4 → 849c2c64). Harness 89/89 PASS. Variant B live triage complete — booking/pricing misclassified (AI gap), not-now cdada69d post-processing not consuming guidance (GAP-3b). See `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md`.  
**Session 4 update (2026-07-04):** FIX-1 (booking classification — `walkthrough`/`demo`/`tour`/`meeting` added to Section B detectMicroIntent regex), FIX-2 (pricing classification — `commitment`/`retainer` added to Section B pricing regex), FIX-3 (GAP-3b — NOT_NOW/NON_PRIORITY style rule consumer added to `_5qApplyActiveFormRuleInstructionToDraft`). Decision versionId: `a3916c2e` → `937488a9`. Harness 119/119 PASS. Owner live Variant C retests required to confirm.  
**Session 6 update (2026-07-04):** PROOF_REQUEST/HUMAN_ONLY review-path repair. Node A and Node J now exempt `HUMAN_ONLY`/`NO_DRAFT` policies from draft_text missing-context check. Valid PROOF_REQUEST cases (and other HUMAN_ONLY cases) no longer become `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK` when upstream context is present. HumanApproval versionId: `849c2c64` → `e0e89e0e`. Harness 168/168 PASS (+20 P10 tests). Classification learning for case-bd8e453e: PARTIAL — plausible, not fully proven without live rule trace.  
**Session 11 update (2026-07-05):** PROOF_REQUEST draft-learning activation bridge fix. Root cause: case-532bae78 style rule had `proposed_rule_scope=requires_human_scope_decision` (owner submitted without checking scope checkbox → Node N fell back to "unsure_review_needed" → SL-P2A else branch). `_5qPolicyApplies` returned false → not eligible → upgrade guard never fired in case-380ae677. Fix 1: Node D `_5qPolicyApplies` adds fallback for `requires_human_scope_decision`/`unsure_review_needed` → micro_intent/broad_category matching. Fix 2: Node J form pre-checks `current_micro_intent_only` for new cases → future rules get `proposed_rule_scope=micro_intent` directly. Decision `84e6638e` → `0e1e1193`. HumanApproval `c20af72e` → `7aac637e`. Harness 292/292 PASS (+26 P15 tests). Owner action: send another "How can I trust you?" and confirm AI-supervised draft appears (using existing case-532bae78 style rule).

**Session 10 update (2026-07-05):** Valid-fallback submit/reopen repair (SL-PHASE-5Q-SUBMIT-REOPEN-FIX). Root causes: (1) Node N `rowLooksMissing` had no `isIntentionallyNoDraft` exemption — `ai_failed_fallback` + empty `draft_text` → `contextMissingBlocked=true` → `CONTEXT_MISSING_BLOCKED` on submit despite fully valid upstream context. (2) Node J `_5q3MissingContext` included `rc.status === "CONTEXT_MISSING_BLOCKED"` as standalone trigger — after blocked submit set status, reopening showed diagnostic fallback even though `sanitized_context` was intact. Additional: `SL-P2A` had same `rowLooksMissing` bug — learning capture skipped for `ai_failed_fallback` cases. Fix: Node N gets `_nIsIntentionallyNoDraft` exemption (mirrors Node A/J); `contextMissingBlocked` drops `rc.status` check (relies on `reply_mode` and `rowLooksMissing`). Node J `_5q3MissingContext` drops `rc.status` check. SL-P2A `rowLooksMissing` and context-skip condition also fixed. HumanApproval versionId: `ee2f160e` → `c20af72e`. Harness 266/266 PASS (+26 P14 tests). Decision unchanged (`84e6638e`). Sender untouched. No Instantly POST. Shadow Evaluator inactive. Gate 2 unapproved.

**Session 9 update (2026-07-04):** ai_failed_fallback valid-review taxonomy fix (SL-PHASE-5Q-AIFAILED-FIX). Root cause: `_aIsIntentionallyNoDraft` (Node A) and `_5q3IsIntentionallyNoDraft` (Node J) only exempted `HUMAN_ONLY`, `NO_DRAFT`, `human_only`, `none` from missing-draft check. `ai_failed_fallback` was not included — causing cases like case-b0cfd04c (PROOF_REQUEST + AI_SUPERVISED_OR_TEMPLATE + ai_failed_fallback + missing draft_text + valid upstream context) to become `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`. Fix: added `ai_failed_fallback` to both guards (and ctx path in Node J). The `ai_failed_fallback` banner already existed in Node J at ~18100 but was never reached. HumanApproval versionId: `c51ac1f3` → `ee2f160e`. Harness 240/240 PASS (+24 P13 tests). Decision unchanged (`84e6638e`).

**Session 8 update (2026-07-04):** PROOF_REQUEST learned-draft pathway (SL-PHASE-5Q-PROOF). Root cause: `_5qDraftPolicyFor` and `draftPolicyFor` had `PROOF_OR_CASE_STUDY_REQUEST → AI_SUPERVISED_OR_TEMPLATE` but no `PROOF_REQUEST` entry (default → HUMAN_ONLY). After classification correction sets `micro_intent=PROOF_REQUEST`, no draft-policy recalculation happened — HUMAN_ONLY persisted. Fix (Node D): `const draftPolicy` → `let draftPolicy`; upgrade guard added (activates only when `activeFormDraftRuleMatches.length > 0` for PROOF_REQUEST); PROOF_REQUEST entry added to `buildAIPrompt` `intInstr` map with safety-first instruction. Classification correction rules (rule_type=classification_correction) are excluded from `activeFormDraftRuleMatches` — they are never counted as draft learning. Current live case (case-5de97d7a, rule 1dba7933) has classification correction only → HUMAN_ONLY correctly preserved. Future owner-created style rules for PROOF_REQUEST will trigger the upgrade path. Decision versionId: `4cb34768` → `84e6638e`. Harness 216/216 PASS (+26 P12 tests). HumanApproval unchanged.

**Session 7 update (2026-07-04):** Node J syntax crash fix. Previous session introduced a JavaScript `SyntaxError` in Node J: `const // SL-PHASE-5Q-PROOF-FIX: ...` (orphaned `const` before comment) + `_5q3RowLooksMissing = ...` declared without `const`. This caused Node J to throw `UNKNOWN` at render time for all cases including valid PROOF_REQUEST/HUMAN_ONLY cases. Fix: removed orphaned `const`, added `const` to `_5q3RowLooksMissing` declaration. HumanApproval versionId: `e0e89e0e` → `c51ac1f3`. Harness 190/190 PASS (+22 P11 tests including `node --check` JS syntax validation). Decision unchanged. Classification learning evidence from cases case-d24661f0/case-3838bcee: CONFIRMED — active learning applied (rule `1dba7933`, source case-bd8e453e). Review page now renders correctly.

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
