# SL-PHASE-5Q Anti-False-Positive Audit
**Created:** 2026-07-04  
**Updated:** 2026-07-04 session 4 — FIX-1/FIX-2/FIX-3 applied. Booking regex extended (walkthrough/demo/tour/meeting). Pricing regex extended (commitment/retainer). GAP-3b NOT_NOW consumer added. New P7+P8 harness sections verified 30 new tests. Decision versionId: 937488a9. No invented content; no hardcoded learned replies; no Sender trigger; no Instantly POST. Owner Variant C live retests still required.

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

## Metadata-only success prevented

| Check | Verdict |
|-------|---------|
| `learningAppliedToDraft` requires actual delta | YES — `draftLearningDelta.changed` must be true |
| `learningNotAppliedReason: RULE_FOUND_BUT_NO_OUTPUT_DELTA` used correctly | YES — emitted when rules eligible but no text change |
| `learning_applied_to_draft: true` requires real delta | YES |

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

---

## Verdict

No learned rule content is hardcoded into non-attributable parts of the system. The one active false-positive risk (booking post-processor pasting instruction sentences literally) is a genuine bug in the post-processor function, not a false positive in the policy injection mechanism itself.
