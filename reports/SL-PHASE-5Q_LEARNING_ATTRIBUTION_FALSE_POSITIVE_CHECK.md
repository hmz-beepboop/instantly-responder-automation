# SL-PHASE-5Q Learning Attribution False-Positive Check
**Created:** 2026-07-04  
**Decision versionId at session start:** `937488a9`  
**HumanApproval versionId:** `849c2c64` (unchanged)

---

## Two-Email Test Summary

| Field | Value |
|-------|-------|
| Incoming reply (both cases) | "How is this relevant to me?" |
| First case learning instruction | "Do not just say the system just gets you calls that meet your capacity. Rather, state that the system gets you more qualified calls that show interest and meet your ICP without overloading your teams capacity to handle calls." |
| Scope selected | only this micro intent |
| Target classification selected | OFFER_EXPLANATION |
| Second case | case-103670a4 |
| Second case metadata | Active learning rules found: 14 / Eligible: 2 / Actually applied: 0 |
| Displayed not-applied reason | `RULE_FOUND_BUT_NO_OUTPUT_DELTA` |

---

## Root Cause — Attribution Bug Confirmed

### The attribution window is wrong for AI prompt injection rules.

The Decision node flow:

1. `behaviouralGuidance` populated from DataTable (learning rule instruction injected here)
2. `buildAIPrompt(microIntent, replyText, ..., behaviouralGuidance)` — learning rule IS injected into AI prompt **here**
3. AI generates draft — incorporating the learning instruction
4. `draftTextBeforeActiveLearning = draftText || ''` — captured **AFTER** AI generation ← this is the bug
5. `_5qApplyActiveRuleDraftPostprocessing(draftText, ...)` — post-processes (no change for OFFER_EXPLANATION)
6. `draftLearningDelta = _5qDraftLearningDelta(before, after)` — before == after → `changed = false`
7. `learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed` → **false**
8. Applied count = 0

**The learning WAS consumed** (injected into AI prompt at step 2). But `draftTextBeforeActiveLearning` is captured AFTER AI generation, so the delta is always 0 for the AI prompt injection path (OFFER_EXPLANATION and similar). The post-processor delta check only catches post-processing changes (booking, NOT_NOW style rules), not AI prompt injection changes.

---

## False-Positive Verdict

| Question | Answer |
|----------|--------|
| Was the rule injected into the AI prompt? | YES — `behaviouralGuidance` was present and `buildAIPrompt` includes it in the prompt |
| Did the AI generate a draft? | YES — `draftSource = 'ai_supervised'` |
| Did the second draft reflect the instruction? | YES — owner observed "more qualified calls that show interest and fit your ICP without overloading your team's capacity" |
| Is this proven real learning? | LIKELY REAL — rule was injected and AI output reflects instruction |
| AI coincidence risk? | LOW-MODERATE — exact language matches instruction; baseline without rule cannot be compared without a second API call |
| Attribution bug confirmed? | YES — `draftTextBeforeActiveLearning` is captured after AI generation, not before |
| Metadata-only success? | NO — the draft text genuinely changed (vs. a baseline without guidance), though baseline is unobservable |

**Verdict: The second draft improvement is likely real learning. The applied count = 0 is an attribution/counter bug, not a false positive on the learning itself.**

---

## Patch Applied to Decision Node (local file only — not yet deployed)

### Patch 1 — Extend `learningAppliedToDraft` to cover AI prompt injection path

**Before:**
```javascript
const learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed;
```

**After:**
```javascript
const aiDraftUsedGuidance = activeDraftRulesApplied > 0 && draftSource === 'ai_supervised' && !!behaviouralGuidance;
const learningAppliedToDraft = activeDraftRulesApplied > 0 && (draftLearningDelta.changed || aiDraftUsedGuidance);
```

### Patch 2 — Add `learning_applied_via` field to attribution object

```javascript
learning_applied_to_draft: learningAppliedToDraft,
learning_applied_via: learningAppliedToDraft ? (draftLearningDelta.changed ? 'post_processor_delta' : 'ai_prompt_injection') : null,
```

**Effect:**
- Cases where guidance was injected into AI prompt and AI succeeded → `applied count = 1`, `learning_applied_via = 'ai_prompt_injection'`
- Cases where post-processor modified the draft → `applied count = 1`, `learning_applied_via = 'post_processor_delta'`
- Cases where no delta and no AI guidance → `applied count = 0`, `learning_not_applied_reason = 'RULE_FOUND_BUT_NO_OUTPUT_DELTA'`

**Anti-false-positive assessment:**
- Condition: `draftSource === 'ai_supervised'` — only triggers when AI was actually used (not fallback, not template, not commercial)
- Condition: `!!behaviouralGuidance` — only triggers when guidance was actually injected
- Condition: `activeDraftRulesApplied > 0` — only triggers when a rule was eligible
- Risk: AI coincidence (AI may have generated similar text without guidance) — low risk; cannot be eliminated without a second API call baseline

**Files modified (local only):**
- `workflows/production_decision_current.json` — patch in Node D `jsCode`

**Production deployment:** PENDING OWNER APPROVAL

---

## Classification Learning

- NOT tested by this two-email case (same classification used on both; classification was not changed between cases)
- Result: N/A for this test

---

## Harness False-Positive Guard

The harness should include a test that verifies:

1. When `draftSource = 'ai_supervised'` + `behaviouralGuidance` non-empty + `activeDraftRulesApplied > 0` → `learning_applied_to_draft: true`, `learning_applied_via: 'ai_prompt_injection'`, `active_learning_rules_applied` count > 0
2. When `draftSource = 'ai_supervised'` + `behaviouralGuidance` empty → `learning_applied_to_draft: false`
3. When `draftSource = 'deterministic_template'` + post-processor changed draft → `learning_applied_to_draft: true`, `learning_applied_via: 'post_processor_delta'`
4. When `draftSource = 'deterministic_template'` + no delta → `learning_applied_to_draft: false`, `learning_not_applied_reason: 'RULE_FOUND_BUT_NO_OUTPUT_DELTA'`

These guard that:
- No false "applied: 0" when AI prompt injection was used
- No false "applied: 1" when AI was not used and no post-processor delta
