# SL-PHASE-5Q Baseline Evidence Reconciliation
**Created:** 2026-07-04  
**Session:** SL-PHASE-5Q self-improvement behavioural closure

---

## Missing prior reports / scripts

| Item | Status |
|------|--------|
| `reports/SL-PHASE-5Q*.md` | ABSENT — none exist |
| `scripts/SL-PHASE-5Q*.ps1` or `.py` | ABSENT — none exist |
| 5Q16F, 5Q18 session logs | ABSENT — not in OPERATION_HANDOFF |

Prior 5Q work appears to have been done in production but without updating the local workflow export or creating session reports. This is confirmed by the local/production versionId mismatch.

---

## Workflow source used

### Decision workflow

| Item | Value |
|------|-------|
| Local `production_decision_current.json` versionId | `e1b84f34-5f91-41c5-9685-317480c38bea` |
| Production Decision versionId | `889e1d45-7103-4b0a-a85d-685d19a2cadd` |
| Production workflow ID | `tgYmY97CG4Bm8snI` |
| Match | **NO — local file is STALE** |
| Node count local | 32 |
| Node count production | 33 (extra: `Q12. Lookup Active Form Learning Rules`) |

**Resolution:** Production workflow fetched directly via REST API for all analysis. Local file NOT used for Decision analysis.

### HumanApproval workflow

| Item | Value |
|------|-------|
| Local `production_humanapproval_current.json` versionId | `9c71882f-a096-48a9-861a-37e5424035ae` |
| Memory-confirmed last applied versionId | `9c71882f` (SL-PHASE-5P) |
| Match | **YES — local file is current** |

---

## Local vs production consistency

- Decision local file is 393-line stale export; production has 1253-line version with complete 5Q learning infrastructure
- HumanApproval local matches production
- No API to query DataTable rows directly (data-store endpoint returns 404); used execution history to retrieve Q12 output

---

## Production 5Q infrastructure confirmed present

From production Decision Node D:

1. **Q12 node** exists and fetches from DataTable `CSdiTjXfi0tl0oZF` with `status = active` filter
2. **`_dynamicFormPolicyRows`** loaded from Q12 output at execution start
3. **`DYNAMIC_FORM_BEHAVIOURAL_POLICIES`** built from Q12 rows (style rules only)
4. **`DYNAMIC_FORM_CLASSIFICATION_RULES`** built from Q12 rows (classification rules)
5. **`ACTIVE_BEHAVIOURAL_POLICIES`** — one hardcoded policy: `27293ea8` (OFFER_EXPLANATION global, from owner live proof)
6. **`_5qSelectBehaviouralPolicyMatches`** — scope-based deduplication with newest-wins
7. **`_5qApplyDynamicClassificationLearning`** — applies classification corrections
8. **`_5qApplyActiveRuleDraftPostprocessing`** — applies post-draft rule processing
9. **`buildBehaviouralPolicyGuidance`** — formats guidance for AI prompt

---

## Q12 live data (from execution 3951, 2026-07-01)

All 6 specified failing rule IDs are present in the DataTable with `status: active`:

| Rule ID | Type | Category Scope | Intent Scope | Source Case |
|---------|------|----------------|--------------|-------------|
| `c9860e74` | style | INFORMATION_REQUEST | BOOKING_REQUEST | case-5cf1aa57 |
| `97eb3b0a` | style | INFORMATION_REQUEST | BOOKING_REQUEST | case-d8368748 |
| `493884ad` | style | PRICING_OR_COMMERCIAL_NEGOTIATION | PRICING_REQUEST | case-78e677c0 |
| `48e10cac` | style | INFORMATION_REQUEST | OFFER_EXPLANATION | case-86a17778 |
| `6e50fd54` | classification | AMBIGUOUS | AMBIGUOUS_SHORT_REPLY | case-39352371 |
| `cdada69d` | style | AMBIGUOUS | NON_PRIORITY | case-39352371 |

---

## Case traceability

| Case ID | Evidence |
|---------|----------|
| case-759e58d7, case-d099e6f3 | Original improvement evidence; no live data available from execution history |
| case-7c87d21a (booking) | Traced to c9860e74 + 97eb3b0a interaction; root cause identified |
| case-d555bcfd (pricing) | Traced to 493884ad; root cause identified |
| case-083fe26e (setup/process) | Traced to 48e10cac; root cause identified |
| case-5fa982f4 (not-now/later) | Traced to 6e50fd54 + cdada69d; root cause identified |

---

## Assumptions rejected

- NOT assumed that missing prior reports mean no 5Q work happened — production confirms significant infrastructure was built
- NOT assumed local Decision file is current — production fetch performed
- NOT assumed phantom rule IDs — all 6 rule IDs verified live in Q12 execution output
- NOT assumed DataTable is empty — execution data confirms all rules present and active
