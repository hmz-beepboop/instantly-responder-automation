# OPERATION_HANDOFF.md

Timestamped log of agent sessions. Most-recent entry first. This file is the authoritative execution state for this repo and takes precedence over Obsidian notes for current project status.

---

## 2026-07-05 00:00 BST — GitHub Checkpoint / Build Preservation (IN PROGRESS)

**Agent:** Codex
**Objective:** Documentation and Git/GitHub checkpoint only. Preserve the current largely working SL-PHASE-5Q responder build before any further repair work.

**Current known production version IDs (from handoff/reports, not freshly queried via n8n API):**

| Workflow | ID | Current known versionId | Status |
|----------|----|-------------------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `afe08974-b635-4a56-be42-d005ba7f3520` / short `afe08974` | Latest known trust/proof variant repair deployed |
| HumanApproval | `9aPrt92jFhoYFxbs` | `7aac637e-e57a-44b3-91c4-96b9e4f0d064` / short `7aac637e` | Latest known modern review/scope/default repair deployed |

**Current known status:** Largely working, approximately 97% ready, and should be preserved before more changes. Latest harness reported `349/349 PASS`. Exact proof/trust classification path is mostly working after the trust/proof variant repair. `trust`, `trustworthy`, `credible`, `believe`, and proof/evidence variants were patched into the Decision classifier priority and NON_PRIORITY leakage guard. Sender remains untouched. Shadow Evaluator remains inactive. Gate 2 remains unapproved. Autonomous remains disabled.

**What is working:** Decision and HumanApproval current known versions reflect SL-PHASE-5Q fixes through the trust/proof variant repair. PROOF_REQUEST classification learning and style-rule eligibility are materially improved. Context/token regression was repaired. Review form modern path and fallback taxonomy are documented as repaired in the current handoff/reports. No Sender trigger, no Instantly POST, no autonomous activation, and no Gate 2 approval are recorded for these latest repairs.

**Not yet fully verified:** A fresh live owner retest is still required after the trust/proof variant repair. Production version metadata was not re-queried in this checkpoint session; `scripts/assert-hmz-production-target.ps1` passed, but no n8n API metadata call was made. SL-PHASE-5Q live verification and anti-false-positive audit remain the gating evidence before any autonomous or 5R work.

**Current blocker / next task:** Remaining known issue is `AI_OUTPUT_VALIDATION_FAILED` / safe fallback banner appearing too often on proof/trust cases. Next repair task is to reduce fallback frequency on proof/trust cases without inventing proof, results, guarantees, customer examples, or credibility claims.

**Do-not-regress rules:** Do not regress to older `README.md` or local dry-run project state. Do not touch Sender. Do not activate Shadow Evaluator. Do not approve Gate 2. Do not enable autonomous. Do not start SL-PHASE-5R before SL-PHASE-5Q live verification and anti-false-positive audit are complete. Keep `OPERATION_HANDOFF.md` as the source of truth when it conflicts with README or older docs.

**Files changed in checkpoint session:** `OPERATION_HANDOFF.md`, `README.md`, `CLAUDE.md`, `AGENTS.md` if safety checks pass. No application code or workflow logic intentionally changed.

**Git branch:** `codex/5q-context-token-forensic-20260705` before checkpoint; preferred checkpoint branch is `checkpoint/sl-phase-5q-largely-working-20260705`, but branch switch may be skipped because the worktree is already dirty with many pre-existing non-documentation changes.

**Commit / push / tag result:** Pending safety checks.

**Exact next recommended owner/action:** Preserve this checkpoint, then run a fresh live proof/trust retest (`Ah, I don't know if you are trustworthy.`). If classification is `INFORMATION_REQUEST / PROOF_REQUEST` but the safe fallback banner appears too often, start a narrow Decision-only repair session for AI validation/fallback-frequency on proof/trust cases. Do not start autonomous or SL-PHASE-5R first.

---

## 2026-07-05 — SL-PHASE-5Q Trust/Proof Variant Classification-Learning Repair (DEPLOYED)

**Agent:** Codex
**Objective:** Prove and repair why `Ah, I don't know if you are trustworthy.` remained `AMBIGUOUS / NON_PRIORITY` after the owner corrected `case-e6e99b67` to `INFORMATION_REQUEST / PROOF_REQUEST`.

**Root cause (live-proven):** The correction was submitted and stored, but not consumable for the follow-up baseline. `case-e6e99b67` produced correction event row `66` (`approval_decision=approve`, `status=captured_only`, old `AMBIGUOUS/NON_PRIORITY`, corrected `INFORMATION_REQUEST/PROOF_REQUEST`) and active Q12 rows: classification rule `b90ff779-5593-4b02-9a98-6aebd40ef7e8` scoped from `AMBIGUOUS/NON_PRIORITY`, plus PROOF_REQUEST style rule `9f7c332d-651d-4931-bae3-a17ed2caa131`. Follow-up `case-3a05c80c` started as `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY`, so `b90ff779` was not eligible. Older rule `6e50fd54` promoted it to `NON_PRIORITY`, then NON_PRIORITY draft rules `877c3d75` and `cdada69d` generated the wrong check-back draft.

**Fix:** Decision only. Section B now gives trust/proof variants (`trust`, `trustworthy`, `credible`, `believe`, proof/evidence wording) deterministic priority as `INFORMATION_REQUEST / PROOF_REQUEST`. Node D now blocks NON_PRIORITY classification-rule promotion when the reply has trust/proof intent. No proof claims or reply text were hardcoded.

**Harness:** 349/349 PASS (was 326/326; P18 added 23 trust/proof variant, NON_PRIORITY leakage, source-case rule eligibility, attribution, and safety tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `f6d5b731` | `afe08974` | Trust/proof classifier priority + NON_PRIORITY classification guard |

**HumanApproval unchanged** (`7aac637e`). Backup created: `workflows/decision_backup_f6d5b731_pre_trust_variant_fix.json`. Local Decision export refreshed from production. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) confirmed inactive. Gate 2 remains unapproved.

**Owner action required:** Send a fresh `Ah, I don't know if you are trustworthy.` reply. Expected: `INFORMATION_REQUEST / PROOF_REQUEST`; PROOF_REQUEST style learning eligible; no NON_PRIORITY check-back draft.

---

## 2026-07-05 — SL-PHASE-5Q Context/Token Upstream Regression Repair (DEPLOYED)

**Agent:** Codex
**Objective:** Prove why `case-68110963` rendered as `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK` with `Invalid or unexpected token` and all upstream context missing.

**Root cause (live-proven):** Not review-link token validation, case lookup, Google Chat URL corruption, Intake payload loss, or owner/test misuse. Production execution `5263` showed Decision received valid upstream context before Node D (`campaign_id=531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email present, sender `hamzah@teamhmzautomations.com`, subject/reply text present, classifier `INFORMATION_REQUEST / OFFER_EXPLANATION`). Decision Node D then failed before its in-node catch could preserve context and emitted only `{ error: "Invalid or unexpected token " }`. HumanApproval execution `5264` created `case-68110963` from that error-only item, generated a diagnostic fallback identity (`DIAGNOSTIC_MISSING_INTAKE_...`), and stored `context_missing.blocked=true`, `status=HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`, all required fields missing, and `upstream_error="Invalid or unexpected token "`. Review execution `5265` proved `token_valid=true`, `token_invalid_reason=OK`; the token was not the cause.

**Exact code bug:** Decision Node D PROOF_REQUEST fallback branch contained a JavaScript syntax error:
`return _prParts.join('` followed by a literal newline and then `');`. n8n could not compile the Code node, so the workflow-level error output dropped valid Decision/Intake context before HumanApproval.

**Fix:** Decision Node D only — changed the PROOF_REQUEST fallback join to escaped newline source: `return _prParts.join('\\n\\n');`.

**Harness:** 326/326 PASS (was 318/318; P17 added 8 context/token/upstream regression tests, plus Node J syntax check now has a static fallback when `node` is unavailable in the agent shell).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `9198554c` | `f6d5b731` | Node D syntax repair in PROOF_REQUEST fallback join |

**HumanApproval unchanged** (`7aac637e`). Backup created: `workflows/decision_backup_9198554c_pre_context_token_fix.json`. Local Decision export refreshed from production. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) remains inactive. Gate 2 remains unapproved.

**Owner action required:** Send a fresh seeded reply in the existing Instantly campaign thread. Verify Instantly shows campaign ID, lead email, sender email, subject/thread, and reply body before sending. The next review case should no longer be an error-only diagnostic from Node D; it should preserve upstream context and render a normal review form or a legitimate context diagnostic if Instantly truly omits required fields.

---

## 2026-07-05 — SL-PHASE-5Q PROOF_REQUEST AI-Fallback Non-Null Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix the empty textarea for PROOF_REQUEST cases when AI fails after the session 11 eligibility fix.

**Root cause (proven from code):** Session 11 fixed eligibility correctly — the upgrade guard fires and `draftPolicy` upgrades to `AI_SUPERVISED_OR_TEMPLATE` when the style rule from case-a92bb763 is active. AI is called. But when AI output fails validation OR the API call fails, `draftText = fallbackText`. `buildPolicyAwareFallback` had no PROOF_REQUEST branch — it fell through to `return deterministicText` which is `null` (no PROOF_REQUEST entry in `MI_TEMPLATES`). Result: `draftText = null` → empty textarea, `draftSource = ai_failed_fallback`, `aiDraftUsedGuidance = false` (because `draftSource !== 'ai_supervised'`) → draft style rule not counted as applied in `activeLearningRulesApplied` → only classification rule 1dba7933 shown as applied. Evidence: case-9996084f (`AI_SUPERVISED_OR_TEMPLATE / ai_failed_fallback`, found=19, eligible=2, applied=1, empty textarea).

**Fix 1 (Decision Node D — `validateAI`):**
- `asksProof = microIntent === 'PROOF_REQUEST' || /.../.test(prospect)` — ensures `asksProof = true` for PROOF_REQUEST micro_intent.
- Prevents false-positive validation rejection if any active guidance rule contains "do not mention validation unless the prospect asks" (the prospect's "How can I trust you?" doesn't contain the trigger words, so `asksProof` would be `false` without this fix).

**Fix 2 (Decision Node D — `buildPolicyAwareFallback`):**
- Added PROOF_REQUEST branch before the HOW_IT_WORKS/AMBIGUOUS fallback.
- Returns a safe, non-null deterministic fallback: honest proof-gap acknowledgment ("We don't have public customer examples or case studies to point to yet. We're at an early validation stage...") + diagnostic question ("Would that be worth the time?").
- No invented proof, results, guarantees, case studies, or customer examples.
- Human review still required before send.

**Harness:** 318/318 PASS (was 292/292; P16 added: 26 new PROOF_REQUEST AI-fallback, validateAI guard, and safety tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `0e1e1193` | `9198554c` | Node D `validateAI` asksProof guard + `buildPolicyAwareFallback` PROOF_REQUEST branch |

**HumanApproval unchanged** (`7aac637e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. The review form should now show a non-empty draft in the textarea — a safe proof-gap acknowledgment with a diagnostic question. Edit as needed and approve/send or approve for learning. If the textarea is still empty, check the n8n execution log for the specific AI failure reason in `aiAttempt.fallback_reason`.

---

## 2026-07-05 — SL-PHASE-5Q PROOF_REQUEST Draft-Learning Activation Bridge Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix the missing bridge between teaching case (case-532bae78) manual reply + draft_learning_instruction and future PROOF_REQUEST AI-supervised draft generation.

**Root cause:** Style rule from case-532bae78 was written to Q12 (rule count 17→18 confirmed) but was NEVER eligible in `_5qPolicyApplies`. The owner submitted the form without selecting a scope checkbox. Node N fell back to `draft_improvement_scope = "unsure_review_needed"` (default). SL-P2A mapped this to `proposed_rule_scope = "requires_human_scope_decision"` (the else branch). In Decision Node D, `_5qPolicyApplies` returned `false` for this scope → rule not eligible → `activeFormDraftRuleMatches = []` → upgrade guard never fired → PROOF_REQUEST remained HUMAN_ONLY.

**Fix 1 (Decision Node D — `_5qPolicyApplies`):**
- Added fallback for `scope === 'requires_human_scope_decision' || scope === 'unsure_review_needed'`.
- Falls back to `_5qPolicyMicroMatches(policy.micro_intent_scope, cat, mi)` if `micro_intent_scope` is set, else `classification_scope` category match.
- Fixes the existing rule already in Q12 from case-532bae78 (will now be eligible for PROOF_REQUEST cases).

**Fix 2 (HumanApproval Node J — form scope default):**
- Changed `_5qDraftScopes` default for new cases from `["unsure_review_needed"]` to `["current_micro_intent_only"]`.
- The "current_micro_intent_only" scope checkbox is now pre-checked for new cases.
- Future rules get `proposed_rule_scope = "micro_intent"` directly via SL-P2A → no fallback needed.
- Previously reviewed cases with saved scopes are preserved (not overridden).

**Harness:** 292/292 PASS (was 266/266; P15 added: 26 new PROOF_REQUEST draft-learning bridge tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `84e6638e` | `0e1e1193` | Node D `_5qPolicyApplies` unresolvable-scope fallback |
| HumanApproval | `9aPrt92jFhoYFxbs` | `c20af72e` | `7aac637e` | Node J form scope default → current_micro_intent_only |

**No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.**

**Owner action required:** Send another "How can I trust you?" reply to generate a fresh PROOF_REQUEST case. The review form should now show: (1) scope checkbox pre-checked at "current_micro_intent_only"; (2) on subsequent cases, if the existing case-532bae78 style rule is eligible, the upgrade guard should fire and produce an AI-supervised draft using the proof-safety prompt. Human approval still required before send.

---

## 2026-07-05 — SL-PHASE-5Q Valid-Fallback Submit/Reopen Repair (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix `CONTEXT_MISSING_BLOCKED` on submit + diagnostic fallback on reopen for valid `ai_failed_fallback` cases (case-13c3dad3 class).

**Root causes:**
- Node N `rowLooksMissing`: no `isIntentionallyNoDraft` exemption → empty `draft_text` on `ai_failed_fallback` cases triggered `contextMissingBlocked=true` → blocked submit despite valid upstream context.
- Node J `_5q3MissingContext`: included `rc.status === "CONTEXT_MISSING_BLOCKED"` as standalone trigger → after blocked submit set status, reopening showed diagnostic fallback even though `sanitized_context` was intact.
- SL-P2A had same `rowLooksMissing` bug → learning capture skipped for `ai_failed_fallback` cases on valid submits.

**Fix (HumanApproval — Node N + Node J + SL-P2A only):**
- Node N: added `_nIsIntentionallyNoDraft` (mirrors Node A/J) before `rowLooksMissing`; removed `rc.status === "CONTEXT_MISSING_BLOCKED"` from `contextMissingBlocked` (relies on `reply_mode` + `rowLooksMissing`).
- Node J: removed `(rc.status === "CONTEXT_MISSING_BLOCKED")` from `_5q3MissingContext`; `_5q3RowLooksMissing` still catches all genuinely missing context.
- SL-P2A: added `_p2aIsIntentionallyNoDraft` exemption; removed `rc.status` check from context-skip condition.
- Genuine diagnostic invariants preserved: `reply_mode=DIAGNOSTIC_CONTEXT_MISSING`, `ctx.context_missing.blocked=true`, and missing required context fields still always diagnostic.

**Harness:** 266/266 PASS (was 240/240; P14 added: 26 new submit/reopen taxonomy tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `ee2f160e` | `c20af72e` | Node N + Node J + SL-P2A submit/reopen fix |

**Decision unchanged** (`84e6638e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Reopen case-13c3dad3 from the review link. The form should now render normally — yellow AI-failed-fallback banner, empty editable textarea, classification/learning metadata, all modern buttons enabled. Submit a learning-only or save action. Confirm CONTEXT_MISSING_BLOCKED is gone and the case can be re-reviewed. Then send another "How can I trust you?" reply to generate a fresh case and confirm the full render → save → approve cycle works end-to-end.

---

## 2026-07-04 — SL-PHASE-5Q ai_failed_fallback Valid-Review Taxonomy Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix recurring valid-context diagnostic fallback when AI draft validation fails (case-b0cfd04c class: PROOF_REQUEST + AI_SUPERVISED_OR_TEMPLATE + ai_failed_fallback + missing draft_text + valid upstream context).

**Root cause:** Both Node A (`_aIsIntentionallyNoDraft`) and Node J (`_5q3IsIntentionallyNoDraft`) only exempted `HUMAN_ONLY`/`NO_DRAFT`/`human_only`/`none` from the missing-draft check. `ai_failed_fallback` was missing → cases where AI ran but output failed validation (draft_source=ai_failed_fallback, draft_text empty) were flagged as diagnostic fallback despite fully valid upstream context. The `ai_failed_fallback` banner at Node J ~18100 already existed but was never reached.

**Fix (HumanApproval Node A + Node J only):**
- Node A: `_aIsIntentionallyNoDraft` — added `|| _aDraftSourceRaw === "ai_failed_fallback"`.
- Node J: `_5q3IsIntentionallyNoDraft` — added `|| rc.draft_source === "ai_failed_fallback"` and `|| ctx.draft_source === "ai_failed_fallback"` in ctx branch.
- Genuine missing context (campaign, lead_email, sender_email, thread_id, reply_text, UNKNOWN category, missing micro_intent) still triggers diagnostic fallback.

**Review-state taxonomy established:**
- Diagnostic: missing reply_from_email, sender_email, thread_id, reply_text, UNKNOWN category, missing micro_intent — always diagnostic regardless of draft_source.
- Valid human-only: draft_policy=HUMAN_ONLY, draft_source=human_only → exempt.
- Valid ai_failed_fallback: draft_source=ai_failed_fallback → exempt. Existing ai_failed_fallback banner renders (yellow warning, safety constraints, empty editable textarea).
- Valid no-draft: draft_policy=NO_DRAFT, draft_source=none → exempt.

**Harness:** 240/240 PASS (was 216/216; P13 added: 24 new ai_failed_fallback taxonomy tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `c51ac1f3` | `ee2f160e` | Node A + Node J ai_failed_fallback exempt |

**Decision unchanged** (`84e6638e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. The review page must now render normally — yellow AI-failed-fallback banner, empty editable textarea, classification/learning metadata, all modern buttons. If still diagnostic, check n8n execution log for any remaining error in Node A or Node J.

---

## 2026-07-04 — SL-PHASE-5Q PROOF_REQUEST Learned-Draft Pathway (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Allow future PROOF_REQUEST draft-learning rules to generate AI-supervised drafts; keep current HUMAN_ONLY behaviour while only classification correction exists.

**Root cause:** `_5qDraftPolicyFor` (and `draftPolicyFor` in Section B) mapped `PROOF_OR_CASE_STUDY_REQUEST → AI_SUPERVISED_OR_TEMPLATE` but had no `PROOF_REQUEST` entry — default fell through to `HUMAN_ONLY`. After classification correction set `micro_intent=PROOF_REQUEST`, no draft-policy recalculation occurred.

**Fix (Decision Node D only):**
- `const draftPolicy` → `let draftPolicy` (allows in-place upgrade).
- Upgrade guard: if `microIntent === 'PROOF_REQUEST'` AND `draftPolicy === 'HUMAN_ONLY'` AND `activeFormDraftRuleMatches.length > 0`, upgrade to `AI_SUPERVISED_OR_TEMPLATE`.
- `activeFormDraftRuleMatches` includes only `rule_type=style` rules (via `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`). Classification correction rules (`rule_type=classification_correction`) are excluded — classification learning alone does NOT trigger the upgrade.
- Added `PROOF_REQUEST` entry to `buildAIPrompt` `intInstr` map with safety-first instruction (no invented proof/results/customer claims).

**Current state:** Case case-5de97d7a has rule `1dba7933` (classification correction only) → upgrade condition is `false` → PROOF_REQUEST correctly remains HUMAN_ONLY. Upgrade path is ready for future owner-created style rules for PROOF_REQUEST.

**Harness:** 216/216 PASS (was 190/190; P12 section added: 26 new PROOF_REQUEST learned-draft pathway tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `4cb34768` | `84e6638e` | Node D PROOF_REQUEST draft-learning upgrade guard + intInstr |

**HumanApproval unchanged** (`c51ac1f3`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** To enable AI drafts for future PROOF_REQUEST cases, use the review form to create a draft-learning rule with `rule_type=style` and `micro_intent_scope=PROOF_REQUEST`. Once that rule is active in Q12, the upgrade guard will fire and AI-supervised drafts will be generated — human approval still required before send.

---

## 2026-07-04 — SL-PHASE-5Q Node J Syntax Crash Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix live render crash (UNKNOWN at node J) for valid PROOF_REQUEST/HUMAN_ONLY cases after session 6 deploy.

**Root cause:** Session 6 introduced a JavaScript `SyntaxError` in Node J. The comment placement was wrong: `const // SL-PHASE-5Q-PROOF-FIX: ...` (line 59) left an orphaned `const` keyword with no variable declaration — only a comment followed on the same line. Line 61 then declared `_5q3RowLooksMissing = ...` without `const`/`let`/`var`. These two errors together caused n8n to report `UNKNOWN at node J. Render Review Form HTML` for every case, including valid PROOF_REQUEST cases. The session 6 harness (168/168 Python simulation) missed this because it simulates logic in Python and never runs the actual JavaScript.

**Fix (HumanApproval Node J only):**
- Line 59: `const // SL-PHASE-5Q-PROOF-FIX: ...` → `// SL-PHASE-5Q-PROOF-FIX: ...` (removed orphaned `const`)
- Line 61: `_5q3RowLooksMissing = ...` → `const _5q3RowLooksMissing = ...` (added `const` declaration)
- Verified with `node --check`: SYNTAX OK.

**Harness:** 190/190 PASS (was 168/168; P11 section added: 22 new tests including `node --check` JS syntax validation to prevent recurrence).

**Classification learning confirmed (live):** Cases case-d24661f0 and case-3838bcee both showed active learning applied, rule `1dba7933-c38c-4bc1-a7d2-3723af0b2711`, source case-bd8e453e, marker `humanapproval_form_created_learning`, effective classification `INFORMATION_REQUEST / PROOF_REQUEST`. Classification learning is materially evidenced.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `e0e89e0e` | `c51ac1f3` | Node J syntax crash fix (two-line const error) |

**Decision unchanged** (`4cb34768`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. Review page must now render fully — HUMAN_ONLY banner, empty editable textarea, classification/learning metadata, all modern buttons. If blank page persists, check n8n execution log for any remaining error.

---

## 2026-07-04 — SL-PHASE-5Q PROOF_REQUEST / HUMAN_ONLY Review-Path Repair (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix valid PROOF_REQUEST/HUMAN_ONLY cases incorrectly becoming `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`.

**Root cause:** Both Node A (Build Review Case Record) and Node J (Render Review Form HTML) in HumanApproval treated missing `draft_text` as a missing-context indicator. For `HUMAN_ONLY` and `NO_DRAFT` policies, `draft_text` is intentionally absent — no AI draft is generated. This caused valid PROOF_REQUEST cases with complete upstream context (campaign, lead_email, sender_email, thread_id, reply_text all present) to be flagged as diagnostic fallback.

**Patches applied (HumanApproval):**
- Node A: `_aIsIntentionallyNoDraft` guard — skips `draft_text` from `missingContextFields` when `draft_policy ∈ {HUMAN_ONLY, NO_DRAFT}` or `draft_source ∈ {human_only, none}`.
- Node J: `_5q3IsIntentionallyNoDraft` guard — same condition exempts `draft_text` from `_5q3RowLooksMissing`.
- Existing HUMAN_ONLY banner at ~line 17090 in Node J was already correct — it was never reached due to the diagnostic intercept.
- Genuine missing context (campaign, lead_email, sender_email, thread_id, reply_text absent) still triggers diagnostic fallback correctly.

**Harness:** 168/168 PASS (was 148/148; P10 section added: 20 new PROOF_REQUEST/HUMAN_ONLY tests).

**Classification-learning verdict (case-bd8e453e):** PARTIAL. The owner corrected `OFFER_EXPLANATION` → `PROOF_REQUEST` on case-bd8e453e, and follow-up cases ea4350f5/cd2c2eb6 showed `PROOF_REQUEST` classification. This is plausible classification learning but cannot be fully proven without a live rule trace from the DataTable (no rule ID confirmed).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `849c2c64` | `e0e89e0e` | Node A + Node J HUMAN_ONLY draft_text exempt |

**Decision unchanged** (`4cb34768`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. Review page should now show the HUMAN_ONLY banner ("No AI draft was generated because this reply requires human-only handling.") with a text area to write a manual reply — not the diagnostic fallback red error page.

---

## 2026-07-04 — SL-PHASE-5Q Attribution False-Positive Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Audit local attribution patch; fix multi-rule over-credit risk; deploy.

**Root cause fixed:** Local patch credited ALL eligible draft rules when `learningAppliedToDraft=true` via AI prompt injection. If 2 rules were eligible (as in the two-email test), both were counted even if only one could provably influence AI output.

**Fix applied (Node D):**
- Added `aiPromptInjectionSingleRule` / `aiPromptInjectionMultiRule` flags.
- Single-rule AI injection → 1 rule credited, `via: 'ai_prompt_injection'`.
- Multi-rule AI injection → 0 rules credited individually; `learning_attribution_uncertain: true`; `via: 'ai_prompt_injection_multi_rule_unproven'`; reason: `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN`.
- Post-processor delta → all eligible rules credited (observable proof).
- Added `learning_guidance_injected` and `learning_attribution_uncertain` to attribution object.

**Harness:** 148/148 PASS (was 119/119; P9 section added: 29 new attribution false-positive tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `937488a9` | `4cb34768` | Attribution false-positive fix |

**HumanApproval unchanged** (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Run a fresh two-email self-learning test (same OFFER_EXPLANATION path). Expect: if 1 eligible rule → `applied count = 1`, `via = 'ai_prompt_injection'`. If 2 eligible → `applied count = 0`, `attribution_uncertain = true`, reason = `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN`.

---

## 2026-07-04 — SL-PHASE-5Q Learning Attribution False-Positive Check (PATCH READY, PENDING DEPLOY)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Diagnose two-email self-improvement test: applied count = 0 despite apparent second-draft improvement.

**Root cause confirmed:** Attribution bug. `draftTextBeforeActiveLearning` is captured AFTER AI generation (index 62,295) but the learning rule is injected into `buildAIPrompt` BEFORE AI generation (index 57,461). For OFFER_EXPLANATION (AI prompt injection path), the post-processor makes no change → delta = 0 → applied count = 0. The learning IS consumed but is invisible to the delta check.

**Verdict:** Second draft improvement is likely REAL learning. Applied count = 0 is a counter bug, not a false positive.

**Patch written to local file — NOT YET DEPLOYED:**
- `workflows/production_decision_current.json` — Node D: added `aiDraftUsedGuidance` flag; extended `learningAppliedToDraft` to include AI prompt injection path; added `learning_applied_via` field (`'ai_prompt_injection'` vs `'post_processor_delta'`)
- Owner must approve and deploy this patch before it takes effect.

**Files changed (local only):**
- `workflows/production_decision_current.json` — patch written
- `reports/SL-PHASE-5Q_LEARNING_ATTRIBUTION_FALSE_POSITIVE_CHECK.md` — created
- `OPERATION_HANDOFF.md` — this entry

**No production changes applied.** Decision versionId still `937488a9`. HumanApproval unchanged (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator untouched. Gate 2 unapproved.

**Owner action required:** Review patch in `workflows/production_decision_current.json` Node D, then deploy via `PUT /workflows/tgYmY97CG4Bm8snI` or run harness after confirming patch is correct.

---

## 2026-07-04 — SL-PHASE-5Q Decision Classification + GAP-3b Repair (PARTIAL → pending Variant C)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** FIX-1 booking/pricing classification correction; FIX-3 NOT_NOW style rule consumption (GAP-3b).

**Files changed:**
- `workflows/production_decision_current.json` — updated from production (versionId `937488a9`)
- `workflows/nodeD_backup_a3916c2e_pre_5q_session4.json` — backup before patch
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 89/89 → 119/119 (+30 new P7+P8 tests)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — session 4 patches documented
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — session 4 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — session 4 verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `a3916c2e` | `937488a9` | FIX-1 booking regex, FIX-2 pricing regex, FIX-3 GAP-3b NOT_NOW consumer |

**HumanApproval unchanged** (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Root causes fixed:**
- FIX-1: Section B `detectMicroIntent` BOOKING_REQUEST regex didn't match `walkthrough`/`demo`/`tour`/`meeting`. Extended: `book (?:a (?:quick |brief )?)?(time|slot|call|walkthrough|demo|tour|meeting)`. Same fix applied to `_5qReplyHasBookingIntent` in Section D.
- FIX-2: Section B `detectMicroIntent` PRICING_REQUEST regex didn't match `commitment`/`retainer`. Extended with those terms.
- FIX-3 (GAP-3b): `_5qApplyActiveFormRuleInstructionToDraft` had no NON_PRIORITY/NOT_NOW handler. Added: when cdada69d guidance active + "check back/when would be/better time" signal present, replaces "I'll close the loop" with "When would be a good time to check back in?"

**Harness:** 119/119 PASS (was 89/89). P7 (booking/pricing classification 12 tests) + P8 (NOT_NOW style 18 tests) added.

**Remaining:** Owner Variant C live retests required — booking, pricing/commitment, not-now, setup/process regression.

---

## 2026-07-04 — SL-PHASE-5Q Live Regression Repair (PARTIAL)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Repair Node J review form regression; triage Variant B live results; update harness.

**Files changed:**
- `workflows/production_humanapproval_current.json` — Node J restored from 0fa9d0ce lineage; pushed to production
- `workflows/nodeJ_backup_pre_live_regression_repair.json` — backup of 54b7a8e4 Node J before repair
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 66/66 → 89/89 (P5 + P6 sections added)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — created (Variant B execution trace + root causes)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — updated to PARTIAL + session 3 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — updated with session 3 Variant B verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `54b7a8e4` | `849c2c64` | Node J regression repair (modern UI restored) |

**Decision unchanged.** No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Node J regression root cause confirmed:**
Previous session patched Node J using stale `9c71882f` as base instead of modern `0fa9d0ce` lineage. Old `draft_revision_type`, `desired_future_behavior`, and `What should the system do next time?` fields reintroduced. `draft_learning_instruction` field and `Save draft and learning` button lost.

**Node J repair:** Surgically replaced from `agent/codex/sl-phase-5q-checkpoint-20260701` (0fa9d0ce). Modern UI confirmed: `draft_learning_instruction`, `Why did you make this change, and what should the system do next time?`, `Save draft and learning`, `Approved for learning only`. Old fields removed. Other nodes (H, L, N, Q2, SL-P2A) preserved.

**Harness: 89/89 PASS** (was 66/66; added P5 Node J regression + P6 Variant B structural sections).

**Variant B live triage (all cases confirmed against a3916c2e):**

| Case | Exec | Classification | Rule applied | Verdict | Root cause |
|------|------|---------------|-------------|---------|-----------|
| Booking | 4846 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 97eb3b0a | FAIL | AI misclassification |
| Setup/process | 4855 | OFFER_EXPLANATION (correct) | 48e10cac | PASS | — |
| Not-now | 4859 | AMBIGUOUS→NON_PRIORITY (correct) | cdada69d eligible but not consumed | FAIL | GAP-3b: NOT_NOW post-processor gap |
| Pricing | 4865 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 493884ad | FAIL | AI misclassification |

**Remaining gaps requiring next session:**

1. **GAP-3b:** cdada69d post-processing not implemented for NOT_NOW/FIXED_TEMPLATE path. Draft says "close the loop" — needs "when to check back" question. Requires narrow Decision patch to NOT_NOW style rule consumer.

2. **Classification correction for booking/pricing:** Booking walkthrough requests and minimum-commitment questions misclassified as OFFER_EXPLANATION. Recommended fix: add classification correction rules (similar to 6e50fd54 pattern) for BOOKING_REQUEST and PRICING_REQUEST signals within OFFER_EXPLANATION context.

**Recommended next actions (owner):**
1. Verify review form renders modern UI (no `draft_revision_type` dropdown, yes `Save draft and learning` button).
2. Next Claude Code session: patch GAP-3b (NOT_NOW post-processor for cdada69d style guidance).
3. Decide booking/pricing classification fix approach (correction rules recommended).
4. Fresh live retest after Decision patch.

---

## 2026-07-04 — SL-PHASE-5Q Self-Improvement Behavioural Closure (COMPLETE)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Root-cause all self-learning behavioural failures; create harness; patch all 4 gaps.

**Files changed:**
- `reports/SL-PHASE-5Q_BASELINE_EVIDENCE_RECONCILIATION.md` — created (session 1), unchanged (session 2)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — created (session 1); updated to COMPLETE + patch status (session 2)
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — created (session 1); updated post-patch verdicts (session 2)
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — created 44/44 (session 1); updated to 66/66 with P1-P4 post-patch tests (session 2)
- `workflows/nodeD_backup_889e1d45.js` — backup of Decision Node D before patch
- `workflows/nodeD_patched.js` — patched Decision Node D (all 4 gaps, pushed to production)
- `workflows/production_decision_current.json` — updated from production (versionId `a3916c2e`)
- `workflows/production_humanapproval_current.json` — updated from production (versionId `54b7a8e4`)
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `889e1d45` | `a3916c2e` | GAP-1, GAP-2, GAP-3 |
| HumanApproval | `9aPrt92jFhoYFxbs` | `0fa9d0ce` | `54b7a8e4` | GAP-4 |

**No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.**

**Patches applied (Decision Node D, versionId a3916c2e):**

- **GAP-1 (booking post-processor):** `_5qApplyActiveFormRuleInstructionToDraft` now detects `instructionUrl`. If URL present → email-content mode (extract booking link). If no URL and instruction matches constraint pattern (`replace the previous|do not ask|do not say|do not use`) → policy-constraint mode: renders template without pasting instruction meta-phrases as email lines. Eliminates hyper-literal booking draft from 97eb3b0a.

- **GAP-2 (pricing constraints):** New function `_5qApplyPricingConstraints` added to post-processing chain. When `behaviouralGuidance` from rule 493884ad is present (marker check + `do not dodge pricing` signal), replaces the hardcoded evasive pricing paragraph with a per-shown-call / setup-fee pricing line. No invented prices. Pilot line added when guidance mentions "small pilot".

- **GAP-3 (NON_PRIORITY template):** `NON_PRIORITY` added to `_5qDraftPolicyFor` → `"FIXED_TEMPLATE"`. `templateMicroIntent` maps `NON_PRIORITY` → `NOT_NOW`. NON_PRIORITY cases now produce a NOT_NOW template draft (not null), enabling cdada69d style rule post-processing.

**Patch applied (HumanApproval Node J, versionId 54b7a8e4):**

- **GAP-4 (revision reason prefill):** `_5pSavedRevisionReason` variable added. For sent-case reopens (`RESPONSE_APPROVED`/`LEARNING_REVISION_APPROVED`), reads `decision_payload.draft_revision_reason` and prefills the `draft_revision_reason` textarea. New cases and old cases without saved reason start blank.

**Harness: 66/66 PASS** (was 44/44 pre-patch; P1-P4 post-patch sections added).

**Key finding — local Decision file is STALE:**
Local `production_decision_current.json` versionId `e1b84f34` ≠ production `889e1d45`.
Production Decision has 1253-line Node D with full 5Q learning infrastructure (Q12 DataTable lookup, policy matching, classification correction, AI prompt injection). Local file has 393-line stale version.
**Action required: update local workflow export after any future Decision patch.**

**Root causes confirmed:**

1. **Booking hyper-literal (case-7c87d21a):** `_5qApplyActiveFormRuleInstructionToDraft` extracts sentences from `97eb3b0a`'s behavioral specification and pastes them as email content. The instruction contains no URL → booking link is null → draft becomes garbled instruction fragments.

2. **Old booking rule (c9860e74) suppression:** WORKING CORRECTLY via scope deduplication. `97eb3b0a` wins (newer timestamp). Not a bug — the literal application (root cause #1) is the only booking failure.

3. **Pricing no delta (case-d555bcfd):** Rule `493884ad` eligible, guidance built, but `AI_COMMERCIAL_SUPERVISED` branch uses a hardcoded deterministic template that never reads `behaviouralGuidance`. Pipeline gap — guidance built but has no consumer.

4. **Setup/process rule (case-083fe26e):** Rule `48e10cac` eligible, guidance IS injected into AI prompt for OFFER_EXPLANATION (AI_SUPERVISED_OR_TEMPLATE). If "no output delta" was observed, it may be an AI compliance issue (AI ignoring guidance) or a measurement artifact. Not a code injection failure.

5. **Not-now/later → HUMAN_ONLY (case-5fa982f4):** Classification rule `6e50fd54` correctly changes AMBIGUOUS/AMBIGUOUS_SHORT_REPLY → NON_PRIORITY. But `NON_PRIORITY` is not in the draft policy map → defaults to HUMAN_ONLY → `draft_text=null`. Style rule `cdada69d` is eligible but has no pathway to reach the draft.

6. **Reopened form reasons:** Node J doesn't prefill `draft_revision_reason` textarea from case history on reopen. Reply text IS prefilled; reasons are not.

**Harness results:** 44/44 PASS (all rules, leakage tests, safety checks, attribution tests).

**Patches applied:** All 4 gaps patched. See patch detail block above.

**Old/new versionIDs:** Decision `889e1d45` → `a3916c2e`. HumanApproval `0fa9d0ce` → `54b7a8e4`.

**Recommended next actions (owner):**
1. Live test GAP-1: BOOKING_REQUEST case — verify draft has no policy meta-phrases ("Replace the previous", "Do not ask them").
2. Live test GAP-2: PRICING_REQUEST case with rule 493884ad active — verify commercial draft shows setup-fee / per-shown-call wording.
3. Live test GAP-3: AMBIGUOUS/AMBIGUOUS_SHORT_REPLY case with rule 6e50fd54 active — verify NON_PRIORITY classification produces NOT_NOW template draft.
4. Live test GAP-4: Reopen a previously approved case — verify `draft_revision_reason` textarea is prefilled.
5. If all 4 live tests pass → SL-PHASE-5Q VERIFIED COMPLETE. Start SL-PHASE-5R if further self-improvement scope identified.

---

## 2026-07-02 03:13 BST — Codex Strategic Repo Audit

**Agent:** Codex
**Objective:** Read-only strategic audit of current repo status and next highest-leverage task.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this concise audit entry only

**Current status observed:**
- Repo docs are inconsistent by age: `README.md` still describes the older six-workflow dry-run state, while newer docs/reports show a seven-workflow supervised responder, production workflow IDs, self-improvement patches, and autonomous shadow-review preparation.
- Latest repo evidence points to: core supervised responder operating in validation/supervised mode; self-improvement infrastructure installed with remaining behavioural proof for draft-improvement learning; autonomous Gate 2 not approved and blocked by the 14-day shadow review plus owner signoffs/allowlists.
- Worktree has many pre-existing modified files; future sessions should use narrow file scopes and avoid assuming a clean baseline.

**Recommended next task:**
Run the docs-guided, owner-supervised draft-improvement learning behavioural proof from `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md` before further autonomous Gate 2 work. This should be a Claude Code/manual-production-validation session, not a Codex implementation session.

---

## 2026-07-02 02:48 BST — Codex Business Brain Pilot

**Agent:** Codex
**Objective:** Verify that this repo is correctly connected to the HMZ Business Brain and that future Codex sessions can use the correct context without reading the full Obsidian vault.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this timestamped pilot entry

**Files read:**
- `OPERATION_HANDOFF.md`
- `AGENTS.md`
- `README.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_BUSINESS_BRIEF.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_PROJECT_INDEX.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_SOURCE_PRIORITY.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_AGENT_RULES.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\02_PROJECTS\INSTANTLY_RESPONDER.md`

**What was verified:**
- `AGENTS.md` is accurate, concise, and safe for future Codex sessions.
- `AGENTS.md` points to the Business Brain root at `C:\Users\Hamzah Zahid\Projects\hmz-business-brain`.
- `AGENTS.md` explicitly says not to read the full vault by default.
- `AGENTS.md` explicitly says this repo's `OPERATION_HANDOFF.md` takes precedence over Obsidian notes for current execution state.
- The named Business Brain files were read selectively; the full vault was not scanned or edited.

**Current status:** COMPLETE — documentation/control-file review only; no application code, scripts, workflows, configs, credentials, package files, tests, lockfiles, deployment files, or vault files were modified.

**Risks / unknowns:**
- `AI_CONTEXT/AI_AGENT_RULES.md` mentions `AI_CONTEXT/AI_CURRENT_PRIORITIES.md` in its general vault checklist, but this repo's `AGENTS.md` deliberately lists a narrower project-specific allowed set. Future sessions should follow repo instructions and current user instructions first.
- `02_PROJECTS/INSTANTLY_RESPONDER.md` still contains placeholder repo-reference fields and explicitly says not to rely on it for current state. This is low risk because both the repo and `AI_SOURCE_PRIORITY.md` direct agents back to `OPERATION_HANDOFF.md`.

**Recommended next step:**
Proceed with future Codex sessions using `OPERATION_HANDOFF.md`, `AGENTS.md`, and `README.md` first; read only the named Business Brain context files when the task needs business context.

---

## 2026-07-01 — Business Brain Connection

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Connect this repo to the HMZ Business Brain so Claude Code and Codex can access business-wide context safely.

**Files changed:**
- `CLAUDE.md` — added "Business Brain Context" section at end of file
- `AGENTS.md` — created; contains production target rules, safety defaults, source-of-truth table, and Business Brain Context section
- `OPERATION_HANDOFF.md` — created (this file)

**What was done:**
Documentation/control-file update only. No application code, scripts, workflows, configs, tests, package files, or credentials were modified. No vault files were read or edited. No secrets were stored.

**Current status:** COMPLETE — documentation update only; no production changes.

**Risks / unknowns:**
- The vault path `C:\Users\Hamzah Zahid\Projects\hmz-business-brain` has not been verified to exist in this session (per the hard rule against reading the vault without need). An agent reading `AI_CONTEXT/` files for the first time should confirm the path exists before acting on anything found there.
- `AI_CONTEXT/AI_SOURCE_PRIORITY.md` has not been read. Until it is, conflict-resolution between vault and repo files should default to favouring repo files (this file, `docs/SOURCE_PRIORITY.md`).
- `AGENTS.md` is new — Codex or other agents that auto-load it will pick up the vault-path pointer. Verify those agents respect the "read only when needed" rule before running them in this repo.

**Recommended next step:**
If the owner wants to use business-brain context in an upcoming session, open `AI_CONTEXT/AI_BUSINESS_BRIEF.md` and `AI_CONTEXT/AI_SOURCE_PRIORITY.md` at the start of that session to confirm the vault is current, then proceed with the specific task (e.g., campaign copy, offer positioning, or scope decisions).

**Recommended next agent:** Human review first. Then Codex should perform a documentation-only onboarding pass to verify `AGENTS.md` before any implementation task.
