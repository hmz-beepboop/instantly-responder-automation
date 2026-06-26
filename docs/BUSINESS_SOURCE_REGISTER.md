# Business Source Register

Date: 2026-06-10. Status: authoritative inventory of business-authority source documents referenced by `docs/SOURCE_PRIORITY.md`.

This register exists so that every reference to a business source elsewhere in the project points at a real, project-relative file path. It does not change the priority hierarchy defined in `docs/SOURCE_PRIORITY.md` — it is the lookup table that hierarchy depends on.

**Rule:** the original `.docx` files listed below are never edited, renamed, or deleted (`CLAUDE.md` rule #18). If a discrepancy is found between a path referenced in project documentation and the actual file on disk, this register is corrected and the documentation reference is updated to match the actual file — the source file itself is left untouched.

---

## Naming discrepancy — resolved 2026-06-10

An earlier instruction referred to the rank-4 source as `sources/business/03_Alpha_Offer_SUPERSEDED.docx`. No file with that name exists on disk. The user explicitly corrected this during the surgical correction pass: **the authoritative rank-4 business source is `sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx`** (the actual file present in `sources/business/`). All references in this correction pass use that exact path. The file is treated as **future offer concept / not approved for runtime use**, consistent with its rank-4 status in `docs/SOURCE_PRIORITY.md` — the corrected filename does not change its authority level.

---

## Register

### Rank 1 — `sources/business/01_Abs_Plan.docx`

| Field | Value |
| --- | --- |
| Path | `sources/business/01_Abs_Plan.docx` |
| Priority | 1 (highest business authority) |
| Status | ACTIVE — current go-to-market strategy and operating plan |
| SHA-256 | `237ea201c2cf6b96b27f8fcc229cf6c10f71565fed82e7ba9f9c435ea374826` |
| Purpose | Refined step-by-step plan for the AI Sales Outbound Engine: capacity-aligned positioning, Phase 1 geography lock (`US_B2B_CORE_12`), Phase 2 ICP, Phase 3 three validation test cells (Cell 1 SaaS+new sales hires, Cell 2 SaaS+existing outbound, Cell 3 specialised B2B agencies), Phase 5 30-day/500-email validation sprint, Phase 8 pricing options, Phase 11 reply-handling templates, Phase 12 list-building fields, Phase 13 scorecard, Phase 14 kill/continue thresholds, Phase 20 decision tree. |
| Claims permitted (after copy into approved KB + owner approval) | Current ICP hypotheses, geography lock (`US_B2B_CORE_12`), validation-cell definitions, capacity-aligned positioning language, validation-sprint structure (cells, volumes, durations) framed as the current plan, not as proof of results. |
| Claims prohibited | Any phrasing that the validation sprint has already produced results; any pricing as automatic disclosure; any phase-3+ roadmap content presented as currently operating. |
| Conflicts identified | None with rank 2. Phase 8 pricing in this document is in USD and differs from the GBP pricing in rank 2 (`02_Product_Offer_Intake_COMPLETED.docx`) — pricing is human-only regardless (`docs/HMZ_APPROVED_REPLY_RULES.md` §"pricing"), so this conflict does not affect runtime behaviour, but is recorded here for owner awareness. |

### Rank 2 — `sources/business/02_Product_Offer_Intake_COMPLETED.docx`

| Field | Value |
| --- | --- |
| Path | `sources/business/02_Product_Offer_Intake_COMPLETED.docx` |
| Priority | 2 |
| Status | ACTIVE — factual maturity baseline (brutally-honest intake) |
| SHA-256 | `5b87eebc9e9da340b65e7e0cccec89de87f4c4512496e2a1e2396944c941e18e`* |
| Purpose | Establishes the factual maturity baseline: zero customers, zero revenue, zero proof, zero case studies; test-readiness verdict 3/10 ("DO NOT LAUNCH COLD OUTREACH YET"); honest scope/exclusions; delivery-risk and capacity ceilings; GBP alpha pricing (£7,500 + £10,000 bonus, with a recommended £10k + £15k = £25k alternative). |
| Claims permitted (after copy into approved KB + owner approval) | "Zero proof / pre-case-study / validation-stage" framing; honest scope and exclusions; proof-limitation language used in §11 of the approved KB. |
| Claims prohibited | Any of the 38-workflow / Lock & Key / delivery-infrastructure detail being surfaced to a prospect; any pricing figure as an automatic disclosure; any framing that the offer is test-ready (it explicitly is not, 3/10). |
| Conflicts identified | Pricing differs from rank 1 (USD vs GBP, different bonus structure) — not runtime-relevant (pricing is human-only). No other conflicts with rank 1. |

\* This hash is reported by `certutil` as 65 hex characters in a copy/paste of the raw tool output; the value above is the 64-character SHA-256 digest with the trailing duplicate character removed. If verifying, recompute with `certutil -hashfile <path> SHA256` and compare the first 64 hex characters.

### Rank 3 — `docs/HMZ_APPROVED_REPLY_RULES.md` + `brainstorms/2026-06-09-instantly-rapid-reply-policy.md`

| Field | Value |
| --- | --- |
| Path | `docs/HMZ_APPROVED_REPLY_RULES.md` (reconciled policy) and `brainstorms/2026-06-09-instantly-rapid-reply-policy.md` (Grill-Me Q&A record, historical, never edited) |
| Priority | 3 |
| Status | ACTIVE (policy doc, living/versioned) / FROZEN (brainstorm record, historical) |
| SHA-256 | Not applicable — living Markdown documents under change control via `docs/KNOWLEDGE_BASE_CHANGELOG.md` and `docs/PHASE_2_CORRECTION_CHANGELOG.md` / `docs/PHASE_2_SURGICAL_CORRECTION_CHANGELOG.md`. |
| Purpose | Owner-approved operational reply policy and safety controls: 16-category taxonomy (T1-T16), deterministic prefilter rules, structured action-plan fields, suppression levels, approved template wording, pre-send gates. |
| Claims permitted | Defines which replies are permitted and how — does not itself invent business facts; business facts must still trace to rank 1/2 via the approved KB. |
| Claims prohibited | May not override rank 1/2 facts, the five-minute objective, deterministic safety, or an unverified technical capability (`docs/SOURCE_PRIORITY.md` §2.3). |
| Conflicts identified | None outstanding after this correction pass (see `docs/PHASE_2_SURGICAL_CORRECTION_CHANGELOG.md`). Prior conflict (0.85 vs 0.90 confidence threshold) was resolved in the earlier `docs/PHASE_2_CORRECTION_CHANGELOG.md` pass (item C2). |

### Rank 4 — `sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx`

| Field | Value |
| --- | --- |
| Path | `sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx` |
| Priority | 4 — **future offer concept only** |
| Status | NOT APPROVED FOR RUNTIME CLAIMS (future-only) |
| SHA-256 | `526cc7a0bd42ff62ecb390ce40c07c2ba769216c8f0ea7601462161a07bda28` |
| Purpose | Describes a future "Alpha" commercial offer: "20+ Qualified SHOWN Meetings in 90 Days," a 3-spot "Testimonial Push," and a 3-phase future roadmap (Managed AI Sales Service → Custom AI Infrastructure Installation → Executive Membership). Recorded for completeness and to make the prohibition list traceable to its source. |
| Claims permitted | None for runtime use. May inform internal future-roadmap planning only, with explicit "future offer concept" labelling. |
| Claims prohibited | Everything in `docs/SOURCE_PRIORITY.md` §4's prohibited list: 20+ qualified shown meetings; prospects ready to buy; ensured/guaranteed results; proven delivery/infrastructure; established managed service; existing customers/case studies/testimonials; established performance stats; automatic alpha eligibility; "we handle everything at scale"; claims that the full engine is built and operational. |
| Conflicts identified | Directly conflicts with rank 2's "zero proof, 3/10 test-readiness, DO NOT LAUNCH" verdict if its claims were ever used as present-tense runtime statements. Resolved by treating this source as future-only and never copying its claims into the approved KB (`docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §"Prohibited claims"). |

\* Hash computed via `certutil -hashfile "sources\business\03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx" SHA256`.

---

## How to use this register

- Whenever any project document needs to cite a business source, it must use the **Path** column value verbatim (project-relative, forward slashes).
- If a future correction pass finds the path no longer matches a file on disk, update this register first, then propagate the corrected path to other documents.
- This register does not grant any new claims permission — it only fixes the path/identity problem. Claims permission is governed entirely by `docs/SOURCE_PRIORITY.md` and `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`.
