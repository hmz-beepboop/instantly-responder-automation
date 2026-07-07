# SL-PHASE-5Q Live Behavioural Verification
**Created:** 2026-07-04 (session 3 — 5Q-LIVE-REGRESSION repair)  
**Decision versionId:** `84b941a4` (session 16 S2 upgrade engine + proof-promotion gate — unchanged in Run 3)  
**HumanApproval versionId:** `99b4c092` (Fable Run 3 UI-visibility fix; was `0054f20b`)

**Fable Run 3 update (2026-07-07) — five live rows re-fetched via REST (Review Cases `WMTmI6UNjZZgSU3h`); the session-16 owner retest is now live-verified:**

- **case-58e6b3b0** ("Anything to establish trust between us and your company?"): PASS — `INFORMATION_REQUEST/PROOF_REQUEST` (baseline = effective), `reply_mode=AI_DRAFT_APPROVAL`, real AI draft (484 chars, `ai_attempt.ok=true`, model gpt-5.4-mini, no fallback), style rule `ea15095a` injected with a truthful non-empty impact summary — session 16's S2-SUMMARY fix confirmed live.
- **case-5e2fbcbe** ("Mind breaking down what the setup actually is?"): PASS — `INFORMATION_REQUEST/OFFER_EXPLANATION` (NOT hijacked to PROOF_REQUEST), AI draft present, `ai_upgrade_eligible=false / DRAFT_POLICY_ALREADY_AI` (truthful) — session 16's PROOF promotion gate confirmed live.
- **case-4a5596a0 / case-07bd8bb5 / case-659d1e01** ("Not now. Maybe later" / "I can't right now." / "I don't have time right now. Maybe later"): **backend SUCCESSES, not failures.** All three: baseline `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` → effective `AMBIGUOUS/NON_PRIORITY` via rule `6e50fd54`; `reply_mode=AI_DRAFT_APPROVAL`; `ai_attempt.ok=true`; drafts present (97-110 chars); no fallback; `ai_upgrade_eligible=true / ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS` — the session-16 S2 upgrade engine is live-proven for the not-now class.
- **Actual defect (proven and fixed):** UI/reporting visibility, not classification/upgrade. (a) The Google Chat notification printed "Micro intent: N/A" (its fallback chain missed `recommended_action_plan.micro_intent`); (b) the review form never displayed Original vs Effective classification, so the row's baseline `AMBIGUOUS` read as final; (c) Node J's correction section labelled the EFFECTIVE micro intent "Original micro intent"; (d) neither surface stated reply_mode or explicit AI draft status. Fix `SL-PHASE-5Q-RUN3-UIVIS` (HumanApproval nodes J + chat D only): Original (detected) vs Effective (used for drafting) block with applied correction rule ID, explicit "Reply mode / AI draft status" line, truthful correction-section labels, chat "Micro intent (effective)" + correction line + reply mode + "(AI draft passed validation)". Offline proof: patched Node J executed against the REAL case-4a5596a0 row — 11/11 render assertions PASS; chat node 6/6. HumanApproval `0054f20b` → `99b4c092`; backup `workflows/humanapproval_backup_0054f20b_pre_run3_ui_visibility.json`. Harness 463/463 (+38 P21). Decision untouched; Sender untouched (read-only audit only); no Instantly POST; Shadow inactive (API-confirmed); Gate 2 unapproved. **Owner action:** open the next review case + chat message and confirm the new fields render.

**Session 16 update (2026-07-07) — S2 live-case trace (cases 64589b37 / 269eed7f / 5afa61d3):** all three owner-reported cases were traced end-to-end from the production Review Cases DataTable (`WMTmI6UNjZZgSU3h`, via REST). Verdicts:

- **case-64589b37** ("This could be useful but not until later in the quarter."): learning WORKED. Baseline `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` → effective `AMBIGUOUS/NON_PRIORITY` via classification rule `6e50fd54`; style rules `877c3d75` + `cdada69d` applied via `post_processor_delta`; the draft correctly asked "When would be a good time to check back in?". It stayed a deterministic template because NON_PRIORITY maps to FIXED_TEMPLATE and the old upgrade guard covered PROOF_REQUEST only — the exact blocking predicate was `microIntent === 'PROOF_REQUEST' && draftPolicy === 'HUMAN_ONLY'` plus `canTryAI` requiring `AI_SUPERVISED_OR_TEMPLATE`. Fixed by the S2 upgrade engine (below).
- **case-269eed7f** ("I don't know if you are trustworthy."): SUCCESS — genuine AI-supervised draft (`draft_source_raw=ai_supervised`, `ai_attempt.ok=true`, zero validation errors) with style rule `ea15095a` injected (applied=1 via `ai_prompt_injection`). Two truthfulness defects: `learning_impact_summary` was empty for the injection path, and the case row stored `reply_mode=HUMAN_ONLY`.
- **case-5afa61d3** ("Before I book, can you give me a quick breakdown of what toy set up?"): CLASSIFICATION FALSE POSITIVE. Genuine OFFER_EXPLANATION setup question hijacked to `PROOF_REQUEST` by active correction rules `d82e94d7`/`1dba7933` (created from trust case case-bd8e453e) because `_5qClassificationRuleAllowedForReply` had content gates for booking and NON_PRIORITY promotions but none for PROOF_REQUEST promotion. Downstream: PROOF_REQUEST trust guidance (`ea15095a`) leaked into a setup answer, and the plan's `reply_draft_status` stayed `NO_DRAFT_HUMAN_ONLY` while a real AI draft existed (status set before the upgrade guard, never re-synced).
- **All three rows** stored `reply_mode=HUMAN_ONLY` because Decision never emitted `reply_mode` — HumanApproval Node A defaults `decision.reply_mode || "" → "HUMAN_ONLY"` for every case.

**Fixes deployed (Decision Node D only; HumanApproval untouched):** (1) `SL-PHASE-5Q-S2-PROOF-GATE` — rules promoting to PROOF_REQUEST now require a trust/proof signal in the reply (`_5qReplyHasProofTrustIntent`); (2) `SL-PHASE-5Q-S2-UPGRADE` — generalized safe deterministic/human→AI upgrade engine with allowlist {PROOF_REQUEST from HUMAN_ONLY; NON_PRIORITY, NOT_NOW from FIXED_TEMPLATE/HUMAN_ONLY}, high-risk/suppress/no-reply classes never upgrade, auditable via `ai_upgrade_eligible`/`ai_upgrade_reason`/`ai_upgrade_blocked_reason`/`effective_classification_used_for_draft_policy` in `learning_attribution`; new `intInstr` entries for NON_PRIORITY/NOT_NOW (acknowledge timing, ask when to check back, no pitch); AI failure falls back to the non-null NOT_NOW template with post-processing; (3) `SL-PHASE-5Q-S2-STATUS-SYNC` — `reply_draft_status` flipped only when contradicted by the actual draft; (4) `SL-PHASE-5Q-S2-REPLY-MODE` — Decision now emits `decision.reply_mode` (AI_DRAFT_APPROVAL / FIXED_TEMPLATE_APPROVAL / HUMAN_ONLY / NO_REPLY) so the case row is truthful; (5) `SL-PHASE-5Q-S2-SUMMARY` — single-rule AI injection now produces a truthful non-empty impact summary; multi-rule injection states per-rule impact is unproven. Decision `4474c96a` → `84b941a4`. Harness 425/425 PASS (+50 P20 tests incl. reproductions of all three cases, high-risk no-upgrade protections, rollback/deactivation drill, newer-overrides-older, scope containment). Backup: `workflows/decision_backup_4474c96a_pre_s2_upgrade_engine.json`. Sender untouched; no Instantly POST; Shadow inactive (API-confirmed); Gate 2 unapproved. **Owner retest:** (a) send a fresh not-now reply — expect an AI-supervised draft (banner "AI-generated draft for human review") that acknowledges timing and asks when to check back, with `ai_upgrade_eligible=true` in metadata; (b) send a fresh setup-breakdown question — expect OFFER_EXPLANATION (NOT PROOF_REQUEST) with a setup-steps draft; (c) send a fresh trust reply — expect PROOF_REQUEST AI draft as in case-269eed7f, now with a non-empty learning impact summary.

**Session 15 update (2026-07-06):** remaining `AI_OUTPUT_VALIDATION_FAILED` frequency on proof/trust cases traced with live execution evidence. Exec `5329` (PROOF_REQUEST, current code): AI provider returned output (`ok=true`); the ONLY validation error was `active policy violation: dense paragraph`; the raw draft was safe, honest, and correctly negated ("...no public customer examples or validation signal yet..."). Execs `5286`/`5296` (same day, same intent) passed at ~336 chars / multi-paragraph shape — proving the 360-char dense boundary was the differentiator, not content safety. Execs `4976`/`4980` (2026-07-04, pre-session-12 code) failed on the proof-mention predicate that session 12 already fixed; that fix is confirmed working in current executions. Root cause chain for the residual class: globally-scoped owner style policy `27293ea8` ("short paragraphs", `all_ai_drafts`) arms the dense-paragraph validator for every AI draft, while `intInstr.PROOF_REQUEST` instructed "One concise paragraph" — the prompt invited exactly the shape the validator rejects. Fixes deployed: (1) PROOF_REQUEST prompt instruction now asks for 2-3 short paragraphs with the CTA in its own final paragraph; (2) Node D repairs style-only dense rejections with a whitespace-only sentence-boundary reflow (`_5qReflowDenseParagraphs`) and re-runs the FULL validator — any safety error still falls back unchanged; (3) reflow is recorded truthfully in `ai_attempt` (`style_reflow_applied`, `raw_draft_text_before_reflow`); (4) HumanApproval Node J fallback banner now names the exact failed check(s) and states when the rejection was formatting/style-only. Node smoke test proved the exact exec-5329 draft passes after reflow with wording preserved, and invented-proof drafts still fail. Decision `afe08974` → `4474c96a`; HumanApproval `7aac637e` → `0054f20b`. Harness 375/375 PASS (+26 P19 tests). Backups: `workflows/decision_backup_afe08974_pre_dense_reflow_fix.json`, `workflows/humanapproval_backup_7aac637e_pre_fallback_banner_detail.json`. Sender untouched; no Instantly POST; Shadow inactive; Gate 2 unapproved. Owner retest: send a fresh trust/proof reply — expect an AI-supervised draft (possibly reflowed into 2-3 short paragraphs); if a fallback still occurs, the banner will name the exact failed check.

**Session 14 update (2026-07-05):** trust/proof variant failure repaired and deployed. Live evidence proved case `case-e6e99b67` was submitted (`approval_decision=approve`), stored a correction event (`status=captured_only`), and created active Q12 rows: classification rule `b90ff779-5593-4b02-9a98-6aebd40ef7e8` scoped from `AMBIGUOUS/NON_PRIORITY` to `INFORMATION_REQUEST/PROOF_REQUEST`, plus style rule `9f7c332d-651d-4931-bae3-a17ed2caa131` scoped to `INFORMATION_REQUEST/PROOF_REQUEST`. Follow-up `case-3a05c80c` started as `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY`, so the newer trust correction was not eligible; older NON_PRIORITY rule `6e50fd54` applied, then NON_PRIORITY style rules `877c3d75` and `cdada69d` produced the wrong check-back draft. Fix: Decision classifier now treats trust/proof variants (`trustworthy`, `trust`, `credible`, `believe`, proof/evidence variants) as `INFORMATION_REQUEST/PROOF_REQUEST`; Decision classification-rule guard now blocks NON_PRIORITY promotion when the reply has trust/proof intent. Decision deployed `f6d5b731` → `afe08974`; HumanApproval unchanged `7aac637e`. Harness 349/349 PASS (+23 P18 tests). Backup: `workflows/decision_backup_f6d5b731_pre_trust_variant_fix.json`.

**Session 13 update (2026-07-05):** case-68110963 diagnostic fallback root cause proven and patched. Live Decision execution `5263` had valid upstream context before Node D, then Node D emitted only `{ error: "Invalid or unexpected token " }`. HumanApproval execution `5264` created the diagnostic case from that error-only item; review execution `5265` proved the review token was valid (`token_valid=true`, `token_invalid_reason=OK`). Exact bug: Node D PROOF_REQUEST fallback had `return _prParts.join('` + literal newline + `');`, causing a JavaScript syntax failure before the in-node context-preserving catch could run. Fix: escaped the join string to `return _prParts.join('\\n\\n');`. Decision deployed `9198554c` → `f6d5b731`; HumanApproval unchanged `7aac637e`. Harness 326/326 PASS (+8 P17 tests). Backup: `workflows/decision_backup_9198554c_pre_context_token_fix.json`.

**Session 12 update (2026-07-05):** PROOF_REQUEST AI-fallback non-null fix. Root cause (deeper layer): session 11 eligibility fix worked correctly — the upgrade guard fires and `draftPolicy` upgrades to `AI_SUPERVISED_OR_TEMPLATE` for future PROOF_REQUEST cases with an active style rule. But when AI output fails validation OR the API call fails, `draftText = fallbackText` which was `null` for PROOF_REQUEST (no branch in `buildPolicyAwareFallback`). Result: empty textarea, `ai_failed_fallback` source, draft style rule not counted as applied (only classification rule in `activeLearningRulesApplied`). Evidence: case-9996084f shows `AI_SUPERVISED_OR_TEMPLATE / ai_failed_fallback`, eligible=2, applied=1 (classification). Fix 1: `validateAI` — `asksProof = true` when `microIntent === 'PROOF_REQUEST'` prevents false-positive validation rejection when guidance contains "do not mention validation" restrictions. Fix 2: `buildPolicyAwareFallback` — PROOF_REQUEST branch added returning a safe, non-null fallback: honest proof-gap acknowledgment + diagnostic question. No invented proof, results, or credibility claims. Human review still required. Decision deployed: `0e1e1193` → `9198554c`. HumanApproval unchanged (`7aac637e`). Harness: 318/318 PASS (+26 P16 tests).

**Session 11 update (2026-07-05):** PROOF_REQUEST draft-learning activation bridge fix. Root cause: teaching case case-532bae78 style rule was written to Q12 with `proposed_rule_scope=requires_human_scope_decision` (no scope checkbox checked by owner → Node N default → SL-P2A else branch). `_5qPolicyApplies` returned false → rule not eligible → upgrade guard never fired in case-380ae677. Fix 1: Node D `_5qPolicyApplies` adds fallback for unresolvable scope → micro_intent/broad_category matching. Fix 2: Node J form pre-checks `current_micro_intent_only` for new cases → future rules get `micro_intent` scope directly. Decision deployed: `84e6638e` → `0e1e1193`. HumanApproval deployed: `c20af72e` → `7aac637e`. Harness: 292/292 PASS (+26 P15 tests).

---

## Variant B Execution Trace Results

All 4 Variant B cases ran against Decision versionId `a3916c2e` (confirmed via n8n API).

### Case 1 — Booking request (exec 4846)
**Reply:** "Is there a link where I can book a quick walkthrough?"  
**Expected classification:** INFORMATION_REQUEST / BOOKING_REQUEST  
**Actual classification:** INFORMATION_REQUEST / OFFER_EXPLANATION  
**Booking rule 97eb3b0a applied:** NO — wrong classification scope  
**Setup rule 48e10cac applied:** YES — misclassification caused setup guidance to apply  
**Draft observed:** Booking link + 3-step setup process  

**Root cause:** AI misclassified "walkthrough" as a product explanation (OFFER_EXPLANATION) rather than a booking request (BOOKING_REQUEST). The booking post-processor (GAP-1 fix) was not triggered because the wrong micro-intent was set. Setup guidance from rule 48e10cac bled into the booking draft.

**Classification fix needed:** Not a deterministic code bug — AI classification prompt gap. Options: (a) improve AI classification prompt to distinguish walkthrough/booking from setup explanation, (b) add classification correction rule for this case, (c) accept as ambiguous and handle via review form.

**Verdict:** STALE with respect to GAP-1. GAP-1 fix is correct but was not reached due to upstream classification error. Decision patch scope: classification prompt or correction rule — NOT the post-processor.

---

### Case 2 — Setup/process breakdown (exec 4855)
**Reply:** "Before I book, can you give me a quick breakdown of what you actually set up?"  
**Actual classification:** INFORMATION_REQUEST / OFFER_EXPLANATION  
**Draft observed:** "Absolutely. Here's the setup in simple terms: 1..."  

**Root cause:** Correct classification. Setup rule 48e10cac applied. Draft shows setup steps before CTA.  
**Verdict:** PASS — broadly acceptable. No leakage of booking or pricing guidance detected.

---

### Case 3 — Not-now / later (exec 4859)
**Reply:** "This could be useful, but realistically, we would not review something like this until later in the quarter."  
**Actual classification:** AMBIGUOUS / AMBIGUOUS_SHORT_REPLY  
**After correction (rule 6e50fd54):** NON_PRIORITY → NOT_NOW template used ✓ (GAP-3 working)  
**cdada69d style rule 97eb3b0a applied:** Eligible, but post-processing did NOT modify draft  
**Draft observed:** "Understood. I'll close the loop for now. Feel free to reach out if the timing changes."  

**Root cause:** GAP-3 fix correctly routes NON_PRIORITY → NOT_NOW FIXED_TEMPLATE. cdada69d IS eligible. But the post-processor `_5qApplyActiveFormRuleInstructionToDraft` has no handler for style rules on NOT_NOW templates — it only handles BOOKING_REQUEST/MEETING_TIME_REQUEST. The guidance (ask when to check back) is built but never consumed by the NOT_NOW template path.

**Remaining gap — GAP-3b:** cdada69d post-processing is unimplemented for NOT_NOW style rules. The base NOT_NOW template produces "close the loop" but does not ask "when to check back."

**Decision patch required:** Narrow patch to NOT_NOW post-processing path to consume cdada69d style guidance (e.g. append "When would be a better time to reconnect?" or equivalent). Must not use cdada69d's instruction text verbatim in draft. Must use an approved follow-up question. Requires anti-false-positive verification.

**Verdict:** FAIL — owner live retest still required after GAP-3b patch.

---

### Case 4 — Pricing / minimum commitment (exec 4865)
**Reply:** "Before scheduling, can you tell me what the lowest commitment would be to try this?"  
**Expected classification:** PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST  
**Actual classification:** INFORMATION_REQUEST / OFFER_EXPLANATION  
**Pricing rule 493884ad applied:** NO — wrong classification scope  
**Setup rule 48e10cac applied:** YES — misclassification caused setup guidance to apply  
**Draft observed:** "The lowest commitment is a short setup phase so we can confirm fit before anything broader..." + 3-step process  

**Root cause:** AI misclassified "lowest commitment" as an offer explanation request. The pricing post-processor (GAP-2 fix, `_5qApplyPricingConstraints`) was not triggered. Setup guidance applied instead. Draft answered "lowest commitment = short setup phase" which is derived from setup guidance, not an actual pricing/commitment answer.

**Assessment:** While the draft is not fabricating invented prices (which is good), it's deflecting into setup process instead of answering the pricing/commitment question directly. The GAP-2 fix is correct but was not reached due to upstream classification error.

**Classification fix needed:** AI classification prompt or correction rule for pricing/commitment questions that get classified as OFFER_EXPLANATION. Not a post-processor bug.

**Verdict:** STALE with respect to GAP-2. Decision patch scope: classification prompt or correction rule.

---

## Summary of Variant B Live Triage

| Case | Version | Rule applied | Classification correct | Draft correct | Gap |
|------|---------|-------------|----------------------|---------------|-----|
| Booking | a3916c2e ✓ | 48e10cac (wrong) | NO — OFFER_EXPLANATION | PARTIAL | Classification bug |
| Setup/process | a3916c2e ✓ | 48e10cac (correct) | YES | YES | None |
| Not-now | a3916c2e ✓ | cdada69d (eligible, not consumed) | YES (after correction) | FAIL | GAP-3b: NOT_NOW post-processing |
| Pricing | a3916c2e ✓ | 48e10cac (wrong) | NO — OFFER_EXPLANATION | FAIL | Classification bug |

---

## Decision Patch Scope Required

### GAP-3b — PATCHED (session 4)
**Fix applied:** `_5qApplyActiveFormRuleInstructionToDraft` now has a NON_PRIORITY/NOT_NOW handler. When cdada69d guidance is active and contains "check back/when would be/better time", the "close the loop" template line is replaced with "When would be a good time to check back in?". Instruction text is NOT pasted verbatim. cdada69d instruction text does not appear in output.  
**Harness:** P8.1–P8.18 all PASS.

### Classification correction for BOOKING/PRICING confusion — PATCHED (session 4)
**Root cause confirmed:** Section B `detectMicroIntent` did not recognise `walkthrough`/`demo`/`tour`/`meeting` as booking signals, and did not recognise `commitment`/`retainer` as pricing signals.  
**Fix applied:**  
- FIX-1: `book (a )?(time|slot|call)` extended to `book (?:a (?:quick |brief )?)?(time|slot|call|walkthrough|demo|tour|meeting)`
- FIX-2: pricing regex extended with `commitment|retainer`
- FIX-1a: `_5qReplyHasBookingIntent` (Section D guard) extended consistently  
**Harness:** P7.1–P7.12 all PASS. Setup/process regression (P7.8) confirmed clean.

**Session 4 Decision versionId:** `a3916c2e` → `937488a9`. Active: true. 119/119 PASS.

---

## Review Form Regression (session 3)

**Root cause confirmed:** Previous session patched Node J using stale HumanApproval `9c71882f` as source, not the modern `0fa9d0ce` lineage. Old `draft_revision_type`, `desired_future_behavior`, and `What should the system do next time?` fields reintroduced.

**Fix applied:** Node J replaced surgically from `agent/codex/sl-phase-5q-checkpoint-20260701` (0fa9d0ce lineage). Modern `draft_learning_instruction` combined field restored. Old fields removed.

**Harness:** 89/89 PASS session 3 → 119/119 PASS session 4 (+30 new P7+P8 tests).

**Production applied:** HumanApproval `54b7a8e4` → `849c2c64`. Active state preserved. No Sender touched.

---

## Owner Action Required (session 4 — Variant C live retests)

1. **Run Variant C live retests** — send fresh emails from Instantly for all 4 cases:
   - Booking: "Is there a link where I can book a quick walkthrough?" → expect BOOKING_REQUEST, booking link draft
   - Pricing/commitment: "Before scheduling, what's the minimum commitment to try this?" → expect PRICING_REQUEST or AI_COMMERCIAL_SUPERVISED draft with commitment answer before CTA
   - Not-now: "This could be useful but not until later in the quarter." → expect "When would be a good time to check back in?" in draft (not "close the loop")
   - Setup/process: "Before I book, can you give me a quick breakdown of what you set up?" → expect OFFER_EXPLANATION, setup steps draft (regression guard)
2. **Confirm booking classification** after Variant C — if still OFFER_EXPLANATION, investigate whether `walkthrough` is in the live Section B code (check production execution trace).
3. **Paste Variant C execution IDs** into this report when available.
