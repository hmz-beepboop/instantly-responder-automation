# Phase 2 Business-Alignment Audit (Surgical Correction Pass)

Date: 2026-06-10. Scope: this audit checks the **Phase 2 surgical correction pass** (the 15 numbered corrections, items 1-11 and 13/14/15 of which are tracked in this pass) for internal consistency, source-hierarchy alignment, and absence of prohibited claims, across all 19 Markdown files in the repository at the time of this audit. It does **not** re-derive business facts — it checks that the corrected documents agree with each other and with `docs/HMZ_APPROVED_REPLY_RULES.md` / `docs/SOURCE_PRIORITY.md` / `docs/BUSINESS_SOURCE_REGISTER.md`.

This audit is itself governed by `CLAUDE.md`: it does not build, import, activate, or test any n8n workflow, and does not make API calls. It is read-only analysis of the Markdown corpus plus this report and `docs/PHASE_2_SURGICAL_CORRECTION_CHANGELOG.md` (task #14, written immediately after this report).

Files in scope (19 at audit time, plus this report and the task-#14 changelog as new outputs):

```
CLAUDE.md
docs/SOURCE_PRIORITY.md
docs/BUSINESS_SOURCE_REGISTER.md
docs/HMZ_APPROVED_KNOWLEDGE_BASE.md
docs/HMZ_APPROVED_REPLY_RULES.md
docs/REPLY_POLICY.md
docs/ARCHITECTURE.md
docs/IMPLEMENTATION_PLAN.md
docs/NORMALIZED_EVENT_SCHEMA.md
docs/STATE_AND_IDEMPOTENCY.md
docs/VALIDATION_CAMPAIGN_CONFIG.md
docs/RISK_REGISTER.md
docs/ASSUMPTIONS_AND_UNKNOWNS.md
docs/ENVIRONMENT_AUDIT.md
docs/INSTANTLY_FIELD_MAP.md
docs/SOURCES.md
docs/PHASE_2_CORRECTION_CHANGELOG.md
docs/KNOWLEDGE_BASE_CHANGELOG.md
brainstorms/2026-06-09-instantly-rapid-reply-policy.md
archive/SESSION_HANDOFF_PHASE_2_SUPERSEDED.md
```

---

## A. Source grounding (correction #1 + the rank-4 path correction)

- `docs/BUSINESS_SOURCE_REGISTER.md` correctly lists rank 4 as `sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx` (the user's mid-session correction), not the originally-stated `03_Alpha_Offer_SUPERSEDED.docx`. **PASS.**
- `docs/SOURCE_PRIORITY.md` and `docs/HMZ_APPROVED_REPLY_RULES.md` reference the register and the `01_Abs_Plan.docx` / `02_Product_Offer_Intake_COMPLETED.docx` / `03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx` rank order consistently. **PASS.**
- `docs/VALIDATION_CAMPAIGN_CONFIG.md` cites `sources/business/01_Abs_Plan.docx` Phases 1 and 3 for the geography lock and validation cells, consistent with rank-1 sourcing. **PASS.**

### Historical-reference finding (resolved — no change needed)
Two changelog entries use the un-prefixed document names `Abs Plan.docx` / `Product_Offer_Intake_COMPLETED.docx` instead of the now-standard `sources/business/0X_*.docx` form:

- `docs/PHASE_2_CORRECTION_CHANGELOG.md:11` — describes the **prior** (1.0→1.1) correction that *created* `docs/SOURCE_PRIORITY.md`, at a point before the project-relative path convention existed.
- `docs/KNOWLEDGE_BASE_CHANGELOG.md:7` — a dated changelog row recording what `KB-1.0-DRAFT` was built from at the time.

**Determination:** both are **historical changelog entries describing a past state**, not current guidance — the same treatment already applied to the `LEGAL_REVIEW_PENDING` reference left untouched elsewhere in `docs/PHASE_2_CORRECTION_CHANGELOG.md` as a record of the prior pass. Per `CLAUDE.md` rule #17 ("save important findings... so later phases do not depend on chat history") changelogs are append-only historical records; rewriting them to match later path conventions would misrepresent what was actually written at the time. **Left unchanged.** All *current-guidance* documents (`docs/SOURCE_PRIORITY.md`, `docs/BUSINESS_SOURCE_REGISTER.md`, `docs/VALIDATION_CAMPAIGN_CONFIG.md`, `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`, `docs/HMZ_APPROVED_REPLY_RULES.md`) use the full `sources/business/0X_*.docx` paths. **PASS (no action required).**

---

## B. Prohibited business claims (correction re: 3rd source as future-only/rank-4)

Searched case-insensitively for: `20+ qualified`, `ready to buy`, `ensures? results`, `established`, `proven`, `testimonial`, `fully operating`, `scarcity`, and similar rank-4 phrasing.

- All matches found are either (a) inside `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §14 "Prohibited claims" / §4 maturity statement, explicitly listing these as **forbidden**, or (b) inside `docs/SOURCE_PRIORITY.md` / `docs/BUSINESS_SOURCE_REGISTER.md` describing the rank-4 document's status as **future-only, not a current claim source**.
- No file asserts any of these as a current fact, current capability, or current proof point. **PASS.**

---

## C. Cross-reference integrity

- `docs/PHASE_2_SURGICAL_CORRECTION_CHANGELOG.md` is referenced from `docs/HMZ_APPROVED_REPLY_RULES.md` (§18, source note), `docs/BUSINESS_SOURCE_REGISTER.md` (SHA-256/conflicts rows), and `docs/IMPLEMENTATION_PLAN.md`. The file does not yet exist at the time of this audit — it is created immediately after this report as task #14. **Forward reference, resolved by the next file write — not a defect.**
- `reports/PHASE_2_BUSINESS_ALIGNMENT_AUDIT.md` (this file) is referenced from `docs/IMPLEMENTATION_PLAN.md` §1. **Resolved by this file's creation.**
- `docs/SESSION_HANDOFF_PHASE_2.md` no longer exists at its old path; it has been moved to `archive/SESSION_HANDOFF_PHASE_2_SUPERSEDED.md`. A grep across all non-archive `.md` files for `SESSION_HANDOFF_PHASE_2` found **no remaining references to the old path** outside the archived file's own (historical) checklist text. **PASS.** `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` (task #12) is written after this report and the task-#14 changelog so it can cite both accurately.
- `docs/VALIDATION_CAMPAIGN_CONFIG.md` is referenced correctly from `docs/ARCHITECTURE.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/NORMALIZED_EVENT_SCHEMA.md` (§3.4), and `docs/HMZ_APPROVED_REPLY_RULES.md` §12 (`LIVE_CAMPAIGNS`). **PASS.**

---

## D. Terminology consistency

| Term | Files checked | Result |
| --- | --- | --- |
| `REVIEW_HOLD` (replacing `LEGAL_REVIEW_PENDING`) | `docs/HMZ_APPROVED_REPLY_RULES.md`, `docs/REPLY_POLICY.md`, `docs/ARCHITECTURE.md`, `docs/STATE_AND_IDEMPOTENCY.md` | Consistent. No remaining `LEGAL_REVIEW_PENDING` anywhere except as an explicitly-labelled historical correction record in `docs/PHASE_2_CORRECTION_CHANGELOG.md`. **PASS.** |
| `legal_review_required` / `privacy_review_required` / `reputational_review_required` | `docs/HMZ_APPROVED_REPLY_RULES.md` §7.1/§9.2/§11, `docs/ARCHITECTURE.md` §5, `docs/STATE_AND_IDEMPOTENCY.md` §1.2, `docs/REPLY_POLICY.md` §4 closing note | All four files describe these as **independent booleans, not all set for every T12/T13 case**, citing §7.1 as authority. **PASS.** |
| `CELL_1_SAAS_SALES_HIRING` / `CELL_2_SAAS_EXISTING_OUTBOUND` / `CELL_3_SPECIALISED_B2B_AGENCY` | `docs/VALIDATION_CAMPAIGN_CONFIG.md`, `docs/NORMALIZED_EVENT_SCHEMA.md`, `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`, `docs/IMPLEMENTATION_PLAN.md` | Consistent naming and Cell-3-must-not-use-SaaS-language constraint repeated identically. **PASS.** |
| `geo_code` / `US_B2B_CORE_12` | 8 files (`VALIDATION_CAMPAIGN_CONFIG.md`, `NORMALIZED_EVENT_SCHEMA.md`, `ARCHITECTURE.md`, `HMZ_APPROVED_REPLY_RULES.md`, `IMPLEMENTATION_PLAN.md`, and others) | Consistent: `US_B2B_CORE_12` for the first sprint; mismatch is a human-review flag, never an auto-reject, stated identically everywhere. **PASS.** |
| `policy-HMZ-1.2` / `policy-HMZ-1.1` / `policy-HMZ-1.0` | `docs/HMZ_APPROVED_REPLY_RULES.md` (header + §18), `docs/REPLY_POLICY.md` (supersession notice), `docs/NORMALIZED_EVENT_SCHEMA.md` (`policy_version` example), `docs/PHASE_2_CORRECTION_CHANGELOG.md` (historical) | Current version `policy-HMZ-1.2` used consistently in live examples; `1.0`/`1.1` only appear in correctly-labelled historical/supersession context. **PASS.** |
| `0.85` confidence band | `docs/REPLY_POLICY.md`, `docs/RISK_REGISTER.md`, `docs/BUSINESS_SOURCE_REGISTER.md`, `docs/PHASE_2_CORRECTION_CHANGELOG.md`, `archive/...SUPERSEDED.md`, `brainstorms/...md` | All occurrences explicitly say the `0.85` band **is removed** / was the **prior, now-corrected** value. No file asserts `0.85` as current. **PASS.** |

---

## E. T1 / T2 / T3 mutual distinguishability

- `docs/REPLY_POLICY.md` §1 (taxonomy table) and `docs/HMZ_APPROVED_REPLY_RULES.md` §3 are the only two documents that *define* T1/T2/T3, and they are mutually consistent:
  - **T1** `positive_interest` — positive interest/acceptance, explicitly **excluding** substantive information requests (→T2) **and** explicit booking/scheduling asks (→T3).
  - **T2** `information_request` — "how it works", proof/feature/mechanism/comparison questions.
  - **T3** `booking_request` — explicit booking/scheduling intent; always recorded as T3 even where its approved wording reuses T1's, never reclassified as T1.
- `docs/ARCHITECTURE.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/NORMALIZED_EVENT_SCHEMA.md`, and `docs/STATE_AND_IDEMPOTENCY.md` reference the categories only generically (e.g. "16 categories", "deterministic categories T7/T8/T9/T11/T12/T13/T14", "semantic categories T1/T2/T4/T5/T6/T10/T15/T16") and do not restate or contradict the T1/T2/T3 definitions. **PASS.**
- `det-booking-001` (T3) and the T1 definition in both defining documents now cross-reference each other (`HMZ_APPROVED_REPLY_RULES.md` §3.1/§6 cited from `REPLY_POLICY.md`). **PASS.**

---

## F. Stop / suppression / DNC / `REVIEW_HOLD` non-conflation

- `docs/HMZ_APPROVED_REPLY_RULES.md` §7 (suppression-level enum) and §7.1 (per-category stop-vs-suppression mapping, correction #9) are the authoritative sections.
- `docs/REPLY_POLICY.md` §4 and §6, `docs/ARCHITECTURE.md` §5, and `docs/STATE_AND_IDEMPOTENCY.md` §1.2 all describe `suppression_level` (including `REVIEW_HOLD`) as **independent** from `stop_sequence`/`pause_sequence`, and all defer to §7/§7.1 for the authoritative mapping rather than restating a conflicting mapping. **PASS.**
- No document conflates `STOP_ACTIVE_SEQUENCE` (sequence-level), `WORKSPACE_DNC`/`ORGANISATION_DNC`/`GLOBAL_BLOCKLIST` (suppression-level), and `REVIEW_HOLD` (a neutral hold state, not itself a suppression destination) — `REPLY_POLICY.md`'s T12/T13 row explicitly shows `REVIEW_HOLD` **paired with** a separate suppression level, matching §7.1. **PASS.**

---

## G. `DRY_RUN=true` preservation

`DRY_RUN` appears in 14 of the 19 files. Every occurrence either (a) states `DRY_RUN=true` / `true` is the default, (b) describes a *gate that must pass before* `DRY_RUN=false` can apply (always paired with "explicit owner approval" + `LIVE_CAMPAIGNS`), or (c) is in `archive/SESSION_HANDOFF_PHASE_2_SUPERSEDED.md` describing the same default historically. No file states or implies `DRY_RUN=false` as a default or as something that can be set without the full gate list. **PASS.**

---

## H. No self-approval of KB / policy

- `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §16: "The AI must never autonomously rewrite or approve this document. Changes... require owner review and a new version recorded in `docs/KNOWLEDGE_BASE_CHANGELOG.md`." **PASS.**
- `docs/HMZ_APPROVED_REPLY_RULES.md` §18: "Updated only by Hamzah and the designated business partner... The automation must never autonomously update this document." **PASS.**
- This correction pass itself does not mark `KB-1.0-DRAFT` as approved, does not change its status from `DRAFT`, and does not mark `policy-HMZ-1.2` as anything other than the current *document* version (not a runtime-approved state requiring no further sign-off). **PASS.**

---

## I. Scope clarification (correction #2/#13 — HMZ's own campaign vs reusable client responder)

`CLAUDE.md` "Scope", `docs/ARCHITECTURE.md` (new scope paragraph), and `docs/IMPLEMENTATION_PLAN.md` (new scope paragraph) all state, in matching language, that this system supports **HMZ's own initial US B2B validation campaign only**, is single-tenant/single-workspace, and that any future client-facing/reusable use requires separate approvals out of scope for the current plan. `docs/VALIDATION_CAMPAIGN_CONFIG.md` reinforces this in its own scope paragraph. **PASS — no contradicting "reusable responder" framing found in any file.**

---

## J. Files reviewed but out of scope for edits (no contradictions found)

`docs/RISK_REGISTER.md`, `docs/ASSUMPTIONS_AND_UNKNOWNS.md`, `docs/ENVIRONMENT_AUDIT.md`, `docs/INSTANTLY_FIELD_MAP.md`, `docs/SOURCES.md` were not in the 15-item correction list and were not edited. Each was checked for: stale `LEGAL_REVIEW_PENDING`/`0.85`/old-T1-T3 wording/`geo_code` conflicts/`REVIEW_HOLD` conflicts — **none found**. One minor observation (not a contradiction, no action taken): `docs/ASSUMPTIONS_AND_UNKNOWNS.md` §D item 1 ("First in-scope... test campaign") is a shorter restatement of `docs/IMPLEMENTATION_PLAN.md` U1, which now additionally specifies "mapped to one validation cell and `geo_code=US_B2B_CORE_12`." The shorter form is not wrong, just less detailed, and `docs/IMPLEMENTATION_PLAN.md` is the canonical list for U-numbered items.

---

## K. Prompt-3 readiness verdict

Per `docs/IMPLEMENTATION_PLAN.md` §1 (Route A / Route B gating, itself part of this correction pass):

- **Route A (n8n MCP-verified build):** `docs/ASSUMPTIONS_AND_UNKNOWNS.md` A1 (n8n MCP — **BLOCKED**) and A2 (non-production n8n instance — **BLOCKED**) remain unresolved, reaffirmed by `docs/ENVIRONMENT_AUDIT.md`. Route A gates are **not met**.
- **Route B (offline mock-only design):** requires "Owner authorisation for offline fallback — Explicit and recorded — not assumed from silence." No such authorisation has been given in this task; on the contrary, the standing instruction for this entire task is **"Do not begin Prompt 3."** Route B gates are **not met** (and are not being sought).

**Verdict: NOT READY FOR PROMPT 3.**

This is the expected and correct outcome for a correction-only pass — no implementation phase was authorised or attempted. Unmet gates and what would clear them:

| Unmet gate | What would clear it |
| --- | --- |
| n8n MCP connected (Route A) | Owner registers an n8n MCP server and confirms tools are callable (`docs/ASSUMPTIONS_AND_UNKNOWNS.md` A1). |
| Non-production n8n instance confirmed (Route A) | Owner provides instance URL + written non-prod/isolation confirmation (A2). |
| Owner authorisation for offline fallback (Route B) | Owner explicitly authorises a Route-B offline design pass, separately from this correction pass, with the mandatory later-MCP-verification precondition recorded. |

---

## Summary

All 11 in-scope document edits (corrections #1-11), the source-register creation, the archive move, and the terminology/consistency checks above are internally consistent. No prohibited business claims, no stale `LEGAL_REVIEW_PENDING`/`0.85`/scheduling-ambiguity references, no broken cross-references other than the two forward references resolved by this report and the immediately-following `docs/PHASE_2_SURGICAL_CORRECTION_CHANGELOG.md`. `DRY_RUN=true` and "no self-approval" are preserved everywhere. **Verdict: NOT READY FOR PROMPT 3** (by design — this pass does not seek Prompt-3 readiness).
