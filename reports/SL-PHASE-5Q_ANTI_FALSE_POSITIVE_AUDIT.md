# SL-PHASE-5Q Anti-False-Positive Audit
**Created:** 2026-07-04  
**Updated:** 2026-07-06 session 15 — Dense-paragraph false-positive rejection fixed. The remaining `AI_OUTPUT_VALIDATION_FAILED` frequency on proof/trust cases was live-proven to be a STYLE false positive, not a safety rejection: exec 5329 (PROOF_REQUEST) had a fully safe, honest, correctly-negated AI draft rejected solely by `active policy violation: dense paragraph` (~386-char single paragraph vs 360 threshold). Cause chain: globally-scoped style policy 27293ea8 ("short paragraphs") arms the dense validator for ALL AI drafts, while intInstr.PROOF_REQUEST demanded "One concise paragraph" — the prompt invited exactly what the validator rejects. Siblings 5286/5296 passed at shorter/multi-paragraph shape, confirming the boundary. Fixes: (1) PROOF_REQUEST prompt now asks for 2-3 short paragraphs; (2) style-only dense rejections are repaired by a whitespace-only sentence-boundary reflow and the FULL validator re-runs — safety errors always still fall back (harness P19.11-16 prove invented proof/results/guarantees/pricing still fail after reflow); (3) reflow recorded truthfully (`style_reflow_applied`, `raw_draft_text_before_reflow`); (4) HumanApproval fallback banner now names the exact failed check(s) and states when the rejection was formatting-only, not safety. Deployed: Decision `afe08974` → `4474c96a`; HumanApproval `7aac637e` → `0054f20b`. Harness 375/375 PASS (+26 P19). Known residual (deliberately NOT patched — no live occurrence): FORBIDDEN_AI negation window lacks `can't/cannot/won't` and does not exempt post-keyword negation; logged in `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md` item 10(c). Sender untouched, no Instantly POST, Shadow inactive, Gate 2 unapproved.

**Updated:** 2026-07-05 session 14 — Trust/proof variant repair deployed. This was not a false learning success: production rows proved `case-e6e99b67` correction was submitted and stored, but its active classification rule `b90ff779` was scoped from `AMBIGUOUS/NON_PRIORITY`, while follow-up `case-3a05c80c` began as `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY`; older NON_PRIORITY rule `6e50fd54` therefore hijacked the variant. Decision now classifies trust/proof variants (`trustworthy`, `credible`, `believe`, proof/evidence wording) directly as `INFORMATION_REQUEST/PROOF_REQUEST`, and blocks NON_PRIORITY promotion on trust/proof replies. No credibility claims were hardcoded; draft safety still forbids invented proof/results/guarantees/case studies/testimonials. Decision deployed `f6d5b731` → `afe08974`; HumanApproval unchanged `7aac637e`; harness 349/349 PASS. Sender untouched, no Instantly POST, Shadow Evaluator inactive, Gate 2 unapproved.

**Updated:** 2026-07-05 session 13 — Context/token upstream regression fix. case-68110963 was live-proven as a Decision Node D syntax failure, not proof-learning failure and not review-token failure. HumanApproval GET token validation succeeded (`token_valid=true`); the diagnostic row already contained `context_missing.blocked=true` and `upstream_error="Invalid or unexpected token "`. Decision execution had valid upstream context before Node D, then Node D emitted only an error item because PROOF_REQUEST fallback had a literal newline inside `_prParts.join('...')`. Fix: escaped join string to `return _prParts.join('\\n\\n');`. Decision deployed: `9198554c` → `f6d5b731`. HumanApproval unchanged (`7aac637e`). Harness 326/326 PASS (+8 P17 tests). No Sender trigger, no Instantly POST, Shadow Evaluator inactive, Gate 2 unapproved.

**Updated:** 2026-07-05 session 12 — PROOF_REQUEST AI-fallback non-null fix. `validateAI` `asksProof` guard: `asksProof = true` when `microIntent === 'PROOF_REQUEST'` (prevents false-positive rejection when guidance contains "do not mention validation"). `buildPolicyAwareFallback` PROOF_REQUEST branch: safe deterministic fallback when AI fails — no invented proof, no results claims, no guarantees, no case studies, no customer examples. Text is honest about validation stage and asks a diagnostic question. Decision deployed: `0e1e1193` → `9198554c`. HumanApproval unchanged (`7aac637e`). Harness 318/318 PASS (+26 P16 tests). Sender untouched; no Instantly POST; Shadow Evaluator inactive; Gate 2 unapproved.

**Previous:** 2026-07-05 session 11 — PROOF_REQUEST draft-learning activation bridge fix. Node D `_5qPolicyApplies` unresolvable-scope fallback added; Node J form scope default changed to `current_micro_intent_only`. No hardcoded proof replies; no invented credibility claims; classification-vs-draft distinction preserved; upgrade guard still requires active style rules. Decision deployed: `84e6638e` → `0e1e1193`. HumanApproval deployed: `c20af72e` → `7aac637e`. Harness 292/292 PASS (+26 P15 tests). Sender untouched; no Instantly POST; Shadow Evaluator inactive; Gate 2 unapproved.

**Previous:** 2026-07-05 session 10 — Valid-fallback submit/reopen repair (SL-PHASE-5Q-SUBMIT-REOPEN-FIX). Nodes N + J + SL-P2A patched. `_nIsIntentionallyNoDraft` added to Node N; Node J `_5q3MissingContext` drops `rc.status` check; SL-P2A `rowLooksMissing` fixed. Harness 266/266 PASS (+26 P14 tests). HumanApproval deployed: old `ee2f160e` → new `c20af72e`. No hardcoded content; no invented credibility claims; no Sender trigger; no Instantly POST. Decision unchanged (`84e6638e`).

**Previous:** 2026-07-04 session 9 — ai_failed_fallback / AI_OUTPUT_VALIDATION_FAILED valid-review taxonomy fix (SL-PHASE-5Q-AIFAILED-FIX). HumanApproval Node A + Node J guards extended: `ai_failed_fallback` added to `_aIsIntentionallyNoDraft` (Node A) and `_5q3IsIntentionallyNoDraft` (Node J). Valid cases with draft_source=ai_failed_fallback no longer trigger diagnostic fallback. Harness 240/240 PASS (+24 P13 tests). HumanApproval deployed: old `c51ac1f3` → new `ee2f160e`. No hardcoded content; no invented credibility claims; no Sender trigger; no Instantly POST. Decision unchanged (`84e6638e`).

**Previous:** 2026-07-04 session 8 — PROOF_REQUEST learned-draft pathway patch (SL-PHASE-5Q-PROOF). Node D patched: `const draftPolicy` → `let draftPolicy`; upgrade guard added (PROOF_REQUEST + HUMAN_ONLY + active form-created draft-learning rules → AI_SUPERVISED_OR_TEMPLATE); PROOF_REQUEST entry added to buildAIPrompt intInstr. Harness 216/216 PASS. Decision deployed: old `4cb34768` → new `84e6638e`. No hardcoded proof replies; no invented credibility claims; no Sender trigger; no Instantly POST. HumanApproval unchanged (`c51ac1f3`).

---

## Hardcoded learned content checks

### In baseline draft templates (MI_TEMPLATES in Node D)

| Check | Verdict |
|-------|---------|
| Booking wording hardcoded | NOT FOUND — MI_TEMPLATES.MEETING_TIME_REQUEST uses generic "You can choose a suitable time here" |
| Pricing wording hardcoded | NOT FOUND — pricing uses deterministic AI_COMMERCIAL_SUPERVISED branch with generic content |
| Setup/process wording hardcoded | NOT FOUND — OFFER_EXPLANATION template is generic; no step-by-step from 48e10cac |
| Not-now wording hardcoded | NOT FOUND — NOT_NOW template is generic "Understood. I'll close the loop" |
| Rule instruction text in templates | NOT FOUND |

### In AI prompt instructions (buildAIPrompt intInstr map)

| Check | Verdict |
|-------|---------|
| Booking instruction modified by c9860e74 | NOT FOUND — no MEETING_TIME_REQUEST/BOOKING_REQUEST in intInstr |
| Pricing instruction modified by 493884ad | NOT FOUND — intInstr has no pricing entry |
| Setup instruction modified by 48e10cac | MODIFIED — OFFER_EXPLANATION instruction updated (to "short paragraphs... CTA at end"), but this is a generic quality improvement, not 48e10cac's content pasted in |
| Not-now wording from cdada69d | NOT FOUND |

**Verdict:** No learned rule wording hardcoded into baseline AI instruction map.

### In buildPolicyAwareFallback

| Check | Verdict |
|-------|---------|
| OFFER_EXPLANATION fallback text from 27293ea8 | PARTIAL — the hardcoded ACTIVE_BEHAVIOURAL_POLICIES policy `27293ea8` influenced the `buildPolicyAwareFallback` logic (setup steps listed). However this was owner-activated via live proof session, not from a DataTable rule. Not a false positive — it's correctly attributed. |
| c9860e74/97eb3b0a wording in fallback | NOT FOUND |
| 493884ad wording in fallback | NOT FOUND |
| 48e10cac wording in fallback | NOT FOUND |
| cdada69d wording in fallback | NOT FOUND |

### In postprocessor (_5qApplyActiveFormRuleInstructionToDraft)

| Check | Verdict |
|-------|---------|
| c9860e74 instruction text pasted as draft | PATCHED (SL-PHASE-5Q GAP-1) — URL detected in instruction → email-content mode correctly extracts booking link only. |
| 97eb3b0a instruction text pasted as draft | PATCHED (SL-PHASE-5Q GAP-1) — No URL detected → constraint mode. Policy meta-phrases ("Replace the previous", "Do not ask them", "Do not say") NOT pasted into email. |
| 493884ad wording in postprocessor | NOT APPLIED — pricing goes through _5qApplyPricingConstraints (GAP-2), not the booking postprocessor. |
| 48e10cac wording in postprocessor | NOT APPLIED — OFFER_EXPLANATION uses AI prompt injection, not booking postprocessor. |
| cdada69d wording in postprocessor | NOT APPLIED — cdada69d eligible for NON_PRIORITY; FIXED_TEMPLATE draft now exists (GAP-3); guidance applied via post-processing chain. |

**Verdict (post-patch):** Booking post-processor literal-paste bug eliminated. _5qApplyPricingConstraints replaces evasive pricing paragraph without inventing prices. No new false-positive risk introduced.

---

## Metadata-only success prevented (updated session 5)

| Check | Verdict |
|-------|---------|
| `learningAppliedToDraft` requires delta OR ai_draft_used_guidance | YES — either delta changed or guidance was injected into AI prompt |
| Single-rule AI injection: 1 rule credited | YES — `aiPromptInjectionSingleRule` gates individual rule credit |
| Multi-rule AI injection: 0 rules credited, uncertainty flagged | YES — `aiPromptInjectionMultiRule` suppresses per-rule credit; sets `learning_attribution_uncertain=true` |
| Multi-rule AI injection reason | `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN` |
| Post-processor delta: all eligible rules credited | YES — observable text change is sufficient proof |
| `learning_applied_to_draft: true` requires real delta OR injected guidance | YES |
| `learning_guidance_injected` field | Added — `true` when AI path used guidance; independent of applied count |

---

## Safety checks

| Check | Verdict |
|-------|---------|
| Sender not triggered | CONFIRMED — no Sender workflow call in Node D |
| No Instantly POST | CONFIRMED — no HTTP calls to Instantly API in Node D |
| Autonomous not activated | CONFIRMED — Shadow Evaluator disabled workflow unchanged |
| Legal/safety blocks not bypassed | CONFIRMED — learning policies skipped for UNSUBSCRIBE/LEGAL/COMPLAINT categories |
| Human review not bypassed | CONFIRMED — all supervised draft paths still require human review |
| Proposed_shadow rules not applied | CONFIRMED — Q12 filters `status = active`; proposed_shadow would require different status |
| PROOF_REQUEST upgrade: classification correction alone does NOT trigger | CONFIRMED — upgrade requires `activeFormDraftRuleMatches.length > 0`; classification correction rules (rule_type=classification_correction) are excluded from `DYNAMIC_FORM_BEHAVIOURAL_POLICIES` (which filters for `rule_type=style` only) |
| PROOF_REQUEST upgrade: no hardcoded proof replies | CONFIRMED — upgrade only enables AI supervised draft path; no hardcoded content injected |
| PROOF_REQUEST intInstr does not invent results/customer claims | CONFIRMED — P12.14 harness verified |

---

## Verdict

No learned rule content is hardcoded into non-attributable parts of the system. The one active false-positive risk (booking post-processor pasting instruction sentences literally) is a genuine bug in the post-processor function, not a false positive in the policy injection mechanism itself.
