# SL-PHASE-5Q Anti-False-Positive Audit
**Created:** 2026-07-04  
**Updated:** 2026-07-04 session 8 — PROOF_REQUEST learned-draft pathway patch (SL-PHASE-5Q-PROOF). Node D patched: `const draftPolicy` → `let draftPolicy`; upgrade guard added (PROOF_REQUEST + HUMAN_ONLY + active form-created draft-learning rules → AI_SUPERVISED_OR_TEMPLATE); PROOF_REQUEST entry added to buildAIPrompt intInstr. Harness 216/216 PASS. Decision deployed: old `4cb34768` → new `84e6638e`. No hardcoded proof replies; no invented credibility claims; no Sender trigger; no Instantly POST. HumanApproval unchanged (`c51ac1f3`).

**Previous:** 2026-07-04 session 7 — Node J JS syntax crash fixed. Orphaned `const // comment` + undeclared `_5q3RowLooksMissing` (SyntaxError) patched. P11 harness section added (22 new tests including `node --check` syntax validation). Harness 190/190 PASS. HumanApproval deployed: old `e0e89e0e` → new `c51ac1f3`. No invented content; no hardcoded proof replies; no Sender trigger; no Instantly POST. Decision unchanged (`4cb34768`).

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
